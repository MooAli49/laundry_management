# Laundry Management System — Architecture Guidelines

## 1. Purpose

This document defines the practical architecture guidelines for implementing the Laundry Management System V1.

It translates the approved architectural decisions into implementation rules that developers and AI coding agents must follow.

This document exists to prevent architectural drift during implementation.

It defines:

- Layer responsibilities
- Dependency direction
- Feature boundaries
- Domain boundaries
- Data boundaries
- Core responsibilities
- Dependency injection
- State management
- Navigation
- Local-first behavior
- Networking boundaries
- Testing boundaries
- AI implementation constraints

This document does not redefine:

- Product requirements
- Business rules
- Database schema
- UI/UX specifications
- API contracts

Those remain defined by their respective project documentation.

## 2. Architectural Foundation

The approved V1 architecture is intentionally simple.

The primary structure is:

Features
↓
Domain
↓
Data

With Core providing shared application infrastructure.

The practical application flow is:

User
↓
Screen
↓
Cubit / Bloc
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source
↓
SQLite / Drift

When synchronization is implemented later:

Local Database
↓
Sync Operation
↓
Sync Engine
↓
Remote API

Remote changes follow:

Remote API
↓
Sync Engine
↓
Local Database
↓
Reactive Repository Query
↓
Cubit / Bloc
↓
UI

The local database remains the primary operational data source for V1.

## 3. Architectural Principles

The V1 architecture follows these principles:

1. Simple
2. Offline-first
3. Repository-based
4. Domain-aware
5. Feature-based
6. Testable
7. Arabic-first
8. RTL-aware
9. Tablet-first
10. AI-friendly
11. Centralized design system
12. Minimal abstraction
13. Clear dependency direction
14. Local database as operational source of truth
15. Documentation-driven implementation

Architecture should solve real problems.

Architecture must not be added merely for theoretical purity.

## 4. Approved Layer Structure

The application is organized into:

lib/
├── core/
├── domain/
├── data/
├── features/
└── main.dart

The responsibilities are:

Core
→ Shared infrastructure

Domain
→ Business concepts and contracts

Data
→ Persistence and external data access

Features
→ User-facing application functionality

Main
→ Application bootstrap

## 5. Core Layer

The Core layer contains shared infrastructure that is not specific to one business feature.

The approved Core areas are:

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

Core must not become a dumping ground for feature-specific business logic.

A class belongs in Core only when it is genuinely shared infrastructure.

## 6. Core Constants

The constants directory contains shared technical or application-wide constants.

Examples may include:

- Application configuration constants
- Storage keys
- Network configuration constants
- Shared limits
- Shared formatting constants

Business-specific constants should remain close to their relevant Domain or Feature unless they are genuinely global.

Do not put arbitrary feature constants into Core.

## 7. Core Errors

Core errors contain shared error infrastructure.

Examples include:

- Application exceptions
- Error categories
- Error conversion infrastructure
- Shared error result types

Core errors must not contain feature-specific business decisions.

Feature-specific errors may remain inside the relevant Domain or Feature layer.

## 8. Core Localization

Localization belongs to Core because it is shared across the entire application.

The application is Arabic-first.

All user-facing strings must go through the localization system.

Feature code should not create independent localization systems.

The architecture must remain capable of supporting additional languages later.

## 9. Core Network

The network layer contains shared networking infrastructure.

The approved networking stack is:

Dio
+
Retrofit

Network infrastructure belongs in Core/Data infrastructure.

Feature UI must not directly use Dio.

Feature UI must not directly use Retrofit clients.

Domain must not depend on Dio or Retrofit.

## 10. Core Routing

Routing belongs to Core.

Navigation should be centralized.

The application should have one primary routing mechanism.

The approved high-level routes include:

- Dashboard
- Orders
- Customers
- Storage
- Services
- Reports
- Expenses
- Settings

Features may request navigation.

Features must not create independent application-wide navigation systems.

## 11. Core Storage

Core storage contains shared infrastructure for local persistence access and related technical services.

Database implementation remains part of the Data layer.

Core storage must not expose raw database implementation details to Presentation.

UI code must not directly access:

- SQLite
- Drift database instances
- SharedPreferences
- Secure storage
- Raw storage adapters

when an appropriate abstraction exists.

## 12. Core Theme

