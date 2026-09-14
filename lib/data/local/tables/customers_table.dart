import 'package:drift/drift.dart';

class Customers extends Table {
  @override
  String get tableName => 'customers';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().unique()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
