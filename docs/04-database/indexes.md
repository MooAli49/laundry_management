# Laundry Management System — Database Indexes

## 1. Document Purpose

This document defines the approved V1 database indexes for the Laundry Management System.

The purpose of database indexes is to improve query performance for the application's main operational workflows without introducing unnecessary indexes.

The index strategy must support:

    SQLite
        +
    Drift
        +
    Offline-first local operation

Indexes are designed around the application's actual query patterns, including:

- Customer search.
- Order lookup.
- Order filtering.
- Order status filtering.
- Order date filtering.
- Payment history.
- Storage operations.
- Items requiring storage.
- Storage filtering by Item Type.
- Service and Item Type compatibility.
- Expense reporting.
- Expense Category filtering.
- Financial reports.
- Dashboard queries.
- Synchronization queue processing.

This document must remain aligned with:

    docs/01-product/
    docs/02-domain/
    docs/03-architecture/
    docs/04-database/database-overview.md
    docs/04-database/tables.md
    docs/04-database/relationships.md
    docs/04-database/constraints.md

---

## 2. Indexing Philosophy

Indexes should exist because a query needs them.

The database must not create indexes on every column by default.

The strategy is:

    Required Query
        ↓
    Identify Filter / Join
        ↓
    Add Targeted Index
        ↓
    Avoid Redundant Indexes

Indexes must provide meaningful performance benefits for common V1 operations.

---

## 3. Primary Key Indexes

Every Primary Key automatically provides an index through SQLite.

The following Primary Keys therefore do not require separate manual indexes:

    customers.id
    orders.id
    order_items.id
    payments.id
    storage_locations.id
    storage_records.id
    item_types.id
    item_definitions.id
    services.id
    service_item_types.id
    storage_location_item_types.id
    carpet_sizes.id
    order_item_carpets.id
    expense_categories.id
    expenses.id
    business_settings.id
    sync_operations.id

No duplicate manual index should be created on a Primary Key column.

---

## 4. Unique Constraint Indexes

Unique constraints normally create the required uniqueness structure.

The following unique fields should therefore not receive duplicate standalone indexes unless query analysis proves a separate index necessary:

    customers.phone
    orders.order_number
    storage_locations.name
    item_types.name
    services.name
    expense_categories.name

For composite unique relationships:

    item_definitions.item_type_id
    +
    item_definitions.name

    service_item_types.service_id
    +
    service_item_types.item_type_id

    storage_location_item_types.storage_location_id
    +
    storage_location_item_types.item_type_id

The unique constraint/index itself should be preferred over an additional duplicate index.

---

## 5. Customer Indexes

Customers are frequently searched by phone number.

### Customer Phone

Required:

    INDEX customers(phone)

If:

    customers.phone

is already implemented as a UNIQUE constraint, the unique index satisfies this requirement.

No additional duplicate index should be created.

### Customer Name

Customer name search is a common UI operation.

Recommended:

    INDEX customers(name)

This supports:

    Search Customers by Name

and improves ordered/filtering queries involving the Customer name.

---

## 6. Customer Updated At Index

Customer synchronization and administrative queries may need recently changed records.

Recommended:

    INDEX customers(updated_at)

This supports:

    Fetch Customers Changed Since Timestamp

for synchronization or incremental data operations.

If synchronization implementation does not query by updated_at, this index may be omitted.

---

## 7. Order Indexes

Orders are one of the most frequently queried tables in the system.

The index strategy must support:

    Order List
    Order Search
    Order Details
    Order Status Filtering
    Order Date Filtering
    Customer Order History
    Dashboard Metrics
    Financial Reports

---

## 8. Order Customer Index

Required:

    INDEX orders(customer_id)

This supports:

    Customer
        ↓
    Orders

Examples:

    View Customer Order History

    Fetch Orders for Customer

The Foreign Key relationship itself does not remove the need for an application query index.

---

## 9. Order Status Index

Required:

    INDEX orders(status)

This supports operational queries such as:

    Processing Orders

    Ready Orders

    Completed Orders

    Cancelled Orders

It also supports Dashboard queries based on Order status.

---

## 10. Order Expected Pickup Date Index

Required:

    INDEX orders(expected_pickup_date)

This supports:

    Orders by Expected Pickup Date

and Dashboard/report queries involving upcoming pickup dates.

---

## 11. Composite Order Status / Pickup Index

Recommended:

    INDEX orders(status, expected_pickup_date)

This supports common operational queries such as:

    Ready Orders
        +
    Expected Pickup Date

and:

    Processing Orders
        +
    Expected Pickup Date

The composite index should only be added if these combined queries are used frequently.

Because SQLite can use the leftmost column of a composite index, this index may also reduce the need for a separate:

    status

index depending on the final query patterns.

The implementation should avoid redundant indexes after query review.

---

## 12. Order Created At Index

