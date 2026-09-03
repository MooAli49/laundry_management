# Testing Strategy

## 1. Purpose

This document defines the testing strategy for the Laundry Management System.

The goal is to ensure that the implementation is:

- Correct
- Predictable
- Maintainable
- Safe for business-critical operations
- Consistent with the approved architecture
- Safe to extend without breaking existing behavior

Testing must validate both technical behavior and the business rules defined by the project.

The testing strategy applies to the current local-first Flutter implementation and defines the future testing approach for networking and synchronization.

---

## 2. Testing Principles

The project follows these principles:

1. Test business-critical behavior first.
2. Prefer fast deterministic tests.
3. Keep tests independent from external services whenever possible.
4. Test through architectural boundaries.
5. Do not test implementation details unnecessarily.
6. Use real database behavior when database behavior itself is being tested.
7. Use fakes/mocks only where they provide a clear testing boundary.
8. Do not require the backend for normal unit tests.
9. Preserve the offline-first architecture in tests.
10. Every important business rule should have an executable test.
11. Regression tests should be added when a bug is discovered.
12. Tests must remain understandable to another developer or coding agent.

---

## 3. Testing Pyramid

The project should follow a testing pyramid:

Unit Tests
↓
Repository / Data Layer Tests
↓
Cubit Tests
↓
Widget Tests
↓
Integration Tests

The majority of tests should be fast unit and data-layer tests.

Integration tests should cover important end-to-end workflows rather than every possible combination.

---

## 4. Current Testing Scope

The current implementation phase is local-first.

Therefore, priority is given to:

- Domain/business rules
- Database behavior
- Data Layer behavior
- Repository behavior
- Cubit state transitions
- Important UI behavior
- Local transactional behavior

Networking and synchronization tests are documented now but implemented later when those components are introduced.

---

## 5. Test Organization

Tests should follow the project structure.

A feature-oriented structure should be preferred.

Conceptually:

test/
├── core/
│   ├── ...
│
├── features/
│   ├── customers/
│   │   ├── ...
│   ├── orders/
│   │   ├── ...
│   ├── payments/
│   │   ├── ...
│   ├── storage/
│   │   ├── ...
│   └── expenses/
│       ├── ...

The exact directory structure must remain consistent with `project-structure.md`.

Do not create a completely separate testing architecture that duplicates the application architecture.

---

## 6. Test Naming

Test names must clearly describe behavior.

Prefer:

`should_create_customer_with_valid_data`

over:

`testCustomer1`

Prefer:

`should_reject_expense_when_amount_is_zero`

over:

`expenseValidationTest`

A test name should communicate:

- What is being tested
- Under what condition
- What should happen

---

## 7. Arrange / Act / Assert

Tests should generally follow:

Arrange
↓
Act
↓
Assert

Example:

Arrange:
Create valid customer data.

Act:
Create customer through repository.

Assert:
Customer exists with the expected values.

Avoid unnecessarily complicated test setup.

---

## 8. Unit Tests

Unit tests should validate isolated logic.

Appropriate candidates include:

- Domain rules
- Validators
- Value calculations
- Utility functions
- Business state transitions
- Model conversions where meaningful
- Small deterministic components

Unit tests should be:

- Fast
- Deterministic
- Independent
- Easy to understand

---

## 9. What Should Not Be Unit Tested

Do not create meaningless tests for trivial framework-generated behavior.

Examples:

- Testing that a constructor assigns a field when no behavior exists.
- Testing generated serialization code line-by-line.
- Testing Flutter framework behavior.
- Testing a getter that has no business significance.

Testing effort should focus on behavior and risk.

---

## 10. Business Rule Testing

Business rules are high-priority test targets.

Examples include:

- Order calculations
- Payment calculations
- Outstanding amount
- Expense validation
- Expense category rules
- Active/inactive constraints
- Required fields
- Custom expense category behavior
- Storage-related rules
- Order state transitions
- Customer-related constraints

Every business rule that can cause incorrect real-world behavior should have an appropriate automated test.

---

## 11. Money Testing

Financial calculations must be tested carefully.

The system represents monetary values using integer minor units.

Therefore tests must use integer values.

Example:

1000 piastres

must remain:

1000

Tests must verify:

- Addition
- Subtraction
- Totals
- Outstanding amounts
- Payments
- Expenses
- Other financial calculations

