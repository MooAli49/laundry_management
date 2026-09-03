# Laundry Management System — Navigation

## 1. Document Purpose

This document defines the V1 navigation structure for the Laundry Management System.

The navigation must provide fast access to the application's main operational areas while keeping the number of navigation levels low.

The navigation is based on the approved Product, Domain, Architecture, API, Design System, and UI/UX decisions.

---

## 2. Navigation Principles

The V1 navigation follows these principles:

    Simple
        +
    Operational
        +
    Shallow
        +
    Predictable
        +
    RTL-first
        +
    Fast access to frequent workflows

The user should not need to navigate through multiple unnecessary screens to complete common daily operations.

---

## 3. Primary Navigation Areas

The main application areas are:

    الرئيسية
    الطلبات
    التخزين
    العملاء
    التقارير
    الإعدادات

These represent the primary navigation destinations.

---

## 4. Navigation Hierarchy

The navigation should remain shallow.

Conceptually:

    Application
        ├── الرئيسية
        ├── الطلبات
        │   ├── قائمة الطلبات
        │   ├── إنشاء طلب
        │   └── تفاصيل الطلب
        ├── التخزين
        ├── العملاء
        │   ├── قائمة العملاء
        │   └── تفاصيل العميل
        ├── التقارير
        └── الإعدادات

The exact sub-navigation is handled by each feature.

---

## 5. Main Navigation

The main navigation should provide direct access to:

    الرئيسية
    الطلبات
    التخزين
    العملاء
    التقارير
    الإعدادات

The navigation must clearly indicate the currently active destination.

---

## 6. Dashboard

The Dashboard is the primary operational landing screen.

Route concept:

    /

or an equivalent application root route.

The Dashboard provides:

    Operational Summary
    +
    Quick Actions
    +
    Important Current States

The Dashboard is not a replacement for the Orders or Storage screens.

---

## 7. Orders Navigation

The Orders section is the primary transaction workflow.

Conceptual navigation:

    الطلبات
        ↓
    قائمة الطلبات
        ├── إنشاء طلب
        └── تفاصيل الطلب
              ├── تعديل
              ├── التخزين
              └── المدفوعات

The user should be able to move from the Order list to a specific Order without losing the surrounding context.

---

## 8. Order List

The Order List is the primary entry point for existing Orders.

It should provide:

    Search
    Filtering where useful
    Order Number
    Customer
    Status
    Expected Pickup
    Payment State where useful

The list should support incremental loading when required.

---

## 9. Create Order Navigation

Creating an Order should be accessible directly from the Orders section.

Primary flow:

    الطلبات
        ↓
    إضافة طلب

The user should remain within the Order Creation workflow while:

    Selecting Customer
    Adding Items
    Adding Services
    Entering Measurements
    Reviewing Pricing
    Saving the Order

---

## 10. Customer Selection During Order Creation

The Order Creation flow should allow:

    Select Existing Customer
    or
    Create New Customer

The user should not be forced to leave the Order Creation workflow just to create a missing Customer.

The exact interaction may use:

    Dialog
    Bottom Sheet
    Inline Section

according to the final screen design.

---

## 11. Order Details

After selecting an Order:

    الطلبات
        ↓
    تفاصيل الطلب

The Order Details screen is the central location for viewing the transaction.

It may provide access to:

    Order Items
    Customer
    Pricing
    Storage
    Payments
    Order Actions

The screen must not become a replacement for the dedicated Storage or Reports sections.

---

## 12. Order Actions

Order actions should be available from the Order Details context when
permitted by the Domain rules.

Examples:

    تعديل الطلب
    التخزين
    إضافة دفعة
    إكمال الطلب
    إلغاء الطلب

Actions that are not valid for the current Order state must not be
presented as normal available actions.

---

## 13. Storage Navigation

Storage is a primary operational destination.

Primary route:

    التخزين

The Storage screen should allow the operator to work directly with
unstored or stored OrderItems.

The user should not need to open every Order individually to perform
normal storage operations.

---

## 14. Storage from Order Details

Order Details may provide a shortcut to the relevant Storage workflow.

Conceptually:

    تفاصيل الطلب
        ↓
    التخزين

The shortcut should open the Storage context relevant to that Order.

The dedicated Storage section remains available independently.

---

## 15. Customers Navigation

Primary route:

    العملاء

Conceptual structure:

    العملاء
        ├── قائمة العملاء
        └── تفاصيل العميل

