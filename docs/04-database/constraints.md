# Laundry Management System — Database Constraints

## 1. Document Purpose

This document defines the approved V1 database constraints for the Laundry Management System.

The purpose of these constraints is to protect:

- Referential integrity.
- Data integrity.
- Historical data.
- Financial correctness.
- Relationship correctness.
- Offline-first consistency.
- Synchronization safety.

The database uses:

    SQLite
        +
    Drift

This document must remain aligned with:

    docs/01-product/
    docs/02-domain/
    docs/03-architecture/
    docs/04-database/database-overview.md
    docs/04-database/tables.md
    docs/04-database/relationships.md
    docs/04-database/indexes.md

The database must protect structural integrity while keeping complex business workflow validation in the Domain/Application layer.

---

## 2. Constraint Philosophy

Database constraints protect structural data integrity.

The Domain/Application layer remains responsible for complex business workflows.

Therefore:

    Database
        ↓
    Structural Integrity

and:

    Domain/Application
        ↓
    Business Rules

The database must enforce rules that can safely and reliably be represented at database level.

It must not attempt to implement the entire business workflow through SQL constraints or triggers.

---

## 3. Primary Key Constraints

Every business and infrastructure table must have a stable Primary Key.

The default Primary Key convention is:

    id

However, the approved V1 schema contains one explicit exception:

    order_item_carpets.order_item_id

is the Primary Key for the OrderItemCarpet table because OrderItemCarpet has a strict 1 → 0..1 relationship with OrderItem.

This exception is intentional and must not be treated as a violation of the UUID Primary Key strategy.

The Primary Key must:

- Be unique.
- Be non-null.
- Remain stable.
- Support Offline-first synchronization.
- Not change during the entity lifecycle.

The approved logical identifier is:

    UUID

The SQLite/Drift representation is:

    TEXT

---

## 4. Primary Key Tables

The following tables require Primary Keys:

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
    order_item_carpets.order_item_id
    expense_categories.id
    expenses.id
    business_settings.id
    sync_operations.id

---

## 5. Foreign Key Constraints

Foreign keys must preserve the approved relational structure.

Required foreign keys:

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

---

## 6. Foreign Key Integrity

A child record must never reference a parent record that does not exist.

Invalid example:

    orders.customer_id
        →
    Non-existent Customer

must never be allowed.

The same rule applies to every required Foreign Key.

SQLite Foreign Key enforcement must be enabled in the database configuration.

---

## 7. Customer Constraints

### Customer ID

    Required
    Primary Key
    Unique

### Customer Name

    Required
    Non-null

The Customer name must not be empty after normalization.

### Customer Phone

    Required
    Non-null
    Unique

Phone numbers are stored as:

    TEXT

Phone numbers are identifiers, not numeric quantities.

The same normalized phone number must not be assigned to multiple Customers.

### Customer Notes

    Nullable

### Timestamps

    created_at → Required
    updated_at → Required

The logical timestamp rule is:

    updated_at >= created_at

---

## 8. Order Constraints

### Order ID

    Required
    Primary Key
    Unique

### Order Number

    Required
    Non-null
    Unique

There must never be two Orders with the same Order Number.

The Order Number is different from:

    orders.id

The UUID identifies the entity technically.

The Order Number identifies the Order to users.

### Customer

    customer_id → Required
    Foreign Key → customers.id

Every Order must belong to an existing Customer.

### Status

    Required
    Default = processing

Allowed V1 values:

    processing
    ready
    completed
    cancelled

No other status may be persisted without an approved Domain/Product change.

Status transition validation belongs to the Domain/Application layer.

---

## 9. Expected Pickup Date Constraints

The Expected Pickup Date is:

    Required
    Date Only

The field:

    expected_pickup_date

must not have a business-time component.

The database must not make Expected Pickup Date nullable.

The UI must use a Date Picker rather than requiring manual date-format entry.

---

## 10. Order Notes

Order Notes are:

    Nullable

No special database constraint is required beyond the column nullability.

---

## 11. Order Delivery Constraints

V1 supports two independent delivery directions.

Customer Pickup:

    customer_pickup_requested
    customer_pickup_fee

Customer Delivery:

    customer_delivery_requested
    customer_delivery_fee

Both options are independent.

Valid combinations include:

    false + false
    true  + false
    false + true
    true  + true

The database must not model the two delivery directions as a single mutually exclusive enum.

Both may be selected on the same Order.

---

## 12. Customer Pickup Constraints

The field:

    customer_pickup_requested

must be:

    Required
    Default = false

The field:

    customer_pickup_fee

must be:

    Required
    Default = 0

The pickup fee must not be negative.

Conceptually:

    customer_pickup_fee >= 0

If:

    customer_pickup_requested = false

the effective pickup fee must be:

    0

This is primarily validated by the Domain/Application layer.

---

## 13. Customer Delivery Constraints

The field:

    customer_delivery_requested

must be:

    Required
    Default = false

The field:

    customer_delivery_fee

must be:

    Required
    Default = 0

The delivery fee must not be negative.

Conceptually:

    customer_delivery_fee >= 0

If:

    customer_delivery_requested = false

the effective delivery fee must be:

    0

This is primarily validated by the Domain/Application layer.

---

## 14. Delivery Scope Constraints

V1 does not include a full Delivery Management system.

The database must not introduce:

    drivers
    vehicles
    delivery_routes
    driver_assignments
    delivery_tracking
    proof_of_delivery
    delivery_status

Delivery is represented only as Order-level requested service and its applicable fee.

---

## 15. Order Financial Constraints

The following fields are required:

    subtotal
    discount
    tax
    total

All are stored as integer minor currency units.

Example:

    100.50 EGP
        ↓
    10050

Persisted monetary values must not use floating-point storage.

### Subtotal

    subtotal >= 0

### Discount

    discount >= 0

### Tax

    tax >= 0

### Total

    total >= 0

The Domain/Application layer is responsible for validating the complete calculation.

Conceptually:

    Subtotal
        +
    Customer Pickup Fee
        +
    Customer Delivery Fee
        -
    Discount
        +
    Tax
        =
    Total

---

## 16. Order Financial History

The following Order values represent transaction-time financial data:

    subtotal
    discount
    tax
    total
    customer_pickup_fee
    customer_delivery_fee

