# Synchronization Implementation

## 1. Purpose

This document defines the implementation contract for offline-first synchronization in the Laundry Management System.

The synchronization architecture exists to allow the application to remain operational while offline and synchronize local changes with the backend when connectivity is available.

The approved architecture is:

User
↓
Presentation
↓
Cubit
↓
Repository
↓
Local Database
↓
Sync Queue
↓
Sync Engine
↓
Remote Data Source
↓
Retrofit
↓
Dio
↓
Supabase Edge Functions
↓
Backend

The most important principle is:

Local operation must not depend on network availability.

---

## 2. Current Implementation Status

Synchronization is approved architecturally but deferred from the current local Flutter implementation phase.

The current phase focuses on completing the local application.

Therefore, during the current implementation phase:

- Local database must work independently.
- Repositories must support local operations.
- Cubits must work without networking.
- The Sync Engine does not need to be implemented yet.
- Remote API calls do not need to be implemented yet.
- Background synchronization does not need to be implemented yet.
- Conflict resolution does not need to be implemented yet.

The codebase must, however, avoid architectural decisions that would make future synchronization difficult to add.

---

## 3. Offline-First Principle

The application is offline-first.

This means:

A user action should normally be accepted locally first.

The UI should reflect the local result immediately after successful local persistence.

Network availability must not be a prerequisite for normal operational workflows.

The expected flow is:

User Action
↓
Cubit
↓
Repository
↓
Local Transaction
↓
Local Database Updated
↓
UI Reflects New State
↓
Sync Operation Queued
↓
Sync Later

The user should not need to wait for the backend before the local application reflects the operation.

---

## 4. Local Database as Operational Source of Truth

The local database is the operational source of truth for the Flutter client.

Screens should render current application state from local data.

The remote backend should not replace the local database as the primary UI data source simply because connectivity exists.

The backend becomes part of the synchronization process.

This ensures that:

- The application works offline.
- Local changes are immediately visible.
- Network failures do not block normal workflows.
- Synchronization can happen asynchronously.

---

## 5. Sync Queue

The Sync Queue stores local operations that must eventually be synchronized with the backend.

A sync queue entry should contain enough information to identify and reproduce the logical operation.

Conceptually, a queue item may contain:

- Operation ID
- Entity type
- Entity ID
- Operation type
- Payload or payload reference
- Created timestamp
- Updated timestamp where required
- Attempt count
- Last attempt timestamp
- Next retry timestamp
- Sync status
- Last error information where appropriate

The exact database representation must follow the approved database design.

Do not duplicate the business entity itself unnecessarily inside the queue.

---

## 6. Stable Operation Identity

Every synchronization operation must have a stable identity.

An operation ID must remain unchanged across retries.

A timeout must not cause the client to create a second logical operation ID.

This is critical for preventing duplicate remote operations.

Conceptually:

Operation A
→ attempt 1
→ timeout
→ retry
→ attempt 2

All attempts belong to the same logical Operation A.

---

## 7. Entity Identity

The system uses stable UUID-based entity identities.

Synchronization must preserve those identifiers.

For example:

Customer UUID
Order UUID
Payment UUID
Expense UUID
StorageRecord UUID

must remain the same locally and remotely.

The sync engine must not replace local entity IDs with newly generated remote IDs.

---

## 8. Operation Types

The synchronization system should represent the logical operation being synchronized.

Typical operation types may include:

- Create
- Update
- Deactivate
- Delete where explicitly supported

The exact supported operation types must follow the domain and backend contract.

Do not introduce destructive delete synchronization where the domain uses deactivation.

For example, if a customer is deactivated rather than physically deleted, synchronization must communicate the corresponding state change.

---

## 9. Create Operations

For a newly created local entity:

1. Generate its stable UUID locally.
2. Persist the entity locally.
3. Create the corresponding sync operation.
4. Mark the operation as pending.
5. Return successful local state to the UI.
6. Synchronize later when possible.

The same entity UUID must be used when the remote operation is attempted.

A network retry must not generate a new entity UUID.

---

## 10. Update Operations

For local updates:

1. Apply the update locally.
2. Commit it successfully.
3. Create or update the appropriate pending synchronization state.
4. Synchronize the logical change later.

The implementation should avoid unnecessary duplicate queue entries when multiple local updates can safely be coalesced.

However, operations must not be coalesced when doing so would change the required business semantics.

The exact coalescing strategy should be implemented only after the final synchronization requirements are established.

---

## 11. Deactivation Operations

Where the business model uses active/inactive state instead of hard deletion:

Local deactivation should:

1. Update the entity locally.
2. Persist the state change.
3. Create the corresponding sync operation.
4. Synchronize the state change remotely.

The sync engine must not translate a deactivation into a physical DELETE request unless the backend contract explicitly requires that behavior.

---

## 12. Transactional Local Write

The local entity change and creation of its synchronization operation should be atomic whenever the operation requires synchronization.

Conceptually:

BEGIN TRANSACTION

Update business entity

Create sync queue operation

COMMIT

If either operation fails:

ROLLBACK

This prevents the dangerous state where:

- The entity was changed locally
- But the application forgot to queue the synchronization operation

or:

- A sync operation exists
- But the local business change does not

The exact transaction implementation must follow the approved Data Layer and Database Implementation documentation.

---

## 13. Sync Status

A synchronization operation should have an explicit state.

Typical states include:

- Pending
- Processing
- Synced
- Failed

The final state model must remain consistent with the database design.

### Pending

The operation has not successfully synchronized yet.

### Processing

The operation is currently being attempted.

### Synced

The backend has accepted the operation successfully.

### Failed

The operation could not currently be synchronized.

A Failed operation should retain enough information to support diagnosis and future retry behavior.

---

## 14. Pending State

Pending is the normal state for a local operation waiting for synchronization.

An operation may remain Pending because:

- The device is offline.
- Synchronization has not started.
- Another operation must be processed first.
- A retry is scheduled.

Pending must not be treated as a local business failure.

---

## 15. Processing State

Processing indicates that the Sync Engine currently owns an operation.

The system must prevent multiple workers from processing the same operation concurrently unless the synchronization design explicitly supports that behavior.

There must be a clear mechanism for recovering operations that remain Processing because the application was interrupted.

An operation must not remain permanently locked because the application crashed during synchronization.

---

## 16. Synced State

An operation becomes Synced only after the backend has confirmed successful processing according to the API contract.

A request being sent is not sufficient.

A timeout is not success.

A locally assumed response is not success.

The sync engine should only mark the operation Synced after receiving a valid successful result.

---

## 17. Failed State

Failed means the current synchronization attempt could not complete successfully.

Failure information should be retained where useful.

Examples may include:

- Error code
- Error message
- HTTP status
- Attempt count
- Last attempt timestamp

The stored information must not contain unnecessary sensitive data.

---

## 18. Temporary vs Permanent Failures

The Sync Engine must distinguish between retryable and non-retryable failures.

### Retryable

Examples:

- No connectivity
- Timeout
- Temporary server error
- Temporary service unavailable

These should normally be retried according to the retry policy.

### Non-Retryable

Examples:

- Invalid business data
- Invalid required field
- Entity violates backend integrity rules
- Unsupported operation
- Permanent conflict requiring user resolution

These should not be retried indefinitely.

The exact error classification must follow the final backend error contract.

---

## 19. Retry Strategy

The approved future retry direction is:

Exponential Backoff
+
Maximum Retry Count
+
Permanent Failure State

The exact constants are not finalized in this document.

Do not invent arbitrary final retry values during the local implementation phase.

A retry strategy should avoid:

- Continuous immediate retries
- Excessive battery consumption
- Excessive network usage
- Backend flooding

---

## 20. Retry Scheduling

A retryable failed operation should have a future retry time.

Conceptually:

Failure
↓
Calculate next retry time
↓
Store next retry time
↓
Wait
↓
Retry

The exact scheduling mechanism may later use:

- Application-triggered synchronization
- Connectivity-triggered synchronization
- Background execution
- Periodic sync

The final mechanism depends on the platform/background requirements and is outside the current local-only phase.

---

