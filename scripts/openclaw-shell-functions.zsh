# OpenClaw shell helpers
#
# Source this file from ~/.zshrc:
#   source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"

# -------- Project Listing --------
oc-projects() {
  local projects_root="$HOME/Projects"
  local found=0

  if [ ! -d "$projects_root" ]; then
    echo "No project contexts found under ~/Projects"
    return 0
  fi

  while IFS= read -r project_dir; do
    local context_file="$project_dir/context.md"

    if [ ! -f "$context_file" ]; then
      continue
    fi

    if [ "$found" -eq 0 ]; then
      printf '%-20s %-16s   %s\n' "Project" "Last Updated" "Next Step"
      printf '%-20s %-16s   %s\n' "--------------------" "----------------" "----------------------------------------"
      found=1
    fi

    local project_name="$(basename "$project_dir")"

    local last_updated="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$context_file")"

    local next_step="$(
      awk '
        /^##[[:space:]]+Next Step[[:space:]]*$/ {
          in_next_step = 1
          next
        }
        in_next_step && /^##[[:space:]]+/ {
          exit
        }
        in_next_step {
          line = $0
          sub(/^[[:space:]]*[-*+][[:space:]]+/, "", line)
          sub(/^[[:space:]]+/, "", line)
          sub(/[[:space:]]+$/, "", line)
          if (line != "") {
            print line
            exit
          }
        }
      ' "$context_file" | sed 's/[[:space:]][[:space:]]*/ /g'
    )"

    if [ -z "$next_step" ]; then
      next_step="None"
    fi

    printf '%-20s %-16s   %s\n' "$project_name" "$last_updated" "$next_step"
  done < <(find "$projects_root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | sort)

  if [ "$found" -eq 0 ]; then
    echo "No project contexts found under ~/Projects"
  fi
}

# -------- Context Capture --------
oc-capture() {
  local project_name="${1:-openclaw-operator}"
  local input_file="$2"
  local project_dir="$HOME/Projects/$project_name"
  local context_file="$project_dir/context.md"
  local history_file="$project_dir/history.log"
  local input_source="interactive"
  local input

  if [ -n "$input_file" ]; then
    if [ ! -f "$input_file" ]; then
      echo "Input file not found: $input_file"
      return 1
    fi

    input_source="file: $input_file"
    input="$(cat "$input_file")"
  elif [ ! -t 0 ]; then
    input_source="stdin"
    input="$(cat)"
  else
    echo "Enter project status update for: $project_name"
    echo "Press Ctrl-D when finished:"
    echo

    input="$(cat)"
  fi

  if [ -z "$input" ]; then
    echo "No input received. Aborting."
    return 1
  fi

  mkdir -p "$project_dir"

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo
    echo "[$timestamp]"
    echo "Source: $input_source"
    echo "$input"
  } >> "$history_file"

  local session_id
  session_id="capture-${project_name}-$(date +%s)"

  local raw_output_file
  raw_output_file="$(mktemp)"

  local filtered_output_file
  filtered_output_file="$(mktemp)"

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
    {
      gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
    }
    found {
      print
      next
    }
    index($0, "# Project Context") {
      found = 1
      print "# Project Context"
    }
  ' "$raw_output_file" > "$filtered_output_file"

  if [ ! -s "$filtered_output_file" ]; then
    echo "Warning: # Project Context not found; saved decoration-stripped output for inspection."

    awk '
      {
        gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
      }
      /^🦞 OpenClaw/ { next }
      /^[[:space:]]*│[[:space:]]*$/ { next }
      /^[[:space:]]*◇[[:space:]]*$/ { next }
      !started && /^[[:space:]]*$/ { next }
      {
        started = 1
        print
      }
    ' "$raw_output_file" > "$filtered_output_file"
  fi

  if [ ! -s "$filtered_output_file" ] && [ -s "$raw_output_file" ]; then
    tee "$context_file" < "$raw_output_file"
    echo "Warning: filtered output was empty; saved raw output for inspection."
  elif [ ! -s "$filtered_output_file" ]; then
    printf '%s\n' "Warning: filtered output was empty; saved raw output for inspection." | tee "$context_file"
  else
    tee "$context_file" < "$filtered_output_file"
  fi

  rm -f "$raw_output_file" "$filtered_output_file"

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
You are preparing an operational resume summary for this project.

Use ONLY the project context below.
Do NOT use prior conversation history.
Do NOT invent tools, files, commands, workflows, or framework internals.
Do NOT mention unrelated projects.
Do NOT give generic productivity advice.
Do NOT use motivational language.
Do NOT use emoji.
Do NOT use a markdown table.
Avoid repetitive wording.
Keep the full response under roughly 250 words.
If the context is thin, say that briefly and still recommend one practical next step.

Return exactly these sections and no others:

Project Status
- 2-4 bullets summarizing the current project state

Active Work
- 1-3 bullets describing what is currently in progress

Blockers / Risks
- 0-3 bullets
- If none are present in the context, write: None

Recommended Next Action
- One clear next action only

First Step
- One concrete first step the user can take immediately

Resume Prompt
- One concise prompt the user can use later

Project:
$project_name

Context:
$context
"
}
