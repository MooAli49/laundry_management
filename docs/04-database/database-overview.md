# Laundry Management System — Database Overview

## 1. Document Purpose

This document defines the high-level database design principles for the V1 Laundry Management System.

It establishes the foundation that the remaining database documentation will follow.

This document is based on the approved:

- Product documentation
- Domain model
- Entity definitions
- Business rules
- Architecture
- Data Layer
- Synchronization strategy
- Technical decisions

The database is designed to support the project's main requirements:

- Offline-first operation
- Relational business data
- Historical data preservation
- Reliable storage management
- Payments
- Daily Expenses
- Financial Reporting
- Net Profit calculation
- Pagination
- Search
- Filtering
- Future synchronization
- Simple V1 implementation

The selected local database technology is:

    SQLite

The selected Flutter/Dart database layer is:

    Drift

---

## 2. Database Role

The local database is the primary operational source of truth while the application is running.

The application must be able to continue normal daily operations without an internet connection.

The database must therefore support local operations such as:

- Viewing customers
- Searching customers
- Creating customers
- Editing customers
- Viewing orders
- Searching orders
- Creating orders
- Editing orders
- Managing OrderItems
- Managing Storage
- Moving items
- Recording payments
- Recording expenses
- Managing Expense Categories
- Viewing Dashboard information
- Viewing Financial Reports
- Managing Services & Pricing
- Managing Settings

Remote synchronization happens separately from normal local operation.

---

## 3. Database Technology

The V1 local database stack is:

    Flutter
        ↓
    Drift
        ↓
    SQLite
        ↓
    Local Database

SQLite is responsible for persistent relational storage.

Drift provides the application-side database abstraction and type-safe access to SQLite.

Database-specific implementation details should remain inside the Data Layer.

The Domain layer must not depend directly on SQLite or Drift.

---

## 4. Relational Database Direction

The system uses a relational data model.

This is required because the business domain contains strong relationships between entities.

Examples:

    Customer
        ↓
    Order
        ↓
    OrderItem
        ↓
    StorageRecord

and:

    Order
        ↓
    Payment

and:

    Order
        ↓
    Expense
        ↓
    ExpenseCategory

and:

    ItemType
        ↓
    ItemDefinition

and:

    Service
        ↓
    ServiceItemType
        ↓
    ItemType

The database must preserve these relationships explicitly.

---

## 5. V1 Entity Categories

The database entities are divided into four main categories.

### Transactional Entities

    Customer
    Order
    OrderItem
    Payment
    StorageRecord
    Expense

These represent operational and historical business data.

### Master Data Entities

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

These represent configurable business data used by transactions.

### Configuration Entity

    BusinessSettings

This represents application/business configuration.

### Infrastructure Entities

    SyncOperation

Infrastructure entities support synchronization and application behavior but do not represent core business concepts.

---

## 6. Main Database Tables

The V1 logical database consists of the following main tables:

    customers
    orders
    order_items
    payments
    storage_records
    storage_locations
    item_types
    item_definitions
    services
    service_item_types
    carpet_sizes
    order_item_carpets
    expense_categories
    expenses
    storage_location_item_types
    business_settings

The synchronization mechanism may require additional internal tables such as:

    sync_operations

These infrastructure tables are part of the Data Layer and do not represent business entities.

---

## 7. Primary Key Strategy

Every main entity must have a stable unique identifier.

The approved conceptual identifier is:

    UUID

The internal ID must be separate from human-readable business identifiers.

For example:

    Order.id

and:

    Order.orderNumber

represent two different concepts.

The Order Number is for business/user interaction.

The UUID is for stable entity identity.

The same principle applies to:

    Customer
    Payment
    Expense
    StorageRecord
    ItemType
    Service
    ExpenseCategory

and other entities.

---

## 8. Stable IDs and Synchronization

Stable IDs are required because the application is Offline-first and must support synchronization.

An entity may be:

    Created Locally
        ↓
    Stored in SQLite
        ↓
    Added to Sync Queue
        ↓
    Synchronized Later

The entity must retain the same logical identity throughout this process.

The local database must not depend on auto-increment integer IDs as the only identity mechanism.

---

## 9. Common Metadata

Transactional and mutable entities should contain:

    id
    created_at
    updated_at

Where a specific business event requires its own timestamp, it should have a dedicated field.

Examples:

    completed_at
    cancelled_at
    paid_at

For Expenses:

    expense_date

represents the business date of the expense.

The Expense business date is separate from:

    created_at
    updated_at

This allows an expense to be recorded later while still belonging to the correct financial reporting date.

Event-specific timestamps must not be replaced by a generic updated timestamp.

---

## 10. Date and Time Handling

The database must distinguish between:

    Date Only

and:

    Date + Time

Expected Pickup is a Date Only value.

Therefore:

    expected_pickup_date

must not require a time component.

Expense Date is also a Date Only business value:

    expense_date

Other events such as:

    created_at
    updated_at
    completed_at
    cancelled_at
    paid_at

represent Date + Time values.

The exact physical SQLite/Drift representation is an implementation detail, but the business meaning must remain unchanged.

---

## 11. Currency and Money

