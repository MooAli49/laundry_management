# Laundry Management System — Screen States

## 1. Document Purpose

This document defines the standard UI states used across the V1 Laundry Management System.

The purpose is to ensure that all screens behave consistently when they are:

    Loading
    Loaded
    Empty
    Searching
    Saving
    Error
    Offline
    Synchronizing
    Waiting for Synchronization

The screen-state system must remain:

    Simple
        +
    Consistent
        +
    Arabic-first
        +
    RTL
        +
    Tablet-first
        +
    Offline-first

The application must not create a completely different state pattern for every feature.

---

# 2. State Design Principles

Every feature should clearly communicate:

    What is happening?
    What can the user do?
    Whether the operation succeeded?
    Whether data exists?
    Whether the application is offline?
    Whether synchronization is pending?

The UI should never leave the user wondering whether an action:

    Is still processing
    Failed
    Succeeded
    Has been saved locally
    Is waiting for synchronization

---

# 3. Standard State Categories

The application uses the following general state categories:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Validation Error
    Saving
    Success
    Error
    Offline
    Syncing
    Sync Pending
    Sync Attention

Not every screen needs every state.

Each feature should implement only the states that are meaningful for its workflow.

---

# 4. Initial State

Initial state represents a screen before its first meaningful data load or interaction.

The Initial state should generally be short-lived.

The UI should not expose technical initialization details.

Example:

    Screen opens
        ↓
    Initial
        ↓
    Loading
        ↓
    Loaded / Empty / Error

For Offline-first screens, if local data is immediately available, the application should minimize or skip visible Loading time.

---

# 5. Loading State

Loading indicates that the screen is retrieving or calculating data.

The preferred loading behavior is lightweight.

Use:

    Skeleton
    Progress Indicator
    Loading Placeholder

where appropriate.

Avoid unnecessarily replacing the entire screen with a blocking loader when existing local data can remain visible.

---

# 6. Local-first Loading

Because the application is Offline-first:

    Local Data
        ↓
    Should be displayed as soon as practical

The application should not wait for:

    Internet
    Remote API
    Synchronization

before displaying available local information.

This applies especially to:

    Dashboard
    Orders
    Customers
    Storage
    Reports

---

# 7. Loaded State

Loaded means that valid data has been retrieved and can be displayed.

The Loaded state may contain:

    Data
    Filters
    Search State
    Pagination State
    Sync State

The screen should clearly present the primary content without exposing technical details.

---

# 8. Empty State

Empty means the feature has no data for the current context.

Empty is not an error.

Examples:

    No Orders
    No Customers
    No Storage Items
    No Expenses
    No Report Data

The Empty state should explain what is missing and, where useful, provide the next meaningful action.

---

# 9. Empty State Structure

A standard Empty state may contain:

    Icon / Illustration
    Title
    Supporting Message
    Primary Action when useful

Example:

    لا توجد طلبات حتى الآن

    ابدأ بإضافة أول طلب إلى النظام.

    + إضافة طلب

The exact visual component must use the centralized Design System.

---

# 10. Empty State Rules

Empty states should:

- Be concise.
- Use Arabic.
- Explain the current condition.
- Avoid technical terminology.
- Provide a useful action when appropriate.
- Not look like an error.
- Not imply that data was deleted.

---

# 11. No Search Results State

No Search Results is different from Empty.

Example:

    Search Query:
    أحمد

    Result:
    لا توجد نتائج

The screen should allow the user to:

    Clear Search

or modify the search query.

It should not display:

    إضافة عميل

unless adding a new entity is genuinely useful in that context.

---

# 12. Filtered Empty State

A filtered screen may contain data in general but none matching the active filter.

Example:

    Status:
    جاهز

    Result:
    لا توجد طلبات مطابقة

The user should be able to:

    Clear Filter

or change the filter.

The UI must distinguish this from a completely empty database.

---

# 13. Error State

Error indicates that the application could not complete a required operation.

Errors should be presented in clear Arabic.

