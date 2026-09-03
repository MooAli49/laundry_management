# Laundry Management System — Components

## 1. Document Purpose

This document defines the centralized component system for the Laundry
Management System.

The component system provides reusable UI building blocks for:

    Navigation
    +
    Forms
    +
    Buttons
    +
    Cards
    +
    Lists
    +
    Tables
    +
    Statuses
    +
    Dialogs
    +
    Feedback
    +
    Operational Workflows

The goal is to ensure that the entire application uses a consistent
visual and interaction language.

---

## 2. Component Principles

Components must be:

    Reusable
    +
    Consistent
    +
    Accessible
    +
    RTL-aware
    +
    Responsive
    +
    Easy to maintain
    +
    Compatible with the Design System

Components should represent real reusable UI patterns.

Do not create abstractions only for the sake of abstraction.

---

## 3. Component Architecture

The component hierarchy is:

    Design Tokens
        ↓
    Foundation Components
        ↓
    Shared Components
        ↓
    Feature Components
        ↓
    Screens

Examples:

    Colors / Typography / Spacing
        ↓
    Button / TextField / Card
        ↓
    SearchField / StatusBadge / MetricCard
        ↓
    OrderItemCard / StorageItemCard
        ↓
    Order Screen

---

## 4. Component Naming

Components should use clear semantic names.

Examples:

    AppButton
    AppTextField
    AppCard
    AppDialog
    SearchField
    StatusBadge
    EmptyState
    LoadingState

Avoid names based on appearance.

Incorrect:

    BlueButton
    BigCard
    RoundedBox

Correct:

    PrimaryButton
    MetricCard
    CustomerCard

---

## 5. Component Variants

Variants should be defined when the same component has meaningful
different states or purposes.

Example:

    AppButton
        Primary
        Secondary
        Destructive
        Text
        Disabled

Do not create separate components when a variant is enough.

---

## 6. Button System

The application uses a centralized button system.

Primary button:

    Main action

Secondary button:

    Supporting action

Destructive button:

    Irreversible / dangerous action

Text button:

    Low-emphasis action

Disabled button:

    Temporarily unavailable

---

## 7. AppButton

The primary reusable button component.

Supported properties conceptually:

    label
    icon
    variant
    size
    enabled
    loading
    onPressed

The component must support RTL.

---

## 8. Primary Button

Use for:

    إضافة طلب
    حفظ
    تأكيد الدفع
    تخزين
    إنشاء عميل

The Primary button should have the strongest visual emphasis.

---

## 9. Secondary Button

Use for:

    إلغاء
    تعديل
    إجراءات مساعدة

Secondary buttons should not compete with the primary action.

---

## 10. Destructive Button

Use for:

    إلغاء الطلب
    تعطيل الخدمة
    تعطيل موقع التخزين

Destructive actions should use the centralized Error semantic colors.

---

## 11. Loading Button

When an action is being processed:

    Disable duplicate interaction
        +
    Show loading indicator
        +
    Preserve button context

Example:

    جاري الحفظ...

Do not replace the entire screen with a loading state for a small action.

---

## 12. Icon Button

Icon buttons are used for compact actions.

Examples:

    Edit
    Search
    More
    Back
    Close

Icon buttons must provide a sufficient touch target.

They must have accessible labels.

---

## 13. Text Button

Use for low-emphasis actions.

Examples:

    إلغاء
    مسح الفلاتر
    عرض المزيد

Do not use Text Buttons for the primary action of a workflow.

---

## 14. Button Sizes

The component system should support:

    Small
    Medium
    Large

Recommended primary operational size:

    Medium

Large buttons may be used for major actions.

Small buttons should be used carefully because the system is tablet-first.

---

## 15. AppTextField

The standard text input component.

It should support:

    Label
    Hint
    Placeholder
    Leading Icon
    Trailing Icon
    Error
    Helper Text
    Enabled / Disabled
    Read-only
    Required

The component must support Arabic RTL.

---

## 16. TextField States

Supported states:

    Default
    Focused
    Filled
    Error
    Disabled
    Read-only

Each state must use the centralized color system.

---

## 17. TextField Label

Labels must remain outside or clearly associated with the input.

Example:

    اسم العميل

    [ محمد أحمد ]

Required fields may use an approved required indicator.

---

## 18. TextField Error

Error text should appear directly below the affected field.

Example:

    رقم الهاتف غير صحيح

The error must not be communicated through border color alone.

---

## 19. SearchField

SearchField is a specialized reusable input.

