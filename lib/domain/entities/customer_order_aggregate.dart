import '../value_objects/money.dart';

class CustomerOrderAggregate {
  final int totalOrders;
  final int processingOrders;
  final int readyOrders;
  final int completedOrders;
  final int cancelledOrders;
  final Money totalPaid;
  final Money totalRemaining;

  const CustomerOrderAggregate({
    required this.totalOrders,
    required this.processingOrders,
    required this.readyOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    this.totalPaid = Money.zero,
    this.totalRemaining = Money.zero,
  });

  const CustomerOrderAggregate.empty()
      : totalOrders = 0,
        processingOrders = 0,
        readyOrders = 0,
        completedOrders = 0,
        cancelledOrders = 0,
        totalPaid = Money.zero,
        totalRemaining = Money.zero;

  int get activeOrders => processingOrders + readyOrders;
}
