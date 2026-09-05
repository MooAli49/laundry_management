import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/business_settings_dao.dart';
import 'package:laundry_management/data/local/daos/carpet_sizes_dao.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  late AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageLocationsDao storageLocationsDao;
  late StorageRecordsDao storageRecordsDao;
  late ServicesDao servicesDao;
  late ItemTypesDao itemTypesDao;
  late ItemDefinitionsDao itemDefinitionsDao;
  late CarpetSizesDao carpetSizesDao;
  late ExpenseCategoriesDao expenseCategoriesDao;
  late ExpensesDao expensesDao;
  late BusinessSettingsDao businessSettingsDao;
  late SyncOperationsDao syncOperationsDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    servicesDao = ServicesDao(db);
    itemTypesDao = ItemTypesDao(db);
    itemDefinitionsDao = ItemDefinitionsDao(db);
    carpetSizesDao = CarpetSizesDao(db);
    expenseCategoriesDao = ExpenseCategoriesDao(db);
    expensesDao = ExpensesDao(db);
    businessSettingsDao = BusinessSettingsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomersDao', () {
    test('inserts, gets, searches customers, and checks order history', () async {
      final now = DateTime.now();
      await customersDao.insertCustomer(
        CustomersCompanion(
          id: const Value('cust-1'),
          name: const Value('أحمد محمد'),
          phone: const Value('01012345678'),
          notes: const Value('عميل مميز'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final customer = await customersDao.getCustomerById('cust-1');
      expect(customer, isNotNull);
      expect(customer!.name, 'أحمد محمد');

      final byPhone = await customersDao.getCustomerByPhone('01012345678');
      expect(byPhone, isNotNull);
      expect(byPhone!.id, 'cust-1');

      final searchResults = await customersDao.searchCustomers(query: 'أحمد');
      expect(searchResults.length, 1);

      final hasHistory = await customersDao.hasOrderHistory('cust-1');
      expect(hasHistory, isFalse);
    });
  });

  group('OrdersDao', () {
    test('generates incremental sequence number YY-XXX', () async {
      final orderNumber1 = await ordersDao.generateNextOrderNumber();
      final year = (DateTime.now().year % 100).toString().padLeft(2, '0');
      expect(orderNumber1, '$year-001');

      final now = DateTime.now();
      await customersDao.insertCustomer(
        CustomersCompanion(
          id: const Value('cust-1'),
          name: const Value('محمود'),
          phone: const Value('01099998888'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await ordersDao.insertOrder(
        OrdersCompanion(
          id: const Value('ord-1'),
          orderNumber: Value(orderNumber1),
          customerId: const Value('cust-1'),
          expectedPickupDate: Value(now),
          subtotal: const Value(5000),
          total: const Value(5000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final orderNumber2 = await ordersDao.generateNextOrderNumber();
      expect(orderNumber2, '$year-002');
    });

    test('inserts order with items and carpet details and queries them', () async {
      final now = DateTime.now();
      await customersDao.insertCustomer(
        CustomersCompanion(
          id: const Value('cust-1'),
          name: const Value('خالد'),
          phone: const Value('01011112222'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Get seeded item type and create service
      final itemTypes = await itemTypesDao.getAllItemTypes();
      final carpetType = itemTypes.firstWhere((t) => t.name == 'سجاد');

      await servicesDao.insertService(
        ServicesCompanion(
          id: const Value('srv-1'),
          name: const Value('غسيل سجاد'),
          pricingType: const Value('perSquareMeter'),
          price: const Value(3000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await ordersDao.insertOrder(
        OrdersCompanion(
          id: const Value('ord-1'),
          orderNumber: const Value('26-001'),
          customerId: const Value('cust-1'),
          expectedPickupDate: Value(now),
          subtotal: const Value(18000),
          total: const Value(18000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await ordersDao.insertOrderItem(
        OrderItemsCompanion(
          id: const Value('item-1'),
          orderId: const Value('ord-1'),
          itemTypeId: Value(carpetType.id),
          serviceId: const Value('srv-1'),
          itemTypeNameSnapshot: const Value('سجاد'),
          serviceNameSnapshot: const Value('غسيل سجاد'),
          pricingType: const Value('perSquareMeter'),
          quantity: const Value(6.0),
          unitPrice: const Value(3000),
          calculatedTotal: const Value(18000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await ordersDao.insertOrderItemCarpet(
        OrderItemCarpetsCompanion(
          id: const Value('carpet-1'),
          orderItemId: const Value('item-1'),
          length: const Value(2.0),
          width: const Value(3.0),
          area: const Value(6.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final itemsWithCarpets = await ordersDao.getOrderItemsWithCarpets('ord-1');
      expect(itemsWithCarpets.length, 1);
      expect(itemsWithCarpets.first.item.id, 'item-1');
      expect(itemsWithCarpets.first.carpet, isNotNull);
      expect(itemsWithCarpets.first.carpet!.area, 6.0);
    });
  });

  group('PaymentsDao', () {
    test('inserts payment and calculates total paid', () async {
      final now = DateTime.now();
      await customersDao.insertCustomer(
        CustomersCompanion(
          id: const Value('cust-1'),
          name: const Value('تامر'),
          phone: const Value('01022223333'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await ordersDao.insertOrder(
        OrdersCompanion(
          id: const Value('ord-10'),
          orderNumber: const Value('26-010'),
          customerId: const Value('cust-1'),
          expectedPickupDate: Value(now),
          subtotal: const Value(5000),
          total: const Value(5000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await paymentsDao.insertPayment(
        PaymentsCompanion(
          id: const Value('pay-1'),
          orderId: const Value('ord-10'),
          amount: const Value(2000),
          paymentMethod: const Value('cash'),
          paidAt: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await paymentsDao.insertPayment(
        PaymentsCompanion(
          id: const Value('pay-2'),
          orderId: const Value('ord-10'),
          amount: const Value(3000),
          paymentMethod: const Value('instapay'),
          paidAt: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final payments = await paymentsDao.getPaymentsForOrder('ord-10');
      expect(payments.length, 2);

      final totalPaid = await paymentsDao.getTotalPaidForOrder('ord-10');
      expect(totalPaid, 5000);
    });
  });

  group('StorageRecordsDao & StorageLocationsDao', () {
    test('enforces storage location links and active record tracking', () async {
      final now = DateTime.now();
      await storageLocationsDao.insertLocation(
        StorageLocationsCompanion(
          id: const Value('loc-1'),
          name: const Value('رف 1'),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final locations = await storageLocationsDao.getActiveLocations();
      expect(locations.length, 1);
      expect(locations.first.name, 'رف 1');

      // Setup customer, order, and item for storage
      await customersDao.insertCustomer(
        CustomersCompanion(
          id: const Value('cust-1'),
          name: const Value('سعيد'),
          phone: const Value('01033334444'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final itemTypes = await itemTypesDao.getAllItemTypes();
      await servicesDao.insertService(
        ServicesCompanion(
          id: const Value('srv-1'),
          name: const Value('غسيل'),
          pricingType: const Value('perPiece'),
          price: const Value(1000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await ordersDao.insertOrder(
        OrdersCompanion(
          id: const Value('ord-1'),
          orderNumber: const Value('26-001'),
          customerId: const Value('cust-1'),
          expectedPickupDate: Value(now),
          subtotal: const Value(1000),
          total: const Value(1000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await ordersDao.insertOrderItem(
        OrderItemsCompanion(
          id: const Value('item-1'),
          orderId: const Value('ord-1'),
          itemTypeId: Value(itemTypes.first.id),
          serviceId: const Value('srv-1'),
          itemTypeNameSnapshot: const Value('ملابس'),
          serviceNameSnapshot: const Value('غسيل'),
          pricingType: const Value('perPiece'),
          quantity: const Value(1.0),
          unitPrice: const Value(1000),
          calculatedTotal: const Value(1000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Store item
      await storageRecordsDao.insertRecord(
        StorageRecordsCompanion(
          id: const Value('rec-1'),
          orderItemId: const Value('item-1'),
          storageLocationId: const Value('loc-1'),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final activeRec = await storageRecordsDao.getActiveRecordForOrderItem('item-1');
      expect(activeRec, isNotNull);
      expect(activeRec!.storageLocationId, 'loc-1');

      final allStored = await storageRecordsDao.areAllOrderItemsStored('ord-1');
      expect(allStored, isTrue);

      // Deactivate record
      await storageRecordsDao.deactivateActiveRecord('item-1', DateTime.now());
      final afterDeactivation = await storageRecordsDao.getActiveRecordForOrderItem('item-1');
      expect(afterDeactivation, isNull);
    });
  });

  group('ItemDefinitionsDao & CarpetSizesDao & ExpenseCategoriesDao', () {
    test('manages auxiliary entities and definitions', () async {
      final now = DateTime.now();
      final itemTypes = await itemTypesDao.getAllItemTypes();

      await itemDefinitionsDao.insertItemDefinition(
        ItemDefinitionsCompanion(
          id: const Value('def-1'),
          itemTypeId: Value(itemTypes.first.id),
          name: const Value('قميص حرير'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final defs = await itemDefinitionsDao.getDefinitionsForItemType(itemTypes.first.id);
      expect(defs.length, 1);
      expect(defs.first.name, 'قميص حرير');

      await carpetSizesDao.insertCarpetSize(
        CarpetSizesCompanion(
          id: const Value('cs-1'),
          length: const Value(2.0),
          width: const Value(3.0),
          area: const Value(6.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final carpetSizes = await carpetSizesDao.getActiveCarpetSizes();
      expect(carpetSizes.length, 1);
      expect(carpetSizes.first.area, 6.0);

      final expenseCats = await expenseCategoriesDao.getAllCategories();
      expect(expenseCats.isNotEmpty, isTrue);
    });
  });

  group('ExpensesDao & BusinessSettingsDao', () {
    test('records expenses and calculates totals', () async {
      final now = DateTime.now();
      final expenseCats = await expenseCategoriesDao.getAllCategories();

      await expensesDao.insertExpense(
        ExpensesCompanion(
          id: const Value('exp-1'),
          expenseCategoryId: Value(expenseCats.first.id),
          amount: const Value(5000),
          expenseDate: Value(now),
          categoryNameSnapshot: Value(expenseCats.first.name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final total = await expensesDao.getTotalExpenses(
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 1)),
      );
      expect(total, 5000);

      final settings = await businessSettingsDao.getSettings();
      expect(settings, isNotNull);
      expect(settings.id, '00000000-0000-0000-0000-000000000001');
    });
  });

  group('SyncOperationsDao', () {
    test('records sync operations and updates status', () async {
      await syncOperationsDao.recordOperation(
        entityType: 'order',
        entityId: 'ord-123',
        operationType: 'create',
      );

      final pending = await syncOperationsDao.getPendingOperations();
      expect(pending.length, 1);
      expect(pending.first.entityId, 'ord-123');
      expect(pending.first.status, 'pending');

      await syncOperationsDao.markOperationCompleted(pending.first.id);
      final pendingAfterComplete = await syncOperationsDao.getPendingOperations();
      expect(pendingAfterComplete.isEmpty, isTrue);
    });
  });
}
