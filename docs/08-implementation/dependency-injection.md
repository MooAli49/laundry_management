# Dependency Injection Implementation

## 1. Purpose

This document defines the implementation rules for Dependency Injection (DI) in the Laundry Management System.

The project uses `get_it` as the approved dependency injection mechanism.

The purpose of this document is to make dependency registration predictable, testable, and consistent across the application while preventing individual features or coding agents from introducing alternative dependency-management patterns.

This document defines:

- DI package
- Dependency registration
- Registration lifecycle
- Dependency graph
- Initialization order
- Repository registration
- Data-source registration
- DAO registration
- Cubit registration
- Application startup
- Testing and dependency replacement
- Future networking and synchronization dependencies
- DI boundaries
- Prohibited patterns

This document does not define business rules, database schema, repository behavior, or presentation behavior.

Those responsibilities remain in their respective documentation.

---

## 2. Approved DI Solution

The project uses:

`get_it`

as the dependency injection mechanism.

Do not introduce another dependency injection package.

The application should have one application-level `GetIt` instance.

The preferred access pattern is through the configured application service locator rather than creating additional `GetIt` instances.

---

## 3. Core Dependency Graph

The approved dependency direction is:

Presentation
↓
Cubit
↓
Repository
↓
Data Source / DAO
↓
Database / Infrastructure

The dependency graph must respect this direction.

A higher layer may depend on a lower layer through the approved abstraction.

A lower layer must not depend on a higher presentation layer.

Examples:

Valid:

OrdersCubit → OrdersRepository

OrdersRepository → OrdersDao

OrdersDao → AppDatabase

Invalid:

OrdersRepository → OrdersCubit

OrdersDao → OrdersScreen

AppDatabase → OrdersCubit

---

## 4. Dependency Registration Principles

Every dependency should be registered in one clearly defined place.

Registration must be:

- Explicit
- Predictable
- Centralized
- Testable
- Consistent

Do not register dependencies randomly inside feature screens.

Do not register repositories from Cubits.

Do not register Cubits from widgets.

Do not create hidden global dependencies inside constructors.

---

## 5. DI Initialization

Dependency injection must be initialized before the application starts using injected dependencies.

The application startup flow should conceptually be:

main()
→ initialize Flutter
→ initialize dependencies
→ initialize required infrastructure
→ runApp()

The exact implementation should follow the existing project structure.

Dependency initialization should be asynchronous when required by the underlying dependency.

For example, if database initialization requires asynchronous work, DI initialization must await that work before the dependency is exposed as ready for application use.

---

## 6. Registration Order

Dependencies should be registered from lower-level dependencies toward higher-level dependencies.

Recommended order:

1. Core infrastructure
2. Database
3. DAOs / local data sources
4. Repositories
5. Presentation dependencies such as Cubits

Conceptually:

Database
↓
DAO / Data Source
↓
Repository
↓
Cubit

This makes the dependency graph explicit and avoids attempting to resolve a dependency before its prerequisites exist.

---

## 7. Registration Lifetimes

Registration lifetime must reflect the responsibility of the dependency.

The project may use:

- Singleton
- Lazy Singleton
- Factory

The default choice should be `LazySingleton` unless the dependency requires another lifecycle.

### 7.1 Singleton

Use Singleton when exactly one instance must exist for the entire application lifetime and the instance should be created immediately during registration.

Use this deliberately.

Do not make every dependency a Singleton automatically.

### 7.2 Lazy Singleton

Use Lazy Singleton for long-lived services that should have one shared instance but do not need to be created until first requested.

Typical candidates include:

- Database
- Repositories when stateless/shared
- Infrastructure services

This should be the default for long-lived dependencies where appropriate.

### 7.3 Factory

Use Factory for dependencies that should receive a new instance every time they are requested.

Cubits are normally registered as factories.

This prevents one Cubit's state from unintentionally being shared across unrelated screens.

---

## 8. Database Registration

The application database should have one controlled instance.

The database is infrastructure and should not be recreated every time a repository or Cubit is requested.

The registration should conceptually follow:

AppDatabase
→ single application-level instance

Repositories and DAOs receive the database through dependency injection.

No Screen, Cubit, or Widget should construct the database directly.

---

## 9. DAO Registration

DAOs belong to the Data Layer.

They should receive the database through DI.

Example dependency direction:

AppDatabase
→ OrdersDao
→ OrdersRepository
→ OrdersCubit

The DAO should not be constructed inside the Repository if the DAO itself is an application dependency that can be injected cleanly.

The exact DAO implementation should follow the approved Data Layer design.

---

## 10. Repository Registration

Repositories form the boundary between Presentation and Data.

Presentation should depend on repository abstractions where the project's architecture defines interfaces/contracts.

Repositories should be registered centrally.

Conceptually:

