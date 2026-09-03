# Routing and Navigation

## 1. Purpose

This document defines the mandatory routing and navigation architecture for the V1 Laundry Management System.

The goal is to provide:

- Centralized route definitions.
- A centralized App Router.
- No hardcoded route strings throughout the application.
- Clear separation between navigation and business logic.
- Predictable navigation between feature screens.
- Safe handling of route parameters and entity IDs.
- A structure that can scale as additional screens are implemented.

These rules are mandatory for the implementation.

---

## 2. Core Principle

Routing must be centralized.

The application must have:

- One centralized route-definition class.
- One centralized App Router.
- Feature screens registered through the App Router.
- No scattered route-string definitions.

The conceptual structure is:

AppRoutes
↓
Defines route names/paths

AppRouter
↓
Maps routes to Screens

Screens
↓
Use AppRoutes for navigation

Cubit
↓
Handles state and operation results

Cubit does not define routes.

---

## 3. No Hardcoded Routes

Hardcoded route strings are prohibited outside the centralized route-definition class.

Do not write:

context.go('/orders');

context.push('/orders/123');

Navigator.pushNamed(context, '/customers');

inside arbitrary application files.

Instead, use the approved centralized route definitions.

For example:

context.go(AppRoutes.orders);

or the equivalent API defined by the selected routing implementation.

The exact API may vary depending on the approved router package, but the principle remains mandatory.

---

## 4. AppRoutes

The application must have a dedicated centralized route-definition class.

Example conceptual structure:

class AppRoutes {
  static const dashboard = '/';
  static const customers = '/customers';
  static const customerDetails = '/customers/details';
  static const orders = '/orders';
  static const orderDetails = '/orders/details';
  static const orderCreate = '/orders/create';
  static const storage = '/storage';
  static const expenses = '/expenses';
}

The actual route list must follow the approved Navigation documentation and implemented feature scope.

The class is the single source of truth for route paths.

---

## 5. AppRoutes Responsibilities

AppRoutes is responsible only for route definitions.

It must contain:

- Route path constants.
- Route identifiers where required.
- Centralized route naming.

It must not contain:

- Screen widgets.
- Business logic.
- Repository calls.
- Cubits.
- Database logic.
- Navigation decisions.
- Authentication logic.

AppRoutes is a definition layer, not a behavior layer.

---

## 6. AppRouter

The application must have a centralized App Router.

AppRouter is responsible for:

- Registering application routes.
- Mapping routes to screens.
- Handling route configuration.
- Handling route parameters.
- Creating the appropriate screen.
- Applying approved route-level guards when required.

Conceptually:

AppRouter
├── Dashboard
├── Customers
├── Customer Details
├── Orders
├── Order Create
├── Order Details
├── Storage
├── Expenses
└── Other approved screens

---

## 7. Router Package

The routing implementation must use the routing approach approved by the project architecture.

The implementation must not introduce multiple routing frameworks.

If the project has already selected a routing package, all application navigation should use that package consistently.

Do not mix:

GoRouter
+
Navigator 1.0
+
another routing framework

as independent application routing systems.

---

## 8. Single Routing System

The application must have one primary routing system.

Feature screens must not independently create their own routing architecture.

Do not create:

OrdersRouter

CustomersRouter

StorageRouter

as separate application-level routers unless explicitly required by the architecture.

Feature-specific route helpers may exist only when they do not duplicate the central App Router.

---

## 9. Route Registration

Every application route must be registered in AppRouter.

A route must not exist only because a screen happens to navigate to it.

The correct structure is:

AppRoutes
↓
Route Definition

AppRouter
↓
Route Registration

Screen
↓
Navigation

---

## 10. Route Naming

Route names and paths must follow one consistent convention.

Use readable, stable route paths.

Examples:

/dashboard

/customers

/customers/:customerId

/orders

/orders/create

/orders/:orderId

/storage

/expenses

The exact final paths must match the approved navigation structure.

Do not introduce inconsistent patterns such as:

/customerDetails

/customer/details

/customer-detail

for the same conceptual screen.

---

## 11. Route Constants

Route constants must use the project naming conventions.

Example:

AppRoutes.dashboard

AppRoutes.customers

AppRoutes.customerDetails

AppRoutes.orders

AppRoutes.orderCreate

AppRoutes.orderDetails

AppRoutes.storage

AppRoutes.expenses

Avoid:

