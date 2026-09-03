# Laundry Management System — Project Structure

## 1. Document Purpose

This document defines the approved V1 Flutter project structure for the Laundry Management System.

The structure is intentionally simple and feature-oriented.

The goal is to provide:

- Clear ownership of code
- Simple navigation between layers
- Easy maintenance
- Offline-first support
- Clear repository boundaries
- Easy testing
- Predictable implementation by AI coding tools

This document must remain aligned with:

- `architecture.md`
- `data-layer.md`
- `sync-strategy.md`
- `domain-model.md`
- `entities.md`
- `database-design.md`

The project is Arabic-first, RTL, tablet-first, and Offline-first.

---

## 2. Architecture Direction

The approved application flow is:

    Feature UI
        ↓
    Cubit / Bloc
        ↓
    Repository Contract
        ↓
    Repository Implementation
        ↓
    Local / Remote Data Source

The project intentionally does not use:

- UseCases layer
- Mappers layer
- Separate Application layer
- Unnecessary abstraction layers

The architecture should remain simple and practical for V1.

---

## 3. Main Project Structure

The main `lib/` structure is:

    lib/
    ├── core/
    ├── domain/
    ├── data/
    ├── features/
    └── main.dart

Each area has a clear responsibility.

---

## 4. Core Directory

Location:

    core/

The Core layer contains application-wide infrastructure and genuinely shared UI components.

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

Core must not become a dumping ground for feature-specific code.

---

## 5. Core — Constants

Location:

    core/constants/

Contains application-wide constants.

Examples:

- API configuration
- Application constants
- Database constants where genuinely shared
- Global configuration values

Feature-specific constants should remain inside their feature.

Do not place every constant in one large file if that makes the file difficult to maintain.

---

## 6. Core — Errors

Location:

    core/errors/

Contains shared technical error definitions.

Examples:

- Network errors
- Database errors
- Synchronization errors
- General infrastructure errors

Feature-specific business errors should remain close to the Domain or feature that owns them.

---

## 7. Core — Localization

Location:

    core/localization/

Contains the application's localization setup.

V1 language:

    Arabic

V1 direction:

    RTL

All user-facing strings must be managed through the localization system.

Feature-specific translations may be organized by feature if the selected localization implementation supports it.

The Data and Domain layers must not contain presentation strings.

---

## 8. Core — Network

Location:

    core/network/

Contains shared networking infrastructure.

Examples:

- Dio configuration
- Retrofit configuration
- API client
- Interceptors
- Connectivity handling
- Network exceptions
- API configuration

Feature repositories must not create independent HTTP clients.

The application should use centralized network infrastructure.

---

## 9. Core — Routing

Location:

    core/routing/

Contains application-wide navigation configuration.

Examples:

- App router
- Route definitions
- Navigation helpers

The main navigation structure includes:

    Dashboard
    Orders
    Customers
    Storage
    Services
    Reports
    Settings

Features must not create unrelated navigation systems.

---

## 10. Core — Storage

Location:

    core/storage/

Contains shared local storage that is not part of the main business database.

Examples:

- Simple preferences
- Secure storage where required by infrastructure
- App-level local settings

Business entities must not be stored here.

Business data belongs to the Data layer and SQLite database.

---

## 11. Core — Theme

Location:

    core/theme/

The Design System is centralized here.

Recommended files:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

The global application theme must be built using these files.

Conceptually:

    App Colors
        +
    App Text Styles
        +
    App Theme
        ↓
    MaterialApp

Feature screens must not define independent global design systems.

---

## 12. Core — Utils

Location:

    core/utils/

Contains genuinely shared utility functions.

Examples:

- Date formatting
- Currency formatting
- General validation helpers
- Generic formatting utilities

Do not place business logic here.

If a function only belongs to Orders, it belongs in Orders.

If a function only belongs to Expenses, it belongs in the Expense feature/domain layer.

---

## 13. Core — Widgets

Location:

    core/widgets/

