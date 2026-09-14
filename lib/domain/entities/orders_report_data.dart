import '../value_objects/money.dart';

class OrdersReportData {
  final int totalOrders;
  final Money totalOrderValue;
  final int processingOrdersCount;
  final int readyOrdersCount;
  final int completedOrdersCount;
  final int cancelledOrdersCount;
  final int overdueOrdersCount;

  const OrdersReportData({
    required this.totalOrders,
    required this.totalOrderValue,
    required this.processingOrdersCount,
    required this.readyOrdersCount,
    required this.completedOrdersCount,
    required this.cancelledOrdersCount,
    required this.overdueOrdersCount,
  });

  static const empty = OrdersReportData(
    totalOrders: 0,
    totalOrderValue: Money.zero,
    processingOrdersCount: 0,
    readyOrdersCount: 0,
    completedOrdersCount: 0,
    cancelledOrdersCount: 0,
    overdueOrdersCount: 0,
  );

  int get activeOrdersCount => processingOrdersCount + readyOrdersCount;
}
