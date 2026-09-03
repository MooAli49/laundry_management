# Laundry Management System — Implementation Overview

## 1. Document Purpose

This document defines the implementation-level direction for the Laundry Management System V1.

It is the primary entry point for implementation work.

Its purpose is to translate the already-approved:

- Product Requirements
- Domain Model
- Business Rules
- Architecture
- Database Design
- Data Layer Decisions
- UI/UX Decisions
- Technical Decisions

into a clear implementation direction for the Flutter application.

This document does NOT redefine product requirements.

It does NOT introduce new business behavior.

It does NOT replace the Product, Domain, Architecture, Database, or Technical Decisions documentation.

Instead, it explains how the approved system should be implemented.

---

## 2. Implementation Source of Truth

Implementation must follow the existing documentation hierarchy.

The implementation agent must treat the following as authoritative:

1. Product documentation
2. Requirements documentation
3. Scope documentation
4. Domain documentation
5. Business Rules
6. Architecture documentation
7. Data Layer documentation
8. Database documentation
9. Technical Decisions
10. UI/UX and feature documentation
11. This Implementation documentation

When two documents conflict, implementation must stop.

The conflict must be identified and resolved in the appropriate higher-level documentation before code is changed.

Implementation convenience must never override an approved business rule.

---

## 3. V1 Implementation Goal

The primary V1 implementation goal is:

Build a production-oriented Flutter application that provides the approved Laundry Management System workflows with:

- Offline-first operation
- Local SQLite persistence
- Drift database access
- Arabic-first UI
- RTL layout
- Tablet-first design
- Feature-based architecture
- Bloc/Cubit state management
- Repository-based data access
- Centralized dependency injection
- Centralized theme
- Centralized localization
- Stable entity identifiers
- Transaction-safe data operations
- Testable business behavior
- Synchronization readiness

The first implementation phase is local-first.

The application must be useful without requiring a backend connection for normal V1 local operations.

---

## 4. Implementation Scope

The implementation is divided into two major areas.

### 4.1 Current Implementation Scope

The current implementation phase includes:

- Flutter application foundation
- Project structure
- Core configuration
- Theme
- Arabic localization
- RTL support
- Dependency injection
- Routing foundation
- Domain entities
- Domain enums
- Repository contracts
- SQLite database
- Drift database layer
- Local repositories
- Local queries
- Transactions
- Bloc/Cubit state management
- Validation
- Error handling
- Approved V1 features
- Testing
- Seed data
- Offline-first local operation

### 4.2 Deferred Implementation Scope

The following are intentionally deferred until the local Flutter implementation is complete and the corresponding requirements are approved:

- Backend implementation
- Production remote API integration
- Production synchronization execution
- Advanced multi-device conflict resolution
- Real-time synchronization
- Complex background synchronization
- Distributed locking
- CRDTs
- Event sourcing
- Advanced caching architecture
- Authentication implementation unless explicitly required
- Advanced delivery management
- Advanced analytics
- AI assistant
- Barcode workflows
- Other future features not approved for V1

The implementation agent must not begin deferred functionality simply because the architecture is synchronization-ready or because corresponding folders exist.

---

## 5. Approved Technology Stack

The V1 application uses:

### Application

- Flutter
- Dart

### State Management

- Bloc / Cubit

Only one state-management solution is allowed.

Do not introduce another state-management library.

### Local Database

- SQLite
- Drift

SQLite is the operational local database.

Drift is the approved database access layer.

### Dependency Injection

- get_it

Dependency injection must be centralized.

The application must use a single dependency injection mechanism.

Do not introduce another dependency injection framework.

### Networking

- Dio
- Retrofit

Dio is the HTTP client.

Retrofit provides the typed API client abstraction/code generation layer where remote API implementation is required.

Networking is part of the synchronization-ready architecture but does not mean that backend integration should be implemented during the initial local-first phase.

### UI