It should support:

    Search Icon
    +
    Search Text
    +
    Clear Action
    +
    Loading State where needed

Primary use cases:

    Orders
    Customers
    Storage
    Settings

---

## 20. SearchField Behavior

The search field should provide fast local search where the feature
supports Offline-first searching.

The clear action should immediately remove the current search query.

Search should not unnecessarily block the rest of the screen.

---

## 21. Dropdown / Select

The standard selection component should support:

    Label
    +
    Current Value
    +
    Options
    +
    Error
    +
    Disabled State

Use for:

    Pricing Type
    Payment Method
    Status Filters
    Service Selection
    Storage Location

---

## 22. Selection Components

Selection components may use:

    Dropdown
    Radio
    Segmented Control
    Bottom Sheet

The choice depends on:

    Number of Options
    Available Space
    Interaction Frequency
    Context

Do not use a large dropdown for a very small set of frequently used
choices when a simpler selection component is better.

---

## 23. Checkbox

Checkboxes are used for:

    Multi-selection
    Filters
    Selecting multiple physical OrderItems

Checkboxes must clearly communicate:

    Unselected
    Selected
    Disabled

They must remain touch-friendly.

---

## 24. Radio Selection

Radio controls are used for mutually exclusive choices.

Examples:

    Payment Method
    Pricing Type
    Single selection options

Only one option can be selected within the same group.

---

## 25. Switch

Switches may be used for:

    Active / Inactive
    Enabled / Disabled

Example:

    الخدمة مفعلة

The switch must not be used where the action has destructive or
high-risk consequences without confirmation.

---

## 26. AppCard

AppCard is the standard content container.

It should support:

    Default
    Elevated
    Selected
    Interactive
    Disabled
    Semantic

Cards should use centralized:

    Radius
    +
    Padding
    +
    Border
    +
    Shadow

---

## 27. Interactive Card

Interactive cards should provide a clear interaction state.

Examples:

    Customer Card
    Order Card
    Storage Item Card

The user should understand that the entire card or a specific action is
interactive.

---

## 28. MetricCard

MetricCard displays a summarized operational or financial metric.

Structure:

    Label
        ↓
    Value
        ↓
    Optional Supporting Information

Examples:

    طلبات اليوم
    25

    المبالغ المتبقية
    3,250.00 ج.م

MetricCard should support:

    Default
    Success
    Warning
    Info

when semantic treatment is useful.

---

## 29. StatusBadge

StatusBadge displays a short semantic status.

Examples:

    قيد التنفيذ
    جاهز للتسليم
    مكتمل
    ملغي

It should support:

    Success
    Warning
    Error
    Info
    Neutral

The label must remain visible.

---

## 30. StatusBadge Rules

StatusBadge should:

    Be compact
    +
    Be readable
    +
    Use semantic colors
    +
    Work in RTL
    +
    Not depend only on color

Do not use StatusBadge for long descriptions.

---

## 31. OrderItemCard

OrderItemCard represents an individual physical OrderItem.

It may display:

    Item Type
    +
    Service
    +
    Measurements
    +
    Price
    +
    Storage Status

If the Order contains multiple physical items, each item must remain
visually distinguishable.

---

## 32. OrderItemCard Selection

OrderItemCard should support selection for workflows such as:

    Storage

States:

    Unselected
    Selected
    Disabled
    Stored
    Unstored

The selected state must be visually obvious.

---

## 33. CustomerCard

CustomerCard represents a Customer in lists and selection workflows.

Primary content:

    Customer Name

Secondary content:

    Phone

Optional content:

    Order Count
    Recent Order

The card should remain concise.

---

## 34. CustomerSelector

CustomerSelector is a reusable component for selecting a Customer.

It should support:

    Search
    +
    Existing Customers
    +
    Selected Customer
    +
    Add Customer

It is primarily used inside:

    Create Order

---

## 35. CustomerSelector States

CustomerSelector should support:

    Empty
    Searching
    Results
    No Results
    Selected
    Error

The user should be able to create a new Customer without losing the
current Order workflow.

---

## 36. PaymentMethodSelector

PaymentMethodSelector provides the approved Payment Methods:

    كاش
    InstaPay
    محفظة إلكترونية

It should support single selection.

The selected method must be visually clear.

---

## 37. PaymentSummary

PaymentSummary displays:

    إجمالي الطلب
    +
    المدفوع
    +
    المتبقي

The Remaining amount may receive stronger visual emphasis when it
requires attention.