Do not use floating-point assertions for financial persistence or domain calculations.

---

## 12. Money Edge Cases

Financial tests should include:

- Zero amount
- Smallest valid amount
- Large valid amount
- Exact payment
- Partial payment
- Multiple payments
- Payment exceeding outstanding amount where prohibited
- Invalid negative values where prohibited

The expected behavior must follow the approved business rules.

---

## 13. Date Testing

Date-only business values must be tested as dates rather than timestamps.

Tests should verify that date handling does not accidentally shift the business date because of timezone conversion.

Important candidates include:

- Expense Date
- Other date-only business fields

Tests should distinguish between:

Date-only values

and:

Date-time values.

---

## 14. Identifier Testing

The system uses stable UUID-based identifiers.

Tests should verify that:

- New entities receive valid stable IDs.
- IDs remain unchanged when entities are updated.
- IDs are preserved when data moves between layers.
- IDs are not regenerated during normal updates.

Future synchronization tests must also verify that retries preserve the same identifiers.

---

## 15. Database Tests

The database layer requires dedicated tests.

Database tests should validate:

- Table creation
- Required columns
- Constraints
- Unique constraints
- Foreign keys
- Indexes where behaviorally relevant
- Insert
- Update
- Read
- Deactivation
- Transaction behavior
- Relationship integrity

Database tests should use the real database implementation or the closest supported test database environment.

Do not replace all database tests with mocks.

---

## 16. Database Constraint Testing

Important database constraints must have tests.

Examples include:

- Required values
- Unique values
- Foreign key relationships
- Valid enum/status values where enforced
- Active/inactive behavior where relevant
- Monetary representation
- Stable identifiers

If a constraint exists specifically to protect data integrity, at least one test should verify that it actually protects the data.

---

## 17. Transaction Testing

Transactions are critical for operations that modify multiple pieces of related data.

Tests should verify:

Successful transaction:
All required changes are committed.

Failed transaction:
Required changes are rolled back.

Example:

Order creation
+
Order items
+
Required related records

must not leave partial data when the transaction fails.

The exact transaction boundaries must follow the approved database/data-layer documentation.

---

## 18. Repository Tests

Repositories should be tested as the application-facing data boundary.

Repository tests should verify:

- Successful reads
- Successful writes
- Updates
- Deactivation
- Validation propagation
- Database errors
- Transaction behavior
- Correct mapping between layers where applicable

Repositories should not expose infrastructure-specific exceptions directly to Presentation.

---

## 19. Repository Test Philosophy

Repository tests should focus on observable behavior.

Avoid asserting every internal method call unless that interaction itself is a requirement.

Prefer:

"Creating an order persists the order and its items"

over:

"Repository called method X exactly once."

This keeps tests resilient to internal refactoring.

---

## 20. Data Source Tests

Data sources should be tested where they contain meaningful behavior.

Local data sources should verify:

- Correct database queries
- Correct inserts
- Correct updates
- Correct reads
- Correct query parameters
- Correct transaction interaction

Remote data sources will be tested when networking is implemented.

---

## 21. Cubit Tests

The project uses Cubit rather than Bloc unless a future explicit decision changes this.

Cubit tests should verify state transitions.

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

The exact state names must follow the implementation.

---

## 22. Cubit Test Responsibilities

Cubit tests should verify:

- User action triggers the correct repository operation.
- Loading state is emitted where appropriate.
- Successful repository results produce the expected state.
- Errors produce the expected failure state.
- Existing data is preserved where required.
- Refresh/reload behavior works correctly.
- Empty states are handled correctly.

Cubit tests should not verify database SQL or HTTP behavior.

Those concerns belong to lower layers.

---

## 23. Cubit and Offline-First

Cubit tests must preserve the offline-first architecture.

A Cubit should be able to complete a normal local workflow without a network dependency.

For example:

Create Customer
↓
Cubit
↓
Repository
↓
Local Database

The Cubit test should not require Dio or Retrofit.

---

## 24. Widget Tests

Widget tests should verify important UI behavior.

Examples:

- Correct rendering of states
- Loading state
- Empty state
- Error state
- Form validation feedback
- Button enabled/disabled behavior
- Navigation triggers
- User interaction
- Important Arabic UI content where relevant

