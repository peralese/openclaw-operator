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

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    echo "Did not expect to find: $unexpected"
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

portfolio_home="$tmpdir/home"
meal_dir="$portfolio_home/Projects/meal-planner"
smoke_dir="$portfolio_home/Projects/api-smoke-test"
mkdir -p "$meal_dir" "$smoke_dir"

cat > "$meal_dir/context.md" <<'EOF'
# Project Context

## Project
meal-planner

## Current State
- Functional meal-planning app is implemented and running on the local network.
- Shopping-list ingredients are aggregated and deduplicated.

## In Progress
- No explicit in-progress work found

## Open Issues
- Documentation could be clearer.

## Next Step
- Verify the documented startup workflow.
EOF

cat > "$smoke_dir/context.md" <<'EOF'
# Project Context

## Project
api-smoke-test

## Current State
- Test-only API smoke test with no useful project purpose.

## In Progress
- No explicit in-progress work found

## Open Issues
- None

## Next Step
- Archive the test repository.
EOF

portfolio_output="$tmpdir/portfolio-output.md"
HOME="$portfolio_home" oc-portfolio > "$portfolio_output"

assert_contains "$portfolio_output" "## Maintain"
assert_contains "$portfolio_output" "meal-planner - intent: Sustain; project appears operational"
assert_contains "$portfolio_output" "api-smoke-test - intent: Sunset; context indicates a test-only"
assert_not_contains "$portfolio_output" "meal-planner - context indicates a test-only"

assert_contains "$portfolio_output" "meal-planner - intent: Sustain"
assert_contains "$portfolio_output" "api-smoke-test - intent: Sunset"

HOME="$portfolio_home" oc-portfolio-set meal-planner Pause Invest > /dev/null
HOME="$portfolio_home" oc-portfolio > "$portfolio_output"
assert_contains "$portfolio_output" "## Pause"
assert_contains "$portfolio_output" "meal-planner - intent: Invest; manual state override (automatic: Maintain)"

status_output="$tmpdir/status-output.txt"
HOME="$portfolio_home" oc-status meal-planner > "$status_output"
assert_contains "$status_output" "Portfolio State: Pause (manual)"
assert_contains "$status_output" "Strategic Intent: Invest (manual)"

HOME="$portfolio_home" oc-portfolio-set meal-planner auto auto > /dev/null

cat > "$meal_dir/README.md" <<'EOF'
# Meal Planner

Initial source.
EOF

oc__record_capture_source "$meal_dir" "$meal_dir/README.md"
rescan_output="$tmpdir/rescan-output.txt"
HOME="$portfolio_home" oc-rescan > "$rescan_output"
assert_contains "$rescan_output" "meal-planner"
assert_contains "$rescan_output" "Current"

cat >> "$meal_dir/README.md" <<'EOF'

Changed source.
EOF

HOME="$portfolio_home" oc-rescan > "$rescan_output"
assert_contains "$rescan_output" "Changed"

echo "All tests passed."
