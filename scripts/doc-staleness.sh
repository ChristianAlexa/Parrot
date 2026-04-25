#!/usr/bin/env bash
# Warn (don't block) when a git commit touches surface-area files
# whose docs may now be stale. Invoked as a Claude Code PreToolUse hook.
#
# Reads hook JSON from stdin, exits 0 silently unless the tool call is
# `git commit*` and the staged files include surface-area triggers.

set -uo pipefail

# Mode: --git-hook for git pre-commit, otherwise Claude Code PreToolUse hook
if [[ "${1:-}" != "--git-hook" ]]; then
  input=$(cat)
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)
  command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
  [[ "$tool_name" == "Bash" ]] || exit 0
  [[ "$command" =~ ^[[:space:]]*git[[:space:]]+commit ]] || exit 0
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" || exit 0

staged=$(git diff --cached --name-only 2>/dev/null)
[[ -n "$staged" ]] || exit 0

surface='^(Makefile|Package\.swift|Resources/Info\.plist|scripts/)'
echo "$staged" | grep -qE "$surface" || exit 0

DOCS=(README.md CLAUDE.md PRIVACY.md CHANGELOG.md)
findings=()

# Check 1: `make <target>` references that don't exist in Makefile
if [[ -f Makefile ]]; then
  targets=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_-]*:' Makefile | sed 's/:.*//' | sort -u)
  for doc in "${DOCS[@]}"; do
    [[ -f "$doc" ]] || continue
    while IFS= read -r hit; do
      line=${hit%%:*}
      rest=${hit#*:}
      while [[ "$rest" =~ \`make[[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*)\` ]]; do
        target="${BASH_REMATCH[1]}"
        if ! grep -qx "$target" <<<"$targets"; then
          findings+=("$doc:$line: missing make target \`$target\`")
        fi
        rest=${rest/${BASH_REMATCH[0]}/}
      done
    done < <(grep -nE '`make[[:space:]]+[a-zA-Z_]' "$doc" 2>/dev/null || true)
  done
fi

# Check 2: backtick'd repo-relative paths that don't exist
for doc in "${DOCS[@]}"; do
  [[ -f "$doc" ]] || continue
  while IFS= read -r hit; do
    line=${hit%%:*}
    rest=${hit#*:}
    for ref in $(grep -oE '`[^ \`]+/[^ \`]+`' <<<"$rest" | tr -d '`'); do
      [[ "$ref" =~ ^(/|~|\.\.|https?:) ]] && continue
      [[ "$ref" == */ ]] && ref="${ref%/}"
      if [[ ! -e "$ref" ]]; then
        findings+=("$doc:$line: missing path \`$ref\`")
      fi
    done
  done < <(grep -nE '`[^\` ]+/[^\` ]+`' "$doc" 2>/dev/null || true)
done

# Check 3: README claims zip output but Makefile produces DMG (or vice versa)
if [[ -f Makefile && -f README.md ]]; then
  makes_dmg=$(grep -q 'create-dmg\|\.dmg' Makefile && echo yes || echo no)
  if [[ "$makes_dmg" == yes ]]; then
    if hit=$(grep -niE 'zip (for distribution|installer|bundle)' README.md | head -1); then
      [[ -n "$hit" ]] && findings+=("README.md:${hit%%:*}: artifact drift — README mentions zip but Makefile builds a DMG")
    fi
  fi
fi

# Check 4: README "macOS NN+" disagrees with Info.plist LSMinimumSystemVersion
if [[ -f Resources/Info.plist && -f README.md ]]; then
  plist_min=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist 2>/dev/null | cut -d. -f1)
  if [[ -n "$plist_min" ]]; then
    if hit=$(grep -nE 'macOS[[:space:]]+[0-9]+\+' README.md | head -1); then
      readme_min=$(grep -oE '[0-9]+' <<<"${hit#*:}" | head -1)
      if [[ -n "$readme_min" && "$plist_min" != "$readme_min" ]]; then
        findings+=("README.md:${hit%%:*}: min-macOS drift — README says $readme_min+, Info.plist says $plist_min")
      fi
    fi
  fi
fi

if (( ${#findings[@]} > 0 )); then
  {
    echo ""
    echo "doc-staleness: ${#findings[@]} potential drift(s) — review before commit:"
    for f in "${findings[@]}"; do echo "  $f"; done
    echo ""
  } >&2
fi

exit 0
