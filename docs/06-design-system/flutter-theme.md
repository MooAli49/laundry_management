# Laundry Management System — Flutter Theme

## 1. Document Purpose

This document defines how the Laundry Management System Design System
is represented in Flutter.

The purpose is to centralize:

    Colors
    +
    Typography
    +
    Spacing
    +
    Component Styling
    +
    Interaction States
    +
    Theme Configuration

The Flutter application must consume these centralized definitions
instead of defining visual values independently inside feature screens.

---

## 2. Theme Principles

The Flutter theme must be:

    Centralized
    +
    Semantic
    +
    Reusable
    +
    RTL-aware
    +
    Arabic-first
    +
    Responsive
    +
    Accessible

Feature screens should consume the theme.

They should not redefine:

    Colors
    +
    Text Styles
    +
    Border Radius
    +
    Component Shapes
    +
    Component Defaults

unless there is a documented exception.

---

## 3. Theme Mode

V1 uses:

    Light Theme

Dark Theme is not part of the current V1 scope.

The architecture should nevertheless avoid hardcoding assumptions that
would make a future Dark Theme impossible.

---

## 4. Theme Architecture

The visual system should conceptually be organized as:

    App Theme
        ↓
    Color System
        +
    Typography System
        +
    Component Theme
        +
    Spacing System

The Flutter implementation should keep these systems centralized.

---

## 5. Material Theme

The application should use Flutter's Material theming capabilities as
the foundation of the UI system.

Conceptually:

    ThemeData
        +
    ColorScheme
        +
    TextTheme
        +
    Component Themes

The exact Flutter implementation should follow the project's approved
architecture and current Flutter version.

---

## 6. ColorScheme

The application's semantic colors should be represented through a
centralized ColorScheme where appropriate.

Core semantic concepts include:

    Primary
    Secondary
    Surface
    Background
    Error
    OnPrimary
    OnSecondary
    OnSurface
    OnError

Additional application-specific semantic colors may be represented using
a centralized ThemeExtension when they are not sufficiently represented
by Flutter's standard ColorScheme.

---

## 7. App Colors

Application-specific colors should remain centralized.

Conceptual structure:

    AppColors
        primary
        primaryLight
        primaryLighter
        primaryDark

        secondary
        secondaryLight
        secondaryDark

        background
        backgroundSecondary

        surface
        surfaceElevated
        surfaceSelected
        surfaceDisabled

        textPrimary
        textSecondary
        textTertiary
        textDisabled

        border
        borderStrong
        borderFocused
        borderDisabled
        divider

        success
        successLight
        successDark

        warning
        warningLight
        warningDark

        error
        errorLight
        errorDark

        info
        infoLight
        infoDark

        focus
        selectionBackground
        selectionBorder
        selectionContent

        disabledBackground
        disabledBorder
        disabledText

        overlay

The exact raw color values belong to the centralized color definition.

---

## 8. ThemeExtension

Custom semantic colors that are not directly represented by Flutter's
standard ColorScheme may be exposed through a ThemeExtension.

Conceptually:

    AppColorsExtension

This allows widgets to access application-specific semantic colors
through the active Theme.

The goal is to avoid direct dependency on a global static color class
inside every widget.

---

## 9. Typography

Typography should be represented through Flutter's TextTheme.

Conceptual styles:

    displayLarge
    displayMedium

    headlineLarge
    headlineMedium
    headlineSmall

    bodyLarge
    bodyMedium
    bodySmall

    labelLarge
    labelMedium
    labelSmall

The project's semantic typography names may map to Flutter's standard
TextTheme names.

---

## 10. Font Family

Primary font:

    IBM Plex Sans Arabic

The font must support:

    Arabic
    +
    Latin
    +
    Numbers
    +
    Common Symbols

The font configuration must be centralized.

Individual screens must not specify independent font families.

---

## 11. Typography Mapping

Recommended semantic mapping:

    Display Large
        → displayLarge

    Display Medium
        → displayMedium

    Heading Large
        → headlineLarge

    Heading Medium
        → headlineMedium

    Heading Small
        → headlineSmall

    Body Large
        → bodyLarge

    Body Medium
        → bodyMedium

    Body Small
        → bodySmall

    Caption
        → bodySmall / labelSmall
          depending on context

---

## 12. Typography Defaults

The Theme should define:

    Font Family
    +
    Font Size
    +
    Font Weight
    +
    Line Height
    +
    Letter Spacing
    +
    Text Color where appropriate

Feature widgets should consume these styles instead of creating local
TextStyle objects.

---

## 13. Text Direction

The application direction is:

    RTL

The root application should configure Arabic RTL behavior.

Widgets should use logical layout concepts such as:

    start
    end

