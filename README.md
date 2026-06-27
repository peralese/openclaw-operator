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
- `oc-help` — show a man-style reference for available OpenClaw helper commands
- `oc-list` — list tracked project names only, with no timestamps or next-step details
- `oc-projects` — list local tracked project contexts under `~/Projects`
- `oc-projects --grouped [state]` — list projects by Continue, Maintain, Review, Pause, Archive Candidates, and Missing / Thin Context using the same deterministic heuristics as `oc-portfolio`
- `oc-portfolio` — group projects into Continue, Maintain, Review, Pause, Archive Candidates, and Missing / Thin Context
- `oc-portfolio --review` — show Review-bucket projects with reason, next step, and a deterministic suggested action
- `oc-portfolio-set <project> <state|auto> <intent|auto>` — override a project's computed state and strategic intent
- `oc-rescan` — report whether each project's captured source README has changed
- `oc-rescan <project> [input-file]` — refresh one project's context only when its source has changed
- `oc-rescan --all` — refresh every changed project with a discoverable source README
- `oc-status <project-name>` — show deterministic project details, effective portfolio state, and strategic intent without calling OpenClaw or an LLM
- `oc-capture <project-name> [input-file]` — create the initial project context from raw project state
- `oc-update <project-name> [input-file]` — apply a short update to an existing `~/Projects/<project-name>/context.md`
- `oc-continue <project-name>` — generate a concise operational resume summary from `~/Projects/<project-name>/context.md`

These shell helpers are tracked in `scripts/openclaw-shell-functions.zsh` and loaded from `~/.zshrc`:

```zsh
source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"
```

The shell helpers load local API/backend settings from `.env` by default. Copy `.env.example` to `.env`, add `OPENAI_API_KEY`, and keep `.env` uncommitted. Existing exported shell variables take precedence over `.env` values, and blank `.env` values are ignored.

## Capture / Continue Workflow

- Run `oc-help` to see a man-style command reference in the terminal.
- Run `oc-list` when you only need project names with no extra columns.
- Run `oc-projects` to see available tracked projects with `context.md` files.
- Run `oc-projects --grouped` for a compact daily view grouped by portfolio state without reasons or intent labels, or pass a state such as `Continue`, `Review`, `Pause`, `archive`, or `missing` to show one group.
- Run `oc-portfolio` to group projects into Continue, Maintain, Review, Pause, Archive Candidates, and Missing / Thin Context using deterministic heuristics only.
- Run `oc-portfolio --review` for a focused Review queue with why each project needs attention and the likely next decision.
- Portfolio entries also show strategic intent: Invest, Sustain, Explore, Hold, or Sunset. By default, intent is derived from state; `oc-portfolio-set` can override either dimension while `auto` restores automatic behavior.
- Run `oc-rescan` to check source README hashes and timestamps without making an LLM call.
- Run `oc-rescan <project>` to re-run capture for one changed source, or `oc-rescan --all` to refresh all changed sources. The bulk form can make multiple capture/backend calls.
- Run `oc-status <project-name>` to inspect the saved context for one project without invoking OpenClaw.
- Run `oc-continue <project-name>` to resume from the saved context for that project when you need a short, practical handoff back into real work.
- Run `oc-capture <project-name>` for first-pass synthesis from a README, HTML README, docs export, transcript, or other broad project source.
- Run `oc-update <project-name>` for short follow-up notes after `context.md` already exists.
- Enter a raw status update interactively, pass an input file, or pipe stdin.
- The raw update is appended to `~/Projects/<project-name>/history.log`.
- `history.log` records whether the source was interactive input, a file, or stdin.
- `oc-capture` preprocesses `.html` and `.htm` inputs by stripping scripts, styles, page chrome, tags, and repeated whitespace.
- `oc-capture` front-loads operational README sections such as Next Steps, TODO, Roadmap, Open Issues, Known Limitations, In Progress, Current Status, Recent Work, and Changelog before sending the full source to the capture backend.
- `oc-capture` refuses to send processed inputs larger than `OPENCLAW_CAPTURE_MAX_CHARS` (`120000` by default).
- `oc-capture` uses the OpenAI API by default. Set `OPENCLAW_CAPTURE_BACKEND=openclaw` to force the local OpenClaw backend.
- `oc-update` uses the local OpenClaw backend by default. Set `OPENCLAW_UPDATE_BACKEND=openai` to use the OpenAI API for updates.
- `oc-update` refuses update inputs larger than `OPENCLAW_UPDATE_MAX_CHARS` (`60000` by default).
- The model output must contain a valid `# Project Context` structure before `context.md` is overwritten.
- Failed capture or update output is saved to `capture-failed-*.log` or `update-failed-*.log` under the project directory.
- If capture or update fails, `context.md` is not overwritten.
- `oc-status` reads only `context.md` and returns the saved `Current State`, `In Progress`, `Open Issues`, `Next Step`, and `Suggested Resume Prompt` sections.
- `oc-portfolio` reads only local project directories and `context.md` files; it does not call OpenAI, OpenClaw, Ollama, or any other LLM.
- `oc-rescan` without arguments is read-only. Successful file-based captures record the source path and SHA-256 in the locally ignored `.openclaw-source`; older captures fall back to the most recent file source in `history.log`, then the project's own `README.md`, and use modification times until a hash baseline exists.
- `oc-rescan --all` skips unchanged sources and projects whose source README cannot be found.
- `oc-continue` reads only `context.md` and returns these LLM-generated sections: `Project Status`, `Active Work`, `Blockers / Risks`, `Recommended Next Action`, `First Step`, and `Resume Prompt`.
- `oc-projects` is the compact portfolio list, `oc-portfolio` is deterministic portfolio triage, `oc-status <project-name>` is deterministic project detail, and `oc-continue <project-name>` is LLM-assisted resume guidance.
- `oc-continue` is intended for restarting work after an interruption without rereading the full project context.
- `oc-capture` and `oc-update` start saved context at the first exact `# Project Context` heading and strip OpenClaw terminal decorations before validation.

