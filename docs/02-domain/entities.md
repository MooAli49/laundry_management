# Laundry Management System — Entities

## 1. Document Purpose

This document defines the application-level entity contracts for the V1 Laundry Management System.

It describes the entities, their properties, types, nullability, relationships, and important data rules.

This document is based on:

- `docs/01-product/product-overview.md`
- `docs/01-product/requirements.md`
- `docs/01-product/scope.md`
- `docs/01-product/business-rules.md`
- `docs/02-domain/domain-model.md`
- `docs/02-domain/database-design.md`

This document is intended to provide a clear contract for implementation.

It does not define:

- Flutter architecture
- State management
- Repository implementation
- Database-specific SQL
- API implementation
- UI models

Those concerns are documented separately.

---

# 2. Entity Classification

The V1 entities are grouped into four categories.

## 2.1 Transactional Entities

Customer

Order

OrderItem

Payment

Expense

StorageRecord

These represent operational or historical business data.

---

## 2.2 Master Data Entities

ItemType

ItemDefinition

Service

ServiceItemType

CarpetSize

StorageLocation

ExpenseCategory

These represent configurable business data used by transactions.

---

## 2.3 Configuration Entities

BusinessSettings

These represent limited business configuration required by V1.

---

## 2.4 Item-Specific Data Entities

CarpetItemData

These contain additional data that applies only to specific Item Types.

This approach prevents unrelated fields from being added to every OrderItem.

---

# 3. Common Conventions

## 3.1 Entity IDs

Every main entity has:

id: UUID

The internal ID is separate from any human-readable business identifier.

---

## 3.2 Timestamps

Entities that are mutable or transactional should support:

createdAt: DateTime

updatedAt: DateTime

Where an event-specific timestamp is required, it is stored separately.

Examples:

completedAt

cancelledAt

paidAt

---

## 3.3 Nullable Values

A property is nullable only when the business domain allows the value to be absent.

Nullable properties must not be used simply because a universal entity model is convenient.

---

## 3.4 Money

All monetary values use:

Egyptian Pound (EGP)

V1 uses integer minor units for monetary storage.

Example:

100.50 EGP

is represented as:

10050 piastres

Financial storage must not use floating-point representation.

The UI displays:

ج.م

Because V1 supports only one currency, currency is not stored as configurable data on every entity.

---

# 4. Customer Entity

## Entity

Customer

## Purpose

Represents a laundry customer.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique customer identifier |
| name | String | Yes | Customer name |
| phone | String | Yes | Customer phone number |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Relationships

Customer

1:N → Order

## Rules

- `name` is required.
- `phone` is required.
- Phone number should be unique.
- A Customer can have zero or more Orders.
- Customer must not be hard-deleted when historical Orders reference it.

---

# 5. Order Entity

## Entity

Order

## Purpose

Represents a customer's laundry transaction.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Internal order identifier |
| orderNumber | String | Yes | Unique human-readable order number |
| customerId | UUID | Yes | Customer reference |
| status | OrderStatus | Yes | Current order status |
| expectedPickupDate | Date | Yes | Expected pickup date |
| customerPickupRequested | Boolean | Yes | Whether the laundry will collect items from the customer |
| customerPickupFee | Money | Yes | Fee for customer pickup/collection |
| customerDeliveryRequested | Boolean | Yes | Whether the laundry will deliver the completed order to the customer |
| customerDeliveryFee | Money | Yes | Fee for delivery to customer |
| subtotal | Money | Yes | Sum of OrderItem totals |
| discount | Money | Yes | Order-level discount |
| tax | Money | Yes | Calculated tax amount |
| total | Money | Yes | Final historical order total |
| notes | String? | No | General order notes |
| cancellationReason | String? | No | Cancellation reason |
| cancelledAt | DateTime? | No | Cancellation timestamp |
| completedAt | DateTime? | No | Completion timestamp |
| customerHandoverConfirmedAt | DateTime? | No | Timestamp when customer handover was explicitly confirmed |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Relationships

Order

- customerId → Customer
- 1:N → OrderItem
- 1:N → Payment

## Rules

