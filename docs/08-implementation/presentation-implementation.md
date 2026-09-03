# Presentation Implementation

## 1. Purpose

This document defines the implementation rules for the Presentation Layer of the Laundry Management System.

It translates the approved architecture, project structure, coding standards, data-layer implementation, and UI decisions into concrete implementation rules for Flutter.

The purpose is to ensure that implementation follows the existing project architecture exactly and that coding tools do not introduce alternative patterns, unnecessary abstractions, or architectural layers.

This document covers:

- Screens
- Widgets
- Cubits
- States
- User interactions
- Forms
- Validation
- Loading states
- Empty states
- Error states
- Search and filtering
- Pagination
- Dialogs and sheets
- Navigation interaction
- Arabic and RTL behavior
- Design System usage
- Presentation testing
- Boundaries between Presentation and lower layers

This document does not redefine the domain model, database schema, business rules, or backend architecture.

Those responsibilities remain in their respective documentation.

---

## 2. Approved Presentation Architecture

The Presentation Layer follows this flow:

Screen → Cubit → Repository → Data Layer

The Presentation Layer must not communicate directly with the database or data source.

### 2.1 Screen

The Screen is responsible for:

- Building the UI
- Reading Cubit state
- Dispatching user actions to the Cubit
- Displaying loading, empty, success, and error states
- Triggering navigation actions where appropriate
- Composing reusable widgets

The Screen must not:

- Query the database directly
- Call Drift DAOs directly
- Execute SQL
- Contain repository implementations
- Contain persistence logic
- Implement business rules that belong to the domain/data layers
- Perform networking
- Manage synchronization

### 2.2 Cubit

Cubit is the approved state-management solution for the project.

The default presentation flow is:

Screen → Cubit → Repository

Cubit is responsible for:

- Managing presentation state
- Receiving user actions
- Calling repository methods
- Exposing results to the UI
- Managing loading state
- Managing empty state
- Managing error state
- Managing form state when required
- Managing screen-level filters and search state
- Managing pagination state when required
- Coordinating presentation-level workflows

Cubit must not:

- Access the database directly
- Access Drift directly
- Execute SQL
- Contain UI widgets
- Contain Flutter layout code
- Become a replacement for the Repository
- Duplicate database logic
- Implement infrastructure concerns

### 2.3 Repository

The Repository remains the abstraction between Presentation and Data.

Presentation code must depend on repository contracts rather than concrete data-source implementations.

The exact repository responsibilities are defined by the Data Layer documentation.

---

## 3. State Management Decision

### 3.1 Cubit Only

The project will use Cubit as the state-management mechanism.

Bloc is not part of the current implementation architecture.

Do not introduce Bloc for new features.

Do not convert a Cubit to Bloc simply because a screen has multiple actions.

Cubit should remain the default even when a screen has several independent user interactions, as long as the resulting implementation remains clear and maintainable.

### 3.2 Future Bloc Usage

If a future feature appears to require Bloc specifically, this must be treated as a new architectural decision.

The developer or coding agent must not introduce Bloc autonomously.

The decision must first be reviewed and documented.

Until such a decision exists:

Use Cubit.

---

## 4. Feature Presentation Structure

Presentation code should follow the approved project structure.

A typical feature should follow the established structure rather than creating a new architectural hierarchy.

Example:

lib/
  features/
    orders/
      presentation/
        pages/
        widgets/
        cubit/

The exact directory naming should follow the project's existing `project-structure.md`.

Do not introduce:

- use_cases/
- interactors/
- presenters/
- view_models/
- controllers/
- services/

unless explicitly approved by the project architecture.

The project intentionally avoids unnecessary architectural layers.

---

## 5. Cubit Responsibilities

A Cubit should represent the state and interactions of a meaningful presentation unit.

Examples:

- OrdersCubit
- CustomersCubit
- InventoryCubit
- DashboardCubit

A Cubit should not automatically represent an entire application area if that causes it to become unnecessarily large.

### 5.1 Good Cubit Responsibilities

A Cubit may handle:

- Loading orders
- Applying order filters
- Searching orders
- Selecting an order
- Creating an order
- Updating an order
- Loading customers
- Searching customers
- Managing a form
- Handling pagination
- Refreshing data

### 5.2 Avoid Large Cubits

Do not create a single Cubit that manages unrelated screens and workflows.

For example, avoid:

AppCubit

containing:

- Customers
- Orders
- Inventory
- Settings
- Dashboard
- Authentication
- Reports

