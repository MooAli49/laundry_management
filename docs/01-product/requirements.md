# Laundry Management System — Product Requirements

## 1. Document Purpose

This document defines the functional requirements of the Laundry Management System.

It describes what the system must be able to do from a business and user perspective.

This document should be treated as a source of truth for V1 functional requirements.

It should not contain implementation-specific decisions unless they are necessary to clarify a functional requirement.

---

# 2. Customer Management

## 2.1 Customer Creation

The system must allow the user to create a new customer.

Required information:

- Customer name
- Customer phone number

The system should validate the phone number format.

The system should prevent duplicate customers based on an existing phone number.

---

## 2.2 Customer Search

The user must be able to search for customers by:

- Customer name
- Customer phone number

Search must work using locally available data.

---

## 2.3 Customer Editing

The user must be able to edit:

- Customer name
- Customer phone number

Customer information may be updated without modifying historical order snapshots.

---

## 2.4 Customer History

The system must allow the user to view a customer's order history.

Customer details should provide access to:

- Total number of orders
- Current active orders
- Previous orders
- Latest order

Selecting an order should open its Order Details screen.

---

## 2.5 Customer Orders

The user must be able to start a new order directly from Customer Details.

When creating an order from Customer Details, the selected customer should already be associated with the new order.

---

# 3. Order Management

## 3.1 Order Creation

The system must allow the user to create a new order.

An order must contain at least:

- Customer
- One or more OrderItems
- Expected Pickup Date

Optional information:

- Delivery to Laundry
- Delivery to Customer
- Discount
- Payment
- Order notes

Both delivery types may be selected for the same order.

---

## 3.2 Order Number

Every order must have a human-readable unique Order Number.

The Order Number is separate from the internal database identifier.

The approved V1 display format is:

    YY-XXX

Example:

    26-001

The exact numbering implementation must guarantee uniqueness.

The Order Number is immutable after assignment.

---

## 3.3 Order Statuses

The system must support exactly four order statuses:

- Processing
- Ready
- Completed
- Cancelled

Arabic UI labels:

| Internal Status | Arabic Label |
| --- | --- |
| Processing | قيد التجهيز |
| Ready | جاهز |
| Completed | مكتمل |
| Cancelled | ملغي |

The system must not introduce additional operational statuses in V1.

---

## 3.4 Automatic Status Transition

When all OrderItems have been successfully stored, the system should automatically change the order status from:

    Processing

to:

    Ready

The system must not track individual laundry processing stages.

---

## 3.5 Manual Status Changes

The user must be able to manually change the order status when necessary to correct an operational mistake.

Manual status changes must respect the system's business rules and validations.

The system must not silently perform unintended side effects when a status is manually changed.

If a status change affects storage or other operational state, the behavior must follow the approved business rules.

---

## 3.6 Order Editing

The user must be able to edit an order while it is still operational and editable according to the business rules.

Editable information may include:

- OrderItems
- Services
- Item information
- Expected Pickup Date
- Delivery selections
- Delivery fees where applicable
- Discount
- Notes
- Payments where applicable
- Order item prices where permitted by the approved pricing behavior

Completed and Cancelled orders are considered historical records and should be read-only.

---

## 3.7 Order Search

The user must be able to search orders by:

- Order Number
- Customer name
- Customer phone number

Search should work against locally available data.

---

## 3.8 Order Filtering

The Orders screen must support filtering by order status.

Available status filters:

- All
- Processing
- Ready
- Completed
- Cancelled

Additional useful filters may include:

- Expected Pickup Date
- Payment status
- Delivery to Laundry
- Delivery to Customer

Filters should remain simple and operational.

---

## 3.9 Order Pagination

The Orders list must support pagination/lazy loading because the number of orders is expected to grow over time.

Pagination should not be presented as traditional numbered pages.

The preferred behavior is:

1. Load an initial batch.
2. Load additional records as the user approaches the end of the list.

The exact batch size is an implementation detail.

---

# 4. Order Items

## 4.1 Physical Item Representation

Each physical piece must be represented as an independent OrderItem.

For example:

    Customer brings 5 shirts.

The UI may allow the user to enter:

    Shirt × 5

But the system must internally create:

    5 independent OrderItems.

---

## 4.2 Independent Item Identity

Every OrderItem must have its own internal identifier.

This allows each physical item to have its own:

- Storage location
- Notes
- Item-specific information
- Future barcode identifier

---

## 4.3 Item Types

The system must support the following primary item types:

