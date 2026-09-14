# Laundry Management System — Spacing

## 1. Document Purpose

This document defines the centralized spacing system for the Laundry
Management System.

The spacing system provides a consistent spatial language across:

    Screens
    +
    Sections
    +
    Cards
    +
    Forms
    +
    Lists
    +
    Tables
    +
    Dialogs
    +
    Navigation
    +
    Components

The goal is to make the interface:

    Organized
    +
    Readable
    +
    Consistent
    +
    Tablet-friendly
    +
    Easy to scan
    +
    Easy to maintain

---

## 2. Spacing Principles

Spacing should communicate hierarchy and grouping.

Use spacing to distinguish:

    Screen Sections
    +
    Related Content
    +
    Separate Content
    +
    Interactive Controls

The application should not rely on borders or colors to separate every
piece of information.

Whitespace should be intentional.

---

## 3. Base Spacing Unit

The primary spacing system uses a base unit of:

    4 px

All standard spacing values should be multiples of 4.

This provides a predictable visual rhythm.

---

## 4. Spacing Scale

The centralized spacing scale is:

    4 px
    8 px
    12 px
    16 px
    20 px
    24 px
    32 px
    40 px
    48 px
    64 px

These values should cover the majority of application layouts.

Do not introduce arbitrary spacing values unless there is a clear
component-specific reason.

---

## 5. Spacing Token Names

The Flutter implementation should expose semantic spacing tokens.

Conceptually:

    xs
    sm
    md
    lg
    xl
    xxl
    xxxl

Recommended mapping:

    xs
        4 px

    sm
        8 px

    md
        12 px

    lg
        16 px

    xl
        20 px

    xxl
        24 px

    xxxl
        32 px

Additional larger layout spacing:

    section
        40 px

    page
        48 px

    major
        64 px

The exact naming may be adjusted during Flutter implementation as long
as the system remains centralized and consistent.

---

## 6. Micro Spacing

Use:

    4 px

for very small visual relationships.

Examples:

    Icon to text
    +
    Badge content
    +
    Small label relationships
    +
    Tight metadata

Do not use 4 px as the default spacing between unrelated content.

---

## 7. Small Spacing

Use:

    8 px

for closely related elements.

Examples:

    Label to helper text
    +
    Icon to label
    +
    Small list metadata
    +
    Compact component content

---

## 8. Medium Spacing

Use:

    12 px

for normal internal relationships.

Examples:

    Form fields
    +
    List row content
    +
    Card content groups
    +
    Small component sections

---

## 9. Standard Component Spacing

Use:

    16 px

as the primary component spacing value.

Typical usage:

    Card padding
    +
    Screen content gaps
    +
    Form field spacing
    +
    List item padding
    +
    Button groups

16 px should be one of the most frequently used values in the
application.

---

## 10. Large Component Spacing

Use:

    20 px

for slightly larger internal separation.

Examples:

    Major form groups
    +
    Important card sections
    +
    Summary blocks

Use 20 px only when 16 px does not provide sufficient hierarchy.

---

## 11. Section Spacing

Use:

    24 px

to separate major sections within the same screen.

Examples:

    Customer Information
        ↓ 24 px
    Order Information

    Order Summary
        ↓ 24 px
    Payment History

    Dashboard Metrics
        ↓ 24 px
    Recent Orders

24 px should communicate a meaningful section boundary.

---

## 12. Major Section Spacing

Use:

    32 px

when separating major screen areas.

Examples:

    Page Header
        ↓ 32 px
    Main Content

    Main Content
        ↓ 32 px
    Secondary Content

32 px should be used sparingly.

---

## 13. Screen-Level Spacing

The primary tablet layout should use consistent horizontal page padding.

Recommended:

    24 px

for standard tablet content areas.

Where the screen is wide enough, content may use a maximum readable width
rather than continuously expanding.

---

## 14. Large Screen Padding

