---
name: disc
description: "Transform a precise design (UML sequence diagrams and decision tables) into working code using the DisC methodology"
disable-model-invocation: true
---

You are executing the DisC (Design is Code) methodology. Transform the provided precise design (UML sequence diagrams and decision tables) into working code: first generate tests from the design, then derive implementation from the tests.

## Context

In DisC, the design is the source. Tests are derived from the design. Implementation is derived from the tests. Code is never written directly — it is the last link in a deterministic chain that begins with a human-authored design.

Two kinds of design feed this chain. **Sequence diagrams** specify how orchestrators call collaborators — the structure of behaviour. **Decision tables** specify what pure functions return — the result of behaviour. Each kind has its own deterministic transformation, but both obey the same rule: every element of the design produces exactly one test, and the implementation is whatever makes those tests pass.

**What DisC controls:**
DisC pins the contract — call order, arguments, and data flow for orchestrators; input-output behaviour for pure functions with a filled decision table.

**The two invariants** — every other rule derives from these:

1. **Design element = Test.** Every `call_arrow` in a sequence diagram becomes exactly one `verify_test`. Every row in a `decision_table_file` becomes exactly one leaf test. The count of design elements must equal the count of generated tests.

2. **Implement from tests, not design.** The transformation has two phases separated by a wall. 
   - Phase 1 (design → tests) consumes the sequence diagrams and decision tables. 
   - Phase 2 (tests → implementation) reads only the tests. The design is never consulted during implementation. This two-phase wall ensures the implementation structure matches what the tests demand.

## Concepts

Every later reference uses the exact snake_case name defined here.

### Design Inputs

What the human authors. The first artifacts in the chain.

#### UML elements

- **`call_arrow`** — An arrow from caller to callee representing a method invocation. Labeled with a method call: `A -> B: method(arg)`. May appear as solid (`->`) or plain arrow. Identified by its label format: a method name followed by parentheses.

- **`return_arrow`** — An arrow from callee back to caller representing a returned value. Labeled with a value: `B --> A: value` or `B --> A: value : Type`. May appear as dashed (`-->`) or plain arrow. Identified by direction (back to the original caller) and label format (a value name, no parentheses).

- **`participant`** — A named box in the diagram. By default, the participant name stands for the abstraction. Only when the name is separated by colon, the left is the implementation name, the right is the abstraction's name.

- **`loop_block`** — A `loop` / `end` fragment wrapping one or more arrows.

- **`branch_block`** — An `alt` / `else` / `end` fragment with multiple paths.

- **`throw_arrow`** — A self-arrow (from a `participant` to itself) labeled `<<throws>> ExceptionType`.

**Distinguishing `call_arrow` from `return_arrow`** — when arrow styles are identical, use three signals:

1. **Label format** — A `call_arrow` has parentheses in its label: `method(arg)`. A `return_arrow` has a value name with no parentheses: `result` or `result : Type`.
2. **Direction** — A `call_arrow` goes forward (caller to new callee). A `return_arrow` goes back to the original caller.
3. **Pairing** — A `return_arrow` always follows a `call_arrow` to the same callee and returns to the same caller.

#### Decision-table elements

- **`decision_table_file`** — A `design/<Participant>.decision.md` file with YAML frontmatter (`target`, `input`, `output`, a `target_placement` declaration, optional `config`) and a markdown table of rows. Specifies the input/output behaviour of a `pure function` leaf. Frontmatter and `config:` keys are documented in the `language_profile`.

#### Placement

- **`target_placement`** — A declaration on each design file (both `.puml` and `decision_table_file`) stating where its generated code should live. Every design file carries one; the `language_profile` defines the form. This is a `required_decision`.

#### Profile

- **`language_profile`** — A static reference document at `skills/disc/<language>.md` that owns every language-specific rule the pipeline depends on. SKILL.md is language-neutral; the `language_profile` defines the form of `target_placement`, the recognised `config:` keys, the test/implementation/decision-table templates, file path patterns, naming conventions, UPDATE-mode rules, the build command, and the documented defaults for every `optional_decision`. Step 3a selects which `language_profile` to load based on project signals.

### Subject vs collaborator

Classifies each `participant` by its relationship to the test. Determines instantiation vs mocking.

- **`component_under_test`** — The first `participant` in the diagram. Not mocked. Instantiated in tests.

- **`collaborator`** — Any `participant` other than the `component_under_test`. Mocked in tests. Injected into the `component_under_test` via its constructor.

