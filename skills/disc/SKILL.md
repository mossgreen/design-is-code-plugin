---
name: disc
description: "Transform UML sequence diagrams into working code using the DisC methodology"
disable-model-invocation: true
---

You are executing the DisC (Design is Code) methodology. Transform the provided UML sequence diagram into working code: first generate tests from the UML, then derive implementation from the tests.

## Context

AI generates code in seconds. Humans review code in hours. This asymmetry means AI produces faster than humans can verify — and unverified code is a liability. DisC solves this: the UML is a contract. Each arrow becomes a test. Tests force implementation structure. The human verifies the contract held by counting arrows against tests — a 30-second check, not an hours-long code review.

**What DisC controls:**
DisC constrains **how orchestrators call collaborators** — call order, arguments, data flow.
It does NOT constrain **how pure functions compute their results** — only that they produce
correct output for human-designed inputs.

**What DisC does NOT guarantee:**
DisC verifies the design contract. It does NOT verify runtime correctness (a real repository
throwing, a real mapper transforming incorrectly). Runtime correctness requires integration
tests. DisC and integration tests are complementary, not substitutes.

**The two invariants** — every other rule derives from these:

1. **Arrow = Test.** Every `call_arrow` in the UML becomes exactly one `verify_test`. The count of `call_arrow`s in the diagram must equal the count of `verify_test`s in the generated tests.

2. **Implement from tests, not UML.** The transformation has two phases separated by a wall. Phase 1 (UML → tests) consumes the diagram. Phase 2 (tests → implementation) reads only the tests. The UML is never consulted during implementation. This two-phase wall ensures the implementation structure matches what the tests demand.

### Input

The user's UML sequence diagram:

$ARGUMENTS

---

## Concepts

Every later reference uses the exact snake_case name defined here.

### UML Elements

- **`call_arrow`** — An arrow from caller to callee representing a method invocation. Labeled with a method call: `A -> B: method(arg)`. May appear as solid (`->`) or plain arrow. Identified by its label format: a method name followed by parentheses.

- **`return_arrow`** — An arrow from callee back to caller representing a returned value. Labeled with a value: `B --> A: value` or `B --> A: value : Type`. May appear as dashed (`-->`) or plain arrow. Identified by direction (back to the original caller) and label format (a value name, no parentheses).

- **`participant`** — A named box in the diagram.

- **`loop_block`** — A `loop` / `end` fragment wrapping one or more arrows.

- **`branch_block`** — An `alt` / `else` / `end` fragment with multiple paths.

- **`throw_arrow`** — A self-arrow (from a `participant` to itself) labeled `<<throws>> ExceptionType`.

### Distinguishing `call_arrow` from `return_arrow`

When arrow styles are identical, use three signals:

1. **Label format** — A `call_arrow` has parentheses in its label: `method(arg)`. A `return_arrow` has a value name with no parentheses: `result` or `result : Type`.
2. **Direction** — A `call_arrow` goes forward (caller to new callee). A `return_arrow` goes back to the original caller.
3. **Pairing** — A `return_arrow` always follows a `call_arrow` to the same callee and returns to the same caller.

### Participant Roles

- **`component_under_test`** — The first `participant` in the diagram. Not mocked. Instantiated in tests.

- **`collaborator`** — Any `participant` other than the `component_under_test`. Mocked in tests. Injected into the `component_under_test` via its constructor.

- **`orchestrator`** — A `participant` that has outgoing `call_arrow`s to other participants. DisC dictates its implementation structure: call order, arguments, and data flow are all fixed by tests.

- **`leaf_node`** — A `participant` with no outgoing `call_arrow`s. Its internal algorithm is unconstrained. DisC verifies its correctness via input/output examples, not its structure.

### Test Concepts

- **`interaction`** — One `call_arrow` paired with its optional `return_arrow`. The atomic unit of DisC.

- **`verify_test`** — A test asserting that a `collaborator` method was called with expected arguments. One `verify_test` per `call_arrow`.

- **`result_test`** — A test asserting that the `component_under_test`'s return value equals an expected value. One `result_test` per final `return_arrow` (the last `return_arrow` back to the `component_under_test`).

- **`stub`** — Configuring what a `collaborator` returns when called. One `stub` per `return_arrow`. Wired in test setup before execution.

- **`data_mock`** — A mock representing a return value or input data. It is NOT a `collaborator`. It does NOT appear in the constructor. It exists only to carry identity through the `data_pipe`.

- **`test_group`** — A scoped collection of tests sharing setup. One `test_group` per method when a `component_under_test` has multiple methods, or one `test_group` per branch when a `branch_block` is present.

