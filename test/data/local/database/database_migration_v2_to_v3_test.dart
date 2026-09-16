import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Database Migration v2 -> v3', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('db_migration_test_');
      dbFile = File(p.join(tempDir.path, 'migration_test.db'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'successfully upgrades v2 database to v3, normalizes completed to synced, and adds nextRetryAt with compound index',
      () async {
        const nowSec = 1700000000;

        // Step 1: Create a genuine v2 SQLite database using raw SQLite commands.
        // We initialize the database with all tables using Drift's onCreate,
        // then downgrade the sync_operations table and schema to v2:
        // recreate sync_operations table without next_retry_at, insert v2 records,
        // and set user_version = 2.
        {
          final initialDb = AppDatabase(NativeDatabase(dbFile));
          // Force table creation and initial seed by running a query
          await initialDb.select(initialDb.businessSettings).get();

          // Recreate sync_operations table without next_retry_at to strictly reflect schema v2
          await initialDb.customStatement(
            'DROP INDEX IF EXISTS idx_sync_operations_status_next_retry;',
          );
          await initialDb.customStatement(
            'DROP TABLE IF EXISTS sync_operations;',
          );
          await initialDb.customStatement('''
            CREATE TABLE sync_operations (
              id TEXT NOT NULL PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              payload TEXT,
              status TEXT NOT NULL DEFAULT 'pending',
              retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
              last_error TEXT,
              last_attempt_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');

          // Create standard v2 indexes
          await initialDb.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_operations_status ON sync_operations(status);',
          );
          await initialDb.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_operations_status_created_at ON sync_operations(status, created_at);',
          );
          await initialDb.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_operations_entity ON sync_operations(entity_type, entity_id);',
          );

          // Insert a v2 SyncOperation with status = 'completed'
          await initialDb.customStatement(
            'INSERT INTO sync_operations ('
            'id, entity_type, entity_id, operation_type, payload, status, retry_count, last_error, last_attempt_at, created_at, updated_at'
            ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
            [
              'op-v2-test-id-123',
              'order',
              'ord-entity-456',
              'create',
              '{"orderNumber":"26-001","items":2}',
              'completed',
              0,
              null,
              null,
              nowSec,
              nowSec,
            ],
          );

          // Also insert a v2 SyncOperation with status = 'pending' to ensure other statuses are untouched
          await initialDb.customStatement(
            'INSERT INTO sync_operations ('
            'id, entity_type, entity_id, operation_type, payload, status, retry_count, last_error, last_attempt_at, created_at, updated_at'
            ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
            [
              'op-v2-pending-id-789',
              'payment',
              'pay-entity-001',
              'create',
              '{"amount":5000}',
              'pending',
              1,
              'temporary timeout',
              nowSec,
              nowSec,
              nowSec,
            ],
          );

          // Explicitly set SQLite PRAGMA user_version to 2
          await initialDb.customStatement('PRAGMA user_version = 2;');

          // Close initial connection
          await initialDb.close();
        }

        // Step 2: Open AppDatabase on the v2 file.
        // Because AppDatabase.schemaVersion == 3 and user_version == 2,
        // Drift will execute onUpgrade(m, from: 2, to: 3).
        final migratedDb = AppDatabase(NativeDatabase(dbFile));

        try {
          // Trigger migration by opening the database with a query
          final operations = await (migratedDb.select(
            migratedDb.syncOperations,
          )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

          // 1. Verify rows survived without data loss
          expect(operations.length, 2);

          final migratedCompletedOp = operations.firstWhere(
            (o) => o.id == 'op-v2-test-id-123',
          );
          final pendingOp = operations.firstWhere(
            (o) => o.id == 'op-v2-pending-id-789',
          );

          // 2. Requirement: status 'completed' normalized to 'synced'
          expect(migratedCompletedOp.status, equals('synced'));

          // Requirement: other statuses (pending) preserved
          expect(pendingOp.status, equals('pending'));
          expect(pendingOp.retryCount, equals(1));
          expect(pendingOp.lastError, equals('temporary timeout'));

          // 3. Requirement: nextRetryAt exists and is nullable (null for migrated rows)
          expect(migratedCompletedOp.nextRetryAt, isNull);
          expect(pendingOp.nextRetryAt, isNull);

          // 4. Requirement: Existing operation ID is unchanged
          expect(migratedCompletedOp.id, equals('op-v2-test-id-123'));
          expect(migratedCompletedOp.entityId, equals('ord-entity-456'));
          expect(migratedCompletedOp.entityType, equals('order'));
          expect(migratedCompletedOp.operationType, equals('create'));

          // 5. Requirement: Existing payload is unchanged
          expect(
            migratedCompletedOp.payload,
            equals('{"orderNumber":"26-001","items":2}'),
          );
          expect(pendingOp.payload, equals('{"amount":5000}'));

          // 6. Requirement: Existing createdAt is unchanged
          expect(
            migratedCompletedOp.createdAt.millisecondsSinceEpoch ~/ 1000,
            equals(nowSec),
          );

          // 7. Requirement: Compound index idx_sync_operations_status_next_retry exists
          final indexRows = await migratedDb
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_sync_operations_status_next_retry';",
              )
              .get();
          expect(indexRows.length, 1);
          expect(
            indexRows.first.read<String>('name'),
            equals('idx_sync_operations_status_next_retry'),
          );

          // Verify schema version is now 3
          final versionRow = await migratedDb
              .customSelect('PRAGMA user_version;')
              .getSingle();
          expect(versionRow.read<int>('user_version'), equals(3));
          expect(migratedDb.schemaVersion, equals(3));

          // 8. Verify inserting a record with nextRetryAt works on migrated schema
          final retryTime = DateTime.now().add(const Duration(minutes: 5));
          await migratedDb
              .into(migratedDb.syncOperations)
              .insert(
                SyncOperationsCompanion.insert(
                  id: 'op-v3-new-retry',
                  entityType: 'customer',
                  entityId: 'cust-999',
                  operationType: 'create',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  nextRetryAt: Value(retryTime),
                ),
              );

          final insertedRow = await (migratedDb.select(
            migratedDb.syncOperations,
          )..where((t) => t.id.equals('op-v3-new-retry'))).getSingle();
          expect(insertedRow.nextRetryAt, isNotNull);
          expect(insertedRow.status, equals('pending'));
        } finally {
          await migratedDb.close();
        }
      },
    );
  });
}
