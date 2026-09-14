import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/dashboard_data.dart';
import 'package:laundry_management/domain/repositories/dashboard_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/dashboard/presentation/cubit/dashboard_cubit.dart';

class FakeDashboardRepository implements DashboardRepository {
  bool shouldThrow = false;
  DashboardData mockData = const DashboardData(
    todayOrdersCount: 5,
    processingOrdersCount: 2,
    readyOrdersCount: 3,
    totalRemainingAmount: Money.fromPiastres(12000),
    unpaidOrdersCount: 2,
    storageAttentionCount: 4,
    overdueOrdersCount: 1,
    todayPickupOrdersCount: 2,
    todayPickupOrders: [],
    recentOrders: [],
  );

  @override
  Future<DashboardData> getDashboardData() async {
    if (shouldThrow) throw Exception('Repository failure');
    return mockData;
  }
}

void main() {
  late FakeDashboardRepository repository;
  late DashboardCubit cubit;

  setUp(() {
    repository = FakeDashboardRepository();
    cubit = DashboardCubit(dashboardRepository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('DashboardCubit Tests', () {
    test('initial state has empty data and isLoading=false', () {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.data, DashboardData.empty);
    });

    test('loadDashboard emits loading and updates state with data on success', () async {
      await cubit.loadDashboard();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.data.todayOrdersCount, 5);
      expect(cubit.state.data.processingOrdersCount, 2);
      expect(cubit.state.data.readyOrdersCount, 3);
      expect(cubit.state.data.totalRemainingAmount, const Money.fromPiastres(12000));
    });

    test('loadDashboard sets errorMessage on failure', () async {
      repository.shouldThrow = true;
      await cubit.loadDashboard();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, 'تعذر تحميل بيانات الرئيسية');
    });

    test('refresh updates state without destructive loading flag', () async {
      await cubit.loadDashboard();
      expect(cubit.state.data.todayOrdersCount, 5);

      repository.mockData = const DashboardData(
        todayOrdersCount: 8,
        processingOrdersCount: 3,
        readyOrdersCount: 4,
        totalRemainingAmount: Money.fromPiastres(15000),
        unpaidOrdersCount: 3,
        storageAttentionCount: 2,
        overdueOrdersCount: 0,
        todayPickupOrdersCount: 1,
        todayPickupOrders: [],
        recentOrders: [],
      );

      await cubit.refresh();

      expect(cubit.state.data.todayOrdersCount, 8);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });
  });
}
