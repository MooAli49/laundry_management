# Laundry Management System — Database Tables

## 1. Document Purpose

This document defines the approved V1 database tables for the Laundry Management System.

It translates the approved Domain Model into a concrete relational database structure for:

    SQLite
        +
    Drift

This document defines:

- Table names.
- Column names.
- Data types.
- Required / Nullable fields.
- Primary Keys.
- Foreign Keys.
- Defaults.
- Historical snapshot fields.
- Active / Inactive fields.
- Table-specific implementation notes.

This document must remain aligned with:

    docs/01-product/
    docs/02-domain/
    docs/03-architecture/
    docs/04-database/database-overview.md
    docs/04-database/database-decisions.md
    docs/04-database/relationships.md
    docs/04-database/constraints.md
    docs/04-database/indexes.md

This document does not define:

- Index strategy.
- Full relationship documentation.
- Detailed database constraints.
- Seed data.
- Synchronization algorithm.

Those are documented separately.

---

## 2. Database Naming Convention

Database table names use:

    snake_case
    plural nouns

Examples:

    customers
    orders
    order_items
    payments
    expenses

Column names use:

    snake_case

Examples:

    customer_id
    expected_pickup_date
    created_at

Primary key:

    id

Foreign keys:

    <entity>_id

Examples:

    customer_id
    order_id
    service_id
    expense_category_id

---

## 3. SQLite / Drift Type Conventions

The logical database types are:

    UUID
    TEXT
    INTEGER
    REAL
    BOOLEAN
    DATE
    DATETIME

Because SQLite has a limited native type system, the final physical representation follows Drift/SQLite conventions.

### UUID

Stored as:

    TEXT

UUID values must remain stable across local persistence and synchronization.

### TEXT

Used for:

- Names.
- Phone numbers.
- Order numbers.
- Notes.
- Enum values.
- Reasons.
- Human-readable identifiers.
- Historical snapshots.

### INTEGER

Used for:

- Counts.
- Boolean values where appropriate.
- Monetary minor units.
- Integer identifiers where explicitly required.

### REAL

Used only where a decimal numeric value is genuinely required.

Monetary values must not use floating-point storage.

### BOOLEAN

Stored using the SQLite/Drift-supported boolean representation.

### DATE

Used for date-only business values.

Examples:

- Expected Pickup Date.
- Expense Date.
- Report date filters.

### DATETIME

Used for timestamps and events.

Examples:

- created_at
- updated_at
- paid_at
- completed_at
- cancelled_at

---

# 4. customers

## Purpose

Stores customer information.

A Customer may have multiple Orders.

Relationship:

    Customer
        1
        ↓
    Orders
        N

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the customer.

---

### name

Type:

    TEXT

Required:

    Yes

Description:

Customer full/display name.

---

### phone

Type:

    TEXT

Required:

    Yes

Description:

Customer phone number.

The value is stored as text because phone numbers are identifiers rather than quantities.

The normalized phone value is used for uniqueness.

---

### notes

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional customer notes.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the customer was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest customer update.

---

# 5. orders

## Purpose

Stores laundry Orders.

An Order belongs to exactly one Customer.

Relationship:

    Customer
        1
        ↓
    Order
        N

An Order contains one or more physical OrderItems.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the Order.

---

### order_number

Type:

    TEXT

Required:

    Yes

Unique:

    Yes

Description:

Human-readable business Order Number.

The approved V1 format is:

    YY-XXX

Example:

    26-001

The Order Number:

- Is assigned once.
- Must remain unchanged after creation.
- Is the human-readable Order identifier.
- Is different from the internal UUID.

---

### customer_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    customers.id

Description:

Customer who owns the Order.

---

### status

Type:

    TEXT

Required:

    Yes

Default:

    processing

Allowed V1 values:

    processing
    ready
    completed
    cancelled

Arabic UI labels:

    processing → قيد التجهيز
    ready → جاهز
    completed → مكتمل
    cancelled → ملغي

The application/domain layer is responsible for validating status transitions.

Manual status changes are supported according to the approved workflow.

---

### expected_pickup_date

Type:

    DATE

Required:

    Yes

Description:

Expected customer pickup date.

This is a date-only value.

Time is intentionally not stored.

The UI uses a Date Picker.

---

### notes

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional notes associated with the Order.

---

### delivery_to_laundry_requested

Type:

    BOOLEAN

Required:

    Yes

Default:

    false

Description:

Indicates whether the customer requested the laundry to receive the items through delivery/pickup.

This is independent from customer delivery.

---

### delivery_to_laundry_fee

Type:

    INTEGER

Required:

    Yes

Default:

    0

Description:

Delivery fee charged for receiving the customer's items.

Stored in minor currency units.

Example:

    50.00 EGP
    →
    5000

This fee is part of the Order total when customer pickup is requested.

It is not a Payment.

It is not an Expense.

---

### customer_delivery_requested

Type:

    BOOLEAN

Required:

    Yes

Default:

    false

Description:

Indicates whether the laundry should deliver the completed Order to the customer.

This is independent from customer pickup.

Both:

    delivery_to_laundry_requested = true

and:

    customer_delivery_requested = true

may be true at the same time.

---

### customer_delivery_fee

Type:

    INTEGER

Required:

    Yes

Default:

    0

Description:

Delivery fee charged for sending the completed Order to the customer.

Stored in minor currency units.

Example:

    50.00 EGP
    →
    5000

This fee is part of the Order total when customer delivery is requested.

It is not a Payment.

It is not an Expense.

---

### subtotal

Type:

    INTEGER

Required:

    Yes

Description:

Order subtotal before discount, tax, and applicable delivery fees.

Stored in minor currency units.

---

### discount

Type:

    INTEGER

Required:

    Yes

Default:

    0

Description:

Discount applied to the Order.

Stored in minor currency units.

---

### tax

Type:

    INTEGER

Required:

    Yes

Default:

    0

Description:

Tax amount applied to the Order.

Stored in minor currency units.

If tax is disabled, the effective tax amount is zero.

---

### total

Type:

    INTEGER

Required:

    Yes

Description:

Final historical Order total.

The total includes applicable:

- OrderItem charges.
- Delivery fees.
- Discount.
- Tax.

Historical Order totals must remain stable unless an explicit approved Order edit changes the transaction.

---

### completed_at

Type:

    DATETIME

Required:

    No

Nullable:

    Yes

Description:

Timestamp when the Order became Completed.

Only populated when the Order is completed.

---

### cancelled_at

Type:

    DATETIME

Required:

    No

Nullable:

    Yes

Description:

Timestamp when the Order was cancelled.

Only populated when the Order is cancelled.

---

### cancellation_reason

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Reason provided when the Order is cancelled.

Required when an Order is cancelled.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Order was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Order update.

---

## Order Financial Formula

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

Only applicable delivery fees are included.

A fee must not be charged when its corresponding delivery option is not requested.

---

# 6. order_items

## Purpose

Stores the individual physical items belonging to an Order.

Every physical item has its own OrderItem record.

Example:

    Order
        ↓
    Shirt
    Shirt
    Shirt

is represented as:

    OrderItem 1
    OrderItem 2
    OrderItem 3

The UI may display:

    Shirt × 3

while the database keeps three independent physical OrderItems.

This is required because individual items may have:

- Different storage locations.
- Different notes.
- Different item-specific details.
- Independent physical identification.
- Future barcode identification.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the physical OrderItem.

---

### order_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    orders.id

Description:

Order containing the physical item.

---

### item_type_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    item_types.id

Description:

Item Type selected for this physical OrderItem.

---

### item_definition_id

Type:

    UUID / TEXT

Required:

    No

Nullable:

    Yes

Foreign Key:

    item_definitions.id

Description:

Optional Item Definition.

If provided, it must belong to the selected Item Type.

This allows examples such as:

    Item Type:
    بطاطين

    Item Definition:
    بطانية ثقيلة

---

### service_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    services.id

Description:

Service selected for this physical OrderItem.

The selected Service must support the selected Item Type.

---

### item_type_name_snapshot

Type:

    TEXT

Required:

    Yes

Description:

Historical Item Type name captured at transaction time.

This allows Order Details and Invoice output to remain historically understandable even if the current Item Type name changes later.

---

### item_definition_name_snapshot

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Historical Item Definition name captured at transaction time when applicable.

---

### service_name_snapshot

Type:

    TEXT

Required:

    Yes

Description:

Historical Service name captured at transaction time.

This value must remain unchanged when the current Service master data changes.

---

### pricing_type

Type:

    TEXT

Required:

    Yes

Description:

Historical pricing type used for this OrderItem.

Expected V1 values:

    per_piece
    per_kg
    per_square_meter
    fixed_price

The value is stored as transaction-time historical data.

---

### quantity

Type:

    Numeric

Required:

    Yes

Description:

Transaction quantity used for pricing.

The physical-item model still represents each physical piece as its own OrderItem.

Quantity may represent the pricing quantity where applicable.

Examples:

    Per Piece:
    1

    Per Kilogram:
    3.5

    Per Square Meter:
    6.25

    Fixed Price:
    1

The exact physical representation of decimal quantities must follow the approved implementation strategy.

---

### unit_price

Type:

    INTEGER

Required:

    Yes

Description:

Historical transaction-time unit price.

Stored in minor currency units.

Example:

    100.50 EGP
    →
    10050

This value must not be reconstructed from the current Service price.

---

### calculated_total

Type:

    INTEGER

Required:

    Yes

Description:

Historical calculated total for this OrderItem.

Stored in minor currency units.

This value remains stable unless an explicit approved Order edit changes it.

---

### notes

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional notes specific to the physical item.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the OrderItem was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest OrderItem update.

---

# 7. payments

## Purpose

Stores payment transactions associated with Orders.

An Order may have multiple Payments.

Relationship:

    Order
        1
        ↓
    Payments
        N

