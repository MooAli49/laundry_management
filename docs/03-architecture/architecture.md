# Laundry Management System — Architecture

## 1. Document Purpose

This document defines the approved V1 software architecture for the Laundry Management System.

The architecture is intentionally simple and practical.

The goal is to provide:

- Clear separation of responsibilities
- Offline-first operation
- Reliable local data
- Maintainability
- Testability
- Fast implementation
- Easy understanding by developers
- Easy and predictable implementation by AI coding tools

This document does not redefine the Product or Domain requirements.

The following documents remain the source of truth for their respective areas:

- `docs/01-product/`
- `docs/02-domain/`

---

## 2. Architecture Philosophy

The project should not follow Clean Architecture mechanically.

We will use only the abstractions that provide real value to the project.

V1 intentionally avoids unnecessary layers such as:

- Use Cases for every operation
- Dedicated Mapper classes
- Separate Application layer
- Excessive interfaces
- Generic abstractions
- Duplicate models without a real need

The architecture should follow this principle:

> Keep the project as simple as possible without sacrificing business correctness, offline reliability, or maintainability.

---

## 3. High-Level Architecture

The approved V1 architecture is:

    Presentation (Screens / Widgets / Cubits)
         ↓
    Application UseCases (Selective Workflows) OR Direct Repository
         ↓
    Repository Contracts (Domain)
         ↓
    Repository Implementations (Data)
         ↓
    Local / Remote Data Source

The Domain layer provides:

- Entities
- Enums
- Repository contracts
- Important domain logic

The Application layer (`lib/application/use_cases/`) provides:

- Selective orchestration for complex, multi-step business workflows (e.g. Order Creation, Storage, Relocation, Status Transitions, Completion, Cancellation)
- Cross-repository orchestration without coupling Cubits to multi-step business logic
- Strict pure Dart implementation (no Flutter, Drift, SQLite, or DAO dependencies)
- Note: UseCases are NOT mandatory CRUD wrappers; simple entity operations go directly to Repositories.

The Data layer provides:

- Repository implementations
- Local database (SQLite / Drift)
- Remote API
- Data models when needed
- Synchronization infrastructure

---

## 4. Main Layers

The project consists of five main architectural areas:

    Core
    Domain
    Application
    Data
    Features

Conceptually:

    ┌─────────────────────────────────────────┐
    │                Features                 │
    │       Screens / Widgets / Cubits        │
    └────────────────────┬────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │ (Complex Workflows)           │ (Simple CRUD)
         ↓                               ↓
    ┌─────────────────────────┐          │
    │       Application       │          │
    │  Selective Use Cases    │          │
    └────────────┬────────────┘          │
                 │                       │
                 └───────────┬───────────┘
                             ↓
    ┌─────────────────────────────────────────┐
    │                 Domain                  │
    │ Entities / Enums / Contracts / Rules   │
    └────────────────────┬────────────────────┘
                         ↓
    ┌─────────────────────────────────────────┐
    │                  Data                   │
    │ Repositories / Local / Remote / Models │
    └───────────────┬─────────────┬───────────┘
                    │             │
                    ↓             ↓
             Local Database   Remote API

The Core layer provides shared infrastructure and UI capabilities to the rest of the application.

---

## 5. Dependency Direction

The preferred dependency direction is:

    Feature Presentation
            ↓
    Repository Contract
            ↓
    Repository Implementation
            ↓
    Local / Remote Data Source

The Domain defines the repository contracts.

The Data layer implements those contracts.

Therefore:

    Presentation → Domain Contracts
    Data → Domain Contracts

The Domain must remain independent from Data and Presentation.

---

## 6. Domain Independence

The Domain must not depend on infrastructure technologies.

The Domain must not import or depend on:

- Flutter UI
- Widgets
- Dio
- HTTP clients
- Database packages
- SQL
- Local database models
- API DTOs
- SharedPreferences
- Platform-specific storage

The Domain represents business concepts, not technical implementation details.

---

## 7. Core Layer

The Core layer contains shared application infrastructure and reusable UI components.

Recommended structure:

    core/
    ├── constants/
    ├── errors/
    ├── localization/
    ├── network/
    ├── routing/
    ├── storage/
    ├── theme/
    ├── utils/
    └── widgets/

Core must not become a dumping ground for feature-specific logic.

If functionality belongs specifically to Orders, Customers, Storage, or another feature, it should remain within that feature.

---

