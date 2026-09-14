# Error Handling

## 1. Purpose

This document defines the error-handling architecture for the Laundry Management System.

The goal is to ensure that errors are:

- Consistent
- Predictable
- Understandable
- Safe for business-critical operations
- Properly isolated between architectural layers
- Suitable for the current local-first implementation
- Ready for future networking and synchronization

The error-handling architecture must prevent infrastructure-specific errors from leaking into the Presentation layer.

The approved V1 approach is:

Infrastructure Exceptions
↓
Repository Boundary
↓
Application Failures
↓
Cubit
↓
UI

The project will use exceptions internally where appropriate and convert them into application-level failures at the Repository boundary.

A large functional-programming-style Result/Either architecture is not required for V1.

---

## 2. Approved Error Pattern

The approved pattern is:

Database / Local Data Source
→ Exception

Remote Data Source
→ Exception

Other Infrastructure
→ Exception

Repository
→ Convert Exception to Failure

Cubit
→ Handle Failure

UI
→ Display appropriate localized message

Conceptually:

Database
↓
DriftException
↓
Repository
↓
DatabaseFailure
↓
Cubit
↓
Error State
↓
Arabic User-Facing Message

And in the future:

Dio / Retrofit
↓
Network Exception
↓
Repository
↓
NetworkFailure
↓
Cubit
↓
Error State
↓
Arabic User-Facing Message

---

## 3. Why Exceptions Internally

Exceptions are appropriate for infrastructure failures because libraries such as Drift, SQLite, Dio, and Retrofit already communicate failures through exceptions.

The project should not force every infrastructure operation into a custom Result/Either abstraction.

Instead:

- Infrastructure reports technical failure.
- Repository translates it.
- Application layers consume meaningful failures.

This keeps the implementation simple while preserving architectural boundaries.

---

## 4. Why Failures at the Repository Boundary

The Repository is the appropriate boundary for translating infrastructure errors into application-level failures.

Infrastructure knows:

- SQLite
- Drift
- Dio
- HTTP
- Serialization
- Network errors

The Presentation layer should not need to know any of these details.

The Repository therefore converts technical failures into stable application-level concepts.

For example:

DriftException

becomes:

DatabaseFailure

The Cubit does not need to know that Drift was involved.

---

## 5. Failure vs Exception

The project distinguishes between:

### Exception

A technical/infrastructure-level failure.

Examples:

- DriftException
- SQLite exception
- DioException
- Serialization exception

### Failure

An application-level representation of a problem that higher layers can safely understand.

Examples:

- ValidationFailure
- BusinessRuleFailure
- DatabaseFailure
- NetworkFailure
- SyncFailure
- UnexpectedFailure

The distinction is important.

Exceptions belong primarily below the Repository boundary.

Failures are what the application layer consumes.

---

## 6. Failure Base Type

The project should have a common application-level Failure abstraction.

Conceptually:

Failure

with specialized types such as:

- ValidationFailure
- BusinessRuleFailure
- DatabaseFailure
- NetworkFailure
- SyncFailure
- UnexpectedFailure

The exact Dart implementation should follow the project's established coding standards.

Do not create a large hierarchy of failure types unless there is a real application-level distinction.

---

## 7. ValidationFailure

`ValidationFailure` represents invalid input that can be corrected by the user or calling layer.

Examples:

- Required field missing
- Invalid amount
- Invalid date
- Invalid customer data
- Invalid order data
- Invalid expense data
- Invalid category data

A validation failure should provide enough structured information for the UI to show the correct message.

The UI should not need to parse technical exception messages to determine which field is invalid.

---

## 8. BusinessRuleFailure

`BusinessRuleFailure` represents a violation of a domain/business rule.

Examples may include:

- Invalid order state transition
- Payment violates an approved business rule
- Attempt to perform an operation on an inactive entity when prohibited
- Invalid relationship between entities
- Operation that is not allowed according to business rules

BusinessRuleFailure is different from generic validation.

Validation asks:

"Is this input structurally valid?"

Business rules ask:

"Is this operation allowed in the current business context?"

---

## 9. DatabaseFailure

