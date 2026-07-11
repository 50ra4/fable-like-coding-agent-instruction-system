---
name: synthesize-evals
description: Builder-model protocol for synthesizing discriminative evals from failure-log/review-feedback-log clusters — semantic clustering by root cause and task shape, drafting standard-Eval-format scenarios whose Forbidden behavior reproduces the original failure, with verbatim provenance and command-map-verbatim validation. Builder-class model only, never a normal coding session.
---

Canonical procedure: `.agent-os/skills/synthesize-evals/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/synthesize-evals/SKILL.md`). Read it before running this
workflow — this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Run `scripts/summarize-learning-log.sh --adapter <dir>` as a mechanical
   pre-pass only. Read every log entry in full and cluster by substance,
   not wording. Drop clusters an existing `.agent-os/evals.md` eval covers.
2. Draft one eval per remaining cluster in the standard Eval format (all
   seven sections, unique `## Eval:` heading), Task minimally reproducing
   the cluster's real task shape.
3. Forbidden behavior MUST include the behavior that produced the
   original failure, concrete enough that a repeating model triggers it.
4. Use only Validation commands verbatim from `.agent-os/command-map.md`,
   or `Manual review` if none fits — never invent one.
5. Attach an HTML comment after each eval: the regression it catches,
   plus verbatim provenance quotes with date/label. Comments are stripped
   before parsing, so `--show`/`--check` stay unaffected.
6. Hand additions to `improve-instructions`'s non-destructive-addition
   flow; deleting/rewriting an existing eval needs explicit approval.
   Confirm the new eval parses via `--show`/`--check`.

## Codex-specific notes

- Builder-class model only — do not run this inside a normal coding
  session. A dedicated maintenance pass over an installed project's
  `.agent-os/*` logs is in scope.
- Quote the supporting log entries verbatim in the summary so the user
  can approve additions without reopening the logs.

## Forbidden

- An eval proposed without attached verbatim provenance quotes.
- A Forbidden behavior section omitting the original failure's behavior.
- A Validation command not command-map-verbatim (other than
  `Manual review`), or a duplicate `## Eval:` name.
- Deleting or rewriting an existing eval without explicit approval.
- Treating `summarize-learning-log.sh` output as a semantic verdict.
