# Laundry Management System — Implementation Roadmap

## Purpose

This document defines the agreed high-level implementation order for the V1 Laundry Management System.

The task numbers are **sequence numbers**, not a pre-existing official project plan. Each task should be planned and locked before implementation, and this roadmap should be updated only when the project direction is explicitly changed.

The implementation workflow remains:

> **Understand → Review → Decide → Plan → Prompt → Implement → Audit → Fix → Verify → Lock → Next Task**

---

## Roadmap

| Task | Stage | Primary Goal | Status |
|---|---|---|---|
| Task #01 | Foundation / Architecture | Establish the project foundation, architecture boundaries, conventions, and core technical direction. | Completed |
| Task #02 | Database | Implement and verify the local SQLite/Drift database baseline. | Completed |
| Task #03 | Domain + Data Layer | Establish domain entities/value objects, repository contracts, DAOs, repository implementations, and data-layer foundation. | Completed |
| Task #04 | Application Workflows | Implement the core business workflows through selective Application-layer UseCases. | Completed / Locked |
| Task #05 | Core Presentation Foundation | Establish the core Flutter presentation foundation and prepare the first production-ready screen flow. | Completed / Locked |
| Task #06 | Orders — End-to-End | Implement the core Order experience from creation through order management, using the existing business workflows. | Completed / Locked |
| Task #07 | Customers | Implement customer management and its integration with Orders. | Completed / Locked |
| Task #08 | Storage | Implement physical OrderItem storage workflows and location management. | Completed / Locked |
| Task #09 | Payments | Implement the payment workflow, payment-related Order experience, and Step 10 Live Supabase backend synchronization. | Completed / Locked |
| Task #10 | Expenses & Reports | Implement operational expense management and operational/financial reporting as a tightly coupled unified feature, and Step 11 Live Supabase backend synchronization. | Completed / Locked |
| Task #11 | Services & Pricing / Settings | Implement management of services, pricing/master data, and approved Settings workflows, and Step 12 Live Supabase backend synchronization. | Completed / Locked |
| Task #12 | Dashboard | Implement the operational Dashboard using real data from the completed workflows. | Completed / Locked |
| Task #13 | Reports | *(Merged into Task #10 — Expenses & Reports)* | Merged into Task #10 |
| Task #14 | Invoice / Receipt | Implement invoice/receipt viewing and printing using historical Order information. | Completed / Locked |
| Task #15 | Offline / Sync Integration | Integrate and verify bidirectional synchronization (Push + Pull + Realtime Signal) for 2-device terminal operation. | Completed / Locked |
| Task #16 | Full Integration / QA / Hardening | Perform end-to-end verification, business-rule audit, offline testing, UI/RTL/responsive checks, and release hardening. | Completed / Locked |

---

# Task Sequencing Principles

## 1. Build foundations before dependent workflows

The project should establish the technical and business foundations before building feature workflows on top of them.

Current completed sequence:

```text
Foundation / Architecture
        ↓
Database
        ↓
Domain + Data Layer
        ↓
Application Workflows
```

Task #04 provides the current business-workflow foundation for the next presentation phase.

---

## 2. Do not interpret the roadmap as a strict layer-by-layer architecture plan

The roadmap is organized around useful implementation increments and product workflows, not simply:

```text
Domain → Data → Application → Presentation
```

After the foundation is complete, implementation should move toward **vertical feature slices** where practical.

For example:

```text
Presentation Foundation
        ↓
Orders E2E
        ↓
Customers / Storage / Payments
        ↓
Expenses / Settings
        ↓
Dashboard / Reports / Invoice
```

---

## 3. Task #05 is intentionally a foundation, not "all UI"

Task #05 should establish only the presentation infrastructure and shared UI capabilities actually required by the first production-ready flows.

It must not become an uncontrolled effort to build every possible shared component.

The Design System remains the visual source of truth.

Feature screens should consume:

- AppColors
- AppTextStyles
- AppTheme
- Design Tokens
- Shared Components
- Feature-specific Components where appropriate

Feature screens must not create independent visual systems.

---

# Feature Sequencing Rationale

## Task #05 — Core Presentation Foundation

This comes next because the Domain, Data, and Application foundations are already in place, while the product still needs a stable Flutter presentation foundation to turn those capabilities into operational screens.

The goal is to establish the reusable presentation conventions before building the main feature workflows.

---

## Task #06 — Orders End-to-End

