# Domain Implementation

## 1. Purpose

This document defines how the approved V1 Domain Model is implemented in Flutter.

The purpose is to ensure that:

- Domain entities remain consistent with the approved Domain Model.
- Business invariants are enforced in the correct layer.
- Domain behavior does not depend on Flutter, Drift, SQLite, Dio, Retrofit, or other infrastructure.
- Historical transaction information remains stable.
- Physical laundry items retain independent identities.
- Order lifecycle rules remain deterministic.
- Financial calculations remain accurate.
- The implementation stays simple and avoids unnecessary architectural abstractions.

This document defines implementation guidance.

It does not redefine the business requirements.

The approved Domain Model, Business Rules, Product Scope, Architecture, and Database documentation remain the source of truth.

---

## 2. Domain Layer Responsibilities

The Domain layer represents business concepts and business rules.

It is responsible for:

- Entities
- Value concepts
- Enums
- Repository contracts
- Domain validation
- Business invariants
- Business calculations
- State transition rules
- Domain-specific decisions

The Domain layer must not depend on:

- Flutter
- Widgets
- BuildContext
- Cubit
- Bloc
- Drift
- SQLite
- Dio
- Retrofit
- HTTP
- Database tables
- API response objects
- UI localization
- UI-specific models

The Domain layer must remain usable without internet connectivity.

---

## 3. Approved V1 Domain Architecture

The V1 Domain structure is intentionally simple.

Conceptually:

Domain
├── Entities
├── Enums
├── Value Concepts
├── Repository Contracts
└── Limited Domain Services

There is:

- No mandatory Use Case layer.
- No mandatory Application layer.
- No mandatory Mapper layer.
- No generic domain manager.
- No generic domain service for every entity.
- No unnecessary abstraction.

Additional abstractions may only be introduced when there is a real domain problem that requires them.

---

## 4. Domain Dependency Rule

The dependency direction is:

Presentation
↓
Application-facing behavior
↓
Domain
↓
Nothing infrastructure-specific

More concretely:

UI
↓
Cubit
↓
Repository Contract
↓
Domain

Repository implementations and data sources live outside the Domain layer.

The Domain must never import infrastructure packages.

---

## 5. V1 Entity Set

The complete V1 entity set is:

### Transactional

- Customer
- Order
- OrderItem
- Payment
- Expense
- StorageRecord

### Master Data

- ItemType
- ItemDefinition
- Service
- ServiceItemType
- CarpetSize
- StorageLocation
- ExpenseCategory

### Configuration

- BusinessSettings

### Item-Specific

- CarpetItemData

### Supporting Values / Enums

- Money
- OrderStatus
- PricingType
- PaymentMethod

No additional business entity should be introduced without an approved requirement.

---

## 6. Explicitly Excluded Domain Concepts

The following are not V1 Domain entities:

- Driver
- Vehicle
- Delivery
- DeliveryRoute
- DeliveryAssignment
- DeliveryTracking
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
- ExpenseLedger
- AI Assistant

Future versions may introduce additional concepts when approved requirements justify them.

The implementation must not create these entities simply because they might become useful later.

---

## 7. Domain Separation

The following concepts must remain separate:

- Order
- Payment
- Expense
- OrderItem
- StorageRecord
- StorageLocation

They must not be merged into a generic transaction/activity entity.

Their responsibilities are different.

### Order

Represents the customer transaction.

### Payment

Represents money received from the customer against an Order.

### Expense

Represents money spent by the laundry.

### OrderItem

Represents one physical laundry piece.

### StorageRecord

Represents the current physical storage assignment of an OrderItem.

### StorageLocation

Represents a physical location where an item can currently be stored.

---

## 8. Customer

### Responsibility

`Customer` represents one laundry customer.

### Required Information

A Customer contains:

- Unique identifier
- Name
- Phone number
- Creation timestamp
- Update timestamp

### Relationships

One Customer can have multiple Orders.

Conceptually:

Customer
↓
1:N
Order

### Domain Rules

- Customer name is required.
- Customer phone number is required.
- Customer phone number should be unique.
- Customer information may be edited.
- Customer history must remain available.
- Customers with historical Orders must not be hard-deleted.

### Implementation Notes

Customer validation belongs to the Domain/Application boundary.

The Domain must not know how a phone number is displayed in the UI.

The Domain should validate business requirements rather than widget state.

---

## 9. Order

### Responsibility

`Order` represents one customer transaction with the laundry.

It is the primary transactional business entity.

### Core Information

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

### Relationships

Order:

- Belongs to exactly one Customer.
- Contains one or more OrderItems.
- May contain multiple Payments.

Conceptually:

Customer
↓
1:N
Order
↓
1:N
OrderItem

and:

Order
↓
1:N
Payment

---

## 10. Order Invariants

An Order:

- Must belong to exactly one Customer.
- Must contain at least one OrderItem.
- Must have an Expected Pickup Date.
- Must have exactly one V1 OrderStatus.
- May have neither delivery type.
- May have only Delivery to Laundry.
- May have only Delivery to Customer.
- May have both delivery types.
- Must preserve the delivery fees applicable to the transaction.
- Must preserve historical financial values.

An Order must never be considered valid merely because the database accepts the row.

Business invariants must also be validated before persistence.

---

## 11. Order Number

The human-readable Order Number is separate from the internal database ID.

Approved V1 format:

YY-XXX

Example:

26-001

The Order Number must:

- Be unique.
- Be assigned once.
- Remain unchanged after assignment.

The exact generation mechanism is an implementation concern.

The Domain must treat the generated Order Number as immutable after assignment.

---

## 12. Order Status

V1 supports exactly four statuses:

- Processing
- Ready
- Completed
- Cancelled

No additional operational status should be introduced.

The Domain should represent these using the approved `OrderStatus` enum/value representation.

---

## 13. Processing

`Processing` represents an active Order that is not yet ready for customer handover.

The system does not model individual laundry processing stages.

Do not introduce statuses such as:

- Washing
- Drying
- Ironing
- Folding
- QualityCheck

These are explicitly outside the V1 Domain Model.

---

## 14. Ready

