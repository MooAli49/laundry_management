# Networking Implementation

## 1. Purpose

This document defines the implementation contract for the remote networking layer of the Laundry Management System.

The approved networking technology for the Flutter application is:

Dio + Retrofit

Networking is part of the Data/Core infrastructure boundary.

The Presentation Layer must never communicate with the network directly.

The current V1 implementation is local-first. Backend networking and synchronization are intentionally deferred until the local Flutter implementation is complete.

Therefore, this document defines the future networking implementation contract without requiring networking to be implemented prematurely.

---

## 2. Current Implementation Status

Networking is:

Approved for the final V1 architecture.

Deferred for the current local implementation phase.

The current implementation must continue to work without:

- Internet access
- Dio
- Retrofit
- Remote API availability
- Synchronization

The local database remains the operational source of truth during normal application operation.

The approved operational flow is:

User Action
↓
Cubit
↓
Repository
↓
Local Database
↓
UI Updated
↓
Synchronization
↓
Remote API

The user must not be blocked waiting for the backend during normal local operations.

---

## 3. Approved Networking Stack

The Flutter remote networking stack is:

- Dio
- Retrofit

Dio is responsible for the underlying HTTP client infrastructure.

Retrofit is responsible for defining typed API interfaces and endpoint contracts.

Do not introduce another HTTP client alongside Dio.

Do not introduce another API client framework alongside Retrofit.

The project should maintain one centralized networking infrastructure.

---

## 4. Networking Boundary

Networking belongs below the Repository boundary.

The approved architecture is:

Presentation
↓
Cubit
↓
Repository
↓
Local Data / Remote Data
↓
Dio + Retrofit
↓
Backend API

The Domain layer must not know that Dio or Retrofit exists.

The Presentation layer must not know that Dio or Retrofit exists.

Feature Cubits must never perform HTTP requests directly.

---

## 5. Centralized API Client

The application should have one centralized API networking configuration.

The centralized network infrastructure is responsible for concerns such as:

- Base URL
- HTTP client configuration
- Default headers
- Timeouts
- Interceptors
- Request configuration
- Response handling
- Network-level errors
- Serialization support
- Backend protection configuration when applicable

Feature repositories must use this centralized infrastructure.

Do not create independent Dio clients inside individual features.

---

## 6. Dio Responsibilities

Dio should be used for low-level HTTP infrastructure.

Dio is responsible for:

- Creating HTTP requests
- Sending HTTP requests
- Receiving HTTP responses
- HTTP status handling
- Request/response interceptors
- Timeout configuration
- Connection errors
- Transport-level failures
- Request metadata

Dio must not contain business workflows.

Dio must not decide business states such as:

- Order is Ready
- Order is Completed
- Payment is valid
- Expense is valid
- Storage is complete
- Profit has been calculated

Those concerns belong to the appropriate application/domain/data responsibilities.

---

## 7. Retrofit Responsibilities

Retrofit should provide typed endpoint definitions.

Retrofit API interfaces should describe:

- HTTP method
- Endpoint path
- Request parameters
- Request body
- Response type
- Required headers where applicable

Retrofit endpoint definitions should remain focused on transport/API communication.

They must not contain business workflows.

---

## 8. HTTP Methods

The V1 API uses:

- GET
- POST
- PATCH

DELETE should not be used for normal deletion of historical business records.

Where the domain uses deactivation, the API should use PATCH to update the relevant active/inactive state.

The Flutter networking layer must follow the backend API contract rather than inventing alternative HTTP semantics.

---

## 9. API Base URL

The API base URL must be centrally configured.

Do not hardcode API URLs inside:

- Cubits
- Screens
- Widgets
- Repositories
- Individual Retrofit methods

Environment-specific configuration should be handled centrally.

The application should be able to distinguish development/testing/production configuration without modifying feature code.

---

## 10. API Versioning

The backend API is versioned.

The networking layer must use the approved API version consistently.

Do not mix different API versions across feature implementations without an explicit compatibility requirement.

If the API version changes:

1. Update the centralized configuration.
2. Verify endpoint compatibility.
3. Update affected API contracts.
4. Update affected remote models.
5. Update tests.

Do not silently change API semantics.

---

## 11. Request Headers

Common request headers should be configured centrally when they apply globally.