Instead, keep state ownership close to the feature or presentation workflow that needs it.

---

## 6. State Design

Cubit states should be explicit and predictable.

The UI must be able to determine the current presentation condition without guessing.

At minimum, screens that load asynchronous data should be able to represent:

- Initial
- Loading
- Success
- Empty
- Error

The exact state implementation may use:

- A sealed-state style
- Equatable state classes
- A state object with a status field

The chosen implementation must remain consistent with the project's coding standards.

Do not mix multiple state patterns unnecessarily.

---

## 7. Loading State

Loading states must be intentional.

### 7.1 Initial Loading

When a screen initially loads data:

- Display the approved loading UI
- Prevent invalid duplicate actions when necessary
- Preserve the expected screen structure where appropriate

### 7.2 Refresh Loading

Refreshing existing content should not unnecessarily destroy useful content.

If appropriate:

- Keep the current content visible
- Show a refresh/loading indicator
- Replace the content only after the refresh completes

### 7.3 Action Loading

For operations such as:

- Save
- Update
- Delete
- Confirm
- Submit

the UI should communicate that the operation is in progress.

Prevent duplicate submissions.

Example:

Save button becomes disabled while the save operation is executing.

---

## 8. Empty States

Empty data is not an error.

The UI must distinguish between:

- Successful request with no records
- Failed request
- Loading request

Empty states should provide useful context.

Examples:

No orders yet.

No customers match the current search.

No inventory items match the selected filters.

Where appropriate, the empty state should provide a relevant action such as:

- Add customer
- Create order
- Clear filters
- Add inventory item

Do not display generic error messaging for a valid empty result.

---

## 9. Error States

Errors must be represented explicitly.

The UI should provide:

- Clear Arabic error messaging
- Appropriate retry action where retry is meaningful
- Preservation of user-entered data where possible
- No exposure of low-level database or technical error details to normal users

Technical details may be logged for debugging, but the presentation message should remain user-friendly.

Do not silently ignore repository failures.

Do not show a success state when the underlying operation failed.

---

## 10. Form Implementation

Forms must keep presentation state separate from persistence.

A form may contain:

- Text fields
- Dropdowns
- Search fields
- Numeric fields
- Date fields
- Selection controls
- Checkboxes
- Toggles

Form state should be managed deliberately.

### 10.1 Form Validation

Validation should happen before submitting invalid data.

Validation should provide:

- Clear feedback
- Arabic messages
- Field-level errors where appropriate
- Prevention of invalid submission

Validation must not duplicate complex domain/business rules unnecessarily.

The presentation layer may perform user-input validation.

Business rules remain governed by the approved business/domain architecture.

### 10.2 Preserve Input

If an operation fails:

- Do not unnecessarily clear the form
- Preserve user-entered values
- Allow the user to correct and retry

### 10.3 Submit Protection

While a submit operation is in progress:

- Prevent duplicate submissions
- Keep the UI responsive
- Clearly communicate progress

---

## 11. Search

Search behavior must be consistent across features.

Search belongs to the presentation workflow when it represents UI state and user interaction.

Example:

User enters search text.

Cubit updates search state.

Cubit requests the appropriate repository operation.

The Screen displays the result.

Do not make the Screen itself responsible for coordinating asynchronous search logic.

### 11.1 Search Input

Search fields should:

- Use the approved design-system component
- Support Arabic text correctly
- Preserve RTL behavior
- Provide clear affordances
- Avoid unnecessary requests for every keystroke when inappropriate

If debouncing is required, it should be implemented in the Cubit/presentation logic rather than inside reusable visual widgets.

---

## 12. Filtering

Filters are presentation state.

Examples:

- Order status
- Customer
- Date range
- Payment status
- Inventory location
- Category

The Cubit should own active filter state when the filter affects the screen's data.

Filters should be:

- Explicit
- Resettable
- Represented clearly in the UI
- Consistent with the feature's repository capabilities

A filter operation must not directly manipulate database queries from the Screen.

---

## 13. Pagination

Pagination must be handled by the presentation/data interaction rather than by UI widgets alone.

The Cubit should track relevant pagination state such as:

- Current page or cursor
- Loading-more state
- Whether more records exist
- Current filters/search
- Existing loaded records

The UI should request additional data when appropriate.

Do not:

- Duplicate records
- Reset existing data accidentally
- Trigger unlimited concurrent pagination requests
- Lose the current filter/search state when loading more

When a new search or filter is applied, pagination should reset appropriately.

---

## 14. Refresh

