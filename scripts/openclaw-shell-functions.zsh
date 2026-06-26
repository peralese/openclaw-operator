# OpenClaw shell helpers
#
# Source this file from ~/.zshrc:
#   source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"

oc__load_env() {
  local env_file="${OPENCLAW_ENV_FILE:-$HOME/Projects/openclaw-operator/.env}"

  if [ ! -f "$env_file" ]; then
    return 0
  fi

  local line key value current_value

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [ -z "$line" ] || [[ "$line" != *=* ]]; then
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    if [[ ! "$key" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || [ -z "$value" ]; then
      continue
    fi

    current_value="${(P)key}"
    if [ -n "$current_value" ]; then
      continue
    fi

    export "$key=$value"
  done < "$env_file"
}

oc__load_env

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

# -------- Portfolio Triage --------
oc__canonical_portfolio_state() {
  case "${1:l}" in
    auto) echo "Auto" ;;
    continue) echo "Continue" ;;
    maintain) echo "Maintain" ;;
    review) echo "Review" ;;
    pause) echo "Pause" ;;
    "archive candidates"|archive) echo "Archive Candidates" ;;
    "missing / thin context"|missing|thin) echo "Missing / Thin Context" ;;
    *) return 1 ;;
  esac
}

oc__canonical_portfolio_intent() {
  case "${1:l}" in
    auto) echo "Auto" ;;
    invest) echo "Invest" ;;
    sustain|"steady state") echo "Sustain" ;;
    explore) echo "Explore" ;;
    hold) echo "Hold" ;;
    sunset) echo "Sunset" ;;
    *) return 1 ;;
  esac
}

oc__portfolio_metadata_value() {
  local metadata_file="$1"
  local key="$2"

  [ -f "$metadata_file" ] || return 0
  sed -n "s/^${key}: *//p" "$metadata_file" | head -n 1
}

oc-portfolio-set() {
  local project_name="$1"
  local requested_state="${2:-auto}"
  local requested_intent="${3:-auto}"

  if [ -z "$project_name" ]; then
    echo 'Usage: oc-portfolio-set <project> <state|auto> <intent|auto>'
    return 1
  fi

  local project_dir="$HOME/Projects/$project_name"
  if [ ! -d "$project_dir" ]; then
    echo "Project directory not found: $project_dir"
    return 1
  fi

  local state intent
  if ! state="$(oc__canonical_portfolio_state "$requested_state")"; then
    echo "Invalid state: $requested_state"
    echo 'Valid states: Continue, Maintain, Review, Pause, Archive Candidates, Missing / Thin Context, Auto'
    return 1
  fi
  if ! intent="$(oc__canonical_portfolio_intent "$requested_intent")"; then
    echo "Invalid intent: $requested_intent"
    echo 'Valid intents: Invest, Sustain, Explore, Hold, Sunset, Auto'
    return 1
  fi

  local metadata_file="$project_dir/.openclaw-portfolio"
  printf 'State: %s\nIntent: %s\n' "$state" "$intent" > "$metadata_file"
  echo "Saved portfolio overrides for $project_name: state=$state, intent=$intent"
}