Contains reusable UI components shared across multiple features.

Examples:

- App button
- App text field
- App dialog
- App loading indicator
- App empty state
- App error state
- Shared table/list components

A widget should only be moved here when it is genuinely shared.

Do not create generic widgets prematurely.

---

## 14. Domain Directory

Location:

    domain/

The Domain contains business concepts that should remain independent from Flutter and infrastructure.

Structure:

    domain/
    ├── entities/
    ├── enums/
    ├── repositories/
    └── services/

---

## 15. Domain — Entities

Location:

    domain/entities/

Contains the main business entities.

Approved V1 entities include:

    customer.dart
    order.dart
    order_item.dart
    payment.dart
    storage_record.dart
    storage_location.dart
    service.dart
    item_type.dart
    item_definition.dart
    carpet_size.dart
    carpet_item_data.dart
    business_settings.dart
    expense.dart
    expense_category.dart

Entity names must match the approved Domain documentation.

---

## 16. Domain — Expense Entities

The Expense feature introduces two Domain concepts:

    Expense

and:

    ExpenseCategory

`Expense` represents an operating cost.

`ExpenseCategory` represents manageable master data used to classify Expenses.

The relationship is:

    Expense
        ↓
    ExpenseCategory

Expense does not reference:

- Order
- Customer
- Payment

---

## 17. Domain — Enums

Location:

    domain/enums/

Contains actual business enums.

Examples:

    order_status.dart
    pricing_type.dart
    payment_method.dart

Enums should represent real business concepts.

Do not create enums for simple UI-only states.

Expense Category names are not an enum because Categories are user-manageable master data.

---

## 18. Domain — Repositories

Location:

    domain/repositories/

Contains repository contracts/interfaces.

Approved repository areas include:

    customer_repository.dart
    order_repository.dart
    order_item_repository.dart
    payment_repository.dart
    storage_repository.dart
    service_repository.dart
    item_type_repository.dart
    item_definition_repository.dart
    carpet_size_repository.dart
    settings_repository.dart
    expense_category_repository.dart
    expense_repository.dart

The Domain defines what the application needs from repositories.

The Data layer decides how those operations are implemented.

---

## 19. Domain — Expense Repository Contracts

The Expense repository contract should support operations required by V1, including:

- Create Expense
- Update Expense
- Find Expense by ID
- List Expenses
- Watch Expenses
- Filter by date
- Filter by category
- Calculate Expense totals
- Calculate Expense breakdowns

The ExpenseCategory repository contract should support:

- List Categories
- Create Category
- Update Category
- Activate Category
- Deactivate Category
- Find Category by ID

The exact method names may be finalized during implementation.

---

## 20. Domain — Services

Location:

    domain/services/

This folder is intentionally small.

It is only used for genuine domain-level logic that does not naturally belong to one entity.

Examples may include:

    pricing_service.dart

A service must not be created simply because a method contains a few lines of logic.

Do not create:

    expense_service.dart

unless a real cross-entity Domain responsibility requires it.

---

## 21. Data Directory

Location:

    data/

The Data layer handles persistence and external data sources.

Structure:

    data/
    ├── local/
    ├── remote/
    ├── models/
    └── repositories/

---

## 22. Data — Local

Location:

    data/local/

Contains local database implementation.

Recommended structure:

    data/local/
    ├── database/
    ├── tables/
    ├── queries/
    └── data_sources/

The local database technology is:

    SQLite

through:

    Drift

Database-specific code belongs inside the Data layer.

---

## 23. Data — Remote

Location:

    data/remote/

Contains remote API implementation.

Recommended structure:

    data/remote/
    ├── api/
    ├── dto/
    └── data_sources/

Networking uses the approved centralized:

    Dio
    +
    Retrofit

implementation.

Feature Cubits must not directly communicate with Dio or Retrofit.

---

## 24. Data — Models

Location:

    data/models/

Contains infrastructure-specific models when they are genuinely different from Domain entities.