- **`decision_table`** — A set of input/output examples for a `leaf_node`. Human-designed, not AI-generated. Each row becomes one test with a direct assertion on the return value.

### Data Flow

- **`data_pipe`** — The `return_arrow` value of one `interaction` becomes the argument of the next `interaction`. When a `return_arrow` labels a value `x`, and a subsequent `call_arrow` uses `x` as an argument, those two `interaction`s are connected by a `data_pipe`.

### Exception Handling

- **`throw_placement`** — The rule governing where the method-under-test is called when a `throw_arrow` is present:
  - **Happy path:** The method is called in setup (before individual tests run).
  - **Exception path:** The method is called inside the assertion that expects the exception. If the method were called in setup, the exception would abort setup and no assertions would execute.

---

## Transformation Rules

Each rule describes how a UML element transforms into test and implementation constructs, using only the concepts defined above.

### `participant` to role

The first `participant` is the `component_under_test`. It is instantiated in test setup via constructor injection of all `collaborator`s.

Every other `participant` is a `collaborator`. Each `collaborator` becomes a mock in the test and a constructor parameter of the `component_under_test`.

### `interaction` with `return_arrow`

An `interaction` that has a `return_arrow` produces:
- One `stub` in setup: configure the `collaborator` to return a `data_mock` when called.
- One `verify_test`: assert the `collaborator` was called with the expected argument.

The `return_arrow` label determines the `data_mock` name and type:
- **Explicit format** `value : Type` — Split on ` : `. Left side is the variable name. Right side is the type.
- **Inferred format** `value` — The variable name is the label. The type is inferred by capitalizing the first letter of each word (e.g., `product` becomes type `Product`).
- Prefer explicit format. It eliminates ambiguity (e.g., `savedOrder : Order` is clear, while inferring a type name from `savedOrder` alone is not).

### `interaction` without `return_arrow` (void)

A `call_arrow` with no following `return_arrow` produces:
- No `stub` (nothing to configure).
- One `verify_test`: assert the `collaborator` was called with the expected argument.

### Final `return_arrow`

The last `return_arrow` back to the `component_under_test` produces:
- A result variable in the test to capture the return value.
- The method-under-test is called in test setup, and its return value is stored.
- One `result_test`: assert the captured result equals the expected `data_mock`.

In implementation, this becomes the method's return statement.

### `data_pipe`

When a `return_arrow` labels its value `x`, and a subsequent `call_arrow` uses `x` as an argument, the `data_mock` named `x` flows from the `stub` of the first `interaction` into the `verify_test` of the second `interaction`.

In implementation, this means the return value of one method call is passed as the argument to the next method call.

### `loop_block`

A `loop_block` wrapping one or more arrows transforms as follows:
- Test data uses a single-element collection so iteration executes once.
- Each `call_arrow` inside the `loop_block` still produces one `verify_test`, verified for the single element.
- In implementation, the `loop_block` becomes an iteration construct over the collection.

### `branch_block`

An `alt` / `else` / `end` fragment with multiple paths transforms as follows:
- Each branch becomes a separate `test_group` with its own setup.
- Each `test_group` configures `stub`s that drive execution down that specific branch.
- Each branch has its own `verify_test`s matching only that branch's `call_arrow`s.
- The method-under-test is called in each branch's `test_group` setup independently.
- In implementation, the `branch_block` becomes a conditional.

### `throw_arrow`

A self-arrow labeled `<<throws>> ExceptionType` produces two `test_group`s governed by the `throw_placement` rule:

**Happy path `test_group`:**
- `stub`s are configured to avoid the exception condition.
- The method-under-test is called in shared test setup (before individual tests run).
- `verify_test`s assert `collaborator` calls happened.

**Exception path `test_group`:**
- `stub`s are configured to trigger the exception condition.
- The method-under-test is NOT called in shared test setup. It is called inside the test that asserts the exception is thrown.
- The test asserts both the exception type and (when specified in the UML) the exception message.

When the UML specifies a message template in the `throw_arrow`:
- The error message is declared as a constant in the implementation.
- The test references that constant directly — single source of truth, no string duplication.

### `leaf_node`

A `participant` with no outgoing `call_arrow`s is a `leaf_node`. It is classified into one of two sub-types:

| Sub-type | Characteristics | DisC action |
|---|---|---|
| **Computational** | Computes results from inputs (mappers, factories, calculators, converters, builders) | Generate a `decision_table` skeleton. Human fills in test cases. |
| **I/O boundary** | Interacts with external systems (repositories, clients, gateways, adapters) | Mocked in consumer tests only. No standalone DisC test. I/O boundary leaf nodes are tested via integration tests, not DisC. |