V1 supports only:

    Egyptian Pound (EGP)

Displayed to users as:

    ج.م

Currency selection is not required.

Monetary values must use a precise integer-based representation.

The approved conceptual representation is:

    100.50 ج.م
        ↓
    10050 piastres

Therefore persisted monetary values must not use floating-point types such as double or REAL.

This applies to:

    Order amounts
    OrderItem prices
    Payment amounts
    Delivery fees
    Expense amounts
    Tax
    Discounts

All financial calculations must use the same minor-unit representation.

---

## 12. Nullability

Database columns should be nullable only when the business domain allows the value to be absent.

Nullability must not be introduced simply to make one table/model handle unrelated cases.

Examples:

    Order.expected_pickup_date
        → Required

    Customer.phone
        → Required

    Expense.expense_category_id
        → Required

    Expense.expense_name
        → Required only when the selected category is "Other"

    Order.cancellation_reason
        → Nullable

because a normal active Order has no cancellation reason.

Nullable fields should have a clear business meaning.

---

## 13. Required vs Optional Data

The database design must follow the Domain entity contracts.

Examples of required transactional values:

    Customer.name
    Customer.phone

    Order.customer_id
    Order.order_number
    Order.expected_pickup_date
    Order.status

    OrderItem.order_id
    OrderItem.item_type_id
    OrderItem.service_id

    Payment.order_id
    Payment.amount
    Payment.payment_method

    StorageRecord.order_item_id
    StorageRecord.storage_location_id

    Expense.amount
    Expense.expense_category_id
    Expense.expense_date

Optional values may include:

    Order.notes
    Order.cancellation_reason
    Order.cancelled_at
    Order.completed_at
    OrderItem.notes

    OrderItem.item_definition_id

    CarpetSize reference when custom carpet dimensions are used

    Expense.expense_name

Expense Name is conditional:

    Category != Other
        ↓
    expense_name may be null

    Category = Other
        ↓
    expense_name is required

The exact nullable fields are defined in the table-level documentation.

---

## 14. Historical Data Principle

Historical transactional data must remain stable.

Changes to current master data must not rewrite historical transactions.

Examples:

    Service Price Changes
        ↓
    Existing OrderItems
        ↓
    Historical Unit Price Remains Unchanged

and:

    Expense Category Name Changes
        ↓
    Existing Expenses
        ↓
    Historical Expense Information Remains Understandable

and:

    CarpetSize Changes
        ↓
    Existing OrderItem
        ↓
    Historical Dimensions Remain Unchanged

This is one of the most important database principles in the system.

---

## 15. Historical OrderItem Data

An OrderItem must preserve the information required to understand what was actually included in the historical order.

Historical information may include:

- Item Type name
- Item Definition name where applicable
- Service name
- Pricing Type
- Unit Price
- Calculated Total
- Carpet Length
- Carpet Width
- Carpet Area

Historical transaction values must not depend on the current state of master data.

This is particularly important because Services, Item Types, Item Definitions, and Carpet Sizes can be changed or deactivated over time.

---

## 16. Historical Expense Data

Expenses are historical financial transactions.

An Expense must preserve enough information to understand the expense at the time it was recorded.

Historical Expense information includes:

- Amount
- Expense Category reference
- Expense Category name snapshot
- Expense Name where applicable
- Expense Date
- Notes
- Creation timestamp
- Update timestamp

The historical category name should be preserved as a snapshot so that changing or renaming an Expense Category does not make old financial records ambiguous.

Expense amount must remain stored in integer minor units.

---

## 17. Master Data Deactivation

Master data that may be referenced by historical transactions should use active/inactive behavior.

The following entities use an active state:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

Conceptually:

    is_active = true
        ↓
    Available for applicable new operations

    is_active = false
        ↓
    Not available for new operations
    Historical references remain valid

Deactivation is preferred over destructive deletion.

---

## 18. Destructive Deletion

The system should avoid destructive deletion of records referenced by historical business data.

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

must not be physically deleted when doing so would break historical information.

Orders use cancellation rather than deletion.

Master data generally uses deactivation rather than deletion.

Expense Categories also use deactivation rather than deletion.

---

## 19. Customer and Order Relationship

Every Order belongs to exactly one Customer.

Relationship:

    Customer
        1
        │
        │
        N
        ↓
      Order

Database relationship:

    orders.customer_id
        →
    customers.id

An Order cannot exist without a valid Customer reference.

---

## 20. Order and OrderItem Relationship

Every Order contains one or more physical OrderItems.

Relationship:

    Order
        1
        │
        │
        N
        ↓
    OrderItem

Every physical item receives its own independent OrderItem ID.

For example:

    Customer brings 5 Shirts

The UI may allow:

    Quantity = 5

but the database represents:

    OrderItem 1
    OrderItem 2
    OrderItem 3
    OrderItem 4
    OrderItem 5

This is required because each physical item can have its own:

- Storage location
- Identifier
- Item Definition
- Notes
- Future barcode identifier

---

## 21. Order and Payment Relationship

An Order may have:

    Zero payments
    One payment
    Multiple payments

