# Laundry Management System — Settings UI/UX

## 1. Document Purpose

This document defines the V1 UI/UX requirements for the Settings
feature.

The Settings feature is responsible for managing approved operational
configuration and master data used by the Laundry Management System.

The feature must follow the approved Product, Domain, Database, API,
Architecture, Design System, and UI/UX decisions.

Settings must remain an operational configuration area.

It must not become a technical administration panel.

---

## 2. Settings UX Goals

The Settings feature should allow the operator to manage approved
configuration in a clear and controlled way.

The primary goals are:

    Easy Configuration
        +
    Clear Organization
        +
    Safe Changes
        +
    Consistent Forms
        +
    Minimal Technical Complexity

---

## 3. Settings Navigation

The primary route is:

    الإعدادات

The Settings area should be organized into logical sections.

Conceptually:

    الإعدادات
        ├── بيانات النشاط
        ├── الخدمات
        ├── أنواع القطع
        ├── تعريفات القطع
        ├── مواقع التخزين
        └── إعدادات أخرى معتمدة

Only configuration that is explicitly part of the approved V1 Product
scope should be exposed.

---

## 4. Settings Principles

Settings should follow:

    Simple
        +
    Clear
        +
    Safe
        +
    Arabic-first
        +
    RTL
        +
    Operational

The operator should understand what a setting changes before modifying
it.

---

## 5. Business Information

If Business Information is part of the approved configuration, the UI
may provide fields such as:

    اسم النشاط
    رقم الهاتف
    العنوان

Only fields defined by the approved Product/Domain model should be
included.

The UI must not invent additional business profile information.

---

## 6. Services

Services are master data used during Order creation.

The Settings UI should allow the operator to manage approved Service
definitions.

Typical actions:

    عرض الخدمات
    إضافة خدمة
    تعديل خدمة
    تفعيل / تعطيل خدمة

The exact lifecycle must follow the approved Domain rules.

---

## 7. Service Information

A Service configuration may contain information such as:

    اسم الخدمة
    نوع التسعير
    السعر
    حالة الخدمة

The exact fields depend on the approved Service domain model.

The UI must not introduce fields that are not supported by the Domain.

---

## 8. Pricing Types

The approved V1 Pricing Types are:

    Per Piece
    Per Kilogram
    Per Square Meter
    Fixed Price

The Settings UI should present these using clear Arabic terminology.

Example:

    بالقطعة
    بالكيلو
    بالمتر المربع
    سعر ثابت

The technical enum/value remains an implementation concern.

---

## 9. Service Pricing

When configuring a Service, the UI should show only the pricing fields
relevant to its selected Pricing Type.

Examples:

    Per Piece
        → Unit Price

    Per Kilogram
        → Price per Kilogram

    Per Square Meter
        → Price per Square Meter

    Fixed Price
        → Fixed Price

The UI should not show irrelevant pricing fields.

---

## 10. Historical Pricing

Changing a current Service price must not silently modify historical
Orders.

Existing Orders preserve their transaction-time pricing information.

Therefore:

    Current Service Configuration
        ≠
    Historical Order Pricing

The Settings UI should make this behavior clear if the user changes a
Service price.

---

## 11. Service Deactivation

Where the approved Domain model supports deactivation, the UI should
prefer:

    تعطيل الخدمة

rather than destructive deletion.

An inactive Service should not normally be selectable for new Orders.

Existing historical Orders must remain valid and readable.

---

## 12. Item Types

Item Types are master data used by the Order workflow.

The Settings UI may allow:

    عرض أنواع القطع
    إضافة نوع قطعة
    تعديل نوع قطعة
    تفعيل / تعطيل نوع قطعة

The exact actions depend on the approved Domain rules.

---

## 13. Item Type Information

An Item Type may contain:

    اسم النوع
    الحالة

Additional information should only be shown if defined by the approved
Domain model.

---

## 14. Item Definitions

Where Item Definitions are part of the approved model, the Settings UI
may manage them under their related Item Type.

Conceptually:

    أنواع القطع
        ↓
    نوع القطعة
        ↓
    تعريفات القطعة

This relationship should be visually clear.

---

## 15. Item Definition Lifecycle

Item Definitions should follow the same master-data principles as other
configuration data.

Where supported:

    إضافة
    تعديل
    تعطيل

should be preferred over destructive deletion.

Historical Orders must remain readable after configuration changes.

---

## 16. Service and Item Type Relationship

If the Domain defines compatibility between Services and Item Types, the
Settings UI should make this relationship understandable.

For example:

    نوع القطعة
        ↓
    الخدمات المتاحة

The operator should not be able to configure an invalid relationship
that violates the Domain rules.

---

## 17. Storage Locations

Storage Locations are master data used by the Storage workflow.

The Settings UI should allow the operator to manage approved Storage
Locations.