The Design System must have one source of truth.

The architecture should centralize:

- Colors
- Typography
- Theme
- Shared visual tokens

Conceptually:

App Colors
+
App Text Styles
+
App Theme
↓
MaterialApp Theme

Feature screens should consume the shared design system.

Feature screens must not define competing global design systems.

## 13. Core Shared Widgets

Shared widgets may live in Core when they are genuinely reusable across multiple features.

Examples:

- Shared buttons
- Shared empty-state components
- Shared loading indicators
- Shared dialogs
- Shared form components

Do not move a widget to Core merely because it exists in one feature.

A widget becomes shared when there is a real reuse requirement.

## 14. Domain Layer

The Domain layer represents the application's business concepts.

The Domain layer contains:

domain/
├── entities/
├── enums/
├── repositories/
└── services/

The Domain layer must remain independent from Flutter infrastructure.

## 15. Domain Entities

Domain entities represent business concepts.

V1 entities include:

Transactional Entities:

- Customer
- Order
- OrderItem
- Payment
- Expense
- StorageRecord

Master Data Entities:

- ItemType
- ItemDefinition
- Service
- ServiceItemType
- CarpetSize
- StorageLocation
- ExpenseCategory

Configuration:

- BusinessSettings

Item-specific:

- CarpetItemData

Domain entities must preserve the approved entity responsibilities.

Do not introduce new entities simply to make implementation easier.

## 16. Domain Enums

Domain enums represent controlled business states and classifications.

Examples include:

- OrderStatus
- PricingType
- ItemType classification
- Expense-related classifications where required

Enums must represent approved business concepts.

Do not add speculative statuses.

## 17. Repository Contracts

Repository interfaces belong to Domain.

They describe business-oriented data operations.

Example conceptual structure:

CustomerRepository
OrderRepository
PaymentRepository
ExpenseRepository
StorageRepository

Repository contracts must not expose infrastructure-specific concepts.

Avoid exposing:

- Drift rows
- Dio responses
- HTTP requests
- SQL queries
- Database connections

through Domain contracts.

## 18. Domain Services

Domain services should be limited.

A Domain service is appropriate only when behavior:

- Is genuinely business logic
- Does not naturally belong to one entity
- Is reused or complex enough to justify extraction

Do not create a service for every method.

Do not create generic business services without a concrete requirement.

## 19. Domain Independence

Domain must not depend on:

- Flutter UI
- BuildContext
- Widgets
- Cubit
- Bloc
- Dio
- Retrofit
- Drift
- SQLite
- Navigator
- GetIt

Domain should remain independently testable.

## 20. Data Layer

The Data layer is responsible for external persistence and data access.

The approved structure is:

data/
├── local/
├── remote/
├── models/
└── repositories/

The Data layer connects infrastructure to Domain contracts.

## 21. Local Data Layer

Local data is the primary operational data source for V1.

The local stack is:

SQLite
+
Drift

Local data includes:

- Database
- Tables
- DAOs
- Queries
- Local data sources
- Local persistence models

Local data must preserve the approved database design.

## 22. Remote Data Layer

Remote data infrastructure exists for the eventual synchronization architecture.

The approved networking technologies are:

Dio
Retrofit

Remote implementation should not become the primary operational dependency of local workflows.

Remote API work is deferred until the synchronization phase.

## 23. Data Models

Data models translate infrastructure representations into application/domain representations.

Examples include:

- Local database models
- Remote API models
- Persistence DTOs

Data models must not be unnecessarily exposed to Presentation.

## 24. Repository Implementations

Repository implementations belong in Data.

They implement Domain repository contracts.

Their responsibilities include coordinating:

- Local data source
- Remote data source when applicable
- Mapping
- Persistence
- Synchronization preparation

They should not contain UI behavior.

## 25. Repository Boundary

The Repository is the main boundary between the application/domain concepts and infrastructure.

Typical flow:

Feature
↓
Repository Contract
↓
Repository Implementation
↓
Data Source

This boundary protects the rest of the application from infrastructure details.

## 26. Feature Layer

Features represent user-facing business functionality.

Approved V1 features include:

features/
├── dashboard/
├── orders/
├── customers/
├── storage/
├── services/
├── reports/
├── expenses/
└── settings/

Each feature should own its presentation logic.

