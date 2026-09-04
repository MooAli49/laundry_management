import 'package:drift/drift.dart';
import 'customers_table.dart';

class Orders extends Table {
  @override
  String get tableName => 'orders';

  TextColumn get id => text()();
  TextColumn get orderNumber => text().unique()();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get status => text().withDefault(const Constant('processing'))();
  DateTimeColumn get expectedPickupDate => dateTime()();
  TextColumn get notes => text().nullable()();
  BoolColumn get customerPickupRequested =>
      boolean().withDefault(const Constant(false))();
  IntColumn get customerPickupFee => integer().withDefault(const Constant(0))();
  BoolColumn get customerDeliveryRequested =>
      boolean().withDefault(const Constant(false))();
  IntColumn get customerDeliveryFee =>
      integer().withDefault(const Constant(0))();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (customer_pickup_fee >= 0)',
    'CHECK (customer_delivery_fee >= 0)',
    'CHECK (subtotal >= 0)',
    'CHECK (discount >= 0)',
    'CHECK (tax >= 0)',
    'CHECK (total >= 0)',
  ];
}
