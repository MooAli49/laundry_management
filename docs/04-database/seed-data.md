**# Laundry Management System — Seed Data**

**## 1. Document Purpose**

This document defines the approved V1 database seed-data strategy for the Laundry Management System.

The purpose is to define:

\- Which records must exist when the application is initialized.

\- Which records are optional defaults.

\- Which data must be created or configured by the business owner.

\- Which data must never be seeded automatically.

\- How seed data should behave in an Offline-first application.

\- How seed data must remain safe during future synchronization.

\- How Expense Categories are initialized and managed.

The seed-data strategy must remain aligned with:

    docs/01-product/

    docs/02-domain/

    docs/03-architecture/

    docs/04-database/database-overview\.md

    docs/04-database/tables.md

    docs/04-database/relationships.md

    docs/04-database/indexes.md

    docs/04-database/constraints.md

    docs/04-database/sync-strategy.md

\---

**## 2. Seed Data Philosophy**

Seed data must be minimal.

The application should not populate the database with arbitrary business information simply to make the application look populated.

The goal is:

    Required System Data

        +

    Useful Default Configuration

        +

    Empty Transactional Data

The database should start in a clean operational state.

Seed data is intended to provide legitimate initial configuration.

It is not intended to fabricate business activity.

\---

**## 3. Seed Data Categories**

Seed data is divided into:

**### Category A — System Required**

Data required for the application to operate correctly.

**### Category B — Default Master Data**

Useful default records that allow the business to configure the system quickly.

**### Category C — Business-Owned Data**

Data that must be entered or configured by the actual business.

**### Category D — Transactional Data**

Must not be seeded.

Examples:

    Customers

    Orders

    OrderItems

    Payments

    Expenses

    StorageRecords

**### Category E — Development/Test Data**

Must not be included in production seed data.

\---

**# 4. Business Settings**

**## 4.1 BusinessSettings**

V1 expects one BusinessSettings record.

The application should initialize a default settings record when the database is first created.

Minimum default values:

    tax\_enabled = false

    tax\_rate = 0

Business name requires business-specific input.

Therefore the application should not invent a real business name.

A placeholder may be used only if the onboarding/setup flow explicitly supports it.

\---

**## 4.2 Currency**

Currency is fixed for V1:

    EGP

Displayed to users as:

    ج.م

No currency table is required.

No currency seed records are required.

The system must not seed:

    USD

    EUR

    GBP

or other currencies unless the product scope is explicitly changed.

\---

**## 4.3 Language**

V1 language is:

    Arabic

The application is:

    Arabic-first

        +

    RTL

The database does not require a language table.

Arabic UI text belongs to the application localization/design system.

No language seed data is required.

\---

**## 4.4 Branch**

V1 supports:

    Single Branch

No branch table is required.

No branch seed records should be introduced.

\---

**# 5. Item Types**

Item Types are master data.

The application may provide a small set of default Item Types to make the first setup easier.

Approved conceptual default Item Types include:

    Clothing

    Blankets

    Carpets

    Carpet Covers

These are aligned with the approved Product/Domain model.

The exact Arabic display names should follow the application's final Arabic terminology.

\---

**## 5.1 Item Type IDs**

Seeded Item Types must use stable deterministic IDs.

This is important because:

    Seed Data

        ↓

    Local Database

        ↓

    Synchronization

must not create duplicate logical entities.

Seed IDs should not be generated randomly every time the database is initialized.

\---

**## 5.2 Item Type Re-Run Safety**

Seed initialization must be idempotent.

Running the seed process more than once must not create duplicate ItemTypes.

Preferred behavior:

    Seed Exists

        ↓

    Keep Existing Record

    Seed Missing

        ↓

    Create Record

\---

**# 6. Item Definitions**

Item Definitions are optional master data.

Only definitions that are clearly part of the approved default configuration should be seeded.

The application must not invent a large catalog of clothing types or laundry items.

Examples of possible Item Definitions may include:

    Shirt

    T-Shirt

    Pants

    Jacket

However, these should only be included as default seed data if they are explicitly approved as part of the final business configuration.

If not approved:

    item\_definitions

        ↓

    Empty

and the business adds its own definitions.

\---

**## 6.1 Item Definition Principle**

The seed system must not assume that every laundry business uses the same item catalog.

Therefore:

    Item Types

        ↓

    Small Default Set