instead of hardcoded:

    left
    right

---

## 14. Locale

The primary application locale is Arabic.

The Flutter application should configure localization centrally.

Date, number, and currency presentation should use the application's
localization and formatting utilities.

---

## 15. Currency

The application's currency is:

    Egyptian Pound

Display:

    ج.م

Financial UI should use centralized formatting.

Example:

    250.00 ج.م

The theme must not perform financial calculations.

---

## 16. Text Field Theme

All standard text fields should share one centralized visual language.

TextField theme should define:

    Background
    +
    Border
    +
    Focused Border
    +
    Error Border
    +
    Disabled Border
    +
    Border Radius
    +
    Content Padding
    +
    Label Style
    +
    Hint Style
    +
    Error Style

The exact values should follow the Design System.

---

## 17. Input Shape

Text inputs should use a consistent shape.

The application should use the centralized border radius token rather than
independent values per screen.

Inputs should feel:

    Clear
    +
    Modern
    +
    Operational
    +
    Easy to scan

---

## 18. Input Padding

Input content padding should provide comfortable tablet interaction.

The component should preserve:

    Adequate Touch Target
    +
    Readable Text
    +
    Vertical Breathing Room

The exact values should follow the spacing and component specifications.

---

## 19. Button Theme

Buttons should use centralized component themes.

Supported conceptual variants:

    Primary
    Secondary
    Destructive
    Text

Flutter's standard button themes may be used where appropriate.

Feature-specific buttons should not define independent colors or shapes.

---

## 20. Elevated Button

The primary operational action may use:

    ElevatedButton

or an equivalent centralized custom button implementation.

It should follow:

    Primary Color
    +
    OnPrimary
    +
    Centralized Shape
    +
    Centralized Typography
    +
    Centralized Padding

---

## 21. Outlined Button

Secondary actions may use:

    OutlinedButton

It should follow:

    Border
    +
    Text Color
    +
    Centralized Shape
    +
    Centralized Typography

---

## 22. Text Button

Low-emphasis actions may use:

    TextButton

The component must remain readable and touch-friendly.

---

## 23. Destructive Actions

Destructive actions should use the Error semantic colors.

Example:

    إلغاء الطلب

The Error color should be applied through the centralized theme rather
than directly inside the feature.

---

## 24. Button States

Buttons must support:

    Default
    +
    Hover where applicable
    +
    Pressed
    +
    Focused
    +
    Disabled
    +
    Loading

Loading state should prevent duplicate submission.

---

## 25. Card Theme

Cards should use centralized:

    Background
    +
    Border
    +
    Radius
    +
    Elevation
    +
    Padding where component-specific

The standard Card appearance should be shared across features.

---

## 26. Dialog Theme

Dialogs should use centralized:

    Background
    +
    Radius
    +
    Elevation
    +
    Title Typography
    +
    Content Typography
    +
    Action Typography

Dialogs should remain visually consistent throughout the application.

---

## 27. Bottom Sheet Theme

Bottom Sheets should use centralized:

    Background
    +
    Shape
    +
    Padding
    +
    Typography
    +
    Handle where applicable

The Bottom Sheet must respect:

    RTL
    +
    Safe Area
    +
    Scroll Behavior

---

## 28. Navigation Theme

Navigation components should use the centralized theme.

Active navigation:

    Primary

Inactive navigation:

    textSecondary

Disabled navigation:

    textDisabled

The active state must remain clear without relying solely on color.

---

## 29. NavigationRail

For tablet layouts, NavigationRail may be used.

The theme should define:

    Selected Color
    +
    Unselected Color
    +
    Indicator
    +
    Label Typography

The exact navigation structure follows navigation.md.

---

## 30. AppBar Theme

AppBar should use the centralized:

    Background
    +
    Foreground
    +
    Title Typography
    +
    Icon Theme

The AppBar should remain visually lightweight.

---

## 31. Divider Theme

Dividers should use:

    divider

from the centralized semantic color system.

Dividers must remain subtle.

---

## 32. Icon Theme

The application should use a centralized IconTheme.

It should define:

    Default Icon Color
    +
    Icon Size where appropriate

Interactive icons may use:

    Primary
    +
    Error
    +
    Disabled

according to semantic context.

---

## 33. Checkbox Theme

Checkboxes should use centralized:

    Selected Color
    +
    Unselected Border
    +
    Check Color
    +
    Disabled State

The selected state must remain clear in RTL layouts.

---

## 34. Radio Theme

Radio buttons should use centralized:

    Selected Color
    +
    Unselected Border
    +
    Disabled State

They must follow the same interaction language as other selection
components.

---

## 35. Switch Theme

