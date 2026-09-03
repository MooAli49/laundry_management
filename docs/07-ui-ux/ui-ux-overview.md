# Laundry Management System — UI/UX Overview

## 1. Document Purpose

This document defines the V1 UI/UX direction for the Laundry Management System.

The purpose is to translate the approved Product, Domain, Architecture, Database, API, and Design System decisions into a consistent operational user experience.

This document defines:

- UI/UX principles
- Navigation direction
- Screen composition principles
- User-flow principles
- State handling
- Form behavior
- Feedback behavior
- Arabic and RTL requirements
- Responsive behavior
- Reusable UI patterns
- Operational workflow expectations

This document does not redefine business rules already approved in earlier phases.

---

## 2. UI/UX Source of Truth

The UI/UX layer must be based on the approved documentation:

    01-product/
    02-domain/
    03-architecture/
    04-database/
    05-api/
    06-design-system/

The UI must not invent new business behavior.

The UI represents and executes already-approved workflows and business rules.

When a UI requirement conflicts with an earlier approved business rule, the conflict must be resolved at the documentation level before implementation.

---

## 3. Primary UX Goal

The primary goal of the V1 interface is:

> Make daily laundry operations fast, clear, and difficult to misuse.

The system is an operational application rather than a consumer-facing application.

The UX should therefore prioritize:

    Speed
        +
    Clarity
        +
    Accuracy
        +
    Low Cognitive Load
        +
    Visibility of Operational State

---

## 4. Target User

V1 is designed around a single operational user.

The application does not implement:

    User Accounts
    Login
    Roles
    Permissions
    Employee Management

The interface therefore does not need user-selection or role-switching flows.

The user should be able to open the application and immediately access the operational workspace.

---

## 5. Arabic-first UX

The application UI language is:

    Arabic

Arabic is the primary language of the interface.

All user-facing labels, messages, buttons, statuses, forms, dialogs, and navigation should be designed in Arabic.

Technical identifiers remain English in the codebase.

Examples of user-facing terminology include:

    الطلبات
    العملاء
    التخزين
    المدفوعات
    التقارير
    الإعدادات

---

## 6. RTL-first Layout

The complete application uses:

    RTL

as the default layout direction.

Layouts should use:

    start
    end

instead of hardcoded:

    left
    right

where the relationship is directional.

Directional controls must be reviewed for RTL behavior.

Examples:

    رجوع
    التالي
    السابق
    فتح
    إغلاق

must visually and behaviorally follow RTL conventions.

---

## 7. Operational Navigation

Navigation should prioritize the most frequently used workflows.

The primary operational areas are:

    Dashboard
    Orders
    Storage
    Customers
    Reports
    Settings

The navigation structure should make the primary daily workflows accessible without unnecessary nesting.

---

## 8. Primary User Flow

The core daily workflow is:

    Dashboard
        ↓
    Create Order
        ↓
    Add Customer / Select Customer
        ↓
    Add Order Items
        ↓
    Select Services
        ↓
    Enter Required Measurements
        ↓
    Calculate Order
        ↓
    Save Order
        ↓
    Storage
        ↓
    Ready
        ↓
    Payment
        ↓
    Completed

The exact state transitions remain governed by the approved Domain and Business Rules.

---

## 9. Order Creation UX

Order creation is one of the most important workflows in the application.

The UX should minimize unnecessary navigation during order creation.

The user should be able to:

    Select Customer
        +
    Add Items
        +
    Select Services
        +
    Enter Measurements when required
        +
    Review Pricing
        +
    Apply Discount when permitted
        +
    Save Order

without leaving the primary Order Creation workflow unnecessarily.

---

## 10. Adding Multiple Physical Items

The UI may allow the user to enter multiple identical items together for convenience.

Example:

    قميص × 5

However, the application must create:

    5 independent OrderItems

internally.

The quantity is therefore an input convenience.

The UI must not expose this as if one OrderItem represents five physical pieces.

---

## 11. Order Item Entry

The Order Item entry interface should make the following information clear:

    Item Type
    Item Definition when applicable
    Service
    Pricing Type
    Required Measurement when applicable
    Unit Price
    Calculated Total
    Notes

Only fields relevant to the selected Item Type and Service should be shown.

The UI should avoid presenting irrelevant fields.

---

## 12. Pricing UX

The interface must adapt to the selected Pricing Type.

