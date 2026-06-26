# Project Context

## Project
openclaw-operator

## Current State
- MVP CLI workflow implemented: oc-capture (OpenAI default), oc-update (local OpenClaw/Ollama default), oc-continue, oc-status, oc-projects; oc-plan and oc-next exist as MVP concepts
- Local model setup working: Ollama installed with qwen3:8b; OpenAI used for first-pass capture
- Context storage and safety: context.md and history.log per project; HTML preprocessing; README operational section prioritization; size limits; overwrite only on valid "# Project Context" output; failed outputs logged
- Deterministic vs LLM paths: oc-status reads saved context only; oc-continue returns fixed-section LLM resume summaries; oc-capture uses isolated session IDs
- Multi-project validation completed; prompt rules and preprocessing reduce drift and preserve project isolation
- Local regression tests cover operational README section front-loading and plain input pass-through
- Source baselines have been refreshed for the main captured projects that previously showed Source missing; api-smoke-test remains intentionally unbaselined as an archive candidate
- Portfolio archive-signal heuristic now avoids treating cross-project/archive-category notes as proof the current project should be archived
- repo-proces-baseline has been manually marked Archive Candidates / Sunset because its context and captured source point to repo-context-baseline

## In Progress
- Validate README ingestion across additional real projects
- Audit already captured project contexts for stale sources, vague next steps, and review/maintain grouping quality
- Decide whether to improve oc-projects grouping or continue manual portfolio judgment for remaining Review projects
- Refine deterministic portfolio report after README capture quality is validated

## Open Issues
- README ingestion still needs validation against real READMEs with weak or missing operational sections
- oc-projects does not group projects by status category
- Telegram and email intake not implemented
- Comparison/index mapping bug: cookbook vs family-cookbook conflicting alignment
- Real-project regression fixtures now cover Plex_Catalogue and Simple-Doc-Anonymizer preprocessing; both projects already have captured contexts and current source README baselines
- api-smoke-test still shows Source missing, but it is intentionally skipped because it is already grouped for archival review
- repo-proces-baseline is treated as a duplicate/stale capture of repo-context-baseline rather than a distinct active project

## Next Step
- Choose the next portfolio tooling improvement: either add status grouping to oc-projects or continue reviewing Review-bucket projects for manual state/intent overrides

## Suggested Resume Prompt
"Resume openclaw-operator by choosing the next portfolio tooling improvement: add status grouping to oc-projects, or continue reviewing Review-bucket projects for manual state/intent overrides."
