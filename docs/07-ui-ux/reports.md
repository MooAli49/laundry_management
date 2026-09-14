# Laundry Management System — Reports

## 1. Document Purpose

This document defines the V1 Reports module and its UI/UX behavior.

The Reports module provides simple operational and financial reporting without becoming a full analytics or accounting system.

V1 contains two report categories:

    Orders Report
    Financial Report

The Reports module must remain:

    Simple
        +
    Clear
        +
    Useful
        +
    Arabic-first
        +
    RTL
        +
    Offline-first

Historical transaction values must remain accurate even when current master data changes. This is already established as a database/reporting requirement. :contentReference[oaicite:0]{index=0}

---

# 2. Reports Philosophy

Reports should answer practical business questions.

The user should be able to understand:

    What happened?
    How much business was done?
    How much money was received?
    How much money is still owed?
    How much was spent?
    What is the operating result?

The Reports module must not introduce unnecessary complexity.

V1 does not include:

    Advanced BI
    Predictive Analytics
    Complex Dashboards
    Service Analytics
    Storage Analytics
    Customer Analytics
    Employee Analytics
    Driver Analytics
    Full Accounting

The original product scope intentionally keeps Reports simple. :contentReference[oaicite:1]{index=1}

---

# 3. Report Categories

The Reports module contains:

    1. Orders Report
    2. Financial Report

No additional report category should be introduced in V1 without an approved Product decision.

---

# 4. Report Navigation

The primary Reports navigation should expose:

    التقارير

Inside Reports:

    تقرير الطلبات
    التقرير المالي

The exact UI may use tabs, cards, or a segmented navigation pattern depending on the final Figma design.

The user should be able to switch between the two report categories without unnecessary navigation.

---

# 5. Report Period

Both report categories support date-based filtering.

Approved predefined periods:

    اليوم
    أمس
    آخر 7 أيام
    هذا الشهر
    الشهر السابق
    نطاق مخصص

The user may select:

    نطاق مخصص

using:

    تاريخ من
    تاريخ إلى

Both dates must use a Date Picker.

Dates must not require manual entry using formats such as:

    08/25/2026

The preferred Arabic-friendly display is:

    25 أغسطس 2026

---

# 6. Date Range Rules

The selected report period must be clearly visible.

Example:

    هذا الشهر
    1 أغسطس 2026 — 31 أغسطس 2026

For Custom Range:

    من
    20 أغسطس 2026

    إلى
    25 أغسطس 2026

The report must update according to the selected period.

The UI should make it obvious which period is currently active.

---

# 7. Date Semantics

Different business events use different dates.

The Reports implementation must not use one generic timestamp for every report.

Examples:

    Order reporting
        ↓
    Approved Order reporting date

    Payment reporting
        ↓
    Payment.paidAt

    Expense reporting
        ↓
    Expense.date

The distinction is important because a transaction may be created at a different time from the business date relevant to reporting.

---

# 8. Offline-first Reports

Reports must work offline.

The local database is the primary operational data source.

The preferred flow is:

    Local Database
        ↓
    Repository
        ↓
    Report Calculation
        ↓
    Reports UI

The Reports screen must not require a network connection to display local historical data.

The original architecture explicitly requires Reports to use local historical data. :contentReference[oaicite:2]{index=2}

---

# 9. Reports and Synchronization

When synchronization is pending, the Reports module should use the latest locally available data.

The UI may show a subtle synchronization indicator.

Example:

    البيانات محدثة محليًا
    في انتظار المزامنة

The user must not be blocked from viewing Reports because remote synchronization is unavailable.

---

# 10. Orders Report

The Orders Report provides operational information about Orders during the selected period.

It must provide:

    إجمالي الطلبات
    الطلبات حسب الحالة
    إجمالي قيمة الطلبات
    الطلبات المتأخرة

These are the approved V1 Orders Report metrics. :contentReference[oaicite:3]{index=3}

---

# 11. Orders Report — Total Orders

The Orders Report must display:

    إجمالي الطلبات

This represents the number of Orders included in the selected reporting period according to the approved Order reporting date.

Example:

    إجمالي الطلبات
    42

The metric should be easy to scan.

---

# 12. Orders Report — Orders by Status

The report must provide a breakdown of Orders by status.

V1 statuses are:

    قيد التنفيذ
    جاهزة للتسليم
    مكتملة
    ملغاة

The report should show the count for each relevant status.

Example:

    قيد التنفيذ        12
    جاهزة للتسليم       8
    مكتملة              20
    ملغاة                2

The report must use the actual Domain status values.

---

# 13. Orders Report — Total Order Value

The report must display:

    إجمالي قيمة الطلبات

This represents the total value of Orders included in the selected period.

Historical Order values must be used.

The report must not recalculate old Orders using current Service prices.

