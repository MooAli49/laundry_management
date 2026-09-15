import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/network/network_info.dart';
import '../../domain/sync/sync_engine_state.dart';
import '../../domain/sync/sync_error_classifier.dart';
import '../../domain/sync/sync_retry_policy.dart';
import '../datasources/remote/remote_api_dispatcher.dart';
import '../local/daos/sync_operations_dao.dart';

/// Orchestrates the synchronization of local queued operations to the remote backend.
///
/// Follows `docs/08-implementation/synchronization-implementation.md`.
///
/// Dispatches eligible operations sequentially through [RemoteApiDispatcher],
/// classifies errors using [SyncErrorClassifier], and schedules retries via [SyncRetryPolicy].
class SyncEngine {
  final SyncOperationsDao _syncOperationsDao;
  final RemoteApiDispatcher _remoteApiDispatcher;
  final NetworkInfo _networkInfo;
  final SyncRetryPolicy _retryPolicy;
  final SyncErrorClassifier _errorClassifier;
  final DateTime Function() _clock;

  bool _isSyncing = false;
  SyncEngineState _state = const SyncEngineState.idle();
  final StreamController<SyncEngineState> _stateController =
      StreamController<SyncEngineState>.broadcast();

  SyncEngine({
    required SyncOperationsDao syncOperationsDao,
    required RemoteApiDispatcher remoteApiDispatcher,
    required NetworkInfo networkInfo,
    required SyncRetryPolicy retryPolicy,
    required SyncErrorClassifier errorClassifier,
    DateTime Function()? clock,
  }) : _syncOperationsDao = syncOperationsDao,
       _remoteApiDispatcher = remoteApiDispatcher,
       _networkInfo = networkInfo,
       _retryPolicy = retryPolicy,
       _errorClassifier = errorClassifier,
       _clock = clock ?? DateTime.now;

  /// Current lifecycle state of the synchronization engine.
  SyncEngineState get state => _state;

  /// Stream of state transitions emitted during sync cycles.
  Stream<SyncEngineState> get stateStream => _stateController.stream;

  /// Whether a sync cycle is currently active.
  bool get isSyncing => _isSyncing;

  /// Triggers a synchronization cycle across eligible operations in the queue.
  ///
  /// If a cycle is already in progress, returns the current in-progress state.
  /// If the device is offline, returns the current state without modifying the queue.
  Future<SyncEngineState> sync() async {
    // 1. Re-entrancy / Concurrency guard
    if (_isSyncing) {
      return _state;
    }

    _isSyncing = true;
    _updateState(
      SyncEngineState.syncing(
        lastSyncTime: _state.lastSyncTime,
        pendingOperationsCount: _state.pendingOperationsCount,
      ),
    );

    try {
      // 2. Network connectivity check
      final isConnected = await _networkInfo.isConnected;
      if (!isConnected) {
        final remaining = await _syncOperationsDao.getEligibleOperations(
          asOf: _clock(),
        );
        _updateState(
          _state.copyWith(
            status: SyncEngineStatus.idle,
            pendingOperationsCount: remaining.length,
          ),
        );
        return _state;
      }

      final now = _clock();
      // 3. Fetch eligible operations in deterministic order
      final operations = await _syncOperationsDao.getEligibleOperations(
        asOf: now,
      );

      if (operations.isEmpty) {
        _updateState(
          SyncEngineState.completed(
            lastSyncTime: now,
            pendingOperationsCount: 0,
          ),
        );
        return _state;
      }

      _updateState(
        SyncEngineState.syncing(
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: operations.length,
        ),
      );

      // 4. Sequential processing
      for (var i = 0; i < operations.length; i++) {
        final op = operations[i];

        // Check if connectivity was lost mid-processing
        final stillConnected = await _networkInfo.isConnected;
        if (!stillConnected) {
          // Stop processing safely without marking current unconfirmed operation as synced
          break;
        }

        try {
          // Dispatch through RemoteApiDispatcher
          await _remoteApiDispatcher.dispatch(op);

          // Success: Mark as synced
          await _syncOperationsDao.markOperationSynced(op.id);
        } catch (error) {
          // Classify failure
          final details = _mapErrorToDetails(error);
          final failureKind = _errorClassifier.classify(details);
          final String errorMessage;

          if (failureKind == SyncFailureKind.retryable) {
            final nextRetryCount = op.retryCount + 1;
            if (_retryPolicy.shouldRetry(nextRetryCount)) {
              errorMessage = details.message ?? error.toString();
              final nextRetryAt = _retryPolicy.calculateNextRetryAt(
                nextRetryCount,
                now: _clock(),
              );
              await _syncOperationsDao.markOperationFailed(
                op.id,
                errorMessage,
                nextRetryAt: nextRetryAt,
              );
            } else {
              // Retry limit exhausted: permanent failure
              errorMessage =
                  'Retry limit exhausted: ${details.message ?? error.toString()}';
              await _syncOperationsDao.markOperationFailed(
                op.id,
                errorMessage,
                nextRetryAt: null,
              );
            }
          } else {
            // Permanent failure
            errorMessage = details.message ?? error.toString();
            await _syncOperationsDao.markOperationFailed(
              op.id,
              errorMessage,
              nextRetryAt: null,
            );
          }

          // Stop queue processing on failure to preserve dependency ordering
          final remainingOps = await _syncOperationsDao.getEligibleOperations(
            asOf: _clock(),
          );
          _updateState(
            SyncEngineState.failed(
              error: errorMessage,
              lastSyncTime: _state.lastSyncTime,
              pendingOperationsCount: remainingOps.length,
            ),
          );
          return _state;
        }
      }

      // 5. Completion state update
      final remainingOps = await _syncOperationsDao.getEligibleOperations(
        asOf: _clock(),
      );
      final finishTime = _clock();
      _updateState(
        SyncEngineState.completed(
          lastSyncTime: finishTime,
          pendingOperationsCount: remainingOps.length,
        ),
      );
      return _state;
    } catch (unexpectedError) {
      final remainingOps = await _syncOperationsDao.getEligibleOperations(
        asOf: _clock(),
      );
      _updateState(
        SyncEngineState.failed(
          error: unexpectedError.toString(),
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: remainingOps.length,
        ),
      );
      return _state;
    } finally {
      _isSyncing = false;
    }
  }

  void _updateState(SyncEngineState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  SyncErrorDetails _mapErrorToDetails(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return SyncErrorDetails.http(
          statusCode,
          message: error.message ?? error.toString(),
        );
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return SyncErrorDetails.network(
            SyncNetworkErrorType.timeout,
            message: error.message ?? 'Request timeout',
          );
        case DioExceptionType.connectionError:
          return SyncErrorDetails.network(
            SyncNetworkErrorType.connectionFailed,
            message: error.message ?? 'Connection failed',
          );
        case DioExceptionType.badCertificate:
          return SyncErrorDetails.network(
            SyncNetworkErrorType.connectionFailed,
            message: error.message ?? 'Bad certificate',
          );
        default:
          return SyncErrorDetails.network(
            SyncNetworkErrorType.unknown,
            message: error.message ?? 'Unknown network error',
          );
      }
    }

    if (error is FormatException) {
      return SyncErrorDetails.serialization(message: error.message);
    }

    if (error is ArgumentError ||
        error is TypeError ||
        error is UnsupportedError) {
      return SyncErrorDetails.validation(message: error.toString());
    }

    return SyncErrorDetails(message: error.toString());
  }

  void dispose() {
    _stateController.close();
  }
}
