# Laundry Management System — Orders UI/UX

## 1. Document Purpose

This document defines the V1 UI/UX requirements for the Orders feature.

The Orders feature is the primary transaction workflow of the Laundry Management System.

It covers:

    Order List
    +
    Order Search
    +
    Order Filtering
    +
    Order Creation
    +
    Order Details
    +
    Order Editing
    +
    Order Items
    +
    Pricing
    +
    Payments
    +
    Order Actions

The feature must follow the approved Product, Domain, Architecture, Database, API, Design System, and UI/UX decisions.

---

## 2. Orders UX Goals

The Orders feature should allow the operator to:

    Create an Order quickly
        +
    Understand its current state
        +
    Manage its physical items
        +
    Track storage
        +
    Track payments
        +
    Complete the Order

The workflow should minimize unnecessary navigation and data entry.

---

## 3. Orders Navigation

The primary Orders route is:

    الطلبات

The conceptual structure is:

    الطلبات
        ├── قائمة الطلبات
        ├── إضافة طلب
        └── تفاصيل الطلب

The Orders feature remains accessible while offline.

---

## 4. Order List

The Order List is the main entry point for existing Orders.

It should provide:

    Search
    +
    Useful Filters
    +
    Order List
    +
    Create Order Action

The list should prioritize information needed for daily operations.

---

## 5. Order List Information

Each Order row/card should show the most important information.

Recommended information:

    Order Number
    Customer Name
    Status
    Expected Pickup
    Total
    Remaining

Additional information should only be shown if it provides meaningful
operational value.

The list must remain visually concise.

---

## 6. Order Number

The approved Order Number format is:

    YY-XXX

Example:

    26-001

The Order Number is:

    Unique
    +
    Immutable

The technical Order identity remains the UUID.

The UUID must not be displayed as the primary identifier to the user.

---

## 7. Order Search

The Orders screen must provide search.

Search should support the most useful operational identifiers.

Primary search target:

    Order Number

Additional useful search target:

    Customer Name
    Customer Phone

Search should query local data first because the application is
Offline-first.

---

## 8. Order Filtering

Useful filters may include:

    Order Status
    Expected Pickup
    Payment State
    Storage State

Filters must remain simple.

The feature should not introduce a complex query-builder interface.

Active filters should be visually identifiable.

The user must be able to clear all filters easily.

---

## 9. Order List Sorting

The default Order List should prioritize recent operational activity.

The exact database/query implementation is handled by the Data Layer.

The UI should not expose technical sorting concepts such as:

    SQL
    OFFSET
    Cursor
    Index

The UI only exposes meaningful business sorting/filtering options.

---

## 10. Incremental Loading

The Orders list should support incremental loading when the dataset
requires it.

The user experience should behave like:

    Load initial Orders
        ↓
    Scroll
        ↓
    Load more

The user should not need to manually paginate through page numbers for
normal operational browsing.

---

## 11. Empty Orders State

If there are no Orders:

    لا توجد طلبات حتى الآن

The primary action should be:

    إضافة طلب

If a search/filter produces no results:

    لا توجد نتائج مطابقة

The UI should provide an easy way to:

    Clear Search
    or
    Clear Filters

---

## 12. Order Creation

The primary action is:

    إضافة طلب

The Order Creation screen should be optimized for fast data entry.

The workflow should allow the operator to:

    Select Customer
        ↓
    Add Order Items
        ↓
    Select Services
        ↓
    Enter Required Measurements
        ↓
    Review Pricing
        ↓
    Apply Discount when applicable
        ↓
    Review Order
        ↓
    Save

---

## 13. Customer Selection

The first major part of Order Creation is selecting the Customer.

The user should be able to:

    Search Existing Customer
    +
    Select Customer
    +
    Create New Customer

The user should not be forced to leave Order Creation to create a
missing Customer.

---

## 14. Customer Summary

After selecting a Customer, the Order Creation screen should display a
clear Customer summary.

At minimum:

    Customer Name
    Customer Phone

The user should be able to change the selected Customer before saving
the Order if the Domain rules permit the change.

---

## 15. Adding Order Items

The Order Creation workflow must support adding multiple physical items.

