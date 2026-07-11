---
name: distill-rules
description: Builder-model protocol for semantically clustering verbatim feedback/failure-log entries into effective recurrence counts, proposing rule promotions/merges/deprecations with verbatim evidence, and flagging wording-independent conflicts — feeds improve-instructions' diff+approval flow. Builder-class model only, never a normal coding session.
---

The canonical procedure lives in `.agent-os/skills/distill-rules/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/distill-rules/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Run `scripts/summarize-learning-log.sh --adapter <dir>` and `scripts/detect-rule-conflicts.sh --pairs --adapter <dir>` as a mechanical pre-pass only — counts and candidate pairs, never a verdict.
2. Read every log entry in full and cluster by substance, not wording. Compute each cluster's **effective recurrence count** and list every member's **verbatim quote**.
3. Effective recurrence >= 2 → propose promoting/merging to active, keeping the clearer wording and strongest evidence. Recurrence of 1 stays a candidate.
4. Every promotion/merge/deprecation proposal MUST carry verbatim evidence and use the narrowest `Scope:` the evidence supports — never promote a one-off preference to global scope or the Global Layer.
5. Judge candidate pairs (including ones with no polarity keywords) for genuine same-scope contradiction. Report as pair + verbatim evidence + resolution options — never pick a side unilaterally.
6. Stale/superseded rules get a `Status: deprecated` proposal with a reason — never delete.
7. Present everything through `improve-instructions`' diff+approval protocol; apply nothing without approval.

## Forbidden

- Applying any rewrite, promotion, deprecation, or deletion without approval.
- Any proposal lacking verbatim evidence, or a conflict resolved by picking one side unilaterally.
- Promoting a one-off preference to global scope/Global Layer, or deleting a rule instead of deprecating it.
- Treating the mechanical scripts' output as a semantic verdict.

## Claude-specific notes

- This is builder-model-only work — never run it as part of a normal coding session in an installed target project.
- Escalate every detected conflict to the user with both rules' verbatim text; do not resolve it yourself.
