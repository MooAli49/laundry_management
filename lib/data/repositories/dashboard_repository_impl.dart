import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/dashboard_order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/orders_dao.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final OrdersDao _ordersDao;
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;
  final StorageRepository _storageRepository;

  DashboardRepositoryImpl({
    required OrdersDao ordersDao,
    required OrderRepository orderRepository,
    required PaymentRepository paymentRepository,
    required StorageRepository storageRepository,
  })  : _ordersDao = ordersDao,
        _orderRepository = orderRepository,
        _paymentRepository = paymentRepository,
        _storageRepository = storageRepository;

  @override
  Future<DashboardData> getDashboardData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final todayUtc = DateTime.utc(now.year, now.month, now.day);

    final stats = await _ordersDao.getDashboardOperationalStats(
      todayStart: todayStart,
      todayEnd: todayEnd,
      todayDate: todayUtc,
    );

    final storageAttentionCount = await _storageRepository.countItemsRequiringStorage();

    // Fetch Today's pickups (Date-only active orders capped at 5)
    final activeTodayPickups = await _orderRepository.getOrders(
      expectedPickupDate: OrderDate.today(),
      excludedStatuses: const [OrderStatus.completed, OrderStatus.cancelled],
      limit: 5,
    );

    // Fetch Recent orders
    final recentOrdersRaw = await _orderRepository.getOrders(limit: 5);

    // Batch enrich with payment summaries
    final orderIdsToEnrich = <String>{
      ...activeTodayPickups.map((o) => o.id),
      ...recentOrdersRaw.map((o) => o.id),
    }.toList();

    final paymentSummaries = await _paymentRepository.getPaymentSummariesForOrders(orderIdsToEnrich);

    final todayPickupItems = activeTodayPickups.map((order) {
      final summary = paymentSummaries[order.id];
      return DashboardOrderItem(
        order: order,
        totalPaid: summary?.totalPaid ?? Money.zero,
        remainingAmount: summary?.remaining ?? order.total,
      );
    }).toList();

    final recentItems = recentOrdersRaw.map((order) {
      final summary = paymentSummaries[order.id];
      return DashboardOrderItem(
        order: order,
        totalPaid: summary?.totalPaid ?? Money.zero,
        remainingAmount: summary?.remaining ?? order.total,
      );
    }).toList();

    return DashboardData(
      todayOrdersCount: stats.todayOrdersCount,
      processingOrdersCount: stats.processingOrdersCount,
      readyOrdersCount: stats.readyOrdersCount,
      totalRemainingAmount: Money.fromPiastres(stats.totalRemainingPiastres),
      unpaidOrdersCount: stats.unpaidOrdersCount,
      storageAttentionCount: storageAttentionCount,
      overdueOrdersCount: stats.overdueOrdersCount,
      todayPickupOrdersCount: stats.todayPickupOrdersCount,
      todayPickupOrders: todayPickupItems,
      recentOrders: recentItems,
    );
  }
}
