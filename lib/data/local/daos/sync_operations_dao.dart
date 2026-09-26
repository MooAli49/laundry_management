import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart' as app_db;

class SyncOperationsDao extends DatabaseAccessor<app_db.AppDatabase> {
  SyncOperationsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> recordOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    String? payload,
    DateTime? nextRetryAt,
  }) async {
    final now = DateTime.now();
    await into(db.syncOperations).insert(
      app_db.SyncOperationsCompanion(
        id: Value(const Uuid().v4()),
        entityType: Value(entityType),
        entityId: Value(entityId),
        operationType: Value(operationType),
        payload: Value(payload),
        status: const Value('pending'),
        retryCount: const Value(0),
        nextRetryAt: Value(nextRetryAt),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<app_db.SyncOperation>> getPendingOperations({
    int limit = 50,
  }) async {
    return (select(db.syncOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Emits the list of pending sync operation IDs whenever pending operations change.
  ///
  /// Drift query streams guarantee that emissions only occur AFTER enclosing SQLite
  /// transactions have successfully committed.
  Stream<List<String>> watchPendingOperationIds() {
    final query = selectOnly(db.syncOperations)
      ..addColumns([db.syncOperations.id])
      ..where(db.syncOperations.status.equals('pending'));
    return query.map((row) => row.read(db.syncOperations.id)!).watch();
  }

  /// Emits the full list of pending sync operations for UI/monitoring watchers.
  Stream<List<app_db.SyncOperation>> watchPendingOperations({int limit = 100}) {
    return (select(db.syncOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// Returns operations eligible for synchronization at [asOf] timestamp.
  ///
  /// Eligible operations are:
  /// 1. Status 'pending' with no retry scheduled or retry timestamp <= [asOf].
  /// 2. Status 'failed' with a scheduled retry timestamp <= [asOf].
  ///
  /// Results are ordered chronologically by [createdAt] ascending.
  Future<List<app_db.SyncOperation>> getEligibleOperations({
    DateTime? asOf,
    int limit = 50,
  }) async {
    final effectiveAsOf = asOf ?? DateTime.now();
    return (select(db.syncOperations)
          ..where(
            (t) =>
                (t.status.equals('pending') &
                    (t.nextRetryAt.isNull() |
                        t.nextRetryAt.isSmallerOrEqualValue(effectiveAsOf))) |
                (t.status.equals('failed') &
                    t.nextRetryAt.isNotNull() &
                    t.nextRetryAt.isSmallerOrEqualValue(effectiveAsOf)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markOperationSynced(String id) async {
    final now = DateTime.now();
    await (update(db.syncOperations)..where((t) => t.id.equals(id))).write(
      app_db.SyncOperationsCompanion(
        status: const Value('synced'),
        nextRetryAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  @Deprecated('Use markOperationSynced instead')
  Future<void> markOperationCompleted(String id) => markOperationSynced(id);

  Future<void> markOperationFailed(
    String id,
    String error, {
    DateTime? nextRetryAt,
  }) async {
    final now = DateTime.now();
    final existing = await (select(
      db.syncOperations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final retry = (existing?.retryCount ?? 0) + 1;
    await (update(db.syncOperations)..where((t) => t.id.equals(id))).write(
      app_db.SyncOperationsCompanion(
        status: const Value('failed'),
        retryCount: Value(retry),
        lastError: Value(error),
        lastAttemptAt: Value(now),
        nextRetryAt: Value(nextRetryAt),
        updatedAt: Value(now),
      ),
    );
  }
}
