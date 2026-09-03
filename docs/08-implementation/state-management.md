# State Management

## 1. Purpose

This document defines the mandatory state-management architecture for the V1 Laundry Management System.

The goal is to provide:

- Predictable feature state.
- Clear separation between Presentation, Domain, and Data.
- Consistent loading, success, empty, and failure handling.
- Reactive updates for the Offline-First local database.
- A simple and maintainable state-management approach.
- Strict boundaries for Cubit responsibilities.

The project will use **Cubit only** for application state management.

**BLoC is not part of the V1 architecture.**

---

## 2. State Management Decision

The approved V1 state-management solution is:

**flutter_bloc + Cubit**

The project will use:

- Cubit for feature/application state.
- Repository for data access.
- Domain layer for business logic.
- Local database for persistent V1 data.
- GetIt for dependency injection.

The architecture does not use BLoC event classes.

---

## 3. Cubit-Only Rule

All feature state management must use Cubit.

Do not create:

- `Bloc`
- `Bloc<Event, State>`
- Event classes for BLoC.
- `on<Event>()`.
- BLoC-specific event pipelines.

The preferred pattern is:

UI
↓
Cubit Method
↓
Repository
↓
Domain / Business Logic where required
↓
Data Layer
↓
Cubit State
↓
UI

---

## 4. Why Cubit

Cubit is selected because the V1 application primarily needs direct command-style state transitions rather than a large event-driven architecture.

Typical operations are naturally represented as methods:

- `loadOrders()`
- `createOrder()`
- `updateOrder()`
- `recordPayment()`
- `storeItem()`
- `moveItem()`
- `completeOrder()`
- `cancelOrder()`
- `createExpense()`

Cubit provides these operations without introducing unnecessary event classes.

---

## 5. Core Principle

Cubit owns **Presentation State**, not business state.

Cubit coordinates:

- User actions.
- Loading states.
- Repository calls.
- Success/failure results.
- UI-facing state.
- Reactive updates.

Cubit must not own:

- Database persistence.
- Business rules that belong to Domain.
- Route definitions.
- API implementation.
- SQL queries.
- DAO implementation.

---

## 6. Standard Architecture

The required feature flow is:

Screen
↓
Cubit
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source
↓
Drift / SQLite

For business operations requiring Domain logic:

Screen
↓
Cubit
↓
Repository / Domain Use Case
↓
Domain Rules
↓
Repository
↓
Local Data Source
↓
Database

The exact use-case structure must follow the approved project architecture.

---

## 7. Cubit Responsibilities

A Cubit is responsible for:

- Receiving user-driven commands.
- Calling the appropriate Repository abstraction.
- Managing UI state.
- Exposing loading states.
- Exposing success states.
- Exposing empty states.
- Exposing failure states.
- Reacting to repository streams where required.
- Triggering UI-visible state transitions.
- Coordinating Presentation behavior.

---

## 8. Cubit Must Not Access Database Directly

Cubit must never directly access:

- Drift database.
- DAO.
- SQLite.
- SQL queries.
- Tables.
- Database transactions.

Incorrect:

Cubit
↓
AppDatabase

Correct:

Cubit
↓
Repository
↓
Data Source
↓
AppDatabase

---

## 9. Cubit Must Not Access DAO Directly

Do not inject DAO classes into Cubits.

Incorrect:

class OrdersCubit {
  final OrdersDao dao;
}

Correct:

class OrdersCubit {
  final OrdersRepository repository;
}

The Repository remains the Presentation/Data boundary.

---

## 10. Cubit Must Not Contain SQL

SQL or Drift query expressions must never be written inside Cubits.

Do not put database filtering, joins, ordering, or persistence operations in Cubit methods.

Database-specific logic belongs in the Data Layer.

---

## 11. Cubit Must Not Contain Repository Implementation

Cubit depends on the Repository contract.

It must not depend on a concrete local database implementation when the architecture provides an abstraction.

Preferred:

Cubit
↓
OrdersRepository

not:

Cubit
↓
OrdersRepositoryImpl

unless the DI/architecture explicitly requires the concrete type.

---

## 12. Cubit and Dependency Injection

Cubits must receive their dependencies through the approved DI system.

The project uses **GetIt** for dependency injection.

Conceptually:

GetIt
↓
Repository
↓
Cubit

The exact construction pattern must follow the DI implementation.

Cubits must not manually construct:

- Repositories.
- Database instances.
- Data sources.
- API clients.

---

## 13. No Manual Dependency Construction

Avoid:

final repository = OrdersRepositoryImpl(
  database: AppDatabase(),
);

inside a Cubit.

Dependencies must come from the approved DI configuration.

---

## 14. Cubit Lifecycle

Cubits must have a clear lifecycle.

The application should create a Cubit when its associated screen/feature needs it and dispose it according to the established Flutter widget lifecycle and DI strategy.

Do not create unnecessary global Cubits.

---

## 15. Global Cubits

A Cubit should only be global when its state is genuinely application-wide.

Do not make every feature Cubit a global singleton.

Examples of potentially global state may include:

- Application-wide settings.
- Session state if authentication is introduced.
- Global UI configuration.

Feature-specific state should normally remain feature-scoped.

---

## 16. Feature-Scoped Cubits

Prefer feature-scoped Cubits.

Examples:

- `CustomersCubit`
- `OrdersCubit`
- `StorageCubit`
- `ExpensesCubit`
- `DashboardCubit`

The exact Cubit names must follow the project's naming conventions.

---

## 17. Screen-Specific Cubits

A dedicated Cubit may be used for a screen when that screen has meaningful independent state.

Examples:

- `OrderDetailsCubit`
- `CreateOrderCubit`
- `CustomerDetailsCubit`

Do not create a new Cubit for every tiny widget.

---

## 18. Cubit Granularity

Cubit boundaries should follow meaningful state boundaries.

Good:

`OrdersCubit`

manages:

- Order list.
- Order filters.
- Order loading.
- Order list failures.

Good:

`OrderDetailsCubit`

manages:

- Selected Order.
- Order details loading.
- Payment operation.
- Completion/cancellation operation where appropriate.

Avoid one giant application Cubit managing:

