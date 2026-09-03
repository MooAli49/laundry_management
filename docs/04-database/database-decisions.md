# Laundry Management System — Database Decisions

## 1. Purpose

This document records the approved database-specific decisions for the V1 Laundry Management System.

These decisions are implementation constraints, not suggestions.

Any future database change must be evaluated against this document and the other project source-of-truth documents.

---

## 2. Local Database

V1 uses:

    SQLite

SQLite is the local operational database.

The application must remain fully usable when there is no network connection.

---

## 3. Flutter Database Layer

V1 uses:

    Drift

Drift provides:

- Type-safe database access
- SQLite integration
- Reactive queries where useful
- Transactions
- Migration support
- Structured table definitions

The Domain layer must not depend directly on Drift.

---

## 4. Architecture Boundary

Database implementation belongs to the Data Layer.

The dependency direction is:

    Presentation
        ↓
    Application
        ↓
    Domain
        ↓
    Data

The Data Layer owns:

- Drift tables
- Database queries
- Repositories
- Local persistence
- Sync persistence
- Database migrations

The Domain layer owns business concepts and rules.

The database must not become the primary location for complex business workflows.

---

## 5. Primary Key Strategy

All major entities use stable UUID identifiers.

Examples:

    Customer.id
    Order.id
    OrderItem.id
    Payment.id
    Expense.id
    ExpenseCategory.id
    StorageRecord.id
    StorageLocation.id
    ItemType.id
    ItemDefinition.id
    Service.id

UUIDs are the logical identity of entities.

Human-readable identifiers are separate from entity IDs.

---

## 6. Order Number

The Order Number is a business-facing identifier.

It is separate from:

    Order.id

The Order Number must be unique.

The Order Number is displayed to users and used for order search.

The UUID remains the technical identity used by relationships and synchronization.

---

## 7. Money Representation

All persisted monetary values use integer minor units.

For EGP:

    100.50 ج.م
        ↓
    10050 piastres

The database must not use floating-point values for money.

This applies to:

- Order totals
- OrderItem prices
- Discounts
- Tax
- Delivery fees
- Payments
- Expenses

---

## 8. Currency

V1 supports only:

    EGP

Displayed as:

    ج.م

Currency is not a per-transaction selectable field.

The database does not require a currencies table in V1.

---

## 9. Historical Transaction Values

Transaction records must preserve the values that were actually used at the time of the transaction.

This means current configuration must never be used to reconstruct historical financial data.

Examples:

    Current Service Price
        ≠
    Historical OrderItem Price

    Current Delivery Fee Configuration
        ≠
    Historical Order Delivery Fee

    Current Expense Category Name
        ≠
    Historical Expense Category Name

---

## 10. Service Price Decision

Services contain current pricing configuration.

OrderItems contain the historical transaction-time price.

When an OrderItem is created:

    Current Service Pricing
        ↓
    Calculate Transaction Price
        ↓
    Store Price on OrderItem

After that, changing the Service price must not change the historical OrderItem price.

---

## 11. Manual Order Price Editing

V1 allows authorized Order editing to modify the stored transaction price where the approved UI permits it.

The system must not silently reset the price to the current Service price when an existing Order is opened.

The stored OrderItem price is the source of truth for that historical transaction.

---

## 12. Delivery Model

V1 supports two independent delivery directions.

The Order may request:

    Delivery to Laundry

and/or:

    Delivery to Customer

These are not mutually exclusive.

Both may be selected simultaneously.

The database therefore stores two independent request values.

Conceptually:

    delivery_to_laundry_requested

    delivery_to_customer_requested

---

## 13. Delivery Fees

Each delivery direction may have its own fee.

Conceptually:

    delivery_to_laundry_fee

    delivery_to_customer_fee

Both are stored in integer minor units.

The fee actually applied to an Order becomes historical Order data.

Changing future delivery pricing must not modify existing Orders.

---

## 14. No Delivery Entity in V1

