# Laundry Management System — Storage UI/UX

## 1. Document Purpose

This document defines the V1 UI/UX requirements for the Storage feature.

The Storage feature is responsible for managing the physical location of
OrderItems after they enter the storage workflow.

The feature must support:

    Finding OrderItems
    +
    Adding OrderItems to Storage
    +
    Assigning Storage Locations
    +
    Moving Stored Items
    +
    Reviewing Current Storage State

The Storage feature must follow the approved Product, Domain,
Architecture, Database, API, Design System, and UI/UX decisions.

---

## 2. Storage UX Goals

The primary goal is:

> Make storing physical laundry items fast, clear, and difficult to
> misplace.

The operator should be able to quickly identify:

    Which Order the item belongs to
    +
    Which physical item it is
    +
    Whether it is already stored
    +
    Where it is currently stored
    +
    Where it should be placed

---

## 3. Storage Navigation

The primary Storage route is:

    التخزين

The Storage workflow must be accessible directly from the main
navigation.

It must also be accessible from relevant Order Details screens.

Conceptually:

    التخزين
        ↓
    Storage Workspace

and:

    تفاصيل الطلب
        ↓
    تخزين العناصر

---

## 4. Storage Workflow

The primary workflow is:

    Find Order / Items
        ↓
    Select Unstored Items
        ↓
    Choose Storage Location
        ↓
    Confirm Storage
        ↓
    Local Save
        ↓
    Synchronization Later

The operation must work while offline.

---

## 5. Storage as an Operational Workflow

The Storage screen is not merely a report.

It is an active operational workspace.

The user must be able to perform storage actions directly from the
Storage screen.

The user should not be required to open an Order Details screen just to
store its items.

---

## 6. Order Lookup

The Storage screen should provide a fast way to find the Order whose
items need to be stored.

Primary lookup:

    Order Number

Additional lookup may support:

    Customer Name
    Customer Phone

The lookup should primarily use local data.

---

## 7. Unstored Items

The Storage workflow should prioritize OrderItems that have not yet been
assigned an active StorageRecord.

The user should be able to quickly identify:

    عناصر غير مخزنة

These items are the primary candidates for storage.

---

## 8. Storage Item Identity

Each physical OrderItem remains an independent item.

If an Order contains:

    قميص × 5

the Storage workflow must operate on:

    Item 1
    Item 2
    Item 3
    Item 4
    Item 5

not on one aggregated quantity record.

The UI may display grouped information for convenience, but storage
identity remains per physical OrderItem.

---

## 9. Storage Item Information

A Storage Item should display enough information to identify the
physical item.

Recommended information:

    Order Number
    Item Type
    Item Definition when applicable
    Service
    Customer
    Current Storage State
    Current Location when applicable

Additional information may be shown when it helps identify the item.

---

## 10. Storage Selection

The operator should be able to select one or multiple unstored
OrderItems.

The UI should make selection state obvious.

Possible interaction:

    Checkbox / Selection control

or another appropriate pattern from the Design System.

The exact component should be decided during visual implementation.

---

## 11. Bulk Storage

The Storage workflow should support storing multiple items efficiently.

Example:

    Order 26-001
        ↓
    Select:
        Shirt
        Pants
        T-Shirt
        Dress
        ↓
    Choose Location
        ↓
    Confirm Storage

Bulk operations must still preserve independent StorageRecords for each
OrderItem.

---

## 12. Storage Location

Every active StorageRecord must reference a StorageLocation.

The UI should provide a clear location selection workflow.

The location may be represented by:

    Location Name
    Location Code

or another approved StorageLocation representation.

The user must be able to recognize the location without technical
database information.

---

## 13. Storage Location Selection

The location selection interface should prioritize speed.

If the number of locations is small:

    Dropdown / Selection

may be sufficient.

If the number of locations grows:

    Searchable selection

may be more appropriate.

The component must remain consistent with the Design System.

---

## 14. Current Location

For an already stored OrderItem, the UI should clearly show:

    الموقع الحالي

Example:

    الرف A-03

The current location is more important than historical movement
information for the V1 operational workflow.

---

## 15. Moving an Item

A stored OrderItem may need to be moved to another StorageLocation.

The UI should provide an explicit action:

    نقل

The workflow is:

    Select Item
        ↓
    نقل
        ↓
    Select New Location
        ↓
    Confirm
        ↓
    Local Update

The application must maintain only one active StorageRecord for the
OrderItem.

---

## 16. Storage Invariant

The Storage workflow must preserve the approved invariant:

    Maximum 1 active StorageRecord
    per OrderItem

The UI must not allow a normal operation that intentionally creates two
active locations for the same OrderItem.

---

## 17. Moving vs Adding Storage

The UI should distinguish between:

    تخزين

and:

    نقل

For an unstored item:

    تخزين

For an already stored item:

    نقل

This makes the physical workflow clearer.

---

## 18. Storage Confirmation

Before confirming a storage operation, the UI should show a concise
summary.

Example:

    عدد العناصر: 5
    الموقع: الرف A-03