The user selects:

    Item Type

and, when applicable:

    Item Definition

Then selects:

    Service

The UI should make the relationship between Item Type and Service
understandable.

Only compatible Services should be available for the selected Item Type.

---

## 16. Multiple Identical Items

The UI may provide a quantity/convenience input.

Example:

    قميص × 5

However, this must result in:

    OrderItem 1
    OrderItem 2
    OrderItem 3
    OrderItem 4
    OrderItem 5

Each represents an independent physical item.

The quantity input is therefore:

    Entry Convenience

and not:

    Physical OrderItem Identity

The database does not use quantity as the identity of an OrderItem.

---

## 17. Order Item Form

The Order Item input should show only relevant fields.

Common fields:

    نوع القطعة
    تعريف القطعة
    الخدمة
    السعر
    الملاحظات

Conditional fields depend on the selected Pricing Type and Item Type.

The UI must not show irrelevant measurement inputs.

---

## 18. Item Type

Item Type is required for every OrderItem.

The UI should present available Item Types using the approved master data.

The user should be able to search/select an Item Type efficiently.

---

## 19. Item Definition

Item Definition is optional at the Domain level.

If an Item Type has Item Definitions, the UI may allow the user to
select one.

The UI should not require Item Definition when the selected Item Type
does not use one.

---

## 20. Service Selection

Every OrderItem must have exactly one Service.

The UI should only allow Services compatible with the selected Item
Type.

The user should not be able to select an incompatible Service.

The compatibility is defined by the approved Service/ItemType
relationship.

---

## 21. Pricing Type

Supported V1 Pricing Types are:

    Per Piece
    Per Kilogram
    Per Square Meter
    Fixed Price

The selected Service determines the applicable Pricing Type.

The UI should present the pricing behavior naturally without exposing
internal implementation details.

---

## 22. Per Piece

For:

    Per Piece

each physical OrderItem represents one piece.

Example:

    Shirt
    Service: Wash
    Price: 40 EGP

If the user enters:

    Shirt × 5

the application creates five physical OrderItems.

The UI may show the grouped entry as:

    قميص × 5

for convenience.

---

## 23. Per Kilogram

For:

    Per Kilogram

the UI must collect the required weight/measurement according to the
approved pricing model.

Example:

    الوزن: 4.5 كجم

The application/domain layer performs the actual financial calculation.

The UI is responsible only for collecting and displaying the value.

---

## 24. Per Square Meter

For:

    Per Square Meter

the UI is primarily used for carpet-related pricing.

The user enters:

    الطول
    العرض

The application calculates:

    المساحة = الطول × العرض

The calculated area should be displayed clearly.

The user should not need to manually calculate the area.

---

## 25. Fixed Price

For:

    Fixed Price

the UI displays the applicable fixed transaction price.

The user should not be presented with unnecessary measurement fields.

---

## 26. Carpet Entry

For carpet OrderItems, the UI must support:

    Predefined Carpet Size
    or
    Custom Dimensions

For a predefined size, the user selects the appropriate size.

For a custom size, the user enters:

    Length
    Width

The area is calculated automatically.

---

## 27. Carpet Dimensions

Carpet dimensions must be validated.

The UI should provide clear Arabic validation such as:

    الطول يجب أن يكون أكبر من صفر

    العرض يجب أن يكون أكبر من صفر

The calculated area should be shown after valid dimensions are entered.

---

## 28. Order Item Notes

The user may add notes to an OrderItem when applicable.

Examples:

    ملاحظات على القطعة

Notes should be attached to the physical OrderItem.

They should not be used as a replacement for structured business data.

---

## 29. Added Items List

As items are added, the Order Creation screen should display a clear
list/summary of the added OrderItems.

Each item should show enough information to identify it.

Recommended information:

    Item Type
    Item Definition when applicable
    Service
    Pricing Type
    Measurement when applicable
    Price
    Notes indicator when applicable

---

## 30. Editing an Added Item

Before saving the Order, the user should be able to edit or remove an
OrderItem according to the approved workflow.

The UI should make the action explicit.

Examples:

    تعديل
    حذف

