import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/item_definition_repository.dart';
import '../../domain/repositories/item_type_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';

class CreateOrderItemInput {
  final String itemTypeId;
  final String? itemDefinitionId;
  final String serviceId;
  final Money? customUnitPrice;
  final int physicalQuantity;
  final String? notes;
  final CarpetItemInput? carpetData;

  const CreateOrderItemInput({
    required this.itemTypeId,
    this.itemDefinitionId,
    required this.serviceId,
    this.customUnitPrice,
    required this.physicalQuantity,
    this.notes,
    this.carpetData,
  });
}

class CarpetItemInput {
  final String? carpetSizeId;
  final double length;
  final double width;

  const CarpetItemInput({
    this.carpetSizeId,
    required this.length,
    required this.width,
  });
}

class CreateOrderInput {
  final String customerId;
  final OrderDate expectedPickupDate;
  final String? notes;
  final bool customerPickupRequested;
  final Money customerPickupFee;
  final bool customerDeliveryRequested;
  final Money customerDeliveryFee;
  final Money discount;
  final List<CreateOrderItemInput> items;

  const CreateOrderInput({
    required this.customerId,
    required this.expectedPickupDate,
    this.notes,
    this.customerPickupRequested = false,
    this.customerPickupFee = Money.zero,
    this.customerDeliveryRequested = false,
    this.customerDeliveryFee = Money.zero,
    this.discount = Money.zero,
    required this.items,
  });
}

class CreateOrderUseCase {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final ServiceRepository _serviceRepository;
  final ItemTypeRepository _itemTypeRepository;
  final ItemDefinitionRepository _itemDefinitionRepository;
  final Uuid _uuid;

  CreateOrderUseCase({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required ServiceRepository serviceRepository,
    required ItemTypeRepository itemTypeRepository,
    required ItemDefinitionRepository itemDefinitionRepository,
    Uuid? uuid,
  })  : _orderRepository = orderRepository,
        _customerRepository = customerRepository,
        _serviceRepository = serviceRepository,
        _itemTypeRepository = itemTypeRepository,
        _itemDefinitionRepository = itemDefinitionRepository,
        _uuid = uuid ?? const Uuid();