Relationship:

    Order
        1
        │
        │
        N
        ↓
    Payment

Partial payments are supported.

Payment history must remain preserved.

There is no V1 refund workflow.

---

## 22. OrderItem and Storage Relationship

Each physical OrderItem may have storage information.

Relationship:

    OrderItem
        1
        │
        │
        N
        ↓
    StorageRecord

However, at most one StorageRecord may be active for an OrderItem.

Conceptually:

    OrderItem
        ↓
    StorageRecord A → inactive
    StorageRecord B → active

is valid.

But:

    OrderItem
        ↓
    StorageRecord A → active
    StorageRecord B → active

is invalid.

V1 does not require a dedicated storage movement history feature.

---

## 23. Storage and Order Lifecycle

Current storage is represented by active StorageRecords.

Conceptually:

    storage_records.is_active = true

means:

    This OrderItem is currently physically stored.

When an Order becomes Completed:

    All related active StorageRecords
        ↓
    Become inactive

When an Order becomes Cancelled:

    All related active StorageRecords
        ↓
    Become inactive

OrderItems themselves remain preserved.

---

## 24. Manual Status Correction

If a Completed Order is manually changed back to Processing:

    Order.status
        ↓
    Processing

must not automatically reactivate previous StorageRecords.

The previous StorageRecords remain inactive.

If the physical items return to storage, the user must explicitly store them again.

The database design must preserve this distinction.

---

## 25. Order Status Values

V1 supports four Order statuses:

    processing
    ready
    completed
    cancelled

No additional operational statuses should be introduced without an approved requirement change.

Detailed status transition rules belong to the Domain/Application layer.

The database stores the status but should not become the sole owner of business workflow logic.

---

## 26. Ready State and Storage

An Order is Ready when all of its physical OrderItems have active StorageRecords.

Conceptually:

    Every OrderItem
        ↓
    Has active StorageRecord
        ↓
    Order can be Ready

An OrderItem without an active StorageRecord means that the item still requires storage.

This allows the database to support:

    Items Requiring Storage

and:

    Current Storage

through queries against StorageRecords.

Storage Location suggestions for a selected Item are determined using the Item Type compatibility configuration.

---

## 27. Order Completion

An Order cannot become Completed unless the required business conditions are satisfied.

The Domain/Application layer is responsible for validating:

- Order is Ready
- Remaining amount is zero
- Customer handover is confirmed

After successful completion:

    Order.status = completed

and:

    All active StorageRecords = inactive

The database should preserve:

    completed_at

as the completion timestamp.

---

## 28. Order Cancellation

Orders are not deleted as part of normal V1 operation.

Cancellation is used instead.

A cancelled Order:

- Remains in history
- Becomes read-only operationally
- Is not considered an active operational Order
- Has active StorageRecords deactivated
- Preserves existing payments

Cancellation information should include:

    cancelled_at
    cancellation_reason

---

## 29. Payment Data

Payments are historical financial transactions.

Each Payment belongs to exactly one Order.

A Payment must contain enough information to preserve:

- Amount
- Payment Method
- Payment Timestamp
- Related Order

Payment records must not be overwritten simply to maintain a current balance.

---

## 30. Remaining Amount

The conceptual calculation is:

    Order Total
        -
    Sum of Payments
        =
    Remaining Amount

Remaining Amount is a derived value.

It should not require a separate transactional table.

If a cached/stored value is introduced for performance, it must remain consistent with the underlying transaction data.

---

## 31. Payment Constraints

The database/application layer must preserve:

    Payment amount > 0

and:

    Payment amount <= Remaining Amount

The exact validation responsibility is shared.

### Domain/Application

Responsible for business validation.

### Database

Should enforce appropriate low-level data integrity constraints where practical.

---

## 32. Pricing and Historical Prices

Current Service pricing belongs to master data.

Historical OrderItem pricing belongs to the transaction.

Therefore:

    Current Service Price

must never be used to reconstruct:

    Historical OrderItem Price

An OrderItem must preserve its transaction-time pricing information.

This allows reports and historical orders to remain correct after Service price changes.

---

## 33. Item Types and Definitions

Item Types represent broad categories such as:

    Clothing
    Blankets
    Carpets
    Carpet Covers

Item Definitions represent applicable subtypes/definitions where required.

The relationship is:

    ItemType
        1
        │
        │
        N
        ↓
    ItemDefinition

Carpet Covers are operationally similar to Blankets and do not require a separate Cover Type system.

The database must not introduce unnecessary Cover Type tables.

---

## 34. Services and Item Types

A Service may support multiple Item Types.

An Item Type may be supported by multiple Services.

Therefore the relationship is:

    Service
        N
        │
        │
        N
        ↓
    ItemType

This is represented through:

    service_item_types

The junction table represents service compatibility.

---

## 35. Service Compatibility

An OrderItem's selected Service must support its Item Type.

The database stores the relationship.

The Domain/Application layer validates that the selected combination is valid.

The database should not allow the application to silently create invalid service/item combinations where the constraint can reasonably be enforced.

---

## 36. Carpet Data

Carpets have special pricing behavior based on area.

Carpet-specific data should be separated from normal OrderItem data.

