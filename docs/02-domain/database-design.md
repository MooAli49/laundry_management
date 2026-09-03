# Laundry Management System — Database Design

## 1. Document Purpose

This document defines the database design for the V1 Laundry Management System.

It translates the approved domain model into a concrete relational data structure.

This document is based on:

- `docs/01-product/product-overview.md`
- `docs/01-product/requirements.md`
- `docs/01-product/scope.md`
- `docs/01-product/business-rules.md`
- `docs/02-domain/domain-model.md`

This document defines:

- Tables
- Columns
- Relationships
- Primary keys
- Foreign keys
- Constraints
- Indexes
- Historical snapshots
- Active/inactive behavior

It does not define Flutter architecture or UI implementation.

---

# 2. Database Principles

The database must follow these principles:

1. Every physical laundry item is represented independently.
2. Transactional data must preserve historical information.
3. Master data must not overwrite historical transaction data.
4. Current Storage must be directly queryable.
5. An OrderItem may have at most one active Storage Record.
6. Master data should use active/inactive state instead of destructive deletion where historical references exist.
7. The schema should avoid unnecessary nullable columns.
8. The schema should remain simple enough for V1.
9. The schema should support offline-first local operation.
10. The schema should remain compatible with future synchronization.

---

# 3. Database Technology Direction

The application is Offline-First.

The local database is the primary operational database for the application.

The exact database technology and ORM implementation are architecture decisions and are not defined by this document.

The logical relational schema defined here must be implementable in the selected local database.

The same domain structure should be representable in the remote backend.

---

# 4. Primary Keys

All main entities should have an internal unique identifier.

The preferred conceptual type is:

> UUID

Primary keys must not depend on human-readable business identifiers.

For example:

```text
Order.id
```

and:

```text
Order.orderNumber
```

are separate concepts.

---

# 5. Common Entity Metadata

Where applicable, entities should contain:

```text
id
createdAt
updatedAt
```

Master/configuration entities should additionally support:

```text
isActive
```

The exact timestamp storage format is an implementation detail.

---

# 6. Customer Table

## Table

```text
customers
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| name | String | Yes | Customer name |
| phone | String | Yes | Customer phone number |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Constraints

- `id` is the primary key.
- `phone` should be unique.
- `name` cannot be null.
- `phone` cannot be null.

## Relationships

```text
customers 1 ──────── N orders
```

---

# 7. Order Table

## Table

```text
orders
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| order_number | String | Yes | Human-readable unique order number |
| customer_id | UUID | Yes | Reference to customer |
| status | Enum/String | Yes | Processing / Ready / Completed / Cancelled |
| expected_pickup_date | Date | Yes | Expected customer pickup date |
| delivery_requested | Boolean | Yes | Whether customer requested delivery |
| subtotal | Decimal | Yes | Calculated order subtotal |
| discount | Decimal | Yes | Order-level discount |
| tax | Decimal | Yes | Tax amount, zero when disabled |
| total | Decimal | Yes | Final order total |
| notes | String | No | General order notes |
| cancellation_reason | String | No | Reason for cancellation |
| cancelled_at | DateTime | No | Cancellation timestamp |
| completed_at | DateTime | No | Completion timestamp |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Constraints

- `id` is the primary key.
- `order_number` must be unique.
- `customer_id` must reference an existing customer.
- `expected_pickup_date` cannot be null.
- `status` cannot be null.
- `delivery_requested` cannot be null.
- Monetary values cannot be negative.
- `discount` cannot exceed the applicable subtotal.
- `total` cannot be negative.

## Relationships

```text
customers 1 ──────── N orders

orders 1 ──────── N order_items

orders 1 ──────── N payments
```

---

# 8. Order Status Storage

The database must store one of exactly four V1 statuses:

```text
processing
ready
completed
cancelled
```

The database must not introduce additional operational statuses without an approved requirement change.

The application/domain layer remains responsible for validating status transitions.

---

# 9. Order Item Table

## Table

```text
order_items
```

Each row represents one physical laundry piece.

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique physical item identifier |
| order_id | UUID | Yes | Parent order |
| item_type_id | UUID | Yes | Primary item type |
| item_definition_id | UUID | No | Specific item definition |
| service_id | UUID | No | Selected service reference |
| item_type_name_snapshot | String | Yes | Historical item type name |
| item_definition_name_snapshot | String | No | Historical item definition name |
| service_name_snapshot | String | No | Historical service name |
| pricing_type_snapshot | Enum/String | No | Historical pricing type |
| unit_price | Decimal | Yes | Historical unit price |
| calculated_total | Decimal | Yes | Historical calculated item total |
| notes | String | No | Item-specific notes |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Important

