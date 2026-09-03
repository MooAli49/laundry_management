# Laundry Management System — Design System Overview

## 1. Document Purpose

This document defines the V1 Design System direction for the Laundry Management System.

The Design System exists to provide one consistent visual and interaction language across the entire application.

The Design System must be treated as a shared system rather than a collection of screen-specific styles.

The primary goals are:

- Consistency
- Maintainability
- Arabic-first UI
- RTL support
- Reusable components
- Centralized theme configuration
- Predictable implementation
- Easy future modification
- Reliable AI-assisted implementation

The Design System must remain aligned with:

    docs/01-product/
    docs/02-domain/
    docs/03-architecture/
    docs/04-database/
    docs/05-api/

---

## 2. Source of Truth

The Flutter implementation must have a single source of truth for visual design tokens.

The approved direction is to centralize the core visual system in dedicated files such as:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

Additional token files may be introduced when the system grows, but they must remain part of the same centralized Design System.

The application theme must consume the centralized tokens.

Conceptually:

    AppColors
        +
    AppTextStyles
        +
    Other Design Tokens
        ↓
    AppTheme
        ↓
    MaterialApp

Screens and feature widgets must consume the Design System rather than defining their own visual system.

---

## 3. Design System Principles

The V1 Design System follows these principles:

    Centralized
        +
    Consistent
        +
    Arabic-first
        +
    RTL-aware
        +
    Reusable
        +
    Simple
        +
    Accessible
        +
    Responsive
        +
    Easy to maintain

The Design System should solve repeated UI problems once instead of allowing every screen to solve them independently.

---

## 4. Arabic-first Design

The application UI language is:

    Arabic

Arabic is not treated as a secondary translation layer.

The Design System must therefore be designed around Arabic content from the beginning.

This affects:

- Typography
- Text alignment
- Layout direction
- Icons
- Navigation
- Forms
- Tables
- Search
- Status labels
- Dates
- Numbers
- Currency
- Dialogs
- Bottom sheets

The UI must support:

    RTL

as the default layout direction.

---

## 5. RTL Rules

The application should use RTL as the default direction for Arabic UI.

Components must not hardcode left/right assumptions when the intended behavior is directional.

Prefer:

    start
    end

over:

    left
    right

when defining layout relationships.

Directional icons must also be reviewed for RTL behavior.

Examples:

    Back
    Forward
    Previous
    Next
    Expand
    Collapse

must behave correctly in RTL.

---

## 6. Design Token Categories

The V1 Design System should define centralized tokens for:

    Colors
    Typography
    Spacing
    Border Radius
    Borders
    Elevation
    Component Sizes
    Icon Sizes
    Motion where required

Not every possible visual value needs to become a token.

Tokens should exist when:

- A value is reused.
- A value represents a meaningful design decision.
- A value needs centralized control.
- A value is likely to change consistently across the application.

---

## 7. Colors

All application colors must be defined centrally.

The primary source should be:

    app_colors.dart

Screens must not contain arbitrary color literals for normal UI styling.

Avoid:

    Color(0xFF...)

directly inside feature screens unless there is a documented exceptional reason.

The Design System should define semantic colors rather than only raw color names.

Examples:

    primary
    secondary
    background
    surface
    textPrimary
    textSecondary
    border
    divider
    success
    warning
    error
    info

The exact final color palette is defined in the dedicated color/token documentation.

---

## 8. Semantic Colors

Colors should communicate meaning consistently.

Examples:

    Success
        → Successful operations
        → Completed states
        → Positive feedback

    Warning
        → Attention
        → Pending situations
        → Important but non-critical states

    Error
        → Validation errors
        → Failed operations
        → Critical problems

    Info
        → Informational messages

The same semantic meaning must use the same Design System color across the application.

---

## 9. Typography

Typography must be centralized.

The primary source should be:

    app_text_styles.dart

Feature screens must not create arbitrary TextStyle definitions for normal application typography.

Typography should provide semantic roles rather than screen-specific names.

Examples:

    display
    headline
    title
    body
    label
    caption

The exact typography scale, font family, weights, and sizes belong to the typography token documentation.

---

## 10. Arabic Typography

The selected font must provide appropriate Arabic glyph coverage.

Typography must be validated using real Arabic UI content rather than only Latin placeholder text.

Important cases include:

    أسماء العملاء
    أسماء الخدمات
    أسماء القطع
    الملاحظات
    الأسعار
    التواريخ
    حالات الطلبات

The Design System must remain readable across:

- Small labels
- Buttons
- Forms
- Tables
- Cards
- Dialogs
- Headings

---

## 11. Spacing

Spacing must use a centralized spacing scale.

Avoid arbitrary values throughout screens.

Example conceptual scale:

    xs
    sm
    md
    lg
    xl

The exact numeric values are defined in the spacing token documentation.

