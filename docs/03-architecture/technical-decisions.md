# Laundry Management System — Technical Decisions

## 1. Document Purpose

This document records the approved technical decisions for V1 of the Laundry Management System.

The purpose of this document is to prevent unnecessary technology changes and prevent AI coding tools from making independent architectural decisions during implementation.

This document contains technical decisions only.

Detailed business requirements are defined in:

    docs/01-product/

Domain definitions are defined in:

    docs/02-domain/

Architecture rules are defined in:

    docs/03-architecture/architecture.md

Project structure is defined in:

    docs/03-architecture/project-structure.md

Data Layer rules are defined in:

    docs/03-architecture/data-layer.md

Synchronization rules are defined in:

    docs/03-architecture/sync-strategy.md

---

## 2. Decision Status

Each technical decision should have one of the following statuses:

    Approved
    TBD
    Deferred

### Approved

The technology or approach has been selected and must be used unless the documentation is intentionally changed.

### TBD

The decision has not been finalized yet.

AI tools must not make a permanent decision for TBD items without explicit approval.

### Deferred

The decision is intentionally postponed because it is not required for the current implementation stage.

---

## 3. Technology Stack

### Application

    Flutter

Status:

    Approved

Flutter is the primary application framework.

---

### Programming Language

    Dart

Status:

    Approved

The application must use Dart.

---

## 4. Platform Direction

The application is intended primarily for:

    Tablet

The UI should be designed with tablet usage as the primary target.

The architecture should remain capable of supporting other screen sizes.

Status:

    Approved

---

## 5. Language and Direction

Primary application language:

    Arabic

Text direction:

    RTL

Status:

    Approved

The application should be designed Arabic-first.

Localization should still be structured so that additional languages can be introduced later.

---

## 6. State Management

State management:

    Flutter Bloc / Cubit

Status:

    Approved

Cubit should be preferred for straightforward feature state.

Bloc may be used when a feature genuinely benefits from event-driven state management.

The project must not introduce another state-management solution without an explicit architectural decision.

---

## 7. Architecture Style

Architecture style:

    Feature-based
    +
    Simplified Layered Architecture
    +
    Repository Pattern
    +
    Offline-first

Status:

    Approved

The architecture intentionally avoids unnecessary Clean Architecture layers.

---

## 8. Use Cases

Dedicated Use Case classes:

    Not used in V1

Status:

    Approved

The preferred flow is:

    Presentation
        ↓
    Repository
        ↓
    Data Source

A Use Case layer must not be introduced automatically.

A dedicated abstraction may be introduced later only if a real complexity problem justifies it.

---

## 9. Mappers

Dedicated Mapper classes:

    Not used in V1

Status:

    Approved

Simple conversions should live in an appropriate existing layer.

Possible locations include:

- Repository
- Data Source
- Model
- `fromJson`
- `toJson`

A Mapper layer must not be introduced automatically.

---

## 10. Dependency Injection

The project should use centralized Dependency Injection.

Status:

    Approved

All major dependencies should be registered centrally.

Examples:

- Database
- Network Client
- Data Sources
- Repository Implementations
- Cubits / Blocs

The exact Dependency Injection package:

    get_it

The AI must not permanently select a DI package without an explicit decision.

---

## 11. Local Database

The local database technology:

    SQLite

Flutter integration:

    Drift

Status:

    Approved

SQLite is the primary local relational database.

Drift is the approved Flutter/Dart database layer used to interact with SQLite.

The local database must support:

- Offline operation
- Transactions
- Relationships
- Pagination
- Search
- Filtering
- Reliable persistence
- Type-safe database access

The project must not replace SQLite with another database technology without an explicit architectural decision.

---

## 12. SQLite and Drift Responsibilities

SQLite is responsible for persistent relational data storage.

Drift is responsible for providing the application-side database abstraction and type-safe access to SQLite.

Conceptually:

    Flutter Application
            ↓
          Drift
            ↓
          SQLite
            ↓
      Local Database File

The rest of the application should not depend directly on SQLite implementation details.

Database-specific code belongs inside:

    data/local/

---

## 13. Database Architecture

The database must support relational business data.

Status:

    Approved

