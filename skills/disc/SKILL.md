---
name: disc
description: "Transform UML sequence diagrams into working Java code using the DisC (Design is Code) methodology: first generate tests from UML, then derive implementation from the tests."
disable-model-invocation: true
---

You are executing the DisC (Design is Code) methodology. Transform the provided UML sequence diagram into working Java code: first generate tests from the UML, then derive implementation from the tests.

### Why DisC Exists

AI generates code in seconds. Humans review code in hours. This asymmetry means AI produces faster than humans can verify — and unverified code is a liability. DisC solves this: the UML is a contract. Each arrow becomes a test. Tests force implementation structure. The human verifies the contract held by counting arrows against tests — a 30-second check, not an hours-long code review.

### The Two Invariants

1. **Arrow = Test.** Every arrow in the UML becomes exactly one `verify()` test.
2. **Implement from tests, not UML.** The implementation is derived by reading the test's `verify()` calls and `when().thenReturn()` chains. The UML is consumed only during test generation. Implementation reads the tests.

### Input

The user's UML sequence diagram:

$ARGUMENTS

---

# Section 1: Definitions

Each definition is a self-contained, referenceable block. The router (Section 2) dispatches to these definitions — they don't prescribe order or process.

> **What DisC Controls**
>
> | Component type | DisC dictates... | Test style |
> |---|---|---|
> | **Orchestrator** (has outgoing arrows to other participants) | Structure — call order, arguments, wiring | `verify()` tests — one per arrow |
> | **Pure function / leaf node** (no outgoing arrows) | Correctness only — input/output examples | `assertThat()` decision table tests — human designs the examples |
>
> DisC constrains **how orchestrators call collaborators**. It does NOT constrain **how pure functions compute their results** — only that they produce correct output for human-designed inputs.

---

## Definition: participant

**Trigger:** `participant X` or named box in the diagram.

**Test shape:**
- The FIRST participant is the class under test → instantiated in `@BeforeEach` via constructor injection.
- All other participants → `@Mock private [Type] [name];`

**Impl shape:**
- First participant → `Default[Name]` implementation class with `private final` fields for each collaborator.
- Each collaborator → constructor parameter.

**Classify each participant (except first):**

| Participant has... | Classification | Test style |
|---|---|---|
| Outgoing solid arrows to other participants | Orchestrator collaborator | Mock + verify() in consumer's test; own DisC test later |
| NO outgoing solid arrows | Pure function (leaf node) | Mock + verify() in consumer's test; own decision table test later |

Both types get mocked in the consumer's test. The difference is what happens when you later test the collaborator itself.

**Checklist:**
- [ ] Every collaborator has an `@Mock` field
- [ ] Constructor injection includes ALL collaborators (and only collaborators)

---

## Definition: interaction

**Trigger:** Any `A -> B: method(arg)` solid arrow, optionally paired with `B --> A: value` dashed return.

Each solid arrow produces exactly one `verify()` test. Processing depends on whether there is a return:

**Return label parsing:** The dashed return label supports two formats:

| Format | Example label | Variable name | Type |
|---|---|---|---|
| `variable : Type` (explicit) | `greeting : Greeting` | `greeting` | `Greeting` |
| `variable` (inferred) | `greeting` | `greeting` | `Greeting` (PascalCase of variable) |

When the label contains ` : `, split on ` : ` — left side is the variable name (camelCase), right side is the explicit type. When no ` : ` is present, infer the type by converting the variable name to PascalCase. Prefer explicit syntax — it eliminates ambiguity (e.g., `savedOrder : Order` vs inferring `SavedOrder`).

**With return** (`A -> B: method(arg)` + `B --> A: value`):
- **Test setup:** `when([collaborator].[method](any())).thenReturn([returnValue]);` in `@BeforeEach`
- **Test:** `verify([collaborator]).[method]([expectedArg]);`
- **Impl:** `[ReturnType] [var] = [collaborator].[method]([arg]);`
- The return value becomes a `@Mock` field (or real value for primitives/final classes like `UUID`, `Integer`, `String`).

**Void — no return** (solid arrow with NO following dashed return):
- **Test setup:** No `when().thenReturn()` for this call
- **Test:** `verify([collaborator]).[method]([expectedArg]);` — still exists
- **Impl:** `[collaborator].[method]([arg]);` — no return capture