Examples may include:

- Content-Type
- Accept
- API/version headers
- Request identifiers where required

Feature endpoints should only define headers that are genuinely endpoint-specific.

Do not duplicate global headers across every endpoint.

---

## 12. Timeouts

Network timeouts must be configured centrally.

The implementation should distinguish between appropriate timeout categories when required, such as:

- Connection timeout
- Send timeout
- Receive timeout

Timeout values should be chosen as an implementation decision when the networking layer is implemented.

Do not add arbitrary timeout values to individual requests without a specific requirement.

---

## 13. Interceptors

Dio interceptors may be used for centralized infrastructure concerns.

Appropriate interceptor responsibilities include:

- Request logging in development
- Response logging in development
- Request metadata
- Common headers
- Error normalization support
- Backend protection mechanisms when approved

Interceptors must not contain feature business logic.

Do not implement:

Order workflows

Payment workflows

Expense workflows

Storage workflows

inside interceptors.

---

## 14. Logging

Network logging must be safe.

Development logging may include useful request/response information.

Production logging must avoid exposing:

- Secrets
- API protection credentials
- Unnecessary customer data
- Payment-sensitive information
- Personal data that is not required for diagnostics

The exact logging package remains a separate technical decision if not already finalized.

Do not introduce a logging package solely for networking unless required by the approved implementation.

---

## 15. Authentication Boundary

V1 does not implement an end-user authentication system.

The application does not include:

- User accounts
- Login
- Registration
- Password management
- Roles
- Permissions
- User sessions

Therefore, feature networking code must not implement a user authentication workflow.

Remote API access may still require infrastructure-level protection.

Any such protection must be handled centrally and must not expose credentials through feature code.

---

## 16. Security

Production API communication must use HTTPS.

The client must not assume that client-side validation is sufficient.

The backend remains responsible for enforcing critical integrity rules.

The networking layer must:

- Use secure transport
- Avoid exposing secrets
- Avoid logging credentials
- Avoid logging unnecessary sensitive information
- Handle backend authorization/protection mechanisms centrally
- Preserve machine-readable backend errors

Do not embed secrets directly inside feature source files.

---

## 17. Serialization

Remote API data must use structured serialization.

The selected serialization/code-generation approach must remain consistent with the project's approved implementation.

Large amounts of duplicated manual JSON parsing should be avoided.

Remote models should provide predictable conversion between:

JSON
↔
Remote Model

The networking layer must not silently convert remote data into unrelated business semantics.

---

## 18. Remote Models

Remote API models belong to the Data Layer.

They should represent the API contract.

A remote model may contain:

- API fields
- JSON serialization
- Request payload structure
- Response structure

Remote models should not become accidental replacements for Domain entities.

The Repository/Data Layer is responsible for translating data between infrastructure representations and the rest of the application according to the approved architecture.

---

## 19. No Mapper Layer

The project does not use a dedicated Mapper layer in V1.

Do not introduce:

RemoteModelMapper

EntityMapper

GenericMapper

or another dedicated mapping architecture automatically.

Simple conversions should remain in an appropriate existing location according to the project's architecture.

Possible locations include:

- Repository
- Data Source
- Model
- fromJson
- toJson

Conversion logic should have one clear owner and must not be duplicated unnecessarily.

---

## 20. Repository Boundary

Repositories are responsible for hiding whether data comes from:

- Local storage
- Remote API
- Synchronization infrastructure

Presentation should not need to know which source is being used.

For example:

OrdersCubit
↓
OrdersRepository
↓
Local database

and later:

OrdersRepository
↓
Local database
+
Remote synchronization

The Cubit should not change simply because remote synchronization is introduced.

---

## 21. Offline-First Networking

Networking must support the application's offline-first architecture.

The API is not the normal operational source of truth for screen rendering.

Normal reads should primarily use local data.

Normal writes should be committed locally first.

Remote synchronization occurs afterward.

If the network is unavailable:

- Local data remains valid.
- Local operations remain usable.
- Pending synchronization remains pending.
- The UI must not treat a valid local operation as failed merely because synchronization is unavailable.

---

## 22. Remote Reads

Remote reads should not replace normal local reads unnecessarily.

The application should not make an API request for every screen load.

The normal operational model is:

Local Database
↓
UI

Remote API is primarily involved in:

- Synchronization
- Initial synchronization where required
- Explicit remote operations defined by the final backend contract

The exact remote-read strategy must follow the approved sync architecture.

---

## 23. Remote Writes

Remote writes must respect the local-first architecture.

The preferred V1 flow is:

User Action
↓
Cubit
↓
Repository
↓
Local Transaction
↓
Local State Updated
↓
Sync Operation Created
↓
Later Remote API Request

The user should not have to wait for the remote request before seeing the local result.

---

## 24. Synchronization Boundary

Synchronization is a Data Layer responsibility.

Conceptually:

Local Database
↓
Pending Sync Operations
↓
Sync Engine
↓
Remote API
↓
Backend

The networking layer only handles communication with the remote API.

It must not become responsible for deciding:

- Which local operation should sync
- When synchronization should happen
- How conflicts should be resolved
- Which business entity is considered authoritative

Those responsibilities belong to the synchronization architecture.

---

## 25. Sync Queue Interaction

The remote networking layer must be capable of receiving synchronization requests generated by the Sync Layer.

A synchronization operation may contain information such as:

- Operation ID
- Entity type
- Entity ID
- Operation type
- Payload/reference
- Created time
- Retry information
- Sync status

The networking layer should not own the persistent sync queue.

The Sync Layer owns queue management.

The network client executes the required remote request.

---

## 26. Idempotency

Critical remote operations must be idempotent.

The backend must support retrying the same logical operation without creating duplicate business data.

This is particularly important for operations such as:

- Create Customer
- Create Order
- Create Payment
- Create StorageRecord
- Create Expense
- Create ExpenseCategory

The networking layer must preserve the identifiers/idempotency information required by the backend contract.

The client must not generate a different logical operation merely because the previous request timed out.

---

## 27. Stable IDs

The system uses stable UUID-based entity identities.

Networking code must preserve these IDs.

Do not replace stable entity IDs with temporary network-generated IDs.

Local and remote representations must be able to refer to the same logical entity consistently.

---

## 28. Financial Values

Financial values are represented using integer minor units.

The approved representation is:

1 EGP = 100 piastres

Networking code must preserve this representation.

Do not use floating-point values for monetary persistence or synchronization.

Do not silently convert:

1000 piastres

into a floating-point EGP value inside transport models unless an explicit API contract requires it.

The API contract must remain consistent with the approved financial representation.

---

## 29. Dates

Business date-only values must remain date-only where the API contract defines them as such.

Do not automatically convert a date-only business value into a timestamp containing an unintended timezone.

This is especially important for:

- Expense Date
- Business dates
- Other date-only domain concepts

Timestamp values and date-only values must remain semantically distinct.

---

## 30. API Error Model

The backend must return a consistent machine-readable error structure.

At minimum, an error should identify:

- code
- message
- requestId

Optional fields may include:

- field
- details
- retryable

The Flutter Data Layer must convert these backend errors into the application's approved error model.

Raw backend errors must never leak directly into Presentation.

---

## 31. HTTP Error Handling

The network layer should distinguish between categories of failure.

Examples include:

- Connectivity failure
- Timeout
- Server error
- Client validation error
- Unauthorized/protected API access
- Not found
- Conflict
- Unexpected response
- Serialization failure

The exact application error hierarchy should follow the approved error strategy.

Do not expose raw Dio exceptions directly to Cubits.

---

## 32. Validation Errors

Backend validation errors should remain machine-readable.

Where the backend identifies a specific field, the Data Layer should preserve that information so the appropriate presentation layer can provide meaningful feedback.

Examples include:

- Invalid Expense amount
- Expense Category is required
- Custom Name is required when category is أخرى
- Expense Category does not exist
- Expense Category is inactive
- Duplicate Expense Category name
- Duplicate Expense ID

The client may perform validation for UX, but backend validation remains authoritative for server-side integrity.

---

## 33. Retry Behavior

Networking retries must be designed together with synchronization.

The approved future retry direction is:

Exponential Backoff
+
Maximum Retry Count
+
Permanent Failure State

The exact retry timing and maximum count remain implementation decisions for the final synchronization strategy.

Do not invent final retry constants during the local-only implementation phase.

Do not retry every error automatically.

