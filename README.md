# Design is Code (DisC)

A methodology where design generates tests, and tests constrain AI-generated code.

In software, the real work is design. Code is the consequence.

DisC applies London-school TDD (Freeman & Pryce, 2009) to AI code generation. Mockist tests specify exact call structure, order, and arguments — leaving no room for AI interpretation. There is only one implementation that passes. 

What you design is what you get.

## The Problem

AI code generation has two root causes of failure:

1. **Natural language is ambiguous.** Natural language is built for human communication, where ambiguity is tolerable. As a code specification, it's a liability. The AI interprets rather than executes — same prompt, different code, every time. There's no contract. There's no determinism.
2. **Cost is asymmetric.** AI has no cost to generate, and no cost to be wrong. You have high cost to review, and high cost if you miss an error. That's not collaboration — that's **exploitation**.

## Design is the Contract

Every generation of software engineering raised the abstraction level while preserving formal notation — machine code → assembly → structured programming → OOP. Each step made intent more expressible without sacrificing precision. Natural language breaks that contract. It's expressive, but not formal.

This is not a tooling problem. It's a specification problem.

If the specification is ambiguous, everything downstream inherits that ambiguity — the tests, the implementation, the architecture. You can't review your way out of a bad contract. You can only fix it at the source.

Design is the source.

A precise design artifact eliminates interpretation before code is written. This changes where human effort belongs. Peer collaboration, architectural debate, edge case reasoning — all of it should happen at design time, not in code review. Reviewing code that AI generated from an agreed design is spot-checking. Reviewing code that AI generated from a natural language prompt is archaeology.

DisC works with any design representation that meets this precision bar. UML sequence diagrams are the current supported format.

## How It Works

The key mechanism:
1. Tests are generated from the design
2. The implementation is driven by tests alone
3. You get what you design, no code review needed

```
 Design Artifact (UML Sequence Diagram, etc.)
        |
        v
  Phase 1: Design → Tests 
        |
        v
  Phase 2: Tests → Implementation  (Implementation is driven by tests not the design)
        |
        v
  Working Code (Reviewed designs don't need code review)
```

## Participants

Every participant in a design is either an **orchestrator** or a **leaf**.

An orchestrator has dependencies and coordinates them. Orchestrators are verified by mockist tests — every call becomes a test, every argument is pinned, every order is fixed. AI generation risk is low because the tests fully constrain the structure.

A leaf has no outgoing calls. Because leaves cannot be verified by interaction tests, DisC classifies each one by what kind of work it does, and tests it accordingly:

- **Pure function** — output depends only on inputs. Tested by decision table: humans design the test cases (input → expected output), AI implements only. AI must not invent both cases and implementation — that creates false positives where tests pass but logic is wrong. When a decision table is authored ahead of time as `design/<Participant>.decision.md`, DisC consumes it directly and generates filled tests; otherwise DisC emits a skeleton for humans to fill in.
- **Side effect** — touches external systems (DB, network, clock, queue). Mocked in consumer tests; correctness verified via integration tests, not DisC.
- **Factory** — name ends in `Factory`. Assumed to be pass-through packaging into a constructor. No standalone test; correctness is transitive through the consumer.

## Scope and Limitations

DisC constrains interaction structure — how components collaborate. It does not constrain non-functional properties: performance, readability, or error handling style.

Algorithmic code — ML pipelines, trading algorithms, game engines — falls outside the methodology entirely.

## Who Does the Design?

| What | Who          | Why |
|---|--------------|---|
| Component interactions (UML arrows) | Developers   | Architecture decisions require engineering judgment |
| Pure function test cases (decision tables) | Product team | Business rules require domain knowledge |
| Implementation | AI           | Mechanical — forced by the tests |

## Supported Languages

Currently supports **Java** (Spring Boot) with **UML sequence diagrams** (PlantUML format) and **decision tables** (Markdown with YAML frontmatter). Support for additional languages is planned.

## Quick Start

