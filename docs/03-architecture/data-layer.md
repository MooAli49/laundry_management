# Laundry Management System — Data Layer

## 1. Document Purpose

This document defines the approved V1 Data Layer architecture for the Laundry Management System.

The Data Layer is responsible for:

- Local database access
- Remote API access
- Repository implementations
- Drift database integration
- Database transactions
- Local queries
- Pagination
- Search
- Filtering
- Seed initialization
- Database migrations
- Synchronization persistence
- Sync queue processing
- Mapping remote data to local persistence where required

The Data Layer must implement the approved Product, Domain, Database, and Architecture decisions.

It must not redefine business requirements.

---

# 2. Data Layer Position

The approved application direction is:

    Presentation
        ↓
    Domain / Application Logic
        ↓
    Repository Interfaces
        ↓
    Data Layer
        ↓
    Local Database / Remote API

The Data Layer contains the concrete implementations required to persist and retrieve application data.

---

# 3. Local-First Principle

The local database is the primary operational data source.

Normal application workflows should use:

    UI
        ↓
    Repository
        ↓
    Local Database
        ↓
    UI

Remote synchronization happens separately.

The application must remain functional when the remote API is unavailable.

---

# 4. Local Database Technology

The approved local database stack is:

    Drift
        ↓
    SQLite

Drift is responsible for:

- Table definitions
- Type-safe queries
- Transactions
- Reactive queries
- Database migrations
- Local persistence

SQLite is responsible for persistent relational storage.

---

# 5. Remote API Role

The Remote API is responsible for:

- Server persistence
- Remote synchronization
- Server-side validation
- Authentication where applicable
- Multi-device data synchronization

The Data Layer must not make the UI dependent on remote API availability for normal local operations.

---

# 6. Repository Pattern

Repositories provide the application-facing data access boundary.

The Domain/Application layer should depend on repository contracts rather than directly on:

- Drift
- SQLite
- SQL
- Dio
- HTTP clients
- Sync queue implementation

Example:

    ExpenseRepository
        ↓
    ExpenseRepositoryImpl
        ↓
    Local Database
        +
    Remote Synchronization

---

# 7. Repository Responsibilities

Repositories are responsible for:

- Reading local data
- Writing local data
- Executing appropriate transactions
- Exposing application-friendly operations
- Coordinating local persistence
- Triggering synchronization operations where required
- Providing streams/watchers where appropriate
- Handling local query details

Repositories must not become generic utility classes containing unrelated business logic.

---

# 8. Approved Repository Areas

V1 repositories should cover the following business areas:

- Customers
- Orders
- OrderItems
- Payments
- Storage
- Item Types
- Item Definitions
- Services
- Service/Item Type Compatibility
- Carpet Sizes
- Business Settings
- Expense Categories
- Expenses

Synchronization infrastructure may have its own repository/service implementation.

---

# 9. Customer Data

Customer persistence must support:

- Create Customer
- Update Customer
- Search Customer
- Find Customer by ID
- Find Customer by phone
- List Customers
- Observe Customer changes where required

Customer search must support at least:

- Customer Name
- Customer Phone

The local database is used for normal Customer search.

---

# 10. Order Data

Order persistence must support:

- Create Order
- Update Order
- Find Order
- Search Orders
- Filter Orders
- Sort Orders
- Paginate Orders
- Observe Orders
- Load Order details
- Calculate/report derived financial state

Orders must preserve their historical transaction values.

---

# 11. Order Search

Order search must support:

- Order Number
- Customer Name
- Customer Phone

The Data Layer should perform these searches locally.

The UI must not load the entire Order table and filter it manually in memory.

---

# 12. Order Pagination

Orders are expected to grow over time.

The Data Layer must support incremental loading.

Preferred concept:

    Initial Batch
        ↓
    Load More
        ↓
    Next Batch
        ↓
    Continue

The UI should not need to know raw SQL pagination details.

The exact query strategy may use:

    created_at
        +
    id

