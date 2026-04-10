# openclaw-operator

A local-first OpenClaw project for capturing project status updates and resuming work later. The MVP focuses on a Project Context Intake & Resume Agent that turns raw status updates into structured context and stores it in markdown.

## Current Objective

Build a small self-documenting repo for the first OpenClaw operator: a CLI-based context intake and resume assistant.

## High-Level Architecture

- Local-first workflow powered by OpenClaw
- Primary model host: Ollama with `qwen3:8b`
- Fallback support for OpenAI when needed
- Shell-based flow with lightweight markdown persistence
- Core agent: Project Context Intake & Resume Agent

## Current Commands

- `oc-plan` — plan next project steps
- `oc-next` — determine the next action
- `oc-capture` — capture current project state
- `oc-continue` — resume work from saved context

## Current Status

- Ollama installed and working
- `qwen3:8b` available locally
- OpenClaw configured to use Ollama first and OpenAI as fallback
- `oc-plan` and `oc-next` are working concepts in the MVP
- `oc-capture` and `oc-continue` MVP flow implemented
- The model still occasionally drifts into speculative OpenClaw internals

## Next Steps

- Tighten `oc-capture` output format for consistent structured context
- Add support for multi-project usage
- Reduce hallucination by grounding responses in local markdown and git state

## Repo Structure

- `README.md` — project overview
- `context.md` — current project context and next step
- `history.log` — saved timeline of key milestones
- `notes/` — session notes and idea backlog
- `agents/` — agent definitions and design docs
- `scripts/` — placeholder documentation for shell helpers