The component must use centralized financial formatting.

---

## 38. PaymentRow

PaymentRow represents one Payment transaction.

It may display:

    Amount
    +
    Payment Method
    +
    Paid At

The component must treat each Payment as an independent historical
transaction.

---

## 39. StorageItemCard

StorageItemCard represents a physical OrderItem in Storage workflows.

It should display:

    Order Number
    +
    Item Information
    +
    Customer when useful
    +
    Storage Status
    +
    Current Location when stored

Actions may include:

    تخزين
    نقل

depending on the item's current state.

---

## 40. StorageLocationSelector

StorageLocationSelector allows the user to choose a Storage Location.

It should display:

    Location Name
    +
    Location Code

Inactive locations must not normally be selectable for new Storage
operations.

---

## 41. StorageLocationCard

StorageLocationCard represents a Storage Location in Settings or
operational views.

It may display:

    Location Name
    +
    Code
    +
    Status
    +
    Current Occupancy when relevant

Do not turn the card into a complex warehouse analytics component.

---

## 42. AppTable

AppTable is the reusable table component for:

    Orders
    +
    Reports
    +
    Settings
    +
    Other dense data

It should support:

    RTL
    +
    Header
    +
    Rows
    +
    Selection where required
    +
    Responsive behavior

---

## 43. Table Behavior

Tables should:

    Preserve column meaning
    +
    Align numeric values clearly
    +
    Support Arabic
    +
    Remain readable on tablet

On smaller screens, use:

    Horizontal Scrolling
    or
    Responsive List/Card Representation

rather than making the table unreadable.

---

## 44. AppDialog

AppDialog is the standard modal dialog.

Use for:

    Confirmation
    +
    Short focused actions
    +
    Important warnings

Structure:

    Title
    +
    Content
    +
    Actions

Dialogs must remain concise.

---

## 45. ConfirmationDialog

ConfirmationDialog is used for important actions.

Examples:

    إلغاء الطلب
    تعطيل الخدمة
    تعطيل موقع التخزين

The dialog should clearly communicate:

    What will happen
        +
    What the user can choose

Actions should be explicit.

---

## 46. BottomSheet

BottomSheet is used for contextual choices and short workflows.

Examples:

    Payment Method Selection
    +
    Filter Selection
    +
    Storage Location Selection
    +
    Quick Actions

Bottom Sheets must support:

    RTL
    +
    Scrollable Content
    +
    Safe Area
    +
    Touch-friendly Options

---

## 47. DateRangePicker

DateRangePicker is used by Reports and any other workflow requiring a
date range.

It should support:

    Start Date
    +
    End Date
    +
    Apply
    +
    Cancel

The UI must clearly communicate the selected range.

---

## 48. DatePicker

DatePicker is used for date-only business values.

Avoid unnecessary time selection when the Domain only requires a date.

The component must support Arabic localization and RTL presentation.

---

## 49. EmptyState

EmptyState is the standard component for successful queries with no
data.

Structure:

    Icon / Illustration
    +
    Title
    +
    Description
    +
    Optional Action

Example:

    لا توجد طلبات حتى الآن

    ابدأ بإضافة أول طلب.

    [ إضافة طلب ]

---

## 50. NoResultsState

NoResultsState is different from EmptyState.

It is used when:

    Data exists
        +
    Current Search / Filter has no matches

Example:

    لا توجد نتائج مطابقة

Optional action:

    مسح البحث

---

## 51. LoadingState

LoadingState is the shared loading representation.

It may support:

    Spinner
    +
    Skeleton
    +
    Inline Loading

The appropriate representation depends on context.

---

## 52. Skeleton

Skeleton loading should approximate the final content structure.

It should use the same:

    Spacing
    +
    Shape
    +
    Approximate Size

as the final component.

Avoid layout jumps when data loads.

---

## 53. ErrorState

ErrorState communicates a failed operation.

Structure:

    Icon
    +
    Title
    +
    Description
    +
    Retry Action

Example:

    تعذر تحميل الطلبات

    [ إعادة المحاولة ]

---

## 54. InlineError

InlineError is used for small localized errors.

Examples:

    Form Validation
    +
    Field Errors
    +
    Small Component Failures

It should not replace a complete screen-level ErrorState.

---

## 55. SyncIndicator

SyncIndicator communicates background synchronization.

Possible states:

    Synchronized
    جاري المزامنة
    في انتظار المزامنة
    توجد مشكلة في المزامنة

The indicator should remain subtle.