oc-portfolio() {
  local projects_root="$HOME/Projects"
  local stale_days="${OPENCLAW_PORTFOLIO_STALE_DAYS:-45}"
  local now_epoch
  now_epoch="$(date +%s)"

  if [ ! -d "$projects_root" ]; then
    echo "No project directories found under ~/Projects"
    return 0
  fi

  local report_file
  report_file="$(mktemp)"

  local found=0

  while IFS= read -r project_dir; do
    local project_name=""
    project_name="$(basename "$project_dir")"

    if [[ "$project_name" == .* ]]; then
      continue
    fi

    found=1

    local context_file="$project_dir/context.md"
    local metadata_file="$project_dir/.openclaw-portfolio"
    local override_state="" override_intent=""
    override_state="$(oc__portfolio_metadata_value "$metadata_file" "State")"
    override_intent="$(oc__portfolio_metadata_value "$metadata_file" "Intent")"
    [ "$override_state" = "Auto" ] && override_state=""
    [ "$override_intent" = "Auto" ] && override_intent=""

    if [ ! -f "$context_file" ]; then
      local missing_state="${override_state:-Missing / Thin Context}"
      local missing_intent="${override_intent:-Explore}"
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$missing_state" \
        "$missing_intent" \
        "$project_name" \
        "$([ -n "$override_state" ] && echo 'manual state override; context.md is missing' || echo 'context.md is missing')" \
        "None" >> "$report_file"
      continue
    fi

    local modified_epoch="" days_old=""
    modified_epoch="$(stat -f '%m' "$context_file")"
    days_old=$(( (now_epoch - modified_epoch) / 86400 ))

    awk -v fallback_project="$project_name" -v days_old="$days_old" -v stale_days="$stale_days" \
      -v override_state="$override_state" -v override_intent="$override_intent" '
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

      function clean_bullet(s) {
        s = trim(s)
        sub(/^[[:space:]]*[-*+][[:space:]]+/, "", s)
        return trim(s)
      }

      function append_section(name, line) {
        line = clean_bullet(line)

        if (name == "Project") {
          if (project == "" && line != "") {
            project = line
          }
          return
        }

        if (line == "") {
          return
        }

        if (section_text[name] == "") {
          section_text[name] = line
        } else {
          section_text[name] = section_text[name] " " line
        }

        if (first_line[name] == "") {
          first_line[name] = line
        }
      }

      function has_any(s, pattern) {
        return tolower(s) ~ pattern
      }

      function has_archive_signal(s, normalized) {
        normalized = tolower(s)
        return normalized ~ /(smoke test|test-only|obsolete|abandoned|superseded|no useful project purpose)/ ||
          normalized ~ /(^|[^[:alnum:]_])duplicate([^[:alnum:]_]|$)/
      }

      function looks_operational(s) {
        s = tolower(s)
        return s ~ /(^|[^[:alnum:]_])(working|functional|running|deployed|operational|accessible)([^[:alnum:]_]|$)/ ||
          s ~ /(implemented features|features implemented|in use)/
      }

      function has_concrete_next_step(s) {
        s = trim(s)
        return s != "" &&
          tolower(s) != "none" &&
          tolower(s) !~ /^no explicit next step/ &&
          tolower(s) !~ /^continue work/ &&
          tolower(s) !~ /^improve project/
      }

      BEGIN {
        wanted["Project"] = 1
        wanted["Current State"] = 1
        wanted["In Progress"] = 1
        wanted["Open Issues"] = 1
        wanted["Next Step"] = 1
        wanted["Suggested Resume Prompt"] = 1
      }

      /^# Project Context[[:space:]]*$/ {
        has_context_heading = 1
      }

      {
        line = $0
        sub(/\r$/, "", line)
        header = rtrim(line)

        if (header ~ /^##[[:space:]]+/) {
          current = header
          sub(/^##[[:space:]]+/, "", current)
          current = rtrim(current)
          if (current in wanted) {
            seen[current] = 1
          }
          next
        }

        if (current in wanted) {
          append_section(current, line)
        }
      }

      END {
        project = trim(project)
        if (project == "") {
          project = fallback_project
        }

        current_state = section_text["Current State"]
        in_progress = section_text["In Progress"]
        open_issues = section_text["Open Issues"]
        next_step = first_line["Next Step"]
        all_text = project " " current_state " " in_progress " " open_issues " " next_step
        archive_text = project " " current_state " " next_step

        concrete_next = has_concrete_next_step(next_step)

        if (!has_context_heading || !seen["Current State"] || !seen["Next Step"] || !concrete_next) {
          category = "Missing / Thin Context"
          if (!has_context_heading) {
            reason = "context.md does not contain a valid # Project Context heading"
          } else if (!seen["Current State"] || !seen["Next Step"]) {
            reason = "context.md is missing required sections"
          } else {
            reason = "next step is missing or not actionable"
          }
        } else if (has_archive_signal(archive_text)) {
          category = "Archive Candidates"
          reason = "context indicates a test-only, obsolete, duplicate, or low-purpose project"
        } else if (has_any(open_issues " " in_progress, "(blocked|blocker|stalled|waiting|credential|permission denied|unavailable)")) {
          category = "Pause"
          reason = "context shows a blocking or stalled condition"
        } else if (days_old > stale_days) {
          category = "Review"
          reason = "context is stale (" days_old " days old)"
        } else if (in_progress != "" && tolower(in_progress) !~ /no explicit in-progress work found/) {
          category = "Continue"
          reason = "active in-progress work and concrete next step"
        } else if (looks_operational(current_state)) {
          category = "Maintain"
          reason = "project appears operational, with no explicit active development"
        } else if (has_any(open_issues, "(unclear|weak|missing|risk|limitation|gap|needs validation|not implemented|not yet)")) {
          category = "Review"
          reason = "context has open issues or validation gaps"
        } else {
          category = "Review"
          reason = "concrete next step exists, but active work is unclear"
        }

        automatic_category = category
        if (override_state != "") {
          category = override_state
          reason = "manual state override (automatic: " automatic_category ")"
        }

        if (override_intent != "") {
          intent = override_intent
        } else if (category == "Continue") {
          intent = "Invest"
        } else if (category == "Maintain") {
          intent = "Sustain"
        } else if (category == "Review" || category == "Missing / Thin Context") {
          intent = "Explore"
        } else if (category == "Pause") {
          intent = "Hold"
        } else if (category == "Archive Candidates") {
          intent = "Sunset"
        }

        if (next_step == "") {
          next_step = "None"
        }

        printf "%s\t%s\t%s\t%s\t%s\n", category, intent, fallback_project, reason, next_step
      }
    ' "$context_file" >> "$report_file"
  done < <(find "$projects_root" -mindepth 1 -maxdepth 1 -type d -print | sort)

  if [ "$found" -eq 0 ]; then
    rm -f "$report_file"
    echo "No project directories found under ~/Projects"
    return 0
  fi

  awk -F '\t' '
    function print_section(name) {
      print ""
      print "## " name
      count = 0
      for (i = 1; i <= total; i++) {
        if (category[i] == name) {
          count++
          if (name == "Archive Candidates") {
            printf "- %s - intent: %s; %s\n", project[i], intent[i], reason[i]
          } else {
            printf "- %s - intent: %s; %s; next: %s\n", project[i], intent[i], reason[i], next_step[i]
          }
        }
      }
      if (count == 0) {
        print "- None"
      }
    }

    {
      total++
      category[total] = $1
      intent[total] = $2
      project[total] = $3
      reason[total] = $4
      next_step[total] = $5
    }

    END {
      print "# Project Portfolio"
      print_section("Continue")
      print_section("Maintain")
      print_section("Review")
      print_section("Pause")
      print_section("Archive Candidates")
      print_section("Missing / Thin Context")
    }
  ' "$report_file"

  rm -f "$report_file"
}

