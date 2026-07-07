---
name: disc
description: "Transform a precise design (UML sequence diagrams and decision tables) into working code using the DisC methodology"
disable-model-invocation: true
---

You are executing the DisC (Design is Code) methodology. Transform the provided precise design (UML sequence diagrams and decision tables) into working code: first generate tests from the design, then derive implementation from the tests.

## Context

In DisC the design is the source: design → tests → implementation. Tests are derived from the design, implementation from the tests; code is never written directly.

Two kinds of design feed the chain:

1. **Sequence diagrams** specify how orchestrators call collaborators — the structure of behaviour. DisC pins call order, arguments, and data flow.
2. **Decision tables** specify what pure functions return — the result of behaviour. DisC pins the output at every listed row and the location of every declared `boundary`.

Each kind has its own deterministic transformation; both obey one rule: every design element produces exactly one test, and the implementation is whatever makes those tests pass.

**The two invariants** — every other rule derives from these:

1. **Design element = Test.** Every `call_arrow` in a sequence diagram becomes exactly one `verify_test`. Every row in a `decision_table_file` becomes exactly one leaf test. The count of design elements must equal the count of generated tests.

2. **Implement from tests, not design.** The transformation has two phases separated by a wall.
   - Phase 1 (design → tests) consumes the sequence diagrams and decision tables.
   - Phase 2 (tests → implementation) reads only the tests. The design is never consulted during implementation. This two-phase wall ensures the implementation structure matches what the tests demand.
   - Within a single generation context the wall is a discipline, not a mechanism — the mind that read the design also writes the implementation. Hosts can make it mechanical by running Phase 2 in a separate context that receives only the tests.

Generated tests are **born green**: test and implementation are co-projected from one design, so a green build at generation time verifies faithful transcription, not design correctness. Their full regression value activates when the design changes (`regenerate:`, `extend:`) or code is hand-edited.

**What DisC guarantees — and what stays yours:**

| Artifact | DisC guarantees (enforced at) | Defaulted (reported) | You still own |
|---|---|---|---|
| Orchestrator — CREATE / REGEN | Call order, arguments, data flow (Step 5 checks 1–2; Step 8 build) | — | Diagram completeness and argument intent (checklist 1–2; REGEN: checklist 8) |
| Filled leaf / variant — numeric inputs | Output at every listed row (Step 4); every declared `boundary`'s location (Step 1 bracketing; Step 6 pinning) | `optional_decision` defaults (Step 8 `Applied defaults` line) | Thresholds never declared (checklist 7); the rows' business correctness |
| Filled leaf / variant — finite inputs (enum, boolean) | Output at every listed row (Step 4); coverage of every domain value (Step 1 `finite_domain_coverage`) | `optional_decision` defaults (Step 8 `Applied defaults` line) | The rows' business correctness; coverage when the type is unenumerable (checklist 9) |
| Skeleton leaf / variant | Compile-safe structure, TODO-marked (Step 5 pattern rules) | — | Every test case (checklist 4) |
| Side-effect / factory leaf | Consumer wiring only (Step 5 check 1) | — | Internals — integration tests, outside DisC (`leaf_node` rule) |
| Deferred participant — STUB | Interface + throwing stub, CI-greppable (Step 6 STUB rule) | — | The child `.puml` design — a later DisC run (Step 8 summary) |

Never verified by DisC: that the design matches the business intent; a REUSE collaborator's semantics beyond its compile-checked signature.

## Concepts

Every later reference uses the exact snake_case name defined here.

### Design Inputs

What the human authors. The first artifacts in the chain.

#### UML elements

- **`call_arrow`** — An arrow from caller to callee representing a method invocation. Labeled with a method call: `A -> B: method(arg)`. May appear as solid (`->`) or plain arrow. Identified by its label format: a method name followed by parentheses.

- **`return_arrow`** — An arrow from callee back to caller representing a returned value. Labeled with a value: `B --> A: value`,`A <-- B: value` or `B --> A: value : Type`. May appear as dashed (`-->`) or plain arrow. Identified by direction (back to the original caller) and label format (a value name, no parentheses).

- **`participant`** — A named box in the diagram. By default, the participant name stands for the abstraction. When the name is separated by colon, the left is the implementation name and the right is the abstraction's name. When a `participant_target` stereotype is attached (defined in the Composition block below), the name becomes a local handle and the class identity comes from the stereotype (FQN for REUSE/UPDATE, sibling-folder path for DEFER). See `entity_declaration` for the data-side parallel — entities are passed *through* participants, not called *by* them.

- **`loop_block`** — A `loop` / `end` fragment wrapping one or more arrows.

- **`branch_block`** — An `alt` / `else` / `end` fragment with multiple paths.

- **`throw_arrow`** — A self-arrow (from a `participant` to itself) tagged as a throw declaration.

- **`system_caller`** — The fixed boundary marker for the entry into the system under test. Stands in for the test harness in DisC tests and for the framework (HTTP, message queue, scheduled trigger) in production. It is **not** a `participant`: it has no abstraction, no implementation, no class to generate, and it is never instantiated, mocked, or placed in a constructor. It exists in the design only to be the caller of the **entry interaction** (and, optionally, the callee of the final return). Exactly one `system_caller` per diagram. The notation used to write the `system_caller` is owned by the `language_profile`.

**Distinguishing `call_arrow` from `return_arrow`** — when arrow styles are identical, use three signals:

1. **Label format** — A `call_arrow` has parentheses in its label: `method(arg)`. A `return_arrow` has a value name with no parentheses: `result` or `result : Type`.
2. **Direction** — A `call_arrow` goes forward (caller to new callee). A `return_arrow` goes back to the original caller.
3. **Pairing** — A `return_arrow` always follows a `call_arrow` to the same callee and returns to the same caller.

#### Decision-table elements

- **`decision_table_file`** — A `<Participant>.decision.md` file (sibling of the `.puml` that uses it) with YAML frontmatter (`target`, `input`, `output`, a `target_placement` declaration, optional `config`) and a markdown table of rows. Specifies the input/output behaviour of a `pure function` leaf. Frontmatter and `config:` keys are documented in the `language_profile`.