Screens that support refresh should use a consistent refresh mechanism.

Refreshing should:

1. Request current data again.
2. Preserve applicable search/filter state.
3. Update the Cubit state.
4. Display refreshed data.
5. Surface errors appropriately.

Refresh must not bypass the Repository.

---

## 15. Dialogs

Dialogs are presentation components.

They should be used for:

- Confirmation
- Short focused forms
- Important warnings
- Small contextual actions

Examples:

Delete confirmation.

Cancel order confirmation.

Confirm payment.

Dialog widgets should not:

- Access repositories directly
- Access the database
- Execute business operations themselves

The dialog communicates the user's decision back to the Screen/Cubit workflow.

---

## 16. Bottom Sheets

Bottom sheets may be used for:

- Filters
- Contextual actions
- Compact selection workflows
- Mobile-friendly interactions

The same architectural boundaries apply.

Bottom sheets must not access the database directly.

If a bottom sheet changes state, the resulting action should flow through the appropriate Cubit.

---

## 17. Navigation

Navigation must remain consistent with the project's approved navigation structure.

Presentation code may trigger navigation.

Navigation must not be mixed with:

- Database operations
- Repository implementations
- Infrastructure logic

After successful operations, navigation may occur when required by the feature flow.

Example:

Create Order → successful save → navigate to Order Details.

The navigation decision belongs to the presentation workflow, while persistence remains in the Repository/Data Layer.

---

## 18. Arabic and RTL Requirements

The application is Arabic-first.

All presentation implementation must support Arabic and RTL correctly.

### 18.1 Text Direction

Screens must work correctly with:

- Arabic text
- Arabic numerals where applicable
- Mixed Arabic/English text
- Customer names
- Order identifiers
- Phone numbers
- Dates
- Numeric values

Do not hardcode left/right assumptions where directional layout is required.

Prefer directional Flutter APIs and layout concepts.

Examples include:

- start / end
- AlignmentDirectional
- EdgeInsetsDirectional

instead of unnecessary:

- left / right

### 18.2 Text

User-facing strings must follow the project's localization strategy.

Do not scatter arbitrary Arabic strings throughout the code if the project has an established localization mechanism.

Do not introduce English UI text simply because the developer or generated code defaults to English.

### 18.3 Mixed Content

Some values may naturally contain Latin characters or numbers.

Examples:

- Order IDs
- Phone numbers
- Reference codes

These values must remain readable within the Arabic RTL interface.

Do not reverse or corrupt identifiers because of incorrect directional handling.

---

## 19. Design System Usage

Presentation implementation must use the approved Design System.

Do not recreate visual components unnecessarily.

Prefer existing:

- Buttons
- Inputs
- Cards
- Tables
- Chips
- Dialogs
- App bars
- Navigation components
- Typography
- Spacing
- Colors
- Icons

If a required component does not exist, create a reusable component when the pattern is genuinely reusable.

Do not create one-off variants for every screen.

The implementation must remain visually consistent with the approved Figma design.

---

## 20. Responsive Behavior

Screens must respect the application's approved responsive behavior.

Do not assume a single fixed viewport size.

Layouts should adapt according to the project's supported device/desktop patterns.

However, responsiveness must not be invented independently of the approved design.

If a Figma screen defines a particular responsive behavior, implementation should follow that behavior.

---

## 21. Tables and Dense Data

Laundry management screens may contain dense operational information.

Examples:

- Orders
- Order items
- Customers
- Inventory
- Payments
- Reports

Dense data must remain:

- Readable
- Scannable
- Consistent
- RTL-compatible
- Responsive to the supported layout

Do not sacrifice usability simply to fit more columns.

Where appropriate, use:

- Horizontal scrolling
- Responsive columns
- Detail views
- Expandable rows
- Mobile-specific presentation

according to the approved UI design.

---

## 22. Reusable Widgets

Reusable widgets should be created when they represent a meaningful repeated UI pattern.

Good candidates include:

- Order status badge
- Customer summary
- Item row
- Price display
- Empty-state widget
- Error-state widget
- Loading-state widget
- Search field
- Filter control
- Confirmation dialog

Avoid excessive abstraction.

Do not create a widget solely because a block of code appears twice unless the abstraction improves clarity or consistency.

---

## 23. Widget Responsibilities

Widgets should primarily be responsible for rendering and local interaction.

A reusable widget should not unexpectedly:

- Query repositories
- Access the database
- Create its own global state
- Perform unrelated navigation
- Execute business workflows

