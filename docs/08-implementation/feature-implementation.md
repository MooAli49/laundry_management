# Feature Implementation

## 1. Purpose

This document defines how V1 business features are implemented end-to-end in the Flutter application.

The goal is to ensure that every feature follows the same approved architecture:

Presentation
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source / DAO
↓
SQLite / Drift

The feature implementation must remain aligned with:

- Product Scope
- Requirements
- Business Rules
- Domain Model
- Architecture Guidelines
- Database Implementation
- Data Layer Implementation
- Domain Implementation
- Dependency Injection
- Error Handling
- Offline-First
- State Management
- Routing and Navigation
- Testing Strategy
- Validation Checklist

This document defines feature-level implementation behavior.

It does not redefine business requirements or database schema.

---

## 2. V1 Feature Map

The approved V1 feature structure is:

lib/
├── core/
├── domain/
├── data/
├── features/
│   ├── dashboard/
│   ├── orders/
│   ├── customers/
│   ├── storage/
│   ├── services/
│   ├── reports/
│   ├── expenses/
│   └── settings/
└── main.dart

The main product features are:

- Dashboard
- Orders
- Customers
- Storage
- Services
- Reports
- Expenses
- Settings

The feature structure should remain simple.

Do not introduce additional top-level features unless a documented requirement requires them.

---

## 3. Feature Boundary

Each feature owns its own:

- Screens
- Feature widgets
- Cubits
- Feature-specific presentation state
- Feature-specific presentation helpers

Shared business concepts remain in Domain.

Shared persistence remains in Data.

Shared application infrastructure remains in Core.

A feature must not directly access another feature's internal implementation.

---

## 4. Layer Responsibilities

### Presentation

Responsible for:

- Screens
- Widgets
- User interaction
- Form state
- Display formatting
- Loading indicators
- Empty states
- Error presentation
- Navigation requests

### Cubit

Responsible for:

- Feature state
- User action handling
- Calling repository contracts
- Coordinating presentation-level operations
- Exposing operation results to the UI
- Mapping application/domain failures into presentation state

### Domain

Responsible for:

- Entities
- Enums
- Business invariants
- Business calculations
- Business validation
- Repository contracts

### Data

Responsible for:

- Repository implementations
- Local data sources
- DAOs
- Database interaction
- Data conversion
- Future remote integration
- Persistence transactions

### Core

Responsible for shared infrastructure such as:

- Routing
- DI
- Localization
- Theme
- Errors
- Network infrastructure
- Shared widgets
- Shared utilities

---

## 5. Standard Feature Flow

The standard V1 feature flow is:

User Action
↓
Screen / Widget
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source / DAO
↓
Drift / SQLite
↓
Repository
↓
Cubit State
↓
UI Update

The Screen must not skip the Cubit.

The Cubit must not skip the Repository.

The Repository must not expose database implementation details to Presentation.

---

## 6. Feature Communication

A Feature Cubit communicates with repository contracts.

Preferred:

OrdersScreen
↓
OrdersCubit
↓
OrderRepository

Not preferred:

OrdersScreen
↓
OrderRepository

and prohibited:

OrdersScreen
↓
OrderDao

or:

OrdersCubit
↓
SQLite

or:

OrdersCubit
↓
Dio

---

## 7. Repository Contract Rule

Feature code should depend on Domain repository contracts.

Example:

OrdersCubit
↓
OrderRepository

The concrete:

OrderRepositoryImpl

remains in Data.

The Cubit should not depend on:

- OrderRepositoryImpl
- OrderLocalDataSource
- OrderDao
- AppDatabase

directly.

---

## 8. Feature Folder Structure

The default feature structure should remain lightweight.

Example:

features/orders/
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── cubit/

A feature should not automatically receive:

- domain/
- data/
- services/
- repositories/
- mappers/
- usecases/

inside its own feature directory.

Domain and Data remain centralized according to the approved project structure.

---

## 9. Feature Growth

A feature may be split internally when it becomes large.

For example:

features/orders/
└── presentation/
    ├── order_list/
    ├── order_creation/
    ├── order_details/
    └── order_payment/

This is allowed when the feature complexity justifies it.

Do not create deep nesting before it is necessary.

---

## 10. Cubit Rule

V1 uses Cubit for feature state management.

Bloc is not required.

The standard naming is:

<Feature>Cubit

Examples:

- OrdersCubit
- CustomersCubit
- StorageCubit
- ServicesCubit
- ReportsCubit
- ExpensesCubit
- SettingsCubit

A complex feature may contain more than one Cubit if there is a clear responsibility boundary.

Do not create multiple Cubits simply to divide a small feature artificially.

---

## 11. Cubit Lifecycle

Cubits should normally be short-lived presentation dependencies.

They should be created according to the screen/feature lifecycle.

They should not become global state holders unless there is a documented reason.

For example:

OrdersCubit

should not become a global application-wide state container merely because multiple screens use Order information.

Shared data should normally be obtained through the appropriate repository.

---

## 12. No Global App Cubit

Do not create:

AppCubit

as a container for unrelated feature state.

Do not put:

- Orders
- Customers
- Expenses
- Storage
- Reports

into one global Cubit.

Each feature owns its own presentation state.

---

## 13. Feature State

Feature Cubit state should represent what the UI needs to know.

Typical state categories include:

- Initial
- Loading
- Loaded
- Empty
- Failure
- Operation Success
- Operation Failure

The exact state structure should follow the State Management documentation.

Do not create technical state values that represent business concepts unless the business concept actually exists.

---

## 14. UI State vs Business State

Presentation state is not Domain business state.

For example:

Loading

is UI state.

Processing

is Order business state.

Do not add:

Loading

or:

Syncing

to `OrderStatus`.

Similarly:

Error

is not an OrderStatus.

---

## 15. Feature Read Operations

A read operation generally follows:

Screen Opens
↓
Cubit Load
↓
Repository Query
↓
Local Database
↓
Domain Entities
↓
Cubit Emits Loaded
↓
UI Displays Data

The feature should preferably consume reactive repository streams/watchers where the Data Layer supports them.

This keeps UI state synchronized with local changes.

---

## 16. Feature Write Operations

A write operation generally follows:

