import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/network_info.dart';
import '../../core/network/realtime_sync_adapter.dart';
import '../../domain/sync/sync_engine_state.dart';
import '../../domain/sync/sync_error_classifier.dart';
import '../../domain/sync/sync_retry_policy.dart';
import '../datasources/remote/remote_api_dispatcher.dart';
import '../datasources/remote/sync_remote_data_source.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/daos/sync_state_dao.dart';
import 'remote_change_applier.dart';

/// Orchestrates bidirectional synchronization (Push + Pull + Realtime Wake-Up)
/// between the local SQLite database and the remote Supabase backend.
///
/// Follows `docs/08-implementation/synchronization-implementation.md`.
///
/// Invariants:
/// 1. Local SQLite/Drift database remains the operational source of truth.
/// 2. `sync_state.last_applied_sequence` is the authoritative local pull cursor.
/// 3. Realtime is strictly a SIGNAL-ONLY wake-up mechanism. Payloads are never authoritative.
/// 4. Actual change data is always retrieved from `GET /api/v1/sync/changes?after=<cursor>&limit=<limit>`.
/// 5. [RemoteChangeApplier] is the exclusive boundary for applying remote changes to SQLite.
/// 6. Remote apply never generates outgoing [SyncOperation] records (zero echo loop).
/// 7. Unified single-flight concurrency: At most ONE synchronization operation runs at a time.
/// 8. Multiple incoming triggers during active sync are coalesced into at most ONE trailing pass.
/// 9. Pull pages are committed atomically in SQLite. Network calls never span a multi-page transaction.
/// 10. `CURSOR_TOO_OLD` preserves pending [SyncOperation] records without destructive local reset.
class SyncEngine {
  static const int _defaultPageSize = 100;

  final SyncOperationsDao _syncOperationsDao;
  final RemoteApiDispatcher _remoteApiDispatcher;
  final NetworkInfo _networkInfo;
  final SyncRetryPolicy _retryPolicy;
  final SyncErrorClassifier _errorClassifier;
  final SyncRemoteDataSource? _syncRemoteDataSource;
  final RemoteChangeApplier? _remoteChangeApplier;
  final SyncStateDao? _syncStateDao;
  final RealtimeSyncAdapter? _realtimeAdapter;
  final DateTime Function() _clock;
  final void Function(String message, [Object? error, StackTrace? stackTrace])?
  _logHandler;

  bool _isSynchronizing = false;
  bool _pendingNeedsPush = false;
  bool _pendingNeedsPull = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<void>? _realtimeSubscription;
  StreamSubscription<List<String>>? _outboxSubscription;
  Set<String> _knownPendingIds = {};
  Timer? _periodicTimer;

  SyncEngineState _state = const SyncEngineState.idle();
  final StreamController<SyncEngineState> _stateController =
      StreamController<SyncEngineState>.broadcast();

  SyncEngine({
    required SyncOperationsDao syncOperationsDao,
    required RemoteApiDispatcher remoteApiDispatcher,
    required NetworkInfo networkInfo,
    required SyncRetryPolicy retryPolicy,
    required SyncErrorClassifier errorClassifier,
    SyncRemoteDataSource? syncRemoteDataSource,
    RemoteChangeApplier? remoteChangeApplier,
    SyncStateDao? syncStateDao,
    RealtimeSyncAdapter? realtimeAdapter,
    DateTime Function()? clock,
    void Function(String message, [Object? error, StackTrace? stackTrace])?
    logHandler,
  }) : _syncOperationsDao = syncOperationsDao,
       _remoteApiDispatcher = remoteApiDispatcher,
       _networkInfo = networkInfo,
       _retryPolicy = retryPolicy,
       _errorClassifier = errorClassifier,
       _syncRemoteDataSource = syncRemoteDataSource,
       _remoteChangeApplier = remoteChangeApplier,
       _syncStateDao = syncStateDao,
       _realtimeAdapter = realtimeAdapter,
       _clock = clock ?? DateTime.now,
       _logHandler = logHandler;

  /// Current lifecycle state of the synchronization engine.
  SyncEngineState get state => _state;

  /// Stream of state transitions emitted during sync cycles.
  Stream<SyncEngineState> get stateStream => _stateController.stream;

  /// Whether a synchronization cycle (push, pull, or both) is actively running.
  bool get isSyncing => _isSynchronizing;

  /// Whether the sync engine has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether the sync engine has been disposed.
  bool get isDisposed => _isDisposed;

