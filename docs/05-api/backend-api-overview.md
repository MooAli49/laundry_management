# Laundry Management System — Backend & API Overview

## 1. Document Purpose

This document defines the approved V1 backend and remote API direction for the Laundry Management System.

It connects the approved:

- Product requirements
- Business rules
- Domain model
- Architecture
- Database design
- Data Layer
- Synchronization strategy

to the remote backend contract.

The purpose is to define how the Flutter application communicates with the backend without coupling the Domain layer to backend implementation details.

The approved V1 backend platform is:

    Supabase

The approved server-side API layer is:

    Supabase Edge Functions

The approved Flutter networking stack is:

    Dio + Retrofit

This document does not redefine the Product scope.

---

# 2. Phase 05 Scope

Phase 05 defines:

- Remote API style
- API versioning
- Resource model
- Request/response conventions
- Error conventions
- Pagination contract
- Synchronization API
- Idempotency requirements
- Order number handling
- Master-data synchronization
- Expense synchronization
- Expense Category synchronization
- Payment synchronization
- Timestamp/version handling
- Financial representation
- Security requirements
- Backend responsibilities

The following remain implementation choices unless explicitly approved later:

- Exact backend database implementation
- Exact API protection mechanism
- Exact retry timing values
- Exact serialization details beyond the documented JSON contract
- Exact Edge Function organization

---

# 3. Relationship to the Existing Architecture

The approved V1 architecture is:

    Feature Presentation
        ↓
    Domain Repository Contract
        ↓
    Repository Implementation
        ↓
    Local Database / Remote API

The local database remains the operational source of truth for the application.

The Remote API exists for:

- Remote persistence
- Synchronization
- Recovery
- Future access from another authorized device

The UI must never call the Remote API directly.

---

# 4. Offline-first Requirement

The backend must never become a prerequisite for normal daily operation.

The approved flow remains:

    User Action
        ↓
    Domain Validation
        ↓
    Local Transaction
        ↓
    Sync Operation
        ↓
    UI Updated
        ↓
    Remote Synchronization

This preserves the approved Offline-first behavior.

If the backend is unavailable:

    Local Operation
        ↓
    Success

must remain possible for supported V1 operations.

---

# 5. API Style

V1 uses an HTTP API with JSON request and response bodies.

The API is resource-oriented and versioned.

Base structure:

    /api/v1/

The Flutter application depends only on the documented HTTP contract.

The Flutter application must not depend directly on Supabase-specific database implementation details.

---

# 6. API Versioning

All production API endpoints must be versioned.

V1:

    /api/v1/

A future incompatible API may use:

    /api/v2/

The server must not silently change the meaning of an existing V1 endpoint in a backward-incompatible way.

---

# 7. Backend Responsibilities

The backend is responsible for:

- Validating incoming requests
- Enforcing server-side uniqueness
- Persisting synchronized business data
- Preserving stable entity IDs
- Enforcing critical business/data invariants
- Processing idempotent operations
- Returning deterministic errors
- Supporting synchronization
- Maintaining server timestamps where required
- Returning enough information for synchronization reconciliation
- Protecting API access at the backend/infrastructure boundary
- Preserving historical transaction data
- Preserving financial precision

The backend must not assume that the client is always online.

---

# 8. Client Responsibilities

The Flutter client is responsible for:

- Local persistence
- Local business workflows
- Local search
- Local filtering
- Creating SyncOperations
- Retry scheduling
- Sync queue management
- Presenting synchronization state
- Sending API requests
- Applying remote synchronization results locally

The client must not assume that a successful HTTP request is the same thing as a successful local business operation.

---

# 9. Backend Data Model

The backend must be capable of representing the same logical business entities as the approved local model:

    Customer
    Order
    OrderItem
    Payment
    StorageRecord
    StorageLocation
    ItemType
    ItemDefinition
    Service
    ServiceItemType
    CarpetSize
    OrderItemCarpet
    BusinessSettings
    ExpenseCategory
    Expense

The backend may use a different physical schema, but it must preserve the same logical relationships and stable identifiers.

---

# 10. Stable Entity Identity

Synchronizable entities use stable UUID-based identifiers.

The same entity ID must remain unchanged across:

    Local Database
        ↓
    Sync Queue
        ↓
    Remote Backend

The backend must accept client-generated IDs for offline-created entities.

The backend must not replace a valid local entity ID with a different identity during normal synchronization.

This applies to:

- Customers
- Orders
- OrderItems
- Payments
- StorageRecords
- StorageLocations
- ItemTypes
- ItemDefinitions
- Services
- ServiceItemTypes
- CarpetSizes
- BusinessSettings
- ExpenseCategories
- Expenses