- `customerId` is required.
- An Order must contain at least one OrderItem.
- `expectedPickupDate` is required.
- `expectedPickupDate` contains date only.
- `customerPickupRequested` and `customerDeliveryRequested` are independent.
- Both delivery directions may be selected for the same Order.
- If `customerPickupRequested` is false, `customerPickupFee` must be zero.
- If `customerDeliveryRequested` is false, `customerDeliveryFee` must be zero.
- Delivery fees cannot be negative.
- `discount` is applied at Order level.
- `tax` is zero when tax is disabled.
- `total` represents the historical transaction total after the latest successful save of the Order.
- An editable Order may have its pricing changed according to the approved business rules.
- Later changes to master data must not change the saved historical pricing of an Order.
- Completed Orders must have `completedAt`.
- Completed Orders must have `customerHandoverConfirmedAt`.
- Cancelled Orders should have `cancelledAt`.
- Cancelled Orders require a cancellation reason.
- Completed and Cancelled Orders are historical/read-only operationally.

---

# 6. Order Delivery Representation

Delivery is represented as two independent capabilities on the Order.

The domain does not use a single mutually exclusive DeliveryType.

The two independent properties are:

customerPickupRequested

customerDeliveryRequested

## Customer Pickup / Collection

Represents:

Customer → Laundry

When enabled:

customerPickupRequested = true

The associated fee is:

customerPickupFee

This is the technical representation of the business concept:

Delivery to Laundry

---

## Customer Delivery

Represents:

Laundry → Customer

When enabled:

customerDeliveryRequested = true

The associated fee is:

customerDeliveryFee

This is the technical representation of the business concept:

Delivery to Customer

---

## Both Directions

Both may be true simultaneously.

Example:

customerPickupRequested = true

customerPickupFee = 5000

customerDeliveryRequested = true

customerDeliveryFee = 5000

Total delivery fees:

10000 piastres

## No Delivery

If both are false:

customerPickupRequested = false

customerDeliveryRequested = false

The Order has no delivery requirement.

## Delivery Total

Total delivery fees are:

customerPickupFee + customerDeliveryFee

Only selected delivery fees may be greater than zero.

---

# 7. Order Number

The final approved Order Number format is:

YY-XXX

Example:

26-001

The Order Number:

- Is assigned once.
- Must be unique.
- Must remain unchanged after creation.
- Is the human-readable Order identifier.
- Must not expose the database UUID as the primary identifier.

The exact generation mechanism is an implementation concern.

---

# 8. OrderStatus Enum

## Enum

OrderStatus

## Values

processing

ready

completed

cancelled

## Arabic UI Labels

processing → قيد التجهيز

ready → جاهز

completed → مكتمل

cancelled → ملغي

No additional operational statuses are introduced in V1.

---

# 9. OrderStatus Rules

The normal lifecycle is:

processing → ready → completed

Cancellation may occur before completion:

processing → cancelled

ready → cancelled

Manual status correction is supported when necessary.

Manual status changes must not create an invalid Storage state.

## Ready

Ready means all required physical OrderItems have active StorageRecords.

## Completed

Completed requires:

1. Order is Ready.
2. Remaining amount is zero.
3. Customer handover is explicitly confirmed.

## Cancelled

Cancellation requires:

1. Explicit confirmation.
2. Cancellation reason.

---

# 10. Order Pricing

The Order contains:

subtotal

discount

tax

total

Delivery fees are part of the Order total calculation.

The conceptual calculation is:

OrderItem totals

+

Customer pickup/collection fee

+

Customer delivery fee

-

Discount

+

Tax

=

Order total

When tax is disabled:

tax = 0

Therefore, with tax disabled:

OrderItem totals

+

Delivery fees

-

Discount

=

Order total

The `total` value represents the transaction total after the latest successful save.

An editable Order may have its pricing changed according to the approved Order editing behavior.

After an Order version is saved, its stored pricing must not silently change because master data was edited later.

---

# 11. OrderItem Entity

## Entity

OrderItem

## Purpose

Represents one physical laundry piece.

