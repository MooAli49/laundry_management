# Laundry Management System — Coding Standards

## 1. Purpose

This document defines the coding standards for the Laundry Management System V1.

Its purpose is to ensure that all Flutter and Dart code follows one consistent implementation style.

These standards apply to:

- Application code
- Domain code
- Data code
- Feature code
- Tests
- Shared utilities
- Shared widgets
- Database code
- Networking code

These standards must be followed by all developers and AI coding agents working on the project.

This document does not redefine product requirements or architecture.

The approved architecture and business rules remain authoritative.

## 2. General Principles

Code must prioritize:

1. Correctness
2. Readability
3. Maintainability
4. Testability
5. Simplicity
6. Consistency

Avoid code that is clever but difficult to understand.

Prefer explicit code over unnecessary abstraction.

Prefer small focused classes over large multipurpose classes.

Prefer clear names over comments explaining unclear names.

Do not optimize prematurely.

Do not introduce complexity without a concrete requirement.

## 3. Dart Style

Follow standard Dart formatting and linting conventions.

Use:

- dart format
- flutter analyze

before considering implementation complete.

Code should be formatted automatically rather than manually aligned.

Do not commit intentionally unformatted Dart code.

## 4. Naming Conventions

Use Dart naming conventions.

### Classes

Use PascalCase.

Examples:

class CustomerRepository {}

class OrderDetailsCubit {}

class StorageRecord {}

### Variables

Use lowerCamelCase.

Examples:

final customerName = '';

final orderItems = <OrderItem>[];

### Methods

Use lowerCamelCase.

Examples:

Future<Order> createOrder() {}

Future<void> recordPayment() {}

### Constants

Use lowerCamelCase for local constants.

Example:

const defaultPageSize = 50;

For compile-time static constants:

static const defaultCurrency = 'EGP';

### Files

Use snake_case.

Examples:

customer_repository.dart
order_details_cubit.dart
storage_location_dao.dart
business_settings_page.dart

### Enums

Use PascalCase for enum type names.

Use lowerCamelCase for enum values.

Example:

enum OrderStatus {
  processing,
  ready,
  completed,
  cancelled,
}

Do not use uppercase enum values.

## 5. Boolean Naming

Boolean variables should clearly read as boolean values.

Prefer:

isActive
isPaid
isStored
hasCustomer
canComplete
requiresStorage

Avoid ambiguous names such as:

active
paid
stored
customer
complete

when their boolean nature is not immediately clear.

## 6. Null Safety

Use Dart null safety correctly.

Avoid unnecessary nullable values.

Prefer:

final Customer customer;

over:

final Customer? customer;

when the business rule guarantees that a Customer exists.

Do not use ! as a shortcut for proper null handling.

Avoid:

customer!.name

unless the invariant is guaranteed and documented by the surrounding logic.

Prefer explicit validation or safe handling.

## 7. Avoid Dynamic

Avoid dynamic unless there is a concrete technical reason.

Do not use dynamic to bypass type errors.

Prefer strongly typed models and parameters.

Bad:

dynamic result = repository.getOrder();

Preferred:

final Order result = await repository.getOrder();

## 8. Immutability

Prefer immutable objects.

Use final whenever reassignment is not required.

Domain entities should be designed with predictable state behavior.

Avoid mutable shared global state.

Do not expose mutable collections unnecessarily.

Prefer controlled modification rather than exposing internal mutable collections.

## 9. Collections

Use typed collections.

Preferred:

final customers = <Customer>[];

final payments = <Payment>[];

final orderItems = <OrderItem>[];

Avoid:

final customers = [];

when the intended type is not obvious.

Do not use loosely typed maps as substitutes for proper domain objects.

Avoid:

Map<String, dynamic>

for business entities.

## 10. Domain Models

Domain entities must represent business concepts clearly.

Do not place database-specific annotations inside Domain entities when the architecture does not require them.

Do not make Domain entities depend on:

- Drift
- SQLite
- Dio
- Retrofit
- Flutter UI

Domain models should remain infrastructure-independent.

## 11. Data Models

Data models may contain persistence-specific information where necessary.

Keep persistence concerns inside the Data layer.

Do not leak Drift table row objects into Presentation.

Do not expose DAO result types directly to Cubits or widgets.

Convert data into the appropriate Domain representation at the repository/data boundary.