Permanent validation errors should not be treated like temporary connectivity failures.

---

## 34. Retry Safety

A retry must not accidentally create duplicate business data.

Before retrying a critical operation, the implementation must preserve the same logical operation identity and required idempotency information.

The network layer must not generate a new business identity simply because a request is retried.

---

## 35. Backend Compatibility

The Flutter networking implementation must follow the backend API contract.

Do not silently:

- Rename API fields
- Change HTTP methods
- Change endpoint semantics
- Change identifier meaning
- Change financial representation
- Change date semantics
- Remove required fields

If the backend contract changes, the affected technical documentation and implementation must be updated intentionally.

---

## 36. Endpoint Organization

Retrofit endpoints should be organized by meaningful backend resource or feature.

Examples may include:

- Customers API
- Orders API
- Payments API
- Storage API
- Expenses API
- Expense Categories API

Avoid creating one massive API interface containing unrelated endpoints if the interface becomes difficult to maintain.

At the same time, do not split every endpoint into a separate interface without a meaningful reason.

The organization should remain consistent with the feature-based architecture.

---

## 37. API Client and Feature Boundaries

Feature code should not configure:

- Base URL
- Dio instance
- Global headers
- Global interceptors
- Global timeout policies

These belong to centralized network infrastructure.

Feature API definitions may define endpoint-specific details.

---

## 38. Testing Networking

Networking must be testable independently of the UI.

Tests should cover:

- Successful responses
- HTTP errors
- Serialization
- Validation errors
- Timeout behavior
- Connectivity failures
- Retry behavior where implemented
- Idempotency-related request data
- Date serialization
- Financial value serialization

Do not require a live production backend for normal unit tests.

---

## 39. Repository Testing

Repository tests should verify the interaction between:

Repository
→
Local Data
→
Remote Data

according to the final synchronization strategy.

The Repository should not expose raw Dio/Retrofit exceptions.

It should expose the application's approved result/error model.

---

## 40. Mocking and Fakes

Network dependencies must be replaceable in tests.

A repository test should be able to use:

- Fake Remote Data Source
- Mock Retrofit API
- Fake HTTP layer

without requiring an actual backend.

The exact mocking technology should follow the project's testing standards.

Do not introduce a mocking package solely for one test unless necessary.

---

## 41. No Network Calls from Presentation

The following are prohibited:

Screen → Dio

Screen → Retrofit

Widget → Dio

Widget → Retrofit

Cubit → Dio

Cubit → Retrofit

The correct direction is:

Cubit
↓
Repository
↓
Remote Data Source
↓
Retrofit
↓
Dio

---

## 42. No Business Logic in API Client

The API client must remain infrastructure.

It must not calculate:

- Net Profit
- Outstanding Amount
- Order completion
- Storage readiness
- Expense business validity
- Customer business status

It must not decide business workflows based on raw API responses.

The API client communicates data.

Business interpretation belongs elsewhere.

---

## 43. No Direct Backend Dependency in Domain

Domain entities and domain rules must not depend on:

- Dio
- Retrofit
- HTTP
- JSON transport details
- API response classes

The Domain must remain independent from networking technology.

---

## 44. No Premature Networking Implementation

During the current local Flutter implementation phase:

Do not:

- Add Dio merely because it is approved for future use.
- Add Retrofit merely because it is approved for future use.
- Create API endpoints that are not currently required.
- Implement authentication.
- Implement synchronization.
- Implement remote conflict resolution.
- Replace local operations with network calls.

The goal is to complete the local operational implementation first.

---

## 45. Deferred Synchronization Complexity

The following remain outside the current implementation scope:

- Real-time synchronization
- Complex background synchronization
- Advanced multi-device conflict resolution
- Distributed locking
- CRDTs
- Event sourcing
- Advanced caching architecture

The networking implementation must not introduce these concepts prematurely.

---

## 46. Future Supabase Integration

The approved backend platform is:

Supabase

The server-side API layer is:

Supabase Edge Functions

The Flutter networking layer is:

Dio + Retrofit

The Flutter client should communicate through the approved API boundary rather than coupling feature code directly to backend-specific infrastructure.

Do not allow individual features to directly depend on Supabase SDK behavior when the approved architecture requires the centralized API boundary.

---