Changes to current configuration must not silently rewrite historical Order financial data.

Examples:

    Service Price Changes
        ↓
    Existing OrderItems
        ↓
    Historical Prices Remain Unchanged

and:

    Tax Setting Changes
        ↓
    Existing Orders
        ↓
    Historical Tax Remains Unchanged

and:

    Delivery Fee Configuration Changes
        ↓
    Existing Orders
        ↓
    Historical Delivery Fees Remain Unchanged

---

## 17. Order Completion Timestamp Constraints

For a Completed Order:

    completed_at

should be populated.

For an Order that has not been completed:

    completed_at

should normally be null.

The Domain/Application layer controls the completion workflow.

The database preserves the timestamp.

---

## 18. Order Cancellation Constraints

For a Cancelled Order:

    cancelled_at

should be populated.

For a non-cancelled Order:

    cancelled_at

should normally be null.

The field:

    cancellation_reason

is nullable.

When an Order is cancelled, a valid cancellation reason is required according to the Domain/Application workflow.

Orders are cancelled rather than physically deleted during normal V1 operation.

---

## 19. OrderItem Constraints

Every OrderItem must have:

    id
    order_id
    item_type_id
    service_id
    item_type_name_snapshot
    service_name_snapshot
    pricing_type
    unit_price
    calculated_total
    created_at
    updated_at

Required Foreign Keys:

    order_id
        →
    orders.id

    item_type_id
        →
    item_types.id

    service_id
        →
    services.id

Every OrderItem must belong to exactly one Order.

Every OrderItem must have exactly one Item Type.

Every OrderItem must have exactly one Service.

---

## 20. Order Must Contain OrderItems

An Order must contain at least one physical OrderItem.

Conceptually:

    COUNT(order_items WHERE order_id = Order.id) >= 1

This rule depends on multiple records and therefore belongs primarily to the Domain/Application layer.

Order creation must not be considered complete unless at least one OrderItem exists.

The Create Order operation must be transactional.

---

## 21. Physical OrderItem Identity

Every physical laundry item must have its own OrderItem ID.

Example:

    Shirt × 5

is represented as:

    OrderItem 1
    OrderItem 2
    OrderItem 3
    OrderItem 4
    OrderItem 5

The database must not merge separate physical items merely because they share:

    Item Type
    Service
    Price

Each physical OrderItem must remain independently addressable.

---

## 22. OrderItem Quantity Constraints

The current V1 schema contains:

    order_items.quantity

Quantity is required.

Quantity must be:

    > 0

Quantity represents the transaction/pricing quantity for the physical OrderItem.

Examples:

    Per Piece:
    1

    Per Kilogram:
    3.5

    Per Square Meter:
    6.25

    Fixed Price:
    1

The exact numeric precision is determined by the approved implementation.

Quantity must never be zero or negative.

---

## 23. OrderItem Item Definition Constraints

The field:

    item_definition_id

is nullable.

This is intentional.

Not every Item Type requires an Item Definition.

If an Item Definition is provided:

    item_definition_id
        →
    item_definitions.id

The referenced Item Definition must belong to the selected Item Type.

The Domain/Application layer validates:

    ItemDefinition.item_type_id
        =
    OrderItem.item_type_id

when an Item Definition is used.

---

## 24. OrderItem Historical Snapshot Constraints

The following snapshots are required:

    item_type_name_snapshot
    service_name_snapshot

The following snapshot is optional:

    item_definition_name_snapshot

Historical snapshots must not be automatically updated when master data changes.

Example:

    Service:
    غسيل

Historical OrderItem:

    service_name_snapshot = غسيل

If the current Service is later renamed:

    غسيل سريع

the historical OrderItem must remain:

    غسيل

---

## 25. OrderItem Pricing Constraints

The following are required:

    pricing_type
    unit_price
    calculated_total

Allowed V1 pricing types:

    per_piece
    per_kg
    per_square_meter
    fixed_price

No unsupported pricing type may be persisted.

---

## 26. OrderItem Monetary Constraints

The following monetary fields must not be negative:

    unit_price
    calculated_total

Conceptually:

    unit_price >= 0
    calculated_total >= 0

The Domain/Application layer determines the valid pricing calculation.

Persisted monetary values use integer minor units.

---

## 27. OrderItem Historical Pricing

When an OrderItem is created:

    Current Service Price
        ↓
    OrderItem.unit_price

After the OrderItem is created:

    services.price

may change independently.

The historical:

    order_items.unit_price

must remain unchanged unless an explicit approved Order Edit operation changes the transaction.

The database must not reconstruct historical prices from current Service prices.

---

## 28. Payment Constraints

Every Payment must have:

    id
    order_id
    amount
    payment_method
    paid_at
    created_at

The Payment must belong to an existing Order.

Required relationship:

    payments.order_id
        →
    orders.id

---

## 29. Payment Amount Constraint

Payment amount must be:

    > 0

A Payment amount of:

    0

is invalid.

A negative Payment amount is invalid.

Payment amount uses integer minor currency units.

---

## 30. Payment Method Constraint

Payment Method is required.

Approved V1 values:

    cash
    instapay
    ewallet

No other payment method may be persisted without an approved requirement change.

---

## 31. Payment Overpayment Rule

The business rule is:

    Payment Amount
        <=
    Remaining Amount

Remaining Amount is conceptually:

    Order Total
        -
    Sum of Existing Payments

This rule primarily belongs to the Domain/Application layer because it depends on multiple records.

The database must enforce the basic structural rule:

    amount > 0

Payment insertion must be transactional where required to prevent inconsistent financial state.

---

## 32. Payment History Protection

Payments are historical financial transactions.

When a new payment is recorded:

    Create New Payment

Do not overwrite an existing Payment to represent a new transaction.

Normal V1 operations must not physically delete Payment records.

This preserves financial history.

---

## 33. Storage Location Constraints

Every Storage Location must have:

    id
    name
    is_active
    created_at
    updated_at

### Name

    Required
    Unique

Two Storage Locations must not have the same name.

### Active State

    Required
    Default = true

---

## 34. Inactive Storage Location Rule

An inactive Storage Location:

    Cannot be selected for new storage operations.