Payment history must be preserved.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the Payment.

Important for Offline-first synchronization and duplicate prevention.

---

### order_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    orders.id

Description:

Order receiving the payment.

---

### amount

Type:

    INTEGER

Required:

    Yes

Description:

Payment amount in minor currency units.

The amount must be greater than zero.

---

### payment_method

Type:

    TEXT

Required:

    Yes

Description:

Method used for the Payment.

Approved V1 values:

    cash
    instapay
    ewallet

---

### paid_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Payment was recorded.

Payment reports may use this transaction date/time when reporting Payments.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Payment record was created.

---

## Payment Data Rules

Payment records are historical transactions.

A Payment must not be overwritten simply to represent a new Payment.

Multiple Payments remain separate records.

Payment belongs to an Order.

Payment is independent from Expense.

A Payment cannot exceed the current Order remaining amount.

---

# 8. storage_locations

## Purpose

Stores physical storage locations available in the laundry.

Examples:

    A-01
    A-02
    B-01

The exact naming scheme is configurable.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the Storage Location.

---

### name

Type:

    TEXT

Required:

    Yes

Unique:

    Yes

Description:

Human-readable Storage Location name.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Determines whether the location can be selected for new storage operations.

Inactive locations remain available for historical references.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the location was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest location update.

---

# 9. storage_records

## Purpose

Represents the storage assignment of an individual physical OrderItem.

An OrderItem may have multiple historical StorageRecords.

Only one StorageRecord may be active for an OrderItem at any point in time.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the StorageRecord.

---

### order_item_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    order_items.id

Description:

Physical OrderItem being stored.

---

### storage_location_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    storage_locations.id

Description:

Current or historical Storage Location.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Indicates whether this is the current active storage assignment.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when this StorageRecord was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest StorageRecord update.

---

## Storage Rules

When an item is moved:

    Old StorageRecord
        ↓
    is_active = false

    New StorageRecord
        ↓
    is_active = true

The system must not have two active StorageRecords for the same OrderItem.

Inactive StorageRecords may be retained for data integrity and synchronization.

V1 does not expose Storage Movement History as a separate user-facing feature.

---

# 10. item_types

## Purpose

Stores the main categories of physical laundry items.

Examples:

    ملابس
    بطاطين
    سجاد

The actual list is configurable.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier.

---

### name

Type:

    TEXT

Required:

    Yes

Unique:

    Yes

Description:

Display name of the Item Type.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Determines whether the Item Type can be used for new Orders.

Inactive Item Types remain valid for historical records.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Item Type was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Item Type update.

---

# 11. item_definitions

## Purpose

Stores optional definitions/subtypes associated with Item Types.

An Item Type may have multiple Item Definitions.

Relationship:

    ItemType
        1
        ↓
    ItemDefinitions
        N

Examples:

    Item Type:
    بطاطين

    Definitions:
    بطانية عادية
    بطانية ثقيلة

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier.

---

### item_type_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    item_types.id

Description:

Parent Item Type.

---

### name

Type:

    TEXT

Required:

    Yes

Description:

Definition/subtype name.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Whether this Definition can be used for new Orders.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Definition was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Definition update.

---

# 12. services

## Purpose

Stores laundry Services and their current pricing configuration.

Examples may include:

    غسيل
    تنظيف جاف
    كي
    غسيل وطي

The exact Service list is configurable.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier.

---

### name

Type:

    TEXT

Required:

    Yes

Unique:

    Yes

Description:

Service display name.

---

### description

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional Service description.

---

### pricing_type

Type:

    TEXT

Required:

    Yes

Description:

Current pricing model for the Service.

Approved V1 values:

    per_piece
    per_kg
    per_square_meter
    fixed_price

---

### price

Type:

    INTEGER

Required:

    Yes

Description:

Current configured Service price.

Stored in minor currency units.

Example:

    100.50 EGP
    →
    10050

This is master-data pricing.

It must not be used to reconstruct historical OrderItem prices.

The current Service price is editable through Settings.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Whether the Service is available for new Orders.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Service was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Service update.

---

# 13. service_item_types

## Purpose

Junction table defining which Services are compatible with which Item Types.

Relationship:

    Service
        N
        ↕
    ServiceItemType
        ↕
    ItemType
        N

This represents the many-to-many relationship between Services and Item Types.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable identifier for the compatibility record.

---

### service_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    services.id

Description:

Service participating in the compatibility relationship.

---

### item_type_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    item_types.id

Description:

Item Type supported by the Service.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the compatibility record was created.

---

## Compatibility Rule

The same:

    service_id + item_type_id

combination must not be duplicated.

This relationship determines whether a Service can be selected for a particular Item Type.

---

# 14. storage_location_item_types

## Purpose

Junction table defining which Item Types are compatible with which Storage Locations.

Relationship:

    StorageLocation
        N
        ↕
    StorageLocationItemType
        ↕
    ItemType
        N

