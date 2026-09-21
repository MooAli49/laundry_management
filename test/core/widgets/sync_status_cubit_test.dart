import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/core/widgets/sync_status_cubit.dart';
import 'package:laundry_management/core/widgets/sync_status_state.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => isConnectedValue;

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void emitConnectivity(bool connected) {
    isConnectedValue = connected;
    _connectivityController.add(connected);
  }

  void dispose() {
    _connectivityController.close();
  }
}

class FakeSyncEngine implements SyncEngine {
  SyncEngineState _state = const SyncEngineState.idle();
  final StreamController<SyncEngineState> _stateController =
      StreamController<SyncEngineState>.broadcast();
  bool _isSyncing = false;

  @override
  SyncEngineState get state => _state;

  @override
  Stream<SyncEngineState> get stateStream => _stateController.stream;

  @override
  bool get isSyncing => _isSyncing;

  void emitState(SyncEngineState newState, {bool? isSyncing}) {
    _state = newState;
    if (isSyncing != null) {
      _isSyncing = isSyncing;
    }
    _stateController.add(newState);
  }

  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    _stateController.add(_state);
  }

  @override
  void dispose() {
    _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeNetworkInfo networkInfo;
  late FakeSyncEngine syncEngine;
  late SyncStatusCubit cubit;

  final fixedTimestamp = DateTime.utc(2026, 9, 21, 12, 0, 0);

  setUp(() {
    networkInfo = FakeNetworkInfo();
    syncEngine = FakeSyncEngine();
  });

  tearDown(() async {
    await cubit.close();
    networkInfo.dispose();
    syncEngine.dispose();
  });

  group('SyncStatusCubit Tests', () {
    group('A. Startup', () {
      test(
        '1. no last successful sync + network available -> SYNCING (never CONNECTED)',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(const SyncEngineState.idle(lastSyncTime: null));

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );

          // Allow async _init to complete
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.syncing));
          expect(cubit.state.label, equals('جاري المزامنة'));
          expect(cubit.state.isConnected, isFalse);
        },
      );

      test(
        '2. no last successful sync + network unavailable -> OFFLINE',
        () async {
          networkInfo.isConnectedValue = false;
          syncEngine.emitState(const SyncEngineState.idle(lastSyncTime: null));

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );

          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.offline));
          expect(cubit.state.label, equals('غير متصل'));
          expect(cubit.state.isOffline, isTrue);
        },
      );
    });

    group('B. Healthy & Connected', () {
      test(
        'successful sync completed + network available -> CONNECTED',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.completed(
              lastSyncTime: fixedTimestamp,
            ),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );

          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.connected));
          expect(cubit.state.label, equals('متصل'));
          expect(cubit.state.lastSyncTime, equals(fixedTimestamp));
          expect(cubit.state.isConnected, isTrue);
        },
      );
    });

    group('C. Sync Lifecycle Transitions', () {
      test(
        'healthy -> sync starts (SYNCING) -> sync completes (CONNECTED)',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.connected));

          // 1. Sync starts
          syncEngine.emitState(
            SyncEngineState.syncing(lastSyncTime: fixedTimestamp),
            isSyncing: true,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.syncing));
          expect(cubit.state.label, equals('جاري المزامنة'));

          // 2. Sync completes with new timestamp
          final newTimestamp = fixedTimestamp.add(const Duration(minutes: 5));
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: newTimestamp),
            isSyncing: false,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.connected));
          expect(cubit.state.label, equals('متصل'));
          expect(cubit.state.lastSyncTime, equals(newTimestamp));
        },
      );
    });

    group('D. Network Connectivity Changes', () {
      test(
        'connected -> network loss (OFFLINE) -> network recovery + sync (CONNECTED)',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.connected));

          // 1. Network drops
          networkInfo.emitConnectivity(false);
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.offline));
          expect(cubit.state.label, equals('غير متصل'));
          expect(cubit.state.isOffline, isTrue);

          // 2. Network recovers
          networkInfo.emitConnectivity(true);
          // SyncEngine starts sync on recovery
          syncEngine.emitState(
            SyncEngineState.syncing(lastSyncTime: fixedTimestamp),
            isSyncing: true,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.syncing));

          // 3. Sync finishes
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
            isSyncing: false,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.connected));
        },
      );

      test(
        'never displays CONNECTED when NetworkInfo reports offline even if lastSyncTime is valid',
        () async {
          networkInfo.isConnectedValue = false;
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.offline));
          expect(cubit.state.isConnected, isFalse);
        },
      );
    });

    group('E. Error Handling & Classification', () {
      test(
        'transport/network timeout failure -> OFFLINE',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();

          // Sync fails due to timeout
          syncEngine.emitState(
            SyncEngineState.failed(
              error: 'Request timeout',
              lastSyncTime: fixedTimestamp,
              errorDetails: const SyncErrorDetails.network(
                SyncNetworkErrorType.timeout,
                message: 'Request timeout',
              ),
            ),
            isSyncing: false,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.offline));
          expect(cubit.state.label, equals('غير متصل'));
        },
      );

      test(
        'backend/server/application sync error -> SYNC_ERROR',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: fixedTimestamp),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();

          // Sync fails with HTTP 500
          syncEngine.emitState(
            SyncEngineState.failed(
              error: 'HTTP 500 Internal Server Error',
              lastSyncTime: fixedTimestamp,
              errorDetails: const SyncErrorDetails.http(
                500,
                message: 'Internal Server Error',
              ),
            ),
            isSyncing: false,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.syncError));
          expect(cubit.state.label, equals('فشل المزامنة'));
          expect(cubit.state.errorMessage, contains('HTTP 500'));
        },
      );

      test(
        'old successful lastSyncTime does NOT mask a current unresolved sync error',
        () async {
          networkInfo.isConnectedValue = true;
          // Engine has an old lastSyncTime, but status is failed!
          syncEngine.emitState(
            SyncEngineState.failed(
              error: 'CURSOR_TOO_OLD: sequence expired',
              lastSyncTime: fixedTimestamp,
              errorDetails: const SyncErrorDetails(
                statusCode: 410,
                message: 'CURSOR_TOO_OLD',
              ),
            ),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.syncError));
          expect(cubit.state.isConnected, isFalse);
        },
      );
    });

    group('F. Recovery from Error', () {
      test(
        'SYNC_ERROR + successful later sync -> CONNECTED',
        () async {
          networkInfo.isConnectedValue = true;
          syncEngine.emitState(
            SyncEngineState.failed(
              error: 'Server error',
              lastSyncTime: fixedTimestamp,
              errorDetails: const SyncErrorDetails.http(500),
            ),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.syncError));

          // Next sync attempt begins
          syncEngine.emitState(
            SyncEngineState.syncing(lastSyncTime: fixedTimestamp),
            isSyncing: true,
          );
          await pumpEventQueue();
          expect(cubit.state.status, equals(SyncStatus.syncing));

          // Sync succeeds
          final recoveredTime = fixedTimestamp.add(const Duration(hours: 1));
          syncEngine.emitState(
            SyncEngineState.completed(lastSyncTime: recoveredTime),
            isSyncing: false,
          );
          await pumpEventQueue();

          expect(cubit.state.status, equals(SyncStatus.connected));
          expect(cubit.state.label, equals('متصل'));
          expect(cubit.state.lastSyncTime, equals(recoveredTime));
        },
      );
    });

    group('G. Offline-First Non-blocking Invariant', () {
      test(
        'offline state preserves clean contract without throwing or blocking',
        () async {
          networkInfo.isConnectedValue = false;
          syncEngine.emitState(
            const SyncEngineState.idle(lastSyncTime: null),
          );

          cubit = SyncStatusCubit(
            syncEngine: syncEngine,
            networkInfo: networkInfo,
          );
          await pumpEventQueue();

          expect(cubit.state.isOffline, isTrue);
          // State is purely informational and does not hold blocking error states
          expect(cubit.state.label, equals('غير متصل'));
        },
      );
    });
  });
}