Example:

    تعذر تحميل البيانات

    حاول مرة أخرى.

    إعادة المحاولة

The error UI must not expose:

    Stack Traces
    SQL Errors
    Dio Errors
    Retrofit Errors
    Supabase Errors
    Internal Exception Names

---

# 14. Error State Actions

The available action depends on the situation.

Possible actions:

    إعادة المحاولة
    إلغاء
    إغلاق
    العودة

The user should not be given an action that cannot resolve the current problem.

---

# 15. Network Error

A network failure is not automatically a screen Error in an Offline-first system.

If local data exists:

    Network Failure
        ↓
    Local Data
        ↓
    Continue Working

The application may show:

    غير متصل

or:

    في انتظار الاتصال

The user should remain able to continue supported local operations.

---

# 16. Offline State

Offline indicates that the device currently has no usable internet connection.

Offline does not mean:

    Application Error

The UI should communicate the state subtly.

Example:

    غير متصل

The application should continue using local data.

---

# 17. Offline with Local Data

Preferred behavior:

    Offline
        +
    Local Data Available

Result:

    Display Local Data
        +
    Allow Local Operations
        +
    Queue Synchronization

The user should not be blocked.

---

# 18. Offline with No Local Data

If the application is offline and there is no local data available for the requested screen, the UI may show:

    لا توجد بيانات متاحة حاليًا

with an optional:

    إعادة المحاولة

The message must explain that the data is unavailable rather than implying that the business has no data.

---

# 19. Saving State

Saving indicates that the user submitted a local mutation.

Examples:

    إنشاء طلب
    تعديل طلب
    تسجيل دفعة
    إضافة مصروف
    تعديل خدمة
    إضافة تصنيف مصروف

The UI should prevent accidental duplicate submissions.

The primary action may become disabled while saving.

---

# 20. Saving Must Be Local-first

For supported Offline-first operations:

    User Action
        ↓
    Local Transaction
        ↓
    Success

The user should receive success after the local operation is successfully persisted.

The UI must not require remote synchronization before treating the local action as successful.

---

# 21. Saving Indicator

While saving, the UI may display:

    جاري الحفظ...

The exact component should follow the Design System.

Avoid long blocking states for simple local operations.

---

# 22. Success State

Success means the requested local operation completed successfully.

Examples:

    Order Created
    Payment Recorded
    Expense Added
    Customer Updated
    Storage Updated

Success feedback should be concise.

Possible examples:

    تم حفظ الطلب بنجاح

    تم تسجيل الدفعة بنجاح

    تم إضافة المصروف بنجاح

---

# 23. Success and Navigation

After a successful operation, navigation should follow the feature-specific workflow.

Examples:

    Create Order
        ↓
    Success
        ↓
    Order Details

    Add Payment
        ↓
    Success
        ↓
    Order Details

    Storage Operation
        ↓
    Success
        ↓
    Stay in Storage Context

    Add Expense
        ↓
    Success
        ↓
    Return to the appropriate previous context

The application should not automatically redirect to Dashboard unless the approved workflow requires it.

---

# 24. Unsaved Changes State

When a user leaves a screen containing meaningful unsaved changes, the application should warn them.

Example:

    التغييرات لم يتم حفظها.
    هل تريد الخروج؟

Actions:

    متابعة التعديل
    خروج بدون حفظ

This warning should only appear when meaningful changes actually exist.

---

# 25. Validation Error

Validation errors indicate that the user input does not satisfy the required business/form rules.

Validation should be shown as close as possible to the affected field.

Examples:

    الاسم مطلوب

    رقم الهاتف مطلوب

    المبلغ يجب أن يكون أكبر من صفر

    التصنيف مطلوب

    اسم المصروف مطلوب عند اختيار أخرى

---

# 26. Validation vs Error

Validation errors are user-correctable.

Example:

    Amount = 0

The user can correct the value.

A system Error is different.

Example:

    Database transaction unexpectedly failed