---

## 56. OfflineIndicator

OfflineIndicator communicates:

    غير متصل

Offline is not automatically an error.

The indicator should not prevent the user from continuing supported
Offline-first workflows.

---

## 57. Snackbar / Feedback

A shared transient feedback component may be used for:

    Success
    +
    Informational Feedback
    +
    Non-blocking Errors

Examples:

    تم حفظ الطلب
    تم تسجيل الدفعة بنجاح
    تم التخزين بنجاح

The message should be concise.

---

## 58. Toast Usage

Transient feedback should preferably use the application's standard
feedback component.

Avoid relying on platform-specific Toast behavior that may look
different across environments.

---

## 59. AppDivider

AppDivider provides subtle visual separation.

Use for:

    List Rows
    +
    Payment History
    +
    Settings Sections
    +
    Table Structure

Avoid excessive dividers.

Spacing should often provide separation without requiring a divider.

---

## 60. AppAvatar

If Customer avatars are required by the approved UI, use a centralized
avatar component.

For V1, avatars should remain optional and must not become a required
Customer workflow.

Do not introduce profile-photo management unless explicitly included in
the Product scope.

---

## 61. AppIcon

Icons should come from a centralized icon system.

Do not mix arbitrary icon libraries throughout the application.

Icons must:

    Support RTL
    +
    Have consistent visual weight
    +
    Use semantic colors
    +
    Provide accessible labels when interactive

---

## 62. Navigation Components

The application may use:

    NavigationRail
    +
    NavigationBar
    +
    AppBar

depending on screen size and layout.

The navigation system must remain consistent with the approved
navigation document.

---

## 63. AppBar

AppBar should support:

    Page Title
    +
    Navigation
    +
    Contextual Actions

The AppBar should not become a place for unrelated controls.

---

## 64. NavigationRail

For tablet layouts, NavigationRail may be used when appropriate.

It should provide:

    Primary Navigation
    +
    Active State
    +
    Clear Labels

The exact navigation layout must follow navigation.md.

---

## 65. Search and Filter Bar

Search and filters should be grouped into a reusable layout component
where multiple screens share the same pattern.

It may contain:

    SearchField
    +
    Filter Controls
    +
    Sort Control
    +
    Clear Filters

The component must remain responsive.

---

## 66. Form Components

Forms should be assembled from reusable components:

    AppTextField
    +
    Dropdown
    +
    DatePicker
    +
    Checkbox
    +
    Radio
    +
    Switch
    +
    Buttons

Do not create separate input systems for each feature.

---

## 67. Form Section

FormSection is a reusable structural component.

Structure:

    Section Title
        ↓
    Fields
        ↓
    Optional Helper

It should use the centralized spacing and typography systems.

---

## 68. Financial Components

Financial UI should use shared components where patterns repeat.

Examples:

    PaymentSummary
    +
    FinancialMetric
    +
    AmountDisplay

All financial components must use centralized:

    Currency Formatting
    +
    Typography
    +
    Colors
    +
    Spacing

---

## 69. AmountDisplay

AmountDisplay is a reusable presentation component for monetary values.

It should support:

    Amount
    +
    Currency
    +
    Semantic State when appropriate

Example:

    250.00 ج.م

It must not perform business calculations.

---

## 70. Status Mapping

Status components should receive semantic status information from the
application layer.

The component is responsible for:

    Presentation

not:

    Business Rule Evaluation

For example, StatusBadge should not determine whether an Order is
Completed.

It only displays the status it receives.

---

## 71. Component State Rules

Components should expose only meaningful UI states.

Example:

    AppButton
        Default
        Pressed
        Disabled
        Loading

Example:

    AppTextField
        Default
        Focused
        Error
        Disabled
        Read-only

Avoid exposing internal technical states as UI variants.

---

## 72. RTL Component Rules

Every reusable component must be designed for RTL.

Important rules:

    Use start/end
    +
    Mirror directional icons
    +
    Preserve numeric readability
    +
    Support Arabic text wrapping
    +
    Avoid fixed left/right assumptions

---

## 73. Responsive Component Rules

Components should adapt to:

    Tablet
    +
    Smaller Screens

Examples:

    Table → Responsive Table/List

    Horizontal Form → Vertical Form

    NavigationRail → Compact Navigation

The underlying component semantics should remain unchanged.

---

## 74. Accessibility Rules

Interactive components must provide:

    Adequate Touch Target
    +
    Clear Label
    +
    Visible State
    +
    Keyboard/Focus support where applicable
    +
    Sufficient Contrast