The `order_items` table must not use a quantity column as a replacement for physical item identity.

If the user enters:

```text
Shirt × 5
```

the database stores:

```text
5 rows in order_items
```

not:

```text
1 row with quantity = 5
```

This is required because each physical item has an independent storage location and future barcode identity.

---

# 10. Order Item Historical Snapshots

The OrderItem stores historical values so existing orders remain stable when master data changes.

The following values should be preserved directly on the OrderItem:

- Item Type name
- Item Definition name when applicable
- Service name when applicable
- Pricing Type
- Unit Price
- Calculated Total

The corresponding foreign keys may still exist for reference to the current master data.

Example:

```text
service_id = service-123

service_name_snapshot = "غسيل وكي"

unit_price = 40
```

If the current Service later becomes:

```text
service_name = "غسيل وكي"
price = 50
```

the historical OrderItem still represents:

```text
40 ج.م
```

---

# 11. Item Type Table

## Table

```text
item_types
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| name | String | Yes | Item type name |
| is_active | Boolean | Yes | Availability for new operations |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Initial Types

The database must support:

```text
Clothing
Blankets
Carpets
Carpet Covers
```

The exact stored IDs are implementation data.

---

# 12. Item Definition Table

## Table

```text
item_definitions
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| item_type_id | UUID | Yes | Parent Item Type |
| name | String | Yes | Definition name |
| is_active | Boolean | Yes | Availability for new orders |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Relationship

```text
item_types 1 ──────── N item_definitions
```

## Constraints

- `item_type_id` must reference an existing Item Type.
- Definition names should be unique within the same Item Type.

---

# 13. Service Table

## Table

```text
services
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| name | String | Yes | Service name |
| pricing_type | Enum/String | Yes | Per Piece / Per Kilogram / Per Square Meter / Fixed Price |
| price | Decimal | Yes | Current service price |
| is_active | Boolean | Yes | Availability for new orders |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Constraints

- `price` cannot be negative.
- `pricing_type` must be one of the supported pricing types.
- Inactive services cannot be selected for new OrderItems.
- Existing OrderItems remain valid after service deactivation.

---

# 14. Service Item Type Relation

A Service may be available for multiple Item Types.

An Item Type may support multiple Services.

Therefore this is a many-to-many relationship.

## Table

```text
service_item_types
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| service_id | UUID | Yes | Service reference |
| item_type_id | UUID | Yes | Item Type reference |

## Primary Key

Composite primary key:

```text
(service_id, item_type_id)
```

## Relationship

```text
services N ──────── M item_types
```

---

# 15. Carpet Size Table

## Table

```text
carpet_sizes
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| length | Decimal | Yes | Length |
| width | Decimal | Yes | Width |
| area | Decimal | Yes | Calculated area |
| is_active | Boolean | Yes | Available for new orders |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Area

Area is calculated as:

```text
area = length × width
```

The stored Area exists for convenience and historical consistency.

---

# 16. Carpet Item Data

Carpet-specific values belong to the OrderItem rather than the CarpetSize master table alone.

The OrderItem must preserve:

- Length
- Width
- Area

These values represent the actual carpet submitted in that historical order.

---

# 17. Carpet Order Item Data Table

Because Carpet-specific fields should not create unnecessary nullable columns in the main `order_items` table, carpet-specific data should be separated.

## Table

```text
order_item_carpets
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| order_item_id | UUID | Yes | Reference to OrderItem |
| length | Decimal | Yes | Actual carpet length |
| width | Decimal | Yes | Actual carpet width |
| area | Decimal | Yes | Actual calculated area |
| carpet_size_id | UUID | No | Predefined size used during entry |

## Primary Key

```text
order_item_id
```

## Relationship

```text
order_items 1 ──────── 0..1 order_item_carpets
```

## Important

`carpet_size_id` is optional.

It represents the predefined size selected during entry.

The actual:

- Length
- Width
- Area

remain stored directly in `order_item_carpets`.

Therefore, deactivating or changing a CarpetSize does not affect historical orders.

---

# 18. Storage Location Table

## Table

