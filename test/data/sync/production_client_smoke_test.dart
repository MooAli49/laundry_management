import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/config/supabase_config.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_api.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/remote/dto/pull_changes_response_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';

/// Production Client Smoke Test
///
/// Verifies the end-to-end client connectivity path:
/// Flutter Client (DioClient / SyncRemoteApi) -> Production Edge Function -> Production Database -> Local Drift Storage
///
/// Ensures:
/// 1. Application correctly resolves and initializes with Production configuration.
/// 2. Canonical master data loads cleanly through the Production Edge Function.
/// 3. Canonical master data ingests cleanly into local Drift SQLite database via RemoteChangeApplier.
/// 4. Direct PostgREST table access bypass is blocked.
/// 5. Production remains pristine with exactly 35 canonical baseline changes and 0 test transactions.
void main() {
  group('Production Client Smoke Test', () {
    late final SupabaseConfig config;
    late final Dio edgeFunctionDio;
    late final Dio directPostgrestDio;
    late final SyncRemoteApi syncRemoteApi;

    setUpAll(() {
      String? prodUrl;
      String? prodAnonKey;

      // 1. Try reading from git-ignored release_env.json
      final envFile = File('release_env.json');
      if (envFile.existsSync()) {
        try {
          final content = envFile.readAsStringSync();
          final data = jsonDecode(content) as Map<String, dynamic>;
          prodUrl = data['SUPABASE_URL_ROOT'] as String?;
          prodAnonKey = data['SUPABASE_ANON_KEY'] as String?;
        } catch (_) {}
      }

      // 2. Resolve configuration in Release mode
      config = SupabaseConfig.resolve(
        customUrlRoot: prodUrl,
        customAnonKey: prodAnonKey,
        isRelease: true,
      );

      // 3. Initialize Flutter network client
      final client = DioClient(config: config);
      edgeFunctionDio = client.dio;
      syncRemoteApi = SyncRemoteApi(edgeFunctionDio);

      // Direct client to verify PostgREST bypass protection
      directPostgrestDio = Dio(
        BaseOptions(
          baseUrl: config.urlRoot,
          headers: {
            'apikey': config.anonKey,
            'Authorization': 'Bearer ${config.anonKey}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
    });

    test('1. Production configuration resolves to dedicated Production project', () {
      expect(config.urlRoot, equals('https://rvrskluqfbrkvvlxtxfp.supabase.co'));
      expect(
        config.apiUrl,
        equals('https://rvrskluqfbrkvvlxtxfp.supabase.co/functions/v1/api'),
      );
      expect(config.anonKey, isNotEmpty);
      expect(config.anonKey, isNot(equals(SupabaseConfig.defaultDevAnonKey)));
      expect(config.urlRoot, isNot(contains(SupabaseConfig.devProjectRef)));
    });

    test('2. Master data loads successfully from Production Edge Function', () async {
      final response = await syncRemoteApi.getChanges(after: 0, limit: 50);

      expect(response, isA<Map<String, dynamic>>());
      final data = response as Map<String, dynamic>;

      expect(data['has_more'], isFalse);
      expect(data['latest_sequence'], equals(35));

      final changes = data['changes'] as List<dynamic>;
      expect(changes.length, equals(35));

      // Verify sequence integrity: 1..35 contiguous
      for (int i = 0; i < changes.length; i++) {
        final change = changes[i] as Map<String, dynamic>;
        expect(change['sequence'], equals(i + 1));
      }

      // Verify canonical entity counts
      final entityTypes = changes.map((c) => c['entity_type'] as String).toList();
      expect(entityTypes.where((t) => t == 'business_settings').length, equals(1));
      expect(entityTypes.where((t) => t == 'item_type').length, equals(4));
      expect(entityTypes.where((t) => t == 'expense_category').length, equals(7));
      expect(entityTypes.where((t) => t == 'service').length, equals(5));
      expect(entityTypes.where((t) => t == 'carpet_size').length, equals(3));
      expect(entityTypes.where((t) => t == 'storage_location').length, equals(5));
      expect(entityTypes.where((t) => t == 'item_definition').length, equals(10));
    });

    test('3. Master data ingests into local Drift SQLite database via RemoteChangeApplier', () async {
      final db = app_db.AppDatabase(NativeDatabase.memory());
      final syncStateDao = SyncStateDao(db);
      final applier = RemoteChangeApplier(db: db, syncStateDao: syncStateDao);

      try {
        final initialSeq = await syncStateDao.getLastAppliedSequence();
        expect(initialSeq, equals(0));

        final response = await syncRemoteApi.getChanges(after: 0, limit: 50);
        final page = PullChangesResponseDto.fromJson(response as Map<String, dynamic>);

        await applier.applyPage(page);

        final updatedSeq = await syncStateDao.getLastAppliedSequence();
        expect(updatedSeq, equals(35));

        // Verify local table population
        final itemTypes = await db.select(db.itemTypes).get();
        final expenseCategories = await db.select(db.expenseCategories).get();
        final services = await db.select(db.services).get();
        final carpetSizes = await db.select(db.carpetSizes).get();
        final storageLocations = await db.select(db.storageLocations).get();
        final itemDefinitions = await db.select(db.itemDefinitions).get();
        final businessSettings = await db.select(db.businessSettings).get();

        expect(itemTypes.length, equals(4));
        expect(expenseCategories.length, equals(7));
        expect(services.length, equals(5));
        expect(carpetSizes.length, equals(3));
        expect(storageLocations.length, equals(5));
        expect(itemDefinitions.length, equals(10));
        expect(businessSettings.length, equals(1));
      } finally {
        await db.close();
      }
    });

    test('4. Sync pull beyond baseline returns zero changes (Production is clean)', () async {
      final response = await syncRemoteApi.getChanges(after: 35, limit: 10);
      final data = response as Map<String, dynamic>;

      expect(data['has_more'], isFalse);
      expect(data['latest_sequence'], equals(35));
      final changes = data['changes'] as List<dynamic>;
      expect(changes, isEmpty);
    });

    test('5. Direct PostgREST mutation is blocked by RLS & privilege revocation', () async {
      final res = await directPostgrestDio.post(
        '/rest/v1/customers',
        data: {'name': 'Unauthorized Test', 'phone': '01000000000'},
      );

      // Must be forbidden / unauthorized (Postgres privilege error 42501 mapped to 401/403)
      expect(res.statusCode, isIn([401, 403]));
      final body = res.data.toString();
      expect(body, contains('permission denied for table customers'));
    });

    test('6. Direct PostgREST stored function invocation is forbidden', () async {
      final res = await directPostgrestDio.post(
        '/rest/v1/rpc/get_sync_changes',
        data: {'p_after': 0, 'p_limit': 10},
      );

      // Must be forbidden (EXECUTE privilege revoked from anon)
      expect(res.statusCode, isIn([401, 403, 404]));
    });
  });
}
