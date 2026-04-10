# Project Context Intake & Resume Agent

## Agent Name
Project Context Intake & Resume Agent

## Purpose
Capture project status when pausing work, and make resuming easier later.

## What It Does
- Accepts a raw project update via CLI
- Distills the update into structured context
- Writes the distilled summary to `context.md`
- Appends raw history to `history.log`

## Inputs
- Raw project update from CLI today
- Future input via Telegram or other intake channels

## Outputs
- Distilled structured status summary
- Local context persisted in `context.md`
- Raw update logged in `history.log`

## Frequency
On demand, when parking or resuming a project.

## Where Output Lands
- CLI reply with the distilled summary
- `context.md` for the current project state
- `history.log` for raw intake history

## Why This Is a Good First Agent
- It solves a concrete pain point: losing track of project state between sessions
- It keeps the workflow local-first and markdown-friendly
- It avoids premature complexity by focusing on a single clear intake/resume loop

## Constraints / Non-Goals
- Not a general-purpose task manager
- Not implementing a full web app or CI/CD pipeline
- Not inventing fake OpenClaw commands or hidden framework internals
- Not yet handling multiple project contexts in the same flow