Existing historical StorageRecords referencing an inactive Storage Location remain valid.

Deactivation must not invalidate historical transactions.

---

## 35. Storage Record Constraints

Every StorageRecord must have:

    id
    order_item_id
    storage_location_id
    is_active
    created_at
    updated_at

Required Foreign Keys:

    storage_records.order_item_id
        →
    order_items.id

    storage_records.storage_location_id
        →
    storage_locations.id

---

## 36. One Active StorageRecord Rule

The most important Storage constraint is:

    One OrderItem
        →
    Maximum One Active StorageRecord

Conceptually:

    order_item_id
        +
    is_active = true

must be unique.

The preferred implementation is a SQLite-compatible partial unique index.

The final implementation must guarantee:

    COUNT(active StorageRecords for an OrderItem) <= 1

---

## 37. Storage Movement Constraint

When an OrderItem moves from one Storage Location to another:

    Old StorageRecord
        ↓
    is_active = false

    New StorageRecord
        ↓
    is_active = true

The operation must be atomic.

The database must never be left with:

    Old StorageRecord = active
    New StorageRecord = active

for the same OrderItem.

---

## 38. Storage Completion Constraint

When an Order becomes Completed:

    All active StorageRecords
        belonging to its OrderItems
        ↓
    is_active = false

The Order status update and StorageRecord updates must happen inside the same database transaction.

---

## 39. Storage Cancellation Constraint

When an Order becomes Cancelled:

    All active StorageRecords
        belonging to its OrderItems
        ↓
    is_active = false

The Order status update and StorageRecord updates must happen atomically.

---

## 40. Manual Status Correction and Storage

If a Completed Order is manually changed back to Processing:

    Previous StorageRecords
        ↓
    Remain inactive

The database must not automatically reactivate previous StorageRecords.

If the physical items need to be stored again:

    New StorageRecord
        ↓
    is_active = true

must be explicitly created.

---

## 41. Item Type Constraints

Every Item Type must have:

    id
    name
    is_active
    created_at
    updated_at

### Name

    Required
    Unique

### Active State

    Required
    Default = true

An inactive Item Type cannot be selected for new transactions.

Historical OrderItems referencing it remain valid.

---

## 42. Item Definition Constraints

Every Item Definition must have:

    id
    item_type_id
    name
    is_active
    created_at
    updated_at

Required Foreign Key:

    item_definitions.item_type_id
        →
    item_types.id

The combination:

    item_type_id
        +
    name

must be unique.

This allows:

    Same Definition Name
        under different Item Types

while preventing:

    Duplicate Definition
        under the same Item Type

### Active State

    Required
    Default = true

---

## 43. Service Constraints

Every Service must have:

    id
    name
    description
    pricing_type
    price
    is_active
    created_at
    updated_at

### Name

    Required
    Unique

### Pricing Type

    Required

Allowed V1 values:

    per_piece
    per_kg
    per_square_meter
    fixed_price

### Price

    Required
    >= 0

The current Service price uses integer minor currency units.

### Active State

    Required
    Default = true

---

## 44. Service Price History Constraint

The current:

    services.price

is master data.

The historical:

    order_items.unit_price

is transaction data.

Changing:

    services.price

must not modify:

    order_items.unit_price

This is required for historical financial correctness.

---

## 45. Service / Item Type Compatibility Constraints

The junction table:

    service_item_types

represents the many-to-many relationship between:

    Service
    +
    Item Type

Required Foreign Keys:

    service_item_types.service_id
        →
    services.id

    service_item_types.item_type_id
        →
    item_types.id

The combination:

    service_id
        +
    item_type_id

must be unique.

The same Service must not be linked to the same Item Type more than once.

---

## 46. Service Compatibility Rule

Every OrderItem must use a valid:

    Service
        +
    Item Type

combination.

The combination must exist in:

    service_item_types

The Domain/Application layer validates the compatibility before creating or updating an OrderItem.

The database preserves the compatibility relationship.

---

## 47. Storage Location / Item Type Compatibility

The junction table:

    storage_location_item_types

represents the many-to-many relationship between:

    Storage Location
    +
    Item Type

Required Foreign Keys:

    storage_location_item_types.storage_location_id
        →
    storage_locations.id

    storage_location_item_types.item_type_id
        →
    item_types.id

The combination:

    storage_location_id
        +
    item_type_id

must be unique.

The same Item Type must not be linked to the same Storage Location more than once.

---

## 48. Storage Compatibility Rule

When storing an OrderItem:

    OrderItem
        ↓
    ItemType
        ↓
    StorageLocationItemType
        ↓
    Compatible StorageLocations

The application should only offer Storage Locations compatible with the selected Item Type.

The Domain/Application layer validates the compatibility before creating a StorageRecord.

The database preserves the compatibility relationship.

---

## 49. Carpet Size Constraints

Every Carpet Size must have:

    id
    length
    width
    area
    is_active
    created_at
    updated_at

### Length

    Required
    > 0

### Width

    Required
    > 0

### Area

    Required
    > 0

### Active State

    Required
    Default = true

---

## 50. Carpet Dimension Constraint

Carpet dimensions must always be positive.

Conceptually:

    length > 0
    width > 0
    area > 0

The Domain/Application layer validates:

    area = length × width

according to the approved unit and precision rules.

The database should protect against non-positive values.

---

## 51. OrderItemCarpet Constraints

Every OrderItemCarpet must have:

    order_item_id
    length
    width
    area
    created_at
    updated_at

The relationship:

    order_item_carpets.order_item_id
        →
    order_items.id

is required.

The field:

    order_item_id

is the Primary Key of OrderItemCarpet and therefore is unique and non-null.

This intentionally models the strict 1 → 0..1 relationship:

    One OrderItem
        →
    Maximum One OrderItemCarpet

There is no separate:

    order_item_carpets.id

Primary Key.

The OrderItem UUID is reused as the OrderItemCarpet Primary Key because the Carpet record is a strict one-to-zero-or-one extension of the OrderItem.

This also guarantees that one OrderItem cannot have multiple OrderItemCarpet records at database level.

---

## 52. Carpet Size Optionality

The field:

    carpet_size_id

is nullable.

This supports:

    Predefined Carpet Size

or:

    Custom Dimensions

If:

    carpet_size_id != null

