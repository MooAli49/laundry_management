**# Laundry Management System — Synchronization Strategy**

**## 1. Document Purpose**

This document defines the approved V1 synchronization strategy for the Laundry Management System.

The system is designed as an offline-first application.

The local database is the primary operational data source for the application UI.

Synchronization is responsible for transferring locally committed business changes to the remote backend and retrieving remote changes when required.

The synchronization strategy must preserve:

\- Stable entity identity

\- Local offline operation

\- Transaction integrity

\- Historical business data

\- Conflict safety

\- Retry capability

\- Expense synchronization

\- Master-data synchronization

\- Order synchronization

\- Payment synchronization

\- Storage synchronization

This document works together with:

\- docs/01-product/

\- docs/02-domain/

\- docs/03-architecture/

\- docs/04-database/database-overview\.md

\- docs/04-database/tables.md

\- docs/04-database/relationships.md

\- docs/04-database/constraints.md

\- docs/04-database/indexes.md

\- docs/04-database/seed-data.md

\- docs/04-database/database-decisions.md

\---

**# 2. Core Synchronization Principle**

The application is:

Offline-first

This means:

User Action

↓

Local Database

↓

UI Updates Immediately

↓

Sync Queue

↓

Remote Backend

↓

Synchronization Result

The UI must not require a successful network request before considering a valid local operation complete when the operation is supported offline.

\---

**# 3. Local Database as Operational Source**

The local SQLite/Drift database is the source used by the UI for normal application reads.

Examples:

\- Orders

\- Customers

\- OrderItems

\- Payments

\- Expenses

\- Expense Categories

\- Storage

\- Services

\- Item Types

The UI should not directly depend on remote API availability for normal data display.

\---

**# 4. Remote Backend Role**

The remote backend is responsible for:

\- Remote persistence

\- Multi-device synchronization

\- Server-side validation

\- Centralized business data

\- Authentication/authorization where applicable

\- Receiving local changes

\- Returning remote changes

The local database remains the application's operational layer.

\---

**# 5. Stable Entity Identity**

Every synchronized business entity uses a stable UUID.

Example:

Local Expense:

id = UUID-A

After synchronization:

Remote Expense:

id = UUID-A

The remote backend must not create a completely unrelated ID for the same logical entity without an explicit identity-mapping strategy.

Stable identity is required to prevent:

\- Duplicate entities

\- Duplicate Expenses

\- Duplicate Orders

\- Duplicate Payments

\- Duplicate Customers

\---

**# 6. Synchronization Queue**

Local mutations that require remote synchronization are represented through:

sync\_operations

The SyncOperation is infrastructure data.

It does not represent a business transaction.

It represents:

Something changed locally

↓

This change must eventually be synchronized

\---

**# 7. Sync Operation Fields**

The synchronization queue contains information such as:

\- id

\- entity\_type

\- entity\_id

\- operation\_type

\- status

\- retry\_count

\- last\_attempt\_at

\- last\_error

\- created\_at

\- updated\_at

The exact implementation may evolve as the backend integration becomes finalized.

\---

**# 8. Supported Sync Operation Types**

V1 supports the conceptual operations:

create

update

delete

However, destructive delete operations should be used carefully.

For historical business entities, deactivation/cancellation is preferred over physical deletion.

Therefore most normal business synchronization will primarily involve:

create

update

\---

**# 9. Sync Operation Status**

Synchronization operations must use controlled statuses.

The implementation may use values such as:

pending

processing

completed

failed

The exact persisted values must remain consistent across the Data Layer.

Arbitrary status strings are not allowed.

\---

**# 10. Sync Queue Lifecycle**

A typical synchronization operation follows:

pending

↓

processing

↓

completed

If synchronization fails:

pending

↓

processing

↓

failed

↓

retry

↓

processing

↓

completed

A failed operation must retain enough information to diagnose the failure.

\---

**# 11. Retry Strategy**

Temporary failures should be retried.

Examples:

\- No Internet

\- Timeout

\- Temporary server error

\- Connection reset

Permanent validation failures should not be retried indefinitely.

Examples:

\- Invalid request

\- Invalid entity state

\- Rejected business rule

\- Unauthorized operation

The synchronization layer should distinguish retryable failures from permanent failures.

\---

**# 12. Retry Count**

Each SyncOperation maintains:

retry\_count

The value increases when an attempted synchronization fails.

The system should use controlled retry behavior.

The exact maximum retry policy belongs to the synchronization implementation and may use exponential backoff.

\---

**# 13. Offline Creation Flow**

Example:

User creates Expense:

150 EGP

\+

منظفات

\+

25 August 2026

The flow is:

Create Expense locally

↓

Commit Expense

↓

Create SyncOperation

↓

Return success to UI

↓

User continues working

↓

Network becomes available

↓

SyncOperation is processed

↓

Expense sent to backend

↓

Operation marked completed

The user does not need to wait for the server to save the Expense before continuing normal work.

\---

**# 14. Atomic Local Mutation + Sync Queue**

When a local business operation requires synchronization:

Business Data Change

\+

SyncOperation Creation

must be committed atomically.

Example:

Create Expense

\+

Create SyncOperation

must happen inside the same local database transaction.

If the transaction fails:

Expense is not committed

\+

SyncOperation is not committed

This prevents:

Expense exists locally

\+

No synchronization record exists

or:

Sync record exists

\+

Expense does not exist

\---

**# 15. Expense Synchronization**

Expenses are fully synchronizable V1 business entities.

When creating an Expense locally:

expenses

\+

sync\_operations

are created atomically.

The SyncOperation contains:

entity\_type = expense

entity\_id = Expense.id

operation\_type = create

status = pending

\---

**# 16. Expense Update Synchronization**

When an Expense is edited locally:

Expense

↓

updated locally

↓

SyncOperation created

The SyncOperation identifies:

entity\_type = expense

entity\_id = Expense.id

operation\_type = update

The local Expense remains the source used by the UI.

\---

**# 17. Expense Category Synchronization**

Expense Categories are manageable master data.

Changes such as:

Create Category

Edit Category

Deactivate Category

may require synchronization.

The corresponding entity type is:

expense\_category

The system must preserve the category UUID across synchronization.

\---

**# 18. Expense Category Deactivation Sync**

When a user deactivates:

ExpenseCategory

the local change is synchronized as an update.

Example:

is\_active = false

The remote backend must preserve the category because historical Expenses may reference it.

The synchronization layer must not convert deactivation into destructive deletion.

\---

**# 19. Expense \`أخرى\` Synchronization**

For an Expense using:

Category = أخرى

the:

custom\_name

is part of the Expense business data.

Example:

expense\_category\_id = category\_uuid

custom\_name = إصلاح باب المحل

The synchronization operation must transfer both values.

The backend must preserve:

expense\_category\_id

and:

custom\_name

together.

\---

**# 20. Historical Expense Synchronization**

An Expense's historical values must remain synchronized accurately.

Important fields include:

amount

expense\_category\_id

custom\_name

date

notes

The system must not replace the historical amount with a current value.

\---

**# 21. Expense Date During Synchronization**

The field:

expenses.expense_date

represents the business date.

Synchronization must preserve the exact date.

Example:

Local:

2026-08-25

Remote:

2026-08-25

The synchronization process must not shift the date because of timezone conversion.

\---

**# 22. Expense Created/Updated Timestamps**

The technical fields:

created\_at

updated\_at

are timestamps.

They may be synchronized according to the backend contract.

They must not be confused with:

expenses.expense_date

which is the business date.

\---

**# 23. Master Data Synchronization**

The following master data may require synchronization:

\- Item Types

\- Item Definitions

\- Services

\- Service Item Types

\- Carpet Sizes

\- Storage Locations

\- Expense Categories

\- Business Settings

Business Settings synchronization must preserve the configured values without inventing defaults.

This includes the configured:

- business name
- address
- phone
- logo reference
- invoice footer text
- tax configuration

Stable identity must be preserved for the Business Settings record.

Master data changes must preserve stable UUIDs.

\---

**# 24. Master Data Deactivation**

Deactivation is synchronized as:

update

not:

delete

Example:

Service:

is\_active = false

The remote record remains available for historical references.

The same applies to:

\- Item Types

\- Item Definitions

\- Carpet Sizes

\- Storage Locations

\- Expense Categories

\---

**# 25. Order Synchronization**

Orders are synchronized as business entities.

An Order may be:

\- Created offline

\- Updated offline

\- Cancelled offline where allowed

\- Completed offline where the approved workflow allows it

