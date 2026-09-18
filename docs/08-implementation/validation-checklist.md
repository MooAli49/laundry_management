# Validation Checklist

## 1. Purpose

This document defines the final validation checklist for the V1 Flutter implementation of the Laundry Management System.

Its purpose is to verify that the implementation:

- Follows the approved architecture.
- Follows the documented business rules.
- Follows the approved database design.
- Follows the Offline-First strategy.
- Uses Cubit-only state management.
- Uses the approved routing architecture.
- Uses GetIt for dependency injection.
- Preserves the documented feature boundaries.
- Does not introduce undocumented architecture or dependencies.
- Is ready for functional testing and the next implementation phase.

This checklist is a validation document.

It does not introduce new architecture decisions.

---

## 2. Validation Rules

The implementation must satisfy the documented project decisions before it is considered complete.

For every checklist item use one of:

- PASS
- FAIL
- N/A

Do not mark an item PASS based only on the existence of a file or class.

Validate actual implementation behavior and architecture.

---

## 3. Documentation Alignment

### 3.1 Scope

- [ ] Implementation matches the approved project scope.
- [ ] No out-of-scope feature was implemented.
- [ ] No undocumented major feature was introduced.
- [ ] Deferred features remain deferred.
- [ ] V1 boundaries remain intact.

### 3.2 Requirements

- [ ] Functional requirements are represented in the implementation.
- [ ] Important user workflows are implemented according to the documented requirements.
- [ ] No documented requirement was silently removed.
- [ ] Requirements that are intentionally deferred are clearly identified.

### 3.3 Business Rules

- [ ] Documented business rules are implemented.
- [ ] Business invariants are not duplicated inconsistently across layers.
- [ ] Invalid business operations are rejected.
- [ ] Business calculations follow the documented rules.
- [ ] Status transitions follow the documented rules.

---

## 4. Architecture Validation

### 4.1 Layer Boundaries

- [ ] Presentation depends on approved application/domain abstractions.
- [ ] Presentation does not directly access database implementation.
- [ ] Presentation does not directly access DAOs.
- [ ] Presentation does not contain SQL/Drift queries.
- [ ] Domain does not depend on Flutter.
- [ ] Domain does not depend on `flutter_bloc`.
- [ ] Data Layer does not depend on Presentation.
- [ ] Data Layer does not depend on Cubits.
- [ ] Repository boundaries are respected.

### 4.2 Dependency Direction

Expected direction:

Presentation
→
Domain/Application abstractions
→
Repository
→
Data Layer
→
Database

Validate that dependencies do not point upward into Presentation.

---

## 5. Project Structure

- [ ] Files follow the approved project structure.
- [ ] Feature code is placed in the correct feature directories.
- [ ] Cubits are placed in the approved Presentation locations.
- [ ] Repository implementations are placed in the Data Layer.
- [ ] Database code is placed in the approved database/data locations.
- [ ] Shared code is not placed inside an unrelated feature.
- [ ] No duplicate implementations exist because of incorrect folder placement.
- [ ] File names follow the documented naming conventions.

---

## 6. Dependency Injection

- [ ] GetIt is used as the approved dependency-injection mechanism.
- [ ] Required dependencies are registered.
- [ ] Database dependencies are registered correctly.
- [ ] Data sources/DAOs are registered correctly.
- [ ] Repository implementations are registered correctly.
- [ ] Cubit dependencies are provided through the approved DI configuration.
- [ ] Cubits do not manually construct repositories.
- [ ] Repositories do not manually construct database infrastructure unnecessarily.
- [ ] No second service-locator/state-management system was introduced.
- [ ] Dependency lifetimes/scopes are appropriate.

---

## 7. State Management

### 7.1 Cubit-Only

- [ ] Cubit is the application state-management solution.
- [ ] No BLoC classes were introduced.
- [ ] No BLoC event classes were introduced.
- [ ] No `on<Event>()` BLoC architecture was introduced.
- [ ] No alternative application-wide state-management framework was introduced.

### 7.2 Cubit Responsibilities

- [ ] Cubits manage Presentation state.
- [ ] Cubits call Repository/domain abstractions.
- [ ] Cubits do not access the database directly.
- [ ] Cubits do not access DAOs directly.
- [ ] Cubits do not contain SQL.
- [ ] Cubits do not contain Drift queries.
- [ ] Cubits do not contain core persistence logic.
- [ ] Cubits do not contain unrelated feature logic.
- [ ] Cubits do not become God Cubits.

### 7.3 State

- [ ] State is immutable.
- [ ] Initial state is meaningful.
- [ ] Loading state is represented where required.
- [ ] Success state is represented where required.
- [ ] Empty state is represented where required.
- [ ] Failure state is represented where required.
- [ ] Existing data is preserved during independent mutations where appropriate.
- [ ] State equality behaves predictably.
- [ ] Mutable collections are not exposed unnecessarily.
- [ ] State does not contain Widgets.
- [ ] State does not contain `BuildContext`.
- [ ] State does not contain Flutter controllers.

### 7.4 Cubit Lifecycle

- [ ] Cubits have appropriate lifecycle/scope.
- [ ] Stream subscriptions are safely disposed.
- [ ] Cubits do not emit invalid state after disposal.
- [ ] Feature Cubits are not unnecessarily global.
- [ ] Business data does not depend on Cubit memory surviving screen recreation.

---

## 8. Repository Validation

- [ ] Presentation accesses data through Repository abstractions.
- [ ] Repository responsibilities are clearly defined.
- [ ] Repository does not expose unnecessary Data Layer implementation details.
- [ ] Repository handles the appropriate data source coordination.
- [ ] Repository returns appropriate results/failures.
- [ ] Repository does not contain UI logic.
- [ ] Repository does not depend on Widgets or BuildContext.
- [ ] Repository behavior matches the documented data-layer architecture.

---

## 9. Database Validation

- [ ] Database implementation follows the approved database design.
- [ ] Tables match the documented schema.
- [ ] Primary keys are correct.
- [ ] Foreign keys are correct.
- [ ] Required constraints are implemented.
- [ ] Unique constraints are implemented.
- [ ] Nullability matches the documented design.
- [ ] Defaults match the documented design.
- [ ] Relationships match the documented relationship model.
- [ ] Indexes required by the documentation exist.
- [ ] Database transactions are used where required.
- [ ] Business-critical multi-step operations are atomic.
- [ ] No undocumented schema changes were introduced.

---

## 10. Database Integrity

- [ ] Invalid foreign-key references are prevented.
- [ ] Required fields cannot become invalid null values.
- [ ] Unique business identifiers remain unique.
- [ ] Required status values are constrained.
- [ ] Database constraints support the documented business rules.
- [ ] Delete behavior matches the documented relationship decisions.
- [ ] Update behavior matches the documented relationship decisions.
- [ ] No operation can silently create orphaned records where prohibited.
- [ ] Database-level integrity is not delegated entirely to the UI.

---

## 11. Local-First Validation

### 11.1 Core Principle