An Order becomes Ready when all required physical OrderItems have an active StorageRecord.

Conceptually:

Every OrderItem stored
↓
Order = Ready

If at least one required OrderItem is not stored:

Order ≠ Ready

Example:

5 OrderItems

4 stored
1 not stored

Result:

Processing

The readiness rule is derived from physical OrderItem storage state.

---

## 15. Completed

Completed means that the Order has actually been handed over to the customer.

Completed does not simply mean:

- Ready
- Fully paid
- Laundry work finished

All completion conditions must be satisfied.

An Order can become Completed only when:

1. Order is Ready.
2. Remaining payment amount is zero.
3. User explicitly confirms customer handover.

Conceptually:

Ready
+
Fully Paid
+
Handover Confirmed
↓
Completed

---

## 16. Completion Validation

Completion validation belongs to the Domain/Application boundary.

Before completing an Order, validate:

- Current status is Ready.
- Remaining amount is zero.
- Customer handover is explicitly confirmed.

If any condition fails:

The operation must be rejected.

The Domain must not silently complete the Order.

---

## 17. Completion Effects

When an Order becomes Completed:

- Order status becomes Completed.
- Completion timestamp should be preserved where supported.
- All active StorageRecords belonging to its OrderItems become inactive.
- The Order remains available as historical data.

Conceptually:

Complete Order
↓
Order.status = Completed
↓
Deactivate active StorageRecords

The completion operation must not report success before the required persistence operation succeeds.

---

## 18. Completed Orders

Completed Orders are historical records.

Normal UI behavior should treat them as read-only.

A controlled correction may exist where explicitly supported by the approved business rules.

The Domain must not allow arbitrary status changes simply because the underlying enum assignment is technically possible.

---

## 19. Completed to Processing

If a Completed Order is manually changed back to Processing:

Previous StorageRecords must not automatically become active again.

Conceptually:

Completed
↓
Processing

does not imply:

Inactive StorageRecord
↓
Active StorageRecord

The user must explicitly store the physical items again if they return to storage.

This prevents the system from claiming that an item is physically stored when it is not.

---

## 20. Cancellation

Cancellation is a business state, not deletion.

Cancelling an Order requires explicit user confirmation.

A cancellation reason should be recorded.

A cancelled Order:

- Remains in history.
- Is no longer an active operational Order.
- Becomes operationally read-only.
- Preserves existing Payments.
- Deactivates active StorageRecords.
- Preserves cancellation information.

Cancellation information should include:

- Cancelled timestamp
- Cancellation reason

---

## 21. Cancellation Does Not Mean Refund

Cancelling an Order does not automatically create a refund.

The V1 Domain does not contain a Refund entity.

Existing Payment records remain historical records.

If refund functionality is introduced later, it must be an explicitly approved requirement.

---

## 22. Order Status Lifecycle

Normal lifecycle:

Processing
↓
Ready
↓
Completed

Cancellation may occur before completion:

Processing
↓
Cancelled

Ready
↓
Cancelled

Manual status correction is supported only where the approved business rules allow it.

Manual status correction must not automatically create incorrect physical Storage state.

---

## 23. Expected Pickup Date

Every Order requires an Expected Pickup Date.

The Domain value is date-only.

It does not contain a time component.

Example:

2026-08-25

The Domain should not treat the Expected Pickup Date as a DateTime business value.

The UI may display it using a localized Arabic representation.

---

## 24. Overdue Order

An Order is overdue when:

Expected Pickup Date < Today

AND:

Status != Completed

AND:

Status != Cancelled

Overdue detection is a domain/business rule.

It must not depend on UI formatting.

The exact source of "Today" should be controlled sufficiently to make tests deterministic.

---

## 25. Delivery

Delivery is intentionally modeled as an Order-level request in V1.

The Domain supports:

- Delivery to Laundry
- Delivery to Customer

They are independent.

Possible combinations:

- Neither
- Delivery to Laundry only
- Delivery to Customer only
- Both

Each delivery type has its own fee.

---

## 26. Delivery Fees

Delivery fees are part of Order pricing.

Conceptually:

Delivery Fees
=
Delivery to Laundry Fee
+
Delivery to Customer Fee

Only selected delivery types contribute their applicable fees.

Historical delivery fees must remain unchanged for an existing transaction.

---

## 27. Delivery Non-Goals

V1 does not contain Domain concepts for:

- Driver
- Vehicle
- Route
- Delivery assignment
- Delivery status
- Delivery tracking
- Delivery optimization
- Proof of delivery

Do not create these as part of Order implementation.

---

## 28. OrderItem

### Responsibility

`OrderItem` represents one physical laundry piece belonging to an Order.

This is a critical Domain concept.

Every physical piece must have an independent OrderItem identity.

Example:

User enters:

Shirt × 5

The Domain represents:

OrderItem A
OrderItem B
OrderItem C
OrderItem D
OrderItem E

not one OrderItem with quantity = 5 as the physical identity.

The UI may use quantity-based entry for convenience.

The Domain must preserve physical item identity.

---

## 29. OrderItem Core Information

An OrderItem may contain:

- Unique identifier
- Order reference
- ItemType reference
- ItemDefinition reference
- Service reference
- Historical service information
- Historical pricing information
- Item-specific notes
- Item-specific data
- Storage relationship

The exact persistence representation is defined by the Database documentation.

The Domain should represent the business meaning rather than database column layout.

---

## 30. OrderItem Identity

Every physical laundry piece must have a stable independent identifier.

The identifier:

- Is unique.
- Remains stable.
- Belongs to exactly one Order.
- Must not be regenerated during updates.
- Must remain usable for storage operations.

This identity is important for future barcode readiness and current storage workflows.

Barcode scanning itself is not a V1 feature.

---

## 31. OrderItem Relationships

Each OrderItem belongs to exactly one Order.

An OrderItem references:

- One ItemType.
- One ItemDefinition where applicable.
- One Service.
- Zero or one CarpetItemData depending on ItemType.
- At most one active StorageRecord.

---

## 32. ItemType

`ItemType` represents a broad item category.

V1 supports:

- Clothing
- Blankets
- Carpets
- Carpet Covers