## 21. Connectivity

The Sync Engine should not assume that a failed request always means the device is offline.

Examples:

No internet
→ connectivity failure

Server unavailable
→ remote service failure

Validation error
→ permanent business/data failure

The synchronization layer should use appropriate network/error information rather than relying exclusively on connectivity checks.

Connectivity detection can help decide when to attempt synchronization, but it must not be treated as proof that the backend request will succeed.

---

## 22. Synchronization Trigger

The final implementation may trigger synchronization through multiple mechanisms.

Possible triggers include:

- Application startup
- Application resume
- Connectivity restored
- Manual refresh/sync
- Background execution
- Periodic execution

The exact trigger strategy will be finalized when background synchronization is implemented.

The local implementation must not require any of these triggers for normal operation.

---

## 23. Manual Synchronization

If a manual synchronization action is eventually exposed to users, it should:

- Start synchronization
- Display appropriate progress
- Avoid duplicate concurrent sync jobs
- Report successful synchronization
- Report meaningful failures
- Preserve local data

Manual sync must not reset local data simply because the remote operation fails.

---

## 24. Single Sync Worker

The synchronization system should avoid multiple independent workers processing the same queue concurrently.

The preferred model is one coordinated Sync Engine responsible for queue processing.

If concurrency is introduced later, it must be designed explicitly with locking/idempotency guarantees.

Do not create:

OrdersSyncWorker

CustomersSyncWorker

PaymentsSyncWorker

all independently processing the same queue without a clear coordination strategy.

---

## 25. Ordering

Synchronization ordering matters when operations depend on each other.

Example:

Create Customer
↓
Create Order referencing Customer

The Order must not be synchronized before the Customer exists remotely if the backend requires that relationship.

Therefore, the Sync Engine must respect dependency ordering.

At minimum, operations that have explicit entity dependencies must not be processed in an order that violates backend referential integrity.

---

## 26. Parent-Child Operations

Some entities depend on parent entities.

Examples may include:

Customer
→ Order

Order
→ Order Item

Order
→ Payment

Order
→ Storage Record

The sync architecture must preserve the required dependency ordering.

The exact dependency graph should follow the approved domain and database relationships.

---

## 27. Multiple Local Updates

A user may update the same entity multiple times before synchronization occurs.

The sync system must preserve the correct final business state.

Example:

Order status:
Pending
→ Processing
→ Ready
→ Completed

If all intermediate states are not required remotely, the sync system may eventually optimize the queue.

However, such optimization must not change business meaning.

Do not implement aggressive queue collapsing until the final synchronization semantics are defined.

---

## 28. Idempotency

Critical synchronization operations must be idempotent.

The same logical operation may be sent more than once because of:

- Timeout
- Connection interruption
- Client crash
- Response loss
- Retry

The backend must recognize the operation identity and avoid creating duplicate business records.

The client must preserve the same:

- Operation ID
- Entity ID
- Relevant idempotency information

across retries.

---

## 29. Timeout Scenario

A critical scenario is:

Client sends request
↓
Backend processes request
↓
Client does not receive response
↓
Client assumes request failed
↓
Client retries

The backend must be able to recognize the repeated logical operation.

The client must not create a new business operation simply because the previous response was lost.

---

## 30. Conflict Handling

Synchronization conflicts may occur when local and remote data diverge.

The final conflict strategy must be defined according to the business requirements.

The current implementation must not invent a generic conflict-resolution system.

Potential future strategies may include:

- Server-authoritative resolution
- Last-write-wins for specific fields
- Domain-specific conflict resolution
- Manual user resolution

The correct strategy may differ by entity.

For example, financial records should not automatically use an arbitrary last-write-wins strategy if that could cause incorrect financial data.

---

## 31. Financial Data

Financial data requires special care.

Values such as:

- Order totals
- Payments
- Expenses
- Profit-related values

must preserve the approved integer minor-unit representation.

Synchronization must not introduce floating-point conversions that can change monetary values.

Example:

1000 piastres

must remain:

1000

rather than being converted to a floating-point representation and potentially introducing precision errors.

---

## 32. Business Dates