the referenced Carpet Size must exist.

If:

    carpet_size_id == null

the OrderItemCarpet must still contain:

    length
    width
    area

---

## 53. Historical Carpet Data

For every OrderItemCarpet:

    length
    width
    area

are historical transaction values.

They must remain unchanged when:

    CarpetSize
        ↓
    is edited

or:

    CarpetSize
        ↓
    is deactivated

The system must not reconstruct historical dimensions from the current Carpet Size.

---

## 54. Carpet Item Relationship Validation

Only Carpet OrderItems should have an OrderItemCarpet record.

A non-Carpet OrderItem should not have Carpet-specific data.

The Domain/Application layer validates:

    OrderItem.item_type
        =
    Carpet

before creating OrderItemCarpet.

The database relationship itself protects referential integrity.

---

## 55. Expense Category Constraints

Every Expense Category must have:

    id
    name
    is_active
    created_at
    updated_at

### Name

    Required
    Non-null
    Unique

Two active or historical Expense Categories must not have the same normalized name.

### Active State

    Required
    Default = true

---

## 56. Expense Category Management

Expense Categories are configurable master data.

The system supports:

    Add Category
    Edit Category
    Activate Category
    Deactivate Category

Deactivation means:

    Not available for new Expenses

It does not mean:

    Historical Expenses become invalid

Historical Expenses must remain valid after Category deactivation.

---

## 57. Expense Constraints

Every Expense must have:

    id
    expense_category_id
    amount
    expense_date
    category_name_snapshot
    created_at
    updated_at

Required Foreign Key:

    expenses.expense_category_id
        →
    expense_categories.id

---

## 58. Expense Amount Constraint

Expense amount must be:

    > 0

A zero Expense is invalid.

A negative Expense is invalid.

Expense amounts use integer minor currency units.

Example:

    150.00 EGP
        ↓
    15000

---

## 59. Expense Date Constraint

The field:

    expense_date

is:

    Required
    Date Only

It must not contain a business-time component.

The Financial Report uses:

    expense_date

to determine whether an Expense belongs to a selected date or date range.

---

## 60. Expense Name Constraint

The field:

    expense_name

is nullable in the general schema.

However, when the selected Expense Category represents:

    أخرى

the Expense Name becomes required.

Example:

    Category:
    أخرى

    Expense Name:
    إصلاح باب المحل

The Domain/Application layer validates this conditional requirement.

The database should preserve the value when provided.

---

## 61. Expense Category Snapshot

Every Expense must preserve:

    category_name_snapshot

This is the Category name at transaction time.

Changing the current:

    expense_categories.name

must not rewrite:

    expenses.category_name_snapshot

This protects historical financial reporting.

---

## 62. Expense Independence

Expense is an independent financial transaction.

The expenses table intentionally does not contain:

    order_id
    order_item_id
    payment_id
    customer_id

An Expense is not:

    Payment

An Expense is not:

    Order

An Expense is not:

    Customer transaction

It represents an operating cost of the laundry.

---

## 63. Expense and Payment Separation

Payments represent:

    Money received from Customers for Orders

Expenses represent:

    Operating Money spent by the Business

Therefore:

    Payment
        ≠
    Expense

They must remain separate tables and separate Domain concepts.

---

## 64. Expense Reporting Constraint

For a selected report date:

    expenses.expense_date
        =
    selected_date

For a selected date range:

    start_date
        <=
    expenses.expense_date
        <=
    end_date

The Financial Report may aggregate Expenses by:

    Category
    Amount
    Date

No duplicated reporting table is required.

---

## 65. Net Profit Constraint

Net Profit is a derived financial value.

It must not be stored as a dedicated database entity.

For a selected reporting period:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

Total Operating Expenses are derived from:

    expenses

using:

    expense_date

Total Sales are derived from the approved Order reporting rules.

Payments are not subtracted from Sales when calculating Net Profit.

Outstanding amounts are not Expenses.

---

## 66. Outstanding Amount Constraint

Outstanding Amount is derived.

Conceptually:

    Order Total
        -
    Sum of Payments
        =
    Remaining Amount

No dedicated:

    outstanding_balances

table is required.

The database must preserve the source data required to calculate the value.

---

## 67. Invoice Data Constraint

V1 does not require a dedicated:

    invoices

table.

Invoice output is generated from:

    business_settings
    customers
    orders
    order_items
    payments

Invoice output must use historical transaction values.

For each OrderItem, the Invoice must be able to display:

    Item Type
    Item Definition where applicable
    Service
    Quantity
    Pricing Type
    Unit Price
    Calculated Total

For Carpet items:

    Carpet Size where applicable
    Length
    Width
    Area

---

## 68. Business Settings Constraints

BusinessSettings must have:

    id
    business_name
    address
    phone
    logo_reference
    invoice_footer_text
    tax_enabled
    tax_rate
    updated_at

### Business Name

    Required
    Non-null

### Optional Business Information

The following fields are nullable:

    address
    phone
    logo_reference
    invoice_footer_text

These fields are optional business/invoice information and do not participate in financial calculations.

### Tax Enabled

    Required
    Default = false

### Tax Rate

    Required
    Default = 0
    >= 0

---

## 69. Single Business Settings Constraint

V1 assumes:

    One Business
        +
    One Branch
        +
    One BusinessSettings Record

The database/application design must prevent accidental creation of multiple active settings records.

The preferred implementation is:

    Single Fixed Record ID

or another explicit single-row strategy.

A multi-branch configuration model must not be introduced in V1.

---

## 70. Tax Constraints

If:

    tax_enabled = false

the effective Order tax must be:

    0

If:

    tax_enabled = true

the configured:

    tax_rate

may be applied according to the approved pricing rules.

Historical Order tax must remain unchanged after future tax-setting changes.

---

## 71. Active / Inactive Master Data

The following master-data tables use:

    is_active

    item_types
    item_definitions
    services
    carpet_sizes
    storage_locations
    expense_categories

The active flag means:

    Available for new applicable operations

The inactive flag means:

    Not available for new applicable operations

It does not mean:

    Historical data is invalid

---

## 72. Historical Data Protection

Historical transaction data must remain understandable after master-data changes.

