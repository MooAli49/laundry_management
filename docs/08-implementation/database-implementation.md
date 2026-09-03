# Laundry Management System — Database Implementation

## 1. Document Purpose

This document defines the approved implementation contract for the V1 local database of the Laundry Management System.

It translates the approved database documentation into concrete Flutter/Drift implementation requirements.

This document is intended to guide the implementation phase.

The implementation must follow the approved:

    requirements.md
    scope.md
    business-rules.md
    domain-model.md
    entities.md
    architecture.md
    data-layer.md
    database-overview.md
    database-decisions.md
    tables.md
    relationships.md
    constraints.md
    indexes.md
    seed-data.md
    sync-strategy.md

This document does not redefine business requirements.

It defines how the approved database design is implemented.

---

## 2. Implementation Status

The V1 implementation phase covered by this document is:

    Local Flutter Database
        +
    Drift
        +
    SQLite

The following are intentionally deferred from this implementation phase:

    Remote Backend Implementation
    Supabase Implementation
    Edge Functions
    Dio Integration
    Retrofit Integration
    Remote Synchronization Execution
    Multi-device Synchronization
    Conflict Resolution Runtime

The database implementation must, however, remain compatible with the approved future synchronization strategy.

---

## 3. Approved Technology

The local database stack is:

    Flutter
        ↓
    Drift
        ↓
    SQLite

Drift is the approved database abstraction for Flutter.

SQLite is the actual local persistence engine.

The implementation must not replace Drift with:

    sqflite
    Hive
    Isar
    ObjectBox
    Realm
    Floor
    sembast
    shared_preferences

or another persistence technology unless an explicit architecture decision changes the database technology.

---

## 4. Data Layer Boundary

Database implementation belongs to the Data Layer.

The approved dependency direction is:

    Presentation
        ↓
    Application
        ↓
    Domain
        ↓
    Data

The Data Layer owns:

    Drift tables
    Drift database class
    Database queries
    DAO/query methods
    Local persistence
    Repository implementations
    Database migrations
    Database transactions
    Sync-operation persistence

The Domain layer must not directly depend on:

    Drift
    SQLite
    Generated Drift table classes
    Generated Drift row classes
    Drift exceptions
    SQLite exceptions

The Presentation layer must not directly access Drift.

---

## 5. Local Database Role

The local database is the primary operational source of truth for the Flutter application.

Normal V1 operations must work without network access.

The following must be locally supported:

    Customer management
    Order management
    OrderItem management
    Storage management
    Payment recording
    Expense recording
    Expense Category management
    Service management
    Item Type management
    Item Definition management
    Carpet Size management
    Storage Location management
    Dashboard queries
    Financial report queries
    Settings management

The UI reads normal operational data from the local database.

Remote synchronization is separate.

---

## 6. Database File

The application must use a single local SQLite database for the V1 application.

The database file must be opened through the approved Drift database abstraction.

The database lifecycle must be managed centrally.

The application must not create independent database instances inside individual screens, widgets, repositories, or features.

There must be one application-level database instance.

---

## 7. Database Class

A single root Drift database class must own the approved tables.

Conceptually:

    @DriftDatabase(
      tables: [...],
      daos: [...]
    )
    class AppDatabase extends _$AppDatabase

The exact generated class naming may follow the project naming convention.

The database class must:

    Extend Generated Database
    Configure schema version
    Configure migrations
    Enable required SQLite behavior
    Expose approved DAOs
    Provide transaction boundaries where required

---

## 8. Database Initialization

Database initialization must happen through the Data Layer.

The database must be initialized before repositories that depend on it are used.

The application must not initialize a database directly from UI code.

Dependency flow:

    Application Startup
        ↓
    Database Provider / DI
        ↓
    AppDatabase
        ↓
    DAOs / Repositories

---

## 9. SQLite Foreign Key Enforcement

SQLite Foreign Key enforcement must be enabled.

The implementation must ensure that:

    Foreign Key constraints
        ↓
    Are actually enforced by SQLite

The implementation must not assume that defining a Foreign Key relationship is sufficient if SQLite enforcement has not been enabled.

---

## 10. Primary Key Strategy

The default V1 Primary Key strategy is:

    UUID
        ↓
    TEXT
        ↓
    Drift text column

UUIDs are generated at the application/data boundary before persistence.

The UUID must be stable.

The same UUID must remain valid across:

    Local Creation
    Local Updates
    Offline Operation
    Future Synchronization

The database must never replace an entity UUID because synchronization occurs.

---

## 11. Primary Key Exception — OrderItemCarpet

There is one intentional exception to the default:

    id

Primary Key convention.

For:

    order_item_carpets

the Primary Key is:

    order_item_id

The same field is also the Foreign Key:

    order_item_carpets.order_item_id
        →
    order_items.id

This is intentional because the relationship is:

    OrderItem
        1
        |
        |
        0..1
        |
        ↓
    OrderItemCarpet

Therefore:

    order_item_carpets.order_item_id

must be:

    PRIMARY KEY
    NOT NULL
    UNIQUE
    FOREIGN KEY → order_items.id

There must not be a separate:

    order_item_carpets.id

column used as Primary Key.

There must not be a second UUID generated for OrderItemCarpet.

---

## 12. Money Representation

All persisted monetary values must use integer minor currency units.

Currency:

    EGP

Example:

    100.50 ج.م
        ↓
    10050

The database must not store monetary values as:

    REAL
    DOUBLE
    FLOAT

Money must be represented using an integer database type.

In Dart, the application/domain representation may use an appropriate money abstraction, but persistence must remain integer minor units.

---

## 13. Money Fields

The following fields use integer minor currency units:

    orders.subtotal
    orders.discount
    orders.tax
    orders.total
    orders.customer_pickup_fee
    orders.customer_delivery_fee

    order_items.unit_price
    order_items.calculated_total

    services.price

    payments.amount

    expenses.amount

    business_settings.tax_rate

No floating-point persistence is allowed for these values.

---

## 14. Date and Time Representation

Date-only fields must not be stored as arbitrary formatted strings when a proper date representation is available through the approved Drift/SQLite implementation.

Date-only fields include:

    orders.expected_pickup_date
    expenses.expense_date

Timestamp fields include:

    created_at
    updated_at
    paid_at
    completed_at
    cancelled_at
    last_attempt_at

The implementation must keep a clear distinction between:

    Business Date

and:

    Timestamp

The application must not mix the two concepts.

---

## 15. Timestamp Policy

Required timestamps must be populated at persistence time.

Entities containing:

    created_at
    updated_at

must preserve:

    updated_at >= created_at

When an entity is updated:

    updated_at

must be updated.

The implementation must not modify historical business event timestamps merely because another field changed.

Examples:

    Payment.paid_at
    Expense.expense_date
    Order.completed_at
    Order.cancelled_at

are not generic update timestamps.

---

## 16. Approved V1 Tables

The local database must implement the following approved tables:

    customers
    orders
    order_items
    payments
    storage_locations
    storage_records
    item_types
    item_definitions
    services
    service_item_types
    storage_location_item_types
    carpet_sizes
    order_item_carpets
    expense_categories
    expenses
    business_settings
    sync_operations

No additional V1 business table should be introduced.

---

## 17. Customers Table

Table:

    customers

Required fields:

    id
    name
    phone
    notes
    created_at
    updated_at

Primary Key:

    id

Required constraints:

    id NOT NULL
    name NOT NULL
    phone NOT NULL
    phone UNIQUE

Notes:

    notes

is nullable.

---

## 18. Customer Phone

Phone numbers must be stored as:

    TEXT

The implementation must not use a numeric SQLite type for phone numbers.

Phone normalization belongs to the application/domain/data boundary according to the approved customer rules.

The persisted normalized phone must be unique.

Duplicate normalized phone numbers must be rejected.

---

## 19. Customer Queries

The customer DAO/repository must support:

    Create Customer
    Get Customer by ID
    Get Customer by Phone
    Update Customer
    Search Customers
    List Customers
    Check Phone Exists

Customer search must support at least:

    Customer Name
    Customer Phone

The implementation must support efficient local queries.

---

## 20. Orders Table

Table:

    orders

Required fields:

    id
    customer_id
    order_number
    status
    expected_pickup_date
    subtotal
    discount
    tax
    total
    customer_pickup_requested
    customer_pickup_fee
    customer_delivery_requested
    customer_delivery_fee
    notes
    completed_at
    cancelled_at
    cancellation_reason
    created_at
    updated_at

Primary Key:

    id

Foreign Key:

    customer_id
        →
    customers.id

Unique:

    order_number

---

## 21. Order Status Storage

Order status must be persisted using the approved V1 values:

    processing
    ready
    completed
    cancelled

The database representation may use:

    TEXT

The implementation must not persist unsupported status strings.

Domain/application validation remains responsible for lifecycle transitions.

---

## 22. Order Number

Order Number is a business identifier.

It is not the same as:

    orders.id