User Action
↓
Form Validation
↓
Cubit
↓
Repository
↓
Domain Validation
↓
Database Transaction
↓
Success
↓
Cubit Updates State
↓
UI Refreshes

The UI may perform immediate field validation.

Business validation must not exist only in the UI.

---

## 17. Local-First Feature Rule

V1 business operations are local-first.

The normal flow is:

User Action
↓
Cubit
↓
Repository
↓
Local Database
↓
Success
↓
Cubit
↓
Immediate UI Update

Future synchronization happens separately.

The feature must not require an internet connection for normal local operations.

This applies to:

- Orders
- Customers
- Payments
- Storage
- Expenses
- Supported master-data operations

---

## 18. Future Synchronization Boundary

Synchronization is deferred from the current local implementation phase.

Feature code must not implement synchronization logic directly.

Do not add:

- Sync queues inside Cubits
- HTTP requests inside Cubits
- Retry logic inside Screens
- Connectivity logic inside Widgets

When synchronization is introduced, it remains behind the Repository/Data infrastructure.

---

## 19. Feature Error Handling

Feature errors should follow the centralized error-handling strategy.

The Cubit should not expose raw infrastructure exceptions directly to the UI.

Examples:

Database failure
→ Repository translates infrastructure failure
→ Cubit receives application/domain failure
→ UI displays appropriate error state

Business rule failure:

Payment exceeds remaining amount
→ Business failure
→ Cubit failure state
→ Arabic user-facing message

The UI should not inspect raw Drift/Dio exceptions.

---

## 20. Feature Validation

Validation has two levels.

### Presentation Validation

Used for:

- Required form fields
- Input formatting
- Immediate feedback
- Preventing obviously invalid submissions

### Business Validation

Used for:

- Payment <= Remaining Amount
- Service compatibility
- ItemDefinition compatibility
- Order completion rules
- Storage readiness
- Expense Other/customName rule
- Conditional Carpet data

Presentation validation improves UX.

Business validation protects correctness.

---

## 21. Feature Transactions

A feature operation that modifies multiple related records must be executed atomically by the Data Layer.

Examples:

Create Order
+
Create OrderItems
+
Create Carpet data where required

Record Payment
+
Create required synchronization record when synchronization exists

Store Item
+
Create StorageRecord

Move Item
+
Deactivate old StorageRecord
+
Create new StorageRecord

Complete Order
+
Update Order
+
Set completedAt
+
Deactivate active StorageRecords

Cancel Order
+
Update Order
+
Set cancelledAt
+
Save cancellation reason
+
Deactivate active StorageRecords

The Feature does not manually coordinate database transactions.

The Repository/Data Layer owns transaction boundaries.

---

## 22. Order Feature

The Orders feature is the primary operational feature.

It is responsible for:

- Order listing
- Order creation
- Order details
- Order item management
- Payment operations related to an Order
- Order status operations
- Completion
- Cancellation
- Historical Order viewing

The exact screen grouping follows the approved UI/UX.

---

## 23. Order Feature Structure

Recommended starting structure:

features/orders/
└── presentation/
    ├── screens/
    ├── widgets/
    └── cubit/

If the feature grows significantly, it may be split into:

features/orders/
└── presentation/
    ├── order_list/
    ├── order_creation/
    ├── order_details/
    └── order_payment/

Do not create this deeper structure unless implementation complexity justifies it.

---

## 24. Order Creation Flow

Conceptual flow:

Create Order
↓
Select Customer
↓
Set Expected Pickup Date
↓
Add OrderItems
↓
Select ItemType
↓
Select ItemDefinition where applicable
↓
Select Service
↓
Enter required pricing/item data
↓
Configure delivery where applicable
↓
Apply discount/tax according to approved rules
↓
Calculate total
↓
Validate Order
↓
Save Order transactionally
↓
Display Order

The UI should guide the user through valid combinations.

The Repository/Data Layer persists the result.

---

## 25. Order Item Entry

The UI may allow quantity-based entry for convenience.

Example:

Shirt × 5

However, the implementation must create independent physical OrderItems where required.

Conceptually:

Quantity = 5

becomes:

OrderItem A
OrderItem B
OrderItem C
OrderItem D
OrderItem E

This is required because storage operates at physical OrderItem level.

---

## 26. Order Item Pricing

The Orders feature must respect the selected PricingType.

Supported V1 Operational PricingTypes:

- Per Piece
- Fixed Price
- Per Square Meter

*(Note: Per Kilogram pricing has been completely removed from V1 operations).*

The feature must not assume:

price × quantity

for every service.

Pricing inputs depend on the selected PricingType.

---

## 27. Carpet Order Items

For Carpet items:

- CarpetItemData is required.
- Length is required.
- Width is required.
- Area is calculated.
- Historical dimensions are preserved.

For non-Carpet items:

- CarpetItemData is not required.
- Carpet-specific fields must not become mandatory.

The UI should only expose carpet-specific fields when appropriate.

---

## 28. Service Selection

When creating an OrderItem:

The selected Service must:

- Be active.
- Support the selected ItemType.

The UI may filter the Service list.

The business rule must still be enforced outside the UI.

An incompatible Service must be rejected.

---

## 29. ItemDefinition Selection

When an ItemDefinition is selected:

Its ItemType must match the OrderItem ItemType.

Inactive ItemDefinitions must not be selectable for new Orders.

Historical OrderItems may continue referencing inactive definitions.

---

## 30. Historical Order Data

The Orders feature must never reconstruct historical transaction information from current master data.

Historical OrderItem values must remain stable.

This includes:

- ItemType name
- ItemDefinition name
- Service name
- PricingType
- Unit price
- Calculated total

Order-level historical values include:

- Subtotal
- Discount
- Tax
- Total
- Delivery fees
- Delivery request state

---

## 31. Order Details

Opening Order Details should provide the information needed for operations and historical understanding.

Conceptually:

Order
+
Customer
+
OrderItems
+
Payments
+
Storage Information

The screen should not query the database directly.

The Cubit obtains the required information through repository contracts.

---

## 32. Payment in Orders

Payments belong to the Order workflow but remain a separate Domain entity.

The Orders feature may expose payment actions from Order Details.

Conceptually:

Order Details
↓
Record Payment
↓
Payment Repository
↓
Payment saved
↓
Order remaining amount updates

The Payment record must remain independently stored.

