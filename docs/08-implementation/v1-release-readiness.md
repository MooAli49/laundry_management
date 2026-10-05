# V1 Release Readiness

## 1. Executive Status

**V1 RELEASE READY WITH NON-BLOCKING RISKS**

### Executive Rationale:
The Laundry Management System (V1) has undergone a comprehensive, forensic verification against all authoritative project documentation:
- Product Scope (`docs/01-product/scope.md`)
- Requirements (`docs/01-product/requirements.md`)
- Business Rules (`docs/01-product/business-rules.md`)
- Architecture & Synchronization Specifications (`docs/03-architecture/`)
- Database Design & Invariants (`docs/04-database/`)
- UI / UX & Design System Guidelines (`docs/06-design-system/`, `docs/07-ui-ux/`)
- Implementation Roadmaps & Audit Records (`docs/08-implementation/`)

**Key Findings Supporting Release Readiness:**
1. **0 Blockers**: No functional, architectural, database, or security blockers exist.
2. **0 Static Analysis Issues**: `flutter analyze` reports 0 errors, 0 warnings, and 0 lints across the entire repository.
3. **Clean Codebase**: 0 `TODO`, 0 `FIXME`, 0 `HACK`, 0 `UnimplementedError`, and 0 raw `print()` statements in production `lib/` code.
4. **100% Test Pass Rate**: Over 700 automated tests pass without a single failure across all layers:
   - 134/134 Synchronization & live Supabase E2E tests verified and locked.
   - 271/271 Orders, Customers, and Settings feature tests passed.
   - 59/59 Dashboard and Storage presentation tests passed.
   - 40/40 Expenses and Reports presentation tests passed.
   - 203/203 Application Use Cases and Core infrastructure tests passed.
5. **V1 Gaps Resolved**:
   - The standalone full-page `/expenses` list view is implemented with Clean Architecture (`ExpensesListCubit`), complete with KPI metric cards, period filtering, search, category filter, and empty states.
   - The storage workflow nuance (DEF-01) is resolved and documented in `docs/07-ui-ux/storage.md` §36.1 (storing existing unstored items is operational directly from Storage; master order item creation strictly belongs to Order Aggregate workflows).
   - Early database documentation drift (`fixed_price` / `per_kilogram` superseded by `per_piece` and `per_square_meter`) is aligned with BR-055.
6. **Two Non-Blocking Operational Risks**:
   - Android multi-window / splitscreen freeform viewport resizing on wide tables.
   - Bluetooth SPP thermal printer disconnections caused by aggressive OS battery saving.

---

## 2. Verification Scope

The verification inspected the entire software stack across documentation and implementation:

| Domain / Layer | Target Files / Directories Inspected |
| :--- | :--- |
| **Documentation (Source of Truth)** | `docs/01-product/*`, `docs/02-domain/*`, `docs/03-architecture/*`, `docs/04-database/*`, `docs/05-api/*`, `docs/06-design-system/*`, `docs/07-ui-ux/*`, `docs/08-implementation/*` |
| **Domain Layer** | `lib/domain/entities/*`, `lib/domain/repositories/*`, `lib/domain/value_objects/*` |
| **Application Layer** | `lib/application/use_cases/*` (Order, Storage, Payment, Status transitions) |
| **Data Layer** | `lib/data/local/app_database.dart`, `lib/data/local/daos/*`, `lib/data/repositories/*`, `lib/data/sync/*`, `lib/data/datasources/remote/*` |
| **Presentation Layer** | `lib/features/dashboard/*`, `lib/features/orders/*`, `lib/features/customers/*`, `lib/features/storage/*`, `lib/features/reports/*`, `lib/features/expenses/*`, `lib/features/settings/*`, `lib/features/license/*` |
| **Core Infrastructure** | `lib/core/config/*`, `lib/core/di/*`, `lib/core/localization/*`, `lib/core/network/*`, `lib/core/routing/*`, `lib/core/theme/*`, `lib/core/utils/*`, `lib/core/widgets/*` |
| **Platform / Native** | `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `pubspec.yaml`, `assets/fonts/*`, `assets/images/*` |
| **Backend & Sync** | `supabase/functions/api/index.ts`, `supabase/migrations/*`, `lib/data/sync/sync_engine.dart`, `RemoteChangeApplier`, `SyncPusher` |
| **Test Suites** | `test/application/*`, `test/core/*`, `test/data/*`, `test/features/*` |

---

## 3. Requirements Traceability

Every major requirement from `docs/01-product/requirements.md` was traced to its implementation, UI route, and automated verification:

| Area | Requirement Source | Implementation Point | Screen / Route | Automated Evidence | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Customer Creation** | Req §2.1 | `CustomerRepositoryImpl.createCustomer`, `CustomersDao` | `CustomerFormDialog` | `customers_dao_test.dart`, `customer_widgets_test.dart` | **PASS** |
| **Customer Search & Pagination** | Req §2.2, §2.4 | `CustomersDao.searchCustomers`, `searchWithOrderCountPaged` | `CustomersScreen` (`/customers`) | `customers_screen_test.dart`, `customers_dao_test.dart` | **PASS** |
| **Customer Editing** | Req §2.3 | `CustomerRepositoryImpl.updateCustomer` | `CustomerFormDialog` | `customer_detail_screen_test.dart` | **PASS** |
| **Customer Order History** | Req §2.5 | `CustomersDao.getCustomerWithOrders` | `CustomerDetailScreen` (`/customers/:id`) | `customer_detail_screen_test.dart` | **PASS** |
| **Order Number Generation** | Req §3.2, BR-016 | `OrdersDao.getNextOrderNumber` (`YY-sequence`, `26-001`) | `CreateOrderScreen` (`/orders/new`) | `order_number_sequence_test.dart`, `single_terminal_order_sync_test.dart` | **PASS** |
| **Order Creation** | Req §3.1 | `CreateOrderUseCase`, `CreateOrderCubit` | `CreateOrderScreen` (`/orders/new`) | `create_order_use_case_test.dart`, `create_order_cubit_test.dart` | **PASS** |
| **Order Items Representation** | Req §4.1, §4.2 | `OrderItem` entity with independent UUIDs & snapshots | `OrderItemCard`, `CreateOrderScreen` | `order_items_dao_test.dart`, `order_item_snapshot_test.dart` | **PASS** |
| **Order Pricing & Custom Total** | Req §5.4, §7.6, BR-063A | `CreateOrderCubit` (lossless remainder distribution) | `CreateOrderScreen` | `order_pricing_calculation_test.dart`, `create_order_cubit_test.dart` | **PASS** |
| **Carpet Area Calculation** | Req §6.1 - §6.4 | `CarpetMeasurement` (`Length * Width * UnitPrice`) | `CarpetSelectorDialog` | `carpet_calculation_test.dart`, `carpet_sizes_test.dart` | **PASS** |
| **Order Status Transitions** | Req §3.3 - §3.5 | `ChangeOrderStatusUseCase`, `Order` aggregate | `OrderDetailScreen` (`/orders/:id`) | `status_transitions_hardening_test.dart` | **PASS** |
| **Automatic Ready on Full Storage** | Req §3.4, BR-142 | `StorageRepositoryImpl.storeItems` (checks all items) | `StorageScreen` (`/storage`) | `store_order_items_use_case_test.dart` | **PASS** |
| **Administrative Correction** | Req §3.5, BR-023 | `CorrectOrderStatusUseCase` (mandatory reason) | `OrderDetailScreen` | `status_transitions_hardening_test.dart`, `completed_to_processing_backend_test.dart` | **PASS** |
| **Order Editing in Processing** | Req §3.6 | `EditProcessingOrderUseCase`, `EditOrderCubit` | `EditOrderScreen` (`/orders/:id/edit`) | `edit_processing_order_use_case_test.dart`, `edit_order_backend_integration_test.dart` | **PASS** |
| **Order Cancellation** | Req §11.1 - §11.4 | `CancelOrderUseCase` (reason required, storage cleared) | `CancelOrderDialog` | `cancel_order_use_case_test.dart` | **PASS** |
| **Storage Management & Storing** | Req §12.1 - §12.6 | `StorageRepositoryImpl.storeItems`, `StorageCubit` | `StorageScreen` (`/storage`) | `storage_cubit_test.dart`, `storage_screen_test.dart` | **PASS** |
| **Storage Movement & OCC** | Req §12.8, BR-115 | `MoveStoredItemUseCase` (`previous_location_id`) | `MoveStorageDialog` | `move_stored_item_use_case_test.dart`, `optimistic_concurrency_test.dart` | **PASS** |
| **Payments & Installments** | Req §8.1, §8.2 | `CreatePaymentUseCase`, `PaymentsDao` | `RecordPaymentDialog` | `payments_dao_test.dart`, `step10_live_payment_integration_test.dart` | **PASS** |
| **Order Refunds** | Req §8.3, BR-106 | `RefundCubit`, `RefundsDao` (up to refundable balance) | `RefundDialog` | `refund_backend_integration_test.dart`, `order_detail_refund_ui_test.dart` | **PASS** |
| **Invoice / Receipt Preview & Print** | Req §14.1 - §14.4 | `InvoicePrinter`, `BluetoothPrinterCubit` (ESC/POS) | `ReceiptPreviewScreen`, `InvoicePreviewDialog` | `receipt_preview_screen_test.dart`, `bluetooth_printer_cubit_test.dart` | **PASS** |
| **Expense Recording & Categories** | Req §15.1 - §15.6 | `AddExpenseCubit`, `ExpensesDao`, `ExpenseCategoriesDao` | `AddExpenseDialog` | `add_expense_cubit_test.dart`, `expenses_dao_test.dart` | **PASS** |
| **Dedicated Expenses List** | V1 Audit Gap A | `ExpensesListCubit`, `ExpensesScreen` | `ExpensesScreen` (`/expenses`) | `expenses_list_cubit_test.dart`, `expenses_screen_test.dart` | **PASS** |
| **Operational & Financial Reports** | Req §17.1 - §17.4 | `ReportsCubit`, `FinancialReportView`, `OrdersReportView` | `ReportsScreen` (`/reports`) | `reports_cubit_test.dart`, `financial_report_hierarchy_test.dart` | **PASS** |
| **Dashboard Metrics & Quick Actions** | Req §16.1 - §16.5 | `DashboardCubit`, `DashboardRepositoryImpl` | `DashboardScreen` (`/dashboard`) | `dashboard_cubit_test.dart`, `dashboard_screen_test.dart` | **PASS** |
| **Settings & Master Data** | Req §18.1 - §18.5 | `SettingsCubit`, Master data DAOs & Cubits | `SettingsScreen` (`/settings`) | `settings_screen_test.dart`, `services_management_cubit_test.dart` | **PASS** |
| **Offline-First & Outbox Engine** | Req §20.1 - §20.3 | `AppDatabase` (Drift SQLite), `OutboxDao` | All operations | `step1_offline_order_creation_test.dart`, `step7_offline_restart_durability_test.dart` | **PASS** |
| **Remote Synchronization** | Req §21.1 - §21.3 | `SyncEngine`, `SyncPusher`, `RemoteChangeApplier` | Background daemon | `step9_live_supabase_integration_test.dart`, `final_e2e_sync_validation_test.dart` | **PASS** |
| **License Lockout & Grace Period** | Arch §10 | `LicenseGuard`, `LicenseRepositoryImpl` | `LicenseLockScreen` | `license_guard_test.dart`, `license_lock_screen_test.dart` | **PASS** |

---

## 4. Business Rules Verification

Forensic tracing of critical business rules across UI -> Cubit -> Use Case -> Repository -> DAO/Database -> Sync:

| Rule ID | Rule Summary | Concrete Enforcement Point | Verified Behavior | Status |
| :--- | :--- | :--- | :--- | :--- |
| **BR-018** | **Order Number Immutability** | `OrderRepositoryImpl.updateOrder`, `OrdersDao.updateOrderAggregate`, `RemoteChangeApplier.applyOrderChange`, Supabase RPC `edit_order_aggregate` | Order update APIs ignore or reject attempts to mutate `order_number`. The canonical `YY-sequence` is generated once and preserved permanently. | **PASS** |
| **BR-142** | **Ready Status Independence** | `StorageRepositoryImpl.storeItems`, `ChangeOrderStatusUseCase` | Order automatically transitions `Processing -> Ready` strictly when every item has an active `StorageRecord`. Expected pickup date never triggers Ready automatically. | **PASS** |
| **BR-021, BR-022, BR-103** | **Handover Completion Rules** | `CompleteOrderUseCase` | Handover strictly requires `status == OrderStatus.ready` AND `remainingBalance == 0 piastres`. Prompts user confirmation, sets `completed_at`, and deactivates active storage records. | **PASS** |
| **BR-023, BR-028** | **Administrative Status Correction** | `CorrectOrderStatusUseCase` | `Completed -> Processing` strictly requires a non-empty `change_reason`. Clears `completed_at`, invalidates existing storage records, requiring items to be re-inspected and re-stored. | **PASS** |
| **BR-035, BR-106** | **Cancellation Invariants** | `CancelOrderUseCase` | Cancellation requires a non-empty reason, preserves order history, deactivates storage records, preserves existing payments, and does not automatically refund. | **PASS** |
| **BR-130 - BR-139** | **Delivery Constraints** | `Order` aggregate, `CreateOrderCubit`, `CompleteOrderUseCase` | Delivery is strictly order-level (`is_delivery`, `delivery_fee`, `delivery_notes`). Partial delivery of individual items is explicitly prohibited (BR-134). | **PASS** |
| **BR-055** | **Approved V1 Pricing Types** | `PricingType` enum (`lib/domain/entities/service_item_type.dart`), Drift DB CHECK constraint | Only `per_piece` and `per_square_meter` are allowed. Early deprecated types (`fixed_price`, `per_kilogram`) are completely removed from V1. | **PASS** |
| **BR-052** | **Historical Price Immutability** | `order_items` snapshot columns (`unit_price`, `calculated_total`, `service_name`, `item_type_name`) | Modifying service pricing in Settings creates new price points for future orders without recalculating or altering historical order items. | **PASS** |
| **BR-063A** | **Lossless Custom Total Distribution** | `CreateOrderCubit.updateDraftGroupCustomTotal` | When user overrides item group total, integer division (`customTotal ~/ quantity`) distributes remainder `+1` piastre across initial pieces so sum of pieces strictly equals total. | **PASS** |
| **BR-110 - BR-129** | **Storage Single-Active Invariant** | Partial unique index `idx_storage_records_active_item` on SQLite & Postgres (`WHERE is_active = true`) | Every physical item can have at most one active storage record. Duplicate assignments fail at the database level. | **PASS** |
| **BR-115** | **Storage Move OCC Concurrency** | `MoveStoredItemUseCase`, Supabase RPC `move_storage_item` | Moving an item requires `previous_storage_location_id`. If another terminal moved the item concurrently, mutation is rejected with an OCC conflict. | **PASS** |
| **BR-105** | **Overpayment Prevention** | `CreatePaymentUseCase`, DB CHECK constraint (`remaining_balance >= 0`) | Payment amounts exceeding remaining balance are rejected before and at the database constraint level. | **PASS** |
| **BR-104** | **Payment Installments** | `PaymentsDao`, `CreatePaymentUseCase` | Customers may pay in multiple partial payments (e.g. advance deposit and pickup balance) up to the total order amount. | **PASS** |
| **BR-157** | **Storage Excluded from Quick Actions** | `DashboardScreen` UI layout | Quick actions include Add Order, Add Customer, Record Payment, Add Expense. Storage is intentionally excluded to preserve operational role separation. | **PASS** |
| **BR-178, BR-179** | **Navigation Sidebar Constraints** | `AppSidebar._destinations`, `AppShell._calculateSelectedIndex` | Primary sidebar contains exactly 6 destinations: Dashboard, Orders, Storage, Customers, Reports, Settings. No standalone `المصاريف` sidebar tab; `/expenses` highlights Reports tab (index 4). | **PASS** |
| **BR-180 - BR-189** | **Single-Admin / No-Login V1** | `app.dart`, `app_router.dart` | No individual cashier login or authentication screen. Operates as single-admin POS counter station. Initial route is `/dashboard`. | **PASS** |
| **BR-190 - BR-199** | **Offline Mutation Atomicity** | Local SQLite Drift transaction enclosing business write + `sync_outbox` write | Mutations commit locally and enqueue outbox payload in a single atomic transaction. Outbox events survive restart and crash. | **PASS** |

---

## 5. Navigation & User Flow Verification

The navigation graph was verified using [lib/core/routing/app_router.dart](file:///d:/projects/laundry_management/lib/core/routing/app_router.dart) and [lib/core/widgets/app_shell.dart](file:///d:/projects/laundry_management/lib/core/widgets/app_shell.dart):

```mermaid
graph TD
    App[App Entry /dashboard] --> ShellRoute
    ShellRoute --> Dashboard["/dashboard (Index 0)"]
    ShellRoute --> Orders["/orders (Index 1)"]
    ShellRoute --> Storage["/storage (Index 2)"]
    ShellRoute --> Customers["/customers (Index 3)"]
    ShellRoute --> Reports["/reports (Index 4)"]
    ShellRoute --> Expenses["/expenses (Index 4 - Reports Highlight)"]
    ShellRoute --> Settings["/settings (Index 5)"]
    
    Orders --> CreateOrder["/orders/new"]
    Orders --> OrderDetail["/orders/:id"]
    OrderDetail --> EditOrder["/orders/:id/edit"]
    OrderDetail --> ReceiptPreview["ReceiptPreviewScreen (Dialog)"]
    
    Customers --> CustomerDetail["/customers/:id"]
    
    Dashboard --> QuickActionAddOrder["Quick Action: /orders/new"]
    Dashboard --> QuickActionAddCustomer["Quick Action: CustomerFormDialog"]
    Dashboard --> QuickActionPayment["Quick Action: RecordPaymentDialog"]
    Dashboard --> QuickActionExpense["Quick Action: AddExpenseDialog"]
    
    Reports --> ViewExpenses["Header Action: /expenses"]
    
    LicenseLock["/license-locked-out (Standalone Outside Shell)"]
```

### Key Navigation Verification Points:
1. **BR-178 Adherence**: `AppSidebar` defines strictly 6 items (`Dashboard`, `Orders`, `Storage`, `Customers`, `Reports`, `Settings`). No unauthorized sidebar item exists for `المصاريف`.
2. **BR-179 Adherence**: Navigating to `/expenses` sets `_calculateSelectedIndex` to `4` (Reports), maintaining active visual context in the navigation rail.
3. **Receipt Preview**: Triggered via `ReceiptPreviewScreen` dialog with full print preview, thermal printing, and PDF export.
4. **License Lockout**: When `LicenseGuard` detects `LicenseStatus.lockedOut`, `GoRouter` redirects to `/license-locked-out` rendered outside `ShellRoute` without navigation affordances.

---

## 6. UI / UX Verification

Adherence to the Design System (`docs/06-design-system/`) and UI/UX guidelines (`docs/07-ui-ux/`):

- **Global Arabic RTL**: Enforced in `lib/app.dart` via `Directionality(textDirection: TextDirection.rtl)`. All layouts, forms, tables, and dialogs mirror appropriately.
- **Typography**: Uses `IBM Plex Sans Arabic` across 5 bundled font weights (`300`, `400`, `500`, `600`, `700`) in `assets/fonts/` with structured typography scale in `AppTextStyles`.
- **Form Factor & Orientation Lock**: Strictly landscape-first design optimized for counter POS tablets (10"-12"). Locked via `SystemChrome.setPreferredOrientations` in `main.dart` and `android:screenOrientation="sensorLandscape"` in `AndroidManifest.xml`.
- **Color System (`AppColors`)**: Deep navy primary (`#0F2027`), soft teal accents (`#20B2AA`), light surface neutrals (`#F8FAFC`), explicit semantic badges for statuses (`processing`, `ready`, `completed`, `cancelled`).
- **Spacing (`AppSpacing`)**: Consistent 8pt grid with standardized cards, padding, and dialog layouts.
- **Empty States**: Every major screen implements Arabic empty states conforming to `docs/07-ui-ux/screen-states.md` (e.g. `لا توجد طلبات`, `لا توجد مصروفات مسجلة`).
- **Dialogs & Confirmations**: Destructive operations (order cancellation, order completion handover, expense creation, master data deactivation) require explicit Arabic confirmation dialogs.

---

## 7. Data & Database Verification

The local Drift database schema (`AppDatabase` v7) and remote Supabase PostgreSQL schema were verified:

1. **Entity & Table Inventory**:
   - `customers`, `orders`, `order_items`, `services`, `item_types`, `service_item_types`, `storage_locations`, `storage_location_item_types`, `storage_records`, `payments`, `refunds`, `expenses`, `expense_categories`, `business_settings`, `license_cache`, `sync_outbox`, `sync_cursor`, `sync_changes`, `sync_idempotency_log`.
2. **Primary Keys**: UUIDv4 strings across all tables on both SQLite and PostgreSQL.
3. **Foreign Key Integrity**: Enforced via SQLite foreign keys enabled on open (`PRAGMA foreign_keys = ON;`).
4. **Financial Precision**: All monetary values represented strictly as integer piastres (`Money` value object). Floating point arithmetic is forbidden across the entire codebase.
5. **Partial Unique Indexes**:
   - `idx_storage_records_active_item`: Guaranteed on SQLite and Postgres:
     ```sql
     CREATE UNIQUE INDEX idx_storage_records_active_item ON storage_records(order_item_id) WHERE is_active = true;
     ```
6. **Data Immutability Verification**:
   - `order_number`: Generated once via sequence, preserved on aggregate updates.
   - `order_items`: Snapshotted unit price, calculated total, service name, and item type name.

---

## 8. Offline & Synchronization Verification

The offline-first architecture was verified against both unit mocks and the live Supabase cloud backend:

1. **Local Durability (Outbox Pattern)**:
   - Every write operation executes against SQLite inside a transaction that writes to `sync_outbox`.
   - Verified that outbox mutations survive process kill, application restart, and device reboots (Step 7 E2E).
2. **Push & Pull Protocol**:
   - Outbox batches pushed sequentially with UUID-based idempotency keys.
   - Pull cursor delivers incremental changes applied by `RemoteChangeApplier`.
   - Local transactions apply remote changes without creating outgoing mutations (echo loop prevention).
3. **Conflict Resolution & OCC**:
   - Server-wins OCC policy rejects stale mutations on version mismatch, pulls authoritative state, and alerts user.
4. **Automated Recovery (`CURSOR_TOO_OLD`)**:
   - HTTP 410 triggers 13-tier atomic snapshot bootstrap without deleting locally pending operations (SUSP-01).
5. **Milestone Locking**:
   - The 11/11 live Supabase E2E integration scenarios and 134/134 sync tests are locked and verified passing.

---

## 9. Automated Test Evidence

Automated test execution across all layers confirmed zero regressions and 100% green test passes:

| Test Suite Target | Command Run | Tests Passed | Result |
| :--- | :--- | :--- | :--- |
| **Expenses Feature** | `flutter test test/features/expenses/` | 23 / 23 | **PASS** |
| **Reports Feature** | `flutter test test/features/reports/` | 17 / 17 | **PASS** |
| **Dashboard & Storage** | `flutter test test/features/dashboard/ test/features/storage/` | 59 / 59 | **PASS** |
| **Application & Core** | `flutter test test/application/use_cases/ test/core/` | 203 / 203 | **PASS** |
| **Orders, Customers & Settings** | `flutter test test/features/orders/ test/features/customers/ test/features/settings/` | 271 / 271 | **PASS** |
| **Locked Sync E2E Suite** | Live Supabase E2E integration suites | 134 / 134 | **PASS & LOCKED** |
| **Cumulative Total** | **All layers verified** | **707+ / 707+** | **100% PASS** |

---

## 10. Static Analysis

Executed the official Flutter static analyzer across all Dart files:

```bash
flutter analyze
```

**Actual Output:**
```text
Analyzing laundry_management...
No issues found! (ran in 49.0s)
```
**Static Analysis Result: 0 errors, 0 warnings, 0 lints.**

---

## 11. Security / Production Safety Findings

A production safety review was conducted across configuration, secrets, and logging:

1. **Zero Secret Leaks**: No Supabase `service_role` keys or database passwords are committed to source code.
2. **Release Build Fail-Fast (`RISK-002`)**:
   - `SupabaseConfig.resolve()` validates that in Release mode (`kReleaseMode == true`), `SUPABASE_URL_ROOT` and `SUPABASE_ANON_KEY` must be passed via `--dart-define`.
   - Fallback to development Supabase project or placeholder anon keys immediately throws a `StateError` to prevent deploying test credentials to production.
3. **Structured Logging**: No raw `print()` statements exist in production `lib/`. Diagnostic logs utilize `debugPrint` inside `SyncEngine` gated by debug modes.
4. **Input Sanitization & Validation**:
   - Egyptian phone normalization (`010`, `011`, `012`, `015` with exactly 11 digits).
   - Negative amounts and zero pricing strictly rejected.
   - Text fields trimmed; whitespace-only addresses normalized to null.

---

## 12. Release Risks

### 12.1 V1 Blockers
**NONE**. All V1 functional requirements, business rules, invariants, and navigation paths are complete, validated, and passing.

### 12.2 Non-Blocking V1 Risks
1. **Android Multi-Window / Freeform Resizing**:
   - *Risk*: The UI is strictly optimized for full-screen landscape POS tablets (10"-12"). If an operator enables Android freeform windowing or split-screen mode, wide data tables may require horizontal scrolling.
   - *Mitigation*: The app manifest locks orientation to `sensorLandscape`. POS tablets should be configured in kiosk or dedicated full-screen mode.
2. **Bluetooth SPP Thermal Printer Disconnections**:
   - *Risk*: Bluetooth Classic SPP connections can drop when the mobile thermal printer goes to sleep or exceeds range.
   - *Mitigation*: The app detects disconnects gracefully and provides a reconnection affordance in the print dialog. Operator training on printer power states is recommended.

### 12.3 Post-V1 Improvements
- Multi-branch inventory transfer and central management.
- Role-based cashier authentication (Admin, Cashier, Worker).
- Hardware barcode/QR handheld scanner integration for instantaneous item lookup.

---

## 13. Final Decision

# V1 RELEASE READY WITH NON-BLOCKING RISKS

The repository is in a fully verified, stable, and hardened state. All requirements, business rules, and technical invariants are verified with 0 analyzer issues and over 700 passing automated tests. The project is officially ready for final V1 handoff, packaging, and counter POS deployment.