```text
storage_locations
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| name | String | Yes | Location name |
| is_active | Boolean | Yes | Whether available for new storage operations |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Constraints

- Location name should be unique.
- Inactive locations should not be selectable for new storage assignments.
- Existing historical references must remain valid.

---

# 19. Storage Record Table

## Table

```text
storage_records
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| order_item_id | UUID | Yes | Physical OrderItem |
| storage_location_id | UUID | Yes | Current Storage Location |
| is_active | Boolean | Yes | Whether this is the current active storage record |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Relationships

```text
order_items 1 ──────── N storage_records

storage_locations 1 ──────── N storage_records
```

However, for each OrderItem:

```text
Maximum active StorageRecord = 1
```

---

# 20. Active Storage Constraint

The database/application must guarantee:

```text
One OrderItem
      ↓
Maximum one active StorageRecord
```

Conceptually:

```text
order_item_id = X

storage_records:

Record A → inactive
Record B → active
```

is valid.

But:

```text
Record A → active
Record B → active
```

for the same OrderItem is invalid.

The exact implementation of the unique active constraint depends on the selected database technology.

---

# 21. Storage Movement

V1 does not require a Storage Movement History table.

Moving an item means changing its current active StorageRecord.

Example:

```text
Before:

OrderItem X → A-03

After:

OrderItem X → B-02
```

The historical movement:

```text
A-03 → B-02
```

does not need to be preserved in V1.

---

# 22. Payment Table

## Table

```text
payments
```

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| order_id | UUID | Yes | Parent order |
| amount | Decimal | Yes | Payment amount |
| payment_method | Enum/String | Yes | Cash / InstaPay / E-Wallet |
| paid_at | DateTime | Yes | Payment timestamp |
| created_at | DateTime | Yes | Creation timestamp |

## Relationship

```text
orders 1 ──────── N payments
```

## Constraints

- `amount` must be greater than zero.
- Payment amount must not exceed the remaining Order amount.
- Payment method must be one of the supported V1 methods.

---

# 23. Payment Method Values

The database must support:

```text
cash
instapay
ewallet
```

The application may display Arabic labels:

```text
Cash      → نقدي
InstaPay  → إنستا باي
E-Wallet  → محفظة إلكترونية
```

---

# 24. Business Settings Table

## Table

```text
business_settings
```

V1 operates with one business configuration.

## Columns

| Column | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Primary key |
| business_name | String | Yes | Laundry/business name |
| tax_enabled | Boolean | Yes | Whether tax is enabled |
| tax_rate | Decimal | Yes | Tax percentage/rate |
| created_at | DateTime | Yes | Creation timestamp |
| updated_at | DateTime | Yes | Last update timestamp |

## Fixed Configuration

The database does not need configurable entities for:

- Branch
- Currency
- Language

V1 values are:

```text
Branch   = Single Branch
Currency = EGP
Language = Arabic
RTL      = Enabled
```

---

# 25. Tax Data

Tax is disabled by default.

The Order stores:

```text
tax
```

as the historical calculated tax amount.

This allows future tax support without requiring historical orders to be recalculated.

When tax is disabled:

```text
tax = 0
```

---

# 26. Order Total Data

The Order stores its calculated monetary values:

```text
subtotal
discount
tax
total
```

These values represent the historical financial state of the Order.

They should not be recalculated from current Service prices after the Order has been created unless the Order is intentionally edited according to the business rules.

---

# 27. Order Item Total Data

Each OrderItem stores:

```text
unit_price
calculated_total
```

These values represent the historical price used for that item.

The exact calculation depends on the Pricing Type.

---

# 28. Pricing Type Values

The database must support:

```text
per_piece
per_kilogram
per_square_meter
fixed_price
```

The exact implementation may use an enum or constrained string depending on the selected database technology.

---

# 29. Entity Relationship Diagram

The logical database relationship is:

```text
customers
    │
    │ 1:N
    ▼
orders
    │
    ├─────────────── 1:N ───────────────► payments
    │
    │ 1:N
    ▼
order_items
    │
    ├─────────────── 0..1 ──────────────► order_item_carpets
    │                                      │
    │                                      └──► carpet_sizes
    │
    └─────────────── 0..1 active ────────► storage_records
                                             │
                                             └──► storage_locations


item_types
    │
    └─────────────── 1:N ───────────────► item_definitions


services
    │
    └─────────────── N:M ───────────────► item_types
```

---

# 30. Foreign Key Summary

## orders

```text
orders.customer_id
    → customers.id
```

## order_items

```text
order_items.order_id
    → orders.id

order_items.item_type_id
    → item_types.id

order_items.item_definition_id
    → item_definitions.id

order_items.service_id
    → services.id
```