- Clothing
- Blankets
- Carpets
- Carpet Covers

---

## 4.4 Item Definitions

Item types may contain definitions/subtypes.

Examples:

### Clothing

- Shirt
- Pants
- T-Shirt
- Jacket

### Blankets

- Blanket
- Quilt
- Comforter

### Carpets

- Different carpet definitions as configured by the business

### Carpet Covers

Carpet Covers do not require a separate subtype/type system in V1.

They are treated similarly to blankets for operational purposes.

---

## 4.5 Item Notes

The user should be able to add notes to an individual OrderItem.

Examples:

- Stain on sleeve
- Damaged edge
- Special handling note

Item notes are independent from general Order notes.

---

## 4.6 Item Information Display

The system must clearly display relevant OrderItem information wherever physical items are shown.

This includes:

- Item Type
- Item Definition when applicable
- Carpet size or dimensions when applicable
- Blanket type or definition when applicable
- Carpet measurements when applicable
- Service
- Price

This information must be available in:

- Order Details
- Invoice / Receipt
- Storage

The system must not rely on the Service name alone to identify the physical item.

---

# 5. Services

## 5.1 Service Management

The user must be able to create, edit, activate, and deactivate services.

A service must contain at least:

- Service name
- Pricing type
- Price
- Supported item types

---

## 5.2 Service Availability

Only services available for the selected Item Type should be presented during order creation.

Example:

When the user selects:

    Clothing

the system should show only services configured for Clothing.

---

## 5.3 Service Pricing

The system must support the following pricing models at the domain level:

- Per Piece
- Per Kilogram
- Per Square Meter
- Fixed Price

V1 UI should only expose pricing options that are actually relevant to the selected service/item combination.

The system should not unnecessarily show unsupported or irrelevant pricing options.

---

## 5.4 Price Snapshot

When a service is added to an order, the price used for that OrderItem must be preserved as historical data.

Changing the service's current price must not change the price of existing orders.

---

## 5.5 Order Price Adjustment

During Order creation, the user must be able to adjust the applicable item/service price before saving the order according to the approved pricing behavior.

The adjusted price becomes part of the historical order data.

Opening an existing editable order must allow the user to modify its applicable price when permitted by the business rules.

Historical orders must not be recalculated using the current service price.

---

# 6. Carpet Requirements

## 6.1 Carpet Measurements

Carpet OrderItems must support:

- Length
- Width
- Area

Area must be calculated from:

    Length × Width

---

## 6.2 Common Carpet Sizes

The system must support predefined common carpet sizes.

Examples:

- 2 × 3
- 3 × 3
- 3 × 4
- 4 × 4
- 4 × 5

The exact available sizes are configurable.

---

## 6.3 Custom Carpet Size

The user must be able to enter a custom:

- Length
- Width

The system calculates the Area automatically.

The user should not need to manually enter the calculated Area.

---

## 6.4 Carpet Size History

Changing or deactivating a predefined carpet size must not modify historical OrderItems.

The OrderItem stores its actual dimensions and calculated area.

---

# 7. Order Pricing

## 7.1 Subtotal

The system must calculate the order subtotal from its OrderItems using their applicable historical prices.

---

## 7.2 Discount

Discount must be applied at the Order level.

Item-level discounts are not required in V1.

---

## 7.3 Delivery Fees

The system supports two independent delivery fees:

- Delivery to Laundry fee
- Delivery to Customer fee

Each fee applies only when its corresponding delivery type is selected.

Both delivery types may be selected for the same order.

The applicable delivery fees must be added to the Order total.

If a delivery type is not selected, its corresponding fee is zero.

---

## 7.4 Total

When tax is disabled, the order total must be calculated as:

    Subtotal - Discount + Delivery Fees = Total

Where:

    Delivery Fees = Delivery to Laundry Fee + Delivery to Customer Fee

When tax is enabled, the order calculation must follow:

    Subtotal - Discount + Delivery Fees + Tax = Total

The total must be recalculated when applicable order pricing information is changed before saving or while the order remains editable.

---

## 7.5 Currency

All monetary values use:

    Egyptian Pound (EGP)

UI representation:

    ج.م

Currency selection is not required.

---

# 8. Tax

Tax is disabled by default.

The system must provide configuration for enabling or disabling tax.

When tax is enabled, the system must support a configured tax rate.

The expected calculation flow is:

    Subtotal → Discount → Delivery Fees → Tax → Total

Tax configuration should be centralized.

---

