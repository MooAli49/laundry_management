# Laundry Management System — Typography

## 1. Document Purpose

This document defines the centralized typography system for the Laundry
Management System.

The typography system must provide:

    Arabic-first readability
    +
    RTL support
    +
    Clear information hierarchy
    +
    Tablet readability
    +
    Consistent component behavior
    +
    Accessibility

All screens and components must use the centralized typography system.

Feature-specific screens must not introduce independent typography
styles without a documented reason.

---

## 2. Typography Principles

Typography should prioritize:

    Readability
    +
    Hierarchy
    +
    Consistency
    +
    Operational Speed

The application is used during daily operational work.

Therefore typography must remain easy to scan and understand for long
periods of use.

Avoid decorative typography that reduces readability.

---

## 3. Language Direction

The application is Arabic-first.

Typography must be designed around Arabic text rather than treating
Arabic as a translated version of an English UI.

The default text direction is:

    RTL

English technical terms may appear where they are part of approved
product terminology, but the surrounding interface remains RTL.

---

## 4. Font Family

The application should use a high-quality Arabic-compatible font as the
primary font family.

The selected font must support:

    Arabic
    Latin
    Numbers
    Common punctuation

The same primary font family should be used consistently throughout the
application.

A suitable production choice is:

    IBM Plex Sans Arabic

The font should be bundled or configured centrally rather than selected
independently by individual screens.

---

## 5. Font Fallback

A fallback font stack should be defined for cases where a required glyph
is unavailable.

The fallback system should support:

    Arabic
    Latin
    Numbers
    Common Symbols

The UI must not unexpectedly switch between visually incompatible fonts
within the same component.

---

## 6. Font Weight

The typography system should use a limited set of weights.

Recommended weights:

    Regular
    Medium
    SemiBold
    Bold

Avoid excessive use of very heavy weights.

Recommended semantic usage:

    Regular
        Body and supporting content

    Medium
        Labels and interactive content

    SemiBold
        Section titles and important values

    Bold
        Major headings and critical emphasis

---

## 7. Typography Scale

The application should use a centralized typography scale.

Recommended V1 scale:

    Display Large
        32 px

    Display Medium
        28 px

    Heading Large
        24 px

    Heading Medium
        20 px

    Heading Small
        18 px

    Body Large
        16 px

    Body Medium
        14 px

    Body Small
        13 px

    Caption
        12 px

The exact rendered size may be adjusted responsively while preserving
the semantic hierarchy.

---

## 8. Display Large

Recommended:

    32 px
    Bold

Use for:

    Major Dashboard values
    Important summary numbers
    Large page-level emphasis

Do not use Display Large for normal body content.

---

## 9. Display Medium

Recommended:

    28 px
    Bold / SemiBold

Use for:

    Large metric values
    Major financial summaries
    High-level operational indicators

Example:

    1,250.50 ج.م

---

## 10. Heading Large

Recommended:

    24 px
    SemiBold / Bold

Use for:

    Main screen titles
    Major section titles
    Important detail headings

Example:

    تفاصيل الطلب

---

## 11. Heading Medium

Recommended:

    20 px
    SemiBold

Use for:

    Section headings
    Card headings
    Important grouped content

Example:

    بيانات العميل

---

## 12. Heading Small

Recommended:

    18 px
    SemiBold

Use for:

    Smaller section titles
    Dialog titles
    Bottom Sheet titles
    Important component headings

---

## 13. Body Large

Recommended:

    16 px
    Regular / Medium

Use for:

    Primary body content
    Form values
    Important descriptions
    Main list information

This is the primary operational text size.

---

## 14. Body Medium

Recommended:

    14 px
    Regular / Medium

Use for:

    Supporting content
    Secondary labels
    Table content
    Metadata
    Form helper text

---

## 15. Body Small

Recommended:

    13 px
    Regular / Medium

Use for:

    Dense supporting information
    Secondary metadata
    Compact table information

Do not use Body Small for essential information when a larger size is
appropriate.

---

## 16. Caption

Recommended:

    12 px
    Regular / Medium

Use for:

    Minor metadata
    Auxiliary information
    Small status details

Caption must not be used for primary information.

---

## 17. Line Height

Arabic text requires sufficient vertical space for readability.