- Flutter Material-based UI
- Centralized Theme
- Arabic-first
- RTL
- IBM Plex Sans Arabic
- Tablet-first layout

---

## 6. Dependency Injection Decision

The project uses:

get_it

for centralized dependency injection.

The dependency injection container is responsible for wiring application dependencies.

Typical registrations include:

- Database
- DAOs where applicable
- Local data sources
- Remote data sources when implemented
- Repository implementations
- Domain services where required
- Cubits / Blocs
- API clients when remote integration is implemented

The exact registration structure should follow feature and layer ownership.

Do not create a global service locator usage pattern throughout arbitrary classes.

Dependencies should be resolved at composition boundaries where practical.

The implementation should prefer constructor injection for classes that receive dependencies.

Do not introduce another DI framework.

Do not add injectable or another code-generation DI layer unless a future architectural decision explicitly approves it.

---

## 7. Networking Decision

The approved networking stack is:

Dio
+
Retrofit

Networking must remain isolated from the rest of the architecture.

The following dependency direction is prohibited:

Widget → Dio

Cubit → Dio

Domain → Dio

Repository UI coupling

Remote API details must not leak into the Domain layer.

When remote functionality is eventually implemented:

Presentation
↓
Repository
↓
Remote Data Source / API Client
↓
Dio / Retrofit

The current local-first implementation must not require a working backend.

Do not implement remote API endpoints that are not defined by approved requirements.

Do not invent API contracts.

Do not create fake backend workflows merely to demonstrate synchronization.

---

## 8. Approved Architecture

The application follows a feature-based architecture combined with clear responsibility boundaries.

The high-level structure is:

lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── localization/
│   ├── network/
│   ├── routing/
│   ├── storage/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── domain/
│   ├── entities/
│   ├── enums/
│   ├── repositories/
│   └── services/
│
├── data/
│   ├── local/
│   ├── remote/
│   ├── models/
│   └── repositories/
│
├── features/
│   ├── dashboard/
│   ├── orders/
│   ├── customers/
│   ├── storage/
│   ├── services/
│   ├── reports/
│   ├── expenses/
│   └── settings/
│
└── main.dart

Only introduce additional directories when a concrete implementation requirement justifies them.

---

## 9. Architecture Dependency Direction

The allowed high-level dependency direction is:

Presentation
↓
Domain
↓
Data
↓
Infrastructure

More specifically:

Widget
↓
Cubit / Bloc
↓
Repository Contract
↓
Repository Implementation
↓
Local / Remote Data Source
↓
Database / API

The Domain layer must remain independent from:

- Flutter UI
- SQLite
- Drift
- Dio
- Retrofit
- Database implementation details
- Remote API implementation details

The following dependencies are prohibited:

Widget → Database

Widget → API

Cubit → SQL

Cubit → Drift

Cubit → Dio

Domain → Flutter

Domain → Database

Domain → API

Repository → Widget

---

## 10. No Unnecessary Architectural Layers

The project intentionally uses a simplified architecture.

Do not automatically introduce:

- usecases/
- application/
- mappers/
- generic repository frameworks
- generic CRUD frameworks
- generic managers
- unnecessary service layers
- duplicate models
- duplicate repositories
- duplicate state-management solutions
- unnecessary abstraction interfaces

A new abstraction must solve a concrete problem.

The project prefers:

- Fewer files
- Clear responsibilities
- Reusable code
- Simple dependencies
- Easy maintenance
- Testability

over unnecessary architectural complexity.

---

## 11. Domain Implementation

The Domain layer represents approved business concepts.

Domain entities must correspond to documented business entities.

Do not create entities simply because a UI component exists.

Do not create entities for temporary UI state unless that concept genuinely belongs to the Domain.

The Domain layer includes:

- Entities
- Enums
- Repository contracts
- Required domain services

Business rules that affect correctness should remain explicit and testable.

The Domain must not know whether data is stored in:

- SQLite
- Drift
- Memory
- Remote API