The implementation must preserve this distinction.

The Order Number must be:

    NOT NULL
    UNIQUE

Order Number is used by:

    UI display
    Search
    Customer communication
    Invoice/receipt output

---

## 23. Expected Pickup Date

Expected Pickup Date is:

    Required
    Date-only

It must not be treated as a timestamp.

The repository/API exposed to the Domain should use an appropriate domain representation rather than leaking raw database-specific types.

---

## 24. Order Delivery Fields

The Order table must contain independent fields for:

    customer_pickup_requested
    customer_pickup_fee

and:

    customer_delivery_requested
    customer_delivery_fee

These are independent.

The implementation must not replace them with:

    delivery_type

or:

    mutually exclusive delivery enum

Both options may be selected simultaneously.

---

## 25. Order Delivery Defaults

Defaults:

    customer_pickup_requested = false
    customer_pickup_fee = 0

    customer_delivery_requested = false
    customer_delivery_fee = 0

Fees must not be negative.

The Domain/Application layer is responsible for ensuring a disabled option does not retain an effective non-zero fee.

---

## 26. Order Financial Fields

Required:

    subtotal
    discount
    tax
    total

All use integer minor currency units.

The database must protect basic non-negative constraints.

The complete financial formula remains a Domain/Application responsibility.

The database must not attempt to reconstruct the financial calculation from current master data.

---

## 27. Order Historical Financial Data

Order financial values are transaction-time values.

The following must be preserved:

    subtotal
    discount
    tax
    total
    customer_pickup_fee
    customer_delivery_fee

Changes to current configuration must not silently modify existing Orders.

---

## 28. Order Completion Fields

Fields:

    completed_at
    cancelled_at
    cancellation_reason

are nullable.

When an Order becomes Completed through the approved workflow:

    status = completed
    completed_at = completion timestamp

When an Order becomes Cancelled:

    status = cancelled
    cancelled_at = cancellation timestamp
    cancellation_reason = approved reason

The Domain/Application layer controls the workflow.

---

## 29. OrderItem Table

Table:

    order_items

Required fields:

    id
    order_id
    item_type_id
    item_definition_id
    service_id
    item_type_name_snapshot
    item_definition_name_snapshot
    service_name_snapshot
    pricing_type
    quantity
    unit_price
    calculated_total
    notes
    created_at
    updated_at

Primary Key:

    id

Foreign Keys:

    order_id
        →
    orders.id

    item_type_id
        →
    item_types.id

    item_definition_id
        →
    item_definitions.id

    service_id
        →
    services.id

---

## 30. OrderItem Required Relationships

Every OrderItem must belong to:

    One Order
    One Item Type
    One Service

Item Definition is optional.

Therefore:

    item_definition_id

may be null.

---

## 31. OrderItem Physical Identity

Each physical laundry item must have its own OrderItem ID.

Example:

    5 shirts

must be represented as:

    OrderItem A
    OrderItem B
    OrderItem C
    OrderItem D
    OrderItem E

when the business workflow treats them as five physical items.

The database implementation must not automatically collapse physical items merely because their:

    Item Type
    Service
    Price

are identical.

---

## 32. OrderItem Quantity

Quantity is required.

Quantity must be greater than zero.

Examples:

    Per Piece → 1
    Per Kilogram → 3.5
    Per Square Meter → 6.25
    Fixed Price → 1

The exact precision must follow the approved entity/database definition.

The implementation must not use integer-only storage if the approved domain allows decimal quantities.

---

## 33. OrderItem Pricing Type

Allowed values:

    per_piece
    per_kg
    per_square_meter
    fixed_price

The implementation must not introduce additional pricing types.

Pricing behavior belongs primarily to Domain/Application logic.

---

## 34. OrderItem Price

Required:

    unit_price
    calculated_total

Both use integer minor currency units.

Both must be non-negative.

The OrderItem price represents transaction-time pricing.

It must not automatically follow future Service price changes.

---

## 35. OrderItem Historical Snapshots

Required snapshots:

    item_type_name_snapshot
    service_name_snapshot

Optional snapshot:

    item_definition_name_snapshot

These values must represent the names used at transaction time.

Changing current master data must not rewrite these fields.

---

## 36. OrderItem Item Definition

The field:

    item_definition_id

is nullable.

If populated:

    item_definition_id
        →
    item_definitions.id

The Domain/Application layer must validate that the Item Definition belongs to the selected Item Type.

The Data Layer must preserve the Foreign Key relationship.

---

## 37. Payments Table

Table:

    payments

Required fields:

    id
    order_id
    amount
    payment_method
    paid_at
    created_at
    updated_at

Primary Key:

    id

Foreign Key:

    order_id
        →
    orders.id

---

## 38. Payment Amount

Payment amount must be:

    > 0

Payment amount must be stored as integer minor currency units.

Zero payment must be rejected.

Negative payment must be rejected.

---

## 39. Payment Method

Allowed V1 values:

    cash
    instapay
    ewallet

The implementation must not persist unsupported payment methods.

---

## 40. Payment History

A Payment represents a historical financial transaction.

Creating a new payment must create a new Payment record.

The implementation must not overwrite an old Payment to represent a new transaction.

Normal V1 operations must not physically delete Payments.

---

## 41. Payment Overpayment

The complete overpayment rule is:

    Payment Amount
        <=
    Remaining Amount

where:

    Remaining Amount
        =
    Order Total
        -
    Sum of Existing Payments

This rule is not a static column constraint.

It must be validated transactionally by the Domain/Application/Data operation responsible for recording a Payment.

---

## 42. Storage Locations Table

Table:

    storage_locations

Required fields:

    id
    name
    is_active
    created_at
    updated_at

Primary Key:

    id

Name:

    NOT NULL
    UNIQUE

Active state:

    NOT NULL
    DEFAULT true

---

## 43. Storage Location Lifecycle

Active Storage Locations:

    Available for new storage operations

Inactive Storage Locations:

    Not available for new storage operations

Historical StorageRecords referencing an inactive Storage Location remain valid.

The implementation must not delete historical storage information merely because a location is deactivated.

---

## 44. Storage Records Table

Table:

    storage_records

Required fields:

    id
    order_item_id
    storage_location_id
    is_active
    created_at
    updated_at

Primary Key:

    id

Foreign Keys:

    order_item_id
        →
    order_items.id

    storage_location_id
        →
    storage_locations.id

---

## 45. Active StorageRecord Constraint

An OrderItem may have:

    Maximum One Active StorageRecord

The implementation must enforce:

    UNIQUE active storage record per order_item_id

Preferred SQLite implementation:

    Partial Unique Index

Conceptually:

    UNIQUE(order_item_id)
    WHERE is_active = true

The exact Drift implementation must generate a SQLite-compatible constraint/index.

This is a database-level integrity rule.

---

## 46. Storage Movement

Moving an item must perform:

    Deactivate Old StorageRecord
        +
    Create New StorageRecord

inside one database transaction.

The implementation must not leave the database with:

    Two active StorageRecords

for the same OrderItem.

---

## 47. Storage Completion

When an Order becomes Completed:

    All active StorageRecords
        for its OrderItems
        ↓
    is_active = false

This operation must be part of the same database transaction as the Order completion update.

---

## 48. Storage Cancellation

When an Order becomes Cancelled:

    All active StorageRecords
        for its OrderItems
        ↓
    is_active = false

This operation must be transactional with the Order cancellation update.

---

## 49. Manual Completed to Processing

If a Completed Order is manually returned to Processing:

    Existing inactive StorageRecords
        remain inactive

The implementation must not automatically reactivate historical StorageRecords.

If physical items need storage again:

    Create New Active StorageRecord

---

## 50. Item Types Table

Table:

    item_types

Required fields:

    id
    name
    is_active
    created_at
    updated_at

Primary Key:

    id

Name:

    NOT NULL
    UNIQUE

Active:

    NOT NULL
    DEFAULT true

---

## 51. Item Type Lifecycle

Active Item Types:

    Available for new transactions

Inactive Item Types:

    Not available for new transactions

Historical OrderItems referencing inactive Item Types remain valid.

---

## 52. Item Definitions Table

Table:

    item_definitions

Required fields:

    id
    item_type_id
    name
    is_active
    created_at
    updated_at

Primary Key:

    id

Foreign Key:

    item_type_id
        →
    item_types.id

Unique:

    item_type_id
        +
    name

---

## 53. Item Definition Uniqueness

The same Item Definition name must not appear twice under the same Item Type.

Example:

    Item Type = Shirt
    Definition = Cotton

may exist once.

The same Definition name may exist under another Item Type.

Example:

    Shirt + Cotton
    Trousers + Cotton

is valid.

---

## 54. Services Table

Table:

    services

Required fields:

    id
    name
    description
    pricing_type
    price
    is_active
    created_at
    updated_at

Primary Key:

    id

Name:

    NOT NULL
    UNIQUE

