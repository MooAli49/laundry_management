# Synchronization Implementation

## 1. Purpose

This document defines the implementation contract for offline-first synchronization in the Laundry Management System.

The synchronization architecture exists to allow the application to remain operational while offline and synchronize local changes with the backend when connectivity is available.

The approved architecture is **Bidirectional Push + Pull Synchronization**:

### PUSH Flow:

    User
    ↓
    Presentation (Screens / Widgets)
    ↓
    Cubit
    ↓
    Repository
    ↓
    Local SQLite Database (Drift)
    ├── Apply business mutation
    └── Enqueue SyncOperation (atomic local transaction)
    ↓
    SyncEngine
    ↓
    RemoteApiDispatcher (Retrofit + Dio)
    ├── Header: X-Operation-ID (idempotency)
    └── Body: base_version (optimistic concurrency where required)
    ↓
    Supabase Edge Functions (/api/v1/...)
    ↓
    PostgreSQL Transactional RPCs (ACID)
    ├── Check sync_idempotency_log
    ├── Validate server_version == base_version
    ├── Execute business mutation
    ├── Increment server_version where applicable
    ├── Append to sync_changes (monotonically increasing sequence)
    └── Commit

### PULL Flow:

    Realtime signal (sync_available) / Foreground pull / Resume / Connectivity
    ↓
    SyncEngine.pull() (Single-flight concurrency guard)
    ↓
    RemoteApiDispatcher (Retrofit + Dio)
    ↓
    Supabase Edge Function (GET /api/v1/sync/changes?after=<cursor>)
    ↓
    Remote changes retrieved from sync_changes in sequence order
    ↓
    RemoteChangeApplier
    ↓
    Local SQLite Database (Drift ACID Transaction)
    ├── Upsert records directly via DAOs (zero SyncOperations created)
    └── Advance sync_state.last_applied_sequence
    ↓
    Reactive Drift Streams (db.tableUpdates)
    ↓
    UI updates automatically

The most important principles are:

1. Local operation must not depend on network availability.
2. Realtime is ONLY an ephemeral wake-up signal; the Pull API is the authoritative source.
3. Ingestion must never generate outgoing SyncOperations (echo loop prevention).
4. Applying changes and advancing the local cursor must be atomic in SQLite.

---

## 2. Current Implementation Status

> **ACTIVE IMPLEMENTATION PHASE**

Offline / Sync Integration is now the **active** implementation phase.

The Orders module has completed its Local-First implementation and final E2E verification.

The project is now connecting the existing Local-First application to the approved Supabase remote backend.

This phase is an **infrastructure / integration** phase.

It is not a new V1 business feature.

Existing V1 business rules, domain entities, and lifecycle states remain unchanged.

### What must be implemented in this phase:

- Durable Sync Queue (local database, persisted).
- Atomic local mutation + sync operation enqueue.
- Stable operation IDs preserved across retries.
- Sync Engine with retry, ordering, failure classification, and crash recovery.
- Remote Data Sources communicating with Supabase via Retrofit + Dio.
- Idempotent remote processing.
- Dependency-aware synchronization ordering.
- Conflict handling per the approved entity-specific strategy.
- Financial record protection.

### What remains unchanged from the Local-First phase:

- All local workflows must continue working without network access.
- The local database remains the operational source of truth.
- Cubits and Widgets must remain unaware of sync mechanics.
- Business entity lifecycle statuses must not include sync states.

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

The approved retry architecture is:

    Exponential Backoff
    +
    Maximum Retry Count
    +
    Permanent Failure State

Retryable failures are retried with exponential backoff until the maximum retry count is reached.

Once the maximum retry count is exceeded, the operation transitions to a permanent failure state.

Operations in permanent failure state are not automatically retried.

Retries are safe because all synchronization operations are idempotent: retrying the same operation with the same stable operation ID must not create duplicate business effects.

The exact numeric constants (initial delay, backoff multiplier, maximum delay, maximum retry count) are implementation-level configuration.

Those values must be chosen during synchronization implementation based on:

- Observed platform behavior
- Battery and network usage constraints
- Backend rate-limiting requirements

A retry strategy must avoid:

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
- Periodic sync while foregrounded

Foreground synchronization is part of the current implementation phase. Platform-specific background execution is deferred.

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
- Periodic execution while running in foreground

Foreground synchronization triggers are part of the active sync implementation. Platform-specific background execution remains deferred.

The local operational workflows must not require any of these triggers for normal offline operation.

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

V1 does not implement an end-user authentication system for the application UI.

The application does not include:

- Login screens
- User registration
- User sessions
- Role management
- Permission management