---

## 33. Payment Validation

Before recording a payment:

- Amount > 0.
- PaymentMethod is valid.
- Order exists.
- Payment <= current Remaining Amount.

The feature must not allow overpayment.

Multiple payments are supported.

Example:

Order Total = 1000

Payment 1 = 400

Remaining = 600

Payment 2 = 600

Remaining = 0

The Order is fully paid but is not automatically Completed.

---

## 34. Order Completion

Completion is a business operation.

The feature must require:

- Order is Ready.
- Remaining amount = 0.
- Explicit customer handover confirmation.

Conceptually:

Ready
+
Fully Paid
+
Handover Confirmed
↓
Complete Order

The UI should clearly communicate why completion is unavailable when a prerequisite is missing.

---

## 35. Completion Side Effects

Completing an Order also requires:

- Status = Completed
- Completion timestamp
- Active StorageRecords deactivated

These changes must be persisted atomically.

The UI must not independently update the status and storage state.

---

## 36. Order Cancellation

Cancellation requires explicit confirmation.

The feature should collect a cancellation reason where required.

Conceptually:

Cancel
↓
Confirm
↓
Enter reason
↓
Validate
↓
Cancel Order
↓
Deactivate active storage
↓
Preserve history

Cancelled Orders remain stored.

They are not physically deleted.

---

## 37. Cancelled Orders

Cancelled Orders are operationally read-only.

The feature must not allow normal editing of a cancelled Order.

Existing Payment records remain historical.

Cancellation does not automatically create a Refund because Refund is not a V1 Domain entity.

---

## 38. Status Correction

If a supported manual correction changes:

Completed
→
Processing

the feature must not reactivate previous StorageRecords automatically.

The user must explicitly store the physical items again through the Storage workflow.

Business status and physical storage state remain separate.

---

## 39. Customers Feature

The Customers feature is responsible for:

- Customer list
- Customer creation
- Customer editing
- Customer lookup
- Customer history access where supported

It communicates with:

CustomerRepository

It must not access Order Data Sources directly.

Customer history should be obtained through the appropriate repository contract.

---

## 40. Customer Creation

Creating a Customer requires:

- Name
- Phone number

The phone number should satisfy the approved uniqueness rule.

The feature should provide clear validation feedback before saving.

The final business validation must not depend solely on the form.

---

## 41. Customer Editing

Customers may be edited according to the approved business rules.

Editing a Customer must not rewrite historical Order snapshots.

Historical Orders remain associated with the same Customer identity while preserving their own historical transaction values.

---

## 42. Customer Deletion

Customers with historical Orders must not be physically deleted.

The feature should prefer the approved lifecycle behavior.

Do not add destructive deletion merely because the database technically permits it.

---

## 43. Storage Feature

The Storage feature manages the physical storage workflow for OrderItems.

It is responsible for:

- Items requiring storage
- Selecting compatible storage locations
- Storing items
- Moving items
- Viewing items in a storage location
- Current item location

Storage operates at OrderItem level.

It does not operate only at Order level.

---

## 44. Storage Feature Flow

Conceptual flow:

Storage Screen
↓
Load OrderItems requiring storage
↓
Select OrderItem
↓
Show compatible StorageLocations
↓
Select StorageLocation
↓
Store Item
↓
Create active StorageRecord
↓
Re-evaluate Order readiness
↓
UI updates

The Storage feature must not access the database directly.

---

## 45. Items Requiring Storage

An OrderItem requires storage when:

- It belongs to an active Order.
- It has no active StorageRecord.
- It is eligible according to business rules.

If an Order contains:

Item A → Stored

Item B → Not Stored

Item B must remain visible in the storage workflow.

The Order must not disappear simply because one item is already stored.

---

## 46. Storage Location Compatibility

The available StorageLocations for an OrderItem should be filtered by ItemType compatibility.

An incompatible StorageLocation must not be accepted by the business operation even if the UI accidentally attempts to submit it.

---

## 47. Moving an Item

Moving an OrderItem requires:

- Deactivate old active StorageRecord.
- Create new active StorageRecord.

The operation must be atomic.

Only one active StorageRecord may exist for an OrderItem.

---

## 48. Storage and Order Readiness

After storage changes, Order readiness may change.

Conceptually:

All required OrderItems stored
↓
Order Ready

At least one required OrderItem unstored
↓
Order remains Processing

The Storage feature should not manually duplicate readiness rules.

The Domain/Application logic should provide the authoritative behavior.

---

## 49. Services Feature

The Services feature manages service-related master data.

It may manage:

- Services
- Item Types
- Item Definitions
- Carpet Sizes

The exact UI grouping follows the approved design.

Services are master data.

They may be:

- Created
- Edited
- Activated
- Deactivated

---

## 50. Service Management

Creating or editing a Service may include:

- Name
- Price
- PricingType
- Supported ItemTypes

The feature must preserve the compatibility relationship.

A Service can support multiple ItemTypes.

An ItemType can support multiple Services.

---

## 51. Service Deactivation

Deactivating a Service prevents it from being selected for new Orders.

Historical OrderItems using the Service remain valid.

The feature must not rewrite historical transaction data when a Service is edited or deactivated.

---

## 52. Item Type Management

Item Types are master data.

V1 supports:

- Clothing
- Blankets
- Carpets
- Carpet Covers

The feature must not introduce additional ItemTypes without an approved requirement.

---

## 53. Item Definition Management

ItemDefinitions belong to ItemTypes.

The feature must ensure:

ItemDefinition.itemTypeId
==
selected ItemType

Inactive definitions should not be available for new transaction creation.

Historical OrderItems remain valid.

---

## 54. Carpet Size Management

CarpetSizes are predefined master data.

They may be:

- Created
- Edited
- Activated
- Deactivated

Changing a CarpetSize must not modify historical CarpetItemData.

Historical transactions preserve:

- Length
- Width
- Area

---

## 55. Expenses Feature

The Expenses feature is responsible for daily operating expenses.

It is responsible for:

- Creating Expenses
- Editing Expenses
- Listing Expenses
- Filtering Expenses
- Selecting Expense Categories
- Validating Expense forms
- Displaying Expense state

It must not directly access:

- SQLite
- Drift
- SQL
- Dio
- Retrofit

---