The UI should not present technical system failures as ordinary form validation.

---

# 27. Form State

Forms should support:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error

The exact state model may be implemented using Cubit/Bloc.

---

# 28. Order List States

The Orders List should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

The Loaded state should support:

    Search
    Filters
    Pagination / Incremental Loading

---

# 29. Order Creation States

Order Creation should support:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

The user should be able to continue editing when validation fails.

---

# 30. Order Details States

Order Details should support:

    Loading
    Loaded
    Error
    Offline
    Syncing
    Sync Attention

If local Order data exists, it should be displayed while synchronization occurs.

---

# 31. Customer List States

Customers should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

Search should not require remote connectivity.

---

# 32. Customer Creation States

Customer Creation should support:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

Required Customer fields should be validated before saving.

---

# 33. Customer Details States

Customer Details should support:

    Loading
    Loaded
    Error
    Offline
    Syncing
    Sync Attention

Customer Order History may independently show:

    Loading
    Loaded
    Empty
    Error

---

# 34. Storage List States

Storage should support:

    Initial
    Loading
    Loaded
    Empty
    No Search Results
    Error
    Offline
    Syncing
    Sync Attention

The screen may distinguish between:

    Items Requiring Storage

and:

    Currently Stored Items

---

# 35. Storage Empty States

If there are no items requiring storage:

    لا توجد عناصر تحتاج إلى تخزين

If there are no currently stored items:

    لا توجد عناصر مخزنة حاليًا

The exact wording may be refined in the final UI while preserving the meaning.

---

# 36. Storage Operation States

Storage operations should support:

    Ready
    Saving
    Success
    Validation Error
    Error
    Offline

Examples:

    Store Item
    Bulk Store
    Move Item

The operation must preserve the Storage business rules.

---

# 37. Storage Move State

When moving an item:

    Current Location
        ↓
    New Location
        ↓
    Saving
        ↓
    Success

The UI should clearly confirm the new active location.

Example:

    تم نقل القطعة إلى B-02

The system must not show two active locations for the same physical item.

---

# 38. Payment States

Payment workflows should support:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error
    Offline
    Sync Pending

The payment is considered locally successful once it is persisted locally according to the Offline-first architecture.

---

# 39. Payment Validation States

Payment validation must clearly communicate:

    Payment Amount Required

    Payment Amount > Remaining
        ↓
    Rejected

The user should understand the current remaining amount before entering the payment.

---

# 40. Payment Success

After a successful local Payment:

    تم تسجيل الدفعة بنجاح

The Order Details screen should immediately reflect:

    Total Paid
    Remaining

The user should remain in the relevant Order context.

---

# 41. Expense List States

Expense management may be accessed through:

    Reports
        ↓
    Financial Report
        ↓
    Expenses

The Expense list should support:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Error
    Offline
    Syncing
    Sync Attention

---

# 42. Expense Empty State

When no Expenses exist for the current context:

    لا توجد مصروفات

The screen should provide the relevant action where appropriate:

    + إضافة مصروف

The empty state should not imply that an error occurred.

---

# 43. Expense Creation States

Expense Creation should support:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error
    Offline
    Sync Pending

The Expense must be saved locally before remote synchronization is required.

---

# 44. Expense Form Validation

The Expense form must validate:

    Amount > 0

    Category selected

    Date selected

    If Category = أخرى:
        Custom Name required

Notes remain optional.

---

# 45. Expense "Other" State

When the user selects:

    أخرى

the form must reveal:

    اسم المصروف

The field becomes required.

Example:

    التصنيف
    أخرى

    اسم المصروف *
    إصلاح باب المحل

If the user changes the Category from:

    أخرى

to another category, the Custom Name field may be cleared or hidden according to the final form UX.

---

# 46. Expense Date State

Expense Date uses:

    Date Picker

The user must not manually type a date.

Preferred display:

    25 أغسطس 2026

The date remains date-only.

---

# 47. Expense Save Success