The database must preserve relationships such as:

    Customer
        ↓
    Order
        ↓
    OrderItem
        ↓
    StorageRecord

and:

    Order
        ↓
    Payment

The implementation must not flatten these relationships simply to simplify the code.

---

## 14. Remote Networking

Remote communication:

    HTTP-based API

Status:

    Approved

The exact networking package:

    Dio + Retrofit

The network layer must be centralized.

Feature Cubits must not directly perform HTTP requests.

---

## 15. API Client

The application should use one centralized API client.

Status:

    Approved

The API client is responsible for infrastructure concerns such as:

- Base URL
- Headers
- Authentication
- Timeouts
- Interceptors
- Error handling
- Serialization support

Feature repositories should use the centralized network infrastructure.

## 16. Remote API Technology

The approved remote networking stack is:

    Dio
    +
    Retrofit

Status:

    Approved

Dio is responsible for the underlying HTTP client infrastructure.

Retrofit is responsible for defining typed API interfaces and endpoint contracts.

Do not introduce alternative HTTP clients or API frameworks alongside Dio and Retrofit.

---

## 17. Serialization

The project should use structured serialization for API/local models where needed.

Status:

    Approved

The exact serialization/code-generation approach:

    TBD

The implementation should avoid manually duplicating large amounts of JSON parsing code when a stable serialization solution is available.

---

## 18. Routing

Application navigation should be centralized.

Status:

    Approved

The project should use one routing solution consistently.

The exact routing package:

    go_router

Feature screens must not create independent navigation systems.

---

## 19. Localization

Localization:

    Required

Status:

    Approved

The application must use a centralized localization mechanism.

All user-facing strings should be localized.

The exact localization package/implementation:

    TBD

---

## 20. Design System

The project must have one Design System source of truth.

Status:

    Approved

The main theme should be built from centralized files such as:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

The global application theme must use these definitions.

Feature screens must not define independent global colors or typography systems.

---

## 21. Offline-first

Offline-first architecture:

    Required

Status:

    Approved

Normal business operations must work without an internet connection.

The local database is the primary operational source of truth.

The backend is synchronized afterward.

---

## 22. Synchronization

Synchronization strategy:

    Local-first
    +
    Durable Sync Queue
    +
    Remote Synchronization

Status:

    Approved

The Sync Engine is responsible for:

- Pending operations
- Retry
- Ordering
- Remote synchronization
- Failure handling
- Sync status

The UI must not implement synchronization directly.

---

## 23. Sync Queue Persistence

The synchronization queue must be persistent.

Status:

    Approved

The queue must survive:

- Application restart
- Temporary connectivity loss
- Application crash

The queue must not exist only in memory.

---

## 24. Sync Retry

Retry strategy:

    Exponential Backoff
    +
    Maximum Retry Count
    +
    Permanent Failure State

Status:

    Approved

The retry architecture is finalized:

- Retryable failures (connectivity, timeout, temporary server error) are retried with exponential backoff.
- Non-retryable failures (permanent business/validation errors) transition to a permanent failure state and are not retried.
- A maximum retry count limits how many retries are attempted before an operation is permanently failed.
- Retries are idempotent: retrying the same operation with the same stable operation ID must never create duplicate business records.

The exact numeric values (initial delay, backoff multiplier, maximum delay, maximum retry count) are implementation-level configuration, not architectural constants.

Those values must be chosen during synchronization implementation based on observed platform behavior, battery constraints, and backend requirements.

The application must avoid aggressive continuous retry loops.

---

## 25. Sync Idempotency

Critical synchronization operations must be idempotent.

Status:

    Approved

This is especially important for:

- Payments
- Order creation
- Customer creation
- Storage operations

A retry must not accidentally create duplicate business records.

The approved idempotency architecture is:

- Every sync queue operation has a **stable, unique operation ID** generated by the client when the operation is created.
- The same operation ID is preserved across all retry attempts.
- The backend uses the operation ID to recognize and safely handle duplicate deliveries without creating duplicate business effects.
- The client must never generate a new operation ID on retry.

The exact transport mechanism for communicating the operation ID to the backend (e.g., dedicated header, request body field, idempotency key) is an implementation-level detail to be finalized with the backend API contract.