Historical transaction values are explicitly required to remain independent from current Service pricing. :contentReference[oaicite:4]{index=4}

---

# 14. Orders Report — Overdue Orders

The report should display:

    الطلبات المتأخرة

An Order is overdue when:

    Expected Pickup Date < Today
        AND
    Status != Completed
        AND
    Status != Cancelled

The overdue count must respect the selected report period where applicable.

The Dashboard also uses this same business definition. The rule is established in the Business Rules documentation.

---

# 15. Orders Report Navigation

Order report metrics should be actionable where useful.

Examples:

    إجمالي الطلبات
        ↓
    Orders filtered by report period

    قيد التنفيذ
        ↓
    Orders filtered by Processing

    جاهزة للتسليم
        ↓
    Orders filtered by Ready

    مكتملة
        ↓
    Orders filtered by Completed

    ملغاة
        ↓
    Orders filtered by Cancelled

    الطلبات المتأخرة
        ↓
    Orders filtered by overdue condition

Navigation should preserve the selected period/filter context when possible.

---

# 16. Orders Report — No Service Analytics

The Orders Report must not include Service performance analytics.

Do not add:

    Most used service
    Service revenue
    Service profitability
    Service performance
    Service ranking

Service analytics are outside V1 scope.

---

# 17. Orders Report — No Customer Analytics

The Orders Report must not include customer analytics.

Do not add:

    Top customers
    Customer revenue ranking
    Customer lifetime value
    Customer retention
    Customer segmentation

Customer analytics are outside V1 scope.

---

# 18. Orders Report — No Storage Analytics

The Orders Report must not include Storage analytics.

Do not add:

    Storage utilization
    Location occupancy
    Storage performance
    Storage movement statistics

Storage remains an operational module.

---

# 19. Financial Report

The Financial Report provides the approved V1 financial summary for the selected reporting period.

The final V1 Financial Report includes:

    إجمالي المبيعات
    إجمالي المدفوعات
    إجمالي المصروفات
    المبالغ المتبقية
    إجمالي الخصومات
    طرق الدفع
    المصروفات حسب التصنيف
    صافي الربح

The Financial Report remains an operational financial summary rather than a complete accounting system.

---

# 20. Financial Report — Total Sales

The report must display:

    إجمالي المبيعات

This represents the total value of Orders included in the selected reporting period according to the approved Order reporting date.

Historical Order totals must be used.

The system must not reconstruct historical sales using current Service prices.

---

# 21. Financial Report — Total Payments

The report must display:

    إجمالي المدفوعات

Payment totals are based on Payments recorded during the selected reporting period.

The payment reporting date is:

    Payment.paidAt

This is separate from the Order creation date.

This distinction is explicitly established in the Business Rules. 

---

# 22. Financial Report — Outstanding Amounts

The report must display:

    المبالغ المتبقية

Outstanding amount is conceptually:

    Order Total
        -
    Total Payments

Outstanding Amount represents money still owed by customers.

It is not an Expense.

It must not reduce Net Profit.

---

# 23. Financial Report — Total Discounts

The report must display:

    إجمالي الخصومات

Discounts are applied at the Order level.

Item-level discounts are not part of V1.

The report must use the historical discount values recorded on the Orders.

Discounts must not be subtracted twice when calculating financial metrics.

---

# 24. Financial Report — Payment Methods

The report must provide a breakdown of payments by payment method.

V1 payment methods are:

    كاش
    InstaPay
    محفظة إلكترونية

The exact Arabic UI terminology should follow the approved Design System/product terminology.

Example:

    كاش              400 ج.م
    InstaPay          200 ج.م
    محفظة إلكترونية   100 ج.م

Payment method totals must be based on actual Payment transactions in the selected period.

---

# 25. Financial Report — Total Operating Expenses

The report must display:

    إجمالي المصروفات

This represents the total Operating Expenses recorded during the selected period.

Conceptually:

    Total Operating Expenses
        =
    SUM(Expense.amount)

The reporting date for an Expense is:

    Expense.date

not:

    Expense.createdAt

---

# 26. Financial Report — Expense Breakdown

The report must provide an Expense breakdown by Category.

Example:

    منظفات       300 ج.م
    كهرباء        200 ج.م
    صيانة         150 ج.م
    نقل            75 ج.م
    أخرى           50 ج.م

The breakdown must respect the selected reporting period.

---

# 27. Financial Report — Expense Categories

Expense Categories are manageable master data.

Initial categories:

    كهرباء
    مياه
    منظفات
    صيانة
    مستلزمات
    نقل
    أخرى

The user may later add, edit, activate, or deactivate categories through Settings.

The report must continue to display historical Expenses even if their Category becomes inactive.

---

# 28. Financial Report — Other Expenses

When an Expense uses:

    أخرى

the Expense has a required:

    اسم المصروف