ItemType is master data.

It can be activated/deactivated according to the approved master-data behavior.

---

## 33. ItemDefinition

`ItemDefinition` represents an applicable subtype/definition under an ItemType.

Relationship:

ItemType
↓
1:N
ItemDefinition

When an OrderItem uses an ItemDefinition:

ItemDefinition.itemTypeId
must equal
OrderItem.itemTypeId

An ItemDefinition belonging to another ItemType must not be assigned.

Inactive ItemDefinitions must not be selected for new Orders.

Historical OrderItems may continue referencing inactive definitions.

---

## 34. Carpet Covers

Carpet Covers do not require a separate subtype/type system.

They are operationally treated similarly to Blankets.

Do not introduce:

- CarpetCoverType
- CoverType
- Additional Cover taxonomy

unless a future approved requirement requires it.

---

## 35. Service

`Service` represents a laundry service offered by the business.

A Service may:

- Have a name.
- Have a price.
- Have a PricingType.
- Be active/inactive.
- Support one or more ItemTypes.

A Service can support multiple ItemTypes.

An ItemType can support multiple Services.

Relationship:

Service
N:M
ItemType

The actual compatibility relationship is represented through ServiceItemType.

---

## 36. Service Selection

An OrderItem may select a Service only when:

- Service is active.
- Service supports the OrderItem's ItemType.

Conceptually:

OrderItem
+
ItemType
↓
Service compatibility check
↓
Valid Service

The Domain/Application layer must validate this combination.

The UI should not be the only layer enforcing the rule.

---

## 37. Service Pricing

V1 supports these Domain-level PricingTypes:

- Per Piece
- Per Kilogram
- Per Square Meter
- Fixed Price

Only relevant pricing options should be presented to users according to the applicable item/service context.

Typical usage:

Clothing
→ Per Piece

Blankets
→ Per Piece

Carpet Covers
→ Per Piece

Carpets
→ Per Square Meter

---

## 38. Pricing Calculation

Pricing calculation must respect the selected PricingType.

The Domain must not blindly multiply every service price by quantity.

The required calculation depends on the pricing type.

Examples:

Per Piece:

unit price × piece quantity

Per Kilogram:

price × applicable weight

Per Square Meter:

price × calculated area

Fixed Price:

applicable fixed amount

The exact input requirements must follow the approved feature/business rules.

Do not invent unsupported pricing inputs.

---

## 39. Historical Pricing

Current Service pricing belongs to master data.

Historical OrderItem pricing belongs to the transaction.

Therefore:

Current Service Price

must never be used to reconstruct:

Historical OrderItem Price

after the transaction has been created.

An OrderItem must preserve the pricing information used at transaction time.

---

## 40. OrderItem Historical Snapshots

The following OrderItem information must be preserved:

- ItemType name snapshot
- ItemDefinition name snapshot
- Service name snapshot
- PricingType snapshot
- Unit price
- Calculated total

These values represent the historical transaction state.

Changing master data later must not silently rewrite these values.

---

## 41. CarpetItemData

`CarpetItemData` contains information specific to carpet OrderItems.

For Carpets, it contains:

- Length
- Width
- Area
- Optional reference to predefined CarpetSize where applicable

For non-Carpet item types:

CarpetItemData = null

---

## 42. Carpet Data Rules

For:

Clothing
→ CarpetItemData = null

Blankets
→ CarpetItemData = null

Carpet Covers
→ CarpetItemData = null

Carpets
→ CarpetItemData = required

This prevents irrelevant carpet fields from becoming universal nullable fields on every OrderItem.

---

## 43. Carpet Area

For a rectangular carpet:

Area is calculated from:

Length
×
Width

The calculated Area is part of the transaction state.

The Domain must preserve the historical area used for the transaction.

The system does not support:

- Irregular polygon calculations
- Image-based measurement
- Camera measurement
- AI measurement
- Advanced carpet classification

---

## 44. CarpetSize

`CarpetSize` represents predefined common carpet dimensions.

It is master/input data.

A predefined size may be selected when creating CarpetItemData.

However, CarpetSize is not the historical source of truth.

The transaction must preserve:

- Length
- Width
- Area

directly.

This ensures historical carpet dimensions remain stable if a predefined CarpetSize is later modified.

---

## 45. StorageRecord

`StorageRecord` represents the current physical storage assignment of an OrderItem.

An OrderItem can have:

- Zero active StorageRecords
- At most one active StorageRecord

A StorageRecord belongs to:

- Exactly one OrderItem.
- Exactly one StorageLocation.

---

## 46. Storage State

Storage state is represented separately from OrderItem itself.

Conceptually:

OrderItem
↓
Active StorageRecord
↓
StorageLocation

An OrderItem without an active StorageRecord is not currently stored.

An OrderItem with an active StorageRecord is currently stored.

---

## 47. Storage Replacement

When an OrderItem moves from one storage location to another:

The previous StorageRecord becomes inactive.

A new active StorageRecord represents the current location.

Conceptually:

Storage A
↓
Inactive

Storage B
↓
Active

The Domain must ensure that only one StorageRecord is active for an OrderItem.

V1 does not preserve detailed storage movement history.

---

## 48. Order Readiness and Storage

Order readiness is derived from physical OrderItems.

An Order is Ready when every required OrderItem has an active StorageRecord.

Conceptually:

Every OrderItem
↓
Active StorageRecord
↓
Order = Ready

If at least one required OrderItem is missing an active StorageRecord:

Order remains Processing.

The system must not treat partial storage as readiness.

---

## 49. Storage Pending State

An OrderItem requires storage when:

- It belongs to an active Order.
- It does not have an active StorageRecord.
- It has not been excluded by an applicable business rule.

Storage workflow operates at OrderItem level.

Example:

Order
├── Item A → Stored
└── Item B → Not Stored

Item B remains visible in the storage workflow.

The Order must not disappear merely because another item was already stored.

---

## 50. Storage Location Compatibility

StorageLocation is compatible with one or more ItemTypes.

The Domain/Application layer should validate that an OrderItem can be stored in the selected location according to the approved compatibility rules.

Do not allow an arbitrary ItemType/StorageLocation combination if the documented compatibility rules prohibit it.

