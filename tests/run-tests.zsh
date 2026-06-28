#!/usr/bin/env zsh
set -euo pipefail

repo_root="${0:A:h:h}"
source "$repo_root/scripts/openclaw-shell-functions.zsh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq -- "$expected" "$file"; then
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

  if grep -Fq -- "$unexpected" "$file"; then
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

  first_line="$(grep -Fn -- "$first" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -Fn -- "$second" "$file" | tail -n 1 | cut -d: -f1)"

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

plex_fixture="$repo_root/tests/fixtures/readmes/Plex_Catalogue.md"
plex_output="$tmpdir/plex-prioritized.md"

oc__prioritize_operational_sections "$plex_fixture" "$plex_output"

assert_contains "$plex_output" "OPERATIONAL README SECTION EXCERPTS:"
assert_contains "$plex_output" "## Roadmap"
assert_contains "$plex_output" "Auto-cleanup old timestamped folders after successful upload"
assert_contains "$plex_output" "FULL RAW PROJECT UPDATE:"
assert_before "$plex_output" "## Roadmap" "## Requirements"
assert_before "$plex_output" "Export the wishlist to Google Sheets" "Run the exporter:"

anonymizer_fixture="$repo_root/tests/fixtures/readmes/Simple-Doc-Anonymizer.md"
anonymizer_output="$tmpdir/anonymizer-prioritized.md"

oc__prioritize_operational_sections "$anonymizer_fixture" "$anonymizer_output"

assert_contains "$anonymizer_output" "OPERATIONAL README SECTION EXCERPTS:"
assert_contains "$anonymizer_output" "## Known Limitations"
assert_contains "$anonymizer_output" "PDF write-back not supported"
assert_contains "$anonymizer_output" "FULL RAW PROJECT UPDATE:"
assert_before "$anonymizer_output" "## Known Limitations" "## Setup"
assert_before "$anonymizer_output" "If the span merger is joining spans that should stay separate" "python detect.py --doc input/sample_document.txt"

weak_next_fixture="$repo_root/tests/fixtures/readmes/Weak_Next_Steps.md"
weak_next_output="$tmpdir/weak-next-prioritized.md"

oc__prioritize_operational_sections "$weak_next_fixture" "$weak_next_output"

assert_contains "$weak_next_output" "OPERATIONAL README SECTION EXCERPTS:"
assert_contains "$weak_next_output" "## Current MVP"
assert_contains "$weak_next_output" "## Roadmap Notes"
assert_contains "$weak_next_output" "## Later / nice to have"
assert_contains "$weak_next_output" "Phone notifications are not implemented yet."
assert_before "$weak_next_output" "Phone notifications are not implemented yet." "Run the app locally with the documented command."

phase_roadmap_fixture="$repo_root/tests/fixtures/readmes/Phase_Roadmap.md"
phase_roadmap_output="$tmpdir/phase-roadmap-prioritized.md"

oc__prioritize_operational_sections "$phase_roadmap_fixture" "$phase_roadmap_output"

assert_contains "$phase_roadmap_output" "OPERATIONAL README SECTION EXCERPTS:"
assert_contains "$phase_roadmap_output" "## Phase 2 Roadmap"
assert_contains "$phase_roadmap_output" "### Future Enhancement - Document Ingestion Engine"
assert_contains "$phase_roadmap_output" "Evaluate uploaded PDF, DOCX, and PPTX parsing before adding dependencies."
assert_before "$phase_roadmap_output" "## Phase 2 Roadmap" "## Getting Started"

valid_context_fixture="$tmpdir/valid-context.md"
cat > "$valid_context_fixture" <<'EOF'
# Project Context

## Project
weak-next-steps

## Current State
- Local server is implemented.

## In Progress
- No explicit in-progress work found

## Open Issues
- Phone notifications are not implemented yet.

## Next Step
- Inferred: Implement phone notifications for due and overdue reminders.

## Suggested Resume Prompt
"Resume weak-next-steps and implement phone notifications."
EOF

oc__has_valid_context_output "$valid_context_fixture"

invalid_context_fixture="$tmpdir/invalid-context.md"
cat > "$invalid_context_fixture" <<'EOF'
# Project Context

## Project
weak-next-steps

## Current State
- Local server is implemented.

## Next Step
- Inferred: Implement phone notifications.
EOF

if oc__has_valid_context_output "$invalid_context_fixture"; then
  echo "Expected context missing required sections to fail validation"
  exit 1
fi

idea_home="$tmpdir/idea-home"
idea_fixture="$tmpdir/idea.md"
cat > "$idea_fixture" <<'EOF'
---
id: idea-2026-0627-local-idea-capture
title: "Local Idea Capture"
captured: 2026-06-27
status: raw
source: openai
tags: [openclaw, idea-capture]
one_line: "Capture raw application ideas into deterministic markdown files for later promotion."
promoted_to: null
---

## Idea

Capture early-stage app ideas as structured markdown before they become full projects. The import path should stay deterministic and local-first so the idea backlog can be searched, reviewed, and promoted later without forcing every thought into a project immediately.