Examples:

    OrderDto
    CustomerDto
    ExpenseDto
    ExpenseCategoryDto

A separate model should not be created only for the sake of creating one.

The project does not use a dedicated Mapper layer.

Transformations should remain simple and close to their actual Data Layer responsibility.

---

## 25. Data — Repositories

Location:

    data/repositories/

Contains repository implementations.

Examples:

    order_repository_impl.dart
    customer_repository_impl.dart
    storage_repository_impl.dart
    payment_repository_impl.dart
    service_repository_impl.dart
    expense_repository_impl.dart
    expense_category_repository_impl.dart

Repository implementations coordinate:

- Local data
- Remote data
- Synchronization
- Persistence
- Data conversion when genuinely required

They implement the contracts defined under:

    domain/repositories/

---

## 26. Data — Expense Repositories

The Expense Data Layer should contain:

    expense_repository_impl.dart
    expense_category_repository_impl.dart

The Expense repository coordinates:

    Local Expense Data
        +
    Sync Operations
        +
    Remote Expense Data

The Expense Category repository coordinates:

    Local Category Data
        +
    Sync Operations
        +
    Remote Category Data

---

## 27. Feature Directory

Location:

    features/

The application is organized by business feature.

Approved V1 features:

    features/
    ├── dashboard/
    ├── orders/
    ├── customers/
    ├── storage/
    ├── services/
    ├── reports/
    ├── expenses/
    └── settings/

Expenses are a V1 feature, but they are not a new top-level Sidebar navigation module.

The Expense feature is accessed through:

- Dashboard Quick Action
- Financial Report
- Expense management workflow where appropriate
- Expense Category management through Settings

---

## 28. Feature Internal Structure

Each feature should remain simple.

Preferred structure:

    feature/
    ├── presentation/
    │   ├── screens/
    │   ├── widgets/
    │   └── cubit/
    │
    └── models/

The `models` directory should only be created when the feature genuinely needs UI-specific models.

Do not duplicate Domain entities unnecessarily.

---

## 29. Feature Presentation

Location:

    features/<feature>/presentation/

Contains everything directly related to the UI of that feature.

Structure:

    presentation/
    ├── screens/
    ├── widgets/
    └── cubit/

---

## 30. Feature Screens

Location:

    features/<feature>/presentation/screens/

Contains full feature screens.

Examples:

    orders_screen.dart
    order_details_screen.dart
    create_order_screen.dart

Screen files should focus on composing UI and connecting it to feature state.

They must not contain:

- Database queries
- SQL
- Dio requests
- Repository implementations

---

## 31. Feature Widgets

Location:

    features/<feature>/presentation/widgets/

Contains widgets specific to that feature.

Examples:

    order_card.dart
    order_item_row.dart
    customer_search_field.dart
    storage_item_card.dart
    expense_card.dart
    expense_form.dart
    expense_category_selector.dart

If a widget becomes genuinely reusable across multiple features, it can be moved to:

    core/widgets/

---

## 32. Feature Cubit / Bloc

Location:

    features/<feature>/presentation/cubit/

Contains feature state-management classes.

Examples:

    orders_cubit.dart
    customers_cubit.dart
    storage_cubit.dart
    services_cubit.dart
    reports_cubit.dart
    settings_cubit.dart
    expenses_cubit.dart

Cubit/Bloc responsibilities include:

- Receiving UI actions
- Calling repositories
- Managing UI state
- Loading state
- Success state
- Error state
- Filters
- Search
- Pagination where required
- Form state where required

Cubit/Bloc must not directly access:

- SQL
- Drift tables
- Dio
- Retrofit
- Remote DTOs

---

## 33. Feature Models

Feature models are allowed only when they represent UI-specific data.

Example:

    OrderListItemViewModel

or:

    ExpenseListItemViewModel

However:

> Do not create a ViewModel for every screen automatically.

Use Domain entities directly when they already represent the required information clearly.

---

## 34. Orders Feature Structure