Supported V1 Pricing Types are:

    Per Piece
    Per Kilogram
    Per Square Meter
    Fixed Price

The user should not be required to understand the internal pricing implementation.

The interface should present the relevant input naturally.

Examples:

    Per Piece
        → Item count / physical items

    Per Kilogram
        → Weight

    Per Square Meter
        → Carpet dimensions / area

    Fixed Price
        → Fixed transaction price

The exact domain calculation remains outside the UI.

---

## 13. Carpet UX

Carpet orders require a dedicated interaction for dimensions.

The UI must support:

    Predefined Carpet Size
    +
    Custom Dimensions

When custom dimensions are used, the user enters:

    Length
    Width

The application calculates:

    Area = Length × Width

The historical dimensions and area are preserved as part of the transaction.

The UI should not force the user to manually enter the calculated area when it can be derived safely.

---

## 14. Customer Selection

The user should be able to:

    Search Customer
    Select Existing Customer
    Create New Customer

Customer search should prioritize:

    Phone
    Name

The user should not need to navigate to a separate Customers screen simply to create a customer during order creation.

---

## 15. Customer Creation During Order Flow

If the requested customer does not exist, the user should be able to create the customer without unnecessarily abandoning the Order Creation flow.

The exact UI pattern may be:

    Inline Form
    or
    Dialog
    or
    Bottom Sheet

The selected pattern must remain consistent with the Design System and should minimize workflow interruption.

---

## 16. Order Review

Before saving an Order, the user should have a clear summary containing:

    Customer
    Order Items
    Services
    Measurements when applicable
    Subtotal
    Discount when applicable
    Total

The review should make the final amount obvious.

Financial values must be displayed using the approved EGP formatting.

---

## 17. Order Number Presentation

After an Order is created, the generated Order Number should be highly visible.

V1 format:

    YY-XXX

Example:

    26-001

The Order Number is immutable.

It should be easy to:

    Read
    Search
    Copy
    Reference verbally

---

## 18. Order Status Presentation

The primary V1 statuses are:

    Processing
    Ready
    Completed
    Cancelled

The UI should communicate status consistently using the shared Design System.

Status must not rely on color alone.

The status label itself must remain visible.

---

## 19. Ready State UX

An Order becomes Ready only according to the approved business rules.

The UI should make the required operational conditions clear.

For example:

    Items Stored
        ↓
    Order Ready

The user should not need to infer readiness from unrelated fields.

Storage completion and Order readiness should be visually understandable.

---

## 20. Storage UX

Storage is a primary operational workflow.

The Storage screen should allow the user to quickly:

    Find Order Items
    Identify Items
    Assign Storage Locations
    Review Current Storage
    Move Items when required

The UI should optimize for speed because storage may involve many physical items during daily operation.

---

## 21. Storage from Order Flow

The approved workflow allows the user to add/store OrderItems from the Storage workflow.

The UI should make it possible to:

    Select Order
        ↓
    See its unstored Items
        ↓
    Assign Locations
        ↓
    Confirm Storage

The system should not require the user to repeatedly navigate between unrelated screens.

---

## 22. Current Storage State

The Storage interface should emphasize the current physical location of each item.

For an item:

    Current Location

is more important than historical movement information in V1.

V1 does not require a user-facing storage movement history workflow.

---

## 23. Payment UX

Payments are associated with Orders.

The user should be able to:

    View Order Total
    View Total Paid
    View Remaining Amount
    Add Payment
    View Payment History

Payment methods are:

    Cash
    InstaPay
    E-Wallet

The UI must not allow invalid payment amounts according to the approved business rules.

---

## 24. Payment History

Payments are historical transactions.

The UI should display them as separate records.

Example:

    Payment 1
    Payment 2
    Payment 3

The interface should not make one payment appear to have been edited into another payment.

---

## 25. Completion UX

An Order can only be completed when the approved completion conditions are satisfied.

The UI should clearly communicate missing requirements.

For example:

    Remaining Amount > 0
        → Payment still required

    Required items not stored
        → Storage still required

    Handover not confirmed
        → Confirmation still required

The user should understand why completion is unavailable.

---

## 26. Handover Confirmation

Before completing an Order, the user must explicitly confirm handover according to the approved business workflow.

This confirmation should be clear and intentional.

The action should not happen accidentally through navigation or background behavior.

---

## 27. Cancelled Orders

Cancellation is a business state, not a destructive deletion operation.

