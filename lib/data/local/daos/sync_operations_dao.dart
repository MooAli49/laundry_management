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
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<app_db.SyncOperation>> getPendingOperations({int limit = 50}) async {
    return (select(db.syncOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markOperationCompleted(String id) async {
    final now = DateTime.now();
    await (update(db.syncOperations)..where((t) => t.id.equals(id))).write(
      app_db.SyncOperationsCompanion(
        status: const Value('completed'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markOperationFailed(String id, String error) async {
    final now = DateTime.now();
    final existing = await (select(db.syncOperations)..where((t) => t.id.equals(id))).getSingleOrNull();
    final retry = (existing?.retryCount ?? 0) + 1;
    await (update(db.syncOperations)..where((t) => t.id.equals(id))).write(
      app_db.SyncOperationsCompanion(
        status: const Value('failed'),
        retryCount: Value(retry),
        lastError: Value(error),
        lastAttemptAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}