Required:

    INDEX orders(created_at)

This supports:

    Recent Orders

    Today's Orders

    Orders by Creation Date

    Dashboard operational metrics

    Date-based reporting where Order creation date is the reporting basis.

---

## 13. Order Updated At Index

Recommended:

    INDEX orders(updated_at)

This supports:

    Incremental Synchronization

    Recently Updated Orders

    Local change detection

If synchronization queries are not based on updated_at, this index may be omitted.

---

## 14. Order Delivery Indexes

V1 supports two independent delivery directions:

    delivery_to_laundry_requested

    delivery_to_customer_requested

These values are normally low-cardinality Boolean fields.

Standalone indexes on Boolean fields are generally not useful by themselves.

Therefore:

    Do not automatically create:


unless actual query profiling demonstrates a meaningful benefit.

Delivery fees are financial fields and do not require standalone indexes.

---

## 15. OrderItem Indexes

OrderItems are heavily accessed through their parent Order and through Storage operations.

---

## 16. OrderItem Order Index

Required:

    INDEX order_items(order_id)

This supports:

    Order
        ↓
    OrderItems

Examples:

    Load Order Details

    Load Invoice Items

    Calculate Order Item Totals

    Load all physical items for an Order

---

## 17. OrderItem Item Type Index

Required:

    INDEX order_items(item_type_id)

This supports:

    Item Type filtering

    Storage workflows

    Item Type-based reporting

    Item Type-based queries

---

## 18. OrderItem Service Index

Recommended:

    INDEX order_items(service_id)

This supports:

    Service-based reporting

    Service-related queries

    Historical transaction analysis

If Service-based reporting is not queried frequently, this index can be reviewed during implementation.

---

## 19. OrderItem Item Definition Index

Recommended:

    INDEX order_items(item_definition_id)

This supports:

    Item Definition filtering

    Item Definition reporting

The index is particularly useful when Item Definitions are frequently used in operational searches.

---

## 20. OrderItem Composite Order / Item Type Index

Recommended:

    INDEX order_items(order_id, item_type_id)

This supports queries such as:

    Load Order Items
        +
    Filter by Item Type

It may be unnecessary if the application's actual queries use only:

    order_id

or:

    item_type_id

The final implementation should avoid redundant indexes.

---

## 21. Payment Indexes

Payments are queried primarily by Order and payment date.

---

## 22. Payment Order Index

Required:

    INDEX payments(order_id)

This supports:

    Order
        ↓
    Payments

Examples:

    Load Order Payments

    Calculate Remaining Amount

    Display Payment History

---

## 23. Payment Paid At Index

Required:

    INDEX payments(paid_at)

This supports:

    Payments by Date

    Daily Payment Reporting

    Financial Reports

    Dashboard Payment Metrics

---

## 24. Composite Payment Order / Paid At Index

Recommended:

    INDEX payments(order_id, paid_at)

This supports:

    Payment History for an Order
        +
    Chronological Ordering

If this composite index is used, a separate:

    INDEX payments(order_id)

may become unnecessary depending on the query planner and actual queries.

The implementation should avoid duplicate indexing.

---

## 25. Storage Location Indexes

Storage Locations are master data.

Their names are unique, so the unique constraint provides the lookup index.

No additional index is required on:

    storage_locations.name

if the column already has a UNIQUE constraint.

---

## 26. Storage Location Active Index

Required for operational filtering:

    INDEX storage_locations(is_active)

This supports:

    Active Storage Locations

and:

    Inactive Storage Locations

The application frequently needs to distinguish locations available for new storage operations from historical/inactive locations.

---

## 27. Storage Record Indexes

StorageRecords are central to:

    Current Storage
    Items Requiring Storage
    Storage Movement
    Order Completion
    Order Cancellation

---

## 28. Storage Record Order Item Index

Required:

    INDEX storage_records(order_item_id)

This supports:

    OrderItem
        ↓
    StorageRecord

Examples:

    Get Current Storage for Item

    Check Whether Item Is Stored

    Load Storage History

---

## 29. Active Storage Partial Unique Index

Required:

    UNIQUE INDEX
        storage_records(order_item_id)
        WHERE is_active = true

This is one of the most important indexes in the database.

It guarantees:

    One OrderItem
        →
    Maximum One Active StorageRecord

It prevents:

    Same OrderItem
        +
    Two Active StorageRecords

from existing simultaneously.

This is both:

    Integrity Constraint

and:

    Query Optimization

The exact SQLite/Drift syntax must follow the supported implementation.

---

## 30. Storage Record Location Index

Required:

    INDEX storage_records(storage_location_id)

This supports:

    Storage Location
        ↓
    Stored Items

Examples:

    Show Items in Location A

    Count Items in Location A

    Load all active items in a Storage Location

---

## 31. Storage Record Active Index

Required:

    INDEX storage_records(is_active)

This supports current-storage queries.

