# Laundry Management System — Business Rules

## 1. Document Purpose

This document defines the business rules that govern how the Laundry Management System behaves.

These rules represent confirmed business decisions for V1.

They are more authoritative than UI assumptions.

If the UI, implementation, or AI-generated code conflicts with a rule in this document, the business rule must take precedence.

Any approved change to a business rule must be reflected in this document before or alongside the implementation change.

---

# 2. General Business Rules

## BR-001 — Single Branch

The system operates as a single-branch laundry business in V1.

No branch selection is required.

No branch-specific business logic should be introduced.

---

## BR-002 — Single Currency

All monetary values use Egyptian Pound (EGP).

The UI displays the currency as:

> ج.م

Currency selection is not supported.

---

## BR-003 — Single Primary User

V1 does not distinguish between users, roles, or permissions.

The primary user has access to all available system features.

---

## BR-004 — Arabic-First

All user-facing content must be Arabic and the application must use RTL layout.

---

# 3. Customer Rules

## BR-005 — Customer Required for Order

Every order must be associated with a customer.

An order cannot exist without a customer.

---

## BR-006 — Customer Identity

Customer identity is primarily based on the customer's phone number.

The system should prevent creating multiple customer records using the same phone number.

---

## BR-007 — Customer Name

Customer name is required.

---

## BR-008 — Customer Phone

Customer phone number is required.

The phone number must pass the application's Egyptian phone number validation rules.

---

## BR-009 — Customer History Preservation

Updating a customer's name or phone number must not rewrite historical order snapshots.

Historical orders must preserve the information relevant to the order at the time it was created.

---

## BR-010 — Customer Deletion

Customers should not be hard-deleted when they have historical orders.

Historical customer relationships must remain intact.

If customer deactivation is introduced in the future, it must not remove historical data.

---

# 4. Order Creation Rules

## BR-011 — Order Must Have Items

An order must contain at least one OrderItem.

An empty order cannot be saved.

---

## BR-012 — Expected Pickup Is Required

Every order must have an Expected Pickup Date.

The value is date-only.

Time is not required.

---

## BR-013 — Expected Pickup Date

Expected Pickup Date represents the date the customer is expected to receive the order.

It is not a guaranteed delivery or appointment time.

---

## BR-014 — Delivery Request

Delivery is represented only as a boolean request.

The system stores whether the customer requested delivery.

The system does not manage the actual delivery operation.

---

## BR-015 — Order Notes

Order-level notes are optional.

They apply to the entire order.

They must remain separate from Item-level notes.

---

# 5. Order Number Rules

## BR-016 — Unique Order Number

Every order must have a unique human-readable Order Number.

---

## BR-017 — Order Number Format

The intended format is:

> YYMMDD-XXX

Example:

> 260823-001

The exact generation mechanism is an implementation detail, but uniqueness is mandatory.

---

## BR-018 — Order Number Immutability

Once an Order Number is assigned, it must not change.

Editing an order must never generate a new Order Number.

---

# 6. Order Status Rules

## BR-019 — Allowed Statuses

Only these four statuses exist in V1:

- Processing
- Ready
- Completed
- Cancelled

No additional operational statuses should be introduced.

---

## BR-020 — Processing

Processing represents an active order that is not yet ready for customer handover.

The system does not attempt to represent individual laundry processing stages.

---

## BR-021 — Ready

Ready means:

> All OrderItems have been stored and the order is ready for customer handover.

Ready does not mean that the customer has received the order.

---

## BR-022 — Completed

Completed means:

> The order has actually been handed over to the customer.

Completed must never mean only:

- The order is ready.
- The order is fully paid.
- The laundry work is finished.

Actual customer handover must be confirmed.

---

## BR-023 — Cancelled

Cancelled means the order has been cancelled and is no longer an active operational order.

Cancelled orders remain as historical records.

---

# 7. Automatic Status Rules

## BR-024 — Processing to Ready

