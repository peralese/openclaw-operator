#!/usr/bin/env zsh
set -euo pipefail

repo_root="${0:A:h:h}"
source "$repo_root/scripts/openclaw-shell-functions.zsh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "Expected to find: $expected"
    echo "In file: $file"
    echo
    cat "$file"
    return 1
  fi
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line second_line

  first_line="$(grep -Fn "$first" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -Fn "$second" "$file" | tail -n 1 | cut -d: -f1)"

  if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
    echo "Expected '$first' to appear before '$second'"
    echo "In file: $file"
    echo
    cat "$file"
    return 1
  fi
}

readme_fixture="$tmpdir/readme.md"
prioritized_output="$tmpdir/prioritized.md"

cat > "$readme_fixture" <<'EOF'
# Example Project

## Installation

Run a long setup process.

## Architecture

This section has many implementation details that are less useful when choosing the next action.

## Roadmap

- Add regression coverage for README ingestion.
- Validate capture output against real project READMEs.

## Known Limitations

- Next steps can be buried below setup and architecture sections.
EOF

oc__prioritize_operational_sections "$readme_fixture" "$prioritized_output"

assert_contains "$prioritized_output" "OPERATIONAL README SECTION EXCERPTS:"
assert_contains "$prioritized_output" "## Roadmap"
assert_contains "$prioritized_output" "## Known Limitations"
assert_contains "$prioritized_output" "FULL RAW PROJECT UPDATE:"
assert_before "$prioritized_output" "Add regression coverage for README ingestion." "Run a long setup process."

plain_fixture="$tmpdir/plain.txt"
plain_output="$tmpdir/plain-output.txt"

cat > "$plain_fixture" <<'EOF'
Short project update with no markdown sections.
EOF

oc__prioritize_operational_sections "$plain_fixture" "$plain_output"

if ! cmp -s "$plain_fixture" "$plain_output"; then
  echo "Expected input without operational markdown sections to pass through unchanged"
  exit 1
fi

zero_budget_output="$tmpdir/zero-budget-output.md"
oc__prioritize_operational_sections "$readme_fixture" "$zero_budget_output" 0

if ! cmp -s "$readme_fixture" "$zero_budget_output"; then
  echo "Expected zero excerpt budget to pass input through unchanged"
  exit 1
fi

echo "All tests passed."