For computational `leaf_node`s:
- Tests use direct assertions on return values. No mocks. No `verify_test`s.
- Test cases are marked for human review. AI must NOT invent both test cases and implementation.
- The algorithm is unconstrained — any implementation that passes the `decision_table` is valid.

**Dual testing rule:** In the consumer's test, a `leaf_node` is still a mocked `collaborator` with `verify_test`s. It also gets its own standalone `decision_table` test. These serve different purposes: the consumer's test verifies orchestration wiring; the `decision_table` verifies computational correctness.

---

## Constraints

### N-path complexity

If a `branch_block` nests 3 or more levels deep, the transformation breaks down. The number of `test_group`s grows exponentially. This is a design smell, not a DisC limitation. The remedy is to refactor the design using patterns that flatten branching (strategy, factory, resolver) before applying DisC.

### False positive risk

When AI generates both test cases and implementation for a `leaf_node`, it can produce matching pairs that pass but do not reflect actual requirements. AI writes: test expects X, implementation returns X. But the human needed Y.

Prevention: humans design `decision_table` test cases. AI implements only.

### Dual testing

A `leaf_node` appears in two places:
1. As a mocked `collaborator` in its consumer's `verify_test`s (testing orchestration).
2. In its own standalone `decision_table` test (testing correctness).

Both are necessary. Neither substitutes for the other.

### One test, one assertion

Each test contains exactly one `verify_test` OR one `result_test`. Never both. Never multiple. When a test fails, you know exactly which `interaction` broke.

### No logic in tests

Tests contain no conditionals, no loops, no branching. Tests are declarative: setup executes, then each test verifies one thing.

### `return_arrow` label parsing

Prefer the explicit ` : Type` format over inferring the type from the variable name. Explicit typing eliminates ambiguity and makes the `data_mock` type unambiguous to any reader of the diagram.

---

## The Pipeline

Execute these eight steps in order. Each step must complete before the next begins.

### Step 1: Validate UML

Parse the input diagram. For each element, confirm it matches a concept defined in the Concepts section above:

`participant` · `call_arrow` · `return_arrow` · `loop_block` · `branch_block` · `throw_arrow`

Use the disambiguation rules ("Distinguishing `call_arrow` from `return_arrow`") when arrow styles are identical.

**Refusal protocol** — if any element is unsupported or ambiguous:

1. **STOP** — do not generate code
2. **EXPLAIN** — describe what is unsupported, referencing the concept definitions
3. **SUGGEST** — propose how to restructure using supported concepts

Refuse when:
- An arrow has no method name label
- A fragment type is not defined (`par`, `critical`, `break` are not supported)
- Circular arrows exist with no clear entry point
- Participant names don't follow naming conventions

### Step 2: Classify

Identify which concepts apply:

1. List all `participant`s → classify each as `component_under_test`, `orchestrator`, or `leaf_node`
2. List all `call_arrow`s → each is an `interaction`
3. Identify `loop_block`s, `branch_block`s, `throw_arrow`s
4. Sub-classify each `leaf_node`:

| Sub-type | Name ends in... | DisC action |
|---|---|---|
| **Computational** | Mapper, Factory, Calculator, Converter, Builder | `decision_table` skeleton (human fills in) |
| **I/O boundary** | Repository, Client, Gateway, Adapter | Mocked in consumer only — no standalone test |

### Step 3: Discover Context

**3a. Detect language/framework** — Determine which language profile to load:

1. If the user specifies a language/framework, use that.
2. Otherwise, detect from project files:

| Signal files | Language profile |
|---|---|
| `build.gradle`, `pom.xml`, `*.java` | `java_spring.md` |

3. If no signal matches or multiple match, ask the user.

Load the matched language profile. All subsequent steps use its conventions.

**3b. Detect base package** — Follow the language profile's base package detection rules.

**3c. Derive all target file paths** — Use the language profile's naming conventions, package placement rules, and file path patterns to derive paths from participant names and domain types in `return_arrow` labels.

**3d. Check file existence** — Glob all target paths.

**3e. For each existing file:** read it, identify what's already there (mocks, test groups, methods, signatures).

**3f. Set mode per file:** NEW → **CREATE**, EXISTS → **UPDATE**

### Step 4: Generate (apply Transformation Rules)

For each classified element, apply its transformation rule from the Transformation Rules section above:

| Element | Rule | Produces |
|---|---|---|
| `participant` | "participant to role" | Mocks, constructor wiring |
| `interaction` + `return_arrow` | "interaction with return_arrow" | `stub` + `verify_test` |
| `interaction` (void) | "interaction without return_arrow" | `verify_test` only |
| Final `return_arrow` | "Final return_arrow" | `result_test` |
| `data_pipe` | "data_pipe" | Return value → next argument |
| `loop_block` | "loop_block" | Single-element collection, iteration |
| `branch_block` | "branch_block" | Separate `test_group` per branch |
| `throw_arrow` | "throw_arrow" | Two `test_group`s with `throw_placement` |
| `leaf_node` (computational) | "leaf_node" | `decision_table` skeleton |

