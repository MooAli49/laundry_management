import 'package:drift/drift.dart';

class CarpetSizes extends Table {
  @override
  String get tableName => 'carpet_sizes';

  TextColumn get id => text()();
  RealColumn get length => real()();
  RealColumn get width => real()();
  RealColumn get area => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length > 0)',
    'CHECK (width > 0)',
    'CHECK (area > 0)',
  ];
}