for stable ordering where appropriate.

---

# 13. OrderItem Data

OrderItems represent individual physical laundry items.

The Data Layer must preserve the distinction between:

    Order

and:

    OrderItem

Example:

    Order
    ├── Shirt
    ├── Shirt
    ├── Blanket
    └── Carpet

Each physical item must remain an individual OrderItem record.

The Data Layer must never merge physically separate items merely because they share the same Item Type.

---

# 14. Order Creation Transaction

Creating an Order may involve:

    Create Order
        +
    Create OrderItems
        +
    Create related Carpet data where applicable
        +
    Create SyncOperation

These local changes should be performed atomically.

If any required part fails:

    Rollback

The UI must not receive a successful result for a partially created Order.

---

# 15. OrderItem Pricing Data

OrderItem persistence must preserve transaction-time pricing.

Important values include:

- service_id
- service_name_snapshot
- pricing_type_snapshot
- unit_price
- calculated_total
- item_type_id
- item_type_name_snapshot
- item_definition_id
- item_definition_name_snapshot

Historical values must not be recalculated from current Service configuration.

---

# 16. Payment Data

Payment persistence must support:

- Record Payment
- Multiple Payments per Order
- Payment History
- Payment Method
- Payment Timestamp
- Payment Amount
- Payment lookup by Order
- Payment reporting

Payments belong to Orders.

The Data Layer must not treat Payments as Expenses.

---

# 17. Payment Transaction

If recording a Payment requires multiple local changes, they must be performed in one database transaction.

The local result must not leave:

    Payment partially persisted

or:

    Payment persisted without required synchronization metadata

when synchronization is required.

---

# 18. Remaining Amount

The Data Layer must not persist a separate:

    remaining_amount

field unless explicitly required by a future approved schema change.

Remaining Amount is derived from:

    Order Total
        -
    Sum of Payments
        =
    Remaining Amount

The repository may expose a query or derived result for this calculation.

---

# 19. Storage Data

Storage is associated with individual OrderItems.

The Data Layer must support:

    OrderItem
        ↓
    StorageRecord
        ↓
    StorageLocation

The system must support:

- Store Item
- Bulk Storage
- Move Item
- Search Stored Items
- Filter by Location
- Find Current Item Location
- Find Items Requiring Storage

---

# 20. Storage Move Transaction

Moving an item must be atomic.

The local transaction should perform:

    Deactivate Previous Active StorageRecord
        +
    Create New Active StorageRecord

Both operations must succeed together.

The result must never leave:

    Two Active StorageRecords
    for the same OrderItem

---

# 21. Bulk Storage

Bulk Storage must use a database transaction.

Example:

    Select multiple OrderItems
        ↓
    Select StorageLocation
        ↓
    Create Active StorageRecords
        ↓
    Commit

Each physical OrderItem remains an independent record.

---

# 22. Order Completion Transaction

Completing an Order may require:

    Update Order Status
        +
    Set Completed At
        +
    Deactivate Active StorageRecords
        +
    Create/Update Sync Operations

These changes must be atomic.

If the transaction fails:

    Rollback

---

# 23. Order Cancellation Transaction

Cancelling an Order may require:

    Update Order Status
        +
    Store Cancellation Information
        +
    Deactivate Active StorageRecords
        +
    Create/Update Sync Operations

Payment history must remain preserved.

The Order itself must remain available as historical data.

---

# 24. Item Type Data

Item Type persistence must support:

- Create
- Edit
- Activate
- Deactivate
- List
- Search/filter where required

Inactive Item Types must not normally be selectable for new Orders.

Existing historical OrderItems remain valid.

---

# 25. Item Definition Data

Item Definition persistence must support:

- Create
- Edit
- Activate
- Deactivate
- List by Item Type
- Select active definitions for Order creation

The Data Layer must preserve:

    item_type_id
        ↓
    item_definitions

Historical OrderItems must preserve their transaction-time definition snapshot.