However, because:

    is_active

is a low-cardinality Boolean field, the preferred implementation is often a composite/partial index rather than a standalone Boolean index.

---

## 32. Storage Record Location / Active Index

Required:

    INDEX storage_records(storage_location_id, is_active)

This supports:

    Active Items in a Specific Storage Location

Example:

    Storage Location = Shelf A
        +
    is_active = true

This is a high-value operational query.

---

## 33. Storage Record Item / Active Index

The partial unique index:

    UNIQUE INDEX
        storage_records(order_item_id)
        WHERE is_active = true

already supports:

    Find Active Storage for OrderItem

Therefore, a separate:

    INDEX storage_records(order_item_id, is_active)

is not required unless query profiling demonstrates a need.

---

## 34. Item Type Indexes

Item Types are master data.

The unique name constraint provides:

    Item Type Name Lookup

No duplicate standalone name index should be created if uniqueness is already implemented.

---

## 35. Item Type Active Index

Required:

    INDEX item_types(is_active)

This supports:

    Active Item Types

for:

    New Order

    Storage

    Settings

    Filtering

---

## 36. Item Definition Indexes

Item Definitions are accessed primarily by Item Type.

---

## 37. Item Definition Item Type Index

Required:

    INDEX item_definitions(item_type_id)

This supports:

    ItemType
        ↓
    ItemDefinitions

Examples:

    Show Blanket Types

    Show Carpet Types

    Filter Item Definitions by Item Type

---

## 38. Item Definition Active Index

Recommended:

    INDEX item_definitions(is_active)

This supports:

    Active Item Definitions

If most queries combine:

    item_type_id
    +
    is_active

the preferred index may instead be:

    INDEX item_definitions(item_type_id, is_active)

---

## 39. Item Definition Composite Index

Recommended for common selection queries:

    INDEX item_definitions(item_type_id, is_active)

This supports:

    Get Active Item Definitions
        for a Specific Item Type

This is more useful than indexing Boolean:

    is_active

alone when the UI normally selects definitions within a specific Item Type.

---

## 40. Service Indexes

Services are master data.

Service names are unique.

The unique name constraint provides:

    Service Name Lookup

No duplicate standalone name index should be created.

---

## 41. Service Active Index

Required:

    INDEX services(is_active)

This supports:

    Active Services

for:

    New Order

    Pricing Management

    Settings

---

## 42. Service Pricing Type Index

Recommended:

    INDEX services(pricing_type)

This supports queries that group/filter Services by:

    Per Piece
    Per KG
    Per Square Meter
    Fixed Price

If pricing type is not used as a query filter, this index may be omitted.

---

## 43. Service Updated At Index

Recommended:

    INDEX services(updated_at)

This supports:

    Incremental Synchronization

    Recently Changed Services

If synchronization is not based on updated_at, the index may be omitted.

---

## 44. Service Item Type Indexes

The junction table:

    service_item_types

is used to validate and query Service / Item Type compatibility.

---

## 45. Service Item Type Service Index

Required:

    INDEX service_item_types(service_id)

This supports:

    Service
        ↓
    Supported Item Types

---

## 46. Service Item Type Item Type Index

Required:

    INDEX service_item_types(item_type_id)

This supports:

    Item Type
        ↓
    Supported Services

Both directions are operationally useful.

---

## 47. Service Item Type Composite Unique Index

Required:

    UNIQUE INDEX
        service_item_types(service_id, item_type_id)

This prevents duplicate compatibility records.

The unique index also supports:

    Check Service + Item Type Compatibility

---

## 48. Storage Location Item Type Indexes

The junction table:

    storage_location_item_types

controls which Storage Locations can accept which Item Types.

---

## 49. Storage Location Item Type Location Index

Required:

    INDEX storage_location_item_types(storage_location_id)

This supports:

    Storage Location
        ↓
    Compatible Item Types

---

## 50. Storage Location Item Type Item Index

Required:

    INDEX storage_location_item_types(item_type_id)

This supports:

    Item Type
        ↓
    Compatible Storage Locations

This is particularly important for:

    Storage UI filtering

---

## 51. Storage Location Item Type Composite Unique Index

Required:

    UNIQUE INDEX
        storage_location_item_types(
            storage_location_id,
            item_type_id
        )

This prevents duplicate compatibility relationships.

---

## 52. Carpet Size Indexes

Carpet Sizes are master data.

The current CarpetSize entity does not define a name field.

Therefore, no name-based index is required for V1.

---

## 53. Carpet Size Active Index

Required:

    INDEX carpet_sizes(is_active)

This supports:

    Active Carpet Sizes

for new Carpet OrderItems.

If the UI always queries active sizes only, this index is useful.

---

## 54. OrderItem Carpet Indexes

OrderItemCarpet contains historical carpet-specific information.

---

## 55. OrderItem Carpet Order Item Index

