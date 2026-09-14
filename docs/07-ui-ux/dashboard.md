# Laundry Management System — Dashboard

## 1. Document Purpose

This document defines the V1 UI/UX requirements for the Dashboard.

The Dashboard is the primary operational landing screen of the Laundry Management System.

Its purpose is to give the operator a quick understanding of the current operational situation and provide fast access to the most common daily actions.

The Dashboard is not intended to replace:

    Orders
    Storage
    Customers
    Reports

It should provide a concise operational overview and shortcuts into those workflows.

---

## 2. Dashboard Goals

The Dashboard should help the operator answer these questions quickly:

    What needs my attention?
    How many Orders are active?
    Which Orders are Ready?
    Which Orders are waiting for action?
    What payments are still pending?
    What storage work needs to be completed?
    What pickups are due today?
    What are today's important operational numbers?

The Dashboard should avoid unnecessary analytics.

---

## 3. Dashboard Principles

The Dashboard follows:

    Simple
        +
    Operational
        +
    Action-oriented
        +
    Information-dense but not cluttered
        +
    Arabic-first
        +
    RTL
        +
    Offline-first

Every Dashboard section should have a clear operational purpose.

---

## 4. Dashboard Entry

The Dashboard is the default application landing screen.

Conceptually:

    Application Start
        ↓
    الرئيسية

The Dashboard should load its primary information from local data first.

Network availability must not be required to display the local operational state.

---

## 5. Dashboard Structure

The Dashboard should be organized into a small number of meaningful sections.

Recommended structure:

    Header
        ↓
    Quick Actions
        ↓
    Operational Summary
        ↓
    Attention Required
        ↓
    Recent / Relevant Orders

The final visual arrangement is subject to responsive screen design.

---

## 6. Header

The Dashboard header should clearly communicate:

    الصفحة الحالية: الرئيسية

It may also provide access to:

    Synchronization Status
    Application-level actions
    Other approved global controls

The header must remain visually lightweight.

---

## 7. Quick Actions

The Dashboard must provide direct access to the most common operational actions.

The approved V1 Quick Actions are:

    إضافة طلب
    إضافة عميل
    تسجيل دفعة
    إضافة مصروف

The primary Quick Action is:

    إضافة طلب

The Quick Actions should represent real actions that save navigation steps.

The Dashboard must not become a duplicate navigation menu.

Storage must not appear as a primary Quick Action.

Storage is an ongoing operational workflow with its own dedicated screen.

---

## 8. Create Order Shortcut

The Create Order action should be visually prominent because Order creation is one of the primary daily workflows.

Preferred action:

    إضافة طلب

The action should navigate directly to the Order Creation workflow.

The user should not need to open the Orders list first.

---

## 9. Add Customer Shortcut

The Dashboard should provide:

    إضافة عميل

The action should navigate directly to the Create Customer workflow.

The user should not need to open the Customers list first.

---

## 10. Record Payment Shortcut

The Dashboard should provide:

    تسجيل دفعة

The action should navigate directly to the relevant payment workflow.

The user should not be required to navigate through unrelated screens.

The payment workflow remains associated with an Order.

---

## 11. Add Expense Shortcut

The Dashboard should provide:

    إضافة مصروف

The action should navigate directly to the Expense creation workflow.

The user should not need to open Reports first.

The Expense workflow must allow the user to provide:

    المبلغ
    التصنيف
    التاريخ
    اسم المصروف when category = أخرى
    ملاحظات

The Expense is independent from Orders and Payments.

---

## 12. Quick Action Priority

The visual priority should be:

    1. إضافة طلب
    2. إضافة عميل
    3. تسجيل دفعة
    4. إضافة مصروف

The primary action should have stronger visual emphasis.

The remaining actions should remain clearly accessible without competing equally with the primary action.

The Dashboard should avoid presenting excessive numbers of actions.

---

## 13. Storage Is Not a Quick Action

Storage must not be presented as one of the primary Dashboard Quick Actions.

Storage is a continuous operational workflow.

The Dashboard may instead show:

    عناصر تحتاج تخزين
    طلبات تحتاج تخزين

inside the Attention Required section.

Selecting the Storage attention should navigate to the appropriate Storage context.

---

## 14. Operational Summary