The UI should use language such as:

    إلغاء الطلب

rather than:

    حذف الطلب

when the intended action is cancellation.

Cancelled Orders should remain discoverable through appropriate search/filtering.

---

## 28. Order Editing

Editing must respect the approved business rules and Order status.

The UI must not expose actions that the Domain layer does not permit.

When an edit is not allowed, the UI should explain why rather than silently disabling the entire screen.

---

## 29. Dashboard UX

The Dashboard should focus on operational information.

The dashboard should prioritize:

    Today's Orders
    Orders Requiring Attention
    Processing Orders
    Ready Orders
    Pending Payments
    Storage-related Operational Information

The dashboard must remain concise.

It should not become a general-purpose analytics screen.

---

## 30. Reports UX

Reports were intentionally simplified during Product planning.

The Reports area should focus only on useful operational/business information approved in the Product documentation.

Avoid creating:

    Excessive Charts
    Redundant Metrics
    Unused Analytics
    Decorative Dashboards

Every report should answer a useful business question.

---

## 31. Customers UX

The Customers screen should support:

    Search
    View Customer
    Create Customer
    Edit Customer
    View Customer Orders

The interface should prioritize phone and name because they are primary customer identifiers in the workflow.

---

## 32. Settings UX

Settings should contain configuration relevant to the operational system.

Examples include:

    Business Information
    Pricing Configuration
    Services
    Item Types
    Storage Locations
    Other Approved Master Data

Settings must not expose technical infrastructure controls to the normal operational user.

---

## 33. Forms

Forms should follow a consistent structure:

    Section
        ↓
    Label
        ↓
    Input
        ↓
    Validation

Forms should minimize unnecessary fields.

Only information required by the selected workflow should be requested.

---

## 34. Validation UX

Validation should be:

    Immediate when useful
        +
    Clear
        +
    Local to the field when possible
        +
    Written in Arabic

Examples:

    رقم الهاتف مطلوب
    الخدمة مطلوبة
    الوزن يجب أن يكون أكبر من صفر
    الطول يجب أن يكون أكبر من صفر
    العرض يجب أن يكون أكبر من صفر

Validation must not expose technical database or API terminology.

---

## 35. Loading UX

Because the application is Offline-first, most local operations should feel immediate.

Avoid unnecessary full-screen loading indicators for fast local database operations.

Loading states are primarily required for:

    Remote Synchronization
    Initial Data Loading when necessary
    Expensive Operations

The UI should remain usable whenever possible.

---

## 36. Offline State UX

The application must make offline behavior understandable without making
offline mode feel like an error.

The user should be able to continue normal operations while offline.

The UI may provide a subtle connectivity/synchronization indicator.

Example states:

    متصل
    غير متصل
    جاري المزامنة
    توجد عمليات تحتاج للمزامنة

The exact visual treatment belongs to the Design System.

---

## 37. Synchronization Feedback

Synchronization should not interrupt normal daily operations.

When synchronization fails temporarily, the user should receive clear but non-disruptive feedback.

The UI should distinguish between:

    Waiting for synchronization
    Successfully synchronized
    Temporary sync failure
    Permanent sync failure requiring attention

Raw retry counts or technical queue details should not be exposed unless
they help the user resolve a problem.

---

## 38. Empty States

Every major collection screen should define an empty state.

Examples:

    لا يوجد عملاء
    لا توجد طلبات
    لا توجد نتائج بحث
    لا توجد مدفوعات
    لا توجد عناصر مخزنة

Empty states should provide an appropriate next action when one exists.

---

## 39. Error States

The UI must distinguish:

    Validation Errors
    Business Rule Errors
    Network Errors
    Synchronization Errors
    Unexpected Errors

The presentation should remain simple and actionable.

Examples:

    Business Rule Error
        → Explain what must change

    Network Error
        → Explain that synchronization will retry

    Unexpected Error
        → Provide a clear generic message

Do not expose stack traces or raw exception messages.

---

## 40. Search UX

Search should feel immediate.

Because normal operational data is local, search should primarily query
the local database.

Search interfaces should support:

    Clear Search
    Empty State
    No Results
    Loading when necessary
    Incremental Results

The user should not need to manually refresh the screen to see local
changes.

---

## 41. Filtering

Filters should be introduced only when they provide clear operational
value.

Common examples:

    Order Status
    Expected Pickup Date
    Payment State
    Storage State

Filters should be easy to clear.