Orders are the central operational workflow of the system.

The existing Application layer already contains the main Order workflows:

- Create Order
- Store Order Items
- Move Stored Item
- Change Order Status
- Complete Order
- Cancel Order

Therefore, Orders are the natural first major vertical feature after the Presentation Foundation.

---

## Task #07 — Customers

Customers are directly connected to Orders and are a primary V1 module.

Customer management should be implemented after the basic Order flow so the integration between customer selection/creation and Orders can be built around a real workflow.

---

## Task #08 — Storage

Storage is a dedicated operational workflow for physical OrderItems.

It depends heavily on the OrderItem model and the storage workflows already established in the Application layer.

---

## Task #09 — Payments

Payments are a core operational transaction and are intentionally separate from Task #04.

The payment workflow should be implemented after the Order experience is established.

`AddPaymentUseCase` was intentionally not introduced during Task #04 and should not be added unless the approved scope for the payment task requires it.

---

## Task #10 — Expenses & Reports

Task #10 combines operational Expenses management and Financial / Orders Reporting into one coherent feature because they are tightly coupled at both the data and UI levels.

Expenses represent operational financial transactions outside of Order payments. Expense categories remain configurable master data, with historical category snapshots preserved on each expense.

The Reports module provides operational and financial reporting derived from authoritative transaction data rather than duplicated reporting tables:

```text
Sales       ← Orders
Payments    ← Payments
Expenses    ← Expenses
Remaining   ← Orders + Payments
Net Profit  ← Orders (Sales) - Expenses
```

Key principles:
- Net Profit = Total Sales - Total Operating Expenses. Payments and Outstanding balances do NOT reduce Net Profit.
- Reporting adheres strictly to business dates: `expense_date` for Expenses, `paid_at` for Payments, `created_at` for Orders.
- Offline-first architecture: All aggregations run locally on SQLite/Drift.

---

## Task #11 — Services & Pricing / Settings

Services and pricing are master/configuration data used by operational workflows.

They belong under Settings rather than the primary navigation.

This task provides the approved management experience without expanding the V1 configuration scope, coupled with Step 12 Live Supabase Backend Synchronization:
- **Local Persistence & Sync Enqueue**: `ItemType`, `ItemDefinition`, `CarpetSize`, `StorageLocation`, and `BusinessSettings` persist locally via Drift transactions and enqueue non-null, self-contained JSON sync payloads.
- **Remote Supabase Schema**: Migration `20260916000004_master_data_schema.sql` creates tables `item_types`, `item_definitions`, `carpet_sizes`, `storage_locations`, `storage_location_item_types`, and `business_settings` with default-deny RLS.
- **Transactional RPCs**: 9 `SECURITY DEFINER` RPCs handle idempotency logging (`sync_idempotency_log`), FK integrity, check constraints, and atomic mutations.
- **Edge Function API**: Deployed and active on `/item-types`, `/item-definitions`, `/carpet-sizes`, `/storage-locations`, and `/business-settings`.
- **Status**: Completed / Locked. Next task is Task #12 — Dashboard.

---

## Task #12 — Dashboard

The Dashboard provides an operational overview of real system data without replacing Orders, Storage, Customers, or Reports:
- **Operational Overview Metrics**: All 7 operational metrics implemented via optimized Drift database-side aggregations:
  1. Orders created today (`today_orders_count` using local midnight boundaries `00:00:00.000` to `23:59:59.999`)
  2. Ready orders (`ready_orders_count` matching `OrderStatus.ready`)
  3. Items requiring storage (`itemsRequiringStorageCount` matching active orders with no active storage records via `StorageRepository.countItemsRequiringStorage()`)
  4. Outstanding payments (`totalRemaining` in piastres + `unpaidOrdersCount` for non-cancelled orders with `total - paid > 0`)
  5. Overdue orders (`overdueOrdersCount` where `expectedPickupDate < today` and order not completed or cancelled)
  6. Today's expected pickups (`todayPickupOrdersCount` count + list capped at 5 active orders due today)
  7. Recent orders (latest 5 orders with `PaymentSummary` remaining amount enrichment)
- **Reactive Stream**: `DashboardRepository.watchDashboardData()` reactive via Drift `db.tableUpdates` monitoring `orders`, `payments`, `storage_records`, and `order_items` tables with zero polling and zero pending timers.
- **Quick Actions**: All 4 actions operational:
  1. Add Order (`/orders/new`)
  2. Add Customer (`CustomerFormDialog` with duplicate handling & `onViewExisting` navigation)
  3. Record Payment (`RecordPaymentDialog` two-step flow: search/select order + record payment with live balance validation)
  4. Add Expense (`AddExpenseDialog` with active category selection and expense recording)
