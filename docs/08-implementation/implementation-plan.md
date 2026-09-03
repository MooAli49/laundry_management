# Laundry Management System — Implementation Plan

## 1. Document Purpose

This document defines the official implementation sequence for the Laundry Management System V1.

It answers:

- What should be implemented first?
- What depends on what?
- What must be completed before moving forward?
- What should be tested at each stage?
- What is explicitly deferred?
- What conditions allow a phase to be considered complete?

This is an execution plan.

It does not redefine:

- Product scope
- Business rules
- Domain model
- Database design
- Architecture
- UI/UX design
- Technical decisions

Those remain governed by their respective source-of-truth documents.

---

# 2. Core Execution Principle

Implementation must proceed in dependency order.

The implementation agent must not:

- Skip foundational phases
- Implement dependent features before their dependencies
- Build UI against temporary fake business logic when the required domain/data layer is not ready
- Introduce new architecture to accelerate a feature
- Implement deferred functionality
- Implement features that are not approved
- Create speculative APIs
- Create speculative database tables

The required implementation direction is:

Foundation
↓
Database
↓
Domain
↓
Data Layer
↓
Feature Infrastructure
↓
Core Features
↓
Cross-Feature Workflows
↓
Testing
↓
Stabilization
↓
Final Acceptance

---

# 3. Phase Overview

The V1 implementation is divided into the following phases:

1. Project Foundation
2. Database Foundation
3. Domain Layer
4. Data Layer
5. Application Infrastructure
6. Customers
7. Master Data
8. Orders
9. Payments
10. Storage
11. Expenses
12. Reports
13. Dashboard
14. Settings
15. Invoice / Receipt
16. Cross-Feature Integration
17. Testing
18. Offline Verification
19. Final Stabilization
20. Final Acceptance

Each phase has:

- Objective
- Scope
- Dependencies
- Deliverables
- Validation
- Exit Criteria

---

# 4. Phase 1 — Project Foundation

## Objective

Create the base Flutter application and establish the approved project structure.

## Dependencies

None.

This is the first implementation phase.

## Scope

Implement:

- Flutter project
- Dart configuration
- Approved folder structure
- Application entry point
- Core directories
- Feature directories
- Basic configuration
- Environment-safe configuration structure
- Git-safe project setup where applicable

The initial project must compile before additional implementation begins.

## Required Foundation

Establish the approved structure:

lib/
├── core/
├── domain/
├── data/
├── features/
└── main.dart

Do not add unnecessary architectural directories.

## Deliverables

- Flutter project created
- Project compiles
- `main.dart` exists
- Approved directory structure exists
- No speculative feature implementation
- No fake production architecture

## Validation

Run:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

At this stage, tests may be minimal but the project must build and analyze successfully.

## Exit Criteria

Phase 1 is complete only when:

- Project builds successfully
- Project structure matches approved architecture
- No unauthorized packages are introduced
- No unauthorized architecture is introduced
- Basic application startup works

---

# 5. Phase 2 — Database Foundation

## Objective

Implement the approved local database using:

SQLite
+
Drift

## Dependencies

Phase 1.

## Scope

Implement:

- Drift database
- Tables
- Relationships
- Foreign keys
- Indexes
- Constraints
- Database initialization
- Migration foundation
- Seed initialization
- Transaction support

## Approved Tables

The implementation must cover the approved V1 tables:

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

Do not create additional business tables without an approved documentation change.

## Identifier Rules

Use UUID-based identifiers stored as:

TEXT

Do not use auto-increment integer IDs for business entities.

## Money Rules

Persist money as integer minor units.

Currency:

EGP

Example:

100.50 EGP
→
10050

## Seed Rules

Seed data must be:

- Local
- Idempotent
- Deterministic
- Transaction-safe where required

Seed data must not create fabricated operational transactions.

## Validation

Test:

- Database creation
- Database opening
- Foreign keys
- Constraints
- Indexes
- Basic CRUD
- Transactions
- Seed initialization
- Re-running seed initialization

## Exit Criteria

Phase 2 is complete only when:

- Database opens successfully
- All approved tables exist
- Relationships are correct
- Constraints are correct
- Indexes are implemented
- Money representation is correct
- UUID representation is correct
- Seed initialization is idempotent
- Transactions work correctly
- Database tests pass

---

# 6. Phase 3 — Domain Layer

## Objective

Implement the approved business concepts independently from persistence and UI.

## Dependencies

Phase 2 documentation/schema may inform the Domain, but the Domain must not depend directly on Drift implementation.

## Scope

Implement:

- Domain entities
- Domain enums
- Repository contracts
- Required domain services
- Business validation