Required:

    UNIQUE INDEX
        order_item_carpets(order_item_id)

Because:

    One OrderItem
        →
    Maximum One OrderItemCarpet

The unique index both enforces the relationship and provides lookup performance.

---

## 56. OrderItem Carpet Size Index

Recommended:

    INDEX order_item_carpets(carpet_size_id)

This supports:

    Reporting by predefined Carpet Size

and:

    Historical queries involving Carpet Size

The column remains nullable because custom carpet dimensions are supported.

---

## 57. Expense Category Indexes

Expense Categories are configurable master data.

---

## 58. Expense Category Name Index

The category name must be unique.

Therefore:

    UNIQUE INDEX
        expense_categories(name)

provides:

    Category Name Lookup
    Duplicate Prevention

No additional standalone name index is required.

---

## 59. Expense Category Active Index

Required:

    INDEX expense_categories(is_active)

This supports:

    Active Expense Categories

for:

    Add Expense

    Edit Expense

    Settings

---

## 60. Expense Category Updated At Index

Recommended:

    INDEX expense_categories(updated_at)

This supports synchronization and change detection when category configuration is synchronized.

If the synchronization implementation does not query by updated_at, this index may be omitted.

---

## 61. Expense Indexes

Expenses are a major new financial transaction type.

The database must support:

    Daily Expenses

    Expenses by Date Range

    Expenses by Category

    Financial Reports

    Dashboard Expense Metrics

    Net Profit Calculation

---

## 62. Expense Category Foreign Key Index

Required:

    INDEX expenses(expense_category_id)

This supports:

    Expense Category
        ↓
    Expenses

and:

    Expenses by Category

---

## 63. Expense Date Index

Required:

    INDEX expenses(expense_date)

This is one of the most important Expense indexes.

It supports:

    Today's Expenses

    Expenses for Selected Date

    Expenses for Date Range

    Monthly Expenses

    Financial Reports

    Net Profit Calculation

The Financial Report uses:

    expense_date

as the Expense business date.

---

## 64. Expense Category / Date Composite Index

Recommended:

    INDEX expenses(expense_category_id, expense_date)

This supports:

    Expenses for Category
        +
    Selected Date / Date Range

Example:

    Category = Cleaning Supplies
        +
    August 2026

The exact final index strategy should be validated against actual report queries.

---

## 65. Expense Date / Category Composite Index

If the dominant query pattern is:

    Date Range
        +
    Group by Category

the preferred index may instead be:

    INDEX expenses(expense_date, expense_category_id)

Only one of:

    (expense_category_id, expense_date)

or:

    (expense_date, expense_category_id)

should normally be created unless profiling demonstrates that both are necessary.

The final choice should follow actual query patterns.

---

## 66. Expense Created At Index

Recommended:

    INDEX expenses(created_at)

This supports:

    Recently Created Expenses

    Synchronization

    Local audit/debugging

If Expense reporting never uses created_at and synchronization uses another mechanism, this index may be omitted.

---

## 67. Expense Updated At Index

Recommended:

    INDEX expenses(updated_at)

This supports:

    Incremental Synchronization

    Recently Updated Expenses

If synchronization does not query by updated_at, this index may be omitted.

---

## 68. Expense Name Search

Expense Name is primarily used when:

    Expense Category = Other

Expense Name does not require a standalone index for V1.

The expected dataset is small and the primary reporting/filtering dimension is:

    expense_date

and:

    expense_category_id

---

## 69. Business Settings Indexes

V1 has a single BusinessSettings record.

The Primary Key is sufficient.

No additional indexes are required.

The application must use the single approved settings record.

---

## 70. Synchronization Indexes

The synchronization queue requires efficient access to pending operations.

The main queries are:

    Get Pending Operations

    Get Failed Operations

    Retry Operations

    Get Operations for Entity

    Process Operations in Order

---

## 71. Sync Status Index

Required:

    INDEX sync_operations(status)

This supports:

    Pending
    Processing
    Synced
    Failed

queue filtering.

---

## 72. Sync Status / Created At Index

Required:

    INDEX sync_operations(status, created_at)

This supports:

    Get Pending Operations
        ordered by creation time

and:

    Get Failed Operations
        ordered by creation time

This is preferred over relying on a standalone status index when the queue query also orders/filters by created_at.

---

## 73. Sync Entity Index

Required:

    INDEX sync_operations(entity_type, entity_id)

This supports:

    Find Synchronization Operations
        for a Specific Entity

Examples:

    Order
    Customer
    Payment
    Expense
    StorageRecord

The combination must not be globally unique.

An entity may have multiple synchronization operations.

---

## 74. Sync Updated At Index

Recommended:

    INDEX sync_operations(updated_at)

This supports:

    Recently Changed Sync Operations

and internal synchronization maintenance.

If not used by the final sync worker, it may be omitted.

---