OrdersRepository
→ OrdersRepositoryImpl

CustomersRepository
→ CustomersRepositoryImpl

InventoryRepository
→ InventoryRepositoryImpl

The concrete implementation should remain hidden from Presentation code.

A Cubit should request the repository dependency rather than constructing its implementation.

---

## 11. Cubit Registration

Cubits are presentation dependencies.

Cubits should normally be registered as factories.

Conceptually:

OrdersCubit
→ new instance when requested

CustomersCubit
→ new instance when requested

InventoryCubit
→ new instance when requested

This prevents state leakage between unrelated screens.

A Cubit should receive its repository dependency through its constructor.

Example concept:

OrdersCubit(OrdersRepository repository)

The Cubit must not perform:

GetIt.instance<OrdersRepository>()

inside its business methods when constructor injection is practical.

Prefer explicit constructor dependencies.

---

## 12. Constructor Injection

Constructor injection is the preferred way for classes to receive their dependencies.

Example:

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this.repository);

  final OrdersRepository repository;
}

This makes:

- Dependencies explicit
- Testing easier
- Coupling visible
- Construction predictable

Avoid hidden dependencies whenever possible.

---

## 13. Service Locator Access

`get_it` is the dependency registration and resolution mechanism.

However, application classes should not unnecessarily resolve their own dependencies from the service locator.

Prefer:

GetIt
→ creates/resolves object
→ injects dependencies through constructor

instead of:

Class
→ accesses GetIt
→ resolves dependency internally

The service locator should primarily remain at composition/root boundaries.

---

## 14. Avoid Service Locator Leakage

Avoid code such as:

class OrdersCubit {
  final repository = getIt<OrdersRepository>();
}

This hides the dependency.

Prefer:

class OrdersCubit {
  OrdersCubit(this.repository);

  final OrdersRepository repository;
}

Then the DI configuration resolves:

OrdersCubit(getIt<OrdersRepository>())

This produces a clearer dependency graph.

---

## 15. Composition Root

The application's DI configuration should act as the composition root.

The composition root is responsible for deciding:

- Which concrete implementation satisfies an abstraction
- Which lifetime is used
- Which dependencies are constructed
- Which dependencies are injected

Feature code should not make these architectural decisions.

This keeps implementation choices centralized.

---

## 16. Suggested DI Structure

The exact filenames must follow the approved project structure, but the implementation should conceptually have a dedicated DI configuration.

For example:

lib/
  core/
    di/
      injection.dart

or another structure already approved by the project.

Do not create multiple unrelated DI containers.

Do not create one DI configuration per screen.

Feature-specific registration may be separated into registration functions if the project grows, but all registrations must ultimately be coordinated through the application DI initialization.

---

## 17. Registration Functions

If the number of dependencies becomes large, registrations may be grouped logically.

For example:

registerCoreDependencies()

registerDatabaseDependencies()

registerDataDependencies()

registerRepositoryDependencies()

registerPresentationDependencies()

The final initialization may conceptually be:

configureDependencies()
→ registerCoreDependencies()
→ registerDatabaseDependencies()
→ registerDataDependencies()
→ registerRepositoryDependencies()
→ registerPresentationDependencies()

The exact function names are implementation details.

The dependency order is not.

---

## 18. Dependency Naming

Dependency registrations should use clear, domain-oriented types.

Prefer:

OrdersRepository

CustomersRepository

InventoryRepository

OrdersCubit

Avoid vague registrations such as:

Service

Manager

Handler

Helper

unless the type itself has a clearly defined responsibility.

---

## 19. Interfaces and Implementations

When a repository abstraction exists, register the implementation against the abstraction.

Conceptually:

OrdersRepository
→ OrdersRepositoryImpl

This allows the Presentation Layer to depend on the contract.

It also allows tests to replace the implementation without changing the Cubit.

---

## 20. Testing and DI

DI must support isolated testing.

Tests should be able to replace production dependencies with:

- Mocks
- Fakes
- In-memory implementations
- Test repositories

For example:

OrdersCubit
→ FakeOrdersRepository

instead of:

OrdersCubit
→ production database

This allows Cubit tests to focus on presentation behavior.

---

## 21. Test Isolation

Tests must not accidentally reuse application-level singleton state between unrelated test cases.

When global DI registrations are used in tests:

- Reset or replace required registrations
- Avoid state leakage
- Restore the expected dependency configuration when necessary

Test setup should remain deterministic.

---

## 22. Cubit Testing

A Cubit test should generally construct the Cubit with an injected fake/mock repository.

Conceptually:

fakeRepository
→ OrdersCubit(fakeRepository)
→ execute action
→ verify emitted states

The test should not require:

- Real database
- Real network
- Production DI initialization

unless the test is explicitly an integration test.

---

## 23. Database Testing

