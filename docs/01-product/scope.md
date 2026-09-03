# Laundry Management System — V1 Scope

## 1. Document Purpose

This document defines the boundaries of Version 1 (V1) of the Laundry Management System.

Its purpose is to clearly distinguish:

- What must be implemented in V1.
- What may be supported by the architecture but is not exposed in V1.
- What is explicitly outside the current product scope.

This document is a scope-control document.

No feature should be added to V1 simply because it may be useful in the future.

---

# 2. V1 Product Scope

V1 focuses on the core daily operations of a single-branch laundry business.

The system must support:

1. Customer management
2. Order management
3. Order item management
4. Services and pricing
5. Storage management
6. Payments
7. Expenses
8. Expected pickup tracking
9. Invoice and receipt viewing and printing
10. Basic dashboard
11. Basic reports
12. Basic settings
13. Offline-first operation
14. Local data management
15. Synchronization with the backend when connectivity is available

---

# 3. Target Operating Model

V1 assumes:

- One laundry branch.
- One primary user.
- One primary tablet.
- Arabic-first interface.
- RTL interface.
- Egyptian Pound currency.
- Offline-first operation.
- Simple operational workflows.

The application does not attempt to model a large enterprise laundry operation.

---

# 4. Customer Management Scope

## Included

- Create customer
- Edit customer
- Search customer
- View customer details
- View customer order history
- Start a new order from customer details
- Validate phone numbers
- Prevent duplicate customers based on phone number

## Not Included

- Customer accounts/login
- Customer mobile application
- Customer portal
- Loyalty points
- Customer levels
- Marketing campaigns
- Customer segmentation
- Customer addresses as a delivery management system
- Customer notifications
- Email management

---

# 5. Order Management Scope

## Included

- Create order
- Generate unique order number
- Select customer
- Add one or more OrderItems
- Edit order
- Search orders
- Filter orders
- Pagination/lazy loading
- Expected Pickup Date
- Delivery to Laundry
- Delivery to Customer
- Independent delivery fees
- Order notes
- Order discount
- Order status management
- Order cancellation
- Order completion
- Order history
- Invoice / Receipt view
- Print Invoice / Receipt

## Order Number

Every order must have a unique human-readable Order Number.

The approved V1 display format is:

    YY-XXX

Example:

    26-001

The Order Number is separate from the internal database identifier.

The Order Number is immutable after assignment.

## Order Statuses

V1 supports only:

- Processing
- Ready
- Completed
- Cancelled

No additional operational statuses should be introduced.

---

# 6. Order Item Scope

## Included

Each physical item is represented as an independent OrderItem.

The system supports:

- Item type
- Item definition
- Service
- Price snapshot
- Item-specific notes
- Independent identifier
- Storage location
- Future barcode readiness
- Applicable carpet measurements
- Applicable item-specific information

The UI may support quantity-based entry for identical items.

Example:

    Shirt × 5

Internally:

    5 independent OrderItems.

---

# 7. Item Type Scope

V1 supports these primary item types:

- Clothing
- Blankets
- Carpets
- Carpet Covers

Item definitions/subtypes are supported where useful.

Carpet Covers do not require their own subtype system.

They are operationally treated similarly to Blankets.

---

# 8. Carpet Scope

## Included

- Length
- Width
- Calculated area
- Common predefined sizes
- Custom sizes
- Size management
- Area-based pricing

## User Experience

The user may select:

    2 × 3

or enter:

    Custom Length + Width

The system calculates the area automatically.

## Not Included

- Complex carpet shape calculations
- Irregular polygon measurements
- Carpet image measurement
- Camera-based measurement
- AI measurement
- Advanced carpet classification

---

# 9. Services & Pricing Scope

## Included

- Create service
- Edit service
- Activate/deactivate service
- Configure pricing type
- Configure price
- Configure supported item types
- Manage item definitions
- Manage common carpet sizes

Services & Pricing is part of Settings in the V1 navigation structure.

## Supported Pricing Types at Domain Level

- Per Piece
- Per Kilogram
- Per Square Meter
- Fixed Price

Only relevant pricing options should be exposed in the V1 UI.

## Current Expected Usage

| Item Type | Typical Pricing |
|---|---|
| Clothing | Per Piece |
| Blankets | Per Piece |
| Carpet Covers | Per Piece |
| Carpets | Per Square Meter |

