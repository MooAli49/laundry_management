import 'package:drift/drift.dart';

class SyncConflicts extends Table {
  @override
  String get tableName => 'sync_conflicts';

  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get conflictType => text()();
  TextColumn get localEntityId => text().nullable()();
  TextColumn get orderNumber => text().nullable()();
  IntColumn get remoteSequence => integer()();
  TextColumn get operationId => text()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get detectedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolutionNotes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
