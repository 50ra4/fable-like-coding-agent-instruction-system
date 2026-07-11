---
name: distill-rules
description: Builder-model protocol for semantically clustering verbatim feedback/failure-log entries into effective recurrence counts, proposing rule promotions/merges/deprecations with verbatim evidence, and flagging wording-independent conflicts — feeds improve-instructions' diff+approval flow. Builder-class model only, never a normal coding session.
---

Canonical procedure: `.agent-os/skills/distill-rules/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/distill-rules/SKILL.md`). Read it before running this workflow —
this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Run `scripts/summarize-learning-log.sh --adapter <dir>` and
   `scripts/detect-rule-conflicts.sh --pairs --adapter <dir>` first, as a
   mechanical pre-pass only — counts and candidate pairs, never a verdict.
2. Read every log entry in full and cluster it by substance, independent of
   wording. Compute each cluster's effective recurrence count and record
   every member's verbatim quote.
3. Effective recurrence >= 2 promotes/merges into an active rule (clearer
   wording, strongest evidence kept); recurrence of 1 stays a candidate.
4. Attach verbatim evidence to every promotion/merge/deprecation proposal
   and use the narrowest supported `Scope:` — never global scope or the
   Global Layer for a one-off preference.
5. Judge every candidate pair, including ones with no polarity keywords,
   for genuine same-scope contradiction. Report conflicts as pair +
   verbatim evidence + resolution options; never resolve unilaterally.
6. Deprecate stale/superseded rules with a reason instead of deleting them.
7. Route every change through `improve-instructions`' diff+approval flow;
   nothing is applied without approval.

## Codex-specific notes

- Builder-class model only — do not run this inside a normal coding
  session in an installed target project.
- When reporting a conflict, quote both rules verbatim in the summary so
  the user can decide without re-opening the log files.

## Forbidden

- Applying a rewrite, promotion, deprecation, or deletion without approval.
- A proposal without verbatim evidence, or a conflict resolved unilaterally.
- Promoting a one-off preference to global/Global Layer scope, or deleting
  a rule instead of deprecating it.