---

# 11. Human-readable Order Number

The approved Order Number format is:

    YYMMDD-XXX

Example:

    260825-001

The Order Number is separate from:

    Order.id

The Order Number is immutable after assignment.

---

# 12. Order Number Generation

The client may generate the Order Number locally because order creation must work offline.

The backend must enforce uniqueness.

The synchronization contract therefore treats:

    order.id

as the authoritative stable entity identity and:

    order.order_number

as a human-readable business identifier that must remain unique.

If a locally generated Order Number conflicts with an existing remote Order Number, synchronization must fail deterministically rather than silently changing the historical Order Number.

The V1 backend must not silently rename an already-issued Order Number.

---

# 13. Order Number Uniqueness Scope

Because V1 is single-branch:

    Order Number uniqueness
        ↓
    Global within the business dataset

There is no branch prefix or branch-specific numbering in V1.

---

# 14. Customer API

The API must support:

    GET    /api/v1/customers
    GET    /api/v1/customers/{id}
    POST   /api/v1/customers
    PATCH  /api/v1/customers/{id}

Customer search fields include:

- Name
- Phone

Normal operational search remains local.

The remote API does not need to reproduce every local-search optimization.

---

# 15. Customer Validation

The backend must enforce:

- Unique Customer ID
- Unique Customer Phone
- Required Customer Name
- Required Customer Phone
- Valid supported data format

The backend must return a deterministic validation error when a Customer Phone conflicts with an existing Customer.

---

# 16. Order API

The API must support:

    GET    /api/v1/orders
    GET    /api/v1/orders/{id}
    POST   /api/v1/orders
    PATCH  /api/v1/orders/{id}

The backend must preserve:

- Customer relationship
- Order Number
- Order Status
- Expected Pickup Date
- Delivery Request
- Financial totals
- Discount
- Notes
- Completion information
- Cancellation information
- Created/Updated timestamps

---

# 17. OrderItem API

OrderItems must remain independently identifiable.

The API must preserve:

    OrderItem.id

for every physical item.

The backend must not aggregate:

    Shirt × 5

into one physical OrderItem record.

A synchronization request may contain multiple OrderItems, but each physical item remains an independent entity.

---

# 18. Order Historical Data

The backend must preserve historical transaction values, including where applicable:

- Item Type name
- Item Definition name
- Service name
- Pricing Type
- Unit Price
- Calculated Total

The backend must not reconstruct historical OrderItem values from current master data.

---

# 19. Order Status Validation

The backend must accept only the approved V1 Order statuses:

- Processing
- Ready
- Completed
- Cancelled

No additional status values should be introduced without an approved Product/Domain change.

---

# 20. Order Financial Validation

The backend must validate:

- Monetary values use integer minor units
- Monetary values are non-negative where required
- Discount values are valid
- Order totals are internally consistent according to the approved contract

The backend must not use floating-point values for financial correctness.

---

# 21. Payment API

Payments are immutable financial transactions.

The API must support synchronization-safe payment creation.

The API must support:

    POST   /api/v1/payments

and retrieval where required:

    GET    /api/v1/payments/{id}

Payments may be queried by Order through an appropriate endpoint or query mechanism.

A Payment must contain:

- Payment ID
- Order ID
- Amount
- Payment Method
- Paid At
- Created At

---

# 22. Payment Immutability

Once a Payment has been successfully recorded, it must remain immutable in V1.

The backend must not allow normal updates that alter:

- Amount
- Order ID
- Payment Method
- Paid At

If a future correction/refund workflow is required, it must be explicitly introduced as a new Product/Domain decision.

---

# 23. Payment Idempotency

The backend must reject duplicate creation of the same Payment ID.

Retrying the same Payment operation must not create another Payment.

The Payment ID is the stable business entity identity.

---

# 24. Payment Validation

The backend must enforce:

- Valid Order ID
- Positive Payment amount
- Supported Payment Method
- Stable Payment ID
- No duplicate Payment ID
- Valid monetary representation

The backend should also enforce the approved rule that a payment must not exceed the current remaining amount where the API contract requires server-side payment validation.

---

# 25. Payment Methods

V1 supports:

- Cash
- InstaPay
- E-Wallet

No additional payment methods should be introduced without an approved Product change.

---

# 26. Storage API

Storage is associated with OrderItems.

The backend must preserve:

    OrderItem
        ↓
    StorageRecord
        ↓
    StorageLocation

The backend must enforce:

    Maximum 1 active StorageRecord
    per OrderItem

A storage move must not result in two active locations for the same physical item.

---

# 27. Storage Endpoints