---

## 12. Data Layer Implementation

The Data layer is responsible for persistence and external data access.

It includes:

- Drift database
- Tables
- DAOs
- Local data sources
- Remote data sources
- Data models where required
- Repository implementations

The Data layer must implement the repository contracts defined by the Domain.

Local persistence is the primary operational source of truth.

The application must not depend on the remote API for normal local V1 operations.

---

## 13. Database Implementation

The database implementation must use:

SQLite
+
Drift

The approved logical schema must be implemented exactly as documented.

Do not invent additional business tables.

The current approved V1 database includes:

- customers
- orders
- order_items
- payments
- storage_locations
- storage_records
- item_types
- item_definitions
- services
- service_item_types
- storage_location_item_types
- carpet_sizes
- order_item_carpets
- expense_categories
- expenses
- business_settings
- sync_operations

Every table must have a documented purpose.

Do not create tables for excluded or speculative features.

---

## 14. Identifier Implementation

Business and infrastructure identifiers use UUIDs.

The SQLite/Drift representation is:

TEXT

Identifiers must remain stable for the entire entity lifecycle.

Do not use auto-increment integer IDs for business entities.

Do not regenerate an entity ID during updates.

Stable identifiers are required for:

- Offline-first operation
- Synchronization readiness
- Historical references
- Relational integrity

---

## 15. Money Implementation

All persisted monetary values use integer minor units.

The application currency is:

EGP

Example:

100.50 EGP

is stored as:

10050

Do not persist money using floating-point database values.

Do not use floating-point arithmetic as the authoritative representation of financial values.

Financial calculations must preserve exact monetary values.

---

## 16. Transaction Requirements

Multi-record business operations must use database transactions where required.

Examples include:

- Order creation
- Payment creation
- Expense creation
- Expense category changes
- Storage changes
- Seed initialization
- Other operations that modify multiple related records

The preferred synchronization-aware structure is:

Begin Transaction
↓
Modify Business Data
↓
Create Sync Operation when required
↓
Commit

If the transaction fails:

Rollback

Business data must not be committed while its required related synchronization operation is missing.

The exact synchronization behavior is defined by sync-strategy.md.

---

## 17. Offline-First Implementation

Offline-first is a core V1 requirement.

The application must:

- Open and operate from the local database
- Support normal local workflows without internet
- Read operational data from SQLite
- Write operational changes to SQLite
- Avoid making network availability a prerequisite for normal local operations

The local database is the operational source of truth.

Network synchronization is an additional mechanism and must not replace local persistence.

First launch must not require internet access simply to initialize the local application database.

---

## 18. Synchronization Readiness

The application is synchronization-ready but synchronization execution is deferred.

The database includes the approved synchronization infrastructure.

When local business data requires synchronization, the architecture must support:

Business Transaction
↓
Local Business Change
↓
Sync Operation Creation
↓
Commit

The implementation must preserve this future capability without implementing advanced synchronization prematurely.

Do not implement:

- Real-time synchronization
- Complex background synchronization
- Advanced conflict resolution
- CRDTs
- Distributed locking

unless explicitly approved later.

---

## 19. Seed Data

Seed data is initialized locally.

Required default master data must be available without internet access.

Seed initialization must be:

- Idempotent
- Transaction-safe where multiple related records are created
- Safe to run during application initialization

The conceptual startup flow is:

Application Startup
↓
Open Database
↓
Run Required Migrations
↓
Run Idempotent Seed Initialization
↓
Application Ready

Seed data must not create fabricated financial transactions.

Seeded Expense Categories do not create Expenses.

The seeded Expense Category "أخرى" must remain available according to the approved Expense rules.

---

## 20. State Management

The application uses:

Bloc / Cubit

Only one state-management solution is allowed.

State management must remain feature-oriented.

Avoid creating a single global application Cubit that owns unrelated business features.

For example:

Expenses must not be placed inside a global AppCubit merely because Dashboard displays expense-related information.

