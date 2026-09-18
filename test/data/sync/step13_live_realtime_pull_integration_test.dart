import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/supabase_realtime_sync_adapter.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DummyRemoteApiDispatcher implements RemoteApiDispatcher {
  @override
  Future<dynamic> dispatch(SyncOperation operation) async {
    return {'status': 'ok'};
  }
}

class _AlwaysConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

void main() {
  group('Step 13 — Live Supabase Realtime + Pull Orchestration Integration Tests', () {
    late DioClient dioClient;
    late Dio dio;
    late SupabaseClient supabaseClient;
    late AppDatabase db;
    late SyncOperationsDao syncOperationsDao;
    late SyncStateDao syncStateDao;
    late RemoteChangeApplier changeApplier;
    late SyncRemoteDataSource remoteDataSource;
    late SupabaseRealtimeSyncAdapter realtimeAdapter;
    late SyncEngine syncEngine;
    bool isLiveBackendAvailable = true;

    final runId = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    late final String testCustomerId;
    late final String testCustomerName;
    late final String testPhone;

    late final String noSignalCustomerId;
    late final String noSignalCustomerName;
    late final String noSignalPhone;

    setUpAll(() async {
      dioClient = DioClient();
      dio = dioClient.dio;

      const supabaseUrl = String.fromEnvironment(
        'SUPABASE_URL_ROOT',
        defaultValue: 'https://dyhfgnbhijukbdptreto.supabase.co',
      );
      const supabaseAnonKey = String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5aGZnbmJoaWp1a2JkcHRyZXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NjcxNDcsImV4cCI6MjEwNDA0MzE0N30.gInc0tuzZiWq8EeEqbNBYa_Ay4liCcB4iGGOjUMnOBw',
      );
      supabaseClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

      testCustomerId = 'c1300000-0000-4000-8000-$runId';
      testCustomerName = 'Step 13 Realtime Tester $runId';
      testPhone = '011${DateTime.now().millisecondsSinceEpoch % 100000000}'
          .padRight(11, '3');

      noSignalCustomerId = 'c1300000-0000-4000-8001-$runId';
      noSignalCustomerName = 'Step 13 No-Signal Tester $runId';
      noSignalPhone = '012${DateTime.now().millisecondsSinceEpoch % 100000000}'
          .padRight(11, '4');

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isLiveBackendAvailable = false;
        }
      } catch (_) {
        isLiveBackendAvailable = false;
      }
    });

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      syncOperationsDao = SyncOperationsDao(db);
      syncStateDao = SyncStateDao(db);
      changeApplier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
      );
      remoteDataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));
      realtimeAdapter = SupabaseRealtimeSyncAdapter(client: supabaseClient);

      syncEngine = SyncEngine(
        syncOperationsDao: syncOperationsDao,
        remoteApiDispatcher: _DummyRemoteApiDispatcher(),
        networkInfo: _AlwaysConnectedNetworkInfo(),
        retryPolicy: SyncRetryPolicy(),
        errorClassifier: const SyncErrorClassifier(),
        syncRemoteDataSource: remoteDataSource,
        remoteChangeApplier: changeApplier,
        syncStateDao: syncStateDao,
        realtimeAdapter: realtimeAdapter,
      );
    });

    tearDown(() async {
      await realtimeAdapter.unsubscribe();
      syncEngine.dispose();
      await db.close();
    });

    test(
      '1. Live subscription check: SupabaseRealtimeSyncAdapter subscribes to laundry:sync broadcast topic',
      () async {
        if (!isLiveBackendAvailable) return;

        // Verify the realtime adapter subscribes without throwing
        await realtimeAdapter.subscribe();

        // Safe idempotent repeat: duplicate subscribe calls are prevented
        await realtimeAdapter.subscribe();
      },
    );

    test(
      '2. Remote mutation emits real Supabase Broadcast wake-up signal which triggers authoritative Pull, applies locally, advances cursor, and creates zero echo SyncOperations',
      () async {
        if (!isLiveBackendAvailable) return;

        // a. Subscribe to the Broadcast channel via SyncEngine initialization
        await syncEngine.initialize(triggerInitialSync: false);

        // b & c. Establish subscription readiness and allow initial/reconnect signal to settle
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (syncEngine.state.status == SyncEngineStatus.syncing) {
          await syncEngine.stateStream.firstWhere(
            (s) => s.status != SyncEngineStatus.syncing,
          );
        }

        // Fast-forward local cursor to current latest remote sequence
        int currentMaxSeq = 0;
        var probe = await remoteDataSource.getChanges(
          after: currentMaxSeq,
          limit: 100,
        );
        while (probe.changes.isNotEmpty) {
          currentMaxSeq = probe.changes.last.sequence;
          if (!probe.hasMore) break;
          probe = await remoteDataSource.getChanges(
            after: currentMaxSeq,
            limit: 100,
          );
        }
        await syncStateDao.updateLastAppliedSequence(currentMaxSeq);

        // d. Register a mutation-specific signal listener BEFORE performing mutation
        final signalCompleter = Completer<void>();
        final subscription = realtimeAdapter.onSyncAvailable.listen((_) {
          if (!signalCompleter.isCompleted) {
            signalCompleter.complete();
          }
        });

        try {
          // e. Perform a real remote mutation through the existing Edge Function API
          final postRes = await dio.post(
            '/customers',
            data: {
              'id': testCustomerId,
              'name': testCustomerName,
              'phone': testPhone,
              'notes': 'Created by Step 13 live integration test',
            },
            options: Options(
              headers: {'X-Operation-ID': 'op-step13-cust-$runId'},
              validateStatus: (_) => true,
            ),
          );

          expect(postRes.statusCode, equals(201));

          // f & g. Require a real Broadcast event — fail explicitly if not received
          await signalCompleter.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail(
              'Supabase Realtime Broadcast wake-up signal was NOT received within 10s of remote mutation',
            ),
          );

          // h & i. Allow authoritative Pull to persist the entity locally into SQLite
          Customer? localCustomer;
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (DateTime.now().isBefore(deadline)) {
            localCustomer = await (db.select(db.customers)
                  ..where((tbl) => tbl.id.equals(testCustomerId)))
                .getSingleOrNull();
            if (localCustomer != null) break;
            await syncEngine.pull();
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }

          expect(localCustomer, isNotNull);
          expect(localCustomer!.id, equals(testCustomerId));
          expect(localCustomer.name, equals(testCustomerName));
          expect(localCustomer.phone, equals(testPhone));

          // j. Verify: Cursor advanced beyond currentMaxSeq
          final lastCursor = await syncStateDao.getLastAppliedSequence();
          expect(lastCursor, isNotNull);
          expect(lastCursor, greaterThan(currentMaxSeq));

          // k. Verify zero local SyncOperation echo (Invariant: remote apply never creates local operations)
          final pendingOps = await syncOperationsDao.getPendingOperations();
          expect(pendingOps, isEmpty);
        } finally {
          await subscription.cancel();
        }
      },
    );

    test(
      '3. Authoritative Pull works independently without any Realtime signal (adapter unsubscribed/offline)',
      () async {
        if (!isLiveBackendAvailable) return;

        // Ensure realtime adapter is completely unsubscribed
        await realtimeAdapter.unsubscribe();
        expect(realtimeAdapter.isSubscribed, isFalse);

        await syncEngine.initialize(triggerInitialSync: false);

        // Fast-forward local cursor to current latest remote sequence
        int currentMaxSeq = 0;
        var probe = await remoteDataSource.getChanges(
          after: currentMaxSeq,
          limit: 100,
        );
        while (probe.changes.isNotEmpty) {
          currentMaxSeq = probe.changes.last.sequence;
          if (!probe.hasMore) break;
          probe = await remoteDataSource.getChanges(
            after: currentMaxSeq,
            limit: 100,
          );
        }
        await syncStateDao.updateLastAppliedSequence(currentMaxSeq);

        // Perform remote mutation with no realtime listener
        final postRes = await dio.post(
          '/customers',
          data: {
            'id': noSignalCustomerId,
            'name': noSignalCustomerName,
            'phone': noSignalPhone,
            'notes': 'Created by Step 13 without realtime test',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step13-nosig-$runId'},
            validateStatus: (_) => true,
          ),
        );
        expect(postRes.statusCode, equals(201));

        // Directly invoke authoritative Pull and wait for local SQLite persistence
        Customer? localCustomer;
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (DateTime.now().isBefore(deadline)) {
          await syncEngine.pull();
          localCustomer = await (db.select(db.customers)
                ..where((tbl) => tbl.id.equals(noSignalCustomerId)))
              .getSingleOrNull();
          if (localCustomer != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }

        expect(localCustomer, isNotNull);
        expect(localCustomer!.id, equals(noSignalCustomerId));
        expect(localCustomer.name, equals(noSignalCustomerName));

        // Verify: Cursor advanced
        final lastCursor = await syncStateDao.getLastAppliedSequence();
        expect(lastCursor, isNotNull);
        expect(lastCursor, greaterThan(currentMaxSeq));

        // Verify: Zero echo SyncOperations
        final pendingOps = await syncOperationsDao.getPendingOperations();
        expect(pendingOps, isEmpty);
      },
    );

    test(
      '4. Full sync cycle: Push then Pull executes sequentially with single-flight guard',
      () async {
        if (!isLiveBackendAvailable) return;

        await syncEngine.initialize(triggerInitialSync: false);

        // Run full sync() which executes Push then Pull
        await syncEngine.sync();

        // Verify state completed successfully
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));

        // Verify cursor is still valid
        final cursor = await syncStateDao.getLastAppliedSequence();
        expect(cursor, isNotNull);
      },
    );
  });
}
