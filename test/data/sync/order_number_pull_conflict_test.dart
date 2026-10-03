import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/remote/dto/pull_changes_response_dto.dart';
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_conflict_exception.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class _PullOnlyNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}

class _PullOnlyDispatcher implements RemoteApiDispatcher {
  @override
  Future<dynamic> dispatch(SyncOperation operation) async => null;
}

class _ConflictRemoteDataSource implements SyncRemoteDataSource {
  final PullChangesResponseDto response;

  _ConflictRemoteDataSource(this.response);

  @override
  Future<PullChangesResponseDto> getChanges({
    required int after,
    int? limit,
  }) async => response;

  @override
  Future<PullChangesResponseDto> getSnapshot() async => response;
}

void main() {
  late AppDatabase db;
  late RemoteChangeApplier applier;
  late SyncStateDao syncStateDao;
  final now = DateTime.utc(2026, 10, 3, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(), false);
    syncStateDao = SyncStateDao(db);
    applier = RemoteChangeApplier(db: db, syncStateDao: syncStateDao);
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            name: 'Customer',
            phone: '01000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => db.close());

  Map<String, dynamic> orderPayload({
    required String id,
    required String orderNumber,
    String status = 'processing',
  }) => {
    'id': id,
    'order_number': orderNumber,
    'customer_id': 'customer-1',
    'customer_name_snapshot': 'Customer',
    'customer_phone_snapshot': '01000000000',
    'status': status,
    'expected_pickup_date': now.toIso8601String(),
    'subtotal': 1000,
    'discount': 0,
    'tax': 0,
    'total': 1000,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
    'items': <Map<String, dynamic>>[],
  };

  SyncChangeDto change({
    required int sequence,
    required String id,
    required String orderNumber,
    String operationType = 'create',
    String operationId = 'operation',
  }) => SyncChangeDto(
    sequence: sequence,
    operationId: '$operationId-$sequence',
    entityType: 'order',
    entityId: id,
    operationType: operationType,
    payload: orderPayload(id: id, orderNumber: orderNumber),
    createdAt: now,
  );

  test('same UUID and same order number is idempotent', () async {
    final first = change(sequence: 1, id: 'order-1', orderNumber: '26-001');
    final replay = change(sequence: 2, id: 'order-1', orderNumber: '26-001');

    await applier.applyBatch([first]);
    await applier.applyBatch([replay]);

    expect((await db.select(db.orders).get()).length, 1);
    expect(await syncStateDao.getLastAppliedSequence(), 2);
    expect(await db.select(db.syncConflicts).get(), isEmpty);
  });

  test(
    'same UUID with a changed order number is recorded and rejected',
    () async {
      await applier.applyBatch([
        change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
      ]);

      expect(
        () => applier.applyBatch([
          change(
            sequence: 2,
            id: 'order-1',
            orderNumber: '26-002',
            operationType: 'update',
          ),
        ]),
        throwsA(isA<SyncConflictException>()),
      );

      final order = await (db.select(
        db.orders,
      )..where((table) => table.id.equals('order-1'))).getSingle();
      expect(order.orderNumber, '26-001');
      expect(await syncStateDao.getLastAppliedSequence(), 1);
      expect(
        (await db.select(db.syncConflicts).get()).single.conflictType,
        'order_number_changed',
      );
    },
  );

  test(
    'different UUID with a duplicate order number is retained as a conflict',
    () async {
      await applier.applyBatch([
        change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
      ]);

      expect(
        () => applier.applyBatch([
          change(sequence: 2, id: 'order-2', orderNumber: '26-001'),
        ]),
        throwsA(isA<SyncConflictException>()),
      );

      final orders = await db.select(db.orders).get();
      expect(orders.map((order) => order.id), ['order-1']);
      expect(await syncStateDao.getLastAppliedSequence(), 1);

      final conflict = (await db.select(db.syncConflicts).get()).single;
      expect(conflict.entityId, 'order-2');
      expect(conflict.localEntityId, 'order-1');
      expect(conflict.orderNumber, '26-001');
      expect(conflict.remoteSequence, 2);
      expect(conflict.status, 'pending');
    },
  );

  test('retrying the exact conflict does not duplicate diagnostics', () async {
    await applier.applyBatch([
      change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
    ]);

    final duplicate = change(sequence: 2, id: 'order-2', orderNumber: '26-001');
    await expectLater(
      applier.applyBatch([duplicate]),
      throwsA(isA<SyncConflictException>()),
    );
    await expectLater(
      applier.applyBatch([duplicate]),
      throwsA(isA<SyncConflictException>()),
    );

    final conflicts = await db.select(db.syncConflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.id, '2:order:order-2:duplicate_order_number');
    expect(await syncStateDao.getLastAppliedSequence(), 1);
  });

  test('conflict detection does not corrupt unrelated local data', () async {
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-2',
            name: 'Independent Customer',
            phone: '01000000001',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await applier.applyBatch([
      change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
    ]);

    expect(
      () => applier.applyBatch([
        change(sequence: 2, id: 'order-2', orderNumber: '26-001'),
      ]),
      throwsA(isA<SyncConflictException>()),
    );

    final independent = await (db.select(
      db.customers,
    )..where((table) => table.id.equals('customer-2'))).getSingle();
    expect(independent.name, 'Independent Customer');
  });

  test(
    'different UUIDs colliding within one batch are rejected before writes',
    () async {
      expect(
        () => applier.applyBatch([
          change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
          change(sequence: 2, id: 'order-2', orderNumber: '26-001'),
        ]),
        throwsA(isA<SyncConflictException>()),
      );

      expect(await db.select(db.orders).get(), isEmpty);
      expect(await syncStateDao.getLastAppliedSequence(), 0);
      final conflict = (await db.select(db.syncConflicts).get()).single;
      expect(conflict.entityId, 'order-2');
      expect(conflict.conflictType, 'duplicate_order_number');
    },
  );

  test(
    'same UUID create then changed-number update is rejected in one batch',
    () async {
      expect(
        () => applier.applyBatch([
          change(sequence: 1, id: 'order-1', orderNumber: '26-001'),
          change(
            sequence: 2,
            id: 'order-1',
            orderNumber: '26-002',
            operationType: 'update',
          ),
        ]),
        throwsA(isA<SyncConflictException>()),
      );

      expect(await db.select(db.orders).get(), isEmpty);
      expect(await syncStateDao.getLastAppliedSequence(), 0);
      final conflict = (await db.select(db.syncConflicts).get()).single;
      expect(conflict.entityId, 'order-1');
      expect(conflict.conflictType, 'order_number_changed');
    },
  );

  test('snapshot preserves a pending local order', () async {
    final syncOperationsDao = SyncOperationsDao(db);
    await db
        .into(db.orders)
        .insert(
          OrdersCompanion.insert(
            id: 'order-local',
            orderNumber: '26-001',
            customerId: 'customer-1',
            expectedPickupDate: now,
            subtotal: 1000,
            total: 1000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await syncOperationsDao.recordOperation(
      entityType: 'order',
      entityId: 'order-local',
      operationType: 'create',
      payload: '{}',
    );

    await applier.applySnapshot(
      PullChangesResponseDto(
        changes: [
          change(sequence: 10, id: 'order-local', orderNumber: '26-002'),
        ],
        hasMore: false,
        latestSequence: 10,
      ),
    );

    final localOrder = await (db.select(
      db.orders,
    )..where((table) => table.id.equals('order-local'))).getSingle();
    expect(localOrder.orderNumber, '26-001');
    expect(await syncStateDao.getLastAppliedSequence(), 10);
  });

  test(
    'SyncEngine exposes pull conflict without advancing the cursor',
    () async {
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-local',
              orderNumber: '26-001',
              customerId: 'customer-1',
              expectedPickupDate: now,
              subtotal: 1000,
              total: 1000,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final remoteDataSource = _ConflictRemoteDataSource(
        PullChangesResponseDto(
          changes: [
            change(sequence: 5, id: 'order-remote', orderNumber: '26-001'),
          ],
          hasMore: false,
          latestSequence: 5,
        ),
      );
      final engine = SyncEngine(
        syncOperationsDao: SyncOperationsDao(db),
        remoteApiDispatcher: _PullOnlyDispatcher(),
        networkInfo: _PullOnlyNetworkInfo(),
        retryPolicy: SyncRetryPolicy(),
        errorClassifier: const SyncErrorClassifier(),
        syncRemoteDataSource: remoteDataSource,
        remoteChangeApplier: applier,
        syncStateDao: syncStateDao,
      );

      await engine.pull();

      expect(engine.state.status.name, 'failed');
      expect(engine.state.lastError, contains('SyncConflictException'));
      expect(await syncStateDao.getLastAppliedSequence(), 0);
      expect(
        (await db.select(db.syncConflicts).get()).single.entityId,
        'order-remote',
      );
      engine.dispose();
    },
  );
}