The idea agent handles conversation and synthesis, while `oc-idea-import` validates the final artifact and writes it into `~/Projects/.ideas/`.

## Open questions

- How much metadata should be required before promotion?

## Update Log

<!-- left empty at capture time; populated later by oc-idea-update -->
EOF

idea_import_output="$tmpdir/idea-import-output.txt"
HOME="$idea_home" oc-idea-import "$idea_fixture" > "$idea_import_output"
assert_contains "$idea_import_output" "Imported idea: idea-2026-0627-local-idea-capture"
assert_contains "$idea_import_output" "Saved to: $idea_home/Projects/.ideas/idea-2026-0627-local-idea-capture.md"
assert_contains "$idea_home/Projects/.ideas/idea-2026-0627-local-idea-capture.md" "source: openai"
assert_contains "$idea_home/Projects/.ideas/idea-2026-0627-local-idea-capture.md" "## Update Log"

HOME="$idea_home" oc-idea-import "$idea_fixture" > "$idea_import_output"
assert_contains "$idea_import_output" "Imported idea: idea-2026-0627-local-idea-capture-2"
assert_contains "$idea_home/Projects/.ideas/idea-2026-0627-local-idea-capture-2.md" "id: idea-2026-0627-local-idea-capture-2"

invalid_idea_fixture="$tmpdir/invalid-idea.md"
cat > "$invalid_idea_fixture" <<'EOF'
---
id: idea-2026-0627-local-idea-capture
title: "Local Idea Capture"
captured: 2026-06-27
status: explored
source: openai
tags: [openclaw, idea-capture]
one_line: "Capture raw application ideas into deterministic markdown files for later promotion."
promoted_to: null
---

## Idea

Invalid because status is not raw.

## Open questions

## Update Log
EOF

if HOME="$idea_home" oc-idea-import "$invalid_idea_fixture" > "$idea_import_output"; then
  echo "Expected invalid idea status to fail"
  exit 1
fi
assert_contains "$idea_import_output" "Invalid idea status: explored"

portfolio_home="$tmpdir/home"
meal_dir="$portfolio_home/Projects/meal-planner"
smoke_dir="$portfolio_home/Projects/api-smoke-test"
operator_dir="$portfolio_home/Projects/openclaw-operator"
validator_dir="$portfolio_home/Projects/context-validator"
cookbook_dir="$portfolio_home/Projects/cookbook"
family_cookbook_dir="$portfolio_home/Projects/family-cookbook"
mkdir -p "$meal_dir" "$smoke_dir" "$operator_dir" "$validator_dir" "$cookbook_dir" "$family_cookbook_dir"

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

cat > "$operator_dir/context.md" <<'EOF'
# Project Context

## Project
openclaw-operator

## Current State
- Functional local-first project context tooling is implemented and used across active projects.

## In Progress
- Refine deterministic portfolio report after README capture quality is validated.

## Open Issues
- api-smoke-test still shows Source missing, but it is an archive candidate and was intentionally skipped.

## Next Step
- Review oc-portfolio for projects whose next steps need manual overrides.
EOF

cat > "$validator_dir/context.md" <<'EOF'
# Project Context

## Project
context-validator

## Current State
- Context validation helper has a draft parser and fixture layout.

## In Progress
- No explicit in-progress work found

## Open Issues
- Needs validation against malformed context files.

## Next Step
- Add malformed context fixtures.
EOF

cat > "$cookbook_dir/context.md" <<'EOF'
# Project Context

## Project
cookbook

## Current State
- Test-only duplicate cookbook spike with no useful project purpose.

## In Progress
- No explicit in-progress work found

## Open Issues
- Superseded by family-cookbook.

## Next Step
- Archive the duplicate cookbook spike.
EOF

cat > "$family_cookbook_dir/context.md" <<'EOF'
# Project Context

## Project
cookbook

## Current State
- Functional family cookbook site is implemented and running locally.
- Recipe pages build from structured content and preserve a /cookbook/ path prefix.

## In Progress
- Add continuous integration for schema and link validation.

## Open Issues
- GitHub Pages validation is not yet automated.

## Next Step
- Add a GitHub Actions workflow for family-cookbook build validation.
EOF

list_output="$tmpdir/list-output.txt"
HOME="$portfolio_home" oc-list > "$list_output"
assert_contains "$list_output" "cookbook"
assert_contains "$list_output" "family-cookbook"
assert_contains "$list_output" "openclaw-operator"
assert_not_contains "$list_output" "Last Updated"

help_output="$tmpdir/help-output.txt"
oc-help > "$help_output"
assert_contains "$help_output" "OPENCLAW-OPERATOR(1)"
assert_contains "$help_output" "oc-list"
assert_contains "$help_output" "oc-idea-import [input-file]"
assert_contains "$help_output" "oc-projects --grouped [state]"
assert_contains "$help_output" "oc-status <project>"

portfolio_output="$tmpdir/portfolio-output.md"
HOME="$portfolio_home" oc-portfolio > "$portfolio_output"