V1 does not introduce a dedicated Delivery entity.

There is no:

    deliveries

table.

There is no:

    delivery_requests

table.

Delivery is currently an Order-level request and charge.

V1 does not include:

- Drivers
- Vehicles
- Routes
- Delivery assignment
- Delivery tracking
- Proof of delivery
- Delivery scheduling
- Delivery status management

---

## 15. Customer Relationship

Every Order belongs to exactly one Customer.

The relationship is:

    Customer 1:N Order

The foreign key is:

    orders.customer_id

The Customer cannot be physically deleted when historical Orders depend on it.

---

## 16. OrderItem Representation

Every physical laundry item receives its own OrderItem.

If a customer brings:

    5 Shirts

the application may allow entering quantity:

    5

but the persisted representation is:

    OrderItem 1
    OrderItem 2
    OrderItem 3
    OrderItem 4
    OrderItem 5

This is required because physical items can differ in:

- Storage location
- Item definition
- Notes
- Future identifiers
- Physical handling state

---

## 17. OrderItem Historical Information

An OrderItem must preserve the information required to identify and price the physical item historically.

Where applicable this includes:

- Item Type
- Item Definition
- Service
- Pricing Type
- Unit Price
- Total
- Carpet Size
- Carpet Dimensions
- Carpet Area

This information must remain available for:

- Order Details
- Invoice
- Storage
- Historical reporting

---

## 18. Item Type

Item Type is a core domain concept.

Examples include:

    Clothing
    Blankets
    Carpets
    Carpet Covers

Item Type is stored as master data.

It can be deactivated but should not be destructively deleted when historical OrderItems reference it.

---

## 19. Item Definition

Item Definitions provide more specific information when an Item Type requires it.

Relationship:

    ItemType 1:N ItemDefinition

An Item Definition can be deactivated.

Historical OrderItems must remain understandable if the current Item Definition is later renamed or deactivated.

---

## 20. Service and Item Type Compatibility

A Service may support multiple Item Types.

An Item Type may support multiple Services.

This is an N:M relationship represented through:

    service_item_types

Duplicate Service/Item Type combinations are not allowed.

---

## 21. Storage Location Compatibility

Storage Locations may support specific Item Types.

The relationship is:

    StorageLocation N:M ItemType

through:

    storage_location_item_types

Duplicate Storage Location/Item Type combinations are not allowed.

This relationship allows the Storage workflow to show locations appropriate for the selected Item Type.

---

## 22. Storage Assignment

Storage is assigned to the physical OrderItem.

A StorageRecord references:

    order_item_id

and:

    storage_location_id

Storage is not stored only at the Order level.

This is required because different physical items in the same Order may occupy different locations.

---

## 23. Active Storage Record

An OrderItem may have multiple historical StorageRecords.

However, only one may be active at a time.

Conceptually:

    OrderItem
        ↓
    StorageRecord A → inactive
    StorageRecord B → inactive
    StorageRecord C → active

This allows the system to preserve the current location without introducing a dedicated movement-history feature.

---

## 24. Storage Completion Behavior

When an Order becomes Completed:

    Active StorageRecords
        ↓
    inactive

When an Order becomes Cancelled:

    Active StorageRecords
        ↓
    inactive

The OrderItem itself remains stored as historical data.

---

## 25. Manual Status Reversal

If an Order is manually changed from Completed back to Processing:

    Previous StorageRecords
        ↓
    Remain inactive

The database must not automatically reactivate old storage assignments.

If the physical items are stored again, a new storage action creates the new active StorageRecord.

---

## 26. Order Status Values

V1 supports:

    processing
    ready
    completed
    cancelled

No additional status values should be added without an approved product/domain change.

The database stores the status.

The Application/Domain layer controls status transition rules.

---

## 27. Payment Model

Payment is an independent transaction associated with an Order.

Relationship:

    Order 1:N Payment