## 47. API Request Flow

The final remote request flow should conceptually be:

Cubit
↓
Repository
↓
Remote Data Source
↓
Retrofit API
↓
Dio
↓
HTTP
↓
Supabase Edge Function
↓
Backend

The response flows back through:

Backend
↓
HTTP
↓
Dio
↓
Retrofit
↓
Remote Data Source
↓
Repository
↓
Cubit
↓
UI

During normal offline-first operation, local persistence remains the primary operational path.

---

## 48. Dependency Injection

Networking dependencies must be registered through the centralized `get_it` configuration.

Expected future registrations may include:

- Dio client
- Retrofit API clients
- Remote data sources
- Repositories

The exact registration should follow `dependency-injection.md`.

Feature code must not instantiate its own Dio client.

---

## 49. Environment Configuration

Networking configuration should support environment-specific values without modifying feature implementation.

Potential configuration values include:

- API base URL
- API version
- Network timeout values
- Environment flags

Sensitive values must not be hardcoded into source code.

The final environment/configuration mechanism should remain consistent with the project's approved implementation.

---

## 50. API Contract Changes

If an API endpoint changes:

1. Update the API contract documentation.
2. Update Retrofit endpoint definitions.
3. Update remote models.
4. Update affected repository logic.
5. Update tests.
6. Verify synchronization compatibility.
7. Verify backward compatibility where required.

Do not make undocumented API changes simply to make client implementation easier.

---

## 51. AI Coding Agent Rules

When implementing networking, an AI coding agent must:

- Use Dio.
- Use Retrofit.
- Use the centralized network infrastructure.
- Follow the Repository boundary.
- Keep networking inside Data/Core infrastructure.
- Preserve offline-first behavior.
- Preserve stable IDs.
- Preserve integer minor-unit financial values.
- Preserve date-only semantics.
- Use structured serialization.
- Preserve machine-readable API errors.
- Support idempotent critical operations.
- Follow the backend API contract.
- Use centralized dependency injection.
- Add appropriate tests.
- Avoid exposing raw network exceptions to Presentation.

The coding agent must not:

- Introduce another HTTP client.
- Introduce another API framework.
- Call Dio from Cubits.
- Call Retrofit from Cubits.
- Call Dio from Screens.
- Call Retrofit from Screens.
- Put business logic inside interceptors.
- Put business workflows inside API clients.
- Introduce a Mapper layer automatically.
- Introduce Use Cases automatically.
- Implement authentication in V1.
- Implement networking before the project reaches the networking phase.
- Invent endpoint semantics.
- Invent retry constants without approval.
- Add real-time synchronization.
- Add advanced conflict resolution.
- Replace local-first behavior with API-first behavior.

---

## 52. Definition of Done

Networking implementation is considered complete when:

- Dio is configured centrally.
- Retrofit API clients are configured centrally.
- One centralized network infrastructure exists.
- API base URL is centrally configurable.
- HTTP configuration is centralized.
- Timeouts are configured appropriately.
- Interceptors are centralized and limited to infrastructure responsibilities.
- Remote models serialize and deserialize correctly.
- API endpoints follow the approved backend contract.
- Repositories access remote data through the appropriate Data Layer boundary.
- Presentation does not directly access networking.
- Raw network exceptions do not leak into Presentation.
- API errors are converted into the approved application error model.
- Critical operations preserve idempotency.
- Stable UUIDs are preserved.
- Financial values use integer minor units.
- Date-only values remain date-only.
- Tests cover important network behavior.
- Offline-first behavior remains intact.
- Networking does not become a prerequisite for normal local operation.

---

## 53. Final Architecture

The final architecture for remote networking is:

Presentation
↓
Cubit
↓
Repository
↓
Remote Data Source
↓
Retrofit
↓
Dio
↓
HTTP API
↓
Supabase Edge Functions

For normal V1 operation:

Presentation
↓
Cubit
↓
Repository
↓
Local Database
↓
UI Updated
↓
Sync Queue
↓
Remote Data Source
↓
Retrofit
↓
Dio
↓
Backend

The most important rule is:

Networking is an infrastructure concern, not a Presentation concern.

The local database remains the operational source of truth.

Remote networking exists to support synchronization and the approved backend contract without making the application dependent on continuous internet connectivity.