## 8. Domain Layer

The Domain layer contains the application's business concepts.

Recommended structure:

    domain/
    ├── entities/
    ├── enums/
    ├── repositories/
    └── services/

### Domain responsibilities

The Domain contains:

- Entities
- Enums
- Repository contracts
- Important business rules
- Domain-level calculations
- Limited domain services when genuinely necessary

---

## 9. Domain Entities

Domain entities represent real business concepts.

Examples include:

    Customer
    Order
    OrderItem
    Payment
    StorageRecord
    StorageLocation
    Service
    ItemType
    ItemDefinition
    CarpetSize
    CarpetItemData
    BusinessSettings

Entities should reflect the approved Domain documentation.

The Domain should not contain infrastructure-specific models.

---

## 10. Domain Enums

Domain enums represent business concepts.

Examples:

    OrderStatus
    PricingType
    PaymentMethod

Enums should only be created when the concept genuinely represents a finite set of business states or options.

UI-only states should remain in the Presentation layer.

---

## 11. Repository Contracts

Repository contracts live in:

    domain/repositories/

Examples:

    OrderRepository
    CustomerRepository
    StorageRepository
    ServiceRepository
    PaymentRepository
    SettingsRepository

These contracts describe what the application needs from the data layer.

They do not describe how the data is stored.

---

## 12. Repository Implementations

Repository implementations live in:

    data/repositories/

Examples:

    OrderRepositoryImpl
    CustomerRepositoryImpl
    StorageRepositoryImpl
    ServiceRepositoryImpl
    PaymentRepositoryImpl
    SettingsRepositoryImpl

The implementation coordinates the appropriate local and remote data sources.

---

## 13. No Use Case Layer

V1 does not use a dedicated Use Case layer.

The preferred flow is:

    Screen
       ↓
    Cubit / Bloc
       ↓
    Repository
       ↓
    Local / Remote Data Source

Instead of:

    Screen
       ↓
    Cubit / Bloc
       ↓
    Use Case
       ↓
    Repository
       ↓
    Data Source

This reduces unnecessary files and indirection.

If a future workflow becomes sufficiently complex to justify a dedicated abstraction, it can be introduced intentionally.

It should not be created automatically for every operation.

---

## 14. No Mapper Layer

V1 does not use a dedicated Mapper layer.

We should not create a separate mapper class for every model conversion.

Simple conversions can live in an appropriate location such as:

- Repository
- Data source
- Model factory
- `fromJson`
- `toJson`

The important rule is:

> Conversion logic should have one clear owner and should not be duplicated unnecessarily.

---

## 15. Data Layer

The Data layer handles infrastructure and persistence.

Recommended structure:

    data/
    ├── local/
    ├── remote/
    ├── models/
    └── repositories/

The Data layer may depend on:

- Domain entities
- Domain repository contracts
- Database technology
- Network technology
- Serialization libraries
- Core infrastructure

The Data layer must not depend on Presentation.

---

## 16. Local Data Source

The local database is the primary operational data source.

The application must support normal daily operation without internet access.

Local data includes concepts such as:

    customers
    orders
    order_items
    item_types
    item_definitions
    services
    service_item_types
    carpet_sizes
    order_item_carpets
    storage_locations
    storage_records
    payments
    business_settings

The exact implementation and database technology are defined by the Data implementation phase.

---

## 17. Remote Data Source

The Remote Data Source is responsible for communicating with the backend.

It may use:

- REST
- JSON
- Dio
- Retrofit
- HTTP

The selected technologies remain inside the Data/Core infrastructure boundary.

The Domain must not know which networking technology is being used.

---

## 18. Local-First Principle

The application is Offline-first.

Normal operational reads should come from the local database.

Normal writes should be committed locally first.

Preferred flow:

    User Action
         ↓
    Cubit / Bloc
         ↓
    Repository
         ↓
    Local Database
         ↓
    UI Updated
         ↓
    Synchronization
         ↓
    Remote API

The user should not be blocked waiting for the backend during normal operations.

---

## 19. Offline Operation

The system must continue to support normal operations when offline.

Examples include:

- Customer management
- Order creation
- Order editing
- Order item management
- Storage
- Moving items
- Payments
- Dashboard
- Reports
- Local settings

Internet connectivity is required for synchronization, not for normal local operation.

---

## 20. Synchronization

Synchronization is a Data-layer responsibility.