An Order can have:

    Zero payments
    One payment
    Multiple payments

Partial payments are supported.

Payment history must remain preserved.

---

## 28. Payment Independence

Payment is not Expense.

The relationships are:

    Payment
        ↓
    Order

and:

    Expense
        ↓
    ExpenseCategory

There is no direct relationship between Payment and Expense.

---

## 29. Remaining Amount

Remaining Amount is derived.

Conceptually:

    Order Total
        -
    Total Payments
        =
    Remaining Amount

It should not be maintained as an independent financial transaction.

The application/reporting layer may calculate it through database queries.

---

## 30. Expense Entity

V1 includes a first-class Expense entity.

Expense is an independent operational financial transaction.

An Expense is not:

    Order
    Payment
    OrderItem

An Expense does not require:

    order_id
    payment_id
    customer_id

---

## 31. Expense Fields

An Expense contains the concepts:

    id
    amount
    expense_category_id
    expense_category_name_snapshot
    expense_name
    expense_date
    notes
    created_at
    updated_at

The exact physical column names are defined in the table documentation.

---

## 32. Expense Amount

Expense amount is stored in integer minor units.

Example:

    150.00 ج.م
        ↓
    15000 piastres

Floating-point values must not be used.

---

## 33. Expense Date

Every Expense has:

    expense_date

This represents the actual business date of the expense.

It is different from:

    created_at

Example:

    Expense occurred:
        25 August

    User entered it:
        27 August

The Expense still belongs to:

    25 August

for financial reporting purposes.

---

## 34. Expense Category

Expense Categories are configurable master data.

Initial categories include:

    Electricity
    Water
    Cleaning Supplies
    Maintenance
    Supplies
    Transportation
    Other

The category list is manageable from Settings.

---

## 35. Expense Category Management

The system supports:

    Create Category
    Rename Category
    Activate Category
    Deactivate Category

Inactive categories are not available for new Expense creation.

Historical Expenses remain valid.

---

## 36. Other Expense Category

The:

    Other

category is a valid category.

When:

    Category = Other

the user must provide:

    Expense Name

Example:

    Category:
        Other

    Expense Name:
        Coffee for staff

The Expense Name is part of the historical transaction.

---

## 37. Expense Category Historical Snapshot

Each Expense stores the category name used at the time of creation.

Conceptually:

    expense_category_name_snapshot

This prevents historical reports from becoming ambiguous if the category is renamed later.

Example:

    Expense created:
        Category = Cleaning Supplies

Later:

    Category renamed:
        Cleaning Materials

The historical Expense still records:

    Cleaning Supplies

as its transaction-time category name.

---

## 38. Expense Category Deletion

Expense Categories must not be hard-deleted when historical Expenses reference them.

Preferred behavior:

    Active
        ↓
    Inactive

Historical Expenses continue referencing the category.

---

## 39. Expense and Financial Reporting

Expenses are included in the Financial Report.

The report can aggregate Expenses by:

    Day
    Week
    Month
    Custom Date Range

Expense period filtering uses:

    expense_date

not:

    created_at

---

## 40. Net Profit

Net Profit is an approved V1 financial metric.

It is derived.

Conceptually:

    Net Profit
        =
    Sales
        -
    Operating Expenses

Net Profit is not stored as a transaction.

There is no:

    net_profit

table.

There is no manually maintained:

    net_profit

column.

---

## 41. Net Profit Calculation

For a selected financial period:

    Sales for Period
        -
    Expenses for Period
        =
    Net Profit for Period

The calculation must use the same reporting-period rules defined for the Financial Report.

---

## 42. Financial Source of Truth

The main financial transactional sources are:

    orders
    payments
    expenses

The database must not create duplicate manually maintained financial totals.

Derived values should be calculated from transactional records.

---

## 43. Financial Historical Integrity

The following values must remain historically accurate:

    Order Total
    Order Discount
    Order Tax
    Delivery Fees
    OrderItem Prices
    Payment Amounts
    Expense Amounts
    Expense Category Snapshot