Routes.r1

Routes.screen2

Routes.customerPage

unless specifically required.

---

## 12. Dynamic Routes

Entity-specific screens should use dynamic route parameters where appropriate.

Examples:

/customers/:customerId

/orders/:orderId

The ID must be supplied as route data.

Do not create a unique hardcoded path for every entity instance.

Incorrect:

/orders/order-123

/orders/order-124

Correct:

/orders/:orderId

with:

orderId = 123

---

## 13. Route Arguments

Route arguments must be limited to the information required to reconstruct the destination screen.

Prefer stable identifiers.

Example:

orderId

customerId

expenseId

Do not pass infrastructure objects through navigation.

Never pass:

- DAO objects.
- Database connections.
- Repository implementations.
- Drift rows when avoidable.
- Cubits.
- Database transactions.

---

## 14. Entity ID Navigation

For entity details, prefer:

Route
+
Entity ID

Example:

/orders/:orderId

The destination screen then loads the required data through the approved repository/data flow.

Conceptually:

Navigation
↓
orderId
↓
Order Details Screen
↓
Cubit
↓
OrderRepository
↓
Local Database

---

## 15. Do Not Pass Full Business Objects by Default

Avoid passing complete entities through navigation when an ID is sufficient.

For example, do not make:

OrderDetailsScreen(order: order)

the required navigation contract if the screen can safely load:

OrderDetailsScreen(orderId: orderId)

from the repository.

This keeps navigation lightweight and reduces stale-data problems.

---

## 16. Route Data vs Business Data

Route parameters identify the destination.

They must not become a replacement for the repository.

For example:

orderId

is a route parameter.

Order

is business data.

The destination screen should obtain the latest Order data through the approved data flow.

---

## 17. Missing Entity

If a route references an entity that does not exist:

/orders/999999

the destination must handle the missing entity gracefully.

Possible behavior:

- Show a not-found state.
- Show an appropriate localized message.
- Provide a Back action.
- Return to an appropriate parent screen.

Do not crash the application.

---

## 18. Invalid Route Parameters

Invalid route parameters must be handled safely.

Examples:

Missing orderId.

Malformed ID.

Unsupported parameter.

Unknown entity.

The application must not expose raw exceptions to the user.

---

## 19. Route-Level Error Handling

Routing failures must result in an appropriate application state.

Do not display:

- Stack traces.
- Technical parser exceptions.
- Raw router exceptions.

User-facing route errors must follow the localization and error-handling strategy.

---

## 20. Dashboard Route

Dashboard is the primary application entry point for the main operational experience.

The approved route must be centralized through AppRoutes.

The exact route path must follow the approved Navigation documentation.

Dashboard navigation must not be hardcoded in individual widgets.

---

## 21. Customers Navigation

The Customers feature should follow the approved navigation hierarchy.

Conceptually:

Customers List
↓
Customer Details

and where supported:

Customers List
↓
Create Customer

Customer Details
↓
Edit Customer

The actual screens must match the approved feature scope.

---

## 22. Orders Navigation

Orders should support the approved navigation hierarchy.

Conceptually:

Orders List
↓
Order Details

and:

Orders List
↓
Create Order

Order Details
↓
Edit where allowed

Order Details
↓
Payment

Order Details
↓
Storage where applicable

The exact navigation behavior must follow the approved Orders documentation.

---

## 23. Storage Navigation

Storage should follow the approved operational flow.

Conceptually:

Storage
↓
Items Requiring Storage
↓
Store / Move Item

Navigation must use centralized routes.

Storage must not navigate directly through another feature's internal Cubit.

---

## 24. Expenses Navigation

Expenses should follow the approved feature navigation.

Conceptually:

Expenses List
↓
Create Expense

Expenses List
↓
Expense Details/Edit where supported

All routes must be centralized.

---

## 25. Master Data Navigation

Approved master-data screens should follow a consistent hierarchy.

For example:

Master Data
↓
Services

Master Data
↓
Item Types

Master Data
↓
Item Definitions

Master Data
↓
Storage Locations

Master Data
↓
Expense Categories

The actual list depends on the approved navigation scope.

---

## 26. Navigation From Dashboard

Dashboard may navigate to feature screens.

Examples:

Dashboard
→ Orders

Dashboard
→ Customers

Dashboard
→ Storage

Dashboard
→ Expenses

Dashboard
→ Reports

Navigation must use AppRoutes.