## 27. Feature Responsibility

A feature may contain:

- Screens
- Widgets
- Cubits
- Blocs
- Feature-specific presentation models
- Feature-specific UI helpers

A feature should not directly own:

- Database implementation
- Global routing infrastructure
- Dio clients
- Retrofit clients
- Global theme
- Shared infrastructure

## 28. Feature Independence

Features should remain as independent as practical.

A feature should not reach directly into another feature's internal implementation.

Preferred:

Feature A
↓
Domain Contract
↓
Repository

Avoid:

Feature A
↓
Feature B private Cubit
↓
Feature B database

When features need shared business behavior, use an appropriate Domain or repository boundary.

## 29. Presentation Flow

The standard presentation flow is:

Screen
↓
Cubit / Bloc
↓
Repository
↓
Data

The UI should not bypass the state-management layer for business operations.

## 30. Cubit / Bloc Layer

Cubit or Bloc manages feature presentation state.

It may:

- Load data
- Trigger repository operations
- Emit loading states
- Emit success states
- Emit empty states
- Emit error states
- Coordinate user workflows

It must not:

- Execute SQL
- Access Drift directly
- Call Dio directly
- Call Retrofit directly
- Contain UI rendering logic

## 31. Cubit Dependency Direction

A Cubit should receive its dependencies through constructor injection.

Preferred conceptual flow:

DI Container
↓
Repository
↓
Cubit
↓
Screen

The Cubit should depend on abstractions where appropriate.

## 32. UI Responsibility

Widgets are responsible for:

- Rendering state
- Capturing user input
- Triggering feature actions
- Showing validation feedback
- Showing loading/error/empty states
- Requesting navigation

Widgets are not responsible for:

- Database access
- SQL
- Network requests
- Repository implementation
- Business persistence
- Synchronization

## 33. Build Method Responsibility

The build method should describe UI.

Do not perform:

- Database writes
- Repository calls
- Network requests
- Business transactions
- Navigation side effects

inside build().

Side effects must be triggered through appropriate lifecycle or state-management mechanisms.

## 34. Dependency Injection

The project uses:

get_it

as the centralized Dependency Injection mechanism.

Dependencies should be registered centrally.

The DI container may register:

- Database
- DAOs
- Local data sources
- Remote data sources
- Repository implementations
- Cubits
- Blocs
- Network clients

## 35. Constructor Injection

Constructor injection is preferred.

Example conceptual structure:

OrdersCubit(
  OrderRepository repository,
)

The Cubit receives what it needs.

Avoid retrieving dependencies manually from GetIt inside every method.

## 36. Service Locator Usage

GetIt is an infrastructure mechanism.

Do not use GetIt as a replacement for architecture.

Avoid:

Feature
↓
GetIt
↓
Random Service

when a clean constructor dependency can be provided.

The preferred pattern is:

GetIt
↓
Dependency Construction
↓
Constructor Injection
↓
Business Logic

## 37. Dependency Registration Order

Dependencies should be registered in dependency order.

Typical order:

1. Configuration
2. Database
3. DAOs
4. Local Data Sources
5. Remote Data Sources
6. Repositories
7. Cubits / Blocs

Dependencies must be fully initialized before they are used.

## 38. Dependency Direction

The allowed dependency direction is:

Presentation
↓
Domain
↓
Data

Core provides shared infrastructure.

Data may depend on Domain contracts.

Domain must not depend on Data.

Presentation must not depend directly on Data infrastructure.

## 39. Prohibited Dependencies

The following dependencies are prohibited:

Widget → Database

Widget → API

Cubit → SQL

Cubit → Dio

Cubit → Retrofit

Domain → Flutter

Domain → Database

Domain → API

Repository → Widget

Repository → BuildContext

These dependencies create architecture drift.

## 40. Local-First Architecture

V1 is offline-first.

The normal operational path is:

User
↓
Screen
↓
Cubit
↓
Repository
↓
Local Data Source
↓
SQLite
↓
Immediate UI Update

Network availability must not be required for normal local operations.

## 41. Local Database as Operational Source

SQLite is the primary operational database.

Daily workflows should operate against local data.

Examples:

- Create Order
- Open Order
- Search Customer
- Search Order
- Record Payment
- Add Expense
- Store Item
- Move Item
- View Dashboard
- View Reports