Pricing Type:

    NOT NULL

Price:

    NOT NULL
    >= 0

Active:

    NOT NULL
    DEFAULT true

---

## 55. Service Pricing

Current Service pricing is master data.

Historical OrderItem pricing is transaction data.

When creating an OrderItem:

    Current Service Price
        ↓
    Calculate Transaction Price
        ↓
    Store OrderItem.unit_price

After creation:

    Service.price

may change.

The stored:

    OrderItem.unit_price

must not automatically change.

---

## 56. Service / Item Type Junction Table

Table:

    service_item_types

Required fields:

    id
    service_id
    item_type_id
    created_at
    updated_at

Primary Key:

    id

Foreign Keys:

    service_id
        →
    services.id

    item_type_id
        →
    item_types.id

Unique:

    service_id
        +
    item_type_id

---

## 57. Service Compatibility

An OrderItem must use a valid:

    Service
        +
    Item Type

combination.

The valid combination must exist in:

    service_item_types

The Domain/Application layer validates the business rule.

The database preserves the compatibility relationship.

---

## 58. Storage Location / Item Type Junction Table

Table:

    storage_location_item_types

Required fields:

    id
    storage_location_id
    item_type_id
    created_at
    updated_at

Primary Key:

    id

Foreign Keys:

    storage_location_id
        →
    storage_locations.id

    item_type_id
        →
    item_types.id

Unique:

    storage_location_id
        +
    item_type_id

---

## 59. Storage Compatibility

A Storage Location may support multiple Item Types.

An Item Type may be supported by multiple Storage Locations.

The valid relationship is represented through:

    storage_location_item_types

The application must only allow valid Item Type / Storage Location combinations.

The Domain/Application layer performs the workflow validation.

---

## 60. Carpet Sizes Table

Table:

    carpet_sizes

Required fields:

    id
    length
    width
    area
    is_active
    created_at
    updated_at

Primary Key:

    id

Dimensions:

    length > 0
    width > 0
    area > 0

Active:

    NOT NULL
    DEFAULT true

---

## 61. Carpet Size Calculation

The Domain/Application layer is responsible for validating:

    area
        =
    length × width

according to the approved measurement unit and precision.

The database must prevent non-positive values.

---

## 62. OrderItemCarpets Table

Table:

    order_item_carpets

Required fields:

    order_item_id
    length
    width
    area
    carpet_size_id
    created_at
    updated_at

Primary Key:

    order_item_id

Foreign Key:

    order_item_id
        →
    order_items.id

Optional Foreign Key:

    carpet_size_id
        →
    carpet_sizes.id

---

## 63. OrderItemCarpet Identity

There is no independent:

    id

column for OrderItemCarpet.

The identity is:

    order_item_id

The implementation must use the existing OrderItem UUID.

Example:

    OrderItem.id = ORDER-UUID-123

then:

    OrderItemCarpet.order_item_id
        =
    ORDER-UUID-123

No second UUID is generated.

---

## 64. OrderItemCarpet Cardinality

The database must guarantee:

    One OrderItem
        →
    Maximum One OrderItemCarpet

Because:

    order_item_carpets.order_item_id

is the Primary Key.

This automatically prevents duplicate Carpet records for the same OrderItem.

---

## 65. Carpet Size Optionality

The field:

    carpet_size_id

may be null.

This supports:

    Predefined Carpet Size

or:

    Custom Carpet Dimensions

When:

    carpet_size_id != null

the referenced Carpet Size must exist.

Historical dimensions remain stored directly on:

    order_item_carpets.length
    order_item_carpets.width
    order_item_carpets.area

---

## 66. Carpet Historical Data

The following are transaction-time values:

    length
    width
    area

Changing a Carpet Size must not modify historical OrderItemCarpet records.

Historical carpet dimensions must not be reconstructed from current CarpetSize values.

---

## 67. Carpet Type Validation

Only Carpet OrderItems may have an OrderItemCarpet record.

The Domain/Application layer validates:

    OrderItem.item_type
        =
    Carpet

before creating OrderItemCarpet.

The database preserves:

    order_item_id
        →
    order_items.id

but does not need to implement the semantic Item Type check through a complex trigger.

---

## 68. Expense Categories Table

Table:

    expense_categories

Required fields:

    id
    name
    is_active
    created_at
    updated_at

Primary Key:

    id

Name:

    NOT NULL
    UNIQUE

Active:

    NOT NULL
    DEFAULT true

---

## 69. Expense Category Lifecycle

Active Expense Categories:

    Available for new Expenses

Inactive Expense Categories:

    Not available for new Expenses

Historical Expenses referencing an inactive category remain valid.

---

## 70. Expenses Table

Table:

    expenses

Required fields:

    id
    expense_category_id
    amount
    expense_date
    category_name_snapshot
    expense_name
    notes
    created_at
    updated_at

Primary Key:

    id

Foreign Key:

    expense_category_id
        →
    expense_categories.id

---

## 71. Expense Amount

Expense amount must be:

    > 0

The amount uses integer minor currency units.

The implementation must reject:

    0

and:

    negative values

---

## 72. Expense Date

Expense Date is:

    Required
    Date-only

It is the business/reporting date of the Expense.

It must not be confused with:

    created_at

---

## 73. Expense Category Snapshot

Every Expense stores:

    category_name_snapshot

This is the category name at transaction time.

Changing:

    expense_categories.name

must not modify:

    expenses.category_name_snapshot

---

## 74. Other Expense

If the selected Expense Category represents:

    أخرى

then:

    expense_name

is required.

The conditional rule is validated by Domain/Application logic.

The database stores the supplied value.

---

## 75. Expense Independence

Expenses are independent financial transactions.

The Expense table must not introduce:

    order_id
    order_item_id
    payment_id
    customer_id

Expenses must not be implemented as a special type of Payment.

---

## 76. Business Settings Table

Table:

    business_settings

Required fields:

    id
    business_name
    address
    phone
    logo_reference
    invoice_footer_text
    tax_enabled
    tax_rate
    updated_at

Primary Key:

    id

Required:

    business_name
    tax_enabled
    tax_rate
    updated_at

Optional:

    address
    phone
    logo_reference
    invoice_footer_text

---

## 77. Business Settings Single Row

V1 supports:

    One Business
        +
    One Branch
        +
    One BusinessSettings Record

The implementation must prevent accidental creation of multiple settings records.

Preferred strategy:

    Fixed single-row identifier

or another explicit single-row mechanism.

The application must not treat BusinessSettings as a normal multi-row table.

---

## 78. Tax Settings

Fields:

    tax_enabled
    tax_rate

Defaults:

    tax_enabled = false
    tax_rate = 0

Tax rate must not be negative.

If:

    tax_enabled = false

effective Order tax must be:

    0

The complete calculation remains Domain/Application behavior.

---

## 79. Sync Operations Table

Table:

    sync_operations

Required fields:

    id
    entity_type
    entity_id
    operation_type
    status
    retry_count
    created_at
    updated_at

Optional fields:

    payload
    last_error
    last_attempt_at

Primary Key:

    id

---

## 80. Sync Implementation Scope

The local SyncOperation table is part of the database implementation because the approved architecture is synchronization-ready.

However:

    Remote synchronization execution

is deferred.

The implementation must support persistence of synchronization operations without implementing:

    Remote API calls
    Retry workers
    Conflict resolution
    Supabase Edge Functions
    Remote reconciliation

unless explicitly requested in a later implementation phase.

---

## 81. Sync Entity Types

Approved entity types include:

    customer
    order
    order_item
    payment
    storage_location
    storage_record
    item_type
    item_definition
    service
    service_item_type
    storage_location_item_type
    carpet_size
    order_item_carpet
    expense_category
    expense
    business_settings

The implementation must not introduce unsupported entity types.

---

## 82. Sync Operation Types

Approved V1 operation types:

    create
    update
    deactivate

No other operation type should be introduced without updating the synchronization documentation.

---

## 83. Sync Status

Approved statuses:

    pending
    processing
    synced
    failed

The implementation must not persist unsupported statuses.

---

## 84. Sync Retry Count

Default:

    retry_count = 0

Constraint:

    retry_count >= 0

Retry execution is deferred.

The local database only needs to persist the state required by the approved synchronization model.

---

## 85. Sync Entity Identity

The combination:

    entity_type
        +
    entity_id

must identify the business entity associated with a SyncOperation.

It must not be globally unique.

One entity may have multiple synchronization operations over time.

Example:

    Order A
        create
        update
        update

is valid.

---

## 86. Sync Atomicity

When synchronization persistence is enabled for a business mutation:

    Business Data Change
        +
    SyncOperation Creation

must be committed in the same database transaction.

Invalid:

    Business Data Saved
        +
    SyncOperation Missing

Valid:

    Business Data Saved
        +
    SyncOperation Persisted

---

## 87. DAO Organization

DAO classes should be organized by responsibility rather than creating one giant database access class.