Do not embed route strings directly in Dashboard widgets.

---

## 27. Bottom Navigation / Main Navigation

If the approved UI uses primary navigation such as a NavigationRail, NavigationBar, or Sidebar, the navigation destinations must also use centralized route definitions.

Do not create a separate hardcoded routing table inside the navigation widget.

The navigation UI should reference AppRoutes.

---

## 28. Navigation Labels vs Routes

User-facing navigation labels are different from route paths.

Example:

Arabic UI label:

الطلبات

Route:

/orders

Do not use the Arabic display label as the route identifier.

Routes should remain stable and language-independent.

---

## 29. Localization and Routes

Route paths must not depend on the current UI language.

Do not create:

/الطلبات

or:

/orders-ar

Routes must remain language-independent.

Localization affects display text, not route identity.

---

## 30. RTL and Navigation

Navigation UI must respect RTL.

This includes:

- Directional icons.
- Back behavior presentation.
- Navigation rail/sidebar positioning.
- Breadcrumbs if used.
- Transitions where applicable.

RTL presentation must not change the underlying route identifiers.

---

## 31. Back Navigation

Back navigation should follow the platform/router behavior unless the feature has an explicit business requirement.

Avoid manually recreating a global back stack.

The screen should not contain unnecessary custom back-stack management.

---

## 32. Unsaved Changes

Screens containing unsaved user input should protect the user from accidental loss where appropriate.

Example:

Create Order
↓
User enters data
↓
Attempts to leave

The application may show an unsaved-changes confirmation according to the approved UX rules.

This behavior belongs to Presentation/Navigation, not Domain.

---

## 33. Successful Mutation Navigation

After a successful mutation, navigation may occur when required by the feature flow.

Example:

Create Customer
↓
Success
↓
Return to Customer List

Create Order
↓
Success
↓
Open Order Details

The exact behavior must follow the approved feature UX.

Do not make Cubits directly manipulate the router unless explicitly allowed by the State Management architecture.

---

## 34. Cubit and Navigation Separation

Cubits should not own application route definitions.

Avoid:

class OrdersCubit {
  void createOrder() {
    ...
    router.go('/orders');
  }
}

Prefer:

Cubit
↓
Successful operation state/result
↓
Screen
↓
Navigation

This keeps state management independent from routing.

---

## 35. Cubit Navigation Results

A Cubit may expose an operation result that tells the Presentation layer what happened.

Example:

OrderCreated(orderId)

The screen may then decide:

navigate to Order Details

The Cubit does not need to know the route path.

---

## 36. Navigation From Domain

Domain must not know about routing.

Do not import:

- Flutter navigation.
- GoRouter.
- Navigator.
- BuildContext.

into Domain code.

Domain logic must remain framework-independent.

---

## 37. Navigation From Data

Data must not know about routing.

Repositories, DAOs, and database classes must not navigate.

They return data/results/failures.

---

## 38. BuildContext Rules

Do not pass BuildContext deep into:

- Repositories.
- DAOs.
- Database services.
- Domain entities.
- Domain logic.

BuildContext belongs to Presentation.

---

## 39. Router Access

If the selected routing framework requires router access from a screen, use the framework's approved Presentation-level mechanism.

Do not expose the router as a global dependency to every layer.

---

## 40. Route Guards

Route guards should be introduced only when the application has an actual approved requirement.

Do not create speculative authentication/authorization guards.

If authentication is not part of the V1 scope, do not invent:

AuthGuard

RoleGuard

PermissionGuard

---

## 41. Authentication Boundary

If authentication is introduced in a future phase, it must integrate at the routing/application boundary.

Feature screens should not individually implement authentication checks.

---

## 42. Authorization Boundary

If roles/permissions are introduced later, route-level authorization should be centralized.

Do not scatter:

if (isAdmin)

through unrelated screens unless required by the approved feature design.

---

## 43. Deep Linking

Deep linking is not required unless explicitly included in the approved V1 scope.

Do not implement a full deep-linking system simply because the routing package supports it.

The architecture should not prevent future deep linking.

---

## 44. Browser/Web URL Considerations

If the application later targets Flutter Web, route paths should remain stable and readable.

However, web-specific routing requirements must not cause unnecessary complexity in the current V1 implementation unless Web is part of the approved scope.

---

## 45. Nested Routes

Nested routes may be used where they genuinely represent a parent-child navigation relationship.

