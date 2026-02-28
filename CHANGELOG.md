# Changelog

All notable changes to the design-is-code plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