---

# 26. Service Data

Service persistence must support:

- Create Service
- Edit Service
- Activate Service
- Deactivate Service
- Configure Pricing Type
- Configure Price
- Configure Supported Item Types
- List Active Services
- Load Service details

Current Service configuration belongs to master data.

Historical OrderItem pricing remains independent.

---

# 27. Service Compatibility Data

The Data Layer must support the relationship:

    Service
        ↕
    ServiceItemType
        ↕
    ItemType

Queries must support:

- Item Types supported by a Service
- Services supported by an Item Type
- Adding compatibility
- Removing compatibility
- Preventing duplicate compatibility records

---

# 28. Carpet Size Data

Carpet Size persistence must support:

- Create Carpet Size
- Edit Carpet Size
- Activate
- Deactivate
- List active Carpet Sizes

Carpet Sizes are master data.

Historical Carpet transaction dimensions remain stored independently.

---

# 29. Carpet OrderItem Data

For Carpet OrderItems, the Data Layer must support:

    OrderItem
        ↓
    OrderItemCarpet

The transaction must preserve:

- Length
- Width
- Area
- Optional CarpetSize reference

Changing a CarpetSize later must not change historical dimensions.

---

# 30. Storage Location Data

Storage Location persistence must support:

- Create
- Edit
- Activate
- Deactivate
- List active locations
- Search/filter locations
- Load stored items by location

Inactive Storage Locations cannot be selected for new Storage operations.

Existing StorageRecords remain valid.

---

# 31. Business Settings Data

BusinessSettings represents the single-business configuration.

The Data Layer must support:

- Load Settings
- Update Settings
- Initialize default Settings

V1 supports one BusinessSettings record.

The exact single-record enforcement is defined by database constraints.

---

# 32. Expense Category Data

Expense Categories are manageable master data.

The Data Layer must support:

- List active Expense Categories
- List all Expense Categories
- Create Expense Category
- Edit Expense Category
- Activate Expense Category
- Deactivate Expense Category
- Find Expense Category by ID
- Prevent duplicate category names

Expense Categories must be persisted in:

    expense_categories

They must not be hard-coded as an immutable application enum.

---

# 33. Default Expense Categories

The initial Expense Categories are:

- كهرباء
- مياه
- منظفات
- صيانة
- مستلزمات
- نقل
- أخرى

These are seeded during database initialization.

The user can later manage them.

---

# 34. Expense Category Deactivation

Deactivating an Expense Category must update:

    is_active = false

It must not physically delete the category when historical Expenses reference it.

Historical Expenses remain associated with the same category.

---

# 35. Expense Data

Expenses are first-class transactional entities.

The Data Layer must support:

- Create Expense
- Edit Expense
- Load Expense
- List Expenses
- Filter Expenses by date
- Filter Expenses by category
- Query Expense totals
- Query Expense breakdown by category
- Observe Expense changes where required

Expenses are independent of Orders.

---

# 36. Expense Fields

The Expense persistence model must support:

- id
- amount
- expense_category_id
- custom_name
- date
- notes
- created_at
- updated_at

The exact column naming must remain aligned with:

    tables.md

---

# 37. Expense Amount

Expense amount must use integer minor units.

Example:

    150.50 EGP
        ↓
    15050 piastres

The Data Layer must not store Expense money using floating-point values.

---

# 38. Expense Category Requirement

Every Expense must reference an Expense Category.

The Data Layer must not allow:

    expense_category_id = null

unless the approved schema explicitly changes.

---

# 39. Expense `أخرى` Validation

When the selected Expense Category represents:

    أخرى

the Expense must contain:

    custom_name

Example:

    Category:
    أخرى

    Custom Name:
    إصلاح باب المحل

The Data Layer should persist the custom name as part of the Expense transaction.

The Domain/Application layer is responsible for the complete business validation.

---

# 40. Standard Expense Categories

For standard categories such as:

- كهرباء
- مياه
- منظفات
- صيانة
- مستلزمات
- نقل

custom_name is not required.

The user may still provide:

notes

when additional context is needed.

---

# 41. Expense Date

Expense date is a business date.

The Data Layer must preserve:

    expenses.date

without unintended timezone conversion.

Example:

    25 August 2026

must remain the same business date after:

    Local Save
        ↓
    Synchronization
        ↓
    Remote Persistence
        ↓
    Local Refresh

---

# 42. Expense Created/Updated Timestamps

The technical timestamps:

- created_at
- updated_at

are separate from:

- date

The Data Layer must not use:

created_at

as the Expense reporting date.

Financial reports use:

expenses.date

for Expense period filtering.

---

# 43. Expense Independence from Order

The Expense repository must not require:

- order_id
- customer_id
- payment_id

for normal Expense creation.

The relationship is:

    Expense
        ↓
    ExpenseCategory

Expense is an independent operating-cost transaction.

---

# 44. Expense Independence from Payment

The Expense repository must not reuse Payment persistence as a negative transaction.

Incorrect:

    Payment = -150 EGP

Correct:

    Expense = 150 EGP

Payment and Expense remain separate entities.

---

# 45. Expense Creation Transaction

Creating an Expense that requires synchronization should perform:

    Begin Transaction
        ↓
    Create Expense
        ↓
    Create SyncOperation
        ↓
    Commit

This guarantees:

    Expense exists locally
        +
    Sync Operation exists

or:

    Neither exists

---

# 46. Expense Update Transaction

Editing an Expense should update:

    Expense
        +
    Synchronization State

inside an appropriate local transaction.

The UI should immediately reflect the updated local value.

Remote synchronization happens afterward.

---

# 47. Expense Queries

The Data Layer should provide efficient local queries for:

- Expenses by date
- Expenses within date range
- Expenses by category
- Expenses within date range grouped by category
- Total Expenses for a period
- Expense count where needed

Queries should operate directly against the local database.

---

# 48. Financial Report Data

Financial Reports should be derived from local transactional data.

The Data Layer must provide the queries required to calculate:

- Total Sales
- Total Payments
- Total Operating Expenses
- Remaining Amount
- Discounts
- Payment Method totals
- Expense Category totals
- Net Profit

The Data Layer should not create a separate:

    financial_report

business table.

---

# 49. Net Profit

Net Profit is derived:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

The Data Layer should expose the underlying queries required to calculate this value.

It must not persist:

    net_profit

as an independent transactional field.

---

# 50. Total Operating Expenses

Total Operating Expenses are calculated from:

    SUM(expenses.amount)

for the selected business date range.

The filtering date is:

    expenses.date

not:

    expenses.created_at

---

# 51. Expense Breakdown

The Financial Report must support:

    Expense Category
        +
    Total Amount

Example:

    منظفات
        300 EGP

    كهرباء
        200 EGP

    صيانة
        150 EGP

The Data Layer should provide grouped queries rather than loading every Expense into memory when possible.

---

# 52. Dashboard Expense Data

The Dashboard may require:

- Today's Expenses
- Current-period Expenses
- Net Profit
- Financial summaries

These values must be queried from local transactional data.

A Dashboard request must not require a remote API request.

---

# 53. Quick Action: Add Expense

The Dashboard Quick Action:

    إضافة مصروف

must ultimately use the Expense repository/application operation.

The flow is:

    Quick Action
        ↓
    Expense Entry
        ↓
    Expense Repository
        ↓
    Local Database
        ↓
    Sync Queue

---

# 54. Repository API Style

Repository methods should be application-friendly.

Examples:

    createExpense(...)
    updateExpense(...)
    getExpenseById(...)
    watchExpenses(...)
    getExpensesByDateRange(...)
    getExpensesByCategory(...)
    getExpenseSummary(...)

Exact method names may be adjusted during implementation.

The important requirement is that SQL/Drift details remain inside the Data Layer.