Recommended approximate line heights:

    Display Large
        1.25

    Display Medium
        1.25

    Heading Large
        1.30

    Heading Medium
        1.35

    Heading Small
        1.35

    Body Large
        1.50

    Body Medium
        1.50

    Body Small
        1.45

    Caption
        1.40

The final Flutter implementation should use appropriate TextStyle
metrics rather than relying on arbitrary per-screen values.

---

## 18. Letter Spacing

Arabic typography generally requires restrained letter spacing.

The default should be:

    0

Avoid applying aggressive positive letter spacing to Arabic text.

Letter spacing may be adjusted only when required for a specific Latin
or numeric presentation.

---

## 19. Text Alignment

Default Arabic text alignment:

    Start

The UI should generally avoid hardcoded:

    left
    right

Use logical alignment so the same components remain correct in RTL.

---

## 20. Text Hierarchy

The visual hierarchy should generally follow:

    Page Title
        ↓
    Section Heading
        ↓
    Primary Content
        ↓
    Secondary Content
        ↓
    Metadata

Hierarchy should be created through a combination of:

    Size
    +
    Weight
    +
    Color
    +
    Spacing

Do not rely only on font size.

---

## 21. Page Titles

Page titles should use:

    Heading Large

Examples:

    الرئيسية
    الطلبات
    التخزين
    العملاء
    التقارير
    الإعدادات

Page titles should remain visually consistent across the application.

---

## 22. Section Titles

Section titles should generally use:

    Heading Medium

Examples:

    الطلبات الأخيرة
    بيانات العميل
    تفاصيل الدفع
    عناصر الطلب

Section titles should clearly separate logical content groups.

---

## 23. Card Titles

Card titles should generally use:

    Heading Small

or:

    Body Large + SemiBold

depending on the amount of available space.

Cards should not create their own typography hierarchy.

---

## 24. Body Text

Primary body text should generally use:

    Body Large

Supporting text should generally use:

    Body Medium

Body text should remain readable without zooming on the primary tablet
experience.

---

## 25. Labels

Form labels should generally use:

    Body Medium
    Medium

Labels must remain clearly associated with their corresponding controls.

Example:

    اسم العميل

    [ محمد أحمد ]

---

## 26. Input Text

Input values should generally use:

    Body Large
    Regular / Medium

Input text must be visually stronger than helper text.

---

## 27. Helper Text

Helper text should generally use:

    Body Small

It should use:

    textSecondary

unless the helper message communicates an error.

---

## 28. Validation Text

Validation messages should generally use:

    Body Small
    Medium

with:

    error

semantic color.

Example:

    رقم الهاتف غير صحيح

Validation text must remain readable and should not be excessively
small.

---

## 29. Error Text

Error messages should use the centralized error text style.

Example:

    تعذر تحميل الطلبات

The error message should communicate:

    What happened
        +
    What the user can do

when possible.

---

## 30. Success Text

Success messages should use:

    Body Medium
    Medium

with the Success semantic color when appropriate.

Example:

    تم تسجيل الدفعة بنجاح

Do not use oversized success messages for routine operations.

---

## 31. Status Labels

Order and operational statuses should use:

    Body Small
    or
    Body Medium

with:

    Medium

weight.

Examples:

    قيد التنفيذ
    جاهز للتسليم
    مكتمل
    ملغي

The status label must remain readable independently of its color.

---

## 32. Button Typography

Primary and secondary buttons should generally use:

    Body Medium
    Medium / SemiBold

Buttons should have clear readable labels.

Examples:

    إضافة طلب
    حفظ
    إلغاء
    تأكيد الدفع

Avoid overly small button text.

---

## 33. Navigation Typography

Navigation labels should generally use:

    Body Medium
    Medium

Active and inactive navigation items should preserve the same basic
typography while using the Design System's color hierarchy.

Do not make active navigation items dramatically larger.

---

## 34. Table Typography

Tables may use a denser typography scale.

Recommended:

    Header
        Body Small / Medium
        SemiBold

    Row Content
        Body Medium

    Secondary Metadata
        Body Small

The table must remain readable on the primary tablet layout.

---

## 35. Table Headers

Table headers should use:

    SemiBold

