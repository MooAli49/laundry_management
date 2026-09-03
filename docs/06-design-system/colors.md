# Laundry Management System — Colors

## 1. Document Purpose

This document defines the centralized color system for the Laundry
Management System.

All application screens and components must use these semantic color
tokens instead of hardcoded color values.

The color system must support:

    Arabic-first UI
    +
    RTL
    +
    Tablet-first layouts
    +
    Light Theme
    +
    Clear Operational States
    +
    Accessibility
    +
    Consistent Branding

---

## 2. Color System Principles

The application must use semantic color roles.

Components should reference:

    Primary
    Secondary
    Background
    Surface
    Text
    Border
    Success
    Warning
    Error
    Info

rather than directly referencing raw color values.

For example:

    Correct:
        AppColors.primary

    Incorrect:
        Color(0xFF...)

The goal is to allow the entire visual system to be changed centrally
without modifying individual screens.

---

## 3. Theme

V1 uses:

    Light Theme

Dark Theme is not part of the current V1 implementation unless it is
explicitly added later.

The color system should nevertheless be structured semantically so a
future Dark Theme can be introduced without redesigning every component.

---

## 4. Brand Color

The Primary color represents the main brand/action color.

It is used for:

    Primary Buttons
    Active Navigation
    Primary Actions
    Selected Controls
    Important Interactive Elements
    Links when appropriate

The Primary color must not be used as a decorative color everywhere.

It should communicate:

    Action
    +
    Focus
    +
    Brand Identity

---

## 5. Primary Color Scale

The Primary color should be represented as a semantic scale rather than
a single raw value.

Conceptual tokens:

    primary
    primaryLight
    primaryLighter
    primaryDark
    onPrimary

Usage:

    primary
        Main interactive elements

    primaryLight
        Light backgrounds and selected states

    primaryLighter
        Subtle highlights

    primaryDark
        Strong emphasis / pressed states

    onPrimary
        Content displayed on Primary backgrounds

The final raw HEX values should be centralized in the Flutter theme.

---

## 6. Secondary Color

Secondary represents supporting actions and visual accents.

It may be used for:

    Secondary Actions
    Supporting Highlights
    Secondary Interactive Elements

Secondary must not compete visually with Primary.

The hierarchy should remain:

    Primary
        ↓
    Secondary
        ↓
    Neutral

---

## 7. Background Colors

The application requires clear separation between the application
background and content surfaces.

Semantic tokens:

    background
    backgroundSecondary

Usage:

    background
        Main application background

    backgroundSecondary
        Secondary sections or subtle grouping

The background should remain visually calm because the application is
used for long operational sessions.

---

## 8. Surface Colors

Surfaces are used for content containers.

Semantic tokens:

    surface
    surfaceElevated
    surfaceSelected
    surfaceDisabled

Usage:

    surface
        Standard cards, forms, tables and content containers

    surfaceElevated
        Elevated dialogs, menus and important floating elements

    surfaceSelected
        Selected rows/cards/controls

    surfaceDisabled
        Disabled interactive content

Surfaces should provide enough contrast against the application
background.

---

## 9. Text Colors

Text colors must use semantic roles.

Tokens:

    textPrimary
    textSecondary
    textTertiary
    textDisabled
    textOnPrimary
    textOnError
    textOnSuccess
    textOnWarning
    textOnInfo

Usage:

    textPrimary
        Main headings and important information

    textSecondary
        Supporting information

    textTertiary
        Metadata and less important information

    textDisabled
        Disabled controls

The application should avoid using pure black for every text element.

---

## 10. Border Colors

Borders should be subtle and consistent.

Tokens:

    border
    borderStrong
    borderFocused
    borderDisabled

Usage:

    border
        Standard input borders, cards and dividers

    borderStrong
        Important boundaries

    borderFocused
        Focused form controls

    borderDisabled
        Disabled controls

Borders should not visually dominate the content.

---

## 11. Divider Color

A dedicated divider token may be used:

    divider

It should be subtle enough to separate content without creating visual
noise.

Common usage:

    Table rows
    List sections
    Settings sections
    Payment history
    Order details

---

## 12. Success Color

Success communicates a completed or valid operation.

Token group:

    success
    successLight
    successDark
    onSuccess

Usage:

    Successful Save
    Completed Order
    Fully Paid
    Successful Storage
    Successful Synchronization

Examples of Arabic labels:

    تم الحفظ بنجاح
    مكتمل
    مدفوع بالكامل
    تم التخزين بنجاح

Success color must not be the only indicator of the state.

A readable status label must also be present.

---

## 13. Warning Color

Warning communicates attention without indicating failure.

Token group:

    warning
    warningLight
    warningDark
    onWarning

Usage:

    Remaining Payment
    Attention Required
    Pending Synchronization
    Important Operational Notice

Examples:

    متبقي 200.00 ج.م
    في انتظار المزامنة

Warning should not be used for ordinary neutral information.

