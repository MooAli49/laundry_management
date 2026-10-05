import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/license_cache_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  late AppDatabase db;
  late LicenseCacheDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = LicenseCacheDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LicenseCacheDao', () {
    // -------------------------------------------------------------------------
    // 1. Initial state — no cached row
    // -------------------------------------------------------------------------
    test('returns null when no cache exists (first install)', () async {
      final result = await dao.getCached();
      expect(result, isNull);
    });

    // -------------------------------------------------------------------------
    // 2. Persist active status
    // -------------------------------------------------------------------------
    test('saves and retrieves active status', () async {
      await dao.saveCache(remoteStatus: 'active', suspendedAt: null);
      final cached = await dao.getCached();

      expect(cached, isNotNull);
      expect(cached!.remoteStatus, 'active');
      expect(cached.suspendedAt, isNull);
      expect(cached.lastCheckedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 3. Persist suspended status with timestamp
    // -------------------------------------------------------------------------
    test('saves and retrieves suspended status with suspendedAt', () async {
      final suspendedAt = DateTime(2026, 9, 1, 12, 0);
      await dao.saveCache(remoteStatus: 'suspended', suspendedAt: suspendedAt);
      final cached = await dao.getCached();

      expect(cached!.remoteStatus, 'suspended');
      // Drift stores DateTime as UTC milliseconds; compare within 1 second.
      expect(
        cached.suspendedAt!.difference(suspendedAt).inSeconds.abs(),
        lessThan(1),
      );
    });

    // -------------------------------------------------------------------------
    // 4. Upsert is idempotent — second write overwrites first
    // -------------------------------------------------------------------------
    test('upsert overwrites previous value idempotently', () async {
      await dao.saveCache(remoteStatus: 'active', suspendedAt: null);
      final suspendedAt = DateTime(2026, 9, 10, 8, 0);
      await dao.saveCache(remoteStatus: 'suspended', suspendedAt: suspendedAt);
      final cached = await dao.getCached();
      expect(cached!.remoteStatus, 'suspended');
      expect(cached.suspendedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 5. Clearing suspendedAt on reactivation
    // -------------------------------------------------------------------------
    test('clears suspendedAt when reactivated', () async {
      await dao.saveCache(
        remoteStatus: 'suspended',
        suspendedAt: DateTime(2026, 9, 1),
      );
      await dao.saveCache(remoteStatus: 'active', suspendedAt: null);
      final cached = await dao.getCached();
      expect(cached!.remoteStatus, 'active');
      expect(cached.suspendedAt, isNull);
    });

    // -------------------------------------------------------------------------
    // 6. lastCheckedAt defaults to now
    // -------------------------------------------------------------------------
    test('lastCheckedAt is set automatically when not provided', () async {
      final before = DateTime.now();
      await dao.saveCache(remoteStatus: 'active', suspendedAt: null);
      final after = DateTime.now();
      final cached = await dao.getCached();
      expect(cached!.lastCheckedAt, isNotNull);
      expect(
        cached.lastCheckedAt!.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        cached.lastCheckedAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // 7. Custom lastCheckedAt is preserved
    // -------------------------------------------------------------------------
    test('custom lastCheckedAt is stored correctly', () async {
      final customTime = DateTime(2026, 1, 1, 0, 0);
      await dao.saveCache(
        remoteStatus: 'active',
        suspendedAt: null,
        lastCheckedAt: customTime,
      );
      final cached = await dao.getCached();
      expect(
        cached!.lastCheckedAt!.difference(customTime).inSeconds.abs(),
        lessThan(1),
      );
    });

    // -------------------------------------------------------------------------
    // 8. Business data tables are not modified
    // -------------------------------------------------------------------------
    test('saveCache does not modify business data tables', () async {
      await dao.saveCache(
        remoteStatus: 'suspended',
        suspendedAt: DateTime.now(),
      );

      final customers = await db.select(db.customers).get();
      final orders = await db.select(db.orders).get();
      final payments = await db.select(db.payments).get();

      expect(
        customers,
        isEmpty,
        reason: 'License operations must not affect customers',
      );
      expect(
        orders,
        isEmpty,
        reason: 'License operations must not affect orders',
      );
      expect(
        payments,
        isEmpty,
        reason: 'License operations must not affect payments',
      );
    });
  });
}