Example:

/orders
/orders/:orderId

Do not introduce deep nesting simply to organize code.

The route hierarchy should reflect the user navigation hierarchy.

---

## 46. Route Naming Stability

Once a route is introduced and used across the application, do not rename it casually.

A route path is an application contract.

Changes must be deliberate and updated centrally.

---

## 47. No Duplicate Route Definitions

Do not define the same route in multiple files.

Incorrect:

orders = '/orders'

in multiple screens.

Correct:

AppRoutes.orders

used everywhere.

---

## 48. No Magic Route Strings

The following are prohibited outside AppRoutes:

'/'

'/orders'

'/customers'

'/storage'

'/expenses'

'/orders/details'

'/customers/details'

or any other application route literal.

If a route is needed, reference the centralized definition.

---

## 49. No Magic Parameter Keys

Route parameter names should also be centralized or consistently defined where the routing framework requires them.

Avoid scattered string keys such as:

'orderId'

'customerId'

through unrelated router code when a centralized route configuration can define them.

---

## 50. Route Builders

If dynamic routes require path construction, provide a centralized route builder/helper.

Conceptually:

AppRoutes.orderDetails(orderId)

rather than:

'/orders/$orderId'

being reconstructed in multiple screens.

The route builder should remain inside the routing layer.

---

## 51. Example Route API

A preferred conceptual API is:

AppRoutes.dashboard

AppRoutes.customers

AppRoutes.customerDetails(customerId)

AppRoutes.orders

AppRoutes.orderCreate

AppRoutes.orderDetails(orderId)

AppRoutes.storage

AppRoutes.expenses

The exact syntax may vary according to the selected routing package.

The principle is:

Central definition
+
Central construction
+
No scattered strings

---

## 52. AppRouter Responsibilities

AppRouter should contain the actual route-to-screen mapping.

Conceptually:

AppRouter
├── AppRoutes.dashboard → DashboardScreen
├── AppRoutes.customers → CustomersScreen
├── AppRoutes.customerDetails → CustomerDetailsScreen
├── AppRoutes.orders → OrdersScreen
├── AppRoutes.orderCreate → CreateOrderScreen
├── AppRoutes.orderDetails → OrderDetailsScreen
├── AppRoutes.storage → StorageScreen
└── AppRoutes.expenses → ExpensesScreen

The exact screen list follows the approved implementation scope.

---

## 53. Screen Construction

Screens should receive only the dependencies/parameters they actually need.

For an entity details screen:

OrderDetailsScreen(orderId: orderId)

is preferred over passing infrastructure dependencies through route arguments.

DI should provide repositories and infrastructure.

The route provides the entity identity.

---

## 54. Dependency Injection and Routing

AppRouter may use the approved DI setup to create screen dependencies.

The router must not manually instantiate database infrastructure.

Example conceptual flow:

AppRouter
↓
Create Screen
↓
Screen receives Cubit
↓
Cubit receives Repository
↓
Repository receives Data Source

DI remains responsible for dependency construction.

---

## 55. Router and GetIt

GetIt should not be used as a global navigation API.

Avoid:

GetIt.I<AppRouter>().go(...)

throughout the application unless explicitly required by the chosen router architecture.

Prefer framework-approved navigation access from Presentation.

---

## 56. Route Lifecycle

When a screen is created:

- Required route arguments are validated.
- Required dependencies are provided.
- The screen initializes its Cubit/state according to the approved State Management rules.

When a screen is removed:

- Presentation resources should be disposed appropriately.
- Cubit lifecycle must follow the DI/Presentation strategy.

---

## 57. Route Refresh

Do not implement unnecessary manual route refresh mechanisms.

If local data changes, the relevant screen should react through the approved repository/Cubit flow.

Navigation should not be used as a substitute for state management.

---

## 58. Navigation and Reactive Data

Navigation determines which screen is visible.

Reactive data determines what the screen displays.

Do not solve data refresh problems by repeatedly navigating away and back.

Prefer:

Repository Watch
↓
Cubit
↓
UI update

when appropriate.

---

## 59. Navigation After Delete

If a detail screen performs a deletion/deactivation operation and the current entity is no longer valid for the screen:

- Complete the mutation.
- Return to the appropriate parent route.
- Show appropriate feedback if required.

Do not leave the user on a detail screen displaying an entity that no longer exists when the business rules prohibit it.

---