For very wide layouts, content should not become excessively stretched.

Use:

    Maximum Content Width

with:

    Centered Content

when appropriate.

The exact maximum width depends on the screen composition.

The goal is to preserve readable information density.

---

## 15. Small Screen Padding

On smaller supported screens, horizontal padding may reduce to:

    16 px

The layout should remain visually consistent with the tablet version.

Do not reduce padding so aggressively that controls touch the screen edges.

---

## 16. Page Header Spacing

A typical page header should use:

    Page Edge
        ↓
    24 px
    Page Title
        ↓
    16–24 px
    Header Actions / Content

The exact spacing depends on the screen structure.

---

## 17. Screen Title to Content

The standard relationship is:

    Page Title
        ↓
    24 px
    Main Content

For compact screens this may be reduced to:

    16 px

when required by available space.

---

## 18. Section Title Spacing

A section should generally follow:

    Previous Content
        ↓
    24 px
    Section Title
        ↓
    12–16 px
    Section Content

This creates clear grouping without excessive whitespace.

---

## 19. Card Padding

Standard card padding:

    16 px

For dense cards:

    12 px

For large summary cards:

    20 px

The padding should remain consistent across cards with the same semantic
role.

---

## 20. Card Internal Spacing

Typical structure:

    Card Padding
        ↓
    Title
        ↓
    8–12 px
    Supporting Content
        ↓
    12–16 px
    Main Value / Action

Do not use excessive spacing inside compact operational cards.

---

## 21. Metric Card Spacing

Dashboard and Report metric cards should use:

    16–20 px

internal padding.

Typical hierarchy:

    Metric Label
        ↓
    8 px
    Metric Value
        ↓
    8–12 px
    Supporting Information

Large values should have enough surrounding whitespace to remain visually
prominent.

---

## 22. Form Spacing

Forms should use predictable vertical spacing.

Recommended:

    Label
        ↓
    8 px
    Input
        ↓
    12–16 px
    Next Field

Related fields may be grouped more tightly.

Unrelated field groups should use:

    24 px

---

## 23. Form Section Spacing

For larger forms:

    Section Title
        ↓
    16 px
    Fields
        ↓
    24 px
    Next Section

This is especially useful for:

    Customer Forms
    +
    Order Forms
    +
    Service Settings
    +
    Storage Settings

---

## 24. Label to Input

Standard:

    8 px

Use this relationship consistently across:

    Text Fields
    Dropdowns
    Date Pickers
    Measurement Inputs
    Payment Inputs

---

## 25. Input to Helper Text

Recommended:

    4 px

Helper text should remain visually connected to the input.

---

## 26. Input to Validation Message

Recommended:

    4 px

The error should clearly belong to the affected input.

---

## 27. Field to Field Spacing

Standard:

    16 px

For tightly related fields:

    12 px

For separate field groups:

    24 px

---

## 28. Horizontal Field Groups

When multiple fields appear in one row:

    Field
        ↓
    16 px
    Field

The spacing should be large enough to prevent accidental interaction.

On smaller screens, fields may stack vertically.

---

## 29. Button Spacing

Buttons in a group should normally use:

    8–12 px

between adjacent buttons.

Primary and secondary actions should remain visually distinct.

---

## 30. Button Internal Padding

Button content should have sufficient touch area.

Recommended conceptual padding:

    Horizontal
        16–20 px

    Vertical
        10–12 px

The final button height should follow the component specification.

---

## 31. Touch Target

Interactive controls should provide a minimum practical touch target of:

    44 × 44 px

where possible.

For primary tablet interactions, larger controls may be appropriate.

The goal is:

    Easy Touch
        +
    Low Error Rate
        +
    Fast Operation

---

## 32. Icon to Text Spacing

Standard:

    8 px

Use between:

    Icon
        +
    Text

This applies to:

    Buttons
    Navigation
    List Items
    Status Indicators
    Actions

---

## 33. Icon to Icon Spacing