Therefore, synchronization must not introduce end-user authentication UI.

Any backend-level protection required for API access (e.g., API keys, service-level authentication) must remain an infrastructure concern, implemented centrally, and must not appear inside feature code.

Authentication infrastructure is handled at the centralized networking layer per `networking-implementation.md` §15.

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

The approved data retention policy for successfully synchronized operations is:

Successfully synchronized operations (status: Synced) are **retained** in the local Sync Queue for audit and diagnostics.

They are not automatically deleted the moment synchronization succeeds.

Retained Synced records may eventually be archived or purged according to a database maintenance policy, but that maintenance must not interfere with business data integrity.

The specific cleanup/archival mechanism (e.g., periodic background cleanup, manual trigger, time-based expiry) is an implementation-level detail.

Rationale:

- Synced operation records provide an audit trail of what was synchronized.
- Immediate deletion would make it impossible to diagnose synchronization issues after the fact.
- Business entities themselves (Orders, Payments, etc.) remain present regardless of sync record retention.
- Audit requirements for financial records (Payments, Expenses) make retention preferable to immediate deletion.

Do not treat successfully synchronized records as disposable immediately after success.

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

Platform-specific background synchronization is **deferred** from the current Offline / Sync Integration phase.

Foreground synchronization is the active requirement for this phase and must handle queue processing, retry, and crash recovery.

Do not make the application dependent on platform background execution for correctness.

Foreground synchronization must remain capable of recovering pending operations whenever the application is active.

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

## 54. Multi-Device Considerations (Two-Terminal Operation)

The system officially supports **two devices** synchronizing bidirectionally against the same remote Supabase backend.

Key architectural requirements for two-device synchronization:

1. **Bidirectional Ingestion**: Changes made on Device A are committed to remote `sync_changes` and pulled by Device B, and vice versa.
2. **Deterministic Sequence Ordering**: All remote changes are ordered by `sync_changes.sequence ASC`.
3. **Echo Loop Prevention**: `RemoteChangeApplier` directly writes pulled changes to Drift DAOs without enqueueing to `sync_operations`.
4. **Domain-Aware Conflict Handling**:
   - Generic Last-Write-Wins is strictly prohibited.
   - Payments are append-only; balance validation is authoritative on the server.
   - Storage moves enforce at most one active record per `OrderItem`. `sync_changes.sequence` provides committed ordering only; it is not a generic LWW conflict resolver. A stale concurrent move receives `CONCURRENCY_CONFLICT`, and the winning committed change is pulled by both terminals.
   - Mutable entities use entity `server_version` checked against `base_version`.
5. **Crash Safety**: Applying pulled changes and advancing `sync_state.last_applied_sequence` occur within the **same local transaction**.
6. **Preservation of Local Pending Operations**: An initial bootstrap or full resync after `CURSOR_TOO_OLD` must NEVER delete locally pending unsynced records in `sync_operations`.

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

## 59. Approved Architectural Constraints for This Phase

The following architectural decisions are approved and must be followed during the Offline / Sync Integration phase.

These are the binding decisions documented in `technical-decisions.md`.

1. **Local-First write path.**
   Local persistence is the primary client operation.
   A network connection must never be required for normal approved V1 workflows.
   Synchronization happens asynchronously after the local operation.

2. **Stable entity identity.**
   Business entities that participate in synchronization must use stable UUIDs.
   The same entity UUID must remain stable between local and remote storage.
   The Sync Engine must never replace a local entity UUID with a new remote ID.

3. **Stable synchronization operation identity.**
   Every synchronization operation must have a stable operation ID.
   Retries must reuse the same operation ID.
   Retrying an operation must not create duplicate logical records.

4. **Atomic enqueue.**
   A local business mutation and the corresponding synchronization operation must be persisted atomically in the same local transaction.
   We must never end up with a business change without a sync operation, or a sync operation without its corresponding business change.

5. **Idempotent remote processing.**
   The remote / Supabase side must safely process retries.
   Duplicate delivery of the same synchronization operation must not create duplicate business records.

6. **Separation between business state and synchronization state.**
   Sync state must NOT become part of business lifecycle state.
   Do not introduce business statuses such as PendingSync, Syncing, or SyncFailed.
   Order lifecycle remains exactly the approved lifecycle (Processing → Ready → Completed or Cancelled).

7. **Conflict handling.**
   Conflict resolution must be deterministic.
   It must be defined at the entity / business-rule level.
   It must NOT be delegated to UI behavior.
   Do not assume generic last-write-wins is automatically correct for every entity.

