import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

/// Data Access Object for the local license cache.
///
/// Manages the single-row `license_cache` table (id = 'singleton') that
/// stores a local mirror of the remote `license_info` state.
///
/// Responsibilities:
/// - Reading the cached license state for offline evaluation.
/// - Writing updated license data received from the remote API.
/// - Clearing the suspension timestamp when the license is reactivated.
///
/// This DAO never produces [SyncOperation] records and is completely
/// isolated from the SyncEngine outbox.
class LicenseCacheDao extends DatabaseAccessor<app_db.AppDatabase> {
  LicenseCacheDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  static const String _singletonId = 'singleton';

  /// Returns the cached license row, or `null` if no remote check has ever
  /// succeeded (e.g., brand-new install with no connectivity).
  Future<app_db.LicenseCacheData?> getCached() async {
    return (select(
      db.licenseCache,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
  }

  /// Persists or updates the cached license state with data from the remote API.
  ///
  /// - [remoteStatus]: The raw status string ('active' | 'suspended').
  /// - [suspendedAt]: The authoritative suspension timestamp from Supabase.
  ///   Pass `null` when the status is 'active' to clear any prior timestamp.
  /// - [lastCheckedAt]: When the remote check was performed (defaults to now).
  Future<void> saveCache({
    required String remoteStatus,
    required DateTime? suspendedAt,
    DateTime? lastCheckedAt,
  }) async {
    final now = DateTime.now();
    final companion = app_db.LicenseCacheCompanion(
      id: const Value(_singletonId),
      remoteStatus: Value(remoteStatus),
      suspendedAt: Value(suspendedAt),
      lastCheckedAt: Value(lastCheckedAt ?? now),
      updatedAt: Value(now),
    );
    await into(db.licenseCache).insertOnConflictUpdate(companion);
  }
}