- **`variant_decision_table`** — A `decision_table_file` whose `target: Variant.method` resolves to a permit record's override of a `sealed_family` behavior. Distinct pairing rule from the standard `decision_table_file` → `pure function` leaf pairing (see Step 2.8): the target resolves to an *entity permit*, not a *leaf participant*. When attached, the variant's override body is filled from rows; when absent, the override is generated in skeleton mode (throws a marker exception; a skeleton test is emitted).

- **`boundary`** — A declared threshold on a numeric input column of a `decision_table_file`: a point in that input's domain where the expected behaviour changes (e.g. quantity ≥ 5 switches the discount tier). Declared in the table's frontmatter; syntactic form owned by the `language_profile`. Every declared `boundary` must be *demonstrated* by a **bracketing pair**: one row at the largest adjacent value below the boundary (adjacency per the `language_profile`'s rule for the column's type) and one row at exactly the boundary, all other input columns held equal, with differing expected outputs. Enforced at Step 1, pinned at Step 6; undeclared thresholds are checklist 7's duty (see Interpolation risk).

- **`finite_domain_coverage`** — The finite-domain counterpart of `boundary`. An input column whose declared type has a finite domain (enum, boolean — the `language_profile` owns the list and how values are enumerated) must be **covered**: every value of the domain appears in at least one row. On a finite domain there is no between-rows space, so full coverage pins the behaviour completely. Nothing is declared — the domain is read from the type. Enforced at Step 1 (the refusal lists the missing values; a `throws:` row records a value the business rules out). A column whose type DisC cannot enumerate is exempt and falls to checklist 9.

#### Entity elements

A parallel taxonomy to `participant`. Entities are **data** nodes (passed through `data_pipe`s); participants are **behavioral** nodes (called via `call_arrow`s). Entities are never mocked at the SUT level and never appear in any constructor as a `collaborator` — they show up in tests only as `data_mock`s the orchestrator passes between collaborator interactions.

- **`entity_declaration`** — A line in the `.puml` prelude declaring a domain type the participants pass through `data_pipe`s. Five kinds, one form per line: `record`, `enum`, `class`, `interface`, `sealed-interface`. The syntactic form is owned by the `language_profile`.

- **`entity_prelude`** — The block of `entity_declaration`s between the `target_placement` header and the participant prelude, preceded by a marker the `language_profile` defines. **Optional** — when absent, every type referenced in a method signature that is neither a `language_profile`-recognised standard type nor a participant is generated as a plain class under the language profile's entity package. When present, declared entities win over inferred ones for the same name.

Per-entity configuration (`entity_target`) and derived/composite entity concepts (`sealed_family`) live in the **Composition** section below, alongside their participant-side counterparts.

#### Placement

- **`target_placement`** — A declaration on each design file (both `.puml` and `decision_table_file`) stating where its generated code should live. Every design file carries one; the `language_profile` defines the form. This is a `required_decision`.

#### Profile

- **`language_profile`** — A static reference document at `skills/disc/<language>.md` that owns every language-specific rule the pipeline depends on. SKILL.md is language-neutral; the `language_profile` defines the form of `target_placement`, the recognised `config:` keys, the test/implementation/decision-table templates, file path patterns, naming conventions, UPDATE-mode rules, the build command, and the documented defaults for every `optional_decision`. Step 3a selects which `language_profile` to load based on project signals.

### Participant roles

Each `participant` plays one of two roles. The role determines instantiation, mocking, and constructor membership.

- **`component_under_test`** — The subject of the test. The `participant` that the `system_caller` calls. Instantiated in test setup via constructor injection of all `collaborator`s. Not mocked.

- **`collaborator`** — Every other `participant`. Mocked in tests. Injected into the `component_under_test` via its constructor.

### Call-graph role

Classifies each `participant` by its relationship to the call graph. Determines test style.

- **`orchestrator`** — A `participant` that has outgoing `call_arrow`s to other participants. DisC dictates its implementation structure: call order, arguments, and data flow are all fixed by tests.

- **`leaf_node`** — A `participant` with no outgoing `call_arrow`s. Its internal algorithm is unconstrained. DisC verifies its correctness via input/output examples, not its structure. Sub-classified as **`pure function`** (output depends only on inputs), **`side effect`** (touches external systems), or **`factory`** (pass-through to a constructor). The full sub-classification table — including DisC's action per sub-kind — is in the `leaf_node` transformation rule.

### Composition

Derived facts about the design, computed before tests are generated.