When a widget needs external state, pass the required state or callbacks through the approved presentation architecture.

---

## 24. Side Effects

Side effects must be controlled.

Examples:

- Navigation
- Showing SnackBars
- Showing dialogs
- Triggering refresh
- Starting another workflow

These should not be triggered repeatedly because a Cubit state is rebuilt.

Avoid putting side effects in places where they may execute every build.

Use appropriate state-listening mechanisms when necessary.

The UI should distinguish between:

- Rendering state
- Reacting to a state transition

---

## 25. Performance

Presentation code should avoid unnecessary work.

Avoid:

- Heavy computation inside `build()`
- Recreating expensive objects unnecessarily
- Rebuilding large widget trees without need
- Excessive listeners
- Unbounded lists without appropriate pagination

Cubit state updates should be intentional.

Do not emit identical states unnecessarily if the chosen state-management implementation can avoid it.

---

## 26. Offline-First Presentation Behavior

The application is designed around offline-first operation.

Presentation code must not assume that the network is always available.

Screens should primarily consume the local application state through repositories.

The UI should remain useful when:

- Internet is unavailable
- Data has not synchronized yet
- Changes are queued for synchronization

Backend synchronization remains a separate concern and is not part of the current local implementation phase.

Do not add network-dependent presentation behavior unless explicitly required by the current implementation scope.

---

## 27. Sync-Aware UI

When synchronization-related information is eventually exposed to users, it must be represented through approved presentation state.

Examples may include:

- Pending sync
- Synced
- Sync failed
- Last synchronization time

However, synchronization UI should not be implemented prematurely if the corresponding backend/sync implementation is deferred.

The current local implementation must remain functional without backend synchronization.

---

## 28. Delete and Destructive Actions

Destructive actions must require appropriate confirmation when defined by the UX/business rules.

Examples:

- Delete customer
- Delete inventory item
- Cancel order
- Remove order item

The UI should clearly communicate:

- What will happen
- Which entity is affected
- Whether the operation can be undone

After confirmation:

Screen/Cubit → Repository

Never:

Screen → Database

---

## 29. Success Feedback

Successful user actions should provide appropriate feedback.

Examples:

- Customer created
- Order saved
- Payment recorded
- Item added

Feedback may be:

- Navigation
- SnackBar
- Inline success state
- Updated list
- Dialog closure

Avoid unnecessary duplicate feedback.

For example, do not show a success SnackBar and a success dialog and navigate simultaneously unless explicitly required by the UX.

---

## 30. Presentation Error Recovery

Whenever practical, errors should be recoverable.

Examples:

- Retry loading
- Retry saving
- Correct invalid input
- Clear filter
- Refresh local data

The UI should not leave the user in a dead-end state after recoverable failures.

---

## 31. Testing Requirements

Presentation logic must be testable independently from widgets where possible.

### 31.1 Cubit Tests

Cubit tests should cover important state transitions.

Examples:

Initial → Loading → Success

Initial → Loading → Empty

Initial → Loading → Error

Success → Refresh → Success

Form → Validation Error

Form → Submit → Success

Form → Submit → Error

Pagination → Loading More → Success

Pagination → Loading More → End

### 31.2 Widget Tests

Important widgets/screens should be tested for:

- Rendering expected states
- User interaction
- Validation feedback
- Button enabled/disabled behavior
- Empty state
- Error state
- Loading state
- RTL behavior where important

### 31.3 Integration Tests

Integration tests should be added where a complete workflow is business-critical.

Examples:

Create customer.

Create order.

Add order items.

Process payment.

Complete an operational workflow.

The exact integration-test scope should follow the implementation plan.

---

## 32. Dependency Injection

Presentation classes should receive their dependencies through the project's approved dependency-injection mechanism.

The project has selected `get_it` for dependency injection.

Cubits should not manually construct repositories.

Avoid:

final repository = OrdersRepositoryImpl(...);

inside a Cubit.

Prefer dependency injection through the established project configuration.

This keeps the Presentation Layer decoupled from concrete implementations and improves testing.

---

## 33. Testing Dependencies

Cubits should be testable with mocked or fake repository dependencies.

A Cubit test should be able to replace the production Repository with a test implementation.

Do not make Cubits depend on global static data access that cannot be replaced during testing.

---

## 34. Anti-Patterns

The following patterns are prohibited unless explicitly approved.

### 34.1 Direct Database Access

Screen → Drift

Prohibited.

Cubit → Drift

Prohibited.

Widget → Drift

Prohibited.

