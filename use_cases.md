# Plugin Use Cases

## Use Case 1: Generate a CRUD service from a sequence diagram

A developer draws a UML sequence diagram showing `ProductService` calling `ProductMapper.toEntity()`, `ProductRepository.save()`, `ProductMapper.toDTO()`, and `ProductResponseFactory.createSingleResponse()`. They run `/design-is-code:disc` and get: interfaces for all participants, a test class with 4 `verify()` tests (one per arrow) + 1 `assertThat`, a `DefaultProductService` implementation derived entirely from the tests, and a decision table skeleton for the `ProductMapper` leaf node. The developer verifies correctness in 30 seconds by counting arrows against `verify()` calls — no line-by-line code review needed.

## Use Case 2: Add branching logic to an existing service

An `OrderService` already exists with create functionality. The developer adds an `alt`/`else` sequence diagram for "update or create" logic — if the order exists, update it; if not, create a new one. They run `/design-is-code:disc` and the plugin detects the existing files, switches to UPDATE mode, and adds two new `@Nested` test classes (one per branch) without touching existing code. Each branch gets its own `verify()` tests and mock setup. The implementation is then derived from the new tests. Existing tests and code remain untouched.

## Use Case 3: Generate a validation guard clause with exception handling

A developer draws a `ResourceUsageValidator` that calls `ResourceUsageService.getResourceUsages()` and throws `ResourceInUseException` if resources are in use. They run `/design-is-code:disc` and get two `@Nested` test classes: the happy path calls the method in `@BeforeEach`, while the exception path uses `assertThatThrownBy` with `.hasMessage()` verification. Error message constants are generated as `protected static final String` — single source of truth, no string duplication between test and implementation.