---

## 26. Conflict Resolution

Conflict handling status:

    Basic deterministic conflict handling: Approved for V1 sync
    Advanced multi-device conflict resolution: Deferred

For the current Offline / Sync Integration phase:

- Conflict resolution must be **deterministic** and **entity-specific**.
- Do NOT implement a generic "last write wins" policy for all entities.
- For each conflict-prone entity, the appropriate strategy must be defined at the domain / business-rule level.
- Financial records (Payments, Expenses) must never be silently overwritten, duplicated, or lost through conflict resolution.
- Conflicts that cannot be automatically resolved must fail safely rather than silently corrupting data.

The following remain deferred from the current implementation phase:

- Complex merge algorithms
- Distributed conflict resolution
- CRDTs
- Real-time collaboration conflict resolution
- Distributed locking

The architecture must remain extensible for future multi-device requirements.

---

## 27. Background Synchronization

Background synchronization:

    Optional / Platform-dependent

Status:

    Deferred

The system must not depend exclusively on background execution.

Synchronization must also be triggered through:

- Application startup
- App resume
- Connectivity restoration
- Manual synchronization
- Post-write synchronization attempts

---

## 28. Pagination

Pagination:

    Required

Status:

    Approved

Pagination must be supported from the beginning because business data will grow over time.

Pagination should be implemented at the Data Layer.

The UI should not directly manage database-specific pagination details.

---

## 29. Local Search

Local search:

    Required

Status:

    Approved

Normal searches should work offline.

Examples:

- Customer name
- Customer phone
- Order number

Search should be executed through the Repository/Data Layer.

---

## 30. Local Filtering

Local filtering:

    Required

Status:

    Approved

Large datasets should be filtered at the database/query level where practical.

The application should avoid loading the entire dataset into memory simply to filter it in Dart.

---

## 31. Database Transactions

Database transactions:

    Required

Status:

    Approved

Transactions must be used for business operations that modify multiple related records.

Examples:

- Create Order
- Complete Order
- Cancel Order
- Move OrderItem
- Bulk Storage
- Payment operations when multiple records are modified

---

## 32. Financial Precision

Financial values must not rely on unsafe floating-point calculations for persisted monetary amounts.

Status:

    Approved

The exact representation:

    TBD

A minor-unit integer representation may be used if appropriate.

The selected representation must remain consistent throughout the system.

---

## 33. Date Handling

The application must distinguish between:

    Date Only

and:

    Date + Time

Status:

    Approved

Expected Pickup is:

    Date Only

The implementation must preserve this business meaning.

---

## 34. ID Strategy

All synchronizable business entities must have stable identifiers.

Status:

    Approved

The ID strategy must support:

- Local persistence
- Remote synchronization
- Retry
- Idempotency
- Stable references

The approved entity ID strategy is:

    Client-generated stable UUID (UUIDv4)

The UUID is generated by the Flutter client when the entity is first created locally.

The same UUID is used:

- In local Drift database storage
- In the Sync Queue operation payload
- In the remote / Supabase backend storage
- Across all retry attempts

The sync engine must never replace a local entity UUID with a newly generated remote ID.

A retry must not generate a new entity UUID.

Entity IDs must not depend on database auto-increment values that could produce different values across devices.

---

## 35. Error Handling

The application must use a consistent error-handling strategy.

Status:

    Approved

Infrastructure errors should not leak directly into Presentation.

Examples:

    Network Error
    Database Error
    Validation Error
    Business Rule Error
    Synchronization Error

The exact Result/Exception implementation:

    TBD

---

## 36. Logging

Application logging:

    Required

Status:

    Approved

Logs should help diagnose:

- API failures
- Database failures
- Synchronization failures
- Unexpected application errors

Logs must not unnecessarily expose sensitive information.

The exact logging package:

    TBD

---

## 37. Testing

Testing:

    Required

Status:

    Approved

The project should include tests for:

- Domain business rules
- Repository behavior
- Database operations
- Synchronization
- Cubit/Bloc state
- Important UI behavior

The exact testing libraries beyond Flutter/Dart's standard testing ecosystem:

    TBD

