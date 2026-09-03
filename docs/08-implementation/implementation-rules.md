# Implementation Rules

## 1. Purpose

This document defines the mandatory implementation rules for the Laundry Management System.

These rules govern how the approved architecture, domain model, database, data layer, features, state management, validation, and offline-first behavior must be implemented.

The purpose is to prevent implementation drift, unnecessary abstraction, accidental scope expansion, and violations of the approved project architecture.

These rules are mandatory unless an explicit project decision changes them.

---

## 2. Source of Truth

Implementation must follow the approved project documentation.

The coding agent must not treat its own assumptions as requirements.

Before implementing a task, the agent should consult the relevant documentation, especially:

- Product Scope
- Requirements
- Business Rules
- Domain Model
- Database Design
- Database Decisions
- Architecture
- Technical Decisions
- Data Layer
- Project Structure
- Design System
- Navigation
- Dashboard
- Customers
- Orders
- Implementation Overview
- Implementation Plan
- Coding Standards
- Architecture Guidelines
- Database Implementation
- Data Layer Implementation
- Domain Implementation
- Feature Implementation
- Offline-First
- Routing and Navigation
- State Management
- Validation Checklist

If two documents appear to conflict, do not silently choose one.

The conflict must be identified and resolved before implementing the affected behavior.

---

## 3. Scope Discipline

The implementation must remain within the approved V1 scope.

The coding agent must implement the requested task and its necessary dependencies only.

Do not:

- Add unrelated features.
- Refactor unrelated modules.
- Rename unrelated classes.
- Replace approved libraries without justification.
- Change the database schema without requirement.
- Introduce new architectural layers without approval.
- Add speculative functionality.
- Implement deferred backend/synchronization functionality.
- Improve unrelated UI screens while implementing another feature.

A task should produce the smallest coherent change that satisfies the approved requirement.

---

## 4. No Feature Invention

The coding agent must not invent product capabilities.

Unless explicitly approved, do not add:

- Employee management
- Roles
- Permissions
- Branch management
- Driver management
- Vehicle management
- Delivery management
- Refunds
- Loyalty programs
- Barcode workflows
- AI assistant
- Advanced workflow stages
- Cloud synchronization
- Backend APIs
- Multi-branch functionality
- Additional accounting entities

If a missing capability is necessary to complete a task, stop and identify the dependency instead of inventing it.

---

## 5. Architecture Is Mandatory

The approved V1 architecture is:

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
Drift / SQLite

The implementation must preserve these boundaries.

Presentation must not directly access Data Layer infrastructure.

Domain must remain independent from Flutter-specific presentation concerns.

Data must remain independent from Presentation.

---

## 6. Presentation Rules

Presentation contains:

- Screens
- Widgets
- Forms
- Cubits
- Presentation state
- User interaction
- Display formatting
- Navigation requests

Presentation must not contain:

- SQL
- Drift queries
- DAO calls
- SQLite access
- Dio calls
- Retrofit calls
- Database transactions
- Infrastructure exceptions

---

## 7. Cubit Rules

V1 uses Cubit for state management.

Do not introduce Bloc unless an explicit architecture decision requires it.

Cubit responsibilities include:

- Handling user actions.
- Calling repository contracts.
- Managing presentation state.
- Coordinating loading/success/error states.
- Exposing operation results to the UI.

Cubit must not:

- Access DAOs directly.
- Access SQLite directly.
- Construct repository implementations.
- Perform SQL.
- Make HTTP calls directly.
- Contain widget code.
- Become a global application state container.

---

## 8. Cubit-to-Cubit Communication

Avoid Cubit-to-Cubit dependencies.

Do not implement:

OrdersCubit → CustomersCubit

ReportsCubit → ExpensesCubit

StorageCubit → OrdersCubit

as a default communication mechanism.

When a feature needs business data, obtain it through the appropriate repository contract.

Cubit-to-Cubit communication may only be introduced when there is a clearly documented presentation-level requirement that cannot reasonably be handled through the approved architecture.

---

## 9. Repository Rules

Repositories are the boundary between Domain-facing feature logic and Data implementation.

Feature code must depend on repository contracts.

Example:

OrdersCubit
↓
OrderRepository

The concrete implementation:

OrderRepositoryImpl

belongs to Data.

Presentation must not depend directly on repository implementations.

---

## 10. Repository Responsibilities

Repositories are responsible for:

- Exposing application/domain-facing data operations.
- Coordinating Data Sources.
- Returning Domain entities/models.
- Translating Data Layer failures into approved application/domain failures where applicable.
- Coordinating persistence operations.
- Protecting transaction boundaries through the Data Layer.

Repositories must not contain UI logic.

Repositories must not return widgets or presentation states.

---

## 11. Data Layer Rules

The Data Layer contains:

- Repository implementations.
- Local data sources.
- DAOs.
- Database interaction.
- Data-to-Domain conversion.
- Persistence-specific logic.

Data must not depend on:

- Screens
- Widgets
- Cubits
- Presentation state
- Navigation

---

## 12. Database Access

All database access must remain inside the approved Data Layer.

Prohibited:

Screen → Database

Cubit → Database

Widget → DAO

Cubit → DAO

Feature → SQL

Feature → Drift

The only approved path is through the Repository boundary.

---

## 13. Database Schema Discipline

Do not modify the database schema casually.

Before changing:

- Tables
- Columns
- Foreign keys
- Constraints
- Indexes
- Relationships
- Enums stored in the database
- Generated database code

verify that the change is actually required by an approved requirement or implementation dependency.

Database changes must remain aligned with the approved Database Design and Database Decisions.

---

## 14. Database Constraints

Application validation and database constraints serve different purposes.

Application/domain validation provides user-friendly behavior.

Database constraints protect structural integrity.

Never remove or weaken a database constraint simply because the UI already validates the same rule.

Never rely exclusively on UI validation for critical integrity rules.

---

## 15. Transactions

Any operation that changes multiple related records and must succeed or fail as one business operation must use the appropriate Data Layer transaction.

Examples include:

Create Order
+
Create OrderItems

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
Deactivate active StorageRecords

Cancel Order
+
Update Order
+
Deactivate active StorageRecords

The UI and Cubit must not manually manage database transactions.

---

## 16. Domain Rules

Business rules must not live exclusively in widgets.

The Domain is responsible for business concepts and invariants.

Examples:

- Payment cannot exceed remaining amount.
- Carpet requires CarpetItemData.
- Non-Carpet items do not require CarpetItemData.
- Service must support the selected ItemType.
- ItemDefinition must belong to the selected ItemType.
- Order completion requires approved prerequisites.
- Storage must maintain one active StorageRecord per OrderItem.
- Expense Other requires customName.

The exact authoritative location must follow the Domain Implementation documentation.

---

## 17. UI Validation

UI validation is allowed and encouraged for good UX.

Examples:

- Required field validation.
- Input formatting.
- Immediate feedback.
- Invalid number format.
- Empty field feedback.

However, UI validation must not replace business validation.

The same business rule must remain protected outside the UI.

---

## 18. Error Handling

Raw infrastructure exceptions must never be exposed directly to the user.

Do not display:

- SQLite exception messages.
- Drift exception messages.
- Dio exception messages.
- Stack traces.
- Raw technical errors.

Errors must be translated through the approved error-handling strategy.

The UI should receive a meaningful application-level failure representation.

---

## 19. Loading State

Loading states must represent actual asynchronous operations.

Do not introduce artificial delays.

Do not use loading states simply to create visual animation.

Prefer localized loading indicators when only part of a screen is changing.

Do not block an entire screen when a small operation can be represented locally.

---

## 20. Empty State

An empty dataset is not an error.

Every list-based feature should distinguish between:

Loading

Empty

Loaded

Failure

Examples:

No Customers

No Orders

No Expenses

No Items Requiring Storage

These must not be represented as generic errors.

---

## 21. Success State

Successful mutations should produce clear UI behavior.

Depending on the feature, success may result in:

- Updated list.
- Updated details.
- Confirmation.
- Success message.
- Navigation.
- Closing a form.

Do not create unnecessary success notifications for passive data loading.

---

## 22. Offline-First Rule

V1 is local-first.

Normal business operations must work without network connectivity.

The implementation must not require a backend to:

- Create Customers.
- Create Orders.
- Record Payments.
- Store Items.
- Move Items.
- Create Expenses.
- Manage supported master data.

The local database is the operational source for the current implementation phase.

---

## 23. Backend and Synchronization

Backend and synchronization are intentionally deferred.

Do not implement:

- API calls.
- Remote repositories.
- Sync workers.
- Sync queues.
- Connectivity-dependent business flows.
- Retry infrastructure.
- Remote conflict resolution.

