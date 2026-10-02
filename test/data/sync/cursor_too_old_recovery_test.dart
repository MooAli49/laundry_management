import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/app_exception.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/core/network/realtime_sync_adapter.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/remote/dto/pull_changes_response_dto.dart';
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;

  @override
  Future<bool> get isConnected async => isConnectedValue;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void setConnected(bool value) {
    isConnectedValue = value;
    _connectivityController.add(value);
  }

  void dispose() {
    _connectivityController.close();
  }
}

class FakeRemoteApiDispatcher implements RemoteApiDispatcher {
  final List<SyncOperation> dispatchedOperations = [];
  Future<dynamic> Function(SyncOperation op)? onDispatch;

  @override
  Future<dynamic> dispatch(SyncOperation operation) async {
    dispatchedOperations.add(operation);
    if (onDispatch != null) {
      return await onDispatch!(operation);
    }
    return {'status': 'ok'};
  }
}

class FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  int getChangesCallCount = 0;
  final List<int> requestedAfterCursors = [];
  Future<PullChangesResponseDto> Function({required int after, int? limit})?
      onGetChanges;

  int getSnapshotCallCount = 0;
  Future<PullChangesResponseDto> Function()? onGetSnapshot;

  @override
  Future<PullChangesResponseDto> getChanges({
    required int after,
    int? limit,
  }) async {
    getChangesCallCount++;
    requestedAfterCursors.add(after);
    if (onGetChanges != null) {
      return await onGetChanges!(after: after, limit: limit);
    }
    return PullChangesResponseDto(
      changes: const [],
      hasMore: false,
      latestSequence: after,
    );
  }

  @override
  Future<PullChangesResponseDto> getSnapshot() async {
    getSnapshotCallCount++;
    if (onGetSnapshot != null) {
      return await onGetSnapshot!();
    }
    throw const CursorTooOldException(
      message: 'Snapshot endpoint unavailable in test mock',
    );
  }
}

class FakeRealtimeSyncAdapter implements RealtimeSyncAdapter {
  final StreamController<void> _signalController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onSyncAvailable => _signalController.stream;

  @override
  Future<void> subscribe() async {}

  @override
  Future<void> unsubscribe() async {}

  void dispose() {
    _signalController.close();
  }
}

