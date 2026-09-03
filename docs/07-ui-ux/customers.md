# Laundry Management System — Customers UI/UX

## 1. Document Purpose

This document defines the V1 UI/UX requirements for the Customers feature.

The Customers feature is responsible for:

    Customer Search
    +
    Customer List
    +
    Customer Creation
    +
    Customer Details
    +
    Customer Editing
    +
    Customer Order History

The feature must follow the approved Product, Domain, Architecture,
Database, API, Design System, and UI/UX decisions.

---

## 2. Customers UX Goals

The Customers feature should allow the operator to:

    Find a Customer quickly
        +
    Create a Customer quickly
        +
    View Customer information
        +
    Edit Customer information
        +
    Review the Customer's Orders

The workflow should prioritize:

    Phone
    +
    Name

because these are the primary operational Customer identifiers.

---

## 3. Customers Navigation

The primary route is:

    العملاء

The conceptual structure is:

    العملاء
        ├── قائمة العملاء
        ├── إضافة عميل
        └── تفاصيل العميل

Customer creation must also be available from:

    إنشاء طلب

---

## 4. Customer List

The Customer List is the main entry point for existing Customers.

It should provide:

    Search
    +
    Customer List
    +
    Add Customer Action

The list should remain concise and operational.

---

## 5. Customer List Information

Each Customer row/card should show:

    Customer Name
    Customer Phone
    Number of Orders when useful
    Most Recent Order when useful

The UI should avoid displaying unnecessary Customer information in the
main list.

---

## 6. Customer Search

Search is a primary Customer workflow.

The search should support:

    Customer Name
    Customer Phone

Search should use local data first because the application is
Offline-first.

The user should receive results as quickly as possible.

---

## 7. Phone as Customer Identifier

Phone is a primary Customer identifier.

The UI should make the phone number easy to recognize and use.

Phone formatting should remain consistent across the application.

The technical database identity remains the Customer UUID.

The UUID must not be shown as the primary Customer identifier.

---

## 8. Customer Creation

The primary action is:

    إضافة عميل

The Customer creation form should request only information required by
the approved Customer model.

The form should remain short and fast.

---

## 9. Customer Creation Fields

The V1 Customer form should support the approved Customer fields.

At minimum, the workflow centers around:

    الاسم
    رقم الهاتف

Additional fields should only be displayed when they exist in the
approved Product/Domain model.

The UI must not invent additional Customer profile fields.

---

## 10. Customer Creation from Order

A Customer may be created directly during Order Creation.

Preferred flow:

    إنشاء طلب
        ↓
    اختيار العميل
        ↓
    إضافة عميل
        ↓
    حفظ العميل
        ↓
    Customer automatically selected
        ↓
    Continue Order Creation

The user should not have to manually search for the newly created
Customer again.

---

## 11. Customer Creation Context

When creating a Customer from an Order, the Customer form should feel
like part of the current Order workflow.

The user should be able to return to:

    إنشاء طلب

without losing already entered Order information.

---

## 12. Duplicate Customer Prevention

The system should prevent accidental duplicate Customers.

The primary uniqueness field is:

    Phone

If a Customer with the same phone already exists, the UI should guide
the operator toward the existing Customer.

Example:

    يوجد عميل مسجل بهذا الرقم

The UI may provide:

    عرض العميل
    اختيار العميل

rather than silently creating a duplicate.

---

## 13. Customer Validation

The UI should provide clear Arabic validation.

Examples:

    اسم العميل مطلوب
    رقم الهاتف مطلوب
    رقم الهاتف غير صحيح

The Domain layer remains the final authority for validation.

The UI must not expose raw backend or database validation errors.

---

## 14. Customer Details

The Customer Details screen should provide a concise view of:

    Customer Name
    Customer Phone
    Customer Order History

The screen should prioritize information useful during daily operations.

---

## 15. Customer Header

The Customer Details header should prominently display:

    Customer Name
    Customer Phone

The header should remain simple.

---

## 16. Customer Actions

Available Customer actions may include:

    تعديل العميل
    إنشاء طلب

The exact action availability must follow the approved Domain rules.

---

## 17. Create Order from Customer

Customer Details should provide a shortcut:

    إنشاء طلب

The flow should preselect the current Customer.

