import 'package:drift/drift.dart';

class Services extends Table {
  @override
  String get tableName => 'services';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  TextColumn get pricingType => text()();
  IntColumn get price => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (price >= 0)'];
}