Recommended structure:

    features/orders/
    ├── presentation/
    │   ├── screens/
    │   │   ├── orders_screen.dart
    │   │   ├── create_order_screen.dart
    │   │   └── order_details_screen.dart
    │   │
    │   ├── widgets/
    │   │   ├── order_card.dart
    │   │   ├── order_item_row.dart
    │   │   └── order_filter_bar.dart
    │   │
    │   └── cubit/
    │       ├── orders_cubit.dart
    │       └── orders_state.dart
    │
    └── models/

The `models/` folder may be omitted if no feature-specific models are required.

---

## 35. Customers Feature Structure

Recommended structure:

    features/customers/
    ├── presentation/
    │   ├── screens/
    │   │   ├── customers_screen.dart
    │   │   ├── customer_details_screen.dart
    │   │   └── create_customer_screen.dart
    │   │
    │   ├── widgets/
    │   │   ├── customer_card.dart
    │   │   └── customer_search_bar.dart
    │   │
    │   └── cubit/
    │       ├── customers_cubit.dart
    │       └── customers_state.dart
    │
    └── models/

---

## 36. Storage Feature Structure

Recommended structure:

    features/storage/
    ├── presentation/
    │   ├── screens/
    │   │   ├── storage_screen.dart
    │   │   └── storage_details_screen.dart
    │   │
    │   ├── widgets/
    │   │   ├── storage_location_card.dart
    │   │   ├── storage_item_card.dart
    │   │   └── move_item_dialog.dart
    │   │
    │   └── cubit/
    │       ├── storage_cubit.dart
    │       └── storage_state.dart
    │
    └── models/

Storage operations must work with physical OrderItems.

Storage remains a dedicated operational workflow.

It is not treated as a simple Dashboard Quick Action.

---

## 37. Services Feature Structure

Recommended structure:

    features/services/
    ├── presentation/
    │   ├── screens/
    │   ├── widgets/
    │   └── cubit/
    │
    └── models/

This feature manages master data such as:

- Services
- Item Types
- Item Definitions
- Carpet Sizes

---

## 38. Dashboard Feature Structure

Recommended structure:

    features/dashboard/
    └── presentation/
        ├── screens/
        ├── widgets/
        └── cubit/

The Dashboard should not contain direct database queries.

It requests dashboard data through the appropriate repositories.

Approved Dashboard Quick Actions are:

    إضافة طلب
    إضافة عميل
    تسجيل دفعة
    إضافة مصروف

Quick Actions represent frequent immediate operations.

Storage is intentionally not included as a Quick Action.

---

## 39. Reports Feature Structure

Recommended structure:

    features/reports/
    └── presentation/
        ├── screens/
        ├── widgets/
        └── cubit/

Reports should request report data through repositories.

The report UI must not construct database queries.

The Financial Report may display:

- Total Sales
- Total Payments
- Total Operating Expenses
- Remaining Amount
- Discounts
- Payment Methods
- Expense Breakdown
- Net Profit

---

## 40. Expenses Feature Structure

Recommended structure:

    features/expenses/
    ├── presentation/
    │   ├── screens/
    │   │   ├── expenses_screen.dart
    │   │   └── expense_details_screen.dart
    │   │
    │   ├── widgets/
    │   │   ├── expense_card.dart
    │   │   ├── expense_form.dart
    │   │   ├── expense_category_selector.dart
    │   │   └── expense_filter_bar.dart
    │   │
    │   └── cubit/
    │       ├── expenses_cubit.dart
    │       └── expenses_state.dart
    │
    └── models/

The exact screen structure may be simplified if the final UI does not require separate screens.

Expense creation must support:

    Amount
    +
    Category
    +
    Date
    +
    Optional Notes

When Category is:

    أخرى

the form must additionally require:

    Custom Name

---

## 41. Expense Feature Responsibilities

The Expense feature is responsible for:

- Creating Expenses
- Editing Expenses
- Listing Expenses
- Filtering Expenses
- Selecting Expense Categories
- Validating the Expense form
- Displaying Expense state
- Connecting the UI to ExpenseRepository

It must not directly access:

- SQLite
- Drift
- SQL
- Dio
- Retrofit

---

## 42. Expense Category Management Structure

Expense Categories are master data.

Their management belongs to Settings rather than a new main navigation module.

Recommended Settings internal structure may include:

    features/settings/
    ├── presentation/
    │   ├── screens/
    │   ├── widgets/
    │   └── cubit/
    │
    └── models/

The Settings feature may contain an Expense Category management section such as:

    Expense Categories
        ├── List
        ├── Add
        ├── Edit
        └── Activate / Deactivate

The actual UI structure may remain inside Settings rather than creating:

    features/expense_categories/

unless the feature becomes large enough to justify separation.

---

## 43. Expense Category UI Responsibility

Settings manages:

- Category name
- Active/inactive state

The Expense feature manages:

- Selecting a Category
- Using `أخرى`
- Entering the transaction custom name

This keeps:

Configuration
and:

Daily Transaction

separate.

---

## 44. Expense `أخرى` UI Structure

When the user selects:

    أخرى

the Expense form should reveal:

    اسم المصروف

and make it required.

Example:

    التصنيف
    [ أخرى ▼ ]

    اسم المصروف *
    [ إصلاح باب المحل ]

The custom name belongs to the Expense transaction.

It is not a separate master-data entity.

---

## 45. Settings Feature Structure

Recommended structure:

    features/settings/
    └── presentation/
        ├── screens/
        ├── widgets/
        └── cubit/

Settings data is accessed through the appropriate repository contracts.

Settings may manage:

- Business Settings
- Services
- Item Types
- Item Definitions
- Carpet Sizes
- Storage Locations
- Expense Categories

The exact grouping may evolve according to the final UI.

---

## 46. Repository Communication

Feature Cubits communicate with repositories.

Preferred flow:

    Screen
       ↓
    Cubit
       ↓
    Repository
       ↓
    Local / Remote Data Source

The Cubit should not communicate directly with Data Sources.

This keeps the Data implementation replaceable.

---

## 47. Local and Remote Coordination

The Repository is responsible for coordinating local and remote sources.

Example:

    ExpenseRepository
        ↓
    Save Expense Locally
        ↓
    Add Sync Operation
        ↓
    Return Success

The Sync Engine later handles remote synchronization.

The UI does not need to know how synchronization is implemented.

---

## 48. Offline-First Rule

The default assumption for business operations is:

    Local First

Therefore:

    User Action
        ↓
    Repository
        ↓
    Local Database
        ↓
    Immediate UI Update
        ↓
    Sync Later

A network request must not be required for normal local operations.

This applies to:

- Orders
- Customers
- Payments
- Storage
- Expenses
- Supported master-data operations

---

## 49. Expense Offline Flow

The approved Expense flow is:

    Add Expense
        ↓
    Validate Locally
        ↓
    Save Expense Locally
        +
    Create Sync Operation
        ↓
    Return Success
        ↓
    UI Updates Immediately
        ↓
    Sync Later

If the network is unavailable, the Expense remains valid locally.

---

## 50. Repository Responsibilities

Repositories are responsible for:

- Reading data
- Writing data
- Updating data
- Deactivating data
- Local queries
- Remote synchronization coordination
- Data conversion when needed
- Transactions
- Returning Domain entities

Repositories are not responsible for:

- UI
- Navigation
- Widget state
- Screen layout
- Presentation formatting

---

## 51. Business Logic Placement

Business logic should be placed where it naturally belongs.

### Entity Logic

Logic directly related to an entity may live in the entity.

Example:

    Order
    → calculateRemainingAmount()

### Domain Service

Logic involving multiple domain concepts may live in a Domain Service.

Example:

    PricingService

### Repository

Persistence and data coordination belong in the Repository.

### Cubit