Deleting an unsaved item from the Order Creation form is different from
deleting a historical persisted OrderItem.

---

## 31. Order Subtotal

The Order Creation screen should show:

    المجموع الفرعي

The subtotal is derived from the OrderItems.

The UI must not independently calculate a conflicting subtotal.

---

## 32. Discount

Where discount is permitted by the approved business rules, the user
may enter/apply a discount.

The UI should clearly distinguish:

    Subtotal
    Discount
    Total

The discount must not be presented as a negative OrderItem.

---

## 33. Total

The final Order total should be highly visible.

Conceptually:

    Subtotal
        -
    Discount
        =
    Total

V1 Tax is disabled.

The UI must not present an active tax workflow.

---

## 34. Tax

V1 Tax is disabled.

The Order Creation UI must therefore not expose:

    Tax Rate
    Tax Input
    Tax Configuration

The underlying financial model may preserve tax-related values as
defined by the approved database/domain design, but the V1 UI must not
present tax as an active feature.

---

## 35. Order Review

Before saving, the user should be able to review:

    Customer
    Order Items
    Services
    Measurements
    Subtotal
    Discount
    Total
    Expected Pickup
    Delivery Request when applicable

The final amount should be visually obvious.

---

## 36. Expected Pickup

Expected Pickup is a date-only business value.

The UI should provide a date picker.

It should not require time selection.

Example:

    موعد الاستلام المتوقع
    26 أغسطس 2026

---

## 37. Delivery Request

If the approved Order workflow includes Delivery Request, the UI should
present it as an explicit Order option.

The exact operational delivery workflow remains governed by the
approved Product and Domain documentation.

The Orders UI must not invent:

    Driver Assignment
    Vehicle Assignment
    Route Planning

because these are outside the approved V1 scope.

---

## 38. Order Notes

The Order may contain general notes.

These are different from:

    OrderItem Notes

The UI should clearly distinguish:

    ملاحظات الطلب

from:

    ملاحظات القطعة

---

## 39. Save Order

The primary action should be:

    حفظ الطلب

The save operation should first persist the Order locally.

The UI should not wait for the remote API before confirming a successful
local Order creation.

This follows the approved Offline-first architecture.

---

## 40. Offline Order Creation

Order creation must work while offline.

The expected flow is:

    User creates Order
        ↓
    Local validation
        ↓
    Local database transaction
        ↓
    Order visible immediately
        ↓
    SyncOperation created
        ↓
    Remote synchronization later

The user should not receive an error simply because the device is
offline.

---

## 41. Local Save Feedback

After a successful local save, the user should receive clear feedback.

Example:

    تم حفظ الطلب

The Order Number should be immediately available.

The preferred destination is:

    تفاصيل الطلب

---

## 42. Sync Feedback After Save

The user may see a subtle state such as:

    في انتظار المزامنة

when the newly created Order has not yet synchronized remotely.

This must not make a successfully saved local Order appear as if it
failed.

---

## 43. Order Details

The Order Details screen is the main operational view of a persisted
Order.

It should clearly show:

    Order Number
    Customer
    Status
    Expected Pickup
    Items
    Pricing
    Payments
    Storage State
    Remaining Amount
    Order Actions

---

## 44. Order Header

The Order Details header should prominently display:

    Order Number
    Status

Example:

    #26-001
    جاهز للتسليم

The header should make the current state immediately understandable.

---

## 45. Customer Information

Order Details should show:

    Customer Name
    Customer Phone

The user may navigate to Customer Details when useful.

---

## 46. Order Items Section

The Order Items section should list each physical item.

Each item may show:

    Item Type
    Item Definition
    Service
    Pricing Type
    Measurement when applicable
    Price
    Notes

Every physical item remains independently identifiable.

---

## 47. Storage State per Item

Where useful, each OrderItem may display its storage state.

Examples:

    غير مخزنة
    مخزنة

The exact location may also be shown where relevant.

The Storage screen remains the primary workflow for storage operations.

---

## 48. Storage Shortcut

Order Details should provide a shortcut to the relevant Storage workflow.

Example:

    تخزين العناصر

This should take the user to the Storage context for the current Order
or its relevant unstored items.

---

## 49. Payment Summary