`DatabaseFailure` represents a failure while accessing or modifying local persistent data.

Examples:

- SQLite failure
- Drift query failure
- Insert failure
- Update failure
- Transaction failure
- Constraint violation not already represented as a business failure

DatabaseFailure must not expose raw database implementation details to the UI.

For example, the UI should not receive a raw:

`DriftException`

Instead it receives:

`DatabaseFailure`

---

## 10. Database Constraint Errors

Database constraints are important data-integrity protections.

When a database constraint is violated, the Repository should translate the underlying technical exception into the most meaningful application-level Failure where the cause is known.

For example:

Unique constraint violation

may become:

`BusinessRuleFailure`

or:

`ValidationFailure`

depending on the actual business meaning.

Unknown constraint failures should safely become:

`DatabaseFailure`

Do not expose SQLite/Drift error text directly to users.

---

## 11. Transaction Failure

A failed transaction must be represented as a failure without leaving partial application state.

Example:

BEGIN TRANSACTION
↓
Update entity
↓
Create related record
↓
Failure
↓
ROLLBACK

The Repository should return an appropriate Failure.

The caller must not receive a false success state.

---

## 12. UnexpectedFailure

`UnexpectedFailure` is the fallback for errors that cannot be safely classified.

It exists to prevent unknown exceptions from leaking into Presentation.

Examples:

- Unexpected programming/runtime failure
- Unknown infrastructure error
- Unexpected response structure
- Unclassified exception

UnexpectedFailure should be logged appropriately for diagnosis.

The user-facing message should remain generic and safe.

---

## 13. NetworkFailure

`NetworkFailure` is future scope for the networking phase.

It represents failures such as:

- No internet connection
- Timeout
- DNS/connectivity issue
- Temporary network interruption

The exact classification should be implemented when Networking is introduced.

The local implementation must not depend on NetworkFailure.

---

## 14. RemoteServerFailure

Where useful, remote server failures may be represented separately from generic NetworkFailure.

Examples:

- HTTP 500
- Service unavailable
- Backend temporarily unavailable

The final classification should follow the backend API error contract.

Do not invent detailed HTTP error semantics before the backend contract exists.

---

## 15. RemoteValidationFailure

A backend may reject data because it violates server-side validation or business rules.

When networking is implemented, the Repository should translate the backend response into an appropriate application-level Failure.

The UI should not parse raw HTTP responses.

---

## 16. SyncFailure

`SyncFailure` is future scope.

It represents synchronization-specific failures.

Examples:

- Retryable synchronization failure
- Permanent synchronization failure
- Idempotency failure
- Dependency ordering failure
- Conflict requiring resolution

SyncFailure should remain distinct from ordinary local database failures.

---

## 17. Retryable vs Non-Retryable Errors

The system should distinguish between errors that may succeed later and errors that require correction.

### Retryable

Examples:

- Temporary network failure
- Timeout
- Temporary server failure

### Non-Retryable

Examples:

- Invalid data
- Business rule violation
- Unsupported operation
- Permanent backend rejection

This distinction becomes especially important when synchronization is implemented.

The exact retry classification must follow the Networking and Sync implementation contracts.

---

## 18. Error Propagation

Errors should move through the architecture as follows:

Infrastructure Exception
↓
Data Source
↓
Repository catches/translates
↓
Application Failure
↓
Cubit
↓
Presentation State
↓
Localized UI Message

The error should not bypass the Repository.

---

## 19. Data Source Responsibilities

Data Sources may throw infrastructure-level exceptions.

Local Data Sources may expose:

- DriftException
- SQLite-related exceptions
- Other database exceptions

Remote Data Sources may expose:

- DioException
- Serialization exceptions
- HTTP-related failures

Data Sources should not contain UI logic.

They should not display messages.

They should not directly manipulate Cubit state.

---

## 20. Repository Responsibilities

Repositories are responsible for translating technical errors into application-level failures.

The Repository should:

- Catch expected infrastructure exceptions.
- Convert them to appropriate Failure types.
- Preserve meaningful error information where useful.
- Prevent infrastructure details from leaking upward.
- Preserve domain/business semantics.
- Return or throw errors according to the approved repository contract.