- **`interaction`** — One `call_arrow` paired with its optional `return_arrow`. The atomic unit of DisC. The interaction whose caller is the `system_caller` is the **entry interaction** — it declares the public method-under-test and produces no `verify_test` (the test harness's call into the SUT is not something to verify). Every other interaction is a **collaborator interaction** and produces a `verify_test`.

- **`data_pipe`** — A relationship between two consecutive `interaction`s in which the `return_arrow` value of the first becomes an argument of the next.

- **`participant_target`** — A declaration on a `participant` that tells DisC whether to CREATE it as a new abstraction, REUSE an existing type as-is, UPDATE an existing type by adding methods, DEFER its design to a separate `.puml`, or REGENERATE an existing orchestrator's implementation wholesale from the design. Absent by default (meaning `create`). Five mutually-exclusive forms:

  - **`create`** (default when no stereotype is declared on the participant): generate the interface, implementation, and tests for this participant under the file's `target_placement`.
  - **`existing:<fqn>`**: this participant is already implemented at the fully-qualified name `<fqn>`. DisC does not generate files for it; it appears only as a `collaborator` mock and constructor parameter. A participant declared as `existing` must have no outgoing `call_arrow`s (REUSE means as-is — no behavioural change).
  - **`extend:<fqn>:+method1,+method2,...`**: this participant exists at `<fqn>` but the design adds the listed methods. DisC opens the existing files (interface, implementation, test) in UPDATE mode and adds only the listed signatures.
  - **`defer:<relative_puml_path>`**: this participant is called by the SUT but its internals have not yet been designed; design them later in their own `.puml` at the given path. DisC generates the interface plus a throwing stub-implementation now, with no test class and no decision table. The actual implementation will come from running DisC on the child `.puml`. Like `existing:`, a `defer:` participant must have no outgoing `call_arrow`s in *this* diagram — its outgoing calls live in its own `.puml`. The path is optional in the stereotype; absent, the profile defaults to a sibling-folder convention (see `language_profile`).
  - **`regenerate:<fqn>`**: this participant exists at `<fqn>` and is an `orchestrator` (it has outgoing `call_arrow`s) whose design has changed. DisC overwrites its implementation and test **wholesale** from the current design — not add-only — because an orchestrator's implementation is fully determined by its design (structure is determined), so it is a pure artifact with nothing hand-authored to preserve. For that premise to hold by construction, a regenerable orchestrator keeps cross-cutting concerns — transactions, tracing, metrics, guards — out of its method bodies: at class level, in aspects, or in configuration (placement rules owned by the `language_profile`); a concern hand-edited into a method body is lost on regeneration. Its `collaborator`s — especially `leaf_node`s — are never overwritten; they follow their own `participant_target`. This is what keeps *design is the source* true after the first generation: when an orchestrator's design changes, the artifact is regenerated, not hand-patched. Unlike `existing:` and `defer:`, a `regenerate:` participant MUST have outgoing `call_arrow`s. Because regeneration overwrites from the design, the diagram MUST describe this orchestrator's complete flow — every `call_arrow` it makes — or the regenerated implementation will omit the missing calls (see Step 7).

  Exactly one form per participant. The syntactic form of the stereotype is owned by the `language_profile`. The abstract concept defines what each declaration *means*; the profile defines how it *looks* in the diagram.

  **One-hop mocking invariant.** The SUT's test always mocks its direct `collaborator`s as units, regardless of their `participant_target`. A `collaborator`'s own dependencies (its grandchildren in the call tree) never bubble up to the SUT's test. This is true for `create`, `existing:`, `extend:`, `defer:`, and `regenerate:` alike — each `collaborator` is one mock at the SUT's level.

  **Direction of flow.** DisC is *outside-in* for interfaces and *inside-out* for implementations. A participant's interface is pinned by its callers' `call_arrow`s — the leaf does not author its own contract. Implementation flows the other way: each leaf is implemented from its own tests in isolation, and the orchestrator's implementation composes them. In a multi-level design (`defer:` participants), this convention spans `.puml` files: each child's interface is locked by the parent's call signatures (validated by the host's `contractHash`), and host tools build the tree bottom-up so an orchestrator is built only after its leaves' real implementations exist.

- **`entity_target`** — Per-entity analog of `participant_target`. Two forms:

  - **`create`** (default, no stereotype): generate the entity's file under the `language_profile`'s entity-package convention.
  - **`existing:<fqn>`**: the entity already exists at `<fqn>`. DisC generates no file; it reads the existing source for its shape (fields for a record, permits for a sealed-interface) so downstream codegen can reference it. A REUSE entity carries the FQN binding only — declaring body content on a REUSE entity refuses at Step 1.

  `extend` and `defer` from `participant_target` do not apply to entities.

- **`sealed_family`** — A `sealed-interface` `entity_declaration` paired with a `permits` list. Permits each resolve to a `record` or `class` entity in the same `entity_prelude`. Sealed families host **sealed polymorphism** variance: the parent declares one or more behaviors, and each permit produces an override. A sealed family with `< 2` permits refuses at Step 1 (the `sealed-interface` kind models closed disjoint unions; with one permit there is no choice — declare the variant directly as a `record` or `class`).

### Test Outputs

What is generated in Phase 1 (design → tests).

Note: `decision_table` is the *artifact* generated for a `pure function` leaf. `decision_table_file` is the *input* file that may attach to one. They are different concepts on opposite ends of the pipeline.

- **`verify_test`** — A test asserting that a `collaborator` method was called with expected arguments. One `verify_test` per `call_arrow`.

- **`result_test`** — A test asserting that the `component_under_test`'s return value equals an expected value. One `result_test` per final `return_arrow` (the `return_arrow` back to the `system_caller`). Absent when the method-under-test returns void.

- **`stub`** — Configuring what a `collaborator` returns when called. One `stub` per `return_arrow`. Wired in test setup before execution.

- **`data_mock`** — A mock representing a return value or input data. It is NOT a `collaborator`. It does NOT appear in the constructor. It exists only to carry identity through the `data_pipe`.

- **`test_group`** — A scoped collection of tests sharing setup. One `test_group` per method when a `component_under_test` has multiple methods, or one `test_group` per branch when a `branch_block` is present.

- **`decision_table`** — A set of input/output examples for a `leaf_node`. Human-designed, not AI-generated. Each row becomes one test with a direct assertion on the return value.


## Transformation Rules

Each rule describes how a UML element transforms into test and implementation constructs, using only the concepts defined above.

### `participant` to role

The `participant` called by the `system_caller` is the `component_under_test`. It is instantiated in test setup via constructor injection of all `collaborator`s.

Every other `participant` is a `collaborator`. Each `collaborator` becomes a mock in the test and a constructor parameter of the `component_under_test`.

### Entry interaction

The `interaction` whose caller is the `system_caller` is the **entry interaction**. It declares the method-under-test:

- The `call_arrow`'s label is the method name and parameter list invoked on the `component_under_test`.
- The arguments named in the label become the parameters of the method-under-test. They are `data_pipe` sources available to subsequent interactions.
- The optional `return_arrow` back to the `system_caller` is the explicit final return (see "Final `return_arrow`").

The entry interaction produces no `verify_test`. There is nothing to verify — the call is the test's invocation of the SUT, not an outbound call from the SUT.

How the method name, parameter types, and return type are derived from the entry interaction's label is owned by the `language_profile`. SKILL.md establishes the role and the structural rule; the profile owns the syntactic and type-resolution details.

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

