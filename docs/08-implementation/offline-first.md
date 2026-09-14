# Offline-First Implementation

## 1. Purpose

This document defines the mandatory Offline-First behavior for the V1 Laundry Management System.

The purpose is to ensure that the application remains fully usable for its approved local workflows without requiring an Internet connection, while keeping the architecture ready for the future Backend and Synchronization phase.

V1 is Local-First.

Backend integration and synchronization are intentionally deferred.

This document defines the current implementation boundary and prevents premature introduction of remote infrastructure.

---

## 2. Core Principle

The application must prioritize the local database for normal V1 business operations.

The standard V1 flow is:

User
↓
Presentation
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source / DAO
↓
Drift / SQLite
↓
Immediate Local Result
↓
Cubit
↓
UI

The Internet is not required for this flow.

---

## 3. Offline-First vs Offline-Only

V1 is Offline-First, not necessarily Offline-Only.

Offline-First means:

- Core business operations work locally.
- Local data is immediately available.
- Local writes do not require network access.
- The architecture does not depend on a remote server for normal operation.
- Future synchronization can be added later.

It does not mean that the final product will permanently operate without a backend.

Backend and synchronization are intentionally deferred to a later implementation phase.

---

## 4. V1 Local Source of Truth

For the current implementation phase, the local database is the operational source of truth.

The application must be able to:

- Read local data.
- Create local data.
- Update local data.
- Apply approved business rules locally.
- Persist local changes.
- Display the updated local state immediately.

The UI must not wait for a future backend to confirm normal local operations.

---

## 5. No Network Dependency

The following V1 workflows must not require Internet connectivity:

- Customer creation.
- Customer editing.
- Order creation.
- Order item creation.
- Payment recording.
- Storage operations.
- Order completion.
- Order cancellation.
- Expense creation.
- Expense editing where supported.
- Supported master-data management.
- Dashboard local data.
- Reports based on local data.

The exact supported operations remain governed by the approved Product Scope and Requirements.

---

## 6. Network Is Not Required for Startup

The application must not require a successful API request before becoming operational for local workflows.

Startup should not depend on:

- Remote authentication.
- Remote configuration.
- API health checks.
- Sync completion.
- Remote master-data download.

If the application has local data, it should be able to operate on that data without waiting for a remote service.

---

## 7. Local Database Initialization

The application must initialize the local database according to the approved Database Implementation.

Database initialization must remain local.

Do not add a requirement such as:

Database initialization
↓
Connect to Backend
↓
Download schema/data

The local database must be independently usable.

---

## 8. Local Read Flow

A normal local read follows:

Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source
↓
Database
↓
Domain Data
↓
Cubit State
↓
UI

The UI must not directly query the database.

The Cubit must not directly access the DAO.

---

## 9. Local Write Flow

A normal local write follows:

User Action
↓
Presentation Validation
↓
Cubit
↓
Repository Contract
↓
Business Validation
↓
Repository Implementation
↓
Local Data Source
↓
Database Transaction
↓
Success / Failure
↓
Cubit State
↓
UI

The write is considered successful when the approved local persistence operation succeeds.

A future remote synchronization step is not part of V1 completion.

---

## 10. Immediate Local Feedback

Successful local mutations should become visible immediately.

Example:

Create Customer
↓
Save locally
↓
Local database updated
↓
Repository watcher emits
↓
Cubit updates
↓
Customer appears in list

The UI should not wait for:

- Server confirmation.
- Sync completion.
- Network availability.

---

## 11. Reactive Local Data

Where repository watchers are available, they should be preferred for data that needs to remain synchronized with local changes.

Example:

Database
↓
Repository Watch
↓
Cubit
↓
UI

This allows local changes to propagate automatically.

Example:

Add Expense
↓
Database changes
↓
Expense watcher emits
↓
ExpensesCubit updates
↓
Expense list refreshes

No manual server refresh should be required.

---

## 12. Local Consistency

After a successful local mutation, the application must remain internally consistent.

Examples:

Recording a Payment must update the Order's remaining amount.

Storing an OrderItem must update the relevant storage state.

Moving an OrderItem must deactivate the previous StorageRecord and create the new active StorageRecord.

Completing an Order must apply its approved storage side effects.

Cancelling an Order must apply its approved storage side effects.

These operations must use the appropriate transaction boundaries.

---

## 13. Atomic Local Operations

If multiple local records must change together, the operation must be atomic.

Example:

Move Item:

Deactivate old StorageRecord
+
Create new StorageRecord