Each physical piece must have its own OrderItem.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique physical item identifier |
| orderId | UUID | Yes | Parent Order |
| itemTypeId | UUID | Yes | Item Type reference |
| itemDefinitionId | UUID? | Conditional | Item Definition reference |
| serviceId | UUID | Yes | Selected Service reference |
| itemTypeNameSnapshot | String | Yes | Historical Item Type name |
| itemDefinitionNameSnapshot | String? | Conditional | Historical Item Definition name |
| serviceNameSnapshot | String | Yes | Historical Service name |
| pricingTypeSnapshot | PricingType | Yes | Historical pricing type |
| unitPrice | Money | Yes | Historical item price |
| calculatedTotal | Money | Yes | Historical calculated item total |
| notes | String? | No | Item-specific notes |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Relationships

OrderItem

- orderId → Order
- itemTypeId → ItemType
- itemDefinitionId → ItemDefinition
- serviceId → Service
- 0..1 → CarpetItemData
- 0..1 active → StorageRecord

## Rules

- Every OrderItem belongs to exactly one Order.
- Every physical item has an independent ID.
- Every OrderItem must have exactly one Service.
- The selected Service must support the selected ItemType.
- Historical pricing must be preserved.
- Historical Item Type information must remain understandable after master-data changes.
- Historical Item Definition information must remain understandable after master-data changes.
- Historical Service information must remain understandable after master-data changes.
- An OrderItem may have one active StorageRecord at most.
- OrderItem is the physical identity used by Storage.

---

# 12. OrderItem Quantity Representation

Quantity is an order-entry convenience and is not the physical identity of an item.

If the user enters:

5 × Shirt

the domain represents:

OrderItem 1

OrderItem 2

OrderItem 3

OrderItem 4

OrderItem 5

Each physical piece has an independent OrderItem ID.

The UI may group identical OrderItems visually where appropriate.

---

# 13. ItemType Entity

## Entity

ItemType

## Purpose

Represents the high-level category of a physical laundry item.

## V1 Item Types

Clothing

Blankets

Carpets

Carpet Covers

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Item Type identifier |
| name | String | Yes | Item Type name |
| isActive | Boolean | Yes | Whether available for new transactions |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

ItemType determines:

- Available ItemDefinitions.
- Compatible Services.
- Required item-specific information.
- Compatible StorageLocations.

Inactive ItemTypes must not be selectable for new transactions.

Historical references remain valid.

---

# 14. ItemDefinition Entity

## Entity

ItemDefinition

## Purpose

Represents a specific item definition within an ItemType.

Examples:

Clothing

- Shirt
- Pants
- T-Shirt
- Jacket

Blankets

- Blanket
- Quilt
- Comforter

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Item Definition identifier |
| itemTypeId | UUID | Yes | Parent Item Type |
| name | String | Yes | Definition name |
| isActive | Boolean | Yes | Whether selectable for new transactions |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

- Every ItemDefinition belongs to exactly one ItemType.
- ItemDefinition must belong to the same ItemType as its OrderItem.
- Inactive ItemDefinitions cannot be selected for new transactions.
- Historical references remain valid.
- ItemDefinition names may be edited according to the approved master-data workflow.

---

# 15. Service Entity

## Entity

Service

## Purpose

Represents an operation performed on an OrderItem.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Service identifier |
| name | String | Yes | Service name |
| pricingType | PricingType | Yes | Service pricing type |
| currentPrice | Money | Yes | Current service price |
| isActive | Boolean | Yes | Whether selectable for new transactions |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Pricing Types

PerPiece

PerKilogram

PerSquareMeter

FixedPrice

## Rules

- Service names and current prices are master data.
- Service may be configured for one or more ItemTypes.
- Only active compatible Services may be selected for new OrderItems.
- Changing the current Service price must not modify existing OrderItems.
- Historical Service name, pricing type, and unit price are preserved on the OrderItem.

---

# 16. ServiceItemType Entity

## Entity

ServiceItemType

## Purpose

Represents the compatibility relationship between Services and ItemTypes.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique relationship identifier |
| serviceId | UUID | Yes | Service reference |
| itemTypeId | UUID | Yes | Item Type reference |
| createdAt | DateTime | Yes | Creation timestamp |

