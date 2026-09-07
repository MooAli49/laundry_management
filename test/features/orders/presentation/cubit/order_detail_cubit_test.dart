import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/cancel_order_use_case.dart';
import 'package:laundry_management/application/use_cases/change_order_status_use_case.dart';
import 'package:laundry_management/application/use_cases/complete_order_use_case.dart';
import 'package:laundry_management/application/use_cases/store_order_items_use_case.dart';
import 'package:laundry_management/data/local/daos/business_settings_dao.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/settings_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_location_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/cubit/order_detail_cubit.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageLocationsDao storageLocationsDao;
  late StorageRecordsDao storageRecordsDao;
  late ServicesDao servicesDao;
  late BusinessSettingsDao businessSettingsDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;
  late StorageRepositoryImpl storageRepository;
  late StorageLocationRepositoryImpl storageLocationRepository;
  late SettingsRepositoryImpl settingsRepository;

  late StoreOrderItemsUseCase storeOrderItemsUseCase;
  late ChangeOrderStatusUseCase changeOrderStatusUseCase;
  late CompleteOrderUseCase completeOrderUseCase;
  late CancelOrderUseCase cancelOrderUseCase;

  late OrderDetailCubit cubit;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    servicesDao = ServicesDao(db);
    businessSettingsDao = BusinessSettingsDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    storageRepository = StorageRepositoryImpl(
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    storageLocationRepository = StorageLocationRepositoryImpl(
      storageLocationsDao: storageLocationsDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    settingsRepository = SettingsRepositoryImpl(
      settingsDao: businessSettingsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    storeOrderItemsUseCase = StoreOrderItemsUseCase(
      orderRepository: orderRepository,
      storageRepository: storageRepository,
      storageLocationRepository: storageLocationRepository,
    );

    changeOrderStatusUseCase = ChangeOrderStatusUseCase(orderRepository);

    completeOrderUseCase = CompleteOrderUseCase(
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );

    cancelOrderUseCase = CancelOrderUseCase(orderRepository);

    cubit = OrderDetailCubit(
      orderRepository: orderRepository,
      customerRepository: customerRepository,
      paymentRepository: paymentRepository,
      storageRepository: storageRepository,
      storageLocationRepository: storageLocationRepository,
      settingsRepository: settingsRepository,
      storeOrderItemsUseCase: storeOrderItemsUseCase,
      changeOrderStatusUseCase: changeOrderStatusUseCase,
      completeOrderUseCase: completeOrderUseCase,
      cancelOrderUseCase: cancelOrderUseCase,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  Future<void> seedTestOrder({
    required String orderId,
    required String customerId,
    required int totalPiastres,
  }) async {
    final now = DateTime.now();
    await customerRepository.createCustomer(
      Customer(
        id: customerId,
        name: 'عميل تجريبي',
        phone: '01012345678',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final itemTypes = await db.select(db.itemTypes).get();

    await storageLocationRepository.createStorageLocation(
      StorageLocation(
        id: 'loc-1',
        name: 'رف A-1',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      supportedItemTypeIds: [itemTypes.first.id],
    );

    await servicesDao.insertService(
      db_pkg.ServicesCompanion.insert(
        id: 'srv-$orderId',
        name: 'غسيل وكي $orderId',
        pricingType: 'perPiece',
        price: totalPiastres ~/ 2,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final order = Order(
      id: orderId,
      orderNumber: '26-001',
      customerId: customerId,
      expectedPickupDate: OrderDate(2026, 9, 15),
      subtotal: Money.fromPiastres(totalPiastres),
      total: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    final item1 = OrderItem(
      id: 'item-1-$orderId',
      orderId: orderId,
      itemTypeId: itemTypes.first.id,
      serviceId: 'srv-$orderId',
      itemTypeNameSnapshot: 'قميص',
      serviceNameSnapshot: 'غسيل وكي',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: Money.fromPiastres(totalPiastres ~/ 2),
      calculatedTotal: Money.fromPiastres(totalPiastres ~/ 2),
      createdAt: now,
      updatedAt: now,
    );

    final item2 = OrderItem(
      id: 'item-2-$orderId',
      orderId: orderId,
      itemTypeId: itemTypes.first.id,
      serviceId: 'srv-$orderId',
      itemTypeNameSnapshot: 'بنطلون',
      serviceNameSnapshot: 'غسيل وكي',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: Money.fromPiastres(totalPiastres ~/ 2),
      calculatedTotal: Money.fromPiastres(totalPiastres ~/ 2),
      createdAt: now,
      updatedAt: now,
    );

    await orderRepository.createOrder(order: order, items: [item1, item2]);
  }

  group('OrderDetailCubit', () {
    test('loadOrderDetail populates order, items, customer, and remaining amount', () async {
      await seedTestOrder(orderId: 'ord-1', customerId: 'cust-1', totalPiastres: 10000);

      await cubit.loadOrderDetail('ord-1');

      expect(cubit.state.order, isNotNull);
      expect(cubit.state.order!.orderNumber, '26-001');
      expect(cubit.state.customer?.name, 'عميل تجريبي');
      expect(cubit.state.items.length, 2);
      expect(cubit.state.remainingAmount, const Money.fromPiastres(10000));
      expect(cubit.state.allItemsStored, isFalse);
      expect(cubit.state.unstoredItems.length, 2);
    });

    test('recordPayment rejects overpayment and records valid payment', () async {
      await seedTestOrder(orderId: 'ord-2', customerId: 'cust-2', totalPiastres: 10000);
      await cubit.loadOrderDetail('ord-2');

      // Overpayment: 120 EGP (12000 piastres)
      await cubit.recordPayment(
        amount: const Money.fromPiastres(12000),
        method: PaymentMethod.cash,
      );

      expect(cubit.state.errorMessage, contains('يتجاوز المبلغ المتبقي'));
      expect(cubit.state.totalPaid, Money.zero);

      // Valid payment: 40 EGP (4000 piastres)
      await cubit.recordPayment(
        amount: const Money.fromPiastres(4000),
        method: PaymentMethod.instapay,
      );

      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.totalPaid, const Money.fromPiastres(4000));
      expect(cubit.state.remainingAmount, const Money.fromPiastres(6000));
      expect(cubit.state.payments.length, 1);
    });

    test('storeItems stores items and marks order ready when all items stored', () async {
      await seedTestOrder(orderId: 'ord-3', customerId: 'cust-3', totalPiastres: 10000);
      await cubit.loadOrderDetail('ord-3');

      expect(cubit.state.order!.status, OrderStatus.processing);

      // Store both items in loc-1
      await cubit.storeItems(
        orderItemIds: ['item-1-ord-3', 'item-2-ord-3'],
        storageLocationId: 'loc-1',
      );

      expect(cubit.state.allItemsStored, isTrue);
      expect(cubit.state.unstoredItems, isEmpty);
      expect(cubit.state.activeStorageRecords.length, 2);

      // Verify order automatically became ready
      expect(cubit.state.order!.status, OrderStatus.ready);
    });

    test('completeOrder enforces ready status, remaining == 0, and handover confirmation', () async {
      await seedTestOrder(orderId: 'ord-4', customerId: 'cust-4', totalPiastres: 10000);
      await cubit.loadOrderDetail('ord-4');

      // Attempt complete while processing and unpaid -> fails
      await cubit.completeOrder(handoverConfirmed: true);
      expect(cubit.state.errorMessage, contains('جاهز'));

      // Store items to transition to ready
      await cubit.storeItems(
        orderItemIds: ['item-1-ord-4', 'item-2-ord-4'],
        storageLocationId: 'loc-1',
      );
      expect(cubit.state.order!.status, OrderStatus.ready);

      // Attempt complete without full payment -> fails
      await cubit.completeOrder(handoverConfirmed: true);
      expect(cubit.state.errorMessage, contains('سداد كامل المبلغ'));

      // Pay remaining in full (100 EGP)
      await cubit.recordPayment(
        amount: const Money.fromPiastres(10000),
        method: PaymentMethod.cash,
      );
      expect(cubit.state.remainingAmount, Money.zero);

      // Attempt complete without handover confirmation -> fails
      await cubit.completeOrder(handoverConfirmed: false);
      expect(cubit.state.errorMessage, contains('تأكيد تسليم'));

      // Valid completion!
      await cubit.completeOrder(handoverConfirmed: true);
      expect(cubit.state.order!.status, OrderStatus.completed);
      expect(cubit.state.order!.completedAt, isNotNull);

      // Verify storage records deactivated
      final activeRecord = await storageRepository.getActiveRecordForOrderItem('item-1-ord-4');
      expect(activeRecord, isNull);
    });

    test('cancelOrder requires reason and deactivates storage', () async {
      await seedTestOrder(orderId: 'ord-5', customerId: 'cust-5', totalPiastres: 10000);
      await cubit.loadOrderDetail('ord-5');

      // Store item 1
      await cubit.storeItems(
        orderItemIds: ['item-1-ord-5'],
        storageLocationId: 'loc-1',
      );

      // Empty reason -> fails
      await cubit.cancelOrder(cancellationReason: '   ');
      expect(cubit.state.errorMessage, contains('سبب الإلغاء مطلوب'));

      // Valid cancellation
      await cubit.cancelOrder(cancellationReason: 'العميل تراجع عن الطلب');
      expect(cubit.state.order!.status, OrderStatus.cancelled);
      expect(cubit.state.order!.cancellationReason, 'العميل تراجع عن الطلب');

      // Verify storage deactivated
      final activeRecord = await storageRepository.getActiveRecordForOrderItem('item-1-ord-5');
      expect(activeRecord, isNull);
    });

    test('changeStatus blocks transitioning to completed directly', () async {
      await seedTestOrder(orderId: 'ord-6', customerId: 'cust-6', totalPiastres: 10000);
      await cubit.loadOrderDetail('ord-6');

      await cubit.changeStatus(newStatus: OrderStatus.completed);
      expect(cubit.state.errorMessage, contains('استخدام زر "إكمال الطلب"'));
      expect(cubit.state.order!.status, OrderStatus.processing);
    });
  });
}
