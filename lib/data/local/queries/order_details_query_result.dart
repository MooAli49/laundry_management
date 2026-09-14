import '../../../../domain/entities/carpet_item_data.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/payment.dart';

class OrderItemWithCarpetData {
  final OrderItem orderItem;
  final CarpetItemData? carpetData;

  const OrderItemWithCarpetData({
    required this.orderItem,
    this.carpetData,
  });
}

class OrderDetailsQueryResult {
  final Order order;
  final Customer customer;
  final List<OrderItemWithCarpetData> items;
  final List<Payment> payments;

  const OrderDetailsQueryResult({
    required this.order,
    required this.customer,
    required this.items,
    required this.payments,
  });
}