---

## 14. Error Color

Error communicates invalid input, failed actions, or destructive states.

Token group:

    error
    errorLight
    errorDark
    onError

Usage:

    Validation Errors
    Failed Operations
    Important Destructive Actions
    Sync Attention when appropriate

Examples:

    المبلغ يجب أن يكون أكبر من صفر
    تعذر تحميل البيانات
    فشل تنفيذ العملية

Error should be used intentionally and not for every negative state.

---

## 15. Info Color

Info communicates neutral informational content.

Token group:

    info
    infoLight
    infoDark
    onInfo

Usage:

    Informational Messages
    Explanatory Notices
    Non-critical System Information

Info should remain visually weaker than Error and Warning.

---

## 16. Disabled Colors

Disabled controls should use dedicated semantic values.

Tokens:

    disabledBackground
    disabledBorder
    disabledText

Disabled content must remain distinguishable from active content.

Disabled does not mean:

    Error

Therefore disabled controls should not use Error colors.

---

## 17. Overlay Colors

Overlay colors are used for:

    Dialog Backdrops
    Bottom Sheet Backdrops
    Modal Layers

Token:

    overlay

The overlay should reduce background visibility without completely
destroying context.

---

## 18. Selection Colors

Selection states require dedicated semantic treatment.

Tokens:

    selectionBackground
    selectionBorder
    selectionContent

Used for:

    Selected Order
    Selected OrderItem
    Selected Storage Item
    Selected Customer
    Selected Payment Method
    Selected Filter

Selection must remain obvious without relying only on color.

---

## 19. Focus Colors

Interactive components should have a visible focus state.

Token:

    focus

It may be based on the Primary color but must provide sufficient visual
contrast against the component background.

Focus is particularly important for:

    Text Fields
    Dropdowns
    Buttons
    Selection Controls

---

## 20. Status Colors

Status colors should use semantic mappings.

Approved Order statuses:

    Processing
    Ready
    Completed
    Cancelled

Recommended semantic mapping:

    Processing
        → Info / Neutral

    Ready
        → Primary / Warning depending on visual hierarchy

    Completed
        → Success

    Cancelled
        → Error

The exact visual intensity should remain subtle.

The status text itself must always be visible.

---

## 21. Payment Status Colors

Payment states may use:

    Fully Paid
        → Success

    Remaining Amount
        → Warning / Attention

    Invalid Payment
        → Error

The financial value must always remain visible.

Example:

    المتبقي
    200.00 ج.م

The UI must not communicate the remaining amount through color alone.

---

## 22. Storage Status Colors

Storage states may use:

    Unstored
        → Neutral / Attention

    Stored
        → Success

    Syncing
        → Info

    Sync Attention
        → Warning / Error depending on severity

The UI must always include a readable state label.

---

## 23. Synchronization Colors

Synchronization states should remain subtle because synchronization is
normally a background operation.

Recommended semantic mapping:

    Synchronized
        → Success

    Syncing
        → Info

    Waiting for Sync
        → Warning / Neutral

    Sync Attention
        → Warning / Error

Synchronization status should not dominate the main business content.

---

## 24. Offline Color

Offline is not an application error.

The Offline indicator should therefore use:

    Neutral
    or
    Warning

rather than automatically using Error.

Example:

    غير متصل

The user should still be able to use supported Offline-first features.

---

## 25. Financial Colors

Financial information should remain visually neutral by default.

Do not automatically color every monetary value green.

Use semantic colors only when the value represents a meaningful state.

Examples:

    إجمالي الطلب
        → Neutral

    المدفوع
        → Neutral / Success when contextually appropriate

    المتبقي
        → Warning when attention is required

    Invalid Amount
        → Error

---

## 26. Action Colors

Primary action:

    Primary

Secondary action:

    Secondary / Neutral

Destructive action:

    Error

Disabled action:

    Disabled

The UI should not use Error for normal secondary actions.

---

## 27. Destructive Actions

Destructive actions should use the Error semantic color.

Examples:

    إلغاء الطلب
    تعطيل الخدمة
    تعطيل موقع التخزين

Destructive color should be used for the action itself and important
confirmation context.

It should not flood the entire screen with red.

---

## 28. Form Colors

Form controls should use consistent semantic states.

Default:

    surface
    +
    border

Focused:

    surface
    +
    borderFocused

Valid:

    Standard / Success only when validation feedback is useful

Invalid:

    error
    +
    errorLight
    +
    error text

Disabled:

    disabledBackground
    +
    disabledBorder
    +
    disabledText

---

## 29. Search Colors

Search fields should follow the standard form color system.

Default:

    surface
    border

Focused:

    focus
    borderFocused

Search results should use:

    surface
    +
    textPrimary
    +
    textSecondary

Selected result:

    selectionBackground
    +
    selectionBorder

---

## 30. Table Colors

Tables should remain visually lightweight.

Use:

    surface
    background
    border
    divider