Examples include:

    Service Price
        ↓
    Historical OrderItem.unit_price

    Service Name
        ↓
    Historical OrderItem.service_name_snapshot

    Item Type Name
        ↓
    Historical OrderItem.item_type_name_snapshot

    Item Definition Name
        ↓
    Historical OrderItem.item_definition_name_snapshot

    Carpet Dimensions
        ↓
    Historical OrderItemCarpet.length
    Historical OrderItemCarpet.width
    Historical OrderItemCarpet.area

    Expense Category Name
        ↓
    Historical Expense.category_name_snapshot

Historical values must not be silently rewritten by master-data edits.

---

## 73. Destructive Deletion Constraints

Normal V1 operations must not physically delete:

    customers
    orders
    order_items
    payments
    expenses

Master data referenced by historical transactions should generally be deactivated instead of deleted:

    item_types
    item_definitions
    services
    carpet_sizes
    storage_locations
    expense_categories

Orders use:

    cancellation

rather than:

    deletion

---

## 74. Foreign Key Delete Behavior

The database must not use unrestricted:

    CASCADE DELETE

for historical business relationships.

In particular, deleting:

    Customer

must not silently delete:

    Orders
    OrderItems
    Payments

Deleting:

    Order

must not silently delete historical:

    Payments
    OrderItems

because normal V1 business flow does not require destructive Order deletion.

Conservative behavior such as:

    RESTRICT

should be preferred where historical data could be lost.

---

## 75. Nullable Foreign Keys

The following Foreign Keys are intentionally nullable:

    order_items.item_definition_id
    order_item_carpets.carpet_size_id

They are nullable because the Domain allows those relationships to be optional.

All other core transactional Foreign Keys are required unless explicitly changed by approved Domain documentation.

---

## 76. Unique Constraints Summary

The following values/combinations must be unique:

    customers.phone

    orders.order_number

    storage_locations.name

    item_types.name

    item_definitions.item_type_id
        +
    item_definitions.name

    services.name

    service_item_types.service_id
        +
    service_item_types.item_type_id

    storage_location_item_types.storage_location_id
        +
    storage_location_item_types.item_type_id

    order_item_carpets.order_item_id

    expense_categories.name

The following additional invariant must be enforced:

    Maximum one active StorageRecord
        per OrderItem

BusinessSettings must enforce:

    One V1 settings record

---

## 77. Positive Value Constraints

The following values must be positive:

    order_items.quantity

    payments.amount

    expenses.amount

    carpet_sizes.length
    carpet_sizes.width
    carpet_sizes.area

    order_item_carpets.length
    order_item_carpets.width
    order_item_carpets.area

Quantity and measurement fields must never be zero or negative.

---

## 78. Non-Negative Value Constraints

The following values may be zero but must never be negative:

    orders.subtotal
    orders.discount
    orders.tax
    orders.total
    orders.customer_pickup_fee
    orders.customer_delivery_fee
    services.price
    order_items.unit_price
    order_items.calculated_total
    business_settings.tax_rate
    sync_operations.retry_count

---

## 79. Sync Operation Constraints

The synchronization table is infrastructure data.

Every SyncOperation must have:

    id
    entity_type
    entity_id
    operation_type
    status
    retry_count
    created_at
    updated_at

Optional:

    payload
    last_error
    last_attempt_at

---

## 80. Sync Entity Type Constraints

Expected V1 entity types include:

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

No unsupported business entity type should be introduced without updating the synchronization design.

---

## 81. Sync Operation Type Constraints

Expected V1 operation types include:

    create
    update
    deactivate

Additional operation types require an approved synchronization design change.

---

## 82. Sync Status Constraints

Expected V1 SyncOperation statuses:

    pending
    processing
    synced
    failed

No other status should be persisted without updating the synchronization design.

---

## 83. Sync Retry Count Constraint

The field:

    retry_count

must satisfy:

    retry_count >= 0

It must never be negative.

---

## 84. Sync Entity Reference Rule

The combination:

    entity_type
        +
    entity_id

identifies the business entity associated with a SyncOperation.

However, it must not be globally unique.

One entity may have multiple synchronization operations over time.

Therefore:

    entity_type + entity_id

must not be treated as a global unique key.

---

## 85. Sync Queue Atomicity

When a local business operation requires synchronization:

    Business Data Change
        +
    SyncOperation Creation

must be committed atomically.

Invalid state:

    Business Data Saved
        +
    Sync Operation Missing

Valid state:

    Business Data Saved
        +
    Sync Operation Persisted

This is required for Offline-first reliability.

---

## 86. Timestamp Constraints

Required timestamps must never be null.

For entities with:

    created_at
    updated_at

the logical rule is:

    updated_at >= created_at

Business event timestamps include:

    paid_at
    completed_at
    cancelled_at

These timestamps represent specific events and must not be automatically replaced by generic updated_at changes.

---

## 87. Historical Event Timestamp Protection

Historical event timestamps should not be changed without an explicit business operation.

Examples:

    Payment.paid_at
    Order.completed_at
    Order.cancelled_at
    Expense.expense_date

The following distinction must remain clear:

    created_at
        =
    Record Creation Time

while:

    paid_at
        =
    Payment Business Time

and:

    expense_date
        =
    Expense Business Date

---

## 88. Order Status Business Rules

The database stores:

    orders.status

but the Domain/Application layer owns lifecycle validation.

The following rules remain Domain/Application responsibilities:

    processing
        →
    ready

    ready
        →
    completed

    processing
        →
    cancelled

    ready
        →
    cancelled

Manual corrections may be supported according to the approved workflow.

No unsupported lifecycle transition should be accepted by the application.

---

## 89. Ready State Rule

An Order is Ready only when all physical OrderItems have active StorageRecords.

Conceptually:

    Every OrderItem
        ↓
    Has Active StorageRecord
        ↓
    Order can become Ready

An OrderItem without an active StorageRecord means:

    Item Requires Storage

This rule depends on multiple records and belongs to the Domain/Application layer.

---

## 90. Completion Rule

An Order cannot become Completed unless the required business conditions are satisfied.

The Domain/Application layer validates:

- Order is Ready.
- Remaining Amount is zero.
- Customer handover is confirmed.

After successful completion:

    Order.status = completed

and:

    All active StorageRecords = inactive