Switches should use centralized:

    Active Color
    +
    Inactive Color
    +
    Thumb Color
    +
    Disabled State

The active state should not rely only on color.

---

## 36. Chip Theme

If Chips are used for:

    Filters
    +
    Status
    +
    Selected Items

they should use centralized:

    Background
    +
    Label Typography
    +
    Border
    +
    Radius
    +
    Padding

---

## 37. Snackbar Theme

Snackbar / transient feedback should use the centralized feedback
system.

Semantic variants may include:

    Success
    +
    Info
    +
    Warning
    +
    Error

The message must remain readable.

---

## 38. Tooltip

Tooltips may be used for:

    Icon-only Actions
    +
    Additional Context

They should not replace visible labels for primary workflows.

---

## 39. Focus Theme

All interactive components must have a visible focus state.

Focus should use:

    focus

from the centralized semantic color system.

The focus state must provide sufficient contrast.

---

## 40. Disabled Theme

Disabled components should use:

    disabledBackground
    +
    disabledBorder
    +
    disabledText

Disabled components must remain visually understandable without being
confused with Error states.

---

## 41. Selection Theme

Selected items should use:

    selectionBackground
    +
    selectionBorder
    +
    selectionContent

This applies to:

    OrderItems
    +
    Storage Items
    +
    Filters
    +
    Customers
    +
    Payment Methods

---

## 42. Status Theme

StatusBadge and other status components should consume semantic colors.

Conceptual mapping:

    Processing
        → Info / Neutral

    Ready
        → Primary / Attention

    Completed
        → Success

    Cancelled
        → Error

The status mapping should remain centralized.

---

## 43. Offline Theme

Offline indicator:

    Neutral / Warning

The Offline state is not automatically treated as Error.

The theme must support a subtle presentation that does not block normal
Offline-first workflows.

---

## 44. Sync Theme

Synchronization states:

    Synchronized
        → Success

    Syncing
        → Info

    Waiting for Sync
        → Warning / Neutral

    Sync Attention
        → Warning / Error

The exact presentation should remain subtle.

---

## 45. Border Radius

The application should use a centralized radius scale.

Recommended conceptual values:

    Small
        6 px

    Medium
        8 px

    Large
        12 px

    Extra Large
        16 px

    Pill
        999 px

The exact values should be centralized and consumed by components.

---

## 46. Elevation

Elevation should remain restrained.

Use elevation primarily for:

    Dialogs
    +
    Bottom Sheets
    +
    Floating Elements
    +
    Elevated Cards when necessary

Avoid excessive shadows.

The application should remain visually clean and professional.

---

## 47. Surface Hierarchy

The visual hierarchy should generally be:

    Application Background
        ↓
    Surface
        ↓
    Elevated Surface
        ↓
    Dialog / Modal

Each level should be distinguishable without excessive shadow.

---

## 48. Theme and Responsive Design

The theme itself remains consistent across screen sizes.

Responsive behavior belongs to:

    Layout
    +
    Component Constraints
    +
    Screen Structure

not to creating unrelated visual themes.

---

## 49. Theme and Tablet-first Design

Tablet is the primary target.

The theme must provide comfortable:

    Typography
    +
    Touch Targets
    +
    Component Heights
    +
    Spacing

for tablet use.

The UI should not feel like an enlarged mobile application.

---

## 50. Theme and Arabic

The theme must work naturally with:

    Arabic Text
    +
    RTL Layout
    +
    Arabic Numbers / Numeric Content
    +
    Latin Technical Values

Typography and component padding should account for Arabic glyph
metrics.

---

## 51. Theme and Accessibility

The theme must provide:

    Sufficient Contrast
    +
    Visible Focus
    +
    Readable Typography
    +
    Adequate Touch Targets
    +
    Clear Disabled States
    +
    Semantic State Colors

Color must never be the only way to communicate meaning.

---

## 52. Theme and Offline-first UX

The theme must support Offline-first states without turning them into
blocking error screens.

For example:

    غير متصل

should use a subtle semantic treatment.

Likewise:

    جاري المزامنة

should not visually dominate the current business workflow.

---

## 53. Theme Access

Widgets should access theme values through Flutter's theme mechanisms.

Preferred conceptual access:

    Theme.of(context)

and:

    Theme.of(context).textTheme

or:

    Theme.of(context).colorScheme

For application-specific values:

    Theme.of(context).extension<AppColorsExtension>()

Avoid importing raw color constants into every feature widget when a
theme-based semantic value is available.

---

## 54. Centralized Theme Configuration

The application should have one central theme configuration.

Conceptually:

    AppTheme
        ↓
    lightTheme

This configuration should assemble:

    ColorScheme
    +
    TextTheme
    +
    Component Themes
    +
    Theme Extensions

