#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

usage() {
  echo "Usage: $(basename "$0") <minor|patch>"
  echo ""
  echo "  minor  — new features, structural changes (0.1.0 → 0.2.0)"
  echo "  patch  — bug fixes, docs-only changes   (0.1.0 → 0.1.1)"
  exit 1
}

[[ $# -eq 1 ]] || usage

BUMP_TYPE="$1"
[[ "$BUMP_TYPE" == "minor" || "$BUMP_TYPE" == "patch" ]] || usage

# --- Read current version ---
CURRENT_VERSION=$(grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: could not read version from $PLUGIN_JSON"
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# --- Compute new version ---
if [[ "$BUMP_TYPE" == "minor" ]]; then
  MINOR=$((MINOR + 1))
  PATCH=0
else
  PATCH=$((PATCH + 1))
fi
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "Releasing: $CURRENT_VERSION → $NEW_VERSION"

# --- Guard: tag must not exist ---
if git -C "$REPO_ROOT" tag -l "v$NEW_VERSION" | grep -q "v$NEW_VERSION"; then
  echo "Error: tag v$NEW_VERSION already exists"
  exit 1
fi

# --- Guard: unstaged or untracked changes (staged changes are intentional and will be included) ---
UNSTAGED=$(git -C "$REPO_ROOT" diff --name-only | grep -v 'CHANGELOG.md' | grep -v 'plugin.json' || true)
UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard | grep -v 'CHANGELOG.md' | grep -v 'plugin.json' || true)
if [[ -n "$UNSTAGED" || -n "$UNTRACKED" ]]; then
  echo "Error: working tree has uncommitted changes. Stage, commit, or stash them first."
  [[ -n "$UNSTAGED" ]] && echo "$UNSTAGED"
  [[ -n "$UNTRACKED" ]] && echo "$UNTRACKED"
  exit 1
fi

# --- Guard: unreleased entries exist ---
UNRELEASED_CONTENT=$(sed -n '/^## \[Unreleased\]/,/^## \[/{ /^## \[/d; /^[[:space:]]*$/d; p; }' "$CHANGELOG")
if [[ -z "$UNRELEASED_CONTENT" ]]; then
  echo "Error: no entries under [Unreleased] in CHANGELOG.md"
  echo "Add your changes there first, then re-run."
  exit 1
fi

# --- Update CHANGELOG.md ---
TODAY=$(date +%Y-%m-%d)
sed -i '' "s/^## \[Unreleased\]/## [Unreleased]\\
\\
## [$NEW_VERSION] - $TODAY/" "$CHANGELOG"

# --- Update plugin.json ---
sed -i '' "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"

# --- Commit and tag ---
git -C "$REPO_ROOT" add "$CHANGELOG" "$PLUGIN_JSON"
git -C "$REPO_ROOT" commit -m "release v$NEW_VERSION"
git -C "$REPO_ROOT" tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION"

echo ""
echo "Done! v$NEW_VERSION committed and tagged."
echo "Run 'git push --follow-tags' to publish."