  Future<Order> execute(CreateOrderInput input) async {
    if (input.items.isEmpty) {
      throw const ValidationFailure('Order must contain at least one item');
    }

    if (input.expectedPickupDate.isBeforeToday) {
      throw const ValidationFailure('Expected pickup date cannot be in the past');
    }

    final customer = await _customerRepository.getCustomerById(input.customerId);
    if (customer == null) {
      throw const ValidationFailure('Customer not found');
    }

    if (input.customerPickupFee.isNegative) {
      throw const ValidationFailure('Pickup fee cannot be negative');
    }
    if (input.customerDeliveryFee.isNegative) {
      throw const ValidationFailure('Delivery fee cannot be negative');
    }
    if (!input.customerPickupRequested && input.customerPickupFee > Money.zero) {
      throw const ValidationFailure('Pickup fee must be zero when pickup is not requested');
    }
    if (!input.customerDeliveryRequested && input.customerDeliveryFee > Money.zero) {
      throw const ValidationFailure('Delivery fee must be zero when delivery is not requested');
    }

    final orderId = _uuid.v4();
    final now = DateTime.now();
    final expandedItems = <OrderItem>[];

    for (final itemInput in input.items) {
      if (itemInput.physicalQuantity <= 0) {
        throw const ValidationFailure('Physical quantity must be greater than zero');
      }

      final itemType = await _itemTypeRepository.getItemTypeById(itemInput.itemTypeId);
      if (itemType == null) {
        throw const ValidationFailure('Item type not found');
      }
      if (!itemType.isActive) {
        throw const BusinessRuleFailure('Item type is inactive');
      }

      String? itemDefinitionName;
      if (itemInput.itemDefinitionId != null) {
        final itemDef = await _itemDefinitionRepository.getItemDefinitionById(itemInput.itemDefinitionId!);
        if (itemDef == null) {
          throw const ValidationFailure('Item definition not found');
        }
        if (!itemDef.isActive) {
          throw const BusinessRuleFailure('Item definition is inactive');
        }
        if (itemDef.itemTypeId != itemInput.itemTypeId) {
          throw const BusinessRuleFailure('Item definition does not belong to the selected item type');
        }
        itemDefinitionName = itemDef.name;
      }

      final service = await _serviceRepository.getServiceById(itemInput.serviceId);
      if (service == null) {
        throw const ValidationFailure('Service not found');
      }
      if (!service.isActive) {
        throw const BusinessRuleFailure('Service is inactive');
      }

      final compatibleServices = await _serviceRepository.getServicesForItemType(itemType.id);
      final isCompatible = compatibleServices.any((s) => s.id == service.id);
      if (!isCompatible) {
        throw IncompatibleServiceFailure(
          serviceId: service.id,
          itemTypeId: itemType.id,
        );
      }

      if (service.pricingType == PricingType.perKilogram) {
        throw const BusinessRuleFailure('Per-Kilogram pricing is not supported in V1');
      }

      final unitPrice = itemInput.customUnitPrice ?? service.price;
      if (unitPrice <= Money.zero) {
        throw const ValidationFailure('Unit price must be strictly greater than zero');
      }

      if (service.pricingType != PricingType.perSquareMeter && itemInput.carpetData != null) {
        throw const ValidationFailure(
          'Carpet data is not allowed for non-carpet pricing types',
        );
      }

      if (service.pricingType == PricingType.perSquareMeter) {
        if (itemInput.carpetData == null) {
          throw const ValidationFailure('Carpet data is required for per-square-meter services');
        }
        if (itemInput.carpetData!.length <= 0 || itemInput.carpetData!.width <= 0) {
          throw const ValidationFailure('Carpet dimensions must be greater than zero');
        }

        final area = itemInput.carpetData!.length * itemInput.carpetData!.width;
        final calculatedTotal = Money.fromPiastres((unitPrice.piastres * area).round());

        for (var i = 0; i < itemInput.physicalQuantity; i++) {
          final itemId = _uuid.v4();
          final carpetData = CarpetItemData(
            id: _uuid.v4(),
            orderItemId: itemId,
            carpetSizeId: itemInput.carpetData!.carpetSizeId,
            length: itemInput.carpetData!.length,
            width: itemInput.carpetData!.width,
            area: area,
            createdAt: now,
            updatedAt: now,
          );

          expandedItems.add(
            OrderItem(
              id: itemId,
              orderId: orderId,
              itemTypeId: itemType.id,
              itemDefinitionId: itemInput.itemDefinitionId,
              serviceId: service.id,
              itemTypeNameSnapshot: itemType.name,
              itemDefinitionNameSnapshot: itemDefinitionName,
              serviceNameSnapshot: service.name,
              pricingType: service.pricingType,
              quantity: 1.0,
              unitPrice: unitPrice,
              calculatedTotal: calculatedTotal,
              notes: itemInput.notes,
              carpetData: carpetData,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      } else {
        // perPiece or fixedPrice
        final calculatedTotal = unitPrice;

        for (var i = 0; i < itemInput.physicalQuantity; i++) {
          final itemId = _uuid.v4();
          expandedItems.add(
            OrderItem(
              id: itemId,
              orderId: orderId,
              itemTypeId: itemType.id,
              itemDefinitionId: itemInput.itemDefinitionId,
              serviceId: service.id,
              itemTypeNameSnapshot: itemType.name,
              itemDefinitionNameSnapshot: itemDefinitionName,
              serviceNameSnapshot: service.name,
              pricingType: service.pricingType,
              quantity: 1.0,
              unitPrice: unitPrice,
              calculatedTotal: calculatedTotal,
              notes: itemInput.notes,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    }

    var subtotal = Money.zero;
    for (final item in expandedItems) {
      subtotal += item.calculatedTotal;
    }

    if (input.discount.isNegative) {
      throw const ValidationFailure('Discount cannot be negative');
    }
    if (input.discount > subtotal) {
      throw const BusinessRuleFailure('Discount cannot exceed subtotal');
    }

    const tax = Money.zero;
    final total = subtotal - input.discount + input.customerPickupFee + input.customerDeliveryFee + tax;

    final order = Order(
      id: orderId,
      orderNumber: '', // Generated by OrderRepository during persistence
      customerId: input.customerId,
      status: OrderStatus.processing,
      expectedPickupDate: input.expectedPickupDate,
      notes: input.notes,
      customerPickupRequested: input.customerPickupRequested,
      customerPickupFee: input.customerPickupFee,
      customerDeliveryRequested: input.customerDeliveryRequested,
      customerDeliveryFee: input.customerDeliveryFee,
      subtotal: subtotal,
      discount: input.discount,
      tax: tax,
      total: total,
      createdAt: now,
      updatedAt: now,
    );

    return await _orderRepository.createOrder(
      order: order,
      items: expandedItems,
    );
  }
}
