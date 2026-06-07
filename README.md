# openclaw-operator

A local-first OpenClaw project for capturing project status updates and resuming work later. The MVP focuses on a Project Context Intake & Resume Agent that turns raw status updates into structured context and stores it in markdown.

## Current Objective

Build a small self-documenting repo for the first OpenClaw operator: a CLI-based context intake and resume assistant that keeps each project context compact, isolated, and easy to continue later.

## High-Level Architecture

- Hybrid workflow powered by OpenClaw and the OpenAI API
- Initial synthesis backend: OpenAI API by default, using `OPENCLAW_CAPTURE_MODEL` or `gpt-5`
- Incremental update backend: local OpenClaw/Ollama by default
- Primary local model host: Ollama with `qwen3:8b`
- Shell-based flow with lightweight markdown persistence
- Core agent: Project Context Intake & Resume Agent
- Project source of truth: `~/Projects/<project-name>`
- Each project stores distilled context in `context.md`
- Each project stores raw captured updates in `history.log`

## Current Commands

- `oc-plan` — plan next project steps
- `oc-next` — determine the next action
- `oc-projects` — list local tracked project contexts under `~/Projects`
- `oc-portfolio` — show a heuristic-only portfolio triage report across `~/Projects`
- `oc-status <project-name>` — show deterministic project details from `~/Projects/<project-name>/context.md` without calling OpenClaw or an LLM
- `oc-capture <project-name> [input-file]` — create the initial project context from raw project state
- `oc-update <project-name> [input-file]` — apply a short update to an existing `~/Projects/<project-name>/context.md`
- `oc-continue <project-name>` — generate a concise operational resume summary from `~/Projects/<project-name>/context.md`

These shell helpers are tracked in `scripts/openclaw-shell-functions.zsh` and loaded from `~/.zshrc`:

```zsh
source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"
```

The shell helpers load local API/backend settings from `.env` by default. Copy `.env.example` to `.env`, add `OPENAI_API_KEY`, and keep `.env` uncommitted. Existing exported shell variables take precedence over `.env` values, and blank `.env` values are ignored.

## Capture / Continue Workflow

- Run `oc-projects` to see available tracked projects with `context.md` files.
- Run `oc-portfolio` to group projects into Continue, Review, Pause, Archive Candidates, and Missing / Thin Context using deterministic heuristics only.
- Run `oc-status <project-name>` to inspect the saved context for one project without invoking OpenClaw.
- Run `oc-continue <project-name>` to resume from the saved context for that project when you need a short, practical handoff back into real work.
- Run `oc-capture <project-name>` for first-pass synthesis from a README, HTML README, docs export, transcript, or other broad project source.
- Run `oc-update <project-name>` for short follow-up notes after `context.md` already exists.
- Enter a raw status update interactively, pass an input file, or pipe stdin.
- The raw update is appended to `~/Projects/<project-name>/history.log`.
- `history.log` records whether the source was interactive input, a file, or stdin.
- `oc-capture` preprocesses `.html` and `.htm` inputs by stripping scripts, styles, page chrome, tags, and repeated whitespace.
- `oc-capture` refuses to send processed inputs larger than `OPENCLAW_CAPTURE_MAX_CHARS` (`120000` by default).
- `oc-capture` uses the OpenAI API by default. Set `OPENCLAW_CAPTURE_BACKEND=openclaw` to force the local OpenClaw backend.
- `oc-update` uses the local OpenClaw backend by default. Set `OPENCLAW_UPDATE_BACKEND=openai` to use the OpenAI API for updates.
- `oc-update` refuses update inputs larger than `OPENCLAW_UPDATE_MAX_CHARS` (`60000` by default).
- The model output must contain a valid `# Project Context` structure before `context.md` is overwritten.
- Failed capture or update output is saved to `capture-failed-*.log` or `update-failed-*.log` under the project directory.
- If capture or update fails, `context.md` is not overwritten.
- `oc-status` reads only `context.md` and returns the saved `Current State`, `In Progress`, `Open Issues`, `Next Step`, and `Suggested Resume Prompt` sections.
- `oc-portfolio` reads only local project directories and `context.md` files; it does not call OpenAI, OpenClaw, Ollama, or any other LLM.
- `oc-continue` reads only `context.md` and returns these LLM-generated sections: `Project Status`, `Active Work`, `Blockers / Risks`, `Recommended Next Action`, `First Step`, and `Resume Prompt`.
- `oc-projects` is the compact portfolio list, `oc-portfolio` is deterministic portfolio triage, `oc-status <project-name>` is deterministic project detail, and `oc-continue <project-name>` is LLM-assisted resume guidance.
- `oc-continue` is intended for restarting work after an interruption without rereading the full project context.
- `oc-capture` and `oc-update` start saved context at the first exact `# Project Context` heading and strip OpenClaw terminal decorations before validation.