When multiple actions appear together:

    8–12 px

Avoid placing icons directly beside each other without sufficient
separation.

---

## 34. List Spacing

Standard list item padding:

    12–16 px

Depending on density.

List items should have enough vertical space for easy tablet interaction.

---

## 35. List Item Internal Structure

Typical:

    Item Padding
        ↓
    Primary Content
        ↓
    4–8 px
    Secondary Content
        ↓
    Action / Metadata

The item should remain visually compact.

---

## 36. Order List Spacing

Order rows/cards should prioritize:

    Order Number
    +
    Customer
    +
    Status
    +
    Financial Summary

Spacing should allow quick scanning.

Avoid excessive vertical content.

---

## 37. Order Details Spacing

Order Details should use larger section separation.

Recommended:

    Header
        ↓
    24 px
    Customer Section
        ↓
    24 px
    Items Section
        ↓
    24 px
    Financial Section
        ↓
    24 px
    Payment Section

The exact sections depend on the approved screen design.

---

## 38. Order Item Spacing

Order Items should use compact spacing because multiple physical items
may appear on the same screen.

Recommended:

    Item Padding
        12 px

with:

    8 px

between closely related item values.

---

## 39. Storage Spacing

Storage requires higher operational density.

Recommended:

    Card Padding
        12–16 px

    Item-to-item gap
        8–12 px

    Section spacing
        16–24 px

The user should be able to see many relevant physical items without
making the interface difficult to touch.

---

## 40. Customer List Spacing

Customer rows should use:

    12–16 px

vertical padding.

Primary information:

    Name

Secondary information:

    Phone

The spacing should allow quick scanning of many Customers.

---

## 41. Payment History Spacing

Payment history should remain compact.

Recommended:

    Row padding
        12 px

    Related content gap
        4–8 px

    Payment-to-payment gap
        8 px

The Payment History should not dominate Order Details.

---

## 42. Payment Summary Spacing

Payment Summary should have clear grouping.

Example:

    إجمالي الطلب
        ↓
    8 px
    Value
        ↓
    16 px
    المدفوع
        ↓
    8 px
    Value
        ↓
    16 px
    المتبقي
        ↓
    8 px
    Value

The Remaining Amount may receive stronger visual emphasis.

---

## 43. Reports Spacing

Reports need clear hierarchy.

Recommended:

    Page Header
        ↓
    24 px
    Filters
        ↓
    24 px
    Summary Metrics
        ↓
    24 px
    Main Report
        ↓
    24 px
    Detailed Results

The spacing should support scanning rather than decoration.

---

## 44. Report Metric Spacing

Metric cards should use:

    16–20 px

internal padding.

Between metric cards:

    16 px

On smaller screens:

    12–16 px

depending on available width.

---

## 45. Settings Spacing

Settings should follow a structured hierarchy.

Recommended:

    Page Header
        ↓
    24 px
    Settings Section
        ↓
    16 px
    Fields / List
        ↓
    24 px
    Next Section

---

## 46. Navigation Spacing

Primary navigation items should have enough spacing for comfortable
touch interaction.

Recommended:

    8–12 px

between related navigation elements.

Navigation content should not feel crowded.

---

## 47. Bottom Navigation Spacing

If a bottom navigation pattern is used on smaller screens:

    Icon
        ↓
    4 px
    Label

with sufficient vertical padding to maintain the required touch target.

---

## 48. Dialog Spacing

Standard dialog padding:

    24 px

Typical structure:

    Dialog Padding
        ↓
    Title
        ↓
    12–16 px
    Content
        ↓
    24 px
    Actions

Dialogs should remain compact.

---

## 49. Bottom Sheet Spacing

Recommended:

    Top Padding
        24 px

    Horizontal Padding
        16–24 px

    Title to Content
        16 px

    Option to Option
        8–12 px

Bottom Sheets should provide enough vertical room for comfortable
selection.