An order should automatically become Ready when all its physical OrderItems have an active Storage Record.

Conceptually:

All OrderItems stored
↓
Order = Ready

---

## BR-025 — Partial Storage

If one or more OrderItems are not stored:

Order remains Processing.

Example:

- 5 OrderItems
- 4 stored
- 1 not stored
- Order = Processing

---

## BR-026 — Manual Status Override

The user may manually change the order status when necessary to correct an operational mistake.

However, manual changes must not automatically create incorrect Storage state.

---

# 8. Completed Status Rules

## BR-027 — Completion Preconditions

An order can become Completed only when:

- Order status is Ready.
- Remaining payment amount is zero.
- The user confirms that the order was handed over to the customer.

---

## BR-028 — Ready Does Not Mean Completed

An order must remain Ready until actual customer handover is confirmed.

The system must never automatically mark a Ready order as Completed.

---

## BR-029 — Fully Paid Does Not Mean Completed

A fully paid order must not automatically become Completed.

Payment completion and customer handover are separate business events.

---

## BR-030 — Handover Confirmation

The user must explicitly confirm customer handover before the order becomes Completed.

---

## BR-031 — Completion Is Final for V1

Completed orders are historical records.

They should be read-only through the normal UI.

If a correction is required, the system may allow controlled manual status correction according to the documented status rules.

---

# 9. Completed Storage Rules

## BR-032 — Storage Deactivation on Completion

When an order becomes Completed:

All active Storage Records belonging to its OrderItems must become inactive.

---

## BR-033 — Completed Items Are Not in Current Storage

After completion, the physical OrderItems must no longer appear in Current Storage.

They remain available through historical order information.

---

## BR-034 — No Automatic Reactivation

If a Completed order is manually changed back to Processing:

Its Storage Records must not automatically become active.

The user must explicitly store the items again if they physically return to storage.

---

# 10. Cancellation Rules

## BR-035 — Cancellation Confirmation

Cancelling an order requires explicit user confirmation.

---

## BR-036 — Cancellation Reason

A cancellation reason should be recorded when an order is cancelled.

The reason is part of the order's historical information.

---

## BR-037 — Cancelled Orders Are Preserved

Cancelled orders must not be deleted.

They remain accessible in order history.

---

## BR-038 — Cancelled Orders Are Not Active

Cancelled orders must not appear as active operational orders.

---

## BR-039 — Storage on Cancellation

If an order has active Storage Records when it is cancelled:

Those Storage Records become inactive.

---

## BR-040 — Payments on Cancellation

Existing payment records remain stored after cancellation.

Cancellation does not automatically delete payment history.

---

## BR-041 — No Automatic Refund

Cancellation does not trigger an automatic refund.

There is no V1 refund workflow.

---

# 11. Order Item Rules

## BR-042 — Physical Item Identity

Every physical piece is represented by its own OrderItem.

---

## BR-043 — Quantity Entry

The UI may allow entering identical items using quantity.

Example:

> Shirt × 5

This is an input convenience only.

The domain must represent five physical OrderItems.

---

## BR-044 — Independent Item Identifier

Every OrderItem has an independent internal identifier.

---

## BR-045 — Independent Storage

Each OrderItem can have its own Storage Location.

Items belonging to the same order do not have to share the same location.

---

## BR-046 — Future Barcode Readiness

The independent OrderItem identifier must allow barcode support to be added in the future.

Barcode scanning is not required in V1.

---

# 12. Item Type Rules

## BR-047 — Primary Item Types

V1 supports:

- Clothing
- Blankets
- Carpets
- Carpet Covers

---

## BR-048 — Item Definitions

Item Types may have definitions/subtypes where useful.

The system should avoid unnecessary nullable fields by keeping item-specific data separated by item type.

---

## BR-049 — Carpet Covers

Carpet Covers do not require a separate cover type/subtype hierarchy in V1.

They are treated operationally similarly to Blankets.

They are still a distinct primary item type when the item type needs to be identified.

---

