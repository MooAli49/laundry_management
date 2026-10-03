import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class SyncConflictsDao extends DatabaseAccessor<app_db.AppDatabase> {
  SyncConflictsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> recordOrderNumberConflict({
    required String entityId,
    required String conflictType,
    required String? localEntityId,
    required String orderNumber,
    required int remoteSequence,
    required String operationId,
    required String operationType,
    required Map<String, dynamic> payload,
    required DateTime detectedAt,
  }) async {
    final conflictId = 'order:$entityId:$remoteSequence';
    await into(db.syncConflicts).insertOnConflictUpdate(
      app_db.SyncConflictsCompanion(
        id: Value(conflictId),
        entityType: const Value('order'),
        entityId: Value(entityId),
        conflictType: Value(conflictType),
        localEntityId: Value(localEntityId),
        orderNumber: Value(orderNumber),
        remoteSequence: Value(remoteSequence),
        operationId: Value(operationId),
        operationType: Value(operationType),
        payload: Value(jsonEncode(payload)),
        detectedAt: Value(detectedAt),
      ),
    );
  }
}
