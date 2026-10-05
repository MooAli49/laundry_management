import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;
  final List<bool> connectivitySequence = [];
  Future<bool> Function()? onCheckConnectivity;

  @override
  Future<bool> get isConnected async {
    if (onCheckConnectivity != null) {
      return await onCheckConnectivity!();
    }
    if (connectivitySequence.isNotEmpty) {
      return connectivitySequence.removeAt(0);
    }
    return isConnectedValue;
  }

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isConnectedValue);
}

class FakeRemoteApiDispatcher implements RemoteApiDispatcher {
  final List<SyncOperation> dispatchedOperations = [];
  Object? Function(SyncOperation op)? onDispatch;

  @override
  Future<dynamic> dispatch(SyncOperation operation) async {
    dispatchedOperations.add(operation);
    if (onDispatch != null) {
      final result = onDispatch!(operation);
      if (result != null && (result is Exception || result is Error)) {
        throw result;
      }
      return result;
    }
    return {'status': 'ok'};
  }
}

void main() {
  late AppDatabase db;
  late SyncOperationsDao dao;
  late FakeNetworkInfo networkInfo;
  late FakeRemoteApiDispatcher dispatcher;
  late SyncRetryPolicy retryPolicy;
  late SyncErrorClassifier errorClassifier;
  late SyncEngine syncEngine;
  late DateTime fakeNow;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = SyncOperationsDao(db);
    networkInfo = FakeNetworkInfo();
    dispatcher = FakeRemoteApiDispatcher();
    retryPolicy = SyncRetryPolicy(
      initialDelay: const Duration(seconds: 5),
      multiplier: 2.0,
      maxDelay: const Duration(seconds: 300),
      maxRetries: 5,
      jitterGenerator: () => Duration.zero,
    );
    errorClassifier = const SyncErrorClassifier();
    fakeNow = DateTime(2026, 9, 15, 10, 0, 0);

    syncEngine = SyncEngine(
      syncOperationsDao: dao,
      remoteApiDispatcher: dispatcher,
      networkInfo: networkInfo,
      retryPolicy: retryPolicy,
      errorClassifier: errorClassifier,
      clock: () => fakeNow,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  group('SyncEngine Unit & Orchestration Tests', () {
    test(
      '1. Offline before sync: no operations dispatched, queue unchanged',
      () async {
        networkInfo.isConnectedValue = false;

        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.idle));
        expect(state.pendingOperationsCount, equals(1));
        expect(dispatcher.dispatchedOperations, isEmpty);

        final pending = await dao.getPendingOperations();
        expect(pending.length, equals(1));
        expect(pending.first.status, equals('pending'));
      },
    );

    test('2. Empty queue: completes cleanly with zero remote calls', () async {
      networkInfo.isConnectedValue = true;

      final state = await syncEngine.sync();

      expect(state.status, equals(SyncEngineStatus.completed));
      expect(state.pendingOperationsCount, equals(0));
      expect(dispatcher.dispatchedOperations, isEmpty);
      expect(state.lastSyncTime, equals(fakeNow));
    });

    test(
      '3. Successful operation: dispatcher called once, marked synced, retry metadata cleared',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.completed));
        expect(state.pendingOperationsCount, equals(0));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));

        final rows = await (db.select(db.syncOperations)).get();
        expect(rows.length, equals(1));
        expect(rows.first.status, equals('synced'));
        expect(rows.first.nextRetryAt, isNull);
      },
    );

    test(
      '4. Retryable HTTP 500 failure: schedules backoff, persists retry metadata, not permanently failed',
      () async {
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        dispatcher.onDispatch = (op) {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/v1/orders'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/orders'),
              statusCode: 500,
            ),
            message: 'Internal Server Error',
          );
        };

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, contains('Internal Server Error'));

        final rows = await (db.select(db.syncOperations)).get();
        expect(rows.length, equals(1));
        final op = rows.first;
        expect(op.status, equals('failed'));
        expect(op.retryCount, equals(1));
        expect(op.nextRetryAt, equals(fakeNow.add(const Duration(seconds: 5))));
        expect(op.lastError, contains('Internal Server Error'));
      },
    );

    test(
      '5. Permanent HTTP 400 failure: marked failed with no retry scheduled',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        dispatcher.onDispatch = (op) {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/v1/customers'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/customers'),
              statusCode: 400,
            ),
            message: 'Bad Request: Invalid phone',
          );
        };

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, contains('Bad Request'));

        final rows = await (db.select(db.syncOperations)).get();
        expect(rows.length, equals(1));
        final op = rows.first;
        expect(op.status, equals('failed'));
        expect(op.retryCount, equals(1));
        expect(op.nextRetryAt, isNull); // Permanent failure has no future retry
      },
    );

    test(
      '6. Retry limit exhausted: permanently fails after max retries exceeded',
      () async {
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        // Set retryCount to 5 (maxRetries reached)
        await (db.update(db.syncOperations)).write(
          const SyncOperationsCompanion(
            retryCount: Value(5),
            status: Value('pending'),
          ),
        );

        dispatcher.onDispatch = (op) {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/v1/orders'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/orders'),
              statusCode: 503,
            ),
            message: 'Service Unavailable',
          );
        };

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, contains('Retry limit exhausted'));

        final rows = await (db.select(db.syncOperations)).get();
        final op = rows.first;
        expect(op.status, equals('failed'));
        expect(op.retryCount, equals(6));
        expect(op.nextRetryAt, isNull);
      },
    );

    test(
      '7. Future next_retry_at: operation is not dispatched before eligible',
      () async {
        final futureRetry = fakeNow.add(const Duration(minutes: 5));
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-future',
          operationType: 'create',
          nextRetryAt: futureRetry,
        );

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.completed));
        expect(dispatcher.dispatchedOperations, isEmpty);

        // Fast forward time past nextRetryAt
        fakeNow = futureRetry.add(const Duration(seconds: 1));
        final stateAfter = await syncEngine.sync();

        expect(stateAfter.status, equals(SyncEngineStatus.completed));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(
          dispatcher.dispatchedOperations.first.entityId,
          equals('c-future'),
        );
      },
    );

    test(
      '8. Multiple operations: processed in deterministic DAO order (createdAt ASC)',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );
        // Ensure distinct createdAt
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        await dao.recordOperation(
          entityType: 'payment',
          entityId: 'p-1',
          operationType: 'create',
        );

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.completed));
        expect(dispatcher.dispatchedOperations.length, equals(3));
        expect(dispatcher.dispatchedOperations[0].entityId, equals('c-1'));
        expect(dispatcher.dispatchedOperations[1].entityId, equals('ord-1'));
        expect(dispatcher.dispatchedOperations[2].entityId, equals('p-1'));
      },
    );

    test(
      '9. First operation failure stops queue processing to preserve dependency ordering',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        // Customer fails
        dispatcher.onDispatch = (op) {
          if (op.entityId == 'c-1') {
            throw DioException(
              requestOptions: RequestOptions(path: '/api/v1/customers'),
              response: Response(
                requestOptions: RequestOptions(path: '/api/v1/customers'),
                statusCode: 500,
              ),
              message: 'DB error',
            );
          }
          return {'status': 'ok'};
        };

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        // Order was NOT dispatched because customer failed
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));

        final orderRow = await (db.select(
          db.syncOperations,
        )..where((t) => t.entityId.equals('ord-1'))).getSingle();
        expect(orderRow.status, equals('pending'));
      },
    );

    test(
      '10. Connectivity loss mid-processing stops safely and preserves unconfirmed operation',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        // Initial check is true, but mid-loop check for order becomes false
        networkInfo.connectivitySequence.addAll([
          true, // initial sync() check
          true, // before customer
          false, // before order
        ]);

        final state = await syncEngine.sync();

        expect(state.pendingOperationsCount, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));

        final customerRow = await (db.select(
          db.syncOperations,
        )..where((t) => t.entityId.equals('c-1'))).getSingle();
        expect(customerRow.status, equals('synced'));

        final orderRow = await (db.select(
          db.syncOperations,
        )..where((t) => t.entityId.equals('ord-1'))).getSingle();
        expect(orderRow.status, equals('pending'));
      },
    );

    test(
      '11. Concurrent sync() calls: only one execution runs at a time',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        dispatcher.onDispatch = (op) async {
          // While this is running, invoke sync() again
          final secondState = await syncEngine.sync();
          expect(secondState.status, equals(SyncEngineStatus.syncing));
          return {'status': 'ok'};
        };

        final finalState = await syncEngine.sync();
        expect(finalState.status, equals(SyncEngineStatus.completed));
        expect(dispatcher.dispatchedOperations.length, equals(1));
      },
    );

    test(
      '12. State transitions: emits idle -> syncing -> completed / failed',
      () async {
        final states = <SyncEngineStatus>[];
        final sub = syncEngine.stateStream.listen((s) => states.add(s.status));

        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.sync();
        await Future<void>.delayed(Duration.zero);

        expect(
          states,
          containsAllInOrder([
            SyncEngineStatus.syncing,
            SyncEngineStatus.completed,
          ]),
        );

        await sub.cancel();
      },
    );

    test(
      '13. Unexpected exception: handled safely without crashing engine',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        dispatcher.onDispatch = (op) {
          throw StateError('Unexpected runtime memory defect');
        };

        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, contains('Unexpected runtime memory defect'));

        final rows = await (db.select(db.syncOperations)).get();
        expect(rows.first.status, equals('failed'));
      },
    );

    test(
      '14. Operation ID preservation: dispatcher receives exact existing SyncOperation.id',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final originalOp = (await dao.getPendingOperations()).first;

        await syncEngine.sync();

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.id, equals(originalOp.id));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));
      },
    );

    test(
      '15. Pre-first-await concurrency race window: concurrent call during initial connectivity check is rejected',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final connectivityCompleter = Completer<bool>();
        var connectivityCheckCount = 0;

        networkInfo.onCheckConnectivity = () {
          connectivityCheckCount++;
          if (connectivityCheckCount == 1) {
            return connectivityCompleter.future;
          }
          return Future.value(true);
        };

        // 1. Start sync() call #1
        final syncFuture1 = syncEngine.sync();

        // Allow call #1 to run up to the suspended connectivity check
        await Future<void>.delayed(Duration.zero);
        expect(connectivityCheckCount, equals(1));
        expect(syncEngine.isSyncing, isTrue);

        // 2 & 3. While call #1 is suspended before connectivity returns, call sync() #2
        final state2 = await syncEngine.sync();

        // 4. Verify call #2 does NOT start another sync cycle and returns the current syncing state
        expect(state2.status, equals(SyncEngineStatus.syncing));
        expect(dispatcher.dispatchedOperations, isEmpty);

        // 5. Resume call #1
        connectivityCompleter.complete(true);
        final state1 = await syncFuture1;

        // 6. Verify only one queue processing cycle occurred
        // 7. Verify the operation was dispatched exactly once
        // 8. Verify final state is completed
        expect(state1.status, equals(SyncEngineStatus.completed));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));
        expect(syncEngine.isSyncing, isFalse);

        final customerRow = await (db.select(
          db.syncOperations,
        )..where((t) => t.entityId.equals('c-1'))).getSingle();
        expect(customerRow.status, equals('synced'));
      },
    );
  });
}
