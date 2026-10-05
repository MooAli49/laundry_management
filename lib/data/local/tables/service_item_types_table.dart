import 'package:drift/drift.dart';
import 'services_table.dart';
import 'item_types_table.dart';

class ServiceItemTypes extends Table {
  @override
  String get tableName => 'service_item_types';

  TextColumn get id => text()();
  /// Foreign key to [Services].
  ///
  /// Architectural Decision (LOW-03):
  /// - Local (Drift/SQLite): Uses `KeyAction.restrict` as defense-in-depth on client devices
  ///   to prevent accidental cascading deletion of catalog pricing mappings if a service row
  ///   is targeted by an errant delete command. Services in the app are soft-deactivated (`isActive = false`).
  /// - Remote (Supabase/PostgreSQL): Uses `ON DELETE CASCADE` to facilitate server-side
  ///   administrative purges and database cleanup scripts without manual child row orchestration.
  TextColumn get serviceId =>
      text().references(Services, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemTypeId =>
      text().references(ItemTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get pricingType => text()();
  IntColumn get price => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {serviceId, itemTypeId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (pricing_type IN (\'per_piece\', \'per_square_meter\'))',
    'CHECK (price > 0)',
  ];
}
