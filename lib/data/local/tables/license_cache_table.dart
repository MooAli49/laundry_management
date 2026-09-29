import 'package:drift/drift.dart';

/// Local cache table for the remote license state.
///
/// Single-row singleton (id = 'singleton') that mirrors the authoritative
/// `license_info` row from Supabase, fetched at most once every 24 hours.
///
/// Design notes:
/// - [remoteStatus]: Raw string value from the remote API ('active' | 'suspended').
/// - [suspendedAt]: The authoritative suspension timestamp from Supabase
///   (`license_info.suspended_at`). This is NOT set locally — it always
///   originates from the remote. On reactivation, this column is cleared.
///   On a new suspension (admin suspended again with a newer timestamp), this
///   is updated to the newer remote value, giving a fresh 7-day grace window.
/// - [lastCheckedAt]: When the remote API was last successfully polled.
///   Used for the 24-hour throttle logic in [LicenseService].
///
/// This is NOT a sync table. It does not participate in the SyncEngine or the
/// sync_operations outbox. It is a read-only mirror for offline-safe evaluation.
class LicenseCache extends Table {
  @override
  String get tableName => 'license_cache';

  /// Always 'singleton' — enforces a single-row design.
  TextColumn get id => text().withDefault(const Constant('singleton'))();

  /// Raw remote status value: 'active' or 'suspended'.
  TextColumn get remoteStatus => text().withDefault(const Constant('active'))();

  /// Authoritative suspension timestamp from Supabase `license_info.suspended_at`.
  /// NULL when status is 'active' or when the remote has not provided a timestamp.
  DateTimeColumn get suspendedAt => dateTime().nullable()();

  /// Timestamp of the last successful remote license check.
  /// NULL on first install before any remote check has succeeded.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// Row update timestamp (local).
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