Conceptually:

    Local Database
          ↓
    Pending Changes
          ↓
    Sync Engine
          ↓
    Remote API

The UI does not need to know the technical details of synchronization.

The repository and synchronization infrastructure coordinate local and remote persistence.

---

## 21. Sync Queue

Pending remote operations should be represented by a synchronization mechanism.

Conceptually, a pending operation may contain:

    Operation ID
    Entity Type
    Entity ID
    Operation Type
    Payload / Reference
    Created At
    Retry Information
    Sync Status

The exact database structure is an implementation decision.

The synchronization mechanism should support states such as:

    Pending
    Processing
    Synced
    Failed / Retryable

---

## 22. Synchronization Failure

Synchronization failure must never delete or invalidate valid local data.

If the remote API is unavailable:

    Local Data
        ↓
    Remains Valid
        ↓
    Sync Operation
        ↓
    Retry Later

The application should not require successful synchronization before considering a local operation successful.

---

## 23. Source of Truth

During normal daily operation:

    Local Database
          ↓
    Operational Source of Truth

The backend remains responsible for remote persistence and synchronization.

The application should not require the API for every screen load.

---

## 24. Repository Responsibilities

Repositories are responsible for:

- Reading data
- Writing data
- Updating data
- Deactivating data where appropriate
- Local queries
- Coordinating local and remote operations
- Synchronization coordination
- Transactions
- Returning appropriate Domain entities

Repositories are not responsible for:

- Screen UI
- Widget layout
- Navigation
- Presentation formatting
- UI state

---

## 25. Presentation Layer

Presentation exists inside each feature.

It contains:

- Screens
- Widgets
- Cubits / Blocs
- UI-specific models when actually needed

The Presentation layer is responsible for:

- User interaction
- Displaying data
- UI state
- Loading states
- Error states
- Forms
- Navigation
- Formatting
- Calling repositories through Cubits/Blocs

---

## 26. State Management

The project uses Bloc/Cubit.

The choice between Cubit and Bloc depends on feature complexity.

Simple state:

    Cubit

More event-driven or complex state:

    Bloc

The project should not introduce another state-management solution without an explicit architectural decision.

---

## 27. Cubit / Bloc Responsibilities

Cubit/Bloc is responsible for:

- Receiving user actions
- Calling repositories
- Managing UI state
- Loading states
- Success states
- Error states
- Search state
- Filter state
- Pagination state
- Sync status presentation

Cubit/Bloc must not directly access:

- SQL
- Database tables
- Dio
- HTTP
- Raw API responses

---

## 28. Business Logic Placement

Business logic should not automatically be placed inside Cubits.

Use the simplest appropriate location.

### Entity Logic

Logic directly related to one entity can live with the entity.

### Domain Service

Logic involving multiple domain concepts can use a Domain Service when genuinely necessary.

### Repository

Persistence and data coordination belong in repositories.

### Cubit / Bloc

UI state and interaction belong in Cubits/Blocs.

The goal is clear responsibility without unnecessary abstraction.

---

## 29. Feature-Based Organization

The application is organized around business features.

V1 features are:

    dashboard
    orders
    customers
    storage
    services
    reports
    settings

Each feature owns its UI and UI state.

Shared infrastructure remains in Core, Domain, or Data as appropriate.

---

## 30. Orders Feature

The Orders feature handles:

- Order list
- Order search
- Order filters
- Order creation
- Order editing
- Order details
- Order items
- Pricing interaction
- Payments related to orders
- Completion
- Cancellation

The Orders feature must use repository contracts rather than directly accessing databases.

---

## 31. Customers Feature

The Customers feature handles:

- Customer creation
- Customer editing
- Customer search
- Customer details
- Customer order history
- Starting an order for a customer

Customer history should be retrieved through the appropriate repository.

---

## 32. Storage Feature

The Storage feature handles:

- Current storage
- Items requiring storage
- Storing items
- Bulk storage
- Moving items
- Storage location management
- Search/filtering current storage

Storage operations work on physical OrderItems.

The architecture must not assume:

    One Order = One Storage Location

---

## 33. Services Feature

The Services feature handles master data such as:

- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Service compatibility
- Pricing configuration

Changing current master data must not silently change historical OrderItems.

---

## 34. Dashboard Feature

The Dashboard presents operational information such as:

- Today's orders
- Ready orders
- Items requiring storage
- Outstanding payments
- Overdue orders
- Today's expected pickups
- Recent orders

Dashboard data should be retrieved through repositories.