Conceptually:

    تفاصيل العميل
        ↓
    إنشاء طلب
        ↓
    Customer already selected

This avoids unnecessary Customer search.

---

## 18. Customer Order History

Customer Details should display the Customer's Orders.

The history should be concise.

Each Order item may show:

    Order Number
    Date
    Status
    Total
    Remaining

The user can select an Order to open:

    تفاصيل الطلب

---

## 19. Customer Order History Search

V1 does not require a separate advanced search system inside Customer
Order History.

If the history becomes large, simple filtering/pagination may be used
according to the approved Orders UI behavior.

The primary Orders search remains in:

    الطلبات

---

## 20. Order Navigation from Customer

Selecting an Order from Customer Details should navigate to the existing
Order Details screen.

Conceptually:

    تفاصيل العميل
        ↓
    طلبات العميل
        ↓
    تفاصيل الطلب

The application must not create a second version of Order Details.

---

## 21. Customer Editing

The user may edit Customer information through:

    تعديل العميل

The form should reuse the same Customer input components used during
Customer Creation.

This ensures consistent validation and behavior.

---

## 22. Customer Phone Editing

Because Phone is a primary Customer identifier, changing it should be
handled carefully.

The UI should validate the new phone value and prevent duplicate
Customers according to the approved uniqueness rule.

The system must not silently merge two Customers.

---

## 23. Customer Deletion

The Customers UI should not provide a normal destructive:

    حذف العميل

workflow unless explicitly supported by the approved Domain rules.

Historical Orders depend on Customer identity.

Therefore Customer deletion must not be introduced casually as a UI
feature.

If the approved lifecycle later supports deactivation, the UI should use
the approved business terminology instead.

---

## 24. Customer Historical Data

Customer information shown alongside historical Orders must not alter
the historical transaction values that belong to the Order.

For example, changing the Customer's current name does not rewrite
historical OrderItem snapshots.

The UI should display the current Customer information where the
relationship is current.

Historical transaction data remains governed by the Domain model.

---

## 25. Customer List Empty State

If there are no Customers:

    لا يوجد عملاء حتى الآن

Primary action:

    إضافة عميل

The empty state should guide the operator toward creating the first
Customer.

---

## 26. Customer Search Empty State

If a search returns no Customers:

    لا توجد نتائج مطابقة

The user should be able to:

    Clear Search

and return to the full Customer List.

---

## 27. Customer Loading State

Customer data should load from the local database first.

Loading should be lightweight.

Avoid unnecessary full-screen loading indicators.

For incremental lists, a bottom loading indicator may be used.

---

## 28. Customer Error State

If the Customer List cannot be loaded due to an unexpected local
failure:

    تعذر تحميل العملاء

Provide:

    إعادة المحاولة

Raw database, API, Dio, Retrofit, or Supabase errors must not be shown
directly to the user.

---

## 29. Offline Customers

The Customers feature must remain usable while offline.

The operator should be able to:

    Search Customers
    View Customers
    Create Customers
    Edit Customers

according to the approved local workflow.

Remote synchronization is independent from normal Customer usage.

---

## 30. Customer Sync State

A newly created or edited Customer may be waiting for synchronization.

The UI may show a subtle state:

    في انتظار المزامنة

A temporary synchronization failure must not make the local Customer
appear deleted or invalid.

---

## 31. Customer Synchronization Failure

If remote synchronization fails:

    Customer remains available locally.

The user may see:

    توجد مشكلة في المزامنة

when appropriate.

Retry behavior remains part of the synchronization layer.

---

## 32. Customer Search Performance

Search should be optimized for fast operational use.

Primary local search fields:

    Name
    Phone

The UI should not wait for the remote backend for normal search.

---

## 33. Customer List Performance

The Customer List should support incremental loading when required.

The user should not need to navigate through numbered pages during
normal operation.

---

## 34. Customer Sorting

The default Customer List may prioritize:

    Recently used
    or
    Alphabetical order

The exact default should be selected during implementation based on
operational usefulness.

The UI should not expose technical database sorting concepts.

---

## 35. Customer and Order Workflow

The Customer feature must integrate naturally with Orders.

Primary cross-feature workflows:

    Customers
        ↓
    Customer Details
        ↓
    Create Order