The local Order retains its UUID.

\---

**# 26. Order Delivery Synchronization**

Order delivery data is synchronized as part of the Order.

The two delivery directions are independent:

- Delivery to Laundry
- Delivery to Customer

The two directions may both be selected for the same Order.

Each direction preserves its own requested value and fee.

The synchronization layer must not collapse the two directions into a single delivery flag or a single delivery fee.

Delivery data is part of the Order transaction and is not a separate Delivery Management entity.

No Driver, Vehicle, Route, Tracking, Assignment, or Delivery Status synchronization is introduced in V1.
\---

**# 27. OrderItem Synchronization**

OrderItems are synchronized with their parent Order.

Important identity:

OrderItem.id

must remain stable.

The following transaction-time fields must be preserved:

item\_type\_name\_snapshot

item\_definition\_name\_snapshot

service\_name\_snapshot

pricing\_type\_snapshot

unit\_price

calculated\_total

Synchronization must not recalculate historical OrderItem pricing from current Service configuration.

\---

**# 28. Order + OrderItems Atomicity**

Creating an Order normally involves:

Order

\+

OrderItems

These changes should be committed locally in one transaction.

Synchronization may represent them as multiple remote operations if required by the backend API, but the local database must never expose a partially created Order to the UI as a successful completed operation.

\---

**# 29. Payment Synchronization**

Payments are synchronized independently as child records of Orders.

Payment identity:

payments.id

must remain stable.

The Payment retains:

amount

payment\_method

paid\_at

order\_id

The synchronization layer must not convert a Payment into an Expense.

\---

**# 30. Payment and Expense Separation During Sync**

The synchronization system must preserve:

Payment

→

Order

and:

Expense

→

ExpenseCategory

No synchronization transformation may merge these entities.

A Payment is customer money received.

An Expense is business money spent.

\---

**# 31. Storage Synchronization**

StorageRecords are synchronized as physical item location state.

A Storage operation may involve:

Deactivate previous StorageRecord

\+

Create new StorageRecord

These changes must be treated carefully.

The final state must preserve:

At most one active StorageRecord

per OrderItem

\---

**# 32. Storage Move Synchronization**

Example:

OrderItem:

Item A

Current location:

A-01

User moves item to:

B-03

Local transaction:

StorageRecord A

→

inactive

StorageRecord B

→

active

Then synchronization sends the required changes.

The local database must never end with two active StorageRecords for the same OrderItem.

\---

**# 33. Storage Completion Synchronization**

When an Order is completed:

Order

→

completed

and:

All active StorageRecords

→

inactive

The local changes should be committed atomically.

Synchronization must preserve the resulting state remotely.

\---

**# 34. Conflict Principle**

The system must avoid silently overwriting valid user changes.

When two devices modify the same entity, the synchronization layer must identify the conflict.

The exact conflict resolution strategy depends on the final backend capabilities.

V1 should prefer deterministic conflict handling over silent data loss.

\---

**# 35. Last-Write-Wins**

Last-write-wins may be used for simple configuration fields where appropriate.

However, it must not blindly be applied to complex business state.

Examples requiring additional care:

\- Order status

\- Payments

\- Storage state

\- Financial totals

These concepts may require domain-aware conflict handling.

\---

**# 36. Expense Conflict Handling**

Expenses are relatively simple transactional records.

If the same Expense is edited on two devices, the system must preserve a deterministic result.

Possible strategy:

Latest valid update wins

provided that:

\- Entity identity is the same

\- Version/timestamp rules are respected

\- The update does not violate domain constraints

The final backend conflict contract determines the exact implementation.

\---

**# 37. Payment Conflict Handling**

Payments require stronger protection because they represent financial transactions.

The synchronization layer must avoid:

\- Duplicate Payments

\- Accidental overwriting

\- Duplicate synchronization

Stable Payment UUIDs are essential.

If the same Payment is retried after a network failure, the backend must recognize the existing identity rather than create a second Payment.

\---

**# 38. Expense Duplicate Prevention**

If the client sends the same Expense create operation multiple times because of retry:

The backend must use:

Expense.id

as the stable identity.

A retry must result in:

Same Expense

not:

Two Expenses

This requires idempotent create behavior or equivalent backend protection.

\---

**# 39. Order Duplicate Prevention**

The same principle applies to Orders.