This allows Storage Locations to be filtered according to the selected physical item.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable identifier for the compatibility record.

---

### storage_location_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    storage_locations.id

Description:

Storage Location participating in the compatibility relationship.

---

### item_type_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    item_types.id

Description:

Item Type supported by the Storage Location.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the compatibility record was created.

---

## Compatibility Rule

The same:

    storage_location_id + item_type_id

combination must not be duplicated.

When storing an OrderItem, only Storage Locations compatible with the item's Item Type should be offered.

---

# 15. carpet_sizes

## Purpose

Stores predefined Carpet Size options.

Carpets may use:

    Predefined Carpet Size

or:

    Custom Dimensions

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier.

---

### length

Type:

    Numeric

Required:

    Yes

Description:

Length represented by the predefined size.

---

### width

Type:

    Numeric

Required:

    Yes

Description:

Width represented by the predefined size.

---

### area

Type:

    Numeric

Required:

    Yes

Description:

Calculated/defined area of the predefined size.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Whether the predefined size can be selected for new Orders.

Inactive sizes remain valid for historical records.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Carpet Size was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Carpet Size update.

---

# 16. order_item_carpets

## Purpose

Stores Carpet-specific information for an OrderItem.

This table exists because Carpet-specific fields should not be added to every OrderItem.

Relationship:

    OrderItem
        1
        ↓
    0..1 OrderItemCarpet

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable identifier for the Carpet-specific record.

---

### order_item_id

Type:

    UUID / TEXT

Required:

    Yes

Unique:

    Yes

Foreign Key:

    order_items.id

Description:

The OrderItem represented by this Carpet data.

Each Carpet OrderItem can have at most one Carpet-specific record.

---

### carpet_size_id

Type:

    UUID / TEXT

Required:

    No

Nullable:

    Yes

Foreign Key:

    carpet_sizes.id

Description:

Reference to a predefined Carpet Size when one is selected.

For custom dimensions this may be null.

---

### length

Type:

    Numeric

Required:

    Yes

Description:

Historical Carpet length used for this OrderItem.

---

### width

Type:

    Numeric

Required:

    Yes

Description:

Historical Carpet width used for this OrderItem.

---

### area

Type:

    Numeric

Required:

    Yes

Description:

Historical calculated Carpet area.

This value must be preserved with the transaction.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Carpet data was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Carpet data update.

---

## Carpet Data Rules

If a predefined Carpet Size is selected:

    carpet_size_id
        +
    Historical length
        +
    Historical width
        +
    Historical area

are stored.

If custom dimensions are entered:

    carpet_size_id = null

while:

    length
    width
    area

remain required.

The application calculates:

    length × width = area

The user does not manually calculate the area.

Historical Carpet data must not depend on future Carpet Size changes.

---

# 17. expense_categories

## Purpose

Stores configurable Expense Categories.

Expense Categories are master data.

Initial V1 seed categories:

    كهرباء
    مياه
    منظفات
    صيانة
    مستلزمات
    نقل
    أخرى

These are seed values only.

The user can manage them through Settings.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the Expense Category.

---

### name

Type:

    TEXT

Required:

    Yes

Unique:

    Yes

Description:

Display name of the Expense Category.

---

### is_active

Type:

    BOOLEAN

Required:

    Yes

Default:

    true

Description:

Determines whether the Category can be selected for new Expenses.

Inactive Categories remain valid for historical Expenses.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Category was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Category update.

---

## Expense Category Rules

The user may:

- View Categories.
- Add Category.
- Edit Category.
- Activate Category.
- Deactivate Category.

Inactive Categories cannot be selected for new Expenses.

Historical Expenses remain valid.

---

# 18. expenses

## Purpose

Stores daily operating Expenses of the laundry.

An Expense is an independent financial transaction.

Expense does not belong to:

- Order.
- OrderItem.
- Payment.
- Customer.

Relationship:

    ExpenseCategory
        1
        ↓
    Expense
        N

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Stable unique identifier for the Expense.

Important for Offline-first synchronization and duplicate prevention.

---

### expense_category_id

Type:

    UUID / TEXT

Required:

    Yes

Foreign Key:

    expense_categories.id

Description:

Category assigned to the Expense.

---

### amount

Type:

    INTEGER

Required:

    Yes

Description:

Expense amount stored in minor currency units.

Example:

    150.00 EGP
    →
    15000

The amount must be greater than zero.

---

### expense_name

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Custom transaction name for the Expense.

Required when the selected Expense Category is:

    أخرى

Example:

    التصنيف:
    أخرى

    اسم المصروف:
    إصلاح باب المحل

For normal predefined Categories, this field may remain null unless otherwise needed.

---

### expense_date

Type:

    DATE

Required:

    Yes

Description:

Business date of the Expense.

This is a date-only value.

The UI uses a Date Picker.

Financial reporting uses this field to determine whether the Expense belongs to a selected day or date range.

---

### notes

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional notes associated with the Expense.

---

### category_name_snapshot

Type:

    TEXT