Database integration tests may use a dedicated test database or in-memory configuration where supported.

Production database registration must not be reused blindly when testing database behavior.

The testing strategy should remain consistent with the Data Layer implementation documentation.

---

## 24. Future Networking Dependencies

Backend networking is intentionally deferred from the current local implementation phase.

When networking is implemented later, its dependencies should be added to the DI graph rather than constructed directly by repositories or Cubits.

The future conceptual graph may become:

Presentation
↓
Cubit
↓
Repository
↓
Local Data / Remote Data
↓
Dio / Retrofit / Backend

The current implementation must not add networking dependencies merely because the final architecture will eventually support them.

---

## 25. Future Sync Dependencies

Synchronization is also deferred from the current local implementation phase.

When synchronization is implemented later, its dependencies should be registered through the same DI mechanism.

Potential future dependencies may include:

- Sync service
- Sync queue processor
- Remote API client
- Connectivity service
- Sync coordinator

These should not be registered or implemented prematurely if they are outside the current implementation scope.

---

## 26. Offline-First DI

The current application must remain fully functional without backend synchronization.

Therefore:

- Local database dependencies are required now.
- Repository dependencies required for local operation are required now.
- Networking dependencies are deferred.
- Sync dependencies are deferred.

Do not make current Cubits depend on a future SyncService simply because synchronization will eventually exist.

Dependencies should reflect the current implementation phase.

---

## 27. Initialization Failures

If a required dependency cannot be initialized, application startup should fail clearly rather than leaving a partially initialized dependency graph.

Examples:

- Database initialization failure
- Required infrastructure initialization failure

The application should not silently continue with invalid dependencies.

Error handling should follow the application's approved startup/error strategy.

---

## 28. Async Dependencies

Some dependencies may require asynchronous initialization.

When this occurs:

- Register or initialize them using the appropriate `get_it` mechanism.
- Ensure dependent code cannot access them before initialization completes.
- Await required initialization before `runApp()` when appropriate.

Do not introduce arbitrary delays as a substitute for proper dependency readiness.

---

## 29. Disposal

Long-lived dependencies that own resources must have an appropriate disposal strategy.

Examples:

- Database
- Streams
- Controllers
- Resource-owning infrastructure

When `get_it` manages the lifecycle of such dependencies, disposal should be registered where necessary.

Short-lived factory dependencies such as Cubits should be disposed according to their Flutter lifecycle.

Do not create custom global disposal logic unless required.

---

## 30. Dependency Scope

The project currently uses application-level DI.

Do not introduce complex scoped dependency systems unless there is a demonstrated requirement.

Feature-level isolation should normally be achieved through:

- Constructor injection
- Factory registration
- Proper Cubit lifecycle

rather than creating multiple service locators.

---

## 31. Avoid Circular Dependencies

Dependencies must form a directed graph without cycles.

Invalid example:

OrdersRepository
→ OrdersService
→ OrdersRepository

Another invalid example:

OrdersCubit
→ OrdersRepository
→ OrdersCubit

Circular dependencies usually indicate an architectural responsibility problem.

Resolve the responsibility rather than hiding the cycle through service-locator lookups.

---

## 32. No Dependency Construction in UI

The UI must not construct application dependencies manually.

Avoid:

OrdersScreen(
  repository: OrdersRepositoryImpl(...)
)

The Screen should obtain the Cubit through the approved presentation/DI integration.

The dependency graph should be assembled by the composition root.

---

## 33. No Duplicate Registrations

A dependency should not be registered multiple times accidentally.

Avoid situations where:

OrdersRepository
is registered in:

- Core DI
- Orders feature DI
- Test DI

without an explicit replacement strategy.

Production configuration should have one authoritative registration for each dependency.

---

## 34. Registration Consistency

All production registrations should follow the same conventions.

For each dependency, the implementation should make clear:

- Type
- Concrete implementation
- Lifecycle
- Dependencies
- Registration location

Do not mix registration styles without a reason.

---

## 35. Example Dependency Graph

For an Orders feature, the dependency graph should conceptually look like:

AppDatabase
↓
OrdersDao
↓
OrdersRepositoryImpl
↓
OrdersRepository
↓
OrdersCubit
↓
OrdersScreen

The Screen should only interact with the Cubit.

The Cubit should only interact with the Repository contract.

The Repository should handle the Data Layer interaction.

---

## 36. Example Registration Concept

The implementation may follow a structure conceptually equivalent to:

GetIt getIt = GetIt.instance;

void configureDependencies() {
  // Core

  // Database

  // DAOs / data sources

  // Repositories

  // Cubits
}

The exact syntax and registration API should follow the installed `get_it` version and project coding standards.

Do not introduce custom wrappers around `get_it` unless there is a documented reason.

---

## 37. Feature Expansion

When a new feature is implemented:

1. Identify its required dependencies.
2. Confirm whether an existing dependency can be reused.
3. Define required repository abstractions.
4. Define concrete implementations.
5. Register data dependencies.
6. Register repository dependencies.
7. Register Cubit factories.
8. Verify the dependency graph.
9. Add test replacements where required.

Do not duplicate an existing dependency simply because a new feature uses it.

---

## 38. Shared Dependencies

Shared dependencies should be reused when they represent the same application resource.

Examples:

- AppDatabase
- Shared infrastructure
- Common configuration

Feature-specific state should generally remain isolated.

For example:

OrdersCubit and CustomersCubit should not share the same Cubit instance merely because both exist in the same application.

---

## 39. DI and Design System

The Design System is not an application-service dependency by default.

UI components should normally remain regular widgets and should not be registered in `get_it`.

Do not turn every reusable widget into a DI dependency.

DI is for application dependencies, not arbitrary UI objects.

---

## 40. DI and Configuration

Application configuration values may be injected when they represent real runtime dependencies.

Examples may include:

- Database configuration
- Environment configuration
- API configuration when networking is introduced

Do not use DI as a generic storage mechanism for constants that can remain compile-time or static configuration.

---

## 41. Logging

DI initialization may provide logging/configuration dependencies where required.

Do not introduce logging as a mandatory dependency for every class without a real requirement.

Keep dependencies minimal.

---

## 42. Performance Considerations

Dependency injection should not introduce unnecessary object creation.

Use:

- Lazy Singleton for long-lived shared dependencies where appropriate.
- Factory for short-lived stateful dependencies such as Cubits.

Do not instantiate every possible dependency during application startup unless required.

---

## 43. Security and Secrets

Sensitive configuration must not be hardcoded into DI registration.

When backend networking is implemented, secrets and credentials must follow the project's approved configuration/security strategy.

DI should inject configuration; it should not become a place where secrets are embedded directly into source code.

---

## 44. Coding Agent Rules

When an AI coding agent implements DI, it must:

- Use `get_it`.
- Use the existing DI composition root.
- Follow the approved dependency graph.
- Prefer constructor injection.
- Register dependencies centrally.
- Register Cubits as factories by default.
- Use appropriate lifetimes.
- Keep database as a controlled shared dependency.
- Register repositories through their approved abstractions.
- Keep Presentation independent from concrete data implementations.
- Support test replacement of dependencies.
- Avoid introducing alternative DI/state-management packages.
- Respect the current local-only implementation phase.

The coding agent must not:

- Introduce another DI package.
- Create multiple `GetIt` instances.
- Create repositories inside Cubits.
- Create databases inside repositories.
- Resolve dependencies through `GetIt` deep inside application classes when constructor injection is practical.
- Access the database from Presentation.
- Introduce networking prematurely.
- Introduce synchronization prematurely.
- Create circular dependencies.
- Register widgets as application dependencies without a specific reason.
- Create duplicate production registrations.
- Add unapproved architectural layers.

---

## 45. Definition of Done

Dependency Injection implementation is considered complete when:

- `get_it` is configured.
- There is one authoritative application DI configuration.
- Initialization occurs before dependent application code runs.
- Database dependencies are registered correctly.
- DAO/data-source dependencies are registered correctly.
- Repository implementations are registered correctly.
- Repository abstractions are exposed to Presentation where applicable.
- Cubits are registered using the appropriate lifecycle.
- Constructor injection is used for application dependencies.
- Production code does not unnecessarily resolve dependencies from `GetIt` internally.
- Test dependencies can replace production dependencies.
- No circular dependencies exist.
- No duplicate production registrations exist.
- Current implementation does not depend on deferred networking.
- Current implementation does not depend on deferred synchronization.
- The dependency graph remains:

Presentation
↓
Cubit
↓
Repository
↓
Data Layer

---

## 46. Final Rules

The following rules are authoritative for the current implementation:

1. `get_it` is the approved DI package.
2. There is one application-level service locator.
3. DI configuration is centralized.
4. Constructor injection is preferred.
5. Cubits are normally registered as factories.
6. Long-lived infrastructure uses an appropriate singleton/lazy-singleton lifecycle.
7. The database has one controlled application-level instance.
8. Repositories are registered centrally.
9. Presentation depends on repository contracts rather than concrete data implementations.
10. Presentation must not access the database directly.
11. Cubits must not construct repositories.
12. Repositories must not construct presentation objects.
13. Do not introduce circular dependencies.
14. Do not introduce another DI framework.
15. Networking remains deferred.
16. Synchronization remains deferred.
17. DI must support isolated testing.
18. Dependency lifetimes must be chosen intentionally.
19. New dependencies must follow the existing dependency graph.
20. No implementation should introduce architectural complexity without an explicit project decision.