A `return_arrow` from the `component_under_test` back to the `system_caller` produces:
- A result variable in the test to capture the return value.
- The method-under-test is called in test setup, and its return value is stored.
- One `result_test`: assert the captured result equals the expected `data_mock`.

In implementation, this becomes the method's return statement.

When this `return_arrow` is absent, the method-under-test returns void: no `result_test`, and the implementation method declares a void return.

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

A `throw_arrow` (self-arrow tagged as a throw declaration) produces two `test_group`s governed by the `throw_placement` rule:

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
- When a `decision_table_file` is attached, each row becomes one test with declared-type arguments and assertions. No TODO markers. Exception rows become exception-assertion tests (the assertion construct is owned by the `language_profile`).

**Dual testing rule (pure functions only):** In the consumer's test, a `pure function` leaf is still a mocked `collaborator` with `verify_test`s. It also gets its own standalone `decision_table` test. These serve different purposes: the consumer's test verifies orchestration wiring; the `decision_table` verifies computational correctness. `side effect` and `factory` leaves have no standalone DisC test, so dual testing does not apply.


## Constraints

### False positive risk

When AI invents both a leaf's test cases and its implementation, the pair can agree and still be wrong: test expects X, implementation returns X, but the human needed Y. Prevention: humans author `decision_table` rows; AI implements only.

### Interpolation risk

Decision-table rows constrain output only at the inputs they list. Between rows, the algorithm is unconstrained: rows at quantity 4 and quantity 10 with different discount tiers admit an implementation that switches tiers anywhere from 5 to 10 — every such implementation passes the table. The structural guarantee that holds for orchestrators ("only one implementation passes") does not extend to the space between rows.

Prevention: declare every threshold as a `boundary` and demonstrate it with a bracketing pair (Step 1 enforces; Step 6 pins the comparisons). A threshold never declared is never verified between rows — checklist 7's duty. Finite-domain columns have no between-rows space: `finite_domain_coverage` requires every value to have a row.

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

The lists of which specific decisions are `required_decision` vs `optional_decision` — and the default values for each `optional_decision` — are language-specific and enumerated in the `language_profile`. The values are documented once in the `language_profile`, and every default the implementation actually depends on is reported on Step 8's `Applied defaults` line — a decision the design never made must at least be visible in the run that made it. Any default can be overridden via `config:`.

## Input

The design provided by the user:

$ARGUMENTS

---

## The Pipeline

Execute these eight steps in order. Each step must be complete before the next begins. Report each step using its `### Step N: <name>` heading from below as the section label in your response.

Two host-integration flags change what is emitted: `--plan` (Steps 1–6 as planning, JSON envelope, no files) and `--validate-only` (Step 1 only, strict verdict). Both are specified in **Execution modes (host integration)** after Step 8.

### Step 1: Validate Design

The input set contains at least one `.puml` (UML sequence diagram) and may also contain one or more `decision_table_file`s (`<Participant>.decision.md`). The plugin reads decision-table files **from the same folder as the `.puml` being processed** — not from a project-wide `design/` root. This lets nested designs (a parent `.puml` with sibling-folder children) keep their decision tables locally scoped to their level of the call tree.

**For each `.puml`:** parse the diagram. For each element, confirm it matches a concept defined in the Concepts section above:

`participant` · `call_arrow` · `return_arrow` · `loop_block` · `branch_block` · `throw_arrow`

Use the disambiguation rules ("Distinguishing `call_arrow` from `return_arrow`") when arrow styles are identical. Confirm `target_placement` is declared on the design file.

**For each `decision_table_file`:** parse the YAML frontmatter and the markdown table. Confirm:
- `target:` is present and well-formed (`Class.method`).
- `input:` is present and declares a type for every input column used in the table.
- `output:` is present and declares the method's return type.
- `target_placement` is declared.
- Every column header in the markdown table maps to either a declared `input.*` key or an `expected.*` output field.
- Row cell literals are well-formed (string literals quoted, numerics unquoted).
- Exception rows are well-formed: output cell is `throws: <ExceptionType>` (optionally `: "<message>"`).
- At least one row exists.
- When `boundaries:` is declared: every key resolves to a declared numeric `input.*` column, and every declared `boundary` value has its bracketing pair of rows (adjacency per the `language_profile`): one row at the largest adjacent value below the boundary and one row at exactly the boundary, all other input columns equal, expected outputs differing.
- Every finite-domain input column satisfies `finite_domain_coverage`: each value of its domain appears in at least one row. Columns whose type DisC cannot enumerate (per the `language_profile`) are exempt.

**Refusal protocol** — if any element is unsupported or ambiguous:

1. **STOP** — do not generate code
2. **EXPLAIN** — describe what is unsupported, referencing the concept definitions
3. **SUGGEST** — propose how to restructure using supported concepts

Refuse when:

*UML structure:*
- An arrow has no method name label.
- A diagram has no `system_caller`. Every `.puml` must declare exactly one `system_caller` (the caller of the entry interaction).
- A diagram declares more than one `system_caller`. One `.puml` = one method-under-test = one entry interaction.
- A diagram's entry interaction is nested inside a `branch_block`, `loop_block`, or other fragment. The entry interaction lives at top level.

*Decision-table well-formedness:*
- A `decision_table_file` has missing or malformed frontmatter, or zero rows.
- A `decision_table_file`'s `target:` does not resolve to a `pure function` leaf in any UML in the input set (see Step 2 pairing).
- A `decision_table_file` leaves a `required_decision` unspecified AND `config:` does not pin it. The refusal message names the decision and instructs the human to either (a) add a row that demonstrates the choice, or (b) add the corresponding `config:` key (see the `language_profile` for the recognized key for each decision).
- A `boundaries:` key does not resolve to a declared numeric `input.*` column.
- A declared `boundary` has no bracketing pair. The refusal names the boundary and lists the exact missing row(s) — e.g. "boundary `quantity: 5` needs a row at `quantity = 4` and a row at `quantity = 5` with all other inputs equal and differing expected outputs."
- A finite-domain input column leaves one or more domain values uncovered. The refusal names the column, its domain, and the missing values, and suggests one row per missing value (a `throws:` row for a value the business rules out).