Both operations succeed together or fail together.

Example:

Complete Order:

Update Order
+
Set completion timestamp
+
Deactivate active StorageRecords

The feature must not leave the local database in a partially updated state.

---

## 14. Offline Business Validation

Business rules must execute locally.

The absence of a network connection must not disable business validation.

Examples:

Payment > Remaining Amount

must be rejected locally.

Invalid Service/ItemType combination

must be rejected locally.

Invalid ItemDefinition/ItemType combination

must be rejected locally.

Carpet without required CarpetItemData

must be rejected locally.

Expense with invalid amount

must be rejected locally.

---

## 15. Offline Order Operations

Orders must remain operational offline.

The user should be able to perform approved local Order operations without network access.

Examples:

Create Order
↓
Save locally

Record Payment
↓
Save locally

Store OrderItems
↓
Save locally

Complete Order
↓
Apply local business rules
↓
Save locally

Cancel Order
↓
Apply local business rules
↓
Save locally

---

## 16. Offline Customer Operations

Customer management must work locally.

The application must be able to:

- Create Customers.
- Edit Customers.
- Search Customers.
- Load Customer history where supported.

These operations must not depend on a remote API in V1.

---

## 17. Offline Storage Operations

Storage operations must work locally.

The application must be able to:

- Show items requiring storage.
- Show compatible StorageLocations.
- Store an OrderItem.
- Move an OrderItem.
- Show the current location.
- Apply storage-related Order readiness rules.

The physical storage state is maintained locally.

---

## 18. Offline Payment Operations

Payment recording must work locally.

The application must validate:

- Positive amount.
- Valid PaymentMethod.
- Valid Order.
- Payment <= Remaining Amount.

A successful Payment is persisted locally.

The Order's local balance must update immediately.

The system must not require server confirmation to show the updated local balance.

---

## 19. Offline Expense Operations

Expense operations must work locally.

The application must be able to:

- Create Expenses.
- Edit Expenses where supported.
- List Expenses.
- Filter Expenses.
- Calculate approved local financial summaries.

Expense validation must execute locally.

---

## 20. Offline Master Data

Supported master-data operations must work locally.

This includes the approved V1 master-data concepts such as:

- Services.
- Item Types.
- Item Definitions.
- Carpet Sizes.
- Storage Locations.
- Expense Categories.
- Business Settings.

The exact CRUD/lifecycle behavior remains governed by the existing requirements and business rules.

---

## 21. Offline Dashboard

Dashboard information must be derived from local data.

Examples:

- Order counts.
- Ready Orders.
- Overdue Orders.
- Storage-related operational information.
- Financial information supported by the approved Dashboard scope.

The Dashboard must not require a remote analytics endpoint.

---

## 22. Offline Reports

Reports must operate against locally persisted transactional data.

Examples:

Sales
+
Expenses
↓
Net Profit

The Reports feature must not require a remote reporting service for V1.

---

## 23. No Fake Offline Data

The application must not simulate offline functionality using temporary in-memory data when the information is supposed to be persisted.

For business data:

Local database persistence is required.

Do not implement:

Create Order
↓
Keep in memory
↓
Pretend it was saved

The data must survive application restart.

---

## 24. Persistence Across Restart

Important local business data must remain available after:

- Screen navigation.
- Feature navigation.
- Application restart.
- Device restart, subject to the approved local database behavior.

The application must not treat Cubit memory as the source of persistent business data.

---

## 25. Cubit State Is Not Persistence

Cubit state represents presentation state.

It must not replace the database.

Do not rely on:

OrdersCubit state

as the permanent source of Orders.

The source of persisted V1 business data is the local database accessed through the Repository/Data Layer.

---

## 26. No In-Memory Business Database

Do not create a parallel in-memory repository for normal V1 operation.

Avoid architectures such as:

UI
↓
Cubit
↓
Memory Repository
↓
SQLite later

The local database should be the actual persistence layer.

---

## 27. Network Availability

V1 business behavior must not be based on:

if online then save

else fail

That is not acceptable for local-first operations.

Instead:

save locally

must be the normal behavior.

Future synchronization can process the local state later.

---

## 28. Connectivity Checks

Do not introduce connectivity checks into every feature.

Avoid:

if (isConnected) {
    ...
}

inside:

- Screens.
- Cubits.
- Forms.
- Repositories for normal local operations.

Connectivity becomes relevant when the future synchronization layer is implemented.

---