## 56. Expense Creation

Creating an Expense requires:

- Amount
- Category
- Date

Optional:

- Notes

When Category = Other:

- Custom Name becomes required.

The custom name belongs to the Expense transaction.

It is not a separate master-data entity.

---

## 57. Expense Validation

Before saving an Expense:

- Amount > 0.
- Category exists.
- Date is valid.
- Category is valid.
- If Category = Other, customName is present.

Business validation must not rely only on the form.

---

## 58. Expense Historical State

Expense history must preserve:

- Expense category name snapshot
- Custom name
- Amount
- Date
- Notes where applicable

Changing or deactivating an ExpenseCategory must not rewrite historical Expenses.

---

## 59. Expense Filtering

The Expenses feature may support:

- Date filtering
- Category filtering
- Relevant combinations of supported filters

Filtering should be delegated to repository operations rather than loading all records into the UI and performing database-sized filtering manually.

The final query strategy belongs to the Data Layer.

---

## 60. Expense Categories

Expense Categories are master data managed from Settings.

They are not a separate top-level navigation feature.

Settings manages:

- Category name
- Active/inactive state

Expenses manages:

- Selecting the Category
- Handling Other
- Entering transaction custom name

---

## 61. Reports Feature

The Reports feature is responsible for financial reporting and summaries.

The approved reporting concepts include:

- Financial reporting
- Expense breakdown
- Net Profit

Reports derive information from transactional data.

Do not introduce:

- Profit entity
- FinancialSummary entity
- AccountingTransaction entity

solely to support reporting.

---

## 62. Reports Data Flow

Conceptually:

Reports Screen
↓
ReportsCubit
↓
Appropriate Repository Contracts
↓
Local Queries / Calculations
↓
Derived Report Data
↓
Cubit
↓
UI

The Reports screen must not query:

- ExpenseDao
- OrderDao
- PaymentDao

directly.

---

## 63. Net Profit

Net Profit is derived.

Conceptually:

Sales
-
Operating Expenses
=
Net Profit

It is not stored as a separate transactional entity for V1 unless a documented performance requirement later justifies caching.

---

## 64. Dashboard Feature

The Dashboard provides operational overview and quick actions.

It should consume derived information from the appropriate repository contracts.

It must not become a second business-logic layer.

Do not create:

DashboardEntity

or:

AppRepository

simply to aggregate unrelated business data.

The Dashboard should request the data it needs through appropriate contracts.

---

## 65. Dashboard Metrics

Dashboard metrics may include approved operational values such as:

- Relevant Order counts
- Ready Orders
- Overdue Orders
- Storage-related operational information
- Financial summary information where approved

The exact metrics must follow the approved Dashboard documentation and UI.

Do not invent additional business KPIs.

---

## 66. Settings Feature

Settings manages configuration and master data.

It may contain:

- Business Settings
- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Storage Locations
- Expense Categories

Settings remains one top-level feature.

Do not create separate top-level navigation modules for every master-data type.

---

## 67. Business Settings

The Settings feature manages approved BusinessSettings values.

Examples include:

- Business name
- Address
- Phone
- Logo reference
- Invoice footer
- Tax enabled
- Tax rate

Changes to current settings must not silently rewrite historical transaction values.

---

## 68. Storage Location Management

Storage Locations are master data.

Settings may manage:

- Location name
- Active/inactive state
- Compatible ItemTypes

Deactivating a StorageLocation must not invalidate historical StorageRecords.

Existing StorageRecords remain valid.

Inactive locations should not be selectable for new storage operations where the business rules prohibit it.

---

## 69. Master Data and Transactions

Master-data changes must always respect the historical transaction principle.

Examples:

Change Service price
→ Old OrderItem price remains unchanged.

Change Service name
→ Historical Service snapshot remains unchanged.

Deactivate ItemDefinition
→ Historical OrderItems remain valid.

Change CarpetSize
→ Historical carpet dimensions remain unchanged.

Rename ExpenseCategory
→ Historical Expense category snapshot remains understandable.

Deactivate StorageLocation
→ Existing StorageRecords remain valid.

---

## 70. Cross-Feature Data Access

A feature may need information owned conceptually by another feature.

It should not access that feature's internal Cubit or Data Source.

Preferred:

Feature Cubit
↓
Appropriate Repository Contract

Not:

Feature A Cubit
↓
Feature B Cubit

unless a clearly documented presentation-level coordination requirement exists.

The default architecture should avoid Cubit-to-Cubit coupling.

---

## 71. Cross-Feature Example

Orders needs customer information.

Preferred:

OrdersCubit
↓
OrderRepository
↓
Required Order/Customer data

or another explicitly approved repository contract.

Not:

OrdersCubit
↓
CustomersCubit

Similarly:

Reports

should not depend on:

ExpensesCubit

just to calculate expense totals.

It should use the appropriate repository contract.

---

## 72. No Direct Feature-to-Data Access

Prohibited:

Screen → DAO

Cubit → DAO

Widget → Database

Feature → SQL

Feature → Drift

Feature → Dio

Feature → Retrofit

All persistence access must pass through the approved repository boundary.

---

## 73. No Feature-Owned Repository Implementations

Repository contracts live in Domain.

Repository implementations live in Data.

Do not create:

features/orders/data/order_repository_impl.dart

unless the project structure is explicitly changed later.

The current approved structure centralizes Data implementations.

---

## 74. Selective Use Cases Layer (Task #04 Approved)

Use Cases are NOT a mandatory layer for every feature or simple CRUD operation.

However, for complex multi-step transactional business workflows, the Application UseCases layer (`lib/application/use_cases/`) is explicitly approved:
- `CreateOrderUseCase`
- `StoreOrderItemsUseCase`
- `MoveStoredItemUseCase`
- `ChangeOrderStatusUseCase`
- `CompleteOrderUseCase`
- `CancelOrderUseCase`

Simple entity operations continue to use direct interaction between Cubits and Repository Contracts without mandatory UseCase wrappers.

---

## 75. Selective Application Layer (Task #04 Approved)

An Application layer is approved specifically for orchestrating multi-repository business workflows (such as physical item expansion, storage rules, status matrices, and handover/balance verification).

The Application layer must remain pure Dart with zero Flutter, Drift, SQLite, or DAO imports. It must not be used as an unnecessary generic wrapper for simple CRUD operations.