These workflows should not depend on a live server.

## 42. Remote Synchronization Boundary

Remote synchronization is a separate concern.

The eventual flow is:

Local Business Change
↓
Sync Operation
↓
Sync Engine
↓
Remote API

Remote synchronization must not be mixed into presentation code.

## 43. Synchronization Deferral

Synchronization execution is deferred until the synchronization phase.

Do not implement advanced synchronization behavior during the initial local Flutter implementation.

Do not add speculative:

- Background sync
- Conflict resolution
- Real-time synchronization
- Distributed locking
- CRDTs
- Advanced retry orchestration

without an approved implementation phase.

## 44. Sync-Ready Architecture

Although synchronization execution is deferred, local architecture should remain compatible with it.

Where required:

Business Data
+
Sync Operation

should be treated as one logical transaction.

The exact synchronization behavior is defined by the synchronization documentation.

## 45. Transaction Boundary

When a local business operation requires synchronization metadata, the preferred transaction is:

Begin Transaction
↓
Modify Business Data
↓
Create Sync Operation
↓
Commit

This prevents:

Business Data Saved
+
No Sync Operation

The same principle applies to operations such as:

- Order Creation
- Payment Creation
- Expense Creation
- Expense Category Changes
- Storage Changes

when synchronization is enabled.

## 46. Networking Boundary

Networking must remain behind Data/Infrastructure boundaries.

The approved stack is:

Dio
+
Retrofit

Remote API clients should not be used directly by:

- Widgets
- Cubits
- Domain entities
- Domain services

## 47. Remote Models

Remote API representations should remain separate from Domain entities when the API contract requires different shapes.

Do not leak API response objects into Presentation.

Translate remote representations at the appropriate boundary.

## 48. Error Boundary

Errors should cross architectural boundaries in a controlled way.

Typical flow:

Infrastructure Error
↓
Data Error
↓
Repository/Application Error
↓
Cubit State
↓
UI Message

Raw infrastructure exceptions should not normally be shown directly to users.

## 49. Business Validation Boundary

Validation belongs in the appropriate layer.

Presentation validation:

- Improves user experience
- Detects obvious input problems

Business/domain validation:

- Protects correctness
- Enforces business rules
- Must not depend solely on UI validation

Example:

The UI may prevent an invalid payment amount.

The business layer must still reject:

Payment > Remaining Amount

## 50. Business Rule Ownership

Business rules should be enforced close to the business/domain boundary.

Examples:

- Order completion requirements
- Payment limits
- Storage compatibility
- Storage activation
- Expense rules
- Pricing calculations
- Status transitions

Do not duplicate important business rules independently across multiple widgets.

## 51. Historical Data Protection

Architecture must preserve historical business meaning.

Changes to configuration must not silently rewrite historical transactions.

Examples include:

- Service price changes
- Service name changes
- Item definition changes
- Expense category changes
- Storage location changes
- Carpet size changes

Historical snapshots and transaction values remain authoritative for past transactions.

## 52. Money Architecture

Money is represented using integer minor units.

Currency:

EGP

Example:

100.50 EGP
→
10050 piastres

The authoritative financial value must not use floating-point persistence.

Financial calculations must remain exact.

## 53. Identifier Architecture

Business entities use stable UUID identifiers.

Database representation:

TEXT

Business identifiers such as Order Number are separate from internal entity IDs.

Do not use auto-increment integers as business entity IDs.

## 54. Order Number Architecture

The approved Order Number format is:

YY-XXX

This must remain separate from the internal UUID.

Do not introduce a different Order Number format without an approved documentation change.

## 55. Order Status Architecture

The approved Order status model must remain centralized and consistent.

UI terminology includes:

- قيد التجهيز
- جاهز
- مكتمل
- ملغي

Status transitions are business rules.

They must not be freely controlled by Presentation code.

## 56. Storage Architecture

Storage operates at OrderItem level.

Conceptually:

Order
↓
OrderItems
↓
StorageRecord
↓
StorageLocation

Do not treat the entire Order as one physical storage unit when the business rule requires individual OrderItem tracking.

## 57. Storage Location Boundary

StorageLocation is master data.

StorageRecord represents the current physical storage assignment.

The architecture must preserve this separation.

Do not merge StorageLocation and StorageRecord into a generic storage entity.

