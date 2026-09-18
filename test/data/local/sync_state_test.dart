import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  group('SyncState & SyncStateDao Tests', () {
    late AppDatabase db;
    late SyncStateDao syncStateDao;
    late SyncOperationsDao syncOperationsDao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      syncStateDao = SyncStateDao(db);
      syncOperationsDao = SyncOperationsDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. sync_state initial cursor is 0 and singleton exists', () async {
      final state = await syncStateDao.getSyncState();

      expect(state.id, equals('singleton'));
      expect(state.lastAppliedSequence, equals(0));
      expect(state.lastSyncAt, isNull);
      expect(state.updatedAt, isNotNull);

      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(0));
    });

    test('2. Cursor persistence: updating cursor stores it durably in SQLite', () async {
      final now = DateTime.now();
      await syncStateDao.updateLastAppliedSequence(42, syncAt: now);

      var seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(42));

      var state = await syncStateDao.getSyncState();
      expect(state.lastAppliedSequence, equals(42));
      expect(state.lastSyncAt, isNotNull);
      expect(
        state.lastSyncAt!.millisecondsSinceEpoch ~/ 1000,
        equals(now.millisecondsSinceEpoch ~/ 1000),
      );

      // Advance cursor again
      await syncStateDao.updateLastAppliedSequence(108);

      seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(108));

      state = await syncStateDao.getSyncState();
      expect(state.lastAppliedSequence, equals(108));
    });

    test('3. sync_state operations NEVER create outgoing SyncOperation rows', () async {
      await syncStateDao.getSyncState();
      await syncStateDao.updateLastAppliedSequence(10);
      await syncStateDao.updateLastAppliedSequence(20);

      final pending = await syncOperationsDao.getPendingOperations();
      expect(pending, isEmpty);
    });
  });
}