Use the language profile's test class template and naming conventions.

**Generation order:** domain types → interfaces → tests → `decision_table` skeletons

### Step 5: Quality Gate

Before writing anything, pass every check. Fix generated code if any check fails.

**Self-reflection protocol:** Iterate your output until you rate it 10/10 against an internal rubric before proceeding. Do not infer patterns not defined in this methodology.

**Four critical checks:**

1. **Arrow parity** — `call_arrow` count == `verify_test` count. Each `stub` has a corresponding `return_arrow`. The `result_test` matches the final return value.

2. **Data flow integrity** — Each `data_pipe` connects correctly. Implementation call order matches `verify_test` order. Variable names match `data_mock` names.

3. **File mode correctness** — Step 3 discovery complete. CREATE → Write tool. UPDATE → Edit tool. No existing content modified, moved, or deleted. No duplicate mock fields or test groups.

4. **Pattern rules:**
   - Every `collaborator` has a mock field; constructor includes all `collaborator`s and only `collaborator`s
   - Every `data_mock` has a mock field (or real value for primitives/final classes)
   - `throw_placement` correct (exception path calls method inside assertion, not in setup)
   - Error message constants declared in implementation, referenced by test
   - `leaf_node`s classified (computational vs I/O); standalone tests use direct assertions, not `verify_test`s
   - `decision_table` skeletons marked TODO for human review
   - `leaf_node`s both mocked in consumer AND get standalone tests (dual testing)
   - Each `branch_block` has one `test_group` per branch with branch-specific `stub` setup
   - `loop_block` test data uses single-element collection
   - Primitives/final classes use real values, not mocks

### Step 6: Implement (two-phase wall)

**Re-read the test file. Do NOT reference the UML diagram.**

Derive implementation entirely from the tests:

1. Each `verify_test` → one method call in implementation, in order
2. Each `stub` chain → capture return value, pass through `data_pipe`
3. Return statement produces the value `result_test` expects
4. Apply file mode from Step 3

Use the language profile's implementation template and conventions.

This enforces Invariant 2: implementation matches what tests demand, not what UML shows.

### Step 7: Write Files

**CREATE mode:** Write tool — complete file.
**UPDATE mode:** Read tool first, then Edit tool — add only, never modify existing.

> **Never** use the Write tool on an existing file.

**Critical rule:** Existing content is sacred.

Use the language profile's UPDATE mode rules per file type.

### Step 8: Report

**Summary:**
```
Arrows:          [N] call_arrows parsed
Orchestrators:   [N] participants with outgoing arrows
Leaf nodes:      [M] leaf nodes (decision_table skeletons: [count])
Tests:           [N] verify_tests + [R] result_tests = [total] total
Files:           [CREATE/UPDATE labels per file]
```

**Human verification checklist:**
1. Count arrows in UML. Count `verify_test`s in test. Must match.
2. Each `verify_test` argument matches its UML arrow's argument.
3. Each `stub` matches a `return_arrow`.
4. Fill in `decision_table` TODO test cases with real business examples.

**Final steps:**
1. Write files to disk per file mode
2. Run the language profile's build command
3. If tests fail: read error, fix, re-run
4. Report files and test results

---

## File Management Reference

### Domain Type Rule

Any type in an interface method signature that represents a domain concept is generated as an **interface**, not a class. This enforces Dependency Inversion.

**Not domain types (leave as-is):** Primitives/wrappers, standard generics, framework types, boundary carriers (`*Request`, `*Response`, `*DTO`). See the language profile for language-specific exceptions.

> Domain type EXISTS as class: do not convert to interface. Warn in report.

---

## Output Format

Structure your response with these section headers:

1. **Step 1: Validate** — Confirm all UML elements supported
2. **Step 2: Classify** — List elements and classifications
3. **Step 3: Discover** — Base package, file paths, CREATE/UPDATE modes
4. **Step 4: Generate** — Files with content:
   - CREATE: full path + complete content
   - UPDATE: full path + new content only, labeled "ADD to existing file"
   - Order: domain types → interfaces → tests → `decision_table` skeletons
5. **Step 5: Quality Gate** — Show four checks passing
6. **Step 6: Implement** — Files with content (same CREATE/UPDATE labeling)
7. **Step 7: Write** — Files written to disk
8. **Step 8: Report** — Summary + human verification checklist
