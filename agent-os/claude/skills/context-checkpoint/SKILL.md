---
name: context-checkpoint
description: Compress current session state into a cumulative handoff checkpoint in .agent-os/context-checkpoints.md; update it at safe boundaries so any later turn or agent can resume safely.
---

The canonical procedure lives in `.agent-os/skills/context-checkpoint/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/context-checkpoint/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. At a safe, stable boundary (not mid-edit, not with failures unrecorded) — after long work, large tool output, a large diff, before switching phases, or before an intentional compact — update `.agent-os/context-checkpoints.md`.
2. Capture latest user instructions/constraints first, then confirmed facts, assumptions/uncertainties, files changed/inspected, commands run with real results, known failures, decisions, remaining work, and the next smallest step — keeping each in its own section.
3. If a checkpoint already exists, merge into one cumulative `# Context Checkpoint` — never append a second block; resolve contradictions in favor of the newest user intent and mark superseded decisions as superseded.
4. Prefer `.agent-os/context-checkpoints.md` over older conversation memory whenever resuming work after a phase switch or any suspected context loss.

## Forbidden

- Recording unverified information as confirmed, or a test as passed when it wasn't run.
- Claiming this skill deletes or shrinks conversation history — it does not.
- Appending a new checkpoint block instead of merging into one.
- Dropping or downgrading the latest user instruction when merging.

## Claude-specific notes

- If this environment exposes a native compact mechanism (e.g. a manual `/compact` command), update the checkpoint first, then use it — do not claim a hook or prompt can auto-execute a slash command, and do not assume it exists in every Claude surface.
- When native compact is unavailable, `.agent-os/context-checkpoints.md` is the fallback: re-read it before continuing after any context loss.
- Writing the checkpoint is a recording action, not something to batch for later — update it as soon as a safe boundary is reached.