## Relationships

Service

N:M → ItemType

through:

ServiceItemType

## Rules

- A ServiceItemType record means the Service is available for the ItemType.
- Duplicate ServiceItemType relationships must not exist.
- Removing a ServiceItemType relationship must not invalidate historical OrderItems.
- Historical OrderItems remain valid even if the Service is no longer configured for that ItemType.

---

# 17. PricingType Enum

## Values

PerPiece

PerKilogram

PerSquareMeter

FixedPrice

## Rules

PricingType determines how a Service price is interpreted.

The actual historical pricing information used by an OrderItem is stored on the OrderItem.

---

# 18. CarpetSize Entity

## Entity

CarpetSize

## Purpose

Represents a predefined common carpet size.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Carpet Size identifier |
| length | Decimal | Yes | Length |
| width | Decimal | Yes | Width |
| area | Decimal | Yes | Calculated area |
| isActive | Boolean | Yes | Whether selectable for new Orders |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Examples

2 × 3

3 × 3

3 × 4

4 × 4

4 × 5

## Rules

Area is:

length × width

CarpetSize is master data.

Deactivating or editing a CarpetSize must not change historical Carpet OrderItems.

---

# 19. CarpetItemData Entity

## Entity

CarpetItemData

## Purpose

Contains information specific to Carpet OrderItems.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique identifier |
| orderItemId | UUID | Yes | Related OrderItem |
| carpetSizeId | UUID? | No | Predefined CarpetSize when used |
| length | Decimal | Yes | Historical carpet length |
| width | Decimal | Yes | Historical carpet width |
| area | Decimal | Yes | Historical calculated area |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

- CarpetItemData belongs to one Carpet OrderItem.
- `length` is required.
- `width` is required.
- `area` is calculated from length and width.
- `area` is not manually entered.
- `carpetSizeId` is optional because a custom size may be used.
- Historical dimensions and area must remain unchanged after creation unless the Order itself is being validly edited.
- CarpetItemData must not exist for non-Carpet OrderItems.

---

# 20. StorageLocation Entity

## Entity

StorageLocation

## Purpose

Represents a physical storage location inside the laundry.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Storage Location identifier |
| name | String | Yes | Location name |
| isActive | Boolean | Yes | Whether available for new storage operations |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Compatibility

StorageLocation is compatible with one or more ItemTypes.

The compatibility determines which locations can be selected for an OrderItem.

---

# 21. StorageRecord Entity

## Entity

StorageRecord

## Purpose

Represents the current physical storage assignment of an OrderItem.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Storage Record identifier |
| orderItemId | UUID | Yes | Physical OrderItem reference |
| storageLocationId | UUID | Yes | Storage Location reference |
| isActive | Boolean | Yes | Whether this is the current storage assignment |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Relationships

OrderItem

1:0..1 → Active StorageRecord

StorageLocation

1:N → StorageRecord

## Rules

- An OrderItem may have zero or one active StorageRecord.
- The active StorageRecord represents the current physical location.
- Storage is attached to OrderItem, not directly to Order.
- StorageLocation compatibility is determined through ItemType.
- Inactive StorageLocations cannot be selected for new storage operations.
- Moving an item deactivates the previous active StorageRecord and creates the new active assignment.
- V1 does not require storage movement history.

---

# 22. Expense Entity

## Entity

Expense

## Purpose

Represents an operating expense recorded independently from Orders and Payments.

Expense is a first-class financial transaction.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Expense identifier |
| expenseCategoryId | UUID | Yes | Expense Category reference |
| amount | Money | Yes | Expense amount |
| expenseDate | Date | Yes | Date of the expense |
| customName | String? | Conditional | Expense name when category is `أخرى` |
| notes | String? | No | Optional expense notes |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

- Expense amount must be positive.
- Expense Date is required.
- Expense Category is required.
- Expense is independent from Order.
- Expense is independent from Payment.
- `customName` is required when the selected ExpenseCategory is `أخرى`.
- Historical Expenses must remain available.
- Expenses are included in Financial Reports according to `expenseDate`.

---