- Customers.
- Orders.
- Storage.
- Expenses.
- Dashboard.
- Master Data.

---

## 19. Avoid God Cubits

Do not create:

`AppCubit`

that manages all application business state.

A centralized application Cubit may exist only for truly global UI/application concerns.

Feature state must remain feature-scoped.

---

## 20. State Immutability

Cubit states should be immutable.

A state should represent a snapshot of Presentation state.

Avoid mutating state objects after emission.

Prefer creating a new state when values change.

---

## 21. Equatable

If the project uses `Equatable` for state comparison, all relevant state fields must participate in equality.

The implementation should remain consistent across Cubits.

Do not mix multiple state-comparison strategies unnecessarily.

---

## 22. State Structure

States should clearly communicate the current UI condition.

A typical feature state may contain:

- Status.
- Data.
- Error information.
- Operation-specific information.
- Filters where appropriate.

Example conceptual structure:

OrdersState
├── status
├── orders
├── filters
└── failure

The exact implementation may use a sealed hierarchy or a status-based immutable state according to the approved coding conventions.

---

## 23. Loading State

A loading state means the requested operation is currently being performed.

Examples:

- Loading Orders.
- Loading Customer.
- Creating Order.
- Recording Payment.
- Moving Storage Item.

Loading state must not be confused with an empty state.

---

## 24. Empty State

Empty state means the operation succeeded but there is no data to display.

Example:

Orders loaded successfully
+
Orders count = 0

This is:

**Empty**

not:

**Failure**

and not:

**Loading**

---

## 25. Failure State

Failure means the requested operation could not be completed.

Examples:

- Repository failure.
- Database failure.
- Validation failure.
- Entity not found.
- Transaction failure.

The state should contain an appropriate failure representation.

Raw exceptions should not be exposed directly to the UI.

---

## 26. Success State

A successful operation should produce the appropriate UI-visible state.

Examples:

Create Customer
→ Success
→ Customer available locally.

Create Order
→ Success
→ Order available locally.

Record Payment
→ Success
→ Updated balance available locally.

---

## 27. Initial State

Every Cubit must have a predictable initial state.

The initial state must not falsely imply that data has already been loaded.

For example:

Initial
≠
Loaded empty

unless the feature explicitly defines that behavior.

---

## 28. State Transitions

State transitions should be intentional.

Typical flow:

Initial
↓
Loading
↓
Success

or:

Initial
↓
Loading
↓
Failure

For a mutation:

Idle
↓
Submitting
↓
Success

or:

Idle
↓
Submitting
↓
Failure

The exact state model may differ where multiple concurrent operations are required.

---

## 29. Avoid Unnecessary State Complexity

Do not create dozens of states for simple CRUD screens.

The state model should represent actual UI needs.

Avoid:

LoadingCustomers

LoadingCustomersAfterRefresh

LoadingCustomersAfterSearch

LoadingCustomersAfterFilter

unless the UI genuinely needs to distinguish these states.

---

## 30. State Should Reflect UI Needs

State exists to render the correct UI.

If a distinction does not affect Presentation behavior, it should not necessarily become a separate state.

Keep state understandable.

---

## 31. Multiple Operations

A screen may need to perform more than one operation.

Example:

Order Details may:

- Load Order.
- Record Payment.
- Complete Order.
- Cancel Order.

The state model must prevent unrelated operations from unnecessarily destroying useful state.

For example:

Recording Payment should not make the existing Order details disappear merely because a payment request is in progress.

---

## 32. Preserve Existing Data During Mutations

Where appropriate, mutation states should preserve already-loaded data.

Example:

Order Details loaded
↓
Record Payment
↓
Submitting payment

The existing Order information should remain available while the operation executes unless the UI specifically requires otherwise.

---

## 33. Operation-Specific Status

When multiple independent operations exist on one screen, use operation-specific state information when necessary.

Conceptually:

OrderDetailsState
├── order
├── orderStatus
├── paymentStatus
├── completionStatus
└── cancellationStatus

The exact model should remain as simple as possible while supporting the UI.

---

## 34. Cubit Method Naming

Cubit methods should describe the user/business action clearly.

Examples:

- `loadOrders()`
- `watchOrders()`
- `createOrder()`
- `updateOrder()`
- `recordPayment()`
- `completeOrder()`
- `cancelOrder()`
- `storeItem()`
- `moveItem()`

Avoid vague methods such as:

- `doAction()`
- `process()`
- `handleEverything()`

---

## 35. Cubit Method Parameters

Cubit methods should receive only the data needed to perform the operation.

Do not pass:

- BuildContext.
- Widgets.
- DAO objects.
- Database objects.
- Router objects.

Example:

`recordPayment(orderId, amount, paymentMethod)`

is preferable to:

`recordPayment(context, order, repository, router)`

---

## 36. BuildContext Prohibition

Cubit must not depend on `BuildContext`.

Do not inject or store BuildContext inside Cubit.

This keeps Cubit independent from the widget tree.

---

## 37. Navigation Separation

Cubit must not own application navigation.

Do not place:

- Route strings.
- AppRoutes.
- GoRouter navigation calls.
- Navigator calls.

inside Cubits unless the approved architecture explicitly defines a very narrow exception.

The default rule is:

Cubit
→
State / Result

Screen
→
Navigation

---

## 38. Navigation Result Pattern

When an operation should cause navigation, the Cubit should expose the operation result.

Example:

Create Order
↓
Cubit
↓
OrderCreated(orderId)
↓
Screen
↓
AppRouter
↓
Order Details

The Cubit does not need to know the route.

---

## 39. Error Handling Boundary

Repositories should map lower-level technical failures into appropriate application/domain failures.

Cubit should consume those failures.

Cubit should not parse:

- SQLite error strings.
- HTTP status codes.
- Dio exceptions.
- Drift exceptions.

---

## 40. No Raw Exception Handling in UI

Widgets should not be responsible for catching database/API exceptions.

The expected flow is:

Data Layer
↓
Failure mapping
↓
Repository
↓
Cubit
↓
Presentation State
↓
UI

---

## 41. Failure Presentation

The UI should receive a meaningful failure representation.

Examples:

- Validation failure.
- Not found.
- Database failure.
- Unexpected failure.