# 9. Payments

## 9.1 Payment Recording

The user must be able to record payments against an order.

---

## 9.2 Multiple Payments

An order may contain multiple payment records.

Example:

    Total = 800 ج.م

First payment:

    300 ج.م

Second payment:

    500 ج.م

---

## 9.3 Partial Payments

Partial payment must be supported.

The system must calculate:

    Paid Amount

and:

    Remaining Amount

---

## 9.4 Payment Methods

V1 payment methods:

- Cash
- InstaPay
- E-Wallet

The payment method must be recorded with each payment.

---

## 9.5 Payment Validation

The system must prevent a payment from exceeding the current remaining amount.

---

## 9.6 Refunds

A complete refund workflow is not required in V1.

There is no dedicated refund management system.

---

# 10. Order Completion and Delivery

## 10.1 Ready Status

An order becomes Ready when all its OrderItems have an active Storage Record.

---

## 10.2 Customer Handover

The user must explicitly confirm that the order has been handed over to the customer.

Completion must not happen automatically just because:

- The order is Ready.
- The order is fully paid.

Both conditions are necessary, but the user must also confirm the actual handover.

---

## 10.3 Completed Requirements

An order can become Completed only when:

1. The order is Ready.
2. The remaining amount is zero.
3. The user confirms that the order was handed over to the customer.

---

## 10.4 Storage After Completion

When an order becomes Completed:

- All active Storage Records for its OrderItems become inactive.
- The items no longer appear in Current Storage.

The historical order and its OrderItems remain available.

---

## 10.5 Delivery to Laundry

The system must allow the user to indicate that the customer wants the laundry items delivered to the laundry.

This delivery type:

- Is independent from Delivery to Customer.
- Has its own delivery fee.
- Contributes its fee to the Order total when selected.

The system only records the delivery requirement and applicable fee.

The system does not manage the actual logistics process.

---

## 10.6 Delivery to Customer

The system must allow the user to indicate that the completed order should be delivered to the customer.

This delivery type:

- Is independent from Delivery to Laundry.
- Has its own delivery fee.
- Contributes its fee to the Order total when selected.

The system only records the delivery requirement and applicable fee.

The system does not manage the actual logistics process.

---

## 10.7 Delivery Combination

Delivery to Laundry and Delivery to Customer are not mutually exclusive.

The user may select:

- Neither
- Delivery to Laundry only
- Delivery to Customer only
- Both

The system must calculate the applicable delivery fees accordingly.

---

## 10.8 Delivery Scope

The system must not require or manage:

- Driver information
- Vehicle information
- Delivery assignment
- Delivery tracking
- Delivery status
- Delivery routes
- Delivery optimization
- Proof of delivery

Delivery remains an Order-level operational and financial option in V1.

---

# 11. Order Cancellation

## 11.1 Cancellation

The user must be able to cancel an order before completion.

---

## 11.2 Cancellation Confirmation

Cancellation requires user confirmation.

The user should provide a cancellation reason.

---

## 11.3 Cancelled Orders

Cancelled orders:

- Are not deleted.
- Remain in order history.
- Become read-only.
- Should not appear as active operational orders.

---

## 11.4 Storage After Cancellation

If an order has active Storage Records when it is cancelled:

    Active Storage Records become inactive.

---

## 11.5 Payments After Cancellation

Existing payment records remain stored as historical records.

There is no automatic refund workflow.

---

# 12. Storage Management

## 12.1 Storage Locations

The system must support configurable storage locations.

A Storage Location contains at least:

- Name
- Active state

Storage locations must be associated with compatible Item Types.

---

## 12.2 Compatible Storage Locations

When the user needs to store an OrderItem, the system should show Storage Locations compatible with that OrderItem's Item Type.

The available locations should be determined by:

    OrderItem → Item Type → Compatible Storage Locations

---

## 12.3 Current Storage

The Storage module must show currently stored physical items.

The primary view should answer:

    Where is this item currently stored?

Storage is associated with the physical OrderItem rather than only with the Order.

---

## 12.4 Items Requiring Storage

The system must provide a way to identify OrderItems that have not yet been stored.

The Items Requiring Storage view must support useful filters according to the approved operational workflow.

---

## 12.5 Storing Items

The user must be able to assign an OrderItem to a compatible Storage Location.

---

## 12.6 Bulk Storage

The user must be able to select multiple physical items and assign them to the same compatible Storage Location in one operation.

Example:

    5 shirts + 1 blanket → A-03

---