Primary action:

    تأكيد التخزين

Secondary action:

    إلغاء

The confirmation should be lightweight.

---

## 19. Storage Confirmation for Move

For moving an item:

    العنصر: قميص
    الموقع الحالي: A-03
    الموقع الجديد: B-02

Primary action:

    تأكيد النقل

The user should clearly understand the destination before confirming.

---

## 20. Successful Storage Feedback

After successful local storage:

    تم تخزين العناصر بنجاح

The UI should immediately reflect the new state.

The item should no longer appear in the unstored list.

---

## 21. Offline Storage

Storage operations must work while offline.

The expected flow is:

    User Stores Item
        ↓
    Local Transaction
        ↓
    StorageRecord Created/Updated
        ↓
    UI Updated
        ↓
    SyncOperation Created
        ↓
    Remote Synchronization Later

The user must not be blocked because there is no network connection.

---

## 22. Storage Sync State

A locally stored item may not yet be synchronized remotely.

The UI may show a subtle state such as:

    في انتظار المزامنة

This must not be interpreted as:

    التخزين فشل

The local operation has already succeeded.

---

## 23. Synchronization Failure

If synchronization fails temporarily:

    StorageRecord remains locally valid.

The UI should not remove the item from its current local location.

The user may see:

    توجد مشكلة في المزامنة

when appropriate.

Retry behavior remains part of the Sync Layer.

---

## 24. Storage Search

The Storage screen should support fast search.

Primary search:

    Order Number

Additional search may include:

    Customer Name
    Customer Phone
    Item Type

Search should use local data.

---

## 25. Storage Filters

Useful filters may include:

    غير مخزنة
    مخزنة

Additional filtering may include:

    Storage Location

if operationally useful.

The UI should not introduce unnecessary filtering complexity.

---

## 26. Unstored Items View

The default Storage view should prioritize:

    العناصر غير المخزنة

because these represent immediate operational work.

The user should be able to switch to:

    العناصر المخزنة

when searching for or moving existing items.

---

## 27. Stored Items View

Stored items should show:

    Order Number
    Customer
    Item
    Current Location
    Service
    Relevant State

The view should be optimized for finding physical items.

---

## 28. Storage Location View

If the Storage Location count makes it useful, the Storage screen may
provide a location-oriented view.

Example:

    الرف A-01
        ↓
    4 Items

    الرف A-02
        ↓
    7 Items

Selecting a location may show the items currently assigned to it.

This should only be implemented if it improves the operational workflow.

---

## 29. Storage from Order Details

Order Details should provide a shortcut to Storage for that Order.

Example:

    تفاصيل الطلب
        ↓
    تخزين العناصر

The Storage screen should open with the Order context already applied.

The operator should not have to search for the same Order again.

---

## 30. Storage from Main Navigation

The main Storage destination should work independently from Order Details.

The operator may enter:

    التخزين

and then search for:

    Order Number

to begin storage.

This supports warehouse/storage-oriented workflows.

---

## 31. Order Context

When Storage is opened from an Order:

    Order Number

should be visible.

Example:

    تخزين الطلب #26-001

The list should prioritize items belonging to that Order.

---

## 32. Storage State and Order State

Storage state and Order status are related but distinct concepts.

The UI must not treat:

    StorageRecord

as if it were:

    Order Status

For example:

    An item can be stored

without the UI independently changing:

    Order Status

The Domain/Application layer determines when the Order becomes Ready.

---

## 33. Ready State

The Storage UI should communicate when storage completion contributes to
the Order reaching its Ready state.

However, the UI must not independently decide:

    Order is Ready

The Domain/Application layer remains responsible for this decision.

---

## 34. Storage Completion Feedback

When the final required item of an Order is stored, the UI may provide
informational feedback.

Example:

    تم تخزين جميع عناصر الطلب

If the Domain state changes the Order to Ready, the updated status should
be reflected immediately.

The UI must consume the resulting state rather than calculate it.

---

## 35. Storage Item Details

The UI may provide a compact item detail view when needed.

It may show:

    Order Number
    Customer
    Item Type
    Service
    Notes
    Current Location
    Storage State

It should not duplicate the complete Order Details screen.

---

## 36. Storage Location Creation

Storage Locations are master data.

If the V1 Settings workflow supports creating/editing Storage Locations,
that should happen in:

    الإعدادات

The operational Storage screen should primarily select existing
locations.

The Storage screen should not become a master-data management screen.

---

## 37. Inactive Storage Locations

Inactive Storage Locations should not normally be available for new
storage assignments.

Existing historical StorageRecords referencing an inactive location
must remain understandable.

The exact master-data lifecycle is governed by the Domain/Data model.

---

## 38. Empty State — No Unstored Items

If there are no items requiring storage:

    لا توجد عناصر تحتاج إلى تخزين

The UI may provide a shortcut:

    عرض العناصر المخزنة

or:

    العودة إلى الطلبات

depending on the current context.

---

## 39. Empty State — No Search Results