Example:

    التصنيف:
    أخرى

    اسم المصروف:
    إصلاح باب المحل

The Financial Report may display the Category as:

    أخرى

and may display the custom Expense name in the detailed Expense context.

The custom name is part of the Expense transaction and must remain historically preserved.

---

# 29. Financial Report — Net Profit

Net Profit is an approved V1 Financial Report metric.

The formula is:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

Example:

    Total Sales
        1,000 ج.م

    Total Operating Expenses
        150 ج.م

    Net Profit
        850 ج.م

---

# 30. Net Profit — Payments Are Separate

Payments must not be subtracted from Net Profit.

Example:

    Total Sales       1,000 ج.م
    Payments            700 ج.م
    Expenses            150 ج.م

Net Profit remains:

    850 ج.م

The 700 ج.م Payments represent money received from customers.

They are not an additional expense.

---

# 31. Net Profit — Outstanding Amount Is Separate

Outstanding customer amounts must not be subtracted from Net Profit.

Example:

    Total Sales       1,000 ج.م
    Payments            700 ج.م
    Outstanding         300 ج.م
    Expenses            150 ج.م

Net Profit:

    850 ج.م

Outstanding Amount:

    300 ج.م

These values represent different business concepts.

---

# 32. Net Profit — Derived Value

Net Profit is a derived financial value.

It must not be stored as an independent financial transaction.

The application calculates it from:

    Total Sales
        -
    Total Operating Expenses

This prevents duplicated financial state.

---

# 33. Net Profit — Same Reporting Period

The same selected reporting period must be applied to:

    Total Sales
    Total Operating Expenses

Therefore:

    Net Profit
        =
    Sales for Selected Period
        -
    Expenses for Selected Period

The report must not combine sales from one period with expenses from another period.

---

# 34. Financial Report — Financial Independence

The Financial Report must preserve the distinction between:

    Sales
    Payments
    Outstanding Amounts
    Expenses
    Net Profit

These values must not be merged.

The core relationship is:

    Sales
        ↓
    Customer Payments
        ↓
    Remaining Amount

and separately:

    Business Expenses
        ↓
    Operating Costs

and:

    Sales - Operating Expenses
        ↓
    Net Profit

---

# 35. Financial Report — No Full Accounting

The Financial Report is not a full accounting system.

V1 does not include:

    Accounts Payable
    Supplier Accounting
    General Ledger
    Expense Approval
    Budgets
    Recurring Expenses
    Advanced Tax Accounting
    Cost Centers
    Accounting Period Closing
    Profit Margin Analysis

These features are outside the approved V1 scope.

---

# 36. Financial Report — No Service Analytics

The Financial Report must not introduce Service analytics.

Do not add:

    Revenue by Service
    Service profitability
    Service margin
    Service ranking

The report remains focused on the approved financial metrics.

---

# 37. Financial Report — No Storage Analytics

The Financial Report must not introduce Storage analytics.

Do not add:

    Storage utilization
    Storage occupancy
    Location performance
    Storage turnover

---

# 38. Financial Report — No Customer Analytics

The Financial Report must not introduce:

    Customer lifetime value
    Customer profitability
    Customer ranking
    Customer segmentation

These are outside V1.

---

# 39. Financial Report Layout

The Financial Report should be organized into clear sections.

Recommended structure:

    Report Header
        ↓
    Period Selector
        ↓
    Financial Summary
        ↓
    Payment Breakdown
        ↓
    Expense Breakdown
        ↓
    Net Profit
        ↓
    Optional Detailed Transactions

The final visual arrangement is subject to the final Figma design.

---

# 40. Financial Summary Cards

The primary Financial Report summary should contain the most important values.

Recommended cards:

    إجمالي المبيعات
    إجمالي المدفوعات
    إجمالي المصروفات
    المبالغ المتبقية
    صافي الربح

The cards should remain visually clear.

The UI should not make all metrics appear equally dominant.

---

# 41. Net Profit Visual Priority

Net Profit should be visually important because it is the final derived financial result.

However, it should not be presented as a complex analytics visualization.

A simple prominent metric is preferred.

Example:

    صافي الربح
    850 ج.م

The calculation should remain understandable.

---

# 42. Expense Visual Priority

Total Expenses should be clearly visible because Expenses directly affect Net Profit.

The UI should allow the user to understand:

    How much was spent?

and:

    Where was it spent?

The Expense Category breakdown provides the second answer.

---

# 43. Payment Breakdown Section

The Payment Breakdown section should show the distribution of payments by method.

Example:

    كاش
    400 ج.م

    InstaPay
    200 ج.م

    محفظة إلكترونية
    100 ج.م

The total should correspond to the Payments included in the selected period.

---

# 44. Expense Breakdown Section

The Expense Breakdown section should show:

    Category
    Amount