# 13. Service Rules

## BR-050 — Service Selection

An OrderItem must use a service that is available for its Item Type.

---

## BR-051 — Service Availability

Inactive services must not be selectable for new orders.

Existing orders using an inactive service must remain valid.

---

## BR-052 — Service Price Snapshot

When a service is selected for an OrderItem, the price used at that time must be preserved in the OrderItem.

---

## BR-053 — Historical Price Stability

Changing the current service price must not change the price of existing OrderItems.

---

## BR-054 — Service Deactivation

Deactivating a service must not modify historical orders.

---

# 14. Pricing Rules

## BR-055 — Supported Pricing Types

The domain supports:

- Per Piece
- Per Kilogram
- Per Square Meter
- Fixed Price

---

## BR-056 — Relevant Pricing Types

The UI should expose only pricing types relevant to the selected service and Item Type.

The user should not be forced to choose from irrelevant pricing models.

---

## BR-057 — Current Expected Pricing

The normal V1 use cases are:

- Clothing → Per Piece
- Blankets → Per Piece
- Carpet Covers → Per Piece
- Carpets → Per Square Meter

---

# 15. Carpet Rules

## BR-058 — Carpet Dimensions

Carpet OrderItems must store:

- Length
- Width
- Area

---

## BR-059 — Carpet Area Calculation

Area is calculated as:

> Length × Width

Example:

- Length = 2
- Width = 3
- Area = 6 m²

---

## BR-060 — Common Carpet Size

The user may select a predefined common size.

---

## BR-061 — Custom Carpet Size

The user may enter custom Length and Width values.

The system calculates Area automatically.

---

## BR-062 — Carpet Size Snapshot

The OrderItem must preserve the dimensions used at order creation.

Changing the list of common carpet sizes must not affect existing orders.

---

# 16. Order Pricing Rules

## BR-063 — Subtotal

Subtotal is calculated from the OrderItems using their applicable pricing rules.

---

## BR-064 — Order Discount

Discount is applied at the order level.

---

## BR-065 — No Item-Level Discount

V1 does not support individual discounts per OrderItem.

---

## BR-066 — Total

Current V1 calculation:

Subtotal - Discount = Total

---

# 17. Tax Rules

## BR-067 — Tax Disabled by Default

Tax is disabled in normal V1 operation.

---

## BR-068 — Future Tax Support

The system should allow tax to be enabled in the future.

Expected calculation:

Subtotal - Discount + Tax = Total

---

# 18. Payment Rules

## BR-069 — Payment Independence

Payments are separate records from the Order itself.

---

## BR-070 — Multiple Payments

An order may contain multiple payment records.

---

## BR-071 — Partial Payment

An order may be partially paid.

---

## BR-072 — Remaining Amount

Remaining amount is:

Order Total - Total Paid

---

## BR-073 — Payment Cannot Exceed Remaining

The system must not allow the user to record a payment greater than the current remaining amount.

---

## BR-074 — Payment History

Recorded payments must remain available as historical records.

---

## BR-075 — Payment Methods

V1 supports:

- Cash
- InstaPay
- E-Wallet

---

## BR-076 — No Refund Workflow

V1 does not implement a refund workflow.

---

# 19. Storage Rules

## BR-077 — Current Storage

Current Storage represents physical items that are currently stored by the laundry.

---

## BR-078 — One Active Location

An OrderItem can have at most one active Storage Record at a time.

---

## BR-079 — No Active Location

An OrderItem may temporarily have no active Storage Record.

This is the state used when an item still needs to be stored or has been removed from storage.

---

## BR-080 — Store Item

Storing an item creates or activates its Storage Record with the selected location.

---

## BR-081 — Move Item

Moving an item changes its current Storage Location.

The previous location is no longer active for that item.

---

## BR-082 — No Movement History

V1 does not retain Storage Movement History.

Only the current active location matters.

---

## BR-083 — Bulk Storage

Multiple physical OrderItems may be assigned to the same Storage Location in a single operation.