Date-only values must preserve their semantics during synchronization.

For example:

Expense Date

must remain the intended business date.

Do not introduce timezone conversions that move a date to the previous or next calendar day.

Timestamps and date-only values must remain distinct.

---

## 33. Local Read Behavior During Sync

Synchronization must not make normal screens unusable.

While synchronization is occurring:

- Screens continue reading local data.
- Local state remains available.
- Users can continue normal operations when supported.
- New local changes can be queued.
- Sync progress does not replace the local source of truth.

The application must not block the entire UI while the Sync Engine is working.

---

## 34. New Operations During Synchronization

Users may create or modify records while synchronization is running.

The system should allow additional local operations to enter the queue safely.

New operations should not corrupt or invalidate the currently processing queue item.

The Sync Engine must handle the queue dynamically rather than assuming that the queue cannot change during synchronization.

---

## 35. Crash Recovery

The synchronization system must be resilient to application termination.

If the application closes while an operation is Processing:

The next synchronization run must be able to identify and recover the operation.

It must not remain permanently Processing.

Recovery must preserve idempotency.

The operation should return to a state where it can be safely retried or reconciled.

---

## 36. Partial Failure

Synchronization may process multiple operations where some succeed and others fail.

Example:

Operation A → Synced

Operation B → Synced

Operation C → Failed

Operation D → Pending

The system must preserve the state of each operation independently.

A single failed operation must not incorrectly mark the entire queue as failed.

---

## 37. Sync Result

The Sync Engine should produce a meaningful synchronization result.

Conceptually, a sync run may report:

- Operations processed
- Operations succeeded
- Operations failed
- Operations remaining
- Whether another retry is required

The UI may use this information if synchronization status is exposed.

The Sync Engine itself must remain independent of UI concerns.

---

## 38. Repository Integration

Repositories remain the boundary between application operations and data sources.

The repository should coordinate local persistence and creation of synchronization operations according to the approved Data Layer architecture.

Conceptually:

Repository
↓
Local Transaction
├── Update entity
└── Queue sync operation

The Repository should not directly implement the entire synchronization worker.

The Sync Engine should own queue processing.

---

## 39. Sync Engine Responsibilities

The Sync Engine is responsible for:

- Selecting eligible queue operations
- Processing operations
- Calling remote data sources
- Handling success
- Handling retryable failures
- Handling permanent failures
- Updating sync status
- Respecting operation ordering
- Preventing duplicate processing
- Supporting crash recovery

The Sync Engine is not responsible for:

- Rendering UI
- Managing Cubit state
- Implementing database business rules
- Calculating order totals
- Validating presentation forms

---

## 40. Remote Data Source Responsibilities

The Remote Data Source is responsible for communicating with the backend API.

It should use:

Retrofit
↓
Dio

It should not:

- Manage queue persistence
- Decide retry policy
- Manage UI
- Implement business workflows

The Sync Engine decides when an operation should be sent.

The Remote Data Source knows how to send it.

---

## 41. Dependency Injection

When synchronization is implemented, the following dependencies should be registered through the existing `get_it` configuration.

Potential dependencies include:

- Sync Engine
- Sync Repository/Queue access if required
- Remote Data Sources
- Retrofit API clients
- Dio
- Supporting synchronization infrastructure

The exact dependency structure must follow `dependency-injection.md`.

Do not create a second DI mechanism for synchronization.

---

## 42. Networking Integration

The Sync Engine communicates with the backend through the approved networking architecture:

Sync Engine
↓
Remote Data Source
↓
Retrofit
↓
Dio
↓
API

It must not create its own Dio client.

It must not bypass the centralized networking infrastructure.

---

## 43. Authentication and Sync

The current V1 application does not implement end-user authentication.

Therefore, synchronization must not introduce:

- Login
- Registration
- User sessions
- Role management
- Permission management

Any backend-level protection required for API access must remain an infrastructure concern and follow the approved backend architecture.

---

## 44. Security

Synchronization must avoid exposing sensitive data unnecessarily.

Logs must not contain:

- Secrets
- Credentials
- Unnecessary customer personal data
- Payment-sensitive information