Relationship:

    OrderItem
        0..1
        ↓
    OrderItemCarpet

The carpet-specific record may contain:

    length
    width
    area
    carpet_size_id

This avoids unnecessary carpet-specific nullable fields on every OrderItem.

---

## 37. Carpet Size

Common carpet sizes are managed separately.

Relationship:

    CarpetSize
        1
        │
        │
        N
        ↓
    OrderItemCarpet

Historical carpet measurements must remain stored directly with the historical OrderItem carpet data.

Changing or deactivating a CarpetSize must not alter historical measurements.

---

## 38. Custom Carpet Dimensions

The system supports:

    Predefined Carpet Size

or:

    Custom Length + Width

The calculated area is stored as part of the OrderItem's historical carpet data.

The system must not depend on the current CarpetSize definition to reconstruct an old carpet transaction.

---

## 39. Storage Locations

Storage locations are configurable master data.

Each StorageLocation contains at least:

    id
    name
    is_active
    created_at
    updated_at

Inactive StorageLocations must not be selectable for new storage assignments.

Historical StorageRecords referencing an inactive location must remain valid.

Storage locations can be associated with supported Item Types through:

    storage_location_item_types

This allows the application to show suitable locations based on the selected physical Item Type.

---

## 40. Storage Location / Item Type Compatibility

Storage locations may support specific Item Types.

The relationship is:

    StorageLocation
        N
        │
        │
        N
        ↓
    ItemType

The relationship is represented through:

    storage_location_item_types

This configuration allows the Storage workflow to dynamically show locations compatible with the currently selected Item Type.

For example:

    Selected Item Type = Carpet

may show:

    Carpet-01
    Carpet-02
    Carpet-03

while hiding locations that are not configured for Carpets.

The database must preserve this relationship independently from individual StorageRecords.

---

## 41. Business Settings

BusinessSettings represents limited configurable business information.

V1 includes:

    Business Name
    Address
    Phone
    Logo Reference
    Invoice Footer Text
    Tax Enabled
    Tax Rate

Address, Phone, Logo Reference, and Invoice Footer Text are optional business settings.

The following remain fixed:

    Egyptian Pound
    Single Branch
    Arabic Language
    RTL

The database must not introduce unnecessary configuration tables for fixed V1 behavior.

---

## 42. Delivery Data

V1 does not implement a delivery-management system.

However, an Order may contain two independent delivery requests.

The two delivery directions are separate because they represent different business operations.

### Delivery to Laundry

The customer may request that the items be delivered to the laundry.

Conceptually:

    delivery_to_laundry_requested

### Delivery to Customer

The customer may request that the finished items be delivered back to the customer.

Conceptually:

    delivery_to_customer_requested

Both options may be selected at the same time.

Therefore the database must not model delivery as a single mutually exclusive enum or single boolean.

Valid examples include:

    false + false
        →
    No delivery

    true + false
        →
    Delivery to Laundry only

    false + true
        →
    Delivery to Customer only

    true + true
        →
    Both delivery directions

Each selected delivery direction may have its own fee.

Conceptually:

    delivery_to_laundry_fee

    delivery_to_customer_fee

Both fees are stored as monetary minor units.

The delivery fee becomes part of the Order's historical financial calculation at the time the Order is created.

The database must preserve the actual fee applied to the Order rather than depending on future configuration values.

V1 does not include:

- Drivers
- Vehicles
- Routes
- Driver assignment
- Delivery tracking
- Delivery status
- Proof of delivery
- Delivery scheduling
- Delivery management workflows

Delivery in V1 is therefore an Order-level request and charge, not a logistics-management system.

---

## 43. Reports and Historical Data

Reports must use historical transactional values.

Examples:

    Historical OrderItem Price
    Historical Order Total
    Historical Discount
    Historical Tax
    Historical Delivery Fees
    Historical Payment Amount
    Historical Expense Amount
    Historical Expense Category Name

Reports must not calculate historical sales using current Service prices.

Payment reports must be based on the Payment transaction date when the report is specifically reporting payments.

Expense reports must be based on:

    expense_date

when the report is reporting expenses for a selected date or period.

---

## 44. Financial Report

The Financial Report aggregates financial information from transactional tables.

Primary sources include:

    orders
    payments
    expenses

The report may include:

    Total Sales
    Total Payments
    Total Expenses
    Outstanding Amounts
    Discounts
    Payment Methods
    Expenses by Category
    Net Profit

The exact presentation belongs to the UI/UX documentation.

The database must provide efficient queries for the required date ranges and grouping dimensions.

---

## 45. Expense Data

Expenses are independent operational financial transactions.

An Expense is not a Payment.

An Expense is not related to an Order.

Conceptually:

    Payment
        →
    Order

while:

    Expense
        →
    ExpenseCategory

Therefore:

    expenses

must not contain:

    order_id
    payment_id

unless a future approved requirement explicitly introduces such a relationship.

An Expense contains:

    amount
    expense_category_id
    expense_category_name_snapshot
    expense_name
    expense_date
    notes
    created_at
    updated_at

Expense amount is stored in integer minor units.

---

## 46. Expense Categories