*Participant stereotype:*
- A `participant_target` stereotype is malformed: empty FQN (`<<@class:>>`), or a `+method` listed in an `extend:` form whose name does not appear as a `call_arrow` callee method on this participant in any UML in the input set.
- A participant declared with `participant_target = existing:<fqn>` has any outgoing `call_arrow`. Reuse-as-is means no behavioural change; if the design needs to call methods on this participant, the participant must be a different role (typically `extend:`) or the design must be restructured.
- A `+method` listed in an `extend:<fqn>:+method,...` does not appear as a `call_arrow` callee on this participant. Every listed method must be exercised by the design.
- A participant declared with `participant_target = defer:<path>` is the target of the entry interaction. Its own `.puml` defines that — refuse, and direct the human to invoke DisC on the child `.puml` instead.
- A participant declared with `participant_target = defer:<path>` has any outgoing `call_arrow` in this diagram. Deferral means the internals are designed elsewhere; declaring them here is a contradiction.
- A participant declared with `participant_target = regenerate:<fqn>` has **no** outgoing `call_arrow` in this diagram. Regeneration is for `orchestrator`s; a `leaf_node`'s content is human-owned and is never overwritten — to change a leaf, edit it directly or change its `decision_table_file`.
- A participant declared with `participant_target = regenerate:<fqn>` whose `<fqn>` does not resolve to an existing file. Regeneration overwrites an existing artifact; a participant that does not yet exist is `create`, not `regenerate`.
- A participant declares more than one `participant_target` stereotype. Pick exactly one form. The five forms (`create`, `existing:`, `extend:`, `defer:`, `regenerate:`) are mutually exclusive.

*Entity prelude:*
- An `entity_declaration`'s kind is not one of `record`, `enum`, `class`, `interface`, `sealed-interface`.
- A `sealed_family` declares fewer than 2 permits. The `sealed-interface` kind models closed disjoint unions; with one permit there is no choice — declare the variant directly as a `record` or `class`.
- A `sealed_family` permit name does not resolve to a `record` or `class` `entity_declaration` in the same `entity_prelude`.
- An entity declared with `entity_target = existing:<fqn>` carries body content (fields, values, behaviors, or permits). REUSE means as-is — FQN binding only. The shape is read from the existing source.
- A `variant_decision_table`'s target permit does not implement the sealed parent it claims to override, or names a behavior that does not exist on the parent.
- A `sealed_family` permit name collides with a `participant` name in the same input set. An identifier cannot be both an entity and a participant — rename one.

### Step 2: Classify Participants

Identify which concepts apply:

1. Locate the `system_caller`. The `participant` it calls is the `component_under_test`.
2. Classify every other `participant` as a `collaborator`.
3. For `component_under_test` and `collaborator` participants, sub-classify by call-graph role: `orchestrator` (has outgoing `call_arrow`s) or `leaf_node` (no outgoing `call_arrow`s).
4. List all `call_arrow`s → each is an `interaction`. The entry interaction (caller = `system_caller`) is counted but produces no `verify_test`.
5. Identify `loop_block`s, `branch_block`s, `throw_arrow`s.
6. Sub-classify each `leaf_node` by asking: *does its output depend only on inputs, does it touch the world, or is it a pass-through factory?* The sub-kind table — identification signals and DisC's action per sub-kind — is in the `leaf_node` transformation rule.

6.5. Read the `participant_target` declared on each `participant` and record it — one of the five forms defined in Composition (`create`, `existing:`, `extend:`, `defer:`, `regenerate:`), parsed per the `language_profile`'s notation. Step 3f maps each form to its file mode. Malformed or contradictory stereotypes were already refused in Step 1.

7. Pair each `decision_table_file` with its target `pure function` leaf:
   - Parse the `target: Class.method` frontmatter field.
   - Locate the participant whose interface name matches `Class` across all UMLs in the run. It must be a `leaf_node` sub-classified as `pure function`.
   - Confirm the UML contains a `call_arrow` to that participant with method name `method`.
   - Mark that leaf as **filled**. Record the attached `decision_table_file`.
   - If `Class` does not match a participant, fall through to step 8 (it may be a `sealed_family` permit). If `Class` matches a participant that is a `side effect` or `factory`, refuse per Step 1's refusal protocol.