with:

    textSecondary
    or
    textPrimary

depending on the visual hierarchy.

Headers should be visually distinct from row content without becoming
dominant.

---

## 36. Financial Typography

Financial values require strong visual hierarchy.

Examples:

    إجمالي الطلب
    1,250.50 ج.م

    المدفوع
    800.00 ج.م

    المتبقي
    450.50 ج.م

The amount should normally use a stronger style than its label.

Recommended:

    Label
        Body Medium

    Amount
        Heading Small / Heading Medium
        SemiBold

Important Dashboard financial metrics may use:

    Display Medium

---

## 37. Financial Number Formatting

Financial numbers must be displayed consistently.

Examples:

    50.00 ج.م
    1,250.50 ج.م

The UI must not display internal minor-unit values.

Financial formatting should be handled by a centralized formatting
utility.

---

## 38. Numeric Typography

Numbers should remain highly readable in Arabic RTL layouts.

Important numeric values such as:

    Order Number
    Prices
    Quantities
    Measurements
    Payment Amounts

must remain visually distinct from surrounding Arabic text.

---

## 39. Order Number Typography

Order Numbers such as:

    26-001

should use a stable readable style.

Recommended:

    Body Large
    Medium / SemiBold

The Order Number must remain visually easy to identify in:

    Order List
    Order Details
    Search Results
    Reports

---

## 40. Phone Number Typography

Phone numbers should use:

    Body Large

or:

    Body Medium

depending on context.

The number should remain easy to scan and interact with.

Avoid unnecessarily mixing Arabic numerals and Latin formatting within
the same phone value.

---

## 41. Dates

Dates should generally use:

    Body Medium

Important dates may use:

    Body Large

The date format should follow the centralized localization rules.

Example:

    24 أغسطس 2026

The UI should not create different date formats across screens without
a documented reason.

---

## 42. Measurements

Measurements such as:

    kg
    m²
    cm

should use the same typography hierarchy as their associated numeric
value.

Example:

    5.5 كجم

The unit should remain visually connected to the value.

---

## 43. Search Typography

Search input:

    Body Large

Search result primary text:

    Body Large / Medium

Search result secondary text:

    Body Medium

Example:

    محمد أحمد
    01012345678

The primary identifier should be visually stronger than secondary
information.

---

## 44. Empty State Typography

Empty States should use:

    Title
        Heading Small

    Description
        Body Medium

    Action
        Body Medium / SemiBold

Example:

    لا توجد طلبات حتى الآن

    ابدأ بإضافة أول طلب.

    [ إضافة طلب ]

The Empty State should remain concise.

---

## 45. Error State Typography

Error State:

    Title
        Heading Small

    Description
        Body Medium

    Action
        Body Medium / SemiBold

Example:

    تعذر تحميل الطلبات

    تحقق من البيانات وحاول مرة أخرى.

    [ إعادة المحاولة ]

---

## 46. Dialog Typography

Dialog title:

    Heading Small

Dialog content:

    Body Medium

Dialog actions:

    Body Medium
    Medium / SemiBold

Dialogs should remain concise.

---

## 47. Bottom Sheet Typography

Bottom Sheet title:

    Heading Small

Options:

    Body Large

Supporting information:

    Body Medium

The selected option may use:

    Medium / SemiBold

The bottom sheet should remain easy to scan.

---

## 48. Form Section Typography

Forms may use section headings to separate logical groups.

Example:

    بيانات العميل

    بيانات الطلب

    التسعير

    الدفع

Section heading:

    Heading Small

Field labels:

    Body Medium

Field values:

    Body Large

This creates a predictable hierarchy.

---

## 49. Dashboard Typography

Dashboard hierarchy should generally be:

    Page Title
        ↓
    Summary Metric
        ↓
    Section Title
        ↓
    Operational Content

Large metrics may use:

    Display Medium

while normal operational information should remain within the Body and
Heading scales.

---

## 50. Order Details Typography

Order Details should prioritize:

    Order Number
    +
    Order Status
    +
    Customer
    +
    Financial Summary
    +
    Order Items

Recommended hierarchy:

    Order Number
        Heading Medium

    Status
        Body Medium / SemiBold

    Customer Name
        Body Large / SemiBold

    Financial Amounts
        Heading Small / Medium

    Item Details
        Body Medium

