# Laundry Management System — Database Relationships

## 1. Document Purpose

This document defines the approved V1 database relationships for the Laundry Management System.

It translates the approved Domain relationships into relational database relationships for:

SQLite
+
Drift

The relationships defined here must remain aligned with:

docs/01-product/
docs/02-domain/
docs/03-architecture/
docs/04-database/database-overview.md
docs/04-database/database-decisions.md
docs/04-database/tables.md
docs/04-database/constraints.md
docs/04-database/indexes.md

The database relationship model must support:

- Customers and Orders.
- Orders and physical OrderItems.
- Orders and Payments.
- OrderItems and ItemTypes.
- OrderItems and ItemDefinitions.
- OrderItems and Services.
- OrderItems and Carpet data.
- OrderItems and Storage.
- Services and supported ItemTypes.
- Carpet Sizes and carpet OrderItems.
- Storage Locations and supported ItemTypes.
- Expenses and Expense Categories.
- Independent financial reporting.
- Historical transaction integrity.
- Offline-first synchronization.

---

## 2. Relationship Notation

The relationship notation used in this document is:

1 ──────── N

means:

One-to-Many

and:

1 ──────── 1

means:

One-to-One

and:

N ──────── N

means:

Many-to-Many

Optional relationships are explicitly marked where applicable.

---

## 3. Customer → Order

Relationship:

Customer 1 ──────── N Order

Database:

orders.customer_id
    ↓
customers.id

Rules:

- Every Order belongs to exactly one Customer.
- A Customer may have zero or many Orders.
- An Order cannot exist without a valid Customer reference.
- Customer history must remain available.
- Customers with historical Orders must not be hard-deleted.

This relationship is a core transactional relationship.

---

## 4. Order → OrderItem

Relationship:

Order 1 ──────── N OrderItem

Database:

order_items.order_id
    ↓
orders.id

Rules:

- Every OrderItem belongs to exactly one Order.
- An Order must contain at least one OrderItem.
- Every physical laundry item has its own OrderItem ID.
- Multiple physical items from the same Order must remain separate records.
- OrderItems must not be merged simply because they have the same ItemType.

Example:

Order
    ├── OrderItem 1
    ├── OrderItem 2
    ├── OrderItem 3
    └── OrderItem 4

If the customer brings five shirts, the UI may display:

Shirt × 5

but the database represents the five physical pieces as five independent OrderItems.

This is required for the Storage workflow.

---

## 5. Order → Payment

Relationship:

Order 1 ──────── N Payment

Database:

payments.order_id
    ↓
orders.id

Rules:

- Every Payment belongs to exactly one Order.
- An Order may have zero, one, or many Payments.
- Multiple payments are supported.
- Payment history must remain preserved.
- Payments must not be overwritten to represent later payments.
- A Payment cannot exist without a valid Order.

Example:

Order
    ├── Payment 1
    ├── Payment 2
    └── Payment 3

The remaining amount is derived from:

Order Total
-
Sum of Payments
=
Remaining Amount

---

## 6. OrderItem → ItemType

Relationship:

ItemType 1 ──────── N OrderItem

Database:

order_items.item_type_id
    ↓
item_types.id

Rules:

- Every OrderItem belongs to exactly one ItemType.
- An ItemType may be used by many OrderItems.
- ItemType is master data.
- Deactivating an ItemType does not invalidate historical OrderItems.
- Inactive ItemTypes cannot be selected for new Orders.

The ItemType identifies the primary physical category of the item.

Examples:

- Clothes
- Blankets
- Carpets
- Other configured item types

---

## 7. ItemType → ItemDefinition

Relationship:

ItemType 1 ──────── N ItemDefinition

Database:

item_definitions.item_type_id
    ↓
item_types.id

Rules:

- Every ItemDefinition belongs to exactly one ItemType.
- An ItemType may have zero or many ItemDefinitions.
- An ItemDefinition cannot exist without a valid ItemType.
- ItemDefinitions are master data.
- Inactive ItemDefinitions cannot be selected for new transactions.
- Historical OrderItems remain valid when an ItemDefinition becomes inactive.