---

## 51. Payment

`Payment` represents one payment transaction made against an Order.

Each Payment belongs to exactly one Order.

Multiple Payments are allowed for one Order.

Payment is a historical financial transaction.

Payment is not:

- An Expense
- An Order
- An OrderItem

---

## 52. Payment Information

A Payment contains:

- Unique identifier
- Order reference
- Amount
- PaymentMethod
- Payment timestamp
- Creation timestamp

Payments must not be overwritten simply to maintain a current balance.

Each payment remains an individual historical record.

---

## 53. PaymentMethod

V1 supports:

- cash
- instapay
- ewallet

Arabic UI representations:

cash
→ نقدي

instapay
→ إنستا باي

ewallet
→ محفظة إلكترونية

The Domain enum/value must remain language-independent.

Arabic labels belong to localization/presentation.

---

## 54. Payment Rules

A Payment:

- Must belong to exactly one Order.
- Must have an amount greater than zero.
- Must not exceed the current Order remaining amount.
- May be one of multiple payments against the same Order.
- Must remain a historical record.

Payment validation is a business rule and must not exist only in the UI.

---

## 55. Remaining Amount

Remaining Amount is derived.

Conceptually:

Order Total
-
Sum of Payments
=
Remaining Amount

It should not require a separate financial transaction entity.

If a cached value is introduced for performance, it must remain consistent with the underlying Order and Payment data.

---

## 56. Payment Completion Rule

An Order cannot become Completed while:

Remaining Amount > 0

Therefore:

Ready
+
Remaining Amount = 0
+
Handover Confirmed
↓
Completed

A fully paid Order is not automatically Completed.

Payment completion and customer handover are separate business events.

---

## 57. Money

`Money` represents a monetary amount in Egyptian Pounds.

V1 currency is:

EGP

Financial storage uses integer minor units.

Example:

100.50 EGP

is represented as:

10050 piastres

The Domain must not rely on binary floating-point values for monetary calculations.

---

## 58. Money Rules

Money calculations must preserve exact values.

Important operations include:

- Addition
- Subtraction
- Multiplication where required
- Comparison
- Zero comparison
- Positive-value validation

Financial calculations must not introduce floating-point rounding errors.

The exact implementation type follows the approved architecture/technical decision.

---

## 59. Expense

`Expense` represents an independent operating expense incurred by the laundry.

Expense is not:

- An Order
- A Payment
- An OrderItem
- A customer transaction

Expense does not require:

- Order reference
- Payment reference
- Customer reference

---

## 60. Expense Information

An Expense contains:

- Unique identifier
- ExpenseCategory reference
- Historical ExpenseCategory name snapshot
- Custom name where required
- Amount
- Date
- Optional notes
- Creation timestamp
- Update timestamp

---

## 61. Expense Rules

An Expense:

- Must belong to exactly one ExpenseCategory.
- Must have an amount greater than zero.
- Must have a date.
- Uses a date-only business value.
- Does not require an Order.
- Does not require a Payment.
- Preserves historical category information.

---

## 62. Other Expense Category

When the selected ExpenseCategory represents:

أخرى

the custom expense name is required.

Conceptually:

Category = Other
+
Custom Name
↓
Valid

Category = Other
+
No Custom Name
↓
Invalid

For normal categories, customName is not required.

The machine-readable category representation must remain independent of the Arabic UI label.

---

## 63. Expense Historical State

Historical Expense information must remain understandable if the ExpenseCategory is later:

- Renamed
- Deactivated

The Expense must preserve:

- Historical category name
- Custom name where applicable
- Amount
- Date

Master-data changes must not silently rewrite historical financial meaning.

---

## 64. ExpenseCategory

`ExpenseCategory` is master data for operating expenses.

It is managed independently from Orders and Payments.

ExpenseCategory may be:

- Created
- Active
- Deactivated

Historical Expenses may continue referencing an inactive category.

Do not physically remove historical category information when it is needed to preserve transaction meaning.

---

## 65. BusinessSettings

`BusinessSettings` represents the limited business configuration required by V1.

It may contain:

- Unique identifier
- Business name
- Address
- Phone
- Logo reference
- Invoice footer text
- Tax enabled
- Tax rate
- Creation timestamp
- Update timestamp

---

## 66. Fixed V1 Configuration

The following are fixed in V1:

Currency:
EGP

Branch:
Single Branch

Language:
Arabic

Direction:
RTL

These are not modeled as configurable business entities.

Do not create configuration entities for:

- Multiple branches
- Languages
- Currencies
- Roles
- Permissions

unless future requirements explicitly introduce them.

---

## 67. Tax

Tax configuration belongs to BusinessSettings.

Tax rate is relevant only when tax is enabled.

The Domain must calculate tax according to the approved pricing/business rules.

Historical Order financial values must preserve the transaction-time tax value.

Changing current tax configuration must not silently rewrite historical Orders.

---

## 68. Historical Transaction Principle

Historical transactions are immutable in meaning.

Changing master data must not silently change historical transactions.

This applies to:

- ItemType
- ItemDefinition
- Service
- Service price
- PricingType
- ExpenseCategory
- StorageLocation status
- CarpetSize

Historical transactions preserve their transaction-time values.

---

## 69. Historical Snapshot Principle

Transaction snapshots are part of the business model.

For OrderItem, preserve:

- ItemType name
- ItemDefinition name
- Service name
- PricingType
- Unit price
- Calculated total

For CarpetItemData, preserve:

- Length
- Width
- Area

For Order, preserve:

- Subtotal
- Discount
- Tax
- Total
- Delivery fees
- Delivery request state

For Expense, preserve:

- ExpenseCategory name
- Custom name
- Amount
- Date

These values must remain stable after master data changes.

---

## 70. Order Pricing

Order pricing conceptually includes:

OrderItem totals
+
Delivery fees
-
Discount
+
Tax where applicable
=
Order Total

The exact calculation order must follow the approved business rules.

Do not create a separate persisted financial-summary Domain entity.

---

## 71. Discount

Discount is an Order-level value.

It:

