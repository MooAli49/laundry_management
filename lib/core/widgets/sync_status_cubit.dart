import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync/sync_engine.dart';
import '../../domain/sync/sync_engine_state.dart';
import '../network/network_info.dart';
import 'sync_status_state.dart';

/// Cubit managing dynamic connection and synchronization status.
///
/// Follows deterministic state precedence:
/// 1. Offline: Network interface disconnected or transport/timeout failure.
/// 2. Syncing: Active sync cycle or startup initial sync in progress.
/// 3. Sync Error: Unresolved backend/application/server sync failure while network is connected.
/// 4. Startup Pending: No successful sync yet, network connected -> Syncing.
/// 5. Connected: Successful sync completed, network connected, no unresolved error.
class SyncStatusCubit extends Cubit<SyncStatusState> {
  final SyncEngine _syncEngine;
  final NetworkInfo _networkInfo;

  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<SyncEngineState>? _syncEngineSubscription;

  bool _isNetworkConnected = true;

  SyncStatusCubit({
    required SyncEngine syncEngine,
    required NetworkInfo networkInfo,
  }) : _syncEngine = syncEngine,
       _networkInfo = networkInfo,
       super(
         _computeInitialState(syncEngine.state, syncEngine.isSyncing),
       ) {
    _init();
  }

  static SyncStatusState _computeInitialState(
    SyncEngineState engineState,
    bool isSyncing,
  ) {
    // Before the first network check resolves, if no sync has completed yet,
    // default to syncing (initial startup check) to never show connected falsely.
    if (isSyncing || engineState.status == SyncEngineStatus.syncing) {
      return SyncStatusState.syncing(lastSyncTime: engineState.lastSyncTime);
    }
    if (engineState.status == SyncEngineStatus.failed) {
      if (_isNetworkTransportFailure(engineState)) {
        return SyncStatusState.offline(
          lastSyncTime: engineState.lastSyncTime,
          errorMessage: engineState.lastError,
        );
      }
      return SyncStatusState.syncError(
        lastSyncTime: engineState.lastSyncTime,
        errorMessage: engineState.lastError,
      );
    }
    if (engineState.lastSyncTime == null) {
      return const SyncStatusState.syncing();
    }
    return SyncStatusState.connected(lastSyncTime: engineState.lastSyncTime);
  }

  Future<void> _init() async {
    try {
      _isNetworkConnected = await _networkInfo.isConnected;
    } catch (_) {
      _isNetworkConnected = false;
    }

    _recomputeStatus();

    _networkSubscription = _networkInfo.onConnectivityChanged.listen(
      (connected) {
        _isNetworkConnected = connected;
        _recomputeStatus();
      },
      onError: (_) {
        _isNetworkConnected = false;
        _recomputeStatus();
      },
    );

    _syncEngineSubscription = _syncEngine.stateStream.listen(
      (_) {
        _recomputeStatus();
      },
      onError: (_) {},
    );
  }

  void _recomputeStatus() {
    if (isClosed) return;

    final engineState = _syncEngine.state;
    final isSyncing = _syncEngine.isSyncing;

    // 1. OFFLINE: Network transport is unavailable
    if (!_isNetworkConnected) {
      emit(
        SyncStatusState.offline(
          lastSyncTime: engineState.lastSyncTime,
          errorMessage: engineState.lastError,
        ),
      );
      return;
    }

    // 2. SYNCING: SyncEngine is actively syncing
    if (isSyncing || engineState.status == SyncEngineStatus.syncing) {
      emit(
        SyncStatusState.syncing(
          lastSyncTime: engineState.lastSyncTime,
        ),
      );
      return;
    }

    // 3. SYNC_ERROR vs OFFLINE (on sync failure):
    // Do not let an old lastSyncTime mask an unresolved sync failure!
    if (engineState.status == SyncEngineStatus.failed) {
      if (_isNetworkTransportFailure(engineState)) {
        emit(
          SyncStatusState.offline(
            lastSyncTime: engineState.lastSyncTime,
            errorMessage: engineState.lastError,
          ),
        );
      } else {
        emit(
          SyncStatusState.syncError(
            lastSyncTime: engineState.lastSyncTime,
            errorMessage: engineState.lastError,
          ),
        );
      }
      return;
    }

    // 4. STARTUP: Before the first successful sync has finished
    if (engineState.lastSyncTime == null) {
      // Network is available, initial sync pass is either queued or running
      emit(
        const SyncStatusState.syncing(),
      );
      return;
    }

    // 5. CONNECTED: Successful sync completed, network available, no unresolved error
    emit(
      SyncStatusState.connected(
        lastSyncTime: engineState.lastSyncTime,
      ),
    );
  }

  /// Determines whether a sync failure is an infrastructure network/transport failure.
  ///
  /// Uses typed [SyncErrorDetails] when available, with defensive fallback.
  static bool _isNetworkTransportFailure(SyncEngineState state) {
    final details = state.errorDetails;
    if (details != null) {
      if (details.networkErrorType != null) {
        return true;
      }
      if (details.statusCode != null ||
          details.isValidationError ||
          details.isSerializationError) {
        return false;
      }
    }

    final error = state.lastError;
    if (error == null) return false;
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('connection failed') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection timeout') ||
        lower.contains('send timeout') ||
        lower.contains('receive timeout') ||
        lower.contains('connectionerror') ||
        lower.contains('no internet') ||
        lower.contains('timed out');
  }

  @override
  Future<void> close() {
    _networkSubscription?.cancel();
    _syncEngineSubscription?.cancel();
    return super.close();
  }
}