The UI can then display localized user-facing feedback.

---

## 42. Domain Errors

Business-rule failures should remain meaningful at the Domain/Repository boundary.

Example:

Payment exceeds remaining amount.

Cubit should receive an appropriate failure rather than implementing:

if (amount > remaining) ...

unless the approved architecture explicitly places that specific presentation validation in the Cubit.

---

## 43. Presentation Validation

Simple input validation may happen in Presentation.

Examples:

- Required field.
- Empty text.
- Basic formatting.
- Input length.

Business invariants must remain in the appropriate Domain/Business layer.

---

## 44. Form State

Forms may use Cubit to manage:

- Form submission state.
- Validation results.
- Submission progress.
- Submission failure.
- Submission success.

Do not force every individual text field into Cubit state if Flutter's local form mechanisms are sufficient.

---

## 45. Local UI State

Not every piece of state belongs in Cubit.

Simple ephemeral UI state may remain local to the widget.

Examples:

- Whether a dropdown is open.
- Temporary animation state.
- Focus state.
- Tab selection when it has no business significance.

Cubit should manage meaningful feature/application state.

---

## 46. Business State vs UI State

Business state:

- Order status.
- Payment balance.
- Storage location.
- Customer data.

UI state:

- Loading indicator.
- Selected tab.
- Search field text where appropriate.
- Dialog visibility.

Do not mix the two unnecessarily.

---

## 47. Search State

Search may be handled by Cubit when it affects feature data.

Example:

OrdersCubit
├── searchQuery
├── filters
└── orders

The repository should perform efficient local queries where appropriate.

Do not load the entire database and perform large searches in widgets.

---

## 48. Filter State

Feature filters may be represented in Cubit state.

Examples:

- Order status.
- Pickup date.
- Expense category.
- Expense date range.
- Storage location.

Filters should remain Presentation state unless they represent persisted business configuration.

---

## 49. Sorting State

Sorting preferences may be represented in Cubit state when required by the UI.

The actual data query should remain in the Repository/Data Layer.

Cubit expresses the desired sort.

It does not implement SQL ordering.

---

## 50. Pagination

Pagination should only be implemented if required by the approved feature scope or actual dataset requirements.

Do not add pagination automatically.

If pagination is introduced, Cubit may manage:

- Current page.
- Loading more.
- Has more.
- Initial loading.

Repository/Data Layer performs the actual query.

---

## 51. Reactive Local Data

Because V1 is Offline-First, local repository streams/watchers should be used where continuous updates are required.

Conceptual flow:

Local Database
↓
Repository Stream
↓
Cubit
↓
UI

Cubit should subscribe to the repository abstraction, not directly to Drift/SQLite.

---

## 52. Cubit Stream Subscription

If a Cubit watches repository data, it must manage the subscription lifecycle safely.

When the Cubit is closed:

- Subscriptions must be cancelled/disposed.
- No updates should be emitted after disposal.

Use the established Dart/Flutter async patterns.

---

## 53. Watch vs Load

Use a one-time load when the UI only needs a snapshot.

Use a watch/stream when the UI should automatically react to local changes.

Example:

Customer Details
→ one-time load may be sufficient.

Orders List
→ watch may be appropriate if local mutations should update the list automatically.

The exact choice depends on feature behavior.

---

## 54. Reactive Updates

If a repository watcher is used:

Database change
↓
Repository emits
↓
Cubit updates
↓
UI rebuilds

Do not manually refresh the same data after every mutation if the reactive repository stream already provides the update.

---

## 55. Avoid Manual Refresh Loops

Do not implement:

createOrder()
↓
save
↓
delay
↓
loadOrders()
↓
loadOrders()
↓
loadOrders()

unless technically required.

Prefer a reliable reactive data source.

---

## 56. Cubit and Offline-First

Cubit behavior must not depend on Internet connectivity.

The Cubit should call the Repository.

The Repository decides how the approved data source operates.

V1:

Cubit
↓
Repository
↓
Local

Future:

Cubit
↓
Repository
↓
Local + Remote + Sync

The Cubit should not need to change merely because networking is introduced later.

---

## 57. No Connectivity Logic in Cubit

Do not write:

if (isOnline) {
  ...
} else {
  ...
}

inside feature Cubits for normal V1 operations.

Offline-first means local operations are normal operations.

---

## 58. No Sync Logic in Cubit

Do not add:

- `sync()`
- `syncNow()`
- `uploadPending()`
- `downloadUpdates()`
- `resolveConflict()`

to feature Cubits during V1.

Synchronization belongs to the future infrastructure layer.

---

## 59. No API Calls in Cubit

Cubit must never directly call:

- Dio.
- Retrofit clients.
- REST endpoints.
- HTTP clients.

V1 has no remote dependency.

Future remote access remains behind Repository/Data boundaries.

---

## 60. Cubit and Transactions

Cubit does not implement database transactions.

Cubit requests a business operation.

The Repository/Data Layer performs the transaction.

Example:

Cubit
↓
completeOrder()
↓
Repository
↓
Transaction
├── Update Order
└── Update Storage
↓
Result
↓
Cubit

---

## 61. Long-Running Operations

Long-running operations should expose a loading/submitting state.

Do not block the UI thread with synchronous heavy work.

The Repository/Data Layer should use appropriate asynchronous APIs.

---

## 62. Concurrent Actions

The UI should prevent invalid duplicate submissions where appropriate.

Example:

Record Payment
↓
Submitting

The Payment action should not be triggered repeatedly before the first operation completes if doing so could create duplicate transactions.

The exact protection may be implemented through:

- Cubit state.
- UI disabled state.
- Idempotent/business constraints.

---

## 63. Double Submission

Critical mutations must be protected from accidental double submission.

Examples:

- Payment.
- Order creation.
- Expense creation.
- Storage movement.

The Cubit should expose enough state for the UI to prevent repeated submission.

Database/business constraints remain the final protection for data integrity.

---

## 64. State Reset

State should only be reset when there is a meaningful reason.

Avoid resetting loaded data unnecessarily after every action.

Example:

After recording a Payment:

Do not automatically reset Order Details to Initial.

Instead, update the Order state appropriately.

---

## 65. Refresh