## 29. No Connectivity-Based UI Blocking

Do not disable core business actions simply because the device is offline.

For example:

Create Order

must not become disabled because Wi-Fi is unavailable.

Record Payment

must not become disabled because the Internet is unavailable.

Store Item

must not become disabled because the Internet is unavailable.

---

## 30. Local Error Handling

Local database failures must be handled through the approved Error Handling strategy.

Examples:

- Database unavailable.
- Constraint violation.
- Transaction failure.
- Unexpected local persistence error.

The user should receive a meaningful localized error.

Do not display raw SQLite/Drift exceptions.

---

## 31. Offline Error vs Validation Error

The UI should distinguish between:

Business validation failure

and:

Technical persistence failure.

Example:

Payment exceeds remaining amount

is a business failure.

Database transaction failed

is a technical/local persistence failure.

These should not be represented as the same user-facing condition.

---

## 32. Local Database Failure

If a local database operation fails:

- Do not pretend it succeeded.
- Do not update UI state as if persistence succeeded.
- Do not silently discard the error.
- Do not continue with dependent operations.

The Repository should return an appropriate failure.

The Cubit should expose the failure through the approved state model.

---

## 33. Transaction Failure

If a transaction fails:

All changes within that transaction must be rolled back according to the database transaction mechanism.

Example:

Move Item

If:

Deactivate old StorageRecord

succeeds but:

Create new StorageRecord

fails,

the previous active StorageRecord must remain valid.

---

## 34. Offline Historical Integrity

Offline operation must preserve the same historical data rules as online operation.

Master-data changes must not rewrite historical transactions.

Examples:

Change Service price
→ Old OrderItem price remains unchanged.

Change Service name
→ Historical Service snapshot remains unchanged.

Change Expense Category
→ Historical Expense meaning remains preserved.

Change Carpet Size
→ Historical CarpetItemData remains unchanged.

---

## 35. Offline Order Lifecycle

The Order lifecycle remains:

Processing
→ Ready
→ Completed

or:

Processing
→ Cancelled

The same lifecycle rules apply offline.

Offline mode must not create alternate Order statuses.

---

## 36. Offline Completion

Order completion must remain subject to the normal business prerequisites.

The application must verify locally:

- Order is Ready.
- Remaining amount = 0.
- Explicit handover confirmation.

Only then may the Order be completed.

---

## 37. Offline Cancellation

Order cancellation must work locally.

The application must:

- Validate cancellation requirements.
- Persist cancellation.
- Preserve Order history.
- Apply approved storage side effects.
- Keep the Order available for historical viewing.

No server confirmation is required in V1.

---

## 38. Offline Storage Integrity

The same storage invariants apply offline.

For each OrderItem:

At most one active StorageRecord.

Moving an item:

Deactivate old
+
Create new

Completion/cancellation:

Deactivate active storage according to the approved rules.

Status correction:

Completed → Processing

must not automatically reactivate previous storage.

---

## 39. Offline Payment Integrity

The same Payment rules apply offline.

Do not allow:

- Zero Payment.
- Negative Payment.
- Overpayment.
- Invalid PaymentMethod.
- Payment for a non-existing Order.

Payment history must remain persisted locally.

---

## 40. Offline Expense Integrity

The same Expense rules apply offline.

Do not allow:

- Zero amount.
- Negative amount.
- Missing Category.
- Missing customName when Category = Other.

The local database must preserve the transaction.

---

## 41. Offline Search

Search must operate against local data.

Examples:

Customer search
→ Local Customer data.

Order search
→ Local Order data.

Expense filtering
→ Local Expense data.

Storage lookup
→ Local Storage data.

Do not require a remote search endpoint during V1.

---

## 42. Offline Filtering

Approved filters must work locally.

Filtering should preferably execute through repository/database queries rather than loading unnecessary data into memory.

Examples:

Expenses by date.

Expenses by category.

Orders by status.

Orders by pickup date.

Storage by location.

The exact filters remain governed by the approved feature requirements.

---

## 43. Offline Sorting

Where sorting is required, use the appropriate local query/repository operation.

Do not implement large dataset sorting entirely in the UI when the database can perform the operation efficiently.

---

## 44. Offline Performance

The local-first architecture should remain responsive.

Avoid:

- Loading the entire database unnecessarily.
- Repeated full-table scans for simple operations.
- Rebuilding unrelated UI sections.
- Performing expensive calculations repeatedly in widgets.

Use appropriate indexes and queries defined by the Database documentation.

---