## 12. Repository Interfaces

Repository contracts belong to the Domain layer.

Example:

abstract interface class CustomerRepository {
  Future<Customer> createCustomer(Customer customer);

  Future<Customer?> getCustomerById(String id);

  Future<List<Customer>> searchCustomers(String query);
}

Repository interfaces should express business operations rather than database implementation details.

Avoid methods such as:

Future<void> executeRawSql(String sql);

inside Domain repository contracts.

## 13. Repository Implementations

Repository implementations belong to the Data layer.

They are responsible for connecting Domain contracts to:

- Local data sources
- Remote data sources when implemented

Do not put UI logic inside repositories.

Do not put presentation state inside repositories.

Do not make repositories responsible for rendering.

## 14. DAOs

DAOs belong to the Data layer.

DAOs should be focused on database access.

Do not expose DAOs directly to Presentation.

Do not place business workflows inside DAOs.

DAOs should not decide whether an Order is allowed to become Completed.

That decision belongs to the appropriate business/domain layer.

## 15. Drift Code

Drift code must remain inside the Data layer.

Keep:

- Tables
- DAOs
- Database definitions
- Queries
- Drift-generated code

out of Domain and Presentation layers.

Do not write raw SQL in widgets or Cubits.

Use Drift's typed query mechanisms where possible.

Raw SQL may be used only when there is a concrete database requirement that is not reasonably supported by the normal Drift API.

## 16. Database Queries

Queries should be explicit and focused.

Avoid generic "query everything" abstractions.

Prefer purpose-specific queries.

Example:

Future<List<Order>> getOrdersForCustomer(String customerId)

instead of exposing arbitrary filtering infrastructure everywhere.

Queries should use indexes appropriately when required by the approved database design.

Do not add indexes simply because they seem useful without considering the approved database documentation.

## 17. Transactions

Transactions must be handled at the appropriate Data/Repository boundary.

When an operation modifies multiple related records, use an appropriate database transaction.

Example flow:

Begin Transaction
↓
Create Order
↓
Create OrderItems
↓
Create required Sync Operation
↓
Commit

Do not split a logically atomic business operation into independent database writes without a clear reason.

## 18. Money

Money must use integer minor units.

The application currency is:

EGP

Example:

100.50 EGP
→
10050

Do not use double as the authoritative representation of persisted money.

Avoid:

double total;

for financial persistence.

Use integer minor-unit representations consistently.

If a UI requires decimal display, convert the integer amount only at the presentation boundary.

## 19. UUIDs

Business entity identifiers must use UUIDs.

Identifiers are persisted as:

TEXT

Do not use auto-increment integers for business entity IDs.

Do not generate a new ID when updating an existing entity.

IDs must remain stable throughout the entity lifecycle.

## 20. Date and Time

Use appropriate typed date/time representations.

Do not store formatted user-facing date strings as the authoritative value.

Persist a stable machine-readable timestamp representation according to the approved database design.

Formatting belongs to the Presentation layer.

The stored value must not depend on the current locale.

## 21. User-Facing Strings

Do not scatter repeated hardcoded UI strings throughout the application.

Prefer centralized localization.

Business terminology must match the approved documentation.

Do not invent alternative terminology.

## 22. Arabic and RTL

The application is Arabic-first.

All screens must support RTL correctly.

Do not manually reverse layouts using arbitrary left/right positioning.

Prefer directional properties.

Use:

EdgeInsetsDirectional
AlignmentDirectional
BorderRadiusDirectional

where appropriate.

Avoid hardcoded:

EdgeInsets.only(left: ...)

when the spacing is direction-dependent.

## 23. Typography

Use the approved typography system.

Primary Arabic font:

IBM Plex Sans Arabic

Do not define arbitrary font families inside individual widgets.

Typography should come from the centralized Theme/design system where possible.

## 24. Colors

Use centralized theme colors.

Do not introduce arbitrary color values inside feature widgets unless the design system explicitly requires a one-off value.

Prefer theme-provided colors.

Avoid:

Color(0xFF123456)

inside arbitrary widgets.

If a new color is genuinely required, update the appropriate design-system/theme definition rather than hiding it inside a feature.

## 25. Spacing

Use the approved spacing system where available.

Do not create arbitrary spacing values repeatedly across screens.

Avoid unnecessary values such as:

Padding(
  padding: EdgeInsets.all(13),
)