---

## 51. Storage Typography

Storage is a fast operational workflow.

The typography should prioritize:

    Order Number
    +
    Item Information
    +
    Storage Status
    +
    Storage Location

Primary item information:

    Body Large
    Medium

Supporting information:

    Body Medium

Status:

    Body Small / Medium
    Medium

Avoid excessive text in Storage cards.

---

## 52. Customer Typography

Customer List hierarchy:

    Customer Name
        Body Large
        Medium / SemiBold

    Phone
        Body Medium

    Supporting information
        Body Small

Customer Details should emphasize:

    Name
    +
    Phone
    +
    Order History

---

## 53. Reports Typography

Reports require strong numeric hierarchy.

Recommended:

    Report Title
        Heading Large

    Summary Metric
        Display Medium / Heading Medium

    Metric Label
        Body Medium

    Table Header
        Body Small / Medium
        SemiBold

    Table Value
        Body Medium

The visual hierarchy should make report scanning easy.

---

## 54. Settings Typography

Settings should use the standard form hierarchy.

Recommended:

    Page Title
        Heading Large

    Section Title
        Heading Medium

    Field Label
        Body Medium

    Input
        Body Large

    Helper Text
        Body Small

    Validation
        Body Small

---

## 55. Typography and Accessibility

The typography system must support:

    Readability
    +
    Adequate contrast
    +
    Clear hierarchy
    +
    Sufficient line height
    +
    Touch-friendly interfaces

Do not use tiny typography to fit too much information on the screen.

When information density becomes too high:

    Simplify the content
        or
    Improve layout

rather than continuously reducing font size.

---

## 56. Responsive Typography

The semantic typography hierarchy should remain consistent across
screen sizes.

On smaller screens:

    Large Display styles may scale slightly

but:

    Body
    Labels
    Inputs
    Important status text

must remain comfortably readable.

Do not create a completely different typography system for each device.

---

## 57. Typography Tokens

The Flutter implementation should expose centralized text styles.

Conceptually:

    AppTextStyles.displayLarge
    AppTextStyles.displayMedium

    AppTextStyles.headingLarge
    AppTextStyles.headingMedium
    AppTextStyles.headingSmall

    AppTextStyles.bodyLarge
    AppTextStyles.bodyMedium
    AppTextStyles.bodySmall

    AppTextStyles.caption

The exact implementation may use ThemeData / TextTheme or another
centralized theme mechanism according to the approved architecture.

---

## 58. No Screen-Specific Typography

Feature screens must not define arbitrary styles such as:

    TextStyle(
        fontSize: 17,
        fontWeight: ...
    )

when an existing semantic style already represents the intended role.

If a new typography style is genuinely needed, it should be added to the
centralized typography system.

---

## 59. Typography and Components

Reusable components must consume centralized typography tokens.

For example:

    AppButton
        → Button Typography

    AppTextField
        → Input Typography

    StatusBadge
        → Status Typography

    MetricCard
        → Metric Typography

    AppTable
        → Table Typography

This keeps the visual system consistent.

---

## 60. Typography and Color

Typography hierarchy should work together with the centralized color
system.

Example:

    Primary Heading
        textPrimary

    Supporting Text
        textSecondary

    Disabled Text
        textDisabled

    Error Message
        error

    Success Message
        success

Color should reinforce hierarchy, not replace it.

---

## 61. Typography and Spacing

Typography must work with the centralized spacing system.

Do not compensate for poor spacing by changing font sizes.

The intended relationship is:

    Typography
        +
    Spacing
        +
    Color

to create hierarchy.

---

## 62. Typography Consistency

The same semantic role must use the same typography style throughout the
application.

For example:

    Page Titles

must use the same style on:

    Dashboard
    Orders
    Storage
    Customers
    Reports
    Settings

Likewise:

    Form Labels
    Buttons
    Statuses
    Financial Values

must remain consistent.

---

## 63. Final Typography Principle

> Typography should make the operational workflow easy to scan, understand,
> and act on.

The system should feel:

    Arabic-first
    +
    Clear
    +
    Professional
    +
    Readable
    +
    Consistent

without relying on excessive font sizes, weights, or decorative styling.