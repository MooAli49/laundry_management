import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/app_exception.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/core/network/realtime_sync_adapter.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/remote/dto/pull_changes_response_dto.dart';
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;

  @override
  Future<bool> get isConnected async => isConnectedValue;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void setConnected(bool value) {
    isConnectedValue = value;
    _connectivityController.add(value);
  }

  void dispose() {
    _connectivityController.close();
  }
}

class FakeRemoteApiDispatcher implements RemoteApiDispatcher {
  final List<SyncOperation> dispatchedOperations = [];
  Future<dynamic> Function(SyncOperation op)? onDispatch;

  @override
  Future<dynamic> dispatch(SyncOperation operation) async {
    dispatchedOperations.add(operation);
    if (onDispatch != null) {
      return await onDispatch!(operation);
    }
    return {'status': 'ok'};
  }
}

class FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  int getChangesCallCount = 0;
  final List<int> requestedAfterCursors = [];
  Future<PullChangesResponseDto> Function({required int after, int? limit})?
  onGetChanges;

  @override
  Future<PullChangesResponseDto> getChanges({
    required int after,
    int? limit,
  }) async {
    getChangesCallCount++;
    requestedAfterCursors.add(after);
    if (onGetChanges != null) {
      return await onGetChanges!(after: after, limit: limit);
    }
    return PullChangesResponseDto(
      changes: const [],
      hasMore: false,
      latestSequence: after,
    );
  }
}

class FakeRealtimeSyncAdapter implements RealtimeSyncAdapter {
  final StreamController<void> _signalController =
      StreamController<void>.broadcast();
  int subscribeCount = 0;
  int unsubscribeCount = 0;
  bool isSubscribed = false;

  @override
  Stream<void> get onSyncAvailable => _signalController.stream;

  @override
  Future<void> subscribe() async {
    subscribeCount++;
    isSubscribed = true;
  }

  @override
  Future<void> unsubscribe() async {
    unsubscribeCount++;
    isSubscribed = false;
  }

  void emitSignal() {
    _signalController.add(null);
  }

  void dispose() {
    _signalController.close();
  }
}