The API should support operations conceptually equivalent to:

    GET    /api/v1/storage
    GET    /api/v1/storage/{orderItemId}
    POST   /api/v1/storage
    PATCH  /api/v1/storage/{id}

The exact endpoint organization may be finalized in the detailed API contract.

The important requirement is that the backend preserves the one-active-location invariant.

---

# 28. Storage Move

A Storage move must be processed atomically.

Conceptually:

    Deactivate Previous StorageRecord
        +
    Create / Activate New StorageRecord
        ↓
    Commit

The backend must never leave an OrderItem with two active locations.

---

# 29. Master Data API

The backend must support synchronization of:

    ItemTypes
    ItemDefinitions
    Services
    ServiceItemTypes
    CarpetSizes
    StorageLocations
    BusinessSettings
    ExpenseCategories

Master data uses active/inactive behavior where defined by the local model.

Historical references must remain valid after deactivation.

---

# 30. Item Type API

The API must support synchronization of ItemTypes.

Conceptually:

    GET    /api/v1/item-types
    GET    /api/v1/item-types/{id}
    POST   /api/v1/item-types
    PATCH  /api/v1/item-types/{id}

Inactive ItemTypes must not be selected for new transactions.

Historical OrderItems must remain valid.

---

# 31. Item Definition API

The API must support synchronization of ItemDefinitions.

Conceptually:

    GET    /api/v1/item-definitions
    GET    /api/v1/item-definitions/{id}
    POST   /api/v1/item-definitions
    PATCH  /api/v1/item-definitions/{id}

Historical OrderItems must preserve the relevant historical item-definition information.

---

# 32. Service API

The API must support synchronization of Services.

Conceptually:

    GET    /api/v1/services
    GET    /api/v1/services/{id}
    POST   /api/v1/services
    PATCH  /api/v1/services/{id}

Service configuration may include:

- Name
- Pricing Type
- Price
- Active state
- Supported Item Types

Changing a current Service configuration must not rewrite historical OrderItem snapshots.

---

# 33. Service/ItemType Compatibility API

The API must support synchronization of ServiceItemType relationships.

Conceptually:

    GET    /api/v1/service-item-types
    POST   /api/v1/service-item-types
    PATCH  /api/v1/service-item-types/{id}

The backend must prevent duplicate Service/ItemType compatibility relationships.

---

# 34. Carpet Size API

The API must support synchronization of CarpetSizes.

Conceptually:

    GET    /api/v1/carpet-sizes
    GET    /api/v1/carpet-sizes/{id}
    POST   /api/v1/carpet-sizes
    PATCH  /api/v1/carpet-sizes/{id}

Deactivation must preserve historical references.

---

# 35. Storage Location API

The API must support synchronization of StorageLocations.

Conceptually:

    GET    /api/v1/storage-locations
    GET    /api/v1/storage-locations/{id}
    POST   /api/v1/storage-locations
    PATCH  /api/v1/storage-locations/{id}

Inactive locations must not be available for new Storage operations.

Existing historical StorageRecords remain valid.

---

# 36. Business Settings API

The API must support synchronization of the remotely persistent BusinessSettings fields.

Conceptually:

    GET    /api/v1/business-settings
    PATCH  /api/v1/business-settings

V1 supports one BusinessSettings record.

The backend must preserve the single-business model.

---

# 37. Expense Category API

Expense Categories are manageable master data.

The API must support:

    GET    /api/v1/expense-categories
    GET    /api/v1/expense-categories/{id}
    POST   /api/v1/expense-categories
    PATCH  /api/v1/expense-categories/{id}

The API must support:

- Create Category
- Update Category
- Activate Category
- Deactivate Category
- Retrieve Category
- List Categories

---

# 38. Expense Category Data

An Expense Category must contain at minimum:

- ID
- Name
- Active state
- Created At
- Updated At

The exact API field naming should follow the project's JSON naming convention.

---

# 39. Expense Category Uniqueness

The backend must enforce uniqueness of Expense Category names within the business dataset according to the approved case/normalization rules.

Two active categories must not represent the same logical category name.

The backend should return a deterministic validation error when a duplicate category is attempted.

---

# 40. Expense Category Deactivation

Deactivating an Expense Category must be represented as an update:

    is_active = false

The API must not physically delete a category that is referenced by historical Expenses.

---

# 41. Expense Category Reactivation

Reactivation is represented as:

    is_active = true

However, normal synchronization and seed initialization must not automatically reactivate a category that the user intentionally deactivated.

User configuration must be preserved.

---

# 42. Expense Category Synchronization

Expense Categories are synchronizable master data.

A local change follows:

    Local ExpenseCategory
        ↓
    SyncOperation
        ↓
    Remote API
        ↓
    Success
        ↓
    Mark Synced