## Rules

Domain code must not import:

- Flutter UI
- Drift
- SQLite
- Dio
- Retrofit

Domain code must remain infrastructure-independent.

## Core Domain Concepts

Implement only approved concepts, including:

- Customer
- Order
- OrderItem
- Payment
- StorageLocation
- StorageRecord
- ItemType
- ItemDefinition
- Service
- CarpetSize
- ExpenseCategory
- Expense
- BusinessSettings

Where appropriate, entities may reference IDs instead of infrastructure objects.

## Business Logic

Implement and test approved rules including:

- Order requirements
- Pricing
- Discount
- Delivery fees
- Payment limits
- Remaining amount
- Order status transitions
- Storage eligibility
- Expense validation
- Expense category behavior
- Completion conditions
- Financial calculations

## Tax

Tax is not an active V1 workflow.

Do not implement an active Tax domain workflow.

Future-ready data that is explicitly approved may remain untouched.

## Exit Criteria

Phase 3 is complete when:

- Entities exist
- Enums exist
- Repository contracts exist
- Business rules are testable
- Domain does not depend on infrastructure
- Domain tests pass

---

# 7. Phase 4 — Data Layer

## Objective

Connect the Domain contracts to the local Drift database.

## Dependencies

- Phase 2
- Phase 3

## Scope

Implement:

- DAOs
- Local data sources
- Repository implementations
- Required data models
- Database-to-domain conversion
- Domain-to-database conversion where required

## Rules

Repositories implement Domain contracts.

Presentation must not access DAOs directly.

Widgets must not access Drift directly.

Cubits must not execute SQL.

## Local Source of Truth

Local SQLite remains the primary operational source of truth.

Remote data is not required for normal V1 local workflows.

## Exit Criteria

Phase 4 is complete when:

- Repository implementations work
- Local CRUD works
- Queries work
- Transactions work
- Domain can consume persisted data through repository contracts
- Data layer tests pass

---

# 8. Phase 5 — Application Infrastructure

## Objective

Implement shared application infrastructure required by all features.

## Dependencies

- Phase 1
- Phase 3
- Phase 4

## Scope

Implement:

- get_it
- Routing foundation
- Theme
- Localization
- RTL
- Error handling foundation
- Shared utilities
- Shared widgets only where genuinely reusable

## Dependency Injection

Use:

get_it

Dependencies should be registered centrally.

Prefer constructor injection.

Do not introduce another DI framework.

## Routing

Use one centralized routing solution.

Do not create independent routing systems per feature.

## Localization

Arabic-first.

RTL must be enabled correctly.

## Theme

Use centralized theme configuration.

Use:

IBM Plex Sans Arabic

Do not introduce feature-specific design systems.

## Exit Criteria

Phase 5 is complete when:

- DI works
- Core dependencies resolve correctly
- Routing works
- Arabic localization works
- RTL works
- Theme works
- Shared error handling is available
- Application starts successfully

---

# 9. Phase 6 — Customers

## Objective

Implement Customer management.

## Dependencies

- Foundation
- Database
- Domain
- Data Layer
- Application Infrastructure

## Scope

Implement approved Customer workflows:

- Customer list
- Search
- Customer creation
- Customer editing
- Customer details
- Customer history where approved

## Validation

Test:

- Required fields
- Customer persistence
- Customer search
- Customer editing
- Customer retrieval

## Exit Criteria

Customer workflows work against the real local database.

No mock production data remains.

---

# 10. Phase 7 — Master Data

## Objective

Implement the master data required by Orders and Storage.

## Dependencies

- Customers foundation not necessarily required
- Database
- Domain
- Data Layer
- Application Infrastructure

## Scope

Implement:

- Item Types
- Item Definitions
- Services
- Service / Item Type relationships
- Carpet Sizes
- Storage Locations
- Storage Location / Item Type compatibility

## Settings Placement

Services & Pricing remain inside Settings.

Expense Categories remain inside Settings.

## Rules

Master data supports:

- Active
- Inactive

Inactive master data:

- Cannot be selected for new transactions where prohibited
- Remains available for historical references where required

## Exit Criteria

All master data required by downstream features can be loaded from the local database.

---

# 11. Phase 8 — Orders

## Objective

Implement the core Order workflow.

## Dependencies

- Customers
- Master Data
- Database
- Domain
- Data Layer
- Application Infrastructure

## Scope

Implement:

- Order creation
- Order items
- Item Type
- Item Definition where applicable
- Service
- Pricing
- Discount
- Delivery
- Order totals
- Order status
- Order details
- Order search/filtering where approved

## Order Number

Format:

YY-XXX

Do not use:

YYMMDD-XXX

## Order Requirements

An Order requires:

- Customer
- At least one OrderItem

OrderItem requires the approved item information.

## Delivery

Support independently:

- Delivery to Laundry
- Delivery to Customer

Both may be selected together.

Each has its own fee.

Do not implement:

- Driver
- Vehicle
- Route
- Tracking
- Assignment

## Tax

Tax is not active in V1.

Order calculation follows:

Subtotal
-
Discount
+
Delivery Fees
=
Total

## Transaction

Order creation must use an appropriate transaction boundary when multiple records are written.

## Exit Criteria

A complete Order can be created, persisted, retrieved, displayed, and updated according to approved business rules.

---

# 12. Phase 9 — Payments

## Objective

Implement Order payment functionality.

## Dependencies

- Orders
- Domain
- Data Layer

## Scope

Implement:

- Record Payment
- Payment Method
- Payment Amount
- Remaining Amount
- Payment History

## Rules

Payment must belong to an Order.

Payment amount must not exceed the remaining amount.

Payments must remain independent transaction records.

## Navigation

Payments are not a Primary Navigation item.

Payment functionality is accessible through approved workflows such as:

- Order Details
- تسجيل دفعة

## Exit Criteria

Payments can be created, persisted, retrieved, validated, and reflected correctly in Order financial state.

---

# 13. Phase 10 — Storage

## Objective

Implement physical OrderItem storage.

## Dependencies

- Orders
- Master Data
- Database
- Domain
- Data Layer

## Scope

Implement:

- Storage locations
- Storage records
- Store OrderItem
- Move OrderItem
- Search
- Filters
- Bulk storage where approved

## Core Rule

Storage operates on:

OrderItem

not only:

Order

## Destination Rule

A new destination must satisfy:

Active Location
+
Compatible Item Type

An inactive current location may remain visible when needed for existing operational context.

It must not be selectable as a new destination.

## Completion Interaction

All OrderItems stored is part of the Ready condition where required.

## Exit Criteria

Storage workflows correctly reflect physical OrderItem state.

---

# 14. Phase 11 — Expenses

## Objective

Implement independent expense management.

## Dependencies

- Database
- Domain
- Data Layer
- Application Infrastructure

## Scope

Implement:

- Expense creation
- Expense editing where approved
- Expense list
- Expense details
- Expense Categories
- Category activation/deactivation

## Rules

Expense is independent from:

- Order
- Payment

Expense Category:

- Active categories available for new expenses
- Inactive categories retained for historical references

Category:

أخرى

requires:

Expense Name

## Navigation

Expenses are not a Primary Navigation item.

Access remains through approved workflows such as:

- إضافة مصروف
- Financial Report / approved expense workflow

## Exit Criteria

Expenses can be created, persisted, retrieved, validated, and reported correctly.

---

# 15. Phase 12 — Reports

## Objective

Implement approved reporting functionality.

## Dependencies

- Orders
- Payments
- Expenses

## Scope

Implement:

- Sales
- Payments
- Expenses
- Remaining Amount
- Discounts
- Payment Methods
- Net Profit

## Net Profit

Calculate:

Sales
-
Operating Expenses

Do not calculate:

Payments
-
Expenses

## Data Rules

Reports must derive values from transactional data.

Do not create unnecessary analytics tables.

## Exit Criteria

Reports correctly reflect real local transaction data.

---

# 16. Phase 13 — Dashboard

## Objective

Implement the operational Dashboard.

## Dependencies

- Orders
- Payments
- Expenses
- Reports
- Storage where dashboard metrics require it

## Scope

Implement approved operational metrics and quick actions.

## Quick Actions

Exactly:

- إضافة طلب
- إضافة عميل
- تسجيل دفعة
- إضافة مصروف

Storage is not a Quick Action.

## Status Terminology

Use approved terminology:

- قيد التجهيز
- جاهز

## Welcome Section

Do not add the removed Welcome section.

## Exit Criteria

Dashboard reflects real application state.

No hardcoded production metrics remain.

---

# 17. Phase 14 — Settings

## Objective

Implement approved configuration and master-data management.

## Dependencies

- Database
- Domain
- Data Layer
- Application Infrastructure

## Scope

Implement approved Settings areas including:

- Business Information
- Services & Pricing
- Expense Categories
- Other approved configuration

## Business Information

Business identity information is maintained as the single source of truth.

The invoice consumes these values.

Do not create duplicate business identity storage.

## Services & Pricing

Services & Pricing remains inside Settings.

## Expense Categories

Expense Categories remain inside Settings.

## Tax

Do not expose active Tax configuration in V1.

## Exit Criteria