---

# 55. Reactive Queries

Where the UI benefits from immediate updates, repositories should expose reactive streams/watchers.

Examples:

- Orders list
- Order details
- Payments for an Order
- Storage state
- Expense list
- Financial summaries
- Dashboard metrics

When a local database mutation occurs:

    Database Change
        ↓
    Reactive Query
        ↓
    UI Refresh

---

# 56. Local Search

Search should be implemented using local database queries.

The Data Layer should support the approved search requirements without loading the entire dataset into memory.

Required search areas include:

- Customers
- Orders
- Stored Items where applicable

Expense V1 does not require advanced full-text search.

---

# 57. Expense Search Scope

Expense management primarily supports:

- Date filtering
- Category filtering

Free-text search through:

- notes
- custom_name

is not a primary V1 requirement.

The Data Layer should not introduce full-text search infrastructure for Expenses unless a future requirement explicitly adds it.

---

# 58. Database Transactions

The Data Layer must use database transactions for multi-record operations.

Required examples include:

- Create Order + OrderItems
- Move OrderItem + StorageRecords
- Complete Order + StorageRecords
- Cancel Order + StorageRecords
- Bulk Storage
- Create Expense + SyncOperation
- Update Expense + SyncOperation
- Create ExpenseCategory + SyncOperation where applicable

---

# 59. Transaction Rollback

If a transaction fails:

    All local changes in that transaction
        ↓
    Rollback

The Data Layer must not leave partially persisted business state.

---

# 60. Synchronization Repository

The synchronization infrastructure should provide operations such as:

- Add SyncOperation
- Get Pending Operations
- Mark Processing
- Mark Completed
- Mark Failed
- Increment Retry Count
- Update Last Error
- Retrieve Entity Sync State where required

The exact API can evolve with the backend contract.

---

# 61. Sync Queue Persistence

Sync queue persistence belongs to the Data Layer.

The Domain layer should not directly manipulate:

    sync_operations

The Domain/Application layer requests a business operation.

The Data Layer handles:

    Business Data
        +
    SyncOperation

atomically.

---

# 62. Expense Synchronization

For a new Expense:

    Expense
        ↓
    SyncOperation
        entity_type = expense
        entity_id = Expense.id
        operation_type = create
        status = pending

For an update:

    entity_type = expense
    entity_id = Expense.id
    operation_type = update

---

# 63. Expense Category Synchronization

Expense Category changes should use:

    entity_type = expense_category

The same stable UUID must be used locally and remotely.

Deactivation is synchronized as:

    update

with:

    is_active = false

not as a destructive delete.

---

# 64. Synchronization Dependency

If a new Expense references a newly created Expense Category:

    ExpenseCategory
        ↓
    Expense

The synchronization process must ensure the Category is available remotely before the Expense is accepted if the backend requires foreign-key existence.

The local database may contain both records immediately.

---

# 65. Remote Synchronization and Local Reads

Remote synchronization must update the local database.

The UI should continue reading from the local database.

The preferred flow is:

    Remote API
        ↓
    Sync Worker
        ↓
    Local Database
        ↓
    Reactive Query
        ↓
    UI

The UI should not bypass the local repository architecture.

---

# 66. Remote Change Loop Prevention

Applying a remote change locally must not automatically enqueue the same change again.

The Data Layer must distinguish:

    Local User Change

from:

    Remote Synchronization Change

to prevent:

    Remote
        ↓
    Local
        ↓
    Sync
        ↓
    Remote
        ↓
    ...

loops.

---

# 67. Seed Initialization

The Data Layer is responsible for initial seed initialization.

Required initial master data includes:

- Item Types
- Item Definitions
- Services according to approved configuration
- Service compatibility
- Carpet Sizes
- Expense Categories
- Business Settings

Production must not seed:

- Customers
- Orders
- Payments
- Expenses
- StorageRecords

---

# 68. Idempotent Seed Initialization