Typical actions:

    عرض المواقع
    إضافة موقع
    تعديل موقع
    تفعيل / تعطيل موقع

---

## 18. Storage Location Information

A Storage Location may include:

    اسم الموقع
    كود الموقع
    الحالة

The exact fields must follow the approved StorageLocation model.

---

## 19. Storage Location Deactivation

An inactive Storage Location should not normally be available for new
storage assignments.

Existing StorageRecords referencing the location must remain
understandable.

The UI should use:

    تعطيل الموقع

rather than:

    حذف الموقع

when the business behavior is deactivation.

---

## 20. Settings and Existing Orders

Changing master data must not rewrite historical Order information.

Examples:

    Changing Service Name
    Changing Service Price
    Changing Item Type Name
    Disabling a Service
    Disabling a Storage Location

must not silently alter historical transaction values.

Historical transaction snapshots remain governed by the Domain model.

---

## 21. Safe Configuration Changes

Settings that can affect future Orders should clearly communicate that
the change affects future operations.

Example:

    تعديل سعر الخدمة

The UI may display:

    سيتم تطبيق السعر الجديد على الطلبات الجديدة.

The exact message should reflect the actual Domain behavior.

---

## 22. Confirmation for Important Changes

Important configuration changes may require confirmation.

Examples:

    تعطيل خدمة
    تعطيل نوع قطعة
    تعطيل موقع تخزين

Confirmation should clearly state:

    What will change
    +
    What will not change

Example:

    سيتم تعطيل الخدمة ولن تظهر للطلبات الجديدة.
    الطلبات الحالية لن تتأثر.

---

## 23. Settings Forms

Settings forms should follow the same form principles used throughout
the application.

Structure:

    Section
        ↓
    Label
        ↓
    Input
        ↓
    Validation
        ↓
    Save

Forms should avoid unnecessary fields.

---

## 24. Settings Validation

Validation should be immediate and clear.

Examples:

    الاسم مطلوب
    السعر مطلوب
    السعر يجب أن يكون أكبر من صفر
    يجب اختيار نوع التسعير

Validation messages must be written in Arabic.

The Domain layer remains the final authority for business validation.

---

## 25. Financial Settings

Where Settings contain prices, financial values must use the approved
financial representation.

The UI should display normal EGP values.

Example:

    50.00 ج.م

The presentation layer must not use floating-point arithmetic for
financial correctness.

---

## 26. Tax Settings

V1 Tax is disabled.

The Settings UI must not expose an active Tax configuration workflow.

Do not include:

    Tax Rate
    Tax Configuration
    Enable Tax

unless the Product/Domain scope is explicitly changed later.

---

## 27. Authentication Settings

V1 does not implement User Authentication.

There is only one operational user.

Therefore Settings must not contain:

    Change Password
    User Accounts
    Roles
    Permissions
    Login Settings
    Employee Accounts

---

## 28. Technical Settings

The normal Settings UI must not expose infrastructure configuration such
as:

    API URL
    Supabase URL
    Database Configuration
    Sync Queue Configuration
    Retry Count
    Networking Configuration

These are application implementation concerns.

---

## 29. Offline Settings

Settings must remain usable according to the Offline-first architecture.

Locally available master data should remain accessible while offline.

Changes should be persisted locally first when the approved
synchronization model supports editing that configuration offline.

---

## 30. Settings Synchronization

If a configuration change requires remote synchronization, the local
change should be reflected immediately when permitted by the approved
architecture.

The UI may show:

    في انتظار المزامنة

when the change has not yet synchronized.

---

## 31. Settings Sync Failure

A temporary synchronization failure should not make a valid local
configuration change disappear.

The UI may show:

    توجد مشكلة في المزامنة

when appropriate.

Retry behavior remains part of the synchronization layer.

---

## 32. Settings Empty States

If a master-data section has no records:

    لا توجد خدمات
    لا توجد أنواع قطع
    لا توجد مواقع تخزين

The section should provide the relevant primary action:

    إضافة خدمة
    إضافة نوع قطعة
    إضافة موقع تخزين

---

## 33. Settings Loading State

Settings should load from local data where possible.

Use lightweight loading states.

Avoid unnecessary full-screen blocking.

---

## 34. Settings Error State

Unexpected local loading errors should display a clear Arabic message.

Example:

    تعذر تحميل الإعدادات

Provide:

    إعادة المحاولة

Raw infrastructure exceptions must not be shown.

---

## 35. Settings List Layout

Master-data lists may use:

    Table
    or
    List

depending on screen size and information density.

On larger screens, a table may be appropriate.

On smaller screens, compact cards/list rows may be preferable.

---

## 36. Service List

The Service list should make the following easy to identify:

    اسم الخدمة
    نوع التسعير
    السعر
    الحالة