After a successful local Expense creation:

    تم إضافة المصروف بنجاح

The Expense becomes immediately available in local Financial Reports.

The user must not wait for remote synchronization before seeing the local financial result.

---

# 48. Expense Synchronization State

An Expense may be:

    Saved Locally
        ↓
    Waiting for Synchronization

The UI may communicate this subtly.

Example:

    في انتظار المزامنة

This does not mean the Expense failed.

---

# 49. Expense Synchronization Error

If the backend rejects an Expense synchronization operation:

    Local Expense
        ↓
    Remains Preserved
        ↓
    Sync Attention

The UI should not delete the Expense.

The user should be informed only when action is actually required.

---

# 50. Expense Category List States

Expense Category Management belongs under:

    Settings

The list should support:

    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Categories should show their active/inactive state.

---

# 51. Expense Category Empty State

If no Expense Categories exist:

    لا توجد تصنيفات مصروفات

Provide:

    + إضافة تصنيف

where appropriate.

The initial seed categories should normally prevent this state on a fresh installation.

---

# 52. Expense Category Form States

Category creation/editing should support:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error

Required field:

    اسم التصنيف

---

# 53. Expense Category Duplicate Error

If the user attempts to create a duplicate Category:

    اسم التصنيف موجود بالفعل

The category should not be duplicated.

The user should remain able to correct the value.

---

# 54. Expense Category Deactivation State

When deactivating a Category:

    Confirmation
        ↓
    Saving
        ↓
    Success

The UI should make it clear that:

    Inactive categories cannot be selected for new Expenses.

Historical Expenses remain valid.

---

# 55. Expense Category Inactive Display

Inactive Categories should remain distinguishable.

Example:

    منظفات
    نشط

    نقل
    غير نشط

The visual treatment must not rely only on color.

---

# 56. Reports States

The Reports module should support:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Reports must continue to use local data while offline.

---

# 57. Orders Report Empty State

If the selected period contains no Orders:

    لا توجد طلبات خلال هذه الفترة

The report should still allow the user to change the selected period.

---

# 58. Financial Report Empty State

If the selected period contains no financial transactions:

    لا توجد بيانات مالية خلال هذه الفترة

The report should still display meaningful zero values where appropriate.

Example:

    إجمالي المبيعات
    0 ج.م

    إجمالي المدفوعات
    0 ج.م

    إجمالي المصروفات
    0 ج.م

    المبالغ المتبقية
    0 ج.م

    صافي الربح
    0 ج.م

---

# 59. Reports and No Expenses

If there are Sales but no Expenses:

    Total Sales > 0
    Total Expenses = 0

then:

    Net Profit = Total Sales

The UI must not treat the absence of Expenses as an Error.

---

# 60. Reports Filter Loading

When changing the report period, the UI should provide feedback that the report is updating.

Avoid unnecessary full-screen transitions.

Preferred behavior:

    Current Report
        ↓
    Period Changed
        ↓
    Lightweight Loading
        ↓
    Updated Report

---

# 61. Dashboard States

Dashboard should support:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

The Dashboard should remain operational even when remote synchronization is unavailable.

---

# 62. Dashboard Empty State

A new installation with no Orders may display:

    لا توجد طلبات حتى الآن

and:

    إضافة طلب

Quick Actions should remain available.

---

# 63. Dashboard Operational Attention State

The Dashboard may display attention items such as:

    Orders requiring storage
    Outstanding payments
    Overdue orders
    Today's expected pickups
    Synchronization requiring attention

Only actionable or meaningful information should be shown.

---

# 64. Dashboard No Attention State

If there are no attention items:

    لا توجد مهام تتطلب الانتباه

This state should be subtle.

The Dashboard should not look empty simply because everything is operating normally.

---

# 65. Settings States

Settings should support:

    Loading
    Loaded
    Saving
    Success
    Validation Error
    Error
    Offline
    Syncing
    Sync Attention

Settings should remain locally editable according to the approved Offline-first scope.

---

