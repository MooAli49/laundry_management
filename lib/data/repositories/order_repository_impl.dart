import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/use_cases/edit_processing_order_use_case.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/customer_order_aggregate.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/orders_dao.dart';
import '../local/daos/payments_dao.dart';
import '../local/daos/storage_records_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;
import '../sync/sync_payload_builder.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrdersDao _ordersDao;
  final StorageRecordsDao _storageRecordsDao;
  final SyncOperationsDao _syncOperationsDao;
  final PaymentsDao _paymentsDao;
  final app_db.AppDatabase _db;

  OrderRepositoryImpl({
    required OrdersDao ordersDao,
    required StorageRecordsDao storageRecordsDao,
    required SyncOperationsDao syncOperationsDao,
    required PaymentsDao paymentsDao,
    required app_db.AppDatabase db,
  }) : _ordersDao = ordersDao,
       _storageRecordsDao = storageRecordsDao,
       _syncOperationsDao = syncOperationsDao,
       _paymentsDao = paymentsDao,
       _db = db;

  @override
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
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
                expectedPickupDate: Value(
                  order.expectedPickupDate.toDateTime(),
                ),
                notes: Value(order.notes),
                customerPickupRequested: Value(order.customerPickupRequested),
                customerPickupFee: Value(order.customerPickupFee.piastres),
                customerDeliveryRequested: Value(
                  order.customerDeliveryRequested,
                ),
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
                  itemDefinitionNameSnapshot: Value(
                    item.itemDefinitionNameSnapshot,
                  ),
                  serviceNameSnapshot: Value(item.serviceNameSnapshot),
                  pricingType: Value(item.pricingType.value),
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

            final committedOrder = order.copyWith(
              orderNumber: finalOrderNumber,
            );

            // Record sync operation
            await _syncOperationsDao.recordOperation(
              entityType: 'order',
              entityId: order.id,
              operationType: 'create',
              payload: SyncPayloadBuilder.buildOrderCreatePayload(
                committedOrder,
                items,
              ),
            );

            // Handle initial payment if provided
            if (initialPayment != null) {
              if (initialPayment.orderId != order.id) {
                throw const ValidationFailure(
                  'Payment orderId must match order id',
                );
              }
              if (initialPayment.amount.piastres <= 0) {
                throw const ValidationFailure(
                  'Payment amount must be greater than zero',
                );
              }
              if (initialPayment.amount > order.total) {
                throw const BusinessRuleFailure(
                  'Payment amount exceeds remaining order balance',
                );
              }

              await _paymentsDao.insertPayment(
                app_db.PaymentsCompanion(
                  id: Value(initialPayment.id),
                  orderId: Value(order.id),
                  amount: Value(initialPayment.amount.piastres),
                  paymentMethod: Value(initialPayment.paymentMethod.name),
                  paidAt: Value(initialPayment.paidAt),
                  createdAt: Value(initialPayment.createdAt),
                  updatedAt: Value(initialPayment.updatedAt),
                ),
              );

              await _syncOperationsDao.recordOperation(
                entityType: 'payment',
                entityId: initialPayment.id,
                operationType: 'create',
                payload: SyncPayloadBuilder.buildPaymentPayload(initialPayment),
              );
            }

            return committedOrder;
          });
        } catch (e) {
          final isUniqueConstraint =
              e.toString().toLowerCase().contains('unique') ||
              e.toString().toLowerCase().contains('sqliteexception(1555)') ||
              e.toString().toLowerCase().contains('orders.order_number');

          if (isUniqueConstraint &&
              attempt < maxRetries &&
              order.orderNumber.isEmpty) {
            // Abort/rollback this failed transaction and retry the ENTIRE creation transaction from the beginning
            continue;
          }
          if (e is Failure) rethrow;
          throw DatabaseFailure(e.toString());
        }
      }
      throw const DatabaseFailure(
        'Failed to generate a unique order number after 5 attempts.',
      );
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Order> editProcessingOrder(EditProcessingOrderInput input) async {
    try {
      return await _db.transaction(() async {
        // 1. Fetch existing order
        final existingRow = await _ordersDao.getOrderById(input.orderId);
        if (existingRow == null) {
          throw const ValidationFailure('Order not found');
        }

        // 2. Reject non-processing orders
        if (existingRow.status != OrderStatus.processing.name) {
          throw BusinessRuleFailure(
            'Cannot edit order in status: ${existingRow.status}. Only processing orders can be edited.',
          );
        }

        // 3. Read total paid for financial validation
        final totalPaidPiastres =
            await _paymentsDao.getTotalPaidForOrder(input.orderId);
        final totalPaid = Money.fromPiastres(totalPaidPiastres);

        // 4. Customer change validation
        var customerId = existingRow.customerId;
        var customerNameSnapshot = existingRow.customerNameSnapshot;
        var customerPhoneSnapshot = existingRow.customerPhoneSnapshot;

        if (input.customerId != existingRow.customerId) {
          if (totalPaid > Money.zero) {
            throw const BusinessRuleFailure(
              'Cannot change customer on an order with recorded payments',
            );
          }
          final newCustomerRow = await (_db.select(_db.customers)
                ..where((t) => t.id.equals(input.customerId)))
              .getSingleOrNull();
          if (newCustomerRow == null) {
            throw const ValidationFailure('Customer not found');
          }
          customerId = newCustomerRow.id;
          customerNameSnapshot = newCustomerRow.name;
          customerPhoneSnapshot = newCustomerRow.phone;
        }

        // 5. Existing items and carpets
        final existingItemAndCarpetRows =
            await _ordersDao.getOrderItemsWithCarpets(input.orderId);
        final existingItemsMap = {
          for (final r in existingItemAndCarpetRows) r.item.id: r,
        };

        // 6. Validate item deletions (storage records deletion guard)
        for (final deletedId in input.deletedItemIds) {
          if (!existingItemsMap.containsKey(deletedId)) {
            throw ValidationFailure('Item to delete not found: $deletedId');
          }
          final storageCount =
              await _storageRecordsDao.countAllRecordsForOrderItem(deletedId);
          if (storageCount > 0) {
            throw BusinessRuleFailure(
              'Cannot delete item with storage records: $deletedId',
            );
          }
        }

        // 7. Validate and prepare modified items
        final now = DateTime.now();
        final survivingExistingIds = existingItemsMap.keys
            .toSet()
            .difference(input.deletedItemIds.toSet());

        final updatedItemsMap = <String, ({
          app_db.OrderItemsCompanion item,
          app_db.OrderItemCarpetsCompanion? carpet,
          Money total,
        })>{};

        for (final mod in input.modifiedItems) {
          if (!survivingExistingIds.contains(mod.id)) {
            throw ValidationFailure(
              'Modified item not found or deleted: ${mod.id}',
            );
          }
          final existing = existingItemsMap[mod.id]!;
          final existingItem = existing.item;

          // item_type_id is immutable for existing items
          final itemTypeId = existingItem.itemTypeId;
          final itemTypeNameSnapshot = existingItem.itemTypeNameSnapshot;

          // Validate service
          final serviceRow = await (_db.select(_db.services)
                ..where((t) => t.id.equals(mod.serviceId)))
              .getSingleOrNull();
          if (serviceRow == null) {
            throw const ValidationFailure('Service not found');
          }
          if (!serviceRow.isActive) {
            throw const BusinessRuleFailure('Service is inactive');
          }

          // Verify service compatibility with itemTypeId via service_item_types
          final isServiceCompatible = await (_db.select(_db.serviceItemTypes)
                ..where(
                  (t) =>
                      t.serviceId.equals(mod.serviceId) &
                      t.itemTypeId.equals(itemTypeId),
                ))
              .getSingleOrNull();
          if (isServiceCompatible == null) {
            throw IncompatibleServiceFailure(
              serviceId: mod.serviceId,
              itemTypeId: itemTypeId,
            );
          }

          // Validate item definition if provided
          String? itemDefNameSnapshot =
              existingItem.itemDefinitionNameSnapshot;
          if (mod.itemDefinitionId != null) {
            final defRow = await (_db.select(_db.itemDefinitions)
                  ..where((t) => t.id.equals(mod.itemDefinitionId!)))
                .getSingleOrNull();
            if (defRow == null) {
              throw const ValidationFailure('Item definition not found');
            }
            if (defRow.itemTypeId != itemTypeId) {
              throw const BusinessRuleFailure(
                'Item definition does not belong to the selected item type',
              );
            }
            itemDefNameSnapshot = defRow.name;
          } else {
            itemDefNameSnapshot = null;
          }

          final unitPrice =
              mod.customUnitPrice ?? Money.fromPiastres(serviceRow.price);
          if (unitPrice <= Money.zero) {
            throw const ValidationFailure(
              'Unit price must be strictly greater than zero',
            );
          }

          final pricingType = PricingType.fromValue(serviceRow.pricingType);
          Money calculatedTotal;
          app_db.OrderItemCarpetsCompanion? carpetCompanion;

          if (pricingType == PricingType.perSquareMeter) {
            if (mod.carpetData == null) {
              throw const ValidationFailure(
                'Carpet data is required for per-square-meter services',
              );
            }
            if (mod.carpetData!.length <= 0 || mod.carpetData!.width <= 0) {
              throw const ValidationFailure(
                'Carpet dimensions must be greater than zero',
              );
            }
            final area = mod.carpetData!.length * mod.carpetData!.width;
            calculatedTotal = Money.fromPiastres(
              (unitPrice.piastres * area).round(),
            );

            final existingCarpet = existing.carpet;
            final carpetId = existingCarpet?.id ?? const Uuid().v4();
            carpetCompanion = app_db.OrderItemCarpetsCompanion(
              id: Value(carpetId),
              orderItemId: Value(mod.id),
              carpetSizeId: Value(mod.carpetData!.carpetSizeId),
              length: Value(mod.carpetData!.length),
              width: Value(mod.carpetData!.width),
              area: Value(area),
              createdAt: Value(existingCarpet?.createdAt ?? now),
              updatedAt: Value(now),
            );
          } else {
            if (mod.carpetData != null) {
              throw const ValidationFailure(
                'Carpet data is not allowed for non-carpet pricing types',
              );
            }
            calculatedTotal = unitPrice;
          }

          updatedItemsMap[mod.id] = (
            item: app_db.OrderItemsCompanion(
              id: Value(mod.id),
              orderId: Value(input.orderId),
              itemTypeId: Value(itemTypeId),
              itemDefinitionId: Value(mod.itemDefinitionId),
              serviceId: Value(mod.serviceId),
              itemTypeNameSnapshot: Value(itemTypeNameSnapshot),
              itemDefinitionNameSnapshot: Value(itemDefNameSnapshot),
              serviceNameSnapshot: Value(serviceRow.name),
              pricingType: Value(pricingType.value),
              quantity: Value(
                pricingType == PricingType.perSquareMeter
                    ? (mod.carpetData!.length * mod.carpetData!.width)
                    : 1.0,
              ),
              unitPrice: Value(unitPrice.piastres),
              calculatedTotal: Value(calculatedTotal.piastres),
              notes: Value(mod.notes),
              updatedAt: Value(now),
            ),
            carpet: carpetCompanion,
            total: calculatedTotal,
          );
        }

        // 8. Validate and prepare brand new items
        final newItemsList = <({
          app_db.OrderItemsCompanion item,
          app_db.OrderItemCarpetsCompanion? carpet,
          Money total,
        })>[];

        for (final newItemInput in input.newItems) {
          if (newItemInput.physicalQuantity <= 0) {
            throw const ValidationFailure(
              'Physical quantity must be greater than zero',
            );
          }

          final itemType = await (_db.select(_db.itemTypes)
                ..where((t) => t.id.equals(newItemInput.itemTypeId)))
              .getSingleOrNull();
          if (itemType == null) {
            throw const ValidationFailure('Item type not found');
          }
          if (!itemType.isActive) {
            throw const BusinessRuleFailure('Item type is inactive');
          }

          String? itemDefName;
          if (newItemInput.itemDefinitionId != null) {
            final def = await (_db.select(_db.itemDefinitions)
                  ..where((t) => t.id.equals(newItemInput.itemDefinitionId!)))
                .getSingleOrNull();
            if (def == null) {
              throw const ValidationFailure('Item definition not found');
            }
            if (def.itemTypeId != itemType.id) {
              throw const BusinessRuleFailure(
                'Item definition does not belong to the selected item type',
              );
            }
            itemDefName = def.name;
          }

          final service = await (_db.select(_db.services)
                ..where((t) => t.id.equals(newItemInput.serviceId)))
              .getSingleOrNull();
          if (service == null) {
            throw const ValidationFailure('Service not found');
          }
          if (!service.isActive) {
            throw const BusinessRuleFailure('Service is inactive');
          }

          final isComp = await (_db.select(_db.serviceItemTypes)
                ..where(
                  (t) =>
                      t.serviceId.equals(service.id) &
                      t.itemTypeId.equals(itemType.id),
                ))
              .getSingleOrNull();
          if (isComp == null) {
            throw IncompatibleServiceFailure(
              serviceId: service.id,
              itemTypeId: itemType.id,
            );
          }

          final unitPrice =
              newItemInput.customUnitPrice ??
              Money.fromPiastres(service.price);
          if (unitPrice <= Money.zero) {
            throw const ValidationFailure(
              'Unit price must be strictly greater than zero',
            );
          }

          final pricingType = PricingType.fromValue(service.pricingType);

          if (pricingType == PricingType.perSquareMeter) {
            if (newItemInput.carpetData == null) {
              throw const ValidationFailure(
                'Carpet data is required for per-square-meter services',
              );
            }
            if (newItemInput.carpetData!.length <= 0 ||
                newItemInput.carpetData!.width <= 0) {
              throw const ValidationFailure(
                'Carpet dimensions must be greater than zero',
              );
            }
            final area =
                newItemInput.carpetData!.length * newItemInput.carpetData!.width;
            final calcTotal = Money.fromPiastres(
              (unitPrice.piastres * area).round(),
            );

            for (var i = 0; i < newItemInput.physicalQuantity; i++) {
              final itemId = const Uuid().v4();
              final carpetId = const Uuid().v4();
              newItemsList.add((
                item: app_db.OrderItemsCompanion(
                  id: Value(itemId),
                  orderId: Value(input.orderId),
                  itemTypeId: Value(itemType.id),
                  itemDefinitionId: Value(newItemInput.itemDefinitionId),
                  serviceId: Value(service.id),
                  itemTypeNameSnapshot: Value(itemType.name),
                  itemDefinitionNameSnapshot: Value(itemDefName),
                  serviceNameSnapshot: Value(service.name),
                  pricingType: Value(pricingType.value),
                  quantity: Value(area),
                  unitPrice: Value(unitPrice.piastres),
                  calculatedTotal: Value(calcTotal.piastres),
                  notes: Value(newItemInput.notes),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
                carpet: app_db.OrderItemCarpetsCompanion(
                  id: Value(carpetId),
                  orderItemId: Value(itemId),
                  carpetSizeId: Value(newItemInput.carpetData!.carpetSizeId),
                  length: Value(newItemInput.carpetData!.length),
                  width: Value(newItemInput.carpetData!.width),
                  area: Value(area),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
                total: calcTotal,
              ));
            }
          } else {
            if (newItemInput.carpetData != null) {
              throw const ValidationFailure(
                'Carpet data is not allowed for non-carpet pricing types',
              );
            }
            final calcTotal = unitPrice;
            for (var i = 0; i < newItemInput.physicalQuantity; i++) {
              final itemId = const Uuid().v4();
              newItemsList.add((
                item: app_db.OrderItemsCompanion(
                  id: Value(itemId),
                  orderId: Value(input.orderId),
                  itemTypeId: Value(itemType.id),
                  itemDefinitionId: Value(newItemInput.itemDefinitionId),
                  serviceId: Value(service.id),
                  itemTypeNameSnapshot: Value(itemType.name),
                  itemDefinitionNameSnapshot: Value(itemDefName),
                  serviceNameSnapshot: Value(service.name),
                  pricingType: Value(pricingType.value),
                  quantity: const Value(1.0),
                  unitPrice: Value(unitPrice.piastres),
                  calculatedTotal: Value(calcTotal.piastres),
                  notes: Value(newItemInput.notes),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
                carpet: null,
                total: calcTotal,
              ));
            }
          }
        }

        // 9. Total items count validation
        final totalItemCount =
            survivingExistingIds.length + newItemsList.length;
        if (totalItemCount == 0) {
          throw const ValidationFailure('Order must contain at least one item');
        }

        // 10. Financial calculations
        var subtotal = Money.zero;
        for (final id in survivingExistingIds) {
          if (updatedItemsMap.containsKey(id)) {
            subtotal += updatedItemsMap[id]!.total;
          } else {
            subtotal += Money.fromPiastres(
              existingItemsMap[id]!.item.calculatedTotal,
            );
          }
        }
        for (final n in newItemsList) {
          subtotal += n.total;
        }

        if (input.discount.isNegative) {
          throw const ValidationFailure('Discount cannot be negative');
        }
        if (input.discount > subtotal) {
          throw const BusinessRuleFailure('Discount cannot exceed subtotal');
        }

        final tax = Money.fromPiastres(existingRow.tax); // 0 in V1
        final pickupFee = input.customerPickupRequested
            ? input.customerPickupFee
            : Money.zero;
        final deliveryFee = input.customerDeliveryRequested
            ? input.customerDeliveryFee
            : Money.zero;
        final total = subtotal - input.discount + pickupFee + deliveryFee + tax;

        if (total < totalPaid) {
          throw const BusinessRuleFailure(
            'Order total cannot be less than total paid amount',
          );
        }

        // 11. Execute DB mutations
        // 11a. Delete removed items and their carpets
        for (final deletedId in input.deletedItemIds) {
          await (_db.delete(_db.orderItemCarpets)
                ..where((t) => t.orderItemId.equals(deletedId)))
              .go();
          await (_db.delete(_db.orderItems)
                ..where((t) => t.id.equals(deletedId)))
              .go();
        }

        // 11b. Update modified items
        for (final modEntry in updatedItemsMap.values) {
          await (_db.update(_db.orderItems)
                ..where((t) => t.id.equals(modEntry.item.id.value)))
              .write(modEntry.item);

          if (modEntry.carpet != null) {
            await _db
                .into(_db.orderItemCarpets)
                .insertOnConflictUpdate(modEntry.carpet!);
          } else {
            await (_db.delete(_db.orderItemCarpets)
                  ..where((t) => t.orderItemId.equals(modEntry.item.id.value)))
                .go();
          }
        }

        // 11c. Insert new items
        for (final newItem in newItemsList) {
          await _db.into(_db.orderItems).insert(newItem.item);
          if (newItem.carpet != null) {
            await _db.into(_db.orderItemCarpets).insert(newItem.carpet!);
          }
        }

        // 12. Evaluate readiness invariant:
        // activeStoredCount == totalItemCount && totalItemCount > 0 -> ready else processing
        final storedActiveJoin = _db.select(_db.orderItems).join([
          innerJoin(
            _db.storageRecords,
            _db.storageRecords.orderItemId.equalsExp(_db.orderItems.id) &
                _db.storageRecords.isActive.equals(true),
          ),
        ])..where(_db.orderItems.orderId.equals(input.orderId));

        final activeStoredRows = await storedActiveJoin.get();
        final activeStoredCount = activeStoredRows.length;

        final newStatus =
            (totalItemCount > 0 && activeStoredCount == totalItemCount)
                ? OrderStatus.ready
                : OrderStatus.processing;

        // 13. Update orders header
        await (_db.update(_db.orders)
              ..where((t) => t.id.equals(input.orderId)))
            .write(
              app_db.OrdersCompanion(
                customerId: Value(customerId),
                customerNameSnapshot: Value(customerNameSnapshot),
                customerPhoneSnapshot: Value(customerPhoneSnapshot),
                status: Value(newStatus.name),
                expectedPickupDate: Value(
                  input.expectedPickupDate.toDateTime(),
                ),
                notes: Value(input.notes),
                customerPickupRequested: Value(input.customerPickupRequested),
                customerPickupFee: Value(pickupFee.piastres),
                customerDeliveryRequested: Value(
                  input.customerDeliveryRequested,
                ),
                customerDeliveryFee: Value(deliveryFee.piastres),
                subtotal: Value(subtotal.piastres),
                discount: Value(input.discount.piastres),
                total: Value(total.piastres),
                updatedAt: Value(now),
              ),
            );

        // 14. Outbox Enqueueing
        final updatedOrderRow =
            (await _ordersDao.getOrderById(input.orderId))!;
        final committedOrder = _mapOrderToDomain(updatedOrderRow);
        final currentOrderItems = await getOrderItems(input.orderId);

        final editPayload = SyncPayloadBuilder.buildOrderEditPayload(
          committedOrder,
          currentOrderItems,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: input.orderId,
          operationType: 'edit',
          payload: editPayload,
        );

        return committedOrder;
      });
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
          throw const BusinessRuleFailure(
            'Order number is immutable and cannot be changed.',
          );
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

        final committedOrder = order.copyWith(
          orderNumber: existing.orderNumber,
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: order.id,
          operationType: 'update',
          payload: SyncPayloadBuilder.buildOrderUpdatePayload(committedOrder),
        );

        return committedOrder;
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
    DateTime? referenceDate,
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
        referenceDate: referenceDate,
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
      return _ordersDao
          .watchRecentOrders(limit: limit)
          .map((rows) => rows.map(_mapOrderToDomain).toList());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<Order?> watchOrderById(String id) {
    try {
      return _ordersDao
          .watchOrderById(id)
          .map((row) => row != null ? _mapOrderToDomain(row) : null);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<void> watchOrderTableUpdates() {
    return _ordersDao.watchDashboardUpdates();
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
          throw BusinessRuleFailure(
            'Only processing orders can be marked ready',
          );
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
          payload: SyncPayloadBuilder.buildOrderStatusPayload(
            orderId,
            OrderStatus.ready,
            updatedAt: now,
          ),
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
        final payments = await (_db.select(
          _db.payments,
        )..where((t) => t.orderId.equals(orderId))).get();
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
          payload: SyncPayloadBuilder.buildOrderStatusPayload(
            orderId,
            OrderStatus.completed,
            completedAt: now,
            updatedAt: now,
          ),
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
          payload: SyncPayloadBuilder.buildOrderStatusPayload(
            orderId,
            OrderStatus.cancelled,
            cancelledAt: now,
            cancellationReason: cancellationReason.trim(),
            updatedAt: now,
          ),
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
          throw const BusinessRuleFailure(
            'Cancelled orders cannot transition to any other status',
          );
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

        if (existing.status == OrderStatus.ready.name &&
            newStatus == OrderStatus.processing) {
          if (reason == null || reason.trim().isEmpty) {
            throw const ValidationFailure(
              'Operational reason is required to correct Ready order back to Processing',
            );
          }
          // Deactivate ALL currently active StorageRecords belonging to the order's physical OrderItems
          final items = await _ordersDao.getOrderItemsRaw(orderId);
          for (final item in items) {
            await _storageRecordsDao.deactivateActiveRecord(item.id, now);
          }
        } else if (existing.status == OrderStatus.processing.name &&
            newStatus == OrderStatus.ready) {
          if (reason == null || reason.trim().isEmpty) {
            throw const BusinessRuleFailure(
              'Operational reason is required to manually override Processing order to Ready',
            );
          }
          final allStored = await _storageRecordsDao.areAllOrderItemsStored(
            orderId,
          );
          if (!allStored) {
            throw const BusinessRuleFailure(
              'لا يمكن تحويل الطلب إلى جاهز: لم يتم تخزين جميع القطع بعد',
            );
          }
          // Manual correction with all items stored preserves storage records and sets status to Ready.
        } else if (existing.status == OrderStatus.completed.name &&
            newStatus == OrderStatus.processing) {
          if (reason == null || reason.trim().isEmpty) {
            throw const ValidationFailure(
              'Operational reason is required to correct Completed order back to Processing',
            );
          }
          completedAt = null;
          // Completed -> Processing: storage remains inactive.
        } else if (existing.status == OrderStatus.completed.name &&
            newStatus != OrderStatus.processing) {
          throw const BusinessRuleFailure(
            'Completed orders can only be corrected back to Processing',
          );
        }

        if (newStatus == OrderStatus.cancelled) {
          cancelledAt = now;
          cancellationReason =
              reason ?? existing.cancellationReason ?? 'تصحيح الحالة';
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
          payload: SyncPayloadBuilder.buildOrderStatusPayload(
            orderId,
            newStatus,
            completedAt: completedAt,
            cancelledAt: cancelledAt,
            cancellationReason: cancellationReason,
            updatedAt: now,
          ),
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
    final status = OrderStatus.fromValue(row.status);
    DateTime? completedAt = row.completedAt;
    DateTime? cancelledAt = row.cancelledAt;
    String? cancellationReason = row.cancellationReason;

    if (status == OrderStatus.completed && completedAt == null) {
      completedAt = row.updatedAt;
    } else if (status == OrderStatus.cancelled) {
      cancelledAt ??= row.updatedAt;
      if (cancellationReason == null || cancellationReason.trim().isEmpty) {
        cancellationReason =
            (row.notes != null && row.notes!.trim().isNotEmpty)
                ? row.notes!
                : 'تم الإلغاء';
      }
    }

    return Order(
      id: row.id,
      orderNumber: row.orderNumber,
      customerId: row.customerId,
      customerNameSnapshot: row.customerNameSnapshot,
      customerPhoneSnapshot: row.customerPhoneSnapshot,
      status: status,
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
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
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
      pricingType: PricingType.fromValue(item.pricingType),
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
  Future<Map<String, int>> getOrderCountsByCustomerIds(
    List<String> customerIds,
  ) async {
    try {
      if (customerIds.isEmpty) return {};
      return await _ordersDao.getOrderCountsByCustomerIds(customerIds);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<CustomerOrderAggregate> getCustomerOrderAggregate(
    String customerId,
  ) async {
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
        totalRefunds: Money.fromPiastres(res.totalRefundsPiastres),
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }
}
