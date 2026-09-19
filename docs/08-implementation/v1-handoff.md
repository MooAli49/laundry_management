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
  - Strict foreign key enforcement, custom indexes, partial unique index on storage records.
  - Baseline singleton (`business_settings`) and default categories seeded on schema creation.
- **Remote Database (Supabase PostgreSQL)**:
  - Relational tables protected by Row Level Security (`rowsecurity: true`). Direct PostgREST mutations disabled; all mutations route through `SECURITY DEFINER` RPCs.
  - Monotonically increasing `sequence BIGSERIAL` in `sync_changes` change log.
  - Dedicated `sync_idempotency_log` table storing client operation hashes.
- **Canonical Master Baseline**:
  - Authority catalog consisting of 35 initial changes (sequences 1..35): 1 business setting, 4 item types, 7 expense categories, 5 services, 5 service-item-type links, 3 carpet sizes, 5 storage locations, 9 storage-location-item-type links, 10 item definitions.
- **Phase 3B Remote Foreign Key Hardening**:
  - Enforced referential integrity on remote tables (`order_items`, `order_item_carpets`, `storage_records`, `service_item_types`) with `ON DELETE RESTRICT` and `ON DELETE SET NULL`.
  - All foreign key columns converted from legacy `TEXT` to native PostgreSQL `UUID` types.

---

## 5. Synchronization Engine

- **Push Mechanism**: Flushes queued local `sync_operations` to remote Edge Functions with idempotency header (`X-Operation-ID`).
- **Pull Mechanism**: Cursor-based polling querying `GET /api/v1/sync/changes?after=<cursor>&limit=100`.
- **Realtime Wake-Up Signal**: Listens to Supabase Realtime broadcast channel (`sync_available`) to trigger an immediate pull without transmitting raw data payloads over WebSockets.
- **Atomic Apply & Cursor Advancement**: [RemoteChangeApplier](file:///d:/projects/laundry_management/lib/data/sync/remote_change_applier.dart) applies batches inside a single SQLite transaction and advances `sync_state.last_applied_sequence` in the same transaction.
- **Zero Echo**: Remote changes applied locally bypass `SyncOperationsDao` to prevent re-enqueueing local mutations.
- **Concurrency Guard**: Single-flight coalescing mutex ensures only one sync cycle runs at a time.
- **Retry Policy**: Exponential backoff with bounded additive jitter (0–1s) and max 5 retries.

---

## 6. Quality Assurance & Verification

- **Static Analysis**: `flutter analyze` completed with **0 issues**.
- **Automated Test Suites**: **757 / 757 tests passed (100%)**:
  - `test/domain`, `test/core`, `test/application`: 238 passed
  - `test/data/local`, `test/data/daos`, `test/data/database`, `test/data/datasources`, `test/data/remote`, `test/data/repositories`: 173 passed
  - `test/features`: 233 passed
  - Non-live synchronization test suite: 97 passed
  - `SupabaseConfig` release configuration suite: 16 passed
- **Fresh Client Bootstrap Verification**: Verified from cursor 0 on Android emulator. All 35 canonical changes applied cleanly; local cursor advanced to 35 with 0 errors (0 UNIQUE errors, 0 FK errors, 0 DriftRemoteException).
- **Manual QA Workflows (100% PASS)**:
  - Customer creation & validation
  - Order creation with multi-item types and carpets
  - Partial payment recording and remaining balance computation
  - Payment push and remote sync log entry
  - Physical item storage, moving across locations, and capacity tracking
  - Ready lifecycle transition upon all items stored
  - Complete lifecycle transition upon balance cleared and handover confirmed
  - Offline order creation and queueing
  - Offline → Online network reconnection and automatic push
  - Operational expense recording and validation
  - Operational and financial report calculations (net profit formula)
  - Service catalog management across pricing types (per-piece, per-sqm, fixed-price)
  - Settings singleton configuration (business name, tax toggle, tax rate)

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
10. **Global Last-Write-Wins (LWW)**: Rejected in favor of domain-aware atomic upserts.

---

## 8. Known Informational Observations

- **Emulator Cold-Start Performance**: On initial cold launch under Debug mode on the Android emulator, the Choreographer logs minor initial frame skips (`Skipped 69 frames` / `Width is zero`) during Impeller OpenGL shader compilation. This is an emulator/debug-only compilation artifact. Background sync runs asynchronously without blocking the UI thread, and the dashboard renders smoothly and responsively.