- Affects the Order total.
- Must be preserved historically.
- Must be reflected correctly in financial reporting.

Discount must not modify the historical unit price of individual OrderItems.

---

## 72. Net Profit

Net Profit is derived.

Conceptually:

Net Profit
=
Sales
-
Operating Expenses

It is not a separate Domain entity.

Do not create:

- Profit entity
- Profit transaction
- Profit ledger

for V1.

Financial reporting should derive the required information from existing transactional entities.

---

## 73. Invoice / Receipt

Invoice and Receipt are representations of existing transaction data.

They are not separate financial transactions.

Do not create an Invoice transaction entity merely to represent the printed/document view.

The Domain should expose the required transactional information to the appropriate presentation/reporting layer.

---

## 74. Date Values

The following Domain values are date-only:

- Expected Pickup Date
- Expense Date

They must not contain a time component.

Date-only values should not be silently converted into timezone-dependent DateTime values.

UI formatting is a Presentation responsibility.

---

## 75. DateTime Values

DateTime should be used only where the business meaning requires a timestamp.

Examples:

- Customer createdAt
- Customer updatedAt
- Order createdAt
- Order updatedAt
- Payment paidAt
- Payment createdAt
- Expense createdAt
- Expense updatedAt
- Completion timestamp
- Cancellation timestamp

The Domain should distinguish date-only business values from actual timestamps.

---

## 76. Domain Validation Categories

Validation should be divided conceptually into:

### Structural Validation

Examples:

- Required field missing
- Invalid amount
- Invalid date
- Invalid identifier

### Business Validation

Examples:

- Payment exceeds remaining amount.
- Order cannot be completed.
- Service does not support ItemType.
- ItemDefinition does not belong to ItemType.
- Other Expense requires custom name.

The second category represents business invariants.

---

## 77. Validation Location

Validation must not exist only in the UI.

The UI may perform immediate validation for user experience.

However, Domain/Application validation must remain the final business protection before mutation/persistence.

This prevents business rules from being bypassed by:

- Another screen
- Future background process
- Import process
- Synchronization
- Tests
- Another UI path

---

## 78. State Transition Validation

Status transitions must be validated as business operations.

Do not expose unrestricted code such as:

`order.status = anyStatus`

if doing so allows invalid business states.

Prefer explicit domain operations/concepts where necessary.

Examples:

- Mark Ready
- Complete Order
- Cancel Order
- Correct Status

The implementation may use methods or services depending on complexity.

Do not introduce a state machine framework for V1 unless actual complexity requires it.

---

## 79. Automatic Status Behavior

Some status behavior is derived from domain state.

For example:

All OrderItems stored
↓
Ready

This should not require the UI to manually calculate and persist readiness incorrectly.

The application/domain logic should provide a single reliable interpretation of readiness.

---

## 80. Manual Status Correction

Manual correction is allowed where documented.

However:

Changing status
≠
Automatically changing physical storage state

Examples:

Completed
→
Processing

must not reactivate old StorageRecords.

Manual correction must preserve the distinction between:

Business status

and:

Physical storage state.

---

## 81. Aggregate Boundaries

The Order is the central transactional aggregate for:

- Order
- OrderItems
- Payments
- Storage-related state where required by an operation

Operations that affect multiple related records must respect the approved transaction boundaries.

Do not create an abstract generic Aggregate framework merely to represent this concept.

The implementation should remain explicit and readable.

---

## 82. Order Creation

Creating an Order should conceptually validate:

1. Customer exists and is valid.
2. Expected Pickup Date exists.
3. At least one OrderItem exists.
4. Every OrderItem has valid ItemType.
5. ItemDefinition is compatible where used.
6. Service is active and compatible.
7. Pricing information is valid.
8. Delivery information is valid.
9. Discount/tax rules are valid.
10. Historical transaction values are captured.

Only after validation should the transaction be persisted.

---

## 83. OrderItem Creation

Creating an OrderItem should validate:

- Unique identity.
- Parent Order.
- ItemType.
- ItemDefinition where applicable.
- Service.
- Service compatibility.
- PricingType.
- Pricing inputs.
- Item-specific data.
- Carpet data where applicable.

The exact validation depends on ItemType and PricingType.

Do not require irrelevant data.

---

## 84. Conditional Item Data

Domain validation must respect conditional data.

For Carpets:

CarpetItemData is required.

For non-Carpets:

CarpetItemData must not be treated as required.

This avoids universal nullable data structures that obscure business meaning.

---

## 85. Service Compatibility

Before assigning a Service to an OrderItem:

Check:

Service is active

AND:

Service supports ItemType

If either condition fails:

Reject the operation.

The UI may hide incompatible Services for convenience, but the Domain/Application layer remains responsible for enforcing the rule.

---

## 86. ItemDefinition Compatibility

Before assigning an ItemDefinition:

Check:

ItemDefinition.itemTypeId
==
OrderItem.itemTypeId

If not:

Reject the operation.

Inactive ItemDefinitions must not be used for new Orders.

Historical references remain valid.

---

## 87. Payment Creation

Creating a Payment should conceptually:

1. Validate Order exists.
2. Validate PaymentMethod.
3. Validate amount > 0.
4. Calculate current remaining amount.
5. Ensure payment <= remaining amount.
6. Persist Payment.
7. Recalculate/read derived remaining amount.

Do not modify previous Payment records simply to update the balance.

---

## 88. Expense Creation

Creating an Expense should validate:

1. ExpenseCategory exists.
2. ExpenseCategory is valid for the operation.
3. Amount > 0.
4. Date is valid.
5. If category is Other, customName is present.
6. Historical category name is captured.

---

## 89. Storage Operation

Storing an OrderItem should conceptually:

1. Validate OrderItem exists.
2. Validate OrderItem is eligible for storage.
3. Validate StorageLocation.
4. Validate ItemType/location compatibility.
5. Deactivate previous active StorageRecord if replacing location.
6. Create new active StorageRecord.
7. Re-evaluate Order readiness.

The exact persistence transaction is defined by the Data/Database layer.

---

## 90. Completion Operation

Completing an Order should conceptually:

1. Load current Order state.
2. Confirm status = Ready.
3. Calculate remaining amount.
4. Confirm remaining amount = zero.
5. Require explicit handover confirmation.
6. Set status = Completed.
7. Preserve completion timestamp.
8. Deactivate active StorageRecords.
9. Persist atomically where required.

Failure at any required step must prevent a false Completed state.

---

## 91. Cancellation Operation

Cancelling an Order should conceptually:

1. Require explicit confirmation.
2. Validate cancellation is allowed.
3. Capture cancellation reason.
4. Set status = Cancelled.
5. Preserve cancellation timestamp.
6. Deactivate active StorageRecords.
7. Preserve existing Payments.
8. Persist the operation safely.

Cancellation must not delete the Order.

---

## 92. Domain and Database Responsibilities

The Domain/Application layer validates business meaning.

The Database layer protects low-level data integrity.

Both are required.

Examples:

Domain/Application:

- Payment <= Remaining Amount
- Service compatible with ItemType
- Order can only be Completed under required conditions

Database:

- Unique IDs
- Foreign keys
- Required columns
- Unique constraints
- Low-level integrity

Do not move all business rules into SQL simply because the database can technically enforce them.

Do not rely only on Domain validation when a database constraint can safely protect fundamental data integrity.

---

## 93. Domain and Repository Contracts

Repositories are defined by Domain-facing contracts.

The Domain should not depend on repository implementations.

Conceptually:

Domain Repository Contract
↓
Repository Implementation
↓
Local / Remote Data Sources

The Domain contract should describe business data access needs rather than SQL queries.

---

## 94. No Infrastructure Models in Domain

Domain entities must not be generated directly from:

- Drift tables
- SQLite rows
- JSON payloads
- API response classes

If infrastructure-specific models are required, they belong in Data.

The Domain model represents business meaning.

---

## 95. No UI Models in Domain

Do not place:

- Form state
- Dropdown models
- Table row models
- Screen-specific view models
- Widget state
- Localized display labels

inside Domain entities unless they are genuinely part of the business model.

For example:

`PaymentMethod.cash`

belongs to Domain.

`نقدي`

belongs to localization/presentation.

---

## 96. Domain Immutability

Where practical, Domain entities should be immutable or treated as immutable values.

Business mutations should be explicit.

For example:

Completing an Order should be an explicit operation rather than arbitrary field mutation from unrelated code.

The goal is to make invalid states harder to create.

Do not introduce heavy immutability frameworks solely for this purpose.

---

## 97. Entity Identity

All transactional entities use stable UUID-based identity.

This applies to:

- Customer
- Order
- OrderItem
- Payment
- Expense
- StorageRecord

and relevant master/configuration entities.

An entity ID must remain stable across:

- Updates
- Local persistence
- Future synchronization
- Reloads

The human-readable Order Number is separate from the internal UUID.

---

## 98. Historical Identity

Historical references must remain understandable.

Changing a master record does not mean historical transaction references should become invalid.

For example:

A Service may later become inactive.

Historical OrderItems using that Service remain valid because their transaction-time information has been preserved.

---

## 99. Active / Inactive Master Data

Master data generally follows:

Created
↓
Active
↓
Inactive

Examples:

- ItemType
- ItemDefinition
- Service
- StorageLocation
- ExpenseCategory

Deactivation is preferred over destructive deletion when historical references exist.

---

## 100. Historical vs Current Data

The Domain must distinguish:

### Current Master Data

Used for creating/editing new transactions.

Examples:

Current Service price

Current ItemDefinition name

Current ExpenseCategory name

### Historical Transaction Data

Used to preserve what happened.

Examples:

OrderItem unit price

OrderItem service name snapshot

Expense category name snapshot

Historical carpet area

Historical delivery fee

The two must not be mixed.

---

## 101. Domain Calculations

Calculations should be deterministic.

Examples:

- Order subtotal
- Delivery fees
- Discount
- Tax
- Total
- Remaining payment amount
- Carpet area
- Net profit/reporting-derived values

The same valid input should always produce the same result.

---

## 102. Derived Values

Derived values should not automatically become separate entities.

Examples:

- Remaining Amount
- Order readiness
- Overdue status
- Net Profit
- Financial summaries

These should be derived from source data unless a documented performance requirement justifies caching.

If caching is introduced, consistency must remain guaranteed.

---

## 103. Domain Services

A Domain Service may be introduced only when a business rule:

- Is genuinely domain logic.
- Does not naturally belong to one entity.
- Is reused meaningfully.
- Cannot be expressed clearly as a simple entity/value operation.

Examples that may justify limited services:

- Complex order pricing calculation
- Complex readiness calculation
- Financial summary calculation

Do not create:

- CustomerService
- OrderService
- PaymentService
- ExpenseService

simply because every entity has a CRUD operation.

---

## 104. No Generic CRUD Domain Service

Do not introduce a generic Domain abstraction such as:

GenericEntityService

or:

BaseCrudService

The Domain should remain explicit.

Customer behavior should remain Customer-specific.

Order behavior should remain Order-specific.

Expense behavior should remain Expense-specific.

---

## 105. No Generic Domain Entity

Do not introduce a universal:

Transaction

or:

BusinessEntity

that contains:

- Order
- Payment
- Expense
- Storage

These concepts are intentionally separate.

---

## 106. Domain Error Boundaries

Domain/business validation failures should map to application-level failures according to `error-handling.md`.

Examples:

Invalid payment
→ BusinessRuleFailure / ValidationFailure

Invalid service compatibility
→ BusinessRuleFailure

Invalid Order completion
→ BusinessRuleFailure

Infrastructure failures such as Drift exceptions do not belong in Domain.

---

## 107. Domain and Error Handling

The Domain should not:

- Catch DriftException
- Catch DioException
- Show UI errors
- Generate Arabic UI messages
- Log infrastructure stack traces as a business concern

The Domain communicates business failure.

The Repository handles infrastructure failure translation.

---

## 108. Domain Testing

Domain tests should focus on business behavior.

Important tests include:

### Order