Suggested structure:

    CustomerDao
    OrderDao
    OrderItemDao
    PaymentDao
    StorageDao
    ItemTypeDao
    ItemDefinitionDao
    ServiceDao
    CarpetDao
    ExpenseCategoryDao
    ExpenseDao
    BusinessSettingsDao
    SyncOperationDao

A DAO may combine closely related queries where that improves maintainability.

Do not create unnecessary micro-DAOs for every individual query.

---

## 88. DAO Responsibilities

DAOs are responsible for:

    CRUD persistence
    Queries
    Joins
    Filtering
    Sorting
    Pagination
    Constraint-aware database operations
    Database transactions where appropriate

DAOs are not responsible for:

    UI state
    Navigation
    Presentation logic
    Business workflow orchestration
    Formatting Arabic display strings
    Screen-specific behavior

---

## 89. Repository Responsibilities

Repositories provide the boundary between Domain/Application and Data.

Repositories should expose domain-oriented operations.

The Domain must not need to know:

    Drift table names
    Drift companions
    Generated row types
    SQL expressions
    SQLite exceptions

Repository implementations may internally use:

    DAOs
    AppDatabase
    Drift queries
    Transactions

---

## 90. Repository Examples

Expected repository contracts include concepts such as:

    CustomerRepository
    OrderRepository
    PaymentRepository
    StorageRepository
    ServiceRepository
    ItemTypeRepository
    ExpenseRepository
    SettingsRepository

The exact repository interface names must follow the approved project structure.

Do not introduce a mandatory Use Case layer merely to wrap repository calls.

---

## 91. No Dedicated Use Case Layer

The approved architecture does not require a dedicated generic Use Case layer.

Do not create mandatory classes such as:

    CreateOrderUseCase
    CreateExpenseUseCase
    RecordPaymentUseCase

merely because they are common in other architectures.

Application/domain orchestration should remain within the approved architecture.

A use-case abstraction may only be introduced if a concrete project requirement justifies it and the architecture documentation is updated.

---

## 92. No Generic Mapper Layer

A dedicated generic Mapper layer is not required.

Do not create mappers merely because they are common architectural patterns.

Simple conversions should remain close to the responsibility that needs them.

A mapper may be introduced only when a concrete mapping problem justifies it.

---

## 93. Drift Generated Code

Generated Drift files must not be manually edited.

Generated code must be recreated through the approved Drift code generation process.

Source-of-truth files include:

    Drift table definitions
    DAO definitions
    Database class
    Migration code

Generated output is derived.

---

## 94. Drift Table Naming

Database table names must follow the approved snake_case names:

    customers
    orders
    order_items
    payments
    storage_locations
    storage_records
    item_types
    item_definitions
    services
    service_item_types
    storage_location_item_types
    carpet_sizes
    order_item_carpets
    expense_categories
    expenses
    business_settings
    sync_operations

Dart class names may follow Dart naming conventions.

Example:

    Customers
    Orders
    OrderItems

The database table names must remain aligned with the approved schema.

---

## 95. Column Naming

SQLite column names must follow snake_case.

Examples:

    customer_id
    order_number
    expected_pickup_date
    calculated_total
    customer_pickup_requested
    customer_delivery_requested
    category_name_snapshot
    storage_location_id

Do not introduce inconsistent naming styles.

---

## 96. Boolean Representation

Boolean fields should use Drift's boolean support and map to SQLite appropriately.

Required boolean fields include:

    is_active
    customer_pickup_requested
    customer_delivery_requested
    tax_enabled

The implementation must provide explicit defaults where documented.

---

## 97. Nullable Fields

Nullable fields must only be nullable when the approved schema says they are nullable.

Important nullable fields include:

    order_items.item_definition_id
    order_items.item_definition_name_snapshot
    order_items.notes
    order_item_carpets.carpet_size_id
    orders.notes
    orders.completed_at
    orders.cancelled_at
    orders.cancellation_reason
    expenses.expense_name
    expenses.notes
    sync_operations.payload
    sync_operations.last_error
    sync_operations.last_attempt_at

Do not make required fields nullable merely to simplify inserts.

---

## 98. Database Constraints

The implementation must enforce, where practical:

    Primary Keys
    Foreign Keys
    Required fields
    Unique fields
    Positive values
    Non-negative values
    Unique compatibility relationships
    One active StorageRecord
    One OrderItemCarpet per OrderItem
    Single BusinessSettings row

Complex workflow validation remains outside the database.

---

## 99. Unique Constraints

Required unique constraints include:

    customers.phone

    orders.order_number

    storage_locations.name

    item_types.name

    services.name

    expense_categories.name

    item_definitions(item_type_id, name)

    service_item_types(service_id, item_type_id)

    storage_location_item_types(storage_location_id, item_type_id)

    order_item_carpets.order_item_id

---

## 100. Positive Constraints

Values that must be greater than zero include:

    order_items.quantity

    payments.amount

    expenses.amount

    carpet_sizes.length
    carpet_sizes.width
    carpet_sizes.area

    order_item_carpets.length
    order_item_carpets.width
    order_item_carpets.area

The implementation must reject invalid values.

---

## 101. Non-Negative Constraints

Values that may be zero but must not be negative include:

    orders.subtotal
    orders.discount
    orders.tax
    orders.total
    orders.customer_pickup_fee
    orders.customer_delivery_fee

    order_items.unit_price
    order_items.calculated_total

    services.price

    business_settings.tax_rate

    sync_operations.retry_count

---

## 102. Foreign Key Delete Behavior

Historical business data must be protected.

Do not use unrestricted:

    ON DELETE CASCADE

for relationships where deletion could remove historical transactions.

Conservative behavior such as:

    RESTRICT

should be preferred where appropriate.

Normal V1 operations do not physically delete:

    Orders
    OrderItems
    Payments
    Expenses

---

## 103. Master Data Deletion

Master data should normally be deactivated instead of deleted when historical references exist.

This applies to:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

Deactivation preserves historical references.

---

## 104. Order Deletion

Orders must not be physically deleted during normal V1 business operations.

Instead:

    Cancel Order

is used when the business workflow requires cancellation.

The cancelled Order remains in history.

---

## 105. Payment Deletion

Payments are historical financial records.

Normal V1 operations must not physically delete Payments.

If a future correction mechanism is required, it must be explicitly documented.

---

## 106. Expense Deletion

Expenses are historical financial records.

Normal V1 operations must not physically delete Expenses.

If a future correction mechanism is required, it must be explicitly documented.

---

## 107. Database Transactions

The implementation must use database transactions whenever one business operation changes multiple related records.

Required transaction cases include:

    Create Order
    Create OrderItems
    Create OrderItem-specific data

    Record Payment
    Create SyncOperation

    Create Expense
    Create SyncOperation

    Move OrderItem
    Deactivate old StorageRecord
    Create new StorageRecord

    Complete Order
    Update Order
    Deactivate StorageRecords

    Cancel Order
    Update Order
    Deactivate StorageRecords

---

## 108. Create Order Transaction

Creating an Order should be treated as an atomic operation.

Conceptually:

    Begin Transaction

    Create Customer if required

    Create Order

    Create OrderItems

    Create OrderItem-specific data

    Create required SyncOperations

    Commit

If any required step fails:

    Roll Back

No partially created Order should remain.

---

## 109. Order Item Specific Data

When creating an OrderItem:

    Normal Item
        →
    OrderItem only

    Carpet Item
        →
    OrderItem
        +
    OrderItemCarpet

The creation must be transactional.

A Carpet OrderItem must not be left without its required Carpet data when the approved workflow requires it.

---

## 110. Payment Transaction

Recording a Payment must be atomic.

Conceptually:

    Begin Transaction

    Validate Order
    Calculate Remaining Amount
    Validate Payment Amount
    Insert Payment
    Insert SyncOperation where applicable

    Commit

If any step fails:

    Roll Back

---

## 111. Expense Transaction

Creating an Expense must be atomic.

Conceptually:

    Begin Transaction

    Validate Expense
    Insert Expense
    Insert SyncOperation where applicable

    Commit

If any step fails:

    Roll Back

---

## 112. Storage Movement Transaction

Storage movement must be atomic.

Conceptually:

    Begin Transaction

    Deactivate Current Active StorageRecord

    Create New Active StorageRecord

    Create SyncOperation where applicable

    Commit

The implementation must rely on the database constraint preventing two active StorageRecords.

---

## 113. Complete Order Transaction

Order completion must update all related state atomically.

Conceptually:

    Begin Transaction

    Validate Completion Conditions

    Update Order:
        status = completed
        completed_at = timestamp

    Deactivate active StorageRecords

    Create SyncOperations where applicable

    Commit

No partial completion state is allowed.

---

## 114. Cancel Order Transaction

Order cancellation must update all related state atomically.

Conceptually:

    Begin Transaction

    Validate Cancellation

    Update Order:
        status = cancelled
        cancelled_at = timestamp
        cancellation_reason = reason

    Deactivate active StorageRecords

    Create SyncOperations where applicable

    Commit