Each feature should own its relevant state.

State should represent:

- Loading
- Loaded / Ready
- Empty where applicable
- Error
- Relevant user interaction states

Do not duplicate business logic inside widgets.

---

## 21. Feature Implementation

Approved V1 features are:

### Dashboard

Operational overview and quick actions.

Quick Actions:

- إضافة طلب
- إضافة عميل
- تسجيل دفعة
- إضافة مصروف

Storage is not a Dashboard Quick Action.

The Welcome section is not required.

### Orders

Includes:

- Customer orders
- Order items
- Item information
- Services
- Pricing
- Delivery
- Payments
- Order status
- Order details
- Invoice / receipt

Order Number format:

YY-XXX

### Customers

Customer management.

### Storage

Physical OrderItem storage.

Storage must operate on OrderItems rather than Orders only.

Storage locations must be filtered according to:

- Active status
- Item Type compatibility

An inactive current location may remain visible for existing historical/operational context but must not be offered as a new destination.

### Services

Services and related master data include:

- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Service / Item Type relationships

Services and Pricing remain inside Settings.

### Reports

Includes financial reporting and approved report information.

Financial reporting includes:

- Sales
- Payments
- Expenses
- Remaining Amount
- Discounts
- Payment Methods
- Net Profit

Net Profit is:

Sales - Operating Expenses

Net Profit must not be stored as an independent transaction or entity.

### Expenses

Expenses are first-class independent financial transactions.

Expenses are independent from Orders and Payments.

Expense Categories are managed through Settings.

Expense Category behavior includes:

- Add
- Edit
- Activate
- Deactivate

Hard delete must not be used when historical references exist.

When the category is:

أخرى

the Expense Name is required.

### Settings

Includes approved configuration and master data management.

Services & Pricing remains inside Settings.

Expense Category management remains inside Settings.

Business Information is the single source for business identity information used by the invoice.

---

## 22. Order Implementation Rules

Order creation must enforce the approved Domain and Business Rules.

At minimum:

- Customer is required
- At least one OrderItem is required
- Item Type is required
- Service is required where applicable
- Item Definition appears only when applicable
- Pricing follows the approved pricing behavior
- Price may be adjusted before saving where approved
- Delivery to Laundry is independent
- Delivery to Customer is independent
- Both delivery types may be selected together
- Each delivery direction has its own fee
- Delivery fees are part of the Order financial calculation

Delivery V1 is not a delivery-management system.

Do not introduce:

- Driver
- Vehicle
- Route
- Tracking
- Assignment
- Delivery status

---

## 23. Order Status Implementation

Order status must follow the approved lifecycle and business rules.

The implementation must not invent new statuses.

Approved UI terminology includes:

- قيد التجهيز
- جاهز
- مكتمل
- ملغي

Status transitions must follow the documented business rules.

Important scenarios must remain enforced:

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

Manual status editing must remain available where the approved workflow allows it.

---

## 24. Item Information Implementation

The implementation must preserve the distinction between:

- Item Type
- Item Definition
- Service

Item information must be available where required in:

- Order Details
- Invoice / Receipt
- Storage

For applicable item types, additional information may include:

- Carpet Size
- Carpet dimensions
- Measurements
- Blanket type / definition

The UI must not display irrelevant fields for item types that do not require them.

---

## 25. Storage Implementation Rules

Storage is associated with the physical OrderItem.

The implementation must support:

- Items requiring storage
- Stored items
- Search
- Filters
- Storage location compatibility
- Bulk storage where approved
- Moving items between locations

New destination selection must allow only:

Active Location
+
Compatible Item Type

Existing inactive locations may remain visible as the current location when needed for historical or operational context.

Inactive locations must not be selectable as new destinations.

Storage functionality must not introduce:

- Storage capacity management
- Storage movement history
- Advanced warehouse management

unless explicitly approved later.

---

## 26. Payment Implementation