## 75. Sync Retry Index

No standalone index is required on:

    retry_count

Retry count is normally evaluated together with:

    status

Therefore, if a query requires it, the preferred index should be composite with status rather than indexing retry_count alone.

---

## 76. Dashboard Query Support

Dashboard queries should be supported by existing transactional indexes.

Common Dashboard queries include:

    Today's Orders

    Processing Orders

    Ready Orders

    Orders Requiring Storage

    Today's Payments

    Today's Expenses

    Remaining Amount

    Sales for Selected Period

The relevant indexes are:

    orders.created_at
    orders.status
    orders.expected_pickup_date
    payments.paid_at
    expenses.expense_date
    storage_records.is_active

and their appropriate composite/partial indexes.

No dedicated Dashboard table is required.

---

## 77. Orders Requiring Storage Query

The Dashboard and Storage workflows need to identify physical items without active storage.

The conceptual query is:

    OrderItems
        LEFT JOIN
    Active StorageRecords

where:

    Active StorageRecord does not exist

The key index supporting this workflow is:

    UNIQUE INDEX
        storage_records(order_item_id)
        WHERE is_active = true

The query may also benefit from:

    INDEX order_items(order_id)

and:

    INDEX order_items(item_type_id)

---

## 78. Storage Filtering by Item Type

The Storage UI must be able to filter compatible Storage Locations based on Item Type.

The query path is:

    ItemType
        ↓
    storage_location_item_types
        ↓
    StorageLocation

Required indexes:

    storage_location_item_types(item_type_id)

    storage_location_item_types(storage_location_id)

and:

    storage_locations(is_active)

This allows the application to efficiently show:

    Active Storage Locations
        compatible with selected Item Type

---

## 79. Financial Report Query Support

The Financial Report uses multiple transaction sources.

Primary sources:

    orders
    payments
    expenses

The main date indexes are:

    orders.created_at
    payments.paid_at
    expenses.expense_date

The Expense Report specifically relies on:

    expenses.expense_date

for date-range filtering.

---

## 80. Net Profit Query Support

Net Profit is derived.

Conceptually:

    Total Sales
        -
    Total Operating Expenses
        =
    Net Profit

Expenses must therefore be efficiently filtered by:

    expense_date

The primary index is:

    INDEX expenses(expense_date)

No:

    net_profit

table or index is required.

---

## 81. Payment Reporting Query Support

Payment reports use:

    payments.paid_at

and:

    payments.order_id

Recommended indexes:

    payments(order_id)

    payments(paid_at)

If payment history queries always combine Order and time:

    payments(order_id, paid_at)

may be preferred.

---

## 82. Order Search Strategy

Order search may include:

    Order Number
    Customer Name
    Customer Phone

The following indexes support the underlying queries:

    orders.order_number
    orders.customer_id
    customers.name
    customers.phone

Order Number is unique and therefore already indexed through its uniqueness constraint.

Customer Phone is unique and therefore already indexed through its uniqueness constraint.

---

## 83. Search Index Limitations

SQLite V1 does not require advanced full-text search infrastructure.

The application should begin with normal indexed queries.

Do not introduce:

    FTS5

or another full-text search system unless actual V1 search requirements justify it.

---

## 84. Pagination Support

The application uses pagination for large lists.

Indexes should support:

    WHERE
        filters

    ORDER BY
        stable timestamp / identifier

    LIMIT
        page_size

Common examples:

    Orders
        ORDER BY created_at DESC

    Payments
        ORDER BY paid_at DESC

    Expenses
        ORDER BY expense_date DESC

    Customers
        ORDER BY name

The final query should be checked against the index strategy.

---

## 85. Stable Pagination

Pagination should use stable ordering.

When ordering by timestamps, a stable secondary key may be required.

Example:

    ORDER BY
        created_at DESC,
        id DESC

For large datasets, a composite index may be considered:

    INDEX orders(created_at, id)

if actual pagination queries use this ordering.

The same approach may be used for:

    payments
    expenses

when required by implementation.

---

## 86. Indexes and Sorting

Indexes can help both:

    Filtering

and:

    Sorting

Therefore common list queries should be designed together with their indexes.

Example:

    Expenses
        WHERE expense_date BETWEEN X AND Y
        ORDER BY expense_date DESC

is naturally supported by:

    INDEX expenses(expense_date)

---

## 87. Avoiding Redundant Indexes

The implementation must not create multiple indexes that serve the same query pattern without a demonstrated reason.

Examples of unnecessary duplication:

    UNIQUE orders(order_number)
    +
    INDEX orders(order_number)

or:

    UNIQUE expense_categories(name)
    +
    INDEX expense_categories(name)

The unique index already provides lookup performance.

---

## 88. Foreign Key Index Rule

Foreign Key columns used for joins or parent-child queries should normally have indexes.

