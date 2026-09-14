class OrdersReportAggregateQueryResult {
  final int totalOrders;
  final int totalOrderValuePiastres;
  final int totalDiscountsPiastres;
  final int processingCount;
  final int readyCount;
  final int completedCount;
  final int cancelledCount;
  final int overdueCount;

  const OrdersReportAggregateQueryResult({
    required this.totalOrders,
    required this.totalOrderValuePiastres,
    required this.totalDiscountsPiastres,
    required this.processingCount,
    required this.readyCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.overdueCount,
  });

  static const empty = OrdersReportAggregateQueryResult(
    totalOrders: 0,
    totalOrderValuePiastres: 0,
    totalDiscountsPiastres: 0,
    processingCount: 0,
    readyCount: 0,
    completedCount: 0,
    cancelledCount: 0,
    overdueCount: 0,
  );
}