The Repository should not:

- Show UI messages.
- Access BuildContext.
- Display dialogs/snackbars.
- Depend on widgets.
- Translate errors into Arabic strings.

---

## 21. Cubit Responsibilities

Cubit consumes application-level failures.

Cubit should:

- Execute repository operations.
- Catch/receive failures according to the repository contract.
- Emit appropriate error states.
- Preserve existing data when appropriate.
- Expose enough information for the UI to react.

Cubit should not:

- Catch DriftException directly.
- Catch DioException directly.
- Inspect SQL error strings.
- Build database-specific error messages.
- Translate infrastructure errors into Arabic text.

---

## 22. UI Responsibilities

The UI is responsible for presenting an appropriate user-facing representation of an error.

The UI should:

- Display localized messages.
- Display field-level validation when applicable.
- Display general errors when appropriate.
- Allow retry where meaningful.
- Preserve user-entered data where appropriate.

The UI should not:

- Inspect exception types from infrastructure.
- Parse technical error messages.
- Decide database/network semantics.
- Contain business validation rules.

---

## 23. User-Facing Error Messages

User-facing error messages must be Arabic-first.

Technical messages must never be displayed directly to the user.

Bad:

`SqliteException: UNIQUE constraint failed`

Good:

A localized Arabic message explaining the actual user-relevant problem.

The exact Arabic wording should be centralized through the project's localization system.

---

## 24. Error Message Localization

Error messages must not be hardcoded throughout widgets.

Use the centralized localization architecture.

Conceptually:

Failure
↓
Failure Code / Type
↓
Localization
↓
Arabic Message

This allows future language support without changing business logic.

---

## 25. Failure Codes

Where useful, failures should expose a stable code or structured identifier.

Example concepts:

- requiredField
- invalidAmount
- duplicateCustomer
- databaseUnavailable
- transactionFailed
- networkUnavailable
- requestTimeout
- unexpectedError

The exact final codes should be defined as implementation begins.

Do not use user-facing Arabic text as the machine-readable identifier.

---

## 26. Field-Level Validation

Validation failures should support field-specific information when required.

Conceptually:

ValidationFailure
- field: phoneNumber
- code: invalidFormat

The UI can then associate the error with the correct field.

The validation system must not require parsing free-form error strings.

---

## 27. Form Submission Errors

For a form:

User submits
↓
Validation
↓
If invalid:
ValidationFailure
↓
Display field errors

If valid:

Repository operation
↓
Success

or:

Failure
↓
Display appropriate general error

The UI should distinguish validation problems from persistence failures.

---

## 28. Preserving User Input

An error should not unnecessarily clear user-entered data.

For example:

User fills Expense form
↓
Submit
↓
Database failure
↓
Error displayed

The entered form values should remain available unless there is a specific reason to reset them.

---

## 29. Loading + Error State

When an operation fails after a loading state:

Loading
↓
Failure

The Cubit should not remain permanently in Loading.

The UI must always have a recoverable state.

---

## 30. Existing Data + Error

For screens displaying existing data, a refresh failure should not necessarily erase already loaded data.

Example:

Existing customer list
↓
Refresh
↓
Database error

The preferred behavior is to preserve usable existing data and expose the refresh error where appropriate.

The exact state model should follow the Cubit implementation.

---

## 31. Empty vs Error

The application must distinguish:

Empty State

from:

Error State

For example:

No orders exist

is not the same as:

Orders could not be loaded because the database failed.

These states must remain semantically distinct.

---

## 32. Logging

Errors should be logged at appropriate technical boundaries.

Logging should support debugging without exposing sensitive information.

Useful information may include:

- Failure type
- Operation name
- Entity type
- Entity ID where safe
- Error code
- Stack trace
- Timestamp

Do not log:

- Passwords
- Secrets
- Authentication tokens
- Unnecessary personal information
- Sensitive payment information

---

## 33. Logging Responsibility

Infrastructure-level exceptions may be logged where they are caught.

Repositories may log unexpected failures when converting them into application failures.

Cubits should generally not duplicate the same low-level exception logging.