# -------- Project Status --------
oc__portfolio_effective_dimensions() {
  local project_name="$1"

  oc-portfolio | awk -v target="$project_name" '
    /^## / {
      state = substr($0, 4)
      next
    }
    {
      prefix = "- " target " - intent: "
      if (index($0, prefix) != 1) {
        next
      }

      remainder = substr($0, length(prefix) + 1)
      separator = index(remainder, ";")
      if (separator > 0) {
        intent = substr(remainder, 1, separator - 1)
        print state "\t" intent
        exit
      }
    }
  '
}

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

  local dimensions portfolio_state strategic_intent
  dimensions="$(oc__portfolio_effective_dimensions "$project_name")"
  portfolio_state="${dimensions%%$'\t'*}"
  strategic_intent="${dimensions#*$'\t'}"

  local metadata_file="$project_dir/.openclaw-portfolio"
  local configured_state configured_intent state_source="automatic" intent_source="automatic"
  configured_state="$(oc__portfolio_metadata_value "$metadata_file" "State")"
  configured_intent="$(oc__portfolio_metadata_value "$metadata_file" "Intent")"
  [ -n "$configured_state" ] && [ "$configured_state" != "Auto" ] && state_source="manual"
  [ -n "$configured_intent" ] && [ "$configured_intent" != "Auto" ] && intent_source="manual"

  awk -v fallback_project="$project_name" -v last_updated="$last_updated" \
    -v portfolio_state="$portfolio_state" -v strategic_intent="$strategic_intent" \
    -v state_source="$state_source" -v intent_source="$intent_source" '
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
      print "Portfolio State: " portfolio_state " (" state_source ")"
      print "Strategic Intent: " strategic_intent " (" intent_source ")"

      for (i = 1; i <= 5; i++) {
        print_section(order[i], section_text[order[i]])
      }
    }
  ' "$context_file"
}