Manual refresh may be provided where the UI requires it.

A refresh should trigger the appropriate Repository operation or watcher behavior.

Do not duplicate the repository's data source inside Cubit.

---

## 66. Error Recovery

After a recoverable failure, the Cubit should allow the user to retry the operation.

Example:

Load Orders
↓
Failure
↓
Retry
↓
Loading
↓
Success

The retry should call the same approved Repository operation.

---

## 67. Failure Clearing

When a new successful operation occurs, obsolete failure state should be cleared where appropriate.

Do not keep displaying an old error after the operation has successfully recovered.

---

## 68. Loading and Existing Data

When refreshing existing data, the UI may continue displaying the existing data while showing a loading indicator rather than replacing everything with an empty screen.

This should be handled according to the approved UI design.

---

## 69. Cubit Testing

Each important Cubit should have tests for meaningful state transitions.

Tests should cover:

- Initial state.
- Successful load.
- Empty result.
- Load failure.
- Successful mutation.
- Mutation failure.
- Validation failure.
- Reactive updates where applicable.
- Retry behavior where applicable.

---

## 70. Cubit Test Isolation

Cubit tests should mock or fake the Repository boundary.

Do not require the real SQLite database for every Cubit unit test.

Repository/Data Layer tests should cover persistence separately.

---

## 71. Repository Mocking

Cubit tests should verify that the Cubit:

- Calls the expected Repository method.
- Emits the expected states.
- Handles success correctly.
- Handles failures correctly.

The exact mocking framework should follow project conventions.

---

## 72. State Transition Testing

Tests should verify meaningful transitions.

Example:

Initial
→ Loading
→ Loaded

or:

Initial
→ Loading
→ Failure

Mutation:

Idle
→ Submitting
→ Success

Do not over-test implementation details that are not observable behavior.

---

## 73. Reactive Cubit Testing

For Cubits consuming repository streams, tests should verify:

Repository emits data
↓
Cubit emits corresponding state
↓
UI can render updated data

Also verify proper cleanup after Cubit disposal.

---

## 74. Cubit Naming

Cubit names should clearly communicate the managed feature/state.

Examples:

- `DashboardCubit`
- `CustomersCubit`
- `CustomerDetailsCubit`
- `OrdersCubit`
- `OrderDetailsCubit`
- `StorageCubit`
- `ExpensesCubit`

Avoid generic names such as:

- `MainCubit`
- `DataCubit`
- `ScreenCubit`
- `ControllerCubit`

unless the responsibility is genuinely clear.

---

## 75. Cubit File Organization

Cubit files should follow the approved Project Structure.

A feature may conceptually contain:

feature/
├── presentation/
│   ├── cubit/
│   │   ├── orders_cubit.dart
│   │   └── orders_state.dart
│   └── screens/
│       └── orders_screen.dart

The exact folder structure must follow `project-structure.md`.

---

## 76. One State Model Per Cubit

A Cubit should have a clearly associated state model.

Avoid sharing one giant state class across unrelated Cubits.

Shared state models are acceptable only when they represent a genuinely shared concern.

---

## 77. State Serialization

State serialization is not required unless explicitly needed.

Do not add persistence of Cubit state when the underlying business data is already persisted locally.

---

## 78. Cubit State Is Disposable

Cubit state should be treated as disposable Presentation state.

If the screen is recreated:

Cubit
↓
Repository
↓
Local Database

should be able to reconstruct the required state.

The application must not depend on an old Cubit instance to preserve business data.

---

## 79. Avoid State Duplication

Do not duplicate the same persistent business data unnecessarily across multiple Cubits.

If two screens need the same entity, each may observe the repository independently.

The local database remains the shared persistent source.

---

## 80. Cross-Feature State

Features should communicate through approved application boundaries.

Avoid directly injecting:

OrdersCubit
into:

StorageCubit

just to access Order data.

Prefer:

StorageCubit
↓
StorageRepository

and:

OrdersCubit
↓
OrdersRepository

Shared business data belongs in the Repository/Domain/Data architecture.

---

## 81. Cubit-to-Cubit Communication

Direct Cubit-to-Cubit communication should be avoided by default.

If two Cubits need the same business information, use the appropriate Repository/domain abstraction or a genuinely global application state mechanism.

Do not create tightly coupled Cubits.

---

## 82. Dashboard State

Dashboard Cubit should derive Dashboard information through approved Repository queries/services.

Do not make DashboardCubit depend directly on:

- OrdersCubit.
- ExpensesCubit.
- StorageCubit.

The Dashboard should obtain its required data through its own approved data abstraction.

---

## 83. Reports State

Reports Cubit should obtain report data through approved Repository/domain abstractions.

Do not manually aggregate large datasets in the Cubit if the database/repository can perform the required aggregation.

---

## 84. Customer State

Customer Cubits should manage:

- Customer list state.
- Search/filter state.
- Customer detail state.
- Create/edit operation state.

They should not contain Customer persistence logic.

---

## 85. Order State

Order Cubits should manage:

- Order list state.
- Order detail state.
- Order creation state.
- Order mutation state.
- Payment operation state.
- Completion/cancellation operation state where appropriate.

They should not implement Order business rules that belong to Domain.

---

## 86. Storage State

Storage Cubit should manage:

- Storage list/state.
- Items requiring storage.
- Storage operation progress.
- Storage operation result/failure.

The Cubit should not directly manipulate StorageRecord database rows.

---

## 87. Expense State

Expense Cubit should manage:

- Expense list.
- Filters.
- Search if applicable.
- Create/edit state.
- Failure/success state.

Expense persistence remains in the Repository/Data Layer.

---

## 88. Master Data State

Master-data Cubits should follow the same principles.

Examples:

- ServicesCubit.
- ItemTypesCubit.
- ItemDefinitionsCubit.
- StorageLocationsCubit.
- ExpenseCategoriesCubit.

Each should manage only its approved feature state.

---

## 89. Cubit and Business Rules

Cubit may coordinate a business operation, but it must not become the primary owner of business invariants.

Example:

Cubit:

`completeOrder()`

is acceptable.

Cubit implementing every condition internally:

`if ready && paid && handoverConfirmed ...`