**Final return** (last dashed arrow back to the first participant):
- **Result field:** `private [FinalReturnType] result;`
- **Method invocation in `@BeforeEach`:** `result = default[ServiceName].[methodName]([input]);`
- **Final assertion test:** `assertThat(result).isEqualTo([expectedReturnMock]);`
- **Impl:** The `return` statement of the method

**Data flow rule (pipe pattern):** The return value named in a dashed arrow becomes the argument when that same name appears in a subsequent solid arrow. Example: `B --> A: product` followed by `A -> C: save(product)` — the variable `product` flows from the first call's return into the second call's argument. If names differ, look for an intermediate arrow.

**Checklist:**
- [ ] Count of solid arrows == count of `verify()` tests
- [ ] Each `when().thenReturn()` corresponds to a dashed return arrow
- [ ] Arrow label → exact method name + args in `verify()`
- [ ] Data flow: return value names feed correctly into subsequent arrow arguments
- [ ] Implementation calls methods in the same order as `verify()` tests appear
- [ ] Every mock data object has an `@Mock` field (or real value for primitives/final classes)
- [ ] Return label types: use explicit `: Type` when present; PascalCase inference only when omitted

---

## Definition: loop

**Trigger:** `loop` / `end` block in UML (e.g., `loop for each lineItem`)

**Test shape:**
- Mock inputs use `List.of()` with a single element so iteration happens once.
- `verify()` confirms the call happens with the correct arguments for that single element.
- For primitives like `UUID` and `Integer` that cannot be mocked, use real values: `UUID.randomUUID()`, `(int)(Math.random() * 1000)`.

**Impl shape:**
```java
// forEach or stream iteration
items.forEach(item -> {
    [collaborator].[method](item);
});
```

**Checklist:**
- [ ] Loop test data uses `List.of()` with a single element
- [ ] Primitives/final classes use real values, not mocks

**Example: Builder + Iteration**

**UML Input:**
```
SaleService -> ProductService: getProductByIds(productIds)
ProductService --> SaleService: products
SaleService -> ProductService: throwExceptionIfProductNoExist(productIds)
SaleService -> SaleBuilderFactory: create()
SaleBuilderFactory --> SaleService: saleBuilder
loop for each lineItem
    SaleService -> SaleBuilder: with(product, quantity)
end
SaleService -> SaleBuilder: build()
SaleBuilder --> SaleService: sale
SaleService -> SaleResponseFactory: create(sale)
SaleResponseFactory --> SaleService: saleResponse
```

**Key test patterns for loop (excerpt):**
```java
// Primitives — real values, not mocks
private final UUID productId = UUID.randomUUID();
private final Integer quantity = (int) (Math.random() * 1000);

// List.of() with single element — iteration happens once
when(saleRequest.getLineItems()).thenReturn(List.of(saleLineItemRequest));
when(productService.getProductByIds(any())).thenReturn(List.of(product));

// verify() for the call inside the loop
@Test void shouldBuildWithProductAndQuantity() { verify(saleBuilder).with(product, quantity); }
```

---

## Definition: branching

**Trigger:** `alt` / `else` / `end` block in UML.

**Test shape:**
- Each branch becomes a separate `@Nested` class.
- The branch condition determines the mock setup (different `when().thenReturn()` values).
- Each `@Nested` class has its own `@BeforeEach` with branch-specific setup and method invocation.

**Impl shape:**
```java
if ([condition]) {
    // branch 1
} else {
    // branch 2
}
```

**Checklist:**
- [ ] One `@Nested` class per `alt`/`else` branch
- [ ] Each branch's `@BeforeEach` has correct mock setup for that path
- [ ] Each branch has its own `verify()` calls matching only that branch's arrows

**N-path complexity warning:** If the UML has nested `alt`/`else` blocks (branches within branches), this is a design smell. The number of `@Nested` classes grows exponentially. Suggest the human simplify the design using resolver, strategy, or factory patterns before generating code. A linear flow with one level of branching is the sweet spot.

**Example: Branching (Update or Create)**

**UML Input:**
```
OrderService -> OrderRepository: findById(orderId)
OrderRepository --> OrderService: existingOrder
alt [existingOrder is present]
    OrderService -> OrderMapper: updateEntity(existingOrder, request)
    OrderMapper --> OrderService: updatedOrder
    OrderService -> OrderRepository: save(updatedOrder)
    OrderRepository --> OrderService: savedOrder
else [not found]
    OrderService -> OrderMapper: toEntity(request)
    OrderMapper --> OrderService: newOrder
    OrderService -> OrderRepository: save(newOrder)
    OrderRepository --> OrderService: savedOrder
end
```