The database preserves:

    completed_at

as the completion timestamp.

---

## 91. Cancellation Rule

A cancelled Order:

- Remains in history.
- Is not considered active operational work.
- Preserves its OrderItems.
- Preserves its Payments.
- Deactivates active StorageRecords.
- Preserves cancellation information.

Cancellation information includes:

    cancelled_at
    cancellation_reason

The Domain/Application layer owns the cancellation workflow.

---

## 92. Cancelled Order Read-Only Rule

A Cancelled Order is treated as read-only during normal V1 operations.

The database itself should not need to enforce every read-only behavior.

The Domain/Application layer prevents unsupported modifications.

Historical records remain available for reporting and audit purposes.

---

## 93. Payment and Completion Relationship

The database stores Payments independently from Order status.

The Domain/Application layer determines whether an Order may be Completed.

The completion rule includes:

    Remaining Amount = 0

This is not implemented as a static database constraint because it depends on the aggregate of Payment records.

---

## 94. Service and Item Type Relationship

An OrderItem's:

    service_id

and:

    item_type_id

must represent a valid compatibility relationship.

The valid relationship must exist in:

    service_item_types

The Domain/Application layer performs the compatibility validation.

---

## 95. Item Definition Relationship Rule

If:

    order_items.item_definition_id

is not null, then:

    item_definitions.item_type_id
        =
    order_items.item_type_id

must hold logically.

The database maintains the Foreign Keys.

The Domain/Application layer validates the cross-table relationship.

---

## 96. Carpet Relationship Rule

If an OrderItem has:

    Item Type = Carpet

then:

    OrderItemCarpet

is required.

If an OrderItem is not a Carpet:

    OrderItemCarpet

should not exist.

This is a Domain/Application rule.

The database protects the structural relationship through Foreign Keys and uniqueness.

---

## 97. Expense Category Relationship Rule

Every Expense must belong to exactly one Expense Category.

Required:

    expenses.expense_category_id

The referenced Expense Category must exist.

An inactive Expense Category may remain referenced by historical Expenses.

An inactive Expense Category must not be selected for new Expenses.

---

## 98. Expense Historical Integrity

Changing:

    expense_categories.name

must not rewrite:

    expenses.category_name_snapshot

Changing the active state of an Expense Category must not invalidate existing Expenses.

Historical Expense reports must remain understandable.

---

## 99. Expense vs Net Profit

Expenses are source transactions.

Net Profit is derived.

Therefore:

    expenses
        =
    Source Financial Data

while:

    net_profit
        =
    Derived Report Value

No:

    net_profit

column or table is required for V1.

---

## 100. Financial Report Source Integrity

The Financial Report must derive its data from authoritative transaction tables.

Sales:

    orders

Payments:

    payments

Expenses:

    expenses

Expense Categories:

    expense_categories

Remaining Amount:

    orders
        +
    payments

Net Profit:

    orders
        -
    expenses

The reporting layer must not create duplicated transaction records.

---

## 101. Dashboard Data Integrity

Dashboard metrics are derived.

No dedicated Dashboard table is required.

Examples:

    Today's Orders
    Ready Orders
    Orders Requiring Storage
    Total Sales
    Total Payments
    Total Expenses
    Remaining Amount

must be calculated from authoritative data.

---

## 102. Invoice Data Integrity

Invoice output must use historical transaction values.

The Invoice must not retrieve current Service prices and use them for historical Orders.

It must use:

    order_items.unit_price
    order_items.calculated_total

and historical snapshots.

For Carpet items, it must use:

    order_item_carpets.length
    order_item_carpets.width
    order_item_carpets.area

rather than recalculating historical values from current CarpetSize data.

---

## 103. Storage Filtering Integrity

Storage Location filtering is based on:

    ItemType

and:

    storage_location_item_types

The application should not show incompatible Storage Locations as valid options.

The database maintains the compatibility relationship.

---

## 104. Historical Storage Integrity

StorageRecords represent physical storage assignments.

When a Storage Location becomes inactive:

    Existing StorageRecords
        ↓
    Remain valid

When an item is moved:

    Old StorageRecord
        ↓
    Inactive

    New StorageRecord
        ↓
    Active

Historical StorageRecords should not be deleted simply because the item moved.

---

## 105. Physical Deletion Policy

Physical deletion is not a normal V1 business operation for transactional records.

Do not physically delete:

    orders
    order_items
    payments
    expenses

Master data should generally be:

    Deactivated

instead of:

    Deleted

when historical references exist.

---

## 106. Database Transactions

The following operations must use database transactions where multiple records are modified together.

### Create Order

    Create Order
        +
    Create OrderItems
        +
    Create related item-specific data
        +
    Create SyncOperations where required

### Record Payment

    Create Payment
        +
    Create SyncOperation

### Add Expense

    Create Expense
        +
    Create SyncOperation

### Store Item

    Create StorageRecord
        +
    Create SyncOperation

### Move Item

    Deactivate Old StorageRecord
        +
    Create New StorageRecord
        +
    Create SyncOperation

### Complete Order

    Update Order
        +
    Set completed_at
        +
    Deactivate Active StorageRecords
        +
    Create SyncOperations

### Cancel Order

    Update Order
        +
    Set cancelled_at
        +
    Save cancellation_reason
        +
    Deactivate Active StorageRecords
        +
    Create SyncOperations

---

## 107. Transaction Atomicity

A multi-record business operation must not partially commit.

Invalid example:

    Order status updated
        +
    Storage Records not updated

Another invalid example:

    Expense saved
        +
    SyncOperation missing

Another invalid example:

    Old StorageRecord deactivated
        +
    New StorageRecord not created

All related changes must either:

    Commit Together

or:

    Roll Back Together

---

## 108. Database Constraints vs Business Rules

The following should primarily remain Domain/Application rules:

    Order must contain at least one OrderItem

    Order can become Ready only when all OrderItems are stored

    Order can become Completed only when Ready

    Remaining Amount must be zero before completion

    Customer handover must be confirmed before completion

    Payment cannot exceed Remaining Amount

    Service must support ItemType

    ItemDefinition must belong to selected ItemType

    Carpet OrderItem must have Carpet data

    Non-Carpet OrderItem must not have Carpet data

    Expense Name is required when Category = Other

    Inactive master data cannot be selected for new transactions

    Cancelled Orders are read-only

    Manual Completed → Processing does not reactivate StorageRecords

