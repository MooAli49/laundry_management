import '../entities/order.dart';
import '../entities/order_item.dart';
import '../enums/order_status.dart';
import '../value_objects/order_date.dart';

abstract class OrderRepository {
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
  });

  Future<Order> updateOrder(Order order);

  Future<Order?> getOrderById(String id);

  Future<Order?> getOrderByNumber(String orderNumber);

  Future<List<OrderItem>> getOrderItems(String orderId);

  Future<OrderItem?> getOrderItemById(String id);

  Future<List<Order>> getOrders({
    OrderStatus? status,
    OrderDate? expectedPickupDate,
    String? customerId,
    int limit = 20,
    int offset = 0,
  });

  Future<List<Order>> searchOrders({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  Stream<List<Order>> watchRecentOrders({int limit = 20});

  Stream<Order?> watchOrderById(String id);

  Future<Order> markOrderReady(String orderId);

  Future<Order> completeOrder({
    required String orderId,
    required bool handoverConfirmed,
  });

  Future<Order> cancelOrder({
    required String orderId,
    required String cancellationReason,
  });

  Future<Order> correctOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? reason,
  });
}