Example:

    منظفات
    300 ج.م

    كهرباء
    200 ج.م

    صيانة
    150 ج.م

The section should not become a complex charting system.

A clean list or simple visual breakdown is sufficient.

---

# 45. Expense Breakdown — Empty State

If there are no Expenses in the selected period:

    لا توجد مصروفات خلال هذه الفترة

The report should still show:

    إجمالي المصروفات
    0 ج.م

and:

    Net Profit
    Total Sales

should remain correctly calculated.

If:

    Total Sales = 1,000 ج.م
    Expenses = 0 ج.م

then:

    Net Profit = 1,000 ج.م

---

# 46. Payment Breakdown — Empty State

If no Payments were recorded in the selected period:

    لا توجد مدفوعات خلال هذه الفترة

The report should display:

    إجمالي المدفوعات
    0 ج.م

The presence of zero Payments does not mean there are zero Orders.

Outstanding amounts may still exist.

---

# 47. Orders Report Empty State

If no Orders exist in the selected period:

    لا توجد طلبات خلال هذه الفترة

The report should display zero values for the relevant metrics.

The user should still be able to change the reporting period.

---

# 48. Reports Loading State

Reports should load from local data.

If the local calculation takes time:

    Use a lightweight loading state.

Avoid unnecessary full-screen loading.

The user should not experience a long blocking state simply because synchronization is unavailable.

---

# 49. Reports Error State

If report data cannot be loaded because of an unexpected local application error:

    تعذر تحميل التقرير

Provide:

    إعادة المحاولة

when appropriate.

Technical errors must not be exposed directly.

Do not show:

    SQLite errors
    SQL exceptions
    Dio errors
    Retrofit errors
    Supabase errors
    Stack traces

to the user.

---

# 50. Reports Offline State

When offline:

    Reports remain usable using local data.

The UI may show a subtle:

    غير متصل

indicator.

The report must not require the remote API to calculate its basic V1 values.

---

# 51. Reports Synchronization State

If local data has not yet synchronized:

    The report uses the current local state.

The UI may communicate:

    توجد بيانات في انتظار المزامنة

The report must not hide local transactions simply because they have not yet reached the backend.

---

# 52. Reports and Historical Prices

Reports must always use historical transaction values.

Example:

    Service Price at Order Creation
        100 ج.م

Later:

    Current Service Price
        120 ج.م

Historical Order:

    Still 100 ج.م

The report must not recalculate the old Order as 120 ج.م.

This requirement is explicitly established in the existing database and architecture documentation. :contentReference[oaicite:5]{index=5} :contentReference[oaicite:6]{index=6}

---

# 53. Reports and Payment History

Payments are independent historical transactions.

If an Order has:

    Payment 1 = 300 ج.م
    Payment 2 = 200 ج.م
    Payment 3 = 500 ج.م

the Financial Report must treat them as separate Payment transactions.

The underlying payment history must not be overwritten.

---

# 54. Reports and Cancelled Orders

Cancelled Orders remain historical records.

The Orders Report may include them in:

    Orders by Status

depending on the selected reporting period.

The Financial Report must follow the approved treatment of cancelled Order financial values.

Cancellation must not delete Payment history.

No automatic refund workflow exists in V1.

---

# 55. Reports and Completed Orders

Completed Orders remain historical business transactions.

They remain available for reporting.

Completion does not remove the Order from historical reports.

---

# 56. Reports and Expenses

Expenses are independent financial transactions.

An Expense does not belong to an Order.

The Financial Report must not attempt to associate Expenses with Orders.

The report simply aggregates valid Expenses according to:

    Expense.date
    +
    Expense.amount
    +
    Expense.category

---

# 57. Reports and Expense Category Deactivation

If a Category becomes inactive:

    Existing Expenses remain valid.

The Financial Report must continue to include those Expenses.

Historical reporting must not disappear simply because the Category is no longer available for new Expenses.

---

# 58. Reports and "Other"

If an Expense was recorded under:

    أخرى

and had:

    اسم المصروف = إصلاح باب المحل

the report must preserve the Expense.

Changing the Category configuration later must not remove the historical custom name.

---

# 59. Reports and Monetary Precision

All monetary values must use the approved precise representation.

The system uses integer minor units internally.

Example:

    100.50 ج.م
        ↓
    10050 piastres

The UI displays:

    100.50 ج.م

The Reports UI must not perform floating-point financial calculations directly.

Calculations belong to the appropriate Domain/Application/Data logic.

---

# 60. Reports Currency

V1 uses only:

    EGP

Displayed as:

    ج.م

No currency selector is required.

No multi-currency report is required.

---

# 61. Reports Tax

Tax is disabled by default.

The Reports UI must not introduce complex tax reporting.

If tax is enabled according to the approved future-capable configuration, the implementation must follow the existing Domain/Product rules.