Changes to configuration must not rewrite these values.

---

## 44. Financial Reporting Dates

Different financial concepts use different dates.

Sales:

    Order creation/reporting date

Payments:

    Payment timestamp

Expenses:

    Expense Date

The database must preserve these independently.

A Financial Report must not silently replace the Expense Date with the Expense creation timestamp.

---

## 45. Invoice

V1 requires Order invoice/receipt presentation.

A dedicated invoice table is not required.

The invoice is generated from existing historical Order data.

The invoice must be able to display, where applicable:

- Order Number
- Customer
- Item Type
- Item Definition
- Carpet Size
- Carpet Dimensions
- Service
- Price
- Delivery Fees
- Discount
- Tax
- Total
- Payment Information
- Remaining Amount

The database must preserve the historical values required for this presentation.

---

## 46. Business Settings

BusinessSettings stores configurable business values required by V1.

Current configurable values include:

    Business Name
    Address
    Phone
    Logo Reference
    Invoice Footer Text
    Tax Enabled
    Tax Rate

The following remain fixed for V1:

    EGP
    Single Branch
    Arabic
    RTL

The following BusinessSettings values are optional and may remain unset:

    Address
    Phone
    Logo Reference
    Invoice Footer Text

No unnecessary configuration tables should be introduced.

---

## 47. Master Data Deactivation

The following master entities support active/inactive behavior:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

Deactivation prevents new usage where applicable.

Historical transactions remain valid.

---

## 48. Destructive Delete Policy

Historical business data should not be destructively deleted.

Examples:

    Customer
    Order
    OrderItem
    Payment
    Expense
    Service
    ItemType
    ItemDefinition
    CarpetSize
    StorageLocation
    ExpenseCategory

should remain available when historical references exist.

Orders use cancellation.

Master data uses deactivation.

---

## 49. Foreign Key Integrity

Foreign keys must preserve valid relationships.

Examples:

    orders.customer_id
        →
    customers.id

    order_items.order_id
        →
    orders.id

    order_items.item_type_id
        →
    item_types.id

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

    expenses.expense_category_id
        →
    expense_categories.id

The exact FK behavior is documented in:

    constraints.md

---

## 50. Unique Constraints

The database should enforce uniqueness for business identifiers and configuration combinations.

Important examples:

    Order Number
    Customer Phone
    Service Name
    Item Type Name
    Expense Category Name
    Storage Location Name

and junction combinations:

    Service + Item Type
    Storage Location + Item Type

The exact constraint definitions are documented in:

    constraints.md

---

## 51. Database Transactions

Operations that update multiple related records must use database transactions.

Examples:

    Create Order
        +
    Create OrderItems

    Complete Order
        +
    Deactivate StorageRecords

    Cancel Order
        +
    Deactivate StorageRecords

    Move OrderItem
        +
    Deactivate Previous StorageRecord
        +
    Create New StorageRecord

    Add Expense
        +
    Add Sync Operation

    Update Expense
        +
    Add Sync Operation

The operation must either fully succeed or fully fail.

---

## 52. Offline-first Decision

All normal V1 operations must work locally.

The application must not require network access to:

    Create Orders
    Edit Orders
    Record Payments
    Store Items
    Move Items
    Add Expenses
    Edit Expenses
    Manage Expense Categories
    Search
    Filter
    View Reports

Synchronization happens after local persistence.

---

## 53. Synchronization Identity

UUIDs must remain stable across synchronization.

Example:

    Expense Created Locally
        ↓
    Expense.id = UUID-A
        ↓
    Synchronize
        ↓
    Remote Expense
        ↓
    Same Logical ID = UUID-A

The system must not generate a new business identity during synchronization.

---

## 54. Sync Queue Decision

Local changes that require remote synchronization are recorded as synchronization operations.