## 45. Offline Data Consistency

The application should maintain a consistent local model after every successful operation.

Examples:

Create Order
→ Order and OrderItems exist.

Record Payment
→ Payment exists and remaining balance reflects it.

Store Item
→ Active StorageRecord exists.

Move Item
→ Exactly one active StorageRecord exists.

Complete Order
→ Completion state and storage state are consistent.

Cancel Order
→ Cancellation and storage state are consistent.

---

## 46. No Partial Feature Offline Support

Do not advertise a feature as Offline-First if its core workflow still requires the network.

For example:

Order creation

cannot be considered Offline-First if:

Customer lookup

requires an API.

The full approved local workflow must operate against local data.

---

## 47. Local Master Data Availability

For an offline workflow to function, required master data must be available locally.

Examples:

Creating an Order may require:

- Customer.
- ItemType.
- ItemDefinition where applicable.
- Service.

Storage may require:

- StorageLocation.

Expenses may require:

- ExpenseCategory.

These dependencies must be satisfied from the local database during V1.

---

## 48. No Remote Master Data Dependency

Do not implement:

Create Order
↓
Fetch Services from API
↓
Continue

in the current phase.

Services and other required master data must come from local persistence.

Future synchronization may update them later.

---

## 49. Future Remote Data Source Boundary

The architecture must remain compatible with a future structure such as:

Repository
├── Local Data Source
└── Remote Data Source

The Feature layer should continue using:

Repository Contract

without needing to know whether data is local or remote.

---

## 50. Future Synchronization Boundary

Future synchronization should remain outside Feature Presentation.

Future architecture may conceptually become:

Cubit
↓
Repository
↓
Local Data
+
Remote Data
↓
Synchronization Infrastructure

The current implementation must not build this infrastructure prematurely.

---

## 51. No Sync Logic in Cubits

Do not add:

sync()

pushChanges()

uploadPendingOrders()

downloadUpdates()

to feature Cubits during V1.

Synchronization is infrastructure.

It is not a feature-level UI responsibility.

---

## 52. No Sync Logic in Widgets

Widgets must never contain synchronization logic.

Do not add:

- Connectivity listeners for business persistence.
- Upload buttons for normal V1 operations.
- Retry-sync UI.
- Remote refresh requirements.

unless explicitly introduced by the future synchronization phase.

---

## 53. No Sync Fields in Business Status

Do not add synchronization concepts to business entities unless explicitly approved.

Do not turn:

OrderStatus

into:

Processing
Ready
Completed
Cancelled
PendingSync
Syncing
SyncFailed

Synchronization state is separate from business lifecycle.

---

## 54. No Premature Sync Queue

Do not create:

SyncQueue

PendingUpload

SyncOperation

SyncConflict

or similar entities during the current V1 local implementation unless explicitly requested as part of the synchronization phase.

---

## 55. No Premature Conflict Resolution

Do not implement:

- Last-write-wins.
- Server-wins.
- Client-wins.
- Merge rules.
- Conflict UI.

during the local-only phase.

Those decisions belong to the future synchronization architecture.

---

## 56. Local IDs and Future Sync

The local data model must continue using the approved identifier strategy.

Do not introduce a second identifier system solely because a backend may be added later.

If future synchronization requires additional identifiers, that must be an explicit architecture/database decision.

---

## 57. Local Timestamps

Use the approved timestamp/date conventions from the Domain and Database documentation.

Do not introduce synchronization timestamps simply because they may be useful later.

Current V1 implementation should store only the approved fields.

---

## 58. Offline and Historical Dates

Offline operation must preserve the same date semantics as normal operation.

Date-only fields remain date-only.

Examples:

- Expected Pickup Date.
- Expense Date.

Do not convert business dates into network timestamps merely for future synchronization.

---

## 59. Offline Localization

Offline behavior must work with the Arabic RTL UI.

All local error messages and user-facing feedback must follow the localization rules.

Offline mode must not require remote translation resources.

---

## 60. Offline Startup

Startup should follow:

Initialize Flutter
↓
Initialize Core
↓
Initialize DI
↓
Initialize Local Database
↓
Initialize Router / Application
↓
Open Application

Do not add:

Initialize Network
↓
Wait for API
↓
Download Data
↓
Allow Application

as a V1 requirement.

---

## 61. Offline Database Migration

Database migrations must be local and deterministic.

An application update may require a database migration.

The migration must not depend on network availability unless a future architecture explicitly introduces that requirement.

---