# 66. Services States

Services & Pricing should support:

    Loading
    Loaded
    Empty
    No Search Results
    Validation Error
    Saving
    Success
    Error
    Offline
    Syncing
    Sync Attention

The same general state conventions apply to:

    Services
    Item Types
    Item Definitions
    Carpet Sizes
    Service Compatibility

---

# 67. Master Data Deactivation States

Master data that supports activation/deactivation should use:

    Active
    Inactive

The UI must distinguish:

    Current selectable data

from:

    Historical references

Deactivation must not remove historical transaction data.

---

# 68. Confirmation Dialog State

Confirmation dialogs should only be used for meaningful destructive or state-changing actions.

Examples:

    Deactivate Category
    Cancel Order
    Discard Unsaved Changes

The dialog should clearly state:

    What will happen?
    What are the available choices?

Actions should use clear Arabic labels.

---

# 69. Destructive Confirmation

For destructive or irreversible actions, the UI should not rely on vague labels such as:

    OK

Prefer:

    إلغاء الطلب
    تعطيل التصنيف
    خروج بدون حفظ

The action label should describe the actual result.

---

# 70. Delete Behavior

V1 avoids hard deletion of historical business records.

Therefore, screen states should not generally present:

    Delete Order
    Delete Payment
    Delete Expense

as normal destructive operations.

Where a record is configurable master data, use:

    Activate
    Deactivate

when the Domain model supports it.

---

# 71. Sync Status

The application may expose a global synchronization state.

Possible states:

    متصل
    غير متصل
    جاري المزامنة
    في انتظار المزامنة
    توجد مشكلة في المزامنة

The exact indicator may appear in:

    Dashboard
    Relevant Feature Screens
    Global App Shell

The UI should remain subtle.

---

# 72. Syncing State

Syncing means local pending changes are currently being synchronized.

The user may see:

    جاري المزامنة

The UI must not block normal local operations.

The user should still be able to navigate and work.

---

# 73. Sync Pending State

Pending synchronization means:

    Local Operation Successful
        +
    Remote Synchronization Not Yet Completed

This is not an Error.

Example:

    تم الحفظ
    في انتظار المزامنة

The local operation remains successful.

---

# 74. Sync Attention State

Sync Attention means that a synchronization operation requires attention because it cannot be silently completed.

The application may show:

    توجد مشكلة في المزامنة

The local business data must remain preserved.

The exact conflict/recovery UX is intentionally simple in V1.

---

# 75. Sync Failure Principle

Synchronization failure must never:

    Delete Local Data
    Roll Back a Successful Local Business Operation
    Block Normal Offline Operation

The local database remains the operational source of truth.

---

# 76. Loading and Syncing Are Different

Loading means:

    The screen is obtaining data for display.

Syncing means:

    Local and remote data are being reconciled.

A screen may therefore be:

    Loaded
        +
    Syncing

at the same time.

The UI should not replace loaded content with a blank loading screen just because synchronization is occurring.

---

# 77. Success and Sync Pending Are Different

A locally successful operation can simultaneously be:

    Success
        +
    Pending Synchronization

Example:

    Expense saved locally
        ↓
    Expense appears in Financial Report
        ↓
    Remote sync pending

This is the expected Offline-first behavior.

---

# 78. Error and Offline Are Different

Offline is not necessarily an Error.

Example:

    Internet unavailable
        +
    Local database available

Result:

    Continue normally

An actual Error should indicate that the application cannot complete the requested local operation or cannot provide the required local state.

---

# 79. Error Recovery

Every recoverable Error should provide an appropriate recovery path.

Examples:

    تعذر تحميل البيانات
        ↓
    إعادة المحاولة

    تعذر حفظ التغييرات
        ↓
    إعادة المحاولة

    Invalid Form
        ↓
    Correct Fields

The application should avoid dead-end error states.

---

# 80. Error Messaging

Error messages must be:

    Arabic
    Clear
    Short
    Actionable

