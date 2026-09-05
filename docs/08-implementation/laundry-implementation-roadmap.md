# Laundry Management System — Implementation Roadmap

## Purpose

This document defines the agreed high-level implementation order for the V1 Laundry Management System.

The task numbers are **sequence numbers**, not a pre-existing official project plan. Each task should be planned and locked before implementation, and this roadmap should be updated only when the project direction is explicitly changed.

The implementation workflow remains:

> **Understand → Review → Decide → Plan → Prompt → Implement → Audit → Fix → Verify → Lock → Next Task**

---

## Roadmap

| Task | Stage | Primary Goal | Status |
|---|---|---|---|
| Task #01 | Foundation / Architecture | Establish the project foundation, architecture boundaries, conventions, and core technical direction. | Completed |
| Task #02 | Database | Implement and verify the local SQLite/Drift database baseline. | Completed |
| Task #03 | Domain + Data Layer | Establish domain entities/value objects, repository contracts, DAOs, repository implementations, and data-layer foundation. | Completed |
| Task #04 | Application Workflows | Implement the core business workflows through selective Application-layer UseCases. | Completed / Locked |
| **Task #05** | **Core Presentation Foundation** | Establish the core Flutter presentation foundation and prepare the first production-ready screen flow. | **Next** |
| Task #06 | Orders — End-to-End | Implement the core Order experience from creation through order management, using the existing business workflows. | Planned |
| Task #07 | Customers | Implement customer management and its integration with Orders. | Planned |
| Task #08 | Storage | Implement the operational storage workflow for physical OrderItems, including storing and moving items. | Planned |
| Task #09 | Payments | Implement the payment workflow and payment-related Order experience. | Planned |
| Task #10 | Expenses | Implement operational expense management. | Planned |
| Task #11 | Services & Pricing / Settings | Implement management of services, pricing/master data, and approved Settings workflows. | Planned |
| Task #12 | Dashboard | Implement the operational Dashboard using real data from the completed workflows. | Planned |
| Task #13 | Reports | Implement operational and financial reporting using authoritative transaction data. | Planned |
| Task #14 | Invoice / Receipt | Implement invoice/receipt viewing and printing using historical Order information. | Planned |
| Task #15 | Offline / Sync Integration | Integrate and verify synchronization after the core local workflows are stable. | Planned |
| Task #16 | Full Integration / QA / Hardening | Perform end-to-end verification, business-rule audit, offline testing, UI/RTL/responsive checks, and release hardening. | Planned |

---

# Task Sequencing Principles

## 1. Build foundations before dependent workflows

The project should establish the technical and business foundations before building feature workflows on top of them.

Current completed sequence:

```text
Foundation / Architecture
        ↓
Database
        ↓
Domain + Data Layer
        ↓
Application Workflows
```

Task #04 provides the current business-workflow foundation for the next presentation phase.

---

## 2. Do not interpret the roadmap as a strict layer-by-layer architecture plan

The roadmap is organized around useful implementation increments and product workflows, not simply:

```text
Domain → Data → Application → Presentation
```

After the foundation is complete, implementation should move toward **vertical feature slices** where practical.

For example:

```text
Presentation Foundation
        ↓
Orders E2E
        ↓
Customers / Storage / Payments
        ↓
Expenses / Settings
        ↓
Dashboard / Reports / Invoice
```

---

## 3. Task #05 is intentionally a foundation, not "all UI"

Task #05 should establish only the presentation infrastructure and shared UI capabilities actually required by the first production-ready flows.

It must not become an uncontrolled effort to build every possible shared component.

The Design System remains the visual source of truth.

Feature screens should consume:

- AppColors
- AppTextStyles
- AppTheme
- Design Tokens
- Shared Components
- Feature-specific Components where appropriate

Feature screens must not create independent visual systems.

---

# Feature Sequencing Rationale

## Task #05 — Core Presentation Foundation

This comes next because the Domain, Data, and Application foundations are already in place, while the product still needs a stable Flutter presentation foundation to turn those capabilities into operational screens.

The goal is to establish the reusable presentation conventions before building the main feature workflows.

---

## Task #06 — Orders End-to-End

Orders are the central operational workflow of the system.

The existing Application layer already contains the main Order workflows:

- Create Order
- Store Order Items
- Move Stored Item
- Change Order Status
- Complete Order
- Cancel Order

Therefore, Orders are the natural first major vertical feature after the Presentation Foundation.

---

## Task #07 — Customers

Customers are directly connected to Orders and are a primary V1 module.

Customer management should be implemented after the basic Order flow so the integration between customer selection/creation and Orders can be built around a real workflow.

---

## Task #08 — Storage

Storage is a dedicated operational workflow for physical OrderItems.

It depends heavily on the OrderItem model and the storage workflows already established in the Application layer.

---

## Task #09 — Payments

Payments are a core operational transaction and are intentionally separate from Task #04.

The payment workflow should be implemented after the Order experience is established.

`AddPaymentUseCase` was intentionally not introduced during Task #04 and should not be added unless the approved scope for the payment task requires it.

---

## Task #10 — Expenses

Expenses represent the operational financial side outside Order payments.