V1 must not expand into a full tax accounting system.

---

# 62. Reports Data Source Boundary

The Reports UI must not directly access:

    SQLite
    Drift
    SQL queries
    Dio
    Retrofit
    Supabase
    Edge Functions

The approved architecture remains:

    Reports UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local Data Source

The Reports feature must consume repository/application data.

---

# 63. Reports Business Logic Boundary

The Reports UI must not independently calculate business rules.

It must not decide:

    What counts as overdue
    What counts as Ready
    What counts as Completed
    Whether a Payment is valid
    Whether an Expense is valid
    How Net Profit is calculated

These rules belong to the appropriate Domain/Application layer.

The Reports feature presents calculated/report-ready values.

---

# 64. Report State Model

The Reports feature should support the following conceptual UI states:

    Initial
    Loading
    Loaded
    Empty
    Error

It may also expose:

    Offline
    Synchronizing
    Pending Synchronization

These are UI/Application states.

They must not be introduced as new business entities.

---

# 65. Report Filters

The report period selector should remain easy to use.

Recommended controls:

    اليوم
    أمس
    آخر 7 أيام
    هذا الشهر
    الشهر السابق
    مخصص

For:

    مخصص

show:

    من
    إلى

using Date Pickers.

The report should update after the user confirms the range.

---

# 66. Report Date Picker

The Date Picker must be used for:

    Custom Report Start Date
    Custom Report End Date

The user must not be required to manually type dates.

Preferred display:

    25 أغسطس 2026

The same date interaction pattern should be used throughout the application.

---

# 67. Report Date Range Validation

For Custom Date Range:

    Start Date <= End Date

If the user selects an invalid range, the UI should provide a clear Arabic validation message.

Example:

    تاريخ البداية يجب أن يكون قبل أو مساويًا لتاريخ النهاية

The report must not execute an invalid range.

---

# 68. Reports Responsive Layout

The Reports screen must support tablet-first responsive behavior.

On larger screens:

    Summary cards
        ↓
    Multi-column layout

may be used.

On smaller supported layouts:

    Cards
        ↓
    Stack / Responsive Grid

The business information must remain unchanged.

---

# 69. Reports RTL

All Reports UI must use RTL.

The visual hierarchy should naturally follow Arabic reading direction.

Tables, cards, filters, lists, and dialogs must use logical:

    start
    end

positioning rather than hardcoded left/right assumptions.

---

# 70. Reports Typography

Reports must use the centralized:

    AppTextStyles

The hierarchy should distinguish:

    Report Title
    Period Selector
    Section Title
    Metric Value
    Metric Label
    Breakdown Label
    Supporting Information

No independent typography system should be created.

---

# 71. Reports Colors

Reports must use:

    AppColors
    AppTheme

Semantic colors may represent:

    Positive
    Warning
    Error
    Neutral
    Primary

Net Profit should not rely on color alone to communicate its meaning.

The numeric value and label must always remain clear.

---

# 72. Reports Components

The Reports feature should reuse shared Design System components.

Likely components include:

    AppCard
    AppButton
    DateRangeSelector
    MetricCard
    EmptyState
    LoadingState
    ErrorState
    StatusBadge
    BreakdownList
    ReportSection

New components should only be created when an existing shared component cannot represent the required pattern.

---

# 73. Report Tables

If tabular data is used, it should remain concise.

The report must not become a large spreadsheet-like interface.

Detailed transaction tables are optional and should only be used if they provide clear V1 value.

The primary purpose remains:

    Quick understanding

rather than:

    Full accounting ledger

---

# 74. Financial Report Transaction Details

If the final UI includes a detailed Expense list, each row may show:

    التاريخ
    التصنيف
    اسم المصروف when applicable
    المبلغ

Notes may be shown in Expense Details rather than in the main report list.

The report should remain readable.

---

# 75. Expense Navigation from Financial Report

If the user selects an Expense-related section, the UI may navigate to the Expense management/detail workflow.

Example:

    المصروفات
        ↓
    Expense list

The exact navigation should remain consistent with the approved final UI architecture.

The primary Sidebar must not gain a new top-level:

    المصاريف

module.

---

# 76. Expense Creation from Reports

The Financial Report may provide:

    + إضافة مصروف

as an action.

This is useful because the user may notice a missing Expense while reviewing financial data.

The primary daily shortcut remains on the Dashboard.

---

# 77. Report Quick Actions

Reports should not become a collection of unrelated actions.

Allowed useful actions include:

    تغيير الفترة
    إضافة مصروف

and navigation to relevant detailed records.

Avoid:

    Export
    Advanced filters
    Complex analytics
    Report builder

unless explicitly approved later.

---

# 78. No Automated Export in V1

Automated report exports are outside the approved V1 scope.

Do not introduce:

    PDF Export
    Excel Export
    CSV Export
    Scheduled Reports