Required:

    Yes

Description:

Historical Expense Category name captured at transaction time.

This preserves historical meaning if the current Expense Category is renamed later.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the Expense was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest Expense update.

---

## Expense Rules

An Expense:

- Must have an amount greater than zero.
- Must have an Expense Category.
- Must have an Expense Date.
- May have Notes.
- Requires Expense Name when Category = Other.
- Is independent from Orders.
- Is independent from Payments.
- Is included in Financial Reports according to Expense Date.

---

# 19. business_settings

## Purpose

Stores editable business-level settings.

V1 settings include:

    Business Name
    Tax Enabled
    Tax Rate

These settings are also used when generating Invoice output.

V1 is designed for a single business/branch.

Only one current settings record is expected.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Identifier for the settings record.

---

### business_name

Type:

    TEXT

Required:

    Yes

Description:

Business display name.

---

### address

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Business address used where applicable in business and invoice information.

---

### phone

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Business phone number used where applicable in business and invoice information.

---

### logo_reference

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Reference to the business logo used by the application and invoice presentation.

---

### invoice_footer_text

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional footer text displayed on invoices/receipts.

---

### tax_enabled

Type:

    BOOLEAN

Required:

    Yes

Default:

    false

Description:

Determines whether tax is enabled.

---

### tax_rate

Type:

    Numeric

Required:

    Yes

Default:

    0

Description:

Configured tax rate.

When tax is disabled, the effective tax amount is zero regardless of the stored configured rate.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest settings update.

---

# 20. sync_operations

## Purpose

Infrastructure table used by the Offline-first synchronization system.

This is not a Domain business entity.

It exists to persist pending synchronization operations.

---

## Columns

### id

Type:

    UUID / TEXT

Required:

    Yes

Primary Key:

    Yes

Description:

Unique identifier for the synchronization operation.

---

### entity_type

Type:

    TEXT

Required:

    Yes

Description:

Identifies the business entity affected by the operation.

Expected V1 values include:

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
    carpet_size
    order_item_carpet
    expense_category
    expense
    business_settings

---

### entity_id

Type:

    UUID / TEXT

Required:

    Yes

Description:

ID of the affected business entity.

---

### operation_type

Type:

    TEXT

Required:

    Yes

Description:

Type of remote operation.

Expected V1 values:

    create
    update
    deactivate

Additional operation types may be added only when required by the approved synchronization design.

---

### payload

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Optional serialized operation data.

The exact payload strategy depends on the final synchronization implementation.

---

### status

Type:

    TEXT

Required:

    Yes

Default:

    pending

Expected values:

    pending
    processing
    synced
    failed

---

### retry_count

Type:

    INTEGER

Required:

    Yes

Default:

    0

Description:

Number of synchronization attempts.

---

### last_error

Type:

    TEXT

Required:

    No

Nullable:

    Yes

Description:

Last synchronization error information.

Technical error details should not expose sensitive data.

---

### created_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp when the synchronization operation was created.

---

### updated_at

Type:

    DATETIME

Required:

    Yes

Description:

Timestamp of the latest synchronization operation update.

---

### last_attempt_at

Type:

    DATETIME

Required:

    No

Nullable:

    Yes

Description:

Timestamp of the latest synchronization attempt.

---

# 21. Table Summary

The V1 business tables are:

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

Infrastructure table:

    sync_operations

---

# 22. Business Entity to Table Mapping

The logical mapping is:

    Customer
        ↓
    customers

    Order
        ↓
    orders

    OrderItem
        ↓
    order_items

    Payment
        ↓
    payments

    StorageLocation
        ↓
    storage_locations

    StorageRecord
        ↓
    storage_records

    ItemType
        ↓
    item_types

    ItemDefinition
        ↓
    item_definitions

    Service
        ↓
    services

    ServiceItemType
        ↓
    service_item_types

    StorageLocationItemType
        ↓
    storage_location_item_types

    CarpetSize
        ↓
    carpet_sizes

    OrderItemCarpet
        ↓
    order_item_carpets

    ExpenseCategory
        ↓
    expense_categories

    Expense
        ↓
    expenses

    BusinessSettings
        ↓
    business_settings

Synchronization infrastructure:

    SyncOperation
        ↓
    sync_operations

---

# 23. Tables That Are Intentionally Not Included

The following tables are not part of V1:

    branches
    employees
    roles
    permissions
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
    delivery_tracking
    delivery_routes
    invoice_records
    profit_records
    outstanding_balance_records
    service_analytics
    customer_analytics
    storage_analytics

These features are outside the approved V1 scope or are derived from existing transaction data.

They must not be added by AI coding tools without an approved requirement change.

---

# 24. Historical Snapshot Rule

The following OrderItem information must be preserved independently from current master data:

    item_type_name_snapshot
    item_definition_name_snapshot
    service_name_snapshot
    pricing_type
    quantity
    unit_price
    calculated_total

For Carpets:

    length
    width
    area

For Expenses:

    category_name_snapshot