---

## 38. Code Generation

Code generation:

    TBD

No code-generation package should be introduced automatically.

If code generation is selected, it should be used consistently for the relevant models and generated code.

Drift's required code generation is an approved part of the selected database technology.

Additional code-generation systems remain TBD.

---

## 39. Image/File Storage

File and image storage requirements are not part of the core V1 architecture unless a concrete feature requires them.

Status:

    Deferred

No storage technology should be introduced prematurely.

---

## 40. Authentication

Authentication status:

    V1 Application End-User Authentication: Out of Scope (No Login/Registration UI)
    API Access / Service Authentication: Centralized Infrastructure Concern

Status:

    Approved

V1 does not implement an end-user authentication system (no login screens, user registration, user sessions, or user role management).

Any backend protection required for API access (e.g., API keys, service-level authentication) is handled centrally in the networking infrastructure layer (`networking-implementation.md` §15) and must not leak into feature code or UI.

---

## 41. Backend Dependency

The Flutter application must not embed backend-specific business rules inside UI code.

Status:

    Approved

Backend-specific behavior belongs behind:

    Repository
    +
    Remote Data Source

If backend limitations require an architectural decision, that decision must be documented.

---

## 42. Feature Communication

Features should not directly access the internal implementation of other features.

Status:

    Approved

Cross-feature requirements should communicate through:

- Domain entities
- Repository contracts
- Shared Domain services when genuinely necessary

Avoid direct:

    Feature A → Feature B Cubit

dependencies.

---

## 43. Shared Widgets

Shared widgets should live in:

    core/widgets/

Status:

    Approved

A widget should only become shared when it is actually reused or clearly represents a global application component.

Avoid creating generic widgets prematurely.

---

## 44. Shared Utilities

Shared utilities should live in:

    core/utils/

Status:

    Approved

Feature-specific utilities should remain inside the feature.

The `utils` directory must not become a dumping ground for unrelated business logic.

---

## 45. Naming Convention

Dart files:

    snake_case

Classes:

    PascalCase

Variables and methods:

    camelCase

Status:

    Approved

Examples:

    order_details_screen.dart
    OrderDetailsScreen
    expectedPickupDate

---

## 46. State Management Naming

Cubit names should follow:

    <Feature>Cubit

Examples:

    OrdersCubit
    CustomersCubit
    StorageCubit

Status:

    Approved

The project should maintain consistent naming across features.

---

## 47. Repository Naming

Domain contract:

    OrderRepository

Data implementation:

    OrderRepositoryImpl

Status:

    Approved

The same convention should be used consistently for other repositories.

---

## 48. Data Source Naming

Local:

    OrderLocalDataSource

Remote:

    OrderRemoteDataSource

Status:

    Approved

Names must describe the actual responsibility.

Avoid generic names such as:

    Helper
    Manager
    CommonService

unless they represent a real concept.

---

## 49. Architecture Restrictions

The following are not allowed by default:

    UseCases
    Mappers
    Application Layer
    Generic Repository Framework
    Generic CRUD Framework
    Multiple State Management Solutions
    Multiple Routing Systems
    Multiple Network Clients
    Unnecessary Caching Layers
    Premature Conflict Resolution

Status:

    Approved

Any exception requires an explicit architectural decision.

### Architectural Exception — Task #04 Application / UseCase Workflows

Status:

    Approved

An Application layer (`lib/application/use_cases/`) is explicitly approved for complex, multi-step business workflow orchestration:
- `CreateOrderUseCase`
- `StoreOrderItemsUseCase`
- `MoveStoredItemUseCase`
- `ChangeOrderStatusUseCase`
- `CompleteOrderUseCase`
- `CancelOrderUseCase`

**Principles**:
- UseCases are selective workflow orchestrators, NOT mandatory CRUD wrappers.
- Simple entity CRUD remains direct between Presentation/Cubits and Repositories.
- Application UseCases remain pure Dart with zero Flutter, Drift, SQLite, or DAO dependencies.
- UseCases encapsulate cross-repository transactions, lifecycle transition matrices, physical item expansion, positive pricing validation, and handover/balance verification.

---

## 50. AI Coding Tool Policy

