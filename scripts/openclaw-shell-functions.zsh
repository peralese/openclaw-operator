# OpenClaw shell helpers
#
# Source this file from ~/.zshrc:
#   source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"

# -------- Context Capture --------
oc-capture() {
  local project_name="${1:-openclaw-operator}"
  local project_dir="$HOME/Projects/$project_name"
  local context_file="$project_dir/context.md"
  local history_file="$project_dir/history.log"

  mkdir -p "$project_dir"

  echo "Enter project status update for: $project_name"
  echo "Press Ctrl-D when finished:"
  echo

  local input
  input="$(cat)"

  if [ -z "$input" ]; then
    echo "No input received. Aborting."
    return 1
  fi

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo
    echo "[$timestamp]"
    echo "$input"
  } >> "$history_file"

  local session_id
  session_id="capture-${project_name}-$(date +%s)"

  local raw_output_file
  raw_output_file="$(mktemp)"

  openclaw agent --agent main --session-id "$session_id" --message "
You are a Project Context Intake Agent.

TASK:
Distill the raw project update below into a compact, deterministic project context snapshot for later resume.

CRITICAL CONTEXT ISOLATION RULES:
- Treat the raw update as the only source of truth
- Ignore prior agent memory, prior conversations, prior context.md files, and other project contexts
- Do NOT import details from unrelated projects
- Do NOT merge this update with any other project
- Only use information explicitly provided in the raw update
- Do NOT mention OpenClaw unless the raw update is specifically about OpenClaw
- Do NOT invent commands, files, OpenClaw internals, cron jobs, dashboards, automations, issues, or next steps
- If a field is unknown, write \"None\"

OUTPUT RULES:
- Output exactly the markdown structure below
- Use short bullets only in bullet sections
- Keep the final context under roughly 500 words
- Do not include commentary before or after the structured output
- Do not include validation commentary
- Do not include confidence scores
- Do not include extra sections

REQUIRED OUTPUT FORMAT:

# Project Context

## Project
<project name or inferred name>

## Current State
- ...

## In Progress
- ...

## Open Issues
- ...

## Next Step
- ...

## Suggested Resume Prompt
\"<one concise prompt the user can paste later>\"

PROJECT NAME:
$project_name

RAW PROJECT UPDATE:
$input
" > "$raw_output_file"

  awk '
    /^🦞 OpenClaw/ { next }
    /^[[:space:]]*│[[:space:]]*$/ { next }
    /^[[:space:]]*◇[[:space:]]*$/ { next }
    !started {
      if ($0 == "# Project Context") {
        started = 1
        print
      }
      next
    }
    { print }
  ' "$raw_output_file" | tee "$context_file"

  rm -f "$raw_output_file"

  echo
  echo "Saved distilled context to: $context_file"
  echo "Appended raw update to: $history_file"
}


# -------- Resume / Continuity --------
oc-continue() {
  local project_name="${1:-openclaw-operator}"
  local project_dir="$HOME/Projects/$project_name"
  local context_file="$project_dir/context.md"

  if [ ! -f "$context_file" ]; then
    echo "Context file not found: $context_file"
    return 1
  fi

  local session_id
  session_id="continue-${project_name}-$(date +%s)"

  local context
  context="$(
    awk '
      {
        gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
      }
      /Project:/ {
        sub(/^.*Project:/, "Project:")
      }
      /Waiting for agent reply/ { next }
      /^🦞 OpenClaw/ { next }
      /^[[:space:]]*│/ { next }
      /^[[:space:]]*◇/ { next }
      !started {
        if ($0 == "# Project Context" || $0 ~ /^Project:[[:space:]]*$/ || $0 ~ /^Current State:?[[:space:]]*$/) {
          started = 1
          print
        }
        next
      }
      { print }
    ' "$context_file" | head -c 8000
  )"

  openclaw agent --agent main --session-id "$session_id" --message "
You are a Session Continuity Agent.

Use ONLY the project context below.
Do NOT use prior conversation history.
Do NOT invent tools, files, commands, workflows, or framework internals.

Output format:

Current State
In Progress
Open Issues
Most Important Next Step
Why This Matters
Exact Actions
Suggested Resume Prompt

Project:
$project_name

Context:
$context
"
}