Expense Categories are configurable master data.

Initial categories may include:

    Electricity
    Water
    Cleaning Supplies
    Maintenance
    Supplies
    Transportation
    Other

The category list must be manageable from Settings.

The system must support:

    Create Category
    Edit Category
    Activate Category
    Deactivate Category

Inactive categories must not be available for new Expenses.

Historical Expenses remain valid.

The special:

    Other

category requires an Expense Name.

Example:

    Category = Other
    Expense Name = "Coffee for staff"

The Expense Name is historical transaction data and must remain understandable even if the Category configuration changes later.

---

## 47. Expense and Expense Category Relationship

Every Expense belongs to exactly one Expense Category.

Relationship:

    ExpenseCategory
        1
        │
        │
        N
        ↓
      Expense

Database relationship:

    expenses.expense_category_id
        →
    expense_categories.id

The Expense Category name should also be stored as a historical snapshot on the Expense transaction.

This ensures that financial history remains understandable after category changes.

---

## 48. Expense Date

Every Expense has a business date:

    expense_date

This is a Date Only value.

Examples:

    25 August 2026
    26 August 2026
    27 August 2026

The Financial Report uses this field when filtering Expenses by:

    Day
    Week
    Month
    Custom Date Range

The creation timestamp:

    created_at

is not a replacement for:

    expense_date

because an Expense may be entered after the actual expense occurred.

---

## 49. Expense and Order Independence

Expenses are operational costs and are independent from customer Orders.

Example:

    Order #26-014
        └── Payment = 135 ج.م

and:

    Expense
        Category = Cleaning Supplies
        Amount = 150 ج.م

These records have no direct relationship.

The Financial Report may aggregate both, but the database must not create a direct relationship between them.

---

## 50. Net Profit

Net Profit is a derived financial metric.

Conceptually:

    Total Sales
        -
    Total Operating Expenses
        =
    Net Profit

Net Profit must not be stored as an independent transactional value.

The database should calculate it from historical transactional data.

For a selected reporting period:

    Sales for Period
        -
    Expenses for Period
        =
    Net Profit for Period

The exact definition of Total Sales and the selected reporting date basis must remain consistent with the approved Financial Report requirements.

No dedicated:

    net_profit

table is required.

No dedicated:

    net_profit

column is required.

---

## 51. Dashboard Queries

The database should support efficient queries for operational Dashboard information.

Examples:

    Orders Created Today
    Ready Orders
    Items Requiring Storage
    Outstanding Payments
    Overdue Orders
    Today's Expected Pickups
    Recent Orders
    Today's Sales
    Today's Payments
    Today's Expenses
    Current Net Profit

These values should preferably be calculated using database queries rather than loading the entire database into memory.

The Dashboard should not require a dedicated Dashboard table.

---

## 52. Search

The database must support local search.

Required Order search:

    Order Number
    Customer Name
    Customer Phone

Customer search should support at least:

    Customer Name
    Customer Phone

Expense search/filtering should primarily support:

    Expense Category
    Expense Date
    Expense Name where applicable

The exact search implementation is defined during the query/index design phase.

---

## 53. Pagination

Orders are expected to grow over time.

The database must support efficient incremental loading.

The UI does not require traditional numbered pages.

Preferred behavior:

    Initial Result Batch
        ↓
    User Reaches End
        ↓
    Load Next Batch

The same strategy may be applied to:

    Customers
    Payments
    Expenses
    Storage Lists

where the dataset size justifies it.

The exact pagination query strategy is defined in the table/index implementation.

---

## 54. Indexing Principle

Indexes should be created for fields frequently used in:

- Search
- Filtering
- Sorting
- Joins
- Pagination
- Dashboard queries
- Financial Reports
- Storage workflows

Important examples include:

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
    expenses.expense_date

The index design should be based on real application queries.

Indexes should not be created indiscriminately.

The exact index list is defined in:

    indexes.md

---

## 55. Foreign Keys

Foreign keys must preserve the main entity relationships.

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

Foreign key behavior must be defined explicitly before implementation.

---

## 56. Database Constraints

The database should enforce low-level integrity where practical.

Examples:

- Primary keys
- Foreign keys
- Required fields
- Unique Order Number
- Unique Customer Phone
- Unique Expense Category Name
- Unique Service Name
- Unique Item Type Name
- Unique Storage Location Name
- Positive monetary values
- Valid enum/constrained values
- One active StorageRecord per OrderItem
- Unique Service/Item Type compatibility
- Unique Storage Location/Item Type compatibility

Business workflows remain the responsibility of the Domain/Application layer.

---

## 57. Database Transactions

Transactions are required for operations that modify multiple related records.

Important examples:

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
    Update Order
        +
    Deactivate StorageRecords

    Cancel Order
        +
    Update Order
        +
    Deactivate StorageRecords

    Bulk Storage
        +
    Multiple StorageRecords

    Create Expense
        +
    Create Sync Operation

    Update Expense
        +
    Create Sync Operation

The goal is to prevent partially committed business operations.

---

## 58. Offline-first Database Behavior

The local database must be fully usable without network access.