The Dashboard should not contain direct database queries.

---

## 35. Reports Feature

Reports should remain intentionally simple in V1.

The feature handles:

- Orders report
- Financial report
- Date filtering
- Report presentation

Reports should use local historical data.

Historical transaction values must not depend on current Service prices.

---

## 36. Settings Feature

The Settings feature handles editable business settings such as:

- Business Name
- Tax Enabled
- Tax Rate

Fixed V1 configuration should not be exposed as unnecessary settings.

Examples of fixed V1 configuration:

    Single Branch
    EGP Currency
    Arabic Language
    RTL

---

## 37. Order Pricing

Pricing logic should not be implemented directly inside widgets.

The pricing calculation should be performed by Domain logic or a small Domain Service when appropriate.

Supported V1 Operational Pricing Types are:

    Per Piece
    Fixed Price
    Per Square Meter

*(Note: Per Kilogram pricing has been completely removed from the V1 operational model and workflow by locked business decision).*

Historical OrderItem pricing must be preserved.

Current Service prices must not silently recalculate old orders.

---

## 38. Historical Snapshots

Historical values required to understand an OrderItem must be preserved at transaction time.

Examples include:

    Item Type Name
    Item Definition Name
    Service Name
    Pricing Type
    Unit Price
    Calculated Total

The application must not depend on current master data to reconstruct historical orders.

---

## 39. Carpet Architecture

Carpet-specific information must remain separate from normal OrderItem information.

Conceptually:

    OrderItem
        ↓
    Optional CarpetItemData

Carpet-specific information may include:

    Length
    Width
    Area
    Carpet Size

Non-carpet items should not contain unrelated carpet-specific fields.

This keeps the domain model clean and avoids unnecessary nullable fields.

---

## 40. Storage Architecture

Storage belongs to individual physical OrderItems.

Example:

    Order
    ├── OrderItem 1 → Storage A
    ├── OrderItem 2 → Storage A
    ├── OrderItem 3 → Storage B
    └── OrderItem 4 → Storage C

The system must allow different items from the same Order to exist in different storage locations.

---

## 41. Storage Move Operation

Moving an item must be handled as one application/data operation.

Conceptually:

    Move OrderItem
         ↓
    Deactivate Previous StorageRecord
         ↓
    Create New Active StorageRecord

The system must never leave an OrderItem with two active StorageRecords.

This should be protected through appropriate transaction handling.

---

## 42. Bulk Storage

Bulk storage is a convenience feature.

Example:

    Selected Items:
    5 Shirts
    1 Blanket

    Storage:
    A-03

Each physical OrderItem is stored individually.

The system must not merge multiple OrderItems into one database record simply because they share a storage location.

---

## 43. Order Readiness

Order readiness is derived from storage state.

Conceptually:

    Every OrderItem
        has active StorageRecord
              ↓
           Ready

If at least one OrderItem does not have an active StorageRecord:

    Processing

Readiness must be calculated from actual data.

It must not depend on a UI flag.

---

## 44. Order Completion

Completion is a business operation.

An Order can become Completed only when:

    Order is Ready
    AND
    Remaining Amount = 0
    AND
    Customer Handover is Confirmed

Then:

    Order.status = Completed

and:

    All active StorageRecords become inactive

The UI must not directly change the Order status to Completed without enforcing these rules.

---

## 45. Completion Does Not Mean Handover Automatically

The system must distinguish between being operationally ready and being completed.

Ready means:

    All OrderItems are stored.

Completed means:

    Ready
    +
    Fully Paid
    +
    Customer Handover Confirmed

An Order must never become Completed simply because all items were stored.

---

## 46. Cancellation

Cancellation is a controlled business operation.

Conceptually:

    Cancel Order
        ↓
    Confirm Cancellation
        ↓
    Capture Reason
        ↓
    Set Cancelled
        ↓
    Deactivate Active StorageRecords
        ↓
    Preserve Payment History

Cancellation does not automatically create a refund.

---

## 47. Manual Status Correction

Manual status correction must preserve the real physical storage state.

Example:

    Completed → Processing

must not automatically reactivate StorageRecords.

If the physical items need to return to storage, the user must explicitly perform the storage operation again.

---

## 48. Transactions

Operations that modify multiple related records should be performed atomically whenever supported by the selected local database.

Examples:

    Complete Order
    Cancel Order
    Move Item
    Bulk Store Items