For delivery:

    delivery_to_laundry_fee
    customer_delivery_fee

For Orders:

    subtotal
    discount
    tax
    total

This guarantees that historical transactions remain understandable even when master data changes later.

---

# 25. Active / Inactive Rule

The following master-data tables use:

    is_active

    item_types
    item_definitions
    services
    carpet_sizes
    storage_locations
    expense_categories

Deactivation means:

    Not available for new operations

It does not mean:

    Historical data is invalid

Historical references remain valid.

---

# 26. Physical Deletion Rule

Normal V1 operations should not physically delete:

    Orders
    OrderItems
    Payments
    Expenses

Master data should generally be deactivated instead of physically deleted when historical references exist.

The exact deletion behavior and foreign-key actions are defined in:

    constraints.md

---

# 27. Monetary Storage Rule

All persisted monetary values use integer minor currency units.

Applicable fields include:

    orders.delivery_to_laundry_fee
    orders.customer_delivery_fee
    orders.subtotal
    orders.discount
    orders.tax
    orders.total
    order_items.unit_price
    order_items.calculated_total
    services.price
    payments.amount
    expenses.amount

Example:

    100.50 EGP
        ↓
    10050

Floating-point values must not be used for persisted monetary amounts.

---

# 28. Date Storage Rule

Date-only business fields use:

    DATE

Applicable fields include:

    orders.expected_pickup_date
    expenses.expense_date

The database does not store a time component for these fields.

The UI provides Date Picker controls.

---

# 29. Delivery Data Rule

V1 supports two independent delivery directions.

Customer Pickup:

    customer_pickup_requested
    delivery_to_laundry_fee

Customer Delivery:

    customer_delivery_requested
    customer_delivery_fee

The two options are independent.

All combinations are valid:

    false + false
    true + false
    false + true
    true + true

V1 does not implement:

    drivers
    vehicles
    routes
    driver assignment
    delivery tracking
    proof of delivery

Delivery fees are part of the Order financial calculation.

They are not Payment records.

They are not Expense records.

---

# 30. Expense Data Rule

Expenses are independent operating-cost transactions.

The relationship is:

    ExpenseCategory
        ↓
    Expense

There is intentionally no:

    order_id

in the expenses table.

An Expense does not belong to a Customer.

An Expense does not belong to a Payment.

An Expense is reported according to:

    expense_date

---

# 31. Net Profit Rule

Net Profit is a derived Financial Report value.

It is not stored in a dedicated database table.

For a selected report period:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

Total Sales is derived from Orders according to the approved reporting rules.

Total Operating Expenses is derived from Expenses whose:

    expense_date

falls within the selected reporting period.

Payments are reported separately and are not subtracted from Sales when calculating Net Profit.

Outstanding amounts are not Expenses.

---

# 32. Outstanding Amount Rule

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

---

# 33. Invoice Data Rule

V1 does not persist an Invoice as a separate business entity.

Invoice output is generated from existing data:

    BusinessSettings
        +
    Customer
        +
    Order
        +
    OrderItems
        +
    Payments

Invoice output must display sufficient item information including:

- Item Type.
- Item Definition where applicable.
- Service.
- Quantity.
- Transaction price.
- Carpet Size where applicable.
- Carpet dimensions where applicable.
- Order totals.
- Payment information.

No dedicated:

    invoices

table is required for V1.

---

# 34. Item Detail Persistence Rule

OrderItem must preserve enough information to support:

- Order Details.
- Invoice.
- Storage.
- Historical reporting.

Important information includes:

    Item Type
    Item Definition where applicable
    Service
    Quantity
    Pricing Type
    Unit Price
    Calculated Total

For Carpets:

    Carpet Size where applicable
    Length
    Width
    Area

The current master data must not be required to reconstruct historical transaction information.

---

# 35. Storage Filtering Rule

Storage Locations are ItemType-aware.

The compatibility path is:

    OrderItem
        ↓
    ItemType
        ↓
    StorageLocationItemType
        ↓
    StorageLocation

When an operator selects an OrderItem for storage, the application should display only compatible Storage Locations.

Example:

    Selected Item:
    Carpet

    ↓

    Item Type:
    Carpets

    ↓

    Compatible Storage Locations:
    Carpet-A
    Carpet-B

Locations configured only for Clothes should not appear as valid storage options.

---

# 36. Storage State Rule

The current Storage Location of an OrderItem is determined by its active StorageRecord.

Conceptually:

    OrderItem
        ↓
    StorageRecords
        ├── inactive
        ├── inactive
        └── active

If there is no active StorageRecord:

    Item requires storage

If there is an active StorageRecord:

    Item is currently stored

There may be only one active StorageRecord per OrderItem.

---

# 37. Order Ready Rule

An Order becomes Ready when all physical OrderItems have active StorageRecords.

Conceptually:

    Order
        ↓
    OrderItems
        ↓
    Every OrderItem has active StorageRecord
        ↓
    Order = Ready

Ready is derived from Storage completion.