while:

    Item Definitions

        ↓

    Minimal / Configurable

This keeps V1 flexible.

\---

**# 7. Services**

Services are master data.

The application may provide default Service records if the final business configuration has approved them.

Possible examples include:

    Wash

    Dry Clean

    Iron

    Wash & Fold

However, these exact services must not be treated as universal business truth unless they are explicitly approved.

If the final business requirements provide a specific Service catalog, the seed data must use that approved catalog exactly.

\---

**## 7.1 Service Pricing**

Default Service prices must not be invented.

A Service seed may contain:

    name

    pricing\_type

    is\_active

but a real business price should be configured by the business unless an approved default price list exists.

The system must not silently assume arbitrary prices.

\---

**## 7.2 Pricing Type**

Every seeded Service must use an approved Pricing Type.

Examples:

    per\_piece

    per\_kg

    per\_square\_meter

    fixed\_price

Only pricing types supported by the Domain Model should be seeded.

\---

**# 8. Service / ItemType Compatibility**

If default Services are seeded, their compatibility with ItemTypes may also be seeded.

Example structure:

    Service

        ↓

    ServiceItemType

        ↓

    ItemType

Only explicitly approved combinations should be inserted.

The seed process must not automatically assume:

    Every Service

        +

    Every ItemType

is valid.

\---

**# 9. Carpet Sizes**

CarpetSizes are configurable master data.

The system may seed predefined sizes only if they are explicitly approved by the business requirements.

Examples such as:

    2 × 3

    3 × 4

    4 × 5

must not be treated as final business data unless approved.

If no approved predefined sizes exist:

    carpet\_sizes

        ↓

    Empty

The user can then add the business's actual standard sizes.

The system also supports custom Carpet dimensions where approved by the Domain/Product requirements.

\---

**# 10. Storage Locations**

StorageLocations represent the physical laundry storage structure.

The system must not invent physical locations.

Therefore:

    storage\_locations

        ↓

    Empty by default

unless the business provides an approved initial storage structure.

Examples such as:

    A-01

    A-02

    B-01

are examples only and must not automatically become production records.

\---

**## 10.1 Storage Location Setup**

Storage locations should be created through the Storage management/setup functionality.

After creation:

    is\_active = true

by default.

\---

**# 11. Expense Categories**

Expense Categories are manageable master data.

Unlike transactional Expenses, Expense Categories are valid production seed data because the application needs an initial classification system for daily operating expenses.

The initial production categories are:

    كهرباء

    مياه

    منظفات

    صيانة

    مستلزمات

    نقل

    أخرى

These categories must be seeded during initial database setup.

\---

**## 11.1 Expense Category Purpose**

Expense Categories exist to classify operating Expenses.

Example:

    Expense

        ↓

    Category: منظفات

or:

    Expense

        ↓

    Category: كهرباء

The category is independent from:

    Order

    Payment

    Customer

\---

**## 11.2 Expense Category IDs**

Seeded Expense Categories must use stable deterministic IDs.

The same logical category must receive the same stable identity across installations where predefined seed identity is required.

This prevents duplicate logical master-data records during synchronization.

\---

**## 11.3 Expense Category Re-Run Safety**

Expense Category seed initialization must be idempotent.

If a seeded category already exists:

    Keep Existing Record

If the category does not exist:

    Create Record

The seed process must not create duplicate categories.

\---

**## 11.4 Expense Category Active State**

Seeded Expense Categories start with:

    is\_active = true

The user may later:

    Edit

    Activate

    Deactivate

a category through Settings.

\---

**## 11.5 User-Managed Expense Categories**

Seeded categories become normal database records after initialization.

The business may:

    Add Category

    Edit Category

    Activate Category

    Deactivate Category

The seed process must not continuously control the categories after initialization.

\---

**## 11.6 Expense Category Deactivation**

If the user deactivates a seeded Expense Category:

    is\_active = false

the category must remain in the database.

Historical Expenses that reference the category remain valid.

The category simply becomes unavailable for new Expense selection.

\---

**## 11.7 Deactivated Seed Category Protection**

If a previously seeded Expense Category has been deactivated by the user:

    Existing Category

        +

    is\_active = false

a future seed process must not automatically reactivate it.

The seed process must distinguish between:

    Missing Seed Category

and:

    Existing but Inactive Category