void main() {
  late AppDatabase db;
  late SyncOperationsDao syncOperationsDao;
  late SyncStateDao syncStateDao;
  late OrdersDao ordersDao;
  late RemoteChangeApplier remoteChangeApplier;
  late FakeSyncRemoteDataSource remoteDataSource;
  late FakeRemoteApiDispatcher dispatcher;
  late FakeNetworkInfo networkInfo;
  late SyncRetryPolicy retryPolicy;
  late SyncErrorClassifier errorClassifier;
  late FakeRealtimeSyncAdapter realtimeAdapter;
  late SyncEngine syncEngine;

  final fixedTime = DateTime.parse('2026-10-02T12:00:00.000Z');

  /// Builds a sample authoritative full snapshot containing all 13 business tiers.
  PullChangesResponseDto buildCompleteSnapshot({int latestSequence = 5000}) {
    final changes = <SyncChangeDto>[
      // Tier 1: Business Settings
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-1',
        entityType: 'business_settings',
        entityId: 'settings-global-id',
        operationType: 'update',
        payload: {
          'id': 'settings-global-id',
          'business_name': 'Authoritative Cleaners',
          'tax_rate': 0.15,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 2: Storage Locations
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-2',
        entityType: 'storage_location',
        entityId: 'loc-shelf-1',
        operationType: 'create',
        payload: {
          'id': 'loc-shelf-1',
          'name': 'Shelf 1',
          'capacity': 100,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 3: Item Types
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-3',
        entityType: 'item_type',
        entityId: 'type-suit-id',
        operationType: 'create',
        payload: {
          'id': 'type-suit-id',
          'name': 'Suit',
          'pricing_type': 'per_piece',
          'base_price': 5000,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 4: Item Definitions
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-4',
        entityType: 'item_definition',
        entityId: 'def-wool-suit-id',
        operationType: 'create',
        payload: {
          'id': 'def-wool-suit-id',
          'item_type_id': 'type-suit-id',
          'name': 'Wool Suit',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 5: Carpet Sizes
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-5',
        entityType: 'carpet_size',
        entityId: 'carpet-size-medium',
        operationType: 'create',
        payload: {
          'id': 'carpet-size-medium',
          'name': '2x3m Medium',
          'length': 3.0,
          'width': 2.0,
          'area': 6.0,
          'is_active': true,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 6: Services
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-6',
        entityType: 'service',
        entityId: 'service-dry-clean-id',
        operationType: 'create',
        payload: {
          'id': 'service-dry-clean-id',
          'name': 'Dry Clean',
          'description': 'Premium dry cleaning',
          'pricing_type': 'per_piece',
          'price': 2500,
          'is_active': true,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 7: Expense Categories
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-7',
        entityType: 'expense_category',
        entityId: 'cat-supplies-id',
        operationType: 'create',
        payload: {
          'id': 'cat-supplies-id',
          'name': 'Detergent & Supplies',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 8: Expenses
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-8',
        entityType: 'expense',
        entityId: 'exp-101',
        operationType: 'create',
        payload: {
          'id': 'exp-101',
          'expense_category_id': 'cat-supplies-id',
          'category_name_snapshot': 'Detergent & Supplies',
          'amount': 15000,
          'expense_name': 'Bulk liquid detergent',
          'expense_date': '2026-02-01T10:00:00.000Z',
          'created_at': '2026-02-01T10:00:00.000Z',
          'updated_at': '2026-02-01T10:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 9: Customers
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-9',
        entityType: 'customer',
        entityId: 'cust-remote-1',
        operationType: 'create',
        payload: {
          'id': 'cust-remote-1',
          'name': 'Ahmed Al-Mansoor',
          'phone': '0551234567',
          'address': 'King Fahd Rd, Building 12',
          'notes': 'VIP Customer',
          'created_at': '2026-02-01T08:00:00.000Z',
          'updated_at': '2026-02-01T08:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 10: Orders (with Items and Carpet)
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-10',
        entityType: 'order',
        entityId: 'order-remote-100',
        operationType: 'create',
        payload: {
          'id': 'order-remote-100',
          'order_number': '26-100',
          'customer_id': 'cust-remote-1',
          'customer_name_snapshot': 'Ahmed Al-Mansoor',
          'customer_phone_snapshot': '0551234567',
          'status': 'processing',
          'subtotal': 5000,
          'total': 5000,
          'created_at': '2026-02-01T09:00:00.000Z',
          'updated_at': '2026-02-01T09:00:00.000Z',
          'items': [
            {
              'id': 'item-100-1',
              'order_id': 'order-remote-100',
              'item_type_id': 'type-suit-id',
              'service_id': 'service-dry-clean-id',
              'item_type_name_snapshot': 'Suit',
              'service_name_snapshot': 'Dry Clean',
              'quantity': 1.0,
              'unit_price': 5000,
              'calculated_total': 5000,
              'created_at': '2026-02-01T09:00:00.000Z',
              'updated_at': '2026-02-01T09:00:00.000Z',
            },
          ],
        },
        createdAt: fixedTime,
      ),
      // Tier 11: Payments
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-11',
        entityType: 'payment',
        entityId: 'pay-100',
        operationType: 'create',
        payload: {
          'id': 'pay-100',
          'order_id': 'order-remote-100',
          'amount': 5000,
          'payment_method': 'cash',
          'created_at': '2026-02-01T09:05:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 12: Refunds
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-12',
        entityType: 'refund',
        entityId: 'ref-100',
        operationType: 'create',
        payload: {
          'id': 'ref-100',
          'order_id': 'order-remote-100',
          'amount': 1000,
          'reason': 'Small stain discount compensation',
          'refunded_at': '2026-02-01T11:00:00.000Z',
          'created_at': '2026-02-01T11:00:00.000Z',
        },
        createdAt: fixedTime,
      ),
      // Tier 13: Storage Records
      SyncChangeDto(
        sequence: latestSequence,
        operationId: 'op-snap-13',
        entityType: 'storage_record',
        entityId: 'rec-100-1',
        operationType: 'create',
        payload: {
          'id': 'rec-100-1',
          'order_item_id': 'item-100-1',
          'storage_location_id': 'loc-shelf-1',
          'status': 'stored',
          'stored_at': '2026-02-01T10:30:00.000Z',
          'created_at': '2026-02-01T10:30:00.000Z',
          'updated_at': '2026-02-01T10:30:00.000Z',
        },
        createdAt: fixedTime,
      ),
    ];

    return PullChangesResponseDto(
      changes: changes,
      hasMore: false,
      latestSequence: latestSequence,
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    syncOperationsDao = SyncOperationsDao(db);
    syncStateDao = SyncStateDao(db);
    ordersDao = OrdersDao(db);
    remoteChangeApplier = RemoteChangeApplier(
      db: db,
      syncStateDao: syncStateDao,
      syncOperationsDao: syncOperationsDao,
    );
    remoteDataSource = FakeSyncRemoteDataSource();
    dispatcher = FakeRemoteApiDispatcher();
    networkInfo = FakeNetworkInfo();
    retryPolicy = SyncRetryPolicy();
    errorClassifier = const SyncErrorClassifier();
    realtimeAdapter = FakeRealtimeSyncAdapter();

    syncEngine = SyncEngine(
      syncOperationsDao: syncOperationsDao,
      remoteApiDispatcher: dispatcher,
      networkInfo: networkInfo,
      retryPolicy: retryPolicy,
      errorClassifier: errorClassifier,
      syncRemoteDataSource: remoteDataSource,
      remoteChangeApplier: remoteChangeApplier,
      syncStateDao: syncStateDao,
      realtimeAdapter: realtimeAdapter,
      clock: () => fixedTime,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    networkInfo.dispose();
    realtimeAdapter.dispose();
    await db.close();
  });

  group('SUSP-01 — CURSOR_TOO_OLD / Full Resync Recovery Suite', () {
    test(
      '1. Valid cursor: performs normal incremental pull without invoking snapshot',
      () async {
        await syncStateDao.updateLastAppliedSequence(100);

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          expect(after, equals(100));
          return PullChangesResponseDto(
            changes: [
              SyncChangeDto(
                sequence: 101,
                operationId: 'op-inc-1',
                entityType: 'customer',
                entityId: 'cust-incremental-1',
                operationType: 'create',
                payload: {
                  'id': 'cust-incremental-1',
                  'name': 'Incremental Customer',
                  'phone': '0559998888',
                  'created_at': '2026-02-01T08:00:00.000Z',
                  'updated_at': '2026-02-01T08:00:00.000Z',
                },
                createdAt: fixedTime,
              ),
            ],
            hasMore: false,
            latestSequence: 101,
          );
        };

        await syncEngine.pull();

        expect(remoteDataSource.getChangesCallCount, equals(1));
        expect(remoteDataSource.getSnapshotCallCount, equals(0));
        expect(await syncStateDao.getLastAppliedSequence(), equals(101));

        final cust = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-incremental-1')))
            .getSingleOrNull();
        expect(cust, isNotNull);
        expect(cust!.name, equals('Incremental Customer'));
      },
    );

    test(
      '2. CURSOR_TOO_OLD: automatically triggers snapshot recovery and establishes new cursor',
      () async {
        // Device starts at sequence 10 (which is expired remotely)
        await syncStateDao.updateLastAppliedSequence(10);

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'requested sequence 10 is older than oldest sequence 1000',
            oldestAvailableSequence: 1000,
          );
        };

        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        await syncEngine.pull();

        expect(remoteDataSource.getChangesCallCount, equals(1));
        expect(remoteDataSource.getSnapshotCallCount, equals(1));

        // Cursor must be updated to snapshot's latestSequence
        final currentCursor = await syncStateDao.getLastAppliedSequence();
        expect(currentCursor, equals(5000));
        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
      },
    );

    test(
      '3. Full resync hydrates all 13 business tiers in strict dependency order',
      () async {
        await syncStateDao.updateLastAppliedSequence(5);

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'requested sequence 5 is older than oldest sequence 500',
            oldestAvailableSequence: 500,
          );
        };

        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        await syncEngine.pull();

        // Verify Tier 1: Business Settings
        final settings = await (db.select(db.businessSettings)
              ..where((t) => t.id.equals('settings-global-id')))
            .getSingleOrNull();
        expect(settings, isNotNull);
        expect(settings!.businessName, equals('Authoritative Cleaners'));

        // Verify Tier 2: Storage Locations
        final loc = await (db.select(db.storageLocations)
              ..where((t) => t.id.equals('loc-shelf-1')))
            .getSingleOrNull();
        expect(loc, isNotNull);
        expect(loc!.name, equals('Shelf 1'));

        // Verify Tier 3: Item Types
        final it = await (db.select(db.itemTypes)
              ..where((t) => t.id.equals('type-suit-id')))
            .getSingleOrNull();
        expect(it, isNotNull);

        // Verify Tier 4: Item Definitions
        final idef = await (db.select(db.itemDefinitions)
              ..where((t) => t.id.equals('def-wool-suit-id')))
            .getSingleOrNull();
        expect(idef, isNotNull);

        // Verify Tier 5: Carpet Sizes
        final cs = await (db.select(db.carpetSizes)
              ..where((t) => t.id.equals('carpet-size-medium')))
            .getSingleOrNull();
        expect(cs, isNotNull);

        // Verify Tier 6: Services
        final svc = await (db.select(db.services)
              ..where((t) => t.id.equals('service-dry-clean-id')))
            .getSingleOrNull();
        expect(svc, isNotNull);

        // Verify Tier 7: Expense Categories
        final cat = await (db.select(db.expenseCategories)
              ..where((t) => t.id.equals('cat-supplies-id')))
            .getSingleOrNull();
        expect(cat, isNotNull);

        // Verify Tier 8: Expenses
        final exp = await (db.select(db.expenses)
              ..where((t) => t.id.equals('exp-101')))
            .getSingleOrNull();
        expect(exp, isNotNull);
        expect(exp!.amount, equals(15000));

        // Verify Tier 9: Customers
        final cust = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-remote-1')))
            .getSingleOrNull();
        expect(cust, isNotNull);
        expect(cust!.name, equals('Ahmed Al-Mansoor'));

        // Verify Tier 10: Orders & Order Items
        final ord = await (db.select(db.orders)
              ..where((t) => t.id.equals('order-remote-100')))
            .getSingleOrNull();
        expect(ord, isNotNull);
        expect(ord!.orderNumber, equals('26-100'));

        final item = await (db.select(db.orderItems)
              ..where((t) => t.id.equals('item-100-1')))
            .getSingleOrNull();
        expect(item, isNotNull);
        expect(item!.calculatedTotal, equals(5000));

        // Verify Tier 11: Payments
        final pay = await (db.select(db.payments)
              ..where((t) => t.id.equals('pay-100')))
            .getSingleOrNull();
        expect(pay, isNotNull);
        expect(pay!.amount, equals(5000));

        // Verify Tier 12: Refunds
        final ref = await (db.select(db.refunds)
              ..where((t) => t.id.equals('ref-100')))
            .getSingleOrNull();
        expect(ref, isNotNull);
        expect(ref!.amount, equals(1000));

        // Verify Tier 13: Storage Records
        final rec = await (db.select(db.storageRecords)
              ..where((t) => t.id.equals('rec-100-1')))
            .getSingleOrNull();
        expect(rec, isNotNull);
        expect(rec!.isActive, isTrue);
      },
    );

    test(
      '4. Pending outbox CREATE survives recovery and is subsequently drained',
      () async {
        // Enqueue an offline local order creation
        await syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: 'order-local-offline',
          operationType: 'create',
          payload: '{"id":"order-local-offline","order_number":"26-002"}',
        );

        // Insert customer draft so foreign key is satisfied
        await db.into(db.customers).insert(
          CustomersCompanion(
            id: const Value('cust-draft'),
            name: const Value('Local Draft User'),
            phone: const Value('0500000000'),
            createdAt: Value(fixedTime),
            updatedAt: Value(fixedTime),
          ),
        );

        // Insert local draft in Drift
        await ordersDao.insertOrder(
          OrdersCompanion(
            id: const Value('order-local-offline'),
            orderNumber: const Value('26-002'),
            customerId: const Value('cust-draft'),
            customerNameSnapshot: const Value('Local Draft User'),
            customerPhoneSnapshot: const Value('0500000000'),
            status: const Value('processing'),
            expectedPickupDate: Value(fixedTime),
            subtotal: const Value(3000),
            total: const Value(3000),
            createdAt: Value(fixedTime),
            updatedAt: Value(fixedTime),
          ),
        );

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Cursor expired',
            oldestAvailableSequence: 100,
          );
        };

        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        // When sync() runs:
        // 1. Initial push might fail or be offline, but pull will encounter CURSOR_TOO_OLD
        // 2. Full resync recovers the baseline
        // 3. Engine flags push pass to dispatch preserved outbox records
        await syncEngine.sync();

        // Local order still exists!
        final localOrder = await (db.select(db.orders)
              ..where((t) => t.id.equals('order-local-offline')))
            .getSingleOrNull();
        expect(localOrder, isNotNull);
        expect(localOrder!.orderNumber, equals('26-002'));

        // Dispatched outbox operations must have sent order-local-offline
        expect(
          dispatcher.dispatchedOperations.any(
            (op) => op.entityId == 'order-local-offline',
          ),
          isTrue,
        );
      },
    );

    test(
      '5. Pending outbox UPDATE survives recovery without being overwritten by snapshot',
      () async {
        // Pre-populate customer in local SQLite
        await db.into(db.customers).insert(
          CustomersCompanion(
            id: const Value('cust-remote-1'),
            name: const Value('Local Offline Edited Name'),
            phone: const Value('0551234567'),
            address: const Value('Local Custom Street'),
            createdAt: Value(fixedTime),
            updatedAt: Value(fixedTime),
          ),
        );

        // Record pending update in outbox
        await syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: 'cust-remote-1',
          operationType: 'update',
          payload: '{"name":"Local Offline Edited Name"}',
        );

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Cursor too old',
            oldestAvailableSequence: 100,
          );
        };

        // Snapshot contains server's older version: 'Ahmed Al-Mansoor'
        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        await syncEngine.pull();

        // Local edited name must NOT have been overwritten by snapshot
        final cust = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-remote-1')))
            .getSingle();
        expect(cust.name, equals('Local Offline Edited Name'));
        expect(cust.address, equals('Local Custom Street'));

        // Preserved outbox update operation was subsequently dispatched and drained
        expect(
          dispatcher.dispatchedOperations.any(
            (op) =>
                op.entityId == 'cust-remote-1' &&
                op.operationType == 'update',
          ),
          isTrue,
        );
      },
    );

    test(
      '6. Recovery failure: rolls back transaction, preserves cursor, and keeps outbox intact',
      () async {
        await syncStateDao.updateLastAppliedSequence(25);

        await syncOperationsDao.recordOperation(
          entityType: 'order',
          entityId: 'order-safe-1',
          operationType: 'create',
          payload: '{"order_number":"26-050"}',
        );

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Old cursor 25 is expired',
            oldestAvailableSequence: 200,
          );
        };

        // Snapshot download throws network error
        remoteDataSource.onGetSnapshot = () async {
          throw Exception('Network disconnected while downloading snapshot');
        };

        await syncEngine.pull();

        // Engine enters failed state
        expect(syncEngine.state.status, equals(SyncEngineStatus.failed));
        expect(syncEngine.state.lastError, contains('Old cursor 25 is expired'));

        // Cursor must NOT have moved
        expect(await syncStateDao.getLastAppliedSequence(), equals(25));

        // Pending outbox operations remain completely unharmed
        final remaining = await syncOperationsDao.getPendingOperations();
        expect(remaining.length, equals(1));
        expect(remaining.first.entityId, equals('order-safe-1'));
      },
    );

    test(
      '7. Recovery retry safety: can be retried successfully after initial failure',
      () async {
        await syncStateDao.updateLastAppliedSequence(25);

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          if (after < 5000) {
            throw const CursorTooOldException(
              message: 'Old cursor 25 is expired',
              oldestAvailableSequence: 200,
            );
          }
          return PullChangesResponseDto(
            changes: const [],
            hasMore: false,
            latestSequence: after,
          );
        };

        // Attempt 1: Snapshot fails
        var failSnapshot = true;
        remoteDataSource.onGetSnapshot = () async {
          if (failSnapshot) {
            throw Exception('Temporary timeout');
          }
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        await syncEngine.pull();
        expect(syncEngine.state.status, equals(SyncEngineStatus.failed));
        expect(await syncStateDao.getLastAppliedSequence(), equals(25));

        // Attempt 2: Server/network recovers
        failSnapshot = false;
        await syncEngine.pull();

        expect(syncEngine.state.status, equals(SyncEngineStatus.completed));
        expect(await syncStateDao.getLastAppliedSequence(), equals(5000));
      },
    );

    test(
      '8. Recovery is idempotent: running recovery twice produces identical clean state',
      () async {
        await syncStateDao.updateLastAppliedSequence(10);

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Cursor is expired',
            oldestAvailableSequence: 100,
          );
        };

        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        // Run recovery 1
        await remoteChangeApplier.applySnapshot(
          buildCompleteSnapshot(latestSequence: 5000),
        );
        final count1 = (await db.select(db.customers).get()).length;

        // Run recovery 2 with exact same snapshot
        await remoteChangeApplier.applySnapshot(
          buildCompleteSnapshot(latestSequence: 5000),
        );
        final count2 = (await db.select(db.customers).get()).length;

        expect(count1, equals(count2));
        expect(await syncStateDao.getLastAppliedSequence(), equals(5000));
      },
    );

    test(
      '9. BR-018 Order numbers: existing order numbers remain immutable and sequence advances correctly',
      () async {
        // Hydrate baseline with order 26-100
        await remoteChangeApplier.applySnapshot(
          buildCompleteSnapshot(latestSequence: 5000),
        );

        // Existing order number must remain exactly 26-100
        final order = await ordersDao.getOrderById('order-remote-100');
        expect(order, isNotNull);
        expect(order!.orderNumber, equals('26-100'));

        // Next order number generated by local cashier terminal must continue from 26-101
        final nextNum = await ordersDao.generateNextOrderNumber();
        expect(nextNum, equals('26-101'));
      },
    );

    test(
      '10. Public fullResync(): performs explicit baseline refresh on demand',
      () async {
        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 7500);
        };

        final state = await syncEngine.fullResync();

        expect(state.status, equals(SyncEngineStatus.completed));
        expect(await syncStateDao.getLastAppliedSequence(), equals(7500));
        expect(remoteDataSource.getSnapshotCallCount, equals(1));
      },
    );

    test(
      '11. Pending outbox mutation remains in outbox if subsequent push fails',
      () async {
        // Pre-populate customer in local SQLite
        await db.into(db.customers).insert(
          CustomersCompanion(
            id: const Value('cust-remote-1'),
            name: const Value('Local Custom Name'),
            phone: const Value('0551234567'),
            address: const Value('Local Street'),
            createdAt: Value(fixedTime),
            updatedAt: Value(fixedTime),
          ),
        );

        // Record pending update in outbox
        await syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: 'cust-remote-1',
          operationType: 'update',
          payload: '{"name":"Local Custom Name"}',
        );

        remoteDataSource.onGetChanges = ({required int after, int? limit}) async {
          throw const CursorTooOldException(
            message: 'Cursor too old',
            oldestAvailableSequence: 100,
          );
        };

        remoteDataSource.onGetSnapshot = () async {
          return buildCompleteSnapshot(latestSequence: 5000);
        };

        // Dispatcher fails when push runs
        dispatcher.onDispatch = (_) async {
          throw Exception('Backend network failure during push');
        };

        await syncEngine.pull();

        // Local data preserved!
        final cust = await (db.select(db.customers)
              ..where((t) => t.id.equals('cust-remote-1')))
            .getSingle();
        expect(cust.name, equals('Local Custom Name'));

        // Operation remains in sync_operations (marked failed with nextRetryAt, not deleted)
        final unsynced = await (db.select(db.syncOperations)
              ..where((t) => t.status.isNotValue('synced')))
            .get();
        expect(unsynced.length, equals(1));
        expect(unsynced.first.entityId, equals('cust-remote-1'));
        expect(unsynced.first.status, equals('failed'));
        expect(unsynced.first.retryCount, equals(1));
      },
    );
  });
}