Color must not be the only source of information.

---

## 75. Component Composition

Prefer composition over duplicated feature-specific widgets.

Example:

    CustomerSelector
        =
    SearchField
    +
    CustomerCard
    +
    EmptyState
    +
    Add Customer Action

Example:

    PaymentForm
        =
    Amount Input
    +
    PaymentMethodSelector
    +
    PaymentSummary
    +
    AppButton

---

## 76. Feature Components

Feature components are allowed when they represent a real domain-facing
UI pattern.

Examples:

    OrderItemCard
    StorageItemCard
    CustomerSelector
    PaymentSummary

They should still consume the centralized Design System.

---

## 77. Avoiding Over-Abstraction

Do not create a generic component for every small UI element.

Avoid:

    GenericContainer123
    GenericRow
    GenericBox
    GenericSection2

unless there is a real reusable semantic purpose.

---

## 78. Component Documentation

Every major reusable component should have clearly defined:

    Purpose
    +
    Variants
    +
    States
    +
    Required Properties
    +
    Interaction Behavior

This allows consistent implementation across the application.

---

## 79. Component Visual Consistency

Components with the same semantic role must look the same.

Examples:

    All Primary Buttons
        → Same visual language

    All Text Fields
        → Same visual language

    All Status Badges
        → Same visual language

    All Cards
        → Same visual language

Feature-specific content may change, but the component language remains
consistent.

---

## 80. Component Interaction Consistency

The same interaction pattern should produce the same feedback.

For example:

    Save
        → Loading
        → Success / Error

This behavior should be consistent across:

    Customer
    Service
    Settings
    Order
    Payment

workflows.

---

## 81. Component and Offline-first Behavior

Components should not directly know about:

    Network
    Supabase
    Sync Queue
    Database

They should receive presentation state such as:

    Syncing
    Offline
    Sync Attention

from the appropriate application layer.

---

## 82. Component and Business Logic

Components must not contain business rules.

For example:

    PaymentSummary

must display:

    Total
    Paid
    Remaining

but must not independently decide how these values are calculated.

Likewise:

    StorageItemCard

must display Storage state but must not decide whether an item can be
stored.

---

## 83. Component and Infrastructure

Reusable UI components must not directly access:

    Dio
    Retrofit
    Supabase
    SQLite
    Drift

The approved application flow remains:

    UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Data Source

---

## 84. Component Testing Considerations

Major reusable components should be designed so they can be tested
independently.

Important component states should be testable:

    Default
    +
    Loading
    +
    Error
    +
    Disabled
    +
    Selected
    +
    Empty

The visual system should not depend on hidden global state.

---

## 85. Component Library Structure

The Flutter implementation may organize components conceptually as:

    core/
        theme/
        widgets/

    shared/
        buttons/
        inputs/
        cards/
        feedback/
        dialogs/
        navigation/
        tables/

    features/
        orders/
        storage/
        customers/
        payments/
        reports/
        settings/

The exact folder structure remains subject to the approved Architecture
document.

---

## 86. Final Component Inventory

The V1 shared component system should cover at minimum:

    AppButton
    IconButton
    AppTextField
    SearchField
    Dropdown / Select
    Checkbox
    Radio
    Switch
    AppCard
    MetricCard
    StatusBadge
    CustomerCard
    CustomerSelector
    OrderItemCard
    StorageItemCard
    StorageLocationSelector
    StorageLocationCard
    PaymentMethodSelector
    PaymentSummary
    PaymentRow
    AppTable
    AppDialog
    ConfirmationDialog
    BottomSheet
    DatePicker
    DateRangePicker
    EmptyState
    NoResultsState
    LoadingState
    Skeleton
    ErrorState
    InlineError
    SyncIndicator
    OfflineIndicator
    Snackbar / Feedback
    AppDivider
    AppIcon
    AppBar
    Navigation
    SearchFilterBar
    FormSection
    AmountDisplay

Not every component must appear on every screen.

---

## 87. Final Component Principle

> Build the interface from a small, consistent set of reusable components
> instead of building every screen independently.

The component system should make it possible to implement:

    Dashboard
    +
    Orders
    +
    Storage
    +
    Customers
    +
    Payments
    +
    Reports
    +
    Settings

while preserving the same:

    Visual Language
    +
    Interaction Behavior
    +
    RTL Support
    +
    Responsive Behavior
    +
    Accessibility
    +
    Offline-first UX