Example:

```zsh
oc-projects
oc-list
oc-help
oc-projects --grouped
oc-projects --grouped Continue
oc-projects --grouped archive
oc-portfolio
oc-portfolio --review
oc-portfolio-set openclaw-operator Continue Invest
oc-portfolio-set openclaw-operator auto auto
oc-rescan
oc-status openclaw-operator
oc-capture openclaw-operator
oc-capture openclaw-operator README.md
oc-capture repo-process-baseline readme.html
oc-update openclaw-operator update-notes.md
oc-rescan meal-planner ~/Downloads/Readme/meal-planner.md
oc-rescan --all
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
- `oc-help` shows a man-style terminal reference for available helper commands
- `oc-list` shows project names only for compact scripting and selection
- `oc-projects` lists tracked local project contexts without calling OpenClaw
- `oc-projects --grouped [state]` lists projects by portfolio state using deterministic `oc-portfolio` heuristics
- `oc-portfolio` groups local projects with heuristic-only continue/review/pause/archive triage
- `oc-portfolio --review` shows a deterministic Review-bucket decision queue
- `oc-status` shows deterministic project details without calling OpenClaw
- `oc-capture` uses isolated capture session IDs
- `oc-capture` now preprocesses HTML inputs and refuses oversized processed input
- `oc-capture` prioritizes operational README sections before broad setup, architecture, or feature documentation
- `oc-capture` and `oc-update` do not overwrite `context.md` unless valid `# Project Context` output is produced
- `oc-continue` returns concise operational resume summaries with fixed sections
- Project validation showed framework behavior and project isolation are working correctly
- Prompt rules reduce drift into speculative OpenClaw internals
- Local regression tests cover operational README section prioritization and plain input pass-through

## Known Limitations

- README ingestion still needs validation against more real project READMEs with weak or missing next-step sections.
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
- `oc-help` for command reference.
- `oc-list` for project-name-only listing.
- `oc-projects` for portfolio/project listing.
- `oc-projects --grouped` for compact portfolio-state project listing.
- `oc-portfolio` for deterministic portfolio triage.
- `oc-portfolio --review` for focused Review-bucket decisions.
- `oc-status <project>` for deterministic project detail views.
- Project isolation validated with at least `openclaw-operator` and `family-cookbook`.
- Multi-project validation across `family-cookbook`, `Knowledge-Base`, `Plex-Catalogue`, `Simple-Doc-Anonymizer`, and `openclaw-operator`.
- `oc-projects` confirmed to extract `Next Step` values when present.
- README section prioritization for `oc-capture`, with regression coverage for operational section front-loading.
- Real README regression fixtures added for `Plex_Catalogue` and `Simple-Doc-Anonymizer`.
- Source baselines refreshed across the active project portfolio, with archive candidates intentionally skipped where appropriate.
- Manual portfolio overrides validated for maintain, pause, and archive/sunset decisions.

Project validation showed the framework is functioning correctly; current effort is moving from single-project continuity toward portfolio-level project triage.

## Current Focus

- Use OpenAI-backed `oc-capture` for initial project synthesis.
- Use local `oc-update` for short incremental project updates.
- Keep project contexts compact, valid, and non-destructively updated.
- Make daily portfolio review faster and more useful after the initial capture/rescan foundation.
- Refine deterministic portfolio views for deciding which projects to continue, maintain, review, pause, or archive.
- Keep manual state/intent overrides inspectable while avoiding accidental archive or duplicate-project classifications.

The project is currently in a CLI portfolio maturity phase: capture works well enough to manage many projects, and the next value is making review, grouping, and next-action selection easier.

## Near-Term Roadmap

- Add richer override inspection, such as a compact report of manual state/intent overrides and their automatic fallback values.
- Keep regression coverage for project identity alignment where `cookbook` and `family-cookbook` both exist.
- Keep adding regression fixtures only when real captures produce weak, vague, or misleading output.
- Add guidance for when to use `oc-status`, `oc-continue`, `oc-capture`, `oc-update`, `oc-projects`, and `oc-portfolio`.

## Mid-Term Roadmap

- Introduce an intake abstraction so file, stdin, email body, email attachment, Telegram message, and voice transcript sources can share the same capture/update safety rules.
- Consider commit-summary or changelog ingestion as another structured intake source.
- Add optional project metadata files later, such as `~/Projects/<project>/project.json`, if deterministic context parsing and `.openclaw-portfolio` are not enough.
- Add optional LLM-assisted portfolio recommendations only after the heuristic `oc-portfolio` report is useful and inspectable.

## Later Roadmap

- Email-based project context intake: send or forward a README/update, ingest the body or attachment, refresh project context, and optionally reply with status and next step.
- Telegram-based project context intake for quick status updates.
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
- `tests/run-tests.zsh` — local regression checks for shell helper behavior