## 58. Expense Architecture

Expense is a separate financial transaction.

Expense must not be modeled as Payment.

The conceptual flow is:

Expenses Screen
↓
ExpensesCubit
↓
ExpenseRepository
↓
ExpenseRepositoryImpl
↓
Local Expense Data Source

ExpenseCategory is master data and should remain separate.

## 59. Financial Reporting Architecture

Reports are derived from transactional data.

The financial report reads from:

Orders
+
Payments
+
Expenses

and produces a derived financial summary.

Do not create a separate persisted financial-summary entity for V1.

## 60. Dashboard Architecture

The Dashboard is an operational overview.

It should consume repository/query results.

The Dashboard must not become a second database access layer.

Do not place raw SQL or direct Drift queries inside Dashboard widgets.

## 61. Master Data Architecture

Master data includes concepts such as:

- ItemType
- ItemDefinition
- Service
- ServiceItemType
- CarpetSize
- StorageLocation
- ExpenseCategory

Master data should be managed through appropriate repositories and feature workflows.

Do not duplicate master-data storage inside individual features.

## 62. Configuration Architecture

BusinessSettings contains only approved V1 business configuration.

Configuration fields must remain aligned with the current Domain documentation.

Do not reintroduce removed configuration properties simply because they appear useful.

Do not add new configuration without an approved requirement.

## 63. Navigation Architecture

Navigation is centralized.

Conceptually:

App Router
├── Dashboard
├── Orders
├── Customers
├── Storage
├── Services
├── Reports
├── Expenses
└── Settings

Features should not create competing routing systems.

Business/domain code must not depend on navigation.

## 64. Navigation and State

Navigation decisions based on feature state may be coordinated by the Presentation layer.

For example:

Cubit State
↓
UI Listener
↓
Navigation

Avoid:

Cubit
↓
Navigator
↓
BuildContext

The Cubit should remain independent from Flutter navigation infrastructure.

## 65. Arabic-First Architecture

Arabic is the primary application language.

All user-facing terminology must remain consistent with approved product and UI documentation.

Localization should be centralized.

Feature logic must not hardcode language-specific business behavior.

## 66. RTL Architecture

The application must support RTL correctly.

Prefer directional Flutter APIs:

EdgeInsetsDirectional
AlignmentDirectional
BorderRadiusDirectional

Avoid implementing RTL by manually reversing arbitrary left/right values.

The architecture should allow localization and RTL behavior to be handled globally.

## 67. Tablet-First Architecture

The application is tablet-first.

Feature layouts should be designed to work well on tablet-sized screens.

Architecture should not assume a mobile-only layout.

Reusable widgets should avoid hardcoding narrow screen assumptions.

## 68. Responsive Boundaries

Responsive layout decisions belong to Presentation.

Do not put screen-size logic inside:

- Domain
- Repository
- Data source
- Database

Business logic must remain independent from device dimensions.

## 69. Design System Boundary

The Design System is centralized.

Features consume:

- Theme
- Colors
- Typography
- Spacing
- Shared components

Features should not create competing application-wide styling systems.

## 70. Shared Code Boundary

Shared code should be introduced only when there is real reuse.

Prefer:

Feature-specific code

over:

Generic abstraction

until reuse is demonstrated.

Avoid creating:

- Generic managers
- Generic helpers
- Generic repositories
- Generic CRUD systems
- Generic service layers

without a concrete need.

## 71. Avoid God Classes

Avoid classes such as:

AppCubit
AppRepository
DatabaseHelper
CommonService
Utils

when they contain unrelated responsibilities.

Each class should have one clear responsibility.

## 72. Avoid Premature Abstraction

Do not create:

- Interface for every class
- Service for every function
- Mapper for every object
- Use Case for every operation
- Generic repository for every entity
- Application layer without a concrete requirement

The approved architecture intentionally avoids unnecessary abstraction.

## 73. Use Cases

Use Cases are not a mandatory architectural layer in V1.

Do not introduce a Use Case layer automatically.

A Use Case may be considered later only when a concrete business complexity justifies it and the architecture is intentionally updated.

## 74. Mappers

Mappers should not be introduced automatically for every model.

Mapping is appropriate when there is a meaningful boundary between representations.

Examples:

- Database model → Domain entity
- API model → Domain entity