# -------- Source Rescan --------
oc__source_hash() {
  shasum -a 256 "$1" | awk '{ print $1 }'
}

oc__record_capture_source() {
  local project_dir="$1"
  local source_file="$2"
  local metadata_file="$project_dir/.openclaw-source"

  if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
    return 0
  fi

  {
    printf 'Source: %s\n' "$source_file"
    printf 'SHA256: %s\n' "$(oc__source_hash "$source_file")"
  } > "$metadata_file"

  if [ -f "$project_dir/.git/info/exclude" ] && ! grep -Fqx '.openclaw-source' "$project_dir/.git/info/exclude"; then
    printf '%s\n' '.openclaw-source' >> "$project_dir/.git/info/exclude"
  fi
}

oc__project_source() {
  local project_dir="$1"
  local explicit_source="$2"
  local metadata_file="$project_dir/.openclaw-source"
  local history_file="$project_dir/history.log"
  local source_file=""

  if [ -n "$explicit_source" ]; then
    printf '%s\n' "${explicit_source:A}"
    return 0
  fi

  if [ -f "$metadata_file" ]; then
    source_file="$(sed -n 's/^Source: //p' "$metadata_file" | head -n 1)"
    if [ -f "$source_file" ]; then
      printf '%s\n' "$source_file"
      return 0
    fi
  fi

  if [ -f "$history_file" ]; then
    source_file="$(sed -n 's/^Source: file: //p' "$history_file" | tail -n 1)"
    if [ -f "$source_file" ]; then
      printf '%s\n' "$source_file"
      return 0
    fi
  fi

  if [ -f "$project_dir/README.md" ]; then
    printf '%s\n' "$project_dir/README.md"
    return 0
  fi

  return 1
}

oc__rescan_state() {
  local project_dir="$1"
  local source_file="$2"
  local context_file="$project_dir/context.md"
  local metadata_file="$project_dir/.openclaw-source"
  local recorded_source="" recorded_hash="" current_hash=""

  if [ ! -f "$context_file" ]; then
    echo "Needs capture"
    return 0
  fi

  if [ -f "$metadata_file" ]; then
    recorded_source="$(sed -n 's/^Source: //p' "$metadata_file" | head -n 1)"
    recorded_hash="$(sed -n 's/^SHA256: //p' "$metadata_file" | head -n 1)"
  fi

  if [ "$recorded_source" = "$source_file" ] && [ -n "$recorded_hash" ]; then
    current_hash="$(oc__source_hash "$source_file")"
    if [ "$current_hash" != "$recorded_hash" ]; then
      echo "Changed"
    else
      echo "Current"
    fi
  elif [ "$source_file" -nt "$context_file" ]; then
    echo "Changed"
  else
    echo "Current"
  fi
}

oc__rescan_project() {
  local project_name="$1"
  local explicit_source="$2"
  local project_dir="$HOME/Projects/$project_name"
  local source_file="" state=""

  if [ ! -d "$project_dir" ]; then
    echo "Project directory not found: $project_dir"
    return 1
  fi

  source_file="$(oc__project_source "$project_dir" "$explicit_source")" || {
    echo "$project_name: source README not found"
    return 1
  }

  if [ ! -f "$source_file" ]; then
    echo "$project_name: source file not found: $source_file"
    return 1
  fi

  if [ -n "$explicit_source" ]; then
    local recorded_source=""
    if [ -f "$project_dir/.openclaw-source" ]; then
      recorded_source="$(sed -n 's/^Source: //p' "$project_dir/.openclaw-source" | head -n 1)"
    fi
    if [ "$recorded_source" != "$source_file" ]; then
      state="Changed"
    else
      state="$(oc__rescan_state "$project_dir" "$source_file")"
    fi
  else
    state="$(oc__rescan_state "$project_dir" "$source_file")"
  fi
  if [ "$state" = "Current" ]; then
    echo "$project_name: Current — $source_file"
    return 0
  fi

  echo "$project_name: $state — refreshing from $source_file"
  oc-capture "$project_name" "$source_file"
}