- [ ] Local database is the V1 operational source.
- [ ] Core workflows work without Internet access.
- [ ] Normal CRUD operations do not require connectivity.
- [ ] Feature Cubits do not depend on network availability.
- [ ] Connectivity checks are not required for normal local operations.

### 11.2 Sync Integration Phase

- [x] Offline / Sync Integration implementation follows the approved decisions in `synchronization-implementation.md` and `technical-decisions.md` §55.
- [x] Synchronization infrastructure (Sync Engine, Sync Queue, Remote Data Sources) is implemented in the Data / Infrastructure layer only.
- [x] Local workflows remain fully operational without network access after sync infrastructure is added.
- [x] Sync state is kept separate from business entity state.
- [x] Cubits and Widgets remain free from sync engine logic.
- [x] Supabase is accessed only through the approved Remote Data Source boundary.
- [x] Multi-tenant / SaaS functionality was not introduced prematurely.

### 11.3 Future Compatibility

- [ ] Repository boundaries allow future remote data sources.
- [ ] Feature-layer architecture does not depend on SQLite-specific details.
- [ ] Cubits do not need to know whether data is local or remote.
- [ ] Future synchronization can be introduced without rewriting Presentation architecture unnecessarily.

---

## 12. Reactive Local Data

- [ ] Features that require automatic local updates use approved repository streams/watchers.
- [ ] Cubits subscribe through Repository abstractions.
- [ ] Cubits do not subscribe directly to Drift database internals.
- [ ] Stream subscriptions are disposed safely.
- [ ] Empty stream results are handled correctly.
- [ ] Stream failures are represented as appropriate Presentation failures.
- [ ] Manual refresh loops are not used unnecessarily.
- [ ] Duplicate data-loading mechanisms are avoided.

---

## 13. Routing and Navigation

### 13.1 Route Architecture

- [ ] Routes are not hardcoded throughout screens.
- [ ] Route definitions are centralized.
- [ ] The approved route class/constants structure is used.
- [ ] `AppRouter` exists and is the central routing configuration.
- [ ] Screens navigate through the approved router architecture.
- [ ] Route names/paths are not duplicated as arbitrary string literals.
- [ ] Route parameters are defined consistently.

### 13.2 Navigation Boundaries

- [ ] Cubits do not own navigation.
- [ ] Cubits do not call `Navigator`.
- [ ] Cubits do not call `context.go()`.
- [ ] Cubits do not call `context.push()`.
- [ ] Cubits do not depend on `AppRouter`.
- [ ] Screens/Presentation handle navigation.
- [ ] Route parameters are passed into detail screens/Cubits correctly.
- [ ] Navigation behavior matches the documented navigation structure.

### 13.3 Route Parameters

- [ ] Required route parameters are validated appropriately.
- [ ] Entity IDs are passed using the approved types.
- [ ] Cubits receive typed parameters rather than parsing route strings.
- [ ] Invalid/missing route parameters produce appropriate behavior.

---

## 14. UI and Presentation

- [ ] UI follows the approved design system.
- [ ] UI follows the approved Arabic-first direction.
- [ ] RTL behavior is correct.
- [ ] User-facing strings are localized appropriately.
- [ ] Cubits do not contain hardcoded UI messages.
- [ ] Widgets do not contain Repository/database logic.
- [ ] Widgets do not contain SQL/Drift logic.
- [ ] Widgets do not implement core business rules.
- [ ] Loading states are displayed appropriately.
- [ ] Empty states are displayed appropriately.
- [ ] Failure states are displayed appropriately.
- [ ] Success feedback follows the approved UX.
- [ ] Dialogs remain Presentation concerns.
- [ ] SnackBars/toasts remain Presentation concerns.

---

## 15. Forms and Validation

- [ ] Required fields are validated.
- [ ] Basic input validation is handled at the appropriate Presentation boundary.
- [ ] Business validation remains in the appropriate business/domain layer.
- [ ] Invalid submissions cannot proceed.
- [ ] Validation feedback is understandable to the user.
- [ ] Arabic validation messages are localized appropriately.
- [ ] Form submission state prevents accidental duplicate submission.
- [ ] Critical mutations are protected against accidental double submission.

---

## 16. Customer Feature

- [ ] Customer creation follows the documented requirements.
- [ ] Customer editing follows the documented requirements.
- [ ] Customer search works as specified.
- [ ] Customer list state is correct.
- [ ] Customer details state is correct.
- [ ] Customer data is persisted locally.
- [ ] Customer relationships are preserved.
- [ ] Customer validation follows the documented rules.

---

## 17. Order Feature

- [ ] Order creation follows the documented workflow.
- [ ] Order items are represented correctly.
- [ ] Pricing follows the documented pricing model.
- [ ] Customer association is correct.
- [ ] Order status transitions follow the business rules.
- [ ] Payment behavior follows the documented rules.
- [ ] Remaining balance is calculated correctly.
- [ ] Expected Pickup behavior matches the documented requirements.
- [ ] Order completion follows the documented prerequisites.
- [ ] Order cancellation follows the documented rules.
- [ ] Order data is persisted locally.
- [ ] Order detail navigation works correctly.

---

## 18. Storage Feature

- [ ] Storage workflow matches the approved requirements.
- [ ] Items can be associated with storage appropriately.
- [ ] Storage locations are handled according to the domain model.
- [ ] Storage movement follows the documented rules.
- [ ] Storage state is persisted locally.
- [ ] Storage operations are atomic where required.
- [ ] Invalid storage operations are rejected.
- [ ] Storage UI reflects the persisted state correctly.

---

## 19. Expense Feature

- [ ] Expense creation follows the documented requirements.
- [ ] Expense editing follows the documented requirements.
- [ ] Expense categories are handled correctly.
- [ ] Expense date behavior is correct.
- [ ] Expense amounts are validated.
- [ ] Expense data is persisted locally.
- [ ] Expense list/filter behavior matches the approved design.

---

## 20. Master Data

For each approved master-data feature:

- [ ] Create behavior is correct.
- [ ] Edit behavior is correct.
- [ ] Required validation exists.
- [ ] Relationships are preserved.
- [ ] Local persistence works.
- [ ] Search/filter behavior works where required.
- [ ] Duplicate records are prevented where required.
- [ ] UI state is correct.

Applicable areas include:

- [ ] Services.
- [ ] Item Types.
- [ ] Item Definitions.
- [ ] Storage Locations.
- [ ] Expense Categories.
- [ ] Other approved master data.

---

## 21. Dashboard

- [ ] Dashboard loads from approved local data sources.
- [ ] Dashboard does not depend on remote connectivity.
- [ ] Dashboard calculations match the documented requirements.
- [ ] Dashboard does not depend directly on unrelated Cubits.
- [ ] Dashboard data is refreshed/reactive according to the approved design.
- [ ] Empty states are handled correctly.
- [ ] Loading states are handled correctly.
- [ ] Failure states are handled correctly.

---

## 22. Business Workflow Validation

### 22.1 Customer → Order

- [ ] Customer can be selected correctly.
- [ ] Order is associated with the correct Customer.
- [ ] Customer data remains consistent after Order creation.