assert_contains "$portfolio_output" "## Maintain"
assert_contains "$portfolio_output" "meal-planner - intent: Sustain; project appears operational"
assert_contains "$portfolio_output" "context-validator - intent: Explore; context has open issues or validation gaps; next: Add malformed context fixtures."
assert_contains "$portfolio_output" "api-smoke-test - intent: Sunset; context indicates a test-only"
assert_not_contains "$portfolio_output" "meal-planner - context indicates a test-only"
assert_not_contains "$portfolio_output" "openclaw-operator - intent: Sunset"
assert_contains "$portfolio_output" "openclaw-operator - intent: Invest; active in-progress work and concrete next step"
assert_contains "$portfolio_output" "cookbook - intent: Sunset; context indicates a test-only"
assert_contains "$portfolio_output" "family-cookbook - intent: Invest; active in-progress work and concrete next step; next: Add a GitHub Actions workflow for family-cookbook build validation."
assert_not_contains "$portfolio_output" "family-cookbook - intent: Sunset"

assert_contains "$portfolio_output" "meal-planner - intent: Sustain"
assert_contains "$portfolio_output" "api-smoke-test - intent: Sunset"

grouped_projects_output="$tmpdir/grouped-projects-output.md"
HOME="$portfolio_home" oc-projects --grouped > "$grouped_projects_output"

assert_contains "$grouped_projects_output" "# Projects by Portfolio State"
assert_contains "$grouped_projects_output" "## Continue"
assert_contains "$grouped_projects_output" "openclaw-operator - next: Review oc-portfolio for projects whose next steps need manual overrides."
assert_contains "$grouped_projects_output" "## Maintain"
assert_contains "$grouped_projects_output" "meal-planner - next: Verify the documented startup workflow."
assert_contains "$grouped_projects_output" "## Review"
assert_contains "$grouped_projects_output" "context-validator - next: Add malformed context fixtures."
assert_contains "$grouped_projects_output" "## Archive Candidates"
assert_contains "$grouped_projects_output" "- api-smoke-test"
assert_contains "$grouped_projects_output" "- cookbook"
assert_contains "$grouped_projects_output" "family-cookbook - next: Add a GitHub Actions workflow for family-cookbook build validation."
assert_not_contains "$grouped_projects_output" "intent:"
assert_not_contains "$grouped_projects_output" "context indicates a test-only"

review_output="$tmpdir/review-output.md"
HOME="$portfolio_home" oc-portfolio --review > "$review_output"
assert_contains "$review_output" "# Project Review Queue"
assert_contains "$review_output" "## context-validator"
assert_contains "$review_output" "- Reason: context has open issues or validation gaps"
assert_contains "$review_output" "- Next: Add malformed context fixtures."
assert_contains "$review_output" "- Suggested action: Review the gaps, then update context or move the project to Continue, Pause, or Archive."
assert_not_contains "$review_output" "## meal-planner"
assert_not_contains "$review_output" "## api-smoke-test"

if HOME="$portfolio_home" oc-portfolio --bogus > "$portfolio_output"; then
  echo "Expected invalid portfolio argument to fail"
  exit 1
fi
assert_contains "$portfolio_output" "Usage: oc-portfolio [--review]"

HOME="$portfolio_home" oc-projects --grouped Continue > "$grouped_projects_output"
assert_contains "$grouped_projects_output" "# Projects by Portfolio State"
assert_contains "$grouped_projects_output" "## Continue"
assert_contains "$grouped_projects_output" "openclaw-operator - next: Review oc-portfolio for projects whose next steps need manual overrides."
assert_not_contains "$grouped_projects_output" "## Maintain"
assert_not_contains "$grouped_projects_output" "meal-planner"

HOME="$portfolio_home" oc-projects --grouped archive > "$grouped_projects_output"
assert_contains "$grouped_projects_output" "## Archive Candidates"
assert_contains "$grouped_projects_output" "- api-smoke-test"
assert_not_contains "$grouped_projects_output" "## Continue"
assert_not_contains "$grouped_projects_output" "openclaw-operator"

HOME="$portfolio_home" oc-projects --grouped Archive Candidates > "$grouped_projects_output"
assert_contains "$grouped_projects_output" "## Archive Candidates"
assert_contains "$grouped_projects_output" "- api-smoke-test"
assert_not_contains "$grouped_projects_output" "## Continue"

if HOME="$portfolio_home" oc-projects --grouped Unknown > "$grouped_projects_output"; then
  echo "Expected invalid grouped state to fail"
  exit 1
fi
assert_contains "$grouped_projects_output" "Invalid group: Unknown"
assert_contains "$grouped_projects_output" "Valid groups: Continue, Maintain, Review, Pause, Archive Candidates, Missing / Thin Context"

HOME="$portfolio_home" oc-portfolio-set meal-planner Pause Invest > /dev/null
HOME="$portfolio_home" oc-portfolio > "$portfolio_output"
assert_contains "$portfolio_output" "## Pause"
assert_contains "$portfolio_output" "meal-planner - intent: Invest; manual state override (automatic: Maintain)"

HOME="$portfolio_home" oc-projects --grouped > "$grouped_projects_output"
assert_contains "$grouped_projects_output" "## Pause"
assert_contains "$grouped_projects_output" "meal-planner - next: Verify the documented startup workflow."

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