The Dashboard should display concise operational metrics.

Approved V1 operational metrics include:

    طلبات اليوم
    قيد التنفيذ
    جاهزة للتسليم
    مبالغ متبقية

These metrics should represent useful operational information rather than decorative statistics.

The Dashboard should not introduce unrelated analytics metrics.

---

## 15. Today's Orders

The Dashboard should show:

    طلبات اليوم

The value represents the number of Orders created on the current business date.

The value should be based on local Order data.

The metric should use the application's business date rather than relying blindly on a remote server response.

Selecting the metric should navigate to the relevant Orders view when useful.

---

## 16. Processing Orders

The Dashboard should show the current number of Orders in:

    قيد التنفيذ

This represents Orders currently in Processing status.

The Dashboard must use the Domain/Application state as the source of truth.

The Dashboard must not independently redefine what Processing means.

---

## 17. Ready Orders

The Dashboard should show the current number of Orders in:

    جاهزة للتسليم

This should reflect the approved Ready business state.

The Dashboard must not independently calculate readiness.

The Domain/Application state remains the source of truth.

---

## 18. Outstanding Payments

The Dashboard should show concise information about Orders with outstanding payment amounts.

The relevant condition is:

    Remaining Amount > 0

The Dashboard may show either:

    عدد الطلبات ذات المبالغ المتبقية

or:

    إجمالي المبالغ المتبقية

The exact visual representation should remain concise.

Selecting the metric should navigate to an appropriate Orders/payment context.

---

## 19. Storage Attention

The Dashboard may display a compact indicator for storage work that requires attention.

Examples:

    عناصر تحتاج تخزين
    طلبات تحتاج تخزين

The exact metric should be based on the approved Storage workflow.

The Dashboard must not duplicate the full Storage screen.

---

## 20. Overdue Orders

The Dashboard may highlight Orders that are overdue.

An Order is overdue when:

    Expected Pickup Date < Today
        AND
    Status != Completed
        AND
    Status != Cancelled

Overdue information belongs in the Attention Required section rather than becoming a large analytics metric.

---

## 21. Today's Expected Pickups

The Dashboard may show a concise list or indicator for Orders whose Expected Pickup Date is today.

The displayed date must remain date-only.

Example:

    موعد الاستلام المتوقع
    26 أغسطس 2026

The Dashboard must not introduce pickup times or appointment scheduling.

---

## 22. Attention Required

A dedicated section should highlight items that require operator attention.

Possible approved conditions include:

    Orders awaiting storage
    Orders with remaining payment
    Overdue orders
    Today's expected pickups
    Synchronization requiring attention

Only meaningful actionable conditions should appear.

The section should remain short.

---

## 23. Attention Priority

Attention items should be ordered by operational importance.

Recommended priority:

    Critical / blocking action
        ↓
    Immediate operational action
        ↓
    Storage attention
        ↓
    Payment attention
        ↓
    Overdue / pickup information
        ↓
    Synchronization attention

The exact visual priority may be refined during final UI implementation while preserving the operational principle.

---

## 24. Recent Orders

The Dashboard may display a short list of recent or relevant Orders.

The list should remain intentionally limited.

Each Order summary may show:

    Order Number
    Customer Name
    Status
    Total
    Remaining
    Expected Pickup

The user can select an Order to open:

    تفاصيل الطلب

The Dashboard must not contain the complete Orders list.

---

## 25. Order Number Display

The Dashboard must display the approved human-readable Order Number.

The technical UUID must never be displayed as the primary Order identifier.

The Order Number should remain easy to recognize and consistent with the approved Order Number format.

---

## 26. Order Status

Order status should be displayed using the shared Design System status component.

V1 statuses are:

    Processing
    Ready
    Completed
    Cancelled

The status label must remain understandable without depending only on color.

---

## 27. Expected Pickup

Where Expected Pickup is displayed, it should use the approved date-only concept.

The Dashboard should not introduce time-based pickup scheduling.

Example:

    موعد الاستلام المتوقع
    26 أغسطس 2026

The exact Arabic date formatting is handled by the application's formatting utilities.

---

## 28. Financial Display

Financial values shown on the Dashboard must use the approved financial representation and display formatting.

The currency is:

    EGP
    ج.م