oc-rescan() {
  local mode="${1:-check}"
  local projects_root="$HOME/Projects"

  if [ "$mode" != "check" ] && [ "$mode" != "--all" ]; then
    oc__rescan_project "$mode" "$2"
    return $?
  fi

  if [ ! -d "$projects_root" ]; then
    echo "No project directories found under ~/Projects"
    return 0
  fi

  if [ "$mode" = "check" ]; then
    printf '%-28s %-14s %s\n' "Project" "Source Status" "Source"
    printf '%-28s %-14s %s\n' "----------------------------" "--------------" "----------------------------------------"
  fi

  local project_dir="" project_name="" source_file="" state=""
  while IFS= read -r project_dir; do
    project_name="$(basename "$project_dir")"
    source_file="$(oc__project_source "$project_dir" "")" || source_file=""

    if [ -z "$source_file" ]; then
      if [ "$mode" = "check" ]; then
        printf '%-28s %-14s %s\n' "$project_name" "Source missing" "None"
      else
        echo "$project_name: source README not found; skipped"
      fi
      continue
    fi

    state="$(oc__rescan_state "$project_dir" "$source_file")"
    if [ "$mode" = "check" ]; then
      printf '%-28s %-14s %s\n' "$project_name" "$state" "$source_file"
    elif [ "$state" = "Current" ]; then
      echo "$project_name: Current — skipped"
    else
      oc__rescan_project "$project_name" "$source_file" || return $?
    fi
  done < <(find "$projects_root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | sort)
}

# -------- Context Intake Helpers --------
oc__append_history() {
  local history_file="$1"
  local timestamp="$2"
  local input_source="$3"
  local input="$4"

  {
    echo
    echo "[$timestamp]"
    echo "Source: $input_source"
    echo "$input"
  } >> "$history_file"
}

oc__strip_html_file() {
  local input_file="$1"
  local output_file="$2"

  perl -0pe '
    s/<script\b[^>]*>.*?<\/script>/ /gis;
    s/<style\b[^>]*>.*?<\/style>/ /gis;
    s/<nav\b[^>]*>.*?<\/nav>/ /gis;
    s/<footer\b[^>]*>.*?<\/footer>/ /gis;
    s/<header\b[^>]*>.*?<\/header>/ /gis;
    s/<(h[1-6]|p|li|br|div|section|article|tr)\b[^>]*>/\n/gis;
    s/<\/(h[1-6]|p|li|div|section|article|tr)>/\n/gis;
    s/<[^>]+>/ /g;
    s/&nbsp;/ /g;
    s/&amp;/\&/g;
    s/&lt;/</g;
    s/&gt;/>/g;
    s/&quot;/"/g;
    s/&#39;/'"'"'/g;
    s/[ \t]+/ /g;
    s/\n[ \t]+/\n/g;
    s/[ \t]+\n/\n/g;
    s/\n{3,}/\n\n/g;
  ' "$input_file" > "$output_file"
}

oc__prioritize_operational_sections() {
  local input_file="$1"
  local output_file="$2"
  local max_excerpt_chars="${3:-${OPENCLAW_OPERATIONAL_EXCERPT_MAX_CHARS:-40000}}"
  local excerpt_file
  excerpt_file="$(mktemp)"

  if [ "$max_excerpt_chars" -le 0 ]; then
    cp "$input_file" "$output_file"
    rm -f "$excerpt_file"
    return 0
  fi

  awk '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function header_name(line) {
      sub(/^#{1,6}[[:space:]]+/, "", line)
      sub(/[[:space:]]+#+[[:space:]]*$/, "", line)
      return trim(line)
    }

    function is_operational_header(name) {
      name = tolower(name)
      return name ~ /^(next steps?|next action|todo|to do|roadmap|open issues?|known issues?|known limitations?|limitations|in progress|current status|current state|recent work|changelog|backlog|remaining work|future work|planned work|status)$/
    }

    /^#{1,6}[[:space:]]+/ {
      current_header = header_name($0)
      in_operational = is_operational_header(current_header)
      if (in_operational) {
        print ""
        print $0
      }
      next
    }

    in_operational {
      print
    }
  ' "$input_file" | head -c "$max_excerpt_chars" > "$excerpt_file"

  if [ -s "$excerpt_file" ]; then
    {
      echo "OPERATIONAL README SECTION EXCERPTS:"
      cat "$excerpt_file"
      echo
      echo "FULL RAW PROJECT UPDATE:"
      cat "$input_file"
    } > "$output_file"
  else
    cp "$input_file" "$output_file"
  fi

  rm -f "$excerpt_file"
}

oc__clean_agent_output() {
  local raw_output_file="$1"
  local filtered_output_file="$2"

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
}

oc__has_valid_context_output() {
  local context_output_file="$1"

  awk '
    /^# Project Context[[:space:]]*$/ { found_context = 1 }
    /^## Project[[:space:]]*$/ { found_project = 1 }
    /^## Current State[[:space:]]*$/ { found_current = 1 }
    /^## Next Step[[:space:]]*$/ { found_next = 1 }
    END {
      exit !(found_context && found_project && found_current && found_next)
    }
  ' "$context_output_file"
}

oc__save_failed_capture() {
  local raw_output_file="$1"
  local debug_file="$2"

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
  ' "$raw_output_file" > "$debug_file"
}

oc__context_intake_prompt() {
  local project_name="$1"
  local input="$2"

  cat <<EOF
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
- You may make conservative operational inferences from the raw update when they are useful, but label inferred next steps with "Inferred: "
- Do NOT mention OpenClaw unless the raw update is specifically about OpenClaw
- Do NOT invent commands, files, OpenClaw internals, cron jobs, dashboards, automations, issues, features, or project details
- If a field is unknown, write "None"

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
- Use "No explicit next step found in README" only when the raw update provides no useful operational gap, risk, limitation, roadmap item, TODO, unfinished work, or validation target

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
"<one concise prompt the user can paste later>"

PROJECT NAME:
$project_name

RAW PROJECT UPDATE:
$input
EOF
}

oc__context_update_prompt() {
  local project_name="$1"
  local context="$2"
  local input="$3"

  cat <<EOF
You are a Project Context Update Agent.

TASK:
Update the existing project context using the new project update below.

RULES:
- Treat CURRENT CONTEXT and NEW UPDATE as the only sources of truth
- Preserve stable facts from CURRENT CONTEXT unless NEW UPDATE clearly contradicts them
- Do NOT re-synthesize the project from scratch
- Do NOT import prior agent memory, other project contexts, or unrelated details
- Prefer explicit information from NEW UPDATE
- You may make conservative operational inferences from NEW UPDATE when useful, but label inferred next steps with "Inferred: "
- Do NOT invent commands, files, OpenClaw internals, cron jobs, dashboards, automations, issues, features, or project details
- Keep the output compact and deterministic
- Continue requiring one concrete, verb-led Next Step when possible

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
- <3-5 bullets about what is implemented, working, true now, or the current maturity/working state>

## In Progress
- <1-4 bullets about active work or inferred active work>
- If none found, say exactly: No explicit in-progress work found

## Open Issues
- <1-5 bullets about gaps, risks, missing pieces, unclear docs, limitations, or weak operational evidence>
- If none found, say exactly: No explicit open issues found

## Next Step
- <exactly one most actionable, concrete, verb-led next step>
- If inferred, start with: Inferred:
- If no explicit next step exists and no useful conservative inference can be made, say exactly: No explicit next step found

## Suggested Resume Prompt
"<one concise prompt the user can paste later>"

PROJECT NAME:
$project_name

CURRENT CONTEXT:
$context

NEW UPDATE:
$input
EOF
}

oc__run_openai_response() {
  local prompt="$1"
  local output_file="$2"
  local model="${3:-${OPENCLAW_CAPTURE_MODEL:-gpt-5}}"
  local response_file
  response_file="$(mktemp)"

  if [ -z "$OPENAI_API_KEY" ]; then
    echo "OPENAI_API_KEY is not set." > "$output_file"
    rm -f "$response_file"
    return 1
  fi

  if ! jq -n --arg model "$model" --arg input "$prompt" '{model: $model, input: $input}' \
    | curl -sS https://api.openai.com/v1/responses \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d @- > "$response_file"; then
    cp "$response_file" "$output_file"
    rm -f "$response_file"
    return 1
  fi

  if jq -e '.error' "$response_file" >/dev/null 2>&1; then
    jq -r '.error.message // .error // .' "$response_file" > "$output_file"
    rm -f "$response_file"
    return 1
  fi

  jq -r '
    .output_text //
    ([.output[]?.content[]? | select(.type == "output_text") | .text] | join("\n")) //
    empty
  ' "$response_file" > "$output_file"

  rm -f "$response_file"
}

oc__run_openclaw_agent() {
  local session_id="$1"
  local prompt="$2"
  local output_file="$3"

  openclaw agent --agent main --session-id "$session_id" --message "$prompt" > "$output_file"
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
  local processed_input
  local processed_input_file
  local raw_input_file

  if [ -n "$input_file" ]; then
    if [ ! -f "$input_file" ]; then
      echo "Input file not found: $input_file"
      return 1
    fi

    input_file="${input_file:A}"
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

  oc__append_history "$history_file" "$timestamp" "$input_source" "$input"

  raw_input_file="$(mktemp)"
  processed_input_file="$(mktemp)"
  printf '%s\n' "$input" > "$raw_input_file"

  case "$input_file" in
    *.html|*.htm|*.HTML|*.HTM)
      oc__strip_html_file "$raw_input_file" "$processed_input_file"
      input_source="$input_source (HTML preprocessed)"
      ;;
    *)
      cp "$raw_input_file" "$processed_input_file"
      ;;
  esac

  local max_chars="${OPENCLAW_CAPTURE_MAX_CHARS:-120000}"
  local original_processed_chars
  local excerpt_char_budget
  original_processed_chars="$(wc -c < "$processed_input_file" | tr -d ' ')"
  excerpt_char_budget=$(( max_chars - original_processed_chars - 128 ))
  if [ "$excerpt_char_budget" -gt "${OPENCLAW_OPERATIONAL_EXCERPT_MAX_CHARS:-40000}" ]; then
    excerpt_char_budget="${OPENCLAW_OPERATIONAL_EXCERPT_MAX_CHARS:-40000}"
  fi

  local prioritized_input_file
  prioritized_input_file="$(mktemp)"
  oc__prioritize_operational_sections "$processed_input_file" "$prioritized_input_file" "$excerpt_char_budget"
  cp "$prioritized_input_file" "$processed_input_file"
  rm -f "$prioritized_input_file"

  local processed_chars
  processed_chars="$(wc -c < "$processed_input_file" | tr -d ' ')"

  if [ "$processed_chars" -gt "$max_chars" ]; then
    rm -f "$raw_input_file" "$processed_input_file"
    echo "Capture failed; context.md was not overwritten."
    echo "Processed input is too large: $processed_chars chars; limit is $max_chars chars."
    echo "Original raw update was still appended to: $history_file"
    echo "Try a smaller input, a cleaner README body, or raise OPENCLAW_CAPTURE_MAX_CHARS."
    return 1
  fi

  processed_input="$(cat "$processed_input_file")"
  rm -f "$raw_input_file" "$processed_input_file"

  local session_id
  session_id="capture-${project_name}-$(date +%s)"

  local raw_output_file
  raw_output_file="$(mktemp)"

  local filtered_output_file
  filtered_output_file="$(mktemp)"

  local prompt
  prompt="$(oc__context_intake_prompt "$project_name" "$processed_input")"

  local backend="${OPENCLAW_CAPTURE_BACKEND:-openai}"
  local backend_status=0

  case "$backend" in
    openai)
      oc__run_openai_response "$prompt" "$raw_output_file" "${OPENCLAW_CAPTURE_MODEL:-gpt-5}" || backend_status=$?
      ;;
    openclaw|local)
      oc__run_openclaw_agent "$session_id" "$prompt" "$raw_output_file" || backend_status=$?
      ;;
    *)
      printf 'Unknown OPENCLAW_CAPTURE_BACKEND: %s\n' "$backend" > "$raw_output_file"
      backend_status=1
      ;;
  esac

  oc__clean_agent_output "$raw_output_file" "$filtered_output_file"

  local debug_file="$project_dir/capture-failed-$(date +%Y%m%d-%H%M%S).log"

  if [ "$backend_status" -ne 0 ] || ! oc__has_valid_context_output "$filtered_output_file"; then
    oc__save_failed_capture "$raw_output_file" "$debug_file"
    rm -f "$raw_output_file" "$filtered_output_file"
    echo "Capture failed; context.md was not overwritten."
    echo "Debug output saved to: $debug_file"
    echo "Appended raw update to: $history_file"
    return 1
  fi

  cp "$filtered_output_file" "$context_file"
  oc__record_capture_source "$project_dir" "$input_file"
  rm -f "$raw_output_file" "$filtered_output_file"

  echo
  echo "Saved distilled context to: $context_file"
  echo "Appended raw update to: $history_file"
}