**Generated Test:**
```java
@MockitoSettings(strictness = Strictness.LENIENT)
class DefaultOrderServiceTest {

    @Mock private OrderRepository orderRepository;
    @Mock private OrderMapper orderMapper;

    @Mock private OrderRequest request;
    @Mock private Order existingOrder;
    @Mock private Order updatedOrder;
    @Mock private Order newOrder;
    @Mock private Order savedOrder;
    private UUID orderId;
    private Order result;

    DefaultOrderService defaultOrderService;

    @BeforeEach
    void setUp() {
        orderId = UUID.randomUUID();
        defaultOrderService = new DefaultOrderService(orderRepository, orderMapper);
    }

    @Nested
    class WhenOrderExists {

        @BeforeEach
        void setUp() {
            when(orderRepository.findById(any())).thenReturn(Optional.of(existingOrder));
            when(orderMapper.updateEntity(any(), any())).thenReturn(updatedOrder);
            when(orderRepository.save(any())).thenReturn(savedOrder);
            result = defaultOrderService.createOrUpdate(orderId, request);
        }

        @Test void shouldFindById() { verify(orderRepository).findById(orderId); }
        @Test void shouldUpdateEntity() { verify(orderMapper).updateEntity(existingOrder, request); }
        @Test void shouldSaveUpdatedOrder() { verify(orderRepository).save(updatedOrder); }
        @Test void shouldReturnSavedOrder() { assertThat(result).isEqualTo(savedOrder); }
    }

    @Nested
    class WhenOrderNotFound {

        @BeforeEach
        void setUp() {
            when(orderRepository.findById(any())).thenReturn(Optional.empty());
            when(orderMapper.toEntity(any())).thenReturn(newOrder);
            when(orderRepository.save(any())).thenReturn(savedOrder);
            result = defaultOrderService.createOrUpdate(orderId, request);
        }

        @Test void shouldFindById() { verify(orderRepository).findById(orderId); }
        @Test void shouldMapToEntity() { verify(orderMapper).toEntity(request); }
        @Test void shouldSaveNewOrder() { verify(orderRepository).save(newOrder); }
        @Test void shouldReturnSavedOrder() { assertThat(result).isEqualTo(savedOrder); }
    }
}
```

**Each branch: 3 solid arrows = 3 verify() tests + 1 assertThat = 4 tests per branch. Different `when()` setup drives different code paths.**

---

## Definition: guard_clause

**Trigger:** A dashed self-arrow from a participant to itself labeled `<<throws>> ExceptionType`, typically inside an `alt` fragment.

**Test shape — THREE critical rules:**

1. **Method invocation placement:** Happy path calls the method in `@BeforeEach`. Exception path calls it inside `assertThatThrownBy` in the `@Test`. Never call a throwing method in `@BeforeEach` — the exception would abort setup.
2. **`.hasMessage()` verification:** When the UML specifies a message template (e.g., `<<throws>> ResourceInUseException("...%s...")`), chain `.hasMessage(CONSTANT.formatted(...))` after `.isInstanceOf()`.
3. **`protected static final` constant:** Declare the error message as `protected static final String` in the implementation. The test imports it directly — single source of truth, no string duplication.

```java
// Happy path @Nested — method called in @BeforeEach
@Nested
class NoUsage {
    @BeforeEach
    void setUp() {
        when([collaborator].[method](any())).thenReturn(Collections.emptyList());
        // Happy path — method called in @BeforeEach
        default[ServiceName].[methodName]([args]);
    }

    @Test
    void should[VerifyCall]() {
        verify([collaborator]).[method]([args]);
    }
}

// Exception path @Nested — method called inside assertThatThrownBy
@Nested
class Usage {
    @BeforeEach
    void setUp() {
        when([collaborator].[method](any())).thenReturn(List.of([mockItem]));
        // Exception path — @BeforeEach only wires mocks, does NOT call method
    }

    @Test
    void shouldThrowException() {
        assertThatThrownBy(() -> default[ServiceName]
            .[methodName]([args]))
            .isInstanceOf([ExceptionType].class)
            .hasMessage([CONSTANT].formatted([args]));
    }
}
```

**Impl shape:**
```java
@Override
public void [methodName]([params]) {
    [ReturnType] [result] = [collaborator].[method]([params]);
    if (![result].isEmpty()) {
        throw new [ExceptionType](
            [CONSTANT].formatted([args]));
    }
}
```

