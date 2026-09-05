import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class CustomersDao extends DatabaseAccessor<app_db.AppDatabase> {
  CustomersDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertCustomer(app_db.CustomersCompanion companion) async {
    await into(db.customers).insert(companion);
  }

  Future<void> updateCustomer(app_db.CustomersCompanion companion) async {
    await (update(db.customers)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.Customer?> getCustomerById(String id) async {
    return (select(db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<app_db.Customer?> getCustomerByPhone(String phone) async {
    return (select(db.customers)..where((t) => t.phone.equals(phone))).getSingleOrNull();
  }

  Future<List<app_db.Customer>> searchCustomers({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryBuilder = select(db.customers);
    if (query != null && query.trim().isNotEmpty) {
      final sanitized = query.trim();
      queryBuilder.where(
        (t) => t.name.like('%$sanitized%') | t.phone.like('%$sanitized%'),
      );
    }
    queryBuilder
      ..orderBy([(t) => OrderingTerm.asc(t.name)])
      ..limit(limit, offset: offset);
    return queryBuilder.get();
  }

  Stream<List<app_db.Customer>> watchCustomers() {
    return (select(db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<bool> hasOrderHistory(String customerId) async {
    final countExp = db.orders.id.count();
    final query = selectOnly(db.orders)
      ..where(db.orders.customerId.equals(customerId))
      ..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return (result ?? 0) > 0;
  }
}