---

# 10. Pricing History Scope

Historical order prices must remain unchanged after service prices are modified.

V1 must preserve the price used when the OrderItem was created.

The system must not recalculate historical orders using current service prices.

The user may adjust the applicable OrderItem price during Order creation according to the approved pricing behavior.

Editable existing orders may also allow price adjustment where permitted by the business rules.

---

# 11. Discount Scope

## Included

- Order-level discount
- Discount reflected in order total
- Discount included in financial reports
- Historical preservation of the applied discount

## Not Included

- Item-level discount
- Coupon system
- Promo codes
- Loyalty discounts
- Complex discount rules
- Automatic promotional pricing

---

# 12. Tax Scope

Tax is disabled by default.

V1 includes the basic configuration required to enable tax when needed.

## Included

- Tax configuration structure
- Enable/disable capability
- Tax rate configuration
- Tax reflected in applicable order totals
- Tax information preserved for historical orders

## Default

Tax is disabled.

## Not Included

- Complex tax rules
- Multiple tax types
- Regional tax rules
- Tax authority integrations
- Advanced tax management

---

# 13. Payment Scope

## Included

- Record payment
- Multiple payments per order
- Partial payments
- Remaining amount calculation
- Payment history
- Payment method

## V1 Payment Methods

- Cash
- InstaPay
- E-Wallet

## Not Included

- Online payment gateway
- Card terminal integration
- Automatic bank reconciliation
- Refund workflow
- Chargeback handling
- Payment settlement system

---

# 14. Order Completion Scope

An order is considered Completed only after the actual customer handover is confirmed.

Completion requires:

1. Order is Ready.
2. Remaining amount is zero.
3. User confirms the order was handed over.

Being Ready or fully paid alone must not automatically mark the order as Completed.

---

# 15. Cancellation Scope

## Included

- Cancel order
- Confirmation
- Cancellation reason
- Preserve cancelled order history
- Deactivate active storage records
- Preserve payment history

## Not Included

- Refund workflow
- Automatic refund
- Refund approvals
- Refund reports

---

# 16. Storage Scope

Storage is a core V1 module.

## Included

- Storage locations
- Compatible storage locations by Item Type
- Current stored items
- Items requiring storage
- Store item
- Bulk storage
- Move item
- Search stored items
- Filter by location
- Filter items requiring storage
- Open related order
- Active/inactive storage state
- Display relevant OrderItem information

## Storage Model

Each physical OrderItem can have one active storage location at a time.

Compatible storage locations are determined by:

    OrderItem → Item Type → Compatible Storage Locations

Items from the same order may be stored in different locations.

Example:

    Order #26-001

    Shirt 1 → A-01
    Shirt 2 → A-01
    Blanket → B-02
    Carpet → Carpet-01

## Not Included

- Storage movement history
- Storage capacity management
- Shelf capacity
- Automated warehouse management
- Barcode-based storage scanning
- RFID
- Warehouse analytics

---

# 17. Storage and Order Status Scope

When all OrderItems are stored:

    Processing → Ready

When the order is Completed:

    Active Storage Records → Inactive

If a Completed order is manually changed back to Processing:

- Storage Records do not automatically become active.
- The user must explicitly store the items again if required.

---

# 18. Delivery Scope

V1 supports two independent delivery directions.

## Delivery to Laundry

The customer requests that the laundry items be delivered to the laundry.

## Delivery to Customer

The laundry sends the completed order to the customer.

Both delivery types may be selected for the same Order.

The supported combinations are:

- Neither
- Delivery to Laundry only
- Delivery to Customer only
- Both

Each delivery type has its own delivery fee.

The applicable delivery fees are added to the Order total.

## Included

- Delivery to Laundry selection
- Delivery to Customer selection
- Independent delivery fees
- Display delivery information on Order Details
- Display delivery fees in applicable order financial information
- Include delivery fees in Invoice / Receipt
- Include delivery fees in the Order total
- Filter orders by delivery type where useful

## Not Included

- Drivers
- Driver accounts
- Driver assignment
- Vehicles
- Routes
- Delivery tracking
- Delivery status
- Delivery optimization
- Proof of delivery
- Customer delivery application
- Separate delivery management system