AI coding tools must treat this document as the source of truth for technical decisions.

The AI must not:

- Change the database technology without approval
- Change the state-management solution
- Add Use Cases
- Add Mapper layers
- Introduce another architecture
- Add another networking package
- Add another routing solution
- Add another state-management package
- Introduce unnecessary abstractions

If a required technology is marked:

    TBD

the AI must not make a permanent decision silently.

---

## 51. AI Package Selection Rule

When a technical decision is marked:

    TBD

the AI may suggest options.

It must not silently select one and build the entire project around it.

The decision should be explicitly approved first.

---

## 52. Package Minimization

The project should minimize external dependencies.

Before adding a package, determine:

1. Is the functionality genuinely required?
2. Can Flutter/Dart already provide it?
3. Is the package maintained?
4. Does it introduce unnecessary architectural complexity?
5. Does it fit the existing architecture?

A package should not be added simply because it is popular.

---

## 53. Technology Change Rule

Changing an Approved technology requires:

1. Identifying the reason.
2. Evaluating the impact.
3. Updating this document.
4. Updating affected architecture documentation.
5. Updating implementation.

AI tools must not replace an Approved technology silently.

---

## 54. Decision Priority

When technical decisions conflict, use this priority:

    Product Requirements
        ↓
    Domain Rules
        ↓
    Architecture
        ↓
    Technical Decisions
        ↓
    Implementation Details

Implementation convenience must not override approved business requirements.

---

## 55. Offline / Sync Integration — Approved / Active Implementation Phase

Status:

    Approved / Active

### 55.1 Phase Description

Offline / Sync Integration is now the **active** implementation phase.

It is not a new V1 business feature.

It is an infrastructure / integration phase that connects the existing Local-First application to the approved Supabase remote backend while preserving all existing business rules.

The Orders module has completed its Local-First implementation and final E2E verification.

### 55.2 Remote Backend Platform

    Supabase

Status:

    Approved

Supabase is the approved remote backend platform for the Offline / Sync Integration phase.

Supabase must remain behind the approved Remote Data Source boundary.

Feature-level code must not directly call Supabase.

### 55.3 Approved Architectural Constraints

The following constraints are binding for this phase and for all future phases unless explicitly superseded by a documented decision.

#### 55.3.1 Local-First Write Path

Local persistence is the primary client operation.

A network connection must never be required for normal approved V1 workflows.

Synchronization happens asynchronously after the local operation succeeds.

#### 55.3.2 Stable Entity Identity

Business entities that participate in synchronization must use stable UUIDs.

The same entity UUID must remain stable between local and remote storage.

The Sync Engine must never replace a local entity UUID with a newly generated remote ID.

#### 55.3.3 Stable Synchronization Operation Identity

Every synchronization operation must have a stable operation ID.

Retries must reuse the same operation ID.

Retrying an operation must not create duplicate logical records.

#### 55.3.4 Atomic Enqueue

A local business mutation and the corresponding synchronization operation must be persisted atomically in the same local transaction.

We must never end up with:

    business change without sync operation

OR:

    sync operation without the corresponding business change

#### 55.3.5 Idempotent Remote Processing

The remote / Supabase side must safely process retries.

Duplicate delivery of the same synchronization operation must not create duplicate business records.

#### 55.3.6 Separation Between Business State and Synchronization State

Sync state must NOT become part of business lifecycle state.

Do not introduce business statuses such as:

    PendingSync
    Syncing
    SyncFailed

Order lifecycle remains exactly the approved lifecycle:

    Processing → Ready → Completed
    or
    Processing → Cancelled

#### 55.3.7 Conflict Handling

Conflict resolution must be deterministic.

It must be defined at the entity / business-rule level.

It must NOT be delegated to UI behavior.

Do not assume generic last-write-wins is automatically correct for every entity.

#### 55.3.8 Financial Safety

Payments and other financial records require special protection.

Synchronization must never silently overwrite, duplicate, or lose financial history.

#### 55.3.9 Dependency-Aware Synchronization

Synchronization order must respect entity relationships and dependencies.

Parent / reference data must be available before dependent records when required by the backend.