UI state and user interaction belong in the Cubit.

Do not put all logic inside Cubits.

---

## 52. Feature Boundary Rule

A feature must not access another feature's internal implementation directly.

For example:

    Orders Screen
        ↓
    StorageCubit

is not the preferred architecture.

Instead, the Orders feature should use the appropriate Domain/Repository contract when it needs Storage information.

Similarly:

    Reports Screen
        ↓
    ExpenseRepository

is valid through the appropriate Cubit/repository flow.

The Reports UI must not access Expense Data Sources directly.

---

## 53. Shared Code Rule

Before creating a new shared utility or widget, ask:

1. Is it actually used by multiple features?
2. Does it have a clear generic responsibility?
3. Would keeping it inside the feature create duplication?

If not, keep it inside the feature.

---

## 54. Import Rules

Presentation should import:

- Domain entities when needed
- Repository contracts through the Cubit
- Core UI/theme components
- Feature-specific components

Presentation should not import:

- Local database classes
- Remote API classes
- SQL queries
- Dio implementation classes
- Retrofit implementation classes

---

## 55. Domain Import Rules

Domain should import only:

- Dart core libraries when needed
- Domain classes

Domain must not import:

- Flutter
- Dio
- Retrofit
- Database packages
- API packages
- Presentation classes

---

## 56. Data Import Rules

Data may import:

- Domain entities
- Domain repository contracts
- Database packages
- Network packages
- Serialization packages
- Core infrastructure

Data must not import:

- Feature widgets
- Screens
- Cubits

---

## 57. Repository Naming

Use:

    <Entity>Repository

for the Domain contract.

Examples:

    OrderRepository
    CustomerRepository
    ExpenseRepository
    ExpenseCategoryRepository

Use:

    <Entity>RepositoryImpl

for the Data implementation.

Examples:

    OrderRepositoryImpl
    CustomerRepositoryImpl
    ExpenseRepositoryImpl
    ExpenseCategoryRepositoryImpl

---

## 58. Data Source Naming

Use clear names based on responsibility.

Examples:

    OrderLocalDataSource
    OrderRemoteDataSource
    ExpenseLocalDataSource
    ExpenseRemoteDataSource
    ExpenseCategoryLocalDataSource
    ExpenseCategoryRemoteDataSource

Avoid:

    ExpenseHelper
    ExpenseManager
    ExpenseService

unless the class actually represents that concept.

---

## 59. Cubit Naming

Use:

    <Feature>Cubit

Examples:

    OrdersCubit
    CustomersCubit
    StorageCubit
    ServicesCubit
    ReportsCubit
    SettingsCubit
    ExpensesCubit

For a complex feature, multiple Cubits are allowed.

Do not create multiple Cubits simply to split a small feature into arbitrary pieces.

---

## 60. File Naming

Use `snake_case` for Dart file names.

Examples:

    expense.dart
    expense_category.dart
    expense_repository.dart
    expense_repository_impl.dart
    expense_local_data_source.dart
    expense_form.dart
    expense_card.dart

Use PascalCase for classes.

Examples:

    Expense
    ExpenseCategory
    ExpenseRepository
    ExpenseRepositoryImpl
    ExpenseForm

Use camelCase for variables and methods.

Examples:

    expenseId
    expenseCategoryId
    customName
    createExpense()

---

## 61. Feature Growth Rule

If a feature becomes large, it may be split internally.

For example:

    orders/
    ├── presentation/
    │   ├── order_list/
    │   ├── order_creation/
    │   ├── order_details/
    │   └── order_payment/
    │
    └── ...

The Expense feature may later be split similarly if it becomes large:

    expenses/
    ├── presentation/
    │   ├── expense_list/
    │   ├── expense_creation/
    │   └── expense_details/
    │
    └── ...

Do not create deep nesting from the beginning.

---

## 62. Avoid Premature Abstraction

Do not create:

- Interfaces for every class
- Services for every operation
- Managers for every feature
- Helpers for one method
- Generic repositories for unrelated entities
- Generic CRUD abstractions without a real need
- Generic Expense management abstractions

The project should optimize for clarity rather than theoretical abstraction.

---

## 63. No UseCases

The project does not contain:

    usecases/

Do not introduce:

    CreateExpenseUseCase
    CreateOrderUseCase
    RecordPaymentUseCase

as a mandatory architectural layer.

Repository and Domain responsibilities are sufficient for V1.

---

## 64. No Mappers

The project does not contain:

    mappers/

Do not introduce a dedicated Mapper layer.

Data conversion should remain simple and close to the Data Layer boundary when required.

---

## 65. No Application Layer

The project does not contain:

    application/

unless a future architecture decision explicitly introduces it.

Do not create an Application layer simply to add another abstraction between Cubit and Repository.

---

## 66. No Generic CRUD Framework

Do not create generic structures such as:

    BaseRepository
    BaseCrudRepository
    GenericDataSource
    GenericEntityManager

unless a real implementation problem requires them and the architecture is explicitly updated.

Business entities have different behaviors and should remain understandable.

---

## 67. Dependency Injection

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

## 68. Navigation

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

There is no dedicated top-level:

    Expenses

Sidebar module in V1.

Expenses are accessed through:

    Dashboard Quick Action
        +
    Financial Reports
        +
    Expense workflow
        +
    Settings → Expense Categories

---

## 69. Arabic-First UI Structure

The project is Arabic-first and RTL.

Feature code must not assume LTR layout.

Use Flutter direction/localization infrastructure for:

- Text alignment
- Icons where direction matters
- Tables
- Forms
- Navigation
- Dialogs
- Date/number presentation

The project structure itself remains language-neutral.

Arabic strings belong in Localization.

---

## 70. Testing Structure

Tests should mirror the project's responsibilities.

Recommended:

    test/
    ├── domain/
    ├── data/
    ├── features/
    └── core/

Feature tests may follow:

    test/features/orders/
    test/features/customers/
    test/features/storage/
    test/features/expenses/
    test/features/reports/

Data tests may include:

    test/data/expenses/
    test/data/storage/
    test/data/orders/

---

## 71. Expense Tests

The Expense feature should have tests for:

- Expense form validation
- Positive amount validation
- Required category
- Expense date
- Optional notes
- `أخرى` custom name requirement
- Expense creation state
- Expense update state
- Expense filtering
- Expense loading
- Expense error handling

The Data Layer should separately test:

- Expense persistence
- Expense Category persistence
- Financial aggregation
- Sync queue behavior
- Transactions

---

## 72. Financial Report Tests

Reports should test:

- Total Sales
- Total Payments
- Total Operating Expenses
- Remaining Amount
- Expense Breakdown
- Net Profit

Net Profit must be derived from:

    Total Sales
        -
    Total Operating Expenses

It must not be stored as a separate business entity.

---

## 73. AI Coding Rules

AI coding tools must follow this project structure.

Before creating a new file, the AI agent should determine:

- Which layer owns the responsibility?
- Which feature owns the responsibility?
- Is the file actually necessary?
- Does an existing class already provide the required functionality?
- Is the requested concept already represented elsewhere?

The AI must not create new architectural layers automatically.

---

## 74. AI Restrictions

The AI must not introduce:

- `usecases/` folders
- `mappers/` folders
- `application/` folders
- Unnecessary service classes
- Duplicate models
- Duplicate repositories
- Multiple state-management libraries
- Generic CRUD frameworks
- Separate Expense Category feature without a real need
- New navigation modules for Expenses

unless the architecture documentation is explicitly updated and the change is approved.

---

## 75. AI Change Safety

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

## 76. Architecture and Project Growth

The architecture may evolve when the product grows.

Possible future additions include:

- Multi-device synchronization
- Advanced conflict handling
- Multi-branch
- Delivery management
- Refunds
- Advanced reporting
- Barcode support
- Advanced Expense workflows