unless explicitly approved as a new Product requirement.

---

# 79. No Advanced Charts in V1

The Reports module should use simple visualizations only where they improve understanding.

Do not introduce a large charting system.

Avoid:

    Complex dashboards
    Multi-series charts
    Predictive graphs
    Interactive BI dashboards

Simple metric cards and category breakdowns are sufficient for V1.

---

# 80. Orders Report Summary Example

A conceptual Orders Report may display:

    تقرير الطلبات

    الفترة:
    هذا الشهر

    إجمالي الطلبات
    42

    إجمالي قيمة الطلبات
    8,450 ج.م

    قيد التنفيذ
    12

    جاهزة للتسليم
    8

    مكتملة
    20

    ملغاة
    2

    الطلبات المتأخرة
    3

This is an example of information structure, not fixed mock data.

---

# 81. Financial Report Summary Example

A conceptual Financial Report may display:

    التقرير المالي

    الفترة:
    هذا الشهر

    إجمالي المبيعات
    8,450 ج.م

    إجمالي المدفوعات
    6,700 ج.م

    إجمالي المصروفات
    1,250 ج.م

    المبالغ المتبقية
    1,750 ج.م

    الخصومات
    300 ج.م

    صافي الربح
    7,200 ج.م

The values above are illustrative only.

Figma mock data must always remain internally consistent.

---

# 82. Financial Consistency Rule

All displayed financial values must be mathematically consistent.

For example:

    Total Sales
        +
    Total Payments
        +
    Total Expenses
        +
    Remaining Amount
        +
    Net Profit

must not contain contradictory mock data.

A previous Figma mockup had an inconsistency where an Order Total displayed:

    250 ج.م

while an OrderItem displayed:

    270 ج.م

This must not be repeated.

All final Figma mock data must be internally consistent.

---

# 83. Report Calculation Example

Given:

    Total Sales = 1,000 ج.م
    Total Payments = 700 ج.م
    Total Expenses = 150 ج.م
    Total Discounts = 50 ج.م

and assuming the Sales value already reflects the approved Order total/discount treatment:

    Remaining Amount = 300 ج.م

    Net Profit = 850 ج.م

The discount must not be subtracted again from Net Profit.

---

# 84. Report Calculation Example with No Expenses

Given:

    Total Sales = 2,000 ج.م
    Total Operating Expenses = 0 ج.م

then:

    Net Profit = 2,000 ج.م

Payment amount does not change this calculation.

---

# 85. Report Calculation Example with Expenses

Given:

    Total Sales = 5,000 ج.م
    Total Operating Expenses = 1,200 ج.م

then:

    Net Profit = 3,800 ج.م

This is the approved V1 operational Net Profit calculation.

---

# 86. Report Calculation Example with Payments

Given:

    Total Sales = 5,000 ج.م
    Total Payments = 3,500 ج.م
    Total Operating Expenses = 1,200 ج.م

then:

    Remaining Amount = 1,500 ج.م

    Net Profit = 3,800 ج.م

The 3,500 ج.م Payments must not be subtracted from Net Profit.

---

# 87. Report Calculation Example by Expense Category

Given:

    كهرباء = 200 ج.م
    مياه = 100 ج.م
    منظفات = 300 ج.م
    صيانة = 150 ج.م

then:

    Total Operating Expenses = 750 ج.م

If:

    Total Sales = 2,000 ج.م

then:

    Net Profit = 1,250 ج.م

---

# 88. Report Data Integrity

The report must not show values that contradict the underlying local data.

If the report shows:

    Total Expenses = 500 ج.م

the Expense breakdown should sum to:

    500 ج.م

Similarly:

    Payment Method Breakdown

should sum to:

    Total Payments

within the selected reporting period.

---

# 89. Report Breakdown Consistency

For Payment Methods:

    Cash
    +
    InstaPay
    +
    E-Wallet
    =
    Total Payments

For Expense Categories:

    Category A
    +
    Category B
    +
    Category C
    =
    Total Operating Expenses

The UI should not display contradictory totals.

---

# 90. Report Period Consistency

All report sections must use the same selected reporting period unless the metric has a clearly defined different business date.

For example:

    Payment
        ↓
    paidAt

    Expense
        ↓
    Expense.date

The period itself remains consistent.

---

# 91. Report Performance

Reports must be efficient on local data.

Avoid:

    Loading all Orders into memory unnecessarily
    Loading all Payments into memory unnecessarily
    Loading all Expenses into memory unnecessarily
    Performing expensive calculations directly inside widgets

Prefer:

    Repository queries
        ↓
    Aggregated local calculations
        ↓
    Report State
        ↓
    UI

The existing database documentation already requires efficient queries for Dashboard/report-related data. :contentReference[oaicite:7]{index=7}

---

# 92. Report Search