Payment is an independent transaction associated with an Order.

Payment must reference:

payments.order_id
→
orders.id

Payments must respect the approved remaining amount rules.

A payment greater than the remaining amount must be rejected.

Payment information must remain historically accurate.

Payment records must not be silently rewritten in a way that destroys historical transaction meaning.

Payment methods must follow the approved V1 configuration.

---

## 27. Expense Implementation

Expense is a first-class independent financial entity.

Expense includes the approved information such as:

- Amount
- Category
- Date
- Notes
- Expense Name when required

Expense must not depend on an Order.

Expense must not be represented as a Payment.

Expense Category is a master-data entity.

Active Expense Categories are available for new Expenses.

Inactive Expense Categories remain available for historical references but are not offered for new transactions.

The category:

أخرى

requires:

Expense Name

---

## 28. Financial Reporting Implementation

Financial reporting must derive values from the approved transaction data.

The implementation must not create:

- Profit table
- Profit snapshot
- Expense ledger
- Analytics tables

unless a future approved requirement explicitly introduces them.

Net Profit is a derived value:

Net Profit
=
Sales
-
Operating Expenses

Expense reporting must use expense_date for the selected reporting period.

Payments must remain distinct from Sales.

Do not calculate Net Profit as:

Payments - Expenses

---

## 29. Invoice Implementation

The application must provide an Invoice / Receipt view for an Order.

The invoice must preserve historical Order information.

Relevant information includes:

- Order Number
- Customer
- Item Type
- Item Definition when applicable
- Carpet Size / dimensions when applicable
- Service
- Price
- Delivery Fees
- Discount
- Total
- Payment Information
- Remaining Amount

The V1 Tax workflow is disabled.

Tax must not be exposed as an active user-facing calculation in V1.

The invoice must retain a suitable Print action.

Invoice presentation must follow the approved UI design.

---

## 30. Tax Implementation

Tax is not an active V1 user-facing workflow.

Do not implement or expose:

- Tax Enabled toggle
- Tax Rate configuration
- Active tax calculation
- Tax entry workflow
- Tax line as an active V1 order calculation

The V1 order financial calculation follows:

Subtotal
-
Discount
+
Delivery Fees
=
Total

If future-ready technical fields already exist in approved technical documentation, they may remain untouched when they are not exposed as an active V1 workflow.

Do not create a new Tax subsystem.

---

## 31. Business Settings Implementation

Business Information is the single source of truth for business identity information.

It includes the approved business information such as:

- Business Name
- Phone
- Address
- Logo
- Invoice Footer Text

Invoice rendering should consume these values rather than maintaining duplicate business identity records.

Do not create duplicate business identity storage.

---

## 32. Navigation Implementation

Primary navigation contains only:

- الرئيسية
- الطلبات
- التخزين
- العملاء
- التقارير
- الإعدادات

Payments and Expenses are not Primary Navigation destinations.

Payments remain accessible through approved payment workflows.

Expenses remain accessible through approved expense workflows.

Do not add:

- المدفوعات
- المصروفات

as Primary Navigation items.

Do not create additional navigation modules unless explicitly approved.

---

## 33. Routing

Routing must be centralized.

Only one routing solution should be used.

The routing package and exact implementation must follow the approved technical decision when finalized.

Do not introduce multiple routing systems.

Do not create navigation logic independently inside unrelated widgets.

Routes should map to approved application screens and workflows.

---

## 34. Localization

The application is Arabic-first.

All user-facing UI must support:

- Arabic text
- RTL layout
- Centralized localization

Do not hardcode repeated user-facing strings across widgets when they belong to centralized localization.

English may exist as an implementation fallback only where technically necessary, but V1 UI is Arabic-first.

User-facing terminology must match the approved Product and UI/UX documentation.

---

## 35. Theme and Design System

The application must use a centralized theme.

The implementation must preserve the approved Figma design system.

The primary Arabic font is:

IBM Plex Sans Arabic

Do not introduce arbitrary colors, typography, spacing, or component styles in individual features when an approved shared design token or component already exists.

Reusable UI components should be placed in the appropriate shared location only when reuse is justified.

Do not build a generic design framework unnecessarily.

---

## 36. Validation

Validation must exist at the appropriate layer.

Structural database integrity belongs to the database.

Business workflow validation belongs to Domain/Application behavior.

Presentation validation belongs to the UI where appropriate.

Examples of business validation include:

- Customer required for Order
- Order requires at least one OrderItem
- Payment cannot exceed remaining amount
- Expense category must be valid
- "أخرى" requires Expense Name
- Inactive master data cannot be selected for new transactions
- Storage destination must be active and compatible
- Completion conditions must be satisfied

Do not rely exclusively on UI validation for critical business rules.

---

## 37. Error Handling

Errors must be handled consistently.

The application should distinguish between:

- Validation errors
- Business rule violations
- Database errors
- Network errors
- Unexpected technical errors

User-facing errors must be actionable and understandable.

Technical details must not be exposed unnecessarily to end users.

Do not create a different error-handling architecture for each feature.

Use the centralized error strategy approved by the project documentation.

---

## 38. Testing Strategy

Testing is part of the implementation.

### Domain / Business Tests

Test:

- Pricing
- Payment calculations
- Status transitions
- Storage rules
- Completion rules
- Cancellation rules
- Delivery calculations
- Expense rules
- Financial calculations

### Data Tests

Test:

- Local persistence
- Queries
- Foreign key behavior
- Transactions
- Repository behavior
- Seed initialization
- Synchronization operation creation where applicable

### Presentation Tests

Test important:

- Cubit / Bloc states
- Form behavior
- Validation
- Loading states
- Error states
- Success states
- Important user interactions

### Integration Tests

Cover critical end-to-end workflows where appropriate.

At minimum, the implementation should make the following scenarios testable:

- Create Customer
- Create Order
- Add OrderItem
- Record Payment
- Store OrderItem
- Complete Order
- Record Expense
- Manage Expense Category
- Generate Financial Report
- Open Invoice
- Print Invoice workflow

---

## 39. Implementation Order

Implementation should proceed in dependency order.

### Phase 1 — Foundation

- Flutter project
- Project structure
- Core configuration
- Theme
- Localization
- RTL
- Dependency Injection
- Routing foundation
- Error foundation

### Phase 2 — Database

- Drift database
- Tables
- Foreign keys
- Indexes
- Constraints
- Migrations
- Seed initialization
- Transaction helpers where genuinely required

### Phase 3 — Domain

- Entities
- Enums
- Repository contracts
- Required domain services
- Business validation

### Phase 4 — Data Layer

- DAOs
- Local data sources
- Repository implementations
- Database-to-domain conversion where required
- Remote layer structure only where justified by the approved architecture

### Phase 5 — Core Features

Implement in dependency-aware order:

1. Customers
2. Master Data
3. Orders
4. Payments
5. Storage
6. Expenses
7. Reports
8. Dashboard
9. Settings

The exact order may be adjusted only when a real dependency requires it.

### Phase 6 — Integration

- Feature integration
- Navigation integration
- Cross-feature workflows
- Invoice integration
- Financial reporting integration

### Phase 7 — Testing and Stabilization

- Unit tests
- Data tests
- Widget tests
- Integration tests for critical workflows
- Offline verification
- Transaction verification
- Validation verification
- UI consistency verification

---

## 40. Definition of Implementation Completion

The V1 implementation is considered ready for final review when:

- The project builds successfully.
- The approved architecture is respected.
- SQLite and Drift are implemented.
- Database schema matches approved documentation.
- UUID identifiers are used correctly.
- Money uses integer minor units.
- Local-first workflows work without internet.
- Repository boundaries are respected.
- Bloc/Cubit is used consistently.
- Dependency injection is centralized through get_it.
- Networking is isolated behind the approved architecture.
- No unauthorized architecture layers exist.
- No unauthorized entities or tables exist.
- No unauthorized features exist.
- Critical business rules are enforced.
- Critical workflows are tested.
- Arabic / RTL UI is implemented.
- Approved navigation is implemented.
- Invoice workflow is implemented.
- Expenses are implemented as independent financial transactions.
- Net Profit is derived correctly.
- Tax is not exposed as an active V1 workflow.
- Synchronization remains ready but deferred from execution.
- No known documentation/code contradiction remains.

---

## 41. AI Coding Agent Rules

Any AI coding agent working on this project must:

1. Read the relevant documentation before modifying code.
2. Identify the affected layer and feature before creating files.
3. Reuse existing code when appropriate.
4. Avoid unnecessary abstractions.
5. Avoid duplicate models.
6. Avoid duplicate repositories.
7. Avoid duplicate state-management solutions.
8. Avoid introducing new architecture.
9. Avoid inventing business rules.
10. Avoid inventing entities.
11. Avoid inventing database tables.
12. Avoid inventing statuses.
13. Avoid inventing navigation items.
14. Avoid inventing API contracts.
15. Avoid changing approved technologies.
16. Preserve historical transaction data.
17. Preserve offline-first behavior.
18. Preserve database transaction boundaries.
19. Keep changes localized.
20. Add tests for important behavior.

Before creating a new file, determine:

- Which layer owns the responsibility?
- Which feature owns the responsibility?
- Is the file actually necessary?
- Does an existing class already provide the required functionality?
- Does the requested concept already exist elsewhere?

---

## 42. AI Change Safety

Before changing an existing feature, the implementation agent should identify:

- Affected feature
- Affected Domain entities
- Affected repository
- Affected local data
- Affected remote data, if any
- Affected UI
- Affected tests
- Affected documentation

Changes should remain as localized as possible.

If a change affects Product, Domain, Database, Architecture, or Technical Decisions, implementation must stop until the documentation impact is identified.

---

## 43. Documentation Change Rule

Code must not silently introduce a requirement that is not represented in documentation.

If implementation reveals that an approved requirement cannot be implemented without architectural or database changes:

1. Stop implementation.
2. Identify the conflict.
3. Identify affected documentation.
4. Resolve the documentation first.
5. Update the relevant source-of-truth documents.
6. Then continue implementation.

Do not modify documentation merely to justify an already-written implementation.

Documentation must lead implementation.

---

## 44. No Feature Expansion

The implementation agent must not add functionality because it appears useful.

The following are not V1 implementation targets unless explicitly approved:

- Driver management
- Vehicle management
- Route management
- Delivery tracking
- Employee management
- Roles
- Permissions
- Branches
- Refunds
- Loyalty
- Storage capacity
- Storage movement history
- Laundry processing stages
- AI Assistant
- Barcode workflows
- Advanced analytics
- Predictive analytics
- Advanced conflict resolution
- Real-time synchronization

Future possibilities must not create V1 complexity.

---

## 45. Implementation Philosophy

The project should remain:

- Simple
- Reliable
- Offline-first
- Maintainable
- Testable
- Consistent
- Production-oriented
- Easy for AI coding tools to understand

The implementation should prefer the simplest solution that correctly satisfies the approved requirements.

Do not optimize for architectural sophistication.

Optimize for correctness, clarity, maintainability, and business reliability.

---

## 46. Final Implementation Rule

The most important rule is:

Do exactly what the approved documentation requires.

Do not do less.

Do not do more.

Do not invent.

Do not silently reinterpret.

Do not expand scope.

Do not bypass architectural boundaries.

Do not introduce unnecessary abstractions.

When the documentation is clear, implement it.

When the documentation conflicts, stop and resolve the conflict.

When the documentation does not define a required decision, do not silently invent one.

The implementation must remain aligned with the complete project documentation at all times.