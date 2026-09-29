import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/app.dart';
import 'package:laundry_management/application/license/license_service.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/core/routing/app_router.dart';
import 'package:laundry_management/core/routing/app_routes.dart';
import 'package:laundry_management/core/widgets/app_shell.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_data_source.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/features/license/presentation/screens/license_lock_screen.dart';
import 'package:laundry_management/features/license/presentation/widgets/license_warning_banner.dart';

class _FakeNetworkInfo implements NetworkInfo {
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void dispose() {
    _connectivityController.close();
  }
}

class _FakeSyncEngine implements SyncEngine {
  final StreamController<SyncEngineState> _stateController =
      StreamController<SyncEngineState>.broadcast();

  @override
  SyncEngineState get state =>
      SyncEngineState.completed(lastSyncTime: DateTime(2026, 9, 24));

  @override
  Stream<SyncEngineState> get stateStream => _stateController.stream;

  @override
  bool get isSyncing => false;

  @override
  void dispose() {
    _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLicenseRemoteDataSource implements LicenseRemoteDataSource {
  String status = 'active';
  DateTime? suspendedAt;

  @override
  Future<LicenseRemoteData> fetchLicenseInfo() async {
    return LicenseRemoteData(status: status, suspendedAt: suspendedAt);
  }
}

void main() {
  late _FakeNetworkInfo fakeNetworkInfo;
  late _FakeSyncEngine fakeSyncEngine;
  late _MockLicenseRemoteDataSource fakeRemoteLicense;

  setUp(() async {
    await getIt.reset();
    fakeNetworkInfo = _FakeNetworkInfo();
    fakeSyncEngine = _FakeSyncEngine();
    fakeRemoteLicense = _MockLicenseRemoteDataSource();

    getIt.registerLazySingleton<AppDatabase>(
      () => AppDatabase(NativeDatabase.memory()),
    );
    getIt.registerLazySingleton<NetworkInfo>(() => fakeNetworkInfo);
    getIt.registerLazySingleton<SyncEngine>(() => fakeSyncEngine);
    getIt.registerLazySingleton<LicenseRemoteDataSource>(
      () => fakeRemoteLicense,
    );

    await initDependencies();
  });

  tearDown(() async {
    fakeNetworkInfo.dispose();
    fakeSyncEngine.dispose();
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt<AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('License Router Gating Tests', () {
    testWidgets('Active license: lock screen route redirects to dashboard', (
      WidgetTester tester,
    ) async {
      await getIt<LicenseService>().initialize();
      AppRouter.resetForTesting();

      await tester.pumpWidget(const LaundryManagementApp());
      await tester.pumpAndSettle();

      // Attempt to navigate directly to the lock screen while active
      AppRouter.router.go(AppRoutes.licenseLockedOut);
      await tester.pumpAndSettle();

      // Should be redirected back to dashboard
      expect(
        AppRouter.router.routerDelegate.currentConfiguration.uri.path,
        equals(AppRoutes.dashboard),
      );
      expect(find.byType(LicenseLockScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('Grace period: warning banner is shown inside AppShell', (
      WidgetTester tester,
    ) async {
      // 3 days elapsed out of 7
      fakeRemoteLicense.status = 'suspended';
      fakeRemoteLicense.suspendedAt = DateTime.now().subtract(
        const Duration(days: 3),
      );

      await getIt<LicenseService>().initialize();
      AppRouter.resetForTesting();

      await tester.pumpWidget(const LaundryManagementApp());
      await tester.pumpAndSettle();

      // Warning banner must be present
      expect(find.byType(LicenseWarningBanner), findsOneWidget);
      // AppShell and normal UI remain accessible
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(LicenseLockScreen), findsNothing);
    });

    testWidgets(
      'Locked out license: navigates to LicenseLockScreen with no AppShell',
      (WidgetTester tester) async {
        // 8 days elapsed (> 7 days grace)
        fakeRemoteLicense.status = 'suspended';
        fakeRemoteLicense.suspendedAt = DateTime.now().subtract(
          const Duration(days: 8),
        );

        await getIt<LicenseService>().initialize();
        AppRouter.resetForTesting();

        await tester.pumpWidget(const LaundryManagementApp());
        await tester.pumpAndSettle();

        // Lock screen is rendered outside AppShell
        expect(find.byType(LicenseLockScreen), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(
          AppRouter.router.routerDelegate.currentConfiguration.uri.path,
          equals(AppRoutes.licenseLockedOut),
        );
        expect(find.text('تم تعليق ترخيص النظام'), findsOneWidget);

        // Attempt to navigate to orders should be blocked and redirected back to lock screen
        AppRouter.router.go(AppRoutes.orders);
        await tester.pumpAndSettle();
        expect(
          AppRouter.router.routerDelegate.currentConfiguration.uri.path,
          equals(AppRoutes.licenseLockedOut),
        );
      },
    );

    testWidgets(
      'Reinstatement: transition from lockedOut to active redirects to dashboard',
      (WidgetTester tester) async {
        // Start locked out
        fakeRemoteLicense.status = 'suspended';
        fakeRemoteLicense.suspendedAt = DateTime.now().subtract(
          const Duration(days: 10),
        );

        await getIt<LicenseService>().initialize();
        AppRouter.resetForTesting();

        await tester.pumpWidget(const LaundryManagementApp());
        await tester.pumpAndSettle();

        expect(find.byType(LicenseLockScreen), findsOneWidget);

        // Re-instate remote license
        fakeRemoteLicense.status = 'active';
        fakeRemoteLicense.suspendedAt = null;

        // Force a check on the service
        final licenseService = getIt<LicenseService>();
        await licenseService.initialize();
        await tester.pumpAndSettle();

        // Automatically unblocked and redirected to dashboard
        expect(find.byType(LicenseLockScreen), findsNothing);
        expect(find.byType(AppShell), findsOneWidget);
        expect(
          AppRouter.router.routerDelegate.currentConfiguration.uri.path,
          equals(AppRoutes.dashboard),
        );
      },
    );
  });
}
