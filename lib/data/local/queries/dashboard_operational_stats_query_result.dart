class DashboardOperationalStatsQueryResult {
  final int todayOrdersCount;
  final int processingOrdersCount;
  final int readyOrdersCount;
  final int totalRemainingPiastres;
  final int unpaidOrdersCount;
  final int overdueOrdersCount;

  const DashboardOperationalStatsQueryResult({
    required this.todayOrdersCount,
    required this.processingOrdersCount,
    required this.readyOrdersCount,
    required this.totalRemainingPiastres,
    required this.unpaidOrdersCount,
    required this.overdueOrdersCount,
  });

  static const empty = DashboardOperationalStatsQueryResult(
    todayOrdersCount: 0,
    processingOrdersCount: 0,
    readyOrdersCount: 0,
    totalRemainingPiastres: 0,
    unpaidOrdersCount: 0,
    overdueOrdersCount: 0,
  );
}