If:

Order.id = UUID-A

and the synchronization request is retried:

The backend must not create:

Order UUID-B

for the same local Order.

\---

**# 40. Sync Idempotency**

Synchronization operations should be idempotent where possible.

Examples:

Create Expense UUID-A

\+

Retry

must result in:

One Expense UUID-A

not:

Two Expenses.

This is particularly important for unreliable network connections.

\---

**# 41. Pull Synchronization**

Synchronization is not only:

Local

↓

Remote

The system may also need:

Remote

↓

Local

for changes created or modified elsewhere.

The local database must apply remote changes through controlled transactions.

\---

**# 42. Remote Change Application**

When applying a remote change:

1\. Validate entity identity.

2\. Validate relationships.

3\. Validate business constraints where required.

4\. Apply the change locally.

5\. Update synchronization metadata.

6\. Avoid creating an unnecessary outgoing sync operation for the same remote change.

A remote update must not trigger an infinite:

Remote

→

Local

→

Remote

→

Local

loop.

\---

**# 43. Sync Loop Prevention**

When a remote change is applied locally:

The Data Layer must distinguish:

Remote-originated change

from:

User-originated local change

The remote application must not automatically enqueue the same change for upload again.

\---

**# 44. Sync Ordering**

Where entity dependencies exist, synchronization should respect logical order.

Example:

Customer

↓

Order

↓

OrderItem

↓

StorageRecord

A child entity should not be sent before its required parent exists remotely.

Similarly:

ExpenseCategory

↓

Expense

If an Expense references a newly created ExpenseCategory, the category must be synchronized first or the backend must support dependency-aware requests.

\---

**# 45. Expense Category Before Expense**

Example:

User creates a new category:

مواد تنظيف

Then creates:

Expense

150 EGP

Category = مواد تنظيف

The local database can commit both immediately.

During remote synchronization:

ExpenseCategory

↓

Expense

The category must become available remotely before the Expense is accepted if the backend enforces foreign keys.

\---

**# 46. Offline First Category Creation**

Expense Categories may be created offline.

The user must not require network connectivity to add a new Expense Category if the approved product workflow supports offline master-data management.

The local Category is immediately available for new Expenses.

\---

**# 47. Seed Data and Sync**

Initial seed data is not treated as ordinary user-created data.

The synchronization layer must avoid creating duplicate remote seed records.

Where the backend already contains the same master data:

The local initialization process must reconcile against stable identity/configuration rules.

\---

**# 48. Sync and Deactivated Master Data**

If a master record is deactivated remotely:

Remote

↓

Local

the local record must become inactive.

Existing historical references remain valid.

The UI should stop offering the record for new transactions.

\---

**# 49. Sync and Historical Data**

Synchronization must never modify historical transaction snapshots merely because master data changed remotely.

Example:

Service current price:

60 EGP

Historical OrderItem:

50 EGP

Syncing the Service update must not change:

OrderItem.unit\_price

from:

50

to:

60

\---

**# 50. Sync and Financial Calculations**

Synchronization must preserve the underlying transaction data.

Net Profit is recalculated from synchronized:

Orders

\+

Expenses

It is not synchronized as a separate business value.

Similarly:

Remaining Amount

is recalculated from:

Order Total

\-

Payments

It is not synchronized as an independent field.

\---

**# 51. Sync and Reports**

Reports always use the local database state.

When synchronization changes local data:

Local database updates

↓

Reactive queries update

↓

Reports refresh

The UI does not need to call the remote backend directly to regenerate reports.

\---

**# 52. Sync and Dashboard**

Dashboard data is derived from the local database.

When a local Expense is created offline:

Expense saved locally

↓

Dashboard financial values update immediately

↓

Sync happens later

This preserves the offline-first user experience.

\---

**# 53. Network Availability**

Synchronization should react to network availability where practical.

The application should not repeatedly send requests while the device is clearly offline.

When connectivity becomes available:

Pending SyncOperations

↓

Processed

The exact connectivity detection mechanism belongs to the infrastructure implementation.

\---

**# 54. Manual Sync**

V1 may expose a manual synchronization action if required by the UI.

The manual sync operation should:

1\. Process pending local changes.

2\. Pull remote changes where required.

3\. Resolve/report failures.

4\. Refresh local data.

Manual sync must not bypass local database transactions.