8. **Financial safety.**
   Payments and other financial records require special protection.
   Synchronization must never silently overwrite, duplicate, or lose financial history.

9. **Dependency-aware synchronization.**
   Synchronization order must respect entity relationships / dependencies.
   Parent / reference data must be available before dependent records when required.
   Example: Customer must exist remotely before dependent Orders are synchronized.

10. **Architecture boundary.**
    Feature Cubits and Widgets must NOT contain synchronization engine logic.
    They must not manage queues, retries, conflict resolution, connectivity synchronization, etc.
    Sync belongs to the Data / Infrastructure layer and communicates through approved repository / application boundaries.

11. **Supabase.**
    Supabase is the approved remote backend platform for this phase.
    Supabase must remain behind the approved Remote Data Source boundary.
    Feature-level code must not directly call Supabase.

12. **Future SaaS readiness.**
    The architecture should remain suitable for future multi-device / multi-tenant / SaaS evolution.
    However, SaaS functionality itself is NOT part of the current implementation.
    Do NOT introduce tenants, branches, roles, permissions, subscription management, or multi-tenant UI as part of this phase.

13. **Current phase scope.**
    Offline / Sync Integration is an infrastructure / integration phase.
    It is not a new business feature.
    It connects the existing Local-First application to the approved remote backend while preserving all existing business rules.

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

---

## 63. Step 10 — Payment Synchronization Specification

### 63.1 Overview
The payment synchronization pipeline ensures offline-first payment capture with authoritative server-side validation and atomic order balance updates upon remote sync.

```text
RecordPaymentDialog / RecordPaymentCubit
        ↓
PaymentRepositoryImpl.recordPayment()
        ↓
Local Drift Transaction
        ├── payments (inserted locally)
        └── sync_operations (enqueued with self-contained payload)
        ↓
SyncEngine
        ↓
RemoteApiDispatcher
        ↓
PaymentRemoteApi (@POST('/api/v1/payments'))
        ↓
Supabase Edge Function (/api/v1/payments)
        ↓
PostgreSQL RPC sync_create_payment()
        ↓
Atomic ACID Transaction (FOR UPDATE lock, balance check, payment insert, paid_amount update, idempotency log)
```

### 63.2 Payment Entity & Payload Mapping
- **Local Domain**: `Payment` (`id`, `orderId`, `amount`, `paymentMethod`, `paidAt`, `createdAt`, `updatedAt`).
- **Monetary Units**: Integer minor units (piastres / `BIGINT`). No floating-point numbers.
- **Payment Method Mapping**:
  - `PaymentMethod.cash` → `"cash"`
  - `PaymentMethod.instapay` → `"insta_pay"`
  - `PaymentMethod.ewallet` → `"e_wallet"`
- **Timestamps**: Serialized as UTC ISO-8601 strings (`2026-09-16T10:30:00.000Z`).
- **Payload Schema**:
  ```json
  {
    "id": "<UUID>",
    "order_id": "<UUID>",
    "amount": 8000,
    "payment_method": "cash | insta_pay | e_wallet",
    "paid_at": "<ISO-8601 UTC>",
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

### 63.3 Remote API & Edge Function Contracts
- `POST /api/v1/payments`: Creates a new payment remotely via `sync_create_payment()`. Reads `X-Operation-ID` header. Returns `201 Created` with payment representation.
- `GET /api/v1/payments/:id`: Retrieves a payment by ID. Returns `200 OK` or `404 Not Found`.
- `GET /api/v1/payments?order_id=<UUID>`: Retrieves all payments for an order, ordered by `paid_at DESC`.
- **Payment Immutability (V1)**: Payments are immutable once recorded. `PATCH`, `PUT`, and `DELETE` are disallowed and return `404 Not Found`.

### 63.4 PostgreSQL RPC: `sync_create_payment`
Executed under `SECURITY DEFINER` within a single PostgreSQL ACID transaction:
1. **Idempotency Check**: Queries `sync_idempotency_log` by `operation_id`. If existing, immediately returns the previously recorded payload without re-inserting or incrementing `orders.paid_amount`.
2. **Payload Validation**: Validates UUID formats, `amount > 0`, and allowed payment methods.
3. **Concurrency Protection**: Locks the referenced order row using `SELECT total, paid_amount, status FROM orders WHERE id = v_order_id FOR UPDATE`.
4. **Business Rule Enforcement**:
   - Rejects payments for cancelled orders (`HTTP 409 CONFLICT`).
   - Calculates remaining balance: `remaining = total - paid_amount`.
   - Rejects overpayment if `amount > remaining` (`HTTP 409 CONFLICT`).
5. **Atomic Payment & Balance Mutation**:
   - `INSERT INTO payments (...) VALUES (...)`.
   - `UPDATE orders SET paid_amount = paid_amount + v_amount, updated_at = now() WHERE id = v_order_id`.
6. **Idempotency Logging**: Inserts record into `sync_idempotency_log` within the same transaction.
7. **Return Payload**: Returns JSON representation of the persisted payment.

---

## 64. Step 11 — Expense & Expense Category Synchronization Specification

### 64.1 Overview
The expense and expense category synchronization pipeline provides offline-first expense management with remote persistence to Supabase. Local mutations occur atomically in SQLite/Drift and enqueue self-contained JSON payloads in `sync_operations`. When online, the `SyncEngine` dispatches these operations through `RemoteApiDispatcher`, calling Retrofit endpoints which proxy through Supabase Edge Functions to transactional `SECURITY DEFINER` PostgreSQL RPCs.

```text
AddExpenseDialog / ExpenseCategoryManagement
        ↓