- **Responsive Layout & Design**: Single-column mobile layout, two-column responsive tablet/desktop layout with full Arabic RTL support.
- **Verification**: 100% test pass rate across unit, repository, cubit, widget, and integration suites (735/735 passing, `flutter analyze` 0 issues, `git diff --check` clean).
- **Status**: Completed / Locked. Next task is Task #15 — Offline / Sync Integration.

---

## Task #13 — Reports (Merged into Task #10)

Task #13 Reports was merged into Task #10 because Reports and Expenses are tightly coupled at both data and presentation layers. All reporting functionality (Orders Report, Financial Report, Period Filtering, Payment Methods, Expenses by Category, Outstanding Orders) is implemented as part of Task #10.

---

## Task #14 — Invoice / Receipt

Invoice/Receipt functionality depends on stable Order and Payment information.

Historical Order information must remain authoritative when displaying an invoice or receipt. Current master-data changes must not cause historical Orders to be recalculated.

- **Status**: Completed / Locked via PR #6 (`9586658`) with `invoice_printer.dart` and `invoice_preview_dialog.dart` fully implemented and verified with automated test suites.

---

## Task #15 — Offline / Sync Integration

Task #15 is **Completed / Locked** (verified and accepted through C1 Remote Sync Foundation, C1.5 Forensic Audit, C1.6 Migration Hardening, C2 Local Pull Foundation, C3 Sync Orchestration, C3.1 Realtime Broadcast, C4-A Release Safety, C4-B Pull/Test Hardening, and C4-C Two-Device Bidirectional Sync E2E).

The architecture officially supports **Bidirectional Push + Pull Synchronization** across two terminal devices sharing a single remote Supabase backend:

- **Local Source of Truth**: Local Drift/SQLite database remains the primary operational source of truth for the UI on each device.
- **Push Pipeline**: Local business mutation commits atomically with `sync_operations` entry in SQLite. `SyncEngine` dispatches operations sequentially with `X-Operation-ID` through `RemoteApiDispatcher` to Supabase Edge Functions. PostgreSQL transactional RPCs apply business mutation, append to remote `sync_changes`, and log idempotency.
- **Pull Pipeline**: Remote changes in `sync_changes` are pulled via cursor-based pagination `GET /sync/changes?after=<sequence>&limit=<limit>`. `RemoteChangeApplier` applies changes directly to local DAOs without creating outgoing `SyncOperations` (echo loop prevention) and updates `sync_state.last_applied_sequence` in the **same local transaction**.
- **Realtime Wake-Up Signal**: Ephemeral wake-up notifications via Supabase Realtime Broadcast (`laundry:sync` / `sync_available`) trigger `SyncEngine.pull()`. Realtime payload is NOT authoritative data; Pull API remains the authoritative retrieval mechanism. (Realtime CDC publication migration on `sync_changes` exists as dormant infrastructure).
- **Triggers & Coalescing**: `SyncEngine` orchestrates sync cycles across manual sync, startup sync, app resume, connectivity restoration, Realtime wake-up, and 15-minute periodic foreground safety pull. Push and Pull triggers are coalesced in a single-flight execution loop.
- **Two-Device E2E Validation (C4-C)**: Verified end-to-end with two independent SQLite terminals synchronizing bidirectionally through live Supabase (Device A: Customer + Order → Supabase → Device B; Device B: Payment + Storage → Supabase → Device A).
- **Change Granularity**: Hybrid model. Order Creation is represented as an aggregate change payload containing all items and carpet data; subsequent status transitions, payments, storage moves, and customer/expense/master data updates are entity-specific.
- **Conflict Handling**: Domain-aware conflict resolution (no generic LWW). Payments are append-oriented and idempotent; Storage enforces at most one active record per `OrderItem` and rejects stale moves via server concurrency checks; Order status transitions follow lifecycle rules.
- **Known Deferred Limitations**:
  - *Optimistic Concurrency Propagation*: Remote backend supports `server_version`, but Flutter client currently does NOT maintain local `server_version` columns and does NOT propagate `base_version` through `SyncOperation` (Deferred V1 Limitation).
  - *Recovery & Bootstrap*: `CURSOR_TOO_OLD` is detected (`CursorTooOldException`). Full automatic resync / initial bootstrap recovery is deferred; current implementation guarantees locally pending operations in `sync_operations` are never deleted.
  - *Retention*: Synced operations retained for 90 days; automatic background purge is deferred (manual maintenance).