should only be done if that validation is explicitly Presentation-specific.

Core business invariants belong in the approved Domain/business layer.

---

## 90. Cubit and Domain

When Domain services/use cases are defined by the project architecture, Cubit should invoke them through the approved abstraction.

Conceptually:

Cubit
↓
Use Case / Domain Operation
↓
Repository
↓
Data Layer

The exact layering must follow the existing Architecture and Domain Implementation documents.

---

## 91. No Domain Imports From Flutter

Domain code must remain independent from Cubit and Flutter.

Do not import:

`flutter_bloc`

into Domain.

---

## 92. No Data Imports From Cubit

Data must not depend on:

`flutter_bloc`

or Presentation state.

Data returns data/failures.

Presentation consumes them.

---

## 93. No Router Imports From Cubit

Cubit should not import the application's router.

Navigation remains a Presentation concern.

---

## 94. Localization

Cubit must not hardcode user-facing Arabic strings.

Prefer:

Cubit
↓
Failure code/type/data
↓
Presentation localization
↓
Arabic message

This keeps state independent from UI language.

---

## 95. No UI Widgets Inside State

Do not put Flutter Widgets inside Cubit state.

State should contain:

- Data.
- Enums.
- Value objects where appropriate.
- Failure representations.
- Primitive UI-state values.

Not:

- Widget instances.
- BuildContext.
- Navigator.
- Router.

---

## 96. No Controllers in Cubit State

Do not store:

- TextEditingController.
- ScrollController.
- AnimationController.

inside Cubit state.

Widget lifecycle should own widget controllers.

---

## 97. No Focus Nodes in Cubit State

Do not store FocusNode instances in Cubit state.

Focus management belongs to Presentation/widget lifecycle.

---

## 98. Cubit and Dialogs

Cubit should not directly open dialogs.

Cubit exposes state/result.

The screen decides whether to display:

- Dialog.
- SnackBar.
- Bottom sheet.
- Navigation.

---

## 99. Cubit and SnackBars

Cubit should not directly call ScaffoldMessenger.

Instead:

Cubit
→
Failure/Success state

Screen
→
SnackBar / feedback UI

---

## 100. Cubit and Toasts

The same separation applies to toast notifications.

Do not couple Cubit to a specific UI notification implementation.

---

## 101. Cubit and Navigation Feedback

A successful operation may produce a state that the screen interprets.

Example:

PaymentSuccess

The screen may show feedback and refresh/navigate as defined by the UX.

Cubit remains unaware of the UI mechanism.

---

## 102. Async Safety

Cubit methods performing asynchronous operations must handle lifecycle safely.

If a Cubit can be closed before an async operation completes, the implementation must avoid emitting invalid state after disposal.

Use appropriate Cubit lifecycle patterns.

---

## 103. Race Conditions

Where multiple asynchronous operations can affect the same state, the implementation must avoid stale results overwriting newer state.

Examples:

- Search requests.
- Rapid filter changes.
- Multiple refresh operations.

For local database watchers, prefer a single reactive source when possible.

---

## 104. Search Debouncing

If search input triggers expensive queries, debounce according to the approved UX/performance requirements.

Do not introduce debounce everywhere automatically.

Simple local search may not require it.

---

## 105. Cubit and Transactions

Transactions belong to the Repository/Data Layer.

Cubit should treat a transaction-backed operation as one business operation.

Example:

`moveItem()`

must not expose internal transaction steps to the UI.

---

## 106. Cubit and Persistence

After a successful repository mutation, Cubit should reflect the resulting persisted state.

Do not assume persistence succeeded simply because a method was called.

The Repository result determines success/failure.

---

## 107. Optimistic Updates

Optimistic UI updates should not be introduced by default.

For V1 local-first operations, persistence is already fast and local.

Prefer:

Write locally
↓
Success
↓
Update UI

rather than:

Pretend success
↓
Update UI
↓
Try persistence later

---

## 108. Rollback

If an optimistic update is explicitly required later, rollback behavior must be designed separately.

Do not introduce optimistic state and rollback logic casually.

---

## 109. Offline Errors

A lack of Internet connectivity is not a normal feature failure in V1.

The Cubit should continue using the local Repository.

Do not create an `OfflineState` for every feature.

---

## 110. Sync States

Synchronization states are not part of V1 feature state.

Do not add:

- `Syncing`
- `PendingSync`
- `SyncFailed`

to normal business state unless explicitly introduced by the future synchronization phase.

---

## 111. State and Business Status

Do not confuse:

Presentation state

with:

Business entity status.

For example:

`OrderStatus.ready`

is business data.

`OrderDetailsState.loading`

is Presentation state.

They are different concepts.

---

## 112. State Naming

Use names that clearly describe the state.

Examples:

- Initial.
- Loading.
- Loaded.
- Empty.
- Failure.
- Submitting.
- Success.

Avoid ambiguous names such as:

- Good.
- Done.
- Active.
- Working.

unless they represent an actual domain concept.

---

## 113. State Enums

Enums may be used for simple status fields.

Example:

`OrdersStatus.initial`

`OrdersStatus.loading`

`OrdersStatus.success`

`OrdersStatus.failure`

The state model should remain immutable.

---

## 114. Sealed State Classes

Sealed state hierarchies may be used when the feature benefits from explicit state variants.

Example conceptual structure:

OrdersState
├── Initial
├── Loading
├── Loaded
├── Empty
└── Failure

The project should use one consistent approach rather than mixing styles arbitrarily.

---

## 115. Status-Based State

A status-based immutable state may be preferable when multiple fields must remain available across transitions.

Example:

OrdersState(
  status: OrdersStatus.loaded,
  orders: orders,
  filters: filters,
  failure: null,
)

The final implementation must follow the project's established coding conventions.

---

## 116. State Copying

If using a single immutable state class, use a safe copy/update mechanism.

The implementation should make state transitions explicit and predictable.

---

## 117. Avoid Mutable Lists

State collections should not be exposed as mutable collections that external code can modify.

Prefer immutable/unmodifiable representations according to project conventions.

---

## 118. State Equality

Equivalent states should compare predictably.

This is important for:

- Widget rebuild optimization.
- Testing.
- Debugging.
- Reactive state updates.

