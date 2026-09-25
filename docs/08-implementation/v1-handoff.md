# Laundry Management System V1 — Project Handoff Summary

## 1. V1 Status
**Completed / Locked**

The Laundry Management System V1 has successfully completed all development tasks, architectural hardening phases, automated regression suites, fresh bootstrap verification from cursor 0, and end-to-end manual QA.

---

## 2. Technology Stack

- **Framework**: Flutter (Targeting Android, Windows Desktop, Desktop/Tablet responsive viewports)
- **Language**: Dart (Sound null safety)
- **State Management**: Bloc / Cubit
- **Dependency Injection**: GetIt (Service locator pattern with clean lazy singletons and factories)
- **Navigation & Routing**: GoRouter (Declarative, URL-driven routing with shell routes)
- **Local Persistence**: Drift / SQLite (`PRAGMA foreign_keys = ON;`, reactive streams via `tableUpdates`)
- **Networking**: Dio + Retrofit (Typed API clients, structured error interceptors, logging redaction)
- **Remote Backend**: Supabase (PostgreSQL, Transactional RPC functions)
- **Serverless API**: Supabase Edge Functions (Deno / TypeScript, idempotency enforcement)
- **Live Signaling**: Supabase Realtime (Broadcast channels for wake-up synchronization triggers)

---

## 3. Architecture

- **Feature-Based Modular Structure**: Features organized under `lib/features/` (Orders, Customers, Storage, Payments, Expenses, Reports, Settings, Dashboard).
- **Clean Layered Architecture**:
  - `domain/`: Pure business entities, value objects, repository contracts, and UseCases. Zero Flutter or Drift dependencies.
  - `data/`: Local Drift database, DAOs, Retrofit remote APIs, and repository implementations bridging domain and storage.
  - `presentation/`: Screens, Cubits, States, Dialogs, and widgets styled according to the Design System.
- **Repository Pattern**: Repositories orchestrate atomic local persistence and sync operation enqueueing inside single database transactions.
- **Local-First Operation**: The local SQLite database is the immediate operational source of truth. All user workflows remain fully functional without network connectivity.
- **Synchronization Boundary**: Decoupled background synchronization engine operating independently of UI threads and presentation widgets.

---

## 4. Database Architecture

- **Local Database (Drift / SQLite)**:
  - Schema version 6 containing 19 tables (17 business tables + 2 sync tables: `sync_operations`, `sync_states`).
  - Strict foreign key enforcement (`PRAGMA foreign_keys = ON;`), custom indexes, partial unique index on active storage records.
  - Customer profile support with optional address (`customers.address TEXT NULL`), normalized to null on whitespace.
  - Dedicated `refunds` table: append-only financial records linked to orders, omitting `server_version`.
  - Baseline singleton (`business_settings`) and default categories seeded on schema creation.
- **Remote Database (Supabase PostgreSQL)**:
  - 13 applied migrations from `supabase/migrations/` (through `20260925000000_customer_address.sql`).
  - Relational tables protected by Row Level Security (`rowsecurity: true`). Direct PostgREST mutations disabled; all mutations route through `SECURITY DEFINER` RPCs.
  - Monotonically increasing `sequence BIGSERIAL` in `sync_changes` change log.
  - Dedicated `sync_idempotency_log` table storing client operation hashes.
- **Canonical Master Baseline**:
  - Authority catalog consisting of 35 initial changes (sequences 1..35): 1 business setting, 4 item types, 7 expense categories, 5 services, 5 service-item-type links, 3 carpet sizes, 5 storage locations, 9 storage-location-item-type links, 10 item definitions.
- **Referential Integrity & Type Hardening**:
  - Enforced referential integrity on remote tables (`order_items`, `order_item_carpets`, `storage_records`, `service_item_types`, `refunds`) with `ON DELETE RESTRICT` and `ON DELETE SET NULL`.
  - All foreign key columns use native PostgreSQL `UUID` types.

---

## 5. Synchronization Engine

