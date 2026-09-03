# Laundry Management System — Data Layer Implementation

## 1. Purpose

This document defines how the approved V1 Data Layer must be implemented in Flutter/Dart.

It translates the approved:

- Domain model
- Database design
- Database constraints
- Database relationships
- Database indexes
- Seed data
- Architecture
- Synchronization strategy
- Technical decisions

into concrete implementation guidance.

The purpose of this document is to prevent the implementation from inventing a different database architecture, repository structure, persistence strategy, or synchronization model.

This document is implementation guidance.

It does not replace the approved database documentation.

If this document conflicts with an approved Domain or Database decision, implementation must stop and the source documentation must be reviewed.

## 2. V1 Data Layer Strategy

The V1 Data Layer is:

SQLite
+
Drift
+
Repositories
+
Local-first Operations

The local database is the operational source of truth for V1.

The primary flow is:

Feature
↓
Cubit / Bloc
↓
Domain Repository Contract
↓
Data Repository Implementation
↓
Local Data Source / DAO
↓
Drift
↓
SQLite

The Data Layer must allow all approved V1 workflows to operate without network access.

Remote networking and synchronization infrastructure are prepared for later implementation but must not become a dependency of normal local workflows.

## 3. Approved Technologies

The V1 Data Layer uses:

- Drift
- SQLite
- get_it
- Dio
- Retrofit

Drift and SQLite are used for local persistence.

get_it is used for dependency injection.

Dio and Retrofit are reserved for the remote API boundary and later synchronization implementation.

Do not introduce another database technology.

Do not replace Drift with another ORM or persistence package.

Do not replace Dio or Retrofit without an approved technical decision.

## 4. Data Layer Responsibilities

The Data Layer is responsible for:

- Local persistence
- Database access
- Database queries
- Database transactions
- Repository implementations
- Data conversion where required
- Local search
- Filtering
- Pagination
- Financial aggregation queries
- Database migrations
- Seed initialization
- Persistence-level integrity
- Synchronization infrastructure
- Remote data access when the remote phase begins

The Data Layer is not responsible for:

- Screen rendering
- Navigation
- Widget state
- UI formatting
- UI localization
- Presentation-specific validation
- Complex business workflow decisions

## 5. Data Layer Structure

The conceptual structure is:

data/
├── database/
│   ├── app_database.dart
│   ├── tables/
│   ├── daos/
│   ├── migrations/
│   └── seed/
│
├── models/
│
├── local/
│   └── data_sources/
│
├── repositories/
│
├── remote/
│   ├── api/
│   ├── models/
│   └── data_sources/
│
└── synchronization/
    ├── sync_operations/
    ├── retry/
    ├── pull/
    └── push/

The exact directory naming may follow the final Project Structure document, but the responsibilities must remain equivalent.

## 6. Database Ownership

There must be one application database abstraction responsible for the Drift database.

Widgets must not instantiate the database.

Cubits must not instantiate the database.

Repositories must receive database/DAO dependencies through dependency injection.

The database lifecycle belongs to application infrastructure.

## 7. Drift Database

The central Drift database should:

- Register approved tables
- Register required DAOs
- Configure migrations
- Configure database initialization
- Expose database functionality to Data Layer components

The database must contain only documented tables.

Do not create undocumented tables for convenience.

## 8. Approved Tables

The Data Layer must implement the approved database schema.

The current approved logical tables include:

- customers
- orders
- order_items
- payments
- storage_locations
- storage_records
- item_types
- item_definitions
- services
- service_item_types
- storage_location_item_types
- carpet_sizes
- order_item_carpets
- expense_categories
- expenses
- business_settings
- sync_operations

The exact fields and constraints must come from the approved database table documentation.

Do not infer additional columns from UI requirements.

## 9. Table Implementation Rule

Every Drift table must correspond to an approved database table.

Before creating a table, verify:

- Table is documented
- Purpose is documented
- Relationships are documented
- Constraints are documented
- Index requirements are documented
- Domain entity or infrastructure requirement exists

If any of these are missing for a proposed new table, stop and request a documentation decision.

## 10. Primary Keys

Every approved business/infrastructure table has an id primary key.

The logical identifier is:

UUID

The SQLite/Drift representation is:

TEXT

IDs must:

- Be unique
- Be non-null
- Remain stable
- Not change during updates
- Remain stable across future synchronization

Do not use auto-increment integer IDs for business entities.

## 11. UUID Generation

UUID generation should happen at the application/data boundary before persistence.

A newly created business entity receives its UUID once.

The same UUID must be preserved when:

- Updating
- Reloading
- Synchronizing
- Retrying synchronization
- Mapping between layers

A retry must not create a new business identity.

## 12. Foreign Keys

The Data Layer must implement the approved foreign-key relationships.

Important relationships include:

orders.customer_id
→
customers.id

order_items.order_id
→
orders.id

order_items.item_type_id
→
item_types.id

order_items.item_definition_id
→
item_definitions.id

order_items.service_id
→
services.id

payments.order_id
→
orders.id

storage_records.order_item_id
→
order_items.id

storage_records.storage_location_id
→
storage_locations.id

item_definitions.item_type_id
→
item_types.id

service_item_types.service_id
→
services.id

service_item_types.item_type_id
→
item_types.id

storage_location_item_types.storage_location_id
→
storage_locations.id

storage_location_item_types.item_type_id
→
item_types.id

order_item_carpets.order_item_id
→
order_items.id

order_item_carpets.carpet_size_id
→
carpet_sizes.id

expenses.expense_category_id
→
expense_categories.id

## 13. Nullable Foreign Keys

The approved nullable foreign keys include:

order_items.item_definition_id

order_item_carpets.carpet_size_id

They are nullable because the corresponding Domain relationships are optional.

Do not make these relationships mandatory simply because the database implementation is easier that way.

Do not make other core relationships nullable without an approved decision.

## 14. Delete Behavior

The database must not use unrestricted cascade deletion for historical business data.

The implementation should prefer conservative delete behavior where deleting a parent could destroy historical records.

Examples:

Deleting a Customer must not silently delete:

- Orders
- OrderItems
- Payments