### Composes calls vs terminal

Classifies each `participant` by its relationship to the call graph. Determines test style.

- **`orchestrator`** — A `participant` that has outgoing `call_arrow`s to other participants. DisC dictates its implementation structure: call order, arguments, and data flow are all fixed by tests.

- **`leaf_node`** — A `participant` with no outgoing `call_arrow`s. Its internal algorithm is unconstrained. DisC verifies its correctness via input/output examples, not its structure. Sub-classified as **`pure function`** (output depends only on inputs), **`side effect`** (touches external systems), or **`factory`** (pass-through to a constructor). The full sub-classification table — including DisC's action per sub-kind — is in the `leaf_node` transformation rule.

### Composition

Derived facts about the design, computed before tests are generated.

- **`interaction`** — One `call_arrow` paired with its optional `return_arrow`. The atomic unit of DisC.

- **`data_pipe`** — A relationship between two consecutive `interaction`s in which the `return_arrow` value of the first becomes an argument of the next.

### Test Outputs

What is generated in Phase 1 (design → tests).

Note: `decision_table` is the *artifact* generated for a `pure function` leaf. `decision_table_file` is the *input* file that may attach to one. They are different concepts on opposite ends of the pipeline.

- **`verify_test`** — A test asserting that a `collaborator` method was called with expected arguments. One `verify_test` per `call_arrow`.

- **`result_test`** — A test asserting that the `component_under_test`'s return value equals an expected value. One `result_test` per final `return_arrow` (the last `return_arrow` back to the `component_under_test`).

- **`stub`** — Configuring what a `collaborator` returns when called. One `stub` per `return_arrow`. Wired in test setup before execution.

- **`data_mock`** — A mock representing a return value or input data. It is NOT a `collaborator`. It does NOT appear in the constructor. It exists only to carry identity through the `data_pipe`.

- **`test_group`** — A scoped collection of tests sharing setup. One `test_group` per method when a `component_under_test` has multiple methods, or one `test_group` per branch when a `branch_block` is present.

- **`decision_table`** — A set of input/output examples for a `leaf_node`. Human-designed, not AI-generated. Each row becomes one test with a direct assertion on the return value.


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

A `participant` with no outgoing `call_arrow`s is a `leaf_node`. Leaves are classified by what kind of work they do at their boundary. DisC recognizes three sub-kinds:

| Sub-kind | Identified by | DisC action |
|---|---|---|
| **pure function** | Output depends only on inputs. Deterministic. | If a `decision_table_file` is attached, generate tests from its filled rows. Otherwise generate a `decision_table` skeleton. Human fills in test cases. |
| **side effect** | Touches external systems (DB, network, clock, queue, filesystem). | Mocked in consumer tests only. No standalone DisC test. Tested via integration, not DisC. |
| **factory** | Name ends in `Factory`. Assumed pass-through to a constructor. | No standalone test. Correctness is transitive through its consumer. |

For `pure function` leaves:
- Tests use direct assertions on return values. No mocks. No `verify_test`s.
- Test cases are marked for human review. AI must NOT invent both test cases and implementation.
- The algorithm is unconstrained — any implementation that passes the `decision_table` is valid.
- When a `decision_table_file` is attached, each row becomes one test with declared-type arguments and assertions. No TODO markers. Exception rows become `assertThatThrownBy` tests.

**Dual testing rule (pure functions only):** In the consumer's test, a `pure function` leaf is still a mocked `collaborator` with `verify_test`s. It also gets its own standalone `decision_table` test. These serve different purposes: the consumer's test verifies orchestration wiring; the `decision_table` verifies computational correctness. `side effect` and `factory` leaves have no standalone DisC test, so dual testing does not apply.


## Constraints

### False positive risk

When AI generates both test cases and implementation for a `leaf_node`, it can produce matching pairs that pass but do not reflect actual requirements. AI writes: test expects X, implementation returns X. But the human needed Y.

Prevention: humans design `decision_table` test cases. AI implements only.

### Dual testing

A `pure function` leaf appears in two places:
1. As a mocked `collaborator` in its consumer's `verify_test`s (testing orchestration).
2. In its own standalone `decision_table` test (testing correctness).

Both are necessary. Neither substitutes for the other. `side effect` and `factory` leaves have no standalone DisC test, so this rule applies only to `pure function` leaves.

### One test, one assertion