Do not create redundant mapper classes when direct conversion is clearer and safe.

## 75. Application Layer

There is no mandatory separate Application layer in V1.

Do not create:

application/
services/
use_cases/

merely because they are common in other architectures.

If future complexity requires such a layer, update the architecture documentation first.

## 76. Testing Architecture

The architecture must support testing at three major levels:

Domain
Data
Presentation

Tests should be designed around behavior and boundaries.

## 77. Domain Testing

Domain tests should cover important business behavior.

Examples:

- Pricing
- Payment calculations
- Status transitions
- Storage rules
- Completion rules
- Cancellation rules
- Validation rules

Domain tests must not require Flutter widgets.

## 78. Data Testing

Data tests should cover:

- Local persistence
- Queries
- Transactions
- Repository behavior
- Database constraints
- Mapping
- Synchronization-related behavior when implemented

Data tests should use controlled local test environments.

## 79. Presentation Testing

Presentation tests should cover:

- Cubit/Bloc states
- Forms
- Validation
- Loading states
- Error states
- Empty states
- Important user interactions

Do not require a real backend for normal presentation tests.

## 80. Integration Testing

Important end-to-end workflows should be testable.

Examples:

Customer
↓
Order
↓
OrderItem
↓
Payment
↓
Storage
↓
Completion

And:

Expense
↓
Financial Report
↓
Net Profit

## 81. Testable Dependency Boundaries

Dependencies should be injectable.

Repositories should be replaceable in tests.

Data sources should be replaceable or testable independently.

Cubit dependencies should be constructor-injected.

This is one reason constructor injection is preferred.

## 82. Architecture and Database

Database architecture must follow the approved database documentation.

The implementation must preserve:

- Tables
- Relationships
- Constraints
- Indexes
- UUID strategy
- Money representation
- Historical data behavior

Do not alter database design merely to simplify Flutter code.

## 83. Architecture and Documentation

The documentation set is the architectural source of truth.

Relevant implementation documents include:

Product Documentation
↓
Domain Documentation
↓
Architecture Documentation
↓
Database Documentation
↓
Implementation Documentation
↓
Code

If a conflict appears:

Stop.

Identify the conflict.

Review the relevant documentation.

Do not silently choose an implementation.

## 84. Architecture Change Rule

If a new requirement requires an architectural change:

1. Identify the affected architecture decision.
2. Update the architecture documentation.
3. Check affected Domain documentation.
4. Check affected Database documentation.
5. Check Project Structure documentation.
6. Update implementation documentation.
7. Only then implement the code change.

Code must not become the first place where a new architectural decision appears.

## 85. AI Implementation Rule

AI coding agents must read the relevant documentation before implementing code.

At minimum, the agent should consult:

- Product documentation
- Domain documentation
- Architecture documentation
- Project Structure
- Relevant database documentation
- Relevant implementation documentation

The agent must implement the approved architecture rather than inventing an alternative.

## 86. AI Architecture Restrictions

AI coding agents must not automatically introduce:

- Use Cases
- Application layers
- Generic repositories
- Generic managers
- Extra service layers
- Duplicate models
- New state-management libraries
- New routing frameworks
- New database technologies
- New networking libraries

unless explicitly approved.

## 87. AI Change Safety

Before changing an existing feature, determine:

- Which feature is affected
- Which Domain entities are affected
- Which repository is affected
- Which local data is affected
- Which remote data is affected
- Which UI is affected
- Which tests are affected
- Which documentation is affected

Keep changes as localized as possible.

## 88. Architecture Drift Prevention

The following are considered architecture drift:

- Direct UI database access
- Direct UI network access
- SQL inside Cubits
- Dio inside Cubits
- Flutter dependencies inside Domain
- Business logic inside DAOs
- Navigation inside Domain
- Repository dependencies on Widgets
- Feature-specific infrastructure duplicated across features
- Unapproved architectural layers
- Unapproved packages replacing approved technologies

Architecture drift must be corrected rather than normalized.

## 89. Feature Implementation Boundary

A feature implementation should follow:

Feature UI
↓
Cubit / Bloc
↓
Repository Contract
↓
Repository Implementation
↓
Local Data Source
↓
Database

Remote infrastructure is added only where the current implementation phase requires it.

## 90. Feature-to-Feature Communication