---

## 115. Repository Transactions

Repositories may expose aggregate-level transactional operations.

A repository method representing one business mutation should not require the Presentation layer to manually coordinate multiple DAOs.

Preferred:

    orderRepository.completeOrder(...)

rather than:

    orderDao.update(...)
    storageDao.update(...)
    syncDao.insert(...)

from UI/application code.

The repository/data operation owns the transaction boundary.

---

## 116. Query Design

Queries must be designed around actual application needs.

The database should support:

    Search
    Filtering
    Sorting
    Pagination
    Dashboard
    Financial Reports
    Storage workflows

The implementation must avoid loading the entire database into memory when a SQL query can calculate the required result.

---

## 117. Order Search

Order search must support at least:

    Order Number
    Customer Name
    Customer Phone

The implementation may use joins between:

    orders
    customers

Search queries should remain efficient as data grows.

---

## 118. Customer Search

Customer search must support:

    Name
    Phone

The exact matching behavior should follow the approved UI/domain requirements.

The Data Layer must not introduce arbitrary search semantics that conflict with the product behavior.

---

## 119. Expense Queries

Expense queries must support:

    Expense Date
    Expense Category
    Expense Name where applicable

The Financial Report must be able to filter Expenses by date range.

---

## 120. Pagination

Orders are expected to grow.

The preferred loading model is incremental:

    Initial Batch
        ↓
    User Reaches End
        ↓
    Next Batch

The implementation should prefer cursor/keyset-style pagination where practical.

Traditional numbered page UI is not required.

The exact query strategy must remain compatible with the approved index design.

---

## 121. Pagination Ordering

Paginated queries must use deterministic ordering.

A stable secondary ordering key should be used when the primary sort field is not unique.

Example:

    created_at DESC
        +
    id DESC

This prevents unstable result ordering between batches.

---

## 122. Dashboard Queries

Dashboard values should be calculated through database queries.

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

The implementation must not load all Orders into Dart memory merely to calculate simple aggregates.

---

## 123. Financial Report Queries

Financial reports must use authoritative transaction data.

Sales source:

    orders

Payment source:

    payments

Expense source:

    expenses

Expense category source:

    expense_categories

Outstanding amount:

    orders
        -
    payments

Net Profit:

    Sales
        -
    Operating Expenses

The implementation must not introduce a duplicated financial ledger table.

---

## 124. Net Profit

Net Profit is derived.

The implementation must not create:

    net_profit

as a persistent transactional field.

No dedicated:

    profit

table is required.

The reporting query/service calculates:

    Sales
        -
    Operating Expenses

for the selected period according to the approved reporting rules.

---

## 125. Outstanding Amount

Outstanding Amount is derived.

Conceptually:

    Order Total
        -
    Sum of Payments
        =
    Remaining Amount

No dedicated:

    outstanding_balance

table is required.

---

## 126. Invoice Data

No persistent Invoice table is required in V1.

Invoice/receipt output must be generated from:

    BusinessSettings
    Customer
    Order
    OrderItems
    Payments

Historical OrderItem values must be used.

Do not retrieve current Service prices for historical Orders.

---

## 127. Invoice Carpet Data

For Carpet OrderItems, invoice output should use:

    order_item_carpets.length
    order_item_carpets.width
    order_item_carpets.area

and:

    carpet_size

information where applicable.

The implementation must not recalculate historical dimensions from current CarpetSize records.

---

## 128. Index Strategy

Indexes must be based on actual application queries.

Important indexed fields include:

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

Additional indexes must follow the approved:

    indexes.md

document.

Do not create indexes indiscriminately.

---

## 129. Order Indexes

Expected useful indexes include:

    customer_id
    status
    created_at
    expected_pickup_date

The exact final index definitions must remain centralized in:

    indexes.md

---

## 130. OrderItem Indexes

Expected useful indexes include:

    order_id
    item_type_id
    service_id

The exact final index definitions must remain centralized in:

    indexes.md

---

## 131. Payment Indexes

Expected useful indexes include:

    order_id
    paid_at

These support:

    Order payment history
    Remaining amount calculation
    Financial reports
    Date-based queries

---

## 132. Storage Indexes

Expected useful indexes include:

    order_item_id
    storage_location_id

The active-storage constraint must be enforced through the approved unique partial index.

---

## 133. Expense Indexes

Expected useful indexes include:

    expense_category_id
    expense_date

Additional search indexing should only be introduced if required by actual query patterns.

---

## 134. Migration Strategy

All schema changes must use Drift migrations.

The schema version must be incremented when schema changes occur.

Migrations must preserve existing user data.

A migration must not silently:

    Delete Orders
    Delete OrderItems
    Delete Payments
    Delete Expenses
    Delete StorageRecords
    Reset master data
    Change UUIDs
    Rewrite historical transaction values

unless an explicitly approved destructive migration is required.

---

## 135. Migration Development Rule

Every schema change must include:

    Schema Change
        +
    Migration Step
        +
    Updated Schema Version
        +
    Migration Test

The implementation must not modify an existing production schema without a migration.

---

## 136. Migration Safety

Before applying a migration that changes a table:

    Existing Data
        ↓
    Must remain valid

If SQLite requires table reconstruction for a schema change, the migration must explicitly preserve:

    Existing rows
    Existing IDs
    Existing relationships
    Existing historical values

---

## 137. OrderItemCarpet Migration Safety

If an earlier schema implementation used:

    order_item_carpets.id

as Primary Key,

the approved schema must be migrated to:

    order_item_carpets.order_item_id

as Primary Key.

The migration must preserve existing Carpet records.

The migration must not generate unrelated new UUIDs for existing OrderItemCarpet records.

Before applying the migration:

    Existing duplicate OrderItemCarpet rows

must be resolved according to the approved one-to-zero-or-one relationship.

No silent data loss is allowed.

---

## 138. Schema Versioning

The Drift schema version must represent the actual database schema.

Do not increase schema version merely because application code changed without schema impact.

Do not leave schema version unchanged when the database structure changes.

---

## 139. Seed Data

Seed data must be implemented according to:

    seed-data.md

Seed data must not overwrite user-created data during normal application startup.

The implementation must distinguish:

    Initial Seed
        ≠
    Database Reset

---

## 140. Seed Data Idempotency

If seed initialization is required, it should be safe to run more than once without creating duplicate master data.

The implementation must not create duplicate:

    Services
    Item Types
    Item Definitions
    Carpet Sizes
    Storage Locations
    Expense Categories

---

## 141. Seed Data and User Changes

Normal application startup must not:

    Reset user changes
    Recreate deleted/deactivated master records
    Restore old prices
    Overwrite names
    Reinsert duplicate relationships

Seed logic must preserve user modifications.

---

## 142. Active Master Data Queries

When creating a new transaction, repositories should normally query:

    is_active = true

for applicable master data.

Examples:

    Active Services
    Active Item Types
    Active Item Definitions
    Active Carpet Sizes
    Active Storage Locations
    Active Expense Categories

Historical records may reference inactive master data.

---

## 143. Historical Master Data Queries

Historical transaction screens must not automatically hide historical relationships merely because the current master record is inactive.

Example:

    Service becomes inactive

Historical OrderItem:

    service_id
    service_name_snapshot

must remain displayable.

---

## 144. Constraint Error Handling

Low-level database exceptions must not leak directly to Presentation.

Examples:

    Duplicate Customer Phone
    Duplicate Order Number
    Duplicate Service
    Duplicate Item Type
    Invalid Foreign Key
    Multiple Active StorageRecords
    Invalid positive-value constraint

should be translated into meaningful application/data errors.

---

## 145. Repository Error Boundary

The Data Layer should translate:

    Drift/SQLite Error

into an application-appropriate Data Layer error.

The Domain/Application layer may then map it to appropriate user-facing behavior.

The UI must not inspect raw SQLite exception strings.

---

## 146. Unique Constraint Errors

The Data Layer should be able to distinguish at least:

    Duplicate Customer Phone
    Duplicate Order Number
    Duplicate Expense Category
    Duplicate Service
    Duplicate Item Type
    Duplicate Item Definition
    Duplicate Service/ItemType relation
    Duplicate StorageLocation/ItemType relation
    Duplicate OrderItemCarpet
    Multiple active StorageRecords

---

## 147. Foreign Key Errors

Foreign Key violations should be translated into meaningful persistence errors.

Example:

    order.customer_id
        →
    Missing Customer

must not be surfaced as a raw SQLite error.

---

## 148. Database Logging

Database logging should be appropriate for development/debugging.

Production logging must not expose:

    Sensitive customer information
    Payment details beyond necessary diagnostics
    Internal database payloads
    Authentication information
    Private business data

The implementation should avoid excessive SQL logging in production.

---

## 149. Offline-first Behavior

The local database must not require network access.