when an approved spacing token exists.

Consistency is more important than micro-adjustments.

## 26. Widgets

Widgets should have one clear responsibility.

Avoid extremely large widgets that contain:

- Data access
- Business rules
- Navigation
- Validation
- Rendering
- Persistence

all in one class.

Extract focused widgets when there is a concrete readability or reuse benefit.

Do not create hundreds of tiny widgets without a real need.

## 27. Build Methods

Keep build() readable.

Avoid placing large business algorithms inside build().

Do not perform database writes inside build().

Do not trigger side effects directly from build().

The build method should primarily describe UI.

## 28. Widget State

Use local widget state only for genuinely local UI concerns.

Examples:

- Expanded/collapsed UI
- Temporary text field state
- Tab selection
- Visual toggles

Business state belongs to Bloc/Cubit or the appropriate application state layer.

Do not store persistent business state inside StatefulWidget fields.

## 29. Bloc/Cubit

The project uses Bloc/Cubit.

Use Cubits or Blocs for feature state.

Do not introduce another state-management library.

A Cubit should coordinate presentation state and invoke domain/repository operations.

A Cubit must not:

- Execute SQL
- Access Drift directly
- Render UI
- Contain arbitrary database queries

## 30. Cubit Responsibilities

A Cubit may:

- Load feature data
- Invoke repository operations
- Handle success
- Handle validation failures
- Emit loading state
- Emit error state
- Coordinate approved presentation workflows

A Cubit should not become a replacement for the Domain layer.

Avoid placing complex business rules directly inside Cubits when they belong to the Domain.

## 31. State Classes

States should be predictable and easy to test.

Where practical, represent:

- Initial
- Loading
- Success
- Empty
- Error

Use feature-specific state data.

Do not create a single global state object containing every application feature.

## 32. Events and Actions

For Cubits, use clear method names.

Examples:

loadOrders()
createOrder()
recordPayment()
storeOrderItem()
addExpense()
updateExpenseCategory()

Methods should describe an actual user/business action.

Avoid vague names:

doAction()
process()
handle()
run()

unless the context makes the meaning explicit.

## 33. Navigation

Navigation must be centralized.

Do not perform arbitrary navigation logic throughout business classes.

UI code may request navigation as part of a user action.

Business/domain code must not depend on Navigator or BuildContext.

Do not create multiple routing systems.

## 34. Dependency Injection

Use:

get_it

as the centralized dependency injection mechanism.

Prefer constructor injection.

Example:

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repository);

  final OrderRepository _repository;
}

Register dependencies centrally.

Do not call GetIt.instance repeatedly inside business logic when constructor injection is practical.

Avoid service-locator abuse.

## 35. Networking

Use:

- Dio
- Retrofit

Networking belongs to the Data/Infrastructure side of the architecture.

Do not call Dio from widgets.

Do not call Retrofit clients from Domain.

Do not expose HTTP response objects to Presentation.

Remote API models should remain isolated from Domain models.

## 36. Network Errors

Network errors must be translated into application-level errors before reaching Presentation.

Do not expose raw Dio exceptions directly to users.

The exact error mapping should follow the centralized error strategy.

## 37. Offline-First

Local operations must not require network availability.

When a workflow is local-first:

UI
↓
Cubit
↓
Repository
↓
Local Data Source
↓
SQLite

Network synchronization is separate.

Do not introduce network calls into local workflows simply to validate or persist data.

## 38. Synchronization

Synchronization execution is deferred.

The codebase may contain synchronization-ready infrastructure.

Do not implement advanced synchronization behavior before the synchronization phase is explicitly started.

Do not add:

- Real-time sync
- Background sync
- CRDTs
- Advanced conflict resolution
- Distributed locking

without approval.

## 39. Logging

Use structured logging where logging is required.

Do not use uncontrolled print() statements for production logging.

Avoid logging:

- Sensitive information
- Full customer data
- Payment details
- Secrets
- Authentication tokens
- Database credentials

Debug logs must not become production behavior.

## 40. Secrets and Configuration

Never hardcode secrets.

Do not commit:

- API keys
- Passwords
- Tokens
- Private credentials

Configuration values should use the approved configuration mechanism.

Do not invent a new environment/configuration framework without need.

## 41. Comments

Write comments only when they provide useful context.

Good comments explain:

- Why a non-obvious decision exists
- Why a workaround is required
- Why a constraint exists

Avoid comments that merely repeat the code.

Bad:

// Set customer name
customerName = value;

Good:

// Preserve the historical customer snapshot required by invoice rendering.

## 42. TODO

Do not leave vague TODO comments.

Bad:

// TODO: fix this later

Preferred:

// TODO(PROJECT-123): Replace temporary adapter when remote sync is implemented.

Only add TODOs for real future work.

Do not use TODOs as a substitute for completing required work.

## 43. Exception Handling

Do not use broad exception handling unnecessarily.

Avoid:

try {
  ...
} catch (_) {}

Silent failures are prohibited.

Catch errors when they can be:

- Handled
- Translated
- Logged appropriately
- Presented meaningfully
- Used to maintain a valid state

## 44. Error Propagation

Errors should move through the correct architectural boundaries.

Typical flow:

Infrastructure Error
↓
Data Layer Error
↓
Repository/Application Error
↓
Cubit State
↓
UI Message

Do not leak infrastructure-specific exceptions into the Domain unless explicitly required.

## 45. Validation

Critical business validation must not exist only in widgets.

UI validation improves user experience.

Domain/business validation protects correctness.

Example:

The UI may prevent entering an invalid payment amount.

The business layer must still reject a payment greater than the remaining amount.

## 46. Forms

Forms should be clear and focused.

Use appropriate controllers and validation.

Dispose controllers correctly.

Do not place database logic inside form widgets.

Do not make a form responsible for calculating authoritative financial values.

## 47. Financial Calculations

Financial calculations must use exact monetary values.

Do not rely on floating-point arithmetic for authoritative totals.

Order total:

Subtotal
-
Discount
+
Delivery Fees
=
Total

Tax is not an active V1 workflow.

Do not implement active Tax calculation.

## 48. Order Number

Order numbers follow:

YY-XXX

Do not implement:

YYMMDD-XXX

Do not change the approved format.

## 49. Order Status

Use the approved status model and terminology.

UI terminology includes:

- قيد التجهيز
- جاهز
- مكتمل
- ملغي

Status transitions must be enforced by approved business rules.

Do not create new statuses without documentation approval.

## 50. Storage Rules

Storage operates on OrderItems.

Do not treat Order as the physical storage unit when the business rule requires OrderItem-level tracking.

A new destination must be:

- Active
- Compatible with the OrderItem Item Type

Do not allow inactive locations to be selected as new destinations.

## 51. Expense Rules

Expenses are independent financial transactions.

Do not represent an Expense as a Payment.

Expense Categories are master data.

Inactive categories remain available for historical references where required.

The category:

أخرى

requires:

Expense Name

## 52. Payment Rules

Payments belong to Orders.

A Payment must not exceed the remaining amount.

Do not bypass this validation in the UI or Data layer.

Payment history must remain meaningful.

## 53. Historical Data

Do not destructively modify historical transaction meaning.

Avoid deleting master data when historical references depend on it.

Prefer activation/deactivation where required by the business rules.

Do not silently rewrite historical financial records.

## 54. Database Migration Safety

Database migrations must be deliberate.

Do not:

- Drop production tables casually
- Rename columns without migration
- Remove historical data without approval
- Change identifier types casually
- Change money representation without a migration strategy

Every schema change must be reflected in the database documentation.

## 55. Generated Files

Do not manually edit generated files unless the generation workflow explicitly requires it.

For generated Drift or Retrofit code:

- Modify the source
- Run the appropriate generator
- Verify generated output

Do not treat generated code as the primary source.

## 56. Code Generation

Code generation is allowed only for approved technologies.

Current approved generation-related technologies include:

- Drift
- Retrofit where required

Do not introduce additional code-generation frameworks without approval.

## 57. Package Management

Before adding a package:

1. Check whether Flutter/Dart already provides the required capability.
2. Check whether an approved existing package already provides it.
3. Check whether the package is actually necessary.
4. Confirm that adding it does not violate architecture or project decisions.

Do not add packages simply for convenience.

Do not replace approved packages without a technical decision.

Current approved key packages include:

- get_it
- Dio
- Retrofit
- Drift
- Bloc/Cubit

## 58. Package Addition Rule

Adding a package that affects architecture, persistence, networking, state management, routing, authentication, or security requires explicit approval.

Do not silently replace:

- get_it
- Drift
- Bloc/Cubit
- Dio
- Retrofit

with alternatives.

## 59. Testing Code Standards

Tests should be readable and deterministic.

Avoid tests that depend on:

- Real internet access
- Current time without control
- Random data without deterministic seeds
- External services
- Production databases

Use controlled test data.

Test names should clearly describe behavior.

Example:

test(
  'rejects payment greater than remaining amount',
  () async {
    ...
  },
);

## 60. Test Organization

Organize tests consistently with the application structure.

Examples:

test/
├── domain/
├── data/
├── features/
└── integration/

Use the project structure as the guide.

Do not place all tests in one large directory.

## 61. Business Rule Tests

High-risk business rules must have automated tests.

Prioritize:

- Pricing
- Discounts
- Delivery fees
- Payment validation
- Remaining amount
- Order status
- Completion conditions
- Storage compatibility
- Expense validation
- Net Profit

## 62. Widget Testing

Important user-facing workflows should have widget tests where appropriate.

Prioritize:

- Forms
- Validation
- Loading states
- Error states
- Empty states
- Important actions

Do not attempt to test every visual pixel unless required.

## 63. Integration Testing

Integration tests should validate important end-to-end workflows.

Examples:

Customer
→
Order
→
OrderItem
→
Payment
→
Storage
→
Completion

and:

Expense
→
Report
→
Net Profit

## 64. Static Analysis

Before completing meaningful implementation work, run:

flutter analyze

Resolve relevant warnings and errors.

Do not ignore analyzer output simply to make the build pass.

## 65. Formatting

Run:

dart format .

or the project-approved equivalent.

Code should remain consistently formatted.

## 66. Test Execution

Run:

flutter test

after meaningful implementation changes.

Run focused tests during development and the full suite before phase completion.

## 67. Build Verification

At relevant milestones, verify:

flutter build

using the target platform appropriate to the project.

The exact release target is determined by the project deployment requirements.

## 68. Change Discipline

Changes should be focused.

Avoid combining unrelated work.

A change implementing Customers should not also refactor unrelated Reports code unless there is a concrete dependency.

Prefer small reviewable changes.

## 69. Refactoring

Refactoring is allowed when it improves correctness or maintainability.

Do not perform broad refactoring during feature implementation without need.

Before refactoring:

- Confirm behavior
- Add/verify tests
- Make focused changes
- Re-run affected tests

Do not refactor merely for stylistic preference.

## 70. Duplication

Avoid meaningful duplication.

But do not create abstractions solely to eliminate a few similar lines.

Use the rule:

Prefer duplication over premature abstraction.

Create shared code when:

- Behavior is genuinely shared
- The abstraction has a clear responsibility
- The abstraction improves maintainability

## 71. Generic Utilities

Do not create generic utility classes that become dumping grounds.

Avoid:

Utils
Helpers
CommonManager
AppManager
GeneralService

when the responsibility is unclear.

Prefer domain-specific utilities with clear ownership.

## 72. Global State

Avoid mutable global state.

Allowed global infrastructure includes controlled services such as:

- get_it
- Theme configuration
- Localization configuration

Business state should remain feature-owned.

## 73. Async Code

Use async/await consistently.

Prefer:

final order = await repository.getOrder(id);

over deeply nested Future chains when async/await improves readability.

Handle errors intentionally.

Do not ignore returned Futures.

## 74. Streams

Use streams when the underlying data genuinely represents ongoing asynchronous changes.

Do not convert every repository method into a stream without a real requirement.

For one-time operations, use Futures.

## 75. Performance

Prefer correctness before optimization.

Avoid premature optimization.

Performance-sensitive areas may include:

- Large Order lists
- Storage lists
- Customer search
- Reports
- Database queries

Use pagination, indexing, or optimized queries when supported by actual requirements and database design.

Do not add complex caching without evidence of need.

## 76. UI Performance

Avoid unnecessary rebuilds.

Use appropriate Bloc/Cubit selectors or widget composition when needed.

Do not optimize every widget preemptively.

Keep expensive operations out of build().

## 77. Accessibility

Where appropriate, provide:

- Clear labels
- Adequate touch targets
- Meaningful semantic descriptions
- Readable typography
- Clear validation feedback

Accessibility improvements must not conflict with the approved UI design.

## 78. Security Basics