Features should communicate through approved application boundaries.

Do not directly manipulate another feature's internal state.

If shared business behavior is required:

Feature A
↓
Repository / Domain Contract
↓
Shared Business Concept

rather than:

Feature A
↓
Feature B Cubit
↓
Feature B internal implementation

## 91. Lifecycle Ownership

Each object should have a clear owner.

Examples:

- Database → Application infrastructure
- Repository → Dependency Injection container
- Cubit → Feature/UI lifecycle
- Widget → Flutter widget tree
- DAO → Data layer
- Data source → Data layer

Avoid unclear ownership that causes leaks or duplicate instances.

## 92. Resource Disposal

Resources with explicit lifecycles must be disposed appropriately.

Examples include:

- TextEditingController
- FocusNode
- StreamSubscription
- Database resources
- Dio resources where applicable

Dependency injection must respect lifecycle requirements.

## 93. Initialization

Application initialization should be explicit.

Typical startup flow:

main()
↓
Flutter Initialization
↓
Configuration
↓
Dependency Injection
↓
Database Initialization
↓
Application
↓
Router
↓
Initial Screen

Do not hide important application initialization inside arbitrary widgets.

## 94. Database Initialization

The database must be initialized before repositories that depend on it.

Conceptual order:

Database
↓
DAOs
↓
Local Data Sources
↓
Repositories
↓
Cubits

Do not allow widgets to initialize the database themselves.

## 95. Network Initialization

Network clients should be configured centrally.

Dio configuration should remain centralized.

Retrofit clients should be constructed through the approved dependency system.

Feature code should receive repositories rather than network clients.

## 96. Configuration Initialization

Application configuration should be loaded before dependent services are created.

Do not scatter configuration loading throughout features.

Environment-specific configuration should remain centralized.

Secrets must never be hardcoded.

## 97. Performance Architecture

Performance optimization should focus on real bottlenecks.

Important areas include:

- Database queries
- Customer search
- Order lists
- Storage lists
- Reports
- Dashboard queries

Use:

- Appropriate indexes
- Efficient queries
- Pagination where required
- Reactive queries where useful

Do not introduce caching or complex optimization without a demonstrated need.

## 98. Reactive Data

Reactive database queries may be used where UI needs to remain synchronized with local changes.

Conceptual flow:

Database Change
↓
Repository Stream
↓
Cubit / Bloc
↓
UI

Do not convert every repository method into a stream without a real requirement.

Use Futures for one-time operations.

## 99. Offline Error Handling

A local operation should not fail merely because the network is unavailable.

If a workflow is local-first:

Network unavailable
↓
Local operation continues

Synchronization may occur later according to the synchronization strategy.

## 100. Network Failure Isolation

Network failures should not corrupt local business state.

The local transaction should remain authoritative for local-first operations.

Synchronization failures should be represented by synchronization state rather than by pretending that the local business operation failed.

The exact synchronization behavior belongs to the synchronization implementation phase.

## 101. Database Failure Isolation

Database errors must be handled at the Data/Repository boundary.

Do not allow raw database exceptions to leak into widgets.

Translate them into application-level errors where appropriate.

## 102. Business Transaction Atomicity

When a business operation consists of multiple writes, the operation should be atomic when required.

Example:

Create Order
↓
Create OrderItems
↓
Create required related records
↓
Commit

Do not leave partially created business transactions.

## 103. Historical Transaction Integrity

Completed or historical transactions must remain understandable.

Do not allow current configuration changes to silently modify historical meaning.

Historical values must remain stable according to the approved Domain and Database rules.

## 104. Out-of-Scope Architecture

The V1 architecture must not be expanded for features that are explicitly outside V1.

Do not create architecture for:

- Drivers
- Vehicles
- Delivery Routes
- Refunds
- Loyalty
- Storage Capacity
- Storage Movement History
- Laundry Processing Stages
- AI Assistant
- Barcode Workflow
- Advanced Analytics
- Predictive Analytics
- Multi-branch
- Employee management
- Roles and permissions

unless those features become approved requirements.

## 105. Future Architecture

The architecture may evolve later.

Possible future additions include:

- Multi-device synchronization
- Advanced conflict resolution
- Multi-branch support
- Delivery management
- Refund workflows
- Barcode support
- Advanced reporting
- AI capabilities