V1 Reports do not require a general free-text search.

The primary filtering mechanism is:

    Date Period

Additional filtering should only be introduced where explicitly required.

---

# 93. Report Refresh

Reports should update automatically when relevant local data changes.

Examples:

    New Payment
        ↓
    Total Payments updates

    New Expense
        ↓
    Total Expenses updates
        ↓
    Expense Breakdown updates
        ↓
    Net Profit updates

    New Order
        ↓
    Total Sales updates when it belongs to the selected reporting period

The user should not need to restart the application.

---

# 94. Report State After New Expense

When an Expense is created successfully:

    Expense Saved Locally
        ↓
    Reports Data Invalidated / Refreshed
        ↓
    Total Expenses Updated
        ↓
    Expense Breakdown Updated
        ↓
    Net Profit Updated

This should happen without requiring remote synchronization first.

---

# 95. Report State After New Payment

When a Payment is recorded successfully:

    Payment Saved Locally
        ↓
    Financial Report Updated
        ↓
    Total Payments Updated
        ↓
    Remaining Amount Updated where applicable

Net Profit does not change merely because a Payment was recorded.

---

# 96. Report State After New Order

When a new Order is created:

    Orders Report
        ↓
    May update if Order belongs to selected period

    Financial Report
        ↓
    Sales may update according to the approved reporting treatment

The implementation must follow the Domain/Application reporting rules.

---

# 97. Report State After Expense Category Change

Changing a Category name should update current category display where appropriate.

Historical Expenses must remain linked to the same Category ID.

Deactivating a Category must not remove its historical Expenses from Reports.

---

# 98. Reports and Historical Master Data

Current master data must not be used to reconstruct historical transactions.

Examples:

    Current Service Price
        ≠
    Historical OrderItem Price

    Current Expense Category Name
        ≠
    Historical Expense Custom Name

Historical transaction identity and financial values must remain stable.

---

# 99. Reports and Business Settings

Reports must use:

    EGP
    ج.م

Currency is fixed in V1.

The user must not be offered a Currency selector inside Reports.

---

# 100. Reports and Arabic Localization

All user-facing Reports text must be Arabic.

Examples:

    التقرير المالي
    تقرير الطلبات
    إجمالي المبيعات
    إجمالي المدفوعات
    إجمالي المصروفات
    المبالغ المتبقية
    إجمالي الخصومات
    صافي الربح
    طرق الدفع
    المصروفات حسب التصنيف

Dates should use Arabic-friendly display formatting.

---

# 101. Reports and RTL Tables

If a table is used, its column hierarchy must be designed for RTL.

The UI should not simply mirror an LTR table mechanically.

Column ordering must prioritize the information users need first.

---

# 102. Reports Accessibility

Reports must:

- Not rely on color alone.
- Use clear Arabic labels.
- Maintain readable typography.
- Maintain adequate contrast.
- Provide clear filter labels.
- Use accessible Date Picker controls.
- Provide meaningful labels for icons.
- Keep metric values visually distinguishable.
- Maintain appropriate touch targets.

---

# 103. Reports and Design System

Reports must use the centralized Design System.

Do not invent:

    New Colors
    New Typography
    New Spacing
    New Radius Values
    Independent Components

The Reports feature should use existing shared components wherever possible.

---

# 104. Reports Feature Boundary

The Reports feature owns:

    Orders Report UI
    Financial Report UI
    Date Filtering
    Report Presentation
    Report State

It does not own:

    Order Business Logic
    Payment Business Logic
    Expense Business Logic
    Database Queries
    API Calls
    Synchronization Logic

Those responsibilities remain in the appropriate layers.

---

# 105. Reports Architecture

The approved architecture is:

    Reports UI
        ↓
    Cubit / Bloc
        ↓
    Repository
        ↓
    Local Data Source

Remote synchronization occurs separately.

The Reports feature must not directly access the backend.

---

# 106. Reports Repository Responsibilities

The repository layer may expose report-oriented methods such as:

    getOrdersReport(period)
    getFinancialReport(period)
    getExpenseBreakdown(period)
    getPaymentMethodBreakdown(period)

The exact method names are implementation details.

The important rule is that the Reports UI does not know where the data comes from.

---

# 107. Reports and Domain

Where calculations represent business rules, they should be implemented in Domain/Application logic rather than directly in UI widgets.

Examples:

    Net Profit calculation
    Remaining Amount calculation
    Overdue condition
    Expense validation

The Reports UI only presents the resulting values.

---

# 108. Reports and Database

The database should support efficient queries for:

    Orders by period
    Orders by status
    Payments by date
    Expenses by date
    Expenses by category
    Payment methods by date

Indexes should be introduced based on actual query requirements.

The existing database indexing strategy follows this principle. :contentReference[oaicite:8]{index=8}

---

# 109. Reports and Synchronization Queue