# 23. ExpenseCategory Entity

## Entity

ExpenseCategory

## Purpose

Represents a configurable category used to classify Expenses.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Expense Category identifier |
| name | String | Yes | Category name |
| isActive | Boolean | Yes | Whether selectable for new Expenses |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

Users may:

- Add categories.
- Edit category names.
- Activate categories.
- Deactivate categories.

Categories with historical Expense references must not be hard-deleted.

The system provides the category:

أخرى

When `أخرى` is selected:

customName

is required on the Expense.

---

# 24. BusinessSettings Entity

## Entity

BusinessSettings

## Purpose

Represents business-level configuration required by V1.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Settings identifier |
| businessName | String | Yes | Business name |
| address | String? | No | Business address |
| phone | String? | No | Business phone |
| logoReference | String? | No | Reference to business logo |
| invoiceFooterText | String? | No | Optional invoice footer |
| taxEnabled | Boolean | Yes | Whether tax is enabled |
| taxRate | Decimal | Conditional | Tax rate when tax is enabled |
| createdAt | DateTime | Yes | Creation timestamp |
| updatedAt | DateTime | Yes | Last update timestamp |

## Rules

BusinessSettings provides business information and configuration used by the application and Invoice / Receipt presentation.

Tax is disabled by default in V1.

When tax is disabled:

taxRate = 0

The following are fixed in V1:

- Currency: EGP
- Language: Arabic
- Direction: RTL
- Branch count: Single Branch

Services, ItemTypes, ItemDefinitions, CarpetSizes, StorageLocations, and ExpenseCategories are separate entities and are not embedded inside BusinessSettings.

---

# 25. PaymentMethod Enum

## Values

Cash

InstaPay

EWallet

---

# 26. Payment Entity

## Entity

Payment

## Purpose

Represents a customer payment against an Order.

## Properties

| Property | Type | Required | Description |
|---|---|---:|---|
| id | UUID | Yes | Unique Payment identifier |
| orderId | UUID | Yes | Related Order |
| amount | Money | Yes | Payment amount |
| paymentMethod | PaymentMethod | Yes | Payment method |
| paidAt | DateTime | Yes | Payment timestamp |
| createdAt | DateTime | Yes | Creation timestamp |

## Rules

- Every Payment belongs to exactly one Order.
- An Order may have multiple Payments.
- Payment amount must be positive.
- Payments must not exceed the current remaining amount.
- Payments are not Expenses.

## Relationships

Payment

N:1 → Order

---

# 27. Payment Calculations

## Total Paid

Total Paid is:

sum(Order Payments)

## Remaining Amount

Remaining Amount is:

Order.total - Total Paid

The remaining amount must not become negative.

Payment validation must prevent total Payments from exceeding the current Order total.

---

# 28. Invoice / Receipt Representation

Invoice / Receipt is a presentation of historical Order information.

It is not an independent financial Entity in V1.

It does not create a separate financial transaction.

The Invoice / Receipt derives its information from:

- Order
- Customer
- OrderItems
- Payments
- Delivery information
- Discount
- Tax

It must display relevant historical information, including:

- Order Number
- Customer
- Item Type
- Item Definition
- Carpet Size when applicable
- Carpet dimensions when applicable
- Blanket information when applicable
- Service
- Historical item price
- Delivery to Laundry fee
- Delivery to Customer fee
- Discount
- Tax
- Total
- Payment information
- Remaining amount

The Invoice / Receipt must not recalculate historical transaction values using current master-data values.

Printing is an output capability of the Invoice / Receipt view.

---

# 29. Historical Snapshot Rules

Transaction records must preserve enough information to remain understandable after master-data changes.

OrderItem preserves historical:

- Item Type name
- Item Definition name when applicable
- Service name
- Pricing Type
- Unit price
- Calculated total
- Item-specific data

Order preserves historical:

- Delivery selections
- Delivery fees
- Discount
- Tax
- Total

CarpetItemData preserves historical:

- Length
- Width
- Area

Expense preserves:

- Expense Category reference
- Expense transaction values
- Custom Expense Name when applicable

Historical data must not silently change because a master-data entity was edited or deactivated later.