## item_definitions

```text
item_definitions.item_type_id
    → item_types.id
```

## service_item_types

```text
service_item_types.service_id
    → services.id

service_item_types.item_type_id
    → item_types.id
```

## order_item_carpets

```text
order_item_carpets.order_item_id
    → order_items.id

order_item_carpets.carpet_size_id
    → carpet_sizes.id
```

## storage_records

```text
storage_records.order_item_id
    → order_items.id

storage_records.storage_location_id
    → storage_locations.id
```

## payments

```text
payments.order_id
    → orders.id
```

---

# 31. Delete Behavior

The database must avoid destructive deletion when historical data depends on a record.

## Customer

Customers with historical Orders must not be hard-deleted.

---

## Order

Orders must not be hard-deleted as part of normal V1 operation.

Cancellation is used instead.

---

## OrderItem

OrderItems belonging to historical Orders must not be hard-deleted as part of normal business operations.

---

## Service

Services should be deactivated instead of deleted when historical OrderItems reference them.

---

## ItemType

ItemTypes referenced by historical OrderItems should not be destructively deleted.

---

## ItemDefinition

ItemDefinitions referenced by historical OrderItems should be deactivated instead of deleted.

---

## CarpetSize

CarpetSizes referenced by historical OrderItems should be deactivated instead of deleted.

---

## StorageLocation

StorageLocations referenced by historical StorageRecords should not be destructively deleted.

---

# 32. Active/Inactive Behavior

The following master entities use `is_active`:

```text
item_types
item_definitions
services
carpet_sizes
storage_locations
```

General rule:

```text
is_active = true
    ↓
Available for applicable new operations

is_active = false
    ↓
Not available for new operations
Historical references remain valid
```

---

# 33. Indexing Strategy

Indexes should be created for frequently searched or filtered fields.

## Customers

Recommended indexes:

```text
customers.phone
customers.name
```

---

## Orders

Recommended indexes:

```text
orders.order_number
orders.customer_id
orders.status
orders.expected_pickup_date
orders.created_at
```

Search may also require appropriate indexing for:

```text
customer name
customer phone
```

depending on the query strategy.

---

## OrderItems

Recommended indexes:

```text
order_items.order_id
order_items.item_type_id
order_items.service_id
```

---

## Storage

Recommended indexes:

```text
storage_records.order_item_id
storage_records.storage_location_id
storage_records.is_active
```

A database-specific unique/index strategy should enforce:

```text
one active storage record per order item
```

---

## Payments

Recommended indexes:

```text
payments.order_id
payments.paid_at
payments.payment_method
```

---

# 34. Order Search

The database should support searching orders by:

- Order Number
- Customer Name
- Customer Phone

Because Customer information is stored separately, order search may require a join between:

```text
orders
+
customers
```

The exact full-text/search implementation is an architecture concern.

---

# 35. Order Pagination

Orders are expected to grow over time.

The database layer must support efficient incremental loading.

The preferred operational behavior is:

```text
Initial batch
      ↓
User approaches end
      ↓
Load next batch
```

Traditional numbered pages are not required in the UI.

The exact pagination strategy is an implementation decision.

---

# 36. Current Storage Query

Current Storage should be queryable by selecting active StorageRecords:

```text
storage_records.is_active = true
```

This allows the system to retrieve:

```text
OrderItem
+
Order
+
Customer
+
StorageLocation
```

for the current physical storage view.

---

# 37. Items Requiring Storage Query

An OrderItem requires storage when:

```text
OrderItem has no active StorageRecord
```

For active operational orders, the system can identify such items by checking for the absence of an active StorageRecord.

---

# 38. Completed Order Storage Behavior

When an Order becomes Completed:

```text
orders.status = completed
```

and:

```text
all related active storage_records.is_active = false
```

The OrderItems remain unchanged.

Their historical data remains available.

---

# 39. Cancelled Order Storage Behavior

When an Order becomes Cancelled:

```text
orders.status = cancelled
```

and:

```text
all related active storage_records.is_active = false
```

The OrderItems and payments remain preserved.

---

# 40. Manual Status Correction

Changing:

```text
completed → processing
```

must not reactivate previously inactive StorageRecords.

Therefore:

```text
Order Status = Processing
```

does not imply:

```text
Storage Records = Active
```

The user must explicitly store the items again.

---

# 41. Order Completion Data

When an Order becomes Completed, the database should preserve:

```text
completed_at
```

This represents the time the order was completed/handover was confirmed.