Queue records should contain only the information required to reproduce the synchronization operation.

---

## 45. Data Retention

Successfully synchronized operations may eventually be:

- Marked Synced
- Retained for audit/debugging
- Archived
- Removed according to the final database strategy

The exact retention policy is not finalized here.

Do not automatically delete synchronization history merely because an operation succeeded unless the database design explicitly requires it.

---

## 46. Auditability

Business records should remain auditable.

Synchronization must not destroy important business history simply to simplify queue management.

For example:

Payment records and Expense records should not be treated as disposable synchronization events.

The business entity remains important even after the synchronization operation succeeds.

---

## 47. Sync Status vs Business Status

Synchronization state must not be confused with business state.

For example:

An Order can be:

Business Status:
Ready

while its synchronization state is:

Pending

This does not mean the Order is not Ready.

Similarly:

A Payment may be successfully recorded locally while its remote synchronization is pending.

The UI must not incorrectly replace business status with synchronization status.

---

## 48. User-Facing Sync Indicators

If synchronization status is exposed in the UI, it should be secondary to the business state.

Examples:

- Pending synchronization
- Synchronization failed
- Last synchronized

These indicators must not imply that a locally successful operation is invalid merely because it has not reached the backend yet.

The final UX should follow the approved Design System and Figma design.

---

## 49. Backend Availability

If the backend is unavailable:

- Local application remains usable.
- Local writes remain possible where supported.
- Sync operations remain pending/retryable.
- The user should not lose locally committed data.

Backend outage must not automatically cause local business operations to roll back.

---

## 50. Network Recovery

When connectivity or backend availability returns:

1. Sync Engine becomes eligible to run.
2. Pending/retryable operations are selected.
3. Operations are processed according to ordering rules.
4. Successful operations are marked Synced.
5. Retryable failures receive a future retry time.
6. Permanent failures remain visible for resolution.

The local database continues to operate normally throughout the process.

---

## 51. Performance

Synchronization should avoid unnecessary resource usage.

The implementation should consider:

- Batch size
- Request frequency
- Retry frequency
- Database query efficiency
- Battery consumption
- Network usage

The final values should be chosen during actual synchronization implementation.

Do not prematurely optimize with complex batching or concurrency without evidence that it is required.

---

## 52. Background Synchronization

Background synchronization is a future concern.

It should be introduced only after:

- Local-first behavior is complete.
- Networking is implemented.
- Sync queue processing is stable.
- Retry behavior is verified.
- Crash recovery is verified.
- Platform background limitations are understood.

Do not make the application dependent on background execution for correctness.

Foreground synchronization must remain capable of recovering pending operations.

---

## 53. Conflict Resolution

Conflict resolution must be domain-aware.

Do not implement:

"last write wins for everything"

as a universal strategy.

For each conflict-prone entity, determine:

- Which fields can safely use last-write-wins.
- Which fields require additive behavior.
- Which records must never be overwritten automatically.
- Which conflicts require manual intervention.

Financial records require particular caution.

---

## 54. Multi-Device Considerations

The system may eventually support multiple clients/devices synchronizing against the same backend.

The local implementation must therefore preserve stable identifiers and synchronization metadata.

However, multi-device synchronization behavior is not required to be implemented during the current local phase.

Do not introduce distributed synchronization complexity prematurely.

---

## 55. Testing Strategy

Synchronization must be heavily tested before production use.

Important scenarios include:

### Offline Create

Create entity offline.

Expected:

- Local entity exists.
- Sync operation is Pending.

### Online Sync

Backend becomes available.

Expected:

- Pending operation is sent.
- Operation becomes Synced.

### Timeout

Backend processes request but client times out.

Expected:

- Retry uses the same logical operation identity.
- Duplicate business record is not created.

### Permanent Validation Failure

Backend rejects invalid data.

Expected:

- Operation does not retry indefinitely.
- Failure remains identifiable.
- Local data is preserved.

### Application Crash

Application terminates while processing.

Expected:

- Operation can recover.
- Operation does not remain permanently locked.

### Multiple Operations

Several operations exist.

Expected:

- Dependency ordering is respected.
- Individual operation states are preserved.

---

## 56. Sync Testing Without Backend

Unit tests should not require a live backend.

The Sync Engine should be testable using:

- Fake queue
- Fake repository/data source
- Mock remote API
- Fake network responses

This allows deterministic testing of:

- Retry
- Ordering
- Failure
- Success
- Recovery

---

## 57. Idempotency Testing

Tests must verify that retrying the same operation does not create duplicate business records.

A critical test scenario is:

Send operation
→ simulate timeout
→ retry same operation
→ verify one logical backend result

The exact implementation of this test depends on the backend contract.

---

## 58. Repository and Sync Testing

Repository tests should verify that a local write and its sync operation are created consistently.

Important test:

Local entity write succeeds
+
Sync queue insert succeeds

Both should be committed atomically when required.

Another important test:

Local entity write fails

Expected:

No orphan sync operation should remain.

---

## 59. Current Phase Restrictions

Until the local implementation phase is complete, the coding agent must not implement:

- Sync Engine
- Background sync
- Remote synchronization
- Conflict resolution
- Network-dependent UI
- Retry scheduler
- Connectivity-triggered sync

unless explicitly requested as part of the networking/sync implementation phase.

The documentation exists now to establish the future architecture.

---

## 60. AI Coding Agent Rules

When synchronization implementation begins, an AI coding agent must:

- Follow the offline-first architecture.
- Treat local persistence as the operational source of truth.
- Use the existing Sync Queue design.
- Preserve stable UUIDs.
- Preserve operation identity across retries.
- Use the centralized Repository boundary.
- Use Remote Data Sources for API communication.
- Use Retrofit + Dio.
- Respect dependency ordering.
- Handle retryable and permanent failures differently.
- Preserve local data during remote failures.
- Support crash recovery.
- Prevent duplicate processing.
- Preserve financial precision.
- Preserve date-only semantics.
- Add comprehensive synchronization tests.
- Use the existing `get_it` configuration.
- Follow the documented database and data-layer constraints.

The coding agent must not:

- Make the application API-first.
- Block local operations on network availability.
- Create duplicate business records on retry.
- Generate new entity IDs during retries.
- Put synchronization logic inside Cubits.
- Put synchronization logic inside UI widgets.
- Put queue processing inside Retrofit clients.
- Create a second network client.
- Create a second DI mechanism.
- Implement generic last-write-wins for all entities.
- Delete local data because a remote request failed.
- Introduce background synchronization before the core sync implementation is stable.
- Implement conflict resolution without an approved strategy.
- Introduce complex distributed synchronization unnecessarily.

---

## 61. Definition of Done

Synchronization implementation is considered complete when:

- Local-first writes work correctly.
- Required sync operations are created atomically with local changes.
- Sync queue states are explicit.
- Sync operations have stable identities.
- Stable entity UUIDs are preserved.
- Sync Engine processes eligible operations.
- Remote communication uses Retrofit + Dio.
- Repository boundaries remain intact.
- Retryable failures are retried appropriately.
- Permanent failures do not retry indefinitely.
- Exponential backoff is implemented where approved.
- Idempotency is preserved.
- Dependency ordering is respected.
- Processing state can recover after application interruption.
- Partial queue failures are handled correctly.
- Local application behavior remains independent of network availability.
- Financial values retain integer minor-unit precision.
- Date-only values retain their business-date semantics.
- Synchronization does not corrupt business state.
- Unit and integration tests cover critical sync scenarios.
- No unapproved architecture has been introduced.

---

## 62. Final Architecture

The approved synchronization architecture is:

User
↓
Screen
↓
Cubit
↓
Repository
↓
Local Database
↓
Sync Queue
↓
Sync Engine
↓
Remote Data Source
↓
Retrofit
↓
Dio
↓
Supabase Edge Functions
↓
Backend

The fundamental operating rule is:

Local operation first.

Synchronization second.

Network failure must never erase or invalidate a successfully committed local business operation.

The synchronization system exists to make local operations eventually consistent with the backend while preserving correctness, idempotency, data integrity, and offline usability.