The following operations must not require an API request:

    Create Order
    Add OrderItem
    Edit Order
    Change Order Status
    Store Item
    Move Item
    Record Payment
    Add Expense
    Edit Expense
    Manage Expense Categories
    Search Customers
    Search Orders
    View Dashboard
    View Reports
    View Financial Report

Remote synchronization happens afterward.

---

## 59. Synchronization Readiness

The database must support future synchronization.

Stable UUIDs are required.

The synchronization system may maintain additional infrastructure data such as:

    SyncOperation
    SyncStatus
    RetryCount
    LastSyncAttempt
    LastSyncError

These synchronization concepts belong to the Data Layer.

They should not unnecessarily become part of the Domain business entities.

Expenses and Expense Categories must be treated as synchronizable business data.

---

## 60. Sync Queue and Database Transactions

When a local business operation requires synchronization, the preferred flow is:

    Begin Transaction
        ↓
    Modify Business Data
        ↓
    Create Sync Operation
        ↓
    Commit

This prevents the situation where:

    Business Data Saved
        +
    No Sync Operation

The same transaction principle applies to:

    Order Creation

    Payment Creation

    Expense Creation

    Expense Category Changes

    Storage Changes

The exact implementation is defined by:

    sync-strategy.md

---

## 61. Database Simplicity

The database should remain as simple as possible while preserving business correctness.

Do not introduce tables solely for:

- Architectural fashion
- Future speculation
- Generic abstraction
- Premature analytics
- Features outside V1

Every table must have a clear business or infrastructure purpose.

Expenses and Expense Categories are exceptions to the previous database shape because they are now approved V1 business requirements.

---

## 62. V1 Database Non-Goals

The database must not introduce dedicated V1 business tables for:

    Drivers
    Vehicles
    Delivery Routes
    Employees
    Roles
    Permissions
    Branches
    Refunds
    Loyalty
    Storage Movement History
    Storage Capacity
    Laundry Processing Stages
    AI Assistant
    Barcode Workflow
    Advanced Analytics
    Predictive Analytics

Delivery remains an Order-level request and charge only.

No dedicated delivery-management tables should be created.

Expenses are not considered an out-of-scope feature.

They are an approved V1 financial transaction.

---

## 63. Database Documentation Structure

The database documentation defines:

    database-overview.md
        ↓
    tables.md
        ↓
    relationships.md
        ↓
    indexes.md
        ↓
    constraints.md
        ↓
    seed-data.md
        ↓
    database-decisions.md

This document defines the high-level principles.

The later documents define the concrete implementation details.

---

## 64. Source of Truth

The database design must remain consistent with:

    docs/01-product/

    docs/02-domain/

    docs/03-architecture/

    docs/04-database/

If a conflict appears between the database design and the Domain Model, implementation must stop and the relevant documentation must be reviewed.

The database must not silently change the business model for technical convenience.

---

## 65. AI Coding Tool Rules

AI coding tools must read the following before implementing the database:

    product documentation
    domain documentation
    architecture documentation
    data-layer.md
    sync-strategy.md
    technical-decisions.md
    database-overview.md

The AI must not invent:

- New business entities
- New relationships
- New statuses
- New V1 configuration
- New tables for excluded features
- Different ID strategies
- Different database technology
- Additional delivery workflows
- Additional Expense concepts

The AI must implement the approved:

    Expense

and:

    ExpenseCategory

concepts exactly as documented.

---

## 66. AI Database Implementation Rules

When implementing SQLite with Drift:

1. Follow the approved logical schema.
2. Preserve the Domain relationships.
3. Preserve historical transaction values.
4. Use stable UUID identifiers.
5. Use integer minor units for persisted monetary values.
6. Use database transactions for multi-record business operations.
7. Support local-first operation.
8. Support pagination and local search.
9. Preserve active/inactive behavior.
10. Avoid destructive deletion of historical data.
11. Do not add unnecessary abstractions.
12. Do not introduce Use Cases.
13. Do not introduce Mappers.
14. Do not create tables for excluded V1 features.
15. Do not silently modify the Domain Model.
16. Treat Expenses as independent financial transactions.
17. Treat Expense Categories as manageable master data.
18. Preserve both independent delivery request types.
19. Preserve historical delivery fees.
20. Preserve historical Expense Category names.
21. Calculate Net Profit from transactional data rather than storing it.

---

## 67. Database Change Rule

Any change to the database design must be evaluated against:

    Product Requirements
    Domain Model
    Entities
    Business Rules
    Architecture
    Synchronization Strategy

A new table, relationship, or important column should have a documented reason.

If the change affects business behavior, the relevant Domain documentation must be updated first.

Any schema change must also be reflected in:

    tables.md
    relationships.md
    indexes.md
    constraints.md

when applicable.

---

## 68. Financial Data Integrity

Financial transaction data must be treated as historical business records.

The database must preserve:

    Order Total
    Order Discount
    Order Tax
    Delivery Fees
    Payment Amounts
    Expense Amounts

Changing current configuration must not rewrite historical financial transactions.

