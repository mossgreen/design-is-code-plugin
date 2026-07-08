# Changelog

All notable changes to the design-is-code plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Orchestrator regeneration** (`regenerate:<fqn>` participant_target, rendered `<<@regen:fqn>>`) closes the design-as-source gap past the first generation. When an orchestrator's design changes, DisC overwrites its implementation and test **wholesale** from the new design (REGEN mode) — the single sanctioned use of the Write tool on an existing file — while collaborators, especially `leaf_node`s, stay sacred. Safe because an orchestrator's implementation is fully determined by its design (structure is determined); refused on a leaf (no outgoing `call_arrow`s) at Step 1. The diagram must describe the orchestrator's complete flow (an omitted `call_arrow` is dropped from the regenerated implementation), and the Step 8 checklist adds a version-control diff of each regenerated orchestrator. `<fqn>` may resolve to an interface (the `Default<Name>` implementation and test are rewritten; the interface untouched) or to a class that is its own implementation (`<Name>.java` + `<Name>Test.java` rewritten; public method signatures preserved) — DisC reads the source at `<fqn>` to tell which. Concept, refusals, and the Write-overwrite carve-out in SKILL.md; `<<@regen:fqn>>` syntax, REGEN Mode Rules, and a worked example (both target shapes) in `java_spring.md`.
- **Boundary declarations** (`boundaries:` frontmatter on decision tables) close the interpolation gap on pure-function leaves. Rows constrain output only at the inputs they list; between rows the algorithm was unconstrained — rows at quantity 4 and 10 with different tiers admitted any cut between 5 and 10. A declared boundary must be demonstrated by a **bracketing pair**: one row at the largest adjacent value below the boundary (integers: `B−1`; decimals: one unit below at the boundary literal's scale), one row at exactly the boundary, all other inputs equal, expected outputs differing. Step 1 refuses an unbracketed boundary (listing the exact missing rows); Step 6 pins the implementation's comparison constant to the declared value, with the operator direction (`>=` vs `>`) inferred from which side the at-boundary row sits. New `boundary` concept and **Interpolation risk** constraint in SKILL.md; grammar, adjacency rules, and a worked example in `java_spring.md`.
- **Finite-domain coverage** (`finite_domain_coverage`) closes the same interpolation gap for enum and boolean inputs — the categorical counterpart of `boundaries:`. An input column whose declared type enumerates completely (`boolean`, or a declared / source-read `enum`) must carry a row for every value of its domain; a finite domain has no between-rows space, so per-column coverage pins behaviour on that column the way a bracketing pair pins a numeric threshold. Nothing is declared — the domain is read from the type. Step 1 refuses an uncovered value, naming the column, its domain, and the missing values (a value the business rules out is covered by a `throws:` row). Coverage is **per column**: combinations across several finite columns remain a human sign-off duty (Step 8 checklist), as do columns whose type DisC cannot enumerate. New `finite_domain_coverage` concept and Step 1 refusal in SKILL.md; enumerable-type list, coverage rule, and refusal message in `java_spring.md`.
- **Guarantee ledger** (SKILL.md Context) replaces the "What DisC controls" paragraph with a per-artifact table: what DisC mechanically guarantees and the step that enforces it, what the `language_profile` fills by default (now reported — see *Changed*), and what remains a human duty mapped to a Step 8 checklist item. States guarantee *levels* explicitly — orchestrators pinned uniquely; filled leaves pinned at every row plus every declared boundary (numeric) or covered value (finite domain); skeleton, side-effect / factory, and deferred artifacts each with their own guarantee and residual duty — rather than one uniform "one implementation passes."

### Changed
- README scopes the no-code-review claim explicitly: orchestrators are fully pinned (only one collaboration structure passes); pure-function leaves are pinned at every row and every declared boundary, and the remaining human duty — confirming every business threshold is declared — is a named sign-off checklist item (also added to the Step 8 human verification checklist). The scoped claim also covers `finite_domain_coverage`: enum and boolean inputs must carry a row per domain value, so finite columns have no between-rows gap; the multi-column-combinations residual joins the sign-off duties.
- **Honesty reframing** of SKILL.md's Context, Constraints, and Step 5. Generated tests are named **born green**: test and implementation are co-projected from one design, so a green build at generation time verifies faithful transcription, not design correctness; full regression value activates under later change (`regenerate:`, `extend:`, hand-edit). The two-phase wall is named a **discipline, not a mechanism** within one generation context (the mind that read the design also writes the implementation), with the mechanical enforcement path noted (run Phase 2 in a separate context fed only the tests). No operative rule changed.
- **Fired defaults are reported.** Every `optional_decision` default the implementation depends on is listed on Step 8's new `Applied defaults` line (e.g. `Applied defaults: locale=ROOT`). The profile's "applied silently … not reported per run" wording is retired — a decision the design never made is now visible in the run that made it. SKILL.md Step 6 / Step 8; `java_spring.md` decision-table rules.
- **REGEN keeps cross-cutting concerns out of regenerated bodies.** A regenerable orchestrator's method bodies contain only design-derived calls; transactions, tracing, metrics, and guards belong at class level, in an aspect, or in configuration. REGEN reproduces class-level annotations verbatim and lists every dropped method-level annotation on the Step 8 report. The REGEN checklist item is refocused — confirm complete flow and check the dropped-annotations note, and on the **first** regeneration of a class DisC did not generate, diff the whole file (legacy body statements such as logging and inline guards are dropped without appearing in the report). Resolves the prior contradiction between "nothing hand-authored to preserve" and "diff for lost hand-edits": the premise is now true by construction. SKILL.md `regenerate:` + Step 7 / 8; `java_spring.md` REGEN Mode Rules.
- **Spec structure tightened** (rubric: logical, short, simple, concise, precise). Plan mode and validate mode moved out of the pipeline into an **Execution modes (host integration)** appendix after Step 8, with an imperative pointer at the pipeline head so the strict-output contract governs whenever either flag is present; Steps 1–8 now read uninterrupted. `participant_target`'s five forms are defined once (Composition) and referenced from Step 2 / Step 3f instead of re-enumerated; the `leaf_node` sub-kind table lives in one place; the `boundary` concept bullet is trimmed to a definition plus pointers; the call-graph-role heading and stray whitespace fixed. Editorial only — no operative rule changed.

### Refused (Step 1)
- A decision table with a finite-domain input column (`boolean`, or a declared / source-read `enum`) that leaves any domain value uncovered. The refusal names the column, its domain, and the missing values, and suggests one row per missing value — a `throws:` row for a value the business rules out. Columns whose type DisC cannot enumerate are exempt (Step 8 checklist duty).

## [0.10.0] - 2026-05-28

### Added
- `<<interface>>` may now be paired with `<<@permits:V1,V2,...>>` for an open-but-manifest variant set. The generated Java interface stays non-sealed (no `sealed` keyword, no `non-sealed`/`final` on permits) so third-party implementations remain possible and Spring `@Service` strategies still register; the design itself declares every implementation it owns. Canonical use case: resolver-pattern strategy hierarchies where the design manifest is closed but the Java contract must remain open for Spring auto-configuration. Each permit must resolve to a `record` or `class` `entity_declaration` in the same prelude.
- Interface-with-permits permits emit as `public class V1 implements Parent` (not `record`) and parent/permits share the entity package, mirroring sealed-family layout. Per-variant impl mode is preserved (filled when paired with a `variant_decision_table`, skeleton otherwise). Users add `@Service` themselves when registering as Spring beans.
- Third decision-table mode in `java_spring.md`: **Resolver impl from decision table**. Triggered when the target is `<Participant>.<method>`, the output type resolves to an interface (sealed or plain) with non-empty `<<@permits:>>`, and the `expected` column values exhaustively cover the permits. Emits a constructor-injected `Map<Key, Variant>` resolver implementation (`Default<Resolver>`) plus a row-by-row test that mocks each permit and verifies the Map lookup. Skeleton mode does not apply — an unpaired resolver decision table refuses at Step 1.

### Changed
- `java_spring.md` Per-variant impl mode now covers both sealed-family `record` permits AND interface-with-permits `class` permits — same impl-mode decision (filled vs skeleton), different surface syntax.
- Variant decision-table pairing rule extended: the target's `Variant` may resolve to a permit of either a `sealed_family` OR an `interface` parent with `<<@permits:>>`.
- Entity package placement table gained a row for `interface` parent with permits + all its permit classes (parent and permits share `{basePackage}.entity`, mirroring sealed-family layout).

## [0.9.0] - 2026-05-26

### Changed
- SKILL.md is now strictly language-agnostic. Dependency inversion applied — the methodology no longer names any specific language, framework, or diagram notation. Specifically: (1) Step 1's refusal list dropped language-specific checks (compiler catches them) or relocated them to their point of consumption (Step 3g for REUSE permits-clause mismatch, Step 5 for type resolution). Step 1 now refuses only on design-integrity violations that hold for any `language_profile`. (2) Every `(e.g., PlantUML…)` / `(e.g., java_spring.md…)` parenthetical removed; concept definitions and pipeline prose delegate to `the language_profile` without naming concrete forms. (3) Java/Spring tokens (`JDK type`, `@Override`, `@Mock`, `@Autowired`, `UnsupportedOperationException`, `assertThatThrownBy`, `implements <Parent>`, `sealed interface … permits …`, `.java` paths) replaced with abstract phrasing the profile already templates.
- Both methodology documents (SKILL.md and `java_spring.md`) carry zero version-number references. Forward-looking version mentions (`in v0.8.0`, `wait for v0.9 UPDATE-entity support`) and backward-history clauses (`the v0.5.x signature-inference path`, `predating v0.8.0`, `backward compatibility with the demo corpus`, `legacy`, `for now`) are removed. Operational rules are preserved in full — the no-op behaviour when `' @disc-entities` is absent, the REUSE permits-clause refusal mechanism, and the implicit `create` default all remain. Rationale: methodology docs are loaded as AI prompt context; version anchors rot immediately and invite reading the contract as a changelog instead of a self-contained spec. Changelogs belong in CHANGELOG.md.

## [0.8.0] - 2026-05-24

### Added
- `entity_declaration` and `entity_prelude` concepts in SKILL.md: domain types (records, enums, classes, interfaces, sealed-interfaces) that the participants pass through `data_pipe`s, declared in a prelude block immediately after the `' @package` header. A parallel taxonomy to `participant` — entities are *data* nodes (never mocked at the SUT level, never appear in any constructor as a `collaborator`); participants are *behavioral* nodes.
- `entity_target` concept: per-entity analog of `participant_target`. Two forms in v0.8.0 — `create` (default, generate the file) and `existing:<fqn>` via `<<@class:fqn>>` (REUSE; read the existing source for its shape, generate no file). `extend` and `defer` do not apply to entities in v0.8.0.
- `sealed_family` concept: a `sealed-interface` entity paired with `<<@permits:V1,V2,...>>`. Hosts sealed-polymorphism variance — each permit owns its override of the parent's behaviors. Step 1 refuses families with fewer than 2 permits.
- `variant_decision_table` concept: a `decision_table_file` whose `target: Variant.method` resolves to a permit record's override (distinct from the existing pairing rule that targets a `pure function` leaf participant). When attached, the variant's override body is filled from rows; absent, the override is generated in skeleton mode.
- PlantUML notation in `java_spring.md` for `entity_declaration`: `class Name <<record>>`, `<<enum>>`, `<<class>>`, `<<interface>>`, `<<sealed-interface>>` with body fields/values/behaviors. REUSE form `<<@class:fqn>>` (no body). Sealed families use `<<@permits:V1,V2>>` as a second stereotype on the same line as `<<sealed-interface>>`.
- New SKILL.md Step 2.8: parse the `entity_prelude`, build the entities map, cross-reference type tokens used in method signatures, pair `variant_decision_table`s.
- New SKILL.md Step 3g: set mode per entity from `entity_target` (CREATE for declared, REUSE source-read for `existing:<fqn>`).
- New SKILL.md Step 4 transformation rows for `entity_declaration` (create/existing) and `sealed_family` permits (filled or skeleton override body).
- Two new SKILL.md Step 5 checks: type resolution (every type token resolves when an `entity_prelude` is present) and sealed-family override completeness (every permit produces an override for every parent behavior).
- `java_spring.md` Entity Generation Templates section: per-kind Java output, file paths, sealed-family + permit handling, per-variant impl mode (skeleton vs filled), variant pairing rule.
- Sealed-poly variance is now first-class: adding a new variant to a `sealed_family` requires only a new `record` entity + an entry in the parent's `<<@permits:…>>` stereotype — no orchestrator, participant, or method-signature edits.
- Variant marker convention: skeleton-mode permit overrides throw `UnsupportedOperationException` with the literal `DisC: variant impl pending for <Parent>.<method> on <Variant>` — parallel to the `defer-design` marker. CI greppable to block production deploys.
- Step 8 report shape: new `Entities:` line listing kind counts; new `Sealed-family variants:` line listing filled vs skeleton permit overrides.

### Changed
- SKILL.md Step 5 grew from four to six critical checks (Type resolution + Sealed-family override completeness added).
- SKILL.md Step 4 generation order now begins with declared entities (parents before permits), then falls back to inferred domain types when no `entity_prelude` is present.
- SKILL.md Concepts reorganized: `Entity declarations` subsection renamed to `Entity elements` and slimmed to its primitives (`entity_declaration`, `entity_prelude`). `entity_target` and `sealed_family` moved to the **Composition** section next to `participant_target` / `data_pipe` (where the parallel/derived-fact lives). `variant_decision_table` moved to the **Decision-table elements** subsection next to `decision_table_file` (where line 58's forward-reference points).
- SKILL.md `participant` definition (Concepts) closed a v0.6.0/v0.7.0 gap: now acknowledges that `participant_target` stereotypes override the name→class mapping, and forward-references `entity_declaration` as the data-side parallel.
- SKILL.md `decision_table_file` description corrected to match Step 1's authoritative rule: tables sit as siblings of the `.puml` that uses them, not under a project-wide `design/` root.
- SKILL.md Step 1 refusal list grouped into four named categories (UML structure / decision-table well-formedness / participant stereotype / entity prelude) for scanability; bullet content unchanged.
- SKILL.md Plan-mode JSON example abstracted (`OwnerRepository.findById` → `<CollaboratorName>.<methodName>`) to match the prompt-wide example-agnostic convention.

### Refused (Step 1)
- `sealed-interface` entity with fewer than 2 permits.
- A permit name that does not resolve to a `record` or `class` `entity_declaration` in the same prelude.
- An entity kind not in the allowed set.
- A REUSE entity declared with body content (REUSE = FQN binding only).
- A REUSE `sealed_family` whose declared permits don't match the existing source's `permits` clause exactly. (Refusal message directs the user to declare the parent as `create`, or wait for v0.9 UPDATE-entity support via `<<@class:fqn, +permit:Name>>`.)
- A method signature referencing a type that doesn't resolve to entity/participant/primitive/JDK/boundary-carrier (only when an `entity_prelude` is present — absent prelude triggers signature inference).
- A `variant_decision_table` whose target permit doesn't implement the sealed parent, or names a behavior that doesn't exist on the parent.
- A permit name that collides with a participant name in the same input set.

### Backward compatibility
- When the `' @disc-entities` marker is absent, Step 2.8 short-circuits and the existing signature-inference path runs unchanged. All 9 demo `.puml` files in `design-is-code-demo` continue to generate identical output as v0.7.0.

### Deferred to v0.9
- UPDATE-entity support: extending a REUSE `record` with `+field:name:Type` or a REUSE `sealed-interface` with `+permit:Name`. Mirrors the existing participant `<<@class:fqn, +method>>` syntax.
- Pattern-match-host participant stereotype `<<pattern-match: targetEntity>>` for pure-sum sealed families (empty `behaviors[]`) where a participant's method body switches over the variants.

## [0.7.0] - 2026-05-19

### Added
- Fourth `participant_target` form: `defer:<path>`. Declared in PlantUML as `<<defer-design>>` (default sibling-folder path) or `<<defer-design:relative/path/Child.puml>>` (explicit). Marks a participant whose internals will be designed in a separate `.puml` later. Enables top-down design + bottom-up implementation across multi-level designs.
- STUB generation mode in Step 3f: emits the interface plus a throwing `@Component` stub (`Pending<Name>`) for `defer:` participants. No test class, no decision table — those come when DisC is run on the child `.puml`. Stub-impl throws `UnsupportedOperationException` with a `DisC: design pending` marker string that CI can grep to block production deploys.
- One-hop mocking invariant in SKILL.md: a `collaborator`'s own dependencies (grandchildren) never bubble up to the SUT's test. The SUT mocks each direct child as a unit regardless of its `participant_target`. Makes the boundary between parent and child designs explicit.
- Step 1 refusal cases for `defer:` participants: cannot be the entry interaction's target, cannot have outgoing `call_arrow`s in this diagram, mutually exclusive with `<<@class:fqn>>` on the same participant.
- Clarification in Step 1: decision-table files (`<Participant>.decision.md`) are read from the **same folder as the `.puml` being processed**, not from a project-wide `design/` root. Lets nested designs scope their decision tables to their level of the call tree.
- Stub Implementation Template in `java_spring.md` (`Pending<Name>` naming, `@Component` annotation, mandatory marker string).
- Step 8 report shape: new `Deferred:` line listing the count and child paths; new `STUB` label in the Files line.

### Changed
- `participant_target` concept in SKILL.md now lists four mutually-exclusive forms (`create`, `existing:`, `extend:`, `defer:`) instead of three.
- Step 2.6.5, Step 3f, Step 4 transformation table, Step 5 checks, and Step 6 implementation generation all updated to handle STUB mode.

## [0.6.0] - 2026-05-19

### Added
- `participant_target` concept (SKILL.md, Composition block): participants may now declare whether DisC should CREATE them new (default), REUSE an existing type as-is (`existing:<fqn>`), or UPDATE an existing type by adding methods (`extend:<fqn>:+method,...`). Replaces Step 3's heuristic glob-based file-mode detection when declared; the glob fallback is preserved for `.puml` files with no participant prelude.
- PlantUML stereotype notation for `participant_target` (`java_spring.md`): `<<@class:fqn>>` for reuse-as-is, `<<@class:fqn, +method1, +method2>>` for extend-with-new-methods. Documented with grammar, FQN form, method-list form, prelude position, and a worked example covering all three forms.
- Step 2.6.5: read `participant_target` per participant after the leaf-node sub-classification.
- Step 1 refusal cases for malformed stereotypes, `existing` participants with outgoing arrows, and `+method` lists that name methods not exercised by the diagram.
- Step 3f rewrite: file mode now derives primarily from `participant_target`; glob fallback covers v0.5.x files with no stereotypes.
- UPDATE Mode Rules clarification for the `extend:` case — UPDATE applies to all three files (interface, impl, test) for that participant; only listed `+method` signatures and matching `@Nested` test groups are added.
- Plan mode (`--plan` flag in `$ARGUMENTS`): executes Steps 1–6 internally and emits a single JSON envelope (`{actions, warnings, summary}`) to stdout instead of writing files. Enables host tools (DisC Studio) to render a preview-before-apply panel without mutating the user's filesystem.

### Changed
- Step 2 grows sub-step 2.6.5 to read `participant_target` stereotypes per participant.
- Step 3f rewritten — was `NEW → CREATE, EXISTS → UPDATE` based on file globs; now derives from `participant_target` with glob as fallback.

## [0.5.1] - 2026-05-12

### Changed
- Pipeline step headings renamed for clearer user-facing display (other platforms calling `/disc` show these as a progress sequence): `Validate Inputs` → `Validate Design`, `Classify` → `Classify Participants`, `Discover Context` → `Resolve Targets`, `Generate (apply Transformation Rules)` → `Generate Tests`, `Quality Gate` → `Check Tests`, `Implement (two-phase wall)` → `Generate Implementation`. Steps 7 and 8 unchanged. Step numbers unchanged.
- Walkthrough examples in `java_spring.md` now use SUT-anchored arrow style consistent with the demo `.puml` files: `SUT <-- Collaborator: value` for returns (not `Collaborator --> SUT: value`), and `[*] <-- SUT: value` for the return to `system_caller` (not `SUT --> [*]: value`). The boundary marker `[*]` and the SUT always anchor the left side of every line; arrow direction shows data flow. PlantUML accepts both forms; the disambiguation rule is unchanged.

## [0.5.0] - 2026-05-12

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