Deleting an Order must not silently destroy historical:

- OrderItems
- Payments

Normal V1 workflows should not depend on destructive deletion.

## 15. Historical Data Preservation

Historical transactional data must remain understandable after current master-data changes.

The Data Layer must preserve approved historical snapshots.

Important historical values include:

- OrderItem service name snapshot
- OrderItem item type name snapshot
- OrderItem item definition name snapshot
- OrderItem unit price
- OrderItem calculated total
- Carpet dimensions
- Expense category name snapshot
- Expense amount
- Expense date
- Payment amount

Changing current master data must not rewrite historical transaction values.

## 16. OrderItem Persistence

Each physical OrderItem must remain an independent database record.

Do not merge OrderItems because they share:

- Item Type
- Service
- Item Definition
- Pricing Type

Example:

Order
├── OrderItem 1
├── OrderItem 2
└── OrderItem 3

Each OrderItem has its own:

- UUID
- pricing data
- status-relevant data
- storage relationship
- historical information

The database must preserve this identity.

## 17. Order Persistence

Order creation must persist:

- Order record
- Related OrderItems
- Required related information
- Required synchronization operation when synchronization metadata is active

Creation of an Order with multiple OrderItems must be atomic.

If any required part fails:

The entire transaction must fail.

Do not leave an Order without its required OrderItems.

## 18. Order Transaction

The preferred flow is:

Begin Transaction
↓
Create Order
↓
Create OrderItems
↓
Create required related records
↓
Create SyncOperation when required
↓
Commit

If an error occurs:

Rollback

The UI should receive a meaningful application-level failure.

## 19. Order Search

The Data Layer must support local Order search.

Approved search concepts include:

- Order Number
- Customer Name
- Customer Phone

Search must execute against the local database.

Do not load every Order into Dart memory just to perform search.

Use the approved database indexes and query strategy.

## 20. Order Filtering

The Data Layer must support approved Order filters including:

- Status
- Expected Pickup Date
- Customer
- Other approved operational filters

Filtering should be performed at the database level whenever practical.

## 21. Order Pagination

Orders are expected to grow.

The Data Layer must support incremental loading.

Preferred flow:

Initial Batch
↓
User Reaches End
↓
Load Next Batch

The UI does not require traditional numbered pagination.

The repository should expose an application-friendly pagination API.

Do not expose SQL or Drift pagination details to Presentation.

## 22. Order Reactive Queries

Where the UI requires immediate updates, expose reactive repository queries.

Examples:

- Orders list
- Order details
- Orders by status
- Orders by expected pickup
- Customer order history

Preferred flow:

Database Change
↓
Drift Stream
↓
Repository
↓
Cubit / Bloc
↓
UI

## 23. Payment Persistence

Payments belong to Orders.

Every Payment must reference a valid Order.

The Data Layer must support:

- Creating Payments
- Reading Payment history
- Reading Payments for an Order
- Multiple Payments per Order
- Calculating Payment totals
- Calculating remaining amounts through approved queries/calculations

Payment history must not be destroyed during normal V1 operation.

## 24. Payment Transaction

A Payment creation operation must preserve:

- Payment UUID
- Order reference
- Amount
- Payment method
- Payment timestamp
- Required synchronization information

The exact fields must follow the approved database schema.

If synchronization metadata is required:

Begin Transaction
↓
Create Payment
↓
Create SyncOperation
↓
Commit

## 25. Payment Validation Boundary

The Data Layer must enforce persistence integrity.

The Domain/Application layer remains responsible for business validation such as:

Payment > Remaining Amount

The Data Layer must not be treated as the only business-rule layer.

Database constraints should still prevent structurally invalid values.

## 26. Payment Retry Safety

Synchronization retry must not create duplicate Payments.

The Payment UUID remains stable.

A synchronization retry must identify the same logical Payment rather than creating a new Payment.

## 27. Customer Persistence

The Customer repository must provide application-friendly operations such as:

- Create Customer
- Update Customer
- Get Customer by ID
- Search Customers
- Watch Customers
- Get Customer Order History where required

Customer search should support at least:

- Name
- Phone

The Data Layer must enforce approved uniqueness constraints such as Customer Phone.

## 28. Customer Deletion

Normal V1 workflows should not physically delete Customers when historical relationships would be affected.

A Customer referenced by Orders must remain historically valid.

If deletion behavior is not explicitly approved, do not implement destructive deletion.

## 29. Master Data

Master data includes:

- Item Types
- Item Definitions
- Services
- Service Item Types
- Carpet Sizes
- Storage Locations
- Expense Categories

Master data must use the approved lifecycle.

## 30. Master Data Deactivation

Master data that supports an active/inactive lifecycle should use:

is_active

Active:

Available for applicable new operations.

Inactive:

Not available for new applicable operations.

Historical references remain valid.

Do not physically delete referenced master data merely to hide it from selection lists.

## 31. Item Type Repository

The Item Type repository should support:

- Create
- Update
- Get by ID
- Watch/list
- Activate
- Deactivate
- Search where required

New Orders should normally use active Item Types.

Historical OrderItems must continue to reference their original values.

## 32. Item Definition Repository

The Item Definition repository should support:

- Create
- Update
- Get by ID
- List
- Activate
- Deactivate
- Filter by Item Type

Item Definition belongs to an Item Type.

The optional OrderItem relationship must remain nullable where approved.

## 33. Service Repository

The Service repository should support:

- Create
- Update
- Get by ID
- List
- Activate
- Deactivate
- Filter by applicable Item Type

Service compatibility must use the approved ServiceItemType relationship.

Do not hardcode service compatibility inside UI widgets.

## 34. Service Compatibility

ServiceItemType represents the approved relationship:

Service
+
Item Type

The Data Layer must enforce the approved uniqueness constraint.

Do not create duplicate ServiceItemType combinations.

The Data Layer should provide efficient queries for:

- Services available for an Item Type
- Item Types supported by a Service

## 35. Storage Location Repository

StorageLocation is master data.

The repository should support:

- Create
- Update
- List
- Activate
- Deactivate
- Filter by Item Type compatibility

Storage locations must not be treated as StorageRecords.