ExpenseRepositoryImpl / ExpenseCategoryRepositoryImpl
        ↓
Local Drift Transaction
        ├── expense_categories / expenses (inserted/updated locally)
        └── sync_operations (enqueued with self-contained payload)
        ↓
SyncEngine
        ↓
RemoteApiDispatcher
        ↓
ExpenseRemoteApi / ExpenseCategoryRemoteApi
        ├── @POST('/api/v1/expense-categories') / @PATCH('/api/v1/expense-categories/{id}')
        └── @POST('/api/v1/expenses') / @PATCH('/api/v1/expenses/{id}')
        ↓
Supabase Edge Function (/api/v1/expense-categories, /api/v1/expenses)
        ↓
PostgreSQL RPCs (sync_create_expense_category, sync_update_expense_category, sync_create_expense, sync_update_expense)
        ↓
Atomic ACID Transaction (validation, mutation, sync_idempotency_log)
```

### 64.2 Entity & Payload Mapping

#### Expense Categories
- **Local Domain**: `ExpenseCategory` (`id`, `name`, `isActive`, `createdAt`, `updatedAt`).
- **Normalized Uniqueness**: Category names are unique regardless of case and surrounding whitespace (`LOWER(TRIM(name))`). Duplicate attempts return `HTTP 409 CONFLICT`.
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "name": "<string>",
    "is_active": true,
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "name": "<string>",
    "is_active": true,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Status (Activate/Deactivate) Payload**:
  ```json
  {
    "is_active": true,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

#### Expenses
- **Local Domain**: `Expense` (`id`, `categoryId`, `amount`, `expenseName`, `expenseDate`, `notes`, `categoryNameSnapshot`, `createdAt`, `updatedAt`).
- **Monetary Units**: Integer minor units (piastres / `BIGINT`). Zero or negative amounts are invalid (`amount > 0`).
- **Expense Date**: Stored as date-only `YYYY-MM-DD` (never shifted by timezone offsets).
- **Category Name Snapshot**: Historical snapshot preserved at time of creation (`category_name_snapshot`).
- **Custom Name Validation**: If category snapshot is `'أخرى'`, `expense_name` is mandatory and must be non-empty.
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "expense_category_id": "<UUID>",
    "amount": 15000,
    "expense_name": "<nullable string>",
    "expense_date": "2026-09-16",
    "notes": "<nullable string>",
    "category_name_snapshot": "<string>",
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "amount": 15000,
    "expense_name": "<nullable string>",
    "expense_date": "2026-09-16",
    "notes": "<nullable string>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
  *(Note: `expense_category_id` is immutable once created and cannot be modified via update).*

### 64.3 Remote API & Edge Function Contracts

#### `/api/v1/expense-categories`
- `GET /api/v1/expense-categories`: Returns all categories ordered by `created_at ASC`. Supports optional `?is_active=true|false` query filter.
- `GET /api/v1/expense-categories/:id`: Returns single category or `404 Not Found`.
- `POST /api/v1/expense-categories`: Requires `X-Operation-ID`. Calls `sync_create_expense_category`. Returns `201 Created`.
- `PATCH /api/v1/expense-categories/:id`: Requires `X-Operation-ID`. Calls `sync_update_expense_category`. Returns `200 OK`.
- `DELETE /api/v1/expense-categories/:id`: Physical deletion is prohibited; returns `404 Not Found`.

#### `/api/v1/expenses`
- `GET /api/v1/expenses`: Returns expenses ordered by `expense_date DESC, created_at DESC`. Supports query filters:
  - `category_id` / `categoryId` (UUID)
  - `start_date` / `startDate` (`YYYY-MM-DD`)
  - `end_date` / `endDate` (`YYYY-MM-DD`)
  - `page`, `limit`, `offset` (pagination)
- `GET /api/v1/expenses/:id`: Returns single expense or `404 Not Found`.
- `POST /api/v1/expenses`: Requires `X-Operation-ID`. Calls `sync_create_expense`. Returns `201 Created`.
- `PATCH /api/v1/expenses/:id`: Requires `X-Operation-ID`. Calls `sync_update_expense`. Returns `200 OK`.
- `DELETE /api/v1/expenses/:id`: Physical deletion is prohibited; returns `404 Not Found`.

### 64.4 PostgreSQL RPCs & Database Constraints

All mutations run via `SECURITY DEFINER` RPCs within a single ACID transaction logging to `sync_idempotency_log`:

1. **`sync_create_expense_category(p_op_id text, p_category jsonb)`**:
   - Idempotency check on `p_op_id`: returns existing payload if duplicate.
   - Validates non-empty `id` and non-empty trimmed `name`.
   - Rejects duplicate normalized name via unique index `idx_expense_categories_name_lower` (`HTTP 409 CONFLICT`).
   - Inserts row and logs operation. Returns entity JSON.

2. **`sync_update_expense_category(p_op_id text, p_category_id text, p_category jsonb)`**:
   - Idempotency check on `p_op_id`: returns existing payload if duplicate.
   - Verifies category exists (`P0002` / `HTTP 404 NOT_FOUND` if missing).
   - Updates `name`, `is_active`, and `updated_at`.
   - Logs operation and returns updated entity JSON.

3. **`sync_create_expense(p_op_id text, p_expense jsonb)`**:
   - Idempotency check on `p_op_id`: returns existing payload if duplicate.
   - Validates `amount > 0` and `expense_date`.
   - Verifies referenced `expense_category_id` exists (`23503` / `HTTP 400 FOREIGN_KEY_VIOLATION`).
   - Validates that if `category_name_snapshot == 'أخرى'`, `expense_name` must be non-empty (`HTTP 422 VALIDATION_ERROR`).
   - Inserts expense row and logs operation. Returns entity JSON.

4. **`sync_update_expense(p_op_id text, p_expense_id text, p_expense jsonb)`**:
   - Idempotency check on `p_op_id`: returns existing payload if duplicate.
   - Verifies expense exists (`P0002` / `HTTP 404 NOT_FOUND` if missing).
   - Validates `amount > 0` if amount is being updated.
   - Updates `amount`, `expense_name`, `expense_date`, `notes`, and `updated_at`. Protects `expense_category_id` from mutation.
   - Logs operation and returns updated entity JSON.

#### Security & Access Control
- Remote tables `public.expense_categories` and `public.expenses` have Row Level Security (RLS) enabled.
- Default-deny policies prevent direct access from `anon` and `authenticated` roles.
- Flutter interacts exclusively via Edge Functions using `service_role` through transactional RPCs.

---

## 65. Step 12 — Master Data & Settings Synchronization Specification

### 65.1 Overview
Master Data and Business Settings synchronization completes remote persistence for all configuration entities in the Laundry Management System:
1. `ItemType` (Clothing categories / types)
2. `ItemDefinition` (Specific laundry service items belonging to an `ItemType`)
3. `CarpetSize` (Configurable carpet dimensions `length x width` with calculated `area`)
4. `StorageLocation` (Physical storage shelves/bins with many-to-many supported item types)
5. `BusinessSettings` (Singleton shop configuration: name, phone, address, tax rate, receipt note, etc.)

Local mutations occur atomically within Drift transactions in their respective repository implementations (`ItemTypeRepositoryImpl`, `ItemDefinitionRepositoryImpl`, `CarpetSizeRepositoryImpl`, `StorageLocationRepositoryImpl`, `SettingsRepositoryImpl`), simultaneously enqueuing self-contained JSON payloads into `sync_operations`. When online, mutations dispatch through the Supabase Edge Function `api` to transactional `SECURITY DEFINER` PostgreSQL RPCs with idempotency logging in `sync_idempotency_log`.

### 65.2 Entity & Payload Schema Mapping

#### 1. Item Types (`item_types`)
- **Local Domain**: `ItemType` (`id`, `name`, `isActive`, `createdAt`, `updatedAt`).
- **Normalized Uniqueness**: Case-insensitive and trimmed name uniqueness (`UNIQUE (name)`).
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "name": "<string>",
    "is_active": true,
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "name": "<string>",
    "is_active": true,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

#### 2. Item Definitions (`item_definitions`)
- **Local Domain**: `ItemDefinition` (`id`, `itemTypeId`, `name`, `pricingType`, `defaultPrice`, `isActive`, `createdAt`, `updatedAt`).
- **Foreign Key**: References `item_types(id)` with `ON DELETE RESTRICT`.
- **Pricing Type Mapping**: `perItem` → `"fixed"`, `perMeter` → `"per_meter"`, `custom` → `"custom"`.
- **Monetary Unit**: Minor units (piastres / `BIGINT`).
- **Composite Uniqueness**: `UNIQUE (item_type_id, name)`.
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "item_type_id": "<UUID>",
    "name": "<string>",
    "pricing_type": "fixed | per_meter | custom",
    "default_price": 2500,
    "is_active": true,
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "name": "<string>",
    "pricing_type": "fixed | per_meter | custom",
    "default_price": 2500,
    "is_active": true,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

#### 3. Carpet Sizes (`carpet_sizes`)
- **Local Domain**: `CarpetSize` (`id`, `length`, `width`, `area`, `isActive`, `createdAt`, `updatedAt`).
- **Dimensions**: Floating point numbers > 0. Unique index on `UNIQUE (length, width)`.
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "length": 3.5,
    "width": 2.5,
    "area": 8.75,
    "is_active": true,
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "length": 4.0,
    "width": 2.5,
    "area": 10.0,
    "is_active": true,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

#### 4. Storage Locations (`storage_locations` & `storage_location_item_types`)
- **Local Domain**: `StorageLocation` (`id`, `name`, `supportedItemTypeIds`, `isActive`, `createdAt`, `updatedAt`).
- **Uniqueness**: `name` is unique.
- **Many-to-Many Linking**: Link table `storage_location_item_types` links storage locations to multiple `item_types` with `ON DELETE CASCADE`.
- **Create Payload**:
  ```json
  {
    "id": "<UUID>",
    "name": "<string>",
    "is_active": true,
    "supported_item_type_ids": ["<UUID>", "<UUID>"],
    "created_at": "<ISO-8601 UTC>",
    "updated_at": "<ISO-8601 UTC>"
  }
  ```
- **Update Payload**:
  ```json
  {
    "name": "<string>",
    "is_active": true,
    "supported_item_type_ids": ["<UUID>"],
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

#### 5. Business Settings (`business_settings`)
- **Local Domain**: `BusinessSettings` (`businessName`, `phoneNumber`, `address`, `taxRate`, `taxNumber`, `receiptFooterText`, `logoUrl`, `printerPaperSize`, `autoBackupEnabled`, `syncFrequencyMinutes`, `updatedAt`).
- **Singleton Row**: Stored remotely with primary key `id = 'singleton'`. Always mutated via `PATCH /business-settings`.
- **Tax Rate**: Must be between 0.0 and 1.0 inclusive (`CHECK (tax_rate >= 0 AND tax_rate <= 1)`).
- **Update Payload**:
  ```json
  {
    "business_name": "مغسلة النور",
    "phone_number": "01012345678",
    "address": "القاهرة",
    "tax_rate": 0.14,
    "tax_number": "123-456-789",
    "receipt_footer_text": "شكراً لتعاملكم معنا",
    "logo_url": null,
    "printer_paper_size": "80mm",
    "auto_backup_enabled": true,
    "sync_frequency_minutes": 15,
    "updated_at": "<ISO-8601 UTC>"
  }
  ```

### 65.3 Remote API & Edge Function Contracts
- **Endpoints**:
  - `/api/v1/item-types`: `GET`, `GET /:id`, `POST`, `PATCH /:id`
  - `/api/v1/item-definitions`: `GET`, `GET /:id`, `POST`, `PATCH /:id`
  - `/api/v1/carpet-sizes`: `GET`, `GET /:id`, `POST`, `PATCH /:id`
  - `/api/v1/storage-locations`: `GET`, `GET /:id`, `POST`, `PATCH /:id`
  - `/api/v1/business-settings`: `GET`, `PATCH`
- **Immutability / Deletion Policy**: Physical deletion is prohibited across all master data and settings in V1. `DELETE` on all endpoints returns `404 Not Found`. Deactivation is performed via `is_active: false` in `PATCH`.
- **Idempotency**: All mutation endpoints require and validate the `X-Operation-ID` header.

### 65.4 PostgreSQL RPCs
9 transactional `SECURITY DEFINER` RPCs were deployed via migration `20260916000004_master_data_schema.sql`:
1. `sync_create_item_type(p_op_id, p_item_type)`
2. `sync_update_item_type(p_op_id, p_item_type_id, p_item_type)`
3. `sync_create_item_definition(p_op_id, p_item_def)`
4. `sync_update_item_definition(p_op_id, p_item_def_id, p_item_def)`
5. `sync_create_carpet_size(p_op_id, p_carpet_size)`
6. `sync_update_carpet_size(p_op_id, p_carpet_size_id, p_carpet_size)`
7. `sync_create_storage_location(p_op_id, p_location)`
8. `sync_update_storage_location(p_op_id, p_location_id, p_location)`
9. `sync_update_business_settings(p_op_id, p_settings)`

All RPCs log to `sync_idempotency_log` within the transaction and return cached results on replay. Default-deny RLS is enforced across all master data tables.

---

## 66. Dashboard Operational Aggregation & Offline-First Reactivity

The Dashboard operates in accordance with the system's Offline-First principles:

### 66.1 Architecture & Local Source of Truth
- **Zero Remote Dependencies**: The Dashboard does not issue remote HTTP queries or RPCs. It reads exclusively from the local Drift SQLite database.
- **Database-Side Aggregation**: All operational overview metrics (`todayOrdersCount`, `readyOrdersCount`, `processingOrdersCount`, `totalRemaining`, `unpaidOrdersCount`, `overdueOrdersCount`, `todayPickupOrdersCount`) are evaluated within SQLite using conditional aggregations (`SUM(CASE ...)`). Dart memory is not used to scan or filter full table collections.
- **Enrichment**: Recent orders and today's pickups are retrieved with minimal joins and enriched with `PaymentSummary` calculations directly from local records.

### 66.2 Reactive Stream via Drift Table Updates
- **Mechanism**: `DashboardRepository.watchDashboardData()` observes local table events via `db.tableUpdates()` for `orders`, `payments`, `storage_records`, and `order_items`.
- **Automatic Sync Reflection**: When the background sync worker or local operations insert, update, or delete records in any of the 4 operational tables, `db.tableUpdates` triggers an immediate re-evaluation of `getDashboardData()`.
- **No Polling**: No background polling loops or periodic timers are utilized.
- **Clean Disposals**: Because `tableUpdates` operates via broadcast stream controllers rather than query stream listeners, subscription cancellations cleanly dispose without leaving unexecuted timer callbacks or lingering tasks.

---

## 67. Remote Change Application & Echo Loop Prevention (`RemoteChangeApplier`)

### 67.1 Echo Loop Problem
If remote changes pulled from the server were passed into standard repository methods (e.g. `orderRepository.createOrder()` or `paymentRepository.recordPayment()`), those methods would automatically call `syncOperationsDao.recordOperation()`, creating a circular ping-pong synchronization loop where pulled changes are uploaded back to the server.

### 67.2 Architecture of `RemoteChangeApplier`
The `RemoteChangeApplier` is a dedicated infrastructure service responsible for applying pulled changes directly to local storage:
- Injected with Drift DAOs: `OrdersDao`, `CustomersDao`, `PaymentsDao`, `StorageRecordsDao`, `ExpensesDao`, `ExpenseCategoriesDao`, `MasterDataDao`, `SettingsDao`, `SyncStateDao`.
- Bypasses repository mutation layers entirely.
- Executes within an ACID Drift transaction:
  ```dart
  await db.transaction(() async {
    for (final change in batch) {
      await _applySingleChange(change);
    }
    await syncStateDao.updateLastAppliedSequence(lastSequenceInBatch);
  });
  ```
- Guaranteed invariant: **Zero `SyncOperation` records are enqueued** during remote change application.
- Triggering UI reactivity: Direct DAO writes emit SQLite table update notifications, automatically notifying reactive Drift stream queries (`db.tableUpdates()`) and refreshing Cubits/screens without manual UI re-fetch calls.

---

## 68. Cursor-Based Pull Contract & Change Tracking (`sync_changes`)

### 68.1 Conceptual Schema of `sync_changes`
The remote PostgreSQL database maintains a durable, append-only synchronization change log:

| Column | Type | Nullable | Description |
|---|---|---|---|
| `sequence` | `BIGSERIAL` / `BIGINT` | No | Monotonically increasing primary key and pull cursor |
| `operation_id` | `TEXT` | No | Stable ID of the client operation that triggered the change |
| `entity_type` | `TEXT` | No | Entity type (`order`, `customer`, `payment`, `expense`, etc.) |
| `entity_id` | `TEXT` | No | Stable UUID of the affected entity |
| `operation_type` | `TEXT` | No | `create`, `update`, `deactivate` |
| `payload` | `JSONB` | No | Canonical post-change snapshot required to reconstruct local state |
| `server_version` | `INTEGER` | Yes | Entity version after mutation (null for unversioned entities) |
| `created_at` | `TIMESTAMPTZ` | No | Server commit timestamp (`now()`) |

### 68.2 Change Granularity: Hybrid Model
- **Order Creation Aggregate**: For newly created orders, `sync_changes` records a single aggregate change (`entity_type = 'order'`, `operation_type = 'create'`) with a payload containing the complete canonical state (order header, all order items, carpet dimensions). This guarantees relational integrity on pull.
- **Subsequent Mutations**: Status transitions, payments, storage moves, and cancellations are logged as independent, entity-specific change records.

### 68.3 Pull Endpoint Contract
- **Route**: `GET /api/v1/sync/changes`
- **Query Parameters**:
  - `after`: `BIGINT` (required, the client's `last_applied_sequence`)
  - `limit`: `INTEGER` (optional, default 100, max 500)
- **Response `200 OK`**:
  ```json
  {
    "changes": [
      {
        "sequence": 1042,
        "operation_id": "<UUID>",
        "entity_type": "order",
        "entity_id": "<UUID>",
        "operation_type": "create",
        "payload": { ... },
        "server_version": 1,
        "created_at": "2026-09-17T15:30:00.000Z"
      }
    ],
    "has_more": false,
    "latest_sequence": 1042
  }
  ```
- **Error `410 Gone` (`CURSOR_TOO_OLD`)**:
  If `after < oldest_retained_sequence` in `sync_changes`:
  ```json
  {
    "error": "CURSOR_TOO_OLD",
    "oldest_available_sequence": 500,
    "message": "Client cursor has expired; full resync required."
  }
  ```

### 68.4 Recovery & Bootstrap Invariant
- When `CURSOR_TOO_OLD` is received, the client triggers a controlled full resync/bootstrap.
- **CRITICAL INVARIANT**: Locally pending operations in `sync_operations` must **NEVER be deleted**. Pending local changes remain queued and are pushed to the server after the baseline snapshot is re-established.

---

## 69. Realtime Wake-Up Signal Adapter

### 69.1 Purpose
Supabase Realtime is utilized strictly as an **ephemeral wake-up notification adapter** to eliminate unnecessary polling when two devices are online simultaneously.

### 69.2 Principles
- **No Authoritative Data**: The Realtime payload contains only a lightweight notification (`{ "event": "sync_available", "latest_sequence": 1045 }`).
- **No Direct Mutation**: The Realtime message does NOT modify the local database directly.
- **Trigger Pull**: Upon receiving `sync_available`, the client adapter signals `SyncEngine.triggerPull()`.
- **Single-Flight Concurrency Guard**: `SyncEngine` ensures that only one pull request is active at any time. Duplicate or overlapping Realtime signals are collapsed into the next single-flight pull.
- **Resilience**: If the Realtime connection drops, the client continues normal operation and falls back to foreground pull triggers (app startup, app resume, connectivity restoration, periodic foreground timer).

---

## 70. Structured Semantic Error Classification & Queue Isolation

### 70.1 Semantic Error Codes
The remote API must return structured JSON error responses rather than monolithic `HTTP 409` strings:

```json
{
  "error": "CONCURRENCY_CONFLICT",
  "code": 409,
  "message": "Base version 1 does not match current server version 2",
  "entity_type": "order",
  "entity_id": "<UUID>",
  "current_server_version": 2
}
```

Standard codes:
- `DUPLICATE_ENTITY`: Entity identity already exists with conflicting non-idempotent payload.
- `CONCURRENCY_CONFLICT`: Optimistic concurrency check failed (`server_version != base_version`).
- `BUSINESS_RULE_VIOLATION`: Domain rule rejected mutation.
- `INVALID_REFERENCE`: Referenced foreign entity is missing remotely.
- `PAYMENT_BALANCE_EXCEEDED`: Payment amount exceeds order's remaining balance.
- `INVALID_LIFECYCLE_TRANSITION`: Requested order status transition violates lifecycle rules.

### 70.2 Queue Conflict Isolation in `SyncEngine`
- When an operation receives a permanent semantic error or concurrency conflict:
  - The operation's status in `sync_operations` is marked `failed` with the structured error details.
  - The `SyncEngine` isolates the failed operation and **continues processing independent, unrelated operations** in the queue.
  - Unrelated orders, payments, expenses, or master data are not blocked by a single isolated failure.