unless the task explicitly belongs to the later backend/synchronization phase.

The current architecture must remain ready for future integration without implementing it prematurely.

---

## 24. No Network Logic in Features

Do not add Dio or Retrofit calls to:

- Screens
- Widgets
- Cubits
- Domain entities

Future network access must remain behind the Repository/Data boundary.

---

## 25. Dependency Injection

GetIt is the approved V1 dependency injection approach.

Dependencies should be constructed and registered centrally.

Prefer constructor injection.

Example:

OrdersCubit(orderRepository)

Do not instantiate concrete repositories inside Cubits.

Do not use GetIt as a replacement for constructor dependencies inside every class.

GetIt should primarily assemble the application dependency graph.

---

## 26. Dependency Lifetimes

Use appropriate lifetimes.

Repositories and infrastructure should follow the approved DI lifecycle.

Cubits should normally be factory-created because their state is presentation-specific.

Do not accidentally share one Cubit's state across unrelated screens.

---

## 27. Packages

Before adding a package:

1. Check existing dependencies.
2. Check Technical Decisions.
3. Check Architecture Guidelines.
4. Verify that the package solves an actual approved requirement.
5. Confirm that no existing project capability already solves the problem.

Do not add packages simply because they are popular.

Do not introduce duplicate libraries for the same responsibility.

---

## 28. Approved Networking

When networking is implemented in the later phase, the approved direction is:

Dio
+
Retrofit

Do not implement networking during the current local-only phase.

---

## 29. No Unapproved Architecture Layers

Do not introduce mandatory layers such as:

- Application
- Use Cases
- Interactors
- Managers
- Coordinators
- Mappers
- Service layers
- Feature repositories

unless explicitly approved.

The current architecture intentionally remains lightweight.

---

## 30. No Mandatory Use Cases

Do not automatically create:

CreateOrderUseCase

RecordPaymentUseCase

CreateExpenseUseCase

GetDashboardUseCase

The approved V1 flow is:

Cubit
↓
Repository Contract
↓
Data

Business logic belongs in the appropriate Domain/repository operation according to the existing architecture.

---

## 31. No Generic CRUD Framework

Do not create a generic CRUD abstraction to handle all entities unless explicitly required.

Examples of prohibited premature abstractions:

BaseCrudRepository

GenericCrudCubit

GenericEntityController

UniversalFormManager

GenericDataManager

Explicit implementations are preferred when they are clearer.

---

## 32. No Generic Utils

Avoid generic containers such as:

Utils

Helpers

Managers

CommonService

unless the responsibility is genuinely shared and clearly defined.

A shared abstraction should exist because multiple real use cases require it, not because reuse may happen later.

---

## 33. Feature Boundaries

Each feature owns its presentation concerns.

A feature must not reach into another feature's internal implementation.

For example:

Orders must not import:

customers/presentation/cubit/customers_cubit.dart

Storage must not import:

orders/presentation/cubit/orders_cubit.dart

Use approved repository contracts instead.

---

## 34. Feature Folder Rules

Use the approved project structure.

A typical feature:

features/
└── orders/
    └── presentation/
        ├── screens/
        ├── widgets/
        └── cubit/

Do not create unnecessary folders.

Do not create feature-specific Data or Domain layers when the approved architecture already centralizes those layers.

---

## 35. File Naming

Use:

snake_case for filenames.

PascalCase for classes.

camelCase for variables and methods.

Examples:

order_details_screen.dart

orders_cubit.dart

order_repository.dart

OrderDetailsScreen

OrdersCubit

createOrder()

orderId

Follow Coding Standards for all additional naming rules.

---

## 36. Localization

The application UI is Arabic and RTL.

All user-facing feature strings must support the approved localization strategy.

Do not hardcode business identifiers as Arabic strings.

Example:

Domain:

OrderStatus.processing

Presentation:

قيد التنفيذ

Domain values remain language-independent.

---

## 37. RTL

All new feature screens must respect RTL behavior.

Pay attention to:

- Alignment.
- Directional icons.
- Navigation controls.
- Forms.
- Tables.
- Lists.
- Dates.
- Currency display.

Do not introduce isolated LTR assumptions.

---

## 38. Money

Financial calculations must use the approved monetary representation.

Do not calculate using formatted display strings.

Example:

"١٬٠٠٠ جنيه"