Customer Details may provide access to the customer's Orders.

Conceptually:

    تفاصيل العميل
        ↓
    طلبات العميل
        ↓
    تفاصيل الطلب

---

## 16. Customer Creation

A new Customer may be created from:

    العملاء

and from:

    إنشاء طلب

The same Customer creation component/form should be reused whenever
possible.

This avoids having two different Customer creation experiences.

---

## 17. Customer Details

Customer Details should provide a concise overview of:

    Customer Information
    +
    Relevant Order History

The screen should not duplicate the complete Order Details interface.

Selecting an Order should navigate to its existing Order Details screen.

---

## 18. Reports Navigation

Primary route:

    التقارير

Reports should remain separate from the Dashboard.

The Dashboard presents:

    Current operational information

Reports present:

    Historical / analytical information

The Reports section must remain intentionally simplified according to
the Product decisions.

---

## 19. Settings Navigation

Primary route:

    الإعدادات

Settings contain approved operational configuration and master data.

Examples may include:

    بيانات النشاط
    الخدمات
    أنواع القطع
    تعريفات القطع
    مواقع التخزين
    مقاسات السجاد
    إعدادات أخرى معتمدة

Technical configuration should not be exposed as normal operational
settings.

---

## 20. Back Navigation

Back navigation must preserve user context whenever possible.

Examples:

    Order List
        ↓
    Order Details
        ↓
    Back
        ↓
    Order List

The user should return to the previous context rather than being
unexpectedly redirected to the Dashboard.

---

## 21. Unsaved Changes

When leaving a screen containing meaningful unsaved changes, the
application should warn the user before discarding them.

Example:

    التغييرات لم يتم حفظها.
    هل تريد الخروج؟

Actions:

    متابعة التعديل
    خروج بدون حفظ

The confirmation should only appear when there are actual meaningful
unsaved changes.

---

## 22. Navigation During Order Creation

Order Creation should minimize unnecessary route changes.

The preferred behavior is:

    Create Order
        ↓
    Complete Order workflow
        ↓
    Save
        ↓
    Order Details

The user should not be redirected through unrelated application areas
during normal Order creation.

---

## 23. Navigation After Saving an Order

After successful Order creation, the preferred destination is:

    تفاصيل الطلب

This allows the user to immediately review:

    Order Number
    Customer
    Items
    Total
    Storage Status
    Payment Status

From there, the user can continue the next operational action.

---

## 24. Navigation After Storage

After successful storage operations, the user should remain in the
relevant operational context.

For example:

    Storage
        ↓
    Store Items
        ↓
    Storage Updated

The application should not unnecessarily return to the Dashboard.

---

## 25. Navigation After Payment

After successfully recording a Payment, the user should remain within
the relevant Order context.

Preferred flow:

    Order Details
        ↓
    Add Payment
        ↓
    Payment Saved
        ↓
    Order Details

The updated:

    Total Paid
    Remaining

should be immediately visible.

---

## 26. Navigation After Completion

After completing an Order, the user may return to:

    Order List

or remain in:

    Order Details

The exact behavior should be determined by the final screen UX, but it
must preserve clear confirmation that the Order has been completed.

---

## 27. Navigation After Cancellation

After cancelling an Order, the application should clearly show the new
status.

The preferred behavior is to return to the relevant Order context or
Order List depending on the action flow.

The user must not mistake cancellation for deletion.

---

## 28. Search Navigation

Search should generally be embedded inside the relevant collection
screen.

Examples:

    الطلبات
        → Search Orders

    العملاء
        → Search Customers

    التخزين
        → Search Storage Items

A separate global Search screen is not required for V1.

---

## 29. Deep Links and Direct Navigation

V1 does not require a public deep-linking system.

Internal navigation may still use route parameters for:

    Order ID
    Customer ID

The route must use the stable entity ID rather than relying on the
human-readable Order Number as the technical identifier.

---

## 30. Route Identity

Technical navigation should use stable identifiers.

Example:

    /orders/{orderId}

rather than:

    /orders/{orderNumber}

The displayed Order Number remains:

    YY-XXX

but the stable UUID remains the technical entity identity.

---

## 31. Navigation State

Navigation state should not be confused with Domain state.

For example:

    Current Screen
    Selected Tab
    Open Dialog
    Expanded Section

are UI/navigation states.

