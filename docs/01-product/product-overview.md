# Laundry Management System — Product Overview

## 1. Document Purpose

This document provides the high-level overview of the Laundry Management System.

It defines what the product is, who it is for, the main problems it solves, and the overall product direction.

This document is part of the project's permanent documentation and should be treated as a source of truth for the product scope and direction.

---

## 2. Product Overview

The Laundry Management System is a simple operational management system designed for laundry businesses.

The system helps the laundry staff manage the complete lifecycle of customer orders, from order creation until the order is handed over to the customer.

The system focuses on:

- Customer management
- Order management
- Item management
- Services and pricing
- Storage management
- Payments
- Expenses
- Order pickup tracking
- Basic operational dashboard
- Basic reports
- Basic financial reporting
- Basic settings
- Invoice and receipt viewing and printing

The system is intentionally designed to remain simple and operational.

It is not intended to become a complex enterprise laundry management or logistics platform.

---

## 3. Primary User

The system is designed primarily for a single laundry employee/user operating the main tablet.

There are currently:

- No user roles
- No permissions system
- No employee management
- No driver management

The system assumes a simple operating model where the user has access to all available features.

### Future Device Usage

In the future, the laundry owner/manager may install the application on their own mobile device.

The mobile device should access the same business data and provide the same feature set.

The current product does not introduce different roles or permissions between devices.

---

## 4. Primary Device

The primary target device is a tablet.

The UI should be designed and optimized for tablet usage first.

Mobile support should be considered in the architecture, but mobile-specific UX is not the primary design target for V1.

The system should maintain the same information architecture across device sizes.

---

## 5. Language and Direction

The application is Arabic-first.

### Required

- All user-facing UI text must be Arabic.
- The application must support RTL layouts.
- Navigation must follow RTL conventions.
- Forms, tables, dialogs, bottom sheets, and layouts must be RTL-aware.
- Arabic typography must be considered from the beginning of the design.

English may only appear in technical/internal contexts or where explicitly required.

---

## 6. Currency

The system currently supports only one currency:

> Egyptian Pound (EGP)

Displayed to users as:

> ج.م

Currency selection is not required.

There is no multi-currency support in V1.

---

## 7. Branches

The system currently supports a single branch only.

There is no branch management feature in V1.

The system does not need:

- Branch entities
- Branch switching
- Branch-specific permissions
- Multi-branch reporting

Multi-branch support may be considered in the future but should not influence the V1 UX unnecessarily.

---

## 8. Core Product Philosophy

The product should follow these principles:

### Simplicity

The system should solve the laundry's daily operational needs without unnecessary complexity.

### Speed

Common operations should require as few steps as possible.

The user should be able to create and manage an order quickly.

### Clarity

Important information should be immediately understandable.

The UI should avoid unnecessary visual noise.

### Operational Focus

The product is designed for daily operational use, not for advanced enterprise analytics.

### Offline-First

Core functionality must remain usable without an internet connection.

### Consistency

The same interaction patterns and visual components should be reused throughout the application.

### Maintainability

The system should be designed so future developers and AI coding agents can understand and safely modify it.

### Historical Integrity

Historical business information must remain stable and understandable even when master data changes.

---

## 9. Core Modules

The V1 application consists of the following main modules and functional areas:

### Dashboard

Provides a quick operational overview of what requires attention.

The Dashboard focuses on current operational information rather than advanced analytics.

### Orders

Manages customer orders throughout their lifecycle.

This includes:

- Order creation
- Order editing
- Order status management
- Order items
- Pricing
- Delivery information
- Payments
- Order history
- Invoice and receipt access

### Customers

Stores customer information and order history.

### Storage

Tracks the current physical storage location of laundry items.

Storage is associated with physical OrderItems rather than only with Orders.

### Services & Pricing

Manages:

- Services
- Item types
- Item definitions
- Pricing types
- Service prices
- Common carpet sizes

Services & Pricing is part of Settings in the V1 navigation structure.

### Reports

Provides basic operational and financial reports.

V1 includes:

- Orders Report
- Financial Report

### Expenses

Records operating expenses independently from Orders and Payments.

Expenses are financial transactions in their own right and are not attached to individual Orders.

### Settings

Contains the limited system configuration currently required.

Settings include:

- Business information
- Services & Pricing
- Expense Categories
- Tax settings
- Other approved V1 configuration