Example:

    Create Expense
        ↓
    Local Save
        ↓
    Success

even if:

    Network = Unavailable

The local database operation must not depend on the future backend.

---

## 150. Remote Backend Separation

The database implementation must not directly call:

    Supabase
    Edge Functions
    Dio
    Retrofit

for normal local persistence.

The Data Layer may later contain both:

    Local Data Source
    Remote Data Source

but the local database implementation must remain independently usable.

---

## 151. Future Sync Compatibility

Even though remote synchronization is deferred, the local implementation must preserve:

    Stable UUIDs
    SyncOperation records
    Historical values
    Transaction atomicity
    Explicit entity identity
    Deterministic timestamps

This allows future synchronization without redesigning the local identity model.

---

## 152. No Backend Dependency

The V1 local implementation must compile and operate without requiring:

    Supabase project configuration
    API URL
    API key
    Dio client
    Retrofit generated client
    Edge Function availability

Remote integration is a later phase.

---

## 153. Data Layer and Business Logic

The Data Layer must not become the main location for complex business rules.

Business workflow rules remain in Domain/Application.

Examples:

    Order Completion
    Payment Overpayment
    Order Readiness
    Service Compatibility
    Item Definition Compatibility
    Carpet Item Validation
    Other Expense Name requirement
    Cancelled Order Read-only behavior

The Data Layer is responsible for:

    Persistence
    Queries
    Transactions
    Structural constraints

---

## 154. Database-Level Business Integrity

The database should enforce structural rules that are safe to enforce directly.

Examples:

    Primary Keys
    Foreign Keys
    Unique values
    Positive values
    Non-negative financial values
    One active StorageRecord
    One OrderItemCarpet per OrderItem

The database must not attempt to implement the entire application workflow.

---

## 155. Order Readiness

Order readiness is derived from OrderItems and StorageRecords.

Conceptually:

    Every OrderItem
        ↓
    Has Active StorageRecord
        ↓
    Order is eligible for Ready

The exact status transition remains Domain/Application logic.

The database provides the queries required to determine readiness.

---

## 156. Storage Requirement Query

The Data Layer should support a query capable of finding:

    OrderItems
        without
    Active StorageRecord

This supports:

    Storage Screen
    Dashboard
    Ready validation

The query should use SQL joins/conditions rather than loading all data into memory.

---

## 157. Order Payment Summary Query

The Data Layer should support an efficient query for:

    Order Total
        +
    Sum Payments
        +
    Remaining Amount

The remaining amount should be derived.

The implementation must not persist a separate mutable:

    remaining_amount

field unless explicitly approved.

---

## 158. Order Financial Summary Query

The Data Layer should support efficient queries for:

    Total Sales
    Total Payments
    Total Expenses
    Remaining Amount
    Net Profit

according to the approved report rules.

Financial calculations must use integer minor units.

---

## 159. Historical Price Integrity

The implementation must preserve:

    order_items.unit_price

independently from:

    services.price

When Service price changes:

    Existing OrderItem.unit_price
        remains unchanged

This must be covered by tests.

---

## 160. Historical Snapshot Integrity

The implementation must preserve:

    item_type_name_snapshot
    item_definition_name_snapshot
    service_name_snapshot

when master data changes.

Tests must verify that updating master data does not rewrite historical OrderItem snapshots.

---

## 161. Historical Expense Integrity

The implementation must preserve:

    expenses.category_name_snapshot

when:

    expense_categories.name

changes.

Tests must verify historical Expense reporting remains understandable.

---

## 162. Historical Carpet Integrity

The implementation must preserve:

    length
    width
    area

on OrderItemCarpet when:

    carpet_sizes

are changed or deactivated.

---

## 163. Storage Integrity Tests

The implementation must test:

    One active StorageRecord succeeds.

    Second active StorageRecord for same OrderItem fails.

    Old active StorageRecord can be deactivated.

    New active StorageRecord can then be created.

    Two inactive historical StorageRecords are allowed.

    Moving storage preserves historical records.

---

## 164. OrderItemCarpet Integrity Tests

The implementation must test:

    One OrderItemCarpet can be created.

    Second OrderItemCarpet for same OrderItem fails.

    OrderItemCarpet uses OrderItem ID as its Primary Key.

    OrderItemCarpet references existing OrderItem.

    Invalid OrderItem reference fails.

    Carpet dimensions cannot be zero.

    Carpet dimensions cannot be negative.

    Carpet Size reference may be null.

    Historical dimensions remain unchanged.

---

## 165. Payment Tests

The implementation must test:

    Positive Payment succeeds.

    Zero Payment fails.

    Negative Payment fails.

    Valid Payment belongs to existing Order.

    Invalid Order reference fails.

    Multiple Payments for same Order are allowed.

    Payment history remains preserved.

    Overpayment is rejected by the appropriate business operation.

---

## 166. Expense Tests

The implementation must test:

    Positive Expense succeeds.

    Zero Expense fails.

    Negative Expense fails.

    Expense must reference valid Category.

    Other Expense requires Expense Name.

    Historical Category snapshot remains stable.

---

## 167. Customer Tests

The implementation must test:

    Customer creation.

    Duplicate phone rejection.

    Customer lookup by ID.

    Customer lookup by phone.

    Customer search by name.

    Customer search by phone.

    Customer update.

---

## 168. Order Tests

The implementation must test:

    Order creation.

    Unique Order Number.

    Invalid Customer reference rejected.

    Valid Order status persisted.

    Invalid status rejected.

    Required Expected Pickup Date.

    Independent Pickup/Delivery flags.

    Both Pickup and Delivery may be true.

    Non-negative delivery fees.

---

## 169. Order Transaction Tests

The implementation must test:

    Failed Order creation
        ↓
    No partial Order remains

    Failed OrderItem creation
        ↓
    No partial aggregate remains

    Failed Carpet creation
        ↓
    Order transaction rolls back

    SyncOperation creation failure where applicable
        ↓
    Business transaction rolls back

---

## 170. Migration Tests

Every migration must test:

    Existing data preserved.

    Existing UUIDs preserved.

    Existing Orders preserved.

    Existing Payments preserved.

    Existing Expenses preserved.

    Existing StorageRecords preserved.

    Existing master data preserved.

    Historical snapshots preserved.

    New constraints become active.

---

## 171. Database Test Environment

Database tests should use an isolated test database.

Tests must not depend on:

    Production database
    User data
    Network availability
    Supabase
    External APIs

Database tests must be deterministic.

---

## 172. Repository Tests

Repository tests should verify:

    Correct persistence
    Correct query results
    Correct transaction behavior
    Correct error translation
    Correct historical data preservation
    Correct pagination
    Correct filtering

Repositories must be tested against the real Drift/SQLite behavior rather than only mocked method calls where database behavior itself is under test.

---

## 173. DAO Tests

DAO tests should cover:

    Insert
    Update
    Get by ID
    Search
    Filter
    Sorting
    Pagination
    Aggregation
    Constraint violations
    Relationships

Complex queries must have direct tests.

---

## 174. Query Performance

The implementation should prefer database-side operations for:

    COUNT
    SUM
    EXISTS
    JOIN
    filtering
    ordering
    pagination

Do not retrieve unnecessary records into Dart and calculate large aggregates in memory.

---

## 175. N+1 Query Avoidance

Repository/query implementations should avoid unnecessary N+1 query patterns.

Example:

Do not:

    Load 100 Orders
        ↓
    Query Customer for each Order

when an appropriate SQL JOIN can retrieve the required information efficiently.

The final query design should follow actual UI needs.

---

## 176. Reactive Queries

Drift reactive queries may be used where useful.

They are appropriate for data that should update automatically when local database state changes.

Examples:

    Dashboard
    Order lists
    Storage lists
    Customer lists

Reactive streams should not be used indiscriminately for one-time operations.

---

## 177. Write Operations

Write operations should normally use:

    Future

or equivalent one-shot persistence APIs.

Read operations may use:

    Future
    Stream

depending on whether reactive updates are required.

---

## 178. Data Conversion

Data conversion between:

    Drift Row
        ↔
    Domain Entity

must happen at the Data Layer boundary.

The Domain must receive domain-oriented objects.

The Domain must not receive generated Drift rows.

---

## 179. Companion Usage

Drift `Companion` objects should be used for inserts/updates as appropriate.

The implementation must clearly distinguish:

    Insert
    Update

and nullable fields requiring:

    Value.absent()
    Value(null)

according to Drift semantics.

Do not accidentally clear nullable fields during partial updates.

---

## 180. Partial Updates

Partial update operations must be intentional.

For example:

    Updating Customer name

must not accidentally clear:

    phone
    notes

unless the requested operation explicitly changes those values.

Repository APIs should make update semantics clear.

---

## 181. Full Aggregate Updates

Aggregate operations such as:

    Complete Order
    Cancel Order
    Move Storage

should not be implemented as unrelated individual writes from UI code.