---

## Task #16 — Full Integration / QA / Hardening

Task #16 is **Completed / Locked**.

The final implementation phase should verify the complete system as one product.

It should include:

- End-to-end business workflows
- Business-rule verification
- Offline behavior
- Error states
- RTL
- Arabic UI
- Responsive/adaptive behavior
- Design System consistency
- Static analysis
- Automated tests
- Regression checks
- Final audit
- Release hardening

---

# Locked Business / Scope Constraints

The roadmap must not be used as a reason to reopen already-locked decisions.

Important current constraints include:

### Pricing

V1 supports only:

- Per Piece
- Fixed Price
- Per Square Meter

Per Kg is not part of the current V1 implementation.

### Pricing Validation

```text
unitPrice > Money.zero
```

Zero pricing is not allowed.

### Order Lifecycle

```text
Processing
    ↓
Ready
    ↓
Completed
```

`Processing → Ready` occurs automatically only when all physical OrderItems are stored.

Completion requires:

```text
Ready
+
Fully Paid
+
Customer Handover Confirmation
```

### Cancellation

Cancellation:

- Requires confirmation.
- Requires a reason.
- Preserves order history.
- Deactivates storage.
- Preserves payments.
- Does not automatically refund.

### Payments

Payment creation is not part of Task #04.

The payment workflow belongs to the appropriate later payment/POS scope.

### V1 Exclusions

Do not introduce features such as:

- AI Assistant
- Barcode/RFID
- Customer mobile app
- Driver app
- Multi-branch
- Multi-currency
- Roles/Permissions
- Loyalty
- Advanced notifications
- Refund workflow
- Advanced warehouse management
- Storage movement history
- Storage capacity management
- Advanced analytics
- Full accounting system
- Online payment integration

unless the V1 scope is explicitly changed and documented first.

---

# How to Use This Roadmap

Before starting each new Task:

1. Confirm the current Task from this roadmap.
2. Review its Goal.
3. Define its exact Scope.
4. Identify Business Rules.
5. Review Architecture and Dependencies.
6. Identify Open Decisions.
7. Create the implementation plan.
8. Write the Antigravity implementation prompt.
9. Implement only the approved scope.
10. Run tests and static analysis.
11. Audit the implementation against the source of truth.
12. Fix findings.
13. Perform final verification.
14. Mark the Task as Locked/Completed.
15. Update this roadmap if the status changes.
16. Move to the next Task.

---

# Change Policy

This roadmap is a planning document, not permission to expand scope.

If a future Task reveals a required change to:

- Product requirements
- Business rules
- Domain model
- Database
- Architecture
- Project structure
- Design System

the relevant documentation must be updated and the change explicitly approved before implementation.

The roadmap should then be updated to reflect the new approved direction.

---

# Current Position

```text
Task #01  Foundation / Architecture       ✅
Task #02  Database                         ✅
Task #03  Domain + Data Layer              ✅
Task #04  Application Workflows            ✅ LOCKED
Task #05  Core Presentation Foundation     ✅ LOCKED
Task #06  Orders — End-to-End              ✅ LOCKED
Task #07  Customers                        ✅ LOCKED
Task #08  Storage                          ✅ LOCKED
Task #09  Payments                         ✅ LOCKED (Step 10 Backend Sync Complete)
Task #10  Expenses & Reports               ✅ LOCKED (Step 11 Backend Sync Complete)

Task #11  Services & Pricing / Settings    ✅ LOCKED (Step 12 Backend Sync Complete)
Task #12  Dashboard                        ✅ LOCKED
Task #13  Reports (Merged into #10)        ✅ LOCKED
Task #14  Invoice / Receipt                ✅ LOCKED (PR #6 Merged)
Task #15  Offline / Sync Integration       ✅ LOCKED (C1–C4-C Bidirectional Sync E2E Complete)
Task #16  Full Integration / QA / Hardening ✅ LOCKED (Phase 3A-C Hardening, Fresh Bootstrap & Manual QA Complete)
```

**V1 Status**: All Tasks #01 through #16 are Completed and Locked. Current V1 implementation is complete.