## 12.7 Different Locations Within One Order

Items from the same order may be stored in different locations.

Example:

    Shirt 1 → A-01
    Shirt 2 → A-01
    Blanket → B-02
    Carpet → Carpet-01

---

## 12.8 Moving Items

The user must be able to change an item's current Storage Location.

Example:

    A-03 → B-02

---

## 12.9 Storage Movement History

Storage movement history is not required in V1.

Only the current active location is required.

---

## 12.10 Completed Items

When an order is Completed, its Storage Records become inactive.

---

## 12.11 Manual Status Correction

If a Completed order is manually changed back to Processing:

- Its items must not automatically become active in Storage.
- The user must explicitly store the items again if they physically return to storage.

---

# 13. Expected Pickup

Every order must have an Expected Pickup Date.

Requirements:

- Required
- Date only
- No time component

Example:

    25 أغسطس 2026

The system should allow filtering orders based on the Expected Pickup Date.

Orders whose Expected Pickup Date has passed while they are not Completed or Cancelled are considered overdue.

---

# 14. Invoice and Receipt

## 14.1 Invoice / Receipt View

The system must provide an Invoice / Receipt view for an Order.

The user must be able to access the invoice or receipt from the Order workflow.

---

## 14.2 Historical Information

The invoice or receipt must display the historical information associated with the Order.

It must not recalculate historical order information using current master data.

---

## 14.3 Invoice / Receipt Information

The invoice or receipt should display, where applicable:

- Order Number
- Customer
- Item Type
- Item Definition
- Carpet Size
- Carpet dimensions
- Blanket type / definition
- Service
- Price
- Delivery to Laundry fee
- Delivery to Customer fee
- Discount
- Tax
- Total
- Payment information
- Remaining amount

---

## 14.4 Printing

The user must be able to print the Invoice / Receipt from the Order workflow.

---

# 15. Expenses

## 15.1 Expense Recording

The system must allow the user to record an operating expense independently from Orders and Payments.

An Expense must contain at least:

- Amount
- Category
- Date

Additional information may include:

- Notes
- Expense Name when required

An Expense is not associated with an Order.

An Expense is not a Payment.

---

## 15.2 Expense Categories

Expense Categories must be manageable from Settings.

The user must be able to:

- Add an Expense Category
- Edit an Expense Category name
- Activate an Expense Category
- Deactivate an Expense Category

---

## 15.3 Expense Category History

Expense Categories with historical Expense references must not be hard deleted.

Deactivating a category must not change historical Expenses that already reference it.

---

## 15.4 Other Category

The system must provide an Expense Category named:

    أخرى

When:

    أخرى

is selected, the user must enter an Expense Name.

Expense Name is required in this case.

---

## 15.5 Expense Date

Every Expense must have an Expense Date.

The Expense Date is used to determine the reporting period in which the Expense appears.

---

## 15.6 Expense Amount

Expense amounts must be positive monetary values.

All Expense amounts use EGP.

---

# 16. Dashboard

The Dashboard must provide a simple operational overview.

It should focus on:

- Orders created today
- Orders Ready
- Items requiring storage
- Outstanding payments
- Overdue orders
- Today's expected pickups
- Recent orders

The Dashboard must provide Quick Actions for:

- Add Order
- Add Customer
- Record Payment
- Add Expense

Storage must not be presented as a Dashboard Quick Action.

The Dashboard must not contain a large welcome section that does not provide operational value.

The Dashboard must not become a replacement for the Reports module.

Advanced analytics are not required.

---

# 17. Reports

The Reports module must remain intentionally simple.

V1 contains only two report categories:

## 17.1 Orders Report

Must provide:

- Total orders
- Orders by status
- Total order value
- Overdue orders

---

## 17.2 Financial Report

Must provide:

- Sales for the selected period
- Payments recorded during the selected period
- Expenses for the selected period
- Outstanding amounts
- Total discounts
- Payment method breakdown
- Net Profit

Expenses must be included according to their Expense Date.

Net Profit is a derived reporting value.

The calculation is:

    Net Profit = Sales - Operating Expenses

Net Profit is not a separate transaction or entity.

The system must not require a separate profit table, profit snapshot, or analytics table for Net Profit.

---

## 17.3 Report Period

Reports must support date-based filtering.

Useful predefined periods may include:

- Today
- Yesterday
- Last 7 Days
- This Month
- Previous Month
- Custom Date Range

---

## 17.4 Report Scope

The following are explicitly not required in V1:

- Service analytics
- Storage analytics
- Customer analytics
- Advanced charts
- Complex BI dashboards
- Predictive analytics

---

# 18. Settings

## 18.1 Business Information

The system must allow the user to configure the laundry/business name.

---

## 18.2 Services & Pricing

Services & Pricing must be managed from Settings.

The Settings area must provide access to:

- Services
- Service pricing
- Item types
- Item definitions where applicable
- Common carpet sizes

Services & Pricing must not appear as a separate primary navigation item in V1.

---

## 18.3 Expense Categories

Expense Categories must be managed from Settings.

The user must be able to:

- Add categories
- Edit category names
- Activate categories
- Deactivate categories

Historical references must be preserved.

---

## 18.4 Tax Settings

The system must provide configuration for:

- Tax enabled/disabled
- Tax rate

Tax is disabled by default.

---

## 18.5 Settings Not Required

V1 does not require:

- Branch management
- Currency management
- User management
- Role management
- Permission management
- Driver management
- Vehicle management
- Delivery management configuration
- Delivery tracking configuration
- Notification configuration

---

# 19. Navigation

The V1 primary navigation must contain:

- Dashboard
- Orders
- Customers
- Storage
- Reports
- Settings

Services & Pricing must be accessed from Settings.

Expense Categories must be accessed from Settings.

The system must not add additional primary navigation items unless explicitly approved as a new requirement.

---

# 20. Offline Requirements

The following operations must remain available without internet connectivity:

- View customers
- Search customers
- Create customers
- Edit customers
- View orders
- Search orders
- Create orders
- Edit orders
- Manage OrderItems
- Manage Storage
- Move items
- Record payments
- Record expenses
- Manage Expense Categories
- View reports
- View dashboard
- View invoices and receipts
- Manage local configuration

The user should not be blocked from normal operation because of temporary internet loss.

---

# 21. Synchronization Requirements

When connectivity is available, local changes should be synchronized with the remote backend.

Synchronization must support the relevant transactional and master data required by the application, including:

- Orders
- OrderItems
- Customers
- Payments
- Expenses
- Expense Categories
- Storage
- Services
- Item definitions
- Other approved configuration data

Synchronization must not prevent normal local operations.

The system should communicate synchronization state to the user in a simple way.

Possible states:

- Synchronized
- Synchronizing
- Waiting for synchronization
- Offline

Synchronization details should not clutter the main operational UI.

---

# 22. Data History Requirements

Historical order information must remain stable even when master data changes.

For example:

If a service price changes from:

    40 ج.م

to:

    50 ج.م

existing orders must continue to show:

    40 ج.م

Similarly, historical order items should preserve the relevant item/service information used at the time the order was created.

Historical Order financial information must preserve the applicable:

- Item prices
- Service information
- Delivery fees
- Discount
- Tax
- Total
- Payment information

Changes to current master data must not recalculate historical Orders.

Historical Expenses must also remain associated with the Expense Category that was used when the Expense was recorded.

Deactivating or editing a master-data record must not rewrite historical transaction information.

---

# 23. Barcode Readiness

Barcode scanning is not required in V1.

However, every physical OrderItem must have an independent identifier so barcode support can be added later.

The current UX must not require users to enter or scan barcodes.

---

# 24. V1 Non-Functional Product Requirements

The system should prioritize:

- Fast interaction
- Clear Arabic UI
- RTL correctness
- Tablet usability
- Offline operation
- Data consistency
- Maintainable architecture
- Reusable UI components
- Reliable local data
- Predictable behavior

---

# 25. Explicitly Out of Scope for V1

The following features must not be implemented unless explicitly added to the requirements later:

- Multiple user roles
- Permissions
- Employee management
- Driver management
- Vehicle management
- Delivery tracking
- Delivery routing
- Delivery assignment
- Delivery status management
- Delivery optimization
- Proof of delivery
- Refund workflow
- Loyalty program
- Customer points
- Multi-branch support
- Multi-currency support
- Advanced analytics
- AI assistant
- Barcode scanning
- Detailed laundry processing stages
- Storage movement history
- Storage capacity management
- Complex notification system
- Full accounting system
- Full delivery management system
- Separate profit management system

---

# 26. Requirement Change Rule

Any change to a confirmed requirement must be reflected in the project documentation.

The implementation must not silently introduce behavior that contradicts this document.

If a requirement is ambiguous or conflicts with another documented requirement, the implementation should stop and the conflict should be resolved before proceeding.