Example:

ItemType:
بطاطين

ItemDefinitions:
    ├── عادية
    ├── ثقيلة
    └── أطفال

---

## 8. OrderItem → ItemDefinition

Relationship:

ItemDefinition 1 ──────── N OrderItem

Database:

order_items.item_definition_id
    ↓
item_definitions.id

The relationship is optional.

Rules:

- An OrderItem may have zero or one selected ItemDefinition.
- An ItemDefinition may be used by many OrderItems.
- If an ItemDefinition is selected, it must belong to the selected OrderItem ItemType.
- The application must prevent invalid ItemType/ItemDefinition combinations.
- Historical transaction information must remain available even if the master ItemDefinition changes later.

Conceptually:

OrderItem
    ↓
ItemType
    ↓
Optional ItemDefinition

---

## 9. Service → OrderItem

Relationship:

Service 1 ──────── N OrderItem

Database:

order_items.service_id
    ↓
services.id

Rules:

- Every OrderItem has exactly one Service.
- A Service may be used by many OrderItems.
- Service is configurable master data.
- Inactive Services cannot be selected for new transactions.
- Existing OrderItems remain valid if a Service becomes inactive.
- Historical OrderItem pricing must not change when the Service master price changes.

The actual transaction price belongs to the OrderItem.

---

## 10. Service ↔ ItemType

Relationship:

Service N ──────── N ItemType

Implemented through:

ServiceItemType

Database:

service_item_types.service_id
    ↓
services.id

service_item_types.item_type_id
    ↓
item_types.id

Rules:

- A Service may support multiple ItemTypes.
- An ItemType may support multiple Services.
- Each Service/ItemType compatibility pair must be unique.
- An OrderItem may only select a Service compatible with its ItemType.
- Compatibility is master/configuration data.
- Inactive compatibility records must not be used for new transactions.

Example:

Service:
غسيل عادي

Supported ItemTypes:

    Clothes
    Blankets

Another Service may support:

    Carpets

---

## 11. OrderItem → OrderItemCarpet

Relationship:

OrderItem 1 ──────── 0..1 OrderItemCarpet

Database:

order_item_carpets.order_item_id
    ↓
order_items.id

Rules:

- A Carpet OrderItem may have one Carpet-specific record.
- A non-Carpet OrderItem should not require Carpet-specific data.
- An OrderItem cannot have multiple active Carpet detail records.
- Carpet-specific information remains associated with the OrderItem.

Carpet information may include:

- Carpet Size.
- Length.
- Width.
- Area.

---

## 12. CarpetSize → OrderItemCarpet

Relationship:

CarpetSize 1 ──────── N OrderItemCarpet

Database:

order_item_carpets.carpet_size_id
    ↓
carpet_sizes.id

The relationship is optional from OrderItemCarpet to CarpetSize.

Rules:

- An OrderItemCarpet may reference a predefined CarpetSize.
- An OrderItemCarpet may instead use custom dimensions.
- CarpetSize is master data.
- A CarpetSize may be used by many historical transactions.
- Deactivating a CarpetSize does not invalidate historical OrderItemCarpet records.

---

## 13. Carpet Custom Dimensions

When custom dimensions are used:

Length
+
Width
=
Area

The Area is calculated by the application/domain layer.

The user does not manually calculate the Area.

The database stores the required transaction-time dimensions.

Historical dimensions must remain unchanged even if the predefined CarpetSize configuration changes.

---

## 14. OrderItem → StorageRecord

Relationship:

OrderItem 1 ──────── N StorageRecord

Database:

storage_records.order_item_id
    ↓
order_items.id

The relationship is technically one-to-many because an OrderItem may have multiple StorageRecords over its lifetime.

However:

An OrderItem may have at most one active StorageRecord at any point in time.

Rules:

- Every StorageRecord belongs to exactly one OrderItem.
- An OrderItem may have zero or many historical StorageRecords.
- Only one StorageRecord may be active for an OrderItem.
- Historical StorageRecords remain preserved.
- Moving an item creates a new StorageRecord and deactivates the previous active record.

Example:

OrderItem
    ├── StorageRecord 1 → inactive
    ├── StorageRecord 2 → inactive
    └── StorageRecord 3 → active

---

## 15. StorageRecord → StorageLocation

Relationship:

StorageLocation 1 ──────── N StorageRecord

Database:

storage_records.storage_location_id
    ↓
storage_locations.id

Rules:

- Every StorageRecord references exactly one StorageLocation.
- A StorageLocation may have many StorageRecords.
- A StorageLocation may contain items from many Orders.
- A StorageLocation may contain multiple physical OrderItems.
- Historical StorageRecords remain valid if the StorageLocation becomes inactive.
- New Storage operations cannot select an inactive StorageLocation.

---

## 16. StorageLocation ↔ ItemType

Relationship:

StorageLocation N ──────── N ItemType

Implemented through:

StorageLocationItemType

Database:

storage_location_item_types.storage_location_id
    ↓
storage_locations.id

storage_location_item_types.item_type_id
    ↓
item_types.id

Rules:

- A StorageLocation may support multiple ItemTypes.
- An ItemType may be supported by multiple StorageLocations.
- Each StorageLocation/ItemType compatibility pair must be unique.
- Only compatible StorageLocations should be offered when storing an OrderItem.
- Inactive StorageLocations must not be offered for new storage operations.

---

## 17. Dynamic Storage Location Selection

Storage Location availability is determined from the selected OrderItem.

Flow:

Selected OrderItem
    ↓
OrderItem ItemType
    ↓
StorageLocationItemType
    ↓
Compatible StorageLocations

This means the Storage screen does not show every StorageLocation for every item.

Example:

Selected item:

Carpet

The application should show StorageLocations configured to support:

Carpets

and should not offer locations that only support:

Clothes

---

## 18. Order → Delivery Configuration

Delivery information belongs to the Order.

The Order supports two independent delivery directions:

1. Customer sends items to the laundry.
2. Laundry sends completed items to the customer.

The two directions are independent.

Conceptually:

Order
    ├── delivery_to_laundry_requested
    └── delivery_to_customer_requested

Both may be:

true

at the same time.

---

## 19. Order → Customer Pickup

Customer Pickup represents the case where the laundry receives the items from the customer through delivery.

Relationship:

Order 1 ──────── 0..1 Customer Pickup Configuration

In V1, this does not require a separate Delivery entity.

The Order stores the relevant configuration:

delivery_to_laundry_requested
delivery_to_laundry_fee

Rules:

- Pickup may be enabled or disabled independently.
- Pickup fee is associated with the Order.
- Pickup fee contributes to the Order total when applicable.
- Pickup is not a Payment.
- Pickup is not an Expense.

---

## 20. Order → Customer Delivery

Customer Delivery represents the case where the laundry sends the completed items to the customer.

Relationship:

Order 1 ──────── 0..1 Customer Delivery Configuration

In V1, this does not require a separate Delivery entity.

The Order stores:

delivery_to_customer_requested
delivery_to_customer_fee

Rules:

- Delivery may be enabled or disabled independently.
- Delivery fee is associated with the Order.
- Delivery fee contributes to the Order total when applicable.
- Delivery is not a Payment.
- Delivery is not an Expense.

---

## 21. Both Delivery Directions

The database must support all four combinations:

Pickup = false
Delivery = false

Pickup = true
Delivery = false

Pickup = false
Delivery = true

Pickup = true
Delivery = true

The following combination is explicitly valid:

Pickup = true
Delivery = true

This represents an Order where:

- The customer requests the laundry to receive the items.
- The customer also requests the laundry to deliver the completed items.

---

## 22. Delivery Fees and Order Total

Delivery fees are part of the Order financial calculation.