Example:

    Move Item
        ↓
    Deactivate Old StorageRecord
        +
    Create New StorageRecord

Both operations should succeed or fail together.

---

## 49. Error Handling

Errors should be converted into meaningful application-level states.

Conceptually:

    Infrastructure Error
          ↓
    Repository Error
          ↓
    Cubit / Bloc State
          ↓
    Arabic User Message

Examples:

    NetworkError
    DatabaseError
    ValidationError
    NotFoundError
    ConflictError
    BusinessRuleError
    SynchronizationError

The UI should not display raw infrastructure exceptions.

---

## 50. Business Rule Errors

Important business-rule failures should be represented explicitly.

Examples:

    OrderNotReady
    OutstandingPayment
    HandoverNotConfirmed
    InvalidPaymentAmount
    InvalidServiceForItemType
    InvalidStorageLocation
    CannotCancelCompletedOrder

The exact exception/state implementation may vary.

The important requirement is that business failures remain distinguishable from technical failures.

---

## 51. Network Errors

Network failure must not automatically mean that the business operation failed.

Example:

    User Creates Order
        ↓
    Local Save Successful
        ↓
    Internet Unavailable
        ↓
    Mark For Synchronization

The user should be informed appropriately that the operation was saved locally and synchronization will occur later.

---

## 52. Pagination

Large collections must support pagination.

Orders are expected to grow over time, so pagination should be implemented from the beginning.

Preferred flow:

    Initial Query
        ↓
    First Page
        ↓
    Display
        ↓
    Load More
        ↓
    Next Page

Pagination logic belongs in the Repository/Data layer.

The UI should only manage pagination state.

---

## 53. Search

Search should work against local data during normal operation.

Examples:

- Customer name
- Customer phone
- Order number

Preferred flow:

    Search Field
         ↓
    Cubit
         ↓
    Repository
         ↓
    Local Query

The UI must not construct SQL queries.

---

## 54. Filtering

Filters should be represented using simple application-level parameters.

Example:

    OrderFilter
    ├── Status
    ├── Expected Pickup Date
    ├── Payment Status
    └── Delivery Requested

The filter object should remain simple.

Preferred flow:

    UI Filter
        ↓
    Cubit
        ↓
    Repository
        ↓
    Local Database

---

## 55. Settings Access

Presentation should access settings through the appropriate repository.

Avoid direct access from UI to:

    SharedPreferences
    Secure Storage
    Database

Infrastructure details should remain behind the appropriate abstraction.

---

## 56. Dependency Injection

The project should use one centralized Dependency Injection mechanism.

Dependencies may include:

- Database
- Network Client
- Local Data Sources
- Remote Data Sources
- Repository Implementations
- Cubits / Blocs

Dependencies should not be manually instantiated throughout widgets.

Preferred flow:

    DI Container
         ↓
    Repository
         ↓
    Cubit
         ↓
    Screen

The exact DI package is an implementation decision.

---

## 57. Navigation

Navigation should be centralized.

Conceptually:

    App Router
        ├── Dashboard
        ├── Orders
        ├── Customers
        ├── Storage
        ├── Services
        ├── Reports
        └── Settings

Features should not create unrelated navigation systems.

---

## 58. Localization

The application is Arabic-first.

All user-facing strings must be centralized through the localization system.

The architecture must support:

    Arabic
    RTL

The project should remain capable of supporting additional languages later without rewriting feature logic.

---

## 59. Design System

The Design System must have a single source of truth.

The project should use centralized files such as:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

These files should be used to construct the global application theme.

Conceptually:

    App Colors
        +
    App Text Styles
        +
    App Theme
        ↓
    MaterialApp Theme

Feature screens must not define independent global colors or typography systems.

---

## 60. Testing

The architecture should support testing at three main levels.

### Domain

Test:

- Pricing
- Payment calculations
- Status transitions
- Storage rules
- Completion rules
- Cancellation rules

### Data

Test:

- Local persistence
- Queries
- Transactions
- Repository behavior
- Synchronization

### Presentation

Test:

- Cubit/Bloc states
- Form behavior
- Important user interactions
- Loading/error/success states

---

## 61. Important Business Rule Tests