These should be added only when approved as requirements.

Future possibilities should not create unnecessary V1 complexity.

---

## 77. Documentation Before Structural Changes

If a new requirement requires a project-structure change:

1. Identify the affected architecture decision.
2. Update the relevant Product documentation.
3. Update Domain documentation if a new entity is introduced.
4. Update Database documentation if persistence changes.
5. Update Architecture documentation if dependencies change.
6. Update this Project Structure document.
7. Only then implement the code change.

Documentation and code must remain aligned.

---

## 78. No Architecture Drift

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

## 79. Avoid God Classes

The project should avoid classes such as:

    AppCubit
    AppRepository
    DatabaseHelper
    CommonService
    Utils

when they contain unrelated responsibilities.

Each class should have a clear responsibility.

Expenses must not be added to a global:

    AppCubit

or:

    AppRepository

just because they are used from the Dashboard.

---

## 80. Simplicity Rule

The project should prefer:

    Fewer files
    +
    Fewer abstractions
    +
    Clear responsibilities
    +
    Reusable code
    +
    Easy maintenance

over:

    More layers
    +
    More interfaces
    +
    More classes
    +
    More indirection

The architecture should be practical for a V1 production system.

---

## 81. Final High-Level Structure

The expected high-level structure is:

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

The implementation should start from this structure and only introduce additional folders when a concrete requirement appears.

---

## 82. Final Feature Map

The V1 feature map is:

    Dashboard
        ↓
    Operational Overview
        +
    Quick Actions

    Orders
        ↓
    Customer Orders
        +
    Order Items
        +
    Payments

    Customers
        ↓
    Customer Management

    Storage
        ↓
    Physical OrderItem Storage

    Services
        ↓
    Services
        +
    Item Types
        +
    Item Definitions
        +
    Carpet Sizes

    Reports
        ↓
    Financial Reporting
        +
    Expense Breakdown
        +
    Net Profit

    Expenses
        ↓
    Daily Operating Expenses

    Settings
        ↓
    Business Configuration
        +
    Master Data Management
        +
    Expense Category Management

---

## 83. Final Expense Architecture

The approved Expense architecture is:

    Dashboard Quick Action
        ↓
    ExpensesCubit
        ↓
    ExpenseRepository
        ↓
    ExpenseRepositoryImpl
        ↓
    Local Expense Data Source
        +
    Remote Expense Data Source
        +
    Sync Operation

Expense Categories follow:

    Settings
        ↓
    Settings/Category UI
        ↓
    ExpenseCategoryRepository
        ↓
    ExpenseCategoryRepositoryImpl
        ↓
    Local / Remote Data Sources
        +
    Sync Operation

---

## 84. Final Financial Reporting Architecture

The Financial Report follows:

    Reports Screen
        ↓
    ReportsCubit
        ↓
    Repository / Financial Queries
        ↓
    Local Database
        ↓
    Orders
    Payments
    Expenses
        ↓
    Derived Financial Summary
        ↓
    Reports UI

The report does not create or persist a separate financial-summary entity.

---

## 85. Final Data Flow

The approved V1 flow is:

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
    Local Database
        ↓
    Immediate UI Update
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
    Cubit
        ↓
    UI

---

## 86. Final Architecture Summary

The V1 project structure intentionally follows a simple architecture:

    Feature UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local / Remote Data Source

With:

    Domain
        → Entities
        → Enums
        → Repository Contracts
        → Limited Domain Services

And:

    Data
        → Local Database
        → Remote API
        → Repository Implementations
        → Models when genuinely required
        → Synchronization Infrastructure

There are:

    No mandatory Use Cases
    No mandatory Mappers
    No Application layer
    No unnecessary abstractions

Expenses are a normal V1 business feature.

Expense Categories are manageable master data under Settings.

The project should remain simple, consistent, Arabic-first, RTL, offline-first, and easy for both developers and AI coding tools to understand and modify.