Example:

    Customer must exist remotely before an Order referencing that Customer is synchronized.

#### 55.3.10 Architecture Boundary

Feature Cubits and Widgets must NOT contain synchronization engine logic.

They must not manage queues, retries, conflict resolution, connectivity detection, or synchronization triggers.

Sync belongs to the Data / Infrastructure layer and communicates through the approved repository / application boundaries.

#### 55.3.11 Future SaaS Readiness

The architecture should remain suitable for future multi-device / multi-tenant / SaaS evolution.

However, SaaS functionality itself is NOT part of the current implementation.

Do NOT introduce tenants, branches, roles, permissions, subscription management, or multi-tenant UI as part of this phase.

---

## 56. Current Approved Decisions Summary

The following decisions are currently approved:

    Flutter
    +
    Dart
    +
    Tablet-first UI
    +
    Arabic
    +
    RTL
    +
    Bloc / Cubit
    +
    Feature-based architecture
    +
    Repository pattern
    +
    Offline-first
    +
    SQLite
    +
    Drift
    +
    Local database as operational source of truth
    +
    Persistent Sync Queue
    +
    Supabase (remote backend for Offline / Sync Integration)
    +
    Pagination
    +
    Local Search
    +
    Local Filtering
    +
    Database Transactions
    +
    Centralized Theme
    +
    Centralized Localization
    +
    Centralized Dependency Injection
    +
    Stable Entity IDs
    +
    Stable Operation IDs & Idempotency
    +
    Exponential Backoff Retry Strategy
    +
    Dio + Retrofit (Remote Networking)
    +
    go_router (Routing)
    +
    Consistent Error Handling
    +
    Testing
    +
    No Use Case layer
    +
    No Mapper layer

---

## 57. Current TBD Decisions

The following technical decisions are intentionally not finalized yet:

    Dependency Injection Package
    Serialization / Additional Code Generation Approach
    Localization Package
    Logging Package
    Result / Exception Strategy
    Financial Value Representation
    API Idempotency Transport Mechanism

The following were previously TBD and are now resolved:

    Entity ID Generation Strategy    →  Client-generated stable UUID (UUIDv4)
    Sync Retry Architecture           →  Exponential backoff + max retry count + permanent failure state
                                         (exact numeric values remain implementation-level config)
    Sync Idempotency Architecture     →  Stable operation ID, same ID preserved across retries,
                                         backend uses ID to prevent duplicate effects
                                         (exact transport mechanism remains implementation-level detail)
    Remote Networking Stack           →  Dio + Retrofit (Approved)
    Routing Package                   →  go_router (Approved)
    V1 End-User Authentication        →  Out of scope for V1; API protection is centralized infrastructure

SQLite and Drift are no longer TBD.

They are Approved technical decisions.

---

## 58. Deferred Decisions

The following are intentionally deferred from V1:

    Advanced Multi-device Conflict Resolution
    Real-time Synchronization
    Complex Background Synchronization
    Distributed Locking
    CRDTs
    Event Sourcing
    Advanced Caching Architecture
    File/Image Storage Architecture when not required by V1

These should not be implemented unless requirements change.

---

## 59. Final Technical Direction

The V1 technical direction is:

    Flutter
        +
    Dart
        +
    Bloc / Cubit
        +
    Feature-based Architecture
        +
    Repository Pattern
        +
    SQLite
        +
    Drift
        +
    Local-first Database
        +
    Persistent Sync Queue
        +
    Remote API
        +
    Centralized Design System
        +
    Arabic / RTL
        +
    Tablet-first UI
        +
    Pagination
        +
    Local Search
        +
    Local Filtering
        +
    Simple Architecture
        +
    No Unnecessary Abstractions

The exact technology choices marked as TBD must be finalized before implementation of the corresponding technical layer.

---

## 60. Final Rule

The most important technical rule is:

> Do not add complexity unless the project has a concrete reason to need it.

The system should remain:

    Simple
    +
    Reliable
    +
    Offline-first
    +
    Maintainable
    +
    Testable
    +
    Consistent
    +
    Easy for AI coding tools to implement

Any significant technical decision made after this document is finalized must either fit within these principles or be explicitly documented as a new architectural decision.