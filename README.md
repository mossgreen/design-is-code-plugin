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

## Scope and Limitations

DisC constrains interaction structure — how components collaborate. It does not constrain non-functional properties: performance, readability, or error handling style.

Two kinds of components behave differently:

- Collaborative components have dependencies that can be verified with mocks. AI generation risk is low — the tests fully constrain the structure.
- Pure functions (Mappers, Factories, algorithms) have no dependencies and can't be verified by interaction tests. For these, humans must design the test cases: input values, expected outputs, and edge cases. AI should not invent both the test cases and the implementation — that creates false positives where tests pass but logic is wrong.

Algorithmic code — ML pipelines, trading algorithms, game engines — falls outside the methodology entirely.

## Who Does the Design?

| What | Who          | Why |
|---|--------------|---|
| Component interactions (UML arrows) | Developers   | Architecture decisions require engineering judgment |
| Pure function test cases (decision tables) | Product team | Business rules require domain knowledge |
| Implementation | AI           | Mechanical — forced by the tests |

## Supported Languages

Currently supports **Java** with **UML sequence diagrams** (PlantUML format). Support for additional languages and design formats is planned.

## Quick Start

1. Clone this repo: https://github.com/mossgreen/design-is-code-demo, it's a Java Spring Boot project with simple UML sequence diagram examples.
2. Run `/disc 01_hello-world.puml` in Claude Code session
3. it requires Java 17.

## Install Design-Is-Code plugin for Claude Code

1. Install the plugin in Claude Code ([plugin docs](https://code.claude.com/docs/en/plugins)) in 2 commands:
   ```
   claude plugin marketplace add mossgreen/design-is-code-plugin
   claude plugin install design-is-code@mossgreen-design-is-code --scope user
   ```
2. Put your UML sequence diagram in your project's `design/` folder
3. Run `/design-is-code:disc <filename>` in Claude Code

Verify it's working: open Claude Code in any project and run `/design-is-code:disc`.

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