Settings changes persist correctly and are reflected by dependent workflows.

---

# 18. Phase 15 — Invoice / Receipt

## Objective

Implement the approved Invoice / Receipt workflow.

## Dependencies

- Orders
- Order Items
- Payments
- Business Settings
- Pricing

## Scope

Implement:

- Invoice view
- Order information
- Customer
- Item Type
- Item Definition where applicable
- Dimensions where applicable
- Service
- Price
- Delivery Fees
- Discount
- Total
- Payment information
- Remaining amount
- Print action

## Tax

Tax must not appear as an active V1 calculation.

## Historical Data

Invoice must represent the Order's historical state correctly.

Business identity information comes from Business Settings.

## Exit Criteria

Invoice renders correctly from persisted Order data and remains consistent with the approved UI.

---

# 19. Phase 16 — Cross-Feature Integration

## Objective

Verify that individual features operate correctly together.

## Dependencies

All major features.

## Required Workflows

At minimum:

### Customer → Order

Create Customer
↓
Create Order
↓
Attach Customer

### Order → OrderItem

Create Order
↓
Add OrderItem
↓
Select Item Type
↓
Select Definition when applicable
↓
Select Service
↓
Calculate Price

### Order → Payment

Create Order
↓
Record Payment
↓
Update Remaining Amount

### Order → Storage

Create OrderItem
↓
Store OrderItem
↓
Update Storage State
↓
Evaluate Ready Condition

### Order → Completion

Ready
+
Fully Paid
+
Handover Confirmed
↓
Completed

### Expense → Report

Create Expense
↓
Persist Expense
↓
Include Expense in Report
↓
Calculate Net Profit

### Business Settings → Invoice

Update Business Information
↓
Open Invoice
↓
Invoice reflects Business Information

---

# 20. Phase 17 — Testing

## Objective

Validate the complete implementation against approved requirements.

## Scope

### Unit Tests

Cover:

- Pricing
- Discounts
- Delivery fees
- Payment validation
- Remaining amount
- Status transitions
- Storage compatibility
- Expense validation
- Net Profit
- Completion conditions

### Database Tests

Cover:

- Tables
- Relationships
- Foreign keys
- Constraints
- Indexes
- Transactions
- Seed initialization

### Repository Tests

Cover:

- Create
- Read
- Update
- Search
- Filtering
- Transactional operations

### Bloc/Cubit Tests

Cover:

- Loading
- Success
- Empty
- Error
- Validation
- Important transitions

### Widget Tests

Cover important UI workflows.

### Integration Tests

Cover critical business workflows.

## Exit Criteria

Critical business behavior has automated coverage appropriate to its risk.

---

# 21. Phase 18 — Offline Verification

## Objective

Verify that the V1 application behaves correctly without internet access.

## Test Procedure

Test the application with network access unavailable.

Verify:

- Application starts
- Database opens
- Seed data is available
- Customers work
- Orders work
- Payments work
- Storage works
- Expenses work
- Reports work
- Settings work
- Invoice works

Normal local operations must not fail simply because internet access is unavailable.

## Exit Criteria

Core V1 workflows remain functional offline.

---

# 22. Phase 19 — Final Stabilization

## Objective

Clean the implementation before final acceptance.

## Review Areas

Check for:

- Unused code
- Duplicate code
- Duplicate models
- Duplicate repositories
- Unnecessary abstractions
- Dead routes
- Dead widgets
- Debug-only behavior
- Hardcoded production values
- Incorrect terminology
- Incorrect RTL behavior
- UI inconsistencies
- Missing loading states
- Missing error states
- Missing empty states
- Incorrect database queries
- Missing transaction boundaries
- Incorrect financial calculations

## Architecture Review

Verify:

- Domain has no infrastructure dependencies
- Presentation does not access database directly
- Cubits do not access Drift directly
- Repositories are respected
- get_it is centralized
- Dio/Retrofit are isolated
- No unauthorized packages were added

## Scope Review

Verify:

- No unauthorized feature was added
- No unauthorized table was added
- No unauthorized entity was added
- No unauthorized navigation item was added
- No deferred functionality was implemented

---

# 23. Phase 20 — Final Acceptance

## Objective

Determine whether the V1 implementation is ready for delivery / production preparation.

## Required Acceptance Areas

### Architecture

- Approved architecture followed
- Correct dependency direction
- No unnecessary layers

### Database

- Schema matches documentation
- Constraints work
- Indexes work
- Transactions work
- UUIDs correct
- Money representation correct

### Domain

- Business rules enforced
- No infrastructure coupling

### Features