Example:

Services:
500 ج.م

Customer Pickup:
50 ج.م

Customer Delivery:
50 ج.م

Order Total:
600 ج.م

If the Customer pays:

300 ج.م

Then:

Remaining Amount:
300 ج.م

The delivery fees remain part of the Order total.

---

## 23. ExpenseCategory → Expense

Relationship:

ExpenseCategory 1 ──────── N Expense

Database:

expenses.expense_category_id
    ↓
expense_categories.id

Rules:

- Every Expense belongs to one ExpenseCategory.
- An ExpenseCategory may be used by many Expenses.
- ExpenseCategory is configurable master data.
- Inactive ExpenseCategories cannot be selected for new Expenses.
- Historical Expenses remain valid when a category is renamed or deactivated.

---

## 24. Expense Independence From Orders

Expense has no relationship to:

- Order
- OrderItem
- Payment
- Customer

There is no:

expenses.order_id

in the V1 relationship model.

Conceptually:

ExpenseCategory
    ↓
Expense

not:

Order
    ↓
Expense

An Expense represents a business operating cost rather than a customer transaction.

---

## 25. Expense → Custom Expense Name

An Expense may contain a custom name when the selected category is:

Other

Example:

ExpenseCategory:
Other

Custom Name:
إصلاح باب المحل

The custom name belongs to the Expense transaction.

The relationship remains:

ExpenseCategory
    ↓
Expense

No separate ExpenseName master entity is required in V1.

---

## 26. Expense Category Historical Integrity

ExpenseCategory is master data, but historical Expenses must remain understandable after configuration changes.

Example:

Current Category:
منظفات

Later renamed to:

مواد تنظيف

Historical Expense records must preserve the required transaction-time category information.

The relationship to the master record remains valid while the historical snapshot preserves the original meaning where required.

---

## 27. BusinessSettings

BusinessSettings is business-level configuration.

Relationship:

BusinessSettings
    ↓
Business Configuration

BusinessSettings is not a child of:

- Customer
- Order
- Expense
- Payment

It represents the current business configuration used by the application and Invoice presentation.

---

## 28. Invoice Relationships

V1 does not persist an Invoice as a separate database entity.

The Invoice is generated from existing relationships.

Conceptually:

Customer
    +
Order
    +
OrderItems
    +
Payments
    +
BusinessSettings
    ↓
Invoice Output

The Invoice therefore does not require:

invoice_id

as a separate persistent transaction identity in V1.

---

## 29. Order → Invoice Data

Invoice output can access:

Order
    ↓
OrderItems
    ↓
ItemType
    ↓
ItemDefinition
    ↓
Service
    ↓
Carpet Details where applicable

and:

Order
    ↓
Payments

and:

BusinessSettings

This allows the Invoice to display the required transaction information.

---

## 30. OrderItem Information Shared Across Workflows

OrderItem is the central source of item-level transaction information.

Order Details uses:

OrderItem

Invoice uses:

OrderItem

Storage uses:

OrderItem

Therefore OrderItem must preserve sufficient transaction information for all three workflows.

Important information includes:

- Item Type.
- Item Definition where applicable.
- Service.
- Quantity.
- Transaction price.
- Carpet Size where applicable.
- Carpet dimensions where applicable.

---

## 31. Master Data Relationships

The main master-data relationship structure is:

ItemType
    ├── ItemDefinitions
    ├── ServiceItemTypes
    └── StorageLocationItemTypes

Service
    └── ServiceItemTypes

CarpetSize
    └── OrderItemCarpets

ExpenseCategory
    └── Expenses

StorageLocation
    ├── StorageLocationItemTypes
    └── StorageRecords

Master data may become inactive without breaking historical transactional relationships.

---

## 32. Transaction Relationship Map

The primary transaction relationship is:

Customer
    ↓
Order
    ├── OrderItems
    ├── Payments
    └── Delivery Configuration

Each OrderItem then connects to:

ItemType
    ↓