---

## 119. UI Rebuild Boundaries

Widgets should rebuild only when the state they depend on changes.

Use the appropriate `BlocBuilder`, `BlocSelector`, `buildWhen`, or equivalent flutter_bloc mechanisms where they provide meaningful optimization.

Do not add optimization complexity without need.

---

## 120. BlocBuilder Usage

Although the project does not use BLoC classes, `flutter_bloc` widgets such as `BlocBuilder` may still be used with Cubits because Cubit is part of the flutter_bloc package.

The prohibition is specifically against BLoC event-based state management, not against the flutter_bloc UI integration package.

---

## 121. BlocListener Usage

`BlocListener` may be used with Cubits for one-time side effects such as:

- Showing success feedback.
- Showing error feedback.
- Triggering navigation from the Presentation layer.

The Cubit itself must not perform those side effects.

---

## 122. BlocConsumer Usage

`BlocConsumer` may be used when a screen needs both:

- UI rebuilding.
- Side-effect listening.

Do not use it automatically if separate Builder/Listener widgets are clearer.

---

## 123. Side Effects

Side effects belong to Presentation.

Examples:

- Navigation.
- SnackBar.
- Dialog.
- Bottom sheet.
- Focus.
- Animation.

Cubit emits the state.

Presentation performs the side effect.

---

## 124. Cubit Logging

Cubit may use approved application logging for meaningful diagnostics.

Do not log:

- Sensitive information.
- Full customer data unnecessarily.
- Payment details unnecessarily.
- Authentication secrets.
- Database credentials.

Follow the project's logging standards.

---

## 125. Cubit and Analytics

Analytics events should not be added unless analytics is part of the approved implementation scope.

Do not introduce analytics dependencies into Cubits speculatively.

---

## 126. Cubit and Permissions

Permission checks should follow the approved architecture.

Do not hardcode role/permission logic inside every Cubit.

If authorization is introduced, centralize it according to the architecture.

---

## 127. Cubit and Authentication

Authentication is outside the current local-first V1 implementation unless explicitly included in scope.

Do not add authentication state merely because the application may have users later.

---

## 128. Cubit and App Startup

Application startup state should be managed only where necessary.

Do not make every feature Cubit initialize at application startup.

Feature Cubits should generally initialize when their feature is entered.

---

## 129. Lazy Feature Initialization

Prefer lazy initialization of feature-specific Cubits.

This keeps startup lightweight and avoids unnecessary database work.

---

## 130. Dashboard Initialization

Dashboard Cubit may initialize when Dashboard is opened.

It should obtain the required local data through approved repositories.

---

## 131. Orders Initialization

Orders Cubit should load/watch Orders when the Orders feature becomes active.

It should not require the application to preload every Order at startup.

---

## 132. Customers Initialization

Customers Cubit should load/watch Customers when needed.

Search/filter state should remain scoped to the Customers feature.

---

## 133. Storage Initialization

Storage Cubit should load the operational storage state when the Storage feature is opened.

Do not preload unnecessary storage data globally.

---

## 134. Expenses Initialization

Expenses Cubit should load the required local Expense data when the feature is opened.

Filters should remain feature-scoped unless explicitly persisted.

---

## 135. State Restoration

State restoration is not required unless explicitly included in the project scope.

Persistent business data is handled by the local database.

Do not implement a second persistence system for Cubit state without a requirement.

---

## 136. App Restart

After application restart:

Cubit
↓
Repository
↓
Local Database
↓
Reconstruct State

The system must not depend on serialized Cubit memory to restore business data.

---

## 137. Navigation and Cubit Lifecycle

When navigating away from a feature:

- Feature Cubit may be disposed according to its scope.
- Business data remains in the local database.
- Returning to the feature reconstructs state from the Repository.

---

## 138. Route Parameters and Cubit

For a detail route:

/orders/:orderId

the screen should create the appropriate Cubit with the `orderId`.

Conceptually:

Route
↓
OrderDetailsScreen(orderId)
↓
OrderDetailsCubit(orderId)
↓
Repository
↓
Local Database

---

## 139. Do Not Put Route Parsing in Cubit

The router/screen should extract and validate route parameters.

The Cubit receives typed values.

Do not make the Cubit parse route strings.

---

## 140. Cubit and Entity IDs

IDs passed to Cubits should use the project's approved ID types.

Do not make Cubits responsible for generating database IDs unless the approved architecture explicitly requires it.

---

## 141. Cubit and Form Drafts

Form draft state may be managed by Cubit when the form is complex or spans multiple UI sections.

For simple forms, local widget state may be sufficient.

Do not move every text field into global state.

---

## 142. Create Order State

Create Order may require state for:

- Selected Customer.
- Selected items.
- Services.
- Pricing.
- Validation.
- Submission status.
- Result.

The Cubit should coordinate the form state but must not become the owner of persistence logic.

---

## 143. Payment State

Payment operation state should expose:

- Submitting.
- Success.
- Failure.

The actual Payment persistence is handled by Repository/Data.

---

## 144. Storage Operation State

Storage operations such as:

- Store.
- Move.

should expose clear operation state.

The Cubit should not manually update database records.

---

## 145. Completion State

Order completion should expose:

- Submitting.
- Success.
- Failure.

The Domain/Repository layer performs the approved completion transaction and business validation.

---

## 146. Cancellation State

Order cancellation should follow the same pattern.

Cubit coordinates the operation.

Repository/Domain handles business behavior.

Presentation reacts to success/failure.

---

## 147. Cubit and Confirmation Dialogs

If an operation requires confirmation:

Screen
↓
Confirmation Dialog
↓
User confirms
↓
Cubit Method

The Cubit should not open the confirmation dialog itself.

---

## 148. Cubit and Handover Confirmation

For Order completion requiring explicit handover confirmation:

Screen
↓
Handover Confirmation
↓
Cubit.completeOrder(...)
↓
Repository/Domain
↓
Result

The Cubit should receive the confirmation result rather than controlling the dialog.

---

## 149. Cubit and Validation

Validation should be layered.

Presentation:

- Required fields.
- Basic input formatting.

Domain/business:

