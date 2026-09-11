class OutstandingOrderQueryResult {
  final String orderId;
  final String orderNumber;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final int totalPiastres;
  final int paidPiastres;
  final int remainingPiastres;

  const OutstandingOrderQueryResult({
    required this.orderId,
    required this.orderNumber,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.totalPiastres,
    required this.paidPiastres,
    required this.remainingPiastres,
  });
}