The Dashboard must not perform financial calculations independently.

It should display values supplied by the appropriate Application/Domain logic.

---

## 29. Expense Information on Dashboard

The Dashboard should not become a financial analytics screen.

The primary Expense-related Dashboard interaction is:

    إضافة مصروف

The Dashboard does not need to display:

    Total Expenses
    Net Profit
    Expense Category Breakdown

as primary Dashboard metrics.

These belong to the Financial Report.

If a future requirement introduces an Expense attention state, it must be explicitly approved.

---

## 30. Net Profit on Dashboard

Net Profit must not be a primary Dashboard metric in V1.

Net Profit belongs to:

    Reports
        ↓
    Financial Report

The Dashboard remains operational rather than analytical.

This prevents the Dashboard from becoming a duplicate Financial Report.

---

## 31. Dashboard Data Source

The Dashboard should primarily consume local application state.

Conceptually:

    Local Database
        ↓
    Repository
        ↓
    Dashboard State
        ↓
    UI

Remote synchronization should update local data rather than forcing the Dashboard to depend directly on the API.

---

## 32. Offline Behavior

The Dashboard must remain usable while offline.

When offline:

    Local operational information remains available.

The UI may show:

    غير متصل

or another subtle connectivity indicator.

The user must still be able to:

    View Orders
    View Customers
    View Storage
    Create Orders
    Record Payments
    Add Expenses
    Perform other locally supported workflows

according to the approved Offline-first architecture.

---

## 33. Synchronization Indicator

The Dashboard is an appropriate place for a subtle global synchronization indicator.

Possible states:

    متصل
    غير متصل
    جاري المزامنة
    توجد تغييرات غير متزامنة
    توجد مشكلة في المزامنة

The indicator should not dominate the Dashboard.

Technical synchronization details should remain hidden unless the user needs to take action.

---

## 34. Dashboard Refresh

The Dashboard should react to local data changes automatically when possible.

Examples:

    New Order created
        ↓
    طلبات اليوم updates

    Payment recorded
        ↓
    مبالغ متبقية updates

    Expense recorded
        ↓
    No primary Dashboard financial metric required
    Financial Report updates

    Storage completed
        ↓
    Storage Attention updates

    Order completed
        ↓
    Processing / Ready counts update

A manual refresh should not be required for normal local operations.

---

## 35. Empty Dashboard

The Dashboard must support a valid empty state.

For a new installation with no operational data, it may display:

    لا توجد طلبات حتى الآن

alongside the primary action:

    إضافة طلب

The empty state should guide the operator toward the first useful action.

Quick Actions should remain available even when there are no Orders.

---

## 36. Empty Operational Sections

Individual sections should also support empty states.

Examples:

    لا توجد طلبات تحتاج تخزين

    لا توجد طلبات مستحقة اليوم

    لا توجد مبالغ متبقية

The Dashboard should avoid displaying unnecessary empty cards if they provide no useful action.

---

## 37. Dashboard Loading State

Because the application is Offline-first, Dashboard loading should be minimal.

If local data is available:

    Render local data immediately.

If initial local data loading takes time:

    Use a lightweight loading state.

Do not display a long full-screen loading experience for every Dashboard visit.

---

## 38. Dashboard Error State

If Dashboard data cannot be loaded locally due to an unexpected application error, show a clear Arabic error state.

Example:

    تعذر تحميل بيانات الرئيسية

Provide a retry action when appropriate:

    إعادة المحاولة

Do not expose:

    SQLite errors
    Stack traces
    Dio exceptions
    Retrofit exceptions
    Supabase errors

directly to the user.

---

## 39. Synchronization Failure

A temporary synchronization failure must not prevent the Dashboard from displaying local data.

The Dashboard should continue showing the latest known local state.

The synchronization indicator may communicate:

    توجد مشكلة في المزامنة

The user should only be asked to take action when the failure requires meaningful intervention.

---

## 40. Dashboard Navigation

Dashboard elements that represent meaningful operational information should be actionable where useful.