---

# 30. Master Data Lifecycle

The following entities support Active / Inactive lifecycle management:

- ItemType
- ItemDefinition
- Service
- CarpetSize
- StorageLocation
- ExpenseCategory

Deactivation prevents inappropriate selection in new operational workflows.

Historical references remain valid.

Hard deletion must not be used when it would break historical transaction references.

---

# 31. Item Type Specific Data Rules

Some data exists only for specific ItemTypes.

## Clothing

CarpetItemData = null

## Blankets

CarpetItemData = null

Blanket-specific information is represented through ItemDefinition where applicable.

## Carpet Covers

CarpetItemData = null

## Carpets

CarpetItemData = required

This prevents unrelated nullable fields from being added to every OrderItem.

---

# 32. Service Selection Rules

An OrderItem may reference a Service only when:

Service.isActive = true

and:

Service supports OrderItem.itemType

The selected Service's historical information is captured on the OrderItem.

---

# 33. ItemDefinition Selection Rules

When an ItemDefinition is used:

ItemDefinition.itemTypeId

must equal:

OrderItem.itemTypeId

An ItemDefinition belonging to another ItemType must not be assigned to the OrderItem.

Inactive ItemDefinitions must not be selected for new Orders.

Historical OrderItems may continue referencing inactive definitions.

---

# 34. CarpetSize Selection Rules

If a predefined CarpetSize is selected:

CarpetItemData.carpetSizeId → CarpetSize

The actual dimensions are still stored directly:

length

width

area

Therefore:

CarpetSize

is an input/master-data reference, not the source of truth for historical carpet dimensions.

---

# 35. Storage Location Compatibility Rules

A StorageLocation may support one or more ItemTypes.

The relationship determines whether a location can be selected for a specific physical OrderItem.

When storing an OrderItem:

- The selected ItemType must be supported by the StorageLocation.
- Inactive StorageLocations cannot be selected.
- The current StorageRecord must reference the selected compatible location.

The UI may use this relationship to filter the available storage locations before the user selects a location.

---

# 36. Order Completion Requirements

An Order may only become:

completed

when:

status = ready

and:

remainingAmount = 0

and:

customer handover = confirmed

The confirmation is represented by:

customerHandoverConfirmedAt

Upon completion:

all active StorageRecords → inactive

The Order remains historical.

---

# 37. Order Cancellation Requirements

An Order may be cancelled before completion.

Cancellation requires:

- Explicit confirmation.
- Cancellation reason.

Upon cancellation:

all active StorageRecords → inactive

The following remain preserved:

- Order
- OrderItems
- Payments
- Historical pricing
- Delivery information
- Cancellation information

Cancellation does not create a Refund entity.

---

# 38. Manual Status Correction

Manual status correction is supported when necessary.

If:

completed → processing

the system must not automatically reactivate previous StorageRecords.

If physical items return to storage, the user must explicitly store them again.

Status correction must not silently create or restore physical storage state.

---

# 39. Storage Rules

Storage is attached to physical OrderItems.

An Order does not have a single StorageLocation.

Different OrderItems within the same Order may be stored in different locations.

Example:

Order #26-001

Shirt 1 → A-01

Shirt 2 → A-01

Blanket → B-02

Carpet → Carpet-01

Bulk storage is allowed.

Multiple independent OrderItems may be assigned to the same StorageLocation.

Each OrderItem remains independently identifiable.

---

# 40. Conditional Data Rules

Some data exists only for specific ItemTypes.

## Clothing

CarpetItemData = null

## Blankets

CarpetItemData = null

Blanket-specific information is represented through ItemDefinition where applicable.

## Carpet Covers

CarpetItemData = null

## Carpets

CarpetItemData = required

This allows the domain to avoid a universal OrderItem object containing irrelevant nullable carpet fields.

---

# 41. Service Selection Rules

An OrderItem may reference a Service only when:

Service.isActive = true

and:

Service supports OrderItem.itemType

The selected Service's historical information is then captured on the OrderItem.

---

# 42. ItemDefinition Selection Rules

When an ItemDefinition is used:

ItemDefinition.itemTypeId