---

## BR-084 — Mixed Locations

Items from the same Order may be stored in different locations.

---

## BR-085 — Storage Location

A Storage Location is identified by its configured name.

Examples:

- A-01
- A-02
- B-01
- Carpet-01

---

## BR-086 — Storage Capacity

V1 does not enforce capacity limits on Storage Locations.

---

# 20. Ready Status and Storage

## BR-087 — Ready Depends on Storage

An order becomes Ready when every OrderItem has an active Storage Record.

---

## BR-088 — Storage Does Not Depend on Ready

Items can be stored while the order is Processing.

Storage is what allows the order to become Ready.

---

## BR-089 — Manual Ready Status

If the user manually changes an order to Ready while some items are not stored, the system must preserve the actual Storage state.

The system should warn or prevent the action if business validation requires all items to be stored.

The implementation must not falsely represent unstored items as stored.

---

# 21. Delivery Rules

## BR-090 — Delivery Request Only

Delivery is represented by a boolean:

isDelivery = true / false

---

## BR-091 — No Delivery Workflow

The system does not manage how the order physically reaches the customer.

---

## BR-092 — No Driver Data

No driver information is required.

---

## BR-093 — No Delivery Status

No delivery-specific status is required.

---

# 22. Expected Pickup Rules

## BR-094 — Required Date

Expected Pickup Date is required for every order.

---

## BR-095 — Date Only

Expected Pickup stores a date only.

No pickup time is required.

---

## BR-096 — Overdue Order

An order is considered overdue when:

Expected Pickup Date < Today AND Status != Completed AND Status != Cancelled

---

# 23. Dashboard Rules

## BR-097 — Operational Dashboard

Dashboard information should focus on current operational attention.

---

## BR-098 — Orders Today

"Orders Today" represents orders created on the current date.

---

## BR-099 — Ready Orders

"Ready" count represents orders currently in Ready status.

---

## BR-100 — Items Requiring Storage

The Dashboard should highlight orders/items that still require storage.

---

## BR-101 — Outstanding Payments

Outstanding payment information is based on orders where:

Remaining Amount > 0

---

## BR-102 — Today's Pickup

Today's pickup list represents orders whose Expected Pickup Date equals the current date.

---

# 24. Reports Rules

## BR-103 — Orders Report

The Orders Report provides operational order information for the selected period.

---

## BR-104 — Financial Report

The Financial Report provides financial information for the selected period.

---

## BR-105 — Payment Period

Payment totals should be based on payments recorded during the selected reporting period.

This is separate from the order creation date.

---

## BR-106 — Historical Price Usage

Reports must use historical OrderItem prices rather than current service prices.

---

# 25. Settings Rules

## BR-107 — Business Name

The business name is configurable.

---

## BR-108 — Tax Configuration

Tax configuration is optional and disabled by default.

---

## BR-109 — Fixed Currency

Currency cannot be changed.

---

## BR-110 — Fixed Branch

Branch cannot be changed because V1 supports one branch only.

---

# 26. Data Preservation Rules

## BR-111 — Historical Orders Must Not Break

Changes to master data must not invalidate historical orders.

---

## BR-112 — Historical Service Data

Historical OrderItems must preserve the relevant service and price information used at the time of the order.

---

## BR-113 — Historical Item Data

Historical OrderItems must preserve enough information to identify what physical item/service was part of the order at that time.

---

## BR-114 — No Hard Deletion of Historical Data

Entities that are referenced by historical orders should generally be deactivated rather than hard-deleted.

---

# 27. Offline Rules

## BR-115 — Local Operation

Core operations must work without an internet connection.

---

## BR-116 — Local Source of Truth

The local database is the primary operational source of truth while the application is running.

---

## BR-117 — Connectivity Must Not Block Work

Temporary loss of internet connectivity must not prevent normal local operations.

---

## BR-118 — Synchronization

Local changes should be synchronized with the backend when connectivity is available.