## 62. Seed Data

Approved seed data must be available locally according to the Seed Data documentation.

Do not require a remote API to populate mandatory V1 reference data during normal local startup.

If seed data is intended to be static/system-provided, it should be installed through the approved local initialization mechanism.

---

## 63. Offline Deactivation

Master-data deactivation must work locally.

Example:

Deactivate Service
↓
Local database update
↓
Service no longer selectable for new Orders

Historical OrderItems remain valid.

---

## 64. Offline Reactivation

If reactivation is supported by the approved business rules, it must also work locally.

The operation must follow the same validation and lifecycle rules as online operation.

Do not introduce different behavior simply because the application is offline.

---

## 65. Offline Reporting Consistency

Reports must use the same local transaction data as the rest of the application.

If a Payment is recorded locally:

Payment
↓
Local database
↓
Order balance
↓
Reports

The report should reflect the local transaction according to its defined calculation rules.

---

## 66. Offline Dashboard Consistency

Dashboard values should reflect current local data.

If an Order changes from:

Processing
→ Ready

the Dashboard should reflect the updated local state through the normal data flow.

Do not maintain a separate manually updated Dashboard cache unless explicitly required.

---

## 67. No Duplicate Local State

Avoid maintaining separate copies of business state in:

- Cubits.
- Global variables.
- Dashboard caches.
- Feature managers.

when the same information already exists in the local database.

Derived presentation state is allowed.

Duplicated persistent business state is not.

---

## 68. Offline Feature Independence

Each feature must be capable of using local repository operations without requiring another feature's presentation state.

For example:

Storage
→ StorageRepository

not:

Storage
→ OrdersCubit

Reports
→ Repository contracts

not:

Reports
→ ExpensesCubit + OrdersCubit

This preserves the architecture and keeps offline behavior predictable.

---

## 69. Offline Testing

Offline behavior must be tested explicitly.

Tests should verify that core workflows work when no network is available.

The application should not contain hidden network assumptions that only appear during testing.

---

## 70. Required Offline Tests

At minimum, verify:

- Application can start without network.
- Local database initializes without network.
- Customers can be created without network.
- Orders can be created without network.
- Payments can be recorded without network.
- Storage operations work without network.
- Expenses can be created without network.
- Supported master-data operations work without network.
- Dashboard local data loads without network.
- Reports local data loads without network.

---

## 71. Persistence Tests

Verify that important local data survives application restart.

Examples:

Create Customer
→ Restart
→ Customer still exists.

Create Order
→ Restart
→ Order still exists.

Record Payment
→ Restart
→ Payment still exists.

Store Item
→ Restart
→ Storage state still exists.

Create Expense
→ Restart
→ Expense still exists.

---

## 72. Transaction Tests

Critical multi-record operations must have transaction tests.

At minimum:

- Move StorageRecord.
- Complete Order.
- Cancel Order where multiple records change.
- Create Order with OrderItems.
- Other approved multi-record mutations.

Tests must verify rollback behavior where applicable.

---

## 73. Offline Business Rule Tests

Critical business rules must be verified locally.

Examples:

- Payment cannot exceed remaining amount.
- Completion cannot happen while unpaid.
- Completion requires Ready.
- Completion requires handover confirmation.
- Incompatible StorageLocation is rejected.
- Incompatible Service is rejected.
- Invalid ItemDefinition is rejected.
- Carpet requirements are enforced.
- Expense Other requires customName.

---

## 74. Network Isolation Test

During V1 local feature testing, the feature should continue to work when network access is unavailable.

The implementation must not accidentally invoke:

- Dio.
- Retrofit.
- Remote APIs.

for normal local workflows.

---

## 75. Future Backend Compatibility

Offline-First does not mean the code should be redesigned twice.

The current architecture should preserve stable boundaries:

Presentation
↓
Cubit
↓
Repository Contract

The future phase can extend:

Repository Implementation

to coordinate:

Local Data Source
+
Remote Data Source

without requiring the Feature UI to become network-aware.

---

## 76. Future Synchronization Compatibility

Future synchronization should be added behind the existing architecture.

The desired conceptual evolution is:

V1:

Cubit
↓
Repository
↓
Local

Future:

Cubit
↓
Repository
↓
Local
+
Remote
+
Sync Infrastructure

The V1 Feature layer should remain unaware of synchronization details.

---

## 77. What Must Not Change Later

The following boundaries should remain stable when backend integration begins:

