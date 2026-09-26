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

  Future<void> insertTestOrder(String id, String orderNumber) async {
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: id,
        orderNumber: orderNumber,
        customerId: 'cust-seq',
        expectedPickupDate: now,
        subtotal: 1000,
        total: 1000,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('A. Empty: generates 001 when no orders exist for current year', () async {
    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-001');
  });

  test('B. Normal: 26-001, 26-002, 26-018 => 26-019', () async {
    await insertTestOrder('ord-1', '$yearPrefix-001');
    await insertTestOrder('ord-2', '$yearPrefix-002');
    await insertTestOrder('ord-18', '$yearPrefix-018');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-019');
  });

  test('C. Boundary: 26-999 => 26-1000', () async {
    await insertTestOrder('ord-999', '$yearPrefix-999');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-1000');
  });

  test('D. Continue after expansion: 26-999, 26-1000, 26-1001 => 26-1002', () async {
    await insertTestOrder('ord-999', '$yearPrefix-999');
    await insertTestOrder('ord-1000', '$yearPrefix-1000');
    await insertTestOrder('ord-1001', '$yearPrefix-1001');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-1002');
  });

  test('E. Large numeric suffix: 26-9176612 => 26-9176613', () async {
    await insertTestOrder('ord-large', '$yearPrefix-9176612');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-9176613');
  });

  test('F. Alphanumeric ignored: 26-T548604, 26-R669666, 26-C559809 plus 26-036 => 26-037', () async {
    await insertTestOrder('ord-36', '$yearPrefix-036');
    await insertTestOrder('ord-t', '$yearPrefix-T548604');
    await insertTestOrder('ord-r', '$yearPrefix-R669666');
    await insertTestOrder('ord-c', '$yearPrefix-C559809');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-037');
  });

  test('G. Invalid numeric suffix shorter than minimum (e.g. 26-12) must not participate', () async {
    await insertTestOrder('ord-1', '$yearPrefix-001');
    // 26-12 has only 2 digits, shorter than minimum width 3 digits
    await insertTestOrder('ord-short', '$yearPrefix-12');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(
      nextNumber,
      '$yearPrefix-002',
      reason: '26-12 must not be treated as seq 12; sequence should continue from 26-001 -> 26-002',
    );
  });

  test('H. Multi-hyphen and malformed values ignored', () async {
    await insertTestOrder('ord-1', '$yearPrefix-001');
    await insertTestOrder('ord-abc', '$yearPrefix-ABC');
    await insertTestOrder('ord-extra', '$yearPrefix-001-extra');
    await insertTestOrder('ord-dh', '$yearPrefix--');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-002');
  });

  test('I. Candidate collision: continues to next sequence if candidate exists', () async {
    await insertTestOrder('ord-1', '$yearPrefix-001');
    // Pre-insert candidate 002
    await insertTestOrder('ord-2', '$yearPrefix-002');

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-003');
  });

  test('J. Restart safety: persists across new DAO / database accessor instances', () async {
    await insertTestOrder('ord-1', '$yearPrefix-001');
    final next1 = await ordersDao.generateNextOrderNumber();
    expect(next1, '$yearPrefix-002');

    await insertTestOrder('ord-2', next1);

    // Simulate new DAO instance on the same database
    final newOrdersDao = OrdersDao(db);
    final next2 = await newOrdersDao.generateNextOrderNumber();
    expect(next2, '$yearPrefix-003');
  });

  test('K. Clean UAT sequence after deleting large numbers continues naturally (26-001..26-022 => 26-023)', () async {
    for (int i = 1; i <= 22; i++) {
      final padded = i.toString().padLeft(3, '0');
      await insertTestOrder('ord-$i', '$yearPrefix-$padded');
    }

    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-023');
  });

  test('L. Retained order numbers remain strictly immutable and unchanged', () async {
    await insertTestOrder('ord-19', '$yearPrefix-019');
    await insertTestOrder('ord-20', '$yearPrefix-020');
    await insertTestOrder('ord-21', '$yearPrefix-021');
    await insertTestOrder('ord-22', '$yearPrefix-022');

    final o19 = await ordersDao.getOrderByNumber('$yearPrefix-019');
    final o20 = await ordersDao.getOrderByNumber('$yearPrefix-020');
    final o21 = await ordersDao.getOrderByNumber('$yearPrefix-021');
    final o22 = await ordersDao.getOrderByNumber('$yearPrefix-022');

    expect(o19?.orderNumber, '$yearPrefix-019');
    expect(o20?.orderNumber, '$yearPrefix-020');
    expect(o21?.orderNumber, '$yearPrefix-021');
    expect(o22?.orderNumber, '$yearPrefix-022');

    // Generating next order number does not alter existing orders
    final nextNumber = await ordersDao.generateNextOrderNumber();
    expect(nextNumber, '$yearPrefix-023');

    final o22After = await ordersDao.getOrderByNumber('$yearPrefix-022');
    expect(o22After?.orderNumber, '$yearPrefix-022');
  });
}