- Payment cannot exceed remaining.
- Completion prerequisites.
- Storage compatibility.
- Service compatibility.
- ItemDefinition compatibility.
- Other approved business rules.

Cubit coordinates these layers.

It does not replace them.

---

## 150. Cubit and Error Localization

Failure objects should remain language-independent where possible.

Example:

`PaymentExceedsRemainingAmount`

Presentation localization maps it to the Arabic user-facing message.

Do not hardcode:

"المبلغ أكبر من المتبقي"

inside the Cubit.

---

## 151. Cubit and Arabic UI

The application UI is Arabic-first and RTL.

Cubit state must remain language-independent.

UI localization is responsible for Arabic labels/messages.

---

## 152. Cubit and Performance

Cubits should remain lightweight coordinators.

Avoid:

- Large synchronous loops.
- Heavy data transformations.
- Full database aggregation.
- Large object duplication.

Move appropriate work to Repository/Data/Domain layers.

---

## 153. Derived Presentation Data

Small presentation-only derived values may be computed in Cubit when appropriate.

Examples:

- Whether a button should be enabled.
- Whether a filter is active.
- Whether a section should be displayed.

Do not duplicate complex business calculations that belong to Domain.

---

## 154. Business Calculation Ownership

Financial/business calculations should follow the approved Domain/Data architecture.

Examples:

- Remaining balance.
- Order totals.
- Profit calculations.
- Pricing.

Cubit should consume the resulting business data rather than reimplementing the formulas.

---

## 155. Cubit and Caching

Do not introduce independent Cubit-level caching for persistent business data unless explicitly required.

The local database already provides durable local storage.

---

## 156. Cache Invalidation

If caching is later introduced, its invalidation strategy must be explicitly designed.

Do not add ad-hoc caches inside Cubits.

---

## 157. Cubit and Repository Streams

When a Cubit subscribes to a repository stream, it should translate repository data into Presentation state.

It must not expose the raw stream directly to widgets unless that is explicitly part of the architecture.

---

## 158. Repository Failure Streams

Repository stream failures should be converted into the Cubit's appropriate failure state.

The UI should not need to understand Data Layer exceptions.

---

## 159. Empty Stream Results

A successful repository stream with no records should produce an empty state or equivalent state representation.

It must not automatically become a failure.

---

## 160. State Transition Documentation

Complex Cubits should document their meaningful state transitions in code comments or feature documentation when necessary.

Do not add comments for obvious code.

---

## 161. Avoid Premature Abstractions

Do not create:

- Generic Cubit base classes.
- Generic state frameworks.
- Custom state machines.

unless they solve a demonstrated repeated problem.

Keep V1 implementation explicit and maintainable.

---

## 162. Avoid Over-Engineering

Do not introduce:

- BLoC event systems.
- Redux.
- Riverpod.
- Provider as a second state-management architecture.
- MobX.
- GetX state management.

The approved V1 state-management architecture is Cubit.

---

## 163. Single State Management Strategy

Do not mix multiple application-level state-management solutions.

`flutter_bloc` + Cubit is the standard.

Other state mechanisms may be used only for local widget concerns where appropriate and without creating a second application-wide architecture.

---

## 164. GetIt vs State Management

GetIt is Dependency Injection.

Cubit is State Management.

Do not use GetIt as a state-management replacement.

Do not use Cubit as a service locator.

Their responsibilities must remain separate.

---

## 165. Repository vs Cubit

Repository is Data/Application access abstraction.

Cubit is Presentation state coordination.

Neither should replace the other.

---

## 166. Domain vs Cubit

Domain owns business rules.

Cubit owns Presentation state.

Do not move business invariants into Cubit simply because the UI needs the result.

---

## 167. Widget vs Cubit

Widget renders state and captures user interaction.

Cubit coordinates the operation.

Do not place repository/database logic inside widgets.

---

## 168. Final Layer Responsibilities

### Widget

Responsible for:

- Rendering.
- User interaction.
- Local ephemeral UI state.
- Triggering Cubit methods.
- Responding to Cubit state.
- Navigation/feedback side effects.

### Cubit

Responsible for:

- Presentation state.
- Operation coordination.
- Repository interaction.
- Loading/success/failure states.
- Reactive state subscription.

### Domain

Responsible for:

- Business rules.
- Business calculations.
- Domain operations.
- Invariants.

### Repository

Responsible for:

- Data access abstraction.
- Coordinating data sources.
- Mapping data/failures.

### Data Layer

Responsible for:

- Database.
- DAO.
- Drift.
- Local persistence.

---

## 169. Standard Mutation Flow

The standard V1 mutation flow is:

User
↓
Widget
↓
Cubit
↓
Repository
↓
Domain/business validation where required
↓
Local Data Source
↓
Database Transaction
↓
Result
↓
Cubit
↓
UI

---

## 170. Standard Read Flow

The standard V1 read flow is:

Screen
↓
Cubit
↓
Repository
↓
Local Data Source
↓
Database
↓
Result
↓
Cubit State
↓
UI

---

## 171. Standard Reactive Flow

For reactive data:

Database
↓
Local Watch
↓
Repository
↓
Cubit
↓
State
↓
UI

This is preferred when the UI needs automatic updates after local mutations.

---

## 172. AI Coding Agent Rules

The coding agent must treat this document as a hard implementation boundary.

The agent must:

- Use Cubit.
- Not use BLoC.
- Keep Cubits Presentation-focused.
- Access data through Repository contracts.
- Use GetIt for dependency injection.
- Keep navigation outside Cubit.
- Keep database logic outside Cubit.
- Keep Domain rules outside Cubit.
- Respect Offline-First behavior.

---

## 173. AI Must Not Introduce BLoC

The coding agent must not create:

- `Bloc` classes.
- BLoC event classes.
- `on<Event>()`.
- Event/state pipelines.

If a task can be implemented with Cubit, it must be implemented with Cubit.

---

## 174. AI Must Not Replace Cubit With Another State Framework

Do not introduce:

- Riverpod.
- Provider as application state management.
- GetX.
- Redux.
- MobX.

The project has an explicit Cubit-only decision.

---

## 175. AI Must Not Access Database From Cubit

The coding agent must not inject:

- AppDatabase.
- DAO.
- Drift table references.