Important examples:

    orders.customer_id

    order_items.order_id

    order_items.item_type_id

    order_items.service_id

    payments.order_id

    storage_records.order_item_id

    storage_records.storage_location_id

    item_definitions.item_type_id

    service_item_types.service_id

    service_item_types.item_type_id

    storage_location_item_types.storage_location_id

    storage_location_item_types.item_type_id

    order_item_carpets.order_item_id

    order_item_carpets.carpet_size_id

    expenses.expense_category_id

---

## 89. Boolean Index Rule

Boolean columns generally have low selectivity.

Therefore standalone indexes should not be created automatically for every:

    is_active

or:

    *_requested

column.

Prefer:

    Composite Index

or:

    Partial Index

when the actual query benefits from it.

Examples:

    storage_records(order_item_id)
        WHERE is_active = true

    storage_records(storage_location_id, is_active)

    item_definitions(item_type_id, is_active)

---

## 90. Partial Index Strategy

SQLite partial indexes should be used when they provide a clear benefit.

The most important V1 partial index is:

    UNIQUE INDEX
        storage_records(order_item_id)
        WHERE is_active = true

This directly represents the business integrity rule:

    One OrderItem
        →
    Maximum One Active StorageRecord

Other partial indexes may be introduced only when justified by actual query patterns.

---

## 91. Indexes for Historical Data

Historical records must remain queryable after master-data deactivation.

Indexes must therefore not depend on:

    is_active = true

for historical transaction tables unless the query specifically requires current records.

Examples:

    Historical Expenses
        ↓
    Query by expense_date

    Historical Payments
        ↓
    Query by paid_at

    Historical OrderItems
        ↓
    Query by order_id

Historical data must remain efficiently accessible.

---

## 92. Indexes for Active Master Data

Master-data selection screens commonly query:

    WHERE is_active = true

Relevant indexes include:

    item_types(is_active)

    item_definitions(item_type_id, is_active)

    services(is_active)

    carpet_sizes(is_active)

    storage_locations(is_active)

    expense_categories(is_active)

These indexes support the active-only selection behavior required by V1.

---

## 93. Expense Category Management Queries

Expense Category management requires:

    List Categories

    Search Category

    Show Active Categories

    Show Inactive Categories

    Create Category

    Edit Category

The main indexes are:

    UNIQUE expense_categories(name)

    INDEX expense_categories(is_active)

The system does not require a separate Category usage counter table.

---

## 94. Storage Location Management Queries

Storage Location management requires:

    List Locations

    Show Active Locations

    Show Inactive Locations

    Filter Locations by Item Type

The relevant indexes are:

    UNIQUE storage_locations(name)

    INDEX storage_locations(is_active)

    INDEX storage_location_item_types(storage_location_id)

    INDEX storage_location_item_types(item_type_id)

---

## 95. Service Management Queries

Service management requires:

    List Services

    Show Active Services

    Filter by Pricing Type

    Find Supported Item Types

The relevant indexes are:

    UNIQUE services(name)

    INDEX services(is_active)

    INDEX services(pricing_type)

    INDEX service_item_types(service_id)

    INDEX service_item_types(item_type_id)

---

## 96. Customer Management Queries

Customer management requires:

    Search by Phone

    Search by Name

    Open Customer

    Load Customer Orders

The relevant indexes are:

    UNIQUE customers(phone)

    INDEX customers(name)

    INDEX orders(customer_id)

---

## 97. Order Management Queries

Order management requires:

    Search by Order Number

    Filter by Status

    Filter by Expected Pickup Date

    Filter by Customer

    Load Order Items

    Load Payments

The relevant indexes are:

    UNIQUE orders(order_number)

    INDEX orders(customer_id)

    INDEX orders(status)

    INDEX orders(expected_pickup_date)

    INDEX order_items(order_id)

    INDEX payments(order_id)

---

## 98. Invoice Query Support

Invoice generation loads:

    Customer
    Order
    OrderItems
    Payments
    BusinessSettings

The main supporting indexes are:

    orders.id

    order_items(order_id)

    payments(order_id)

Primary Key indexes already support:

    Customer
    Order
    BusinessSettings

No dedicated Invoice index is required because V1 does not introduce an invoices table.

---

## 99. Expense Invoice Independence

Expenses do not belong to Orders.

Therefore:

    expenses

must not have:

    order_id

and no index should be created for a non-existent Order relationship.

Expense indexes are based on:

    expense_category_id
    expense_date
    created_at
    updated_at

---

## 100. Delivery Query Support

Customer Pickup and Customer Delivery are independent Order-level options.

Because these are Boolean values:

    delivery_to_laundry_requested

    delivery_to_customer_requested

they do not require standalone indexes by default.

Delivery fees also do not require indexes because they are not used as primary filtering dimensions.

---

## 101. Financial Amount Indexes

