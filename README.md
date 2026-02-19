# Design is Code (DisC)

A methodology where design generates tests, and tests constrain AI-generated code.
DisC builds on the London school of TDD (Freeman & Pryce, Growing Object-Oriented Software, Guided by Tests, 2009) and applies it to AI-assisted code generation.

## The Problem

AI code generation has two root causes of failure:

1. **Natural language is ambiguous.** The same prompt produces different code every time. There's no contract — just interpretation.
2. **Cost is asymmetric.** AI has no cost to be wrong. You have high cost to miss errors. AI generates in seconds; you review for hours.

## Why Precise Design?

Every generation of software engineering raised the abstraction level while preserving formal notation — machine code → assembly → structured programming → OOP. Natural language breaks that contract. It's expressive, but not formal. The same prompt means different things every time.

Precise design representations restore the contract. UML sequence diagrams are unambiguous: boxes are components, arrows are calls, labels are method signatures. No interpretation needed. DisC works with any design representation that meets this precision bar. UML is the current supported format.

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

This wall between phases is what makes DisC work. The implementation can only produce what the tests demand — no more, no less.

Each arrow in a UML sequence diagram becomes a verify() call using London-style mockist tests — verifying which collaborators are called, in what order, with what arguments. verify(repository).save(product) only passes if the implementation actually calls repository.save(product). The AI can't skip it, reorder it, or change the arguments.

**Review shifts to design time**. One hour of peer design review replaces many hours of code review. The remaining review is sampling — verifying the transformation was correct, not reading the full codebase.

## Scope and Limitations

DisC constrains interaction structure — how components collaborate. It does not constrain non-functional properties: performance, readability, or error handling style.

Two kinds of components behave differently:

- Collaborative components have dependencies that can be verified with mocks. AI generation risk is low — the tests fully constrain the structure.
- Pure functions (Mappers, Factories, algorithms) have no dependencies and can't be verified by interaction tests. For these, humans must design the test cases: input values, expected outputs, and edge cases. AI should not invent both the test cases and the implementation — that creates false positives where tests pass but logic is wrong.

- Algorithmic code — ML pipelines, trading algorithms, game engines — falls outside the methodology entirely.

## Who Does the Design?

| What | Who | Why |
|---|---|---|
| Component interactions (UML arrows) | Developers | Architecture decisions require engineering judgment |
| Pure function test cases (decision tables) | Product / QA team | Business rules and edge cases require domain knowledge |
| Implementation | AI | Mechanical — forced by the tests |

## Quick Start

1. Clone this repo
2. Run `claude --plugin-dir .` from the repo root. It loads the plugin for the current session only. No cleanup needed afterward.
3. Run `/disc 01_hello-world.puml` in Claude Code

## Install Design-Is-Code plugin for Claude Code

1. Install the plugin in Claude Code ([plugin docs](https://code.claude.com/docs/en/plugins)) in 2 commands:
   ```
   /plugin marketplace add mossgreen/design-is-code-plugin
   ```
   ```
   /plugin install design-is-code@mossgreen-design-is-code
   ```
2. Put your UML sequence diagram in your project's `design/` folder
3. Run `/design-is-code:disc <filename>` in Claude Code

## Uninstall Design-Is-Code plugin for Claude Code

```
/plugin uninstall design-is-code@mossgreen-design-is-code
/plugin marketplace remove mossgreen-design-is-code
```

Verify with `/plugin` — check the Installed tab.

See [Claude Code plugin docs](https://code.claude.com/docs/en/plugins-reference.md) for full CLI reference.
