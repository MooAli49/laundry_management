import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;

void main() {
  late app_db.AppDatabase db;
  late SyncOperationsDao dao;

  final now = DateTime(2026, 10, 1, 10);

  setUp(() {
    db = app_db.AppDatabase(NativeDatabase.memory());
    dao = SyncOperationsDao(db);
  });

  tearDown(() => db.close());

  Future<void> insertOperation({
    required String id,
    required DateTime createdAt,
    String status = 'pending',
    DateTime? nextRetryAt,
  }) {
    return db
        .into(db.syncOperations)
        .insert(
          app_db.SyncOperationsCompanion(
            id: Value(id),
            entityType: const Value('customer'),
            entityId: Value(id),
            operationType: const Value('create'),
            status: Value(status),
            retryCount: const Value(0),
            nextRetryAt: Value(nextRetryAt),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );
  }

  test('retrying older operation blocks newer pending operation', () async {
    await insertOperation(
      id: 'op-1',
      createdAt: now,
      status: 'failed',
      nextRetryAt: now.add(const Duration(minutes: 5)),
    );
    await insertOperation(
      id: 'op-2',
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final eligible = await dao.getEligibleOperations(asOf: now);

    expect(eligible, isEmpty);
  });

  test('eligible retry is selected before newer pending operation', () async {
    await insertOperation(
      id: 'op-1',
      createdAt: now,
      status: 'failed',
      nextRetryAt: now,
    );
    await insertOperation(
      id: 'op-2',
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final eligible = await dao.getEligibleOperations(asOf: now);

    expect(eligible.map((operation) => operation.id), ['op-1', 'op-2']);
  });

  test('pending operations are returned in FIFO order', () async {
    await insertOperation(id: 'op-1', createdAt: now);
    await insertOperation(
      id: 'op-2',
      createdAt: now.add(const Duration(seconds: 1)),
    );
    await insertOperation(
      id: 'op-3',
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final eligible = await dao.getEligibleOperations(asOf: now);

    expect(eligible.map((operation) => operation.id), ['op-1', 'op-2', 'op-3']);
  });

  test('permanent failure does not block later operations', () async {
    await insertOperation(id: 'op-1', createdAt: now, status: 'failed');
    await insertOperation(
      id: 'op-2',
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final eligible = await dao.getEligibleOperations(asOf: now);

    expect(eligible.map((operation) => operation.id), ['op-2']);
  });
}