The user should be able to quickly identify active and inactive
Services.

---

## 37. Item Type List

The Item Type list should show:

    اسم النوع
    الحالة

Where Item Definitions are relevant, the UI may indicate their count or
provide access to them.

---

## 38. Storage Location List

The Storage Location list should show:

    اسم الموقع
    الكود
    الحالة

Where useful, the UI may display the number of currently stored
OrderItems.

This should remain a useful operational indicator rather than a complex
analytics view.

---

## 39. Search in Settings

Search may be provided when the number of master-data records makes it
useful.

Examples:

    Search Services
    Search Item Types
    Search Storage Locations

Do not add search to every Settings section automatically.

---

## 40. Filtering in Settings

Simple filtering may be provided for:

    Active
    Inactive

when relevant.

Avoid advanced filtering.

---

## 41. Settings Navigation

Important navigation paths include:

    الإعدادات
        ↓
    الخدمات
        ↓
    إضافة / تعديل خدمة

    الإعدادات
        ↓
    أنواع القطع
        ↓
    إضافة / تعديل نوع قطعة

    الإعدادات
        ↓
    مواقع التخزين
        ↓
    إضافة / تعديل موقع

The Back action should preserve the previous context.

---

## 42. Settings and Order Creation

Changes made in Settings should become available to the Order Creation
workflow according to the approved local data/synchronization behavior.

Example:

    Add Service
        ↓
    Service becomes selectable in new Orders

Historical Orders must remain unchanged.

---

## 43. Settings and Storage

Changes to Storage Locations should affect future Storage assignments.

Inactive locations should not normally be selectable for new storage
operations.

Existing StorageRecords remain historical/current data and must remain
understandable.

---

## 44. Settings and Customers

V1 Customer configuration should remain intentionally limited.

Customer management itself belongs to:

    العملاء

Settings should not duplicate the Customer management workflow.

---

## 45. Settings and Reports

Reports should use the current approved configuration for current
master-data context while preserving historical transaction values.

Changing a Service configuration must not retroactively alter historical
report results that depend on transaction-time values.

---

## 46. Design System Usage

Settings must use:

    AppColors
    AppTextStyles
    AppTheme
    Shared Components

Likely components include:

    AppTextField
    AppButton
    Dropdown
    SearchField
    StatusBadge
    AppCard
    AppDialog
    EmptyState
    LoadingState
    ErrorState

Feature-specific components may be created where required.

---

## 47. RTL Requirements

Settings must be fully RTL.

Important areas include:

    Forms
    Tables
    Lists
    Dialogs
    Action Buttons
    Status Labels

Use:

    start
    end

rather than hardcoded directional positioning where appropriate.

---

## 48. Accessibility

Settings must provide:

-   Clear labels
-   Readable Arabic typography
-   Adequate input targets
-   Clear validation
-   Clear active/inactive states
-   Sufficient contrast
-   Explicit confirmation for important changes

---

## 49. Responsive Behavior

Settings must support:

    Desktop
    Tablet
    Smaller supported screens

The same configuration workflow should remain available across screen
sizes.

The presentation may change:

    Table
        ↔
    Compact List

without changing the business behavior.

---

## 50. Settings State Model

Settings lists should support:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Settings forms should support:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

These are UI/Application states and must not become new Domain states.

---

## 51. No Business Logic in UI

The Settings UI must not independently determine:

    Service compatibility
    Pricing calculations
    Order readiness
    Storage validity
    Historical transaction behavior

These decisions belong to the Domain/Application layer.

The UI collects and presents configuration.

---

## 52. No Infrastructure Access

The Settings UI must not directly access:

    Dio
    Retrofit
    Supabase
    Edge Functions
    SQLite
    Drift

The approved flow remains:

    UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local / Remote Data Source

---

## 53. Master Data Principle

Settings manages configuration.

Orders and Payments preserve transaction history.

Therefore:

    Current Configuration
        ≠
    Historical Transaction Data

Changing configuration should affect future operations according to the
approved business rules, not silently rewrite historical data.

---

## 54. V1 Settings Scope

The V1 Settings feature includes approved operational configuration such
as:

    Business Information
    Services
    Item Types
    Item Definitions
    Storage Locations

The exact final list must remain aligned with the Product and Domain
documentation.

---

## 55. Explicitly Out of Scope

The V1 Settings UI does not include:

    Authentication
    User Management
    Roles
    Permissions
    Employee Management
    Tax Configuration
    Technical API Configuration
    Database Configuration
    Sync Retry Configuration
    Advanced System Administration

These are outside the current approved scope.

---

## 56. Final Settings UX Principle

> Settings should make operational configuration easy to manage without
> exposing technical complexity or risking historical transaction
> integrity.

The operator should always understand:

    What is being configured
        +
    What future operations it affects
        +
    What historical data will remain unchanged