Avoid:

    Technical exception names
    HTTP status codes
    Database error strings
    Internal IDs
    Stack traces

Example:

    تعذر حفظ المصروف.
    حاول مرة أخرى.

is preferable to exposing an API exception.

---

# 81. Toast / Snackbar Usage

Transient success or informational feedback may use:

    Snackbar
    Toast
    Inline Feedback

The exact component should follow the Design System.

Important business errors should not rely only on a disappearing message.

---

# 82. Inline Validation

Form validation should appear near the relevant input when possible.

Example:

    المبلغ *
    [ 0 ]

    المبلغ يجب أن يكون أكبر من صفر

This reduces confusion and avoids forcing the user to search for the problem.

---

# 83. Disabled Action State

A primary action may be disabled when:

    Required Fields Missing
    Invalid Form
    Saving in Progress

However, the UI should still make it clear what information is required.

Do not silently disable an action without providing understandable feedback.

---

# 84. Button Loading State

When a button triggers a save operation:

    Save
        ↓
    Loading

The button may show:

    جاري الحفظ...

or a progress indicator.

The user should not be able to accidentally trigger duplicate local operations.

---

# 85. Modal State

Dialogs and bottom sheets should support:

    Opening
    Editing
    Validation
    Saving
    Success / Close
    Error

The user should not lose meaningful form input because of an unrelated transient state.

---

# 86. Date Picker State

Date Picker interactions should support:

    Closed
    Open
    Date Selected
    Confirmed
    Cancelled

Dates should be displayed in Arabic-friendly format.

Manual date typing is not the preferred V1 pattern.

---

# 87. Date Validation State

For date ranges:

    Start Date <= End Date

If invalid:

    تاريخ البداية يجب أن يكون قبل أو مساويًا لتاريخ النهاية

The user must be able to correct the range.

---

# 88. Pagination / Incremental Loading

Long lists may use incremental loading.

Possible states:

    Initial Loading
    Loaded
    Loading More
    Loaded More
    No More Results
    Error Loading More

The screen should preserve already loaded data while loading additional records.

---

# 89. Search During Loading

Search should not unnecessarily clear already visible local data.

Preferred behavior:

    Existing Results
        ↓
    Search
        ↓
    Update Local Results

If loading additional results is necessary, show lightweight progress.

---

# 90. Search Error

If a local search fails unexpectedly:

    تعذر تنفيذ البحث

Provide:

    إعادة المحاولة

Do not display technical database errors.

---

# 91. List Refresh

Manual refresh, where provided, should:

    Keep existing data visible where possible
        ↓
    Refresh local state
        ↓
    Update UI

A refresh should not automatically force a remote API request unless the synchronization architecture explicitly requires it.

---

# 92. Screen State Consistency

The same conceptual state should look similar across features.

For example:

    Empty Orders
    Empty Customers
    Empty Expenses

should use the same EmptyState component and visual conventions.

Similarly:

    Error Orders
    Error Customers
    Error Reports

should use the same ErrorState pattern.

---

# 93. Design System Integration

Screen states must use the centralized Design System.

Use shared components for:

    Loading
    Empty
    Error
    Buttons
    Dialogs
    Status Badges
    Inputs
    Date Pickers
    Cards

Do not create independent visual systems for individual features.

---

# 94. Accessibility

All states must remain accessible.

The UI must:

- Use readable Arabic labels.
- Maintain sufficient contrast.
- Not rely only on color.
- Provide accessible action labels.
- Maintain appropriate touch targets.
- Clearly communicate state changes.
- Preserve RTL layout.
- Avoid flashing or rapidly changing visual states unnecessarily.

---

# 95. Arabic-first Requirement

All user-facing state messages must be Arabic.

Examples:

    جاري التحميل...

    لا توجد بيانات

    لا توجد نتائج

    تعذر تحميل البيانات

    إعادة المحاولة

    جاري الحفظ...

    تم الحفظ بنجاح

    غير متصل

    جاري المزامنة

    في انتظار المزامنة

    توجد مشكلة في المزامنة

