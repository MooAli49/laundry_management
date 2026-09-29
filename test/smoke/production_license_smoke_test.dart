import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/license/license_service.dart';
import 'package:laundry_management/core/license/license_guard.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/license_cache_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/domain/license/license_status.dart';

class _RealHttpOverrides extends HttpOverrides {}

class _LiveTestNetworkInfo implements NetworkInfo {
  bool online = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  const isDartDefineOptIn = bool.fromEnvironment('RUN_PRODUCTION_SMOKE_TEST');
  final isEnvOptIn =
      Platform.environment['RUN_PRODUCTION_SMOKE_TEST'] == 'true';
  final isOptIn = isDartDefineOptIn || isEnvOptIn;

  if (isOptIn) {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
  }

  const prodApiUrl =
      'https://rvrskluqfbrkvvlxtxfp.supabase.co/functions/v1/api';
  const prodAnonKey = 'sb_publishable__UIcu7AHpwHejCE9b7RA6w_PEwn8aNY';

  late Dio dio;
  late LicenseRemoteApi remoteApi;
  late LicenseRemoteDataSourceImpl remoteDataSource;
  late AppDatabase db;
  late LicenseCacheDao cacheDao;
  late _LiveTestNetworkInfo networkInfo;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: prodApiUrl,
        headers: {
          'apikey': prodAnonKey,
          'Authorization': 'Bearer $prodAnonKey',
          'Accept': 'application/json',
        },
      ),
    );
    remoteApi = LicenseRemoteApi(dio);
    remoteDataSource = LicenseRemoteDataSourceImpl(remoteApi);

    db = AppDatabase(NativeDatabase.memory());
    cacheDao = LicenseCacheDao(db);
    networkInfo = _LiveTestNetworkInfo();
  });

  tearDown(() async {
    dio.close(force: true);
    networkInfo.dispose();
    await db.close();
  });

  group(
    'Production License Live Smoke Tests',
    skip: !isOptIn
        ? 'Production smoke test skipped by default. Opt-in required: run with RUN_PRODUCTION_SMOKE_TEST=true or flutter test --dart-define=RUN_PRODUCTION_SMOKE_TEST=true'
        : null,
    () {
      test(
        'Phase 2: Live Production Active State returns status active',
        () async {
          final remoteData = await remoteDataSource.fetchLicenseInfo();
          expect(remoteData.status, equals('active'));
          expect(remoteData.suspendedAt, isNull);

          final licenseService = LicenseService(
            remoteDataSource: remoteDataSource,
            cacheDao: cacheDao,
            networkInfo: networkInfo,
          );

          await licenseService.initialize();

          expect(licenseService.currentStatus, equals(LicenseStatus.active));
          expect(licenseService.suspendedAt, isNull);

          final cached = await cacheDao.getCached();
          expect(cached, isNotNull);
          expect(cached!.remoteStatus, equals('active'));
          expect(cached.suspendedAt, isNull);

          final guard = LicenseGuard(licenseService);
          expect(guard.status, equals(LicenseStatus.active));
          expect(guard.daysRemainingInGrace, equals(0));
          guard.dispose();
          licenseService.dispose();
        },
      );

      test(
        'Phase 3 & 4: Suspension state evaluation & Grace Period entry',
        () async {
          // Create a suspension fixture anchored to recent timestamp (e.g. 1 hour ago)
          final simulatedSuspension = DateTime.now().subtract(
            const Duration(hours: 1),
          );
          await cacheDao.saveCache(
            remoteStatus: 'suspended',
            suspendedAt: simulatedSuspension,
            lastCheckedAt: DateTime.now(),
          );

          // Offline service evaluates cached suspension
          networkInfo.setOnline(false);
          final licenseService = LicenseService(
            remoteDataSource: remoteDataSource,
            cacheDao: cacheDao,
            networkInfo: networkInfo,
          );

          await licenseService.initialize();

          expect(
            licenseService.currentStatus,
            equals(LicenseStatus.gracePeriod),
          );
          expect(
            licenseService.suspendedAt!
                    .difference(simulatedSuspension)
                    .inSeconds
                    .abs() <=
                1,
            isTrue,
          );

          final cached = await cacheDao.getCached();
          expect(cached, isNotNull);
          expect(cached!.remoteStatus, equals('suspended'));
          expect(
            cached.suspendedAt!
                    .difference(simulatedSuspension)
                    .inSeconds
                    .abs() <=
                1,
            isTrue,
          );
          expect(cached.lastCheckedAt, isNotNull);

          final guard = LicenseGuard(licenseService);
          expect(guard.status, equals(LicenseStatus.gracePeriod));
          expect(guard.daysRemainingInGrace, greaterThanOrEqualTo(6));
          expect(guard.daysRemainingInGrace, lessThanOrEqualTo(7));
          guard.dispose();
          licenseService.dispose();
        },
      );

      test(
        'Phase 5: Offline Grace Period persists across app restart',
        () async {
          // Step 1: Pre-populate cache with a suspended state
          final simulatedSuspendedAt = DateTime.now().subtract(
            const Duration(days: 2),
          );
          await cacheDao.saveCache(
            remoteStatus: 'suspended',
            suspendedAt: simulatedSuspendedAt,
            lastCheckedAt: DateTime.now(),
          );

          // Step 2: Disable network (offline)
          networkInfo.setOnline(false);

          // Step 3: Instantiate a fresh LicenseService (simulating restart)
          final offlineService = LicenseService(
            remoteDataSource: remoteDataSource,
            cacheDao: cacheDao,
            networkInfo: networkInfo,
          );

          await offlineService.initialize();

          // App must NOT fail open to active when cached suspension exists
          expect(
            offlineService.currentStatus,
            equals(LicenseStatus.gracePeriod),
          );
          expect(
            offlineService.suspendedAt!
                    .difference(simulatedSuspendedAt)
                    .inSeconds
                    .abs() <=
                1,
            isTrue,
          );

          final guard = LicenseGuard(offlineService);
          expect(guard.status, equals(LicenseStatus.gracePeriod));
          expect(guard.daysRemainingInGrace, greaterThanOrEqualTo(5));
          expect(guard.daysRemainingInGrace, lessThanOrEqualTo(7));
          guard.dispose();
          offlineService.dispose();
        },
      );

      test(
        'Phase 6: Locked-Out State simulation when > 7 days elapsed',
        () async {
          final simulatedSuspendedAt = DateTime.now().subtract(
            const Duration(days: 1),
          );
          await cacheDao.saveCache(
            remoteStatus: 'suspended',
            suspendedAt: simulatedSuspendedAt,
            lastCheckedAt: DateTime.now(),
          );

          networkInfo.setOnline(false);

          // Simulate clock advanced 8 days past suspendedAt
          final expiredClockService = LicenseService(
            remoteDataSource: remoteDataSource,
            cacheDao: cacheDao,
            networkInfo: networkInfo,
            clock: () => DateTime.now().add(const Duration(days: 8)),
          );

          await expiredClockService.initialize();

          expect(
            expiredClockService.currentStatus,
            equals(LicenseStatus.lockedOut),
          );

          final guard = LicenseGuard(expiredClockService);
          expect(guard.status, equals(LicenseStatus.lockedOut));
          expect(guard.daysRemainingInGrace, equals(0));
          guard.dispose();
          expiredClockService.dispose();
        },
      );

      test(
        'Phase 8: Security Check — Client cannot write to license endpoint',
        () async {
          // 1. POST to Edge Function /license
          try {
            await dio.post('/api/v1/license', data: {'status': 'active'});
            fail('POST /api/v1/license should have been rejected with 405');
          } on DioException catch (e) {
            expect(e.response?.statusCode, equals(405));
          }

          // 2. PATCH to Edge Function /license
          try {
            await dio.patch('/api/v1/license', data: {'status': 'active'});
            fail('PATCH /api/v1/license should have been rejected with 405');
          } on DioException catch (e) {
            expect(e.response?.statusCode, equals(405));
          }

          // 3. DELETE to Edge Function /license
          try {
            await dio.delete('/api/v1/license');
            fail('DELETE /api/v1/license should have been rejected with 405');
          } on DioException catch (e) {
            expect(e.response?.statusCode, equals(405));
          }

          // 4. Direct PostgREST write attempt via anon key
          final restDio = Dio(
            BaseOptions(
              baseUrl: 'https://rvrskluqfbrkvvlxtxfp.supabase.co/rest/v1',
              headers: {
                'apikey': prodAnonKey,
                'Authorization': 'Bearer $prodAnonKey',
                'Content-Type': 'application/json',
              },
            ),
          );

          try {
            await restDio.post(
              '/license_info',
              data: {'id': 'hacked', 'status': 'active'},
            );
            fail('Direct PostgREST INSERT should have been blocked');
          } on DioException catch (e) {
            // PostgREST with RLS and no grants returns 401 Unauthorized or 403 Forbidden or 404
            expect(
              [401, 403, 404].contains(e.response?.statusCode) ||
                  e.response?.statusCode != 201,
              isTrue,
            );
          }

          try {
            await restDio.patch(
              '/license_info?id=eq.singleton',
              data: {'status': 'active'},
            );
            fail('Direct PostgREST PATCH should have been blocked');
          } on DioException catch (e) {
            expect([401, 403, 404].contains(e.response?.statusCode), isTrue);
          }

          restDio.close(force: true);
        },
      );

      test(
        'Phase 7: Live Production Reinstatement clears suspension and restores active state',
        () async {
          // Pre-seed local cache with previous suspended state
          await cacheDao.saveCache(
            remoteStatus: 'suspended',
            suspendedAt: DateTime.now().subtract(const Duration(days: 3)),
            lastCheckedAt: DateTime.now().subtract(
              const Duration(hours: 25),
            ), // past 24h throttle
          );

          final licenseService = LicenseService(
            remoteDataSource: remoteDataSource,
            cacheDao: cacheDao,
            networkInfo: networkInfo,
          );

          // Force initial check on startup
          await licenseService.initialize();

          // Remote has returned active; local cache must be updated and cleared
          expect(licenseService.currentStatus, equals(LicenseStatus.active));
          expect(licenseService.suspendedAt, isNull);

          final cached = await cacheDao.getCached();
          expect(cached, isNotNull);
          expect(cached!.remoteStatus, equals('active'));
          expect(cached.suspendedAt, isNull);

          final guard = LicenseGuard(licenseService);
          expect(guard.status, equals(LicenseStatus.active));
          expect(guard.daysRemainingInGrace, equals(0));
          guard.dispose();
          licenseService.dispose();
        },
      );
    },
  );
}
