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

        // Use short 30ms interval for testing
        await syncEngine.initialize(
          triggerInitialSync: false,
          periodicSyncInterval: const Duration(milliseconds: 30),
        );

        expect(dispatcher.dispatchedOperations, isEmpty);

        // Wait for first timer tick
        await Future<void>.delayed(const Duration(milliseconds: 45));
        expect(dispatcher.dispatchedOperations.length, equals(1));

        // Enqueue a second operation
        await dao.recordOperation(
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        // Wait for second timer tick
        await Future<void>.delayed(const Duration(milliseconds: 45));
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

        // Simulate application transitioning to resumed state
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
  });
}