oc-update() {
  local project_name="${1:-openclaw-operator}"
  local input_file="$2"
  local project_dir="$HOME/Projects/$project_name"
  local context_file="$project_dir/context.md"
  local history_file="$project_dir/history.log"
  local input_source="interactive"
  local input

  if [ ! -f "$context_file" ]; then
    echo "Context file not found: $context_file"
    echo "Run oc-capture first to create an initial context."
    return 1
  fi

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
    echo "Enter project update for: $project_name"
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
  oc__append_history "$history_file" "$timestamp" "update: $input_source" "$input"

  local max_chars="${OPENCLAW_UPDATE_MAX_CHARS:-60000}"
  local input_chars
  input_chars="$(printf '%s' "$input" | wc -c | tr -d ' ')"

  if [ "$input_chars" -gt "$max_chars" ]; then
    echo "Update failed; context.md was not overwritten."
    echo "Update input is too large: $input_chars chars; limit is $max_chars chars."
    echo "Raw update was still appended to: $history_file"
    echo "Use oc-capture for large first-pass synthesis or provide a shorter update."
    return 1
  fi

  local context
  context="$(cat "$context_file")"

  local session_id
  session_id="update-${project_name}-$(date +%s)"

  local raw_output_file
  raw_output_file="$(mktemp)"

  local filtered_output_file
  filtered_output_file="$(mktemp)"

  local prompt
  prompt="$(oc__context_update_prompt "$project_name" "$context" "$input")"

  local backend="${OPENCLAW_UPDATE_BACKEND:-openclaw}"
  local backend_status=0

  case "$backend" in
    openclaw|local)
      oc__run_openclaw_agent "$session_id" "$prompt" "$raw_output_file" || backend_status=$?
      ;;
    openai)
      oc__run_openai_response "$prompt" "$raw_output_file" "${OPENCLAW_UPDATE_OPENAI_MODEL:-${OPENCLAW_CAPTURE_MODEL:-gpt-5}}" || backend_status=$?
      ;;
    *)
      printf 'Unknown OPENCLAW_UPDATE_BACKEND: %s\n' "$backend" > "$raw_output_file"
      backend_status=1
      ;;
  esac

  oc__clean_agent_output "$raw_output_file" "$filtered_output_file"

  local debug_file="$project_dir/update-failed-$(date +%Y%m%d-%H%M%S).log"

  if [ "$backend_status" -ne 0 ] || ! oc__has_valid_context_output "$filtered_output_file"; then
    oc__save_failed_capture "$raw_output_file" "$debug_file"
    rm -f "$raw_output_file" "$filtered_output_file"
    echo "Update failed; context.md was not overwritten."
    echo "Debug output saved to: $debug_file"
    echo "Appended raw update to: $history_file"
    return 1
  fi

  cp "$filtered_output_file" "$context_file"
  rm -f "$raw_output_file" "$filtered_output_file"

  echo
  echo "Updated distilled context at: $context_file"
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
