# Laundry Management System — Domain Model

## 1. Document Purpose

This document defines the domain model of the Laundry Management System.

It describes the core business entities, their responsibilities, relationships, and important domain concepts.

This document is based on the approved product documentation in:

- `docs/01-product/product-overview.md`
- `docs/01-product/requirements.md`
- `docs/01-product/scope.md`
- `docs/01-product/business-rules.md`

This document focuses on the business/domain model.

Database-specific implementation details such as tables, columns, indexes, foreign keys, and database constraints are documented separately in:

> `docs/02-domain/database-design.md`

---

# 2. Domain Design Goals

The domain model must support the following core goals:

- Represent each physical laundry item independently.
- Keep historical order information stable.
- Support order-level pricing and discounts.
- Support multiple payments per order.
- Support independent delivery types and delivery fees.
- Track the current physical storage location of each item.
- Support moving items between storage locations.
- Support carpet-specific measurements without unnecessary nullable fields.
- Keep master data separate from historical transaction data.
- Represent Expenses as independent financial transactions.
- Keep Expense Categories as manageable master data.
- Keep the model simple enough for the V1 operational workflow.
- Remain extensible for future features such as barcode support.

---

# 3. Core Domain Concepts

The main transactional concepts are:

- Customer
- Order
- OrderItem
- Payment
- Expense
- StorageRecord
- StorageLocation

The main master-data/configuration concepts are:

- ItemType
- ItemDefinition
- Service
- CarpetSize
- ExpenseCategory
- BusinessSettings

Conceptually:

    Customer
       │
       └── Order
             │
             ├── OrderItem
             │      │
             │      ├── ItemType
             │      ├── ItemDefinition
             │      ├── Service
             │      └── StorageRecord
             │               │
             │               └── StorageLocation
             │
             └── Payment

    Expense
       │
       └── ExpenseCategory

Expense is independent from Order and Payment.

---

# 4. Customer

## Responsibility

`Customer` represents a laundry customer.

## Core Information

A Customer contains:

- Unique identifier
- Name
- Phone number
- Creation timestamp
- Update timestamp

## Relationships

One Customer can have multiple Orders.

    Customer 1 ──────── N Order

## Business Rules

- Customer name is required.
- Customer phone number is required.
- Customer phone number should be unique.
- Customer information may be edited.
- Customer history must remain available.
- Customers with historical orders must not be hard-deleted.

---

# 5. Order

## Responsibility

`Order` represents one customer transaction with the laundry.

It is the main transactional business concept in the system.

## Core Information

An Order contains:

- Unique internal identifier
- Unique human-readable Order Number
- Customer reference
- Status
- Expected Pickup Date
- Delivery to Laundry selection
- Delivery to Customer selection
- Delivery to Laundry fee
- Delivery to Customer fee
- Subtotal
- Discount
- Tax where applicable
- Total
- Notes
- Creation timestamp
- Update timestamp

## Relationships

    Customer 1 ──────── N Order

    Order 1 ──────── N OrderItem

    Order 1 ──────── N Payment

## Invariants

An Order:

- Must belong to exactly one Customer.
- Must contain at least one OrderItem.
- Must have an Expected Pickup Date.
- Must have exactly one status from the V1 status set.
- May have either, both, or neither delivery type.
- Must preserve the delivery fees applicable to the transaction.

---

# 6. Order Number

The Order Number is a human-readable identifier separate from the internal database identifier.

The approved V1 format is:

    YY-XXX

Example:

    26-001

The Order Number must:

- Be unique.
- Be assigned once.
- Remain unchanged after creation.

The exact generation mechanism is an implementation concern and is not defined here.

---

# 7. Order Status

The domain supports exactly four V1 statuses:

    Processing
    Ready
    Completed
    Cancelled

## Processing

Represents an active order that is not yet ready for customer handover.

The system does not model individual laundry processing stages.

---

## Ready

Represents an order where all physical OrderItems have active Storage Records.

Ready means:

> The order is ready for customer handover.

Ready does not mean:

> The customer has received the order.

---

## Completed

