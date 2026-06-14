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

## In Progress
- Validate README ingestion across additional real projects
- Add real README fixtures for projects that previously produced weak or missing next steps
- Refine deterministic portfolio report after README capture quality is validated

## Open Issues
- README ingestion still needs validation against real READMEs with weak or missing operational sections
- oc-projects does not group projects by status category
- Telegram and email intake not implemented
- Comparison/index mapping bug: cookbook vs family-cookbook conflicting alignment
- Real-project regression fixtures are not yet committed

## Next Step
- Add real README regression fixtures for Plex_Catalogue and Simple-Doc-Anonymizer, then verify oc-capture produces one concrete Next Step for each

## Suggested Resume Prompt
"Resume openclaw-operator by adding real README regression fixtures for Plex_Catalogue and Simple-Doc-Anonymizer; verify the operational section prioritization in oc-capture produces one concrete Next Step for each."