The goal is visual rhythm and consistency, not forcing every layout to use the same spacing.

---

## 12. Border Radius

Border radius values should be centralized.

Examples:

    small
    medium
    large
    pill

Components should reuse approved radius tokens.

Screen-specific arbitrary radii should be avoided unless there is a documented design reason.

---

## 13. Borders and Dividers

Borders and dividers must use centralized semantic values.

Examples:

    borderColor
    dividerColor
    borderWidth

Borders should support clear hierarchy without excessive visual noise.

Tables, cards, inputs, and dialogs should use the same approved border language.

---

## 14. Elevation

Elevation should be used intentionally.

The Design System should define a small number of elevation levels rather than arbitrary shadow values.

Examples:

    none
    low
    medium
    high

Elevation should primarily communicate hierarchy such as:

    Cards
    Dialogs
    Bottom Sheets
    Floating elements

The application should avoid excessive shadows.

---

## 15. Component Philosophy

Shared components should be created when the same UI pattern appears across multiple features.

Examples include:

    Primary Button
    Secondary Button
    Text Button
    App Text Field
    Search Field
    Dropdown
    Date Picker Field
    Status Badge
    Card
    Dialog
    Bottom Sheet
    Empty State
    Loading State
    Error State

A component should not be created only to wrap a single widget without adding reusable behavior or styling.

---

## 16. Buttons

The Design System should provide standardized button variants.

Expected V1 variants include:

    Primary
    Secondary
    Text
    Destructive

Buttons must have consistent:

- Typography
- Height
- Padding
- Radius
- Icon spacing
- Disabled state
- Loading state

The exact visual values are defined in component specifications.

---

## 17. Inputs

Input components must share consistent styling.

Examples:

    Text Input
    Search Input
    Numeric Input
    Phone Input
    Dropdown
    Date Input
    Multiline Notes Input

Inputs should consistently support:

    Label
    Hint
    Error
    Focus
    Disabled
    Read-only where required

Arabic text and RTL behavior must be tested.

---

## 18. Search

Search is a core operational interaction.

The Search component should support the approved search patterns without introducing screen-specific styling.

Search may be used for:

    Customers
    Orders
    Item Types
    Services
    Storage

Search fields should remain consistent across screens.

---

## 19. Date Input

Expected Pickup is date-only.

The Date Picker component must therefore support:

    Date

without requiring:

    Time

The displayed format must follow the approved Arabic UI date convention.

The underlying Domain representation remains a date-only business concept.

---

## 20. Currency Display

The application currency is:

    EGP

User-facing display:

    ج.م

Financial values must use the approved financial representation from the architecture/database decisions.

The Design System is responsible for consistent visual presentation.

It must not perform business calculations.

Example:

    250.00 ج.م

The exact formatting rules belong to the formatting utility/design specification.

---

## 21. Status Presentation

Order statuses are business concepts and should have consistent visual representations.

V1 statuses:

    Processing
    Ready
    Completed
    Cancelled

The Design System should provide a reusable status presentation component.

Example conceptual mapping:

    Processing
        → neutral / active semantic treatment

    Ready
        → positive operational treatment

    Completed
        → completed semantic treatment

    Cancelled
        → error / inactive semantic treatment

The exact colors are controlled by AppColors.

---

## 22. Cards

Cards should be used for grouped information when appropriate.

Common use cases include:

    Order Summary
    Customer Summary
    Dashboard Metrics
    Storage Information

Cards should use centralized:

    Padding
    Radius
    Border
    Elevation
    Typography

The Design System should avoid creating many visually different card variants without a real requirement.

---

## 23. Tables

Tables are useful for information-dense administrative views.

The table design must support:

    Arabic
    RTL
    Long text
    Monetary values
    Status values
    Actions

Column alignment must be intentional.

Numeric and monetary values should use consistent alignment and formatting.

The table component must remain readable on the supported screen sizes.

---

## 24. Dialogs

Dialogs should be standardized.

Typical uses include:

    Confirmation
    Destructive Action
    Validation
    Important Information

Dialogs must have consistent:

    Title
    Content
    Actions
    Spacing
    Radius
    Button hierarchy

Destructive actions should use the semantic error/destructive styling.

---

## 25. Bottom Sheets

Bottom Sheets may be used for contextual actions and compact workflows.

Examples:

    Order Actions
    Filter Options
    Storage Actions
    Payment Actions

They should follow the same Design System tokens as dialogs and cards.

---

## 26. Empty States

Empty states are part of the normal application experience.

Examples:

    No Customers
    No Orders
    No Payments
    No Storage Items
    No Search Results

An Empty State should provide:

    Clear visual indication
    +
    Short Arabic explanation
    +
    Optional primary action

Empty states must not be treated as errors.

---

## 27. Loading States

Loading states should be consistent across the application.