### 22.2 Order → Items

- [ ] Order items are created correctly.
- [ ] Item/service relationships are valid.
- [ ] Pricing information is correct.

### 22.3 Order → Storage

- [ ] Items requiring storage can enter storage.
- [ ] Storage records correspond to the correct order/item.
- [ ] Storage movement follows the documented workflow.
- [ ] Storage completion/removal follows the documented rules.

### 22.4 Order → Payment

- [ ] Payment is associated with the correct Order.
- [ ] Payment amount is validated.
- [ ] Payment cannot violate the documented financial rules.
- [ ] Remaining balance updates correctly.
- [ ] Duplicate payment submission is prevented.

### 22.5 Order → Completion

- [ ] Completion prerequisites are enforced.
- [ ] Completion changes the correct Order status.
- [ ] Required storage/handover behavior is executed atomically where required.
- [ ] UI reflects the resulting state correctly.

---

## 23. Error Handling

- [ ] Repository failures are mapped appropriately.
- [ ] Database failures do not leak raw technical details to the UI.
- [ ] Validation failures are distinguishable from infrastructure failures.
- [ ] Not-found cases are handled appropriately.
- [ ] Unexpected failures are handled safely.
- [ ] Retry behavior exists where appropriate.
- [ ] Old failure state is cleared after successful recovery.
- [ ] User-facing errors are localized.

---

## 24. Offline Behavior Testing

Perform validation with network connectivity unavailable.

### Customer

- [ ] Create Customer works offline.
- [ ] Edit Customer works offline.
- [ ] Search Customer works offline.

### Orders

- [ ] Create Order works offline.
- [ ] View Orders works offline.
- [ ] View Order Details works offline.
- [ ] Record Payment works offline.
- [ ] Complete Order works offline where prerequisites are satisfied.

### Storage

- [ ] Store item works offline.
- [ ] Move item works offline.

### Expenses

- [ ] Create Expense works offline.
- [ ] Edit Expense works offline.
- [ ] View Expenses works offline.

### Dashboard

- [ ] Dashboard works from local data offline.

---

## 25. Data Consistency Testing

- [ ] Create operations persist after screen navigation.
- [ ] Create operations persist after application restart.
- [ ] Edit operations persist after screen navigation.
- [ ] Edit operations persist after application restart.
- [ ] Payment updates persist after restart.
- [ ] Storage movement persists after restart.
- [ ] Order status changes persist after restart.
- [ ] Related records remain consistent after restart.

---

## 26. Transaction Validation

For every documented atomic operation:

- [ ] Transaction starts correctly.
- [ ] All required changes occur within the transaction.
- [ ] Failure rolls back all related changes.
- [ ] Partial updates cannot remain after failure.
- [ ] Successful transaction leaves consistent database state.

Critical operations should be explicitly tested.

---

## 27. Duplicate Submission Testing

Test critical mutations by triggering the action repeatedly.

- [ ] Customer creation does not create unintended duplicates.
- [ ] Order creation does not create unintended duplicates.
- [ ] Payment cannot be accidentally duplicated.
- [ ] Expense creation does not create unintended duplicates.
- [ ] Storage movement does not create unintended duplicate records.
- [ ] UI disables or otherwise protects critical actions while submitting where appropriate.

---

## 28. Application Restart Testing

After creating/modifying data:

1. Close the application.
2. Restart the application.
3. Navigate to the relevant feature.

Validate:

- [ ] Customers remain available.
- [ ] Orders remain available.
- [ ] Order items remain available.
- [ ] Payments remain available.
- [ ] Storage state remains available.
- [ ] Expenses remain available.
- [ ] Master data remains available.
- [ ] Dashboard reflects persisted data.

---

## 29. Navigation Testing

- [ ] Every documented route opens correctly.
- [ ] Back navigation works correctly.
- [ ] Detail routes receive correct IDs.
- [ ] Invalid IDs are handled safely.
- [ ] No screen depends on manually constructed route strings outside the approved route definitions.
- [ ] Deep navigation does not break Cubit lifecycle.
- [ ] Returning to a feature reconstructs state correctly from local data.

---

## 30. State Management Testing

For each important Cubit:

- [ ] Initial state tested.
- [ ] Loading state tested.
- [ ] Success state tested.
- [ ] Empty state tested.
- [ ] Failure state tested.
- [ ] Mutation state tested where applicable.
- [ ] Retry behavior tested where applicable.
- [ ] Stream behavior tested where applicable.
- [ ] Cubit disposal tested where applicable.
- [ ] No direct database dependency exists.
- [ ] No navigation dependency exists.

---

## 31. Repository Testing

For each important Repository:

- [ ] Successful read tested.
- [ ] Empty result tested.
- [ ] Successful mutation tested.
- [ ] Failure tested.
- [ ] Required transaction behavior tested.
- [ ] Repository/Data Layer mapping tested.
- [ ] Local-first behavior tested.

---

## 32. Database Testing

- [ ] Database initializes successfully.
- [ ] Migrations, if applicable, work correctly.
- [ ] Tables are created correctly.
- [ ] Constraints work correctly.
- [ ] Foreign keys work correctly.
- [ ] Unique constraints work correctly.
- [ ] Required indexes exist.
- [ ] Transactions behave correctly.
- [ ] Database can be reopened without corruption.
- [ ] Persisted data survives application restart.

---

## 33. Performance Validation

- [ ] Application startup is reasonable.
- [ ] Feature initialization is not unnecessarily global.
- [ ] Large lists do not trigger unnecessary rebuilds.
- [ ] Database queries are appropriate.
- [ ] Required indexes are present.
- [ ] Search does not unnecessarily load the entire database.
- [ ] Reactive streams do not create duplicate subscriptions.
- [ ] Cubits do not perform heavy unnecessary synchronous work.
- [ ] No obvious memory leaks exist.

---

## 34. Code Quality

- [ ] Code follows `coding-standards.md`.
- [ ] Naming conventions are followed.
- [ ] Files are appropriately scoped.
- [ ] No dead code remains.
- [ ] No temporary debugging code remains.
- [ ] No unnecessary TODOs remain for completed functionality.
- [ ] No commented-out production code remains unnecessarily.
- [ ] No duplicate implementation exists.
- [ ] No unnecessary abstraction was introduced.
- [ ] No unrelated refactor was introduced.

---

## 35. Dependencies

- [ ] All dependencies are documented/approved.
- [ ] No unnecessary package was added.
- [ ] `flutter_bloc` is used for Cubit.
- [ ] GetIt is used for dependency injection.
- [ ] Dio/Retrofit are not introduced into V1 workflows unless explicitly required by the current implementation phase.
- [ ] No alternative state-management package was introduced.
- [ ] Dependency versions are compatible with the project environment.

---

## 36. Security and Data Safety

- [ ] Sensitive information is not logged unnecessarily.
- [ ] Database credentials/secrets are not hardcoded.
- [ ] API credentials are not added to V1 local-only code.
- [ ] User-facing errors do not expose technical internals.
- [ ] Debug-only data is not shown in production UI.