Each test contains exactly one `verify_test` OR one `result_test`. Never both. Never multiple. When a test fails, you know exactly which `interaction` broke.

### No logic in tests

Tests contain no conditionals, no loops, no branching. Tests are declarative: setup executes, then each test verifies one thing.

### Prefer explicit return types

Prefer the explicit ` : Type` format over inferring the type from the variable name. Explicit typing eliminates ambiguity and makes the `data_mock` type unambiguous to any reader of the diagram.

### Throw placement

When a `throw_arrow` is present, the method-under-test is called at different places depending on the path:

- **Happy path:** The method is called in setup (before individual tests run).
- **Exception path:** The method is called inside the assertion that expects the exception. If the method were called in setup, the exception would abort setup and no assertions would execute.

### Required vs optional decisions

A `pure function` leaf has decisions about behaviour that the rows may or may not pin down.

- A **`required_decision`** is one DisC will not silently default. If the rows do not demonstrate it AND `config:` does not pin it, Step 1 refuses.
- An **`optional_decision`** is one where DisC applies a documented default silently when the rows are silent.

The lists of which specific decisions are `required_decision` vs `optional_decision` — and the default values for each `optional_decision` — are language-specific and enumerated in the `language_profile`. Defaults are documented once in the `language_profile`; they are not reported per run. Any default can be overridden via `config:`.

## Input

The design provided by the user:

$ARGUMENTS

---

## The Pipeline

Execute these eight steps in order. Each step must be complete before the next begins. Report each step using its `### Step N: <name>` heading from below as the section label in your response.

### Step 1: Validate Inputs

The input set contains at least one `.puml` (UML sequence diagram) and may also contain one or more `decision_table_file`s (`<Participant>.decision.md`).

**For each `.puml`:** parse the diagram. For each element, confirm it matches a concept defined in the Concepts section above:

`participant` · `call_arrow` · `return_arrow` · `loop_block` · `branch_block` · `throw_arrow`

Use the disambiguation rules ("Distinguishing `call_arrow` from `return_arrow`") when arrow styles are identical. Confirm `target_placement` is declared per the `language_profile`'s form.

**For each `decision_table_file`:** parse the YAML frontmatter and the markdown table. Confirm:
- `target:` is present and well-formed (`Class.method`).
- `input:` is present and declares a type for every input column used in the table.
- `output:` is present and declares the method's return type.
- `target_placement` is declared per the `language_profile`'s form.
- Every column header in the markdown table maps to either a declared `input.*` key or an `expected.*` output field.
- Row cell values are coercible to their declared types (string literals quoted, numerics unquoted).
- Exception rows are well-formed: output cell is `throws: <ExceptionType>` (optionally `: "<message>"`).
- At least one row exists.

**Refusal protocol** — if any element is unsupported or ambiguous:

1. **STOP** — do not generate code
2. **EXPLAIN** — describe what is unsupported, referencing the concept definitions
3. **SUGGEST** — propose how to restructure using supported concepts

Refuse when:
- An arrow has no method name label
- A fragment type is not defined (`par`, `critical`, `break` are not supported)
- Circular arrows exist with no clear entry point
- Participant names don't follow naming conventions
- A `decision_table_file` has missing or malformed frontmatter, undeclared column types, or zero rows
- A `decision_table_file`'s `target:` does not resolve to a `pure function` leaf in any UML in the input set (see Step 2 pairing)
- A `decision_table_file` leaves a `required_decision` unspecified AND `config:` does not pin it. The refusal message names the decision and instructs the human to either (a) add a row that demonstrates the choice, or (b) add the corresponding `config:` key (see the `language_profile` for the recognized key for each decision).
- A `decision_table_file`'s `config:` contains a key not enumerated in the `language_profile`. DisC does not silently ignore unknown keys.

### Step 2: Classify

Identify which concepts apply:

1. List all `participant`s → classify each as `component_under_test`, `orchestrator`, or `leaf_node`
2. List all `call_arrow`s → each is an `interaction`
3. Identify `loop_block`s, `branch_block`s, `throw_arrow`s
4. Sub-classify each `leaf_node` by asking: *does its output depend only on inputs, does it touch the world, or is it a pass-through factory?*

| Sub-kind | Identified by | DisC action |
|---|---|---|
| **pure function** | Output depends only on inputs | `decision_table` skeleton (human fills in) — or filled rows when a `decision_table_file` is attached |
| **side effect** | Touches external systems (DB, network, clock, queue, etc.) | Mocked in consumer only — no standalone test |
| **factory** | Name ends in `Factory` | No standalone test — assumed pass-through constructor |