The database must not introduce a separate:

    storage_completed

entity.

---

# 38. Completed / Cancelled Storage Rule

When an Order becomes Completed:

    Active StorageRecords
        ↓
    become inactive

When an Order becomes Cancelled:

    Active StorageRecords
        ↓
    become inactive

The historical StorageRecords remain preserved.

---

# 39. Service Pricing Rule

The Service table contains the current master price.

The OrderItem table contains the historical transaction price.

Therefore:

    services.price

may change.

But:

    order_items.unit_price

must remain historically stable.

Example:

Current Service:

    غسيل
    150 EGP

Historical OrderItem:

    120 EGP

Changing the Service price to:

    160 EGP

does not modify the historical OrderItem price.

---

# 40. Expense Category Rule

Expense Categories are configurable master data.

Changing:

    expense_categories.name

must not make historical Expenses ambiguous.

Each Expense therefore stores:

    category_name_snapshot

This allows historical reports to preserve the transaction-time Category name.

---

# 41. Carpet Historical Rule

Carpet master data may change.

Historical Carpet transactions must remain stable.

The OrderItemCarpet record therefore stores:

    length
    width
    area

and optionally:

    carpet_size_id

The historical transaction does not depend on the current Carpet Size dimensions.

---

# 42. Master Data Deactivation

The following master data is deactivated rather than destructively deleted when historical references exist:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory

Inactive master data:

    Cannot be selected for new transactions.

Historical transactions:

    Remain valid.

---

# 43. Database Implementation Rule

The table definitions in this document represent the logical V1 schema.

During Drift implementation:

1. Create tables according to this document.
2. Preserve the defined relationships.
3. Preserve required/nullable semantics.
4. Preserve historical snapshots.
5. Use UUID-based stable IDs.
6. Store monetary values as integer minor units.
7. Add only approved indexes.
8. Add only approved constraints.
9. Do not invent new business columns.
10. Do not remove required business columns.
11. Do not introduce tables for out-of-scope V1 features.
12. Preserve Offline-first behavior.
13. Preserve synchronization readiness.

---

# 44. Transactional Integrity

Operations modifying multiple related records should execute atomically.

Important examples:

    Create Order
        +
    Create OrderItems

    Record Payment
        +
    Update related derived financial state where applicable

    Create Expense
        +
    Create SyncOperation

    Move OrderItem
        +
    Deactivate old StorageRecord
        +
    Create new StorageRecord

    Complete Order
        +
    Update Order
        +
    Deactivate active StorageRecords

    Cancel Order
        +
    Update Order
        +
    Deactivate active StorageRecords

    Bulk Storage
        +
    Multiple StorageRecords

The goal is to prevent partially committed business operations.

---

# 45. Offline-first Requirements

The local database must support normal operations without network access.

The following operations must work locally:

    Create Customer
    Create Order
    Add OrderItem
    Edit Order
    Record Payment
    Create Expense
    Store Item
    Move Item
    Search Customers
    Search Orders
    View Dashboard
    View Reports
    View Financial Report

Remote synchronization happens afterward.

---

# 46. Synchronization Readiness

All major business entities use stable UUIDs.

Synchronization must preserve:

    Customer relationships
    Order relationships
    OrderItem relationships
    Payment relationships
    Expense relationships
    Storage relationships
    Master-data relationships

The Sync Engine uses:

    sync_operations

to track pending synchronization operations.

---

# 47. Sync Entity Coverage

The synchronization infrastructure must support changes to:

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

The synchronization layer must not require a separate SyncOperation business entity.

---

# 48. Database Simplicity

The database should remain as simple as possible while preserving business correctness.

Do not introduce tables solely for:

- Architectural fashion.
- Future speculation.
- Generic abstraction.
- Premature analytics.
- Features outside V1.

Every table must have a clear business or infrastructure purpose.

---

# 49. V1 Database Non-Goals

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
    Delivery Tracking
    Profit
    Outstanding Balance
    Invoice Records
    Advanced Analytics
    Predictive Analytics

These may be introduced later if the approved product scope changes.

---

# 50. Derived Financial Values

The following values are derived rather than independent business transactions:

    Total Paid
    Remaining Amount
    Net Profit
    Current Storage State
    Items Requiring Storage
    Dashboard Counts
    Financial Report Aggregates

The source transaction tables remain authoritative.

---

# 51. Financial Report Data Sources

The Financial Report derives its information from:

Sales:

    orders

Payments:

    payments

Expenses:

    expenses

Remaining Amount:

    orders
        +
    payments

Net Profit:

    orders
        -
    expenses

Expense Categories:

    expense_categories

The reporting layer must not depend on a duplicated financial reporting table.

---

# 52. Expense Reporting

For a single selected date:

    expenses.expense_date
        =
    selected_date

For a selected date range:

    start_date
        <=
    expenses.expense_date
        <=
    end_date

The Financial Report may display:

    Total Expenses

and:

    Expenses by Category

and:

    Net Profit

The report must use the Expense transactions for the selected period.