They must not become persistent business state unless explicitly
required.

---

## 32. Offline Navigation

Navigation must remain fully functional while the application is
offline.

The user must be able to navigate to locally available:

    Orders
    Customers
    Storage
    Reports
    Settings

without requiring a network connection.

Remote synchronization must happen independently from normal navigation.

---

## 33. Synchronization Indicator

The application may provide a global synchronization indicator.

Possible states include:

    متصل
    غير متصل
    جاري المزامنة
    توجد تغييرات غير متزامنة
    توجد مشكلة في المزامنة

The indicator should be subtle and must not dominate the main
operational navigation.

---

## 34. Navigation and Permissions

V1 has no user roles or permissions.

Therefore navigation does not need to dynamically hide destinations
based on user roles.

All V1 operational areas are available to the single operational user.

---

## 35. Navigation and Business Rules

Navigation must respect Domain rules.

For example, the UI may navigate to an Order Details screen even when an
Order cannot currently be completed.

However, the completion action itself must follow the Domain rules.

Navigation must not bypass business validation.

---

## 36. Navigation and Design System

Navigation components must use the centralized Design System.

This includes:

    Colors
    Typography
    Spacing
    Icons
    Active State
    Hover State
    Selected State
    Responsive Behavior

No feature should create its own navigation styling.

---

## 37. Desktop Navigation

On larger screens, the application may use a persistent navigation
sidebar.

Conceptually:

    ┌──────────────┬──────────────────────────────┐
    │              │                              │
    │  الرئيسية    │                              │
    │  الطلبات     │         Content              │
    │  التخزين     │                              │
    │  العملاء     │                              │
    │  التقارير    │                              │
    │  الإعدادات   │                              │
    │              │                              │
    └──────────────┴──────────────────────────────┘

The sidebar must follow RTL conventions.

---

## 38. Smaller Screens

On smaller supported screens, navigation may adapt to a more compact
pattern such as:

    Bottom Navigation

or another approved responsive navigation pattern.

The exact responsive navigation component will be defined during screen
design.

The business hierarchy must remain the same.

---

## 39. Navigation Labels

Navigation labels must use concise Arabic terminology.

Preferred:

    الرئيسية
    الطلبات
    التخزين
    العملاء
    التقارير
    الإعدادات

Avoid unnecessarily long labels that make the navigation harder to scan.

---

## 40. Navigation Icons

Each primary destination may have a recognizable icon.

Icons should support quick recognition but must not be the only
identifier.

The Arabic label should remain visible in the primary navigation where
space allows.

Directional icons must behave correctly in RTL.

---

## 41. Active Navigation State

The active destination must be visually distinguishable.

The active state should use the centralized Design System.

The user should always understand which major section is currently open.

---

## 42. Navigation Error Handling

If navigation to a requested entity fails because the entity is no
longer available locally, the UI should provide a clear message.

Example:

    تعذر فتح الطلب

The UI must not expose raw routing exceptions.

---

## 43. Navigation After App Restart

The application may restore the last meaningful navigation state when
appropriate.

However, restoration must not violate business workflow expectations.

For example, the application should not automatically reopen an
unsaved form if doing so could expose stale or discarded input.

The exact restoration strategy may be defined during implementation.

---

## 44. Navigation Performance

Navigation between local screens should feel immediate.

Avoid unnecessary remote requests during route transitions.

A screen should load its local state first when possible and synchronize
independently.

---

## 45. V1 Navigation Summary

The primary navigation is:

    الرئيسية
    الطلبات
    التخزين
    العملاء
    التقارير
    الإعدادات

The most important operational workflow is:

    الرئيسية
        ↓
    الطلبات
        ↓
    إنشاء طلب
        ↓
    تفاصيل الطلب
        ↓
    التخزين / المدفوعات
        ↓
    إكمال الطلب

The navigation remains shallow and operational.

---

## 46. Final Navigation Principles

The V1 navigation follows:

    Arabic-first
        +
    RTL
        +
    Shallow hierarchy
        +
    Fast operational access
        +
    Offline availability
        +
    Clear active state
        +
    Context-preserving back navigation
        +
    Stable entity-based routes
        +
    No role-based navigation
        +
    No unnecessary global navigation

---

## 47. Final Principle

> Navigation should help the operator move between workflows, not become
> a workflow itself.

The user should spend as little time navigating as possible and as much
time completing the actual laundry operation as possible.