- Feature → Cubit.
- Cubit → Repository Contract.
- Domain entities.
- Business rules.
- Presentation responsibilities.
- Offline local persistence.

Backend integration should extend infrastructure rather than forcing UI rewrites.

---

## 78. What May Change Later

The future backend phase may introduce:

- Remote Data Sources.
- Dio.
- Retrofit.
- API DTOs.
- Remote authentication if required.
- Synchronization infrastructure.
- Sync status.
- Conflict handling.
- Retry policies.
- Remote error mapping.

These are explicitly outside the current V1 implementation.

---

## 79. AI Coding Agent Rules

The coding agent must treat this document as a hard boundary.

During the current V1 implementation, the agent must not:

- Add API calls.
- Add Dio usage.
- Add Retrofit usage.
- Add sync queues.
- Add remote repositories.
- Add connectivity requirements.
- Add sync states to business entities.
- Add remote startup dependencies.
- Disable local workflows when offline.

---

## 80. AI Must Not Add Network "Just in Case"

Do not add networking because:

"we will need it later."

Future backend support is already planned.

The current implementation should focus on correct local behavior.

---

## 81. AI Must Not Create Fake Sync

Do not create placeholder synchronization that:

- Pretends data was uploaded.
- Shows fake sync success.
- Generates fake server IDs.
- Simulates remote responses.
- Adds fake online/offline banners without functional purpose.

If synchronization is not implemented, it should remain absent.

---

## 82. AI Must Not Create Duplicate Repositories

Do not create:

OrderLocalRepository

OrderRemoteRepository

OrderSyncRepository

during V1 unless explicitly required.

Use the approved Repository architecture.

---

## 83. AI Must Preserve Local-First Semantics

A successful V1 business operation means:

The local operation succeeded.

Do not redefine success as:

The server accepted the operation.

There is no server dependency in the current phase.

---

## 84. AI Must Preserve Immediate UI Updates

After successful local persistence, the UI should reflect the local change through the approved state/data flow.

Do not introduce artificial waiting for future synchronization.

---

## 85. AI Must Preserve Local Transactions

The agent must use the approved transaction mechanisms for multi-record operations.

Do not split one business operation into independent writes simply to simplify implementation.

---

## 86. AI Must Preserve Local Validation

All approved business validation must work without network access.

Do not defer validation to a future backend.

The local application must protect business invariants itself.

---

## 87. AI Must Not Introduce Offline-Specific Business Rules

Offline mode must not create a different business model.

Do not introduce:

OfflineOrderStatus

OfflinePaymentRule

OfflineCompletionRule

OfflineStorageRule

The same Domain rules apply regardless of connectivity.

---

## 88. Offline Completion Criteria

The Offline-First implementation is complete when:

- Core V1 workflows work without network.
- Local database is the operational source.
- Repository boundaries are preserved.
- Cubits do not access database infrastructure directly.
- Local writes are persisted.
- Critical multi-record operations are transactional.
- Local business validation works.
- Historical data remains protected.
- Dashboard works from local data.
- Reports work from local data.
- Application startup does not depend on network.
- No premature synchronization exists.
- No feature contains direct network access.
- Future backend integration can be added behind the Repository boundary.

---

## 89. Final Offline-First Architecture

Current V1:

User
↓
Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source / DAO
↓
Drift / SQLite

Future:

User
↓
Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
├── Local Data Source / DAO
│   ↓
│   Drift / SQLite
│
└── Remote Data Source
    ↓
    Dio / Retrofit

Synchronization infrastructure may later coordinate local and remote state.

It must remain outside Presentation.

---

## 90. Final Principles

The V1 Offline-First implementation follows these principles:

1. Local data is the operational source of truth for V1.
2. Core business workflows must work without Internet access.
3. The local database provides durable persistence.
4. Cubit state is not persistent business storage.
5. Repositories remain the boundary between Features and Data.
6. Database transactions protect multi-record operations.
7. Business validation works locally.
8. Historical transaction data remains stable.
9. Offline mode does not create alternate business rules.
10. Connectivity must not block normal local operations.
11. Startup must not depend on a backend.
12. Remote APIs are deferred.
13. Synchronization is deferred.
14. Sync state must remain separate from business state.
15. No fake synchronization is allowed.
16. No speculative networking is allowed.
17. Future backend integration must happen behind existing boundaries.
18. The Feature layer should not need to know whether data is local or remote.
19. V1 should remain simple, reliable, and locally consistent.
20. Correct local behavior takes priority over premature distributed-system complexity. 