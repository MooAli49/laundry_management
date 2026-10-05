import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/main.dart';

class FakeStreamNetworkInfo implements NetworkInfo {
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

  void emitError(Object error) {
    _controller.addError(error);
  }

  void dispose() {
    _controller.close();
  }
}

class FakeStreamDispatcher implements RemoteApiDispatcher {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Sync Infrastructure DI & Lifecycle Tests', () {
    late AppDatabase db;
    late SyncOperationsDao dao;
    late FakeStreamNetworkInfo networkInfo;
    late FakeStreamDispatcher dispatcher;
    late SyncRetryPolicy retryPolicy;
    late SyncErrorClassifier errorClassifier;
    late SyncEngine syncEngine;

    setUp(() async {
      await GetIt.instance.reset();

      db = AppDatabase(NativeDatabase.memory());
      dao = SyncOperationsDao(db);
      networkInfo = FakeStreamNetworkInfo();
      dispatcher = FakeStreamDispatcher();
      retryPolicy = SyncRetryPolicy(
        initialDelay: const Duration(seconds: 5),
        multiplier: 2.0,
        maxDelay: const Duration(seconds: 300),
        maxRetries: 5,
        jitterGenerator: () => Duration.zero,
      );
      errorClassifier = const SyncErrorClassifier();

      syncEngine = SyncEngine(
        syncOperationsDao: dao,
        remoteApiDispatcher: dispatcher,
        networkInfo: networkInfo,
        retryPolicy: retryPolicy,
        errorClassifier: errorClassifier,
      );
    });

    tearDown(() async {
      disposeAppLifecycleSync();
      syncEngine.dispose();
      networkInfo.dispose();
      await db.close();
      await GetIt.instance.reset();
    });

    test(
      '1. DI Graph Resolution: resolves all 13 sync infrastructure components as singletons',
      () async {
        await initDependencies();

        // 1. Core Network
        expect(GetIt.instance.isRegistered<NetworkInfo>(), isTrue);
        expect(GetIt.instance.isRegistered<DioClient>(), isTrue);
        expect(GetIt.instance.isRegistered<Dio>(), isTrue);

        // 2. Remote APIs
        expect(GetIt.instance.isRegistered<CustomerRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<OrderRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<PaymentRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<StorageRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<ExpenseRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<MasterDataRemoteApi>(), isTrue);

        // 3. Dispatcher
        expect(GetIt.instance.isRegistered<RemoteApiDispatcher>(), isTrue);

        // 4. Domain Sync Policies & Engine
        expect(GetIt.instance.isRegistered<SyncRetryPolicy>(), isTrue);
        expect(GetIt.instance.isRegistered<SyncErrorClassifier>(), isTrue);
        expect(GetIt.instance.isRegistered<SyncEngine>(), isTrue);

        // Singleton identity check
        final engine1 = GetIt.instance<SyncEngine>();
        final engine2 = GetIt.instance<SyncEngine>();
        expect(identical(engine1, engine2), isTrue);

        final dispatcher1 = GetIt.instance<RemoteApiDispatcher>();
        final dispatcher2 = GetIt.instance<RemoteApiDispatcher>();
        expect(identical(dispatcher1, dispatcher2), isTrue);

        final netInfo1 = GetIt.instance<NetworkInfo>();
        final netInfo2 = GetIt.instance<NetworkInfo>();
        expect(identical(netInfo1, netInfo2), isTrue);

        final retry1 = GetIt.instance<SyncRetryPolicy>();
        final retry2 = GetIt.instance<SyncRetryPolicy>();
        expect(identical(retry1, retry2), isTrue);

        final classifier1 = GetIt.instance<SyncErrorClassifier>();
        final classifier2 = GetIt.instance<SyncErrorClassifier>();
        expect(identical(classifier1, classifier2), isTrue);
      },
    );

    test(
      '2. Initialization: subscribes to connectivity, sets isInitialized, non-blocking startup',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        expect(syncEngine.isInitialized, isFalse);

        // Call initialize with non-blocking initial sync
        final initFuture = syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );

