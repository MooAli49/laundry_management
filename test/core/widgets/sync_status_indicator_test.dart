import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/widgets/sync_status_cubit.dart';
import 'package:laundry_management/core/widgets/sync_status_indicator.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => isConnectedValue;

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void emitConnectivity(bool connected) {
    isConnectedValue = connected;
    _connectivityController.add(connected);
  }

  void dispose() {
    _connectivityController.close();
  }
}

class FakeSyncEngine implements SyncEngine {
  SyncEngineState _state = const SyncEngineState.idle();
  final StreamController<SyncEngineState> _stateController =
      StreamController<SyncEngineState>.broadcast();
  bool _isSyncing = false;

  @override
  SyncEngineState get state => _state;

  @override
  Stream<SyncEngineState> get stateStream => _stateController.stream;

  @override
  bool get isSyncing => _isSyncing;

  void emitState(SyncEngineState newState, {bool? isSyncing}) {
    _state = newState;
    if (isSyncing != null) {
      _isSyncing = isSyncing;
    }
    _stateController.add(newState);
  }

  @override
  void dispose() {
    _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeNetworkInfo networkInfo;
  late FakeSyncEngine syncEngine;
  late SyncStatusCubit cubit;

  setUp(() {
    networkInfo = FakeNetworkInfo();
    syncEngine = FakeSyncEngine();
  });

  tearDown(() async {
    await cubit.close();
    networkInfo.dispose();
    syncEngine.dispose();
  });

  Widget buildTestableWidget(SyncStatusCubit cubit) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 220, // Match sidebar width
            child: SyncStatusIndicator(cubit: cubit),
          ),
        ),
      ),
    );
  }

  group('SyncStatusIndicator Widget Tests', () {
    testWidgets(
      '1. CONNECTED state renders "متصل" with green circle dot',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = true;
        syncEngine.emitState(
          SyncEngineState.completed(
            lastSyncTime: DateTime.utc(2026, 9, 21, 12, 0, 0),
          ),
        );

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );
        await tester.pumpWidget(buildTestableWidget(cubit));
        await tester.pumpAndSettle();

        expect(find.text('متصل'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Verify the 8x8 green dot Container exists
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8 &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == AppColors.success,
        );
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      '2. SYNCING state renders "جاري المزامنة" with 8x8 primary spinner',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = true;
        syncEngine.emitState(
          const SyncEngineState.syncing(),
          isSyncing: true,
        );

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );
        await tester.pumpWidget(buildTestableWidget(cubit));
        await tester.pump(); // Pump without settle because spinner animates

        expect(find.text('جاري المزامنة'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final spinnerBox = tester.firstWidget<SizedBox>(
          find.ancestor(
            of: find.byType(CircularProgressIndicator),
            matching: find.byType(SizedBox),
          ),
        );
        expect(spinnerBox.width, equals(8));
        expect(spinnerBox.height, equals(8));
      },
    );

    testWidgets(
      '3. OFFLINE state renders "غير متصل" with warning dot',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = false;
        syncEngine.emitState(const SyncEngineState.idle(lastSyncTime: null));

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );
        await tester.pumpWidget(buildTestableWidget(cubit));
        await tester.pumpAndSettle();

        expect(find.text('غير متصل'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8 &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == AppColors.warning,
        );
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      '4. SYNC_ERROR state renders "فشل المزامنة" with error dot',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = true;
        syncEngine.emitState(
          SyncEngineState.failed(
            error: 'HTTP 500 Internal Server Error',
            errorDetails: const SyncErrorDetails.http(500),
          ),
        );

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );
        await tester.pumpWidget(buildTestableWidget(cubit));
        await tester.pumpAndSettle();

        expect(find.text('فشل المزامنة'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8 &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == AppColors.error,
        );
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      '5. Reactive updates without rebuilding parent widget',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = true;
        syncEngine.emitState(
          SyncEngineState.completed(
            lastSyncTime: DateTime.utc(2026, 9, 21, 12, 0, 0),
          ),
        );

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );

        int parentBuildCount = 0;

        final parentWidget = StatefulBuilder(
          builder: (context, setState) {
            parentBuildCount++;
            return MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: SyncStatusIndicator(cubit: cubit),
                ),
              ),
            );
          },
        );

        await tester.pumpWidget(parentWidget);
        await tester.pumpAndSettle();

        expect(find.text('متصل'), findsOneWidget);
        expect(parentBuildCount, equals(1));

        // Trigger reactive transition to offline
        networkInfo.emitConnectivity(false);
        await tester.pumpAndSettle();

        expect(find.text('غير متصل'), findsOneWidget);
        // Parent MUST NOT have rebuilt!
        expect(parentBuildCount, equals(1));

        // Trigger reactive recovery
        networkInfo.emitConnectivity(true);
        syncEngine.emitState(
          SyncEngineState.completed(
            lastSyncTime: DateTime.utc(2026, 9, 21, 12, 5, 0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('متصل'), findsOneWidget);
        expect(parentBuildCount, equals(1));
      },
    );

    testWidgets(
      '6. RTL text layout renders dot first (right) and text second (left)',
      (WidgetTester tester) async {
        networkInfo.isConnectedValue = true;
        syncEngine.emitState(
          SyncEngineState.completed(
            lastSyncTime: DateTime.utc(2026, 9, 21, 12, 0, 0),
          ),
        );

        cubit = SyncStatusCubit(
          syncEngine: syncEngine,
          networkInfo: networkInfo,
        );

        await tester.pumpWidget(buildTestableWidget(cubit));
        await tester.pumpAndSettle();

        final dotRect = tester.getRect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 8 &&
                widget.decoration is BoxDecoration,
          ),
        );
        final textRect = tester.getRect(find.text('متصل'));

        // In RTL, the dot (first child) is to the RIGHT of the text (second child)
        expect(dotRect.right, greaterThan(textRect.right));
      },
    );
  });
}