The same stable UUID must remain unchanged across local and remote persistence.

---

# 43. Initial Expense Categories

The initial V1 Expense Categories are:

    كهرباء
    مياه
    منظفات
    صيانة
    مستلزمات
    نقل
    أخرى

These are seeded locally during initial database setup.

They become normal manageable master-data records after initialization.

The API must be capable of persisting them when remote master-data synchronization is required.

---

# 44. "Other" Category

`أخرى` is a normal Expense Category.

It is not a special backend entity.

The backend only needs to store the Category identity and active state like any other category.

The custom Expense name is stored on the Expense itself.

---

# 45. Expense API

Expenses are independent financial transactions.

The API must support:

    GET    /api/v1/expenses
    GET    /api/v1/expenses/{id}
    POST   /api/v1/expenses
    PATCH  /api/v1/expenses/{id}

The API must support:

- Create Expense
- Update Expense
- Retrieve Expense
- List Expenses
- Filter Expenses by date
- Filter Expenses by category

---

# 46. Expense Data

An Expense must contain at minimum:

- Expense ID
- Amount
- Expense Category ID
- Date
- Custom Name where applicable
- Notes where applicable
- Created At
- Updated At

The exact JSON naming convention is defined by the detailed API contract.

---

# 47. Expense Independence

An Expense does not require:

- Order ID
- OrderItem ID
- Customer ID
- Payment ID

Expense is an independent operating-cost entity.

The backend must not force an Order relationship onto Expenses.

---

# 48. Expense and Payment Separation

The backend must treat:

    Payment

and:

    Expense

as separate resources and separate business concepts.

An Expense must never be represented as a negative Payment.

---

# 49. Expense Amount

Expense Amount must be positive.

The backend must reject:

    amount <= 0

for a normal Expense creation/update operation.

---

# 50. Expense Financial Representation

V1 financial values use integer minor units.

For EGP:

    1 EGP = 100 piastres

Example:

    100.50 EGP
        ↓
    10050

Expense amounts must use this representation.

The API must exchange exact integer values.

Floating-point financial values must not be used.

---

# 51. Expense Category Relationship

Every Expense must reference an existing Expense Category.

Conceptually:

    Expense
        ↓
    expense_category_id
        ↓
    ExpenseCategory

The backend must enforce the foreign-key relationship.

---

# 52. Inactive Expense Category

An inactive Expense Category must not be selectable for new Expenses.

However, an existing historical Expense may continue referencing an inactive category.

The backend must preserve the historical relationship.

---

# 53. Expense "Other" Validation

When an Expense references the `أخرى` category, the backend must require:

    custom_name

The custom name must not be empty or whitespace-only.

---

# 54. Expense Standard Category Validation

For standard categories such as:

    كهرباء
    مياه
    منظفات
    صيانة
    مستلزمات
    نقل

custom_name is not required.

The backend may accept a null/empty custom name for these categories according to the API contract.

---

# 55. Expense Date

Expense Date is a business date.

The API must preserve it as a date-only value.

The backend must not unintentionally convert:

    25 أغسطس 2026

into a different business date because of timezone conversion.

The API should use a date representation that clearly preserves date-only semantics.

---

# 56. Expense Timestamps

Expense:

    date

is different from:

    createdAt
    updatedAt

Financial reporting uses:

    Expense.date

not:

    createdAt

---

# 57. Expense Notes

Expense Notes are optional.

The backend may store notes as text.

Notes do not replace:

    Expense Category

or:

    Custom Name

when `أخرى` is selected.

---

# 58. Expense Update

Expense updates use:

    PATCH /api/v1/expenses/{id}

The update must preserve the same Expense ID.

Updating an Expense must not create a second Expense.

---

# 59. Expense Idempotency

Expense creation must be synchronization-safe.

If the same Expense creation request is retried:

    Same Expense ID
        +
    Same operation

must not create a duplicate Expense.

The backend must recognize the existing entity and return a deterministic idempotent result.

---

# 60. Expense Category Idempotency

Expense Category creation must also be safe against duplicate retries.

The same stable Category ID must not create duplicate remote records.

---

# 61. Expense Synchronization Dependency

An Expense depends on its Expense Category.

Conceptually:

    ExpenseCategory
        ↓
    Expense

If a newly created Expense Category is still pending synchronization:

    Create Expense

must wait until the required Category exists remotely if the backend requires the foreign-key relationship.

---

# 62. Expense Sync Ordering

The Sync Engine should process:

    Create ExpenseCategory
        ↓
    Create Expense

when the Expense references a locally created Category.

If the Category already exists remotely:

    Expense

may synchronize directly.

---

# 63. Expense Historical Preservation

