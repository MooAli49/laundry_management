/// Operational status of the synchronization engine.
enum SyncEngineStatus {
  /// The engine is inactive and waiting for triggers.
  idle,

  /// A synchronization cycle is currently in progress.
  syncing,

  /// The most recent synchronization cycle completed successfully.
  completed,

  /// The most recent synchronization cycle failed.
  failed,
}

/// Immutable domain state model representing the lifecycle of the synchronization engine.
///
/// Designed to be completely decoupled from infrastructure details (Dio, Retrofit, Drift).
class SyncEngineState {
  final SyncEngineStatus status;
  final DateTime? lastSyncTime;
  final int pendingOperationsCount;
  final String? lastError;

  const SyncEngineState({
    required this.status,
    this.lastSyncTime,
    this.pendingOperationsCount = 0,
    this.lastError,
  });

  /// Factory constructor for the idle state.
  const SyncEngineState.idle({
    this.lastSyncTime,
    this.pendingOperationsCount = 0,
  }) : status = SyncEngineStatus.idle,
       lastError = null;

  /// Factory constructor for the active syncing state.
  const SyncEngineState.syncing({
    this.lastSyncTime,
    this.pendingOperationsCount = 0,
  }) : status = SyncEngineStatus.syncing,
       lastError = null;

  /// Factory constructor for a successfully completed sync cycle.
  const SyncEngineState.completed({
    required this.lastSyncTime,
    this.pendingOperationsCount = 0,
  }) : status = SyncEngineStatus.completed,
       lastError = null;

  /// Factory constructor for a failed sync cycle.
  const SyncEngineState.failed({
    required String error,
    this.lastSyncTime,
    this.pendingOperationsCount = 0,
  }) : status = SyncEngineStatus.failed,
       lastError = error;

  /// Creates a copy of this state with specified fields replaced.
  SyncEngineState copyWith({
    SyncEngineStatus? status,
    DateTime? lastSyncTime,
    int? pendingOperationsCount,
    String? lastError,
  }) {
    return SyncEngineState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingOperationsCount:
          pendingOperationsCount ?? this.pendingOperationsCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncEngineState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastSyncTime == other.lastSyncTime &&
          pendingOperationsCount == other.pendingOperationsCount &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      status.hashCode ^
      lastSyncTime.hashCode ^
      pendingOperationsCount.hashCode ^
      lastError.hashCode;

  @override
  String toString() =>
      'SyncEngineState(status: $status, lastSyncTime: $lastSyncTime, pending: $pendingOperationsCount, lastError: $lastError)';
}