and:

    Orders
        ↓
    Create Order
        ↓
    Select Customer
        ↓
    Create Customer if needed

The same Customer components should be reused in both flows.

---

## 36. Customer Selection Component

The Customer selection experience inside Order Creation should support:

    Search
    +
    Existing Customer Selection
    +
    Add Customer

The component should prioritize:

    Name
    Phone

The selected Customer should remain clearly visible after selection.

---

## 37. Customer Selection State

The Customer selector should support:

    Empty
    Searching
    Results
    Selected
    No Results
    Error

The exact presentation belongs to the shared component/screen design.

---

## 38. Customer Details and Order Creation

When launching Order Creation from Customer Details:

    Customer ID

should be passed through the navigation/application state.

The UI should use the stable Customer UUID internally.

The displayed Customer identity remains:

    Name
    Phone

---

## 39. Customer Navigation

Important navigation paths include:

    العملاء
        ↓
    تفاصيل العميل

    العملاء
        ↓
    إضافة عميل

    تفاصيل العميل
        ↓
    تعديل العميل

    تفاصيل العميل
        ↓
    إنشاء طلب

    تفاصيل العميل
        ↓
    تفاصيل الطلب

The Back action should preserve the previous context.

---

## 40. Customer Routes

Technical routes should use stable UUID identifiers.

Conceptually:

    /customers
    /customers/{customerId}
    /customers/new

The UUID is the technical identifier.

The UI should not use the Customer Name or Phone as the route identity.

---

## 41. Design System Usage

The Customers feature must use:

    AppColors
    AppTextStyles
    AppTheme
    Shared Components

Likely shared components include:

    SearchField
    AppTextField
    AppButton
    AppCard
    AppDialog
    EmptyState
    LoadingState
    ErrorState

Feature-specific components may be created when they represent a real
Customer-specific UI pattern.

---

## 42. RTL Requirements

The Customers feature must be fully RTL.

Important areas include:

    Search
    Forms
    Customer Cards
    Customer Details
    Order History
    Dialogs
    Action Buttons

Use:

    start
    end

rather than hardcoded directional positioning where appropriate.

---

## 43. Typography

Customer screens must use:

    AppTextStyles

No screen-specific typography system should be created.

Customer names and phone numbers should have a clear visual hierarchy.

---

## 44. Colors

Customer screens must use:

    AppColors
    AppTheme

No arbitrary color literals should be introduced.

Semantic colors should only be used where they communicate meaningful
state.

---

## 45. Accessibility

The Customers feature should provide:

-   Clear labels
-   Readable Arabic typography
-   Adequate input sizes
-   Clear validation
-   Sufficient contrast
-   Clear action hierarchy
-   Accessible search and selection controls

Phone numbers should remain easy to read and interact with.

---

## 46. Responsive Behavior

The Customers feature must support:

    Desktop
    Tablet
    Smaller supported screens

On larger screens, a table or dense list may be appropriate.

On smaller screens, cards or compact list rows may provide a better
experience.

The business workflow remains the same.

---

## 47. Customer State Model

The Customer List should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

Customer Creation should support:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

Customer Details should support:

    Loading
    Loaded
    Empty Order History
    Error
    Offline
    Syncing

---

## 48. No Business Logic in UI

The Customers UI must not determine business rules.

For example, it must not independently decide:

    Whether a Customer is unique
    Whether an Order can be created
    Whether an Order belongs to a Customer

These decisions belong to the Domain/Application layer.

The UI displays and collects information according to those rules.

---

## 49. No Infrastructure Access

The Customers UI must not directly access:

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

## 50. Customer Data Integrity

The UI should help preserve:

    One Customer
        ↓
    Many Orders

Orders must retain their relationship to the correct Customer.

The UI must not offer a casual merge or reassignment workflow unless it
is explicitly approved in the Domain/Product documentation.

---

## 51. Customer Information Density

The Customers feature should avoid becoming a CRM system.

V1 should focus on information needed for laundry operations:

    Name
    Phone
    Orders

Additional Customer profile features should only be introduced when
approved by Product scope.

---

## 52. Final Customer UX Principle

> Finding, creating, and selecting a Customer should take as few steps as
> possible while preserving Customer identity and preventing duplicates.

The Customer workflow should integrate naturally with Order Creation and
should remain fast and usable even when the application is offline.