Seed initialization must be idempotent.

Running initialization multiple times must not:

- Duplicate Expense Categories
- Duplicate Services
- Duplicate Item Types
- Duplicate Item Definitions
- Duplicate Carpet Sizes
- Reset user changes
- Reactivate intentionally deactivated records

---

# 69. Database Migrations

All schema changes must be handled through Drift migrations.

Migrations must preserve existing user data.

A migration must not silently:

- Delete historical transactions
- Change IDs
- Reset Expense Categories
- Remove Payments
- Remove Orders
- Remove StorageRecords

unless an explicitly approved destructive migration is required.

---

# 70. Data Layer and Historical Data

The Data Layer must preserve historical transaction values.

Examples:

OrderItem service price snapshot.

Order total.

Payment amount.

Expense amount.

Expense business date.

Carpet dimensions.

Changing current master data must not rewrite historical transaction values.

---

# 71. Master Data Lifecycle

Master data uses:

    is_active

where applicable.

The Data Layer must support:

    Active
        ↓
    Available for New Transactions

and:

    Inactive
        ↓
    Not Available for New Transactions
        +
    Historical References Preserved

---

# 72. Error Handling

The Data Layer should translate low-level persistence/network failures into application-appropriate errors.

Examples:

- Database failure
- Constraint violation
- Network unavailable
- Timeout
- Authentication failure
- Sync conflict
- Remote validation failure

The Presentation layer should not depend directly on raw SQLite/Drift exceptions.

---

# 73. Constraint Errors

Examples:

Duplicate Customer Phone.

Duplicate Order Number.

Duplicate Expense Category.

Invalid foreign key.

Multiple active StorageRecords.

The Data Layer should expose meaningful errors to the application layer.

---

# 74. Network Errors

Network errors must not cause valid local operations to fail when the operation is supported offline.

Example:

    Create Expense
        ↓
    Local Save = Success
        ↓
    Network = Unavailable

Result:

    Expense remains locally saved.

The synchronization operation remains pending.

---

# 75. Remote Validation Errors

If the backend rejects a synchronized operation:

The local business record must not automatically disappear.

The Data Layer should preserve:

- Local record
- Sync failure information

The application may surface the issue for resolution.

---

# 76. Data Layer and Business Logic

The Data Layer must not become the main location for complex business rules.

For example:

    Order Completion
    Payment Validation
    Expense `أخرى` requirement
    Service Compatibility
    Order Readiness

belong primarily to Domain/Application behavior.

The Data Layer enforces persistence-level integrity and executes the required transactions.

---

# 77. Data Layer and Database Constraints

The Data Layer must rely on database constraints for structural integrity.

Examples:

- Primary keys
- Foreign keys
- Unique values
- Positive amounts
- One active StorageRecord
- Unique Service/ItemType compatibility

The Data Layer must not bypass these constraints for convenience.

---

# 78. Data Layer and No Use Case Layer

The approved architecture does not introduce a dedicated Use Case layer.

Repositories and the existing Domain/Application structure should remain sufficient for V1.

Do not create:

    CreateExpenseUseCase
    CreateOrderUseCase
    RecordPaymentUseCase

as a mandatory architectural layer unless an explicit architecture decision changes this rule.

---

# 79. Data Layer and No Mapper Layer

The project does not require a dedicated generic Mapper layer.

Data transformations should remain simple and close to their actual responsibility.

A mapper may only be introduced if a concrete problem justifies it.

Do not create mappers merely because they are common in other architectures.

---

# 80. Drift Table Organization

Drift tables should be organized according to the approved database schema.

The implementation should keep table definitions understandable and aligned with:

- tables.md
- relationships.md
- constraints.md
- indexes.md

Do not create tables that are not documented.

---

# 81. Query Organization

Queries should be organized by business/data responsibility.

Examples:

Customer queries.

Order queries.

Payment queries.

Storage queries.

Expense queries.

Master-data queries.

Sync queries.