## 36. Storage Location Compatibility

StorageLocationItemType represents:

Storage Location
+
Item Type

The combination must be unique.

Only compatible locations should be offered for applicable new storage operations.

The Data Layer should provide efficient lookup by Item Type.

## 37. StorageRecord Persistence

StorageRecord represents an OrderItem's physical storage assignment.

It references:

- OrderItem
- StorageLocation

The Data Layer must preserve the distinction between:

StorageLocation
and
StorageRecord

A StorageRecord represents an assignment.

A StorageLocation represents a destination/master-data concept.

## 38. Active StorageRecord Rule

At most one active StorageRecord may exist for an OrderItem.

The Data Layer must preserve this invariant.

When moving an OrderItem:

Begin Transaction
↓
Deactivate Current StorageRecord
↓
Create New StorageRecord
↓
Create SyncOperation when required
↓
Commit

The operation must be atomic.

## 39. Storage Movement

Moving an OrderItem must not simply overwrite history if historical StorageRecords need to remain understandable.

The previous StorageRecord should be deactivated.

The new StorageRecord becomes active.

Historical StorageRecord information must remain available according to the approved database design.

## 40. Bulk Storage

Bulk storage operations must be transactional.

Preferred flow:

Begin Transaction
↓
For each OrderItem:
    Validate/prepare storage assignment
    Deactivate previous active record if applicable
    Create new StorageRecord
↓
Create required synchronization records
↓
Commit

If the approved workflow requires all selected items to succeed together, any failure must roll back the transaction.

## 41. Order Completion and Storage

Completing an Order may require deactivating active StorageRecords according to the approved business rules.

The operation should be atomic when it modifies:

- Order
- StorageRecords

Preferred conceptual flow:

Begin Transaction
↓
Update Order
↓
Deactivate relevant StorageRecords
↓
Create SyncOperation when required
↓
Commit

## 42. Order Cancellation and Storage

Cancelling an Order may require deactivating active StorageRecords according to the approved business rules.

The operation must preserve historical information.

Do not delete StorageRecords simply because an Order is cancelled.

## 43. Carpet Persistence

Carpet-specific information belongs to the approved carpet data structure.

OrderItemCarpet references:

- OrderItem
- CarpetSize where applicable
- Length
- Width
- Area

Historical carpet dimensions must remain stable.

Do not recalculate historical dimensions from current CarpetSize master data after the transaction has been created.

## 44. Carpet Size Repository

CarpetSize is master data.

The repository should support:

- Create
- Update
- List
- Activate
- Deactivate

Current CarpetSize changes must not rewrite historical OrderItemCarpet information.

## 45. Expense Category Persistence

ExpenseCategory is approved V1 master data.

The repository should support:

- Create
- Update
- List
- Activate
- Deactivate
- Search where required

Expense Category names must respect the approved uniqueness rules.

Inactive categories remain available for historical references.

## 46. Expense Persistence

Expense is an independent financial transaction.

Expense must not be modeled as:

- Payment
- Order
- OrderItem

The Expense repository should support:

- Create
- Update
- Get by ID
- Watch list
- Filter by date
- Filter by category
- Aggregate by date range
- Aggregate by category

## 47. Expense Required Data

An Expense must preserve the approved information including:

- UUID
- Amount
- Expense Category reference
- Expense Category name snapshot
- Expense Name where applicable
- Expense business date
- Notes
- Creation timestamp
- Update timestamp

The exact field names and types must follow the database documentation.

## 48. Expense Custom Name

The Expense category:

أخرى

requires:

Expense Name

The custom name belongs to the Expense transaction.

It is not a separate master-data entity.

The Data Layer must persist the approved custom_name field where required.

The value must survive:

- Database reload
- Application restart
- Synchronization retry

## 49. Expense Amount

Expense amounts must be stored in integer minor units.

Example:

150.50 EGP
→
15050

Do not persist Expense amounts as double.

Do not perform authoritative financial calculations using floating-point persistence.

## 50. Expense Date

Expense business date must be stored separately from creation timestamp where required.

Financial reports must filter Expenses using:

expenses.date

not:

expenses.created_at

The Data Layer must preserve the business date exactly.

## 51. Expense Creation Transaction

Expense creation should follow:

Begin Transaction
↓
Create Expense
↓
Create SyncOperation when required
↓
Commit

If synchronization is unavailable:

Local Expense Save
↓
Success
↓
Pending SyncOperation

The Expense remains valid locally.

## 52. Expense Update Transaction

Expense updates should follow:

Begin Transaction
↓
Update Expense
↓
Create/Update required SyncOperation
↓
Commit

The local UI should immediately reflect the updated local value.

Remote synchronization happens afterward.

## 53. Expense Queries

The Data Layer should provide:

- Expenses by date
- Expenses within date range
- Expenses by category
- Expenses within date range grouped by category
- Total Expenses for a period
- Expense count where required

Queries should operate against SQLite.

Do not load every Expense into Dart memory when SQLite can perform the required aggregation efficiently.

## 54. Expense Aggregation

Use database aggregation for financial summaries.

Examples:

SUM(expenses.amount)

and:

GROUP BY expense_category_id

Prefer:

SQLite Aggregation
↓
Small Result
↓
Dart

over:

Load All Expenses
↓
Calculate Everything in Dart

## 55. Financial Report Data

The Data Layer must provide the queries required to derive:

- Total Sales
- Total Payments
- Total Operating Expenses
- Remaining Amount
- Discounts
- Payment Method Totals
- Expense Category Totals
- Net Profit

These are derived values.

Do not create a dedicated financial_report table for V1.

## 56. Net Profit

Net Profit is derived.

Conceptually:

Total Sales
-
Total Operating Expenses
=
Net Profit

Do not persist:

net_profit

as an independent transactional value.

The Data Layer should expose the underlying queries needed by the reporting layer.

## 57. Remaining Amount

Remaining Amount is derived from the approved Order total and Payment data.

Do not persist:

remaining_amount

as an independent authoritative transactional field.

The Data Layer should provide efficient queries required to calculate it.

## 58. Financial Date Rules

Financial queries must use the correct business date.

Expenses:

expenses.date

Payments:

payments.paid_at

Orders:

approved Order/Sales reporting date

Do not use:

created_at

for every financial metric simply because it is available.

## 59. Dashboard Data

The Dashboard must remain offline-capable.

The Data Layer should provide efficient local queries for approved metrics such as:

- Recent Orders
- Ready Orders
- Expected Pickups
- Outstanding Payments
- Expenses
- Net Profit
- Other approved operational metrics

The Dashboard must not require a remote API request.

## 60. Dashboard Query Design

Dashboard metrics should preferably be calculated using targeted database queries.

Avoid:

Load entire database
↓
Calculate dashboard in Dart

Prefer:

Targeted SQLite queries
↓
Small result set
↓
Dashboard repository
↓
Cubit
↓
UI

## 61. Quick Actions

Quick Actions are Presentation-level entry points.

They must call the appropriate application/repository operation.

Examples:

إضافة طلب
→
Order Repository

إضافة عميل
→
Customer Repository

تسجيل دفعة
→
Payment Repository

إضافة مصروف
→
Expense Repository

Quick Actions must not access the database directly.

## 62. Business Settings Persistence

BusinessSettings is configuration data.

The approved V1 fields are:

- id
- business_name
- tax_enabled
- tax_rate
- updated_at

Do not add removed or undocumented fields.

Do not reintroduce:

- address
- phone
- logoReference
- invoiceFooterText

unless the approved Domain/Database documentation is explicitly changed.

## 63. Single Business Settings Record

V1 assumes:

One Business
+
One Branch
+
One BusinessSettings Record

The Data Layer must prevent accidental creation of multiple active settings records.

The preferred approach is a fixed single record ID or another explicit single-row strategy.

Do not introduce multi-branch settings architecture.

## 64. Tax Persistence

BusinessSettings stores:

tax_enabled
tax_rate

When tax is disabled:

Effective Order tax
=
0

Historical Order tax must remain unchanged after future BusinessSettings changes.

Do not recalculate historical Order values using the current tax rate.

## 65. Seed Data

Seed data is used only for approved initial/master configuration.

Seed initialization may include approved:

- Expense Categories
- Services
- Item Types
- Item Definitions
- Storage Locations
- Carpet Sizes
- Other documented master data

Seed data must not overwrite:

- User-created records
- User-modified records
- Historical transactions

## 66. Seed Initialization

Seed initialization should run only when appropriate.

The implementation must distinguish between:

Initial Database Creation
and
Existing Database

Do not blindly insert seed records every time the application starts.

Use stable identifiers or approved uniqueness rules to prevent duplicates.

## 67. Database Migrations

All schema changes must use Drift migrations.

Migrations must preserve existing data.

A migration must not silently:

- Delete historical transactions
- Change IDs
- Remove Payments
- Remove Orders
- Remove StorageRecords
- Reset Expense Categories
- Reset user configuration

unless a destructive migration is explicitly approved.

## 68. Migration Discipline

Before implementing a schema migration:

1. Identify the old schema.
2. Identify the new schema.
3. Identify affected data.
4. Define the migration steps.
5. Preserve historical data.
6. Update database documentation.
7. Add migration tests.
8. Verify existing data remains valid.

Do not use destructive database recreation as a shortcut.

## 69. Migration Testing

Migration tests must include:

- Existing Customers
- Existing Orders
- Existing OrderItems
- Existing Payments
- Existing Expenses
- Existing StorageRecords
- Existing master data
- Pending SyncOperations

The migrated database must remain structurally valid.

## 70. Indexes

Indexes must follow the approved index documentation.

Indexes should support actual:

- Search
- Filtering
- Sorting
- Joins
- Pagination
- Dashboard queries
- Financial reporting
- Storage workflows

Important indexed areas may include:

orders.customer_id
orders.status
orders.created_at
orders.expected_pickup_date
order_items.order_id
order_items.item_type_id
payments.order_id
payments.paid_at
storage_records.order_item_id
storage_records.storage_location_id
expenses.expense_category_id
expenses.date

Do not create indexes indiscriminately.

## 71. Query Organization

Queries should be organized by responsibility.

Examples:

Customer queries
Order queries
Payment queries
Storage queries
Expense queries
Master-data queries
Financial queries
Sync queries

Avoid one giant database service containing every query in the application.

## 72. DAO Responsibility

DAOs should focus on database access.

A DAO may provide:

- Insert
- Update
- Select
- Watch
- Filter
- Aggregate
- Delete/deactivate operations where approved
- Transaction support where appropriate

A DAO must not become the location for complex business workflows.

## 73. DAO Business Logic Boundary

Avoid implementing complex business rules inside DAOs.

Do not make a DAO responsible for deciding:

- Whether an Order can be completed
- Whether a Payment is allowed
- Whether an Expense custom name is required
- Whether a Service is compatible
- Whether an Order is ready

Those decisions belong to Domain/Application behavior.

The DAO persists and queries data.

## 74. Repository Responsibility

Repositories are the primary Data boundary exposed to the application.

Repositories are responsible for:

- Reading data
- Writing data
- Updating data
- Deactivating master data
- Local queries
- Transactions
- Mapping/conversion where necessary
- Coordinating local and remote sources later
- Returning Domain entities

Repositories are not responsible for:

- UI
- Navigation
- Screen layout
- Widget state
- Presentation formatting

## 75. Repository Contracts

Repository contracts belong to the Domain layer.

Repository implementations belong to the Data layer.

Conceptual structure:

Domain:
OrderRepository

Data:
OrderRepositoryImpl

The implementation must satisfy the Domain contract without leaking Drift types.

## 76. Repository API Style

Repository methods should be application-friendly.

Examples:

createCustomer(...)
updateCustomer(...)
getCustomerById(...)
watchCustomers(...)
searchCustomers(...)

createOrder(...)
getOrderById(...)
watchOrders(...)
searchOrders(...)
completeOrder(...)
cancelOrder(...)

recordPayment(...)
getPaymentsForOrder(...)
watchPayments(...)

storeOrderItem(...)
moveOrderItem(...)
watchStorage(...)