Optional ItemDefinition

and:

Service

and, for carpets:

OrderItemCarpet
    ↓
Optional CarpetSize

and:

StorageRecords
    ↓
StorageLocation

Expenses exist independently:

ExpenseCategory
    ↓
Expense

---

## 33. Customer → Order → OrderItem → Storage

The complete operational chain is:

Customer
    ↓
Order
    ↓
OrderItem
    ↓
StorageRecord
    ↓
StorageLocation

This allows the application to answer:

- Which customer owns the item?
- Which Order contains the item?
- Which physical item is being stored?
- Where is the item currently stored?
- What is the item's storage history?

---

## 34. Customer → Order → Payment

The financial collection relationship is:

Customer
    ↓
Order
    ↓
Payment

This allows the application to answer:

- Which Customer owns the Order?
- What is the Order total?
- How much has been paid?
- What Payments were recorded?
- What remains to be paid?

Remaining amount remains derived.

---

## 35. Order → OrderItem → Service

The service relationship is:

Order
    ↓
OrderItem
    ↓
Service

The selected Service must be compatible with the OrderItem ItemType.

The application validates:

OrderItem.ItemType
    ↔
Service supported ItemTypes

---

## 36. Order → OrderItem → Carpet

For carpets:

Order
    ↓
OrderItem
    ↓
OrderItemCarpet
    ↓
Optional CarpetSize

Custom dimensions may be stored directly on OrderItemCarpet.

The calculated Area is based on the transaction dimensions.

---

## 37. Order → OrderItem → Storage Location

The storage relationship is:

Order
    ↓
OrderItem
    ↓
StorageRecord
    ↓
StorageLocation

StorageLocation compatibility is determined through:

OrderItem
    ↓
ItemType
    ↓
StorageLocationItemType
    ↓
StorageLocation

This ensures storage options are filtered according to the selected item's type.

---

## 38. Financial Relationship Separation

Financial data is intentionally separated into:

Customer transactions:

Order
    ↓
Payment

Business operating costs:

ExpenseCategory
    ↓
Expense

They are not directly related.

This separation is required for correct financial reporting.

---

## 39. Sales and Expenses

Sales are represented by Order transaction data.

Expenses are represented by Expense transactions.

The reporting layer combines them when calculating:

Net Profit

Conceptually:

Sales
-
Expenses
=
Net Profit

No direct database relationship between Order and Expense is required.

---

## 40. Payment and Expense Separation

Payment and Expense are separate concepts.

Payment:

Payment
    ↓
Order

Expense:

Expense
    ↓
ExpenseCategory

A Payment does not reference an Expense.

An Expense does not reference a Payment.

This prevents financial concepts from being mixed.

---

## 41. Order Status and Relationships

Order status is stored on Order.

Status changes do not change the structural relationships between:

Order
OrderItems
Payments

Storage behavior may be triggered by status changes through Domain/Application logic.

For example:

When an Order becomes Completed:

Active StorageRecords
    ↓
become inactive

The database relationship remains intact.

---

## 42. Ready State and Storage Relationship

The Ready state depends on Storage completion.

Conceptually:

Order
    ↓
All physical OrderItems
    ↓
Each has an active StorageRecord
    ↓
Order can become Ready

The Ready state must not be interpreted as:

One StorageRecord exists for the Order.

The correct requirement is:

Every physical OrderItem must have an active StorageRecord.

---

## 43. Order Cancellation and Relationships

Cancelled Orders remain historical.

Cancellation does not delete:

- Order
- OrderItems
- Payments
- Expense records
- Historical StorageRecords

If active StorageRecords exist for a cancelled Order:

they become inactive through the approved cancellation workflow.

The relationships remain valid.

---

## 44. Master Data Deactivation

Deactivation does not break relationships.

Example:

Service
    is_active = false

Existing:

OrderItem.service_id
    ↓
Service.id

remains valid.

The Service is simply unavailable for new applicable transactions.

The same principle applies to:

- ItemType
- ItemDefinition
- CarpetSize
- StorageLocation
- ExpenseCategory

---

## 45. Storage Location Deactivation

If a StorageLocation becomes inactive:

Existing StorageRecords
    ↓
remain valid

but:

New Storage Operations
    ↓
cannot select the inactive location

Historical storage relationships therefore remain intact.

---

## 46. Expense Category Deactivation

If an ExpenseCategory becomes inactive:

Existing Expenses
    ↓
remain valid

but:

New Expenses
    ↓
cannot select the inactive category

This preserves historical financial reporting.

---

## 47. Service Deactivation

If a Service becomes inactive:

Existing OrderItems
    ↓
remain linked to the Service

but:

New OrderItems
    ↓
cannot select the inactive Service

Historical transaction pricing remains unchanged.

---

## 48. ItemType Deactivation

If an ItemType becomes inactive:

Existing OrderItems
    ↓
remain linked to the ItemType

but:

New OrderItems
    ↓
cannot select the inactive ItemType

Dependent master data and historical transaction data remain valid.

---

## 49. ItemDefinition Deactivation

If an ItemDefinition becomes inactive:

Existing OrderItems
    ↓
remain linked to the ItemDefinition

but:

New OrderItems
    ↓
cannot select the inactive ItemDefinition

The ItemDefinition remains historically available.

---

## 50. CarpetSize Deactivation

If a CarpetSize becomes inactive:

Existing OrderItemCarpet records
    ↓
remain linked to the CarpetSize

but:

New transactions
    ↓
cannot select the inactive CarpetSize

Custom dimensions remain independent from CarpetSize activation state.

---

## 51. Relationship Integrity

The database must preserve referential integrity.

A child record must not reference a non-existent parent.

Examples:

Order.customer_id
    →
Existing Customer

OrderItem.order_id
    →
Existing Order

OrderItem.item_type_id
    →
Existing ItemType

OrderItem.service_id
    →
Existing Service

Payment.order_id
    →
Existing Order

Expense.expense_category_id
    →
Existing ExpenseCategory

StorageRecord.order_item_id
    →
Existing OrderItem

StorageRecord.storage_location_id
    →
Existing StorageLocation

OrderItemCarpet.order_item_id
    →
Existing OrderItem

OrderItemCarpet.carpet_size_id
    →
Existing CarpetSize where provided

---

## 52. Unique Relationship Constraints

The following relationship pairs should be unique where applicable:

Service
+
ItemType

StorageLocation
+
ItemType

This prevents duplicate compatibility records.

Each compatibility relationship represents a single logical configuration.

---

## 53. One Active Storage Relationship

The database must enforce or otherwise guarantee that an OrderItem has no more than one active StorageRecord.

Conceptually:

OrderItem
    ↓
StorageRecords

must satisfy:

Active StorageRecords = 0 or 1

This is critical to correctly identify the current location of an item.

---

## 54. Order Minimum Item Relationship

An Order must contain at least one OrderItem.

The database relationship is:

Order 1
    ↓
N OrderItems

but the business invariant is:

N >= 1

The application/domain layer should enforce this during Order creation and updates.

---

## 55. Order Completion Relationship Requirements

An Order may become Completed only when:

1. The Order is Ready.
2. Remaining amount is zero.
3. Customer handover is explicitly confirmed.

These are Domain/Application rules.

They are not represented as direct relational constraints between Order, Payment, and StorageRecord.

---

## 56. Payment Relationship Requirements

A Payment:

- Must belong to an Order.
- Must have a positive amount.
- Cannot exceed the current remaining amount.
- Remains historical after creation.
- Does not belong to an Expense.
- Does not alter OrderItem prices.

The structural relationship is:

Order
    ↓
Payment

The amount validation is a business rule.

---

## 57. Expense Relationship Requirements

An Expense:

- Must belong to an ExpenseCategory.
- Must have an amount greater than zero.
- Must have an Expense Date.
- May contain Notes.
- Requires a custom name when Category = Other.
- Is independent of Orders.
- Is independent of Payments.