The backend must preserve:

- Expense Amount
- Expense Category relationship
- Expense Date
- Custom Name
- Notes
- Created At
- Updated At

The backend must not reconstruct historical Expenses from current master-data configuration.

---

# 64. Expense Category Rename

If an Expense Category is renamed:

    ExpenseCategory.name

changes.

Historical Expenses continue referencing the same Category ID.

The backend must not create a new Category ID merely because the name was edited.

---

# 65. Expense Category Deactivation and History

If a category is deactivated:

    is_active = false

Historical Expenses referencing the category remain valid.

The backend must not cascade-delete the historical Expenses.

---

# 66. Financial Reporting API

Financial reporting is primarily calculated from synchronized transactional data.

The backend may provide aggregated reporting endpoints where required.

However, the local application must be capable of calculating the approved V1 Financial Report from local data while offline.

---

# 67. Financial Report Metrics

The approved V1 Financial Report includes:

- Total Sales
- Total Payments
- Total Operating Expenses
- Remaining Amount
- Discounts
- Payment Method totals
- Expense Category breakdown
- Net Profit

---

# 68. Net Profit

Net Profit is a derived value.

The approved formula is:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

Net Profit must not be persisted as an independent transactional entity.

---

# 69. Total Operating Expenses

Total Operating Expenses are calculated from:

    SUM(Expense.amount)

for the selected business date range.

The reporting date for Expenses is:

    Expense.date

---

# 70. Expense Category Breakdown

The Financial Report should support grouped Expense totals:

    Expense Category
        ↓
    Total Expense Amount

Example:

    منظفات
        300 EGP

    كهرباء
        200 EGP

    صيانة
        150 EGP

The backend may expose an aggregate endpoint, but the local Data Layer must also support the same calculation.

---

# 71. Reporting Period

The Financial Report supports:

- Today
- Yesterday
- Last 7 Days
- This Month
- Previous Month
- Custom Date Range

Custom Date Range uses date-only boundaries.

---

# 72. Financial Report and Payment Period

Payment totals are based on:

    Payment.paidAt

within the selected reporting period.

They must not simply be based on Order creation date.

---

# 73. Financial Report and Expense Period

Expense totals are based on:

    Expense.date

within the selected reporting period.

They must not use:

    Expense.createdAt

as the primary business reporting date.

---

# 74. Financial Report and Order Period

Order/Sales reporting must use the approved Order reporting date defined by the Product/Domain model.

The backend must not silently substitute a different timestamp.

---

# 75. No Financial Summary Entity

The backend must not introduce a required transactional entity such as:

    FinancialReport
    FinancialSummary
    NetProfitRecord

for V1.

Financial values remain derived from transactional data.

---

# 76. API Pagination

Collection endpoints support:

    page
    limit

Example:

    GET /api/v1/orders?page=1&limit=20

The response should include:

- Items
- Current page
- Page size
- Total count when efficiently available
- Has next page

The local database remains responsible for normal operational pagination while offline.

Remote pagination primarily supports:

- Synchronization
- Recovery
- Administrative access
- Future remote clients

---

# 77. Expense Pagination

Expense collection endpoints should support pagination where required.

Example:

    GET /api/v1/expenses?page=1&limit=20

Filtering may include:

    categoryId
    startDate
    endDate

The exact query parameter naming is finalized in the detailed API contract.

---

# 78. Timestamps

Synchronizable entities must expose:

    createdAt
    updatedAt

where those fields exist in the local Domain model.

Event-specific timestamps remain separate:

    completedAt
    cancelledAt
    paidAt

Expected Pickup remains date-only.

Expense Date remains date-only.

---

# 79. Versioning and Concurrency

The backend should expose an entity version or equivalent optimistic-concurrency value for synchronizable mutable records.

Recommended logical field:

    version

The exact physical implementation may be:

- Integer revision
- Server version
- Equivalent concurrency token

The purpose is to detect incompatible concurrent updates without introducing complex V1 conflict resolution.

---

# 80. Server Time

The backend should provide authoritative server timestamps for synchronization metadata.

The client may create local timestamps for offline operation.

Synchronization responses should provide the server's accepted timestamp/version where needed.

Client clock differences must not corrupt entity ordering or synchronization correctness.

---

# 81. Request Identity

Every request should carry enough information for the backend to identify:

- Request/correlation ID
- Idempotency key when the operation can be retried

The exact header names are defined in the detailed API contract.

---

# 82. Idempotency

Idempotency is required for retryable critical operations.

At minimum this applies to:

- Create Customer
- Create Order
- Create Payment
- Create StorageRecord
- Create Expense
- Create ExpenseCategory