The following scenarios must be testable:

    Order without Customer
    → Rejected

    Order without OrderItems
    → Rejected

    Order with unstored items
    → Processing

    All OrderItems stored
    → Ready

    Ready + Unpaid
    → Cannot Complete

    Ready + Fully Paid + Handover Not Confirmed
    → Cannot Complete

    Ready + Fully Paid + Handover Confirmed
    → Completed

    Completed
    → No Active StorageRecords

    Completed → Processing
    → StorageRecords remain inactive

    Payment > Remaining Amount
    → Rejected

    Move Item A → Storage B
    → Only Storage B is active

---

## 62. AI Coding Tool Rules

AI coding tools are expected to implement the project according to this architecture.

Before creating code, the AI must read:

1. Product documentation
2. Domain documentation
3. Architecture documentation
4. Project Structure documentation

The AI must not infer or invent business behavior when documentation already defines it.

---

## 63. AI Must Not Add Unnecessary Architecture

AI tools must not automatically introduce:

- Use Cases
- Mappers
- Application layers
- Generic repositories
- Generic managers
- Extra service layers
- Duplicate models
- New state-management libraries

unless there is a documented reason and the architecture is intentionally updated.

---

## 64. AI Change Safety

Before changing an existing feature, the AI should determine:

- Which feature is affected
- Which Domain entities are affected
- Which repository is affected
- Which local data is affected
- Which remote data is affected
- Which UI is affected
- Which tests are affected
- Which documentation is affected

Changes should remain as localized as possible.

---

## 65. No Architecture Drift

The following dependencies are prohibited:

    Widget → Database

    Widget → API

    Cubit → SQL

    Cubit → Dio

    Domain → Flutter

    Domain → Database

    Domain → API

    Repository → Widget

The simplified architecture does not mean that layers can be bypassed.

---

## 66. Avoid God Classes

The project should avoid classes such as:

    AppCubit
    AppRepository
    DatabaseHelper
    CommonService
    Utils

when they contain unrelated responsibilities.

Each class should have a clear responsibility.

---

## 67. Avoid Premature Abstraction

Do not create abstractions simply because they are theoretically possible.

Avoid:

- Interface for every class
- Service for every method
- Helper for every small function
- Generic repository for unrelated entities
- Generic CRUD abstraction without a real need

Prefer concrete, understandable code.

Introduce abstraction when there is an actual problem to solve.

---

## 68. Architecture and Project Growth

The architecture may evolve when the product grows.

Possible future additions include:

- Multi-device synchronization
- Advanced conflict handling
- Multi-branch
- Delivery management
- Refunds
- Advanced reporting
- Barcode support

These should be added only when approved as requirements.

Future possibilities should not create unnecessary V1 complexity.

---

## 69. Architecture Stability Rule

If a new requirement requires an architectural change:

1. Identify the affected architecture decision.
2. Update the architecture documentation.
3. Check affected Domain documentation.
4. Check affected Database documentation.
5. Update Project Structure if necessary.
6. Only then implement the code change.

Documentation and code must remain aligned.

---

## 70. Final Architecture

The final V1 architecture is intentionally simple:

    ┌──────────────────────────────────────────┐
    │                Features                  │
    │                                          │
    │ Screens / Widgets / Cubits / Blocs       │
    └────────────────────┬─────────────────────┘
                         ↓
    ┌──────────────────────────────────────────┐
    │                  Domain                  │
    │                                          │
    │ Entities / Enums / Repository Contracts  │
    │ / Business Rules                         │
    └────────────────────┬─────────────────────┘
                         ↓
    ┌──────────────────────────────────────────┐
    │                   Data                   │
    │                                          │
    │ Repositories / Local / Remote / Models   │
    └──────────────┬─────────────────┬─────────┘
                   │                 │
                   ↓                 ↓
          ┌────────────────┐  ┌────────────────┐
          │ Local Database │  │   Remote API   │
          │                │  │                │
          │ Primary for    │  │ Synchronization│
          │ daily operation│  │ & persistence  │
          └────────────────┘  └────────────────┘

The Core layer provides shared infrastructure:

    Core
    ├── Constants
    ├── Errors
    ├── Localization
    ├── Network
    ├── Routing
    ├── Storage
    ├── Theme
    ├── Utils
    └── Shared Widgets

The main architectural principles are:

    Simple
    +
    Offline-first
    +
    Repository-based
    +
    Domain-aware
    +
    Feature-based
    +
    Centralized Design System
    +
    Arabic-first / RTL
    +
    Tablet-first
    +
    Testable
    +
    AI-friendly
    +
    No unnecessary abstraction

This architecture is the approved V1 implementation foundation for the Laundry Management System.