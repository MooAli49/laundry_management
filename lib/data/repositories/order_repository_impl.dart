import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/customer_order_aggregate.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/orders_dao.dart';
import '../local/daos/storage_records_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class OrderRepositoryImpl implements OrderRepository {
  final OrdersDao _ordersDao;
  final StorageRecordsDao _storageRecordsDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  OrderRepositoryImpl({
    required OrdersDao ordersDao,
    required StorageRecordsDao storageRecordsDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _ordersDao = ordersDao,
        _storageRecordsDao = storageRecordsDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
  }) async {
    try {
      if (items.isEmpty) {
        throw ValidationFailure('An order must contain at least one item');
      }

      // Validate subtotal equals sum of items
      var calculatedItemsSubtotal = Money.zero;
      for (final item in items) {
        calculatedItemsSubtotal += item.calculatedTotal;
      }
      if (order.subtotal != calculatedItemsSubtotal) {
        throw ValidationFailure(
          'Order subtotal (${order.subtotal}) must equal sum of item totals ($calculatedItemsSubtotal)',
        );
      }

      const maxRetries = 5;
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          return await _db.transaction(() async {
            final finalOrderNumber = order.orderNumber.isNotEmpty
                ? order.orderNumber
                : await _ordersDao.generateNextOrderNumber();

            // Insert order
            await _ordersDao.insertOrder(
              app_db.OrdersCompanion(
                id: Value(order.id),
                orderNumber: Value(finalOrderNumber),
                customerId: Value(order.customerId),
                customerNameSnapshot: Value(order.customerNameSnapshot),
                customerPhoneSnapshot: Value(order.customerPhoneSnapshot),
                status: Value(order.status.name),
                expectedPickupDate: Value(order.expectedPickupDate.toDateTime()),
                notes: Value(order.notes),
                customerPickupRequested: Value(order.customerPickupRequested),
                customerPickupFee: Value(order.customerPickupFee.piastres),
                customerDeliveryRequested: Value(order.customerDeliveryRequested),
                customerDeliveryFee: Value(order.customerDeliveryFee.piastres),
                subtotal: Value(order.subtotal.piastres),
                discount: Value(order.discount.piastres),
                tax: Value(order.tax.piastres),
                total: Value(order.total.piastres),
                completedAt: Value(order.completedAt),
                cancelledAt: Value(order.cancelledAt),
                cancellationReason: Value(order.cancellationReason),
                createdAt: Value(order.createdAt),
                updatedAt: Value(order.updatedAt),
              ),
            );

            // Insert items & carpets
            for (final item in items) {
              await _ordersDao.insertOrderItem(
                app_db.OrderItemsCompanion(
                  id: Value(item.id),
                  orderId: Value(order.id),
                  itemTypeId: Value(item.itemTypeId),
                  itemDefinitionId: Value(item.itemDefinitionId),
                  serviceId: Value(item.serviceId),
                  itemTypeNameSnapshot: Value(item.itemTypeNameSnapshot),
                  itemDefinitionNameSnapshot: Value(item.itemDefinitionNameSnapshot),
                  serviceNameSnapshot: Value(item.serviceNameSnapshot),
                  pricingType: Value(item.pricingType.name),
                  quantity: Value(item.quantity),
                  unitPrice: Value(item.unitPrice.piastres),
                  calculatedTotal: Value(item.calculatedTotal.piastres),
                  notes: Value(item.notes),
                  createdAt: Value(item.createdAt),
                  updatedAt: Value(item.updatedAt),
                ),
              );

              if (item.carpetData != null) {
                final carpet = item.carpetData!;
                await _ordersDao.insertOrderItemCarpet(
                  app_db.OrderItemCarpetsCompanion(
                    id: Value(carpet.id),
                    orderItemId: Value(item.id),
                    carpetSizeId: Value(carpet.carpetSizeId),
                    length: Value(carpet.length),
                    width: Value(carpet.width),
                    area: Value(carpet.area),
                    createdAt: Value(carpet.createdAt),
                    updatedAt: Value(carpet.updatedAt),
                  ),
                );
              }
            }

            // Record sync operation
            await _syncOperationsDao.recordOperation(
              entityType: 'order',
              entityId: order.id,
              operationType: 'create',
            );

            return order.copyWith(orderNumber: finalOrderNumber);
          });
        } catch (e) {
          final isUniqueConstraint = e.toString().toLowerCase().contains('unique') ||
              e.toString().toLowerCase().contains('sqliteexception(1555)') ||
              e.toString().toLowerCase().contains('orders.order_number');

          if (isUniqueConstraint && attempt < maxRetries && order.orderNumber.isEmpty) {
            // Abort/rollback this failed transaction and retry the ENTIRE creation transaction from the beginning
            continue;
          }
          if (e is Failure) rethrow;
          throw DatabaseFailure(e.toString());
        }
      }
      throw const DatabaseFailure('Failed to generate a unique order number after 5 attempts.');
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> updateOrder(Order order) async {
    try {
      return await _db.transaction(() async {
        final existing = await _ordersDao.getOrderById(order.id);
        if (existing == null) {
          throw ValidationFailure('Order with id ${order.id} not found');
        }

        if (order.orderNumber != existing.orderNumber) {
          throw const BusinessRuleFailure('Order number is immutable and cannot be changed.');
        }

        await _ordersDao.updateOrder(
          app_db.OrdersCompanion(
            id: Value(order.id),
            orderNumber: Value(existing.orderNumber),
            customerId: Value(order.customerId),
            status: Value(order.status.name),
            expectedPickupDate: Value(order.expectedPickupDate.toDateTime()),
            notes: Value(order.notes),
            customerPickupRequested: Value(order.customerPickupRequested),
            customerPickupFee: Value(order.customerPickupFee.piastres),
            customerDeliveryRequested: Value(order.customerDeliveryRequested),
            customerDeliveryFee: Value(order.customerDeliveryFee.piastres),
            subtotal: Value(order.subtotal.piastres),
            discount: Value(order.discount.piastres),
            tax: Value(order.tax.piastres),
            total: Value(order.total.piastres),
            completedAt: Value(order.completedAt),
            cancelledAt: Value(order.cancelledAt),
            cancellationReason: Value(order.cancellationReason),
            createdAt: Value(order.createdAt),
            updatedAt: Value(order.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: order.id,
          operationType: 'update',
        );

        return order.copyWith(orderNumber: existing.orderNumber);
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order?> getOrderById(String id) async {
    try {
      final row = await _ordersDao.getOrderById(id);
      return row != null ? _mapOrderToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order?> getOrderByNumber(String orderNumber) async {
    try {
      final row = await _ordersDao.getOrderByNumber(orderNumber);
      return row != null ? _mapOrderToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    try {
      final rows = await _ordersDao.getOrderItemsWithCarpets(orderId);
      return rows.map((r) => _mapOrderItemToDomain(r.item, r.carpet)).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<OrderItem?> getOrderItemById(String id) async {
    try {
      final row = await _ordersDao.getOrderItemWithCarpetById(id);
      return row != null ? _mapOrderItemToDomain(row.item, row.carpet) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    List<OrderStatus>? excludedStatuses,
    OrderDate? expectedPickupDate,
    bool? isOverdue,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? customerId,
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _ordersDao.getOrders(
        status: status?.name,
        excludedStatuses: excludedStatuses?.map((s) => s.name).toList(),
        expectedPickupDate: expectedPickupDate?.toDateTime(),
        isOverdue: isOverdue,
        createdFrom: createdFrom,
        createdTo: createdTo,
        customerId: customerId,
        hasRemaining: hasRemaining,
        query: query,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapOrderToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Order>> searchOrders({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _ordersDao.searchOrders(
        query: query,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapOrderToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<Order>> watchRecentOrders({int limit = 20}) {
    try {
      return _ordersDao.watchRecentOrders(limit: limit).map(
            (rows) => rows.map(_mapOrderToDomain).toList(),
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<Order?> watchOrderById(String id) {
    try {
      return _ordersDao.watchOrderById(id).map(
            (row) => row != null ? _mapOrderToDomain(row) : null,
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> markOrderReady(String orderId) async {
    try {
      return await _db.transaction(() async {
        final existing = await _ordersDao.getOrderById(orderId);
        if (existing == null) {
          throw ValidationFailure('Order not found');
        }
        if (existing.status != OrderStatus.processing.name) {
          throw BusinessRuleFailure('Only processing orders can be marked ready');
        }

        final now = DateTime.now();
        await _ordersDao.updateOrderStatus(
          orderId: orderId,
          status: OrderStatus.ready.name,
          updatedAt: now,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: orderId,
          operationType: 'mark_ready',
        );

        final updated = await _ordersDao.getOrderById(orderId);
        return _mapOrderToDomain(updated!);
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> completeOrder({
    required String orderId,
    required bool handoverConfirmed,
  }) async {
    try {
      if (!handoverConfirmed) {
        throw BusinessRuleFailure(
          'Customer handover confirmation is required to complete an order',
        );
      }

      return await _db.transaction(() async {
        final existing = await _ordersDao.getOrderById(orderId);
        if (existing == null) {
          throw ValidationFailure('Order not found');
        }
        if (existing.status != OrderStatus.ready.name) {
          if (existing.status == OrderStatus.completed.name) {
            throw BusinessRuleFailure('Order is already completed');
          }
          if (existing.status == OrderStatus.cancelled.name) {
            throw BusinessRuleFailure('Cannot complete a cancelled order');
          }
          throw BusinessRuleFailure('Only Ready orders can be completed');
        }

        // Re-read payments and verify remaining balance == 0
        final payments = await (_db.select(_db.payments)
              ..where((t) => t.orderId.equals(orderId)))
            .get();
        final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
        final remaining = existing.total - totalPaid;
        if (remaining > 0) {
          throw BusinessRuleFailure(
            'Cannot complete order with remaining balance ($remaining piastres)',
          );
        }

        final now = DateTime.now();

        // Release/deactivate active storage records for this order's items upon handover
        final items = await _ordersDao.getOrderItemsRaw(orderId);
        for (final item in items) {
          await _storageRecordsDao.deactivateActiveRecord(item.id, now);
        }

        await _ordersDao.updateOrderStatus(
          orderId: orderId,
          status: OrderStatus.completed.name,
          completedAt: now,
          updatedAt: now,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: orderId,
          operationType: 'complete',
        );

        final updated = await _ordersDao.getOrderById(orderId);
        return _mapOrderToDomain(updated!);
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> cancelOrder({
    required String orderId,
    required String cancellationReason,
  }) async {
    try {
      if (cancellationReason.trim().isEmpty) {
        throw ValidationFailure('Cancellation reason cannot be empty');
      }

      return await _db.transaction(() async {
        final existing = await _ordersDao.getOrderById(orderId);
        if (existing == null) {
          throw ValidationFailure('Order not found');
        }
        if (existing.status == OrderStatus.completed.name) {
          throw BusinessRuleFailure('Cannot cancel an already completed order');
        }
        if (existing.status == OrderStatus.cancelled.name) {
          throw BusinessRuleFailure('Order is already cancelled');
        }

        final now = DateTime.now();

        // Deactivate active storage records upon cancellation
        final items = await _ordersDao.getOrderItemsRaw(orderId);
        for (final item in items) {
          await _storageRecordsDao.deactivateActiveRecord(item.id, now);
        }

        await _ordersDao.updateOrderStatus(
          orderId: orderId,
          status: OrderStatus.cancelled.name,
          cancelledAt: now,
          cancellationReason: cancellationReason.trim(),
          updatedAt: now,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: orderId,
          operationType: 'cancel',
        );

        final updated = await _ordersDao.getOrderById(orderId);
        return _mapOrderToDomain(updated!);
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> correctOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? reason,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await _ordersDao.getOrderById(orderId);
        if (existing == null) {
          throw ValidationFailure('Order not found');
        }

        if (existing.status == OrderStatus.cancelled.name) {
          throw const BusinessRuleFailure('Cancelled orders cannot transition to any other status');
        }

        if (newStatus == OrderStatus.completed) {
          throw const BusinessRuleFailure(
            'Generic transition to Completed is forbidden. Use CompleteOrderUseCase / completeOrder().',
          );
        }

        final now = DateTime.now();
        DateTime? completedAt = existing.completedAt;
        DateTime? cancelledAt = existing.cancelledAt;
        String? cancellationReason = existing.cancellationReason;

        if (existing.status == OrderStatus.ready.name && newStatus == OrderStatus.processing) {
          if (reason == null || reason.trim().isEmpty) {
            throw const ValidationFailure('Operational reason is required to correct Ready order back to Processing');
          }
          // Deactivate ALL currently active StorageRecords belonging to the order's physical OrderItems
          final items = await _ordersDao.getOrderItemsRaw(orderId);
          for (final item in items) {
            await _storageRecordsDao.deactivateActiveRecord(item.id, now);
          }
        } else if (existing.status == OrderStatus.processing.name && newStatus == OrderStatus.ready) {
          if (reason == null || reason.trim().isEmpty) {
            throw const BusinessRuleFailure('Operational reason is required to manually override Processing order to Ready');
          }
          final allStored = await _storageRecordsDao.areAllOrderItemsStored(orderId);
          if (!allStored) {
            throw const BusinessRuleFailure(
              'لا يمكن تحويل الطلب إلى جاهز: لم يتم تخزين جميع القطع بعد',
            );
          }
          // Manual correction with all items stored preserves storage records and sets status to Ready.
        } else if (existing.status == OrderStatus.completed.name && newStatus == OrderStatus.processing) {
          if (reason == null || reason.trim().isEmpty) {
            throw const ValidationFailure('Operational reason is required to correct Completed order back to Processing');
          }
          completedAt = null;
          // Completed -> Processing: storage remains inactive.
        } else if (existing.status == OrderStatus.completed.name && newStatus != OrderStatus.processing) {
          throw const BusinessRuleFailure('Completed orders can only be corrected back to Processing');
        }

        if (newStatus == OrderStatus.cancelled) {
          cancelledAt = now;
          cancellationReason = reason ?? existing.cancellationReason ?? 'تصحيح الحالة';
          final items = await _ordersDao.getOrderItemsRaw(orderId);
          for (final item in items) {
            await _storageRecordsDao.deactivateActiveRecord(item.id, now);
          }
        }

        await _ordersDao.updateOrderStatus(
          orderId: orderId,
          status: newStatus.name,
          completedAt: completedAt,
          cancelledAt: cancelledAt,
          cancellationReason: cancellationReason,
          updatedAt: now,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: orderId,
          operationType: 'status_correction',
          payload: reason,
        );

        final updated = await _ordersDao.getOrderById(orderId);
        return _mapOrderToDomain(updated!);
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  Order _mapOrderToDomain(app_db.Order row) {
    return Order(
      id: row.id,
      orderNumber: row.orderNumber,
      customerId: row.customerId,
      customerNameSnapshot: row.customerNameSnapshot,
      customerPhoneSnapshot: row.customerPhoneSnapshot,
      status: OrderStatus.values.byName(row.status),
      expectedPickupDate: OrderDate.fromDate(row.expectedPickupDate),
      notes: row.notes,
      customerPickupRequested: row.customerPickupRequested,
      customerPickupFee: Money.fromPiastres(row.customerPickupFee),
      customerDeliveryRequested: row.customerDeliveryRequested,
      customerDeliveryFee: Money.fromPiastres(row.customerDeliveryFee),
      subtotal: Money.fromPiastres(row.subtotal),
      discount: Money.fromPiastres(row.discount),
      tax: Money.fromPiastres(row.tax),
      total: Money.fromPiastres(row.total),
      completedAt: row.completedAt,
      cancelledAt: row.cancelledAt,
      cancellationReason: row.cancellationReason,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  OrderItem _mapOrderItemToDomain(
    app_db.OrderItem item,
    app_db.OrderItemCarpet? carpet,
  ) {
    CarpetItemData? carpetData;
    if (carpet != null) {
      carpetData = CarpetItemData(
        id: carpet.id,
        orderItemId: carpet.orderItemId,
        carpetSizeId: carpet.carpetSizeId,
        length: carpet.length,
        width: carpet.width,
        area: carpet.area,
        createdAt: carpet.createdAt,
        updatedAt: carpet.updatedAt,
      );
    }

    return OrderItem(
      id: item.id,
      orderId: item.orderId,
      itemTypeId: item.itemTypeId,
      itemDefinitionId: item.itemDefinitionId,
      serviceId: item.serviceId,
      itemTypeNameSnapshot: item.itemTypeNameSnapshot,
      itemDefinitionNameSnapshot: item.itemDefinitionNameSnapshot,
      serviceNameSnapshot: item.serviceNameSnapshot,
      pricingType: PricingType.values.byName(item.pricingType),
      quantity: item.quantity,
      unitPrice: Money.fromPiastres(item.unitPrice),
      calculatedTotal: Money.fromPiastres(item.calculatedTotal),
      notes: item.notes,
      carpetData: carpetData,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  @override
  Future<int> getOrderCountByCustomerId(String customerId) async {
    try {
      return await _ordersDao.getOrderCountByCustomerId(customerId);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Map<String, int>> getOrderCountsByCustomer() async {
    try {
      return await _ordersDao.getOrderCountsGroupedByCustomer();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Map<String, int>> getOrderCountsByCustomerIds(List<String> customerIds) async {
    try {
      if (customerIds.isEmpty) return {};
      return await _ordersDao.getOrderCountsByCustomerIds(customerIds);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<CustomerOrderAggregate> getCustomerOrderAggregate(String customerId) async {
    try {
      final res = await _ordersDao.getCustomerOrderAggregate(customerId);
      return CustomerOrderAggregate(
        totalOrders: res.totalOrders,
        processingOrders: res.processingOrders,
        readyOrders: res.readyOrders,
        completedOrders: res.completedOrders,
        cancelledOrders: res.cancelledOrders,
        totalPaid: Money.fromPiastres(res.totalPaidPiastres),
        totalRemaining: Money.fromPiastres(res.totalRemainingPiastres),
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }
}