- **Push Mechanism**: Flushes queued local `sync_operations` to remote Edge Functions with idempotency header (`X-Operation-ID`).
- **Pull Mechanism**: Cursor-based polling querying `GET /api/v1/sync/changes?after=<cursor>&limit=100`.
- **Supported Entities**: Customers (with optional address), Orders, OrderItems, OrderItemCarpets, Payments, Refunds (`POST /api/v1/refunds`), Order Aggregate Edits (`PATCH /api/v1/orders/{id}/edit-aggregate`), StorageRecords, and Expenses.
- **Realtime Wake-Up Signal**: Listens to Supabase Realtime broadcast channel (`sync_available`) to trigger an immediate pull without transmitting raw data payloads over WebSockets.
- **Atomic Apply & Cursor Advancement**: [RemoteChangeApplier](file:///d:/projects/laundry_management/lib/data/sync/remote_change_applier.dart) applies batches inside a single SQLite transaction and advances `sync_state.last_applied_sequence` in the same transaction.
- **Zero Echo**: Remote changes applied locally bypass `SyncOperationsDao` to prevent re-enqueueing local mutations.
- **Concurrency Guard**: Single-flight coalescing mutex ensures only one sync cycle runs at a time.
- **Retry Policy**: Exponential backoff with bounded additive jitter (0–1s) and max 5 retries.

---

## 6. Quality Assurance & Verification

- **Static Analysis**: `flutter analyze` completed with **0 issues**.
- **Automated Test Suites**:
  - **Full Suite**: **1,188 / 1,188 passed** (Command: `flutter test --concurrency=1`). Sequential execution is required when running the entire suite with live cloud integration to prevent remote database lock contention.
  - **Offline / Non-Live Suite**: **773 / 773 passed** (`flutter test test/features/ test/core/`).
  - **Controlled Live Integration Batch**: **128 / 128 passed** (`test/data/sync/`).
  - **Targeted Validation Suite**: **341 / 341 passed** (`test/features/orders/ test/features/customers/ test/features/reports/`).
  - *Coverage Note*: The project avoids artificial blanket 100% code coverage claims. Testing focuses rigorously on high-risk domain invariants, offline persistence, sync engine transactions, and financial accuracy.
- **Fresh Client Bootstrap Verification**: Verified from cursor 0 on Android emulator. All 35 canonical changes applied cleanly; local cursor advanced to 35 with 0 errors (0 UNIQUE errors, 0 FK errors, 0 DriftRemoteException).
- **Manual User Acceptance Testing (UAT)**:
  - Customer creation, optional address entry & editing, phone duplicate handling.
  - Order creation with multi-item types and carpets.
  - Order numbering format (`26-001` to `26-10000`), cleanly ignoring synthetic test prefixes (`ORD-TEST-...`).
  - Item snapshots invariant: verified `itemTypeNameSnapshot` and `serviceNameSnapshot` persist immutable historical names without fallback fabrication.
  - Partial payment recording and remaining balance computation.
  - Automatic Ready lifecycle transition upon all order items stored.
  - Physical item storage assignment, moving across locations, and capacity tracking.
  - Delivery handover confirmation and completion upon balance cleared.
  - Administrative correction: `Completed -> Processing` transition verified (requires non-empty reason, clears `completed_at`, storage records cleared requiring re-store).
  - Order aggregate editing in Processing state (add/remove items, recalculate totals).
  - Order cancellation (strictly terminal) and full/partial refund processing (`استرداد المبلغ` with mandatory reason). Refunds are available only for cancelled orders with a refundable balance.
  - Offline order creation, outbox queueing, network reconnection, and automatic push.
  - Operational expense recording and validation.
  - Financial reports: verified 6-section hierarchy (Key Metrics, Payment Methods, Collections & Discounts, Analytics, Expense History, Outstanding Orders), accurate net profit formula (`Total Sales - Operating Expenses`), and amber/warning styling for remaining balances (red reserved strictly for errors).
  - Overdue boundary semantics: strictly calendar-day based (`expected_pickup_date < start_of_today`), today is never overdue.
  - **Synthetic Data Cleanup Checkpoint**: Synthetic test orders contaminated during initial automated tests were purged from local SQLite; canonical sequence was restored to `26-023`, and a real `26-023` order was created during UAT. Operational/UAT data was preserved.

---

## 7. Deferred Items (Approved for Post-V1 Scope)

The following items are intentionally deferred from V1 and are documented as out of scope:
1. **Client-side `server_version` / `base_version` propagation**: Backend RPCs support integer OCC, but client does not track or propagate base version.
2. **Automatic `CURSOR_TOO_OLD` bootstrap recovery**: HTTP 410 triggers error state; automatic snapshot resync is deferred.
3. **Automatic sync operation retention purge**: Synced operations retained for audit; automated background cleanup is deferred.
4. **OS-level platform background sync**: No platform WorkManager / BGTaskScheduler; sync relies on foreground lifecycle triggers (`onResume`, network recovery, timer).
5. **Raw WebSocket data streaming**: WebSockets used purely for lightweight wake-up signals; data travels via HTTP pull.
6. **Multi-tenancy & Multi-branch**: Single-shop operation only.
7. **End-user role-based authentication**: Uses infrastructure anonymous API key.
8. **ESC/POS direct thermal printer socket communication**: Printing uses standard PDF preview and platform print dialogs.
9. **VAT / Per-kg pricing models**: Catalog restricted to per-piece, per-square-meter, and fixed-price.
10. **Delivery routing & fleet dispatch**: Customer profile includes optional address field for identification, but automated routing and dispatch are out of scope.
11. **Automated payment gateway refunds**: In-app refunds record manual cash/electronic returns; payment gateway API reversals are deferred.
12. **Global Last-Write-Wins (LWW)**: Rejected in favor of domain-aware atomic upserts.


---

## 8. Known Informational Observations

- **Emulator Cold-Start Performance**: On initial cold launch under Debug mode on the Android emulator, the Choreographer logs minor initial frame skips (`Skipped 69 frames` / `Width is zero`) during Impeller OpenGL shader compilation. This is an emulator/debug-only compilation artifact. Background sync runs asynchronously without blocking the UI thread, and the dashboard renders smoothly and responsively.

---

## 9. Release Build Configuration (RISK-002)

To satisfy security requirement RISK-002, [SupabaseConfig](file:///d:/projects/laundry_management/lib/core/config/supabase_config.dart) strictly prevents release builds from falling back to development credentials. Launching a release build without explicit credentials throws a `StateError` during startup.

### Required Compile-Time Environment Variables
- `SUPABASE_URL_ROOT`: Supabase project URL root (or `SUPABASE_URL`)
- `SUPABASE_ANON_KEY`: Supabase public anonymous API key

### Exact Build Command
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL_ROOT=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-production-anon-key>
```

### Reproducible Build Scripts
- PowerShell: `.\scripts\build_release.ps1 -SupabaseUrlRoot "..." -SupabaseAnonKey "..."`
- Bash: `./scripts/build_release.sh "..." "..."`
- Configuration File: `scripts/release_env.json` (template in `scripts/release_env.json.example`, ignored by git) via `--dart-define-from-file=scripts/release_env.json`