createExpense(...)
updateExpense(...)
getExpenseById(...)
watchExpenses(...)
getExpenseSummary(...)

Exact method names may be adjusted during implementation.

The important requirement is that SQL and Drift details remain inside Data.

## 77. Repository Return Types

Repositories should return Domain entities or approved application-level result types.

Do not expose:

- Drift generated row classes
- SQLite rows
- Dio Response objects
- Retrofit response models

to Presentation.

The Presentation layer should remain independent of persistence technology.

## 78. Mapping

A dedicated generic Mapper layer is not required.

Data transformation should remain close to the relevant boundary.

For example:

Database Row
↓
Domain Entity

or:

Remote Model
↓
Domain Entity

Create a dedicated mapper only when there is a concrete complexity or reuse reason.

Do not create mapper classes merely because another architecture uses them.

## 79. No Generic Repository

Do not create a generic repository such as:

GenericRepository<T>

merely to avoid writing feature-specific repository code.

Repositories represent business concepts.

Examples:

CustomerRepository
OrderRepository
PaymentRepository
ExpenseRepository
StorageRepository

Each repository should expose meaningful operations.

## 80. No Use Case Layer

The approved V1 architecture does not require a dedicated Use Case layer.

Do not automatically create:

CreateOrderUseCase
CreateExpenseUseCase
RecordPaymentUseCase

as an additional mandatory layer.

Repositories and existing Domain/Application responsibilities are sufficient unless the architecture is explicitly changed.

## 81. Local Data Sources

A local data source may be used when it improves separation between repository behavior and DAO/database implementation.

Conceptually:

Repository
↓
Local Data Source
↓
DAO
↓
Drift

The exact implementation can be simplified when a separate data source provides no meaningful value.

Do not introduce unnecessary abstraction.

## 82. Remote Data Sources

Remote data sources will use:

Dio
+
Retrofit

They belong to the remote Data Layer.

Remote clients must remain hidden from Presentation.

The remote implementation is not required for normal V1 local workflows.

## 83. Remote Implementation Deferral

The following are deferred until the synchronization/backend phase:

- Backend API implementation
- Remote authentication integration
- Remote synchronization execution
- Conflict resolution
- Background synchronization
- Advanced retry orchestration
- Remote pull implementation
- Remote push implementation

The local architecture must remain compatible with future synchronization.

## 84. Synchronization Infrastructure

The approved database includes synchronization infrastructure.

The conceptual structure includes:

sync_operations

and related synchronization state such as:

- Sync status
- Retry count
- Last sync attempt
- Last sync error

The exact schema must follow the approved database documentation.

## 85. Sync Operation Atomicity

When a local business operation requires synchronization:

Begin Transaction
↓
Modify Business Data
↓
Create SyncOperation
↓
Commit

Never intentionally create this inconsistent state:

Business Data Saved
+
No SyncOperation

when synchronization metadata is required.

## 86. Synchronization Identity

The same UUID must represent the same logical entity across synchronization.

Example:

Expense Created Locally
↓
Expense.id = UUID-A
↓
Sync
↓
Remote Expense
↓
Logical ID = UUID-A

A synchronization retry must not generate a new business identity.

## 87. Offline-First Error Behavior

If a valid local operation is supported offline:

Network unavailable
↓
Local operation continues

Example:

Create Expense
↓
Save locally
↓
Network unavailable
↓
Expense remains saved
↓
SyncOperation remains pending

Do not fail a valid local business operation merely because the network is unavailable.

## 88. Remote Validation Failure

If the backend later rejects a synchronization operation:

The local business record must not automatically disappear.

Preserve:

- Local record
- Sync failure information

The application may surface the problem for resolution.

Do not silently delete valid local business data because remote synchronization failed.

## 89. Error Translation

Low-level Data errors must be translated into application-appropriate errors.

Examples:

- Database failure
- Constraint violation
- Duplicate record
- Network unavailable
- Timeout
- Authentication failure
- Sync conflict
- Remote validation failure

Presentation must not depend directly on raw SQLite or Drift exceptions.

## 90. Constraint Error Handling

Examples of meaningful constraint errors include:

- Duplicate Customer Phone
- Duplicate Order Number
- Duplicate Expense Category
- Duplicate Service Name
- Duplicate Item Type Name
- Duplicate Storage Location Name
- Invalid Foreign Key
- Multiple active StorageRecords
- Duplicate Service/ItemType compatibility
- Duplicate StorageLocation/ItemType compatibility

The Data Layer should convert these into meaningful application-level failures where appropriate.

## 91. Database Constraints

The database should enforce structural integrity.

Examples:

- Primary keys
- Foreign keys
- Required fields
- Unique values
- Positive monetary values
- Valid constrained values
- One active StorageRecord per OrderItem
- Unique Service/ItemType combinations
- Unique StorageLocation/ItemType combinations

The Data Layer must not bypass these constraints.

## 92. Business Logic Boundary

The Data Layer must not become the main location for complex business rules.

Examples that belong primarily to Domain/Application behavior:

- Order completion
- Payment validation
- Expense custom-name requirement
- Service compatibility
- Order readiness
- Status transitions

The Data Layer enforces persistence integrity and performs required transactions.

## 93. Financial Query Efficiency

Financial aggregation should preferably execute inside SQLite.

Examples:

SUM
COUNT
GROUP BY
Date filtering
Category filtering

Avoid loading large transaction collections into Dart solely to calculate totals.

The repository should expose small financial summary results.

## 94. Reactive Queries

Use reactive queries where immediate UI updates are valuable.

Examples:

- Orders
- Order details
- Payments
- Storage
- Expenses
- Financial summaries
- Dashboard metrics

Preferred flow:

Local Mutation
↓
Drift Query Stream
↓
Repository
↓
Cubit
↓
UI

## 95. One-Time Queries

Use Futures for one-time operations.

Examples:

- Get Order by ID
- Get Customer by ID
- Create Expense
- Update Expense
- Record Payment

Do not convert every repository method into a stream.

## 96. Search Strategy

Search should be local.

Required search areas include:

Customers
Orders
Stored Items where applicable

Customer search:

- Name
- Phone

Order search:

- Order Number
- Customer Name
- Customer Phone

Expense filtering:

- Category
- Date
- Expense Name where applicable

Do not implement advanced full-text search for Expenses unless later approved.

## 97. Date Handling

The Data Layer stores machine-readable date/time values.

It must not format dates for UI.

Do not store:

25 أغسطس 2026

as the authoritative database representation.

Presentation handles formatting.

## 98. Currency Handling

The Data Layer stores monetary values in integer minor units.

Example:

150.00 EGP
→
15000

The Data Layer must not format:

150.00 ج.م

for UI display.

Presentation handles formatting.

## 99. Arabic UI Separation

The Data Layer must not contain UI strings.

Do not put strings such as:

إضافة مصروف
حفظ
إلغاء
جاهز
مكتمل

inside repository or DAO logic merely for presentation.

Data stores business values.

Localization belongs to Presentation/Core.

## 100. Master Data Historical References

Inactive master data must remain queryable when required for historical records.

For example:

Inactive Service
↓
Historical OrderItem
↓
Historical Service information remains understandable

Do not filter inactive master data out of historical joins when the historical record depends on it.

## 101. Deactivation Queries

For master data, repository methods should distinguish:

Active records for new transactions

from:

All records required for historical/reference display

Do not use a single generic query that accidentally hides historical references.

## 102. Transaction Boundary Design

Use transactions whenever multiple related records must change together.

Required examples include:

Create Order
+
Create OrderItems

Create Order
+
Apply Delivery Fees
+
Create OrderItems

Move OrderItem
+
Deactivate old StorageRecord
+
Create new StorageRecord

Complete Order
+
Deactivate StorageRecords

Cancel Order
+
Deactivate StorageRecords

Bulk Storage
+
Multiple StorageRecords

Create Expense
+
Create SyncOperation

Update Expense
+
Create SyncOperation

The operation should either fully succeed or fully fail.

## 103. Transaction Ownership

The transaction should be owned by the Data operation that requires atomicity.

Do not split one atomic business persistence operation across multiple unrelated repository calls when doing so could create partial state.

Where the workflow requires multiple writes, expose one repository operation representing that atomic persistence action.

## 104. Partial Failure Prevention

Avoid:

Create Order
↓
Success

Create OrderItems
↓
Failure

This creates invalid partial business data.

Instead:

Transaction
├── Create Order
├── Create OrderItems
└── Commit

## 105. Database Initialization

Application startup should initialize:

1. Configuration
2. Database
3. DAOs
4. Local Data Sources
5. Repository Implementations
6. Other approved dependencies
7. Application UI

Widgets must not perform database initialization.

## 106. Dependency Injection

Use get_it for centralized dependency registration.

Recommended registration order:

Configuration
↓
Database
↓
DAOs
↓
Local Data Sources
↓
Repositories
↓
Cubits / Blocs

Constructor injection is preferred after registration.

## 107. Database Testing

The Data Layer must be tested independently of the UI.

Tests should cover:

- CRUD
- Foreign-key integrity
- Constraints
- Transactions
- Pagination
- Search
- Filtering
- Aggregation
- Storage movement
- Payment history
- Expense persistence
- Migration behavior
- Synchronization queue persistence

## 108. Customer Data Tests

Customer persistence tests should cover:

1. Create Customer
2. Read Customer
3. Update Customer
4. Search by name
5. Search by phone
6. Prevent duplicate phone where required
7. Preserve Customer referenced by Orders
8. Reload Customer from database

## 109. Order Data Tests

Order persistence tests should cover:

1. Create Order
2. Create Order with multiple OrderItems
3. Preserve individual OrderItem identity
4. Search Order
5. Search by Customer
6. Search by Order Number
7. Paginate Orders
8. Filter by status
9. Filter by expected pickup date
10. Preserve historical pricing
11. Complete Order transaction
12. Cancel Order transaction

## 110. Payment Data Tests

Payment persistence tests should cover:

1. Record Payment
2. Support multiple Payments
3. Preserve Payment history
4. Calculate Payment total
5. Calculate Remaining Amount
6. Reject invalid Payment amounts
7. Preserve Payment after synchronization retry
8. Prevent duplicate Payment creation during synchronization retry

## 111. Storage Data Tests

Storage persistence tests should cover:

1. Store one OrderItem
2. Move OrderItem
3. Deactivate old StorageRecord
4. Create new active StorageRecord
5. Prevent multiple active StorageRecords
6. Bulk store multiple OrderItems
7. Filter by StorageLocation
8. Preserve historical StorageRecords
9. Complete Order and deactivate active StorageRecords
10. Cancel Order and deactivate active StorageRecords

## 112. Expense Data Tests

Expense persistence tests should cover:

1. Create valid Expense
2. Reject zero Expense amount
3. Reject negative Expense amount
4. Require Expense Category
5. Store Expense date correctly
6. Store optional notes
7. Store custom_name for أخرى
8. Preserve custom_name after reload
9. Filter Expenses by date
10. Filter Expenses by category
11. Calculate Expense totals correctly
12. Group Expenses by category
13. Update Expense
14. Preserve Expense after synchronization failure
15. Create SyncOperation atomically
16. Prevent duplicate Expense Category names

## 113. Master Data Tests

Master data tests should verify:

- Creation
- Update
- Activation
- Deactivation
- Uniqueness
- Compatibility
- Historical reference preservation

At minimum cover:

- Item Types
- Item Definitions
- Services
- Service Item Types
- Carpet Sizes
- Storage Locations
- Storage Location Item Types
- Expense Categories

## 114. Financial Query Tests

Financial tests should verify:

- Total Sales
- Total Payments
- Total Expenses
- Remaining Amount
- Discounts
- Payment Method totals
- Expense Category totals
- Net Profit

Test different date ranges.

Test empty periods.

Test periods containing multiple transaction types.

Verify correct business date usage.

## 115. Migration Tests

Every migration must be tested against existing data.

Test:

- Customers
- Orders
- OrderItems
- Payments
- Expenses
- StorageRecords
- Master data
- SyncOperations

Verify that historical data remains valid.

## 116. Synchronization Persistence Tests

