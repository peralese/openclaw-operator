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
- `oc-capture <project-name>` — capture current project state into `~/Projects/<project-name>/context.md`
- `oc-continue <project-name>` — resume work from `~/Projects/<project-name>/context.md`

These shell helpers are tracked in `scripts/openclaw-shell-functions.zsh` and loaded from `~/.zshrc`:

```zsh
source "$HOME/Projects/openclaw-operator/scripts/openclaw-shell-functions.zsh"
```

## Capture / Continue Workflow

- Run `oc-capture <project-name>` when parking project state.
- Enter a raw status update, then press Ctrl-D.
- The raw update is appended to `~/Projects/<project-name>/history.log`.
- OpenClaw distills the update into the required `# Project Context` markdown structure.
- The distilled context is written to `~/Projects/<project-name>/context.md`.
- `oc-capture` strips OpenClaw CLI decorations before saving context:
  - lines beginning with `🦞 OpenClaw`
  - lines containing only `│`
  - lines containing only `◇`
  - leading blank lines before real content
- If filtering produces empty output, `oc-capture` saves the raw OpenClaw output for inspection and prints a warning.
- Run `oc-continue <project-name>` to resume from the saved context for that project.

## Current Status

- Ollama installed and working
- `qwen3:8b` available locally
- OpenClaw configured to use Ollama first and OpenAI as fallback
- `oc-plan` and `oc-next` are working concepts in the MVP
- `oc-capture` and `oc-continue` MVP flow implemented
- `oc-capture` uses isolated capture session IDs
- `oc-capture` now saves cleaned markdown without OpenClaw terminal decorations
- Prompt rules reduce drift into speculative OpenClaw internals

## Known Limitations

- Multi-project behavior needs validation across real project directories.
- `oc-continue` formatting is still basic.
- There is no project list or status command yet.
- Telegram and email intake are not implemented yet.

## Roadmap

### Immediate Next Steps

- Validate `oc-capture` output across two projects
- Confirm `context.md` contains clean project-specific context
- Confirm `oc-continue` stays project-specific
- Commit cleaned project state

### Near-Term Roadmap

- Add multi-project usage examples
- Improve `oc-continue` formatting
- Add optional project list/status command

### Later Roadmap

- Telegram-based context intake
- Dedicated email intake only after Telegram pattern works
- Richer project memory/history summaries
- Possible lightweight project dashboard

## Repo Structure

- `README.md` — project overview
- `context.md` — current project context and next step
- `history.log` — saved timeline of key milestones
- `notes/` — session notes and idea backlog
- `agents/` — agent definitions and design docs
- `scripts/openclaw-shell-functions.zsh` — tracked shell helpers loaded by `~/.zshrc`