---

# 96. RTL Requirement

All state components must support RTL.

Icons that communicate directional meaning must be reviewed carefully for RTL behavior.

The implementation should use logical layout properties rather than hardcoded left/right positioning.

---

# 97. Tablet-first Requirement

Screen states must be designed primarily for tablet use.

Loading, Empty, Error, and Confirmation states should use the available tablet space appropriately without becoming oversized.

The UI should remain responsive for smaller supported screens.

---

# 98. No Technical State Leakage

The following must never appear as normal user-facing screen states:

    HTTP 500
    SocketException
    DioException
    RetrofitException
    SQLiteException
    SQL error
    Supabase error
    Stack trace
    UUID
    Sync operation ID

Technical details belong to logs/debugging, not normal UI.

---

# 99. State Transition Principle

A typical local mutation follows:

    Editing
        ↓
    Validation
        ↓
    Saving
        ↓
    Local Success
        ↓
    Sync Pending
        ↓
    Syncing
        ↓
    Synced

If remote synchronization fails:

    Sync Pending
        ↓
    Sync Attention / Retryable Failure

The local business operation remains successful.

---

# 100. Read Flow State

A typical read flow follows:

    Initial
        ↓
    Loading
        ↓
    Loaded

or:

    Initial
        ↓
    Loading
        ↓
    Empty

or:

    Initial
        ↓
    Loading
        ↓
    Error

When local data already exists:

    Loaded
        +
    Syncing

is valid.

---

# 101. Search Flow State

A typical search flow follows:

    Loaded
        ↓
    Search
        ↓
    Results

or:

    Loaded
        ↓
    Search
        ↓
    No Results

The original list should remain recoverable by:

    Clear Search

---

# 102. Filter Flow State

A typical filter flow follows:

    Loaded
        ↓
    Filter Applied
        ↓
    Filtered Results

or:

    Filter Applied
        ↓
    No Matching Results

The user should be able to:

    Clear Filter

---

# 103. Order State Summary

Order List:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Error
    Offline
    Syncing
    Sync Attention

Order Creation:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

Order Details:

    Loading
    Loaded
    Error
    Offline
    Syncing
    Sync Attention

---

# 104. Customer State Summary

Customer List:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Error
    Offline
    Syncing
    Sync Attention

Customer Creation:

    Initial
    Editing
    Validation Error
    Saving
    Saved
    Error

Customer Details:

    Loading
    Loaded
    Empty Order History
    Error
    Offline
    Syncing
    Sync Attention

---

# 105. Storage State Summary

Storage List:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Error
    Offline
    Syncing
    Sync Attention

Storage Operations:

    Ready
    Saving
    Success
    Validation Error
    Error
    Offline

---

# 106. Payment State Summary

Payment Form:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error
    Offline
    Sync Pending

Payment History:

    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

---

# 107. Expense State Summary

Expense List:

    Initial
    Loading
    Loaded
    Empty
    No Results
    Error
    Offline
    Syncing
    Sync Attention

Expense Creation:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error
    Offline
    Sync Pending

---

# 108. Expense Category State Summary

Category List:

    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Category Form:

    Initial
    Editing
    Validation Error
    Saving
    Success
    Error

Category Deactivation:

    Confirmation
    Saving
    Success
    Error

---

# 109. Reports State Summary

Orders Report:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Financial Report:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Report Filtering:

    Ready
    Updating
    Updated
    Validation Error

---

# 110. Dashboard State Summary

Dashboard:

    Initial
    Loading
    Loaded
    Empty
    Error
    Offline
    Syncing
    Sync Attention

Attention Section:

    Has Attention
    No Attention

Quick Actions:

    Ready
    Saving / Navigating

---

# 111. Settings State Summary

Settings:

    Loading
    Loaded
    Saving
    Success
    Validation Error
    Error
    Offline
    Syncing
    Sync Attention

Settings should preserve unsaved changes appropriately.

