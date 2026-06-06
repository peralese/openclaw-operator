# openclaw-operator

A local-first OpenClaw project for capturing project status updates and resuming work later. The MVP focuses on a Project Context Intake & Resume Agent that turns raw status updates into structured context and stores it in markdown.

## Current Objective

Build a small self-documenting repo for the first OpenClaw operator: a CLI-based context intake and resume assistant that keeps each project context compact, isolated, and easy to continue later.

## High-Level Architecture

- Local-first workflow powered by OpenClaw
- Primary model host: Ollama with `qwen3:8b`
- Fallback support for OpenAI when needed
- Shell-based flow with lightweight markdown persistence
- Core agent: Project Context Intake & Resume Agent
- Project source of truth: `~/Projects/<project-name>`
- Each project stores distilled context in `context.md`
- Each project stores raw captured updates in `history.log`

## Current Commands

- `oc-plan` — plan next project steps
- `oc-next` — determine the next action
- `oc-projects` — list local tracked project contexts under `~/Projects`
- `oc-status <project-name>` — show deterministic project details from `~/Projects/<project-name>/context.md` without calling OpenClaw or an LLM
- `oc-capture <project-name> [input-file]` — capture current project state into `~/Projects/<project-name>/context.md`
- `oc-continue <project-name>` — generate a concise operational resume summary from `~/Projects/<project-name>/context.md`

These shell helpers are tracked in `scripts/openclaw-shell-functions.zsh` and loaded from `~/.zshrc`:

```zsh
source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"
```

## Capture / Continue Workflow

- Run `oc-projects` to see available tracked projects with `context.md` files.
- Run `oc-status <project-name>` to inspect the saved context for one project without invoking OpenClaw.
- Run `oc-continue <project-name>` to resume from the saved context for that project when you need a short, practical handoff back into real work.
- Run `oc-capture <project-name>` when parking project state.
- Enter a raw status update interactively, pass an input file, or pipe stdin.
- The raw update is appended to `~/Projects/<project-name>/history.log`.
- `history.log` records whether the source was interactive input, a file, or stdin.
- OpenClaw distills the update into the required `# Project Context` markdown structure.
- The distilled context is written to `~/Projects/<project-name>/context.md`.
- `oc-status` reads only `context.md` and returns the saved `Current State`, `In Progress`, `Open Issues`, `Next Step`, and `Suggested Resume Prompt` sections.
- `oc-continue` reads only `context.md` and returns these LLM-generated sections: `Project Status`, `Active Work`, `Blockers / Risks`, `Recommended Next Action`, `First Step`, and `Resume Prompt`.
- `oc-projects` is the portfolio list, `oc-status <project-name>` is deterministic project detail, and `oc-continue <project-name>` is LLM-assisted resume guidance.
- `oc-continue` is intended for restarting work after an interruption without rereading the full project context.
- `oc-capture` starts saved context at the first exact `# Project Context` heading when present.
- If that heading is missing, `oc-capture` falls back to stripping OpenClaw CLI decorations:
  - lines beginning with `🦞 OpenClaw`
  - lines containing only `│`
  - lines containing only `◇`
  - leading blank lines before real content
- If filtering still produces empty output, `oc-capture` saves raw output or a diagnostic message for inspection and prints a warning.

Example:

```zsh
oc-projects
oc-status openclaw-operator
oc-capture openclaw-operator
oc-capture openclaw-operator README.md
cat README.md | oc-capture family-cookbook
oc-continue openclaw-operator
```

## Current Status

- Ollama installed and working
- `qwen3:8b` available locally
- OpenClaw configured to use Ollama first and OpenAI as fallback
- `oc-plan` and `oc-next` are working concepts in the MVP
- `oc-capture` and `oc-continue` MVP flow implemented
- `oc-projects` lists tracked local project contexts without calling OpenClaw
- `oc-status` shows deterministic project details without calling OpenClaw
- `oc-capture` uses isolated capture session IDs
- `oc-capture` now saves cleaned markdown without OpenClaw terminal decorations
- `oc-continue` returns concise operational resume summaries with fixed sections
- Project validation showed framework behavior and project isolation are working correctly
- Prompt rules reduce drift into speculative OpenClaw internals

