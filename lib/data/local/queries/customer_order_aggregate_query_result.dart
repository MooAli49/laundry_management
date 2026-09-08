class CustomerOrderAggregateQueryResult {
  final int totalOrders;
  final int processingOrders;
  final int readyOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int totalPaidPiastres;
  final int totalRemainingPiastres;

  const CustomerOrderAggregateQueryResult({
    required this.totalOrders,
    required this.processingOrders,
    required this.readyOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalPaidPiastres,
    required this.totalRemainingPiastres,
  });

  static const empty = CustomerOrderAggregateQueryResult(
    totalOrders: 0,
    processingOrders: 0,
    readyOrders: 0,
    completedOrders: 0,
    cancelledOrders: 0,
    totalPaidPiastres: 0,
    totalRemainingPiastres: 0,
  );
}