Never expose secrets in source code.

Never log credentials.

Never trust client-side validation as a security boundary.

When backend implementation begins, server-side validation remains authoritative.

The local-first V1 application must still protect sensitive local data according to the approved security requirements.

## 79. Data Integrity

Never sacrifice data integrity for UI convenience.

If a business operation requires a transaction, use a transaction.

If a relationship requires a foreign key, preserve the relationship.

If a historical record must remain available, do not destructively delete it.

## 80. Documentation Alignment

When implementation behavior changes, verify whether documentation needs updating.

Code must not silently become a new source of truth.

If a change affects:

- Product behavior
- Business rules
- Domain model
- Database
- Architecture
- Technical decisions

the relevant documentation must be updated before or alongside implementation.

## 81. AI Coding Agent Rules

AI coding agents must:

- Read relevant documentation before coding.
- Follow the current implementation phase.
- Follow the approved architecture.
- Reuse existing implementations where appropriate.
- Avoid speculative features.
- Avoid speculative abstractions.
- Avoid package substitutions.
- Avoid undocumented business behavior.
- Avoid undocumented database changes.
- Avoid undocumented navigation changes.
- Add tests for important business behavior.
- Run analyzer and tests after meaningful changes.

AI agents must not treat generated code as permission to change requirements.

## 82. Before Creating a New Class

Before creating a new class, ask:

1. Is the responsibility new?
2. Does an existing class already own this responsibility?
3. Which layer should own it?
4. Which feature should own it?
5. Is the abstraction actually necessary?
6. Will the new class improve clarity?

If the answer is unclear, do not create the class automatically.

## 83. Before Creating a New Package

Before adding a package, ask:

1. Is the functionality already provided by Flutter/Dart?
2. Is there an approved package already available?
3. Is the package required by an approved technical decision?
4. Does it affect architecture?
5. Does it introduce code generation?
6. Does it create long-term maintenance cost?

If the package affects architecture or a major technical decision, request approval before adding it.

## 84. Before Creating a New Database Table

A new database table must not be created solely because it makes implementation easier.

First verify:

- Is the entity approved?
- Is the relationship approved?
- Is the table documented?
- Does the Domain require it?
- Does the Database Design require it?

If not, stop and request a documentation decision.

## 85. Before Changing a Database Table

Before changing a table:

- Check database documentation.
- Check relationships.
- Check constraints.
- Check indexes.
- Check seed data.
- Check repository usage.
- Check migrations.
- Check tests.

Do not make schema changes casually.

## 86. Before Changing a Business Rule

Business rules must not be changed inside implementation code without documentation approval.

If a requirement appears ambiguous:

Stop.

Identify the ambiguity.

Request clarification.

Do not silently choose behavior that changes the business meaning.

## 87. Before Completing a Feature

A feature is not complete when its screen exists.

Verify:

- UI
- State management
- Domain behavior
- Repository
- Persistence
- Validation
- Error handling
- Loading state
- Empty state
- Tests
- Offline behavior where applicable
- Documentation alignment

## 88. Final Quality Checklist

Before considering code ready:

### Architecture

- Correct layer
- Correct dependency direction
- No infrastructure leakage
- No unnecessary abstraction

### Code

- Formatted
- Analyzer clean
- Readable
- Typed
- Null-safe
- No dead code

### Database

- Correct tables
- Correct relationships
- Correct constraints
- Correct indexes
- Correct transactions
- Correct identifiers
- Correct money representation

### Business

- Approved rules enforced
- No invented behavior
- No hidden assumptions

### UI

- Arabic-first
- RTL
- Approved terminology
- Approved theme
- Correct states

### Testing

- Relevant tests added
- Tests pass
- Critical business rules covered

### Scope

- No unauthorized feature
- No unauthorized package
- No unauthorized table
- No unauthorized architecture

## 89. Final Rule

Write code that is:

Simple enough to understand.

Explicit enough to trust.

Structured enough to maintain.

Testable enough to verify.

Consistent enough to scale.

The implementation must follow the approved project documentation.

Do not add complexity because it is fashionable.

Do not add features because they are useful.

Do not add abstractions because they look architecturally sophisticated.

Do not bypass business rules because the UI makes it convenient.

Do not bypass the database because a mock is easier.

Do not bypass tests because the feature appears simple.

Correctness and maintainability take priority over implementation speed.