Order Details should clearly show:

    إجمالي الطلب
    المدفوع
    المتبقي

The user should be able to add a Payment when permitted.

---

## 50. Payment History

The Order Details screen should provide access to Payment History.

Each payment should remain an independent transaction.

Recommended information:

    Amount
    Method
    Paid At

---

## 51. Payment Action

The primary payment action may be:

    إضافة دفعة

The action should remain within the Order context.

After saving a payment:

    Total Paid
    Remaining

must update immediately from local application state.

---

## 52. Completion Action

The completion action should be visible only when meaningful.

Example:

    إكمال الطلب

If completion is not currently allowed, the UI should explain the
missing requirement.

Possible explanations include:

    يجب تخزين جميع العناصر أولاً
    يوجد مبلغ متبقي
    يجب تأكيد التسليم

The exact validation comes from the Domain layer.

---

## 53. Handover Confirmation

Completing an Order requires explicit handover confirmation according
to the approved business workflow.

The UI should use a clear confirmation interaction.

Example:

    هل تم تسليم الطلب للعميل؟

Actions:

    تأكيد التسليم
    إلغاء

The action must not happen accidentally.

---

## 54. Completion Result

After successful completion:

    Order Status
        ↓
    Completed

The UI should clearly communicate the completed state.

The related StorageRecord state should reflect the approved lifecycle.

---

## 55. Cancel Order

Cancellation is a business action.

The UI should label it:

    إلغاء الطلب

not:

    حذف الطلب

Cancellation should require appropriate confirmation.

Example:

    هل أنت متأكد من إلغاء الطلب؟

The Order remains part of the historical data.

---

## 56. Order Editing

The user may edit an Order only where the Domain rules permit it.

The UI must not expose editing actions that are invalid for the current
Order state.

If editing is unavailable, the UI should explain why.

---

## 57. Historical Values

Order Details must display transaction-time values.

For example:

    Service Name
    Pricing Type
    Unit Price
    Calculated Total

must represent the historical transaction.

Changing the current Service configuration must not silently change
existing Order Details.

---

## 58. Order Status Flow

The primary lifecycle is:

    Processing
        ↓
    Ready
        ↓
    Completed

Cancellation is a separate terminal state:

    Processing / Ready
        ↓
    Cancelled

The UI must reflect the actual Domain state.

It must not allow arbitrary manual status switching.

---

## 59. Ready State

The UI should communicate that Ready means the approved readiness
conditions have been satisfied.

The user should not manually toggle:

    Ready

as a simple visual flag.

Readiness is determined by the Domain workflow.

---

## 60. Order State Actions

The available actions should depend on the current state.

Conceptually:

    Processing
        → Edit where allowed
        → Storage
        → Payment
        → Cancel

    Ready
        → Payment
        → Handover / Complete
        → Other allowed actions

    Completed
        → View historical information

    Cancelled
        → View historical information

The exact action availability must follow the approved Domain rules.

---

## 61. Order List Status Filters

The Orders list should allow filtering by:

    قيد التنفيذ
    جاهز للتسليم
    مكتمل
    ملغي

The displayed Arabic labels are UI representations of the approved
Domain statuses.

---

## 62. Payment Filter

The Orders list may provide payment-related filtering such as:

    مدفوع بالكامل
    يوجد مبلغ متبقي

The filter should be based on the approved financial state.

---

## 63. Storage Filter

The Orders list may provide a storage-related filter where useful.

Examples:

    يحتاج تخزين
    تم التخزين

The UI should not create a new storage status that does not exist in the
Domain model.

---

## 64. Order List Performance

The Orders screen should use local data for normal browsing.

Search and filtering should be efficient enough for daily operational
use.

Remote synchronization must not block normal browsing.

---

## 65. Orders Offline State

When offline:

    Orders remain accessible locally.

The user can continue supported operations.

The UI may show a subtle:

    غير متصل

indicator.

Orders that have not synchronized may show an appropriate synchronization
state without being treated as failed Orders.

---

## 66. Orders Sync Failure

A temporary sync failure should not remove or hide the locally saved
Order.

The Order remains available locally.

The user may see:

    في انتظار المزامنة