for normal table structure.

Selected row:

    selectionBackground

Hover / interaction state when supported:

    subtle primary-based state

Do not use strong colors for every table row.

---

## 31. Navigation Colors

Navigation should clearly distinguish the active destination.

Recommended semantic usage:

    Active
        → Primary

    Inactive
        → textSecondary

    Hover / Interaction
        → subtle Primary-based surface

    Disabled
        → textDisabled

The active navigation state must be recognizable without relying only
on color.

---

## 32. Cards

Cards should normally use:

    surface

with:

    border

or subtle elevation according to the Design System.

Avoid assigning a different background color to every card.

Semantic cards such as:

    Success
    Warning
    Error

may use very light semantic backgrounds.

---

## 33. Semantic Backgrounds

Light semantic backgrounds should be used for:

    Success
    Warning
    Error
    Info

They should be significantly lighter than their corresponding semantic
foreground colors.

The purpose is:

    Communicate state
        +
    Preserve readability
        +
    Avoid visual overload

---

## 34. Contrast

All foreground/background combinations must provide sufficient
contrast.

Important information must remain readable under normal tablet
conditions.

Do not use:

    Light Gray Text on White
    +
    Low-contrast Borders
    +
    Very Light Status Text

just for visual minimalism.

Accessibility takes priority over decoration.

---

## 35. Color and Arabic Typography

Colors must work with the application's Arabic typography system.

Do not use extremely low-contrast secondary text because Arabic glyphs
can become difficult to read at smaller sizes.

Primary and secondary text must remain clearly distinguishable.

---

## 36. Color and RTL

Color semantics are independent from layout direction.

Do not use:

    Left = Error
    Right = Success

or any directional assumption.

Status meaning must remain correct in RTL.

---

## 37. Color and Icons

Icons may use semantic colors, but icons must not be the only state
indicator.

Correct:

    Success Icon
    +
    تم الحفظ بنجاح

Incorrect:

    Green Icon Only

This applies to:

    Success
    Warning
    Error
    Offline
    Sync
    Status

---

## 38. Color and Animation

Animations should not be the only indication of a state.

For example:

    Syncing animation

must also have:

    جاري المزامنة

as a readable state.

---

## 39. Raw Color Values

Raw HEX/RGB values must be defined centrally.

Feature screens must never introduce their own raw color values.

Avoid:

    Color(0xFF...)

inside feature-specific UI unless the value belongs to the centralized
Design System definition itself.

---

## 40. Flutter Naming Convention

The Flutter implementation should expose semantic colors through a
centralized class.

Conceptually:

    AppColors.primary
    AppColors.secondary
    AppColors.background
    AppColors.surface
    AppColors.textPrimary
    AppColors.textSecondary
    AppColors.border
    AppColors.success
    AppColors.warning
    AppColors.error
    AppColors.info

The exact implementation may use ThemeExtension or another centralized
theme mechanism according to the approved Architecture.

---

## 41. Color Token Categories

The complete semantic color structure is:

    Brand
        primary
        primaryLight
        primaryLighter
        primaryDark
        onPrimary

    Secondary
        secondary
        secondaryLight
        secondaryDark
        onSecondary

    Background
        background
        backgroundSecondary

    Surface
        surface
        surfaceElevated
        surfaceSelected
        surfaceDisabled

    Text
        textPrimary
        textSecondary
        textTertiary
        textDisabled
        textOnPrimary
        textOnSuccess
        textOnWarning
        textOnError
        textOnInfo

    Border
        border
        borderStrong
        borderFocused
        borderDisabled
        divider

    Semantic
        success
        successLight
        successDark
        onSuccess

        warning
        warningLight
        warningDark
        onWarning

        error
        errorLight
        errorDark
        onError

        info
        infoLight
        infoDark
        onInfo

    Interaction
        focus
        selectionBackground
        selectionBorder
        selectionContent

    Disabled
        disabledBackground
        disabledBorder
        disabledText

    Overlay
        overlay

---

## 42. Color Hierarchy

The visual hierarchy should generally follow:

    Primary
        ↓
    Secondary
        ↓
    Semantic
        ↓
    Neutral

Neutral colors should dominate most of the application.

Primary and semantic colors should be reserved for meaningful actions
and states.

---

## 43. Avoiding Color Overuse

Do not color:

    Every Card
    Every Button
    Every Section
    Every Table Row
    Every Label

The application should feel calm and professional.

Color should communicate meaning, not decoration.

---

## 44. Consistency Rule

The same semantic meaning must always use the same color family.

For example:

    Success

must not be green in one screen and blue in another.

Likewise:

    Error

must not change color depending on the feature.

---

## 45. Final Color Principle

> Color is a communication system, not decoration.

The Laundry Management System should use color to communicate:

    Brand
    +
    Action
    +
    State
    +
    Attention
    +
    Feedback

while keeping the overall interface clean, professional, readable, and
appropriate for long daily operational use.