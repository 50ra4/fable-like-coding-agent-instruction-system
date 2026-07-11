---
name: audit-checkpoint
description: Builder-model audit of .agent-os/context-checkpoints.md — cross-check confirmed facts against git/log evidence, re-compress bloat into one cumulative handoff summary, and detect rule/checkpoint contamination; every correction is proposed as a diff requiring approval.
---

Canonical procedure: `.agent-os/skills/audit-checkpoint/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/audit-checkpoint/SKILL.md`). Read it before running this
workflow — this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Use the `context-checkpoint` protocol's 12 sections and Forbidden list
   as the audit checklist — do not invent a different standard.
2. Evidence cross-check: every "Confirmed facts", "Commands run and
   results", and "Files changed" entry needs corroboration from
   `git diff`/`git log`/`git status`, real output, or the failure log.
   Uncorroborated entries get demoted (proposal only) into "Assumptions
   and uncertainties"; a test marked passed with no run evidence is
   proposed "not verified" under "Known failures / unresolved issues".
   Plausibility is not evidence.
3. Re-compression: if bloated or duplicated, draft one merged,
   deduplicated `# Context Checkpoint`, resolving contradictions toward
   the newest user intent, keeping superseded decisions marked
   superseded with a one-line reason. Nothing may be lost.
4. Contamination check, both directions: no rule text from
   `learned-rules.md`/`.agent-os/rules/`/`GLOBAL_*`/canonical skills
   copied into the checkpoint, and no checkpoint content promoted into
   those files — promotion only goes through `learn-from-feedback`.
5. Present every correction as a before/after diff with a one-line
   reason; apply only after approval.
6. Builder-model (Fable-class) task: the auditor must be stronger than
   the checkpoint's author — a same-session self-audit is only a
   self-check, not independent. Not for writing checkpoints, and not a
   repo-wide layer audit — only checkpoint-to-rules/Global contamination
   is in scope here.

## Codex-specific notes

- Codex auto-compacts lossily and uncontrollably, so the checkpoint file
  is the authoritative post-compaction reference — auditing it protects
  exactly the artifact Codex relies on.
- Do not instruct manual compaction, and do not instruct changing or
  disabling auto-compaction settings.

## Forbidden

- Rewriting the checkpoint without presenting the diff and approval.
- Treating plausibility or internal consistency as evidence.
- Losing content in re-compression, or deleting (not marking) superseded
  decisions.
- Promoting checkpoint content into `learned-rules.md` or the Global
  Layer to "fix" contamination.