The exact UI behavior around timestamps is separate from this database requirement.

---

# 42. Cancellation Data

When an Order becomes Cancelled, the database should preserve:

```text
cancelled_at
cancellation_reason
```

These fields are historical information.

---

# 43. Financial Data Integrity

The following values must be internally consistent:

```text
Order Subtotal
Order Discount
Order Tax
Order Total
Payments
Remaining Amount
```

Conceptually:

```text
Subtotal
   -
Discount
   +
Tax
   =
Total
```

and:

```text
Total
   -
Sum(Payments)
   =
Remaining Amount
```

Remaining Amount may be calculated rather than stored.

---

# 44. Derived vs Stored Values

The database should distinguish between:

## Historical values that should be stored

- OrderItem unit price
- OrderItem calculated total
- Order subtotal
- Order discount
- Order tax
- Order total
- Carpet length
- Carpet width
- Carpet area
- Historical names required for reconstruction

## Values that may be derived

- Total Paid
- Remaining Amount
- Current Storage state
- Overdue state
- Dashboard counts

The final choice of derived vs cached values may depend on implementation requirements, but historical transaction values must remain stable.

---

# 45. Offline-First Considerations

The local database must support normal CRUD operations without network access.

All core entities must be available locally:

```text
customers
orders
order_items
item_types
item_definitions
services
carpet_sizes
storage_locations
storage_records
payments
business_settings
```

The application must not require a network request to:

- Create an Order
- Add an OrderItem
- Store an item
- Move an item
- Record a Payment
- Search local data

---

# 46. Synchronization Readiness

The schema should be compatible with future synchronization.

Every major entity should have a stable unique identifier.

The local database should not rely on auto-increment integer IDs as the only identity mechanism.

Future synchronization may require additional metadata such as:

```text
sync_status
last_synced_at
deleted_at
version
```

These are not mandatory V1 domain fields unless required by the selected synchronization architecture.

---

# 47. Data Consistency Rules

The database/application layer must preserve:

1. Every Order references an existing Customer.
2. Every OrderItem references an existing Order.
3. Every OrderItem has an independent ID.
4. Every OrderItem references a valid ItemType.
5. An ItemDefinition belongs to the referenced ItemType.
6. A Service selected for an OrderItem must support its ItemType.
7. An OrderItem can have at most one active StorageRecord.
8. A StorageRecord references an existing StorageLocation.
9. A Payment references an existing Order.
10. Payment amount must be positive.
11. Payment amount must not exceed the Order's remaining amount.
12. Historical prices must not depend on the current Service price.
13. Historical carpet measurements must not depend on the current CarpetSize.
14. Completed Orders must not have active StorageRecords.
15. Cancelled Orders must not have active StorageRecords.

---

# 48. Database Constraints vs Domain Rules

Not every business rule should be implemented purely as a database constraint.

The responsibility should be divided.

## Database Should Enforce

Where practical:

- Primary keys
- Foreign keys
- Unique Order Number
- Unique Customer Phone
- Valid required fields
- Positive monetary values
- One active StorageRecord per OrderItem

## Domain/Application Layer Should Enforce

Examples:

- Order status transitions
- Completion preconditions
- Customer handover confirmation
- Automatic Processing → Ready behavior
- Cancellation workflow
- Service compatibility validation
- Payment remaining amount validation
- Business-specific pricing calculations

The exact implementation architecture will be documented separately.

---

# 49. Database Non-Goals

The database must not introduce V1 tables for concepts that are explicitly out of scope.

Do not create dedicated tables for:

- Drivers
- Vehicles
- Delivery routes
- Employees
- Roles
- Permissions
- Branches
- Refunds
- Loyalty
- Storage movement history
- Storage capacity
- Laundry processing stages
- AI assistant
- Barcode scanning workflow

Future requirements may introduce these later.

---

# 50. Schema Stability

The database schema should remain aligned with the approved Domain Model.

Any new table or relationship must have a corresponding business/domain reason.

Technical convenience alone is not sufficient justification for introducing a new business entity.

If a database requirement conflicts with the Domain Model, the Domain Model and relevant product documentation must be reviewed before implementation.

---

# 51. Source of Truth

This document defines the approved V1 logical database design.

The final physical implementation may adapt:

- Data types
- Naming conventions
- Index syntax
- Constraint syntax
- ORM mappings

to the selected technology.

However, such implementation changes must preserve the logical relationships and business meaning defined here.

Architecture-specific implementation details belong in:

> `docs/03-architecture/architecture.md`