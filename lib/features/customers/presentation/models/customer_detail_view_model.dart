import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/customer_order_aggregate.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_payment_summary.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/value_objects/money.dart';

class CustomerDetailViewModel {
  final Customer customer;
  final List<Order> orders;
  final CustomerOrderAggregate aggregate;
  final Map<String, OrderPaymentSummary> paymentSummaries;

  CustomerDetailViewModel({
    required this.customer,
    required this.orders,
    CustomerOrderAggregate? aggregate,
    Map<String, OrderPaymentSummary>? paymentSummaries,
    Map<String, Money>? remainingAmounts,
    Map<String, Money>? paidAmounts,
  })  : aggregate = aggregate ??
            CustomerOrderAggregate(
              totalOrders: orders.length,
              processingOrders:
                  orders.where((o) => o.status == OrderStatus.processing).length,
              readyOrders:
                  orders.where((o) => o.status == OrderStatus.ready).length,
              completedOrders:
                  orders.where((o) => o.status == OrderStatus.completed).length,
              cancelledOrders:
                  orders.where((o) => o.status == OrderStatus.cancelled).length,
              totalPaid: paidAmounts != null
                  ? paidAmounts.values.fold(Money.zero, (sum, p) => sum + p)
                  : Money.zero,
              totalRemaining: remainingAmounts != null
                  ? remainingAmounts.values.fold(Money.zero, (sum, r) => sum + r)
                  : Money.zero,
            ),
        paymentSummaries = paymentSummaries ??
            {
              for (final order in orders)
                order.id: OrderPaymentSummary(
                  totalPaid: paidAmounts?[order.id] ?? Money.zero,
                  remaining: remainingAmounts?[order.id] ?? Money.zero,
                ),
            };

  int get totalOrdersCount => aggregate.totalOrders;
  int get activeOrdersCount => aggregate.activeOrders;
  int get completedOrdersCount => aggregate.completedOrders;
  int get cancelledOrdersCount => aggregate.cancelledOrders;

  Money get totalPaid => aggregate.totalPaid;
  Money get totalRemaining => aggregate.totalRemaining;

  Map<String, Money> get remainingAmounts => {
        for (final entry in paymentSummaries.entries) entry.key: entry.value.remaining,
      };

  Map<String, Money> get paidAmounts => {
        for (final entry in paymentSummaries.entries) entry.key: entry.value.totalPaid,
      };

  Order? get latestOrder => orders.isNotEmpty ? orders.first : null;

  CustomerDetailViewModel copyWith({
    Customer? customer,
    List<Order>? orders,
    CustomerOrderAggregate? aggregate,
    Map<String, OrderPaymentSummary>? paymentSummaries,
    Map<String, Money>? remainingAmounts,
    Map<String, Money>? paidAmounts,
  }) {
    return CustomerDetailViewModel(
      customer: customer ?? this.customer,
      orders: orders ?? this.orders,
      aggregate: aggregate ?? this.aggregate,
      paymentSummaries: paymentSummaries ?? this.paymentSummaries,
      remainingAmounts: remainingAmounts,
      paidAmounts: paidAmounts,
    );
  }
}
