# Java / Spring Boot Language Profile

All Java/Spring-specific conventions, templates, and examples for the DisC methodology. Referenced by SKILL.md as the "language profile."

---

## Base Package Detection

`{basePackage}` and `{basePackagePath}` appear throughout this profile. Resolve them BEFORE generating any code:

1. Search for the class annotated with `@SpringBootApplication` — its package IS the base package
2. If not found, glob for `src/main/java/**/*.java`, read package statements, and use the common prefix
3. If no Java files exist, check `build.gradle` for `group` or `pom.xml` for `<groupId>`
4. If still unresolvable, ask the user

`{basePackagePath}` is `{basePackage}` with `.` replaced by `/` (e.g., `com.acme.orders` → `com/acme/orders`).

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Interface | PascalCase, from participant name | `OrderService` |
| Implementation class | `Default` + interface name | `DefaultOrderService` |
| Test class | Implementation name + `Test` | `DefaultOrderServiceTest` |
| Test method | `should` + verb phrase describing interaction | `shouldSaveOrder` |
| Mock field (collaborator) | camelCase of interface name | `orderMapper` |
| Mock field (data) | Variable name from return label. Type from explicit `: Type` or PascalCase inference | `savedOrder : Order` → field: `Order savedOrder` |

---

## Package Placement

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

---

## File Path Patterns

| Element | Path |
|---|---|
| Interface | `src/main/java/{basePackagePath}/[package]/[Name].java` |
| Implementation | `src/main/java/{basePackagePath}/[package]/Default[Name].java` |
| Test | `src/test/java/{basePackagePath}/[package]/Default[Name]Test.java` |
| Domain type | `src/main/java/{basePackagePath}/entity/[Type].java` |

---

## Domain Type Exceptions

These are NOT domain types — leave as-is, do not generate interfaces for them:

| Category | Examples |
|---|---|
| Primitives/wrappers | `UUID`, `String`, `Integer`, `Long`, `Boolean` |
| Standard generics | `Optional<T>`, `List<T>`, `Map<K,V>`, `Set<T>` |
| Framework types | Spring, JPA types |
| Boundary carriers | `*Request`, `*Response`, `*DTO` |

Primitives and final classes like `UUID`, `Integer`, `String` cannot be mocked. Use real values: `UUID.randomUUID()`, `(int)(Math.random() * 1000)`.

---

## Test Class Template

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

Mapping to SKILL.md concepts:
- `@Mock` collaborator field = `collaborator` mock
- `@Mock` data field = `data_mock`
- `@Nested` class = `test_group`
- `@BeforeEach` with `when().thenReturn()` = `stub` setup
- `verify()` call = `verify_test`
- `assertThat(result)` = `result_test`

---

## Implementation Template

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

### Implementation Conventions

- Use `@Service` annotation (or `@Component` for non-service classes)
- Constructor injection for all collaborators (no `@Autowired`)
- One method call per `verify()` test, maintaining the order from the test
- Variable names match the mock field names from the test
- Return type matches the `result` field type in the test

---

## Build Command

```
./gradlew test
```

---

## UPDATE Mode Rules

| File type | ADD | Do NOT touch |
|---|---|---|
| Interface | New method signatures (skip if present) | Existing signatures |
| Test | New `@Nested` class + new `@Mock` fields if not declared | Existing `@Nested`, `@Test`, `@Mock`, setup |
| Implementation | New method + new fields + new constructor params | Existing methods, logging, annotations |
| Domain type (EXISTS) | Nothing — skip | Everything |

---

## Decision Table Skeleton (computational `leaf_node`)

```java
class Default[LeafNodeName]Test {

    private [LeafNodeName] [instance] = new Default[LeafNodeName]();

    // TODO: Human must fill in the decision table.
    // DisC CANNOT dictate the implementation of pure functions.
    // Only the human-designed examples constrain the output.

    @Test void shouldHandleBaseCase() {
        assertThat([instance].[method]([baseInput]))
            .isEqualTo([expectedBaseOutput]); // <- Human fills this in
    }

    @Test void shouldHandleEdgeCase() {
        assertThat([instance].[method]([edgeInput]))
            .isEqualTo([expectedEdgeOutput]); // <- Human fills this in
    }
}
```

---

## Walkthrough: Linear Flow

Full pipeline example for a simple linear sequence diagram.

**UML Input:**
```
ProductService -> ProductMapper: toEntity(createProductRequest)
ProductMapper --> ProductService: product
ProductService -> ProductRepository: save(product)
ProductRepository --> ProductService: savedProduct : Product
ProductService -> ProductMapper: toDTO(savedProduct)
ProductMapper --> ProductService: productDto
ProductService -> ProductResponseFactory: createSingleResponse(productDto)
ProductResponseFactory --> ProductService: singleProductResponse
```

**Step 1:** 4 `call_arrow`s, 4 `return_arrow`s. All labeled, all supported.

**Step 2:**
- `ProductService` → `component_under_test`
- `ProductMapper` → `leaf_node` (computational — Mapper)
- `ProductRepository` → `leaf_node` (I/O boundary — Repository)
- `ProductResponseFactory` → `leaf_node` (computational — Factory)
- 4 `interaction`s, all with `return_arrow`s
- `data_pipe`s: `product` → `save` → `savedProduct` → `toDTO` → `productDto` → `createSingleResponse`

**Step 3:** Detect base package. Derive paths. Glob. All NEW → CREATE.

**Step 4:** Apply transformation rules →

