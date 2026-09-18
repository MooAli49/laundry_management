import 'package:drift/drift.dart';

/// Local infrastructure table storing the device's incoming Pull cursor.
///
/// Follows `docs/04-database/tables.md` §21 and `docs/03-architecture/sync-strategy.md`.
/// Tracks the monotonically increasing [lastAppliedSequence] from remote `sync_changes`.
class SyncStates extends Table {
  @override
  String get tableName => 'sync_state';

  static const String singletonId = 'singleton';

  TextColumn get id => text().withDefault(const Constant('singleton'))();
  IntColumn get lastAppliedSequence =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