---

## 50. Empty State Spacing

Recommended structure:

    Illustration / Icon
        ↓
    16 px
    Title
        ↓
    8 px
    Description
        ↓
    16–24 px
    Action

The Empty State should remain visually centered when used as a standalone
screen state.

---

## 51. Error State Spacing

Recommended structure:

    Error Icon
        ↓
    16 px
    Title
        ↓
    8 px
    Description
        ↓
    16–24 px
    Retry Action

Error states should remain clear without becoming visually aggressive.

---

## 52. Loading State Spacing

Loading components should preserve the final layout structure when
possible.

Prefer:

    Skeleton
        ↓
    Same spacing as actual content

instead of changing the entire screen layout during loading.

---

## 53. Skeleton Spacing

Skeleton placeholders should follow the same:

    Padding
    +
    Gap
    +
    Height

as the actual content they represent.

This reduces layout shift.

---

## 54. Table Spacing

Tables should use consistent:

    Cell Padding
    +
    Row Height
    +
    Column Gap

Recommended conceptual cell padding:

    Horizontal
        12–16 px

    Vertical
        12 px

Dense tables may reduce vertical padding where necessary.

---

## 55. Table Column Spacing

Columns should have sufficient separation to prevent values from merging
visually.

Use:

    16–24 px

depending on content density.

Financial columns should remain especially easy to scan.

---

## 56. Search Spacing

Search field:

    Standard height according to component system

Search to filters:

    12–16 px

Search/filter area to content:

    16–24 px

Search should remain visually grouped with its controls.

---

## 57. Filter Spacing

Filter controls should use:

    8–12 px

between adjacent controls.

Filter groups should use:

    16 px

from the main content.

---

## 58. Status Badge Spacing

Status badges should use compact internal spacing.

Recommended:

    Horizontal
        8–12 px

    Vertical
        4–6 px

Status badges should not become oversized buttons.

---

## 59. Chip Spacing

If chips are used for:

    Filters
    +
    Selected Items
    +
    Status

use:

    8 px

between chips.

Chip internal padding should remain consistent with the component
specification.

---

## 60. Section Grouping

Spacing should communicate whether content belongs together.

Use:

    8–16 px

for closely related information.

Use:

    24 px

for separate sections.

Use:

    32–48 px

for major layout divisions.

---

## 61. Vertical Rhythm

The application should maintain a consistent vertical rhythm.

Common vertical gaps should primarily use:

    4
    8
    12
    16
    24
    32

Avoid random values such as:

    13
    17
    19
    27

unless they are required by a specific component geometry.

---

## 62. Horizontal Rhythm

Horizontal spacing should follow the same base system.

Common values:

    8
    12
    16
    24
    32

This is especially important for:

    Forms
    Tables
    Cards
    Navigation
    Toolbar Actions

---

## 63. Grid Spacing

Tablet layouts may use a grid-based structure.

Recommended conceptual grid:

    4 px base
    +
    8 px rhythm

Cards and sections should align to common grid boundaries.

The exact number of columns depends on screen width.

---

## 64. Dashboard Grid

Dashboard metric cards should use:

    16 px

between cards.

Larger screen layouts may use multiple columns.

Smaller layouts should reduce the number of columns rather than shrinking
cards below practical usability.

---

## 65. Order Grid

Where Order Details uses multiple sections side by side on tablet:

    Column Gap
        16–24 px

Sections should maintain consistent internal padding.

---

## 66. Storage Grid

Storage may use a denser grid because many items can be displayed.

Recommended:

    8–16 px

between Storage cards.

The exact gap depends on the card size and number of columns.

---

## 67. Responsive Spacing

Spacing may adapt by screen size while preserving semantic hierarchy.

Example:

    Tablet
        Page Padding = 24 px

    Smaller Screen
        Page Padding = 16 px

Likewise:

    Section Gap
        Tablet = 24 px
        Smaller Screen = 16–20 px