### 34.2 Direct DAO Access

Presentation code must not access DAOs directly.

DAO usage belongs to the Data Layer.

### 34.3 Direct Network Access

Presentation code must not directly call Dio/Retrofit clients.

Networking belongs below the Repository boundary.

### 34.4 Business Logic in Widgets

Do not place significant business workflows inside widget callbacks.

Bad:

onPressed: () {
  // validate business rules
  // update database
  // calculate totals
  // perform persistence
}

Instead, delegate the action to the appropriate Cubit.

### 34.5 Giant Cubit

Do not create a single Cubit containing unrelated application functionality.

### 34.6 Global UI State

Do not use global mutable variables as a replacement for Cubit state.

### 34.7 Unapproved Architecture

Do not introduce:

- Bloc
- Provider
- Riverpod
- GetX
- MVVM
- Clean Architecture use-case layers
- Service layers

as alternative state-management or presentation architectures without explicit project approval.

---

## 35. Implementation Workflow for a New Feature

When implementing a new feature, follow this order.

### Step 1 — Read the Documentation

Before coding, review the relevant:

- Product requirements
- Business rules
- Domain model
- Database design
- Project structure
- Architecture guidelines
- Coding standards
- Data-layer implementation
- Presentation implementation

Do not infer requirements that are already documented elsewhere.

### Step 2 — Confirm the Existing Design

Use the approved Figma design as the visual source of truth.

Identify:

- Screens
- States
- User actions
- Navigation
- Forms
- Empty states
- Error states
- Responsive behavior

### Step 3 — Identify Repository APIs

Determine which repository operations are required.

Do not invent data access methods without checking the existing data-layer design.

### Step 4 — Design Cubit State

Identify:

- Initial state
- Loading state
- Success state
- Empty state
- Error state
- Action states
- Form state
- Pagination state where needed

### Step 5 — Implement Cubit

Implement presentation orchestration only.

The Cubit calls repositories and translates results into presentation state.

### Step 6 — Implement Screen

Build the screen according to the approved Figma design.

Connect the Screen to the Cubit.

### Step 7 — Implement Reusable Widgets

Extract genuinely reusable components.

### Step 8 — Add Validation and Error Handling

Ensure user input and failure scenarios are handled.

### Step 9 — Add Tests

Test important Cubit transitions and UI behavior.

### Step 10 — Verify Architecture

Before considering the feature complete, verify:

Screen → Cubit → Repository

and confirm that no presentation code bypasses the architecture.

---

## 36. Coding Agent Rules

When an AI coding agent implements Presentation code, it must follow these rules.

### Must

- Use Cubit.
- Follow the existing project structure.
- Follow the Design System.
- Follow Arabic/RTL requirements.
- Use repositories.
- Use dependency injection.
- Preserve offline-first behavior.
- Handle loading/empty/error states.
- Add appropriate tests.
- Reuse existing widgets/components.
- Respect existing architecture.

### Must Not

- Introduce Bloc.
- Introduce another state-management package.
- Access the database from Presentation.
- Access DAOs from Presentation.
- Call Dio/Retrofit directly from Presentation.
- Create repositories inside Cubits.
- Invent new architectural layers.
- Change database architecture.
- Implement backend synchronization prematurely.
- Replace approved Figma behavior with an invented UX.
- Remove existing functionality merely to simplify implementation.

---

## 37. Definition of Done for Presentation

A Presentation feature is considered complete when:

- The screen matches the approved design.
- Arabic and RTL behavior are correct.
- The Screen communicates through Cubit.
- Cubit communicates through Repository.
- No direct database access exists in Presentation.
- No direct network access exists in Presentation.
- Loading state is handled.
- Empty state is handled where applicable.
- Error state is handled.
- User actions are handled.
- Forms are validated where applicable.
- Duplicate submissions are prevented where necessary.
- Search/filter state works where applicable.
- Pagination works where applicable.
- Navigation behavior is correct.
- Reusable components are used appropriately.
- Dependencies are injected.
- Important Cubit transitions are tested.
- Important UI behavior is tested.
- No unapproved architecture or package has been introduced.

---

## 38. Final Architectural Rule

The Presentation Layer must remain intentionally simple.

The approved default architecture is:

Screen
↓
Cubit
↓
Repository
↓
Data Layer

Cubit is the only approved state-management mechanism for the current implementation.

Do not add architectural complexity unless the project requirements demonstrate a real need for it.

When in doubt, prefer the existing documented architecture over introducing a new pattern.