Preferred sequence:

    Begin Database Transaction
        ↓
    Modify Business Entity
        ↓
    Create Sync Operation
        ↓
    Commit

This prevents local data from being saved without a corresponding synchronization record.

---

## 55. Expense Synchronization

Expenses are synchronizable business entities.

The same synchronization principles used for Orders and Payments apply to:

    Expense
    ExpenseCategory

An Expense created offline must remain usable locally and synchronize later.

---

## 56. Migration Strategy

Database schema changes must use explicit migrations.

A migration must preserve existing user data.

Schema changes must not silently reset the local database.

Any migration affecting financial or historical records requires additional care and testing.

---

## 57. Seed Data

Seed data is used only for approved initial/master configuration.

Seed data must not overwrite user-created or user-modified records.

Initial Expense Categories may be seeded.

Initial Services, Item Types, Storage Locations, and other master data may also be seeded according to:

    seed-data.md

---

## 58. No Premature Analytics Tables

V1 does not require dedicated analytics or reporting summary tables.

Examples of excluded structures:

    daily_sales_summary
    monthly_profit_summary
    expense_summary
    analytics_events

unless a later performance requirement explicitly justifies them.

Financial reports should initially query the transactional database directly.

---

## 59. No Profit Snapshot Table

Net Profit is derived.

The system must not create:

    profit_snapshots

or:

    profit_records

for V1.

If reporting performance later requires caching, that should be introduced as a separate documented technical decision.

---

## 60. No Expense Ledger Duplication

Expenses are already financial transactions.

The system does not require:

    expense_ledger

in addition to:

    expenses

The Expense table is the source of truth for operational expenses.

---

## 61. No Payment Duplication

Payments are stored once as Payment transactions.

The system must not maintain separate manually editable totals for:

    Cash
    Card
    Wallet
    Other

Payment method totals are derived from Payment records.

---

## 62. Query Strategy

The database should support direct efficient queries for:

    Order Lists
    Customer Search
    Storage Lists
    Payment History
    Expense Lists
    Expense Reports
    Financial Reports
    Dashboard
    Sync Queue

Queries should be designed first.

Indexes should then be selected to support those queries.

---

## 63. Pagination

Large collections use incremental loading.

The database must support efficient:

    LIMIT

and appropriate ordering/cursor strategies.

Initial candidates include:

    Orders
    Customers
    Payments
    Expenses
    Storage Items

The exact query implementation belongs to the Data Layer.

---

## 64. Search

Search must be local and fast enough for daily operation.

Important searchable Order fields include:

    Order Number
    Customer Name
    Customer Phone

Expense filtering/search includes:

    Expense Date
    Expense Category
    Expense Name

The database/index design must support the actual UI query patterns.

---

## 65. Storage Query

The Storage workflow must support:

    Items Requiring Storage

and:

    Current Storage

The database must be able to identify OrderItems without an active StorageRecord.

It must also support filtering by:

    Item Type
    Storage Location
    Order
    Other approved storage filters

without requiring a separate materialized storage list.

---

## 66. Item Type-aware Storage

Storage Location suggestions depend on the selected Item Type.

The relationship is:

    OrderItem
        ↓
    ItemType
        ↓
    StorageLocationItemType
        ↓
    Compatible StorageLocations

This relationship must remain in the database rather than being hard-coded into the UI.

---

## 67. Current Storage Source of Truth

The current physical location of an OrderItem is determined by its active StorageRecord.

The system must not maintain a second manually editable:

    current_storage_location_id

on OrderItem unless a future performance decision explicitly introduces it.

The active StorageRecord is the source of truth.

---

## 68. Historical Storage

StorageRecords remain historical operational data.

When an item moves:

    Previous StorageRecord
        ↓
    inactive

    New StorageRecord
        ↓
    active

The previous location remains preserved.

This is enough for V1 without introducing a separate movement-history entity.

---

## 69. Order Completion and Storage

Completion closes the current storage state.

When:

    Order.status = completed