1. Install the plugin (one-time setup):
   ```
   claude plugin marketplace add mossgreen/design-is-code-plugin
   claude plugin install design-is-code@mossgreen-design-is-code --scope user
   ```
2. Clone the demo project: https://github.com/mossgreen/design-is-code-demo (Java Spring Boot, requires Java 17, includes UML and decision-table examples).
3. Open the demo in Claude Code and run `/design-is-code:disc 01_hello-world.puml`.

The `design/` folder may contain both `.puml` UML files and `.decision.md` decision-table files. DisC picks up both in one invocation: UML defines orchestration, decision tables define pure-function leaves.

### Reusing existing code

By default DisC treats every participant as a new abstraction to generate (CREATE). A `.puml` can declare otherwise by attaching a `<<@class:...>>` stereotype to a participant:

```plantuml
participant Money                <<@class:com.example.common.Money>>           ' reuse as-is
participant DiscountRepository   <<@class:com.example.sale.DiscountRepository, +findActive>>  ' add findActive
```

See [`skills/disc/java_spring.md`](skills/disc/java_spring.md#plantuml-notation-for-participant_target) for the full grammar. The same `.puml` works without stereotypes — DisC falls back to its prior glob-based detection for backward compatibility.

### Preview before applying (`--plan` mode)

Append `--plan` to the command (`/design-is-code:disc design/foo.puml --plan`) to run the pipeline in dry-run mode. DisC emits a single JSON envelope of file actions to stdout without writing anything. Designed for host tools like DisC Studio to render a preview panel before the user commits to a real run.

### Multi-level designs (`<<defer-design>>`)

Real systems often have orchestrators that call other orchestrators. DisC handles this by **top-down design + bottom-up implementation**: each level of the call tree is its own `.puml`, and the bottom level is implemented first.

When a participant in the parent diagram is itself an orchestrator (will need its own `.puml`), declare it `<<defer-design>>`:

```plantuml
participant DiscountCalculator <<defer-design:CreateSale/DiscountCalculator.puml>>
```

For this run, DisC emits the interface and a throwing stub-impl named `PendingDiscountCalculator` (annotated `@Component`, every method throws `UnsupportedOperationException` with a `DisC: design pending` marker). The SUT's test still mocks `DiscountCalculator` as a `collaborator` — one-hop mocking. The deferred child's real implementation comes from a later DisC run on the child `.puml`.

Folder layout:

```
design/05_sale/
  CreateSale.puml                   ← parent
  CreateSale/
    DiscountCalculator.puml         ← child sub-design, real impl when DisC runs on this file
```

The build order is bottom-up: DisC Studio's "Build all" walks the tree leaves-first, so by the time the parent `.puml` is processed its child's `Pending<Name>` stub has been replaced with the real implementation produced by the child's own DisC run. Interfaces flow the other way — the parent's `call_arrow` on the child pins the child's signature, locked by the host's `contractHash` and refused as stale if the parent changes.

The child `.puml`'s `[*] -> DiscountCalculator: apply(...)` entry interaction must match the parent's call signature on `DiscountCalculator`. (DisC Studio computes this signature hash automatically and refuses to build a child whose parent contract has drifted.)

Decision tables (`<Participant>.decision.md`) live in the same folder as the `.puml` that uses them — DisC reads them as siblings, not from a project-wide `design/` root.

## Keep the Plugin Up to Date

Third-party marketplaces have auto-update disabled by default. To manually pull the latest version:

```
/plugin marketplace update mossgreen-design-is-code
```

Claude Code will notify you to restart if a new version was found.


## Uninstall Design-Is-Code plugin for Claude Code

```
claude plugin uninstall design-is-code@mossgreen-design-is-code --scope user
claude plugin marketplace remove mossgreen-design-is-code
```

Verify with `/plugin` — check the Installed tab.

See [Claude Code plugin docs](https://code.claude.com/docs/en/plugins-reference.md) for full CLI reference.
