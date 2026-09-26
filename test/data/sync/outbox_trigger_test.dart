import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => isConnectedValue;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool connected) {
    isConnectedValue = connected;
    _controller.add(connected);
  }

  void dispose() {
    _controller.close();
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
    fakeNow = DateTime(2026, 9, 21, 18, 0, 0);

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
    networkInfo.dispose();
    await db.close();
  });

  group('Central Reactive Outbox Trigger Tests', () {
    test(
      'TEST 1 — New local operation triggers sync promptly after commit',
      () async {
        // Initialize with triggerInitialSync: false to verify outbox is the trigger
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Commit a new pending sync operation
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-101',
          operationType: 'create',
          payload: '{"order_number": "26-101"}',
        );

        // Allow microtasks / Drift stream query to emit and syncEngine to run
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(
          dispatcher.dispatchedOperations.first.entityId,
          equals('ord-101'),
        );
        expect(
          dispatcher.dispatchedOperations.first.entityType,
          equals('order'),
        );

        // Operation is marked synced, outbox is clean
        final pending = await dao.getPendingOperations();
        expect(pending, isEmpty);
      },
    );

    test(
      'TEST 2 — No parallel sync: rapid mutations coalesce into trailing pass',
      () async {
        final completer = Completer<void>();

        // Delay the first dispatch so sync remains in-flight while the second mutation arrives
        dispatcher.onDispatch = (op) async {
          if (op.entityId == 'ord-first') {
            await completer.future;
          }
          return {'status': 'ok'};
        };

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Record first operation -> triggers sync()
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-first',
          operationType: 'create',
        );

        // Wait until syncEngine picks up ord-first and begins dispatching
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(syncEngine.isSyncing, isTrue);
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(
          dispatcher.dispatchedOperations.first.entityId,
          equals('ord-first'),
        );

        // While ord-first is still in-flight, commit a second operation
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-second',
          operationType: 'create',
        );

        // Allow Drift to emit stream event; coalescing guard must prevent parallel sync
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // Still only ord-first was dispatched because first pass is still running
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // Now complete the first dispatch
        completer.complete();

        // Allow the trailing pass to execute
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Both operations were dispatched sequentially without parallel execution
        expect(dispatcher.dispatchedOperations.length, equals(2));
        expect(
          dispatcher.dispatchedOperations[0].entityId,
          equals('ord-first'),
        );
        expect(
          dispatcher.dispatchedOperations[1].entityId,
          equals('ord-second'),
        );
        expect(syncEngine.isSyncing, isFalse);
      },
    );

    test(
      'TEST 3 — Multi-entity generality: works for all operation types (order, customer, payment, expense)',
      () async {
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Record customer
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'cust-1',
          operationType: 'create',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(
          dispatcher.dispatchedOperations.last.entityType,
          equals('customer'),
        );

        // Record payment
        await dao.recordOperation(
          entityType: 'payment',
          entityId: 'pay-1',
          operationType: 'create',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(dispatcher.dispatchedOperations.length, equals(2));
        expect(
          dispatcher.dispatchedOperations.last.entityType,
          equals('payment'),
        );

        // Record expense
        await dao.recordOperation(
          entityType: 'expense',
          entityId: 'exp-1',
          operationType: 'create',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(dispatcher.dispatchedOperations.length, equals(3));
        expect(
          dispatcher.dispatchedOperations.last.entityType,
          equals('expense'),
        );
      },
    );

    test(
      'TEST 4 — Transaction boundary: rollback does NOT trigger sync',
      () async {
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Attempt a transaction that rolls back
        try {
          await db.transaction(() async {
            await dao.recordOperation(
              entityType: 'order',
              entityId: 'ord-rollback',
              operationType: 'create',
            );
            // Simulate validation or constraint failure inside the transaction
            throw Exception('Transaction failed, rolling back');
          });
        } catch (_) {}

        // Allow microtasks to settle
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // No sync was triggered because transaction rolled back
        expect(dispatcher.dispatchedOperations, isEmpty);

        final pending = await dao.getPendingOperations();
        expect(pending, isEmpty);
      },
    );

    test(
      'TEST 5 — Race condition: mutation committed immediately after initialize() triggers sync',
      () async {
        // Initialize and immediately record operation without awaiting any delay
        final initFuture = syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-immediate',
          operationType: 'create',
        );

        await initFuture;

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(
          dispatcher.dispatchedOperations.first.entityId,
          equals('ord-immediate'),
        );
      },
    );

    test(
      'TEST 6 — Status transitions: mark synced does NOT loop, but transition back to pending re-triggers sync',
      () async {
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Record operation and let it sync
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-transition',
          operationType: 'create',
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // After mark synced, no extra sync is triggered (dispatchedOperations remains 1)
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // Simulate retry logic or admin action resetting an operation back to pending
        await (db.update(db.syncOperations)
              ..where((t) => t.entityId.equals('ord-transition')))
            .write(const SyncOperationsCompanion(status: Value('pending')));

        // Transition back to pending is detected as newly pending
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(dispatcher.dispatchedOperations.length, equals(2));
      },
    );
  });
}