The backend must ensure retrying the same logical operation does not create duplicate business data.

---

# 83. HTTP Methods

V1 uses:

    GET
    POST
    PATCH

DELETE should not be used for normal deletion of historical business records.

Where the Domain uses deactivation, the API should expose:

    PATCH

to change:

    is_active

rather than physically deleting the record.

---

# 84. Error Model

The API must return a consistent machine-readable error structure.

At minimum an error should identify:

    code
    message
    requestId

Optional fields may include:

    field
    details
    retryable

The Flutter Data Layer converts API errors into the application's approved error model.

Raw backend errors must not leak directly into Presentation.

---

# 85. Validation Errors

Validation errors should identify the affected field when practical.

Examples:

    Invalid Expense amount

    Expense Category is required

    Custom Name is required when category is أخرى

    Expense Category does not exist

    Expense Category is inactive

    Duplicate Expense Category name

    Duplicate Expense ID

The API should return deterministic error codes suitable for Data Layer handling.

---

# 86. Backend Validation Priority

The backend must independently validate critical invariants, including:

- Unique Customer phone
- Unique Order Number
- Unique entity IDs
- Valid foreign-key relationships
- Positive Payment amounts
- No duplicate Payment IDs
- Positive Expense amounts
- Valid Expense Category references
- Valid `أخرى` custom name
- At most one active StorageRecord per OrderItem
- Valid Order status values
- Valid monetary representation
- Valid date-only fields

Client validation remains useful for UX but is not a security boundary.

---

# 87. Security Requirements

The API must:

- Use HTTPS in production
- Validate all incoming data server-side
- Enforce backend access controls at the API boundary
- Never trust client-side validation alone
- Avoid returning secrets
- Avoid logging API protection credentials
- Avoid logging unnecessary customer/payment data
- Protect synchronization endpoints against unauthorized access
- Apply rate limiting where appropriate

The security mechanism must protect API access without introducing a V1 end-user authentication system.

---

# 88. Authentication Boundary

V1 does not implement end-user authentication.

The system does not include:

- User accounts
- Login
- Registration
- Password management
- Roles
- Permissions
- User sessions

Remote API access must still be protected at the backend/infrastructure level.

API protection is separate from end-user authentication.

Feature code must not implement or manage backend security credentials directly.

---

# 89. Single-user V1 Scope

V1 does not introduce:

- User roles
- Permissions
- Employee management
- Driver accounts
- Customer accounts

There is no V1 user-authentication or role/permission system.

---

# 90. No Business Logic in Flutter API Layer

The API client must not contain business workflows.

For example, it must not decide:

    Order is Ready

based on raw API data.

Domain/Application logic remains responsible for business interpretation.

The API client is infrastructure.

The same rule applies to:

    Net Profit
    Expense validation
    Order completion
    Storage readiness

where business interpretation belongs to the appropriate Domain/Application layer.

---

# 91. Synchronization API

The synchronization protocol is defined in:

    sync-strategy.md

The Remote API must support durable, idempotent synchronization.

The preferred V1 model is:

    Push local changes
        ↓
    Backend processes operations
        ↓
    Backend returns operation results
        ↓
    Client pulls remote changes
        ↓
    Client applies accepted changes locally

---

# 92. Push Synchronization

A local business operation follows:

    Local Transaction
        ↓
    SyncOperation
        ↓
    Remote API
        ↓
    Backend Validation
        ↓
    Persistence
        ↓
    Result

The result must identify whether the operation:

- Succeeded
- Was already applied idempotently
- Failed validation
- Failed due to conflict
- Is retryable

---

# 93. Pull Synchronization

The backend must support retrieving remote changes required by the synchronization strategy.

Conceptually:

    Remote Changes
        ↓
    Sync Response
        ↓
    Client Validation
        ↓
    Local Database

Remote changes must not blindly overwrite local pending changes.

---

# 94. Sync Conflict Scope

V1 does not implement:

- CRDTs
- Event sourcing
- Real-time collaboration
- Distributed locking
- Complex automatic merge algorithms

When a true synchronization conflict cannot be safely resolved automatically, the backend must return a deterministic conflict result.

The client keeps valid local data and marks the synchronization operation as requiring resolution.

---

# 95. Expense Sync Conflict

If an Expense has a pending local update and a conflicting remote update is received:

    Local Pending Expense Update
        +
    Remote Expense Update

the client must not silently discard the local change.

The conflict must follow the approved V1 synchronization strategy.

---

# 96. Expense Category Sync Conflict

If an Expense Category has a pending local update and a conflicting remote update is received:

    Local Pending Category Update
        +
    Remote Category Update

the client must not silently overwrite the pending local change.