Examples:

    طلبات اليوم
        ↓
    قائمة الطلبات

    قيد التنفيذ
        ↓
    Orders filtered by Processing

    جاهزة للتسليم
        ↓
    Orders filtered by Ready

    مبالغ متبقية
        ↓
    Orders with outstanding payment

    عناصر تحتاج تخزين
        ↓
    Storage context

    طلبات متأخرة
        ↓
    Orders filtered by overdue condition

    استلام اليوم
        ↓
    Orders filtered by today's Expected Pickup

Navigation should preserve the relevant filter/context.

---

## 41. Quick Action Navigation

Quick Actions should navigate directly to their intended workflows.

Examples:

    إضافة طلب
        ↓
    إنشاء طلب

    إضافة عميل
        ↓
    إنشاء عميل

    تسجيل دفعة
        ↓
    Relevant Payment workflow

    إضافة مصروف
        ↓
    إنشاء مصروف

The user should not be sent through unnecessary intermediate screens.

---

## 42. Dashboard Does Not Replace Reports

The Dashboard must not contain the full Reports experience.

Dashboard:

    Current operational overview

Reports:

    Historical / analytical information

Avoid adding:

    Complex charts
    Long financial tables
    Expense breakdown charts
    Net Profit analytics
    Advanced analytics

to the Dashboard.

---

## 43. Dashboard Does Not Replace Orders

The Dashboard should not contain the complete Orders list.

The Dashboard may show:

    A small relevant subset

The Orders screen remains responsible for:

    Full Order List
    Search
    Filtering
    Incremental Loading
    Order Management

---

## 44. Dashboard Does Not Replace Storage

The Dashboard may show:

    Storage attention summary

The Storage screen remains responsible for:

    Finding Items
    Assigning Locations
    Moving Items
    Reviewing Current Storage

---

## 45. Dashboard Does Not Replace Customers

The Dashboard may provide:

    Add Customer shortcut

The Customers screen remains responsible for:

    Customer Search
    Customer List
    Customer Details
    Customer Order History

---

## 46. Responsive Layout

The Dashboard must adapt to available screen size.

On larger tablet screens, summary information may be displayed in a responsive grid.

Conceptually:

    ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
    │ طلبات اليوم │ │ قيد التنفيذ │ │ جاهزة       │ │ مبالغ متبقية│
    └────────────┘ └────────────┘ └────────────┘ └────────────┘

Quick Actions should remain visually accessible without creating excessive horizontal density.

On smaller screens, the same information may stack vertically or use a responsive grid.

The business information remains the same.

---

## 47. RTL Layout

All Dashboard sections must follow RTL.

The visual hierarchy should naturally begin from the right side.

Cards, lists, metrics, and action groups must use:

    start
    end

rather than hardcoded left/right positioning where appropriate.

---

## 48. Typography

Dashboard typography must use:

    AppTextStyles

No screen-specific typography system should be created.

Hierarchy should clearly distinguish:

    Page Title
    Section Title
    Metric Value
    Metric Label
    Order Information
    Supporting Information

---

## 49. Colors

Dashboard colors must use:

    AppColors
    AppTheme

Semantic colors should be used for:

    Success
    Warning
    Error
    Information
    Primary Actions

No arbitrary color literals should be introduced.

---

## 50. Components

The Dashboard should reuse the approved Design System components.

Likely components include:

    AppCard
    AppButton
    StatusBadge
    EmptyState
    LoadingState
    ErrorState
    MetricCard
    OrderSummaryCard
    QuickActionCard

A new component should only be introduced if the Dashboard has a repeated or meaningful UI pattern that is not already covered by the Design System.

---

## 51. Metric Cards

Metric cards should be concise.

A metric card should generally contain:

    Metric Label
    Metric Value
    Optional Supporting Information
    Optional Navigation affordance

Avoid putting large amounts of text inside metric cards.

The approved primary operational metrics are:

    طلبات اليوم
    قيد التنفيذ
    جاهزة للتسليم
    مبالغ متبقية

---

## 52. Quick Action Cards

Quick Actions may use:

    Icon
    Arabic Label
    Optional Supporting Text

The primary action:

    إضافة طلب

should have clear visual priority.

The other approved actions:

    إضافة عميل
    تسجيل دفعة
    إضافة مصروف

should remain accessible without competing equally with the primary action.

Storage should not appear as a primary Quick Action.

---

## 53. Recent Order Item

A recent Order item should remain compact.