Reports do not create SyncOperations.

Viewing a report is a read operation.

Creating or editing an Expense or Payment creates the relevant synchronization operation through the normal Data Layer workflow.

---

# 110. Reports and Pending Local Data

Pending synchronization does not mean that the transaction is excluded from local Reports.

If an Expense exists locally:

    Expense
        ↓
    Included in Local Financial Report

even if:

    Sync Status = Pending

The same principle applies to locally created Orders and Payments.

---

# 111. Report Error Recovery

If a report query fails:

    Preserve existing UI state where safe
        +
    Show Arabic error state
        +
    Allow retry

The application must not clear all locally available data simply because one report calculation failed.

---

# 112. Reports and No Data

A zero-value report is valid.

The UI should distinguish between:

    No Data

and:

    Error

Example:

    No Expenses
        ↓
    Valid Empty State

not:

    Error

---

# 113. Report Period Persistence

The application may remember the user's last selected report period during the current session.

However, the Reports screen should always make the active period visible.

The exact persistence behavior is a UI implementation detail.

---

# 114. Report Navigation Back

Returning from an Order or Expense detail view should preserve the current Report context where practical.

Example:

    Financial Report
        ↓
    Expense Detail
        ↓
    Back
        ↓
    Financial Report
    Same selected period

This reduces unnecessary reconfiguration.

---

# 115. Financial Report Main Action

The Financial Report may expose:

    + إضافة مصروف

This action is secondary to the report information.

The Dashboard remains the primary place for fast daily Expense creation.

---

# 116. Orders Report Main Actions

The Orders Report may expose:

    تغيير الفترة

and navigation into filtered Orders.

It should not provide unrelated Order creation actions unless the final UX establishes a strong workflow reason.

---

# 117. Reports Scope Guard

The following must not be added during V1 implementation without a new Product decision:

    Service Analytics
    Customer Analytics
    Storage Analytics
    Employee Analytics
    Driver Analytics
    Advanced Charts
    BI Dashboards
    Predictive Analytics
    Automated Exports
    Scheduled Reports
    Full Accounting
    Budgeting
    Supplier Reports
    Accounts Payable
    Expense Approval Reports
    Recurring Expense Reports

---

# 118. Final Orders Report

The V1 Orders Report is:

    Orders Report
        ↓
    Selected Period
        +
    Total Orders
        +
    Orders by Status
        +
    Total Order Value
        +
    Overdue Orders

No unnecessary analytics are included.

---

# 119. Final Financial Report

The V1 Financial Report is:

    Financial Report
        ↓
    Selected Period
        +
    Total Sales
        +
    Total Payments
        +
    Outstanding Amounts
        +
    Total Discounts
        +
    Payment Method Breakdown
        +
    Total Operating Expenses
        +
    Expense Category Breakdown
        +
    Net Profit

This is the final approved V1 financial reporting scope.

---

# 120. Final Financial Relationship

The core financial relationship is:

    Total Sales
        ↓
    Customer Payments
        ↓
    Outstanding Amount

Separately:

    Operating Expenses
        ↓
    Business Costs

And:

    Total Sales
        -
    Total Operating Expenses
        ↓
    Net Profit

Payments must not be treated as Expenses.

Outstanding Amounts must not be treated as Expenses.

Expenses must not be treated as Payments.

---

# 121. Final Expense Reporting Principle

Expense reporting is based on:

    Expense.date
        +
    Expense.amount
        +
    Expense.category

The Expense Category is manageable master data.

Historical Expenses remain valid even if the Category is later renamed or deactivated.

The `أخرى` category requires a custom Expense name.

---

# 122. Final Offline-first Reporting Principle

The Reports module must remain useful without internet access.

The preferred flow is:

    Local Transactions
        ↓
    Local Report Calculation
        ↓
    Report UI

Synchronization is secondary.

The user must never be blocked from viewing locally available Reports because the backend is unavailable.

---

# 123. Final Report Principle

The Reports module should answer the business's daily and periodic questions without becoming an accounting or analytics platform.

The final V1 principle is:

    Simple
        +
    Accurate
        +
    Historical
        +
    Financially consistent
        +
    Operationally useful
        +
    Offline-first
        +
    Arabic-first
        +
    RTL

The Reports module contains exactly two primary report categories:

    تقرير الطلبات

and:

    التقرير المالي

The Financial Report includes the approved V1 financial metrics:

    إجمالي المبيعات
    إجمالي المدفوعات
    إجمالي المصروفات
    المبالغ المتبقية
    إجمالي الخصومات
    طرق الدفع
    المصروفات حسب التصنيف
    صافي الربح

with:

    صافي الربح
        =
    إجمالي المبيعات
        -
    إجمالي المصروفات

Payments, Outstanding Amounts, and Expenses remain separate concepts throughout the system.