Future possibilities must not create unnecessary V1 complexity.

## 106. Architecture Review Checklist

Before adding a new architectural component, verify:

- Is there a concrete requirement?
- Does an existing layer already own this responsibility?
- Is the dependency direction preserved?
- Does this introduce a new package?
- Does this introduce a new abstraction?
- Does this change the Domain model?
- Does this change the database?
- Does this change navigation?
- Does this change synchronization?
- Does documentation need updating?

If any answer indicates a significant architectural change, stop and review before implementation.

## 107. New Layer Checklist

Before creating a new layer, confirm:

1. Existing layers cannot reasonably own the responsibility.
2. The new layer solves a concrete problem.
3. The dependency direction remains clear.
4. The architecture documentation is updated.
5. The project structure is updated.
6. The implementation plan explicitly allows it.

Otherwise, do not create the layer.

## 108. New Service Checklist

Before creating a service:

1. Confirm the responsibility is business-related.
2. Confirm it cannot naturally belong to an entity.
3. Confirm it is not merely a wrapper around one method.
4. Confirm reuse or complexity justifies the service.
5. Confirm it does not duplicate repository responsibilities.

Do not create services automatically.

## 109. New Repository Checklist

Before creating a repository:

1. Identify the business concept it represents.
2. Confirm the concept exists in the approved Domain model.
3. Define the Domain contract first.
4. Implement the Data repository afterward.
5. Keep infrastructure details out of the contract.

Do not create generic repositories for unrelated entities.

## 110. New Data Source Checklist

Before creating a data source:

1. Identify whether it is Local or Remote.
2. Identify its owning feature/domain concept.
3. Confirm the underlying storage/API requirement.
4. Keep the data source focused.
5. Keep business rules outside the data source.

## 111. New Core Component Checklist

Before adding something to Core:

1. Is it shared by multiple features?
2. Is it infrastructure rather than business logic?
3. Does it have a clear responsibility?
4. Would keeping it feature-local be better?
5. Does placing it in Core create unwanted coupling?

If it is feature-specific, keep it in the feature.

## 112. Architecture Completion Criteria

The architecture implementation is considered aligned when:

- Dependency direction is preserved.
- Domain remains infrastructure-independent.
- UI does not access the database directly.
- Cubits do not access SQL directly.
- Networking remains behind Data boundaries.
- Repository contracts remain in Domain.
- Repository implementations remain in Data.
- DI is centralized through get_it.
- Local-first behavior is preserved.
- Synchronization remains separated.
- Navigation is centralized.
- Localization is centralized.
- Design System remains centralized.
- Tests can isolate each major layer.

## 113. Final Architecture

The final V1 architecture is:

Features
├── Screens
├── Widgets
└── Cubits / Blocs
        ↓
Domain
├── Entities
├── Enums
├── Repository Contracts
└── Limited Domain Services
        ↓
Data
├── Local
├── Remote
├── Models
└── Repository Implementations
        ↓
Infrastructure
├── SQLite / Drift
└── Dio / Retrofit

With Core providing:

- Constants
- Errors
- Localization
- Network Infrastructure
- Routing
- Storage Infrastructure
- Theme
- Utilities
- Shared Widgets

## 114. Final Dependency Rule

The most important implementation rule is:

UI must not know how data is stored.

Domain must not know how data is transported.

Data must implement the approved Domain contracts.

Core must provide shared infrastructure without owning feature business logic.

Features must coordinate user-facing behavior without bypassing architectural boundaries.

## 115. Final Rule

When implementing the Laundry Management System:

Follow the simplest architecture that satisfies the approved requirements.

Do not add layers because they are common in other projects.

Do not add packages because they are popular.

Do not bypass repositories because direct database access is faster to write.

Do not put business rules in widgets because the UI already has the data.

Do not introduce networking into local workflows because a backend will exist later.

Do not implement synchronization before its approved phase.

Do not let code silently become the source of truth for new architectural decisions.

When requirements change, update the documentation first.

When architecture changes, update the architecture documentation first.

When in doubt, prefer the existing approved architecture over a new abstraction.

The goal is a system that is:

Simple
+
Predictable
+
Offline-first
+
Testable
+
Maintainable
+
AI-friendly
+
Aligned with the approved project documentation.