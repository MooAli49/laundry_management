import 'dart:async';

/// Abstract adapter for receiving real-time synchronization wake-up signals.
///
/// Invariants:
/// 1. Realtime is strictly a SIGNAL-ONLY wake-up mechanism.
/// 2. Realtime payloads must NEVER be treated as authoritative change data.
/// 3. Realtime signals must NEVER directly mutate SQLite/Drift tables.
/// 4. Realtime signals must NEVER create SyncOperation records.
/// 5. Actual synchronization data must ALWAYS come from the cursor-based Pull API:
///    `GET /api/v1/sync/changes?after=<cursor>&limit=<limit>`.
abstract class RealtimeSyncAdapter {
  /// Ephemeral stream emitting wake-up signals when remote changes occur.
  Stream<void> get onSyncAvailable;

  /// Connects and subscribes to the remote real-time sync channel.
  Future<void> subscribe();

  /// Unsubscribes and frees channel resources.
  Future<void> unsubscribe();
}