The UI should visibly communicate active filters.

---

## 42. Navigation Consistency

Navigation behavior must remain predictable.

The user should know:

    Where they are
    Where they can go
    How to return
    What action is currently active

Avoid deep navigation stacks for common operational workflows.

---

## 43. Destructive Actions

Destructive or irreversible actions require appropriate confirmation.

Examples:

    Cancel Order
    Deactivate Master Data
    Remove important information

The confirmation should explain:

    What will happen
    Which entity is affected
    Whether the action can be reversed

The wording should remain Arabic and concise.

---

## 44. Success Feedback

Successful operations should provide lightweight feedback.

Examples:

    تم حفظ الطلب
    تم تسجيل الدفعة
    تم تخزين العناصر
    تم تحديث البيانات

Feedback should not unnecessarily block the user's next action.

---

## 45. Accessibility and Usability

The UI should maintain:

-   Readable typography
-   Adequate touch targets
-   Clear labels
-   Strong contrast
-   Consistent focus states
-   Status labels in addition to colors
-   Clear validation feedback

The system is operational software, so clarity is more important than
visual decoration.

---

## 46. Responsive Behavior

The UI must adapt to the available screen size.

The same workflow should remain understandable across:

    Desktop
    Tablet
    Smaller supported screens

Responsive behavior should use the approved Design System tokens and
components.

Do not create completely different business workflows for different
screen sizes unless required by usability.

---

## 47. Component Reuse

The UI should reuse Design System components.

Examples:

    AppButton
    AppTextField
    SearchField
    StatusBadge
    AppCard
    AppDialog
    EmptyState
    LoadingState

Feature-specific components may be created when they represent a real
domain-specific UI pattern.

---

## 48. No Business Logic in UI

The UI must not independently implement business rules.

For example, the UI must not determine:

    Order is Ready

by simply checking whether a list looks complete.

The Domain/Application layer determines business state.

The UI displays the resulting state.

---

## 49. No API Logic in UI

Screens and widgets must not directly call:

    Dio
    Retrofit
    Supabase
    Edge Functions

The flow remains:

    UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local / Remote Data Source

---

## 50. No Database Logic in UI

Screens must not directly access:

    SQLite
    Drift
    SQL queries

All persistence remains behind the approved architecture.

---

## 51. Screen State Model

Each screen should explicitly define its important states.

At minimum where applicable:

    Initial
    Loading
    Success
    Empty
    Error

Operational screens may also require:

    Offline
    Syncing
    Sync Failed
    Action Disabled

The state model should be defined per screen rather than applying every
possible state to every screen.

---

## 52. UX Decision Rule

When choosing between two valid UI patterns, prefer the option that:

1. Requires fewer steps.
2. Reduces cognitive load.
3. Keeps the user in the current workflow.
4. Makes important information visible.
5. Minimizes unnecessary navigation.
6. Reuses existing Design System components.
7. Works well in Arabic RTL.
8. Works offline.
9. Does not introduce new business rules.

---

## 53. AI Implementation Rule

When Antigravity implements a screen, it must first use:

    Product Documentation
        +
    Domain Documentation
        +
    Architecture Documentation
        +
    Database Documentation
        +
    API Documentation
        +
    Design System Documentation
        +
    UI/UX Documentation

It must not infer missing business requirements from visual design alone.

If a screen requirement is not documented, Antigravity should not invent
a new business behavior silently.

---

## 54. V1 UX Scope

The initial V1 UI/UX scope includes:

    Dashboard
    Orders
    Order Creation
    Order Details
    Storage
    Customers
    Payments
    Reports
    Settings

Each screen will be documented separately in the remaining Phase 07
files.

---

## 55. Final UI/UX Direction

The V1 UX is:

    Arabic-first
        +
    RTL
        +
    Operational
        +
    Fast
        +
    Offline-first
        +
    Clear
        +
    Low Cognitive Load
        +
    Reusable
        +
    Consistent
        +
    Responsive

The UI should help the operator complete real laundry workflows quickly
and accurately rather than maximizing the number of visible features.

---

## 56. Final Principle

> The interface should make the correct operational action obvious and the unnecessary action difficult.

Every screen should have a clear purpose.

Every major action should have a clear result.

Every important state should be visible.

Every repeated visual pattern should come from the Design System.

The UI/UX layer must remain a faithful expression of the approved Product
and Domain decisions rather than becoming a new source of business
rules.