## Known Limitations

- README ingestion can over-weight setup, architecture, or feature documentation when operational sections are sparse.
- `oc-projects` does not yet group projects by status category.
- Telegram and email intake are not implemented yet.

# Roadmap

## Philosophy

- Capture lightweight human updates without forcing a heavyweight process.
- Normalize raw notes into structured operational context.
- Resume work quickly after interruption.
- Stay local-first by default, with cloud fallback only when useful.
- Prefer operator tooling over chatbot behavior.
- Keep the system practical, inspectable, and easy to run every day.

## Completed Foundations

- Local OpenClaw + Ollama setup on the Mac Mini.
- `qwen3:8b` primary model with OpenAI fallback.
- Git-backed project contexts under `~/Projects/<project-name>`.
- Each tracked project uses `context.md` and `history.log`.
- Repo-tracked shell functions in `scripts/openclaw-shell-functions.zsh`.
- `.zshrc` sources the repo-tracked shell script.
- `oc-plan` and `oc-next` for planning and next-action support.
- `oc-capture <project>` with interactive, file, and piped input.
- Clean `context.md` generation with OpenClaw banner cleanup.
- `oc-continue <project>` for LLM-assisted resume summaries.
- `oc-projects` for portfolio/project listing.
- `oc-status <project>` for deterministic project detail views.
- Project isolation validated with at least `openclaw-operator` and `family-cookbook`.
- Multi-project validation across `family-cookbook`, `Knowledge-Base`, `Plex-Catalogue`, `Simple-Doc-Anonymizer`, and `openclaw-operator`.
- `oc-projects` confirmed to extract `Next Step` values when present.

Project validation showed the framework is functioning correctly; current effort is improving the quality of operational context extracted from project documentation.

## Current Focus

- Improve README ingestion quality.
- Prioritize operational content over setup content.
- Improve extraction of:
  - Next Step
  - TODO
  - Roadmap
  - Open Issues
  - In Progress
- Reduce installation/architecture dominance in context generation.
- Validate README ingestion across additional real projects.

## Near-Term Roadmap

- Improve `oc-capture` prompt weighting for README ingestion.
- Add README section prioritization rules.
- Add optional fallback logic when README lacks actionable next steps.
- Make `Next Step` capture consistently actionable by requiring one concrete, verb-led action; when no explicit next step exists, infer one from the most operational roadmap item, gap, risk, or known limitation.
- Add regression coverage using real README fixtures that exposed weak or missing next steps, including `Plex_Catalogue` and `Simple-Doc-Anonymizer`.
- Rerun README-ingestion comparisons for `family-cookbook`, `knowledge_base`, `openclaw-operator`, `Plex_Catalogue`, and `Simple-Doc-Anonymizer` after capture changes.
- Fix the comparison/index mapping issue where `cookbook` and `family-cookbook` can report conflicting OpenClaw alignment.
- Consider commit-summary or changelog ingestion.
- Add `oc-projects --detail` or an equivalent richer project listing.
- Improve project metadata/status tracking.
- Add guidance for when to use `oc-status`, `oc-continue`, `oc-capture`, and `oc-projects`.

## Later Roadmap

- Telegram-based project context intake.
- Dedicated email intake after Telegram pattern is proven.
- Voice-note/transcription-based capture.
- Lightweight local dashboard for project review.
- Semantic search across project contexts/history.
- Relationship awareness between projects.

## Repo Structure

- `README.md` — project overview
- `context.md` — current project context and next step
- `history.log` — saved timeline of key milestones
- `notes/` — session notes and idea backlog
- `agents/` — agent definitions and design docs
- `scripts/openclaw-shell-functions.zsh` — tracked shell helpers loaded by `~/.zshrc`