### Invoice / Receipt

Provides access to historical order financial and item information through an invoice or receipt view.

The user can view and print an order's invoice or receipt from the Order workflow.

---

## 10. Order Lifecycle

The core order lifecycle consists of four statuses:

Processing
    ↓
Ready
    ↓
Completed

An order can also become:

Cancelled

The system intentionally does not model detailed operational laundry processing stages.

For example, the system does not track:

- Washing
- Drying
- Ironing
- Folding
- Quality control
- Packaging

as separate order statuses.

These operational details are outside the current product scope.

Manual status changes are supported where allowed by the business rules.

---

## 11. Storage Concept

Storage is a core part of the system.

Each physical OrderItem can have one active storage location at a time.

The user must be able to:

- Store an item.
- See where an item is currently stored.
- Move an item from one storage location to another.
- Store multiple items at once when appropriate.

Storage locations are determined according to the compatible Item Type.

The system does not currently maintain a movement history.

Storage records become inactive when an order is completed.

If an order is manually changed back from Completed to Processing, its storage records are not automatically reactivated.

The user must explicitly store the physical items again when required.

---

## 12. Delivery Concept

The system does not manage delivery operations as a separate logistics system.

V1 supports two independent delivery directions:

### Delivery to Laundry

The customer requests that the laundry items be delivered to the laundry.

### Delivery to Customer

The customer requests that the completed order be delivered to the customer.

Both delivery types may be selected for the same Order.

Each delivery type has its own delivery fee.

The applicable delivery fees are added to the Order when the Order is created.

The system does not manage:

- Drivers
- Vehicles
- Delivery routes
- Delivery tracking
- Driver assignment
- Delivery status
- Delivery optimization
- Proof of delivery
- A separate delivery management workflow

Delivery remains an Order-level operational and financial option rather than a separate logistics subsystem.

---

## 13. Payments

The system supports recording payments against orders.

An order may have:

- No payment
- One payment
- Multiple payments

Partial payments are supported.

The system tracks:

- Order total
- Total paid
- Remaining amount

V1 payment methods are:

- Cash
- InstaPay
- E-Wallet

The system does not currently implement a complete refund workflow.

Payment records remain part of the historical financial record of the Order.

---

## 14. Expenses

Expenses are independent financial transactions.

An Expense is not associated with an Order or Payment.

The system supports recording an Expense with information such as:

- Amount
- Category
- Date
- Notes
- Expense Name when required

Expense Categories are managed from Settings.

The user can:

- Add an Expense Category
- Edit an Expense Category name
- Activate or deactivate an Expense Category

Expense Categories must preserve historical references.

A category named:

> أخرى

is available for expenses that do not fit the configured categories.

When:

> أخرى

is selected, the Expense Name is required so the actual expense can be identified.

Expenses are included in the Financial Report according to their expense date.

---

## 15. Discounts, Taxes, and Order Total

### Discount

Discounts are applied at the Order level.

Item-level discounts are not required in V1.

### Delivery Fees

Delivery fees are part of the Order financial calculation.

Delivery to Laundry and Delivery to Customer have independent fees.

### Tax

Tax is disabled by default.

The system should allow tax to be enabled through Settings.

When tax is enabled, the Order calculation follows:

> Subtotal - Discount + Delivery Fees + Tax = Total

When no delivery fee applies, the corresponding delivery fee is zero.

The financial values used by the Order must remain historically stable after the Order is created.

---

## 16. Financial Reporting

The Financial Report provides a simple financial overview for a selected reporting period.

It includes:

- Sales
- Payments
- Expenses
- Remaining Amount
- Discounts
- Payment Method breakdown
- Net Profit

Expenses are included according to their expense date.

Net Profit is a derived reporting value.

It is calculated as:

> Net Profit = Sales - Operating Expenses

Net Profit is not a separate transaction or business entity.

The product does not require:

- Profit tables
- Profit snapshots
- Separate expense ledgers
- Analytics tables

unless a future requirement explicitly introduces them.

The Financial Report should remain simple and operational rather than becoming a full accounting or business intelligence system.

---

## 17. Carpet Handling

Carpets are treated differently from normal piece-based items because their pricing is based on area.

The system supports:

- Length
- Width
- Calculated Area

The user may either:

- Select a predefined common carpet size.
- Enter a custom length and width.

The calculated area is stored as part of the OrderItem's carpet-specific data.