Represents an order that has actually been handed over to the customer.

Completed requires:

1. Order is Ready.
2. Remaining payment amount is zero.
3. User explicitly confirms customer handover.

---

## Cancelled

Represents an order that has been cancelled and is no longer an active operational order.

Cancelled orders remain available as historical records.

---

# 8. Order Status Lifecycle

The normal lifecycle is:

    Processing
        │
        ▼
      Ready
        │
        ▼
    Completed

Cancellation may occur before completion:

    Processing ──────► Cancelled

    Ready ───────────► Cancelled

Manual status correction is supported when necessary.

Manual status changes must not automatically create incorrect Storage state.

---

# 9. Expected Pickup Date

Every Order requires an Expected Pickup Date.

The domain value is:

> Date only

No time component is required.

Example:

    2026-08-25

The Expected Pickup Date is used for:

- Order display
- Filtering
- Dashboard
- Overdue detection
- Reports

An order is overdue when:

    Expected Pickup Date < Today
    AND
    Status != Completed
    AND
    Status != Cancelled

---

# 10. Delivery

Delivery is intentionally modeled as a simple Order-level request.

V1 supports two independent delivery types:

- Delivery to Laundry
- Delivery to Customer

They are not mutually exclusive.

Possible combinations are:

- Neither
- Delivery to Laundry only
- Delivery to Customer only
- Both

Each delivery type has its own fee.

The Order therefore conceptually contains:

    deliveryToLaundry
    deliveryToLaundryFee

    deliveryToCustomer
    deliveryToCustomerFee

The applicable delivery fees contribute to the Order total.

    Delivery Fees =
    Delivery to Laundry Fee +
    Delivery to Customer Fee

Delivery does not represent a separate logistics management domain in V1.

The domain does not contain:

- Driver
- Vehicle
- Route
- Delivery assignment
- Delivery status
- Delivery tracking
- Delivery optimization
- Proof of delivery

---

# 11. OrderItem

## Responsibility

`OrderItem` represents one physical laundry piece belonging to an Order.

This is a critical domain concept.

Every physical piece must have an independent OrderItem identity.

    Order 1 ──────── N OrderItem

## Core Information

An OrderItem may contain:

- Unique identifier
- Order reference
- Item Type reference
- Item Definition reference
- Service reference
- Historical service information
- Historical pricing information
- Item-specific notes
- Item-specific data
- Storage relationship

The exact database representation is defined separately.

---

# 12. Physical Item Identity

The domain treats the OrderItem itself as the identity of the physical laundry piece.

Example:

Customer brings:

    5 Shirts

The UI may provide:

    Shirt × 5

But the domain represents:

    OrderItem 1
    OrderItem 2
    OrderItem 3
    OrderItem 4
    OrderItem 5

This is required because each physical item may have a different:

- Storage Location
- Note
- Item-specific data
- Future barcode identifier

---

# 13. Quantity Entry

Quantity is an order-entry convenience.

It does not replace physical item identity.

Example:

    User Input:

    Shirt × 5

Domain result:

    OrderItem
    OrderItem
    OrderItem
    OrderItem
    OrderItem

The UI may group identical OrderItems visually when useful, but the underlying domain must preserve individual physical item identity.

---

# 14. Item Type

`ItemType` represents the high-level category of a physical laundry item.

V1 supports:

    Clothing
    Blankets
    Carpets
    Carpet Covers

Item Type is used to determine:

- General item behavior.
- Available Item Definitions.
- Available Services.
- Item-specific data requirements.
- Compatible Storage Locations.

---

# 15. Item Definition

`ItemDefinition` represents a specific item within an Item Type.

Examples:

    Clothing
    ├── Shirt
    ├── Pants
    ├── T-Shirt
    └── Jacket

    Blankets
    ├── Blanket
    ├── Quilt
    └── Comforter

Carpets may also have configured definitions.

The exact Carpet definitions are business-configurable.

---

# 16. Item Type and Item Definition Relationship

An ItemDefinition belongs to one ItemType.

    ItemType 1 ──────── N ItemDefinition