        // initialize() returns immediately without waiting for sync completion
        await initFuture;
        expect(syncEngine.isInitialized, isTrue);

        // Allow microtasks to complete the asynchronous sync
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '3. Connectivity TRUE: onConnectivityChanged(true) triggers sync and processes queue',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Emit connectivity restored
        networkInfo.emit(true);

        // Allow event loop to process stream event and sync
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '4. Connectivity FALSE: onConnectivityChanged(false) does NOT trigger sync',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Emit connectivity loss
        networkInfo.emit(false);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Queue remains pending, nothing dispatched
        expect(dispatcher.dispatchedOperations, isEmpty);
        final pending = await dao.getPendingOperations();
        expect(pending.length, equals(1));
        expect(pending.first.status, equals('pending'));
      },
    );

    test(
      '5. Rapid connectivity events: true, true, true safely serialized by concurrency guard',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final dispatchCompleter = Completer<void>();
        var dispatchCount = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCount++;
          await dispatchCompleter.future;
          return {'status': 'ok'};
        };

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Emit multiple rapid connectivity events
        networkInfo.emit(true);
        networkInfo.emit(true);
        networkInfo.emit(true);

        // Allow the first event to start
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(syncEngine.isSyncing, isTrue);

        // Complete the dispatch
        dispatchCompleter.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatchCount, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(syncEngine.isSyncing, isFalse);
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '6. Periodic timer: triggers sync at specified intervals while foregrounded',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final firstDispatchCompleter = Completer<void>();
        Completer<void>? secondDispatchCompleter;

        dispatcher.onDispatch = (op) async {
          if (!firstDispatchCompleter.isCompleted) {
            firstDispatchCompleter.complete();
          } else if (secondDispatchCompleter != null &&
              !secondDispatchCompleter.isCompleted) {
            secondDispatchCompleter.complete();
          }
          return {'status': 'ok'};
        };

        // Use short 20ms interval for testing
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 20),
        );

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Wait deterministically for first timer tick
        await firstDispatchCompleter.future.timeout(const Duration(seconds: 2));
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // Enqueue a second operation
        secondDispatchCompleter = Completer<void>();
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        // Wait deterministically for second timer tick
        await secondDispatchCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(dispatcher.dispatchedOperations.length, equals(2));
        expect(dispatcher.dispatchedOperations[1].entityId, equals('ord-1'));
      },
    );

    test(
      '7. Concurrent startup + connectivity trigger: only one sync execution active',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final blockCompleter = Completer<void>();
        var dispatchCalls = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCalls++;
          await blockCompleter.future;
          return {'status': 'ok'};
        };

        // Start initial sync and emit connectivity at the exact same moment
        final initFuture = syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );
        networkInfo.emit(true);

        await initFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(syncEngine.isSyncing, isTrue);
        expect(dispatchCalls, equals(1));

        // Release the dispatch
        blockCompleter.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatchCalls, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '8. App resume: AppLifecycleListener triggers sync on resume',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        setupAppLifecycleSync(syncEngine);

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Simulate application transitioning from inactive to resumed state
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(dispatcher.dispatchedOperations.first.entityId, equals('c-1'));
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));

        disposeAppLifecycleSync();
      },
    );

    test(
      '9. Disposal: cancels connectivity subscription, timer, and rejects subsequent syncs',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 20),
        );

        // Dispose the engine
        syncEngine.dispose();
        expect(syncEngine.isDisposed, isTrue);

        // Emit connectivity change and wait for timer interval
        networkInfo.emit(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Nothing should be dispatched because engine is disposed
        expect(dispatcher.dispatchedOperations, isEmpty);

        // Calling sync() directly on disposed engine is safe and returns current state
        final state = await syncEngine.sync();
        expect(state.status, equals(SyncEngineStatus.idle));
        expect(dispatcher.dispatchedOperations, isEmpty);
      },
    );

    test(
      '10. Initialization idempotency: multiple initialize() calls do not duplicate listeners or syncs',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        var dispatchCount = 0;
        dispatcher.onDispatch = (op) async {
          dispatchCount++;
          return {'status': 'ok'};
        };

        // Call initialize() twice
        await syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );
        await syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Only one initial sync ran
        expect(dispatchCount, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // Emit connectivity once
        networkInfo.emit(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Operation was already synced, queue is empty now
        expect(dispatchCount, equals(1));
      },
    );

    test(
      '11. Offline startup: initial sync offline leaves queue unchanged, does not throw',
      () async {
        networkInfo.isConnectedValue = false;

        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        // Initial sync runs offline
        await syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Nothing dispatched, state returns to idle
        expect(dispatcher.dispatchedOperations, isEmpty);
        expect(syncEngine.state.status, equals(SyncEngineStatus.idle));
        expect(syncEngine.state.pendingOperationsCount, equals(1));

        final pending = await dao.getPendingOperations();
        expect(pending.length, equals(1));
        expect(pending.first.status, equals('pending'));
      },
    );

    test(
      '12. Optional initial sync: initialize(triggerInitialSync: false) does not sync',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatcher.dispatchedOperations, isEmpty);
        expect(syncEngine.state.status, equals(SyncEngineStatus.idle));
      },
    );

    test(
      '13. Periodic timer disabled: periodicSyncInterval == null starts no timer',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(dispatcher.dispatchedOperations, isEmpty);
        expect(syncEngine.state.status, equals(SyncEngineStatus.idle));
      },
    );

    test(
      '14. Timer tick during active sync: safely bypassed by concurrency guard',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final blockCompleter = Completer<void>();
        final firstDispatchStarted = Completer<void>();
        var dispatchCount = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCount++;
          if (!firstDispatchStarted.isCompleted) {
            firstDispatchStarted.complete();
          }
          await blockCompleter.future;
          return {'status': 'ok'};
        };

        // Short timer of 20ms
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 20),
        );

        // Wait for first timer tick to start sync
        await firstDispatchStarted.future.timeout(const Duration(seconds: 2));
        expect(syncEngine.isSyncing, isTrue);
        expect(dispatchCount, equals(1));

        // Allow multiple timer ticks while dispatch is blocked
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(dispatchCount, equals(1));

        blockCompleter.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(syncEngine.isSyncing, isFalse);
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '15. Repeated dispose(): safe, idempotent, and cancels resources cleanly',
      () async {
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 20),
        );

        expect(syncEngine.isDisposed, isFalse);
        syncEngine.dispose();
        expect(syncEngine.isDisposed, isTrue);

        // Call dispose a second time
        expect(() => syncEngine.dispose(), returnsNormally);
        expect(syncEngine.isDisposed, isTrue);

        // Sync on disposed engine is safe no-op
        final state = await syncEngine.sync();
        expect(state.status, equals(SyncEngineStatus.idle));
      },
    );

    test(
      '16. GetIt disposal: container reset invokes SyncEngine.dispose() callback',
      () async {
        await initDependencies();

        final engine = GetIt.instance<SyncEngine>();
        expect(engine.isDisposed, isFalse);

        await engine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Reset GetIt
        await GetIt.instance.reset();

        // Instance was disposed via registration callback
        expect(engine.isDisposed, isTrue);
      },
    );

    test(
      '17. Startup error safety: unexpected exception during initial sync does not crash bootstrap',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        // Simulate fatal dispatcher failure
        dispatcher.onDispatch = (op) {
          throw StateError('Simulated unexpected dispatcher crash');
        };

        // Initialize with initial sync
        await syncEngine.initialize(
          triggerInitialSync: true,
          periodicSyncInterval: null,
        );

        // Wait for asynchronous initial sync to process error
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State transitioned to failed, no uncaught exception thrown
        expect(syncEngine.state.status, equals(SyncEngineStatus.failed));
        expect(
          syncEngine.state.lastError,
          contains('Simulated unexpected dispatcher crash'),
        );
        expect(syncEngine.isSyncing, isFalse);
      },
    );

    test(
      '18. App lifecycle wiring: repeated setup and dispose are idempotent without leaks',
      () async {
        // Setup lifecycle sync multiple times
        setupAppLifecycleSync(syncEngine);
        setupAppLifecycleSync(syncEngine);

        // Dispose multiple times
        expect(() => disposeAppLifecycleSync(), returnsNormally);
        expect(() => disposeAppLifecycleSync(), returnsNormally);
      },
    );

    test(
      '19. App resume serialization: rapid resume events execute through atomic concurrency guard',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final blockCompleter = Completer<void>();
        var dispatchCount = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCount++;
          await blockCompleter.future;
          return {'status': 'ok'};
        };

        setupAppLifecycleSync(syncEngine);

        // Transition from inactive to resumed to trigger onResume
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(syncEngine.isSyncing, isTrue);
        expect(dispatchCount, equals(1));

        blockCompleter.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatchCount, equals(1));
        expect(syncEngine.isSyncing, isFalse);
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));

        disposeAppLifecycleSync();
      },
    );

    test(
      '20. Timer + connectivity during active sync: single worker guaranteed',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        final blockCompleter = Completer<void>();
        final timerFired = Completer<void>();
        var dispatchCalls = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCalls++;
          if (!timerFired.isCompleted) {
            timerFired.complete();
          }
          await blockCompleter.future;
          return {'status': 'ok'};
        };

        // Initialize with short timer
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 20),
        );

        // Wait for timer to trigger sync
        await timerFired.future.timeout(const Duration(seconds: 2));
        expect(syncEngine.isSyncing, isTrue);
        expect(dispatchCalls, equals(1));

        // While first sync is still blocked, fire connectivity event
        networkInfo.emit(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Still exactly 1 dispatch in progress
        expect(dispatchCalls, equals(1));

        // Unblock dispatch
        blockCompleter.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(dispatchCalls, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        expect(syncEngine.isSyncing, isFalse);
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '21. Disposal during active sync: stops queue processing and does not report completed',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-2',
          operationType: 'create',
        );

        final blockCompleter = Completer<void>();
        var dispatchCalls = 0;

        dispatcher.onDispatch = (op) async {
          dispatchCalls++;
          await blockCompleter.future;
          return {'status': 'ok'};
        };

        // Start sync
        final syncFuture = syncEngine.sync();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(syncEngine.isSyncing, isTrue);
        expect(dispatchCalls, equals(1));

        // Dispose while first operation is still in-flight
        syncEngine.dispose();
        expect(syncEngine.isDisposed, isTrue);

        // Unblock first operation
        blockCompleter.complete();
        final finalState = await syncFuture;

        // Second operation was never dispatched because disposal halted loop
        expect(dispatchCalls, equals(1));
        expect(dispatcher.dispatchedOperations.length, equals(1));
        // Must NOT falsely report completed
        expect(finalState.status, isNot(equals(SyncEngineStatus.completed)));
        expect(syncEngine.isSyncing, isFalse);
      },
    );

    test(
      '22. Double fault safety: DAO failure during exception handling does not escape or crash',
      () async {
        await dao.recordOperation(
          entityType: 'customer',
          entityId: 'c-1',
          operationType: 'create',
        );

        // First fault: dispatcher throws an unexpected exception
        dispatcher.onDispatch = (op) async {
          // Second fault: close database connection so DAO query inside catch fails as well
          await db.close();
          throw StateError('Simulated remote crash');
        };

        // sync() must handle the double-fault defensively without throwing uncaught exception
        final state = await syncEngine.sync();

        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, isNotNull);
        expect(syncEngine.isSyncing, isFalse);
      },
    );

    test(
      '23. Connectivity stream error: platform stream error is caught safely without crashing',
      () async {
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: null,
        );

        // Emit an error on the connectivity stream
        expect(
          () => networkInfo.emitError(Exception('Platform stream failed')),
          returnsNormally,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Engine remains healthy and operational
        expect(syncEngine.isDisposed, isFalse);
        expect(syncEngine.state.status, equals(SyncEngineStatus.idle));
      },
    );
  });
}