The synchronization system should preserve enough metadata to identify the conflict.

---

# 97. Remote Master Data

The backend must preserve master data changes independently from transaction snapshots.

Example:

    Service price = 100
        ↓
    Historical OrderItem.unitPrice = 100
        ↓
    Service price becomes 120

The historical OrderItem remains:

    100

The same principle applies to:

    Item Types
    Item Definitions
    Expense Categories

Changing master data must not rewrite historical transaction values.

---

# 98. Expense Historical Independence

An Expense stores its own transaction information.

Changing the current Expense Category configuration must not modify:

- Expense amount
- Expense date
- Expense custom name
- Expense notes

The Expense remains a historical transaction.

---

# 99. Seed Data and Backend

Seeded Expense Categories are initialized locally according to:

    seed-data.md

Seed initialization must not create fake:

    Expenses
    Payments
    Orders
    Customers

The backend must not assume that an initial local database contains business transactions.

---

# 100. Backend Does Not Redefine Product Scope

The backend must not introduce V1 entities for:

- Branches
- Employees
- Roles
- Permissions
- Drivers
- Vehicles
- Delivery Routes
- Refunds
- Loyalty
- AI features
- Processing stages
- Recurring Expenses
- Expense Approval
- Budget Management
- Supplier Management
- Accounts Payable
- Advanced Accounting

unless Product/Domain scope is explicitly changed.

---

# 101. API Resource Summary

The approved V1 API resource areas are:

    Customers
    Orders
    OrderItems
    Payments
    Storage
    StorageLocations
    ItemTypes
    ItemDefinitions
    Services
    ServiceItemTypes
    CarpetSizes
    BusinessSettings
    ExpenseCategories
    Expenses

Financial reporting may use derived endpoints or local calculations.

---

# 102. API Endpoint Summary

The conceptual V1 endpoints include:

    /api/v1/customers
    /api/v1/orders
    /api/v1/payments
    /api/v1/storage
    /api/v1/storage-locations
    /api/v1/item-types
    /api/v1/item-definitions
    /api/v1/services
    /api/v1/service-item-types
    /api/v1/carpet-sizes
    /api/v1/business-settings
    /api/v1/expense-categories
    /api/v1/expenses

The exact synchronization endpoints are defined by the detailed synchronization API contract.

---

# 103. API and Local-first Principle

The Remote API must not be used as a mandatory read source for normal application screens.

Preferred:

    UI
        ↓
    Cubit
        ↓
    Repository
        ↓
    Local Database

Synchronization remains:

    Local Database
        ↓
    Sync Engine
        ↓
    Remote API

This is especially important for:

- Orders
- Customers
- Storage
- Payments
- Expenses
- Financial Reports

---

# 104. API and Financial Precision

All monetary API fields must use integer minor units.

Example:

    amount = 15050

represents:

    150.50 EGP

The API must not return:

    150.50

as a floating-point financial value where exact monetary representation is required.

---

# 105. API and Date Precision

The API must distinguish:

    Date Only

from:

    Date + Time

Date-only values include:

    Expected Pickup Date
    Expense Date

Date/time values include:

    Paid At
    Created At
    Updated At
    Completed At
    Cancelled At

The backend must preserve these semantic differences.

---

# 106. API and Historical Data

Historical transactions must remain self-contained enough to remain accurate after master-data changes.

Examples:

    OrderItem price snapshot
    OrderItem service snapshot
    Carpet dimensions
    Expense amount
    Expense date
    Expense custom name

Current configuration must never be used to rewrite historical financial transactions.

---

# 107. API and Local Error Handling

If the backend rejects a synchronization operation:

    Valid Local Data
        ↓
    Remains Locally Valid

The client must preserve the local business record and synchronization failure information.

The backend must return enough information for the client to determine whether the operation is:

- Retryable
- Permanently invalid
- Conflicting
- Already applied

---

# 108. API and Retry

Retryable failures may use:

    Exponential Backoff
        +
    Maximum Retry Count
        +
    Permanent Failure State

The exact retry timing and maximum count remain implementation decisions for the final synchronization implementation.

---

# 109. API and Duplicate Prevention

The backend must protect against duplicate creation caused by:

- Network retries
- Timeout after server acceptance
- Client retry
- Application restart
- Sync worker retry

Stable entity IDs and idempotent operations are the primary mechanisms.

---

# 110. API and Data Integrity

The backend is an additional integrity boundary.

The backend must not assume that the Flutter application always validates correctly.

Critical business constraints must be enforced server-side where practical.

Examples:

    Unique Customer Phone
    Unique Order Number
    Unique Entity ID
    Valid Foreign Keys
    Positive Financial Amounts
    One Active Storage Location
    Valid Expense Category
    Valid Expense Amount