Example:

```zsh
oc-projects
oc-portfolio
oc-status openclaw-operator
oc-capture openclaw-operator
oc-capture openclaw-operator README.md
oc-capture repo-process-baseline readme.html
oc-update openclaw-operator update-notes.md
cat README.md | oc-capture family-cookbook
oc-continue openclaw-operator
```

## Current Status

- Ollama installed and working
- `qwen3:8b` available locally
- `oc-capture` now uses OpenAI API first-pass synthesis by default
- `oc-update` now uses local OpenClaw/Ollama incremental updates by default
- `oc-plan` and `oc-next` are working concepts in the MVP
- `oc-capture` and `oc-continue` MVP flow implemented
- `oc-update` incremental context update flow implemented
- `oc-projects` lists tracked local project contexts without calling OpenClaw
- `oc-portfolio` groups local projects with heuristic-only continue/review/pause/archive triage
- `oc-status` shows deterministic project details without calling OpenClaw
- `oc-capture` uses isolated capture session IDs
- `oc-capture` now preprocesses HTML inputs and refuses oversized processed input
- `oc-capture` and `oc-update` do not overwrite `context.md` unless valid `# Project Context` output is produced
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
- `qwen3:8b` primary local update model with OpenAI first-pass capture support.
- Git-backed project contexts under `~/Projects/<project-name>`.
- Each tracked project uses `context.md` and `history.log`.
- Repo-tracked shell functions in `scripts/openclaw-shell-functions.zsh`.
- `.zshrc` sources the repo-tracked shell script.
- `oc-plan` and `oc-next` for planning and next-action support.
- `oc-capture <project>` with interactive, file, and piped input.
- `oc-update <project>` with interactive, file, and piped input for short incremental updates.
- Clean `context.md` generation with OpenClaw banner cleanup.
- `oc-continue <project>` for LLM-assisted resume summaries.
- `oc-projects` for portfolio/project listing.
- `oc-portfolio` for deterministic portfolio triage.
- `oc-status <project>` for deterministic project detail views.
- Project isolation validated with at least `openclaw-operator` and `family-cookbook`.
- Multi-project validation across `family-cookbook`, `Knowledge-Base`, `Plex-Catalogue`, `Simple-Doc-Anonymizer`, and `openclaw-operator`.
- `oc-projects` confirmed to extract `Next Step` values when present.

Project validation showed the framework is functioning correctly; current effort is moving from single-project continuity toward portfolio-level project triage.

## Current Focus

- Use OpenAI-backed `oc-capture` for initial project synthesis.
- Use local `oc-update` for short incremental project updates.
- Keep project contexts compact, valid, and non-destructively updated.
- Refine the deterministic portfolio report for deciding which projects to continue, review, pause, or archive.

## Near-Term Roadmap

- Add optional project metadata files later, such as `~/Projects/<project>/project.json`, if deterministic context parsing is not enough.
- Add richer `oc-projects --detail` output if it remains distinct from `oc-portfolio`.
- Add regression coverage using real README fixtures that exposed weak or missing next steps, including `Plex_Catalogue` and `Simple-Doc-Anonymizer`.
- Fix the comparison/index mapping issue where `cookbook` and `family-cookbook` can report conflicting OpenClaw alignment.
- Consider commit-summary or changelog ingestion.
- Improve project metadata/status tracking.
- Add guidance for when to use `oc-status`, `oc-continue`, `oc-capture`, `oc-update`, `oc-projects`, and `oc-portfolio`.

## Later Roadmap

- Add optional LLM-assisted portfolio recommendations only after the heuristic `oc-portfolio` report is useful and inspectable.
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