## 60. Navigation After Cancellation

If an Order is cancelled:

- The Order Details screen may remain open if approved by UX.
- Or navigation may return to Orders.

The final behavior must follow the approved Orders UX.

Do not invent a new navigation flow during implementation.

---

## 61. Navigation After Completion

After completing an Order, follow the approved Order workflow.

Do not automatically redirect to unrelated features.

If navigation is required, use the centralized AppRoutes.

---

## 62. Modal vs Route

Not every interaction needs a route.

Use dialogs, sheets, or inline UI for small focused actions when defined by the UI design.

Use routes for actual screens and navigable application destinations.

Do not create routes for every small confirmation dialog.

---

## 63. Create/Edit Screens

Create and Edit screens may be separate routes or share a route with mode parameters depending on the approved implementation.

Whichever approach is selected must be consistent.

Do not create multiple inconsistent patterns across features.

---

## 64. Details Screens

Details routes should identify the entity using its ID.

Examples:

Customer Details
→ customerId

Order Details
→ orderId

Expense Details
→ expenseId

The destination loads current data from the repository.

---

## 65. Navigation and Stale Data

Passing only an entity ID helps prevent stale route data.

If the entity changes elsewhere, the details screen can reload/react to the latest local data.

Do not assume the object passed from the previous screen is always current.

---

## 66. Route-Level Loading

Route construction should not perform long-running business operations before the screen exists unless required by the router architecture.

Prefer:

Route
↓
Screen
↓
Cubit
↓
Loading State
↓
Data

This provides predictable loading and error states.

---

## 67. Route-Level Data Fetching

If the routing framework supports route-level data loading, use it only when required by the architecture.

Do not move repository logic into the router simply because the router can perform it.

The default preference is:

Router identifies screen
+
Screen/Cubit loads data

---

## 68. Router Error Page

The application should have a centralized route error/not-found presentation where appropriate.

It should be localized and consistent with the Design System.

Do not create a unique error UI for every invalid route.

---

## 69. Unknown Routes

Unknown routes should resolve to the centralized error/not-found behavior.

The application must not crash because a route cannot be resolved.

---

## 70. Route Security

Do not assume route hiding provides security.

If authorization is required in a future phase, enforce it at the appropriate application/business boundaries.

Routes are navigation mechanisms, not security mechanisms.

---

## 71. Testing Routes

Routing should be tested at an appropriate level.

At minimum verify:

- Main routes resolve.
- Required screens open.
- Dynamic routes receive correct IDs.
- Invalid/missing IDs are handled.
- Back navigation works.
- Create flows navigate correctly.
- Detail flows navigate correctly.
- Successful mutations navigate correctly where required.
- Unknown routes show the approved fallback.

---

## 72. No Route Tests Through Database

Routing tests should not require a real database unless the route itself intentionally depends on data loading.

Keep routing behavior separate from persistence testing where possible.

---

## 73. Navigation Regression

When adding a new route:

- Existing routes must continue to work.
- Existing navigation destinations must not break.
- Route constants must remain centralized.
- AppRouter must remain the single registration point.

---

## 74. Adding a New Route

The required process is:

1. Confirm the screen is approved.
2. Add the route definition to AppRoutes.
3. Add the route registration to AppRouter.
4. Add the screen implementation.
5. Add required dynamic parameter handling.
6. Update navigation UI if required.
7. Update tests.
8. Verify no hardcoded route strings were introduced.

---

## 75. Removing a Route

Before removing a route:

1. Search the entire project for references.
2. Remove navigation references.
3. Remove AppRouter registration.
4. Remove AppRoutes definition.
5. Remove obsolete tests.
6. Confirm no feature still depends on it.

Do not leave dead route constants.

---

## 76. Renaming a Route

A route rename must be treated as a controlled change.

Update:

- AppRoutes.
- AppRouter.
- All navigation callers.
- Tests.
- Documentation where required.

Do not rename route strings in scattered files manually without updating the central definition.

---

## 77. AI Coding Agent Rules

The coding agent must follow these routing rules strictly.

It must:

- Use AppRoutes.
- Use AppRouter.
- Avoid hardcoded route strings.
- Use centralized dynamic route builders.
- Pass IDs instead of infrastructure objects.
- Keep routing in Presentation/Application boundaries.
- Keep Cubits independent from route definitions.
- Keep Domain independent from routing.
- Keep Data independent from routing.