Example:

    ItemType:
    Clothing

    ItemDefinition:
    Shirt

The separation between ItemType and ItemDefinition is intentional.

It allows item-specific behavior to remain organized without creating one large entity containing many irrelevant nullable fields.

---

# 17. Carpet Covers

Carpet Covers are a distinct primary ItemType.

They do not require a separate Cover Type or Cover subtype hierarchy in V1.

Operationally, Carpet Covers are treated similarly to Blankets.

Conceptually:

    ItemType:
    Carpet Cover

with piece-based handling similar to:

    ItemType:
    Blanket

---

# 18. Item-Specific Data

The domain should support item-specific data without forcing unrelated fields onto every OrderItem.

For example:

    Clothing
    → normal piece-based item data

    Blanket
    → normal piece-based item data

    Carpet
    → Length
    → Width
    → Area

    Carpet Cover
    → normal piece-based item data

This separation is intentional.

The implementation must avoid creating a universal OrderItem model filled with unrelated nullable properties.

---

# 19. Service

`Service` represents an operation performed on an OrderItem.

Examples may include:

- Washing
- Dry Cleaning
- Washing + Ironing
- Carpet Cleaning

A Service contains master data such as:

- Unique identifier
- Name
- Pricing Type
- Current Price
- Active state
- Supported Item Types

---

# 20. Service Availability

A Service may be available for one or more ItemTypes.

This is an N:M relationship between Service and ItemType. In the implementation, the relationship is represented through the ServiceItemType association entity.

Conceptually:

    Service N ──────── M ItemType

Only compatible active services should be available when creating a new OrderItem.

Example:

    ItemType:
    Carpets

    Available Service:
    Carpet Cleaning

A service that is not configured for Carpets should not be selectable for a Carpet OrderItem.

---

# 21. Pricing Type

The domain supports these pricing types:

    PerPiece
    PerKilogram
    PerSquareMeter
    FixedPrice

Typical V1 usage:

    Clothing       → PerPiece
    Blankets       → PerPiece
    Carpet Covers  → PerPiece
    Carpets        → PerSquareMeter

The domain supports all four pricing types even when a particular UI flow only exposes a relevant subset.

---

# 22. OrderItem Pricing Snapshot

Historical transaction data must not depend entirely on current master data.

When a Service is selected for an OrderItem, the OrderItem must preserve the relevant historical pricing information.

At minimum, the historical pricing concept includes:

- Service reference
- Service name snapshot
- Pricing Type snapshot
- Unit price snapshot
- Calculated item total

Example:

    Current Service Price:
    50 ج.م

    Existing OrderItem Price:
    40 ج.م

Changing the current Service price must not change the existing OrderItem.

During Order creation, the user may adjust the applicable OrderItem price according to the approved pricing behavior.

An existing Order may also allow price adjustment while it remains editable according to the business rules.

---

# 23. OrderItem Historical Item Information

Historical OrderItems must preserve enough information to identify what the customer actually submitted.

This includes relevant:

- Item Type information
- Item Definition information
- Service information
- Pricing information
- Item-specific data
- Notes

Changes to current master data must not make historical orders ambiguous or incorrect.

---

# 24. Carpet OrderItem

A Carpet OrderItem has additional measurement data.

Required concepts:

- Length
- Width
- Area

Area is calculated as:

    Area = Length × Width

Example:

    Length = 2
    Width  = 3
    Area   = 6 m²

These values are part of the Carpet OrderItem's domain data. They may be represented through a dedicated CarpetItemData value/entity in the implementation so that carpet-specific fields do not become unrelated nullable fields on every OrderItem.

---

# 25. Carpet Size

`CarpetSize` represents a predefined common carpet size.

Examples:

    2 × 3
    3 × 3
    3 × 4
    4 × 4
    4 × 5

A CarpetSize contains:

- Length
- Width
- Area
- Active state

CarpetSize is master data.

---

# 26. Carpet Size Usage

When the user selects a predefined CarpetSize:

    CarpetSize
        │
        ├── Length
        ├── Width
        └── Area
              │
              ▼
          OrderItem