Examples:

    Service Price Changed
        ↓
    Existing OrderItem Price Unchanged

    Expense Category Renamed
        ↓
    Existing Expense Amount Unchanged
    Historical Category Snapshot Preserved

    Delivery Fee Configuration Changed
        ↓
    Existing Order Delivery Fee Unchanged

This principle is required for accurate Financial Reports.

---

## 69. Financial Reporting Date Basis

Different financial transactions have different business dates.

Orders primarily use:

    created_at

for sales/reporting based on order creation unless another approved reporting basis is explicitly defined.

Payments use:

    paid_at

for payment reporting.

Expenses use:

    expense_date

for expense reporting.

The database must preserve these dates independently.

A report must not silently substitute:

    created_at

for:

    expense_date

when calculating Expenses for a selected period.

---

## 70. Financial Aggregation

Financial reports may aggregate:

    Orders
    Payments
    Expenses

The database must allow efficient aggregation over a selected period.

Conceptually:

    Sales
        ↓
    orders

    Payments
        ↓
    payments

    Expenses
        ↓
    expenses

The application/reporting layer is responsible for combining these values into the final financial presentation.

The database should not create a duplicated summary table for V1.

---

## 71. Expense Category Management

Expense Categories are managed from Settings.

The database must support:

    Create
    Rename
    Activate
    Deactivate

The system should prevent duplicate category names.

A category that has historical Expenses should not be hard-deleted.

Renaming a category affects the current master data.

Historical Expenses retain their historical category snapshot.

---

## 72. Order Delivery Fees

Delivery fees are part of the historical Order financial data.

The Order may contain:

    delivery_to_laundry_fee

and:

    delivery_to_customer_fee

Both values are stored as integer minor units.

The final Order total must include applicable delivery fees according to the approved Order calculation rules.

The database must not derive an old Order's delivery fee from current settings.

Both delivery directions may be selected simultaneously.

---

## 73. Delivery and Order Independence

Delivery is an attribute of the Order.

It is not an independent delivery-management entity in V1.

Therefore the database must not create:

    deliveries

or:

    delivery_requests

tables for V1.

The Order itself preserves:

    delivery_to_laundry_requested
    delivery_to_customer_requested
    delivery_to_laundry_fee
    delivery_to_customer_fee

This keeps the V1 database simple while preserving the required financial information.

---

## 74. Storage Item Type Dependency

Storage assignment is performed at the physical OrderItem level.

The Item Type determines which Storage Locations may be suggested.

The query concept is:

    OrderItem
        ↓
    ItemType
        ↓
    storage_location_item_types
        ↓
    StorageLocations

This allows the Storage UI to show only appropriate locations for the selected physical item.

The database must not store a single generic storage location list without Item Type compatibility.

---

## 75. Item Information Preservation

An OrderItem must preserve enough information to display the physical item correctly across:

    Order Details
    Invoice
    Storage
    Reports

This includes where applicable:

    Item Type
    Item Definition
    Carpet Size
    Carpet Dimensions
    Service
    Pricing Type
    Unit Price
    Calculated Total

Historical snapshot fields must be available where current master data may change.

The database must not require the current Item Type or Item Definition configuration to reconstruct historical Order information.

---

## 76. Invoice Support

V1 requires invoice/receipt presentation for Orders.

The database does not require a dedicated:

    invoices

table.

The invoice can be generated from:

    BusinessSettings
    Customer
    Order
    OrderItems
    Payments

The database must therefore preserve all historical information required for invoice rendering.

For applicable items, the invoice must be able to display:

    Item Type
    Item Definition
    Carpet Size / Dimensions
    Service
    Quantity / physical item representation
    Price
    Total

The invoice must use transaction-time values.

---

## 77. Database and Manual Order Editing

The database must support approved manual Order editing.

Examples include:

    Changing Order Status

    Editing Order Item price

    Editing Order Item details

    Updating Order notes

    Updating Delivery options

When a historical Order is intentionally edited, the application must explicitly update the affected transactional values.

The database must not automatically recalculate historical values from current master data.

Manual editing is an explicit business action.

---

## 78. Order Price Editing

OrderItem pricing is stored as transaction-time data.

The database therefore supports manual editing of:

    unit_price

and:

    calculated_total

when the approved Order editing workflow permits it.

The current Service price is not automatically reapplied when opening an existing Order.

This ensures that editing an Order is an explicit action rather than an unintended side effect.

---

## 79. Current vs Historical Master Data

The database contains both:

    Current Master Data

and:

    Historical Transaction Data

Current master data includes:

    Services
    Item Types
    Item Definitions
    Carpet Sizes
    Storage Locations
    Expense Categories

Historical transaction data includes:

    Orders
    OrderItems
    Payments
    Expenses
    Storage Records

The two concepts must remain distinct.

Historical records must not be rewritten simply because master data changes.

---

## 80. Query-First Design

Database queries should be designed before adding indexes or optimization structures.

The implementation should identify:

    Query
        ↓
    WHERE
        ↓
    JOIN
        ↓
    ORDER BY
        ↓
    LIMIT

and then select the appropriate index strategy.

This is particularly important for:

    Orders
    Storage
    Payments
    Expenses
    Financial Reports
    Dashboard
    Synchronization