must equal:

OrderItem.itemTypeId

An ItemDefinition belonging to another ItemType must not be assigned to the OrderItem.

Inactive ItemDefinitions must not be selected for new Orders.

Historical OrderItems may continue referencing inactive definitions.

---

# 43. CarpetSize Selection Rules

If a predefined CarpetSize is selected:

CarpetItemData.carpetSizeId → CarpetSize

The actual dimensions are still stored directly:

length

width

area

Therefore:

CarpetSize

is an input/master-data reference, not the source of truth for historical carpet dimensions.

---

# 44. Storage Location Compatibility Rules

A StorageLocation may support one or more ItemTypes.

The relationship determines whether a location can be selected for a specific physical OrderItem.

When storing an OrderItem:

- The selected ItemType must be supported by the StorageLocation.
- Inactive StorageLocations cannot be selected.
- The current StorageRecord must reference the selected compatible location.

The UI may use this relationship to filter the available storage locations before the user selects a location.

---

# 45. Order Completion Requirements

An Order may only become:

completed

when:

status = ready

and:

remainingAmount = 0

and:

customer handover = confirmed

The confirmation is represented by:

customerHandoverConfirmedAt

Upon completion:

all active StorageRecords → inactive

The order remains historical.

---

# 46. Order Cancellation Requirements

An Order may be cancelled before completion.

Cancellation requires:

- Explicit confirmation.
- Cancellation reason.

Upon cancellation:

all active StorageRecords → inactive

The following remain preserved:

- Order
- OrderItems
- Payments
- Historical pricing
- Delivery information
- Cancellation information

Cancellation does not create a Refund entity.

---

# 47. Derived Values

The following values can be derived from stored entity data.

## Total Paid

sum(Order.payments.amount)

## Remaining Amount

Order.total - TotalPaid

## Delivery Fees

customerPickupFee + customerDeliveryFee

Only applicable selected delivery fees are included.

## Order Total

sum(OrderItem.calculatedTotal)

+

customerPickupFee

+

customerDeliveryFee

-

discount

+

tax

## Carpet Area

length × width

## Order Readiness

Every required OrderItem has an active StorageRecord.

## Current Item Location

OrderItem's active StorageRecord.storageLocationId

## Overdue Order

expectedPickupDate < today

and:

status != completed

and:

status != cancelled

## Total Operating Expenses

sum(Expense.amount) for the selected report period

## Net Profit

Total Sales - Total Operating Expenses

Net Profit is a derived reporting value.

It is not stored as a transactional entity.

Payments are not subtracted from Net Profit.

Outstanding amounts are not treated as expenses.

---

# 48. Financial Reporting Rules

The Financial Report operates over a selected date range.

For the selected period:

Sales are calculated from applicable Order transaction totals.

Payments are reported separately.

Outstanding amounts are reported separately.

Expenses are filtered by Expense.date.

Expense category totals are derived from Expenses in the selected period.

Net Profit is:

Total Sales - Total Operating Expenses

The same Expense records shown in the selected period must be represented by the Expense totals and category breakdown.

No separate Profit entity is required.

---

# 49. Entity Invariants

The implementation must preserve the following invariants:

1. Every Order belongs to exactly one Customer.
2. Every Order contains at least one OrderItem.
3. Every OrderItem belongs to exactly one Order.
4. Every physical item has its own OrderItem ID.
5. An OrderItem can have at most one active StorageRecord.
6. A StorageRecord references exactly one OrderItem.
7. A StorageRecord references exactly one StorageLocation.
8. An Order is Ready only when all required OrderItems have active StorageRecords.
9. An Order cannot be Completed unless it is Ready.
10. An Order cannot be Completed while a remaining amount exists.
11. An Order cannot be Completed without confirmed customer handover.
12. Completing an Order deactivates its active StorageRecords.
13. Cancelling an Order deactivates its active StorageRecords.
14. Changing Completed back to Processing does not reactivate previous StorageRecords.
15. Payments cannot exceed the Order's remaining amount.
16. Historical OrderItem prices remain unchanged after Service price changes.
17. Historical carpet dimensions remain unchanged after CarpetSize changes.
18. Historical Expense category information remains understandable after ExpenseCategory changes.
19. Master data changes do not overwrite historical transaction snapshots.
20. Cancelled Orders remain available as historical records.
21. Expense is independent from Order and Payment.
22. Payment belongs to an Order.
23. Expense belongs to an ExpenseCategory.
24. Delivery pickup and delivery-to-customer requests are independent.
25. Both delivery directions may exist on the same Order.
26. A disabled delivery direction must have a zero fee.
27. Delivery fees contribute to the Order total.
28. Currency is EGP.
29. V1 supports one branch.
30. Refunds are not part of V1.
31. Storage location selection must respect ItemType compatibility.
32. Carpet OrderItems require CarpetItemData.
33. Non-Carpet OrderItems must not contain CarpetItemData.
34. ItemDefinition must belong to the same ItemType as its OrderItem.
35. Inactive master data cannot be selected for new transactions.
36. Historical transaction data remains stable after master-data changes.
37. Net Profit equals Sales minus Operating Expenses.
38. Payments and outstanding amounts must not be treated as operating expenses.

---

# 50. Implementation Mapping Guidance

The entity definitions in this document are logical contracts.

They may later be represented by:

- Domain entities
- Local database models
- Remote API DTOs
- Repository models

These representations do not have to be identical.

However, mapping between them must preserve the business meaning defined here.

For example:

Order Domain Entity

↕

Order Local Database Model

↕

Order Remote DTO

The architecture documentation defines how these models are separated.

---

# 51. V1 Entity List

The complete V1 entity set is:

Transactional:

- Customer
- Order
- OrderItem
- Payment
- Expense
- StorageRecord

Master Data:

- ItemType
- ItemDefinition
- Service
- ServiceItemType
- CarpetSize
- StorageLocation
- ExpenseCategory

Configuration:

- BusinessSettings

Item-Specific:

- CarpetItemData

Supporting values/enums:

- Money
- OrderStatus
- PricingType
- PaymentMethod

---

# 52. Explicitly Excluded Entities

The following entities must not be introduced in V1 without an approved requirement:

- Driver
- Vehicle
- Delivery
- DeliveryRoute
- Employee
- Role
- Permission
- Branch
- Refund
- LoyaltyAccount
- StorageMovement
- StorageCapacity
- LaundryProcessingStage
- Barcode
- Profit
- AccountingTransaction

Delivery does not require a separate Delivery entity in V1 because the two approved delivery directions are represented directly on the Order.

Future requirements may introduce new entities when justified.

---

# 53. Domain Separation Rules

The following concepts must remain separate:

Order

Payment

Expense

StorageRecord

StorageLocation

OrderItem

They must not be merged into a generic transaction or activity entity.

Order represents the customer transaction.

Payment represents money received against the Order.

Expense represents operating money spent by the laundry.

OrderItem represents one physical laundry piece.

StorageRecord represents the current physical storage assignment of an OrderItem.

StorageLocation represents a physical place where an item can be stored.

---

# 54. Historical Data Stability

Historical transactions must remain understandable even when configuration changes.

Changing:

- Item Type
- Item Definition
- Service name
- Service price
- Pricing Type
- Expense Category name
- Storage Location status
- Carpet Size

must not silently rewrite the historical meaning of an existing transaction.

Historical snapshots and transaction values are the source of truth for past transactions.

---

# 55. Source of Truth

This document defines the logical V1 entity contracts.

The implementation must preserve:

- Entity responsibilities
- Required/optional semantics
- Relationships
- Historical snapshot requirements
- Domain invariants
- Physical item identity
- Delivery representation
- Expense representation
- Item-specific information

If an implementation requires an entity or property that is not documented here, the requirement should be reviewed before adding it.

Database-specific details remain defined in:

docs/02-domain/database-design.md

Architecture-specific implementation details belong in:

docs/03-architecture/architecture.md

API-specific representations belong in:

docs/05-api/backend-api-overview.md

UI-specific behavior belongs in:

docs/07-ui-ux/

The entity model must remain consistent with the approved Product Scope and Requirements.