The Design System may provide:

    Progress Indicator
    Skeleton
    Loading Button

The appropriate loading pattern depends on the interaction.

The UI should avoid unnecessary full-screen blocking loaders for small local operations.

This is especially important because local database operations are expected to be fast.

---

## 28. Error States

Error presentation should distinguish between:

    Validation Error
    Business Rule Error
    Network Error
    Synchronization Error
    Unexpected Error

The Design System provides consistent visual presentation.

The Domain/Data layers remain responsible for determining the error type.

The UI must not inspect raw backend exceptions to determine presentation.

---

## 29. Responsive Design

The application must support the target Flutter platforms and screen sizes defined by the product.

The Design System should use:

    Flexible Layouts
    Adaptive Components
    Centralized Dimensions

Avoid designing screens around one fixed pixel size.

Important layouts include:

    Dashboard
    Order Creation
    Order Details
    Storage
    Customers
    Reports

---

## 30. Desktop-first Considerations

The laundry management system is an operational application and may be used on larger screens.

The Design System should therefore support:

    Desktop
    Tablet
    Smaller Screens where required

Information-dense screens should take advantage of available horizontal space without becoming visually cluttered.

---

## 31. Icons

Icons must follow a consistent visual language.

The project should prefer one primary icon family.

Icons must support RTL behavior where direction matters.

Icons should communicate meaning clearly and should not replace important text where the meaning could be ambiguous.

---

## 32. Icon + Text

For operational actions, icons may be combined with Arabic labels.

Examples:

    إضافة طلب
    حفظ
    تعديل
    حذف
    تخزين
    دفع
    إكمال الطلب

Icon usage must remain consistent across the application.

---

## 33. Accessibility

The Design System should maintain reasonable accessibility standards.

Important considerations include:

-   Sufficient contrast
-   Readable font sizes
-   Clear error states
-   Touch target sizes
-   Do not rely on color alone to communicate status
-   Clear labels
-   Clear focus states

Accessibility must be considered during component implementation rather than added after all screens are complete.

---

## 34. Theme Architecture

The application theme must be centralized.

Recommended conceptual structure:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

The final Flutter implementation should follow:

    AppColors
        ↓
    AppTheme

    AppTextStyles
        ↓
    AppTheme

    AppTheme
        ↓
    MaterialApp

Feature screens must use:

    Theme.of(context)

and/or approved Design System extensions/components.

They must not recreate the theme locally.

---

## 35. No Hardcoded Theme Values

The following should not normally appear directly inside feature screens:

    Color(0xFF...)
    TextStyle(...)
    arbitrary BorderRadius
    arbitrary spacing values
    arbitrary shadow definitions

Instead use:

    AppColors
    AppTextStyles
    Design Tokens
    Theme
    Shared Components

Exceptions require a clear design reason.

---

## 36. Component Variants

Components should use explicit variants.

Example:

    AppButton
        ├── Primary
        ├── Secondary
        ├── Text
        └── Destructive

Avoid creating separate components for every visual variation.

Prefer:

    One reusable component
        +
    Controlled variants

when the behavior and structure are fundamentally the same.

---

## 37. Component State Model

Reusable interactive components should support the states relevant to them.

Typical states:

    Default
    Hover
    Focus
    Pressed
    Disabled
    Loading
    Error
    Selected

Not every component requires every state.

The implementation should only include meaningful states.

---

## 38. Forms

Forms should follow a consistent hierarchy:

    Section Title
        ↓
    Field Label
        ↓
    Input
        ↓
    Validation Message

Required fields must be visually identifiable.

Validation messages should be concise and written in Arabic.

---

## 39. Required Fields

The Design System must provide a consistent visual indication for required fields.

Do not invent a different required-field pattern on every screen.

The exact implementation may use:

    *
    Required label
    or
    Another approved visual convention

The final convention must be consistent across all forms.

---

## 40. Validation

Validation feedback should appear close to the relevant field when possible.

Examples:

    رقم الهاتف غير صحيح
    اسم العميل مطلوب
    تاريخ الاستلام المتوقع مطلوب

Validation should not rely exclusively on color.

---

## 41. Notifications and Feedback

The application may use:

    Snackbar
    Toast-equivalent
    Inline feedback
    Dialog

The choice depends on severity and context.

Examples:

    Successful save
        → Lightweight feedback

    Validation problem
        → Inline field feedback

    Destructive confirmation
        → Dialog

    Critical unexpected failure
        → Clear error state

---

## 42. Motion

Motion should be minimal and purposeful.

Use animation to communicate:

    State change
    Navigation
    Appearance/disappearance
    Loading
    Feedback

Avoid decorative animations that slow down operational workflows.

The exact motion tokens can be defined later if the application requires them.

---

## 43. Screen-specific Styling Rule

Screens may compose Design System components and tokens.

Screens must not redefine the Design System.