---

## 37. Arabic and RTL Validation

- [ ] Application UI is Arabic-first.
- [ ] RTL layout is applied correctly.
- [ ] Text alignment is appropriate.
- [ ] Icons with directional meaning are handled correctly.
- [ ] Navigation direction is appropriate.
- [ ] Forms behave correctly in RTL.
- [ ] Numeric values remain readable.
- [ ] Dates and currency display follow the approved formatting.
- [ ] Error/success messages are localized.
- [ ] No unintended English user-facing strings remain.

---

## 38. Design System Validation

- [ ] Approved typography is used.
- [ ] Approved spacing system is used.
- [ ] Approved component styles are used.
- [ ] Buttons follow the design system.
- [ ] Inputs follow the design system.
- [ ] Cards follow the design system.
- [ ] Tables/lists follow the approved patterns.
- [ ] Empty states follow the approved pattern.
- [ ] Error states follow the approved pattern.
- [ ] Loading states follow the approved pattern.
- [ ] No unrelated visual system was introduced.

---

## 39. Scope Protection

The following must remain outside the implementation unless explicitly approved:

- [ ] Advanced multi-device / distributed conflict resolution.
- [ ] Raw WebSocket / full real-time collaborative document editing (note: Supabase Realtime Broadcast wake-up signal adapter is approved and implemented; raw real-time data streaming remains deferred).
- [ ] Complex background synchronization.
- [ ] CRDTs / Event Sourcing.
- [ ] Advanced offline synchronization UI.
- [ ] Smart Assistant.
- [ ] Multi-tenant / SaaS functionality.
- [ ] Other explicitly deferred features.

Deferred functionality must not be partially implemented in a way that creates architectural confusion.