If the category exists but is inactive:

    Preserve User Decision

\---

**## 11.8 Expense Category Editing**

If the user edits a seeded category name:

    User Change

        ↓

    Preserve User Change

The next application startup must not restore the original seeded name.

Seed initialization is not an ongoing configuration authority.

\---

**## 11.9 The \`أخرى\` Category**

\`أخرى\` is a normal seeded Expense Category.

It is not a special database entity.

It must have:

\- Its own stable category ID.

\- \`is\_active = true\` initially.

\- The same management capabilities as other categories.

The Expense itself handles the custom name when this category is selected.

Example:

    Category:

    أخرى

    Custom Name:

    إصلاح باب المحل

The custom name belongs to the Expense transaction.

It must not create a new Expense Category automatically.

\---

**## 11.10 Additional Categories**

The business may create additional categories after installation.

Examples:

    إيجار

    إنترنت

    رواتب

    تسويق

These are examples only.

The seed system must not add them automatically unless they are explicitly approved as production defaults.

\---

**# 12. Customers**

No Customer seed data should be included in production.

Initial state:

    customers

        ↓

    Empty

Customers are real business data and must be created through the application.

The seed system must never create fake production customers.

\---

**# 13. Orders**

No Order seed data should be included in production.

Initial state:

    orders

        ↓

    Empty

Orders represent real business transactions.

\---

**# 14. OrderItems**

No OrderItem seed data should be included in production.

Initial state:

    order\_items

        ↓

    Empty

OrderItems are created as part of real Orders.

\---

**# 15. Payments**

No Payment seed data should be included in production.

Initial state:

    payments

        ↓

    Empty

Payment records represent real financial transactions.

Fake payment records must never be inserted into production during database initialization.

Order delivery selections and delivery fees are transactional Order data and are not seeded.

\---

**# 16. Expenses**

No Expense seed data should be included in production.

Initial state:

    expenses

        ↓

    Empty

Expenses represent real operating costs incurred by the business.

The application must never create fabricated production Expenses during database initialization.

This is important because Expenses directly affect:

    Total Operating Expenses

        +

    Net Profit

Therefore fake Expenses would create false financial reports.

\---

**# 17. StorageRecords**

No StorageRecord seed data should be included in production.

Initial state:

    storage\_records

        ↓

    Empty

StorageRecords represent the physical location of real customer items.

\---

**# 18. Sync Operations**

No pending SyncOperations should be seeded.

Initial state:

    sync\_operations

        ↓

    Empty

The synchronization queue must only contain operations generated by actual local business changes.

Seed initialization must not create normal user synchronization operations.

\---

**# 19. Production Seed Data Summary**

The production database should start approximately as:

    business\_settings

        ↓

    1 configuration record

    item\_types

        ↓

    Approved default records

    item\_definitions

        ↓

    Approved defaults or empty

    services

        ↓

    Approved defaults or empty

    service\_item\_types

        ↓

    Approved compatibility records

    carpet\_sizes

        ↓

    Approved defaults or empty

    storage\_locations

        ↓

    Empty unless business setup provides initial locations

    expense\_categories

        ↓

    7 approved default categories

    customers

        ↓

    Empty

    orders

        ↓

    Empty

    order\_items

        ↓

    Empty

    payments

        ↓

    Empty

    expenses

        ↓

    Empty

    storage\_records

        ↓

    Empty

    sync\_operations

        ↓

    Empty

\---

**# 20. Development/Test Seed Data**

Development environments may use additional fake data.

Examples:

    Test Customers

    Test Orders

    Test OrderItems

    Test Payments

    Test Expenses

    Test StorageRecords

However, development seed data must be clearly separated from production seed data.

Recommended structure:

    Production Seed

        ↓

    Minimal Approved Data

    Development Seed

        ↓

    Production Seed

        +

    Synthetic Test Data

\---

**# 21. Test Data Rules**

Development/test data must:

\- Be clearly synthetic.

\- Never represent real customers.

\- Never contain real phone numbers.

\- Never contain real payment information.

\- Never contain real financial records.

\- Never be accidentally enabled in production.

Example:

    Test Customer

    Test Order

    Test Payment

    Test Expense

must remain development-only.

\---

**# 22. Seed IDs**

Seeded master-data records should use stable IDs.

Example conceptual strategy:

    predefined ItemType

        ↓

    Stable UUID

    predefined ExpenseCategory

        ↓

    Stable UUID

The same logical seed record must receive the same ID across installations.

This helps prevent:

    Duplicate Master Data

during synchronization.

\---

**# 23. Seed Idempotency**

The seed operation must be safe to run multiple times.

Example:

    First Run

        ↓

    Create ItemType

    Second Run

        ↓

    Detect Existing ID

        ↓

    Do Not Duplicate

Seed initialization must never create:

    Duplicate ItemTypes

    Duplicate Services

    Duplicate ItemDefinitions

    Duplicate CarpetSizes

    Duplicate ServiceItemTypes

    Duplicate ExpenseCategories

\---

**# 24. Seed and User Changes**

Seed data becomes normal database data after initialization.

If the user later changes a seeded record:

    User Change

        ↓

    Preserve User Change

The application must not automatically overwrite user modifications simply because the application starts again.

This applies to:

    Services

    ItemTypes

    ItemDefinitions

    CarpetSizes

    StorageLocations

    ExpenseCategories

\---

**# 25. Seed Versioning**

Seed data may evolve between application versions.

The application must distinguish between:

    Database Schema Migration

and:

    Seed Data Migration

A schema migration changes database structure.

A seed/data migration changes predefined master data.

These operations must not be mixed blindly.

\---

**# 26. Existing User Data Protection**

When a new application version introduces additional default master data:

    Existing Database

        +

    New Approved Seed Records

must not result in:

    Existing User Data Overwritten

The migration must add missing records where appropriate.

It must not reset:

    Services

    ItemTypes

    ItemDefinitions

    CarpetSizes

    StorageLocations

    ExpenseCategories

to their original defaults.

\---

**# 27. Deactivated Seed Records**

If a previously seeded master-data record is later deactivated by the user:

    is\_active = false

a future seed process must not automatically reactivate it.

This is critical.

The seed process must distinguish between:

    Missing Seed Record

and:

    Existing but Inactive Record

If the record exists but is inactive:

    Preserve User Decision

\---

**# 28. Seed and Synchronization**

Seed data must be handled carefully in an Offline-first system.

The application must not automatically generate unnecessary synchronization operations merely because seed data was inserted during local database initialization.

Seed initialization should be treated separately from normal user-generated business operations.

The exact synchronization behavior for master-data seed records must follow:

    sync-strategy.md

\---

**# 29. Seed and Remote Master Data**

If the application receives authoritative master data from the backend, the final synchronization strategy must define whether:

    Local Defaults

or:

    Remote Master Data

takes precedence.

This document does not introduce a new precedence rule.

The implementation must follow the approved synchronization strategy.

\---

**# 30. No Fake Business Data**

Production seed data must never include fabricated:

    Customers

    Orders

    OrderItems

    Payments

    Expenses

    StorageRecords

The application should look empty in transactional screens on a new installation.

This is correct behavior.

The only financial-looking data present initially should come from approved configuration/master data, not fabricated transactions.

\---

**# 31. No Arbitrary Prices**

The seed system must not invent production Service prices.

If approved business pricing exists:

    Seed Approved Prices

If it does not:

    Leave Prices Configurable

The database must not silently assume prices based on generic laundry-market knowledge.

\---

**# 32. No Arbitrary Storage Layout**

The seed system must not invent:

    Storage Locations

    Storage Capacity

    Storage Zones

unless these are explicitly provided as approved business configuration.

The Storage screen should support creating the real storage structure.

\---

**# 33. No Arbitrary Carpet Catalog**

The seed system must not create a large predefined carpet-size catalog without business approval.

The database supports:

    Predefined Carpet Size

and:

    Custom Dimensions

Therefore the business can operate even if:

    carpet\_sizes

        ↓

    Empty

\---

**# 34. Default Data and Arabic UI**

The application UI is Arabic and RTL.

Seeded display names must follow the approved Arabic terminology when those names are part of user-visible master data.

Database identifiers remain technical and use:

    snake\_case

Example:

    Technical Table:

    expense\_categories

    User-visible Category:

    منظفات

Technical identifiers must not be translated into Arabic.

\---

**# 35. Seed Data and Business Setup**

The initial setup flow may allow the business to configure:

    Business Name

    Services

    Service Prices

    Item Types

    Item Definitions

    Carpet Sizes

    Storage Locations

    Expense Categories

The database should support starting with minimal defaults and then allowing the business to customize them.

\---

**# 36. Recommended Initial Production State**

The safest V1 initial state is:

    BusinessSettings

        ↓

    Created with safe defaults

    ItemTypes

        ↓

    Approved defaults

    Services

        ↓

    Approved defaults only if confirmed

    ItemDefinitions

        ↓

    Minimal approved defaults or empty

    ServiceItemTypes

        ↓

    Approved relationships only

    CarpetSizes

        ↓

    Approved defaults or empty

    StorageLocations

        ↓

    Empty unless configured

    ExpenseCategories

        ↓

    7 approved default categories

    Customers

        ↓

    Empty

    Orders

        ↓

    Empty

    OrderItems

        ↓

    Empty

    Payments

        ↓

    Empty

    Expenses

        ↓

    Empty

    StorageRecords

        ↓

    Empty

    SyncOperations

        ↓

    Empty

\---

**# 37. Seed Data Implementation**

Seed logic should live in the Data Layer.

The Domain layer must not directly insert SQLite seed records.

The application startup/database initialization flow may call the seed initializer.

Conceptually:

    App Startup

        ↓

    Open Database

        ↓

    Run Required Migrations

        ↓

    Run Idempotent Seed Initialization

        ↓

    Application Ready

\---

**# 38. Seed Data Transactions**

Seed initialization should run inside a database transaction when multiple related seed records are created.

Example:

    Create ItemType

        +

    Create Service

        +

    Create ServiceItemType

        +

    Create ExpenseCategory

        ↓

    Commit

If seed initialization fails:

    Rollback

This prevents partially initialized master-data relationships.

\---

**# 39. Seed Failure Handling**

A seed failure must not leave the database in a partially initialized state.

The application should:

1\. Detect the failure.

2\. Roll back the transaction where applicable.

3\. Preserve the existing database.

4\. Surface an actionable technical error.

5\. Avoid silently continuing with corrupted/incomplete seed relationships.

\---

**# 40. Seed Data and Offline-first**

The first installation must not require an internet connection simply to initialize the local database.

Required local defaults must be available locally.

Therefore:

    First Launch

        ↓

    Local Database

        ↓

    Local Seed

        ↓

    Application Usable

Network synchronization may happen afterward.

\---

**# 41. Seed Data and Database Reset**

A development-only database reset may delete and recreate seed data.

Production application flows must not expose a casual:

    Reset Database

operation.

If a production reset feature is ever introduced, it requires an explicit product and technical decision because the database contains:

    Customers

    Orders

    Payments

    Expenses

    Historical Data

\---

**# 42. Expense Seed Categories and Financial Reporting**

Seeded Expense Categories do not create any financial values.

For example:

    منظفات

        ↓

    Category exists

does not mean:

    منظفات

        ↓

    100 EGP

No Expense amount is created during seeding.

Financial reports remain empty until real Expenses are recorded.

This guarantees that:

    Initial Net Profit

is not affected by fabricated Expenses.

\---

**# 43. Expense Category Seed and Settings**

The seeded Expense Categories must immediately appear in the Expense Category management section of Settings.

The user should be able to:

    View

    Edit

    Add

    Activate

    Deactivate

categories from there.

The seed system only provides the initial state.

\---

**# 44. Expense Category Seed and New Expenses**

After initialization:

    Expense Categories

        ↓

    Available to Expense Form

Only categories where:

    is\_active = true

should be available for new Expenses.

Inactive seeded categories remain available for historical references but are not offered for new transactions.

\---

**# 45. Expense Category Seed and \`أخرى\`**

The \`أخرى\` category is initially active.

If the user selects it in the Expense form:

    Category = أخرى

        ↓

    Require Custom Name

The seed system does not create any predefined custom Expense name.

Example:

    Category:

    أخرى

    Custom Name:

    إصلاح باب المحل

The value:

    إصلاح باب المحل

is user-entered transactional data.

\---

**# 46. Seed Data and Historical Safety**

Seed initialization must never modify existing historical data.

If a database already contains:

    Expense

    Order

    Payment

    Customer

    StorageRecord

running seed initialization must not:

\- Change their amounts.

\- Change their dates.

\- Change their relationships.

\- Delete them.

\- Replace their IDs.

\- Recalculate their historical values.

\---

**# 47. Seed Data and Synchronization Identity**

Stable seed IDs are important for master data that may later participate in synchronization.

Example:

    ExpenseCategory "منظفات"

        ↓

    Stable UUID

If the same logical predefined category exists on another installation, the identity can be recognized consistently according to the synchronization strategy.

The implementation must not generate a new random identity every time seed initialization runs.

\---

**# 48. Seed Data and User-Owned Configuration**

After initialization, master data becomes business-owned configuration.

This includes:

    Services

    ItemTypes

    ItemDefinitions

    CarpetSizes

    StorageLocations

    ExpenseCategories

The application must respect user modifications.

Seed data is not a recurring reset mechanism.

\---

**# 49. Seed Data and Application Updates**

When a new application version adds an approved default master-data record:

    Existing Database

        ↓

    Check New Seed ID

        ↓

    If Missing → Insert

        ↓

    If Exists → Preserve Existing Record

The application must not overwrite existing user configuration.

\---

**# 50. Seed Data and Removed Defaults**

If a future application version no longer considers a previous seed record a default:

The application must not automatically delete the existing record if it may be referenced by historical data.

The appropriate action is determined by:

    Domain Rules

        +

    Database Constraints

        +

    Migration Strategy

Historical integrity takes priority.

\---

**# 51. AI Coding Tool Rules**

AI coding tools implementing seed data must:

1\. Read this document before creating seed records.

2\. Use only approved master-data records.

3\. Never invent production transactional data.

4\. Keep seed initialization idempotent.

5\. Use stable IDs for predefined records.

6\. Never overwrite user modifications.

7\. Never reactivate user-deactivated master data.

8\. Keep development/test data separate.

9\. Keep seed logic in the Data Layer.

10\. Use transactions for related seed inserts.

11\. Follow the approved Arabic terminology for user-visible seed names.

12\. Seed the approved Expense Categories.

13\. Keep Expenses empty in production seed data.

14\. Never create fake financial transactions.

15\. Never create SyncOperations for seed initialization unless explicitly required by the approved synchronization strategy.

16\. Never introduce seed data for excluded V1 features.

\---

**# 52. Seed Data Change Rule**

Any new production seed record must have:

    Business Purpose

        +

    Approved Name

        +

    Stable ID

        +

    Defined Relationships

        +

    Defined Default Values

A new seed record must not be added simply because it makes a demo look more complete.

\---

**# 53. Expense Category Change Rule**

Any new default Expense Category must have:

    Approved Business Purpose

        +

    Approved Arabic Display Name

        +

    Stable ID

        +

    Active Initial State

The application must not automatically seed arbitrary categories.

Business-created categories remain user-owned configuration.

\---

**# 54. Seed Data Documentation Rule**

When a seed record is changed, the relevant documentation should also be reviewed.

Examples:

    New ItemType

        ↓

    Domain/Product documentation

    New Service

        ↓

    Product/Domain documentation

    New ServiceItemType

        ↓

    Relationship documentation

    New CarpetSize

        ↓

    Business configuration

    New ExpenseCategory

        ↓

    Product/Domain/Database documentation

\---

**# 55. Final Seed Data Direction**

The V1 seed strategy is:

    Minimal

        +

    Explicit

        +

    Idempotent

        +

    Stable

        +

    Offline-first

        +

    Business-configurable

        +

    Safe for historical data

        +

    Safe for synchronization

Production seed data includes:

    Required BusinessSettings

        +

    Approved Master Data

        +

    Seven Default Expense Categories

Production seed data does not include:

    Customers

    Orders

    OrderItems

    Payments

    Expenses

    StorageRecords

    Pending SyncOperations

\---

**# 56. Final Expense Seed Principle**

Expense Categories are seeded because they are reusable master data.

Expenses are not seeded because they represent real financial activity.

Therefore:

    ExpenseCategory

        ↓

    Seeded

    Expense

        ↓

    Empty

This distinction must remain explicit in the implementation.

\---

**# 57. Final Principle**

\> Seed only what the system legitimately needs or what has been explicitly approved as default business configuration.

The application should start clean, predictable, and ready for the real laundry business to configure and use.

The initial Expense Category system provides useful defaults without creating fabricated financial activity.

After initialization:

    Seed Data

        ↓

    Normal Database Data

        ↓

    User Can Manage Configuration

        ↓

    Historical Data Remains Protected