**Checklist:**
- [ ] Guard clause method invocation placement: exception path calls method inside `assertThatThrownBy`, NOT in `@BeforeEach`
- [ ] `.hasMessage()` verification chained when UML specifies a message template
- [ ] Error message constants declared as `protected static final String` in the implementation class

**Example: Guard Clause / Validator with Exception**

**UML Input:**
```
ResourceUsageValidator -> ResourceUsageService: getResourceUsages(organizationId, resourceId, resourceType)
ResourceUsageService --> ResourceUsageValidator: resourceUsages
alt [resourceUsages is not empty]
    ResourceUsageValidator -> ResourceUsageValidator: <<throws>> ResourceInUseException
end
```

**Generated Test:**
```java
@MockitoSettings(strictness = Strictness.LENIENT)
class DefaultResourceUsageValidatorTest {

    @Mock private ResourceUsageService resourceUsageService;
    @Mock private ResourceUsageDetail resourceUsageDetails;

    private UUID organizationId;
    private String resourceType;
    private String resourceId;
    private DefaultResourceUsageValidator defaultResourceUsageValidator;

    @BeforeEach
    void setUp() {
        organizationId = randomUUID();
        resourceType = getRandomString();
        resourceId = getRandomString();
        defaultResourceUsageValidator = new DefaultResourceUsageValidator(resourceUsageService);
    }

    @Nested
    class NoUsage {
        @BeforeEach
        void setUp() {
            when(resourceUsageService.getResourceUsages(any(), any(), any()))
                .thenReturn(Collections.emptyList());
            // RULE 1: Happy path — method called in @BeforeEach
            defaultResourceUsageValidator.validate(organizationId, resourceId, resourceType);
        }

        @Test
        void shouldGetResourceUsage() {
            verify(resourceUsageService).getResourceUsages(organizationId, resourceId, resourceType);
        }
    }

    @Nested
    class Usage {
        @BeforeEach
        void setUp() {
            when(resourceUsageService.getResourceUsages(any(), any(), any()))
                .thenReturn(List.of(resourceUsageDetails));
            // RULE 2: Exception path — @BeforeEach only wires mocks, does NOT call method
        }

        @Test
        void shouldThrownException() {
            // RULE 3: Method called INSIDE assertThatThrownBy with .hasMessage()
            assertThatThrownBy(() -> defaultResourceUsageValidator
                .validate(organizationId, resourceId, resourceType))
                .isInstanceOf(ResourceInUseException.class)
                .hasMessage(RESOURCE_IN_USE_ERROR_MESSAGE.formatted(resourceType, resourceId));
        }
    }
}
```

**1 solid arrow + 1 self-arrow with `<<throws>>` = 1 verify() test + 1 assertThatThrownBy test = 2 total tests.**

---

## Definition: leaf_node

**Trigger:** A participant that is ONLY a target of arrows (never the source of a solid arrow to another participant).

**Classify the leaf node:**

| Leaf node type | Name ends in... | DisC action |
|---|---|---|
| **Computational** (pure function) | `Mapper`, `Factory`, `Calculator`, `Converter`, `Builder` | Decision table test skeleton (human fills in) |
| **I/O boundary** | `Repository`, `Client`, `Gateway`, `Adapter` | Mocked in consumer only — no standalone DisC test |

I/O boundary leaf nodes are tested via integration tests, not DisC. Generating a decision table for a JPA repository would be testing Spring Data, not your code.

**Test shape — Decision table skeleton (computational leaf nodes only, no mocks):**
```java
class Default[PureFunctionName]Test {

    private [PureFunctionName] [instance] = new Default[PureFunctionName]();

    // TODO: Human must fill in the decision table.
    // DisC CANNOT dictate the implementation of pure functions.
    // Only the human-designed examples constrain the output.

    @Test void shouldHandleBaseCase() {
        assertThat([instance].[method]([baseInput]))
            .isEqualTo([expectedBaseOutput]); // ← Human fills this in
    }

    @Test void shouldHandleEdgeCase() {
        assertThat([instance].[method]([edgeInput]))
            .isEqualTo([expectedEdgeOutput]); // ← Human fills this in
    }
}
```

Mark these with `// TODO` comments — the human must design the test cases. AI should NOT invent both test cases and implementation for pure functions (false positive risk).

**Impl shape:**
```java
// Pure function — algorithm is unconstrained
public class DefaultProportionalAllocation implements ProportionalAllocation {
    @Override
    public List<BigDecimal> allocate(BigDecimal total, List<BigDecimal> bases) {
        // Any algorithm that produces correct output is valid
        // The decision table tests verify correctness, not structure
    }
}
```