---

## 78. AI Must Not Create Hardcoded Routes

The coding agent must not write:

context.go('/orders')

context.push('/customers')

Navigator.pushNamed(context, '/storage')

or equivalent hardcoded route strings outside the centralized routing definitions.

If a route does not exist in AppRoutes, the agent must add it centrally rather than bypassing the architecture.

---

## 79. AI Must Not Create Duplicate Routers

Do not create an additional router for a feature without an explicit architectural decision.

The default is:

One AppRouter
+
One AppRoutes

---

## 80. AI Must Not Navigate From Data or Domain

The coding agent must never add router/navigation dependencies to:

- Entities.
- Value Objects.
- Domain services.
- Repositories.
- DAOs.
- Database classes.

---

## 81. AI Must Not Pass Infrastructure Through Routes

Do not pass:

- Repository.
- DAO.
- Database.
- Cubit.
- BuildContext.

as route arguments.

Use DI and route identifiers.

---

## 82. AI Must Not Invent Navigation

If the required navigation behavior is not documented:

Do not invent a new navigation flow.

Identify the ambiguity and request clarification.

---

## 83. AI Must Preserve Existing Routes

When implementing a new feature, do not rename or reorganize existing routes unless the task explicitly requires it.

Avoid unrelated routing refactors.

---

## 84. AI Must Search Before Adding Routes

Before adding a new route:

1. Search AppRoutes.
2. Search AppRouter.
3. Search the project for the intended screen/route.
4. Confirm that an equivalent route does not already exist.
5. Reuse the existing route if appropriate.

---

## 85. AI Completion Report

Any implementation task that changes routing must include an explicit completion report containing:

### Implemented

What routing/navigation behavior was added or changed.

### Routes Added

List the AppRoutes definitions added.

### AppRouter Changes

List the route registrations added or modified.

### Screens

List the screens connected to the routes.

### Parameters

List dynamic route parameters and their handling.

### Tests

List routing tests executed and their result.

### Hardcoded Route Check

Confirm that no new hardcoded application route strings were introduced outside the centralized routing definitions.

### Architecture Compliance

Confirm:

AppRoutes
+
AppRouter
+
Presentation Navigation
+
Cubit/Router Separation

were preserved.

### Out of Scope

List navigation behavior intentionally not implemented.

### Remaining Issues

List any unresolved routing issue or dependency.

---

## 86. Definition of Done

Routing implementation is complete when:

- AppRoutes exists as the centralized route-definition class.
- AppRouter exists as the centralized route registration point.
- All approved routes are defined centrally.
- Screens use centralized route definitions.
- No application route strings are hardcoded throughout features.
- Dynamic routes use centralized parameter handling.
- Entity IDs are passed safely.
- Infrastructure objects are not passed through routes.
- Cubits do not own route definitions.
- Domain does not depend on routing.
- Data does not depend on routing.
- Unknown routes are handled safely.
- Invalid entity routes are handled safely.
- Back navigation works.
- Approved feature navigation flows work.
- Relevant route tests pass.
- No unrelated routing refactor was introduced.
- Documentation remains aligned with the implementation.

---

## 87. Final Architecture

The required routing architecture is:

AppRoutes
↓
Central route definitions
↓
AppRouter
↓
Route → Screen
↓
Screen
↓
Cubit
↓
Repository Contract
↓
Data Layer

Navigation is a Presentation/Application concern.

Business logic remains in the approved Domain/Data boundaries.

---

## 88. Final Principles

1. Routes must never be scattered throughout the application.
2. AppRoutes is the single source of truth for route definitions.
3. AppRouter is the single source of truth for route registration.
4. Screens navigate using centralized route definitions.
5. Dynamic routes use stable entity IDs.
6. Route parameters identify entities; they do not replace business data.
7. Infrastructure objects must never be passed through navigation.
8. Cubits must not define routes.
9. Cubits should report operation results; Presentation decides navigation.
10. Domain must remain independent from routing.
11. Data must remain independent from routing.
12. Localization must not affect route identity.
13. RTL must not affect route identifiers.
14. Unknown and invalid routes must be handled safely.
15. Navigation must not be used as a substitute for state management.
16. New routes must be added centrally.
17. Existing routes must not be changed casually.
18. No speculative navigation should be introduced.
19. No duplicate routers should be created.
20. The routing system must remain simple, centralized, predictable, and ready for future expansion.