---

# 28. Synchronization Rules

## BR-119 — Sync Is Background Work

Synchronization should not unnecessarily interrupt the user's workflow.

---

## BR-120 — Sync State Visibility

The user should have a simple indication of synchronization state when relevant.

Possible states include:

- Synchronized
- Synchronizing
- Waiting for synchronization
- Offline

---

## BR-121 — No Silent Data Loss

Synchronization must never silently discard valid local changes.

Conflict handling must be designed before multi-device synchronization is introduced.

---

# 29. UI Behavior Rules

## BR-122 — Context-Aware Actions

Available actions should depend on the current order state.

The UI should not show every possible action at all times.

---

## BR-123 — Destructive Actions

Destructive actions require explicit confirmation.

Examples:

- Cancel order
- Removing important data
- Other irreversible operations

---

## BR-124 — No Hidden Business Logic in UI

Business rules must be enforced by the domain/application layer, not only by visual UI restrictions.

---

## BR-125 — Shared Components

Common UI behavior must use shared components and the centralized Design System.

---

# 30. Documentation Rules

## BR-126 — Documentation Is Source of Truth

The project documentation represents the approved product behavior.

---

## BR-127 — Requirement Changes

Any approved change to a business rule must update the relevant documentation.

---

## BR-128 — AI Must Not Invent Rules

AI coding tools must not invent business behavior when a requirement is missing.

If behavior is ambiguous, the agent should identify the ambiguity instead of silently choosing a business rule.

---

# 31. Rule Priority

When multiple sources provide instructions, the following priority applies:

Approved Business Rules
↓
Approved Product Requirements
↓
Approved Architecture Decisions
↓
UX Specifications
↓
Design System
↓
Implementation Details

Implementation details must never override confirmed business rules.

---

# 32. V1 Business Philosophy

The system should prefer:

- Simple rules
- Explicit state
- Predictable behavior
- Historical data preservation
- Minimal operational complexity
- Fast daily workflows

The system should avoid introducing business logic that does not correspond to a real operational requirement.

---

# 33. Expense Management Rules

## BR-129 — Expense Is a First-Class V1 Entity

Daily Operating Expense is an approved V1 business concept.

An Expense represents money spent by the laundry as part of normal business operations.

---

## BR-130 — Expense Is Independent

An Expense is independent from:

- Order
- OrderItem
- Payment
- Customer

An Expense does not require an Order reference.

---

## BR-131 — Expense Required Information

Every Expense must contain:

- Amount
- Expense Category
- Date

Notes are optional.

---

## BR-132 — Expense Amount Must Be Positive

Expense amount must be greater than zero.

Zero-value Expenses are not valid.

Negative Expense amounts are not valid.

---

## BR-133 — Expense Amount Precision

Expense monetary values must use the same precise monetary representation used by the rest of the system.

The approved business representation is based on integer minor units.

Example:

150.50 ج.م

is represented as:

15050 piastres

The Expense must not use unsafe floating-point business values.

---

## BR-134 — Expense Date

Expense Date is required.

Expense Date is a date-only business value.

No time component is required.

---

## BR-135 — Expense Date Selection

Expense Date must be selected through a Date Picker.

The user must not be required to manually type a date format such as:

08/25/2026

The preferred Arabic-friendly display is:

25 أغسطس 2026

---

## BR-136 — Expense Notes

Expense Notes are optional.

Notes provide additional context about the Expense.

Notes do not replace the required Expense Category.

---

# 34. Expense Category Rules

## BR-137 — Expense Category Is Master Data

Expense Categories are manageable master data.

They are not hard-coded as an immutable enum.

---

## BR-138 — Initial Expense Categories

The initial V1 categories are:

- كهرباء
- مياه
- منظفات
- صيانة
- مستلزمات
- نقل
- أخرى

These categories are seeded during initial database setup.

---

## BR-139 — Category Management

The user must be able to:

- View Expense Categories
- Add Expense Category
- Edit Expense Category
- Activate Expense Category
- Deactivate Expense Category

---

## BR-140 — Active Categories Only

Only active Expense Categories may be selected when creating a new Expense.

Inactive categories remain available for historical references.

---

## BR-141 — Category Deactivation Preserves History

Deactivating an Expense Category must not invalidate existing Expenses.

Historical Expenses continue to reference the same category.

---

## BR-142 — Category Deactivation Does Not Delete

Deactivating a category means:

is_active = false

It does not mean physically deleting the category.

---

## BR-143 — Category Rename Preserves Identity

Editing an Expense Category changes its current configuration but does not create a new category identity.

Existing Expenses continue to reference the same Expense Category record.

---

## BR-144 — User-Managed Categories

The seeded categories are only initial defaults.

The business may create additional Expense Categories later.

The system must not restrict the business to the seven initial categories.

---

# 35. "Other" Expense Rules

## BR-145 — Other Is a Normal Category

أخرى is a normal Expense Category.

It is not a special database entity.

It has its own category identity and can be managed like other categories.

---

## BR-146 — Other Requires Custom Name

When the selected Expense Category is:

أخرى

the Expense must contain:

اسم المصروف

The custom name is required.

---

## BR-147 — Other Custom Name Belongs to Expense

The custom name belongs to the individual Expense transaction.

Example:

التصنيف:
أخرى

اسم المصروف:
إصلاح باب المحل

The custom name must not automatically create a new Expense Category.

---

## BR-148 — Standard Categories Do Not Require Custom Name

When the selected category is one of the standard categories:

- كهرباء
- مياه
- منظفات
- صيانة
- مستلزمات
- نقل

a custom Expense name is not required.

---

## BR-149 — Custom Name Preservation

If an Expense uses:

أخرى

its custom name must remain part of the historical Expense data.

Editing the Expense Category list must not remove or alter the historical custom name.

---

# 36. Expense Editing Rules

## BR-150 — Expense Editing

The user may edit an existing Expense according to the approved Expense workflow.

Editable values may include:

- Amount
- Category
- Date
- Custom Name when applicable
- Notes

---

## BR-151 — Editing Does Not Create a New Expense

Editing an Expense updates the existing Expense.

It must not silently create a second Expense transaction.

The Expense identity remains unchanged.

---

## BR-152 — Expense History

Expenses are historical financial records.

The system must not silently delete or replace an Expense as a side effect of editing.

---

# 37. Expense and Payment Separation

## BR-153 — Payment Is Not an Expense

A Payment represents money received from a customer for an Order.

An Expense represents money spent by the business.

They are separate business concepts.

---

## BR-154 — Expense Must Not Be Stored as Negative Payment

The system must never represent an Expense by creating a negative Payment.

Expenses must use the Expense entity.

---

## BR-155 — Payment Does Not Reduce Net Profit Directly

Payments are reported separately.

Payments must not be subtracted again from Net Profit.

---

# 38. Expense and Order Separation

## BR-156 — Expense Does Not Belong to an Order

An Expense does not require:

order_id

An Expense remains independent even if the business happens to incur the expense while processing a particular order.

---

## BR-157 — Expense Does Not Affect Order Total

Recording an Expense must not modify:

- Order subtotal
- Order discount
- Order total
- Order payment amount
- Order remaining amount

---

# 39. Financial Report Rules

## BR-158 — Financial Report Includes Expenses

The Financial Report must include Total Operating Expenses for the selected reporting period.

---

## BR-159 — Expense Reporting Period

Expense totals are based on:

Expense Date

not:

created_at

---

## BR-160 — Total Operating Expenses

Total Operating Expenses are calculated from valid Expenses within the selected report period.

Conceptually:

Total Operating Expenses
=
Sum of Expense Amounts

---

## BR-161 — Expense Category Breakdown

The Financial Report should provide an Expense breakdown by Category.

Example:

منظفات
300 ج.م

كهرباء
200 ج.م

