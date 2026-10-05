import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../sync/sync_dependency_resolver.dart';
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
  /// Implements dependency-aware synchronization:
  /// 1. A downstream operation is NOT eligible if any of its parent dependencies
  ///    has permanently failed (status 'failed' with nextRetryAt IS NULL).
  /// 2. If an operation is waiting for retry in the future (nextRetryAt > asOf),
  ///    FIFO queue ordering pauses at that operation so dependent items cannot bypass it.
  /// 3. Unrelated operations are NOT blocked by a permanent failure in an independent entity.
  /// 4. Blocked operations remain in 'pending' status so they can be dispatched once
  ///    their parent dependency is repaired and synced.
  Future<List<app_db.SyncOperation>> getEligibleOperations({
    DateTime? asOf,
    int limit = 50,
  }) async {
    final effectiveAsOf = asOf ?? DateTime.now();
    if (limit <= 0) return [];

    final queue =
        await (select(db.syncOperations)
              ..where((t) => t.status.isIn(['pending', 'failed']))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (_) => OrderingTerm.asc(CustomExpression<int>('rowid')),
              ]))
            .get();

    if (queue.isEmpty) return [];

    Map<String, String>? orderItemToOrderMap;
    final hasStorageRecord = queue.any(
      (op) => op.entityType == 'storage_record',
    );
    if (hasStorageRecord) {
      final items = await select(db.orderItems).get();
      orderItemToOrderMap = {for (final item in items) item.id: item.orderId};
    }

    final eligible = <app_db.SyncOperation>[];
    final permanentlyFailedEntities = <EntityDependency>{
      for (final operation in queue)
        if (operation.status == 'failed' && operation.nextRetryAt == null)
          EntityDependency(
            entityType: operation.entityType,
            entityId: operation.entityId,
          ),
    };

    for (var i = 0; i < queue.length; i++) {
      final operation = queue[i];
      // 1. Permanent failure check for this operation
      final isPermanentlyFailed =
          operation.status == 'failed' && operation.nextRetryAt == null;
      if (isPermanentlyFailed) {
        continue;
      }

      // 2. Future retry barrier: if this operation is waiting for a retry in the future,
      // pause FIFO traversal so operations behind it do not bypass it.
      final retryAt = operation.nextRetryAt;
      if (retryAt != null && retryAt.isAfter(effectiveAsOf)) {
        continue;
      }

      // 3. Inspect dependencies of this operation
      final deps = SyncDependencyResolver.extractDependencies(
        operation,
        orderItemToOrderMap: orderItemToOrderMap,
      );

      if (deps.any(
        (dependency) =>
            dependency.entityType ==
            SyncDependencyResolver.malformedPayloadEntityType,
      )) {
        continue;
      }

      // If any required parent dependency has permanently failed, block this operation
      final isBlockedByFailedParent = deps.any(
        permanentlyFailedEntities.contains,
      );
      if (isBlockedByFailedParent) {
        continue;
      }

      // Synced operations are not in [queue]. An earlier unsynced parent
      // operation therefore remains a lifecycle barrier for this operation.
      final hasUnsyncedParent = deps.any(
        (dependency) => queue.take(i).any(
          (parent) =>
              parent.entityType == dependency.entityType &&
              parent.entityId == dependency.entityId,
        ),
      );
      if (hasUnsyncedParent) continue;

      eligible.add(operation);
      if (eligible.length == limit) break;
    }

    return eligible;
  }

  /// Checks whether any parent dependency of [operation] has permanently failed.
  Future<bool> hasPermanentlyFailedDependency(
    app_db.SyncOperation operation,
  ) async {
    Map<String, String>? orderItemToOrderMap;
    if (operation.entityType == 'storage_record') {
      final items = await select(db.orderItems).get();
      orderItemToOrderMap = {for (final item in items) item.id: item.orderId};
    }

    final deps = SyncDependencyResolver.extractDependencies(
      operation,
      orderItemToOrderMap: orderItemToOrderMap,
    );

    if (deps.isEmpty) return false;

    for (final dep in deps) {
      final failedOp =
          await (select(db.syncOperations)..where(
                (t) =>
                    t.entityType.equals(dep.entityType) &
                    t.entityId.equals(dep.entityId) &
                    t.status.equals('failed') &
                    t.nextRetryAt.isNull(),
              ))
              .getSingleOrNull();

      if (failedOp != null) {
        return true;
      }
    }

    return false;
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

  /// Explicitly reopens a permanently failed operation for user-initiated
  /// recovery. Automatic synchronization never performs this transition.
  Future<void> retryOperation(String id) async {
    final now = DateTime.now();
    await (update(db.syncOperations)..where((t) => t.id.equals(id))).write(
      app_db.SyncOperationsCompanion(
        status: const Value('pending'),
        retryCount: const Value(0),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
        lastAttemptAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }
}