\---

**# 55. Automatic Sync**

The application may automatically synchronize when:

\- Connectivity is restored.

\- Application starts.

\- Application resumes.

\- A suitable background opportunity exists.

The exact background execution mechanism is platform-dependent.

The business logic must remain independent from the UI lifecycle.

\---

**# 56. Sync Failure Visibility**

A synchronization failure should not silently destroy local data.

The local business transaction remains available.

The system should retain:

\- Sync status

\- Retry count

\- Last error

This allows the application to communicate synchronization problems when appropriate.

\---

**# 57. Permanent Failure Handling**

If a synchronization operation fails because the data is invalid:

The operation must not retry forever.

Example:

Backend rejects invalid business state.

The system should:

\- Mark the operation as failed.

\- Preserve the local data.

\- Record the error.

\- Surface an actionable state when appropriate.

Automatic destructive rollback of valid local business data is not allowed without an explicit conflict/recovery strategy.

\---

**# 58. Local Data During Sync Failure**

If the network fails after a successful local operation:

The local operation remains valid.

Example:

Create Expense

↓

Local success

↓

Network request fails

Result:

Expense remains visible locally.

SyncOperation remains pending/failed.

The user can continue working offline.

\---

**# 59. Sync Queue Ordering**

For independent transactions, queue order may follow:

created\_at ASC

For dependent transactions, dependency order must override simple timestamp order.

Example:

ExpenseCategory creation

before

Expense creation

when the Expense references the new category.

\---

**# 60. Sync Queue Indexes**

The SyncOperation table should support:

status

\+

created\_at

for pending queue processing.

It should also support:

entity\_type

\+

entity\_id

for entity-specific lookup.

These indexes are defined in:

indexes.md

\---

**# 61. Sync Transaction Boundaries**

Every local mutation that changes multiple related tables should be atomic.

Examples:

Create Order

\+

OrderItems

Move Storage

\+

StorageRecords

Complete Order

\+

StorageRecords

Create Expense

\+

SyncOperation

Update Expense

\+

SyncOperation

Create ExpenseCategory

\+

SyncOperation

This prevents partially committed local state.

\---

**# 62. Sync and Authentication**

Authentication/authorization is handled by the API/security layer.

The synchronization system must react appropriately to authentication failures.

For example:

401 Unauthorized

may require:

\- Token refresh

\- Re-authentication

\- Sync retry after authentication succeeds

The exact authentication strategy is defined by the backend architecture.

\---

**# 63. Sync and Server Validation**

Remote backend validation remains authoritative for server-level constraints.

However, the local database and Domain layer should validate as much as possible before synchronization.

Goal:

Invalid local data

↓

Prevent before network

Valid local data

↓

Send to server

This reduces unnecessary failed requests.

\---

**# 64. Sync and Business Rules**

Synchronization must not bypass Domain rules.

For example:

An Order cannot be marked Completed if the approved business conditions are not satisfied.

A Payment cannot exceed the allowed remaining amount.