The OrderItem receives the actual dimensions used for that transaction.

The historical OrderItem must not depend on the CarpetSize remaining active.

---

# 27. Custom Carpet Size

A Carpet OrderItem may use a custom size.

The user provides:

    Length
    Width

The domain calculates:

    Area = Length × Width

The resulting dimensions and area are stored as part of the OrderItem's historical data.

The user does not need to manually enter the calculated Area.

---

# 28. Payment

`Payment` represents a payment transaction associated with an Order.

Relationship:

    Order 1 ──────── N Payment

An Order may have:

- No payments
- One payment
- Multiple payments

A Payment contains:

- Unique identifier
- Order reference
- Amount
- Payment Method
- Payment timestamp

Payment is always associated with an Order.

Payment is not an Expense.

---

# 29. Payment Methods

V1 supports:

    Cash
    InstaPay
    EWallet

The payment method must be explicitly stored with each Payment.

---

# 30. Payment Calculations

The Order's total paid amount is derived from its Payments:

    Total Paid = Sum(Payments)

Remaining amount is:

    Remaining Amount = Order Total - Total Paid

The remaining amount must not become negative.

A Payment must not exceed the current remaining amount.

---

# 31. Order Pricing

Order pricing is calculated from its OrderItems and applicable Order-level adjustments.

The conceptual flow is:

    OrderItem Totals
           ↓
       Subtotal
           ↓
      Order Discount
           ↓
      Delivery Fees
           ↓
         Tax
           ↓
         Total

With tax disabled:

    Subtotal - Discount + Delivery Fees = Total

Where:

    Delivery Fees =
    Delivery to Laundry Fee +
    Delivery to Customer Fee

With tax enabled:

    Subtotal - Discount + Delivery Fees + Tax = Total

The applicable pricing values are preserved as historical Order data.

---

# 32. Discount

Discount belongs to the Order.

It is not an OrderItem property.

The domain concept is:

    Order
    ├── Subtotal
    ├── Discount
    ├── Delivery Fees
    ├── Tax
    └── Total

V1 does not support item-level discounts.

---

# 33. Tax

Tax is disabled by default in V1.

The domain should remain capable of supporting:

- Tax enabled/disabled
- Tax rate

When enabled, the expected calculation is:

    Subtotal - Discount + Delivery Fees + Tax = Total

Tax configuration belongs to business/system configuration rather than individual OrderItems.

Historical Orders must preserve the tax information applicable to the transaction.

---

# 34. Expense

`Expense` represents an operating expense recorded independently from Orders and Payments.

An Expense is a first-class financial transaction.

An Expense is not associated with an Order.

An Expense is not a Payment.

## Core Information

An Expense contains:

- Unique identifier
- Amount
- Expense Category reference
- Expense Date
- Notes where applicable
- Expense Name when required
- Creation timestamp
- Update timestamp

## Business Rules

- Expense amount must be positive.
- Expense Date is required.
- Expense Category is required.
- Expense Name is required when the `أخرى` category is selected.
- Historical Expenses must remain available.
- Expenses are included in Financial Reports according to Expense Date.

---

# 35. Expense Category

`ExpenseCategory` represents a configurable category used to classify operating Expenses.

An ExpenseCategory contains:

- Unique identifier
- Name
- Active state
- Creation timestamp
- Update timestamp

Relationship:

    ExpenseCategory 1 ──────── N Expense

Expense Categories are master data.

The user may:

- Add an Expense Category.
- Edit an Expense Category name.
- Activate an Expense Category.
- Deactivate an Expense Category.

A category with historical Expense references must not be hard-deleted.

---

# 36. Other Expense Category

The system provides an Expense Category named:

    أخرى

When an Expense uses:

    أخرى

the Expense must also contain an Expense Name.

Expense Name is required in this case.

The Expense Name belongs to the Expense transaction and does not replace the Expense Category.

---

# 37. Expense Independence

Expenses and Payments represent different financial concepts.

The relationship is:

    Order
      │
      └── Payment