- Order requires Customer.
- Order requires at least one OrderItem.
- Order requires Expected Pickup Date.
- Only approved statuses exist.
- Ready requires all required OrderItems to be stored.
- Completed requires Ready.
- Completed requires zero remaining amount.
- Completed requires handover confirmation.
- Completed deactivates active storage.
- Completed → Processing does not reactivate storage.
- Cancellation preserves the Order.
- Cancellation deactivates storage.

### Payment

- Amount must be positive.
- Payment cannot exceed remaining amount.
- Multiple Payments are supported.
- Remaining amount is derived correctly.

### Service

- Inactive Service cannot be selected for new Orders.
- Incompatible Service cannot be selected.

### ItemDefinition

- Definition must belong to selected ItemType.
- Inactive Definition cannot be selected for new Orders.

### Storage

- OrderItem can have at most one active StorageRecord.
- Moving an item deactivates previous storage.
- All stored items make Order Ready.

### Expense

- Amount must be positive.
- Category is required.
- Other category requires custom name.
- Historical category information remains stable.

### Carpet

- Carpet requires CarpetItemData.
- Non-Carpet items do not require CarpetItemData.
- Area calculation is correct.
- Historical dimensions remain stable.

---

## 109. Domain Edge Cases

The implementation should test meaningful boundary conditions.

Examples:

### Payment

Order total = 1000

Payment = 1000

Valid.

Payment = 1001

Invalid.

Payment = 0

Invalid.

Payment < 0

Invalid.

### Storage

3 OrderItems

3 stored

→ Ready

3 OrderItems

2 stored

→ Processing

### Completion

Ready + fully paid + handover confirmed

→ Completed

Ready + unpaid

→ Rejected

Ready + fully paid + no handover confirmation

→ Rejected

Processing + fully paid + handover confirmed

→ Rejected

---

## 110. Domain Test Isolation

Domain tests must not require:

- Flutter widgets
- Database
- SQLite
- Drift
- Dio
- Retrofit
- Internet
- Production credentials

They should run quickly and deterministically.

---

## 111. Domain Testing and Dates

Date-only logic must be tested using controlled dates.

For example, overdue detection should not depend on the actual machine clock in a way that makes tests unpredictable.

Tests should be able to represent:

Today

Yesterday

Tomorrow

without relying on the actual execution date.

---

## 112. Domain Testing and Money

Money tests must use exact integer minor-unit representations.

Avoid:

floating-point comparisons

for financial correctness.

Test:

- Zero
- Positive values
- Exact equality
- Partial payment
- Full payment
- Overpayment
- Large values where relevant

---

## 113. Domain Testing and Historical Values

Tests must verify that changing master data does not alter historical transaction values.

Example:

Service price:

100 EGP

OrderItem created:

100 EGP

Service price later changed:

150 EGP

Historical OrderItem:

must remain:

100 EGP

The same principle applies to:

- Service name
- ItemType name
- ItemDefinition name
- PricingType
- Carpet dimensions
- Delivery fees
- ExpenseCategory name

---

## 114. Domain Implementation and Offline-First

Core Domain behavior must not depend on internet connectivity.

The same Domain operation should remain valid whether the device is:

- Online
- Offline

Networking and synchronization are infrastructure concerns.

The Domain should not contain:

- Connectivity checks
- HTTP calls
- Sync queue management
- Retry scheduling

---

## 115. Domain Implementation and Synchronization

Future synchronization may require additional metadata and infrastructure.

However, synchronization must not redefine the Domain business model.

For example:

A locally created Order remains a valid Order even if its remote synchronization is pending.

Sync status is not the same as Order status.

Do not add operational Order statuses such as:

- PendingSync
- Syncing
- SyncFailed

to `OrderStatus`.

---

## 116. Domain and Sync Separation

Business status:

- Processing
- Ready
- Completed
- Cancelled

must remain separate from synchronization status.

Synchronization may have its own infrastructure state.

This prevents technical connectivity problems from changing the business meaning of an Order.

---

## 117. Domain and UI Navigation

The Domain must not know about navigation.

Do not put:

- Routes
- Screen names
- Navigation callbacks
- BuildContext

inside Domain entities or services.

Navigation belongs to Presentation/application infrastructure.

---

## 118. Domain and Localization

Domain enums and values must be language-independent.

For example:

`PaymentMethod.cash`

not:

`PaymentMethod.نقدي`

Arabic labels belong to localization.

The Domain should expose semantic values.

Presentation maps those values to Arabic UI text.

---

## 119. Domain and Permissions

V1 does not contain roles or permissions.

Do not introduce Domain authorization concepts unless an approved requirement requires them.

The current single-branch V1 model does not require:

- Role entity
- Permission entity
- User-role mapping

---

## 120. Domain and Multi-Branch

V1 supports one branch.

Do not add:

- Branch entity
- branchId to every entity
- Branch domain services

unless a future approved requirement introduces multi-branch support.

---

## 121. Domain and Delivery

Delivery remains an Order-level request.

Do not create a delivery aggregate or delivery workflow in the Domain.

The Domain only needs to represent:

- Delivery to Laundry
- Delivery to Customer
- Their applicable fees

The logistics domain is intentionally outside V1.

---

## 122. Domain and Reporting

Reporting should derive information from transactional Domain data.

Do not create duplicate financial entities solely for reports.

For example:

Financial Report

should derive from:

Orders
+
Payments
+
Expenses

rather than requiring:

FinancialSummaryEntity

as a separate transactional concept.

---

## 123. Domain and Dashboard

Dashboard values are derived from existing business data.

Do not create:

DashboardEntity

or other artificial Domain entities solely to support the UI.

The Dashboard consumes derived results.

---

## 124. Domain and Invoice

Invoice/Receipt representation consumes existing Order and business data.

Do not introduce Invoice as a separate financial transaction.

The Domain remains focused on actual business transactions.

---

## 125. Domain Change Rule

Before changing a Domain entity, determine:

- Which business requirement requires the change.
- Which invariant is affected.
- Which database tables are affected.
- Which repository contracts are affected.
- Which Cubits are affected.
- Which UI flows are affected.
- Which tests are affected.
- Which documentation is affected.

Do not modify the Domain simply to make a lower layer easier to implement.

---

## 126. Source of Truth

