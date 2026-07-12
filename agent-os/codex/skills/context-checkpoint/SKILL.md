---
name: context-checkpoint
description: Compress current session state into a cumulative handoff checkpoint in .agent-os/context-checkpoints.md so work survives Codex's automatic, lossy compaction.
---

Canonical procedure: `.agent-os/skills/context-checkpoint/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/context-checkpoint/SKILL.md`). Read it before running this workflow —
this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. At a safe, stable boundary — after long work, large tool output, a large
   diff, or a multi-file investigation, or before switching task phases —
   update `.agent-os/context-checkpoints.md`. Do not checkpoint mid-edit or
   with failures left unrecorded.
2. Capture the latest user instructions, constraints, and priorities first —
   newer instructions supersede older plans and must never be lost.
3. Keep confirmed facts (verified this session), assumptions/uncertainties,
   and known failures/unresolved issues in separate sections — never blend them.
4. Record files changed, important files inspected, commands actually run
   with their real results, decisions made, remaining work, and the next
   smallest unit of work.
5. If a checkpoint already exists, merge into one cumulative
   `# Context Checkpoint` — never simply append a new block. Resolve
   contradictions in favor of the newest user intent and mark superseded
   decisions as superseded with a one-line reason. At bloat or
   long-session milestones, have the checkpoint audited via the
   `audit-checkpoint` skill.
6. Reference `.agent-os/learned-rules.md` and other adapter files by name
   only — never copy their content into the checkpoint, or checkpoint
   content into rules.

## Codex-specific notes

- Codex environments typically auto-compact by default, and the agent
  cannot control when compaction happens; compaction is lossy, irreversible,
  and session-bound. Do not instruct manual compaction, and do not instruct
  changing or disabling auto-compaction settings.
- Instead, keep `.agent-os/context-checkpoints.md` fresh at every safe
  boundary, so that whenever compaction happens — or a session resumes —
  the checkpoint file is the authoritative reference to re-read first.
- Do not assume compaction features or controls that a given Codex version
  may not have.

## Forbidden

- Claiming this skill deletes or shrinks conversation history — it does not.
- Appending a new checkpoint block instead of merging into one cumulative summary.
- Instructing that compaction settings be changed or manual compaction be triggered.