Expense Categories remain part of the approved Settings direction rather than becoming an unnecessary top-level navigation module.

---

## Task #11 — Services & Pricing / Settings

Services and pricing are master/configuration data used by operational workflows.

They belong under Settings rather than the primary navigation.

This task should provide the approved management experience without expanding the V1 configuration scope.

---

## Task #12 — Dashboard

The Dashboard should come after the core transactional workflows because it is an operational overview of real system data.

It should not become a replacement for Orders, Storage, Customers, or Reports.

Approved Dashboard focus includes:

- Orders created today
- Orders Ready
- Items/orders requiring storage
- Outstanding payments
- Overdue orders
- Today's expected pickups
- Recent orders
- Quick actions

Approved Quick Actions:

- Add Order
- Add Customer
- Record Payment
- Add Expense

---

## Task #13 — Reports

Reports should be implemented after the underlying transaction workflows are stable.

Reporting values should be derived from authoritative transaction data rather than duplicated reporting tables.

Examples include:

```text
Sales       ← Orders
Payments    ← Payments
Expenses    ← Expenses
Remaining   ← Orders + Payments
Net Profit  ← Orders - Expenses
```

---

## Task #14 — Invoice / Receipt

Invoice/Receipt functionality depends on stable Order and Payment information.

Historical Order information must remain authoritative when displaying an invoice or receipt. Current master-data changes must not cause historical Orders to be recalculated.

---

## Task #15 — Offline / Sync Integration

Synchronization should be integrated after the major local workflows are stable.

The product is Offline-First, but Sync depends on stable entities, relationships, and transaction behavior.

The Sync scope includes the approved V1 business data such as:

- Customers
- Orders
- OrderItems
- Payments
- Expenses
- Storage
- Services & Pricing
- Approved configuration data

Advanced conflict-resolution workflows and multi-device administration remain outside V1.

---

## Task #16 — Full Integration / QA / Hardening

The final implementation phase should verify the complete system as one product.

It should include:

- End-to-end business workflows
- Business-rule verification
- Offline behavior
- Error states
- RTL
- Arabic UI
- Responsive/adaptive behavior
- Design System consistency
- Static analysis
- Automated tests
- Regression checks
- Final audit
- Release hardening

---

# Locked Business / Scope Constraints

The roadmap must not be used as a reason to reopen already-locked decisions.

Important current constraints include:

### Pricing

V1 supports only:

- Per Piece
- Fixed Price
- Per Square Meter

Per Kg is not part of the current V1 implementation.

### Pricing Validation

```text
unitPrice > Money.zero
```

Zero pricing is not allowed.

### Order Lifecycle

```text
Processing
    ↓
Ready
    ↓
Completed
```

`Processing → Ready` occurs automatically only when all physical OrderItems are stored.

Completion requires:

```text
Ready
+
Fully Paid
+
Customer Handover Confirmation
```

### Cancellation

Cancellation:

- Requires confirmation.
- Requires a reason.
- Preserves order history.
- Deactivates storage.
- Preserves payments.
- Does not automatically refund.

### Payments

Payment creation is not part of Task #04.

The payment workflow belongs to the appropriate later payment/POS scope.

### V1 Exclusions

Do not introduce features such as:

- AI Assistant
- Barcode/RFID
- Customer mobile app
- Driver app
- Multi-branch
- Multi-currency
- Roles/Permissions
- Loyalty
- Advanced notifications
- Refund workflow
- Advanced warehouse management
- Storage movement history
- Storage capacity management
- Advanced analytics
- Full accounting system
- Online payment integration

unless the V1 scope is explicitly changed and documented first.

---

# How to Use This Roadmap

Before starting each new Task:

1. Confirm the current Task from this roadmap.
2. Review its Goal.
3. Define its exact Scope.
4. Identify Business Rules.
5. Review Architecture and Dependencies.
6. Identify Open Decisions.
7. Create the implementation plan.
8. Write the Antigravity implementation prompt.
9. Implement only the approved scope.
10. Run tests and static analysis.
11. Audit the implementation against the source of truth.
12. Fix findings.
13. Perform final verification.
14. Mark the Task as Locked/Completed.
15. Update this roadmap if the status changes.
16. Move to the next Task.

---

# Change Policy

This roadmap is a planning document, not permission to expand scope.

If a future Task reveals a required change to:

- Product requirements
- Business rules
- Domain model
- Database
- Architecture
- Project structure
- Design System

the relevant documentation must be updated and the change explicitly approved before implementation.

The roadmap should then be updated to reflect the new approved direction.

---

# Current Position

```text
Task #01  Foundation / Architecture       ✅
Task #02  Database                         ✅
Task #03  Domain + Data Layer              ✅
Task #04  Application Workflows            ✅ LOCKED

Task #05  Core Presentation Foundation     ← CURRENT NEXT TASK

Task #06  Orders — End-to-End
Task #07  Customers
Task #08  Storage
Task #09  Payments
Task #10  Expenses
Task #11  Services & Pricing / Settings
Task #12  Dashboard
Task #13  Reports
Task #14  Invoice / Receipt
Task #15  Offline / Sync Integration
Task #16  Full Integration / QA / Hardening
```
