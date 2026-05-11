# Changelog

All notable changes to the design-is-code plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `system_caller` boundary marker: the fixed marker for the entry into the system under test, written as `[*]` in PlantUML. Stands in for the test harness in DisC tests and for the framework (HTTP, message queue, scheduled trigger) in production. Not a `participant` — has no abstraction, no implementation, no constructor entry. Required in every `.puml`: declares the method-under-test's signature explicitly (no more inference from filename/first-participant).
- "Entry interaction" concept in SKILL.md: the `interaction` whose caller is the `system_caller`. Produces no `verify_test`; declares the method-under-test signature.
- PlantUML notation for `system_caller` (`[*]`) documented in `java_spring.md`.
- Step 1 refusal cases: missing `system_caller`, more than one `system_caller`, `system_caller` calling a `leaf_node`, entry interaction inside a fragment.
- All demo `.puml` files migrated to use the new notation.

## [0.4.0] - 2026-05-05

### Added
- `target_placement` concept: every design file declares where its generated code lives. `.puml` files use a `' @package <pkg>` header comment; `.decision.md` files use a `package:` frontmatter field. Treated as a `required_decision`.
- `language_profile` concept: formalised as a snake_case concept. SKILL.md is language-neutral; the `language_profile` (e.g. `java_spring.md`) owns `target_placement` form, `config:` keys, templates, file paths, naming, UPDATE rules, build command, and `optional_decision` defaults.
- Step 1 validation now confirms `target_placement` is declared on every design file
- Step 8 verification checklist confirms each generated file's package matches its source design file's `target_placement`

### Changed
- Step 3 reads placement per-file from the design instead of auto-detecting a project-wide base package. The `@SpringBootApplication` / glob / `build.gradle` fallback chain is removed.
- `java_spring.md`'s "Base Package Detection" section replaced by "Target Placement Declaration" (positive form, no negative-case bullets)
- Both walkthroughs updated to show declared placement (`com.example.product`) and read-placement narration in Step 3
- `decision_table_file` concept entry now lists `target_placement` alongside `target`, `input`, `output` in frontmatter

## [0.3.0] - 2026-04-28

### Added
- First-class pure-function support: `decision_table_file` (`design/<Participant>.decision.md`) with YAML frontmatter (`target`, `input`, `output`, optional `config`) and markdown rows
- `required_decision` and `optional_decision` concepts: every material decision (rounding, scale, nullHandling, exceptionType) must be either demonstrated by rows or pinned by `config:`
- `config:` key vocabulary in `java_spring.md` (rounding, scale, nullHandling, exceptionType, locale)
- Refusal protocol when a `required_decision` is unspecified
- Filled-mode test generation: one `@Test` per row, no TODO markers
- Walkthrough in `java_spring.md` for paired UML + decision-table flow
- Dual testing rule: pure-function leaves are mocked in consumer tests AND get standalone decision-table tests

### Changed
- SKILL.md tightened: removed N-path complexity section; sharper Concepts → Pipeline structure

## [0.2.1] - 2026-04-14

### Removed
- Token tracker hooks (PreToolUse and Stop) from SKILL.md frontmatter
- Token usage reporting from Step 8 report
- `skills/disc/hooks/token-tracker.sh` script

## [0.2.0] - 2026-04-13

### Added
- Colon syntax for participant naming: `PriorityOrderService: OrderService` lets users specify explicit implementation names
- `[InterfaceName]` and `[ImplementationName]` as standard placeholders across templates and file path patterns

### Changed
- Participant definition in SKILL.md now describes bare form (abstraction) and colon form (implementation: abstraction)
- Naming Conventions in java_spring.md: implementation name defaults to `Default` + interface name, overridable via colon syntax
- Test Class Template, Implementation Template, Decision Table Skeleton, and File Path Patterns all use `[ImplementationName]`/`[InterfaceName]` instead of hardcoded `Default[Name]`

## [0.1.4] - 2026-03-04

### Changed
- Tightened DisC SKILL.md prose for clarity and conciseness
- Removed N-path complexity constraint section

## [0.1.3] - 2026-02-28

### Added
- Added "Keep the Plugin Up to Date" section explaining how to manually refresh the marketplace

### Fixed
- Token tracker hooks now work with user-scope installs: fall back to `find ~/.claude/plugins` when `CLAUDE_PLUGIN_ROOT` is unset, instead of silently doing nothing
- Clarified install instructions to use `user` scope, preventing "Unknown skill" errors when opening Claude Code in a different project

## [0.1.2] - 2026-02-27

### Fixed
- Token tracker hook errors (`PreToolUse:Glob hook error`, `PreToolUse:Read hook error`) caused by empty `CLAUDE_PLUGIN_ROOT` at runtime
- Grep patterns in `token-tracker.sh` now handle both compact and spaced JSON

## [0.1.1] - 2026-02-26

### Added
- Release script (`scripts/release.sh`) for automated version bumps, changelog updates, and tagging

## [0.1.0] - 2026-02-26

### Added
- Hook-based token usage reporting via PreToolUse + Stop hooks
- Java/Spring language profile (`java_spring.md`) extracted from SKILL.md
- Design examples (`01_hello-world.puml`, `02_order-service.puml`, `03_order-service-with-mapper.puml`)
- Marketplace registration (`marketplace.json`)
- Use cases documentation (`use_cases.md`)

### Changed
- Token tracking moved from manual Bash commands in Steps 1/8 to automatic skill hooks
- SKILL.md now language-agnostic (Java-specific rules live in `java_spring.md`)

## [0.0.1] - 2026-02-18

### Added
- Initial DisC methodology skill (SKILL.md)
- Plugin configuration (plugin.json)