  /// Initializes the synchronization engine lifecycle and foreground triggers.
  ///
  /// 1. Subscribes to [NetworkInfo.onConnectivityChanged] to trigger full sync on network recovery.
  /// 2. Subscribes to [RealtimeSyncAdapter.onSyncAvailable] to trigger pull on remote change signals.
  /// 3. Starts an optional periodic foreground sync timer (defaults to 15 minutes).
  /// 4. Triggers initial foreground sync asynchronously if [triggerInitialSync] is true.
  ///
  /// Idempotent: calling [initialize] multiple times is safe and returns early.
  Future<void> initialize({
    bool triggerInitialSync = true,
    Duration? periodicSyncInterval = const Duration(minutes: 15),
  }) async {
    if (_isDisposed || _isInitialized) {
      return;
    }
    _isInitialized = true;

    // Snapshot existing pending IDs before subscribing to avoid false trigger on pre-existing items
    try {
      final initialPending = await _syncOperationsDao.getPendingOperations();
      if (_isDisposed) return;
      _knownPendingIds = initialPending.map((op) => op.id).toSet();
    } catch (_) {
      // Safely ignore DB access errors in unit test environments without real storage
    }

    // 1. Subscribe to central outbox changes for newly committed pending operations
    _outboxSubscription = _syncOperationsDao.watchPendingOperationIds().listen(
      (ids) {
        if (_isDisposed) return;
        final currentIds = ids.toSet();
        final hasNewOperations = currentIds.any(
          (id) => !_knownPendingIds.contains(id),
        );
        _knownPendingIds = currentIds;

        if (hasNewOperations) {
          unawaited(sync().catchError((_, __) => _state));
        }
      },
      onError: (_) {
        // Outbox stream errors are safely ignored
      },
    );

    // 2. Subscribe to network connectivity changes
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (_isDisposed) return;
        if (isConnected) {
          unawaited(sync().catchError((_, __) => _state));
        }
      },
      onError: (_) {
        // Platform connectivity stream errors are safely ignored
      },
    );

    // 2. Subscribe to Realtime wake-up signals
    if (_realtimeAdapter != null) {
      await _realtimeAdapter.subscribe();
      _realtimeSubscription = _realtimeAdapter.onSyncAvailable.listen(
        (_) {
          if (_isDisposed) return;
          unawaited(pull().catchError((_, __) => null));
        },
        onError: (_) {
          // Realtime stream errors are handled gracefully
        },
      );
    }

    // 3. Start optional periodic foreground sync timer
    if (periodicSyncInterval != null && periodicSyncInterval > Duration.zero) {
      _periodicTimer = Timer.periodic(periodicSyncInterval, (_) {
        if (_isDisposed) return;
        unawaited(sync().catchError((_, __) => _state));
      });
    }

    // 4. Trigger initial sync asynchronously (fire-and-forget, non-blocking)
    if (triggerInitialSync) {
      unawaited(sync().catchError((_, __) => _state));
    }
  }

  /// Triggers a complete synchronization cycle:
  ///   1. Push pending local operations to remote
  ///   2. Pull latest remote changes to local
  ///
  /// Concurrency Model:
  /// Uses a unified single-flight coalescing guard. If a cycle is already active,
  /// flags follow-up work so exactly ONE trailing pass executes upon completion.
  Future<SyncEngineState> sync() async {
    if (_isDisposed) {
      return _state;
    }

    if (_isSynchronizing) {
      _pendingNeedsPush = true;
      _pendingNeedsPull = true;
      return _state;
    }

    _isSynchronizing = true;
    _pendingNeedsPush = true;
    _pendingNeedsPull = true;

    return await _runSyncLoop();
  }

  /// Triggers a pull-only synchronization cycle from the remote backend.
  ///
  /// Called by Realtime wake-up signals or targeted pull requests.
  /// Uses the same unified single-flight guard: if a sync cycle is active,
  /// coalesces into the pending follow-up pass.
  Future<void> pull() async {
    if (_isDisposed) {
      return;
    }

    if (_isSynchronizing) {
      _pendingNeedsPull = true;
      return;
    }

    _isSynchronizing = true;
    _pendingNeedsPull = true;

    await _runSyncLoop();
  }

  /// Core coalescing execution loop.
  ///
  /// Ensures at most ONE synchronization operation actively mutates state.
  /// Loops while pending flags remain, coalescing rapid triggers into a single trailing pass.
  Future<SyncEngineState> _runSyncLoop() async {
    try {
      while (!_isDisposed) {
        final doPush = _pendingNeedsPush;
        final doPull = _pendingNeedsPull;

        // Reset pending flags before executing this phase so any trigger
        // arriving during execution re-flags pending work.
        _pendingNeedsPush = false;
        _pendingNeedsPull = false;

        if (!doPush && !doPull) {
          break;
        }

        if (doPush && !_isDisposed) {
          await _executePush();
        }

        if (doPull && !_isDisposed) {
          await _executePull();
        }

        if (!_pendingNeedsPush && !_pendingNeedsPull) {
          break;
        }
      }
    } finally {
      _isSynchronizing = false;
    }
    return _state;
  }

  /// Executes page-by-page remote change pulling.
  ///
  /// Contract:
  /// - Pulls until `has_more == false` or changes list is empty.
  /// - Each page is applied atomically + cursor advanced in SQLite inside a single transaction.
  /// - Network calls are NEVER held inside a multi-page transaction.
  /// - If page N succeeds and page N+1 fails, page N remains committed and cursor remains at page N.
  /// - `CURSOR_TOO_OLD` (HTTP 410) halts pagination and preserves pending operations.
  Future<void> _executePull() async {
    final remoteDataSource = _syncRemoteDataSource;
    final changeApplier = _remoteChangeApplier;
    final stateDao = _syncStateDao;

    if (remoteDataSource == null || changeApplier == null || stateDao == null) {
      return;
    }

    final isConnected = await _networkInfo.isConnected;
    if (!isConnected || _isDisposed) {
      return;
    }

    try {
      int cursor = await stateDao.getLastAppliedSequence();
      bool hasMore = true;

      while (hasMore && !_isDisposed) {
        final stillConnected = await _networkInfo.isConnected;
        if (!stillConnected || _isDisposed) {
          break;
        }

        final response = await remoteDataSource.getChanges(
          after: cursor,
          limit: _defaultPageSize,
        );

        if (response.changes.isEmpty) {
          break;
        }

        // Apply changes and advance sync_state.last_applied_sequence in Drift
        await changeApplier.applyBatch(response.changes);

        cursor = response.changes.last.sequence;
        hasMore = response.hasMore;
      }
    } on CursorTooOldException catch (e, stack) {
      _log('CURSOR_TOO_OLD encountered during pull: ${e.message}', e, stack);
      final remainingOps = await _syncOperationsDao.getEligibleOperations(
        asOf: _clock(),
      );
      _updateState(
        SyncEngineState.failed(
          error: 'CURSOR_TOO_OLD: ${e.message}',
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: remainingOps.length,
        ),
      );
    } catch (e, stack) {
      // Partial pagination safety: if an error occurs mid-pagination,
      // all previously committed pages remain committed with updated cursor.
      // Next pull will resume from the persisted cursor.
      _log('Unexpected pull failure: $e', e, stack);

      int remainingCount = _state.pendingOperationsCount;
      try {
        final remainingOps = await _syncOperationsDao.getEligibleOperations(
          asOf: _clock(),
        );
        remainingCount = remainingOps.length;
      } catch (_) {
        // Defensive: preserve last known count if DAO query fails during double-fault
      }

      final errorMessage = _mapPullErrorMessage(e);
      _updateState(
        SyncEngineState.failed(
          error: errorMessage,
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: remainingCount,
        ),
      );
    }
  }

  /// Executes push dispatching for pending local [SyncOperation] records.
  Future<void> _executePush() async {
    try {
      _updateState(
        SyncEngineState.syncing(
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: _state.pendingOperationsCount,
        ),
      );

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
        return;
      }

      final now = _clock();
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
        return;
      }

      _updateState(
        SyncEngineState.syncing(
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: operations.length,
        ),
      );

      for (var i = 0; i < operations.length; i++) {
        if (_isDisposed) {
          break;
        }

        final op = operations[i];

        final stillConnected = await _networkInfo.isConnected;
        if (!stillConnected || _isDisposed) {
          break;
        }

        try {
          await _remoteApiDispatcher.dispatch(op);
          await _syncOperationsDao.markOperationSynced(op.id);
        } catch (error) {
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
              errorMessage =
                  'Retry limit exhausted: ${details.message ?? error.toString()}';
              await _syncOperationsDao.markOperationFailed(
                op.id,
                errorMessage,
                nextRetryAt: null,
              );
            }
          } else {
            errorMessage = details.message ?? error.toString();
            await _syncOperationsDao.markOperationFailed(
              op.id,
              errorMessage,
              nextRetryAt: null,
            );
          }

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
          return;
        }
      }

      if (_isDisposed) {
        return;
      }

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
    } catch (unexpectedError, stack) {
      _log('Unexpected push failure: $unexpectedError', unexpectedError, stack);
      int remainingCount = _state.pendingOperationsCount;
      try {
        final remainingOps = await _syncOperationsDao.getEligibleOperations(
          asOf: _clock(),
        );
        remainingCount = remainingOps.length;
      } catch (_) {
        // Defensive: preserve last known count if DAO query fails during double-fault
      }
      _updateState(
        SyncEngineState.failed(
          error: unexpectedError.toString(),
          lastSyncTime: _state.lastSyncTime,
          pendingOperationsCount: remainingCount,
        ),
      );
    }
  }

  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    if (_logHandler != null) {
      _logHandler(message, error, stackTrace);
      return;
    }
    developer.log(
      message,
      name: 'SyncEngine',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[SyncEngine] $message');
  }

  String _mapPullErrorMessage(Object error) {
    if (error is CursorTooOldException) {
      return 'CURSOR_TOO_OLD: ${error.message}';
    }
    if (error is AppException) {
      return 'PULL_ERROR: [${error.runtimeType}] ${error.message}';
    }
    if (error is DioException) {
      final code = error.response?.statusCode;
      final codeStr = code != null ? ' (HTTP $code)' : '';
      return 'PULL_ERROR: DioException$codeStr: ${error.message ?? error.toString()}';
    }
    return 'PULL_ERROR: $error';
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

  /// Disposes the synchronization engine and frees all listeners and timers.
  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _outboxSubscription?.cancel();
    _outboxSubscription = null;
    _knownPendingIds.clear();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (_realtimeAdapter != null) {
      unawaited(_realtimeAdapter.unsubscribe().catchError((_) {}));
    }
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
