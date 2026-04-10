# Project Context

## Project
OpenClaw-based local-first Personal AI Operator for project context intake and resume support.

## Current State
- Ollama installed and working
- `qwen3:8b` installed
- OpenClaw configured with Ollama as primary and OpenAI as fallback
- `oc-plan` and `oc-next` operational
- `oc-capture` and `oc-continue` MVP implemented
- Model still drifts into speculative OpenClaw internals occasionally

## In Progress
- Tightening `oc-capture` output format
- Preparing support for multi-project usage

## Open Issues
- inconsistent capture format from the model
- occasional speculative references to non-existent OpenClaw internals
- no multi-project metadata or project selectors yet

## Next Step
Refine the `oc-capture` output schema so distilled context is reliable, then extend the intake agent to handle multiple projects cleanly.

## Suggested Resume Prompt
> "Review the current project context in `context.md` and `history.log`, then suggest the next project action and any missing details required to resume work."
