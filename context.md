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

## In Progress
- Validate README ingestion across additional real projects
- Audit already captured project contexts for stale sources, vague next steps, and review/maintain grouping quality
- Review projects in the Review bucket for manual state/intent overrides or clearer next-step capture
- Refine deterministic portfolio report after README capture quality is validated

## Open Issues
- README ingestion still needs validation against real READMEs with weak or missing operational sections
- oc-projects does not group projects by status category
- Telegram and email intake not implemented
- Comparison/index mapping bug: cookbook vs family-cookbook conflicting alignment
- Real-project regression fixtures now cover Plex_Catalogue and Simple-Doc-Anonymizer preprocessing; both projects already have captured contexts and current source README baselines
- api-smoke-test still shows Source missing, but it is intentionally skipped because it is already grouped for archival review

## Next Step
- Review oc-portfolio projects in the Review bucket and apply manual state/intent overrides where the automatic grouping is wrong or the project should be maintained, paused, or continued

## Suggested Resume Prompt
"Resume openclaw-operator by reviewing oc-portfolio projects in the Review bucket and applying manual state/intent overrides where the automatic grouping is wrong or the project should be maintained, paused, or continued."