Common carpet sizes are managed separately for faster order entry.

---

## 18. Item Modeling

The system distinguishes between different item categories to avoid unnecessary nullable fields and keep the data model clean.

Current primary item types include:

- Clothing
- Blankets
- Carpets
- Carpet Covers

Each item type may have its own definitions/subtypes where applicable.

Carpet Covers are treated similarly to blankets from an operational perspective and do not require a separate cover subtype system.

---

## 19. Quantity Concept

When a customer brings multiple identical pieces, the UI may allow the user to enter a quantity for convenience.

For example:

> 5 shirts

The user enters quantity 5 once.

Internally, the system represents these as five independent OrderItems.

This allows each physical item to have its own:

- Identifier
- Storage location
- Notes
- Future barcode identifier

while keeping the order-entry experience fast.

---

## 20. Item Identification

Each physical OrderItem has an independent internal identifier.

The current system does not require barcode scanning.

However, the data model should not prevent adding barcode support in the future.

Barcode support is considered a future enhancement rather than a V1 requirement.

---

## 21. Expected Pickup

Every order requires an Expected Pickup date.

The value is:

- Required
- Date only
- No time component

Example:

> 25 أغسطس 2026

Time-based pickup scheduling is not part of V1.

---

## 22. Invoice and Receipt

The system must provide an invoice or receipt view for an Order.

The invoice or receipt should preserve and display the important historical information of the Order.

This includes, where applicable:

- Order Number
- Customer
- Item Type
- Item Definition
- Carpet Size or dimensions
- Service
- Price
- Delivery Fees
- Discount
- Tax
- Total
- Payment information
- Remaining amount

The user should be able to print the invoice or receipt from the Order workflow.

The invoice must use the historical Order information rather than recalculating the Order using current master data.

---

## 23. Order Number

Every Order has a unique human-readable Order Number.

The Order Number is separate from the internal database identifier.

The approved V1 display format is:

> YY-XXX

Example:

> 26-001

The Order Number is immutable after assignment.

The technical UUID must not be used as the primary Order identifier in the user interface.

---

## 24. Offline-First Direction

The application is designed as an Offline-First system.

Core operations should work without an internet connection, including:

- Viewing orders
- Creating orders
- Editing orders
- Managing customers
- Managing storage
- Moving items
- Recording payments
- Recording expenses
- Managing expense categories
- Viewing reports
- Viewing invoices and receipts
- Managing approved local configuration

The local database is the primary source of truth for normal application operation.

Remote synchronization is responsible for keeping data synchronized when connectivity is available.

---

## 25. Navigation Direction

The primary navigation remains intentionally simple.

The V1 primary navigation contains:

- Dashboard
- Orders
- Customers
- Storage
- Reports
- Settings

Services & Pricing is accessed from Settings rather than from the primary navigation.

Expense Categories are also managed from Settings.

Expenses are operational financial records and should be accessible through the approved expense workflow without introducing unnecessary top-level navigation.

---

## 26. Dashboard Direction

The Dashboard is an operational overview and should not replace the Orders, Storage, Customers, or Reports modules.

The Dashboard should focus on:

- Orders created today
- Orders Ready
- Items/orders requiring storage
- Outstanding payments
- Overdue orders
- Today's expected pickups
- Recent orders
- Quick actions

The approved Dashboard Quick Actions are:

- Add Order
- Add Customer
- Record Payment
- Add Expense

Storage is not a Dashboard Quick Action.

The Dashboard must not contain a large welcome section that does not provide operational value.

The Dashboard should not become a replacement for the Reports module or a full analytics dashboard.

---

## 27. Future Expansion

The architecture should allow future expansion without forcing those features into V1.

Potential future capabilities may include:

- Barcode scanning
- Multi-device usage
- Advanced synchronization
- Multi-branch support
- More advanced reporting
- Full delivery management
- Additional pricing models
- Tax support enhancements
- More advanced customer features

Future capabilities should not add unnecessary complexity to the V1 user experience.

---

## 28. Explicit Product Direction

The Laundry Management System should remain:

> Simple, fast, operational, Arabic-first, tablet-first, and offline-first.

Any future feature or architectural decision should be evaluated against these principles.

Features that add complexity without solving a real operational problem should not be introduced into V1.

Any approved requirement change must be reflected in the relevant project documentation before implementation.