Domain implementation must remain consistent with:

- Product Scope
- Requirements
- Business Rules
- Domain Model
- Architecture
- Database Design
- Data Layer documentation
- UI/UX documentation

If implementation conflicts with an approved Domain rule:

Stop and resolve the documentation conflict.

Do not silently change the business model.

---

## 127. AI Coding Agent Rules

Before implementing Domain code, the AI coding agent must read the relevant:

- Product documentation
- Requirements
- Business Rules
- Domain Model
- Architecture documentation
- Database documentation where persistence behavior matters
- Data Layer documentation
- Error Handling documentation

The agent must not invent business behavior that is already documented.

---

## 128. AI Must Not Add Domain Complexity Automatically

The AI must not automatically introduce:

- Use Cases
- Application layer
- Generic Domain Services
- Generic CRUD services
- Generic repositories
- Generic transaction entities
- State-machine frameworks
- Validation frameworks
- Functional programming frameworks

unless there is a documented reason.

---

## 129. AI Must Not Invent Entities

The AI must not create new V1 entities for:

- Driver
- Vehicle
- Delivery
- DeliveryRoute
- Employee
- Role
- Permission
- Branch
- Refund
- Loyalty
- StorageMovement
- StorageCapacity
- LaundryProcessingStage
- Barcode
- Profit
- AccountingTransaction
- AI Assistant

without an approved requirement.

---

## 130. AI Must Not Invent Order Statuses

The AI must use exactly:

- Processing
- Ready
- Completed
- Cancelled

Do not create:

- Pending
- Washing
- Drying
- ReadyForPickup
- PickedUp
- Paid
- Unpaid
- Syncing
- SyncFailed

as Order operational statuses.

Payment and synchronization states remain separate concepts.

---

## 131. AI Must Preserve Historical Values

The AI must never implement master-data updates in a way that rewrites historical transaction meaning.

Examples:

Changing Service price must not recalculate old OrderItems.

Changing Service name must not erase historical service name snapshots.

Changing ExpenseCategory name must not make old Expenses lose their historical category meaning.

Changing CarpetSize must not change historical carpet dimensions.

---

## 132. AI Must Preserve Physical Item Identity

If the UI accepts:

Item × Quantity

the implementation must create independent OrderItems for physical pieces where required by the Domain Model.

Do not collapse physical pieces into one generic quantity record if doing so would break:

- Storage
- Item identity
- Future barcode readiness
- Physical workflow

---

## 133. AI Must Preserve Storage Rules

The AI must not:

- Allow multiple active StorageRecords for one OrderItem.
- Mark an Order Ready when some required items are unstored.
- Reactivate old StorageRecords automatically after Completed → Processing.
- Keep completed/cancelled items in Current Storage.
- Create storage movement history in V1.

---

## 134. AI Must Preserve Completion Rules

The AI must not mark an Order Completed simply because:

- All items are stored.
- The Order is Ready.
- The Order is fully paid.
- Laundry processing is assumed finished.

Completion requires:

Ready
+
Remaining Amount = 0
+
Explicit Handover Confirmation

---

## 135. AI Must Preserve Payment Rules

The AI must not:

- Allow zero/negative Payments.
- Allow Payment > Remaining Amount.
- Replace historical Payment records with a balance.
- Merge Payments into Order totals as a substitute for Payment records.

Remaining Amount is derived from:

Order Total
-
Payments

---

## 136. AI Must Preserve Expense Rules

The AI must not:

- Associate Expense with Order by default.
- Treat Expense as Payment.
- Allow non-positive Expense amounts.
- Require an Order for an Expense.
- Remove historical category meaning.
- Allow missing customName when the Other category requires it.

---

## 137. AI Must Preserve Conditional Data

The AI must not make all OrderItems require carpet data.

Rules:

Carpet
→ CarpetItemData required

Non-Carpet
→ CarpetItemData not required

Similarly, pricing inputs must depend on PricingType.

Do not expose irrelevant fields simply because the implementation is easier.

---

## 138. AI Must Preserve Language Independence

The AI must not place Arabic UI labels inside Domain enums.

Use semantic identifiers.

Example:

PaymentMethod.cash

not:

PaymentMethod.نقدي

Arabic display labels belong to localization/presentation.

---

## 139. AI Must Preserve Offline Independence

The AI must not add:

- HTTP calls
- Dio dependencies
- Connectivity checks
- Sync logic

inside Domain entities/services.

Core Domain behavior must remain independent of network availability.

---

## 140. AI Must Keep Domain Code Testable

Domain code should be easy to test without Flutter or infrastructure.

When implementing a business rule:

1. Identify the rule.
2. Implement the smallest appropriate Domain behavior.
3. Add focused tests.
4. Verify edge cases.
5. Keep infrastructure outside the Domain.

---

## 141. Definition of Done

Domain implementation is considered complete when:

- All approved V1 Domain entities are represented correctly.
- Entity responsibilities remain separated.
- Required relationships are preserved.
- Domain invariants are enforced.
- Order lifecycle rules are implemented correctly.
- Payment rules are enforced.
- Expense rules are enforced.
- Storage rules are enforced.
- Service compatibility is enforced.
- ItemDefinition compatibility is enforced.
- Carpet conditional data is enforced.
- Historical transaction values are preserved.
- Money uses exact minor-unit representation.
- Date-only values remain date-only.
- Domain code has no infrastructure dependencies.
- Domain tests cover important business rules.
- No unsupported V1 entities or statuses have been introduced.
- No unnecessary Domain abstractions have been introduced.
- Offline operation remains independent of networking.
- Future synchronization remains separate from business status.

---

## 142. Final Domain Flow

The approved conceptual flow is:

User
↓
Presentation
↓
Cubit
↓
Repository Contract
↓
Domain Rules
↓
Repository Implementation
↓
Data Layer

The Domain itself remains independent from:

- UI
- Database
- Network
- Synchronization
- Localization

The central principle is:

The Domain defines what the business means.

The Data layer defines how data is stored or retrieved.

The Presentation layer defines how the business is presented to the user.

The Domain must remain simple, explicit, testable, offline-capable, and faithful to the approved V1 business model.