---

# 111. API and Expense Financial Integrity

The backend must reject an Expense when:

    amount <= 0

The backend must reject an Expense when:

    expense_category_id
    does not reference an existing Category

The backend must reject an Expense using an inactive Category for a new transaction.

The backend must reject:

    category = أخرى
    +
    missing custom_name

---

# 112. API and Expense Reporting

The backend may provide a financial reporting endpoint if needed for remote reporting.

However, the local application must be able to calculate:

    Total Operating Expenses
    Expense Category Breakdown
    Net Profit

from synchronized local data.

The backend must not become a prerequisite for viewing Financial Reports.

---

# 113. API and Net Profit

If a remote aggregate endpoint exposes Net Profit, it must use the same approved formula:

    Net Profit
        =
    Total Sales
        -
    Total Operating Expenses

The backend must not subtract Payments from Net Profit.

The backend must not subtract Outstanding Amounts from Net Profit.

---

# 114. API and Outstanding Amount

Outstanding Amount is derived from:

    Order Total
        -
    Total Payments

It is not an Expense.

The API must keep these concepts separate.

---

# 115. API and Discounts

Discounts are part of Order financial data.

Historical Order totals must preserve the effect of discounts.

The backend must not double-subtract discounts when calculating financial summaries.

---

# 116. API and No Full Accounting

The backend Financial Report is an operational financial summary.

It does not implement:

- Full accounting
- Accounts payable
- Supplier accounting
- Expense approval
- Budgeting
- Recurring Expenses
- General ledger
- Tax accounting beyond approved V1 tax configuration

These remain outside V1 unless explicitly approved later.

---

# 117. API Documentation Rule

This overview defines the backend direction.

The exact request/response schemas, endpoint payloads, HTTP status codes, synchronization payload structure, and headers should be defined in the detailed API contract.

This document must remain the high-level source of truth for backend architecture.

---

# 118. API Change Rule

Any new API resource must first be supported by an approved Product/Domain requirement.

The implementation must not introduce a backend resource simply because it is technically convenient.

Any new API resource must be reflected in:

- Product documentation
- Domain documentation where applicable
- Database documentation where applicable
- Synchronization documentation where applicable
- This API overview

---

# 119. AI Backend Implementation Rules

AI coding tools implementing the backend/API must:

1. Read Product requirements.
2. Read Business Rules.
3. Read Domain documentation.
4. Read Database documentation.
5. Read Data Layer documentation.
6. Read Synchronization strategy.
7. Follow this API overview.
8. Preserve stable UUID identities.
9. Preserve Offline-first behavior.
10. Implement idempotent critical operations.
11. Use integer minor units for financial values.
12. Preserve historical transaction values.
13. Keep Payments separate from Expenses.
14. Implement Expense Categories as manageable master data.
15. Implement Expenses as independent transactions.
16. Validate `أخرى` custom names.
17. Preserve Expense Date as date-only.
18. Support Expense synchronization.
19. Avoid introducing authentication in V1.
20. Avoid introducing unsupported Product features.
21. Avoid introducing new backend entities without approval.
22. Avoid silently changing existing API semantics.
23. Preserve backward compatibility within V1.
24. Return deterministic machine-readable errors.
25. Enforce critical constraints server-side.

---

# 120. Final Backend Principles

The V1 backend contract follows:

    HTTP + JSON
        +
    Versioned API
        +
    Stable UUID identities
        +
    Local-first client
        +
    Durable synchronization
        +
    Idempotent critical operations
        +
    Immutable payments
        +
    Independent expenses
        +
    Manageable expense categories
        +
    Historical transaction snapshots
        +
    Integer minor-unit financial values
        +
    Date-only business dates
        +
    Server-side integrity
        +
    Simple V1 conflict handling
        +
    No unnecessary enterprise complexity

Backend platform:

    Supabase

Server-side API layer:

    Supabase Edge Functions

Flutter networking:

    Dio + Retrofit

End-user authentication:

    Not applicable in V1

Financial representation:

    Integer minor units

    1 EGP = 100 piastres

Retry strategy:

    Exponential Backoff
        +
    Maximum Retry Count
        +
    Permanent Failure State

The exact maximum retry count and retry timing values remain an implementation decision for the final synchronization strategy.

The backend must support the approved V1 product without redefining or expanding the product scope.

The most important financial separation is:

    Payment
        ↓
    Money received from customer

    Expense
        ↓
    Money spent by business

    Outstanding Amount
        ↓
    Customer money still due

    Net Profit
        ↓
    Total Sales - Total Operating Expenses

These concepts must remain separate throughout the API, database, synchronization, and reporting layers.