void main() {
  late AppDatabase db;
  late SyncOperationsDao syncOperationsDao;
  late SyncStateDao syncStateDao;
  late RemoteChangeApplier remoteChangeApplier;
  late FakeNetworkInfo networkInfo;
  late FakeRemoteApiDispatcher dispatcher;
  late FakeSyncRemoteDataSource remoteDataSource;
  late FakeRealtimeSyncAdapter realtimeAdapter;
  late SyncRetryPolicy retryPolicy;
  late SyncErrorClassifier errorClassifier;
  late SyncEngine syncEngine;
  late DateTime fixedTime;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    syncOperationsDao = SyncOperationsDao(db);
    syncStateDao = SyncStateDao(db);
    remoteChangeApplier = RemoteChangeApplier(
      db: db,
      syncStateDao: syncStateDao,
    );
    networkInfo = FakeNetworkInfo();
    dispatcher = FakeRemoteApiDispatcher();
    remoteDataSource = FakeSyncRemoteDataSource();
    realtimeAdapter = FakeRealtimeSyncAdapter();
    retryPolicy = SyncRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      jitterGenerator: () => Duration.zero,
    );
    errorClassifier = const SyncErrorClassifier();
    fixedTime = DateTime(2026, 9, 18, 12, 0, 0);

    syncEngine = SyncEngine(
      syncOperationsDao: syncOperationsDao,
      remoteApiDispatcher: dispatcher,
      networkInfo: networkInfo,
      retryPolicy: retryPolicy,
      errorClassifier: errorClassifier,
      syncRemoteDataSource: remoteDataSource,
      remoteChangeApplier: remoteChangeApplier,
      syncStateDao: syncStateDao,
      realtimeAdapter: realtimeAdapter,
      clock: () => fixedTime,
    );

    // Initialize sync_state singleton with cursor 0
    await syncStateDao.getSyncState();
  });

  tearDown(() async {
    syncEngine.dispose();
    networkInfo.dispose();
    realtimeAdapter.dispose();
    await db.close();
  });

  group('Phase C3 — Pull Orchestration & Concurrency Engine Tests', () {
    // -------------------------------------------------------------------------
    // Scenario A: Single-flight
    // -------------------------------------------------------------------------
    test(
      'Scenario A: Single-flight: simultaneous pull calls result in exactly one active remote request',
      () async {
        final completer = Completer<PullChangesResponseDto>();
        remoteDataSource.onGetChanges = ({required int after, int? limit}) {
          return completer.future;
        };

        // Fire two pull triggers simultaneously
        final pull1 = syncEngine.pull();
        final pull2 = syncEngine.pull();

        // Let microtasks run
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Exactly one remote call was issued
        expect(remoteDataSource.getChangesCallCount, equals(1));

        // Complete the in-flight remote request with empty changes
        completer.complete(
          PullChangesResponseDto(
            changes: const [],
            hasMore: false,
            latestSequence: 0,
          ),
        );

        await Future.wait([pull1, pull2]);

        // One trailing iteration runs because the second trigger was coalesced while the first was active
        expect(remoteDataSource.getChangesCallCount, equals(2));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario B: Trigger Coalescing
    // -------------------------------------------------------------------------
    test(
      'Scenario B: Trigger coalescing: Realtime + resume + connectivity + timer while sync is active collapse into ONE trailing sync',
      () async {
        final completer = Completer<PullChangesResponseDto>();
        remoteDataSource.onGetChanges = ({required int after, int? limit}) {
          return completer.future;
        };

        // Start active sync
        final initialSync = syncEngine.sync();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(remoteDataSource.getChangesCallCount, equals(1));

        // Now fire multiple distinct triggers while sync is active
        realtimeAdapter.emitSignal();
        realtimeAdapter.emitSignal();
        networkInfo.setConnected(true);
        unawaited(syncEngine.sync());
        unawaited(syncEngine.pull());

        // Complete the initial request
        completer.complete(
          PullChangesResponseDto(
            changes: const [],
            hasMore: false,
            latestSequence: 0,
          ),
        );

        await initialSync;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Total calls should be exactly 2 (initial + 1 coalesced trailing pass), NOT 5!
        expect(remoteDataSource.getChangesCallCount, equals(2));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario C: Realtime Signal During Pagination
    // -------------------------------------------------------------------------
    test(
      'Scenario C: Realtime signal during pagination triggers exactly ONE trailing pull after pagination finishes',
      () async {
        int pageCounter = 0;
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          pageCounter++;
          if (pageCounter == 1) {
            // While page 1 is returning, fire Realtime signal
            realtimeAdapter.emitSignal();
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 1,
                  operationId: 'op-1',
                  entityType: 'customer',
                  entityId: 'cust-1',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-1',
                    'name': 'Customer 1',
                    'phone': '111',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: true,
              latestSequence: 2,
            );
          } else if (pageCounter == 2) {
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 2,
                  operationId: 'op-2',
                  entityType: 'customer',
                  entityId: 'cust-2',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-2',
                    'name': 'Customer 2',
                    'phone': '222',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: false,
              latestSequence: 2,
            );
          } else {
            // Trailing pull iteration
            return PullChangesResponseDto(
              changes: const [],
              hasMore: false,
              latestSequence: 2,
            );
          }
        };

        await syncEngine.initialize(triggerInitialSync: false);

        await syncEngine.pull();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Initial pagination had 2 pages (page 1, page 2).
        // Trailing pull had 1 page (checks if more arrived).
        // Total = 3 calls
        expect(remoteDataSource.getChangesCallCount, equals(3));
        expect(await syncStateDao.getLastAppliedSequence(), equals(2));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario D: Multi-Page Pagination
    // -------------------------------------------------------------------------
    test(
      'Scenario D: Multi-page pagination: sequential pages verify sequential persisted cursors',
      () async {
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          if (after == 0) {
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 10,
                  operationId: 'op-page1',
                  entityType: 'customer',
                  entityId: 'cust-10',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-10',
                    'name': 'Page 1 Cust',
                    'phone': '111',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: true,
              latestSequence: 30,
            );
          } else if (after == 10) {
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 20,
                  operationId: 'op-page2',
                  entityType: 'customer',
                  entityId: 'cust-20',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-20',
                    'name': 'Page 2 Cust',
                    'phone': '222',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: true,
              latestSequence: 30,
            );
          } else if (after == 20) {
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 30,
                  operationId: 'op-page3',
                  entityType: 'customer',
                  entityId: 'cust-30',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-30',
                    'name': 'Page 3 Cust',
                    'phone': '333',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: false,
              latestSequence: 30,
            );
          }
          return PullChangesResponseDto(
            changes: const [],
            hasMore: false,
            latestSequence: after,
          );
        };

        await syncEngine.pull();

        // 3 pages requested sequentially
        expect(remoteDataSource.requestedAfterCursors, equals([0, 10, 20]));
        expect(await syncStateDao.getLastAppliedSequence(), equals(30));

        // Verify all 3 customers exist in local SQLite
        final customers = await db.select(db.customers).get();
        expect(customers.length, equals(3));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario E: Partial Pagination Failure
    // -------------------------------------------------------------------------
    test(
      'Scenario E: Partial pagination failure: page 1 commits, page 2 fails, next pull starts from page 1 cursor',
      () async {
        int callCount = 0;
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          callCount++;
          if (callCount == 1) {
            return PullChangesResponseDto(
              changes: [
                SyncChangeDto(
                  sequence: 15,
                  operationId: 'op-page1-ok',
                  entityType: 'customer',
                  entityId: 'cust-15',
                  operationType: 'create',
                  payload: {
                    'id': 'cust-15',
                    'name': 'Cust 15',
                    'phone': '1515',
                  },
                  createdAt: DateTime.now(),
                ),
              ],
              hasMore: true,
              latestSequence: 30,
            );
          } else {
            throw DioException(
              requestOptions: RequestOptions(path: '/sync/changes'),
              type: DioExceptionType.connectionTimeout,
            );
          }
        };

        // First pull attempt: page 1 succeeds, page 2 fails
        await syncEngine.pull();

        // Page 1 remained committed and advanced cursor to 15
        expect(await syncStateDao.getLastAppliedSequence(), equals(15));
        final cust15 = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-15')))
            .getSingleOrNull();
        expect(cust15, isNotNull);

        // Next pull attempt: resumes strictly from after: 15
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          return PullChangesResponseDto(
            changes: const [],
            hasMore: false,
            latestSequence: 15,
          );
        };

        await syncEngine.pull();
        expect(remoteDataSource.requestedAfterCursors.last, equals(15));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario F: Lifecycle & Resource Cleanup
    // -------------------------------------------------------------------------
    test(
      'Scenario F: Lifecycle: dispose cancels subscriptions/timers, prevents new work from starting',
      () async {
        await syncEngine.initialize(periodicSyncInterval: const Duration(minutes: 5));
        expect(realtimeAdapter.subscribeCount, equals(1));
        expect(syncEngine.isInitialized, isTrue);

        syncEngine.dispose();
        expect(syncEngine.isDisposed, isTrue);
        expect(realtimeAdapter.unsubscribeCount, equals(1));

        final callsBefore = remoteDataSource.getChangesCallCount;
        // Calling pull or sync after dispose must be a no-op
        await syncEngine.pull();
        await syncEngine.sync();
        expect(remoteDataSource.getChangesCallCount, equals(callsBefore));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario I: Push -> Remote Change -> Realtime -> Pull (Zero Echo Loop)
    // -------------------------------------------------------------------------
    test(
      'Scenario I: Push -> remote change -> Realtime -> pull: 0 echo SyncOperations created',
      () async {
        // 1. Enqueue local operation
        await syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: 'cust-local-1',
          operationType: 'create',
          payload: '{"name":"Local Cust"}',
        );

        final initialOps = await syncOperationsDao.getEligibleOperations(asOf: fixedTime);
        expect(initialOps.length, equals(1));
        final localOpId = initialOps.first.id;

        // Configure remote pull to return the committed change
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          return PullChangesResponseDto(
            changes: [
              SyncChangeDto(
                sequence: 100,
                operationId: localOpId,
                entityType: 'customer',
                entityId: 'cust-local-1',
                operationType: 'create',
                payload: {
                  'id': 'cust-local-1',
                  'name': 'Local Cust',
                  'phone': '999',
                },
                createdAt: DateTime.now(),
              ),
            ],
            hasMore: false,
            latestSequence: 100,
          );
        };

        // Run full sync: pushes op-local-1, then pulls change 100
        await syncEngine.sync();

        // Verify local op was marked synced
        final op = await (db.select(db.syncOperations)
              ..where((t) => t.id.equals(localOpId)))
            .getSingle();
        expect(op.status, equals('synced'));

        // Verify customer was written into local SQLite
        final cust = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-local-1')))
            .getSingle();
        expect(cust.name, equals('Local Cust'));

        // CRITICAL INVARIANT: applying remote change created ZERO new SyncOperation rows!
        final allOps = await db.select(db.syncOperations).get();
        expect(allOps.length, equals(1)); // Only original local op exists
        expect(allOps.first.id, equals(localOpId));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario J: CURSOR_TOO_OLD (HTTP 410) Isolation
    // -------------------------------------------------------------------------
    test(
      'Scenario J: CURSOR_TOO_OLD: stops pagination, surfaces distinctly, preserves pending SyncOperations',
      () async {
        // Enqueue a local pending operation
        await syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: 'order-123',
          operationType: 'create',
          payload: '{"orderNumber":"26-001"}',
        );

        // Remote throws CursorTooOldException
        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Cursor is too old',
            oldestAvailableSequence: 500,
          );
        };

        await syncEngine.pull();

        // State reflects failed with CURSOR_TOO_OLD
        expect(syncEngine.state.status, equals(SyncEngineStatus.failed));
        expect(syncEngine.state.lastError, contains('CURSOR_TOO_OLD'));

        // CRITICAL INVARIANT: Local pending SyncOperation is strictly preserved!
        final remaining = await syncOperationsDao.getEligibleOperations(
          asOf: fixedTime,
        );
        expect(remaining.length, equals(1));
        expect(remaining.first.entityId, equals('order-123'));
        expect(remaining.first.status, equals('pending'));
      },
    );

    // =========================================================================
    // Phase C4-B: Pull Error Handling & Observability
    // =========================================================================
    group('Phase C4-B — Pull Error Handling & Observability', () {
      test(
        '1. CursorTooOldException retains dedicated handling and surfaces distinctly',
        () async {
          String? capturedLog;
          final customEngine = SyncEngine(
            syncOperationsDao: syncOperationsDao,
            remoteApiDispatcher: dispatcher,
            networkInfo: networkInfo,
            retryPolicy: retryPolicy,
            errorClassifier: errorClassifier,
            syncRemoteDataSource: remoteDataSource,
            remoteChangeApplier: remoteChangeApplier,
            syncStateDao: syncStateDao,
            realtimeAdapter: realtimeAdapter,
            clock: () => fixedTime,
            logHandler: (msg, [err, stack]) {
              capturedLog = msg;
            },
          );

          remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
            throw const CursorTooOldException(
              message: 'Retention expired at sequence 42',
              oldestAvailableSequence: 42,
            );
          };

          await customEngine.pull();

          expect(customEngine.state.status, equals(SyncEngineStatus.failed));
          expect(customEngine.state.lastError, startsWith('CURSOR_TOO_OLD:'));
          expect(customEngine.state.lastError, contains('Retention expired at sequence 42'));
          expect(capturedLog, contains('CURSOR_TOO_OLD encountered during pull'));
        },
      );

      test(
        '2. Expected offline/connectivity condition leaves state unchanged without marking engine as failed',
        () async {
          String? capturedLog;
          final customEngine = SyncEngine(
            syncOperationsDao: syncOperationsDao,
            remoteApiDispatcher: dispatcher,
            networkInfo: networkInfo,
            retryPolicy: retryPolicy,
            errorClassifier: errorClassifier,
            syncRemoteDataSource: remoteDataSource,
            remoteChangeApplier: remoteChangeApplier,
            syncStateDao: syncStateDao,
            realtimeAdapter: realtimeAdapter,
            clock: () => fixedTime,
            logHandler: (msg, [err, stack]) {
              capturedLog = msg;
            },
          );

          networkInfo.setConnected(false);

          await customEngine.pull();

          expect(customEngine.state.status, equals(SyncEngineStatus.idle));
          expect(customEngine.state.lastError, isNull);
          expect(remoteDataSource.getChangesCallCount, equals(0));
          expect(capturedLog, isNull);
        },
      );

      test(
        '3. Unexpected pull exception (ServerException) is not swallowed, logs error, and updates state to failed',
        () async {
          String? capturedLog;
          Object? capturedError;
          final customEngine = SyncEngine(
            syncOperationsDao: syncOperationsDao,
            remoteApiDispatcher: dispatcher,
            networkInfo: networkInfo,
            retryPolicy: retryPolicy,
            errorClassifier: errorClassifier,
            syncRemoteDataSource: remoteDataSource,
            remoteChangeApplier: remoteChangeApplier,
            syncStateDao: syncStateDao,
            realtimeAdapter: realtimeAdapter,
            clock: () => fixedTime,
            logHandler: (msg, [err, stack]) {
              capturedLog = msg;
              capturedError = err;
            },
          );

          remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
            throw const ServerException('500 Service Unavailable from proxy');
          };

          await customEngine.pull();

          expect(customEngine.state.status, equals(SyncEngineStatus.failed));
          expect(customEngine.state.lastError, startsWith('PULL_ERROR: [ServerException]'));
          expect(customEngine.state.lastError, contains('500 Service Unavailable from proxy'));
          expect(capturedLog, contains('Unexpected pull failure'));
          expect(capturedError, isA<ServerException>());
        },
      );

      test(
        '4. Pull state remains internally consistent after unexpected failure: cursor not advanced, unapplied changes rolled back, pending ops preserved, zero outgoing sync ops',
        () async {
          // Set initial cursor to 10
          await syncStateDao.updateLastAppliedSequence(10);
          expect(await syncStateDao.getLastAppliedSequence(), equals(10));

          // Enqueue a local pending business operation
          await syncOperationsDao.recordOperation(
            entityType: 'customer',
            entityId: 'cust-local-preserve',
            operationType: 'create',
            payload: '{"name":"Local Preserved Cust"}',
          );
          final initialOps = await syncOperationsDao.getEligibleOperations(asOf: fixedTime);
          expect(initialOps.length, equals(1));

          // Remote throws unexpected exception during getChanges
          remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
            throw Exception('Database connection dropped unexpectedly');
          };

          await syncEngine.pull();

          // 1. Cursor did not advance
          expect(await syncStateDao.getLastAppliedSequence(), equals(10));

          // 2. State is failed
          expect(syncEngine.state.status, equals(SyncEngineStatus.failed));
          expect(syncEngine.state.lastError, contains('PULL_ERROR: Exception: Database connection dropped unexpectedly'));

          // 3. Pending operations count is preserved
          expect(syncEngine.state.pendingOperationsCount, equals(1));

          // 4. Pending local operation is untouched and still pending
          final remainingOps = await syncOperationsDao.getEligibleOperations(asOf: fixedTime);
          expect(remainingOps.length, equals(1));
          expect(remainingOps.first.entityId, equals('cust-local-preserve'));
          expect(remainingOps.first.status, equals('pending'));

          // 5. Zero outgoing SyncOperations were created
          final allOps = await db.select(db.syncOperations).get();
          expect(allOps.length, equals(1));
        },
      );

      test(
        '5. Unexpected DioException (HTTP 502) during pull formats status details and updates state to failed',
        () async {
          String? capturedLog;
          final customEngine = SyncEngine(
            syncOperationsDao: syncOperationsDao,
            remoteApiDispatcher: dispatcher,
            networkInfo: networkInfo,
            retryPolicy: retryPolicy,
            errorClassifier: errorClassifier,
            syncRemoteDataSource: remoteDataSource,
            remoteChangeApplier: remoteChangeApplier,
            syncStateDao: syncStateDao,
            realtimeAdapter: realtimeAdapter,
            clock: () => fixedTime,
            logHandler: (msg, [err, stack]) {
              capturedLog = msg;
            },
          );

          remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/sync/changes'),
              response: Response(
                requestOptions: RequestOptions(path: '/sync/changes'),
                statusCode: 502,
                statusMessage: 'Bad Gateway',
              ),
              type: DioExceptionType.badResponse,
              message: 'Bad Gateway',
            );
          };

          await customEngine.pull();

          expect(customEngine.state.status, equals(SyncEngineStatus.failed));
          expect(customEngine.state.lastError, startsWith('PULL_ERROR: DioException (HTTP 502): Bad Gateway'));
          expect(capturedLog, contains('Unexpected pull failure'));
        },
      );
    });
  });
}