---

## 76. No Mapper Layer

Do not introduce a dedicated Mapper layer.

Simple Data ↔ Domain conversion should remain close to the Data Layer boundary.

If conversion becomes genuinely complex, the architecture must be reconsidered explicitly rather than silently introducing a new layer.

---

## 77. Feature Forms

Forms belong to Presentation.

A form may contain:

- Controllers
- Field state
- Validation display
- Input formatting
- Temporary draft values

A form must not directly save to the database.

The submit action should call the Cubit.

---

## 78. Feature Form Submission

Preferred flow:

Form
↓
Cubit Action
↓
Presentation Validation
↓
Repository
↓
Domain/Business Validation
↓
Persistence
↓
Success / Failure
↓
Cubit State
↓
UI

The form must not construct:

- Repository implementations
- Database objects
- DAOs
- Dio clients

---

## 79. Feature Lists

List screens should consume state from the Cubit.

Preferred:

Repository Watch
↓
Cubit
↓
State
↓
List UI

The UI should not independently query the database.

Empty states should be represented explicitly.

---

## 80. Feature Details

Details screens should receive or load the required entity identity.

Example:

Order Details

may receive:

orderId

Then:

OrderDetailsScreen
↓
OrdersCubit
↓
OrderRepository
↓
Load Order Details

The screen should not receive infrastructure objects.

---

## 81. Feature Refresh

Where local reactive streams are used, explicit manual refresh should not be required for normal data consistency.

If a mutation succeeds:

Local database changes
↓
Repository stream
↓
Cubit
↓
UI

This provides immediate local consistency.

Manual refresh may still exist where it improves UX, but it should not be required to make local writes visible.

---

## 82. Feature Loading

Loading indicators should represent actual asynchronous work.

Avoid:

- Artificial delays
- Fake loading
- Unnecessary full-screen blocking
- Loading state for synchronous local transformations

Prefer localized loading where only part of a screen is being updated.

The exact UX follows the approved design system.

---

## 83. Feature Empty States

Every list-based feature should define a meaningful empty state.

Examples:

No Customers

No Orders

No Expenses

No Items Requiring Storage

No Services

No Storage Locations

The empty state must not be confused with an error.

---

## 84. Feature Error States

Error states should distinguish:

- Validation/business failure
- Data/persistence failure
- Unexpected technical failure

The user-facing message should be actionable and localized.

Raw exception messages must not be displayed directly.

---

## 85. Feature Success Feedback

After successful operations, the feature may provide appropriate feedback such as:

- Updated UI
- Success message
- Confirmation
- Navigation to the resulting entity
- Returning to a previous screen

Success feedback should remain consistent with the approved UI/UX.

Do not add intrusive notifications for every local read or state update.

---

## 86. Feature Navigation

Features request navigation through the centralized routing system.

A Cubit should not directly manipulate Navigator state unless the approved routing architecture explicitly allows it.

Business logic should not contain route names.

Example:

Completing an Order

should produce a successful operation.

The Presentation layer decides whether to:

- Show confirmation
- Navigate
- Refresh
- Close a screen

---

## 87. Feature Deep Links and IDs

When navigation requires an entity:

Prefer passing stable entity identifiers.

Example:

/orders/:orderId

The receiving screen loads the current local entity through its repository.

Do not pass database rows or infrastructure objects through navigation.

---

## 88. Feature Dependencies

Feature dependencies should be injected through the approved DI configuration.

Example:

OrdersCubit
↓
OrderRepository

The Cubit receives the dependency.

It should not construct:

OrderRepositoryImpl

inside itself.

---

## 89. Constructor Injection

Constructor injection is preferred.

Example conceptually:

OrdersCubit(orderRepository)

This keeps the Cubit:

- Testable
- Explicit
- Independent from concrete implementations

GetIt should assemble the production dependency graph.

It should not be used deep inside business classes when constructor injection is practical.

---

## 90. Feature DI Lifecycle

Repositories and long-lived infrastructure should use the approved appropriate lifecycle.

Cubits are normally factories.

Therefore:

OrdersCubit
→ Factory

CustomersCubit
→ Factory

StorageCubit
→ Factory

This prevents unrelated screens from sharing accidental Cubit state.

---

## 91. Feature Testing

Every feature must have tests appropriate to its responsibilities.

Testing should include:

### Cubit Tests

- Initial state
- Loading
- Success
- Empty
- Failure
- User actions
- Repository failures
- Business validation failures

### Domain Tests

- Business invariants
- Calculations
- State transitions

### Repository/Data Tests

- Local persistence
- Queries
- Transactions
- Mapping

### Integration Tests

For critical end-to-end workflows where appropriate.

---

## 92. Order Feature Critical Tests

At minimum:

- Create valid Order.
- Reject Order without Customer.
- Reject Order without OrderItems.
- Reject invalid Service compatibility.
- Reject invalid ItemDefinition compatibility.
- Create physical OrderItems correctly from quantity entry.
- Calculate pricing correctly.
- Require CarpetItemData for Carpets.
- Reject inappropriate CarpetItemData for non-Carpets.
- Mark Order Ready only when all required items are stored.
- Reject completion when not Ready.
- Reject completion when unpaid.
- Reject completion without handover confirmation.
- Complete Order successfully when all prerequisites are met.
- Deactivate storage on completion.
- Cancel Order successfully.
- Preserve historical data on cancellation.
- Do not reactivate storage after Completed → Processing.

---

## 93. Customer Feature Critical Tests

At minimum:

- Create Customer.
- Validate required fields.
- Enforce phone uniqueness where applicable.
- Edit Customer.
- Preserve Order history.
- Prevent destructive deletion when historical Orders exist.

---

## 94. Storage Feature Critical Tests

At minimum:

- List items requiring storage.
- Store Item.
- Show compatible locations.
- Reject incompatible location.
- Move Item.
- Deactivate old StorageRecord.
- Create new active StorageRecord.
- Never create two active StorageRecords for one OrderItem.
- Recalculate Order readiness after storage changes.
- Do not reactivate storage automatically after status correction.

---

## 95. Payment Feature Critical Tests

At minimum:

- Positive payment succeeds.
- Zero payment fails.
- Negative payment fails.
- Overpayment fails.
- Multiple payments work.
- Remaining amount is calculated correctly.
- Fully paid does not automatically complete the Order.

---

## 96. Expense Feature Critical Tests

At minimum:

- Create valid Expense.
- Reject zero amount.
- Reject negative amount.
- Require Category.
- Require customName for Other.
- Do not require customName for normal categories.
- Filter by date.
- Filter by category.
- Preserve historical category information.

---

## 97. Master Data Feature Tests

At minimum:

- Create master data.
- Edit master data.
- Activate/deactivate master data.
- Prevent inactive master data from being selected for new transactions.
- Preserve historical transaction values after master-data changes.
- Preserve historical references after deactivation.

---

## 98. Feature and Offline Testing

Critical V1 features must work without network access.

Tests should verify:

- Customer creation offline.
- Order creation offline.
- Payment recording offline.
- Storage operations offline.
- Expense creation offline.
- Master-data operations supported by the local implementation.

The feature must not wait for a remote API that is intentionally deferred.

---

## 99. Feature and Synchronization

Synchronization is not part of the current local implementation.

When synchronization is implemented later:

Feature
↓
Cubit
↓
Repository
↓
Local + Remote Coordination

The Feature layer should not need to be redesigned around network calls.

This is one reason the Repository boundary must remain stable.

---

## 100. Feature Performance

Feature implementation should prefer database-side operations for large or filtered datasets.

Do not:

- Load all Expenses to calculate a simple date filter in memory.
- Load all Orders to calculate a simple count unnecessarily.
- Load all StorageRecords when a direct current-state query exists.

Use repository methods that map to appropriate Data Layer queries.

The exact query implementation remains in Data.

---

## 101. Feature Consistency

The same business concept must behave consistently regardless of entry point.

For example:

A Payment created from Order Details

and:

A Payment created through another approved Payment entry point

must use the same business validation.

Similarly:

Storing an item from Storage

and:

Adding an item to storage from another approved workflow

must preserve the same Storage rules.

Do not duplicate business rules separately in multiple screens.

---

## 102. Avoid Duplicated Business Logic

Do not implement the same business rule independently in:

- Order screen
- Storage screen
- Payment screen
- Reports screen

If a rule is business-critical, it belongs in the appropriate Domain/Application/repository operation according to responsibility.

The UI may provide convenience validation, but must not become the only source of truth.

---

## 103. Feature Shared Widgets

A widget should remain inside its feature when it is feature-specific.

Move it to:

core/widgets/

only when:

- Multiple features use it.
- Its responsibility is genuinely generic.
- Reuse is real rather than hypothetical.

Do not create generic widgets prematurely.

---

## 104. Feature Shared Utilities

The same rule applies to utilities.

Before creating:

CommonOrderHelper

CommonExpenseHelper

CommonUtils

ask whether the behavior actually belongs in:

- Domain
- Core
- Feature

Avoid a generic `Utils` class containing unrelated behavior.

---

## 105. Feature Naming

Use:

- `snake_case` for files.
- `PascalCase` for classes.
- `camelCase` for variables and methods.

Examples:

order_details_screen.dart

order_item_card.dart

orders_cubit.dart

order_repository.dart

OrderDetailsScreen

OrderItemCard

OrdersCubit

createOrder()

orderId

---

## 106. Feature File Organization

A simple Orders feature may look like:

features/
└── orders/
    └── presentation/
        ├── screens/
        │   ├── orders_screen.dart
        │   ├── order_creation_screen.dart
        │   └── order_details_screen.dart
        ├── widgets/
        │   ├── order_card.dart
        │   ├── order_item_card.dart
        │   └── order_form.dart
        └── cubit/
            └── orders_cubit.dart

The exact screen/widget breakdown must follow the approved UI implementation.

Do not create unnecessary files.

---

## 107. Feature Completion Criteria

A feature is not considered implemented merely because its screen exists.

A complete feature requires:

- UI
- Cubit
- Repository contract usage
- Data implementation
- Local persistence
- Validation
- Error handling
- Appropriate loading/empty/error states
- Tests
- DI registration
- Routing where applicable
- Offline-first behavior
- Documentation alignment

---

## 108. Feature Implementation Order

For a normal feature, implementation should proceed in this order:

1. Confirm requirements.
2. Confirm Domain entities/rules.
3. Confirm repository contract.
4. Confirm required database tables/queries.
5. Implement/verify Data Layer.
6. Implement Repository.
7. Register dependencies.
8. Implement Cubit.
9. Implement screens/widgets.
10. Connect navigation.
11. Add validation.
12. Add error states.
13. Add tests.
14. Run validation checklist.

Do not start by building a large UI and inventing the backend/domain behavior afterward.

---

## 109. Vertical Slice Rule

When practical, implement a feature as a complete vertical slice.

Example:

Create Expense

should be implemented through:

Expense Form
↓
ExpensesCubit
↓
ExpenseRepository
↓
ExpenseRepositoryImpl
↓
ExpenseLocalDataSource
↓
Drift
↓
Database

rather than building every screen first and postponing persistence.

This allows each implemented slice to be verified end-to-end.

---

## 110. V1 Implementation Priority

The recommended implementation priority is:

### Foundation

- Core infrastructure
- Database
- Data Layer
- DI
- Domain
- Error handling

### Operational Core

- Customers
- Orders
- Payments
- Storage

### Master Data

- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Storage Locations
- Expense Categories
- Business Settings

### Financial

- Expenses
- Reports

### Dashboard

- Dashboard integration and derived metrics

The exact execution order may follow the approved implementation plan.

---

## 111. Feature Dependencies

The main logical relationships are:

Customers
↓
Orders
↓
OrderItems
↓
Storage

Orders
↓
Payments

Services
↓
OrderItems

ItemTypes
↓
OrderItems

ItemDefinitions
↓
OrderItems

ExpenseCategories
↓
Expenses

Orders + Payments + Expenses
↓
Reports

Master Data
↓
Order Creation

These relationships do not mean the features should directly depend on each other's Cubits.

They represent business/data dependencies.

---

## 112. Feature Independence

Each feature should be independently understandable.

For example:

Expenses

should not require understanding the internal implementation of:

Orders

to create an Expense.

Storage

should not require accessing:

OrdersCubit