Valid:

    Screen
        ↓
    AppButton
        +
    AppTextStyles.title
        +
    AppColors.primary

Invalid:

    Screen
        ↓
    Custom color
        +
    Custom typography
        +
    Custom radius
        +
    Custom button style

without a documented reason.

---

## 44. Feature-specific Components

Not every component must be global.

Feature-specific components are allowed when they are strongly tied to one domain feature.

Examples:

    OrderItemRow
    StorageItemCard
    PaymentSummary
    OrderStatusBadge

These components should still consume the centralized Design System tokens.

---

## 45. Shared vs Feature Components

Use shared components for:

    Repeated UI patterns

Use feature components for:

    Domain-specific UI

Use Design Tokens for:

    Visual decisions

This creates:

    Design Tokens
        ↓
    Shared Components
        ↓
    Feature Components
        ↓
    Screens

---

## 46. Design System Folder Direction

The exact project structure may evolve, but the V1 direction is:

    lib/
    └── core/
        └── theme/
            ├── app_colors.dart
            ├── app_text_styles.dart
            ├── app_theme.dart
            └── additional design token files when required

Shared UI components should have a separate reusable location, for
example:

    lib/
    └── core/
        └── widgets/

Feature-specific components remain inside their feature structure.

The final folder structure must not introduce unnecessary abstraction.

---

## 47. Design System and Antigravity

Antigravity must treat the Design System documentation and Flutter
theme files as the source of truth.

When implementing a screen, Antigravity must:

1. Read the Design System documentation.
2. Use existing tokens.
3. Use existing shared components.
4. Reuse AppColors.
5. Reuse AppTextStyles.
6. Reuse AppTheme.
7. Follow Arabic and RTL rules.
8. Avoid hardcoded visual values.
9. Avoid creating duplicate components.
10. Ask for a documented design decision when a required token does not
   exist instead of inventing one silently.

---

## 48. Design System Change Rule

A visual change that affects multiple screens should be made in the
Design System rather than patched separately on each screen.

Example:

    Change Primary Color

Preferred:

    AppColors.primary
        ↓
    AppTheme
        ↓
    All Components

Not:

    Screen A → change color
    Screen B → change color
    Screen C → change color

This preserves the single source of truth.

---

## 49. Design Token Naming

Token names should communicate semantic meaning.

Prefer:

    primary
    background
    surface
    textPrimary
    textSecondary
    error
    success

over:

    blue1
    blue2
    gray3
    green1

Raw palette values may exist internally, but application components
should consume semantic tokens whenever possible.

---

## 50. Design System and Domain Logic

The Design System must not contain business logic.

For example:

    AppColors
    AppTextStyles
    AppButton
    StatusBadge

must not determine:

    Whether an Order is Ready
    Whether Payment is Allowed
    Whether Storage is Complete

They only represent the state provided by the feature/domain layer.

---

## 51. Design System and API

The Design System must not depend on API models.

For example:

    AppButton
    StatusBadge
    AppTextField

must not import:

    Retrofit
    Dio
    API DTOs
    Supabase classes

Visual components consume application-level state and display it.

---

## 52. Design System and Database

The Design System must not depend on:

    SQLite
    Drift
    Database tables
    SQL queries

Database state is transformed into application/domain state before being
presented.

---

## 53. V1 Design System Scope

The initial Design System should focus on the components actually needed
by the V1 screens.

It should not attempt to become a complete enterprise design system.

Prioritize:

    Colors
    Typography
    Spacing
    Buttons
    Inputs
    Search
    Dropdowns
    Date Picker
    Cards
    Status Badges
    Tables
    Dialogs
    Bottom Sheets
    Loading
    Empty States
    Error States

Additional components may be added when real screen requirements
justify them.

---

## 54. Design System Documentation Structure

Phase 06 is expected to document the Design System through focused
files.

The initial structure is:

    06-design-system/
    ├── design-system-overview.md
    ├── colors.md
    ├── typography.md
    ├── spacing.md
    ├── components.md
    └── flutter-theme.md

Additional files may be added only when they provide meaningful
separation.

---

## 55. Final Design System Direction

The V1 Design System is:

    Arabic-first
        +
    RTL
        +
    Centralized
        +
    Token-based
        +
    Component-driven
        +
    Flutter Theme based
        +
    Responsive
        +
    Accessible
        +
    Simple
        +
    AI-friendly

The Flutter theme files:

    app_colors.dart
    app_text_styles.dart
    app_theme.dart

form the core implementation source of truth.

---

## 56. Final Principle

> Define the visual system once, then reuse it everywhere.

No screen should become its own independent design system.

The application should be visually consistent because:

    Design Tokens
        ↓
    Theme
        ↓
    Shared Components
        ↓
    Feature Components
        ↓
    Screens

This structure is the approved V1 foundation for the Laundry Management
System Design System.