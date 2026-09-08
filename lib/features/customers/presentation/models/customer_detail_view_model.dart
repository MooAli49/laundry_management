import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/value_objects/money.dart';

class CustomerDetailViewModel {
  final Customer customer;
  final List<Order> orders;
  final Map<String, Money> remainingAmounts;
  final Map<String, Money> paidAmounts;
  final int totalOrdersCount;
  final int activeOrdersCount;
  final int completedOrdersCount;

  CustomerDetailViewModel({
    required this.customer,
    required this.orders,
    required this.remainingAmounts,
    this.paidAmounts = const {},
  })  : totalOrdersCount = orders.length,
        activeOrdersCount = orders
            .where((o) =>
                o.status == OrderStatus.processing ||
                o.status == OrderStatus.ready)
            .length,
        completedOrdersCount =
            orders.where((o) => o.status == OrderStatus.completed).length;

  Order? get latestOrder => orders.isNotEmpty ? orders.first : null;

  Money get totalPaid => paidAmounts.values.fold(Money.zero, (sum, p) => sum + p);
  Money get totalRemaining => remainingAmounts.values.fold(Money.zero, (sum, r) => sum + r);

  CustomerDetailViewModel copyWith({
    Customer? customer,
    List<Order>? orders,
    Map<String, Money>? remainingAmounts,
    Map<String, Money>? paidAmounts,
  }) {
    return CustomerDetailViewModel(
      customer: customer ?? this.customer,
      orders: orders ?? this.orders,
      remainingAmounts: remainingAmounts ?? this.remainingAmounts,
      paidAmounts: paidAmounts ?? this.paidAmounts,
    );
  }
}