to store an OrderItem.

Reports

should not depend on:

ExpensesCubit

or:

OrdersCubit

for its data.

Repository contracts provide the appropriate boundary.

---

## 113. Feature and Historical Data

Feature updates must distinguish between:

Current editable data

and:

Historical transaction data.

Master-data screens may edit current master data.

Transactional screens must preserve historical values.

The feature must never silently recalculate old transaction data because current master data changed.

---

## 114. Feature and Read-Only States

The UI must respect business lifecycle restrictions.

Examples:

Cancelled Order
→ Read-only

Completed Order
→ Operationally read-only

Inactive Service
→ Not selectable for new Order

Inactive ItemDefinition
→ Not selectable for new Order

Inactive StorageLocation
→ Not selectable for new storage operation where prohibited

Inactive ExpenseCategory
→ Not selectable for new Expense where prohibited

These restrictions must also be enforced outside Presentation.

---

## 115. Feature and Business Status

Do not confuse:

Entity status

with:

UI state.

Examples:

OrderStatus:
- Processing
- Ready
- Completed
- Cancelled

Cubit state:
- Initial
- Loading
- Loaded
- Failure

Both may exist simultaneously.

They represent different concerns.

---

## 116. Feature and Localization

The application UI is Arabic and RTL.

Feature code should use localized user-facing strings.

Domain identifiers remain language-independent.

Examples:

Domain:

PaymentMethod.cash

UI:

نقدي

Domain:

OrderStatus.processing

UI:

قيد التنفيذ

Do not store Arabic labels as Domain identifiers.

---

## 117. Feature and RTL

All feature screens must follow the approved RTL design system.

Feature implementation must not introduce isolated LTR assumptions.

Examples requiring attention:

- Text alignment
- Form field layout
- Icons with directional meaning
- Navigation affordances
- Dates
- Currency formatting
- Tables/lists

The exact visual rules belong to the Design System and UI documentation.

---

## 118. Feature and Money Display

The Domain uses exact monetary values.

Presentation formats those values for users.

The UI should display:

- EGP
- Arabic-friendly formatting
- Appropriate decimal representation where required

The UI must not perform financial calculations using display strings.

For example:

"١٬٠٠٠ جنيه"

is a display value.

It must not become the underlying financial representation.

---

## 119. Feature and Date Display

Expected Pickup Date and Expense Date are date-only Domain values.

The UI may display localized Arabic dates.

Example:

25 أغسطس 2026

The UI must not accidentally introduce a time component into the business date.

---

## 120. Feature and Search

Search/filter behavior belongs to the feature presentation and repository query boundaries.

The UI may collect:

- Search text
- Date range
- Category
- Status
- Other approved filters

The repository provides the appropriate data operation.

Do not load unnecessarily large datasets into memory simply because filtering in the UI is easier.

---

## 121. Feature and Pagination

V1 pagination should only be introduced where the approved product requirements or actual dataset size justify it.

Do not add complex pagination frameworks automatically.

For local SQLite data, database-side filtering and indexing should be preferred.

If pagination becomes necessary later, it should be added without bypassing the Repository boundary.

---

## 122. Feature and Reactive Data

Where supported, repository watchers should be preferred for screens that need to remain synchronized with local changes.

Example:

Expenses List
↓
watchExpenses()
↓
ExpensesCubit
↓
UI

This allows:

Expense added
↓
Database changes
↓
Watcher emits
↓
Cubit updates
↓
UI refreshes

No manual refresh should be required for normal local state propagation.

---

## 123. Feature and Concurrency

User actions that trigger mutations should avoid accidental duplicate submissions.

Examples:

- Double tapping Save.
- Double recording the same Payment.
- Double storing the same OrderItem.
- Double completing an Order.

Presentation may disable the action while an operation is in progress.

Business/data layers must still protect critical invariants.

---

## 124. Feature and Idempotency

Operations that can accidentally be repeated must be designed carefully.

For example:

Store Item

must not create multiple active StorageRecords.

Complete Order

must not create duplicate completion side effects.

Payment submission

must not accidentally record the same user action twice due to UI duplication.

The exact persistence protection belongs to Data/Database where appropriate.

---

## 125. Feature and Database Constraints

Features should not rely on database constraints as their primary UX mechanism.

Example:

If a duplicate value is rejected by SQLite, the feature should still provide appropriate validation and error handling.

The database protects structural integrity.

The feature provides user-friendly interaction.

Both are required.

---

## 126. Feature and Transactions

A Feature should request a business operation through the Repository.

The Repository/Data Layer decides whether a database transaction is required.

The UI should not manually coordinate:

begin transaction

commit

rollback

This is an infrastructure responsibility.

---

## 127. Feature and Future Backend

Networking is deferred.

Current Feature implementation must remain local-first.

When backend support is introduced:

- Feature Cubits should remain largely unchanged.
- Repository contracts should remain stable where possible.
- Repository implementations coordinate local and remote sources.
- Remote DTOs remain in Data.
- Dio/Retrofit remain outside Presentation.

This is a major architectural boundary.

---

## 128. Feature and Future Sync

Future Sync status must not become business status.

Do not add:

- PendingSync
- Syncing
- SyncFailed

to OrderStatus.

Synchronization state belongs to the synchronization infrastructure.

The user-facing business state remains:

- Processing
- Ready
- Completed
- Cancelled

---

## 129. Feature Change Management

Before changing a feature:

1. Identify the requirement.
2. Check Domain impact.
3. Check Database impact.
4. Check Repository contract impact.
5. Check Data Layer impact.
6. Check Cubit/state impact.
7. Check UI impact.
8. Check navigation impact.
9. Check tests.
10. Update documentation if architecture changes.

Do not silently change architecture to solve a local implementation problem.

---

## 130. AI Coding Agent Rules

Before implementing any feature, the coding agent must read the relevant project documentation.

At minimum:

- Product Scope
- Requirements
- Business Rules
- Domain Model
- Architecture
- Database documentation
- Data Layer documentation
- Domain Implementation
- State Management
- Error Handling
- Offline-First
- Routing and Navigation
- Coding Standards
- Implementation Rules

The agent must implement only the approved scope.

---

## 131. AI Must Not Invent Features

The coding agent must not create:

- Delivery management
- Driver management
- Vehicle management
- Employee management
- Roles
- Permissions
- Branches
- Refunds
- Loyalty
- Barcode scanning
- Advanced laundry stages
- AI Assistant
- Cloud synchronization

unless explicitly added to approved requirements.

---

## 132. AI Must Not Bypass Layers

The coding agent must never implement:

Widget
→
Database

Cubit
→
DAO

Cubit
→
Drift

Cubit
→
Dio

Feature
→
SQL

Domain
→
Flutter

Repository
→
Widget

These are architectural violations.

---

## 133. AI Must Not Introduce Unapproved Layers

Do not automatically introduce:

- Use Cases
- Application layer
- Mapper layer
- Generic CRUD framework
- Generic managers
- Generic service classes
- Feature-level repository implementations
- State-management framework other than approved Cubit approach

without an explicit architecture decision.

---

## 134. AI Must Not Duplicate Business Logic

Do not copy the same rule into multiple screens.

Examples:

Payment validation

Order readiness

Completion prerequisites

Service compatibility

ItemDefinition compatibility

Expense Other validation

These must have one authoritative business implementation with presentation-level validation only as a UX enhancement.

---

## 135. AI Must Preserve Historical Data

The agent must never implement master-data updates that silently modify historical transactions.

Examples:

Service price changes

must not update old OrderItem prices.

Expense Category rename

must not rewrite historical category snapshots.

CarpetSize changes

must not modify historical carpet dimensions.

---

## 136. AI Must Preserve Physical Item Identity

Quantity-based UI input must not collapse physical OrderItems when physical identity is required.

Storage depends on individual OrderItems.

Therefore:

Quantity = N

must produce the required number of physical item records.

---

## 137. AI Must Preserve Order Lifecycle

The agent must use exactly the approved V1 Order statuses:

- Processing
- Ready
- Completed
- Cancelled

It must not invent additional operational statuses.

Completion requires:

Ready
+
Remaining Amount = 0
+
Explicit Handover Confirmation

---

## 138. AI Must Preserve Storage Integrity

The agent must not:

- Create multiple active StorageRecords for one OrderItem.
- Mark an Order Ready when required items remain unstored.
- Reactivate old StorageRecords after Completed → Processing.
- Keep active storage after Completion.
- Keep active storage after Cancellation.

---

## 139. AI Must Preserve Payment Integrity

The agent must not:

- Allow zero Payments.
- Allow negative Payments.
- Allow Payment > Remaining Amount.
- Replace Payment history with a single balance.
- Automatically complete an Order because it is fully paid.

---

## 140. AI Must Preserve Expense Integrity

The agent must not:

- Treat Expense as Payment.
- Associate Expense with an Order unless explicitly required.
- Allow non-positive Expense amounts.
- Allow missing category.
- Allow missing customName when Category = Other.
- Destroy historical category meaning.

---

## 141. AI Must Preserve Conditional Item Data

The agent must implement:

Carpet
→ CarpetItemData required

Non-Carpet
→ CarpetItemData not required

Pricing inputs must also depend on PricingType.

Do not make irrelevant fields universally mandatory.

---

## 142. AI Must Preserve Offline-First

The current implementation phase is local-first.

The coding agent must not introduce network dependencies into normal V1 feature workflows.

Do not add:

- API calls
- Dio usage
- Retrofit usage
- Connectivity requirements
- Sync workers

to the current feature implementation unless explicitly requested as part of the deferred phase.

---

## 143. AI Must Use Existing Dependencies

Before adding a package:

1. Check whether the project already contains an equivalent capability.
2. Check the approved technical decisions.
3. Check coding standards.
4. Avoid introducing another package for a problem already solved.

Do not add a package simply because it is popular.

---

## 144. AI Must Avoid Premature Abstraction

Do not create abstractions simply because:

"we may need this later."

Future requirements should not create V1 complexity.

Prefer:

- Explicit classes
- Small responsibilities
- Constructor injection
- Repository contracts
- Simple Cubits
- Simple feature structures

---

## 145. AI Must Keep Features Understandable

A developer should be able to understand a feature without navigating through unnecessary layers.

Prefer:

Screen
↓
Cubit
↓
Repository
↓
Data

over:

Screen
↓
Controller
↓
Coordinator
↓
UseCase
↓
Manager
↓
Service
↓
Repository
↓
Adapter
↓
Data

unless actual complexity requires those abstractions.

---

## 146. Feature Definition of Done

A V1 feature is complete when:

- Approved requirements are implemented.
- Domain rules are respected.
- Repository contracts are used correctly.
- Data persistence works.
- Local-first behavior works.
- Cubit state is implemented.
- Loading state works.
- Empty state works.
- Error state works.
- Validation works.
- Navigation works where applicable.
- DI is configured.
- Tests exist for critical behavior.
- No architecture boundary is bypassed.
- No unsupported feature has been introduced.
- Historical data remains safe.
- Business state remains separate from UI state.
- The feature works without network access.
- Documentation and implementation remain aligned.

---

## 147. Final Feature Architecture

The authoritative V1 feature architecture is:

User
↓
Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source / DAO
↓
Drift / SQLite

For future networking:

User
↓
Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
├── Local Data Source
└── Remote Data Source
    ↓
    Dio / Retrofit

The Feature layer should not need to know whether data comes from local storage or a future backend.

---

## 148. Final Principles

The V1 feature implementation must follow these principles:

1. Features are organized around business capabilities.
2. Presentation communicates through Cubits.
3. Cubits communicate through Repository contracts.
4. Data access remains outside Presentation.
5. Domain rules remain outside Widgets.
6. V1 uses Cubit rather than requiring Bloc.
7. Local-first behavior is the default.
8. Networking and synchronization remain deferred.
9. Physical OrderItems retain independent identity.
10. Historical transaction values remain stable.
11. Order lifecycle rules are enforced consistently.
12. Storage state remains separate from Order status.
13. Payment history remains separate from Order balance.
14. Expenses remain independent from Orders and Payments.
15. Master data is separated from historical transaction data.
16. Feature-to-feature Cubit coupling is avoided.
17. Generic abstractions are avoided unless justified.
18. No mandatory Use Case or Application layer exists.
19. Tests must protect critical business workflows.
20. Implementation must remain aligned with the approved documentation.