into Cubits.

---

## 176. AI Must Not Put Business Rules in Cubit

Do not move core business invariants into Cubits merely because they are used by a screen.

Use the approved Domain/Repository architecture.

---

## 177. AI Must Not Navigate From Cubit

Do not call:

- `context.go()`
- `context.push()`
- `Navigator`
- `AppRouter`

from Cubit code.

Return state/results and let Presentation navigate.

---

## 178. AI Must Not Hardcode UI Strings in Cubit

Do not hardcode Arabic user-facing messages inside Cubit.

Use language-independent failures/state data and localized Presentation messages.

---

## 179. AI Must Not Put Widgets in State

Do not store Widget instances or Flutter controller objects in Cubit state.

---

## 180. AI Must Not Create God Cubits

Do not create a single Cubit for the entire application.

Use meaningful feature/state boundaries.

---

## 181. AI Must Not Create Cubit-to-Cubit Coupling

Do not inject one feature Cubit into another simply to share business data.

Use repositories/domain abstractions.

---

## 182. AI Must Preserve Reactive Local Data

When a feature requires reactive local updates, use the Repository's approved watch/stream mechanism.

Do not manually poll the database.

---

## 183. AI Must Not Add Connectivity Logic

Do not add connectivity checks to Cubits for normal V1 operations.

The application is Local-First.

---

## 184. AI Must Not Add Sync Logic

Do not add synchronization behavior to Cubits during V1.

Backend and synchronization are deferred.

---

## 185. AI Must Preserve Existing State Architecture

When modifying an existing Cubit:

- Reuse the established state model where appropriate.
- Do not rewrite the entire state architecture unnecessarily.
- Do not introduce a different state pattern without an explicit decision.

---

## 186. AI Must Search Before Creating a Cubit

Before creating a new Cubit:

1. Search for an existing Cubit managing the same feature.
2. Search for the existing state model.
3. Confirm that a new Cubit is actually required.
4. Follow the established naming and folder structure.
5. Avoid duplicate state managers.

---

## 187. AI Must Keep Changes Scoped

When implementing a feature:

- Modify only the required Cubit/state files.
- Do not refactor unrelated Cubits.
- Do not introduce unrelated state-management improvements.
- Do not migrate existing Cubits to another pattern unless explicitly requested.

---

## 188. AI Completion Report

Any implementation task that creates or changes Cubit/state-management code must provide an explicit completion report containing:

### Implemented

What state-management behavior was added or changed.

### Cubits

List the Cubits added or modified.

### States

List the state models added or modified.

### Repository Dependencies

List the Repository contracts used.

### DI

Confirm that dependencies are provided through the approved GetIt configuration.

### Navigation

Confirm that navigation remains outside the Cubit.

### Database Boundary

Confirm that Cubits do not access DAOs, Drift, SQLite, or database instances directly.

### Business Logic Boundary

Confirm that core business rules remain outside Presentation.

### Offline-First

Confirm that the feature does not require network connectivity for its V1 local workflow.

### Tests

List Cubit/state tests executed and their results.

### BLoC Check

Explicitly confirm:

**No BLoC classes or event-based BLoC architecture were introduced.**

### Architecture Compliance

Confirm that:

Widget
→
Cubit
→
Repository
→
Data Layer

was preserved.

### Out of Scope

List anything intentionally not implemented.

### Remaining Issues

List unresolved issues or dependencies.

---

## 189. Definition of Done

State-management implementation is complete when:

- Cubit is the only application state-management architecture.
- No BLoC classes exist.
- Cubits have clear responsibilities.
- Cubits do not access the database directly.
- Cubits do not access DAOs directly.
- Cubits do not contain SQL/Drift queries.
- Cubits depend on approved Repository abstractions.
- Dependencies are provided through GetIt.
- Cubits do not own navigation.
- Cubits do not contain core business invariants.
- State is immutable.
- Loading/success/empty/failure states are represented correctly.
- Existing data is preserved during relevant mutations.
- Reactive local data is handled through Repository streams/watchers.
- Cubit lifecycle is safe.
- Feature state is appropriately scoped.
- Cubit-to-Cubit coupling is avoided.
- UI side effects remain in Presentation.
- Localization remains outside Cubit.
- Offline V1 behavior does not depend on connectivity.
- Synchronization logic is not introduced.
- Tests cover meaningful state transitions.
- No unrelated state-management refactor was introduced.
- The completion report is provided.

---

## 190. Final State Management Architecture

The required V1 architecture is:

Presentation
├── Screens / Widgets
│
└── Cubits
    ↓
Repository Contract
    ↓
Repository Implementation
    ↓
Domain / Business Operations where required
    ↓
Local Data Source
    ↓
Drift / SQLite

Dependency Injection:

GetIt
↓
Creates / Provides
├── Database
├── Data Sources
├── Repositories
└── Cubits where appropriate

Routing:

AppRoutes
↓
AppRouter
↓
Screen

Cubit does not own routing.

---

## 191. Final Principles

1. Cubit is the approved V1 state-management solution.
2. BLoC is not used.
3. No BLoC event architecture should be introduced.
4. Cubit manages Presentation state.
5. Cubit does not own business persistence.
6. Cubit does not access the database directly.
7. Cubit does not access DAOs directly.
8. Cubit does not contain SQL or Drift queries.
9. Cubit communicates with the Repository abstraction.
10. GetIt provides dependencies.
11. Domain owns core business rules.
12. Data owns persistence.
13. Routing remains outside Cubit.
14. UI side effects remain in Presentation.
15. Cubit state is immutable.
16. Loading, success, empty, and failure states must be explicit.
17. Existing data should be preserved during independent mutations when appropriate.
18. Reactive local data should flow through Repository watchers.
19. Cubits should remain feature-scoped and focused.
20. God Cubits are prohibited.
21. Direct Cubit-to-Cubit coupling is discouraged.
22. Offline-first behavior is the normal V1 behavior.
23. Connectivity must not control normal Cubit operations.
24. Synchronization is outside V1.
25. The architecture must remain ready for future Remote Data Sources without requiring Feature-layer rewrites.
26. Simplicity and clear boundaries take priority over unnecessary state-management complexity.