```java
@MockitoSettings(strictness = Strictness.LENIENT)
class DefaultProductServiceTest {

    @Mock private ProductRepository productRepository;
    @Mock private ProductMapper productMapper;
    @Mock private ProductResponseFactory responseFactory;

    @Mock private CreateProductRequest createProductRequest;
    @Mock private Product product;
    @Mock private Product savedProduct;
    @Mock private ProductDTO productDto;
    @Mock private SingleProductResponse singleProductResponse;

    private SingleProductResponse result;
    DefaultProductService defaultProductService;

    @BeforeEach
    void setUp() {
        defaultProductService = new DefaultProductService(
            productRepository, productMapper, responseFactory);
    }

    @Nested
    class WhenCreateProduct {
        @BeforeEach
        void setUp() {
            when(productMapper.toEntity(any())).thenReturn(product);
            when(productRepository.save(any())).thenReturn(savedProduct);
            when(productMapper.toDTO(any())).thenReturn(productDto);
            when(responseFactory.createSingleResponse(any())).thenReturn(singleProductResponse);
            result = defaultProductService.createProduct(createProductRequest);
        }

        @Test void shouldMapToEntity() { verify(productMapper).toEntity(createProductRequest); }
        @Test void shouldSaveProduct() { verify(productRepository).save(product); }
        @Test void shouldMapToDto() { verify(productMapper).toDTO(savedProduct); }
        @Test void shouldCreateResponse() { verify(responseFactory).createSingleResponse(productDto); }
        @Test void shouldReturnResponse() { assertThat(result).isEqualTo(singleProductResponse); }
    }
}
```

**Step 5:** Arrow parity: 4 = 4. Data flow: pipes connect. File modes: all CREATE. Patterns: leaf nodes classified.

**Step 6:** Read tests → derive implementation. Each `verify()` → one method call. Pipes flow through.

**Step 8:** 4 arrows, 0 orchestrator collaborators, 2 computational leaf nodes, 5 tests, all files CREATE.

---

## Example: Branching (Update or Create)

Demonstrates `branch_block` → separate `@Nested` classes per branch.

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

**Generated Implementation:**
```java
@Service
public class DefaultOrderService implements OrderService {
    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;

    public DefaultOrderService(OrderRepository orderRepository, OrderMapper orderMapper) {
        this.orderRepository = orderRepository;
        this.orderMapper = orderMapper;
    }

    @Override
    public Order createOrUpdate(UUID orderId, OrderRequest request) {
        Optional<Order> existingOrder = orderRepository.findById(orderId);
        if (existingOrder.isPresent()) {
            Order updatedOrder = orderMapper.updateEntity(existingOrder.get(), request);
            return orderRepository.save(updatedOrder);
        } else {
            Order newOrder = orderMapper.toEntity(request);
            return orderRepository.save(newOrder);
        }
    }
}
```

Each branch: 3 `call_arrow`s = 3 `verify_test`s + 1 `result_test` = 4 tests per branch. Different `stub` setup drives different code paths.

---

## Example: Guard Clause (Validator with Exception)

Demonstrates `throw_arrow` → two `@Nested` classes governed by `throw_placement`.

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
        organizationId = UUID.randomUUID();
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
            // Happy path — method called in @BeforeEach
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
            // Exception path — @BeforeEach only wires mocks, does NOT call method
        }

        @Test
        void shouldThrownException() {
            // Method called INSIDE assertThatThrownBy with .hasMessage()
            assertThatThrownBy(() -> defaultResourceUsageValidator
                .validate(organizationId, resourceId, resourceType))
                .isInstanceOf(ResourceInUseException.class)
                .hasMessage(RESOURCE_IN_USE_ERROR_MESSAGE.formatted(resourceType, resourceId));
        }
    }
}
```

**Three critical rules:**
1. **Method invocation placement:** Happy path calls method in `@BeforeEach`. Exception path calls it inside `assertThatThrownBy`.
2. **`.hasMessage()` verification:** Chain `.hasMessage(CONSTANT.formatted(...))` when the UML specifies a message template.
3. **`protected static final` constant:** Declare the error message as `protected static final String` in the implementation. The test imports it directly.

**Generated Implementation:**
```java
public class DefaultResourceUsageValidator implements ResourceUsageValidator {
    protected static final String RESOURCE_IN_USE_ERROR_MESSAGE = "Resource %s with id %s is currently in use";

    private final ResourceUsageService resourceUsageService;

    public DefaultResourceUsageValidator(ResourceUsageService resourceUsageService) {
        this.resourceUsageService = resourceUsageService;
    }

    @Override
    public void validate(UUID organizationId, String resourceId, String resourceType) {
        List<ResourceUsageDetail> resourceUsages =
            resourceUsageService.getResourceUsages(organizationId, resourceId, resourceType);
        if (!resourceUsages.isEmpty()) {
            throw new ResourceInUseException(
                RESOURCE_IN_USE_ERROR_MESSAGE.formatted(resourceType, resourceId));
        }
    }
}
```

1 `call_arrow` + 1 `throw_arrow` = 1 `verify_test` + 1 exception assertion = 2 total tests.

---

## Example: Loop + Builder (Iteration with Factory)

Demonstrates `loop_block` → single-element collections and real values for primitives.

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

**Key test patterns for loop:**
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

**Rules for loops:**
- Mock inputs use `List.of()` with a single element so iteration executes once
- Primitives and final classes (`UUID`, `Integer`, `String`) use real values, not mocks
- Each `call_arrow` inside the `loop_block` still produces one `verify_test`
- In implementation, the `loop_block` becomes iteration (`.forEach()` or `.stream()`)