all active StorageRecords belonging to the Order's items become inactive.

The database operation should be atomic.

---

## 70. Order Cancellation and Storage

Cancellation also closes current storage.

When:

    Order.status = cancelled

all active StorageRecords belonging to the Order's items become inactive.

Historical storage records remain preserved.

---

## 71. Manual Status Changes

The application may allow manual status correction.

The database must permit valid status updates.

However, automatic side effects must be handled by the Application/Domain layer.

The database must not contain hidden logic that reactivates storage merely because a status value changed.

---

## 72. Referential Integrity and Deactivation

Deactivation does not remove foreign key relationships.

Example:

    Expense Category
        is_active = false

Existing:

    Expense
        expense_category_id
        ↓
    remains valid

This principle applies to all master data.

---

## 73. Database Simplicity

Every table must have a clear reason to exist.

Avoid creating tables for:

- Future features
- Generic abstractions
- Speculative requirements
- Analytics not required by V1
- Delivery management
- Employee management
- Permissions
- Loyalty
- Refunds
- AI
- Advanced inventory
- Processing stages

Approved V1 additions are:

    Expenses
    Expense Categories
    Net Profit as a derived financial metric
    Independent Delivery directions
    Item Type-aware Storage relationships

---

## 74. V1 Non-Goals

The following are explicitly outside the database scope:

    Drivers
    Vehicles
    Delivery Routes
    Employee Management
    Roles
    Permissions
    Multiple Branches
    Refund Workflow
    Loyalty Program
    AI Assistant
    Advanced Inventory
    Processing Stage Tracking
    Storage Capacity Management
    Barcode Workflow
    Advanced Analytics

No tables should be introduced for these features in V1.

---

## 75. Documentation Consistency

The following documents must remain consistent:

    requirements.md
    scope.md
    domain-model.md
    entities.md
    architecture.md
    data-layer.md
    sync-strategy.md
    tables.md
    relationships.md
    indexes.md
    constraints.md
    seed-data.md
    database-overview.md
    database-decisions.md

A database change that affects business behavior must also update the relevant product/domain documentation.

---

## 76. AI Implementation Constraint

AI coding tools must treat this document as an implementation constraint.

The AI must not:

- Invent new tables
- Invent new entities
- Change UUID strategy
- Change money representation
- Add Delivery entities
- Add Profit tables
- Add Expense Ledger tables
- Add Analytics tables
- Add unsupported statuses
- Add unrelated relationships
- Remove historical transaction values
- Replace Expenses with Payments
- Make delivery directions mutually exclusive

If an implementation requirement is unclear, the documentation must be reviewed before inventing behavior.

---

## 77. Final Approved Decisions

The V1 database decisions are:

    SQLite
    +
    Drift
    +
    UUID identifiers
    +
    Integer minor-unit money
    +
    EGP only
    +
    Offline-first
    +
    Synchronization-ready
    +
    Historical transaction preservation
    +
    Active/Inactive master data
    +
    Relational foreign keys
    +
    Transactional multi-record operations
    +
    Physical OrderItems
    +
    Item Type-aware Storage
    +
    Independent Delivery Directions
    +
    Historical Delivery Fees
    +
    Independent Expenses
    +
    Manageable Expense Categories
    +
    Historical Expense Category Snapshots
    +
    Expense Date-based reporting
    +
    Derived Net Profit
    +
    No dedicated Profit table
    +
    No dedicated Invoice table
    +
    No dedicated Delivery table
    +
    No destructive deletion of historical business data
    +
    No speculative V1 tables

---

## 78. Final Principle

The database must represent the approved business model accurately while remaining as simple as possible.

The priority order is:

    Data Integrity
        ↓
    Historical Accuracy
        ↓
    Financial Accuracy
        ↓
    Offline Reliability
        ↓
    Synchronization Safety
        ↓
    Operational Performance
        ↓
    Simplicity

Technical convenience must never override business correctness.