The following fields should not receive standalone indexes by default:

    orders.subtotal
    orders.discount
    orders.tax
    orders.total
    orders.customer_pickup_fee
    orders.customer_delivery_fee
    order_items.unit_price
    order_items.calculated_total
    payments.amount
    expenses.amount

Financial reports normally aggregate these values after filtering by:

    Date
    Order
    Category
    Status

Indexes should therefore target the filtering dimensions rather than the amounts themselves.

---

## 102. Date Index Strategy

Date/time indexes should be added where the application filters or sorts by that date.

Important V1 date fields:

    orders.created_at
    orders.expected_pickup_date
    payments.paid_at
    expenses.expense_date

Recommended indexes:

    INDEX orders(created_at)

    INDEX orders(expected_pickup_date)

    INDEX payments(paid_at)

    INDEX expenses(expense_date)

---

## 103. Updated At Index Strategy

Updated timestamps are useful for synchronization.

Recommended where synchronization uses incremental updates:

    INDEX customers(updated_at)

    INDEX orders(updated_at)

    INDEX order_items(updated_at)

    INDEX payments(updated_at)

    INDEX storage_locations(updated_at)

    INDEX storage_records(updated_at)

    INDEX item_types(updated_at)

    INDEX item_definitions(updated_at)

    INDEX services(updated_at)

    INDEX service_item_types(updated_at)

    INDEX storage_location_item_types(updated_at)

    INDEX carpet_sizes(updated_at)

    INDEX order_item_carpets(updated_at)

    INDEX expense_categories(updated_at)

    INDEX expenses(updated_at)

The final implementation may reduce this set if the synchronization design uses another strategy.

---

## 104. Synchronization Index Principle

Synchronization indexes should reflect actual synchronization queries.

The system must not blindly index every:

    updated_at

column if the synchronization implementation does not query those columns.

The final Data Layer implementation should validate the actual sync worker queries.

---

## 105. Recommended Core Index Set

The minimum recommended V1 index set is:

    customers.phone
        UNIQUE

    customers.name

    orders.order_number
        UNIQUE

    orders.customer_id

    orders.status

    orders.expected_pickup_date

    orders.created_at

    order_items.order_id

    order_items.item_type_id

    order_items.service_id

    payments.order_id

    payments.paid_at

    storage_locations.name
        UNIQUE

    storage_locations.is_active

    storage_records.order_item_id
        UNIQUE WHERE is_active = true

    storage_records.storage_location_id

    storage_records.storage_location_id + is_active

    item_types.name
        UNIQUE

    item_types.is_active

    item_definitions.item_type_id

    item_definitions.item_type_id + is_active

    services.name
        UNIQUE

    services.is_active

    service_item_types.service_id

    service_item_types.item_type_id

    service_item_types.service_id + item_type_id
        UNIQUE

    storage_location_item_types.storage_location_id

    storage_location_item_types.item_type_id

    storage_location_item_types.storage_location_id + item_type_id
        UNIQUE

    carpet_sizes.is_active

    order_item_carpets.order_item_id
        UNIQUE

    order_item_carpets.carpet_size_id

    expense_categories.name
        UNIQUE

    expense_categories.is_active

    expenses.expense_category_id

    expenses.expense_date

    sync_operations.status + created_at

    sync_operations.entity_type + entity_id

---

## 106. Optional Indexes

The following indexes may be added when supported by actual query patterns:

    customers.updated_at

    orders.updated_at

    orders.status + expected_pickup_date

    order_items.item_definition_id

    order_items.order_id + item_type_id

    payments.order_id + paid_at

    services.pricing_type

    services.updated_at

    expense_categories.updated_at

    expenses.created_at

    expenses.updated_at

    expenses.expense_category_id + expense_date

    expenses.expense_date + expense_category_id

    sync_operations.updated_at

    sync_operations.status + retry_count

---

## 107. Index Selection Rule for Composite Indexes

When choosing between:

    A + B

and:

    B + A

the order must reflect the application's most selective and common filtering pattern.

Example:

    expenses(expense_date, expense_category_id)

is preferable when the primary query is:

    Date Range
        +
    Category Grouping

while:

    expenses(expense_category_id, expense_date)

is preferable when the primary query is:

    Category
        +
    Date Range

Only the index that best matches actual V1 query patterns should be retained unless both are demonstrably necessary.

---

## 108. Index Migration Rule

Adding or removing indexes after the initial database release requires a Drift migration.

A migration must:

    Create New Index
        or
    Drop Existing Index

without modifying business data.

Index changes must not change:

    Entity IDs
    Historical Values
    Order Status
    Payment History
    Expense History
    Storage History

---

## 109. Index Naming Convention

Index names should follow a predictable naming convention.

Recommended:

    idx_<table>_<column>

Examples:

    idx_customers_name
    idx_orders_customer_id
    idx_orders_status
    idx_orders_created_at
    idx_payments_order_id
    idx_payments_paid_at
    idx_expenses_expense_date
    idx_expenses_category_id
    idx_storage_records_location_id