- **No `verify()` calls to read** — there's no call order to follow
- **Algorithm is free** — any implementation that passes the decision table is valid
- **Human-designed test cases constrain output**, not structure

**Dual testing rule:** In the consumer's test, leaf nodes are still `@Mock` fields with `verify()` calls. They ALSO get their own standalone decision table test.

**Checklist:**
- [ ] Leaf node participants identified (no outgoing arrows = pure function)
- [ ] Pure function test skeletons use `assertThat()`, not `verify()`
- [ ] Pure function test cases marked with TODO for human review
- [ ] Dual testing: pure functions are both mocked (in consumer) AND get their own tests

---

## Definition: language_profile

Swap this section to change the target language/framework. All language-specific templates and conventions live here.

**Target: Java / Spring Boot**

### Base Package Detection

`{basePackage}` and `{basePackagePath}` appear throughout this profile. Resolve them BEFORE generating any code:

1. Search for the class annotated with `@SpringBootApplication` — its package IS the base package
2. If not found, glob for `src/main/java/**/*.java`, read package statements, and use the common prefix
3. If no Java files exist, check `build.gradle` for `group` or `pom.xml` for `<groupId>`
4. If still unresolvable, ask the user

`{basePackagePath}` is `{basePackage}` with `.` replaced by `/` (e.g., `com.acme.orders` → `com/acme/orders`).

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Interface | PascalCase, from participant name | `OrderService` |
| Implementation class | `Default` + interface name | `DefaultOrderService` |
| Test class | Implementation name + `Test` | `DefaultOrderServiceTest` |
| Test method | `should` + verb phrase describing interaction | `shouldSaveOrder` |
| Mock field (collaborator) | camelCase of interface name | `orderMapper` |
| Mock field (data) | Variable name from return label. Type from explicit `: Type` or PascalCase inference | `savedOrder : Order` → field: `Order savedOrder` |

### Domain Type Rule — Abstractions Depend on Abstractions

Any type that appears in an interface method signature (parameter or return type)
and represents a **domain concept** is itself generated as an **interface**, not a class.

This enforces Dependency Inversion Principle part B: abstractions should not depend
on details.

**Rule:** When a return label or parameter names a domain type, generate it as an interface:
- `Order.java` → `public interface Order {}`
- Do NOT generate `DefaultOrder.java` — the concrete class is a human concern
  (its fields and persistence mapping are domain/infra decisions DisC cannot make)

**Exceptions — NOT domain types, leave as-is:**
| Type category | Examples | Reason |
|---|---|---|
| Java standard primitives/wrappers | `UUID`, `String`, `Integer`, `Long`, `Boolean` | Not invented by the domain |
| Java standard generics | `Optional<T>`, `List<T>`, `Map<K,V>`, `Set<T>` | Standard library |
| Framework types | Spring, JPA types | External contract |
| `*Request`, `*Response`, `*DTO` | `CreateOrderRequest`, `ProductDTO` | Boundary data carriers — structure IS the contract |

**Effect on tests:** No change. `@Mock private Order order;` mocks interfaces natively.

### Package Placement

| Suffix | Package | Example |
|---|---|---|
| `*Service` | `{basePackage}.service` | `OrderService.java` |
| `*Repository` | `{basePackage}.repository` | `OrderRepository.java` |
| `*Mapper` | `{basePackage}.mapper` | `OrderMapper.java` |
| `*Factory` | `{basePackage}.factory` | `OrderFactory.java` |
| `*Builder` | `{basePackage}.builder` | `SaleBuilder.java` |
| `*Controller` | `{basePackage}.controller` | `OrderController.java` |
| Entity/model types | `{basePackage}.entity` or `{basePackage}.model` | `Order.java` |
| `*Request`, `*Response`, `*DTO` | `{basePackage}.model` | `CreateOrderRequest.java` |
| Test classes | Same package as implementation, under `src/test/java` | `DefaultOrderServiceTest.java` |

If a suffix doesn't match any rule, use `{basePackage}.service` as the default.

### File Paths

- Interface: `src/main/java/{basePackagePath}/[package]/[ServiceName].java`
- Test: `src/test/java/{basePackagePath}/[package]/Default[ServiceName]Test.java`
- Implementation: `src/main/java/{basePackagePath}/[package]/Default[ServiceName].java`

### Test Class Template