while:

    Expense
      │
      └── ExpenseCategory

There is no required relationship between:

    Order ↔ Expense

or:

    Payment ↔ Expense

An Expense must not be used to represent a payment made by a customer.

A Payment must not be used to represent an operating expense.

---

# 38. Financial Reporting Concepts

The Financial Report derives financial values from transactional data.

The report may include:

- Sales
- Payments
- Expenses
- Outstanding amounts
- Discounts
- Payment method breakdown
- Net Profit

Expenses are selected according to:

    Expense Date

Net Profit is a derived reporting value:

    Net Profit = Sales - Operating Expenses

Net Profit is not a separate domain entity.

The domain must not introduce:

- Profit entity
- Profit transaction
- Profit snapshot
- Expense ledger entity
- Analytics entity

unless a future approved requirement explicitly requires one.

---

# 39. Storage Location

`StorageLocation` represents a physical location inside the laundry where items can be stored.

A StorageLocation contains:

- Unique identifier
- Name
- Active state

Examples:

    A-01
    A-02
    B-01
    Carpet-01

Storage Locations are master data.

---

# 40. Storage Compatibility

A Storage Location may be configured as compatible with one or more ItemTypes.

The available locations for an OrderItem are determined by:

    OrderItem
        ↓
    ItemType
        ↓
    Compatible Storage Locations

Only compatible active Storage Locations should be presented when storing an OrderItem.

---

# 41. Storage Record

`StorageRecord` represents the current storage assignment of an OrderItem.

Relationship:

    OrderItem 1 ──────── 0..1 Active StorageRecord

An OrderItem may have:

- No active StorageRecord.
- One active StorageRecord.

A StorageRecord references:

- OrderItem
- StorageLocation
- Active state
- Relevant timestamps

---

# 42. Storage Invariant

An OrderItem must never have more than one active StorageRecord.

Conceptually:

    OrderItem
       │
       └── Active StorageRecord
                 │
                 └── One StorageLocation

This allows the system to answer:

> Where is this physical item currently stored?

---

# 43. Storing an Item

When an item is stored:

    OrderItem
        ↓
    StorageLocation

The system creates or activates the current StorageRecord.

An item without an active StorageRecord is considered not currently stored.

---

# 44. Moving an Item

The user must be able to move an OrderItem from one StorageLocation to another.

Example:

    A-03
      ↓
    B-02

After the move:

    Current Location = B-02

The previous location is no longer active for that item.

V1 does not require Storage Movement History.

---

# 45. Bulk Storage

Multiple independent OrderItems may be stored in the same StorageLocation in a single operation.

Example:

    OrderItem 1 → A-03
    OrderItem 2 → A-03
    OrderItem 3 → A-03
    OrderItem 4 → A-03
    OrderItem 5 → A-03

Bulk storage must not merge the OrderItems into one physical entity.

Each OrderItem remains independently identifiable.

---

# 46. Different Locations Within One Order

Items belonging to the same Order may be stored in different locations.

Example:

    Order #26-001

    Shirt 1 → A-01
    Shirt 2 → A-01
    Blanket → B-02
    Carpet → Carpet-01

The Order does not have one single StorageLocation.

Storage belongs to the individual physical OrderItems.

---

# 47. Storage Movement History

V1 does not require historical storage movement tracking.

The domain only needs to represent the current active StorageLocation.

Future storage history may be introduced later without changing the basic concept that an OrderItem has one current active location.

---

# 48. Order Readiness

An Order is Ready when every OrderItem has an active StorageRecord.

Conceptually:

    Every OrderItem
           │
           ├── Active StorageRecord
           ├── Active StorageRecord
           ├── Active StorageRecord
           └── Active StorageRecord
                    │
                    ▼
                 Order Ready

If at least one OrderItem does not have an active StorageRecord:

    Order remains Processing

---

# 49. Order Completion and Storage

When an Order becomes Completed:

    Order
      ↓
    Completed

    All active StorageRecords
      ↓
    Inactive

Therefore:

> Completed OrderItems no longer appear in Current Storage.

