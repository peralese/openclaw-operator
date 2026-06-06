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

# -------- Project Status --------
oc-status() {
  local project_name="$1"

  if [ -z "$project_name" ]; then
    echo "Usage: oc-status <project>"
    return 1
  fi

  local project_dir="$HOME/Projects/$project_name"
  local context_file="$project_dir/context.md"
  local display_context_file="~/Projects/$project_name/context.md"

  if [ ! -f "$context_file" ]; then
    echo "Context file not found: $display_context_file"
    return 1
  fi

  local last_updated
  last_updated="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$context_file")"

  awk -v fallback_project="$project_name" -v last_updated="$last_updated" '
    function ltrim(s) {
      sub(/^[[:space:]]+/, "", s)
      return s
    }

    function rtrim(s) {
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function trim(s) {
      return rtrim(ltrim(s))
    }

    function append_section(name, line) {
      line = rtrim(line)

      if (name == "Project") {
        if (project == "" && trim(line) != "") {
          project = trim(line)
        }
        return
      }

      if (line ~ /^[[:space:]]*$/) {
        if (section_text[name] != "") {
          pending_blank[name] = 1
        }
        return
      }

      if (pending_blank[name]) {
        section_text[name] = section_text[name] "\n"
        pending_blank[name] = 0
      }

      section_text[name] = section_text[name] line "\n"
    }

    function print_section(name, value) {
      sub(/\n+$/, "", value)
      print ""
      print name
      if (value == "") {
        print "None"
      } else {
        print value
      }
    }

    BEGIN {
      wanted["Project"] = 1
      wanted["Current State"] = 1
      wanted["In Progress"] = 1
      wanted["Open Issues"] = 1
      wanted["Next Step"] = 1
      wanted["Suggested Resume Prompt"] = 1
      order[1] = "Current State"
      order[2] = "In Progress"
      order[3] = "Open Issues"
      order[4] = "Next Step"
      order[5] = "Suggested Resume Prompt"
    }

    {
      line = $0
      sub(/\r$/, "", line)
      header = rtrim(line)

      if (header ~ /^##[[:space:]]+/) {
        current = header
        sub(/^##[[:space:]]+/, "", current)
        current = rtrim(current)
        next
      }

      if (current in wanted) {
        append_section(current, line)
      }
    }

    END {
      if (project == "") {
        project = fallback_project
      }

      print "Project: " project
      print "Last Updated: " last_updated

      for (i = 1; i <= 5; i++) {
        print_section(order[i], section_text[order[i]])
      }
    }
  ' "$context_file"
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
If the raw update is a README or project documentation, do not merely summarize it. Extract documentation-derived operational project state.

CRITICAL CONTEXT ISOLATION RULES:
- Treat the raw update as the only source of truth
- Ignore prior agent memory, prior conversations, prior context.md files, and other project contexts
- Do NOT import details from unrelated projects
- Do NOT merge this update with any other project
- Use explicit information from the raw update first
- You may make conservative operational inferences from the raw update when they are useful, but label inferred next steps with \"Inferred: \"
- Do NOT mention OpenClaw unless the raw update is specifically about OpenClaw
- Do NOT invent commands, files, OpenClaw internals, cron jobs, dashboards, automations, issues, features, or project details
- If a field is unknown, write \"None\"

README AND DOCUMENTATION INGESTION RULES:
- Prioritize operational context over generic documentation
- Extract what the project appears to do, its current maturity or working state, what is implemented, what is in progress, open issues, gaps, risks, missing pieces, and the most actionable next step
- Represent current maturity or working state as a Current State bullet
- If operational evidence is weak or the README lacks status-like information, say so under Open Issues
- Prioritize sections named or resembling: Next Step, Next Steps, TODO, Roadmap, Open Issues, Known Issues, Known Limitations, In Progress, Current Status, Current State, Recent Work, Changelog
- Deprioritize installation/setup instructions, generic feature lists, marketing descriptions, long architecture explanations, badges, and dependency lists unless they indicate operational state

NEXT STEP SELECTION RULES:
- Always prefer one concrete, verb-led action that a developer or project owner can do next
- A good next step starts with an action verb such as Implement, Fix, Add, Validate, Document, Review, Test, Refine, or Rerun
- Do not use vague next steps such as Continue work, Improve project, Investigate later, Consider enhancements, or None
- First look for explicit next-step language in sections named or resembling Next Step, Next Steps, TODO, Roadmap, Open Issues, Known Issues, Known Limitations, In Progress, Current Status, Current State, Recent Work, or Changelog
- If no explicit next step exists, infer one from the most operational gap, risk, known limitation, failing workflow, unfinished roadmap item, or missing validation described in the raw update
- If inferring from gaps or limitations, choose the action that most directly improves usability, reliability, correctness, validation, or documentation
- Use \"No explicit next step found in README\" only when the raw update provides no useful operational gap, risk, limitation, roadmap item, TODO, unfinished work, or validation target

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
- <3-5 bullets about what appears implemented, working, true now, or the current maturity/working state>

## In Progress
- <1-4 bullets about active work or inferred active work>
- If none found, say exactly: No explicit in-progress work found

## Open Issues
- <1-5 bullets about gaps, risks, missing pieces, unclear docs, limitations, or weak operational evidence>
- If none found, say exactly: No explicit open issues found

## Next Step
- <exactly one most actionable, concrete, verb-led next step>
- If inferred, start with: Inferred:
- If no explicit next step exists and no useful conservative inference can be made from gaps, risks, limitations, roadmap items, TODOs, unfinished work, or validation targets, say exactly: No explicit next step found in README

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