```java
package {basePackage}.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@MockitoSettings(strictness = Strictness.LENIENT)
class Default[ServiceName]Test {

    @Mock private [Collaborator1] [collaborator1];
    @Mock private [Collaborator2] [collaborator2];
    @Mock private [InputType] [input];
    @Mock private [ReturnType1] [returnValue1];
    private [FinalReturnType] result;
    Default[ServiceName] default[ServiceName];

    @BeforeEach
    void setUp() {
        default[ServiceName] = new Default[ServiceName]([collaborator1], [collaborator2]);
    }

    @Nested
    class When[MethodName] {
        @BeforeEach
        void setUp() {
            when([collaborator].method(any())).thenReturn([returnValue]);
            result = default[ServiceName].[methodName]([input]);
        }

        @Test void should[DescribeInteraction]() { verify([collaborator]).[method]([expectedArg]); }
        @Test void shouldReturn[ExpectedResult]() { assertThat(result).isEqualTo([expectedReturnMock]); }
    }
}
```

### Implementation Template

```java
package {basePackage}.service;

import org.springframework.stereotype.Service;

@Service
public class Default[ServiceName] implements [ServiceName] {
    private final [Collaborator1] [collaborator1];
    private final [Collaborator2] [collaborator2];

    public Default[ServiceName]([Collaborator1] [collaborator1], [Collaborator2] [collaborator2]) {
        this.[collaborator1] = [collaborator1];
        this.[collaborator2] = [collaborator2];
    }

    @Override
    public [ReturnType] [methodName]([InputType] [input]) {
        // One line per verify() test, in order
        [ReturnType1] [var1] = [collaborator1].method([input]);
        [ReturnType2] [var2] = [collaborator2].method([var1]);
        return [var2];
    }
}
```

### Implementation Annotations

- Use `@Service` annotation (or `@Component` for non-service classes)
- Constructor injection for all collaborators (no `@Autowired`)
- One method call per `verify()` test, maintaining the order from the test
- Variable names match the mock field names from the test
- Return type matches the `result` field type in the test

### Build Command

```
./gradlew test
```

---

## Definition: file_management

All rules for creating vs. updating files live here. The router references this definition — it is never duplicated elsewhere.

### Mode Detection

Before generating anything, check if target files already exist.

**Step 1: Derive target file paths** from two sources:
- **Participant names** — using the language_profile file paths rules (as before)
- **Domain types from return labels** — any type extracted from dashed return arrows
  that is a domain type (per the Domain Type Rule in language_profile) also gets a
  file path derived and checked. Use `{basePackage}.entity` as the package.

Collect ALL target files before proceeding to Step 2.

**Step 2: Check for pre-existing files** using Glob. For each file, record: **EXISTS** or **NEW**.

**Step 3: If any file EXISTS, read it.** For every file marked EXISTS:
1. Read the full file content
2. Identify what already exists:
   - **Test file:** existing `@Mock` fields, `@Nested` classes, `@Test` methods
   - **Interface:** existing method signatures
   - **Implementation:** existing methods, hand-written additions (logging, annotations, comments)

**Step 4: Set mode per file:**

| File status | Mode | Tool to use |
|-------------|------|-------------|
| NEW | CREATE | Write tool (create fresh file) |
| EXISTS | UPDATE | Edit tool (add new content only; never touch existing content) |

**Critical rule:** Existing content is sacred. Never modify, move, or delete anything that already exists in a file. Only ADD new content.

### CREATE Mode Rules

- Use the Write tool to create a new file
- Generate the complete file content using templates from the language_profile definition

### UPDATE Mode Rules

| File type | What to ADD | What NOT to touch |
|-----------|-------------|-------------------|
| Interface | New method signature(s) only. Skip if already present. | Existing method signatures |
| Test | New `@Nested` class (after last existing) + new `@Mock` fields only if not already declared | Existing `@Nested`, `@Test`, `@Mock`, setup code |
| Implementation | New method + new `private final` fields + new constructor params (if new collaborator) | Existing methods, logging, annotations, comments |
| Domain type interface (EXISTS) | Nothing — skip. Never overwrite. | All existing content |

> **Domain type EXISTS as a class:** Do not convert it to an interface. Add a warning
> comment in the Step 5 report: "⚠️ `[TypeName].java` exists as a class — consider
> converting to an interface to satisfy DIP."

### Writing Files