Unique indexes may use:

    uq_<table>_<columns>

Examples:

    uq_orders_order_number
    uq_expense_categories_name
    uq_service_item_types_service_item_type
    uq_storage_location_item_types_location_item_type

The exact generated Drift index naming may vary, but the logical naming convention should remain consistent.

---

## 110. Index and Constraint Separation

An index is not automatically a business rule.

Examples:

    INDEX orders(status)

improves:

    Status Queries

while:

    UNIQUE INDEX storage_records(order_item_id)
    WHERE is_active = true

also enforces:

    One Active StorageRecord per OrderItem

The implementation must clearly distinguish:

    Performance Index

from:

    Integrity Constraint

---

## 111. No Indexes for Out-of-Scope Features

The V1 database must not add indexes for entities or workflows that are not part of V1.

Do not add indexes for:

    drivers

    vehicles

    delivery_routes

    refunds

    loyalty_accounts

    storage_movement_history

    storage_capacity

    laundry_processing_stages

    ai_conversations

    ai_predictions

    barcode_scans

or other unsupported features.

---

## 112. Query-First Validation

Before adding an index, the implementation should identify:

    Query
        ↓
    WHERE
        ↓
    JOIN
        ↓
    ORDER BY
        ↓
    LIMIT

The index should then be designed around the actual query.

Do not add an index simply because a column exists.

---

## 113. SQLite Query Plan Validation

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

## 114. Performance vs Write Cost

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

## 115. Offline-first Consideration

Because SQLite is the local operational database, indexes must optimize common local operations.

Important local workflows include:

    Create Order

    Open Order

    Search Customer

    Search Order

    Record Payment

    Add Expense

    Store Item

    Move Item

    View Dashboard

    View Financial Report

Indexes should prioritize these workflows.

---

## 116. Expense Reporting Performance

The Expense reporting workflow is expected to query:

    expense_date

and optionally:

    expense_category_id

Therefore the primary Expense index must remain:

    INDEX expenses(expense_date)

The Category index:

    INDEX expenses(expense_category_id)

is also required because Expenses are filterable/groupable by Category.

A composite index may be added based on the final report query shape.

---

## 117. Net Profit Performance

Net Profit requires:

    Sales
        +
    Operating Expenses

Expenses are filtered by:

    expense_date

Therefore:

    INDEX expenses(expense_date)

is required.

No index should be created for:

    net_profit

because Net Profit is not stored.

---

## 118. Storage Performance

Storage operations are among the most operationally sensitive V1 workflows.

The database must efficiently support:

    Find Current Location for Item

    Find Items Requiring Storage

    Find Items in Location

    Filter Locations by Item Type

    Complete Order

    Cancel Order

The core indexes are:

    storage_records(order_item_id)
        WHERE is_active = true

    storage_records(storage_location_id)

    storage_records(storage_location_id, is_active)

    storage_location_item_types(item_type_id)

    storage_location_item_types(storage_location_id)

---

## 119. Order Details Performance

Opening an Order Details screen must efficiently load:

    Order

    Customer

    OrderItems

    Payments

    Storage Information

The main indexes are:

    orders.id

    order_items(order_id)

    payments(order_id)

    storage_records(order_item_id)

The Primary Key indexes handle direct entity lookup.

---

## 120. Final Index Principles

The V1 database index strategy follows these principles:

1. Primary Keys already provide indexes.
2. Unique constraints provide lookup and uniqueness indexes.
3. Foreign Keys used in joins should normally be indexed.
4. Date fields used for filtering should be indexed.
5. Status fields used for operational filtering should be indexed.
6. Low-cardinality Boolean fields should not automatically receive standalone indexes.
7. Partial indexes should be used where they provide both integrity and performance.
8. Expense Date must be indexed.
9. Storage current-state queries must be indexed.
10. Service/Item Type compatibility must be indexed in both directions.
11. Storage Location/Item Type compatibility must be indexed in both directions.
12. Historical transaction data must remain efficiently queryable.
13. Dashboard metrics should use transactional indexes.
14. Net Profit does not require a stored value or dedicated index.
15. Outstanding Amount does not require a dedicated table or index.
16. Invoice generation does not require a dedicated Invoice table or index.
17. Delivery direction fields do not require standalone Boolean indexes by default.
18. Indexes must follow actual query patterns.
19. Redundant indexes must be avoided.
20. Index changes require proper database migrations.

---

## 121. Final Approved Direction

The database should remain:

    Relational
        +
    Indexed for real V1 workflows
        +
    Conservative
        +
    Offline-first
        +
    Historical-data safe
        +
    Financial-reporting ready
        +
    Storage-operation ready

Indexes are performance infrastructure.

They must support the approved product without introducing new business behavior or out-of-scope features.