---

## 81. SQLite Query Plan Validation

During implementation, important queries should be validated using SQLite query planning tools where practical.

The goal is to confirm that indexes are actually being used for:

    Customer Search

    Order Lists

    Storage Queries

    Payment History

    Expense Reports

    Dashboard Queries

    Synchronization Queue

Index presence alone does not guarantee optimal query performance.

---

## 82. Indexes and Write Cost

Indexes improve read performance but increase:

    Insert Cost

    Update Cost

    Storage Size

This is particularly relevant for:

    orders
    order_items
    payments
    storage_records
    expenses
    sync_operations

Therefore V1 should keep the index set targeted and avoid speculative indexes.

---

## 83. Offline-first Financial Operations

The following financial operations must work locally:

    Create Order
    Edit Order
    Record Payment
    Add Expense
    Edit Expense
    Manage Expense Categories
    View Financial Report
    View Net Profit

The user must not be blocked from recording an Expense because the network is unavailable.

The Expense must be stored locally first and synchronized later.

---

## 84. Synchronization and Historical Transactions

Synchronization must preserve transaction identity and historical values.

For example:

    Expense Created Offline
        ↓
    Expense Stored Locally
        ↓
    Sync Operation Created
        ↓
    Network Becomes Available
        ↓
    Expense Synchronized

The Expense ID must remain unchanged.

The same applies to:

    Orders
    Payments
    StorageRecords
    ExpenseCategories

---

## 85. Data Integrity Over Convenience

The database must prioritize:

    Historical Accuracy
        +
    Referential Integrity
        +
    Financial Accuracy
        +
    Physical Storage Accuracy

over convenience shortcuts.

Examples of invalid shortcuts:

    Reconstructing old prices from current Services

    Reconstructing old Expense Category names from current Categories

    Reconstructing old Delivery Fees from current configuration

    Storing one storage location on the Order instead of each physical OrderItem

    Storing Net Profit as a manually maintained value

---

## 86. No Duplicate Financial Source of Truth

The database must avoid storing the same financial fact in multiple independent places unless the duplication is explicitly a historical snapshot.

Examples:

    Payment amount
        →
    payments.amount

    Expense amount
        →
    expenses.amount

    Historical OrderItem price
        →
    order_items.unit_price

The system must not maintain separate manually editable totals that can drift from the underlying transactions.

Derived values should be calculated.

Historical snapshots are allowed when they preserve transaction-time truth.

---

## 87. Derived Financial Values

The following values are derived:

    Remaining Amount

    Net Profit

    Financial Totals

    Expense Totals by Category

    Payment Totals by Method

They should not require separate transactional storage.

Conceptually:

    Remaining Amount
        =
    Order Total - Payments

    Net Profit
        =
    Sales - Expenses

    Expense Category Total
        =
    Sum of Expenses for Category

---

## 88. Database Safety for Historical Data

Historical data should remain readable even if:

    Service is deactivated

    Item Type is deactivated

    Item Definition is deactivated

    Carpet Size is deactivated

    Storage Location is deactivated

    Expense Category is deactivated

Historical transactions must remain understandable.

The application may hide inactive master data from new transaction creation, but historical data must continue to reference and display it.

---

## 89. V1 Data Model Summary

The high-level relationship structure is:

    Customer
        │
        └── 1:N → Order
                     │
                     ├── 1:N → OrderItem
                     │              │
                     │              ├── ItemType
                     │              ├── ItemDefinition
                     │              ├── Service
                     │              ├── CarpetItemData
                     │              └── StorageRecord
                     │
                     └── 1:N → Payment

    Service
        │
        └── N:M → ItemType
                    through
                ServiceItemType

    StorageLocation
        │
        └── N:M → ItemType
                    through
                StorageLocationItemType

    ExpenseCategory
        │
        └── 1:N → Expense

    BusinessSettings

    SyncOperation

This represents the approved V1 database direction.

---

## 90. Final Database Direction

The approved V1 database direction is:

    SQLite
        +
    Drift
        +
    Relational Schema
        +
    UUID Primary Keys
        +
    Integer Minor-Unit Money
        +
    Historical Data Preservation
        +
    Active/Inactive Master Data
        +
    Foreign Keys
        +
    Transactions
        +
    Pagination
        +
    Local Search
        +
    Local Filtering
        +
    Offline-first
        +
    Synchronization-ready
        +
    Expenses
        +
    Expense Categories
        +
    Financial Reporting
        +
    Derived Net Profit
        +
    Independent Delivery Directions
        +
    Item Type-aware Storage
        +
    Simple V1 Schema

The database must remain simple, reliable, relational, and aligned with the approved Domain Model.

---

## 91. Final Principle

The most important database principle is:

    The database must preserve the real business state
    and historical truth of the laundry operation
    without introducing unnecessary complexity.

The database should be:

    Reliable
    +
    Relational
    +
    Offline-first
    +
    Historically accurate
    +
    Financially accurate
    +
    Synchronization-ready
    +
    Efficient for daily operations
    +
    Safe for physical storage workflows
    +
    Simple enough to maintain
    +
    Safe for AI-assisted implementation