is a presentation value.

It must not be parsed and used as the financial source of truth.

Use the Domain/Data monetary representation defined by the project documentation.

---

## 39. Dates

Business date-only values must remain date-only.

Do not accidentally add a time component to:

- Expected Pickup Date.
- Expense Date.

Presentation may localize the date for Arabic users.

---

## 40. Historical Data

Historical transaction data must remain stable.

Changing master data must not silently rewrite historical transactions.

Examples:

Changing Service price
→ does not change previous OrderItem prices.

Changing Service name
→ does not change historical Service snapshots.

Changing CarpetSize
→ does not change historical CarpetItemData.

Renaming ExpenseCategory
→ does not destroy historical category meaning.

---

## 41. Master Data

Master data includes concepts such as:

- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Storage Locations
- Expense Categories
- Business Settings

Master data may have active/inactive lifecycle behavior where defined.

Inactive master data should not normally be selectable for new transactions.

Historical references must remain valid.

---

## 42. Order Lifecycle

The approved V1 Order statuses are:

- Processing
- Ready
- Completed
- Cancelled

Do not add additional operational statuses without an explicit requirement.

Do not use UI state such as:

Loading

Error

Saving

as OrderStatus values.

---

## 43. Order Completion

Completion requires all approved prerequisites.

At minimum:

Ready
+
Remaining Amount = 0
+
Explicit Handover Confirmation

The feature must not automatically complete an Order merely because it is fully paid.

---

## 44. Order Cancellation

Cancellation is a business operation.

Cancelled Orders must remain stored for historical purposes.

Do not physically delete cancelled Orders.

Cancelled Orders are operationally read-only according to the approved rules.

---

## 45. Payment Rules

Payments must preserve their own transaction history.

Do not replace payment records with only an Order balance.

A Payment must:

- Be positive.
- Belong to a valid Order.
- Not exceed the current Remaining Amount.
- Use a valid PaymentMethod.

Multiple Payments are supported.

Fully paid does not automatically mean Completed.

---

## 46. Storage Rules

Storage operates at OrderItem level.

An Order may contain multiple physical OrderItems.

Each physical OrderItem may have at most one active StorageRecord.

Moving an item means:

Deactivate previous active StorageRecord
+
Create new active StorageRecord

This operation must be atomic.

---

## 47. Storage and Completion

When an Order is completed:

Active StorageRecords for its items must be deactivated according to the approved business rules.

If:

Completed → Processing

the system must not automatically reactivate previous StorageRecords.

The items must be explicitly stored again through the Storage workflow.

---

## 48. Quantity and Physical Items

Quantity input in the UI must not incorrectly collapse physical identity.

If the business model requires five physical OrderItems:

Quantity = 5

must result in the required physical item records.

Storage and physical lifecycle operations depend on individual OrderItems.

---

## 49. Carpet Rules

Carpet OrderItems require CarpetItemData.

Required carpet information includes:

- Length
- Width
- Area

Area is derived according to the approved business rules.

Non-Carpet OrderItems must not be forced to provide CarpetItemData.

Do not make carpet fields universally required.

---

## 50. Pricing Rules

The selected PricingType determines how the item is priced.

Supported concepts include:

- Per Piece
- Per Kilogram
- Per Square Meter
- Fixed Price

Do not assume all services use:

price × quantity

Pricing logic must follow the approved Domain rules.

---

## 51. Service Compatibility

A selected Service must:

- Exist.
- Be active when required for new transactions.
- Support the selected ItemType.

Filtering the UI is useful but insufficient.

The business rule must also be enforced when saving.

---

## 52. ItemDefinition Compatibility

An ItemDefinition must belong to the selected ItemType.

Inactive ItemDefinitions must not be selectable for new transactions.

Historical OrderItems referencing inactive definitions remain valid.

---

## 53. Expense Rules

Expenses are independent financial transactions.

An Expense must:

- Have a positive amount.
- Have a valid Category.
- Have a valid Date.
- Have customName when Category = Other.

Expenses must not be treated as Payments.

Expenses must not automatically become Order-related transactions.

---

## 54. Expense Historical Integrity

Historical Expenses must remain understandable even after ExpenseCategory changes.

Changing or deactivating a category must not rewrite or delete historical Expenses.

---

## 55. Reports

Reports are derived from transactional data.

Do not introduce separate financial transaction entities simply to calculate:

- Sales
- Expenses
- Net Profit

unless explicitly approved.

Net Profit is derived according to the approved business definition.

---

## 56. Dashboard

Dashboard is a presentation feature.

Do not turn Dashboard into a second business logic layer.

Dashboard metrics must be derived from approved data/repository operations.

Do not invent additional KPIs.

---

## 57. Navigation

Navigation must use the centralized routing system.

Do not hardcode navigation logic throughout business logic.

Cubits should emit operation results.

Presentation decides whether to:

- Navigate.
- Show confirmation.
- Close a screen.
- Refresh.

Entity IDs should be passed through navigation rather than infrastructure objects.

---

## 58. No Infrastructure Through Navigation

Do not pass:

- Database rows.
- DAO objects.
- Repository implementations.
- Database connections.

through route arguments.

Pass stable identifiers and load the required Domain data through approved repository contracts.

---

## 59. Reactive Local Data

Where repository watchers are supported, use them for screens that should automatically reflect local database changes.

Preferred:

Database
↓
Repository Watch
↓
Cubit
↓
UI

Avoid unnecessary manual refresh logic.

A successful local mutation should naturally propagate to the UI where reactive data is available.

---

## 60. Search and Filtering

Search and filtering must respect the approved repository/data boundaries.

Do not load an unnecessarily large dataset into memory simply to perform database filtering in the UI.

Prefer database-side filtering for scalable datasets.

The exact query implementation belongs to Data.

---

## 61. Performance

Do not optimize prematurely.

At the same time, avoid obviously inefficient implementations such as:

- Loading the entire database to calculate a count.
- Loading all Expenses for a date filter.
- Loading all StorageRecords when an indexed current-state query is available.
- Rebuilding unrelated parts of the UI unnecessarily.

Use appropriate repository operations and database queries.

---

## 62. Duplicate Actions

Prevent accidental duplicate mutations.

Examples:

- Double-tapping Save.
- Recording a Payment twice.
- Storing the same OrderItem twice.
- Completing an Order twice.

Presentation should disable or guard actions while an operation is in progress.

Critical integrity rules must also be protected at the Domain/Data/Database level where appropriate.

---

## 63. No Silent Data Loss

Never implement destructive operations without explicit business approval.

Do not:

- Delete historical Orders.
- Delete historical Payments.
- Delete historical Expenses.
- Delete historical StorageRecords.
- Rewrite historical transaction snapshots.

Prefer lifecycle/deactivation behavior where defined.

---

## 64. Refactoring Rules

Refactoring is allowed only when:

- It is required for the requested implementation.
- It preserves approved behavior.
- It does not unnecessarily expand scope.

Do not perform large unrelated refactors during feature implementation.

If a refactor is necessary because the existing code violates an architectural rule, keep it focused and document the reason.

---

## 65. Existing Code

Before creating a new implementation:

1. Search for existing related code.
2. Reuse existing approved components where appropriate.
3. Avoid duplicate classes.
4. Avoid duplicate repositories.
5. Avoid duplicate widgets.
6. Avoid duplicate business rules.

Do not create a second implementation simply because locating the first one is inconvenient.

---

## 66. Generated Code

Generated code must be produced using the project's approved generation workflow.

Do not manually modify generated database or serialization files unless the project documentation explicitly requires it.

Changes should be made to the source definitions and regenerated.

---

## 67. Documentation Alignment

When implementation changes an approved architectural decision, the relevant documentation must be updated.

Do not allow:

Documentation

and:

Code

to silently diverge.

If a change affects:

- Architecture
- Database
- Domain
- State Management
- Offline-First
- Navigation

the corresponding documentation must be reviewed.

---

## 68. Testing Before Completion

A task is not complete simply because the code compiles.

The implementation must be checked for:

- Correct behavior.
- Business rules.
- Validation.
- Error handling.
- Offline operation.
- Persistence.
- Navigation.
- State transitions.
- Regression risk.

Critical business workflows require automated tests according to the testing strategy.

---

## 69. Minimum Feature Testing

A feature should have appropriate tests for:

- Successful operations.
- Validation failures.
- Business rule failures.
- Repository failures.
- Empty states.
- Loading states.
- Important state transitions.
- Critical persistence behavior.

The exact testing depth depends on the feature.

---

## 70. Order Testing

Critical Order behavior must include tests for:

- Valid creation.
- Required Customer.
- Required OrderItems.
- Service compatibility.
- ItemDefinition compatibility.
- PricingType behavior.
- Carpet validation.
- Quantity-to-physical-item behavior.
- Storage readiness.
- Payment prerequisites.
- Completion.
- Handover confirmation.
- Cancellation.
- Historical preservation.

---

## 71. Storage Testing

Critical Storage behavior must include:

- Items requiring storage.
- Compatible locations.
- Store operation.
- Move operation.
- Single active StorageRecord.
- Old StorageRecord deactivation.
- New StorageRecord creation.
- Order readiness.
- Completion cleanup.
- Status correction behavior.

---

## 72. Payment Testing

Critical Payment behavior must include:

- Positive payment.
- Zero payment rejection.
- Negative payment rejection.
- Overpayment rejection.
- Multiple payments.
- Correct remaining balance.
- Fully paid but not automatically completed.

---

## 73. Expense Testing

Critical Expense behavior must include:

- Valid creation.
- Positive amount.
- Required category.
- Other customName requirement.
- Invalid input handling.
- Date filtering.
- Category filtering.
- Historical category preservation.

---

## 74. Master Data Testing

Master-data tests should verify:

- Creation.
- Editing.
- Activation.
- Deactivation.
- Selection restrictions.
- Historical transaction preservation.

---

## 75. Offline Testing

Critical V1 workflows must work without network access.

At minimum verify local behavior for:

- Customer creation.
- Order creation.
- Payment recording.
- Storage operations.
- Expense creation.
- Supported master-data operations.

A feature must not fail simply because the device is offline.

---

## 76. AI Implementation Workflow

Before coding:

1. Read the relevant documentation.
2. Identify the requested scope.
3. Identify dependencies.
4. Check existing implementation.
5. Confirm architecture boundaries.
6. Identify affected layers.
7. Implement the smallest coherent change.
8. Run tests/analyzers.
9. Verify business rules.
10. Verify no unrelated behavior changed.
11. Report what was implemented.

---

## 77. AI Must Stop on Ambiguity

If implementation requires a decision that is not covered by the documentation, do not invent the answer.

Examples:

- New business rule.
- New database relationship.
- New Order status.
- New entity.
- New package.
- New architectural layer.
- New synchronization behavior.

The agent should identify the ambiguity and request a decision.

---

## 78. AI Completion Report

After completing an implementation task, the coding agent must provide an explicit completion report.

The report should contain:

### Implemented

What was actually changed.

### Files Changed

Files created, modified, or deleted.

### Behavior

What the implemented feature now does.

### Tests

Tests executed and their result.

### Validation

Relevant checks performed.

### Architecture Compliance

Confirmation that approved architecture boundaries were preserved.

### Out of Scope

Anything intentionally not implemented.

### Remaining Issues

Any unresolved issue, blocker, or documented limitation.

The agent must not claim completion without actually verifying the implementation.

---

## 79. No False Completion

The agent must not say:

"Done"

or:

"Implemented successfully"

unless the requested implementation was actually completed and checked.

If something could not be completed, state exactly what remains.

Do not hide compile errors, failing tests, missing dependencies, or incomplete flows.

---

## 80. Definition of Done

An implementation task is considered complete when:

- The requested behavior is implemented.
- Approved requirements are respected.
- Domain rules are preserved.
- Architecture boundaries are preserved.
- Database rules are preserved.
- Data Layer boundaries are preserved.
- Cubit is used appropriately.
- Validation is implemented.
- Errors are handled.
- Loading/empty states are handled where applicable.
- Offline-first behavior is preserved.
- Navigation is integrated where applicable.
- DI is configured.
- Relevant tests pass.
- No unapproved feature was introduced.
- No unrelated refactor was performed.
- Documentation remains consistent.
- An explicit completion report is provided.

---

## 81. Final Rule

When there is a choice between:

A simple implementation that follows the approved architecture

and:

A more complex implementation that introduces speculative abstractions or functionality

choose the simple approved implementation.

When there is a choice between:

Guessing an undocumented requirement

and:

Stopping to request clarification

choose clarification.

When there is a choice between:

Convenience that bypasses an architecture boundary

and:

The approved architecture

choose the approved architecture.

The implementation must optimize for:

Correctness
+
Maintainability
+
Scope Discipline
+
Architectural Consistency
+
Offline-First Reliability

not for unnecessary complexity.