The OrderItems and their historical data remain available through the completed Order.

---

# 50. Manual Status Correction and Storage

If:

    Completed → Processing

the domain must not automatically reactivate previous StorageRecords.

If the physical items return to storage, the user must explicitly store them again.

This prevents accidental reappearance of items in Current Storage.

---

# 51. Cancellation and Storage

When an Order is cancelled:

    Active StorageRecords
            ↓
         Inactive

Cancelled items therefore no longer appear in Current Storage.

The OrderItems remain associated with the cancelled Order for historical purposes.

---

# 52. Cancellation

Cancellation is an Order state.

An Order may be cancelled before completion.

Cancellation may preserve:

- Cancellation timestamp
- Cancellation reason

Cancelled Orders:

- Are not deleted.
- Remain in history.
- Are not active operational orders.
- Preserve their payment history.
- Do not automatically trigger refunds.

---

# 53. Refund

Refund is intentionally not modeled as a V1 domain workflow.

There is no V1 Refund entity or Refund process.

Cancellation and Refund are separate concepts.

---

# 54. Invoice / Receipt

Invoice / Receipt is a presentation of historical Order information.

It is not a separate financial transaction.

It does not create a new financial entity.

The Invoice / Receipt must derive its information from the historical Order and its related transaction data.

It must preserve and display, where applicable:

- Order Number
- Customer
- Item Type
- Item Definition
- Carpet Size
- Carpet dimensions
- Blanket type / definition
- Service
- Historical item price
- Delivery to Laundry fee
- Delivery to Customer fee
- Discount
- Tax
- Total
- Payment information
- Remaining amount

The Invoice / Receipt must not recalculate historical values using current Service prices or other current master data.

The domain does not require a separate Invoice entity for V1.

Printing is a presentation/output capability of the Invoice / Receipt view.

---

# 55. Business Settings

`BusinessSettings` represents the limited configurable business information required in V1.

It may contain:

- Business name
- Address
- Phone
- Logo reference
- Invoice footer text
- Tax enabled/disabled
- Tax rate

The following are fixed in V1:

    Branch = Single Branch
    Currency = EGP
    Language = Arabic
    Direction = RTL

Services, ItemTypes, ItemDefinitions, CarpetSizes, StorageLocations, and ExpenseCategories are separate master-data concepts.

They are managed through the appropriate Settings workflows but are not embedded inside BusinessSettings.

---

# 56. Master Data

The following concepts are master/configuration data:

    ItemType
    ItemDefinition
    Service
    CarpetSize
    StorageLocation
    ExpenseCategory
    BusinessSettings

Master data can change over time.

Such changes must not modify historical transaction data.

---

# 57. Deactivation

Master data that may be referenced by historical transactions should generally be deactivated rather than hard-deleted.

Examples:

- Service
- ItemDefinition
- CarpetSize
- StorageLocation
- ExpenseCategory

Deactivated master data should not be selectable in new operational workflows where selection is inappropriate.

Historical references must remain valid.

---

# 58. Historical Data Principle

The system must be able to preserve the historical meaning of an Order even after master data changes.

For example:

    Service Price at Order Creation:
    40 ج.م

    Current Service Price:
    50 ج.م

The historical OrderItem must still represent:

    40 ج.م

Similarly:

- Historical carpet dimensions must remain unchanged.
- Historical item/service information must remain understandable.
- Historical delivery fees must remain unchanged.
- Historical discount and tax information must remain unchanged.
- Deactivating master data must not break old orders.

Historical Expenses must also remain understandable even if their Expense Category is later renamed or deactivated.

---

# 59. Aggregate Concepts

The main transactional aggregate is the Order.

The Order coordinates:

- OrderItems
- Order pricing
- Discount
- Delivery selections
- Delivery fees
- Tax
- Status
- Expected Pickup Date
- Completion rules
- Cancellation rules

Payments are associated with the Order.

Storage is a separate operational concept associated with individual OrderItems.

Customer is an independent entity referenced by Orders.

Expense is an independent financial transaction.