- **CREATE mode files:** Use the Write tool (new file)
- **UPDATE mode files:** Use the Read tool first (to confirm current state), then the Edit tool to insert new content at the correct location. NEVER use the Write tool on an existing file.

---

## Definition: quality_gate

Before writing any files, pass every item in this gate. If any item fails, fix the generated code before proceeding. Do not skip this step.

### Self-Reflection Protocol

Before writing, create an internal rubric for the generated code. Iterate your output until you rate it 10/10 against this rubric. Do not infer patterns that are not in the fragment definitions. If you are unsure how a UML element maps, check the definitions — if it's not there, apply the Refusal Protocol below.

### Refusal Protocol

When the UML is ambiguous, invalid, or uses unsupported fragment types:

1. **STOP** — do not generate code from ambiguous or unsupported UML
2. **EXPLAIN** — describe what is ambiguous or unsupported, referencing the fragment definitions
3. **SUGGEST** — propose how to restructure the UML using supported fragments

Examples of when to refuse:
- UML arrow has no method name label
- Fragment type not in the definitions (e.g., `par`, `critical`, `break` — not yet supported)
- Circular arrows (A → B → A with no clear entry point)
- Participant names that don't follow naming conventions

### Error Handling for Unsupported Fragments

If the UML contains a fragment type not listed in the definitions:
1. List the unsupported fragments found
2. Show which definitions ARE available
3. Suggest how to express the intent using supported fragments (e.g., `par` → sequential arrows with a comment noting concurrency is a runtime concern)

### 4 Critical Checks

Validate these four categories. For detailed per-pattern rules, reference the relevant definition.

1. **Arrow parity** — Count solid arrows in UML. Count `verify()` calls in test. They must be equal. Each `when().thenReturn()` must correspond to a dashed return arrow. The `assertThat(result)` must match the final return value.

2. **Data flow integrity** — Each dashed return value feeds the correct next solid arrow argument (pipe pattern from the interaction definition). Implementation calls methods in the same order as `verify()` tests appear. Variable names match mock field names.

3. **File mode correctness** — Discovery completed. CREATE uses Write tool, UPDATE uses Edit tool. No existing content modified, moved, or deleted. No duplicate `@Mock` fields or `@Nested` classes.

4. **Pattern rules applied** — Guard clause placement correct (guard_clause definition). Leaf nodes classified as computational vs I/O (leaf_node definition). Branching has `@Nested` per branch (branching definition). Constructor injection includes all collaborators and only collaborators.

---

# Section 2: Router

The router orchestrates the DisC pipeline. It contains zero domain knowledge — it only dispatches to the definitions in Section 1.

## Step 1: Validate

Check that the UML is parseable and all elements are supported.

- Parse the input UML diagram
- For each element, check it matches a definition: participant, interaction, loop, branching, guard_clause, or leaf_node
- If any element is unsupported or ambiguous → invoke the quality_gate Refusal Protocol. **STOP.**

## Step 2: Classify

Identify which definitions apply to this UML.

- List all participants → apply the **participant** definition to classify each as orchestrator or leaf node
- List all solid arrows → each is an **interaction**
- Identify `loop`/`end` blocks → mark as **loop**
- Identify `alt`/`else`/`end` blocks → mark as **branching**
- Identify self-arrows with `<<throws>>` → mark as **guard_clause**
- Identify participants with no outgoing arrows → mark as **leaf_node** and sub-classify (computational vs I/O)

## Step 3: Apply (UML → Interfaces + Tests)

For each classified element, use the matching definition to generate output.

1. **Package detection** — Resolve `{basePackage}` using the **language_profile** Base Package Detection rules
2. **Discovery** — Apply the **file_management** definition to determine CREATE or UPDATE mode for every target file
3. **Generate interfaces** — One per collaborator, using **language_profile** naming/placement + **file_management** mode
4. **Generate tests** — For each UML element, apply its definition's test shape. Use **language_profile** templates.
5. **Generate decision table skeletons** — For each **leaf_node** (computational only), generate a standalone test skeleton
6. **Run quality_gate** — Pass all 4 Critical Checks before writing any files

## Step 4: Implement (Tests → Code)

**IMPORTANT:** Re-read the test file. Do NOT reference the UML diagram. The test is your specification. Derive the implementation entirely from the `verify()` calls and `when().thenReturn()` chains in the test. This preserves the DisC guarantee — the two-phase wall ensures implementation structure matches what the tests demand.

Read every `verify()` call and `when().thenReturn()` in the test. The implementation must:

1. Call every method that appears in a `verify()`, in order
2. Pass the exact arguments verified (follow the data flow from `when().thenReturn()` chains)
3. Return the value that `assertThat(result).isEqualTo(...)` expects

Apply **language_profile** templates + **file_management** mode.

**Scope limitation:** DisC verifies the design contract — that collaborators are called in the right order with the right arguments. It does NOT verify runtime correctness (e.g., a real repository throwing, a real mapper transforming incorrectly). Runtime correctness requires integration tests. DisC and integration tests are complementary, not substitutes.

## Step 5: Report

### Walkthrough Example: Simple Linear Flow

**UML Input:**
```
ProductService -> ProductMapper: toEntity(createProductRequest)
ProductMapper --> ProductService: product
ProductService -> ProductRepository: save(product)
ProductRepository --> ProductService: product (saved)
ProductService -> ProductMapper: toDTO(product)
ProductMapper --> ProductService: productDto
ProductService -> ProductResponseFactory: createSingleResponse(productDto)
ProductResponseFactory --> ProductService: singleProductResponse
```

**Generated Test:**
```java
@MockitoSettings(strictness = Strictness.LENIENT)
class DefaultProductServiceTest {

    @Mock private ProductRepository productRepository;
    @Mock private ProductMapper productMapper;
    @Mock private ProductResponseFactory responseFactory;

    @Mock private CreateProductRequest createProductRequest;
    @Mock private Product product;
    @Mock private ProductDTO productDto;
    @Mock private SingleProductResponse singleProductResponse;

    private SingleProductResponse result;
    DefaultProductService defaultProductService;

    @BeforeEach
    void setUp() {
        defaultProductService = new DefaultProductService(productRepository, productMapper, responseFactory);
    }

    @Nested
    class WhenCreateProduct {

        @BeforeEach
        void setUp() {
            when(productMapper.toEntity(any())).thenReturn(product);
            when(productRepository.save(any())).thenReturn(product);
            when(productMapper.toDTO(any())).thenReturn(productDto);
            when(responseFactory.createSingleResponse(any())).thenReturn(singleProductResponse);
            result = defaultProductService.createProduct(createProductRequest);
        }

        @Test void shouldMapToEntity() { verify(productMapper).toEntity(createProductRequest); }
        @Test void shouldCallRepositorySave() { verify(productRepository).save(product); }
        @Test void shouldMapToDto() { verify(productMapper).toDTO(product); }
        @Test void shouldCreateResponse() { verify(responseFactory).createSingleResponse(productDto); }
        @Test void shouldReturnResponse() { assertThat(result).isEqualTo(singleProductResponse); }
    }
}
```

**4 solid arrows = 4 verify() tests + 1 assertThat = 5 total tests.**

### Output Format

Structure your response as:

**Step 1: Validate**
- Confirm all UML elements are supported

**Step 2: Classify**
- List elements and their matching definitions

**Step 3: Apply (Design)**

For each file:
- **CREATE mode:** Show full file path + complete file content
- **UPDATE mode:** Show full file path + ONLY the new content to be added. Clearly label: "ADD to existing file"

Generate in this order:
1. Entity/model classes (if new types are needed)
2. Interfaces (one per collaborator + one for the service under test)
3. Test class

**Step 4: Implement**

For each file:
- **CREATE mode:** Show full file path + complete file content
- **UPDATE mode:** Show full file path + ONLY the new method body. Clearly label: "ADD to existing file"

**Step 5: Report**
```
Arrows:          [N] solid arrows parsed
Orchestrators:   [N] participants with outgoing arrows
Pure functions:  [M] leaf node participants (decision table skeletons generated)
Tests:           [N] verify() tests + 1 assertThat() = [N+1] total
Files:           [list of files created/updated]
```

### Human Verification

After code is generated, the human verifies the contract held by checking:

1. **Count arrows in UML. Count `verify()` calls in test. They must match.**
2. Read each `verify()` argument — does it match the UML arrow's argument?
3. Read the `@BeforeEach` setup — does each `when().thenReturn()` match a dashed return arrow?
4. For pure function skeletons — fill in the TODO test cases with real business examples.

This is a 30-second mechanical check, not an hours-long code review. The entire methodology exists to make this moment possible.

### Final Steps

After passing the quality gate:
1. Write files to disk using the appropriate tool per the file_management definition
2. Run `./gradlew test` to verify everything compiles and passes
3. If tests fail, read the error output, fix the issue, and re-run
4. Report the number of files generated/updated and tests that passed