- Customers complete
- Orders complete
- Payments complete
- Storage complete
- Expenses complete
- Reports complete
- Dashboard complete
- Settings complete
- Invoice complete

### Offline

- Core workflows operate offline

### UI

- Arabic-first
- RTL
- Approved navigation
- Approved design system
- Approved terminology

### Financial

- Pricing correct
- Discounts correct
- Delivery fees correct
- Payments correct
- Expenses correct
- Net Profit correct
- Tax inactive in V1

### Scope

- No unauthorized functionality
- No speculative functionality
- No deferred functionality implemented prematurely

---

# 24. Phase Completion Rule

A phase is not considered complete because the code was written.

A phase is complete only when:

1. Required implementation exists.
2. Required validation exists.
3. Tests pass where applicable.
4. No known blocker remains.
5. The phase's exit criteria are satisfied.
6. No undocumented behavior was introduced.

The implementation agent must not mark a phase complete based solely on compilation.

---

# 25. Phase Transition Rule

Before moving from one phase to the next:

1. Verify the current phase.
2. Run relevant tests.
3. Check architecture boundaries.
4. Check database integrity where relevant.
5. Check documentation alignment.
6. Confirm exit criteria.
7. Only then begin the next phase.

If a blocker is found:

STOP.

Do not work around the blocker by introducing undocumented behavior.

---

# 26. Handling Documentation Conflicts

If implementation reveals a conflict between documents:

STOP implementation of the affected area.

Report:

- Conflicting documents
- Conflicting statements
- Affected code
- Affected database
- Recommended resolution if appropriate

Do not silently choose one.

Do not modify the documentation simply to justify existing code.

The source-of-truth documentation must be resolved first.

---

# 27. Handling Missing Decisions

If implementation requires a decision that is not defined:

Do not invent the decision when it affects:

- Business behavior
- Database structure
- Architecture
- API contract
- Security
- Financial logic
- Data integrity

Pause and request a decision.

For minor implementation details that do not affect approved behavior or architecture, choose the simplest maintainable solution and document it when appropriate.

---

# 28. Handling Bugs

When a bug is found:

1. Reproduce it.
2. Identify the responsible layer.
3. Determine whether the issue is implementation or documentation.
4. Fix it at the correct layer.
5. Add or update a test.
6. Re-run affected tests.
7. Verify no regression.

Do not patch the UI to hide a Domain or Data Layer bug.

---

# 29. Handling Scope Requests During Implementation

If a new feature is requested during implementation:

Do not immediately implement it.

First determine whether it is:

- Already approved
- A clarification of an approved feature
- A new requirement
- A scope expansion

If it is a new requirement or scope expansion:

Stop the affected implementation.

Update the appropriate documentation first.

Then update the implementation plan if necessary.

Then implement it.

---

# 30. AI Coding Agent Operating Mode

The AI coding agent must operate phase-by-phase.

At the beginning of each phase:

1. Read this implementation plan.
2. Read the relevant source-of-truth documentation.
3. Identify dependencies.
4. Identify expected deliverables.
5. Implement only the current phase.

At the end of each phase:

1. Run validation.
2. Report completed work.
3. Report tests.
4. Report known issues.
5. Confirm exit criteria.
6. Wait before moving to unrelated future phases unless explicitly instructed to continue.

The agent must not implement the entire application in one uncontrolled operation.

---

# 31. Required Phase Report

At the completion of each phase, the implementation agent should provide:

## Phase

Name and number of the completed phase.

## Completed

List implemented items.

## Tests

List tests executed and their results.

## Exit Criteria

List each exit criterion and whether it passed.

## Issues

List remaining issues.

If none:

None

## Documentation Impact

State whether documentation changes are required.

If none:

None

## Next Phase

State the next planned phase.

Do not start the next phase automatically unless instructed.

---

# 32. Definition of Done

The implementation is considered done only when:

- All required phases are complete.
- All required exit criteria pass.
- Critical tests pass.
- Offline operation is verified.
- Database integrity is verified.
- Business rules are verified.
- Architecture is verified.
- UI is aligned with approved design.
- No unauthorized feature exists.
- No known critical blocker remains.
- Documentation and implementation are aligned.

---

# 33. Final Rule

The implementation plan is sequential.

Do not skip.

Do not guess.

Do not expand scope.

Do not implement future functionality prematurely.

Do not create architecture that is not required.

Do not treat compilation as completion.

Do not treat a visually complete screen as a completed feature.

A feature is complete only when:

UI
+
State
+
Domain
+
Data
+
Persistence
+
Validation
+
Tests

are correctly integrated according to the approved documentation.

The implementation must progress from foundation to verified functionality.

Correctness comes before speed.