They should use dedicated repository/data operations with explicit transactions.

---

## 182. Concurrency

The database implementation must assume that more than one asynchronous operation may attempt to modify local state.

Critical operations must rely on:

    SQLite transactions
    Database constraints

rather than only application-side pre-checks.

Example:

Checking:

    No Active StorageRecord

before inserting is not sufficient by itself.

The unique active-storage constraint must also exist.

---

## 183. Check-Then-Insert Safety

Application validation may perform:

    Exists?

checks for better error messages.

However, correctness must ultimately depend on:

    Database constraints

where the rule is structural.

Example:

    Check Customer phone
        +
    UNIQUE(phone)

Both should exist.

The application check improves UX.

The database constraint guarantees integrity.

---

## 184. Transaction Isolation

Multi-record operations must use Drift/SQLite transactions.

The implementation should not attempt to manually emulate transactions through flags or temporary application state.

---

## 185. Database Initialization Tests

Startup tests should verify:

    Database opens successfully.

    Foreign Keys are enabled.

    Schema is valid.

    Required tables exist.

    Required indexes exist.

    Seed initialization is safe.

    Migrations execute correctly.

---

## 186. Schema Verification

The implementation should periodically verify that generated Drift schema matches the approved database documentation.

Any mismatch must be resolved before proceeding to dependent implementation phases.

---

## 187. Documentation Consistency

The implementation must remain aligned with:

    tables.md
    relationships.md
    constraints.md
    indexes.md
    database-overview.md
    database-decisions.md
    data-layer.md

If an implementation detail requires changing the approved database model:

    Stop
        ↓
    Review Documentation
        ↓
    Approve Change
        ↓
    Update Source of Truth
        ↓
    Implement

Do not silently change the schema.

---

## 188. No Speculative Tables

The implementation must not create tables for:

    Drivers
    Vehicles
    Delivery Routes
    Delivery Tracking
    Loyalty
    Refunds
    Employee Permissions
    Multi-Branch
    Advanced Inventory
    Processing Stages
    Storage Capacity
    Barcode Workflow
    AI Assistant
    Advanced Analytics
    Profit Ledger
    Invoice Entity

These are outside approved V1 database scope.

---

## 189. No Speculative Columns

Do not add columns simply because they may be useful later.

Examples:

    driver_id
    branch_id
    vehicle_id
    loyalty_points
    barcode
    processing_stage
    storage_capacity
    refund_amount

must not be added without an approved requirement.

---

## 190. No Speculative Relationships

Do not introduce relationships between entities unless documented.

Examples:

    Expense → Order
    Payment → Customer
    StorageLocation → Service
    Order → Driver

must not be added without an approved domain/database decision.

---

## 191. No Generic Audit Table

V1 does not require a generic:

    audit_logs

table unless explicitly approved.

Historical business requirements are handled through:

    Transaction records
    Historical snapshots
    Timestamps
    Existing data model

Do not introduce a generic audit system speculatively.

---

## 192. No Generic Metadata Table

Do not create:

    metadata
    settings_values
    key_value_store

tables to avoid implementing the approved schema.

BusinessSettings must remain explicit.

---

## 193. No Generic Entity Table

Do not replace the relational schema with:

    entities
    records
    attributes
    JSON blobs

The approved relational model must remain explicit.

---

## 194. JSON Usage

JSON may be used only where explicitly approved.

The primary business data must remain relational.

Do not store complete Orders as JSON instead of:

    orders
    order_items
    payments
    storage_records

---

## 195. Historical Data Must Remain Queryable

Historical data must not be hidden inside opaque serialized blobs.

Reports and operational screens must be able to query:

    Orders
    OrderItems
    Payments
    Expenses
    StorageRecords

directly.

---

## 196. Financial Precision

All financial calculations must preserve exact integer minor-unit precision.

Example:

    10.25 EGP
        →
    1025

The implementation must not convert financial values through floating-point arithmetic unnecessarily.

---

## 197. Financial Aggregation

Financial aggregates should use integer arithmetic.

Examples:

    SUM(order_items.calculated_total)

    SUM(payments.amount)

    SUM(expenses.amount)

Results remain in minor units until the presentation formatting boundary.

---

## 198. Currency Formatting Boundary

Database and Domain calculations use numeric minor units.

Arabic display formatting such as:

    100.50 ج.م

belongs outside the database.

The database must not store formatted currency strings as the source of financial truth.

---

## 199. Arabic Data Support

The database must fully support Arabic text.

Relevant fields include:

    Customer.name
    Customer.notes
    Service.name
    Service.description
    ItemType.name
    ItemDefinition.name
    StorageLocation.name
    ExpenseCategory.name
    Expense.expense_name
    Expense.notes
    BusinessSettings.business_name
    BusinessSettings.address
    BusinessSettings.invoice_footer_text

SQLite text storage must support Unicode.

---

## 200. Database Does Not Control RTL

RTL layout is a Presentation concern.

The database stores text.

The database implementation must not embed:

    RTL formatting
    UI alignment
    typography
    display-specific formatting

inside persistence logic.

---

## 201. Database and Arabic Search

Search behavior must support Arabic text according to the approved application requirements.

The Data Layer should not assume that English-only normalization rules are sufficient.

Any specialized Arabic normalization/search behavior must be explicitly designed rather than silently introduced.

---

## 202. Local Date Handling

Business dates must be interpreted consistently with the application's configured local business timezone.

The database layer must not randomly mix:

    UTC timestamp
    Local timestamp
    Date-only values

without a defined purpose.

Date-only fields remain date-only.

---

## 203. Expected Pickup Queries

The Data Layer must support queries for:

    Today's Expected Pickups
    Upcoming Expected Pickups
    Orders by Expected Pickup Date

according to the approved UI/reporting requirements.

These queries must use:

    expected_pickup_date

rather than attempting to derive pickup date from:

    created_at

---

## 204. Overdue Order Queries

If the Dashboard/Orders requirements require overdue Orders, the Data Layer should support determining:

    Order not completed/cancelled
        +
    Expected Pickup Date before current business date

The exact business definition remains governed by the approved requirements.

---

## 205. Storage Screen Queries

Storage queries must support:

    Items requiring storage
    Items grouped by Storage Location
    Active storage assignments
    Item Type-aware location filtering

The Data Layer must expose query results in a form useful to the Storage feature.

---

## 206. Order Detail Query

The Order Detail data operation may need to retrieve:

    Order
    Customer
    OrderItems
    Item Definitions
    Services
    Carpet data
    Payments
    Storage information

The implementation should prefer appropriate joins or grouped queries instead of unnecessary repeated database calls.

---

## 207. Customer Detail Query

Customer detail may require:

    Customer
    Orders
    Order status
    Order totals
    Payment summaries

The implementation must avoid loading unrelated records.

---

## 208. Expense Report Query

Expense report queries must support:

    Date range
    Category
    Amount aggregation
    Expense name where applicable

The report must use:

    expenses.expense_date

as the Expense business date.

---

## 209. Payment Report Query

Payment reports may use:

    payments.paid_at

for timestamp/date filtering according to approved report rules.

Payments remain associated with:

    orders

through:

    payments.order_id

---

## 210. Order Sales Reporting

Sales reporting must use the approved Order reporting definition.

The implementation must not silently substitute:

    Payment total

for:

    Sales

unless the approved Financial Report definition explicitly requires it.

---

## 211. Data Integrity Priority

Implementation priorities are:

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

---

## 212. Implementation Sequence

The recommended implementation sequence is:

    1. Database foundation
    2. Database tables
    3. Relationships
    4. Constraints
    5. Indexes
    6. Database migrations
    7. Seed data
    8. DAOs
    9. Repository implementations
    10. Transaction operations
    11. Query/read models
    12. Database tests
    13. Repository tests
    14. Integration with Domain/Application

Do not start feature UI integration before the required Data Layer contracts are stable.

---

## 213. Database Foundation First

Before implementing feature repositories:

    AppDatabase
    Schema Version
    Foreign Key Enforcement
    Migration Foundation
    Generated Drift Code

must be working.

A broken database foundation must not be hidden behind feature-specific code.

---

## 214. Tables Before Repositories

The implementation should establish:

    Table definitions
        ↓
    Constraints
        ↓
    Indexes
        ↓
    Generated code

before building complex repositories.

This ensures repository behavior is built against the approved schema.

---

## 215. Constraints Before Business Integration

Structural constraints must be active before relying on repository behavior.

Examples:

    UNIQUE Customer Phone
    UNIQUE Order Number
    UNIQUE Service/ItemType
    UNIQUE StorageLocation/ItemType
    One Active StorageRecord
    One OrderItemCarpet

must not be implemented only as application checks.

---

## 216. Seed Data After Schema

Seed data must be inserted only after:

    Tables
    Constraints
    Foreign Keys
    Required Indexes

are available.

Seed initialization must follow:

    seed-data.md

---

## 217. Repository Integration

