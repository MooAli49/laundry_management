import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/financial_report_data.dart';
import 'package:laundry_management/domain/entities/orders_report_data.dart';
import 'package:laundry_management/domain/enums/report_period.dart';
import 'package:laundry_management/domain/repositories/reports_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:laundry_management/features/reports/presentation/cubit/reports_state.dart';

class FakeReportsRepository implements ReportsRepository {
  bool shouldThrow = false;
  OrdersReportData mockOrders = const OrdersReportData(
    totalOrders: 10,
    totalOrderValue: Money.fromPiastres(50000),
    processingOrdersCount: 4,
    readyOrdersCount: 3,
    completedOrdersCount: 2,
    cancelledOrdersCount: 1,
    overdueOrdersCount: 1,
  );

  FinancialReportData mockFinancial = const FinancialReportData(
    totalSales: Money.fromPiastres(50000),
    totalPayments: Money.fromPiastres(35000),
    totalOperatingExpenses: Money.fromPiastres(12000),
    netProfit: Money.fromPiastres(38000),
    outstandingAmount: Money.fromPiastres(15000),
    totalDiscounts: Money.zero,
    paymentMethodsBreakdown: [],
    expenseCategoriesBreakdown: [],
    expenseTransactions: [],
    outstandingOrders: [],
  );

  @override
  Future<OrdersReportData> getOrdersReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return mockOrders;
  }

  @override
  Future<FinancialReportData> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return mockFinancial;
  }
}

void main() {
  late FakeReportsRepository repository;
  late ReportsCubit cubit;

  setUp(() {
    repository = FakeReportsRepository();
    cubit = ReportsCubit(reportsRepository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('ReportsCubit Tests', () {
    test('initial state has default values and not loading', () {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.selectedTab, ReportsTab.orders);
    });

    test('loadReports successfully updates state with report data', () async {
      await cubit.loadReports();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.ordersReport.totalOrders, 10);
      expect(cubit.state.financialReport.netProfit, const Money.fromPiastres(38000));
      expect(cubit.state.selectedTab, ReportsTab.orders);
    });

    test('selectTab switches tab without reloading', () async {
      await cubit.loadReports();
      cubit.selectTab(ReportsTab.financial);

      expect(cubit.state.selectedTab, ReportsTab.financial);
    });

    test('selectPeriod reloads data for new period', () async {
      await cubit.loadReports();
      await cubit.selectPeriod(ReportPeriod.last7Days);

      expect(cubit.state.selectedPeriod, ReportPeriod.last7Days);
      expect(cubit.state.ordersReport.totalOrders, 10);
    });

    test('sets errorMessage on repository failure', () async {
      repository.shouldThrow = true;
      await cubit.loadReports();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, 'DB error');
    });
  });
}