ExpenseCategory is master data referenced by Expenses.

Master data is maintained separately from transactional data.

---

# 60. Main Relationship Summary

    Customer
       │
       └── 1:N
             │
             ▼
           Order
             │
             ├── 1:N ── OrderItem
             │              │
             │              ├── N:1 → ItemType
             │              ├── N:1 → ItemDefinition
             │              ├── N:1 → Service
             │              └── 0..1 → Active StorageRecord
             │                              │
             │                              └── N:1 → StorageLocation
             │
             └── 1:N ── Payment

    Expense
       │
       └── N:1 → ExpenseCategory

Master-data relationships:

    ItemType
       │
       ├── 1:N → ItemDefinition
       │
       └── N:M → Service

    CarpetSize
       │
       └── Used as input when creating Carpet OrderItems

    StorageLocation
       │
       └── Compatible with one or more ItemTypes

    ExpenseCategory
       │
       └── 1:N → Expense

---

# 61. Domain Invariants

The implementation must preserve these invariants:

1. Every Order belongs to exactly one Customer.
2. Every Order contains at least one OrderItem.
3. Every OrderItem belongs to exactly one Order.
4. Every physical laundry piece has an independent OrderItem identity.
5. An OrderItem can have at most one active StorageRecord.
6. A StorageRecord belongs to exactly one OrderItem and one StorageLocation.
7. An Order is Ready only when all OrderItems have active StorageRecords.
8. An Order cannot be Completed unless it is Ready.
9. An Order cannot be Completed while a remaining payment amount exists.
10. An Order cannot be Completed without explicit customer handover confirmation.
11. Completing an Order deactivates its active StorageRecords.
12. Changing Completed back to Processing does not reactivate previous StorageRecords automatically.
13. Cancelling an Order deactivates its active StorageRecords.
14. Payments cannot exceed the current remaining amount.
15. Historical OrderItem pricing must not change when master prices change.
16. Historical carpet dimensions must not change.
17. Historical delivery fees must not change.
18. Cancelled Orders remain historical records.
19. Cancellation does not automatically trigger a refund.
20. Delivery to Laundry and Delivery to Customer are independent and may both be selected.
21. Delivery fees are part of Order pricing.
22. Every Expense belongs to exactly one ExpenseCategory.
23. Expense is independent from Order and Payment.
24. Expense amounts must be positive.
25. Expense Name is required when the `أخرى` ExpenseCategory is selected.
26. Historical Expenses must remain valid when Expense Categories are renamed or deactivated.
27. Net Profit is derived as Sales minus Operating Expenses and is not a separate entity.
28. Invoice / Receipt is not a separate financial transaction.
29. Currency is fixed to EGP.
30. V1 supports one branch.
31. Core domain behavior must not depend on internet connectivity.

---

# 62. Domain Non-Goals

The following are intentionally not part of the V1 domain model:

- Driver
- Vehicle
- Delivery Route
- Delivery Assignment
- Delivery Tracking
- Delivery Status
- Employee
- Role
- Permission
- Branch
- Refund
- Loyalty
- Barcode scanning workflow
- Storage movement history
- Storage capacity
- Detailed laundry processing stages
- Advanced analytics
- Profit entity
- Profit transaction
- Expense ledger
- AI assistant

These may be introduced in future versions if approved requirements justify them.

---

# 63. Future Extensibility

The domain should remain capable of supporting future requirements such as:

- Barcode identification
- Multi-device usage
- Advanced synchronization
- Multi-branch support
- Delivery management
- Refunds
- Expanded tax functionality
- Advanced pricing
- Storage history
- Expanded financial capabilities

Future extensibility must not introduce unnecessary V1 complexity.

---

# 64. Source of Truth

This document defines the approved V1 domain concepts and relationships.

The implementation must not introduce new business entities or relationships simply because they appear technically convenient.

If a required concept is missing or ambiguous, the domain documentation must be updated before implementation.

Database-specific decisions belong in:

> `docs/02-domain/database-design.md`

Architecture-specific decisions belong in:

> `docs/03-architecture/architecture.md`