After database foundation:

    Domain Repository Contract
        ↓
    Data Repository Implementation
        ↓
    DAO
        ↓
    Drift Database

The Domain repository contract must not expose Drift-specific implementation details.

---

## 218. Testing Sequence

Recommended test order:

    Database opening
        ↓
    Table constraints
        ↓
    Foreign Keys
        ↓
    Unique constraints
        ↓
    Positive/non-negative constraints
        ↓
    Storage invariants
        ↓
    OrderItemCarpet invariant
        ↓
    Transactions
        ↓
    DAOs
        ↓
    Repositories
        ↓
    Feature integration

---

## 219. Completion Criteria

The database implementation is considered complete for this phase only when:

    AppDatabase works.

    Drift generation works.

    SQLite database opens.

    Foreign Keys are enforced.

    All approved V1 tables exist.

    Primary Keys are correct.

    OrderItemCarpet uses order_item_id as PK + FK.

    Required Foreign Keys exist.

    Required Unique constraints exist.

    Positive/non-negative constraints are implemented.

    One active StorageRecord constraint works.

    BusinessSettings single-row strategy works.

    Migrations are implemented.

    Seed data is implemented safely.

    Required indexes are implemented.

    DAOs are implemented.

    Repository implementations are connected.

    Required transactions are implemented.

    Database tests pass.

    Repository tests pass.

---

## 220. AI Coding Tool Rules

AI coding tools implementing this document must follow the approved documentation exactly.

The AI must not:

    Invent new tables.
    Invent new entities.
    Invent new relationships.
    Change UUID strategy.
    Change money representation.
    Change currency.
    Replace SQLite.
    Replace Drift.
    Introduce a mandatory Use Case layer.
    Introduce a generic Mapper layer.
    Add Delivery entities.
    Add Driver entities.
    Add Branch entities.
    Add Profit tables.
    Add Invoice tables.
    Add Analytics tables.
    Add Loyalty tables.
    Add Refund tables.
    Add Processing Stage tables.
    Add Storage Capacity tables.
    Add Barcode tables.
    Add AI tables.

---

## 221. AI Primary Key Rules

The AI must not:

    Add a separate id to order_item_carpets.

The approved identity is:

    order_item_carpets.order_item_id

which is:

    Primary Key
    +
    Foreign Key

The AI must not generate a second UUID for OrderItemCarpet.

---

## 222. AI Historical Data Rules

The AI must not:

    Replace historical OrderItem prices with current Service prices.

    Replace historical Service names.

    Replace historical Item Type names.

    Replace historical Item Definition names.

    Replace historical Expense Category names.

    Recalculate historical Carpet dimensions from current Carpet Sizes.

    Recalculate historical Order financial values from current configuration.

---

## 223. AI Transaction Rules

The AI must not implement multi-record business operations as independent writes when atomicity is required.

Required transactions include:

    Create Order
    Move Storage
    Complete Order
    Cancel Order
    Record Payment
    Create Expense

---

## 224. AI Constraint Rules

The AI must not bypass:

    UNIQUE constraints
    Foreign Keys
    Positive value constraints
    One active StorageRecord constraint
    One OrderItemCarpet constraint

Application-level validation may improve errors.

It must not replace database-level structural integrity.

---

## 225. AI Migration Rules

The AI must not:

    Modify production schema without migration.

    Delete historical data during migration.

    Regenerate entity IDs.

    Reset user-created master data.

    Drop tables without an explicitly approved migration.

    Change historical transaction values.

Every schema change must have a migration.

---

## 226. AI Scope Rules

If the AI encounters an unclear requirement:

    Do not guess.

Instead:

    Check Source-of-Truth Documentation
        ↓
    Check Domain Model
        ↓
    Check Database Decisions
        ↓
    Check Constraints
        ↓
    Check Architecture
        ↓
    If still unclear:
        Stop and report the ambiguity

The AI must not invent behavior to make implementation easier.

---

## 227. AI Completion Report

At the end of database implementation, the AI coding tool must provide an explicit completion report.

The report must include:

    Implementation Status

    Files Created

    Files Modified

    Database Tables Implemented

    DAOs Implemented

    Repositories Implemented

    Migrations Implemented

    Indexes Implemented

    Constraints Implemented

    Transactions Implemented

    Seed Data Status

    Tests Added

    Tests Passed

    Code Generation Status

    Remaining Issues

    Deferred Items

    Documentation Deviations

If there are no deviations:

    Documentation Deviations:
    None

If something could not be implemented:

    Remaining Issues:
    <explicit list>

The AI must not report completion if required database work remains incomplete.

---

## 228. Completion Report — Required Detail

The completion report must explicitly confirm:

    SQLite = Implemented

    Drift = Implemented

    Foreign Keys = Enabled

    UUID Strategy = Preserved

    Integer Minor-Unit Money = Preserved

    OrderItemCarpet PK = order_item_id

    OrderItemCarpet FK = order_items.id

    One Active StorageRecord = Enforced

    Historical Snapshots = Preserved

    Historical Pricing = Preserved

    Migrations = Implemented

    Required Indexes = Implemented

    Required Tests = Passing

---

## 229. Deferred Implementation

The following must remain deferred after this phase:

    Supabase backend implementation
    Supabase Edge Functions
    Dio client
    Retrofit client
    Remote synchronization execution
    Conflict resolution
    Multi-device synchronization
    Remote authentication integration
    Remote API retry worker

The local database must be synchronization-ready but must not pretend that remote synchronization is implemented.

---

## 230. Final Database Architecture

The final local architecture is:

    Flutter Application
            ↓
    Presentation
            ↓
    Application / Domain
            ↓
    Repository Contract
            ↓
    Repository Implementation
            ↓
    DAO / Query Layer
            ↓
    Drift
            ↓
    SQLite
            ↓
    Local Database

Future remote synchronization will extend the Data Layer without changing the Domain dependency direction.

---

## 231. Final Database Identity Model

The default identity model is:

    Entity
        ↓
    UUID
        ↓
    SQLite TEXT Primary Key

Except:

    OrderItemCarpet
        ↓
    order_item_id
        ↓
    Primary Key + Foreign Key

This exception is intentional and approved.

---

## 232. Final Storage Model

Storage is represented by:

    OrderItem
        ↓
    StorageRecord
        ↓
    StorageLocation

with:

    Maximum One Active StorageRecord
        per OrderItem

Historical StorageRecords remain preserved.

---

## 233. Final Carpet Model

Carpet-specific data is represented by:

    OrderItem
        ↓
    0..1 OrderItemCarpet

with:

    OrderItemCarpet.order_item_id
        =
    Primary Key
        +
    Foreign Key

Historical dimensions are stored directly on OrderItemCarpet.

---

## 234. Final Financial Model

Financial data is represented by:

    Order
        ↓
    Order financial totals

    OrderItem
        ↓
    Historical transaction prices

    Payment
        ↓
    Customer money received

    Expense
        ↓
    Business operating cost

Derived:

    Remaining Amount
    Net Profit

No dedicated persistent tables are required for:

    Remaining Amount
    Net Profit
    Invoice

---

## 235. Final Historical Data Model

Master data:

    Current Configuration

Transaction data:

    Historical Snapshot

Therefore:

    Service.price
        ≠
    OrderItem.unit_price

and:

    Service.name
        ≠
    Historical service_name_snapshot

and:

    ExpenseCategory.name
        ≠
    Historical category_name_snapshot

and:

    CarpetSize
        ≠
    Historical OrderItemCarpet dimensions

---

## 236. Final Offline-first Model

The approved local flow is:

    User Action
        ↓
    Domain Validation
        ↓
    Local Database Transaction
        ↓
    UI Updated
        ↓
    SyncOperation persisted
        ↓
    Future Remote Synchronization

The local database must not wait for the network.

---

## 237. Final Implementation Principle

The database implementation must be:

    Correct
        +
    Transactional
        +
    Offline-first
        +
    Historically safe
        +
    Financially precise
        +
    Synchronization-ready
        +
    Maintainable
        +
    Simple

The implementation must reflect the approved business model rather than introducing new business behavior.

---

## 238. Final Approved Database Contract

The implementation must preserve these final decisions:

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
    Offline-first local operation
        +
    Stable historical transaction values
        +
    Relational Foreign Keys
        +
    Explicit database constraints
        +
    Transactional multi-record operations
        +
    Item Type-aware Storage
        +
    Independent Pickup and Delivery
        +
    Independent Expenses
        +
    Derived financial metrics
        +
    No speculative V1 tables
        +
    No destructive historical deletion
        +
    Future synchronization readiness

For OrderItemCarpet specifically:

    OrderItem
        |
        | 1
        |
        | 0..1
        ↓
    OrderItemCarpet

with:

    OrderItemCarpet.order_item_id
        =
    Primary Key
        +
    Foreign Key
        →
    OrderItem.id

This is the final approved database implementation contract for the V1 local Flutter implementation.