Sync infrastructure (Sync Engine, Sync Queue, Remote Data Sources, RemoteChangeApplier, RealtimeSyncAdapter) is part of the approved, completed, and locked Offline / Sync Integration phase (Task #15) and is validated under §55.

---

## 40. Architecture Anti-Patterns

Verify that none of the following exist:

- [ ] UI → Database direct access.
- [ ] UI → DAO direct access.
- [ ] Cubit → Database direct access.
- [ ] Cubit → DAO direct access.
- [ ] Cubit → Dio direct access.
- [ ] Cubit → Retrofit direct access.
- [ ] Cubit → Router direct access.
- [ ] Repository → Widget dependency.
- [ ] Domain → Flutter dependency.
- [ ] Data Layer → Presentation dependency.
- [ ] BLoC event architecture.
- [ ] Multiple application-wide state-management frameworks.
- [ ] Hardcoded routes throughout the application.
- [ ] God Cubit.
- [ ] Cubit-to-Cubit business-data coupling.
- [ ] Business rules duplicated across unrelated screens.
- [ ] SQL queries inside Presentation.
- [ ] SQL queries inside Cubit.
- [ ] User-facing Arabic strings hardcoded inside Cubit.
- [ ] Manual network dependency in V1 local workflows.

---

## 41. Build Validation

- [ ] `flutter pub get` completes successfully.
- [ ] Project builds successfully.
- [ ] Debug build runs successfully.
- [ ] Release build does not contain obvious implementation errors.
- [ ] Static analysis completes successfully.
- [ ] No new analyzer errors were introduced.
- [ ] No new compile errors were introduced.
- [ ] Relevant tests pass.

---

## 42. Test Suite Validation

Run the relevant test suite and record:

### Unit Tests

- [ ] Domain tests pass.
- [ ] Repository tests pass.
- [ ] Cubit tests pass.
- [ ] Database/data-layer tests pass.

### Widget Tests

- [ ] Critical screen tests pass.
- [ ] Form behavior tests pass.
- [ ] Important loading/empty/error states pass.

### Integration Tests

Where applicable:

- [ ] Critical customer workflow passes.
- [ ] Critical order workflow passes.
- [ ] Payment workflow passes.
- [ ] Storage workflow passes.
- [ ] Expense workflow passes.

---

## 43. Manual End-to-End Workflow

Perform at least one complete business workflow from start to finish.

Suggested workflow:

Create Customer
↓
Create Order
↓
Add Order Items
↓
Calculate/confirm pricing
↓
Store required items
↓
Record Payment
↓
Verify remaining balance
↓
Complete required storage/handover workflow
↓
Complete Order
↓
Verify final Order state
↓
Restart application
↓
Verify persisted data

Checklist:

- [ ] Workflow completed successfully.
- [ ] Database state is correct.
- [ ] UI state is correct.
- [ ] Navigation is correct.
- [ ] No unexpected errors occurred.
- [ ] Data survived application restart.

---

## 44. Regression Validation

After implementation changes:

- [ ] Existing Customer workflows still work.
- [ ] Existing Order workflows still work.
- [ ] Existing Storage workflows still work.
- [ ] Existing Expense workflows still work.
- [ ] Existing Dashboard behavior still works.
- [ ] Existing navigation still works.
- [ ] Existing database operations still work.
- [ ] Existing Cubit state transitions still work.

---

## 45. Final Documentation Cross-Check

Before declaring implementation complete, compare the code against:

- [ ] `scope.md`
- [ ] `requirements.md`
- [ ] `product-overview.md`
- [ ] `business-rules.md`
- [ ] `domain-model.md`
- [ ] `database-design.md`
- [ ] `architecture.md`
- [ ] `technical-decisions.md`
- [ ] `data-layer.md`
- [ ] `project-structure.md`
- [ ] `seed-data.md`
- [ ] `database-decisions.md`
- [ ] `indexes.md`
- [ ] `database-overview.md`
- [ ] `sync-strategy.md`
- [ ] `relationships.md`
- [ ] `constraints.md`
- [ ] `tables.md`
- [ ] `entities.md`
- [ ] `backend-api-overview.md`
- [ ] `design-system-overview.md`
- [ ] `customers.md`
- [ ] `navigation.md`
- [ ] `orders.md`
- [ ] `dashboard.md`
- [ ] `08-implementation/coding-standards.md`
- [ ] `08-implementation/implementation-overview.md`
- [ ] `08-implementation/implementation-plan.md`
- [ ] `08-implementation/architecture-guidelines.md`
- [ ] `08-implementation/data-layer-implementation.md`
- [ ] `08-implementation/database-implementation.md`
- [ ] `08-implementation/domain-implementation.md`
- [ ] `08-implementation/feature-implementation.md`
- [ ] `08-implementation/implementation-rules.md`
- [ ] `08-implementation/offline-first.md`
- [ ] `08-implementation/routing-and-navigation.md`
- [ ] `08-implementation/state-management.md`

All applicable documents must be consistent with the actual implementation.

---

## 46. Contradiction Check

Before final approval:

- [ ] No code contradicts documented business rules.
- [ ] No code contradicts database constraints.
- [ ] No code contradicts routing decisions.
- [ ] No code contradicts state-management decisions.
- [ ] No code contradicts Offline-First decisions.
- [ ] No code contradicts dependency-injection decisions.
- [ ] No code contradicts project structure.
- [ ] No code contradicts the approved V1 scope.

If a contradiction is discovered:

1. Stop implementation of the affected area.
2. Identify the source of truth.
3. Resolve the documentation/implementation mismatch.
4. Update the affected documentation if the decision intentionally changed.
5. Re-run the relevant validation checks.

Do not silently choose a new architecture during implementation.

---

## 47. Implementation Rules Validation

- [ ] Implementation follows `implementation-rules.md`.
- [ ] No coding-agent rule was bypassed.
- [ ] No undocumented architecture was invented.
- [ ] No shortcut was taken that violates layer boundaries.
- [ ] No future-phase feature was introduced prematurely.
- [ ] Existing decisions were reused instead of recreated.

---

## 48. Final V1 Gate

The V1 implementation can be considered ready only when:

- [ ] Architecture passes.
- [ ] Database passes.
- [ ] Data Layer passes.
- [ ] Domain passes.
- [ ] Feature implementation passes.
- [ ] State management passes.
- [ ] Routing passes.
- [ ] Offline-first validation passes.
- [ ] Business workflow validation passes.
- [ ] UI/RTL validation passes.
- [ ] Tests pass.
- [ ] Build passes.
- [ ] No critical regression exists.
- [ ] No critical architecture violation exists.
- [ ] No unresolved critical business-rule violation exists.

---

## 49. Severity Levels

Issues found during validation should be classified as:

### Critical

Blocks V1 completion.

Examples:

- Database corruption risk.
- Incorrect financial calculation.
- Broken order lifecycle.
- Critical data loss.
- Major architecture violation.
- Core workflow cannot be completed.

### High

Must be fixed before V1 completion.

Examples:

- Important feature does not work.
- Incorrect business rule.
- Broken navigation for a core workflow.
- Important persistence failure.
- Major RTL/UI issue affecting usability.

### Medium

Should be fixed before release when practical.

Examples:

- Non-critical UX issue.
- Minor state handling issue.
- Performance issue without functional impact.

### Low

Can be deferred if documented.

Examples:

- Minor visual inconsistency.
- Non-critical refactoring.
- Small developer-experience improvement.

---

## 50. Validation Result

At the end of the validation process, record:

### Overall Status

- PASS
- PASS WITH KNOWN ISSUES
- FAIL

### Critical Issues

List all unresolved Critical issues.

### High Issues

List all unresolved High issues.

### Medium Issues

List all unresolved Medium issues.

### Low Issues

List all unresolved Low issues.

### Deferred Items

List items intentionally deferred to a future phase.

---

## 51. Final Completion Report

The implementation validation report must explicitly contain:

### Architecture

State whether the implementation follows the approved architecture.

### Database

State whether the database implementation matches the documented design, constraints, relationships, and indexes.

### Data Layer

State whether Repository/Data Layer boundaries are respected.

### Domain

State whether business rules remain in the appropriate Domain/business layer.

### Features

List the implemented features and their validation status.

### State Management

Explicitly confirm:

**Cubit is used for application state management.**

Explicitly confirm:

**No BLoC/event-based architecture was introduced.**

### Dependency Injection

Explicitly confirm:

**GetIt is used according to the approved DI architecture.**

### Routing

Explicitly confirm:

**Routes are centralized and AppRouter is used.**

Explicitly confirm:

**Routes are not hardcoded throughout feature screens.**

### Offline-First

Explicitly confirm:

**V1 core workflows operate against the local data layer without requiring backend connectivity.**

### Backend/Sync

Explicitly confirm:

**Offline / Sync Integration (Task #15) is completed and locked. Synchronization infrastructure (Push + Pull + Realtime Wake-up Signal) is implemented and verified end-to-end across two independent devices. Local-First operation remains intact. Cubits and Widgets remain unaware of sync mechanics. Supabase is behind the approved remote boundary. Multi-tenant / SaaS features are not implemented.**

### Testing

List the tests executed and their results.

### Build

State whether the project builds successfully.

### Known Issues

List unresolved issues.

### Deferred Work

List intentionally deferred work.

### Final Status

State:

**PASS**

or:

**PASS WITH KNOWN ISSUES**

or:

**FAIL**

---

## 52. AI Coding Agent Final Rule

The coding agent must not declare the implementation complete merely because the code compiles.

Completion requires architectural, functional, persistence, state-management, navigation, Offline-First, and business-workflow validation.

If a required checklist item fails:

- Do not hide the failure.
- Do not mark it PASS.
- Do not silently change the architecture.
- Report the failure.
- Fix it if it is within the current scope.
- Otherwise document it explicitly as deferred or unresolved.

---

## 53. Final Definition of Done

The V1 implementation is considered validated only when:

1. The documented scope is respected.
2. Requirements are implemented.
3. Business rules are respected.
4. Architecture boundaries are respected.
5. Database design is respected.
6. Database constraints are enforced.
7. Repository boundaries are respected.
8. Domain responsibilities are respected.
9. Cubit-only state management is respected.
10. No BLoC architecture exists.
11. GetIt DI is correctly implemented.
12. Routes are centralized.
13. AppRouter is used.
14. Routes are not hardcoded throughout screens.
15. Offline-first local workflows work without backend connectivity.
16. Offline / Sync Integration implementation follows approved decisions.
17. Synchronization infrastructure is implemented in the Data / Infrastructure layer only.
18. Critical workflows work end-to-end.
19. Data survives application restart.
20. Transactions preserve data integrity.
21. Duplicate critical submissions are protected.
22. Arabic/RTL requirements are respected.
23. Design-system requirements are respected.
24. Tests pass.
25. Static analysis passes.
26. The application builds successfully.
27. No Critical architecture or business issue remains.
28. All known issues are documented.
29. All deferred work is documented.
30. The final completion report is provided.

---

## 54. Final Principle

Validation is not an opportunity to redesign the system.

The implementation must be judged against the approved documentation and decisions.

If the implementation and documentation disagree:

**Identify → Verify source of truth → Resolve explicitly → Update → Revalidate.**

Never silently invent a new rule during implementation.

---

## 55. Offline / Sync Integration Validation

> **Note**: This section covers requirements and completed validation for the Offline / Sync Integration implementation phase (Task #15, C1 through C4-C).

---

### 55.1 Local-First Operation

- [x] All approved V1 workflows remain fully functional without network access after sync infrastructure is added.
- [x] The UI continues to reflect successful local writes immediately, without waiting for remote acknowledgment.
- [x] Application startup does not require a network connection or remote backend availability.
- [x] Local database continues to operate as the primary operational source of truth.
- [x] Connectivity loss does not disable normal approved business operations.

---

### 55.2 Atomic Local Mutation + Sync Enqueue

- [x] For every synchronizable mutation, the local business change and its corresponding sync queue operation are created in the same database transaction.
- [x] If the local entity write fails, no orphaned sync operation is left in the queue.
- [x] If the sync queue insert fails, the local entity write is rolled back.
- [x] Partial states (business change without sync operation, or sync operation without business change) cannot exist after a failed transaction.

---

### 55.3 Stable Entity UUIDs

- [x] All synchronizable business entities use stable UUIDs.
- [x] The same entity UUID is used in both local storage and remote storage.
- [x] The Sync Engine does not replace a local entity UUID with a newly generated remote ID.
- [x] A retry does not generate a new entity UUID.

---

### 55.4 Stable Operation IDs

- [x] Every sync queue operation has a stable, unique operation ID.
- [x] The operation ID remains unchanged across retries.
- [x] A timeout does not cause the client to create a new logical operation ID.
- [x] All retry attempts for the same logical operation use the same operation ID.

---

### 55.5 Idempotent Retries

- [x] Retrying the same operation with the same operation ID does not create a duplicate business record remotely.
- [x] The backend (Supabase) recognizes repeated delivery of the same operation and processes it exactly once.
- [x] Idempotency is verified for: Customer creation, Order creation, Payment recording, Expense creation, Storage operations, and any other synchronizable mutation.

---

### 55.6 Retryable vs Permanent Failures

- [x] The Sync Engine distinguishes between retryable failures (connectivity, timeout, temporary server error) and permanent failures (invalid data, unsupported operation, permanent conflict).
- [x] Retryable failures are retried according to the approved exponential backoff strategy.
- [x] Permanent failures are not retried indefinitely.
- [x] Permanent failures remain identifiable and do not silently disappear.
- [x] Retryable failures do not block or corrupt permanently failed operations.

---

### 55.7 Interrupted Sync Recovery

- [x] If the application is terminated while an operation is in the Processing state, the next sync run can identify and recover it.
- [x] Interrupted operations do not remain permanently locked in the Processing state.
- [x] Recovery preserves idempotency: recovering a previously sent operation does not duplicate a backend record.
- [x] Crash recovery is verified by testing application restart during active sync.

---

### 55.8 Dependency-Aware Ordering

- [x] Synchronization ordering respects entity dependencies.
- [x] A Customer sync operation is processed before dependent Order operations when the backend requires that relationship.
- [x] An Order sync operation is processed before dependent OrderItem, Payment, and StorageRecord operations when required.
- [x] The Sync Engine does not process a child operation before its parent entity is confirmed remotely.

---

### 55.9 Conflict Handling

- [x] Conflict resolution strategy is defined at the entity / business-rule level.
- [x] Conflict resolution is deterministic (same inputs produce same output).
- [x] Generic last-write-wins is not used as a universal strategy.
- [x] Conflict handling is not delegated to UI behavior.
- [x] Conflicts that cannot be automatically resolved are identified explicitly and do not silently corrupt data.

---

### 55.10 Financial Record Protection

- [x] Payment records are never silently overwritten, duplicated, or lost during synchronization.
- [x] Expense records are never silently overwritten, duplicated, or lost during synchronization.
- [x] Financial values preserve integer minor-unit representation (no floating-point conversion introduced by sync).
- [x] Synchronization does not recalculate or alter historical order totals.
- [x] Financial data is auditable after synchronization.

---

### 55.11 Remote Changes Do Not Produce Outgoing Sync Operations

- [x] When the Sync Engine applies a remote change to local storage (e.g., incoming data from the backend), this does not create an outgoing sync operation that re-sends the data back to the backend.
- [x] Read-path and incoming data paths are clearly separated from the outgoing sync queue path.

---

### 55.12 Sync State Separate from Business State

- [x] Sync queue state (Pending, Processing, Synced, Failed) does not appear in business entity state.
- [x] Order statuses remain exactly: Processing, Ready, Completed, Cancelled.
- [x] No additional business status (PendingSync, Syncing, SyncFailed, etc.) was introduced.
- [x] Sync status is represented only in the sync queue layer, not in domain entities.

---

### 55.13 Cubits Free from Sync Engine Logic

- [x] No Feature Cubit contains sync queue management logic.
- [x] No Feature Cubit manages retries or retry scheduling.
- [x] No Feature Cubit directly interacts with the Sync Engine.
- [x] No Feature Cubit monitors connectivity for the purpose of triggering synchronization.
- [x] No Feature Cubit resolves conflicts.

---

### 55.14 Widgets Free from Sync Execution Logic

- [x] No Widget directly calls the Sync Engine.
- [x] No Widget directly manages the sync queue.
- [x] No Widget triggers retry processing.
- [x] Optional user-facing sync status indicators (if present) are driven only through the approved repository / application boundary, not through direct Sync Engine or DAO calls inside widgets.

---

### 55.15 Supabase Behind Approved Remote/Data Boundary

- [x] Feature-level Cubits do not directly call Supabase.
- [x] Feature-level Widgets do not directly call Supabase.
- [x] Supabase is accessed only through the Remote Data Source layer.
- [x] Supabase connection details do not appear in Domain or Presentation layers.
- [x] A second network client was not introduced; the approved Dio + Retrofit infrastructure is used.

---

### 55.16 Offline Operation Without Network

- [x] After sync infrastructure is added, all pre-existing offline validation tests still pass.
- [x] Application can start without any network access.
- [x] Customers can be created without network access.
- [x] Orders can be created without network access.
- [x] Payments can be recorded without network access.
- [x] Storage operations work without network access.
- [x] Expenses can be created without network access.
- [x] Dashboard loads from local data without network access.
- [x] Reports load from local data without network access.
- [x] Sync queue accumulates operations locally when offline and processes them when connectivity is restored.

---

### 55.17 Future SaaS Readiness Without Implementing SaaS Features

- [x] The architecture uses stable entity UUIDs suitable for future multi-device or multi-tenant scenarios.
- [x] No tenant ID, branch ID, user ID, or role system was introduced in this phase.
- [x] No multi-tenant UI was introduced in this phase.
- [x] No subscription management was introduced in this phase.
- [x] The synchronization boundary (Sync Engine behind Remote Data Source) is structured so that future multi-tenant backend support can be added without rewriting Presentation or Domain layers.

---

### 55.18 Step 10 — Payment Remote Synchronization Validation

- [x] Payment payload is generated locally via `SyncPayloadBuilder.buildPaymentPayload()`.
- [x] Payment sync operation is enqueued with a non-null, self-contained JSON payload.
- [x] Local payment insertion and sync enqueue are atomic within a single Drift transaction.
- [x] Failed sync enqueue rolls back local payment insertion.
- [x] Remote Supabase `payments` table created with RLS and default-deny security.
- [x] Remote `orders` table includes `paid_amount` column.
- [x] PostgreSQL RPC `sync_create_payment` is transactional and protects against concurrency race conditions via `FOR UPDATE`.
- [x] Payment creation is idempotent; duplicate `X-Operation-ID` replays return cached payload without duplicate increment of `orders.paid_amount`.
- [x] Overpayment beyond remaining order balance is rejected with `HTTP 409 CONFLICT`.
- [x] Payments on cancelled orders are rejected with `HTTP 409 CONFLICT`.
- [x] Payments with zero or negative amounts are rejected with `HTTP 422 VALIDATION_ERROR`.
- [x] Payments with invalid payment methods are rejected with `HTTP 422 VALIDATION_ERROR`.
- [x] Missing orders return `HTTP 404 NOT_FOUND`.
- [x] Payments remain immutable in V1; PATCH/PUT/DELETE return `HTTP 404 NOT_FOUND`.
- [x] Retrofit client and RemoteApiDispatcher are verified against `/api/v1/payments`.
- [x] Live Supabase backend integration test suite (`step10_live_payment_integration_test.dart`) passes 100%.

---

### 55.19 Step 11 — Expense & Expense Category Remote Synchronization Validation

- [x] Expense payload generated locally via `SyncPayloadBuilder.buildExpensePayload()`.
- [x] Expense update payload generated locally via `SyncPayloadBuilder.buildExpenseUpdatePayload()`.
- [x] Expense Category payload generated locally via `SyncPayloadBuilder.buildExpenseCategoryPayload()`.
- [x] Expense Category update payload generated locally via `SyncPayloadBuilder.buildExpenseCategoryUpdatePayload()`.
- [x] Expense Category status payload generated locally via `SyncPayloadBuilder.buildExpenseCategoryStatusPayload()`.
- [x] Expense amount represented in integer minor units (piastres / `BIGINT`). Floating-point money prohibited.
- [x] `expense_date` serialized as date-only `YYYY-MM-DD` without timezone distortion.
- [x] Expense creation and update enqueued with non-null, validated JSON payloads.
- [x] Expense Category creation, update, activation, and deactivation enqueued with non-null JSON payloads.
- [x] Local expense and category mutations + sync queue enqueues are atomic within single Drift transactions.
- [x] Failed sync enqueue rolls back local database mutations.
- [x] Remote Supabase `expense_categories` and `expenses` tables deployed with RLS and default-deny policies.
- [x] Normalized unique index `idx_expense_categories_name_lower` (`LOWER(TRIM(name))`) prevents duplicate category names.
- [x] Foreign key constraint `expenses.expense_category_id -> expense_categories.id` enforced with `ON DELETE RESTRICT`.
- [x] Amount constraint `amount > 0` enforced on database level.
- [x] Indexes `idx_expenses_category_date` and `idx_expenses_date` created and active.
- [x] PostgreSQL RPCs `sync_create_expense_category`, `sync_update_expense_category`, `sync_create_expense`, `sync_update_expense` deployed with `SECURITY DEFINER` and ACID transactions.
- [x] RPCs enforce idempotency via `sync_idempotency_log` using `p_op_id`.
- [x] Replaying operations with identical `X-Operation-ID` returns cached response without duplicate mutations.
- [x] Custom name validation for category "أخرى" enforced (empty name rejected with `HTTP 422 VALIDATION_ERROR`).
- [x] Edge Function routes `/expense-categories` and `/expenses` deployed and operational.
- [x] Physical deletion prohibited (DELETE returns `HTTP 404 NOT_FOUND`).
- [x] Filtering by category ID, date ranges (`start_date`, `end_date`), pagination, and sorting verified.
- [x] Unit test suite (`sync_payload_builder_test.dart`) passes 100%.
- [x] Repository test suite (`expense_repository_impl_test.dart`) passes 100%.
- [x] Live Supabase integration test suite (`step11_live_expense_integration_test.dart`) passes 100% (15/15).
- [x] Regression test suite (`step10_live_payment_integration_test.dart`) passes 100% (13/13).

---

### 55.20 Step 12 — Master Data & Settings Remote Synchronization Validation

- [x] ItemType payload generated locally via `SyncPayloadBuilder.buildItemTypePayload()`, `buildItemTypeUpdatePayload()`, and `buildItemTypeStatusPayload()`.
- [x] ItemDefinition payload generated locally via `SyncPayloadBuilder.buildItemDefinitionPayload()` and `buildItemDefinitionUpdatePayload()`.
- [x] CarpetSize payload generated locally via `SyncPayloadBuilder.buildCarpetSizePayload()` and `buildCarpetSizeUpdatePayload()`.
- [x] StorageLocation payload generated locally via `SyncPayloadBuilder.buildStorageLocationPayload()` and `buildStorageLocationUpdatePayload()`, including `supported_item_type_ids`.
- [x] BusinessSettings payload generated locally via `SyncPayloadBuilder.buildBusinessSettingsPayload()`.
- [x] Local mutations in `ItemTypeRepositoryImpl`, `ItemDefinitionRepositoryImpl`, `CarpetSizeRepositoryImpl`, `StorageLocationRepositoryImpl`, and `SettingsRepositoryImpl` enqueue self-contained non-null JSON sync payloads atomically within Drift transactions.
- [x] Failed sync enqueue rolls back local database mutations.
- [x] Remote Supabase migration `20260916000004_master_data_schema.sql` applied successfully.
- [x] Remote tables `item_types`, `item_definitions`, `carpet_sizes`, `storage_locations`, `storage_location_item_types`, and `business_settings` created with RLS and default-deny policies.
- [x] Unique constraints enforced: `item_types(name)`, `item_definitions(item_type_id, name)`, `carpet_sizes(length, width)`, `storage_locations(name)`.
- [x] Foreign key constraints enforced: `item_definitions.item_type_id -> item_types.id`, `storage_location_item_types -> storage_locations.id, item_types.id`.
- [x] Check constraints enforced: `carpet_sizes` dimensions > 0, `item_definitions` default_price >= 0, `business_settings.tax_rate >= 0 AND <= 1`.
- [x] 9 PostgreSQL RPCs deployed with `SECURITY DEFINER` and ACID transactions with idempotency logging in `sync_idempotency_log`.
- [x] Replaying operations with identical `X-Operation-ID` returns cached response without duplicate mutations.
- [x] Edge Function `api` routes `/item-types`, `/item-definitions`, `/carpet-sizes`, `/storage-locations`, `/business-settings` deployed (version 5) and operational.
- [x] Physical deletion prohibited across all master data and settings (DELETE returns `HTTP 404 NOT_FOUND`).
- [x] Unit test suite (`sync_payload_builder_test.dart`) passes 100% (12/12).
- [x] Live Supabase master data integration test suite (`step12_live_master_data_integration_test.dart`) passes 100% (31/31).
- [x] Step 10 live payment regression suite (`step10_live_payment_integration_test.dart`) passes 100% (13/13).
- [x] Step 11 live expense regression suite (`step11_live_expense_integration_test.dart`) passes 100% (15/15).
- [x] Full Flutter test suite passes 100% (731/731).
- [x] `flutter analyze` reports 0 issues.
- [x] `git diff --check` is clean.

---

### 55.21 Task #12 — Dashboard & Daily Overview Operational Implementation Validation

- [x] Operational overview metrics: all 7 metrics computed via database-side aggregation without full-table memory scans:
  - `todayOrdersCount`: orders created today within local calendar boundaries `00:00:00.000` to `23:59:59.999`.
  - `readyOrdersCount`: active orders in `OrderStatus.ready`.
  - `processingOrdersCount`: active orders in `OrderStatus.processing`.
  - `itemsRequiringStorageCount`: items of active orders (`processing` or `ready`) without active `StorageRecord`.
  - `totalRemaining`: remaining balance in minor units (piastres) on non-cancelled orders (`total - paid > 0`).
  - `unpaidOrdersCount`: count of non-cancelled orders with positive remaining balance.
  - `overdueOrdersCount`: active orders (`status != completed AND status != cancelled`) with `expectedPickupDate < today`.
  - `todayPickupOrdersCount`: active orders with `expectedPickupDate == today`.
- [x] Order lists:
  - `todayPickupOrders`: up to 5 active orders scheduled for pickup today, sorted by pickup date ascending.
  - `recentOrders`: up to 5 latest orders created, sorted by `createdAt` descending, enriched with `PaymentSummary` calculations.
- [x] Date handling and boundary enforcement:
  - Today start (`00:00:00.000`) and end (`23:59:59.999`) strictly tested across midnight boundaries.
  - `OrderDate.today()` serialized to `DateTime.utc(year, month, day)` matching Drift `expected_pickup_date` column format.
  - Overdue vs due today vs tomorrow boundary separation strictly validated.
  - Completed and cancelled orders strictly excluded from attention cards and pickup lists.
- [x] Outstanding payment semantics:
  - Reuses existing payment calculation rules (`total - paid`).
  - Fully paid orders (`remaining == 0`) excluded from outstanding lists and counts.
  - Cancelled orders excluded from outstanding totals.
- [x] Storage attention semantics:
  - Uses existing `StorageRepository.countItemsRequiringStorage()` based on `orders_items` without active `storage_records`.
- [x] Reactive stream (`DashboardRepository.watchDashboardData()`):
  - Listens to Drift `db.tableUpdates()` for `orders`, `payments`, `storage_records`, and `order_items`.
  - Emits initial snapshot immediately on listen, then re-evaluates database-side aggregation on any mutation.
  - No polling loops.
  - Zero pending timers on stream cancellation or widget unmount.
  - Subscription lifecycle correctly managed and disposed in `DashboardCubit.close()`.
- [x] Quick Actions:
  - "إضافة طلب": navigates to `/orders/new` and refreshes upon return.
  - "إضافة عميل": opens `CustomerFormDialog` with duplicate handling and `onViewExisting` detail navigation.
  - "تسجيل دفعة": opens two-step `RecordPaymentDialog` with live order search, Arabic numerals support, balance validation, and instant payment recording.
  - "إضافة مصروف": opens `AddExpenseDialog` with category selection and expense recording.
- [x] RTL & Design System:
  - Arabic RTL directionality strictly enforced.
  - Typography, colors, card layouts, and badges adhere strictly to Design System tokens.
  - Responsive single-column mobile layout and two-column tablet/desktop layout.
- [x] Test verification:
  - `test/data/repositories/dashboard_repository_impl_test.dart`: 7/7 passing (boundaries, exclusions, aggregations, reactivity).
  - `test/features/dashboard/presentation/cubit/dashboard_cubit_test.dart`: 4/4 passing (lifecycle, loading, success, error, refresh).
  - `test/features/dashboard/presentation/screens/dashboard_screen_test.dart`: 6/6 passing (rendering, quick actions, dialogs, empty states).
  - `test/features/dashboard/presentation/cubit/record_payment_cubit_test.dart`: 13/13 passing (search normalization, balance validation, payment).
  - `test/features/dashboard/presentation/widgets/record_payment_dialog_test.dart`: 5/5 passing (two-step dialog interactions, filters).
  - `test/widget_test.dart`: 4/4 passing (app bootstrap, sidebar navigation, responsive layout).
  - Full Flutter test suite: 735/735 passing (100%).
  - `flutter analyze`: 0 issues found.
  - `git diff --check`: clean (0 trailing whitespace or format issues).

---

### 55.22 Task #15 — Two-Device Bidirectional Synchronization Validation (C1–C4-C)

- [x] Bidirectional Push + Pull synchronization implemented and operational across two independent devices.
- [x] Two independent local SQLite/Drift databases (Device A and Device B) operating concurrently against the shared live Supabase backend.
- [x] Independent local sync cursors maintained in `sync_state` (`last_applied_sequence`) for each device.
- [x] Independent local `SyncOperation` queues (`sync_operations`) maintained per device.
- [x] Ephemeral Realtime wake-up signal (`laundry:sync` / `sync_available`) received by adapter and triggers `SyncEngine.pull()`.
- [x] Authoritative data retrieval strictly via cursor-based Pull API (`GET /api/v1/sync/changes?after=<sequence>&limit=<limit>`), NOT from Realtime payloads.
- [x] Zero remote-apply echo: `RemoteChangeApplier` writes directly to Drift DAOs without enqueueing outgoing `SyncOperation` records.
- [x] Order aggregate synchronization: initial order creation creates an aggregate change in `sync_changes` containing Order header, all OrderItems, and Carpet data, ensuring complete relational integrity on pull.
- [x] Payment synchronization: append-oriented, idempotent financial transaction applied cleanly on remote device without duplicate balance manipulation.
- [x] Storage synchronization: physical storage state applied cleanly, maintaining invariant of at most one active `StorageRecord` per `OrderItem`, with competing moves rejected via server concurrency checks.
- [x] Strict sequence semantics: `RemoteChangeApplier` strictly validates sequence monotonicity (`change.sequence == expectedSequence`) and rejects out-of-order or duplicate sequences.
- [x] Transactional remote apply: applying remote change batch and advancing local cursor (`sync_state.last_applied_sequence`) execute within ONE atomic local SQLite transaction.
- [x] Rollback safety: simulated failures during batch application roll back all entity mutations and leave cursor unadvanced.
- [x] Replay safety: crash before cursor advance safely allows re-pulling and re-applying uncommitted changes without data corruption.
- [x] Single-flight coalescing: `SyncEngine` collapses overlapping triggers into a single active sync loop.
- [x] Test verification:
  - Dedicated C4-C Two-Device Bidirectional Sync Test (`test/data/sync/two_device_bidirectional_sync_integration_test.dart`): 1/1 passed (1 test passed).
  - Step 13 SyncEngine Integration Suite (`test/data/sync/step13_sync_engine_integration_test.dart`): 4/4 passed (4 tests passed).
  - Step 9 Live Supabase Integration Suite (`test/data/sync/step9_live_supabase_integration_test.dart`): 14/14 passed (14 tests passed).
  - Master Live Supabase Integration Suite (`test/data/sync/live_supabase_integration_suite_test.dart`): 78/78 passed (78 tests passed).
  - SyncEngine Unit Tests (`test/data/sync/sync_engine_test.dart`): 28/28 passed (28 tests passed).
  - RemoteChangeApplier Unit Tests (`test/data/sync/remote_change_applier_test.dart`): 14/14 passed (14 tests passed).
  - Static Analysis (`flutter analyze`): 0 issues.