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
- Prompt rules reduce drift into speculative OpenClaw internals

## Known Limitations

- Multi-project behavior needs validation across real project directories.
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

- Local OpenClaw setup on the Mac Mini.
- Ollama configured as the primary local model host.
- `qwen3:8b` integrated for local project context workflows.
- OpenAI fallback available when local inference is not enough.
- Git-backed project contexts under `~/Projects/<project-name>`.
- Project-isolated `context.md` files for session continuity.
- `history.log` for raw captured updates.
- Clean capture pipeline that writes structured `# Project Context` markdown.
- OpenClaw banner and terminal decoration cleanup for captured context.
- Repo-tracked shell functions loaded from `~/.zshrc`.
- `oc-plan` and `oc-next` for planning and next-action support.
- `oc-capture` for updating project context.
- `oc-continue` for resuming from saved project context.
- `oc-projects` for listing tracked local project contexts.
- `oc-status` for deterministic project detail views.
- Multi-input capture support for interactive paste, file input, and piped stdin.
- Improved `oc-continue` operational summaries.

## Current Focus

- Improve `oc-projects --detail`.
- Validate README ingestion across more real projects.
- Prepare for Telegram intake later.

## Near-Term Improvements

- Improve `oc-projects --detail` for richer multi-project listing.
- Validate README ingestion across more real projects.
- Prepare for Telegram intake after local project workflows stay stable.

## Longer-Term Vision

- Telegram intake after the local project workflow is stable.
- Dedicated operator email intake.
- Voice-note transcription intake.
- Lightweight local dashboard for project review.
- Richer memory and history summarization.
- Optional semantic search across project contexts.
- Project relationship awareness for related workstreams.

## Repo Structure

- `README.md` — project overview
- `context.md` — current project context and next step
- `history.log` — saved timeline of key milestones
- `notes/` — session notes and idea backlog
- `agents/` — agent definitions and design docs
- `scripts/openclaw-shell-functions.zsh` — tracked shell helpers loaded by `~/.zshrc`