When search produces no results:

    لا توجد نتائج مطابقة

The user should be able to clear the search easily.

---

## 40. Empty State — Location

If a selected location contains no active stored items:

    لا توجد عناصر مخزنة في هذا الموقع

This is a valid empty state and not an error.

---

## 41. Storage Loading State

Local Storage data should load quickly.

Use lightweight loading behavior.

For incremental lists:

    Bottom loading indicator

may be used.

Avoid unnecessary full-screen loading states.

---

## 42. Storage Error State

Unexpected local loading errors should show:

    تعذر تحميل بيانات التخزين

with:

    إعادة المحاولة

Raw database/API errors must never be displayed.

---

## 43. Storage Validation

The UI should provide immediate validation for obvious invalid input.

Examples:

    يجب اختيار عنصر واحد على الأقل
    يجب اختيار موقع التخزين
    لا يمكن نقل العنصر إلى نفس الموقع

The Domain layer remains the final authority.

---

## 44. Duplicate Storage Prevention

The UI must prevent normal user actions from creating duplicate active
StorageRecords.

For example, if an item is already stored:

    تخزين

should no longer be presented as the normal action.

Instead:

    نقل

should be available where permitted.

---

## 45. Storage Selection State

When multiple items are selected, the UI should show:

    عدد العناصر المحددة

Example:

    تم تحديد 5 عناصر

The primary bulk action should then become available.

---

## 46. Storage Bulk Action

When items are selected:

    تخزين العناصر

should be available.

The action should open the location selection/confirmation flow.

After successful completion, the selection should be cleared or updated
appropriately.

---

## 47. Storage Performance

Storage is potentially a high-frequency workflow.

The UI should optimize for:

    Fast Search
    Fast Selection
    Fast Location Assignment
    Minimal Navigation
    Immediate Local Feedback

Avoid unnecessary network requests during each individual storage
interaction.

---

## 48. Storage Responsive Behavior

The Storage feature must support:

    Desktop
    Tablet
    Smaller supported screens

On larger screens, a table or dense list may be appropriate.

On smaller screens, cards or compact rows may be more usable.

The business workflow remains the same.

---

## 49. RTL Requirements

The Storage UI must be fully RTL.

Important elements include:

    Item Lists
    Search
    Filters
    Location Selection
    Action Buttons
    Tables
    Dialogs

Use:

    start
    end

rather than hardcoded directional positioning where appropriate.

---

## 50. Design System Usage

The Storage feature must use:

    AppColors
    AppTextStyles
    AppTheme
    Shared Components

Likely shared components include:

    SearchField
    AppCard
    AppButton
    StatusBadge
    Dropdown
    SelectionControl
    AppDialog
    EmptyState
    LoadingState
    ErrorState

Feature-specific components may be added when they represent a real
Storage-specific pattern.

---

## 51. Accessibility

The Storage workflow must provide:

-   Clear item identification
-   Clear location labels
-   Adequate selection controls
-   Sufficient touch/click targets
-   Visible state labels
-   Clear confirmation actions
-   Sufficient contrast

The operator should be able to distinguish:

    Stored
    Unstored
    Current Location
    New Location

without relying only on color.

---

## 52. Navigation

Important Storage navigation paths include:

    الرئيسية
        ↓
    التخزين

    الطلبات
        ↓
    تفاصيل الطلب
        ↓
    التخزين

    التخزين
        ↓
    Order Context
        ↓
    Storage Items

The Back action should preserve the previous context.

---

## 53. Storage and Domain Boundary

The Storage UI must not contain business logic such as:

    Determining Order readiness
    Calculating Order status
    Creating StorageRecords directly
    Deciding conflict resolution

These responsibilities belong to the Domain/Application and Data layers.

---

## 54. Storage and Data Boundary

The Storage UI must not directly access:

    SQLite
    Drift
    Dio
    Retrofit
    Supabase
    Edge Functions

The approved flow remains:

    UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local / Remote Data Source

---

## 55. Storage State Model

The Storage feature should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

Storage actions may additionally use:

    Selecting
    Confirming
    Saving

These are UI/application states and must not become new Domain states.

---

## 56. Storage Action Feedback

Successful operations should provide concise Arabic feedback.

Examples:

    تم تخزين العناصر بنجاح
    تم نقل العنصر بنجاح

Temporary synchronization state may be shown separately:

    في انتظار المزامنة

Errors should be clear and actionable.

---

## 57. Storage and Physical Workflow

The Storage feature represents the physical movement of laundry items.

The UX should therefore prioritize:

    Physical Item Identification
        +
    Location Accuracy
        +
    Fast Action

The interface should avoid unnecessary abstractions that make the
physical workflow harder to understand.

---

## 58. Final Storage UX Principle

> The operator should always know what physical item is being handled,
> which Order it belongs to, and where it currently is.

The Storage workflow must make:

    Finding
        ↓
    Selecting
        ↓
    Storing
        ↓
    Moving

fast, clear, and reliable while remaining fully compatible with the
Offline-first architecture.