8. Parse the `entity_prelude` (when present) and build the entities map:
   - For each `entity_declaration`, record `{name, kind, fields, values, behaviors, permits, existingFqn, target}`.
   - For each `sealed_family`, link each permit name to its declaration in the same map; the permit's kind must be `record` or `class`.
   - For each `entity_target = existing:<fqn>` entity, record the FQN binding; Step 3g will read the existing source.
   - Cross-reference every type token used in participant method signatures AND in sealed-interface behaviors: must resolve to an entry in the entities map, a `participant` in the same input set, a primitive, a language standard-library type (per the `language_profile`'s Domain Type Rule), or a boundary carrier (`*Request`/`*Response`/`*DTO`).
   - Pair each remaining `decision_table_file` (unpaired in step 7) as a `variant_decision_table` candidate:
     - Parse `target: Class.method`.
     - Locate `Class` in the entities map. It must be a permit of some `sealed_family`.
     - Locate `.method` on the parent `sealed-interface`'s behaviors[]. It must exist.
     - Mark that permit's override of that method as **filled**. Record the attached `variant_decision_table`.
     - If `Class` is not a permit, or `.method` is not a parent behavior, refuse per Step 1's refusal protocol.
   - When `entity_prelude` is absent, step 8 short-circuits to no-op. Type-token resolution does not apply; signature inference runs in Step 3 instead.

### Step 3: Resolve Targets

**3a. Detect language/framework** — Determine which `language_profile` to load:

1. If the user specifies a `language_profile`, use that.
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

**3f. Set mode per file from `participant_target`:**

For each participant, derive the mode from its declared `participant_target` (recorded in Step 2.6.5):

- `participant_target = create` → mode is **CREATE** for the participant's interface, implementation, and test. File paths come from the file's `target_placement` + the `language_profile`'s naming and package-placement conventions.
- `participant_target = existing:<fqn>` → mode is **REUSE**. No interface, implementation, or test is generated for this participant. It is only referenced as a `collaborator` mock and constructor parameter in the `component_under_test`'s test and implementation. The participant's existing signatures are read from source to populate mock field types where needed.
- `participant_target = extend:<fqn>:+method,...` → mode is **UPDATE** for all three files (interface, implementation, test). The FQN parses to the file path per the `language_profile`. Only the listed `+method` signatures and their corresponding test groups are added; everything else in the existing files is sacred.
- `participant_target = defer:<path>` → mode is **STUB**. CREATE the interface and a throwing stub-implementation (the profile owns the stub template and the `Pending<Name>` naming). **No** test class. **No** decision table — `defer:` participants are not leaves and have no `decision_table_file` paired. The SUT still mocks the participant as a `collaborator` at its own test level (one-hop mocking invariant). The deferred child's own internals are designed and implemented by a future DisC run on `<path>`.
- `participant_target = regenerate:<fqn>` → mode is **REGEN** for the participant's implementation and test: both are overwritten wholesale from the current design (the `language_profile` owns how `<fqn>` resolves to the implementation and test files, and which files are overwritten). The participant's public contract is left as-is — a change to the contract is an `extend:` concern, not regeneration. The participant's `collaborator`s are resolved by their own `participant_target` and are never overwritten by this participant's REGEN (one-hop boundary).

**Fallback for participants with no `participant_target` declared:** glob the conventional file path per the `language_profile`. NEW → **CREATE**, EXISTS → **UPDATE**.

**3g. Set mode per entity from `entity_target` (when `entity_prelude` is present):**

For each entity in the entities map (built in Step 2.8), derive the mode from its declared `entity_target`:

- `entity_target = create` → mode is **CREATE**. The file path comes from the `language_profile`'s entity-file convention; the body is the entity's kind plus its fields/values/behaviors/permits, expressed in the profile's per-kind template. For `sealed_family` parents, the body is the parent declaration (sealed-interface form per the profile) plus the parent's behaviors as abstract method signatures. For each permit, a separate **CREATE** is emitted: the permit's own record file, with the parent-implementation declaration (form per the profile) and one override body per parent behavior (filled or skeleton — see Step 6).
- `entity_target = existing:<fqn>` → mode is **REUSE**. No file is generated. Read the existing source via the `language_profile`: for a record, capture field names and types; for a sealed-interface, capture the permits clause. **Refuse here** if a REUSE `sealed_family`'s design-declared permits don't match the existing source's permits clause exactly — REUSE is FQN binding only; permit drift is a design error. (To add a new permit to an existing sealed type, declare the family as `create` in the design.) The captured shape is used in Step 5 (cross-check) and in Step 4 codegen wherever the entity appears as a `data_mock` or method parameter.

**Fallback when `entity_prelude` is absent:** every type referenced in a method signature that does not match a `participant` is generated as a plain class under the entity package, with no fields.

### Step 4: Generate Tests

For each classified element, apply its transformation rule from the Transformation Rules section above:

| Element | Rule | Produces |
|---|---|---|
| `participant` | "participant to role" | Mocks, constructor wiring |
| Entry `interaction` | "Entry interaction" | Method-under-test signature; test method invocation; `data_pipe` sources |
| Collaborator `interaction` + `return_arrow` | "interaction with return_arrow" | `stub` + `verify_test` |
| Collaborator `interaction` (void) | "interaction without return_arrow" | `verify_test` only |
| Final `return_arrow` | "Final return_arrow" | `result_test` |
| `data_pipe` | "data_pipe" | Return value → next argument |
| `loop_block` | "loop_block" | Single-element collection, iteration |
| `branch_block` | "branch_block" | Separate `test_group` per branch |
| `throw_arrow` | "throw_arrow" | Two `test_group`s with `throw_placement` |
| `leaf_node` (pure function), no file attached | "leaf_node" | `decision_table` skeleton |
| `leaf_node` (pure function), `decision_table_file` attached | "leaf_node" | Filled tests, one per row |
| Participant with `participant_target = defer:<path>` | "STUB mode" | Interface + throwing stub-impl only. No test class. No decision table. |
| Participant with `participant_target = regenerate:<fqn>` (orchestrator) | "participant to role" + interaction rules | Full test for the orchestrator — every collaborator interaction, generated as for CREATE (not add-only). Overwritten at write time (Step 7). |
| `entity_declaration` (`entity_target = create`) | "entity to file" (language profile owns the template per kind) | File (per the `language_profile`'s entity-file convention) for one of: `record`, `enum`, `class`, `interface`, or sealed-interface family parent |
| `entity_declaration` (`entity_target = existing:<fqn>`) | "REUSE entity" | No file. Source shape recorded in Step 3g is used wherever the entity appears downstream. |
| `sealed_family` permit (each one) | "variant impl" | Each permit emits its record file with the parent-implementation declaration and one override body per parent behavior. Body is **filled** from a paired `variant_decision_table`'s rows, or **skeleton** (throwing the language profile's variant marker exception) when no table is paired. A test file accompanies each permit. |

Use the `language_profile`'s test class template and naming conventions.

**Generation order:** declared entities (parents before permits) → inferred domain types (fallback when no `entity_prelude`) → participant interfaces → tests (orchestrator mockist tests, pure-function leaf tests, variant tests) → `decision_table` skeletons (only for unpaired `pure function` leaves; `sealed_family` permits without paired `variant_decision_table`s emit skeleton variant impls inline rather than as a separate decision-table file).

### Step 5: Check Tests

Before writing anything, pass every check. Fix generated code if any check fails. These checks establish the projection's internal consistency — design → tests → implementation transcribed faithfully — not the design's correctness; that stays with its author (see the guarantee ledger).

**Self-reflection protocol:** Iterate your output until you rate it 10/10 against an internal rubric before proceeding. Do not infer patterns not defined in this methodology.

**Six critical checks:**

1. **Arrow parity** — `verify_test` count == count of *collaborator interactions* (interactions whose caller is the `component_under_test`). The entry interaction is excluded — it produces no `verify_test`. Each `stub` has a corresponding `return_arrow`. The `result_test` matches the value labeled on the `return_arrow` back to the `system_caller`; if no such arrow is present, the method-under-test is void and there is no `result_test`.

2. **Data flow integrity** — Each `data_pipe` connects correctly. Implementation call order matches `verify_test` order. Variable names match `data_mock` names.

3. **File mode correctness** — Step 3 discovery complete. CREATE → Write tool. UPDATE → Edit tool. STUB → Write tool for interface and `Pending<Name>` stub-impl only; no test file. No existing content modified, moved, or deleted. No duplicate mock fields or test groups.

4. **Type resolution** (only when `entity_prelude` is present) — Every type referenced in any participant method or sealed-interface behavior resolves to an `entity_declaration` in the entities map, a `participant` in the same input set, a primitive, a language standard-library type (per the `language_profile`'s Domain Type Rule), or a boundary carrier. Any unresolved token refuses here — the design references a type DisC cannot place.

5. **Sealed-family override completeness** — Every `sealed_family` permit produces an override for every parent behavior. Each override is either filled (from a paired `variant_decision_table`'s rows) or skeleton-throwing (with the language profile's variant marker exception). REUSE sealed-family permits clauses match the existing source's permits clause exactly — any drift should have been refused at Step 3g; this is a belt-and-braces re-check.

6. **Pattern rules:**
   - Every `collaborator` has a mock field; constructor includes all `collaborator`s and only `collaborator`s
   - Every `data_mock` has a mock field (or real value for primitives and types the `language_profile` flags as non-mockable)
   - `throw_placement` correct (exception path calls method inside assertion, not in setup)
   - Error message constants declared in implementation, referenced by test
   - `leaf_node`s classified as `pure function`, `side effect`, or `factory`; standalone tests (pure functions only) use direct assertions, not `verify_test`s
   - `decision_table` skeletons marked TODO for human review (only when no `decision_table_file` is attached)
   - Filled decision-table tests have no TODO markers — every row produces a concrete test
   - For each filled `decision_table_file`, every `required_decision` is either demonstrated by rows or pinned by `config:`. (If it isn't, Step 1 should have refused — this is a belt-and-braces check.)
   - Every declared `boundary` has its bracketing pair (belt-and-braces — Step 1 should have refused), and one generated test exists per bracketing row like any other row
   - Every finite-domain input column is fully covered by rows (belt-and-braces — Step 1 should have refused)
   - `pure function` leaves both mocked in consumer AND get standalone tests (dual testing); `side effect` and `factory` leaves have no standalone test
   - Each `branch_block` has one `test_group` per branch with branch-specific `stub` setup
   - `loop_block` test data uses single-element collection
   - Primitives/final classes use real values, not mocks

### Step 6: Generate Implementation

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
- Read `boundaries:`. Each declared `boundary` is a pinned threshold: the comparison constant in the implementation is the declared boundary value, and the operator's direction is read from the bracketing pair (the row at the boundary demonstrates which side the boundary value belongs to — if the at-boundary row shows the upper tier's output, the comparison is `>=` the boundary). Never compare against a value the rows and `boundaries:` do not pin, and never introduce a threshold that is not declared.
- For any `optional_decision` the rows and `config:` are silent on, apply the `language_profile`'s documented default.
- Do NOT make judgment calls on a `required_decision`. If one is unspecified at this point, Step 1 failed to refuse — stop and re-check Step 1, do not paper over it here.

Write the implementation using these values, and record each `optional_decision` default the implementation depends on — Step 8 reports them on its `Applied defaults` line. The rules themselves are fixed by the methodology and the `language_profile`.

**For participants with `participant_target = defer:<path>` (STUB mode):**

The stub-implementation is canonical: every method on the interface throws the `language_profile`'s stub-marker exception, whose message names the deferred participant and the expected sub-design path. The exact template (annotation, naming, message string) is owned by the `language_profile`. The stub compiles and lets the application framework wire the SUT's dependency; only actual execution of the deferred behaviour fails, at runtime, with a clear DisC-tagged message that CI can grep for to block production deploys.

**For `sealed_family` permits:**

Each permit record carries one override method body per parent behavior. The body source depends on whether a `variant_decision_table` is paired:

- **Filled mode** (`variant_decision_table` attached): apply the existing filled-mode generator (same rule as "pure function leaves with `decision_table_file` attached" above), but route the generated body into the permit's override method instead of a standalone consumer-default impl file. One test per row in the permit's accompanying test file.
- **Skeleton mode** (no `variant_decision_table` paired): the override throws the language profile's variant marker exception (named after the deferred-design marker so CI greppable). The accompanying test file is a skeleton with one test placeholder per parent behavior, marked TODO for the human to fill.

The sealed parent itself has no implementation file beyond its parent declaration (sealed-interface form per the `language_profile`) — the parent's behaviors are abstract; the permits own the bodies. No standalone parent-test exists; the variants' tests cover correctness, and the orchestrator's test covers the dispatch.

### Step 7: Write Files

**CREATE mode:** Write tool — complete file.
**UPDATE mode:** Read tool first, then Edit tool — add only, never modify existing.
**REGEN mode:** Write tool — overwrite the orchestrator's implementation and test with the freshly generated files. This is the **only** sanctioned use of the Write tool on an existing file, and it applies **only** to a participant declared `regenerate:<fqn>` (an orchestrator): an orchestrator's implementation is fully determined by its design, so there is nothing hand-authored to preserve.

**Never** use the Write tool on an existing file — **except** a `regenerate:` orchestrator's own implementation and test.

**Critical rule:** Existing content is sacred — with the single exception of a `regenerate:` orchestrator's implementation and test. A `collaborator`'s files (especially `leaf_node`s) are NEVER overwritten, regardless of any orchestrator's REGEN.

**Complete-design precondition for REGEN:** regeneration derives the implementation from the design, so the diagram must describe the orchestrator's complete flow — a `call_arrow` the design omits will be absent from the regenerated implementation. The host that emits the design owns completeness; Step 8 surfaces the residual review duty.

**Cross-cutting precondition for REGEN:** method bodies contain only design-derived calls; cross-cutting concerns live at class level, in aspects, or in configuration. The `language_profile` preserves class-level annotations across the overwrite, and Step 8 lists any method-level annotations that were dropped.

Use the `language_profile`'s UPDATE and REGEN mode rules per file type.

### Step 8: Report

**Summary:**
```
Entry interaction: present (caller = system_caller, target = <SUT>.<method>)
Interactions:    [E] entry + [N] collaborator = [total]
Orchestrators:   [N] participants with outgoing arrows
Leaf nodes:      [M] total ([P] pure function, [S] side effect, [F] factory)
Deferred:        [D] participants stubbed; child .puml paths: [paths]
Regenerated:     [G] orchestrators overwritten wholesale: [names]; method-level annotations dropped: [list, or none]
Entities:        [E_total] total ([R] record, [S] sealed-family, [N] enum, [I] interface, [C] class; [X] REUSE)
Sealed-family variants: [V] permits ([VF] filled from variant_decision_table, [VS] skeleton)
Decision tables: [K] filled from decision_table_file, [Q] skeletons for humans to fill
Boundaries:      [B] declared, all bracketed
Applied defaults: [key=value per fired optional_decision, or none]
Tests:           [N] verify_tests + [R] result_tests = [total] total
Files:           [CREATE/UPDATE/STUB/REGEN labels per file]
```

**Human verification checklist:**
1. Count arrows in UML. Count `verify_test`s in test. Must match.
2. Each `verify_test` argument matches its UML arrow's argument.
3. Each `stub` matches a `return_arrow`.
4. For skeleton decision tables AND skeleton variant impls: fill in TODO test cases / override bodies with real business examples.
5. Each generated file's package matches the `target_placement` declared on its source design file.
6. For each `sealed_family`, every permit's record file has the parent-implementation declaration and one override per parent behavior.
7. Every threshold in the business rule appears in its decision table's `boundaries:`. A threshold that is not declared is not verified between rows — declare it and add its bracketing pair, then re-run.
8. For each `regenerate:` orchestrator: confirm the diagram described its complete flow (an omitted `call_arrow` is an omitted call), and check the report's dropped-annotations note — any method-level concern the old implementation carried must move to class level, an aspect, or configuration.
9. For every decision table with a finite-domain input column whose type DisC could not enumerate (not a boolean, not resolvable to a declared or readable enum): confirm the rows cover every value of that domain. Step 1's `finite_domain_coverage` check runs only on enumerable domains.

**Final steps:**
1. Write files to disk per file mode
2. Run the `language_profile`'s build command
3. If tests fail: read error, fix, re-run
4. Report files and test results

## Execution modes (host integration)

### Plan mode (dry-run)

When `$ARGUMENTS` contains the token `--plan`, DisC executes Steps 1 through 6 as planning only and emits a single JSON object to stdout in place of Steps 7 and 8. **No files are written. No file-writing tool is invoked.** Plan mode lets host tools (e.g., DisC Studio) render a preview-before-apply panel.

The JSON envelope:

```json
{
  "actions": [
    {
      "type": "CREATE" | "UPDATE" | "REUSE",
      "path": "<language-profile-path>/X.<ext>",
      "participant": "X",
      "reason": "string explanation",
      "addedMethods": ["m1", "m2"]
    }
  ],
  "warnings": [
    "<CollaboratorName>.<methodName> signature mismatch — using catalog form"
  ],
  "summary": {
    "create": 3, "update": 1, "reuse": 2,
    "verifyTests": 4, "resultTests": 1, "decisionTables": 0
  }
}
```

- `type: "CREATE"` — file does not exist (or `participant_target` is `create`); plan would `Write` it.
- `type: "UPDATE"` — file exists (or `participant_target` is `extend:...`); plan would `Edit` it. `addedMethods` lists what would be added.
- `type: "REUSE"` — `participant_target` is `existing:<fqn>` or the participant resolves to an already-correct file with no additions. Plan would not touch this file. Include the row so the host can show "we'll use your existing X as-is".

The envelope is the **only** thing emitted on stdout in plan mode. Steps 1–6 are reasoned about internally; no per-step narration is printed. The exit code is 0 on success and non-zero with a JSON error envelope (`{"error": "..."}`) on refusal.

When `--plan` is absent, the pipeline runs normally and produces Steps 1–8 narration plus written files.

### Validate mode

When `$ARGUMENTS` contains the token `--validate-only`, DisC executes **Step 1 only** (the refusal-grade contract checks) and exits. **No files are written. No file-writing tool is invoked.** No tests, no implementation, no plan envelope — only the verdict on whether the design is shaped well enough to feed into Steps 2–6. Validate mode lets host tools (e.g., DisC Studio) preflight the design at authoring time before the user commits to a full run.

**Strict-output rule** — exactly as in plan mode, Step 1 is reasoned about internally; **no per-step narration, no markdown headings, no "Validation Results" prose, no checklist of which rules passed**. The stdout contract is one of exactly two shapes:

- **On Step 1 pass:** the literal single line `{"ok": true}` — nothing before it, nothing after it. Exit code 0.
- **On Step 1 refusal:** the standard `#### REFUSAL — STOP` markdown block exactly as defined in the Step 1 refusal protocol — same wording, same EXPLAIN + SUGGEST sections, same exit code (non-zero). Host tools render this verbatim.

Any other output (progress narration, partial summaries, "let me check…" preambles) is a contract violation that host tools cannot parse. Run the checks silently; emit only the verdict.

When `--validate-only` is absent and `--plan` is absent, the pipeline runs normally. When both flags are present, `--validate-only` wins (it is a strict subset of `--plan`).
