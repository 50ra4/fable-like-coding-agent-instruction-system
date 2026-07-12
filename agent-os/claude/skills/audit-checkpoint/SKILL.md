---
name: audit-checkpoint
description: Builder-model audit of .agent-os/context-checkpoints.md — cross-check confirmed facts against git/log evidence, re-compress bloat into one cumulative handoff summary, and detect rule/checkpoint contamination; every correction is proposed as a diff requiring approval.
---

The canonical procedure lives in `.agent-os/skills/audit-checkpoint/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/audit-checkpoint/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Use the `context-checkpoint` protocol's 12 sections and Forbidden list as the audit checklist — do not invent a different standard.
2. **Evidence cross-check**: every entry in "Confirmed facts", "Commands run and results", and "Files changed" must be corroborated by `git diff`/`git log`/`git status`, real command output, or the failure log. Uncorroborated entries get a demotion proposal into "Assumptions and uncertainties"; a test recorded as passed with no evidence it ran gets a proposal to move to "Known failures / unresolved issues" marked "not verified". Plausibility is not evidence.
3. **Re-compression**: if the file has multiple checkpoint blocks or has bloated, draft one merged, deduplicated `# Context Checkpoint`, resolving contradictions in favor of the newest user intent and keeping superseded decisions marked superseded with a one-line reason. Nothing may be lost.
4. **Contamination check**, both directions: no rule text from `learned-rules.md`/`.agent-os/rules/`/`GLOBAL_*`/canonical skills copied into the checkpoint, and no checkpoint content promoted into those files — promotion only goes through `learn-from-feedback`.
5. Present every correction — demotions, the re-compressed draft, contamination removals — as a before/after diff with a one-line reason, and apply only after approval.
6. This is a builder-model (Fable-class) task: the auditor must be stronger than the model that wrote the checkpoint. Auditing a checkpoint you wrote yourself in the same session is only a self-check, not an independent audit — say so in the report.
7. Not for writing checkpoints (that's `context-checkpoint`), and not a repo-wide layer-separation audit — only checkpoint-to-rules/Global contamination is in scope.

## Forbidden

- Rewriting the checkpoint without presenting the diff and receiving approval.
- Treating plausibility, tidy prose, or internal consistency as evidence.
- Losing content in re-compression — dropped failures, remaining work, latest intent, or deleted (rather than marked) superseded decisions.
- "Fixing" contamination by promoting checkpoint content into `learned-rules.md` or the Global Layer.

## Claude-specific notes

- This audit fits naturally right before an intentional manual `/compact`: audit first, then apply approved corrections to the checkpoint, then compact. Do not assume `/compact` exists on every Claude surface, and never claim a hook or prompt can auto-execute it.
- When a weaker execution model wrote the checkpoint under context pressure, run this audit with the strongest available model — an auditor no stronger than the author inherits its blind spots.
