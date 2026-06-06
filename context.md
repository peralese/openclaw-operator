# Project Context

## Project
openclaw-operator

## Current State
- MVP CLI workflow implemented: oc-capture (OpenAI default), oc-update (local OpenClaw/Ollama default), oc-continue, oc-status, oc-projects; oc-plan and oc-next exist as MVP concepts
- Local model setup working: Ollama installed with qwen3:8b; OpenAI used for first-pass capture
- Context storage and safety: context.md and history.log per project; HTML preprocessing; size limits; overwrite only on valid “# Project Context” output; failed outputs logged
- Deterministic vs LLM paths: oc-status reads saved context only; oc-continue returns fixed-section LLM resume summaries; oc-capture uses isolated session IDs
- Multi-project validation completed; prompt rules reduce drift and preserve project isolation

## In Progress
- Improve README ingestion quality with stronger prioritization of operational sections
- Enhance extraction of Next Step, TODO, Roadmap, Open Issues, and In Progress; require one concrete, verb-led Next Step or infer conservatively
- Validate README ingestion across additional real projects
- Add README section prioritization and fallback logic for sparse operational content

## Open Issues
- README ingestion can over-weight setup/architecture when operational sections are sparse
- oc-projects does not group projects by status category
- Telegram and email intake not implemented
- Comparison/index mapping bug: cookbook vs family-cookbook conflicting alignment
- No consistent fallback when README lacks actionable next steps

## Next Step
- Implement README section prioritization rules in oc-capture to favor operational sections (Next Step, TODO, Roadmap, Open Issues, In Progress) over setup/architecture

## Suggested Resume Prompt
"Resume openclaw-operator by implementing README section prioritization in oc-capture to prefer operational sections; update the capture prompt and test on family-cookbook, knowledge_base, Plex_Catalogue, and Simple-Doc-Anonymizer to verify one concrete Next Step is produced."