---

# 53. Dashboard Quick Actions and Database

The Dashboard Quick Actions are:

    Add Order
    Add Customer
    Record Payment
    Add Expense

These actions map directly to existing business entities.

No QuickAction database table is required.

Storage remains a dedicated operational workflow and does not require a QuickAction table.

---

# 54. Order Details Data Requirements

The Order Details screen must be able to retrieve:

    Order
        +
    Customer
        +
    OrderItems
        +
    Payments
        +
    Storage State

For each OrderItem, the screen must be able to show:

    Item Type
    Item Definition where applicable
    Service
    Quantity
    Price
    Total

For Carpet items:

    Carpet Size where applicable
    Length
    Width
    Area

The data must remain available even if current master data changes.

---

# 55. Invoice Data Requirements

Invoice generation uses:

    business_settings
    customers
    orders
    order_items
    payments

The Invoice must display historical transaction information.

For each item it should be possible to display:

    Item Type
    Item Definition where applicable
    Service
    Quantity
    Unit Price
    Item Total

For Carpets:

    Carpet Size where applicable
    Length
    Width
    Area

The Invoice does not require its own persistent database table in V1.

---

# 56. Final Table List

The complete approved V1 database table list is:

    1. customers
    2. orders
    3. order_items
    4. payments
    5. storage_locations
    6. storage_records
    7. item_types
    8. item_definitions
    9. services
    10. service_item_types
    11. storage_location_item_types
    12. carpet_sizes
    13. order_item_carpets
    14. expense_categories
    15. expenses
    16. business_settings
    17. sync_operations

---

# 57. Final Database Structure

The approved V1 relational structure is:

    Customer
        ↓
    Order
        ├── OrderItems
        │     ├── ItemType
        │     │     └── ItemDefinition
        │     │
        │     ├── Service
        │     │     └── ServiceItemType
        │     │
        │     ├── OrderItemCarpet
        │     │     └── CarpetSize
        │     │
        │     └── StorageRecords
        │           └── StorageLocation
        │                 └── StorageLocationItemType
        │
        └── Payments

    ExpenseCategory
        ↓
    Expense

    BusinessSettings

    SyncOperation

The two delivery directions are represented directly on:

    orders

using:

    customer_pickup_requested
    delivery_to_laundry_fee
    customer_delivery_requested
    customer_delivery_fee

---

# 58. Final Approved Database Table Principles

1. UUIDs are used as technical primary keys.
2. Order Number is a separate unique human-readable identifier.
3. Money is stored as integer minor currency units.
4. Customers can have multiple Orders.
5. Orders contain individual physical OrderItems.
6. Every physical item has its own OrderItem ID.
7. OrderItems preserve transaction-time item information.
8. ItemType and ItemDefinition are separate concepts.
9. Service and ItemType compatibility is many-to-many.
10. Storage Location and ItemType compatibility is many-to-many.
11. Storage is assigned to physical OrderItems.
12. An OrderItem may have multiple historical StorageRecords.
13. An OrderItem may have at most one active StorageRecord.
14. Carpet-specific data is stored separately.
15. Carpet dimensions are preserved historically.
16. Services store current master pricing.
17. OrderItems store historical transaction pricing.
18. Payments belong to Orders.
19. Payments are independent from Expenses.
20. Expense Categories are configurable master data.
21. Expenses are independent from Orders.
22. Other Expenses require a custom Expense name.
23. Expense Date is the reporting date.
24. Expense Category names are preserved historically.
25. Pickup and Customer Delivery are independent.
26. Both delivery directions may be selected simultaneously.
27. Delivery fees are stored on Orders.
28. Delivery fees are part of the Order total.
29. Delivery fees are not Payments.
30. Delivery fees are not Expenses.
31. Net Profit is derived.
32. Net Profit equals Sales minus Operating Expenses for the selected period.
33. Outstanding Amount is derived.
34. Invoice output is generated from existing transaction data.
35. Invoice does not require a persistent Invoice table in V1.
36. Master data uses deactivation instead of destructive deletion where historical references exist.
37. Historical transaction data remains stable.
38. Financial reports use authoritative transaction data.
39. The database supports Offline-first operation.
40. Synchronization uses stable UUIDs and sync_operations.
41. Database relationships must preserve referential integrity.
42. Database constraints are documented separately.
43. Database indexes are documented separately.
44. The schema must remain simple and avoid unnecessary V1 entities.
45. The table model must remain aligned with Product, Domain, Architecture, API, and UI/UX documentation.

---

# 59. Final Approved V1 Schema Baseline

This document is the approved logical V1 database table baseline for the Laundry Management System.

Any future schema change must be evaluated against:

    requirements.md
    scope.md
    business-rules.md
    domain-model.md
    entities.md
    architecture.md
    data-layer.md
    database-overview.md
    database-decisions.md
    relationships.md
    constraints.md
    indexes.md

No new table, column, relationship, or database behavior should be introduced without a corresponding approved business or technical requirement.