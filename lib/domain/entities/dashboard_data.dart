import '../value_objects/money.dart';
import 'dashboard_order_item.dart';

class DashboardData {
  final int todayOrdersCount;
  final int processingOrdersCount;
  final int readyOrdersCount;
  final Money totalRemainingAmount;
  final int unpaidOrdersCount;
  final int storageAttentionCount;
  final int overdueOrdersCount;
  final List<DashboardOrderItem> recentOrders;

  const DashboardData({
    required this.todayOrdersCount,
    required this.processingOrdersCount,
    required this.readyOrdersCount,
    required this.totalRemainingAmount,
    required this.unpaidOrdersCount,
    required this.storageAttentionCount,
    required this.overdueOrdersCount,
    required this.recentOrders,
  });

  static const empty = DashboardData(
    todayOrdersCount: 0,
    processingOrdersCount: 0,
    readyOrdersCount: 0,
    totalRemainingAmount: Money.zero,
    unpaidOrdersCount: 0,
    storageAttentionCount: 0,
    overdueOrdersCount: 0,
    recentOrders: [],
  );
}