An Expense using \`أخرى\` requires custom\_name.

A Service must be compatible with the selected ItemType.

These rules must be respected both locally and remotely where applicable.

\---

**# 65. Sync and Master Data Changes**

Master data updates can affect future operations but must not rewrite history.

Examples:

Service price changes.

Expense Category rename.

Storage Location deactivation.

Item Definition deactivation.

The local and remote databases must preserve historical transaction snapshots.

\---

**# 66. Sync and Expense Category Rename**

Example:

Local Category:

منظفات

User renames it to:

مواد تنظيف

The update is synchronized.

Historical Expenses referencing the category remain associated with the same category UUID.

The category name may display according to the current master data where appropriate, while transaction-specific custom\_name remains independent.

\---

**# 67. Sync and Expense Category Deactivation**

Example:

Category:

نقل

is deactivated.

Synchronization sends:

is\_active = false

Existing Expenses remain valid.

New Expenses cannot select the category.

\---

**# 68. Sync and Expense Editing**

If an Expense is edited:

Amount

or

Category

or

Date

or

Custom Name

or

Notes

the local record is updated.

A synchronization update is queued.

The UI reflects the local value immediately.

\---

**# 69. Sync and Expense Deletion**

V1 should avoid destructive deletion of historical Expenses.

If the product later supports deleting an Expense, the deletion must be explicitly defined as a business operation with synchronization semantics.

The synchronization layer must not invent hard-delete behavior.

\---

**# 70. Sync and Order Cancellation**

Order cancellation is a business state change.

The preferred synchronization operation is:

update Order

\+

status = cancelled

rather than:

delete Order

Historical Orders must remain available.

\---

**# 71. Sync and Payment History**

Payments must remain historical records.

A Payment should not be overwritten simply because another Payment was added.

Each Payment has its own stable identity.

\---

**# 72. Sync and Storage History**

Storage history is preserved locally and remotely where the backend model supports it.

Moving an item should not erase all previous StorageRecords.

The system must preserve the current active location and historical inactive records according to the approved backend contract.

\---

**# 73. Sync and Data Integrity**

Before a local change enters the sync queue, the Data Layer should ensure:

\- Required fields exist.

\- Foreign keys are valid.

\- Monetary values are valid.

\- IDs are stable.

\- Business rules are satisfied.

The sync queue should not be used as a mechanism for validating obviously invalid local data.

\---

**# 74. Sync and Database Transactions**

The local database transaction is the first integrity boundary.

The remote API request is the second integrity boundary.

The system must not assume:

Remote success

until the API confirms success.

Likewise, the UI must not assume that remote synchronization succeeded simply because the local operation succeeded.

\---

**# 75. User Experience During Sync**

The UI should distinguish:

Saved locally

from:

Synchronized

A successful local operation may show immediate success even if synchronization is pending.

If synchronization is delayed, the user should still be able to continue normal work.

The exact visual treatment is defined in UI/UX documentation.

\---

**# 76. Sync Status Does Not Change Business Status**

Synchronization status must not be confused with business status.

Example:

Order:

status = ready

Sync:

status = pending

These are separate concepts.

Similarly:

Expense exists locally

while:

Expense synchronization = pending

The Expense is still a valid local business record.

\---

**# 77. No Sync Fields in Domain Entities Unless Required**

The Domain model should not become dependent on:

retry\_count

sync\_status

last\_error

These belong to the synchronization infrastructure.

Business entities should remain focused on business meaning.

\---

**# 78. Sync Metadata Separation**

Infrastructure data:

sync\_operations

must remain separate from business tables.

Avoid adding:

sync\_status

directly to every business entity unless a future technical decision explicitly requires it.

\---

**# 79. Conflict Logging**

If a conflict cannot be resolved automatically, the system should retain enough information to diagnose it.

Possible information includes:

\- Entity type

\- Entity ID

\- Local version/time

\- Remote version/time

\- Error reason

The exact conflict-log architecture is not required unless the backend introduces multi-device conflict scenarios that need persistent conflict records.

\---

**# 80. V1 Conflict Scope**

V1 should keep conflict handling intentionally simple.

Priority:

1\. Prevent duplicates.

2\. Preserve stable IDs.

3\. Protect financial data.

4\. Protect storage state.

5\. Preserve historical records.

6\. Avoid silent data loss.

7\. Use deterministic resolution where possible.

A complex general-purpose conflict resolution engine is not required for initial implementation.

\---

**# 81. Sync Security**

Synchronization requests must use the approved API authentication mechanism.

Sensitive authentication credentials must not be stored in the business database tables.

Tokens and credentials belong to the secure application storage/authentication layer.

\---

**# 82. Sync and Local Database Backup**

Local database backup/restore, if implemented later, must preserve:

\- Business entity IDs

\- Historical transactions

\- Sync state where required

\- Master data

A restored local database must not accidentally replay already-completed synchronization operations without idempotency protection.

\---

**# 83. Sync and App Restart**

If the application closes while synchronization is running:

Pending/processing operations must be recoverable.

On next application startup:

Incomplete synchronization operations

↓

Returned to a retryable state

↓

Processed again

The system must not permanently lose operations because the application was terminated.

\---

**# 84. Sync and Crash Safety**

The local transaction model must guarantee that:

Business Data

\+

Sync Operation

are either both committed or both rolled back.

This is especially important for:

Expenses

Payments

Orders

Storage operations

\---

**# 85. Sync and Database Migration**

Database migrations must preserve synchronization data where necessary.

A migration must not accidentally delete:

pending SyncOperations

unless the migration explicitly transforms them safely.

If a schema change modifies an entity that has pending sync operations, the migration must preserve entity identity and compatibility.

\---

**# 86. Sync and Seed Migration**

Seed migrations must not create duplicate synchronization operations for initial static master data unless required by the backend architecture.

User-created or user-modified master data must remain distinguishable from initial seed initialization.

\---

**# 87. Sync and Expense Categories During First Setup**

At first installation:

Expense Categories

↓

Seeded locally

No fake Expenses

↓

Created

When the application is connected to an already initialized remote environment, the implementation must reconcile local seed data with remote master data according to stable identity rules.

\---

**# 88. Sync and Financial Reports**

Financial reports are local derived views.

The report does not synchronize:

Net Profit

as a standalone entity.

Instead:

Remote Orders

\+

Remote Payments

\+

Remote Expenses

↓

Local synchronized data

↓

Financial Report query

↓

Net Profit

\---

**# 89. Sync and Outstanding Amount**

Outstanding amount is recalculated locally from:

Order Total

\-

Payments

It is not synchronized as a separate field.

This prevents:

Local Remaining Amount

and:

Remote Remaining Amount

from becoming inconsistent.

\---

**# 90. Sync and Dashboard Totals**

Dashboard totals are derived from local synchronized data.

Examples:

Total Sales

Total Payments

Total Expenses

Net Profit

The Dashboard does not require a dedicated synchronization endpoint for each metric.

\---

**# 91. Sync Performance**

Synchronization should process changes in manageable batches where practical.

The implementation should avoid:

\- Sending the entire database on every sync.

\- Re-uploading unchanged records.

\- Re-downloading unchanged records.

Only changed entities should be synchronized where the backend supports incremental synchronization.

\---

**# 92. Pull Increment Strategy**

If the backend supports change tracking, the client should use an incremental mechanism such as:

last\_sync\_timestamp

or:

server change token/version

The exact mechanism depends on the backend API.

The local database should retain enough synchronization metadata to continue from the last successful synchronization point.

\---

**# 93. Full Resynchronization**

A full resynchronization may be required in exceptional cases.

Examples:

\- First login on a new device

\- Local database restoration

\- Corrupted sync state

\- Server-requested reset

A full resync must preserve local unsynchronized business data or explicitly protect it before replacement.

It must never blindly delete local pending changes.

\---

**# 94. Sync Error Recovery**

When synchronization fails:

1\. Preserve local business data.

2\. Preserve SyncOperation.

3\. Increment retry count where appropriate.

4\. Store error information.

5\. Retry if the error is temporary.

6\. Stop automatic retries for permanent validation errors.

7\. Surface actionable information when necessary.

\---

**# 95. Sync Error Examples**

**## Temporary**

Network unavailable

Action:

Retry later.

**## Temporary**

Timeout

Action:

Retry.

**## Temporary**

Server unavailable

Action:

Retry later.

**## Permanent**

Invalid Expense Category

Action:

Mark failure and require correction.

**## Permanent**

Invalid Order state

Action:

Mark failure and require resolution.

**## Authentication**

Expired token

Action:

Refresh authentication and retry if possible.

\---

**# 96. Sync and Local Editing While Pending**

A user may edit an entity while a previous synchronization operation is still pending.

The implementation must handle this safely.

Example:

Expense created offline:

150 EGP

Then edited before sync:

175 EGP

The synchronization layer should avoid sending stale:

150 EGP

as the final state if the intended current entity state is:

175 EGP

The exact queue coalescing strategy may combine multiple updates into the latest valid state.

\---

**# 97. Sync Operation Coalescing**

For simple entities such as Expense:

Create

\+

Update

\+

Update

may be coalesced into:

Create

with the latest entity state

if the remote create has not yet occurred.

This is an optimization, not a requirement for correctness.

The final implementation should prioritize correctness and simplicity.

\---

**# 98. Sync and Delete Coalescing**

If a future approved delete operation exists:

Create

\+

Delete

before synchronization may be safely collapsed depending on business semantics.

However, V1 avoids destructive transaction deletion.

No generalized delete-coalescing system is required initially.

\---

**# 99. Sync and Master Data Coalescing**

Master data updates may be coalesced.

Example:

ExpenseCategory created offline

↓

Renamed

↓

Deactivated

The synchronization system may eventually send only the final valid state if the backend has not yet received the initial record.

The category UUID must remain unchanged.

\---

**# 100. Sync Ordering Principle**

The system should prioritize:

Dependencies

before

Dependents

Examples:

ExpenseCategory

before

Expense

Customer

before

Order

Order

before

OrderItem

OrderItem

before

StorageRecord

This prevents avoidable foreign-key failures on the remote backend.

\---

**# 101. AI Implementation Rules**

AI coding tools implementing synchronization must:

1\. Preserve offline-first behavior.

2\. Treat local database changes as immediately usable.

3\. Create SyncOperations atomically with local mutations.

4\. Preserve UUID identity.

5\. Prevent duplicate remote records on retry.

6\. Preserve Expense/Payment separation.

7\. Synchronize Expense Categories.

8\. Synchronize Expenses.

9\. Preserve Expense custom\_name.

10\. Preserve Expense business date.

11\. Preserve historical OrderItem snapshots.

12\. Preserve StorageRecord integrity.

13\. Preserve Payment identity.

14\. Avoid destructive transaction deletion.

15\. Avoid sync loops.

16\. Avoid syncing derived Net Profit.

17\. Avoid syncing derived Remaining Amount.

18\. Respect entity dependencies.

19\. Distinguish retryable and permanent errors.

20\. Preserve pending operations across app restarts.

21\. Keep sync infrastructure separate from Domain entities.

22\. Use local transactions for multi-table mutations.

23\. Follow the backend API contract.

24\. Do not invent unsupported conflict behavior.

25\. Do not introduce a second synchronization architecture.

\---

**# 102. Final Synchronization Architecture**

The approved V1 synchronization flow is:

User

↓

Flutter UI

↓

Domain/Application Layer

↓

Local Drift Database

↓

Immediate UI Update

↓

SyncOperation

↓

Synchronization Worker

↓

Remote API

↓

Backend Database

For remote changes:

Remote API

↓

Synchronization Worker

↓

Local Drift Database

↓

Reactive Queries

↓

Flutter UI

\---

**# 103. Final Expense Synchronization Flow**

The approved Expense flow is:

User

↓

إضافة مصروف

↓

Validate Amount

↓

Validate Category

↓

Validate \`أخرى\` custom name when required

↓

Validate Date

↓

Local Expense Transaction

\+

SyncOperation

↓

UI updates immediately

↓

Network available

↓

Remote Expense Sync

↓

SyncOperation completed

\---

**# 104. Final Expense Category Synchronization Flow**

The approved Category flow is:

User

↓

Settings

↓

Add/Edit/Deactivate Expense Category

↓

Local Database

\+

SyncOperation

↓

Remote Backend

↓

Synchronization Complete

Historical Expenses remain valid throughout the process.

\---

**# 105. Final Financial Synchronization Principle**

The system synchronizes:

Orders

\+

Payments

\+

Expenses

It does not synchronize:

Net Profit

Remaining Amount

Expense Totals

Dashboard Metrics

These are derived locally from synchronized transactional data.

\---

**# 106. Final Storage Synchronization Principle**

The system synchronizes:

OrderItems

\+

StorageRecords

The current physical location is derived from:

Active StorageRecord

The system must never allow:

Two Active StorageRecords

for the same OrderItem

\---

**# 107. Final Historical Data Principle**

Synchronization must never rewrite historical business truth because current master data changed.

Examples:

Service price changes

≠

Historical OrderItem price changes

Expense Category rename

≠

Expense amount/date changes

Carpet Size changes

≠

Historical Carpet dimensions changes

Storage Location rename/deactivation

≠

Historical StorageRecord deletion

\---

**# 108. Final Synchronization Principles**

The V1 synchronization architecture is based on:

Offline-first

\+

Local-first reads

\+

Stable UUID identity

\+

Atomic local transactions

\+

Queued synchronization

\+

Retryable operations

\+

Idempotent remote writes

\+

Dependency-aware synchronization

\+

Historical data protection

\+

Financial data protection

\+

Storage integrity

\+

Manageable master data

\+

Derived financial reporting

\+

Minimal conflict complexity

The synchronization system must remain infrastructure.

It must support the business model without redefining it.

The final rule is:

Local operation first

\+

Reliable synchronization later

\+

No duplicate data

\+

No silent data loss

\+

No corruption of historical transactions

\+

No invented business entities