Recommended information:

    Order Number
    Customer
    Status
    Total / Remaining
    Expected Pickup when relevant

The user can open the complete Order Details screen for additional information.

---

## 54. Dashboard Accessibility

The Dashboard must:

- Maintain readable typography.
- Provide adequate touch/click targets.
- Not rely only on color for status.
- Provide meaningful labels for icons.
- Maintain sufficient contrast.
- Keep important information visually distinguishable.
- Preserve clear Arabic RTL hierarchy.
- Make primary actions easy to identify.
- Ensure Quick Actions have accessible labels.

---

## 55. Dashboard Performance

The Dashboard should be optimized for fast local rendering.

Avoid:

    Large remote queries
    Heavy calculations in widgets
    Unnecessary rebuilds
    Repeated database queries
    Blocking network requests

Where possible, derive Dashboard summaries efficiently from local data.

Dashboard financial and operational values should be calculated by the appropriate Application/Domain/Data Layer rather than by UI widgets.

---

## 56. Business Logic Boundary

The Dashboard must not determine business rules itself.

For example, it must not independently decide:

    Whether an Order is Ready
    Whether an Order is Completed
    Whether Payment is Allowed
    Whether an Order is Overdue
    Whether an Expense is valid
    How Net Profit is calculated

These decisions come from the Domain/Application layer.

The Dashboard only presents the resulting state.

---

## 57. API Boundary

The Dashboard must not directly call:

    Dio
    Retrofit
    Supabase
    Edge Functions

The approved flow remains:

    Dashboard
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local / Remote Data Source

The Dashboard should generally consume local repository state first.

---

## 58. Database Boundary

The Dashboard must not directly access:

    SQLite
    Drift
    SQL queries

All local data must be accessed through the approved Data Layer.

---

## 59. Dashboard State Model

The Dashboard should support the following conceptual states:

    Initial
    Loading
    Loaded
    Empty
    Error

It may also expose:

    Offline
    Syncing
    Sync Attention

These are presentation/application states and must not become new Domain states.

---

## 60. Expense Quick Action State

When the user selects:

    إضافة مصروف

the Dashboard should immediately navigate to the Expense creation workflow.

The Dashboard does not own the Expense form validation.

Expense validation belongs to the Expense Domain/Application workflow.

---

## 61. Dashboard After Expense Creation

After a successful local Expense creation:

    Expense Saved Locally
        ↓
    Expense Workflow Success
        ↓
    Return to Dashboard when appropriate

The Dashboard must remain operational immediately.

The Dashboard does not need to display the newly created Expense as a primary metric.

The Financial Report should reflect the Expense when the user opens the relevant reporting period.

---

## 62. Dashboard Financial Boundaries

The Dashboard may display:

    مبالغ متبقية

because outstanding customer payments are an operational concern.

The Dashboard should not display as primary metrics:

    Total Expenses
    Net Profit
    Expense Category Breakdown

These belong to the Financial Report.

This separation keeps the Dashboard operational and the Reports module analytical.

---

## 63. V1 Dashboard Scope

The Dashboard V1 should include:

    Page Header
    +
    Quick Actions
    +
    Operational Summary
    +
    Attention Required
    +
    Limited Recent Orders
    +
    Today's Pickup / Overdue context when relevant
    +
    Synchronization/Connectivity Indicator when appropriate

It should not include a large analytics suite.

---

## 64. Dashboard Information Priority

The visual hierarchy should generally follow:

    1. Primary Action
    2. Operational Problems / Attention
    3. Current Operational Summary
    4. Relevant Orders
    5. Secondary Information

The user should see what requires action before less important information.

---

## 65. Final Dashboard Principle

The Dashboard is an operational control center, not an analytics showcase.

Its purpose is to help the operator understand the current state of the laundry operation and immediately continue the next useful workflow.

The Dashboard should remain:

    Simple
        +
    Useful
        +
    Fast
        +
    Actionable
        +
    Consistent
        +
    Arabic-first
        +
    RTL
        +
    Offline-first

The Dashboard should make the most common daily actions immediately accessible:

    إضافة طلب
    إضافة عميل
    تسجيل دفعة
    إضافة مصروف

while keeping operational attention visible without turning the Dashboard into a second Reports, Orders, or Storage module.