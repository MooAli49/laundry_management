import 'package:drift/drift.dart';

class BusinessSettings extends Table {
  @override
  String get tableName => 'business_settings';

  TextColumn get id => text()();
  TextColumn get businessName => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get logoReference => text().nullable()();
  TextColumn get invoiceFooterText => text().nullable()();
  BoolColumn get taxEnabled => boolean().withDefault(const Constant(false))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (tax_rate >= 0.0)'];
}