The project should avoid producing multiple identical logs for a single failure.

---

## 34. Stack Traces

Unexpected technical failures should preserve stack trace information for diagnostics.

When converting an exception into a Failure, the implementation should retain diagnostic information where appropriate without exposing it to the user.

The Failure model should not force technical stack traces into UI code.

---

## 35. Error Reporting

A future production error-reporting service may be introduced later.

If introduced, it must remain behind an appropriate abstraction.

The application should not become tightly coupled to a specific error-reporting vendor.

The current V1 implementation does not require an external error-reporting service.

---

## 36. Error Handling in Database Operations

Database operations should follow:

Try operation
↓
If successful:
Return result

If known database exception:
Translate to DatabaseFailure or appropriate application Failure

If unexpected exception:
Translate to UnexpectedFailure

The Repository should prevent raw database exceptions from reaching Presentation.

---

## 37. Error Handling in Transactions

For transactional operations:

BEGIN
↓
Perform all required operations
↓
If success:
COMMIT

If expected failure:
ROLLBACK
↓
Return appropriate Failure

If unexpected failure:
ROLLBACK
↓
Log
↓
Return UnexpectedFailure or DatabaseFailure

The caller must never assume success if the transaction did not commit.

---

## 38. Error Handling in Queries

Read operations should distinguish between:

- Valid empty result
- Database failure

An empty list is normally a valid result.

A database exception is a failure.

Do not convert an empty query result into an error.

Do not convert a database failure into an empty list merely to make the UI appear successful.

---

## 39. Error Handling in Create Operations

For a create operation:

Validate input
↓
Apply business rules
↓
Persist locally
↓
Queue synchronization if applicable
↓
Return success

Possible failures:

- ValidationFailure
- BusinessRuleFailure
- DatabaseFailure
- UnexpectedFailure

The exact ordering follows the feature's implementation requirements.

---

## 40. Error Handling in Update Operations

For an update operation:

Validate
↓
Check business rules
↓
Persist update
↓
Queue synchronization if applicable
↓
Return success

Important rules:

- Do not silently ignore persistence failures.
- Do not report success before the local transaction succeeds.
- Preserve entity identity.
- Preserve existing data when the update fails.

---

## 41. Error Handling in Delete/Deactivate Operations

Where the domain supports deactivation instead of deletion:

- Validate operation.
- Apply business rules.
- Update active/inactive state.
- Persist successfully.
- Return success.

Do not physically delete an entity simply because deletion failed or because it is easier to implement.

The behavior must follow the approved domain/database rules.

---

## 42. Error Handling in Financial Operations

Financial operations require strict failure handling.

Examples:

- Payment
- Expense
- Order total
- Outstanding amount

A financial operation must not report success if persistence failed.

If a transaction involving financial data fails:

- Local financial state must remain consistent.
- Partial financial records must not remain.
- The UI must receive a meaningful Failure.

Financial values must remain integer minor units throughout the operation.

---

## 43. Error Handling in Order Operations

Order operations may involve multiple related entities.

For example:

Order
+
OrderItems
+
Storage-related records

If the operation is transactional, failure must roll back the required related changes together.

The Repository should expose one meaningful application-level Failure rather than leaking individual database exceptions.

---

## 44. Error Handling in Storage Operations

Storage operations must preserve data integrity.

If moving an item between storage locations fails:

- The item must not appear to have moved successfully.
- Partial state must not remain.
- The UI must receive a meaningful failure.
- Existing valid storage state must remain intact.

---

## 45. Error Handling in Dashboard

Dashboard aggregation failures should not be confused with empty business data.

If dashboard data cannot be loaded:

- Emit an appropriate failure state.
- Do not display fabricated zero values as if the database returned zero.

If the database legitimately returns zero:

- Display the valid zero state.

---

## 46. Error Handling in Search

Search errors should be handled differently from no results.

No matches:

Valid empty result.

Database/query failure:

Failure.

The UI should communicate these differently where required by the design.

---

## 47. Error Handling and Offline-First

Offline availability is not itself an application error during local operation.

If the application performs a local operation successfully while offline:

The operation is successful locally.

It should not be displayed as a generic error merely because synchronization has not occurred.

Future synchronization status must remain separate from business success.

---

## 48. Future Networking Error Flow

When networking is implemented:

Dio / Retrofit
↓
Technical Exception
↓
Remote Data Source
↓
Repository
↓
NetworkFailure / RemoteFailure / ValidationFailure / BusinessRuleFailure
↓
Cubit
↓
Localized UI

The Presentation layer must remain independent of Dio and Retrofit.

---

## 49. Future Sync Error Flow

When synchronization is implemented:

Sync Engine
↓
Remote Data Source
↓
Technical Error
↓
Classify
├── Retryable
├── Permanent
└── Conflict
↓
Sync Operation State
↓
Retry / Failed / Resolution

Synchronization errors should not automatically become ordinary UI errors.

Many synchronization failures are infrastructure/background concerns and may only need to update synchronization status.

---

## 50. Background Sync Errors

Future background synchronization should not interrupt the user's normal workflow with intrusive error dialogs for every failed attempt.

For example:

Temporary network failure

should normally remain a synchronization status rather than becoming a blocking application error.

User-facing sync messaging should be intentionally designed when background synchronization is implemented.

---

## 51. Error Recovery

Every user-visible error should have an appropriate recovery path when possible.

Examples:

ValidationFailure
→ Fix input

DatabaseFailure
→ Retry / continue later

NetworkFailure
→ Retry later

UnexpectedFailure
→ Retry / report problem

BusinessRuleFailure
→ Change the requested operation

Do not display an error without considering what the user can reasonably do next.

---

## 52. Retry

Retry should only be offered when retrying makes sense.

Appropriate:

Temporary database issue
Temporary network issue
Temporary server issue

Not appropriate:

Invalid amount
Invalid business rule
Duplicate data when duplication is prohibited

The exact retry behavior for synchronization follows `sync-implementation.md`.

---

## 53. Avoid Generic "Something Went Wrong"

A generic message may be used as the final fallback for unexpected failures.

However, it should not replace meaningful known errors.

For example:

Invalid payment amount

should not become:

Something went wrong.

Known failures should communicate a useful action whenever possible.

---

## 54. No Raw Technical Errors in UI

Never display raw:

- Exception messages
- Stack traces
- SQL statements
- HTTP response bodies
- DioException text
- SQLite errors

to users.

Technical details belong in logs/diagnostics.

---

## 55. Error Handling and Localization

All user-facing error messages must support:

- Arabic
- RTL
- Centralized localization
- Future additional languages

Error types and codes must remain language-independent.

---

## 56. Testing Error Handling

Error handling must be tested at each relevant boundary.

### Unit Tests

Test:

- Validation failures
- Business rule failures
- Failure mapping
- Error classification

### Repository Tests

Test:

- Database exception → DatabaseFailure
- Constraint exception → Appropriate Failure
- Unexpected exception → UnexpectedFailure

### Cubit Tests

Test:

- Failure → correct state
- Existing data preservation where required
- Loading → Failure transition

### Widget Tests

Test:

- Failure state rendering
- Localized message
- Retry action
- Field-level validation

### Integration Tests

Test:

- Failure during real workflow
- Recovery
- No partial data

---

## 57. Error Mapping Tests

Each important infrastructure exception mapping should have a test.

Example:

DriftException
→
Repository
→
DatabaseFailure

The test should verify that the infrastructure-specific exception does not escape the Repository.

---

## 58. Transaction Failure Tests

At least one test should verify:

Transaction begins
↓
Operation fails
↓
Rollback occurs
↓
No partial data remains

This is especially important for:

- Orders
- Order items
- Payments
- Storage operations
- Other multi-table operations

---

## 59. Error Handling and Test Doubles

Tests may use fakes or mocks to simulate failures.

Examples:

Fake repository returns DatabaseFailure.

Fake data source throws a DriftException.

Fake remote data source throws a network exception.

The purpose is to verify error propagation and recovery behavior.

---

## 60. AI Coding Agent Rules

When implementing error handling, the AI coding agent must:

- Follow the approved Exception → Failure pattern.
- Keep infrastructure exceptions below the Repository boundary.
- Convert known infrastructure errors into meaningful Failures.
- Keep Failure types application-level.
- Keep user-facing messages in localization.
- Preserve existing data when appropriate.
- Preserve transaction integrity.
- Distinguish empty results from errors.
- Distinguish validation failures from business rule failures.
- Distinguish retryable from non-retryable failures where applicable.
- Log unexpected technical failures appropriately.
- Avoid exposing sensitive information.
- Add tests for important error paths.
- Reuse the existing error architecture.

The AI coding agent must not:

- Throw DriftException into Cubit code.
- Catch DioException directly inside widgets.
- Display raw exception messages.
- Parse SQL error strings in UI.
- Put Arabic messages inside repositories.
- Put business validation inside widgets when it belongs to the domain/application layer.
- Introduce `Either` or another functional error framework without explicit approval.
- Create multiple competing Failure hierarchies.
- Swallow errors silently.
- Return fake success after a failed transaction.
- Convert database failures into empty successful results.
- Clear user data unnecessarily after a failure.
- Introduce a second logging/error-reporting mechanism without approval.

---

## 61. Implementation Guidance

The initial implementation should remain intentionally simple.

Recommended conceptual structure:

core/
├── error/
│   ├── failure.dart
│   ├── validation_failure.dart
│   ├── business_rule_failure.dart
│   ├── database_failure.dart
│   ├── network_failure.dart
│   ├── sync_failure.dart
│   └── unexpected_failure.dart

The exact project structure may differ according to the approved `project-structure.md`.

Do not create files merely to match this example if the existing structure provides a better approved location.

---

## 62. Current V1 Scope

The current local implementation requires:

- ValidationFailure
- BusinessRuleFailure
- DatabaseFailure
- UnexpectedFailure

Future scope includes:

- NetworkFailure
- RemoteFailure
- SyncFailure
- Conflict-related failures
- Background synchronization error handling

Only implement future failure types when their corresponding infrastructure is introduced, unless the architecture requires a shared abstraction earlier.

---

## 63. No Premature Networking Errors

The local implementation must not pretend that networking exists.

Do not add complex HTTP error mapping before Retrofit/Dio integration.

The architecture can reserve the concepts now, but implementation should follow actual infrastructure availability.

---

## 64. No Premature Sync Errors

Similarly, synchronization failures should not be implemented as active runtime behavior before the Sync Engine exists.

The current local implementation should remain fully functional without:

- NetworkFailure
- SyncFailure processing
- Retry scheduler
- Background sync

unless required by the current implementation phase.

---

## 65. Definition of Done

Error handling is considered correctly implemented when:

- Infrastructure exceptions do not leak into Presentation.
- Repositories translate technical exceptions into application Failures.
- Validation failures are distinguishable from business-rule failures.
- Database failures are distinguishable from unexpected failures.
- Transactions fail safely and roll back when required.
- Empty results are not treated as errors.
- Known failures have meaningful localized messages.
- Raw technical errors never reach users.
- Cubits expose appropriate error states.
- Existing data is preserved where appropriate.
- User-entered form data is not unnecessarily lost.
- Important error paths have automated tests.
- Financial operations fail safely without partial persistence.
- Error logging does not expose sensitive information.
- Future networking/sync concerns remain separated from the current local implementation.
- No unnecessary error-handling framework has been introduced.

---

## 66. Final Error Flow

The approved V1 flow is:

Local Data Source
↓
Technical Exception
↓
Repository
↓
Application Failure
↓
Cubit
↓
UI State
↓
Arabic Localized Message

Future network flow:

Remote Data Source
↓
Dio / Retrofit Exception
↓
Repository
↓
Application Failure
↓
Cubit

Future synchronization flow:

Sync Engine
↓
Remote Data Source
↓
Technical Failure
↓
Retry / Permanent Failure / Conflict
↓
Sync State

The core principle is:

Technical errors stay technical.

Application failures stay application-level.

User-facing messages stay in the Presentation/localization layer.

No layer should expose more implementation detail than the layer above it needs.