Widget tests should not attempt to test the entire application through every widget.

Focus on meaningful user-facing behavior.

---

## 25. Arabic UI Testing

The application UI is Arabic-first.

Important widget tests should verify that:

- Arabic labels are rendered correctly where required.
- RTL layout behaves correctly.
- Important actions remain understandable.
- Text alignment is appropriate.
- Numeric values remain readable.
- Dates and monetary values are displayed according to the approved design/localization rules.

Do not hardcode English assumptions into tests for Arabic-first screens.

---

## 26. RTL Testing

Important screens should have tests for RTL-sensitive behavior where layout correctness matters.

Examples:

- Navigation
- Forms
- Tables/lists
- Action buttons
- Dialogs
- Detail screens
- Financial values

The goal is not to test Flutter's RTL engine itself.

The goal is to ensure the application's layout behaves correctly under RTL.

---

## 27. Form Testing

Forms should test:

- Required fields
- Invalid values
- Valid values
- Boundary values
- Submission behavior
- Error presentation
- Reset behavior where applicable

Examples include:

Customer form

Order form

Payment form

Expense form

Expense Category form

The exact validation rules must follow the business rules documentation.

---

## 28. Empty State Testing

Important screens should have explicit tests for empty data.

Examples:

- No customers
- No orders
- No payments
- No expenses
- No expense categories
- No storage records

An empty state is a valid application state, not an error.

---

## 29. Error State Testing

Tests should distinguish between:

Empty data

and:

Failure to load data.

For example:

No customers
≠
Customer database query failed.

The UI should represent these states differently where the design requires it.

---

## 30. Loading State Testing

Loading states should be tested where asynchronous repository operations exist.

Tests should verify:

- Loading starts appropriately.
- User cannot accidentally trigger duplicate operations where prohibited.
- Success replaces loading.
- Failure replaces loading.
- Existing data is preserved where appropriate.

---

## 31. Integration Tests

Integration tests should validate complete user workflows.

Examples:

Create Customer
→
Customer appears in list

Create Order
→
Order appears in orders list

Create Payment
→
Outstanding amount updates

Create Expense
→
Expense appears correctly

Create Expense Category
→
Category becomes available according to business rules

Storage workflow
→
Expected storage state is reflected

The exact workflows must follow the approved requirements and Figma flows.

---

## 32. Integration Test Scope

Do not attempt to cover every UI combination with integration tests.

Integration tests should focus on:

- Critical workflows
- High-risk business operations
- Cross-feature interactions
- Database persistence
- Navigation across important workflows
- Regression-prone scenarios

---

## 33. Critical Workflow Priority

Testing priority should generally follow business risk.

Highest priority:

1. Orders
2. Payments
3. Financial calculations
4. Storage
5. Customers
6. Expenses
7. Expense Categories

The exact priority may be adjusted if implementation or business requirements identify another higher-risk area.

---

## 34. Order Testing

Order tests should cover important order behavior.

Examples include:

- Creating an order
- Adding items
- Updating items
- Removing items where supported
- Calculating totals
- Updating order status
- Expected pickup behavior
- Customer association
- Storage-related state
- Persistence

The exact rules must follow `orders.md` and the business rules.

---

## 35. Payment Testing

Payment tests should cover:

- Valid payment
- Partial payment
- Full payment
- Multiple payments
- Outstanding calculation
- Invalid payment values
- Payment persistence
- Order/payment relationship

Financial precision must be preserved.

---

## 36. Customer Testing

Customer tests should cover:

- Creating a customer
- Updating customer information
- Searching/filtering where implemented
- Active/inactive behavior
- Order relationship
- Validation rules

The exact behavior must follow `customers.md`.

---

## 37. Expense Testing

Expense tests should cover:

- Creating an expense
- Amount validation
- Expense date
- Category selection
- Custom category behavior
- Notes where applicable
- Persistence
- Expense list behavior

The exact rules must follow the approved business rules.

---

## 38. Expense Category Testing

Expense Category tests should cover:

- Creating a category
- Duplicate prevention
- Active/inactive behavior
- Custom category rules
- Category usage by expenses
- Persistence

The implementation must respect the approved constraints.

---

## 39. Storage Testing

Storage tests should cover the approved storage workflow.

Important areas include:

- Assigning items to storage
- Storage status
- Order/storage relationship
- Updating storage information
- Retrieval/read behavior
- Persistence

The exact behavior must follow the approved domain and orders/storage documentation.

---

## 40. Dashboard Testing

Dashboard tests should focus on meaningful behavior.

Examples:

- Correct display of key totals
- Correct empty states
- Correct local data aggregation
- Correct navigation actions
- Correct loading/error states

Dashboard tests should not duplicate every underlying feature test.

The underlying repositories/business logic should already be tested separately.

---

## 41. Search and Filtering

Search/filter behavior should be tested where implemented.

Tests should verify:

- Exact matches
- Partial matches where supported
- Empty query behavior
- No results
- Multiple results
- Case behavior where relevant
- Arabic text behavior where relevant

Search tests should use realistic business data.

---

## 42. Pagination

If pagination is implemented later, it should have dedicated tests.

Tests should cover:

- First page
- Next page
- Last page
- Empty page
- Duplicate records across pages
- Loading additional data
- Error while loading additional data

Do not add pagination tests if pagination is not part of the current implementation.

---

## 43. Test Doubles

The project may use:

- Fakes
- Mocks
- Stubs

depending on the boundary being tested.

Prefer simple fakes where behavior is more important than interaction verification.

Use mocks when verifying an important interaction is justified.

Do not introduce multiple mocking libraries unnecessarily.

---

## 44. Database vs Mocked Database

When testing business logic:

A fake repository/data source may be appropriate.

When testing repository/database behavior:

Use the actual database implementation or appropriate test database.

Do not mock the database in every test.

Otherwise, database query bugs can pass while the test suite remains green.

---

## 45. Network Testing

Networking tests are future scope.

When networking is implemented, tests should cover:

- Successful response
- Serialization
- HTTP errors
- Timeout
- Connectivity failure
- Validation errors
- Backend errors
- Retry behavior where applicable
- Date serialization
- Financial serialization

Normal unit tests must not require a live production backend.

---

## 46. Sync Testing

Synchronization tests are future scope.

They should cover:

- Local write creates sync operation
- Pending operation processing
- Successful synchronization
- Retryable failure
- Permanent failure
- Exponential backoff
- Operation ordering
- Idempotency
- Crash recovery
- Partial queue failure
- Duplicate prevention
- Recovery after connectivity restoration

---

## 47. Offline Testing

Offline behavior is a first-class requirement.

Important tests include:

### Offline Create

Create a record with no network.

Expected:

- Local record exists.
- UI reflects the record.
- Synchronization remains pending for the future sync phase.

### Offline Update

Update a record while offline.

Expected:

- Local state changes successfully.
- No data is lost because the network is unavailable.

### Network Recovery

When networking is eventually implemented:

- Pending operations become eligible for synchronization.
- Successful operations become Synced.
- Local state remains intact.

---

## 48. Failure Injection

Important infrastructure tests should simulate failures.

Examples:

- Database error
- Repository error
- Timeout
- Connectivity failure
- Backend validation failure
- Unexpected response

Tests should verify that the application fails safely.

A failure should not result in:

- Corrupted local state
- Partial transaction
- Unhandled exception reaching the UI
- Lost business data

---

## 49. Regression Tests

Every significant production or development bug should result in a regression test when practical.

The process is:

Bug discovered
↓
Fix implemented
↓
Regression test added
↓
Test suite passes

The test should reproduce the original failure before the fix where practical.

---

## 50. Test Data

Tests should use deterministic test data.

Avoid:

- Current time unless specifically testing time behavior
- Random IDs without controlled expectations
- Random financial values
- External network data
- Production database records

When IDs are required, use predictable test IDs where possible.

---

## 51. Test Isolation

Tests must not depend on execution order.

Each test should create or reset its required state.

A test must not assume that another test has already:

- Created a customer
- Created an order
- Added a category
- Inserted an expense
- Modified the database

Shared mutable state should be minimized.

---

## 52. Time-Dependent Tests

Time-dependent behavior should use controlled time where practical.

Avoid tests that fail simply because the test runs at:

- Midnight
- Month boundary
- Year boundary
- Daylight saving transition
- Different timezone

Date-only business values require especially careful test data.

---

## 53. Test Environment

Tests should run without requiring:

- Production backend
- Production database
- Internet access

unless a dedicated integration environment explicitly requires it.

The default test suite should be deterministic and runnable locally.

---

## 54. External Dependencies

The default test suite must not depend on:

- Supabase availability
- External HTTP services
- Production credentials
- User accounts
- External APIs

External integration tests may exist separately if required later.

---

## 55. Coverage

Code coverage is useful but should not become the only quality metric.

High coverage of meaningless code does not guarantee correctness.

Priority should be:

Business-critical behavior
+
Data integrity
+
Financial correctness
+
Important user workflows
+
Regression protection

Coverage targets may be established later when the implementation size and risk profile are clearer.

Do not add arbitrary coverage percentages without an explicit project decision.

---

## 56. Definition of a Good Test

A good test is:

- Deterministic
- Readable
- Focused
- Fast where possible
- Independent
- Behavior-oriented
- Stable during refactoring
- Meaningful if it fails

A test should help answer:

"What broke and why does it matter?"

---

## 57. Definition of a Bad Test

Avoid tests that:

- Depend on test execution order
- Depend on production services
- Assert irrelevant implementation details
- Duplicate dozens of equivalent cases
- Use random data unnecessarily
- Are difficult to understand
- Pass while the actual business behavior is broken
- Require manual intervention

---

## 58. AI Coding Agent Testing Rules

When implementing features, an AI coding agent must:

- Add tests for meaningful business behavior.
- Follow the existing test structure.
- Reuse existing test utilities when available.
- Test business-critical edge cases.
- Test repository behavior at the repository boundary.
- Test Cubits at the Cubit boundary.
- Test widgets only for meaningful user-facing behavior.
- Keep tests deterministic.
- Avoid external dependencies in unit tests.
- Preserve offline-first behavior.
- Add regression tests for fixed bugs.
- Avoid testing implementation details unnecessarily.
- Avoid adding new testing packages without a clear requirement.

The coding agent must not:

- Delete failing tests just to make the suite pass.
- Weaken assertions without justification.
- Mock everything automatically.
- Add a mocking library automatically.
- Create tests that require production services.
- Skip business-rule tests because the UI works.
- Test Dio/Retrofit from Cubit tests.
- Test database SQL from widget tests.
- Introduce a separate testing architecture without approval.

---

## 59. Test-Driven Implementation Guidance

Full TDD is not mandatory for every feature.

However, business-critical logic should preferably be implemented with tests close to the time the logic is introduced.

A practical workflow is:

Understand requirement
↓
Identify business rules
↓
Write important test cases
↓
Implement behavior
↓
Run tests
↓
Add edge cases
↓
Integrate with higher layer

The goal is correctness, not adherence to a rigid development methodology.

---

## 60. Minimum Test Requirement Per Feature

A feature should not be considered complete without appropriate tests for:

- Main successful flow
- Important validation rules
- Important failure flow
- Important edge cases
- Persistence behavior where applicable

The exact number of tests depends on feature complexity.

Do not use a fixed number such as "five tests per feature" as a quality metric.

---

## 61. Definition of Done

A feature is considered sufficiently tested when:

- Important business rules have automated coverage.
- Main successful flow works.
- Important failure cases are covered.
- Important edge cases are covered.
- Database behavior is verified where relevant.
- Repository behavior is verified where relevant.
- Cubit state transitions are verified where relevant.
- Important UI behavior is verified where relevant.
- Tests are deterministic.
- Tests do not require production services.
- Existing tests still pass.
- No important regression has been introduced.

---

## 62. Final Testing Architecture

The approved testing approach is:

Domain / Business Rules
↓
Unit Tests

Database / Data Sources
↓
Database & Data Layer Tests

Repositories
↓
Repository Tests

Cubits
↓
Cubit Tests

Widgets
↓
Widget Tests

Critical User Workflows
↓
Integration Tests

Future Networking
↓
Network Tests

Future Synchronization
↓
Sync Tests

The central principle is:

Test each responsibility at the boundary where that responsibility belongs.

The test suite must protect the application's most important guarantees:

- Correct business behavior
- Correct financial calculations
- Correct data integrity
- Correct local-first behavior
- Correct user-facing workflows
- Safe failure handling
- Safe future synchronization

Testing must support the architecture rather than becoming a second architecture.