The structural relationship is:

ExpenseCategory
    ↓
Expense

---

## 58. Delivery Relationship Requirements

Delivery configuration:

- Belongs to Order.
- Supports pickup and delivery independently.
- Allows both simultaneously.
- Stores applicable fees on Order.
- Does not require a separate Delivery entity in V1.

The Domain layer determines valid fee behavior.

---

## 59. Historical Data Relationship Rule

Historical transactional relationships must remain valid when master data changes.

Examples:

Service changes
    ↓
Historical OrderItem remains valid

ExpenseCategory changes
    ↓
Historical Expense remains valid

ItemType changes
    ↓
Historical OrderItem remains valid

CarpetSize changes
    ↓
Historical OrderItemCarpet remains valid

StorageLocation becomes inactive
    ↓
Historical StorageRecord remains valid

---

## 60. Cascade and Deletion Direction

The database must not blindly use cascading deletes for historical business data.

In particular:

Customer → Orders

must not allow deleting a Customer to silently delete historical Orders.

Similarly:

Order → OrderItems
Order → Payments

must not allow normal application operations to destroy historical transaction data.

The exact ON DELETE behavior is finalized in:

constraints.md

The preferred V1 direction is to preserve historical business records and use:

- Deactivation.
- Cancellation.
- Controlled deletion only where explicitly allowed.

---

## 61. Relationship Ownership Summary

The main ownership relationships are:

Customer
    owns Orders

Order
    owns OrderItems

Order
    owns Payments

OrderItem
    owns Carpet Details where applicable

OrderItem
    owns Storage History

StorageLocation
    is referenced by StorageRecords

ExpenseCategory
    owns Expense classification

Master data
    provides configuration for transactions

---

## 62. Relationship Cardinality Summary

Customer:

Customer 1 → N Orders

Order:

Order N → 1 Customer
Order 1 → N OrderItems
Order 1 → N Payments

OrderItem:

OrderItem N → 1 Order
OrderItem N → 1 ItemType
OrderItem N → 0..1 ItemDefinition
OrderItem N → 1 Service
OrderItem 1 → 0..1 OrderItemCarpet
OrderItem 1 → N StorageRecords

Payment:

Payment N → 1 Order

ItemDefinition:

ItemDefinition N → 1 ItemType

ServiceItemType:

ServiceItemType N → 1 Service
ServiceItemType N → 1 ItemType

OrderItemCarpet:

OrderItemCarpet 1 → 1 OrderItem
OrderItemCarpet N → 0..1 CarpetSize

CarpetSize:

CarpetSize 1 → N OrderItemCarpet

StorageRecord:

StorageRecord N → 1 OrderItem
StorageRecord N → 1 StorageLocation

StorageLocation:

StorageLocation 1 → N StorageRecords

StorageLocationItemType:

StorageLocationItemType N → 1 StorageLocation
StorageLocationItemType N → 1 ItemType

Expense:

Expense N → 1 ExpenseCategory

ExpenseCategory:

ExpenseCategory 1 → N Expenses

---

## 63. Complete Relationship Map

The complete V1 relational model is:

Customer
    ↓ 1:N
Order
    ├── ↓ 1:N
    │   OrderItem
    │       ├── ↓ N:1
    │       │   ItemType
    │       │       └── ↓ 1:N
    │       │           ItemDefinition
    │       │
    │       ├── ↓ N:1
    │       │   Service
    │       │       └── ServiceItemType ↔ ItemType
    │       │
    │       ├── ↓ 1:0..1
    │       │   OrderItemCarpet
    │       │       └── ↓ N:0..1
    │       │           CarpetSize
    │       │
    │       └── ↓ 1:N
    │           StorageRecord
    │               └── ↓ N:1
    │                   StorageLocation
    │                       └── StorageLocationItemType ↔ ItemType
    │
    ├── ↓ 1:N
    │   Payment
    │
    └── Delivery Configuration