These rules depend on multiple records or workflow state.

---

## 109. Database-Level Structural Rules

The database should enforce structural rules where practical, including:

    Primary Keys
    Foreign Keys
    Required fields
    Unique identifiers
    Unique compatibility relationships
    Positive basic values
    Non-negative financial values
    One active StorageRecord per OrderItem
    One OrderItemCarpet per OrderItem
    Single BusinessSettings record
    Stable UUID identity

For OrderItemCarpet specifically:

    order_item_carpets.order_item_id

is the Primary Key and Foreign Key.

This is the approved exception to the default:

    table.id

Primary Key convention.

---

## 110. Database Trigger Policy

Database triggers are not required by default.

Preferred architecture:

    Drift Transaction
        +
    Repository / Data Layer
        +
    Domain Validation

Triggers should only be introduced when a concrete integrity requirement cannot be safely handled through normal database constraints and transactional application logic.

Any trigger requires an explicit technical decision.

---

## 111. Cascade Delete Policy

Unrestricted cascade deletion must not be used for historical business data.

Avoid:

    ON DELETE CASCADE

where it could cause loss of:

    Orders
    OrderItems
    Payments
    Expenses
    Historical StorageRecords

Conservative deletion behavior is preferred.

---

## 112. UUID Stability

UUID values must remain stable across:

    Local Creation
        ↓
    Local Persistence
        ↓
    Sync Queue
        ↓
    Remote Synchronization

The local database must never replace a stable entity UUID merely because synchronization occurs.

For OrderItemCarpet:

    order_item_carpets.order_item_id

uses the existing OrderItem UUID as its Primary Key.

No second UUID is generated for the one-to-zero-or-one Carpet extension record.

---

## 113. Offline-first Integrity

All normal V1 operations must work against the local database without requiring an internet connection.

The database must support local:

    Customer Creation
    Customer Editing
    Order Creation
    Order Editing
    OrderItem Management
    Payment Recording
    Expense Recording
    Storage Assignment
    Storage Movement
    Reporting
    Dashboard Queries

Synchronization occurs separately.

---

## 114. Synchronization Safety

Business data and synchronization state must remain consistent.

When an operation changes:

    Customer
    Order
    OrderItem
    Payment
    Expense
    Storage
    Master Data

the required SyncOperation must be persisted atomically with the local business change.

---

## 115. Historical Snapshot Protection

The following transaction-time values must be treated as historical:

    OrderItem.item_type_name_snapshot
    OrderItem.item_definition_name_snapshot
    OrderItem.service_name_snapshot
    OrderItem.pricing_type
    OrderItem.unit_price
    OrderItem.calculated_total

For Carpets:

    OrderItemCarpet.length
    OrderItemCarpet.width
    OrderItemCarpet.area

For Expenses:

    Expense.category_name_snapshot

For Orders:

    Order.subtotal
    Order.discount
    Order.tax
    Order.total
    Order.customer_pickup_fee
    Order.customer_delivery_fee

These values must not change as a side effect of master-data edits.

---

## 116. Master Data Deactivation Rule

The following records should normally be deactivated rather than deleted:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

Deactivation must not remove historical references.

Historical transactions remain valid.

---

## 117. Required Field Policy

Required fields must not be made nullable simply to simplify implementation.

Required fields include, among others:

    Customer.name
    Customer.phone

    Order.customer_id
    Order.order_number
    Order.status
    Order.expected_pickup_date

    OrderItem.order_id
    OrderItem.item_type_id
    OrderItem.service_id
    OrderItem.pricing_type
    OrderItem.quantity
    OrderItem.unit_price
    OrderItem.calculated_total

    Payment.order_id
    Payment.amount
    Payment.payment_method
    Payment.paid_at

    StorageRecord.order_item_id
    StorageRecord.storage_location_id

    Expense.expense_category_id
    Expense.amount
    Expense.expense_date

---

## 118. Allowed Nullable Fields

The following fields are intentionally nullable:

    customers.notes

    orders.notes
    orders.completed_at
    orders.cancelled_at
    orders.cancellation_reason

    order_items.item_definition_id
    order_items.item_definition_name_snapshot
    order_items.notes

    order_item_carpets.carpet_size_id

    payments fields only where explicitly documented

    expense_categories fields only where explicitly documented

    expenses.expense_name
    expenses.notes

    sync_operations.payload
    sync_operations.last_error
    sync_operations.last_attempt_at

Nullability must always have a clear business meaning.

---

## 119. Order Delivery Fee Integrity

Delivery fees are Order financial values.

They are not:

    Payments

and not:

    Expenses

They must not be inserted into:

    payments

or:

    expenses

The fee is part of the Order total when its corresponding delivery option is requested.

---

## 120. Expense Financial Integrity

Expenses must never be used to represent:

    Customer Payment

Payments must never be used to represent:

    Operating Expense

The two transaction types must remain separate.

---

## 121. Profit Calculation Integrity

Profit calculation must not use:

    Payment Total

as the Sales value.

The V1 conceptual calculation is:

    Sales
        -
    Operating Expenses
        =
    Net Profit

Payments are reported separately.

Outstanding amounts are reported separately.

---

## 122. Report Period Integrity

Financial reports use the selected reporting period.

For Orders, the exact reporting date basis must follow the approved reporting rules.

For Expenses:

    expense_date

is the business date.

An Expense must be included in a report when its:

    expense_date

falls inside the selected period.

---

## 123. Date Range Boundary Rule

Date ranges are inclusive.

Conceptually:

    start_date
        <=
    business_date
        <=
    end_date

This applies to Expense Date filtering and other date-only reporting filters where applicable.

---

## 124. AI Coding Tool Rules

AI coding tools implementing the database must follow this document.

The AI must not:

- Remove a required Primary Key.
- Remove a required Foreign Key.
- Remove a required Unique constraint.
- Allow multiple active StorageRecords for one OrderItem.
- Allow duplicate Service/ItemType relationships.
- Allow duplicate StorageLocation/ItemType relationships.
- Allow duplicate Customer phone numbers.
- Allow duplicate Order numbers.
- Allow duplicate ItemDefinitions under the same ItemType.
- Allow duplicate Expense Categories.
- Allow duplicate OrderItemCarpet records for one OrderItem.
- Allow negative financial values where prohibited.
- Allow zero or negative Payments.
- Allow zero or negative Expenses.
- Allow invalid Carpet dimensions.
- Introduce unrestricted cascade deletion.
- Make required fields nullable without an approved change.
- Replace historical transaction values with current master data.
- Introduce a single mutually exclusive Delivery field.
- Remove independent Customer Pickup and Customer Delivery support.
- Introduce a dedicated Profit table for V1.
- Introduce a dedicated Outstanding Balance table for V1.
- Introduce an Invoice table for V1 without an approved requirement.
- Introduce delivery-management tables outside V1 scope.
- Introduce unnecessary database triggers.
- Add new business constraints without documentation.
- Introduce a separate Primary Key for OrderItemCarpet.
- Generate a second UUID for OrderItemCarpet when the approved schema uses order_item_id as its Primary Key.

---

## 125. Constraint Change Rule

Any new constraint or modification must document:

    Constraint
        +
    Reason
        +
    Affected Table
        +
    Affected Domain Rule
        +
    Migration Impact

The change must be reviewed before implementation.

---

## 126. Schema Consistency Rule

Any constraint change must be checked against:

    requirements.md
    scope.md
    business-rules.md
    domain-model.md
    entities.md
    tables.md
    relationships.md
    database-overview.md
    database-decisions.md
    indexes.md
    data-layer.md

A database constraint must never silently introduce a new business requirement.

---

## 127. V1 Constraint Non-Goals

The database must not introduce constraints for unsupported V1 features such as:

    Drivers
    Vehicles
    Delivery Routes
    Driver Assignment
    Delivery Tracking
    Refunds
    Loyalty
    Employee Permissions
    Multi-Branch
    Storage Capacity
    Laundry Processing Stages
    AI Assistant
    Advanced Analytics
    Predictive Analytics
    Barcode Workflows

These features require separate approved requirements.

---

## 128. Final Constraint Summary

The V1 database must enforce or structurally protect:

    Primary Keys
        +
    Foreign Keys
        +
    Required Fields
        +
    Unique Business Identifiers
        +
    Unique Compatibility Relationships
        +
    Valid Basic Values
        +
    Positive Payments
        +
    Positive Expenses
        +
    Positive Quantities
        +
    Positive Carpet Dimensions
        +
    One Active StorageRecord per OrderItem
        +
    One OrderItemCarpet per OrderItem
        +
    Historical Transaction Values
        +
    Single BusinessSettings Record
        +
    Conservative Delete Behavior
        +
    Synchronization Safety
        +
    Independent Delivery Directions
        +
    Expense / Payment Separation

For the one-to-zero-or-one Carpet relationship:

    OrderItem.id
        =
    OrderItemCarpet.order_item_id

The OrderItemCarpet record does not have an independent id Primary Key.

---

## 129. Final Business Integrity Principles

The database must preserve the following principles:

1. Every Order belongs to one Customer.
2. Every Order contains at least one physical OrderItem.
3. Every physical item has its own OrderItem identity.
4. Every OrderItem belongs to one Order.
5. Every OrderItem has one Item Type.
6. Every OrderItem has one Service.
7. Service and Item Type combinations must be valid.
8. Item Definitions are optional where the Domain allows.
9. Item Definitions must belong to their Item Type.
10. Every Payment belongs to one Order.
11. Payments are preserved as historical transactions.
12. Payment amount must be positive.
13. Expenses are independent from Orders and Payments.
14. Every Expense belongs to one Expense Category.
15. Expense amount must be positive.
16. Expense Date is used for Expense reporting.
17. Other Expenses require a custom Expense Name.
18. Expense Category names are preserved historically.
19. Net Profit is derived, not stored.
20. Outstanding Amount is derived, not stored.
21. Customer Pickup and Customer Delivery are independent.
22. Both delivery directions may be selected simultaneously.
23. Delivery fees belong to the Order.
24. Delivery fees are not Payments.
25. Delivery fees are not Expenses.
26. Every OrderItem may have at most one active StorageRecord.
27. Storage movement is represented through StorageRecords.
28. Storage Locations are ItemType-aware.
29. Inactive Storage Locations remain valid historically.
30. Completed Orders deactivate active StorageRecords.
31. Cancelled Orders deactivate active StorageRecords.
32. Manual Completed → Processing does not reactivate old StorageRecords.
33. Carpet-specific information is stored separately.
34. Carpet dimensions are preserved historically.
35. An OrderItemCarpet uses order_item_id as both its Primary Key and Foreign Key to OrderItem.
36. An OrderItem can have at most one OrderItemCarpet.
37. Service prices are master data.
38. OrderItem prices are historical transaction data.
39. Historical snapshots remain stable after master-data changes.
40. Master data is deactivated instead of destructively deleted when historical references exist.
41. Orders are cancelled rather than deleted.
42. SQLite Foreign Key enforcement must be enabled.
43. Multi-record operations must be transactional.
44. Business data changes and SyncOperations must be persisted atomically.
45. UUIDs remain stable across synchronization.
46. The database protects structural integrity.
47. The Domain/Application layer owns complex business workflows.
48. The database must remain simple enough to maintain.
49. No unsupported V1 feature should be introduced through the database schema.

---

## 130. Final Principle

The database must be:

    Strict where structural integrity matters
        +
    Flexible where business workflows belong
        +
    Safe for historical data
        +
    Safe for financial data
        +
    Safe for Offline-first synchronization
        +
    Consistent with the approved Domain Model
        +
    Simple enough to maintain

The database must protect the integrity of the Laundry Management System without becoming the business-logic engine.

The approved OrderItemCarpet identity strategy is:

    OrderItem
        |
        | 1
        |
        | 0..1
        ↓
    OrderItemCarpet

with:

    OrderItem.id
        =
    OrderItemCarpet.order_item_id

and:

    order_item_carpets.order_item_id
        =
    Primary Key
        +
    Foreign Key

This is an intentional exception to the default table.id Primary Key convention and must be preserved throughout the Drift schema, repositories, migrations, synchronization model, and tests.