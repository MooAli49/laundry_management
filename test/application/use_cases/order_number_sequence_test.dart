import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  late AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;

  final now = DateTime.now();
  final yearPrefix = (now.year % 100).toString().padLeft(2, '0');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);

    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: 'cust-seq',
        name: 'عميل تسلسل',
        phone: '01099998888',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('generates 001 when no orders exist for the current year', () async {
    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-001');
  });

  test('increments sequentially beyond 999 without lexical sorting bug (e.g. 999 -> 1000 -> 1001)', () async {
    // Insert order with sequence 999
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-999',
        orderNumber: '$yearPrefix-999',
        customerId: 'cust-seq',
        expectedPickupDate: now,
        subtotal: 1000,
        total: 1000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Next number should be 1000
    final nextNumber1000 = await ordersDao.generateNextOrderNumber();
    expect(nextNumber1000, '$yearPrefix-1000');

    // Insert order with sequence 1000
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-1000',
        orderNumber: '$yearPrefix-1000',
        customerId: 'cust-seq',
        expectedPickupDate: now,
        subtotal: 1000,
        total: 1000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Next number must be 1001, NOT duplicate 1000 due to '26-999' > '26-1000' lexical sort
    final nextNumber1001 = await ordersDao.generateNextOrderNumber();
    expect(
      nextNumber1001,
      '$yearPrefix-1001',
      reason: 'Length-aware sorting ensures 26-1000 takes precedence over 26-999',
    );
  });
}