---

## 55. Theme File Structure

A possible centralized structure is:

    core/
        theme/
            app_theme.dart
            app_colors.dart
            app_text_styles.dart
            app_spacing.dart
            app_radius.dart
            app_extensions.dart

The exact project structure should follow the approved Architecture.

Do not create duplicate theme files inside individual features.

---

## 56. Design Token Source

The source of truth for visual values is:

    Design System Documentation

The Flutter implementation translates those tokens into:

    Dart Constants
    +
    ThemeData
    +
    Theme Extensions
    +
    Component Themes

If a token changes, the corresponding centralized implementation should
change rather than modifying every screen.

---

## 57. Theme and Components

Components must consume the theme.

Example:

    AppButton
        → Theme Button Style

    AppTextField
        → Theme Input Style

    AppCard
        → Theme Card Style

    StatusBadge
        → Semantic Color Extension

    MetricCard
        → Typography + Colors + Spacing

This keeps the system consistent.

---

## 58. Theme and Feature Screens

Feature screens should mainly define:

    Layout
    +
    Content
    +
    Feature-specific Composition

They should not define:

    Global Colors
    +
    Global Typography
    +
    Global Radius
    +
    Global Component Styling

---

## 59. No Raw Colors in Features

Avoid:

    Color(0xFF...)

inside feature screens.

Use:

    Theme.of(context).colorScheme.primary

or the appropriate semantic ThemeExtension value.

---

## 60. No Raw TextStyles in Features

Avoid creating independent TextStyle definitions when an existing
semantic TextTheme style is appropriate.

Prefer:

    Theme.of(context).textTheme.bodyLarge

or another approved semantic style.

---

## 61. No Random Spacing in Features

Avoid arbitrary values when centralized spacing tokens already exist.

Prefer:

    AppSpacing.md

or the corresponding semantic spacing token.

---

## 62. Theme Initialization

The root application should initialize the theme centrally.

Conceptually:

    MaterialApp
        theme
            = AppTheme.lightTheme

The root should also configure:

    Locale
    +
    RTL Direction
    +
    Localization

according to the application requirements.

---

## 63. Theme and State Management

The theme should not contain business state.

For example:

    Order Status

is not a Theme state.

The Theme only provides the visual representation for the status.

Business state remains in:

    Domain
    +
    Application / Presentation

layers.

---

## 64. Theme and Repository Layer

The theme must have no dependency on:

    Repository
    +
    Data Source
    +
    Supabase
    +
    Dio
    +
    Retrofit
    +
    SQLite

The theme is purely a presentation concern.

---

## 65. Theme and Domain Layer

The Domain layer should not depend on Flutter ThemeData or UI colors.

The mapping:

    Domain State
        ↓
    Presentation State
        ↓
    Theme / Component

keeps the Domain independent from UI implementation.

---

## 66. Testing

Theme configuration should be testable independently.

Important checks include:

    Primary Color Exists
    +
    TextTheme Exists
    +
    Component Themes Exist
    +
    RTL Configuration Works
    +
    Custom ThemeExtension Exists

Components should be tested against the theme rather than requiring
hardcoded visual assumptions.

---

## 67. Theme Consistency

The same semantic value must always produce the same visual language.

For example:

    Primary Button

must look consistent in:

    Orders
    +
    Customers
    +
    Storage
    +
    Settings

Likewise:

    Error
    +
    Success
    +
    Warning
    +
    Info

must remain consistent throughout the application.

---

## 68. Theme Evolution

Future visual changes should normally require changes to:

    Theme
    +
    Design Tokens
    +
    Shared Components

rather than changes to every feature screen.

This is a key reason for centralizing the Design System.

---

## 69. Final Theme Structure

The conceptual final Flutter theme is:

    AppTheme
        │
        ├── ColorScheme
        │
        ├── AppColorsExtension
        │
        ├── TextTheme
        │
        ├── ButtonTheme
        │
        ├── InputTheme
        │
        ├── CardTheme
        │
        ├── DialogTheme
        │
        ├── NavigationTheme
        │
        ├── CheckboxTheme
        │
        ├── RadioTheme
        │
        ├── SwitchTheme
        │
        ├── ChipTheme
        │
        └── Snackbar / Feedback Theme

This provides a single visual foundation for the entire application.

---

## 70. Final Theme Principle

> The Flutter Theme is the implementation layer of the Design System.

The final application should allow the visual language to be changed
centrally while keeping feature screens focused on:

    Layout
    +
    Content
    +
    Interaction
    +
    Business Workflow

The result should be a consistent:

    Arabic-first
    +
    RTL
    +
    Tablet-first
    +
    Accessible
    +
    Offline-first

Flutter UI system.