or
    توجد مشكلة في المزامنة

depending on the actual synchronization state.

---

## 67. Orders Loading State

The Order List should use lightweight loading behavior.

For example:

    Initial local loading
        → Lightweight progress/skeleton

    Incremental loading
        → Bottom loading indicator

Do not block the entire application for remote synchronization.

---

## 68. Orders Error State

If the local Orders data cannot be loaded unexpectedly:

    تعذر تحميل الطلبات

Provide:

    إعادة المحاولة

Raw database/API errors must never be displayed.

---

## 69. Order Creation Validation

The UI should validate obvious input problems before save.

Examples:

    العميل مطلوب
    نوع القطعة مطلوب
    الخدمة مطلوبة
    يجب إضافة قطعة واحدة على الأقل
    الوزن يجب أن يكون أكبر من صفر
    الطول يجب أن يكون أكبر من صفر
    العرض يجب أن يكون أكبر من صفر

The Domain layer remains the final authority for business validation.

---

## 70. Duplicate Customer Prevention

When creating a Customer during Order Creation, the UI should use the
approved Customer uniqueness behavior.

The primary duplicate identifier is:

    Phone

If an existing Customer with the same phone is detected, the user
should be guided toward the existing Customer instead of unknowingly
creating a duplicate.

---

## 71. Order Creation and Business Settings

Where pricing/configuration comes from Business Settings or master data,
the UI should consume the approved current local values.

The Order itself must preserve its historical transaction values after
creation.

---

## 72. Design System Usage

The Orders feature must use:

    AppColors
    AppTextStyles
    AppTheme
    Shared Components

The feature must not define its own visual language.

Expected shared components include:

    AppButton
    AppTextField
    SearchField
    Dropdown
    DatePickerField
    StatusBadge
    AppCard
    AppDialog
    EmptyState
    LoadingState
    ErrorState

Feature-specific components may be created when required.

---

## 73. RTL Requirements

All Orders screens must be RTL-first.

Important areas include:

    Forms
    Order Item Lists
    Financial Summary
    Tables
    Status Badges
    Action Buttons
    Dialogs
    Navigation

Directional icons must be reviewed for RTL behavior.

---

## 74. Financial Formatting

All financial values should use the approved EGP formatting.

Example:

    250.00 ج.م

The UI must not use floating-point calculations for financial correctness.

Financial calculations remain outside the presentation layer.

---

## 75. Accessibility

Orders screens must provide:

-   Clear labels
-   Readable typography
-   Adequate input sizes
-   Clear validation
-   Visible status labels
-   Sufficient contrast
-   Clear action hierarchy
-   Appropriate focus behavior

---

## 76. Responsive Behavior

The Orders feature should support:

    Desktop
    Tablet
    Smaller supported screens

On larger screens:

    Order List
        +
    Details / Summary

may use available horizontal space efficiently.

On smaller screens, information may stack vertically.

The workflow must remain the same.

---

## 77. Screen State Model

The Order List should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

Order Creation should support:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

Order Details should support:

    Loading
    Loaded
    Error
    Offline
    Syncing

The exact state implementation belongs to the Presentation layer.

---

## 78. Navigation from Orders

Important navigation paths include:

    الطلبات
        ↓
    تفاصيل الطلب

    الطلبات
        ↓
    إضافة طلب

    تفاصيل الطلب
        ↓
    العميل

    تفاصيل الطلب
        ↓
    التخزين

    تفاصيل الطلب
        ↓
    إضافة دفعة

The user should return to the appropriate previous context after
completing a sub-flow.

---

## 79. No Direct Infrastructure Access

The Orders UI must not directly access:

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

## 80. Final Orders UX Principle

> Creating and managing an Order should feel like one continuous
> operational workflow rather than a collection of disconnected screens.

The operator should be able to:

    Select Customer
        ↓
    Add Physical Items
        ↓
    Select Services
        ↓
    Enter Required Measurements
        ↓
    Review Price
        ↓
    Save Locally
        ↓
    Store Items
        ↓
    Receive Payments
        ↓
    Complete the Order

with minimal unnecessary navigation and with the system remaining
usable even when offline.