صيانة
150 ج.م

---

## BR-162 — Expense Breakdown Uses Selected Period

Expense Category totals must respect the selected Financial Report period.

---

## BR-163 — Expense Report Periods

The Financial Report supports:

- Today
- Yesterday
- Last 7 Days
- This Month
- Previous Month
- Custom Date Range

Custom Date Range uses Date Pickers.

---

# 40. Net Profit Rules

## BR-164 — Net Profit Is Included in V1

Net Profit is an approved V1 Financial Report metric.

---

## BR-165 — Net Profit Formula

Net Profit is calculated as:

Net Profit
=
Total Sales
-
Total Operating Expenses

---

## BR-166 — Net Profit Uses Selected Period

Net Profit must use the same selected reporting period for:

- Total Sales
- Total Operating Expenses

---

## BR-167 — Payments Are Reported Separately

Payments remain a separate Financial Report metric.

Payments must not be subtracted from Net Profit.

---

## BR-168 — Outstanding Amount Is Not an Expense

Outstanding customer amounts are not operating expenses.

Outstanding amounts must not reduce Net Profit.

---

## BR-169 — Discounts and Net Profit

Discounts are already reflected in historical Order totals.

The Net Profit calculation must not subtract the same discount twice.

---

## BR-170 — Net Profit Is Derived

Net Profit is a derived financial value.

It is not stored as an independent business transaction.

---

## BR-171 — No Full Accounting System

V1 Net Profit is a simple operational financial metric.

The system does not attempt to implement full accounting.

V1 does not include:

- Accounts payable
- Supplier accounting
- Budget management
- Recurring expenses
- Expense approval workflow
- Advanced accounting

---

# 41. Dashboard Quick Action Rules

## BR-172 — Quick Actions

The Dashboard V1 Quick Actions are:

- إضافة طلب
- إضافة عميل
- تسجيل دفعة
- إضافة مصروف

---

## BR-173 — Add Order Is Primary Quick Action

إضافة طلب is the primary Dashboard Quick Action.

---

## BR-174 — Add Expense Quick Action

إضافة مصروف provides a direct path to record a daily operating Expense.

It should reduce navigation steps for a frequent operational task.

---

## BR-175 — Storage Is Not a Quick Action

Storage is not a primary Dashboard Quick Action.

Storage is an ongoing operational workflow with its own dedicated screen.

---

## BR-176 — Storage Dashboard Attention

The Dashboard may highlight items/orders requiring Storage as operational attention.

This is different from treating Storage as a Quick Action.

---

## BR-177 — Quick Actions Are Operational

Quick Actions should represent frequent concrete actions that save navigation steps.

They should not duplicate primary navigation modules unnecessarily.

---

# 42. Expense Navigation Rules

## BR-178 — No Primary Expense Sidebar Module

V1 must not add a primary Sidebar navigation item named:

المصاريف

The main navigation remains:

- Dashboard
- Orders
- Customers
- Storage
- Services & Pricing
- Reports
- Settings

---

## BR-179 — Expense Access

Expenses are accessed through the approved Expense workflow, including:

- Dashboard Quick Action
- Financial Report
- Expense management UI where required

---

## BR-180 — Expense Category Settings

Expense Category management belongs under Settings.

The user manages:

- Category list
- Add Category
- Edit Category
- Activate Category
- Deactivate Category

through Settings.

---

# 43. Expense and Offline-first Rules

## BR-181 — Expense Works Offline

Creating and editing Expenses must work without an internet connection.

---

## BR-182 — Local Expense Save

When a valid Expense is created:

The Expense must be saved locally first.

The user should receive immediate local success.

---

## BR-183 — Expense Synchronization

After local persistence, the Expense may be synchronized with the backend when connectivity is available.

The user must not need to wait for remote synchronization before continuing normal work.

---

## BR-184 — Expense Sync Atomicity

When an Expense requires synchronization:

Expense creation/update and its corresponding SyncOperation must be committed atomically.