Delivery remains an Order-level operational and financial option in V1.

---

# 19. Expected Pickup Scope

## Included

- Required Expected Pickup Date
- Date-only value
- Order list filtering
- Dashboard pickup information
- Overdue identification

## Not Included

- Pickup time
- Time slots
- Appointment scheduling
- Calendar booking
- Automated customer reminders

---

# 20. Invoice and Receipt Scope

## Included

- Invoice / Receipt view
- Access Invoice / Receipt from Order workflow
- Print Invoice / Receipt
- Historical Order information
- Order Number
- Customer information
- Item Type
- Item Definition where applicable
- Carpet Size / dimensions where applicable
- Blanket type / definition where applicable
- Service
- Price
- Delivery to Laundry fee where applicable
- Delivery to Customer fee where applicable
- Discount
- Tax where applicable
- Total
- Payment information
- Remaining amount

The Invoice / Receipt must use the historical information of the Order.

It must not recalculate historical Order information using current Service prices or other current master data.

## Not Included

- Advanced invoice templates
- Multiple invoice formats
- Electronic invoicing integrations
- External accounting integrations
- Customer self-service invoice portal

---

# 21. Expenses Scope

Expenses are independent financial transactions.

An Expense is not associated with an Order.

An Expense is not a Payment.

## Included

- Record expense
- Edit expense where permitted
- View expense information
- Expense amount
- Expense category
- Expense date
- Expense notes
- Expense Name when required
- Expense Categories management
- Activate/deactivate Expense Categories
- Expense history
- Include Expenses in Financial Reports

## Expense Categories

The user must be able to:

- Add Expense Category
- Edit Expense Category name
- Activate Expense Category
- Deactivate Expense Category

Categories with historical references must not be hard deleted.

## Other Category

The system includes the category:

    أخرى

When:

    أخرى

is selected, the user must provide an Expense Name.

Expense Name is required in this case.

## Expense Date

Every Expense must have an Expense Date.

The Expense Date determines the reporting period in which the Expense appears.

## Expense Amount

Expense amounts must be positive monetary values.

All Expense amounts use EGP.

## Not Included

- Expense approval workflow
- Expense reimbursement workflow
- Supplier expense management
- Purchase order management
- Accounting ledger
- Advanced accounting
- Budget management
- Separate expense analytics system

---

# 22. Dashboard Scope

The Dashboard is operational rather than analytical.

## Included

- Orders today
- Ready orders
- Items/orders requiring storage
- Outstanding payments
- Overdue orders
- Today's expected pickups
- Recent orders
- Quick actions

## Quick Actions

The approved Dashboard Quick Actions are:

- Add Order
- Add Customer
- Record Payment
- Add Expense

Storage is not a Dashboard Quick Action.

## Not Included

- Advanced analytics
- Complex charts
- Business intelligence
- Predictive analytics
- Service performance analytics
- Customer analytics
- Large non-operational welcome section

The Dashboard should not become a replacement for the Reports module.

---

# 23. Reports Scope

V1 includes two report categories.

## Orders Report

Includes:

- Total orders
- Orders by status
- Total order value
- Overdue orders

## Financial Report

Includes:

- Sales
- Payments recorded
- Expenses
- Outstanding amounts
- Discounts
- Payment method breakdown
- Net Profit

Expenses are included according to their Expense Date.

Net Profit is a derived reporting value.

The calculation is:

    Net Profit = Sales - Operating Expenses

Net Profit is not a separate transaction or entity.

The system does not require:

- Profit table
- Profit snapshot
- Expense ledger
- Analytics tables

## Report Period

Reports must support date-based filtering.

Useful predefined periods may include:

- Today
- Yesterday
- Last 7 Days
- This Month
- Previous Month
- Custom Date Range

## Not Included

- Service reports
- Storage reports
- Customer reports
- Employee reports
- Driver reports
- Advanced BI
- Predictive analytics
- Complex dashboards
- Automated exports

---

# 24. Settings Scope

## Included

- Laundry/business name
- Services & Pricing
- Item definitions where applicable
- Common carpet sizes
- Expense Categories
- Tax settings

## Services & Pricing

Services & Pricing is accessed from Settings.

It includes:

- Services
- Service pricing
- Item types
- Item definitions where applicable
- Common carpet sizes

## Expense Categories

Expense Categories are accessed from Settings.

The user can:

- Add categories
- Edit category names
- Activate categories
- Deactivate categories

Historical references must be preserved.

## Tax Settings

The user can configure:

- Tax enabled/disabled
- Tax rate

Tax is disabled by default.

## Fixed Configuration

The following are fixed in V1:

- Single branch
- Egyptian Pound
- Arabic language
- RTL

## Not Included

- Branch management
- Currency management
- User management
- Role management
- Permission management
- Driver settings
- Delivery management settings
- Notification settings

---

# 25. Navigation Scope

The primary navigation contains:

- Dashboard
- Orders
- Customers
- Storage
- Reports
- Settings

Services & Pricing is accessed from Settings.

Expense Categories are accessed from Settings.

The navigation should remain simple and should not contain unnecessary nested sections.

---

# 26. Offline-First Scope

Core business operations must work offline.

## Included Offline Operations

- Customers
- Orders
- OrderItems
- Storage
- Payments
- Expenses
- Expense Categories
- Services & Pricing
- Dashboard
- Reports
- Invoice / Receipt viewing
- Settings

The user should not need an active internet connection to continue normal daily operations.

---

# 27. Synchronization Scope

The application should synchronize local changes with the backend when connectivity is available.

## Included

- Detect connectivity state
- Queue local changes
- Synchronize changes
- Handle synchronization state
- Provide basic sync feedback
- Synchronize Orders
- Synchronize OrderItems
- Synchronize Customers
- Synchronize Payments
- Synchronize Expenses
- Synchronize Expense Categories
- Synchronize Storage
- Synchronize Services & Pricing
- Synchronize approved configuration data

## Not Included in V1

- Advanced conflict resolution UI
- Manual sync management
- Multi-device conflict workflows
- Sync administration dashboard

The synchronization architecture should remain extensible for future multi-device use.

---

# 28. Device Scope

## Primary

- Tablet

## Future

- Mobile phone

The application should not introduce separate business rules for mobile.

The same core functionality should remain available across supported devices.

---

# 29. Localization Scope

## Included

- Arabic UI
- RTL layout
- Arabic labels
- Arabic dates
- Egyptian currency display

## Not Included

- Multiple languages
- Language switching
- Translation management system

The architecture may support localization in the future.

---

# 30. Design Scope

The application must use a centralized design system.

The design system must define:

- Colors
- Typography
- Spacing
- Radius
- Dimensions
- Component styles
- Status colors
- Shared UI components

Feature screens must not define independent visual systems.

---

# 31. AI Development Scope

AI coding tools may be used to implement the system.

AI-generated implementation must follow:

- Project documentation
- Business rules
- Architecture rules
- Design system
- Existing code conventions

AI tools must not invent features or modify confirmed requirements without explicit approval.

---

# 32. Explicit V1 Exclusions

The following are outside the V1 scope:

- AI assistant
- AI recommendations
- AI analytics
- Barcode scanning
- RFID
- Customer mobile app
- Driver app
- Separate delivery management system
- Delivery tracking
- Delivery routing
- Delivery assignment
- Multi-branch
- Multi-currency
- Roles and permissions
- Employee management
- Loyalty system
- Advanced notifications
- Refund workflow
- Advanced reporting
- Advanced warehouse management
- Storage movement history
- Storage capacity management
- Complex tax management
- Online payment integration
- Advanced analytics
- Predictive analytics
- Full accounting system
- Advanced expense management
- Accounting ledger
- Budget management

---

# 33. Scope Change Policy

Any new feature should be evaluated before being added to V1.

The following questions should be answered:

- Does the feature solve a real current operational problem?
- Is it required for the core workflow?
- Can the workflow work correctly without it?
- Does it add unnecessary complexity?
- Does it affect the existing domain model?
- Does it require updates to other documentation?
- Does it introduce future technical debt?

If the feature is not necessary for V1, it should normally be deferred.

---

# 34. Scope Stability Rule

The V1 scope should remain stable during implementation unless a real business requirement is discovered.

Changes should be documented before implementation.

The relevant documentation must be updated whenever an approved scope change occurs.

The implementation must always reflect the latest approved documentation.