ExpenseCategory
    ↓ 1:N
Expense

BusinessSettings

SyncOperation

---

## 64. Business Rules vs Relationships

Database relationships define structural integrity.

Examples:

Payment → Order

OrderItem → Order

OrderItem → ItemType

OrderItem → Service

StorageRecord → OrderItem

StorageRecord → StorageLocation

Expense → ExpenseCategory

Domain/Application logic defines business behavior.

Examples:

- Order can become Ready only when all physical OrderItems are stored.
- Order can become Completed only when Ready, fully paid, and handover is confirmed.
- Service must support ItemType.
- Payment cannot exceed remaining amount.
- Expense must have a valid active category for new transactions.
- Other Expense requires a custom name.
- Both delivery directions may be selected.
- Delivery fees affect Order total.
- Cancelled Order cannot be edited according to workflow rules.
- Inactive master data cannot be selected for new transactions.

The database must not become responsible for the entire business workflow.

---

## 65. Offline-First Relationship Requirements

All relationships must work correctly in the local database before synchronization.

A locally created:

Customer

may immediately own a locally created:

Order

which may immediately contain:

OrderItems

and:

Payments

Expenses

and:

StorageRecords

may also be created locally.

UUIDs ensure that relationship references can be established without waiting for server-generated IDs.

Synchronization must preserve these relationships when records are uploaded.

---

## 66. Synchronization and Relationship Integrity

Synchronization must not create duplicate logical relationships.

Examples:

One OrderItem must continue referencing exactly one Order.

One Payment must continue referencing exactly one Order.

One Expense must continue referencing exactly one ExpenseCategory.

One StorageRecord must continue referencing exactly one OrderItem and one StorageLocation.

Compatibility relationships must remain unique.

---

## 67. Final Relationship Principles

The V1 database relationship model follows these principles:

1. Every Order belongs to one Customer.
2. Every Order contains at least one OrderItem.
3. Every physical laundry item has its own OrderItem.
4. Every OrderItem belongs to one Order.
5. Every OrderItem belongs to one ItemType.
6. An OrderItem may optionally have one ItemDefinition.
7. Every OrderItem has one Service.
8. Service and ItemType compatibility is many-to-many.
9. Carpet-specific data is optional and belongs to the relevant OrderItem.
10. CarpetSize is optional for custom carpet dimensions.
11. An Order may have many Payments.
12. Payments are independent from Expenses.
13. Expenses belong to ExpenseCategories.
14. Expenses are independent from Orders.
15. Expense Categories are configurable master data.
16. Other Expenses may contain a custom Expense name.
17. Delivery pickup and delivery are independent Order-level configurations.
18. Both delivery directions may be enabled simultaneously.
19. Delivery fees belong to the Order.
20. Storage belongs to physical OrderItems, not entire Orders.
21. Storage Locations are compatible with specific ItemTypes.
22. An OrderItem may have many historical StorageRecords.
23. An OrderItem may have at most one active StorageRecord.
24. Storage history is preserved.
25. Inactive master data remains valid for historical relationships.
26. Inactive master data cannot be selected for new transactions.
27. Invoice output is generated from existing relationships.
28. Invoice does not require a persistent Invoice entity in V1.
29. Net Profit is derived from Sales and Expenses.
30. Profit does not require a separate relationship or entity.
31. Outstanding amount is derived from Order Total and Payments.
32. Referential integrity must be preserved.
33. Historical business records must not be destroyed through normal cascade deletion.
34. Critical relationship updates must be atomic.
35. UUIDs support local relationship creation for Offline-First operation.
36. The relationship model must remain simple and extensible for V1.

---

## 68. Final Approved Relationship Model

The approved V1 relationship structure is:

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
    ├── Payments
    │
    └── Delivery Configuration

ExpenseCategory
    ↓
Expense

BusinessSettings

SyncOperation

This is the approved V1 relational relationship baseline for the Laundry Management System.