Do not create entirely separate spacing systems for different devices.

---

## 68. Safe Areas

The application must respect:

    System Safe Areas
    +
    Device Insets

Content should not be placed directly underneath:

    System Navigation
    +
    Device Notches
    +
    Other System UI

The final implementation should use the platform's safe-area mechanisms.

---

## 69. Scroll Spacing

Scrollable screens should include enough bottom spacing to ensure the
last interactive element is comfortably reachable.

Avoid placing the final button directly against the screen edge.

Recommended bottom content spacing:

    24–32 px

depending on the screen context.

---

## 70. Sticky Actions

If a screen uses a sticky bottom action:

    Bottom Padding
        +
    Safe Area
        +
    Action Height

must provide sufficient separation from the final content.

The sticky action must not cover important content.

---

## 71. Form Action Area

For forms with a bottom action area:

    Form Content
        ↓
    24 px
    Action Area

If the action is sticky, additional bottom content padding must be
included.

---

## 72. Spacing and Touch Interaction

Spacing must support fast physical operation.

Especially for:

    Storage
    +
    Orders
    +
    Customer Selection
    +
    Payment Entry

Avoid putting destructive or unrelated actions too close together.

---

## 73. Spacing and Error Messages

When validation errors appear, spacing should expand naturally enough to
display the message without overlapping neighboring fields.

The layout must not rely on fixed heights that assume no validation text.

---

## 74. Spacing and Dynamic Content

Components must support:

    Long Arabic Names
    +
    Long Service Names
    +
    Long Customer Names
    +
    Large Financial Values
    +
    Multiple OrderItems

Spacing should not break when content grows.

Do not use fixed heights where content may wrap.

---

## 75. Spacing and Arabic

RTL does not change the spacing scale.

However, Arabic text may require:

    Additional line height
    +
    Additional vertical breathing room

when compared with very compact Latin layouts.

Typography and spacing must work together.

---

## 76. Spacing and Components

Reusable components must consume centralized spacing tokens.

Examples:

    AppButton
        → Button Padding

    AppTextField
        → Label/Input Gap

    AppCard
        → Card Padding

    StatusBadge
        → Badge Padding

    MetricCard
        → Metric Spacing

    AppDialog
        → Dialog Padding

Components must not independently invent spacing systems.

---

## 77. Spacing and Design Tokens

The Flutter implementation should expose spacing centrally.

Conceptually:

    AppSpacing.xs
    AppSpacing.sm
    AppSpacing.md
    AppSpacing.lg
    AppSpacing.xl
    AppSpacing.xxl
    AppSpacing.xxxl

Additional semantic values may include:

    AppSpacing.section
    AppSpacing.page
    AppSpacing.major

---

## 78. No Hardcoded Layout Spacing

Feature screens should avoid arbitrary values such as:

    SizedBox(height: 17)

when an approved spacing token already represents the required
relationship.

Prefer:

    AppSpacing.md

or the appropriate semantic token.

---

## 79. Exceptions

A component may use a custom spacing value only when:

    The component has a real geometric requirement
        +
    The value is documented
        +
    The value is centralized where appropriate

Do not use exceptions simply because a screen was difficult to align.

---

## 80. Final Spacing Hierarchy

The general hierarchy is:

    4 px
        Micro relationship

    8 px
        Close relationship

    12 px
        Standard compact relationship

    16 px
        Standard component spacing

    24 px
        Section separation

    32 px
        Major separation

    40–48 px
        Page-level separation

    64 px
        Major visual separation

---

## 81. Final Spacing Principle

> Spacing should make relationships obvious before the user reads every
> word.

The Laundry Management System should use spacing to create:

    Clear Grouping
    +
    Strong Hierarchy
    +
    Comfortable Touch Targets
    +
    Efficient Information Density
    +
    Consistent Visual Rhythm

while avoiding unnecessary whitespace or cramped operational layouts.