Even before full synchronization execution is implemented, synchronization persistence infrastructure should be testable.

Verify:

- SyncOperation creation
- Stable entity UUID
- Pending state
- Retry count persistence where implemented
- Last error persistence where implemented
- No duplicate SyncOperation when the operation must remain idempotent

## 117. No Remote Dependency in V1

The following must work without API access:

- Create Orders
- Edit Orders
- Record Payments
- Store Items
- Move Items
- Add Expenses
- Edit Expenses
- Manage Expense Categories
- Search
- Filter
- Dashboard
- Reports
- Financial Reports

The Data Layer must not block these workflows because the network is unavailable.

## 118. No UI Dependency in Data

Data Layer code must not import or depend on:

- Widget
- BuildContext
- Navigator
- ThemeData for presentation formatting
- TextStyle
- UI localization

The Data Layer must remain independently testable.

## 119. No Domain Leakage

Data implementation classes may implement Domain interfaces.

They must not modify the approved Domain model simply to fit Drift.

If the persistence model differs from Domain representation:

Database Model
↓
Conversion
↓
Domain Entity

Do not contaminate Domain entities with unnecessary database annotations or infrastructure behavior.

## 120. No Database Leakage

Presentation must not know:

- Table names
- Column names
- SQL
- Drift companion objects
- Drift generated rows
- Database connections

The repository boundary hides persistence implementation.

## 121. No SQL in Features

Never place SQL or Drift queries inside:

- Screens
- Widgets
- Cubits
- Blocs

Database queries belong to the Data Layer.

## 122. No Network in Features

Never place Dio or Retrofit calls inside:

- Screens
- Widgets
- Cubits
- Blocs

The application interacts through repository/application boundaries.

## 123. Data Layer and Feature Boundaries

Feature code communicates with repositories.

Preferred:

Screen
↓
Cubit
↓
Repository
↓
Data

Not:

Screen
↓
DAO

or:

Cubit
↓
Database

or:

Cubit
↓
Dio

## 124. Reporting Repository

Reports may use dedicated repository methods or query services inside Data where this improves clarity.

The reporting implementation should query transactional data directly.

Do not create a persistent financial report table.

Do not duplicate transaction totals into reporting tables for V1.

## 125. Dashboard Repository

Dashboard data may use dedicated repository/query methods.

The Dashboard repository should query:

- Orders
- Payments
- Expenses
- Storage
- Other approved operational data

It should not maintain an independent Dashboard database.

## 126. Query Result Models

For complex read-only queries, the Data Layer may use dedicated result models when returning aggregated data.

Examples:

FinancialSummary
ExpenseCategorySummary
DashboardSummary

These are query/result representations.

They must not become persistent business entities unless explicitly approved.

## 127. Derived Data

Derived values should be calculated from authoritative transactional data.

Examples:

- Remaining Amount
- Net Profit
- Expense totals
- Payment totals
- Dashboard counts

Do not persist derived values as independent sources of truth unless explicitly approved.

## 128. Historical Snapshots

When the database design specifies a historical snapshot, the Data Layer must write the snapshot at transaction creation time.

Example:

Current Service Name
↓
OrderItem.service_name_snapshot

Later:

Service Name Changes
↓
Historical OrderItem remains unchanged

Do not populate historical snapshots dynamically from current master data.

## 129. Data Conversion

Conversion between Domain and persistence representations must preserve:

- UUID
- Monetary values
- Dates
- Enum values
- Optional relationships
- Historical snapshots
- Active/inactive state

Never silently lose fields during conversion.

## 130. Enum Persistence

Domain enums must be persisted using the approved stable representation.

Do not rely on enum ordinal position if doing so could make stored values unstable after enum changes.

The persisted representation must remain compatible with migrations and historical data.

The exact representation should follow the approved database design.

## 131. Boolean Persistence

Boolean fields such as:

is_active
tax_enabled

must use the approved Drift/SQLite representation consistently.

Do not implement inconsistent boolean conversions between tables.

## 132. Amount Constraints

Financial amount fields must respect approved positivity/non-negative constraints.

Examples include:

- Order amounts
- OrderItem prices
- Payment amounts
- Expense amounts
- Delivery fees where applicable

The exact constraint must follow the approved database documentation.

## 133. Constraint Duplication

It is acceptable for the application/domain layer to validate input before persistence.

But the database must remain the final structural integrity boundary.

Do not remove database constraints merely because the UI validates the same value.

## 134. Repository Error Mapping

Repository implementations should translate infrastructure failures into errors meaningful to the application.

Example:

SQLite constraint violation
↓
DuplicateCustomerPhoneError

rather than:

SQLiteException
↓
UI

The exact error types should follow the approved Error Handling document.

## 135. Data Layer Logging

Data Layer logging should be controlled.

Do not log:

- Passwords
- Tokens
- Secrets
- Sensitive customer information
- Payment-sensitive information

Logs should contain enough technical context to diagnose failures without exposing sensitive data.

## 136. Data Layer Performance

Performance-sensitive queries should execute close to the database.

Prefer:

SQLite query
↓
Filtered/aggregated result

over:

SQLite all rows
↓
Dart filtering
↓
Dart aggregation

Especially for:

- Orders
- Expenses
- Reports
- Dashboard metrics
- Storage lists

## 137. Query Reuse

Reuse queries where the business meaning is genuinely shared.

Do not create a giant generic query engine.

Queries should remain understandable and traceable to business requirements.

## 138. Data Layer Naming

Use clear names.

Examples:

CustomerDao
OrderDao
PaymentDao
StorageDao
ExpenseDao

CustomerRepositoryImpl
OrderRepositoryImpl
PaymentRepositoryImpl
ExpenseRepositoryImpl

AppDatabase

Do not use vague names such as:

DatabaseHelper
CommonRepository
DataManager
GeneralDao

unless there is a very specific documented responsibility.

## 139. Data Layer File Organization

Files should be grouped by responsibility.

Example:

data/
├── database/
│   ├── app_database.dart
│   ├── tables/
│   │   ├── customers_table.dart
│   │   ├── orders_table.dart
│   │   ├── order_items_table.dart
│   │   ├── payments_table.dart
│   │   ├── storage_locations_table.dart
│   │   ├── storage_records_table.dart
│   │   ├── item_types_table.dart
│   │   ├── item_definitions_table.dart
│   │   ├── services_table.dart
│   │   ├── service_item_types_table.dart
│   │   ├── storage_location_item_types_table.dart
│   │   ├── carpet_sizes_table.dart
│   │   ├── order_item_carpets_table.dart
│   │   ├── expense_categories_table.dart
│   │   ├── expenses_table.dart
│   │   ├── business_settings_table.dart
│   │   └── sync_operations_table.dart
│   └── daos/
│
├── repositories/
├── local/
├── remote/
└── synchronization/

The final file names may be adjusted according to the approved Project Structure.

## 140. Database Documentation Alignment

Before implementing any table, query, DAO, or migration, verify against:

- database-overview.md
- tables.md
- relationships.md
- constraints.md
- indexes.md
- seed-data.md
- database-decisions.md

Do not rely on memory when a concrete database definition already exists.

## 141. Domain Documentation Alignment

Before implementing a repository, verify:

- Entity
- Relationships
- Optional fields
- Business behavior
- Lifecycle
- Statuses
- Historical requirements

against the Domain documentation.

The Data Layer must persist the approved Domain model.

## 142. Architecture Alignment

The Data Layer must preserve:

Presentation
↓
Domain
↓
Data

Data may implement Domain contracts.

Domain must not import Data.

Presentation must not bypass Domain/Data boundaries.

## 143. Documentation Change Rule

If implementation reveals that the approved schema cannot support a required behavior:

Stop.

Do not silently modify the database.

Identify the issue.

Update the appropriate documentation after the decision is approved.

Then implement the approved change through a migration if required.

## 144. Schema Change Rule

Any change to:

- Table
- Column
- Relationship
- Constraint
- Index
- Identifier strategy
- Money representation
- Date representation

requires review of the affected database documentation.

A code change alone is not enough.

## 145. AI Data Layer Rules

AI coding agents implementing the Data Layer must:

1. Read Product documentation.
2. Read Domain documentation.
3. Read Architecture documentation.
4. Read Database documentation.
5. Read Implementation documentation.
6. Use SQLite + Drift.
7. Preserve UUID identity.
8. Preserve historical values.
9. Follow approved relationships.
10. Follow approved constraints.
11. Follow approved indexes.
12. Use transactions for multi-record operations.
13. Keep local database operational.
14. Keep normal workflows offline-capable.
15. Preserve Expense independence.
16. Preserve Expense custom_name.
17. Preserve Expense business date.
18. Preserve inactive master data.
19. Avoid undocumented tables.
20. Avoid undocumented fields.
21. Avoid undocumented relationships.
22. Avoid undocumented indexes.
23. Avoid destructive historical deletion.
24. Avoid unnecessary Use Cases.
25. Avoid unnecessary Mapper layers.
26. Keep UI strings out of Data.
27. Keep UI formatting out of Data.
28. Keep raw database errors out of Presentation.
29. Keep networking behind Data boundaries.
30. Do not silently change database architecture.

## 146. AI Stop Conditions

An AI coding agent must stop and request clarification when:

- A required table does not exist in documentation.
- A required field does not exist in documentation.
- A relationship conflicts with the approved model.
- A business rule conflicts with the Domain documentation.
- A migration could destroy historical data.
- A new package appears necessary for architecture.
- A new architectural layer appears necessary.
- A new synchronization behavior is required before its phase.
- The database and Domain model conflict.

Do not guess.

## 147. Implementation Completion Checklist

Before considering the Data Layer implementation complete, verify:

### Database

- All approved tables implemented
- Primary keys correct
- UUID strategy correct
- Foreign keys correct
- Nullable fields correct
- Constraints correct
- Indexes correct
- Delete behavior correct
- Migrations implemented
- Seed initialization implemented

### Repositories

- Domain contracts implemented
- Local operations supported
- Historical values preserved
- Master-data lifecycle supported
- Financial queries supported
- Storage workflows supported
- Payment workflows supported
- Expense workflows supported

### Transactions

- Order creation atomic
- Storage movement atomic
- Order completion atomic
- Order cancellation atomic
- Bulk storage atomic
- Expense + SyncOperation atomic
- Other multi-record operations atomic

### Offline

- Local operations work without network
- Search works offline
- Dashboard works offline
- Reports work offline
- Financial reports work offline

### Synchronization Readiness

- UUIDs stable
- SyncOperation persistence supported where required
- Local data remains valid when network unavailable
- Sync failures do not delete local business data

### Testing

- CRUD tested
- Constraints tested
- Relationships tested
- Transactions tested
- Search tested
- Pagination tested
- Aggregations tested
- Expense tested
- Storage tested
- Payment tested
- Order tested
- Migration tested

## 148. Final Data Layer Structure

The approved conceptual implementation is:

Data
│
├── Database
│   ├── Drift Tables
│   ├── DAOs
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

## 149. Final V1 Principle

The V1 Data Layer is local-first.

The local database is the operational source of truth.

SQLite + Drift provide persistence.

Repositories provide the application-facing data boundary.

Transactions protect multi-record operations.

UUIDs preserve stable identity.

Historical snapshots protect historical meaning.

Database constraints protect structural integrity.

Domain/Application logic protects business rules.

Synchronization is prepared for but not allowed to block local operation.

## 150. Final Rule

The Data Layer must make the approved business model:

Persistent
+
Queryable
+
Offline-capable
+
Historically safe
+
Transactionally consistent
+
Synchronization-ready

without becoming the business layer itself.

The implementation must follow the approved database and architecture documentation.

Do not invent schema.

Do not invent relationships.

Do not invent business rules.

Do not introduce unnecessary abstraction.

Do not bypass repositories.

Do not bypass database constraints.

Do not make network availability a requirement for local V1 workflows.

Do not destroy historical data for implementation convenience.

When implementation and documentation disagree:

Stop.

Review the source documentation.

Update the decision if necessary.

Then implement.

The database implementation must remain boring, predictable, explicit, and reliable.

That is the intended V1 Data Layer.