5. Pair each `decision_table_file` with its target `pure function` leaf:
   - Parse the `target: Class.method` frontmatter field.
   - Locate the participant whose interface name matches `Class` across all UMLs in the run. It must be a `leaf_node` sub-classified as `pure function`.
   - Confirm the UML contains a `call_arrow` to that participant with method name `method`.
   - Mark that leaf as **filled**. Record the attached `decision_table_file`.
   - If no match exists, or the matched participant is a `side effect` or `factory`, refuse per Step 1's refusal protocol.

### Step 3: Discover Context

**3a. Detect language/framework** — Determine which `language_profile` to load:

1. If the user specifies a language/framework, use that.
2. Otherwise, detect from project files:

| Signal files | Language profile |
|---|---|
| `build.gradle`, `pom.xml`, `*.java` | `java_spring.md` |

3. If no signal matches or multiple match, ask the user.

Load the matched `language_profile`. All subsequent steps use its conventions.

**3b. Read `target_placement` per design file** — For each design file, read its declared placement using the `language_profile`'s form. Placement is per-file and authored by the human.

**3c. Derive all target file paths** — Use the `language_profile`'s naming conventions, package placement rules, and file path patterns. Each file's `target_placement` anchors the paths derived from its participants and domain types; suffix-based sub-packaging (per the `language_profile`) applies relative to that placement.

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
| `leaf_node` (pure function), no file attached | "leaf_node" | `decision_table` skeleton |
| `leaf_node` (pure function), `decision_table_file` attached | "leaf_node" | Filled tests, one per row |

Use the `language_profile`'s test class template and naming conventions.

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
   - `leaf_node`s classified as `pure function`, `side effect`, or `factory`; standalone tests (pure functions only) use direct assertions, not `verify_test`s
   - `decision_table` skeletons marked TODO for human review (only when no `decision_table_file` is attached)
   - Filled decision-table tests have no TODO markers — every row produces a concrete test
   - For each filled `decision_table_file`, every `required_decision` is either demonstrated by rows or pinned by `config:`. (If it isn't, Step 1 should have refused — this is a belt-and-braces check.)
   - `pure function` leaves both mocked in consumer AND get standalone tests (dual testing); `side effect` and `factory` leaves have no standalone test
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

Use the `language_profile`'s implementation template and conventions.

This enforces Invariant 2: implementation matches what tests demand, not what UML shows.

**For `pure function` leaves with a `decision_table_file` attached:**

The implementation is a deterministic function of three inputs: the rows, the `config:` block, and the documented `optional_decision` values from the `language_profile`.

- Read the rows. They constrain output for every input combination they list.
- Read `config:`. It pins the value for any decision the rows do not demonstrate.
- For any `optional_decision` the rows and `config:` are silent on, apply the `language_profile`'s documented default.
- Do NOT make judgment calls on a `required_decision`. If one is unspecified at this point, Step 1 failed to refuse — stop and re-check Step 1, do not paper over it here.

Write the implementation using these values. There is no per-run audit log; the rules are fixed by the methodology and the `language_profile`.

### Step 7: Write Files

**CREATE mode:** Write tool — complete file.
**UPDATE mode:** Read tool first, then Edit tool — add only, never modify existing.

**Never** use the Write tool on an existing file.

**Critical rule:** Existing content is sacred.

Use the `language_profile`'s UPDATE mode rules per file type.

### Step 8: Report

**Summary:**
```
Arrows:          [N] call_arrows parsed
Orchestrators:   [N] participants with outgoing arrows
Leaf nodes:      [M] total ([P] pure function, [S] side effect, [F] factory)
Decision tables: [K] filled from decision_table_file, [Q] skeletons for humans to fill
Tests:           [N] verify_tests + [R] result_tests = [total] total
Files:           [CREATE/UPDATE labels per file]
```

**Human verification checklist:**
1. Count arrows in UML. Count `verify_test`s in test. Must match.
2. Each `verify_test` argument matches its UML arrow's argument.
3. Each `stub` matches a `return_arrow`.
4. For skeleton decision tables: fill in TODO test cases with real business examples.
5. Each generated file's package matches the `target_placement` declared on its source design file.

**Final steps:**
1. Write files to disk per file mode
2. Run the `language_profile`'s build command
3. If tests fail: read error, fix, re-run
4. Report files and test results