Avoid one giant database service containing every query in the application.

---

# 82. Expense Query Organization

Expense queries should cover:

    Create
    Update
    Find by ID
    Watch list
    Filter by Date
    Filter by Category
    Aggregate by Date Range
    Aggregate by Category

Financial aggregation queries should preferably be performed by SQLite rather than by loading all Expense rows into Dart memory.

---

# 83. Financial Aggregation

The Data Layer should use database aggregation where appropriate.

Example:

    SUM(expenses.amount)

and:

    GROUP BY expense_category_id

This is more efficient than:

    Load every Expense
        ↓
    Calculate totals in Dart

especially as the dataset grows.

---

# 84. Net Profit Query

The Data Layer may expose a financial summary query that returns:

    Total Sales
    Total Payments
    Total Expenses
    Remaining Amount
    Net Profit

The values remain derived.

No separate financial-summary table is required.

---

# 85. Financial Date Range

Financial report queries must use the correct business date for each transaction type.

Expenses:

    expenses.date

Payments:

    payments.paid_at

Orders:

    Approved Order/Sales reporting date

The Data Layer must not accidentally use:

    created_at

for every financial calculation.

---

# 86. Data Layer and Dashboard

Dashboard repositories should query the local database for:

- Recent Orders
- Ready Orders
- Expected Pickups
- Outstanding Payments
- Expenses
- Net Profit
- Other approved operational metrics

The Dashboard must remain responsive offline.

---

# 87. Data Layer and Quick Actions

Quick Actions are Presentation-level entry points.

They should call the appropriate application/repository operation.

Examples:

    إضافة طلب
        ↓
    Order Repository

    إضافة عميل
        ↓
    Customer Repository

    تسجيل دفعة
        ↓
    Payment Repository

    إضافة مصروف
        ↓
    Expense Repository

---

# 88. Data Layer and Settings

Settings-related repositories may manage:

- Business Settings
- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Storage Locations
- Expense Categories

These are configuration/master-data workflows.

---

# 89. Data Layer and Arabic UI

The Data Layer must not contain UI strings or presentation formatting.

Examples such as:

    "إضافة مصروف"
    "حفظ"
    "إلغاء"

belong to the Presentation/Localization layer.

The Data Layer stores business data, not UI labels.

---

# 90. Data Layer and Currency Formatting

The Data Layer stores monetary values in minor units.

It must not be responsible for displaying:

    150.00 ج.م

Formatting belongs to the Presentation layer.

The Data Layer returns the numeric financial value.

---

# 91. Data Layer and Date Formatting

The Data Layer stores date/time values according to the approved database representation.

It must not be responsible for formatting:

    25 أغسطس 2026

for UI display.

Formatting belongs to Presentation/Localization.

---

# 92. Data Layer Testing

The Data Layer should be tested for:

- CRUD operations
- Foreign-key integrity
- Transactions
- Pagination
- Search
- Filtering
- Financial aggregation
- Expense creation
- Expense category management
- Storage movement
- Payment history
- Synchronization queue persistence
- Migration behavior

---

# 93. Expense Data Tests

Required Expense persistence tests include:

1. Create valid Expense.
2. Reject zero Expense amount.
3. Reject negative Expense amount.
4. Require Expense Category.
5. Store Expense date correctly.
6. Store optional notes.
7. Store custom_name for `أخرى`.
8. Preserve custom_name after reload.
9. Filter Expenses by date.
10. Filter Expenses by category.
11. Calculate Expense totals correctly.
12. Group Expenses by category.
13. Update Expense.
14. Preserve Expense after sync failure.
15. Create SyncOperation atomically.
16. Prevent duplicate Expense Category names.

---

# 94. Storage Data Tests

Required Storage persistence tests include:

