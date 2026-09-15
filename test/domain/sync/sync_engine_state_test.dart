import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';

void main() {
  group('SyncEngineState Unit Tests', () {
    final fixedTime = DateTime.utc(2026, 9, 15, 14, 30, 0);

    test(
      'SyncEngineState.idle initializes with idle status and clean defaults',
      () {
        const state = SyncEngineState.idle();
        expect(state.status, equals(SyncEngineStatus.idle));
        expect(state.lastSyncTime, isNull);
        expect(state.pendingOperationsCount, equals(0));
        expect(state.lastError, isNull);
      },
    );

    test('SyncEngineState.syncing represents active sync cycle', () {
      final state = SyncEngineState.syncing(
        lastSyncTime: fixedTime,
        pendingOperationsCount: 12,
      );
      expect(state.status, equals(SyncEngineStatus.syncing));
      expect(state.lastSyncTime, equals(fixedTime));
      expect(state.pendingOperationsCount, equals(12));
      expect(state.lastError, isNull);
    });

    test(
      'SyncEngineState.completed represents successful sync cycle with timestamp',
      () {
        final state = SyncEngineState.completed(
          lastSyncTime: fixedTime,
          pendingOperationsCount: 0,
        );
        expect(state.status, equals(SyncEngineStatus.completed));
        expect(state.lastSyncTime, equals(fixedTime));
        expect(state.pendingOperationsCount, equals(0));
        expect(state.lastError, isNull);
      },
    );

    test(
      'SyncEngineState.failed captures failure details while preserving sync time',
      () {
        final state = SyncEngineState.failed(
          error: 'Connection timeout',
          lastSyncTime: fixedTime,
          pendingOperationsCount: 5,
        );
        expect(state.status, equals(SyncEngineStatus.failed));
        expect(state.lastError, equals('Connection timeout'));
        expect(state.lastSyncTime, equals(fixedTime));
        expect(state.pendingOperationsCount, equals(5));
      },
    );

    test(
      'value equality and hashCode behave correctly for identical and distinct states',
      () {
        final state1 = SyncEngineState(
          status: SyncEngineStatus.idle,
          lastSyncTime: fixedTime,
          pendingOperationsCount: 3,
          lastError: null,
        );

        final state2 = SyncEngineState(
          status: SyncEngineStatus.idle,
          lastSyncTime: fixedTime,
          pendingOperationsCount: 3,
          lastError: null,
        );

        final state3 = SyncEngineState(
          status: SyncEngineStatus.syncing,
          lastSyncTime: fixedTime,
          pendingOperationsCount: 3,
          lastError: null,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
        expect(state1, isNot(equals(state3)));
      },
    );

    test(
      'copyWith properly overrides specified fields while keeping others intact',
      () {
        const initial = SyncEngineState.idle(pendingOperationsCount: 4);
        final updated = initial.copyWith(
          status: SyncEngineStatus.syncing,
          pendingOperationsCount: 3,
        );

        expect(updated.status, equals(SyncEngineStatus.syncing));
        expect(updated.pendingOperationsCount, equals(3));
        expect(updated.lastSyncTime, isNull);
        expect(updated.lastError, isNull);
      },
    );

    test(
      'toString contains meaningful state representation for diagnostics',
      () {
        final state = SyncEngineState.failed(
          error: 'Network unreachable',
          pendingOperationsCount: 2,
        );
        expect(state.toString(), contains('SyncEngineStatus.failed'));
        expect(state.toString(), contains('Network unreachable'));
        expect(state.toString(), contains('pending: 2'));
      },
    );
  });
}
