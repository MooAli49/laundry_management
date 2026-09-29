import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/license/license_service.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/license_cache_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/domain/license/license_status.dart';

// ---------------------------------------------------------------------------
// Fake helpers
// ---------------------------------------------------------------------------

class _FakeNetworkInfo {
  bool connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  _FakeNetworkInfo({this.connected = true});

  Future<bool> get isConnected async => connected;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setConnected(bool value) {
    connected = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}

/// A minimal adapter so [_FakeNetworkInfo] satisfies [NetworkInfo]'s interface.
class _NetworkInfoAdapter implements NetworkInfo {
  final _FakeNetworkInfo _fake;
  _NetworkInfoAdapter(this._fake);

  @override
  Future<bool> get isConnected => _fake.isConnected;

  @override
  Stream<bool> get onConnectivityChanged => _fake.onConnectivityChanged;
}

class _FakeRemoteDataSource implements LicenseRemoteDataSource {
  String status;
  DateTime? suspendedAt;
  bool shouldThrow;

  _FakeRemoteDataSource({
    this.status = 'active',
    this.suspendedAt,
    this.shouldThrow = false,
  });

  @override
  Future<LicenseRemoteData> fetchLicenseInfo() async {
    if (shouldThrow) throw Exception('Network error');
    return LicenseRemoteData(status: status, suspendedAt: suspendedAt);
  }
}

// ---------------------------------------------------------------------------
// Helper to build a LicenseService with injectable clock
// ---------------------------------------------------------------------------
LicenseService _buildService({
  required AppDatabase db,
  required LicenseRemoteDataSource remote,
  required _FakeNetworkInfo network,
  DateTime Function()? clock,
}) {
  return LicenseService(
    remoteDataSource: remote,
    cacheDao: LicenseCacheDao(db),
    networkInfo: _NetworkInfoAdapter(network),
    clock: clock,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // A — Active license
  // -------------------------------------------------------------------------
  group('A — Active license', () {
    test('initialize reports active when remote returns active', () async {
      final remote = _FakeRemoteDataSource(status: 'active');
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(db: db, remote: remote, network: network);

      await service.initialize();

      expect(service.currentStatus, LicenseStatus.active);
      service.dispose();
      network.dispose();
    });

    test('statusStream emits active on initialize', () async {
      final remote = _FakeRemoteDataSource(status: 'active');
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(db: db, remote: remote, network: network);

      final statuses = <LicenseStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      await service.initialize();
      await pumpEventQueue();

      expect(statuses, contains(LicenseStatus.active));
      await sub.cancel();
      service.dispose();
      network.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // B — Suspended / grace period
  // -------------------------------------------------------------------------
  group('B — Suspended / grace period', () {
    test('suspended with suspendedAt < 7 days ago → gracePeriod', () async {
      final suspendedAt = DateTime(2026, 9, 24); // 3 days before clock
      DateTime clock() => DateTime(2026, 9, 27);
      final remote = _FakeRemoteDataSource(
        status: 'suspended',
        suspendedAt: suspendedAt,
      );
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(
        db: db,
        remote: remote,
        network: network,
        clock: clock,
      );

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.gracePeriod);
      service.dispose();
      network.dispose();
    });

    test('suspended with suspendedAt exactly 7 days ago → lockedOut', () async {
      final suspendedAt = DateTime(2026, 9, 20, 12, 0);
      DateTime clock() => suspendedAt.add(const Duration(days: 7));
      final remote = _FakeRemoteDataSource(
        status: 'suspended',
        suspendedAt: suspendedAt,
      );
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(
        db: db,
        remote: remote,
        network: network,
        clock: clock,
      );

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.lockedOut);
      service.dispose();
      network.dispose();
    });

    test('suspended with suspendedAt > 7 days ago → lockedOut', () async {
      final suspendedAt = DateTime(2026, 9, 1);
      DateTime clock() => DateTime(2026, 9, 20);
      final remote = _FakeRemoteDataSource(
        status: 'suspended',
        suspendedAt: suspendedAt,
      );
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(
        db: db,
        remote: remote,
        network: network,
        clock: clock,
      );

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.lockedOut);
      service.dispose();
      network.dispose();
    });

    test(
      'suspendedAt is stored from remote, not local detection time',
      () async {
        // Remote says suspended since 5 days ago; even though device "discovers"
        // it today, the authoritative timestamp is from Supabase.
        final remoteTimestamp = DateTime(2026, 9, 22, 10, 0);
        DateTime clock() => DateTime(2026, 9, 27); // 5 days later
        final remote = _FakeRemoteDataSource(
          status: 'suspended',
          suspendedAt: remoteTimestamp,
        );
        final network = _FakeNetworkInfo(connected: true);
        final service = _buildService(
          db: db,
          remote: remote,
          network: network,
          clock: clock,
        );

        await service.initialize();

        expect(service.currentStatus, LicenseStatus.gracePeriod);
        expect(service.suspendedAt, isNotNull);
        expect(
          service.suspendedAt!.difference(remoteTimestamp).inSeconds.abs(),
          lessThan(1),
        );
        service.dispose();
        network.dispose();
      },
    );
  });

  // -------------------------------------------------------------------------
  // C — Offline behavior
  // -------------------------------------------------------------------------
  group('C — Offline / cached state', () {
    test('offline + no cache → fails open (active)', () async {
      final remote = _FakeRemoteDataSource(shouldThrow: true);
      final network = _FakeNetworkInfo(connected: false);
      final service = _buildService(db: db, remote: remote, network: network);

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.active);
      service.dispose();
      network.dispose();
    });

    test('offline + cached active → continues active', () async {
      // Pre-populate cache with active state
      final dao = LicenseCacheDao(db);
      await dao.saveCache(
        remoteStatus: 'active',
        suspendedAt: null,
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final remote = _FakeRemoteDataSource(shouldThrow: true);
      final network = _FakeNetworkInfo(connected: false);
      final service = _buildService(db: db, remote: remote, network: network);

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.active);
      service.dispose();
      network.dispose();
    });

    test(
      'offline + cached suspended, grace not expired → gracePeriod',
      () async {
        final suspendedAt = DateTime.now().subtract(const Duration(days: 3));
        final dao = LicenseCacheDao(db);
        await dao.saveCache(
          remoteStatus: 'suspended',
          suspendedAt: suspendedAt,
          lastCheckedAt: DateTime.now().subtract(const Duration(hours: 2)),
        );

        final remote = _FakeRemoteDataSource(shouldThrow: true);
        final network = _FakeNetworkInfo(connected: false);
        final service = _buildService(db: db, remote: remote, network: network);

        await service.initialize();
        expect(service.currentStatus, LicenseStatus.gracePeriod);
        service.dispose();
        network.dispose();
      },
    );

    test('offline + cached suspended, grace expired → lockedOut', () async {
      final suspendedAt = DateTime.now().subtract(const Duration(days: 8));
      final dao = LicenseCacheDao(db);
      await dao.saveCache(
        remoteStatus: 'suspended',
        suspendedAt: suspendedAt,
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final remote = _FakeRemoteDataSource(shouldThrow: true);
      final network = _FakeNetworkInfo(connected: false);
      final service = _buildService(db: db, remote: remote, network: network);

      await service.initialize();
      expect(service.currentStatus, LicenseStatus.lockedOut);
      service.dispose();
      network.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // D — 24-hour throttle
  // -------------------------------------------------------------------------
  group('D — 24-hour throttle', () {
    test('checkIfDue skips remote when checked within 24 hours', () async {
      int fetchCount = 0;
      final remote = _FakeRemoteDataSource(status: 'active');
      // Wrap remote to count fetches
      final countingRemote = _CountingRemoteDataSource(
        remote,
        () => fetchCount++,
      );

      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(
        db: db,
        remote: countingRemote,
        network: network,
      );

      // Initialize (forced, fetches once)
      await service.initialize();
      expect(fetchCount, 1);

      // checkIfDue with recent lastCheckedAt — should skip remote
      await service.checkIfDue();
      expect(fetchCount, 1, reason: 'Should not fetch again within 24h');

      service.dispose();
      network.dispose();
    });

    test('checkIfDue re-fetches when last check was > 24 hours ago', () async {
      int fetchCount = 0;
      var currentTime = DateTime(2026, 9, 1, 10, 0);

      final remote = _FakeRemoteDataSource(status: 'active');
      final countingRemote = _CountingRemoteDataSource(
        remote,
        () => fetchCount++,
      );
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(
        db: db,
        remote: countingRemote,
        network: network,
        clock: () => currentTime,
      );

      await service.initialize(); // forced, bypasses throttle → fetch #1
      expect(fetchCount, 1);

      // Advance clock past 24 hours
      currentTime = currentTime.add(const Duration(hours: 25));

      await service.checkIfDue(); // stale cache → fetch #2
      expect(fetchCount, 2, reason: 'Should re-fetch after 24h threshold');

      service.dispose();
      network.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // E — Reactivation
  // -------------------------------------------------------------------------
  group('E — Reactivation', () {
    test(
      'remote returns active after suspension → status reverts to active',
      () async {
        // Start suspended
        final suspendedAt = DateTime.now().subtract(const Duration(days: 2));
        final dao = LicenseCacheDao(db);
        await dao.saveCache(
          remoteStatus: 'suspended',
          suspendedAt: suspendedAt,
          lastCheckedAt: DateTime.now().subtract(const Duration(hours: 25)),
        );

        // Remote now returns active
        final remote = _FakeRemoteDataSource(
          status: 'active',
          suspendedAt: null,
        );
        final network = _FakeNetworkInfo(connected: true);
        final service = _buildService(db: db, remote: remote, network: network);

        await service.initialize();
        expect(service.currentStatus, LicenseStatus.active);
        expect(service.suspendedAt, isNull);

        service.dispose();
        network.dispose();
      },
    );
  });

  // -------------------------------------------------------------------------
  // F — Re-suspension with newer timestamp
  // -------------------------------------------------------------------------
  group('F — Re-suspension with newer timestamp', () {
    test('newer remote suspendedAt replaces older cached value', () async {
      final oldSuspendedAt = DateTime(2026, 9, 1);
      final dao = LicenseCacheDao(db);
      await dao.saveCache(
        remoteStatus: 'suspended',
        suspendedAt: oldSuspendedAt,
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      final newSuspendedAt = DateTime(2026, 9, 20); // newer
      final remote = _FakeRemoteDataSource(
        status: 'suspended',
        suspendedAt: newSuspendedAt,
      );
      final network = _FakeNetworkInfo(connected: true);

      // Use clock just 3 days after new suspension so it's gracePeriod
      DateTime clock() => DateTime(2026, 9, 23);
      final service = _buildService(
        db: db,
        remote: remote,
        network: network,
        clock: clock,
      );

      await service.initialize();
      // Should use new suspendedAt (Sep 20) and be in grace period
      expect(service.currentStatus, LicenseStatus.gracePeriod);
      expect(
        service.suspendedAt!.isAfter(oldSuspendedAt),
        isTrue,
        reason: 'Newer remote timestamp must replace the older cached one',
      );

      service.dispose();
      network.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // G — Remote failure falls back to cache
  // -------------------------------------------------------------------------
  group('G — Remote failure', () {
    test('remote fetch failure uses cached state', () async {
      final suspendedAt = DateTime.now().subtract(const Duration(days: 1));
      final dao = LicenseCacheDao(db);
      await dao.saveCache(
        remoteStatus: 'suspended',
        suspendedAt: suspendedAt,
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Remote throws
      final remote = _FakeRemoteDataSource(shouldThrow: true);
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(db: db, remote: remote, network: network);

      await service.initialize();
      // Should fall back to cached gracePeriod
      expect(service.currentStatus, LicenseStatus.gracePeriod);

      service.dispose();
      network.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // H — Business data preservation
  // -------------------------------------------------------------------------
  group('H — Business data not modified', () {
    test('license operations do not modify business tables', () async {
      // Seed a customer manually
      await db.customStatement(
        'INSERT INTO customers (id, name, phone, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        ['cust-1', 'Test', '01011111111', 0, 0],
      );

      final remote = _FakeRemoteDataSource(
        status: 'suspended',
        suspendedAt: DateTime.now(),
      );
      final network = _FakeNetworkInfo(connected: true);
      final service = _buildService(db: db, remote: remote, network: network);
      await service.initialize();

      final customers = await db.select(db.customers).get();
      expect(
        customers.length,
        1,
        reason: 'License initialization must NOT modify customer records',
      );

      service.dispose();
      network.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Counting wrapper for remote data source
// ---------------------------------------------------------------------------
class _CountingRemoteDataSource implements LicenseRemoteDataSource {
  final LicenseRemoteDataSource _inner;
  final void Function() _onFetch;

  _CountingRemoteDataSource(this._inner, this._onFetch);

  @override
  Future<LicenseRemoteData> fetchLicenseInfo() async {
    _onFetch();
    return _inner.fetchLicenseInfo();
  }
}