1. Store one OrderItem.
2. Move OrderItem.
3. Deactivate old StorageRecord.
4. Create new active StorageRecord.
5. Prevent multiple active StorageRecords.
6. Bulk store multiple OrderItems.
7. Filter by StorageLocation.
8. Preserve historical StorageRecords.
9. Complete Order and deactivate active StorageRecords.
10. Cancel Order and deactivate active StorageRecords.

---

# 95. Payment Data Tests

Required Payment persistence tests include:

1. Record Payment.
2. Support multiple Payments.
3. Preserve Payment history.
4. Calculate Payment total.
5. Calculate Remaining Amount.
6. Prevent invalid Payment amount.
7. Preserve Payment after synchronization retry.
8. Prevent duplicate Payment creation during sync retry.

---

# 96. Order Data Tests

Required Order persistence tests include:

1. Create Order.
2. Create Order with multiple OrderItems.
3. Preserve individual OrderItem identity.
4. Search Order.
5. Search by Customer.
6. Search by Order Number.
7. Paginate Orders.
8. Filter by status.
9. Filter by expected pickup date.
10. Preserve historical pricing.
11. Complete Order transaction.
12. Cancel Order transaction.

---

# 97. Migration Testing

Every database migration must be tested against:

- Existing data
- Existing Orders
- Existing Payments
- Existing Expenses
- Existing StorageRecords
- Existing master data
- Pending SyncOperations

The migration must not silently destroy business data.

---

# 98. AI Implementation Rules

AI coding tools implementing the Data Layer must:

1. Read all approved Product documentation.
2. Read Domain documentation.
3. Read Database documentation.
4. Follow the approved Architecture.
5. Use Drift + SQLite.
6. Preserve UUID identity.
7. Preserve historical transaction values.
8. Implement repositories according to approved responsibilities.
9. Keep local database as the operational source.
10. Support offline-first workflows.
11. Use transactions for multi-record operations.
12. Persist SyncOperations atomically.
13. Implement Expense and ExpenseCategory support.
14. Keep Expense independent from Orders and Payments.
15. Preserve Expense `custom_name`.
16. Preserve Expense business date.
17. Support financial aggregation.
18. Avoid storing derived Net Profit.
19. Avoid storing derived Remaining Amount.
20. Avoid unnecessary Use Cases.
21. Avoid unnecessary Mappers.
22. Avoid undocumented tables.
23. Avoid undocumented relationships.
24. Avoid undocumented indexes.
25. Avoid destructive historical deletion.
26. Preserve inactive master-data records.
27. Keep UI strings out of the Data Layer.
28. Keep UI formatting out of the Data Layer.
29. Follow synchronization strategy.
30. Do not silently change the database architecture.

---

# 99. Final Data Layer Structure

The approved conceptual Data Layer is:

    Data
    │
    ├── Database
    │   ├── Drift Tables
    │   ├── Queries
    │   ├── Transactions
    │   ├── Migrations
    │   └── Seed Initialization
    │
    ├── Repositories
    │   ├── Customer
    │   ├── Order
    │   ├── Payment
    │   ├── Storage
    │   ├── Item Type
    │   ├── Item Definition
    │   ├── Service
    │   ├── Carpet
    │   ├── Business Settings
    │   ├── Expense Category
    │   └── Expense
    │
    ├── Remote
    │   └── API
    │
    └── Synchronization
        ├── Sync Operations
        ├── Retry Handling
        ├── Remote Pull
        └── Local Push

---

# 100. Final Principle

The Data Layer must make the approved business model persistent, queryable, offline-capable, and synchronization-ready.

The most important V1 rules are:

    Local First
        +
    SQLite + Drift
        +
    Repository-based Access
        +
    Atomic Transactions
        +
    Stable UUID Identity
        +
    Historical Data Preservation
        +
    Query-driven Persistence
        +
    Offline Operation
        +
    Reliable Synchronization
        +
    Independent Expenses
        +
    Configurable Expense Categories
        +
    Derived Financial Reporting
        +
    Minimal Architecture
        +
    No Undocumented Schema Changes

The Data Layer must support the business without becoming the business itself.