---

# 112. Services State Summary

Services & Pricing:

    Loading
    Loaded
    Empty
    No Results
    Editing
    Validation Error
    Saving
    Success
    Error
    Offline
    Syncing
    Sync Attention

The same general pattern applies to related master-data screens.

---

# 113. State Naming Principle

State names in code should describe meaningful UI/application conditions.

Prefer:

    OrdersLoading
    OrdersLoaded
    OrdersEmpty
    OrdersError

over generic states that hide feature meaning.

Avoid creating a massive global state class that contains unrelated feature states.

---

# 114. State Management Architecture

Screen state should be managed through:

    Cubit
    or
    Bloc

depending on feature complexity.

The approved application flow remains:

    UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Data Source

Screen widgets must not directly access:

    Database
    SQL
    Dio
    Retrofit
    Supabase

---

# 115. State and Domain Boundaries

UI states must not become Domain entities.

For example:

    Loading
    Empty
    Error
    Syncing

are Presentation/Application concerns.

They must not be added to the Order Domain model or Expense Domain model.

---

# 116. State and Business Statuses

Business statuses remain separate from UI states.

Order business statuses are:

    Processing
    Ready
    Completed
    Cancelled

UI state may be:

    Loading
    Loaded
    Error

These concepts must not be mixed.

Example:

    Order Status = Ready

while:

    Screen State = Loaded

This is valid.

---

# 117. State and Synchronization

Synchronization status is also separate from business status.

Example:

    Order Status = Ready
    Screen State = Loaded
    Sync State = Pending

This is valid.

The UI should be able to represent these dimensions independently.

---

# 118. Final State Principles

The V1 screen-state system follows:

    Local-first
        +
    Clear feedback
        +
    Consistent components
        +
    Arabic-first
        +
    RTL
        +
    Minimal blocking
        +
    Recoverable errors
        +
    Separate business and UI states
        +
    Separate offline and error states
        +
    Separate success and synchronization states

The most important principle is:

    A successful local business operation is still successful
    even when remote synchronization is pending.

The application should therefore communicate:

    تم الحفظ
        +
    في انتظار المزامنة

rather than treating the operation as failed.

---

# 119. Final V1 Screen-State Checklist

Every feature should be reviewed against the following checklist:

    Does it have a Loading state?

    Does it have a Loaded state?

    Does it have a meaningful Empty state?

    Does it distinguish Empty from No Search Results?

    Does it show user-correctable Validation Errors?

    Does it show Saving state for mutations?

    Does it show Success feedback?

    Does it show recoverable Error state?

    Does it work Offline?

    Does it communicate Syncing when useful?

    Does it distinguish Sync Pending from Error?

    Does it preserve local data when synchronization fails?

    Does it use Arabic messages?

    Does it follow RTL?

    Does it use shared Design System components?

    Does it avoid exposing technical errors?

    Does it preserve user context after successful operations?

---

# 120. Final Principle

The V1 UI should always make the current application state understandable.

The user should be able to tell whether:

    Data is loading
    Data exists
    No data exists
    Search returned nothing
    Input is invalid
    A local operation is being saved
    An operation succeeded
    An operation failed
    The device is offline
    Data is waiting for synchronization
    Synchronization is running
    Synchronization needs attention

without seeing technical implementation details.

The final state model is:

    Initial
        ↓
    Loading
        ↓
    Loaded / Empty / Error

For mutations:

    Editing
        ↓
    Validation
        ↓
    Saving
        ↓
    Local Success
        ↓
    Sync Pending
        ↓
    Syncing
        ↓
    Synced

With offline operation:

    Offline
        ↓
    Continue Local Operation
        ↓
    Queue Sync
        ↓
    Sync When Available

With synchronization failure:

    Local Success
        ↓
    Sync Failure
        ↓
    Preserve Local Data
        ↓
    Retry / Sync Attention

This state model is the approved V1 foundation for consistent behavior across the Laundry Management System.