import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;
import '../tables/sync_states_table.dart';

/// Data Access Object for local synchronization pull state.
///
/// Follows `docs/04-database/tables.md` §21 and `docs/08-implementation/synchronization-implementation.md` §67.
/// Maintains the singleton pull cursor tracking the latest applied sequence from `sync_changes`.
///
/// Invariant: Zero [SyncOperation] records are ever created by this DAO.
class SyncStateDao extends DatabaseAccessor<app_db.AppDatabase> {
  SyncStateDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  static const String singletonId = SyncStates.singletonId;

  /// Retrieves the current sync state singleton, initializing it with sequence 0 if missing.
  Future<app_db.SyncState> getSyncState() async {
    final existing = await (select(
      db.syncStates,
    )..where((t) => t.id.equals(singletonId))).getSingleOrNull();

    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final companion = app_db.SyncStatesCompanion(
      id: const Value(singletonId),
      lastAppliedSequence: const Value(0),
      lastSyncAt: const Value(null),
      updatedAt: Value(now),
    );

    await into(db.syncStates).insertOnConflictUpdate(companion);
    return (select(
      db.syncStates,
    )..where((t) => t.id.equals(singletonId))).getSingle();
  }

  /// Returns the latest successfully applied sequence cursor (defaults to 0).
  Future<int> getLastAppliedSequence() async {
    final state = await getSyncState();
    return state.lastAppliedSequence;
  }

  /// Atomically updates the local sync cursor.
  ///
  /// When called within an active transaction (`db.transaction`), this update
  /// commits atomically with the applied changes.
  Future<void> updateLastAppliedSequence(
    int sequence, {
    DateTime? syncAt,
  }) async {
    final now = DateTime.now();
    final companion = app_db.SyncStatesCompanion(
      id: const Value(singletonId),
      lastAppliedSequence: Value(sequence),
      lastSyncAt: Value(syncAt ?? now),
      updatedAt: Value(now),
    );

    await into(db.syncStates).insertOnConflictUpdate(companion);
  }
}