---

## BR-185 — Expense Retry Safety

Retrying an Expense synchronization operation must not create a duplicate Expense.

The Expense's stable identity must be preserved.

---

# 44. Expense Historical Data Rules

## BR-186 — Historical Expense Stability

Historical Expense data must remain stable and readable.

---

## BR-187 — Category Changes Do Not Change Amount

Changing an Expense Category configuration must not modify the historical Expense amount.

---

## BR-188 — Category Deactivation Does Not Break Expense History

A historical Expense must remain valid even if its category becomes inactive.

---

## BR-189 — Expense Date Is Historical Business Data

Changing the current date or application configuration must not alter an existing Expense Date.

---

## BR-190 — Custom Expense Name Is Historical Data

The custom name recorded for an Expense using أخرى must remain part of that Expense's historical information.

---

# 45. Report Calculation Rules

## BR-191 — Total Sales

Total Sales / Order Value is based on the applicable historical Order totals for the selected reporting period.

Current Service prices must not be used to reconstruct historical Order totals.

---

## BR-192 — Total Payments

Total Payments are based on payments recorded during the selected reporting period.

---

## BR-193 — Outstanding Amounts

Outstanding Amounts are based on Orders where:

Remaining Amount > 0

---

## BR-194 — Total Operating Expenses

Total Operating Expenses are based on Expenses recorded for the selected Expense Date range.

---

## BR-195 — Net Profit

Net Profit is derived from:

Total Sales
-
Total Operating Expenses

Payments and Outstanding Amounts remain separate report metrics.

---

## BR-196 — Financial Report Is Not Accounting

The Financial Report is an operational financial summary.

It is not intended to replace a full accounting system.

---

# 46. Business Rule Testing

## BR-197 — Expense Validation Test

The system must reject:

- Expense with no amount
- Expense with zero amount
- Expense with negative amount
- Expense with no category
- Expense with no date

---

## BR-198 — Other Expense Validation Test

The system must reject:

Category = أخرى

when:

اسم المصروف

is empty.

---

## BR-199 — Expense Category Test

The system must support:

- Creating a category
- Editing a category
- Deactivating a category
- Preventing inactive category selection for new Expenses
- Preserving historical Expenses

---

## BR-200 — Expense Financial Test

Given:

Total Sales = 1,000 ج.م

Total Operating Expenses = 150 ج.م

the Financial Report must calculate:

Net Profit = 850 ج.م

---

## BR-201 — Payment Separation Test

Given:

Total Sales = 1,000 ج.م
Total Expenses = 150 ج.م
Payments = 700 ج.م

Net Profit remains:

850 ج.م

The 700 ج.م Payments must not be subtracted again.

---

## BR-202 — Outstanding Amount Test

Given:

Total Sales = 1,000 ج.م
Payments = 700 ج.م
Expenses = 150 ج.م

Outstanding Amount:

300 ج.م

Net Profit:

850 ج.م

Outstanding Amount is not an Expense.

---

## BR-203 — Expense Period Test

An Expense with:

Expense Date = 25 أغسطس 2026

must be included in a report period containing 25 أغسطس 2026.

Its created_at timestamp must not determine its Financial Report period.

---

## BR-204 — Expense Offline Test

When the application is offline:

Create Expense
↓
Local Save
↓
UI Success
↓
Pending Synchronization

The Expense must remain available locally.

---

# 47. Final Business Rule Principles

The V1 business rules are based on:

- Simple operational workflows
- Explicit state
- Historical data preservation
- Local-first operation
- Reliable synchronization
- Independent financial concepts
- Configurable master data
- Minimal accounting complexity
- Arabic-first UX
- Predictable behavior

The Expense system follows the same principles.

The key financial separation is:

Payment
→ Money received from customer

Expense
→ Money spent by business

Net Profit
→ Total Sales - Total Operating Expenses

Outstanding Amount
→ Customer money still due

These concepts must never be merged or treated as interchangeable.