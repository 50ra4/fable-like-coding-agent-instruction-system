---
name: synthesize-evals
description: Builder-model protocol for synthesizing discriminative evals from failure-log/review-feedback-log clusters — semantic clustering by root cause and task shape, drafting standard-Eval-format scenarios whose Forbidden behavior reproduces the original failure, with verbatim provenance and command-map-verbatim validation. Builder-class model only, never a normal coding session.
---

The canonical procedure lives in `.agent-os/skills/synthesize-evals/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/synthesize-evals/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Run `scripts/summarize-learning-log.sh --adapter <dir>` as a mechanical pre-pass only. Read every log entry in full and cluster by substance, not wording. Drop clusters an existing eval in `.agent-os/evals.md` already covers.
2. Draft one eval per remaining cluster in the standard Eval format (all seven sections, unique `## Eval:` heading). The Task must minimally reproduce the cluster's real task shape.
3. The Forbidden behavior section MUST include the behavior that produced the original failure, concretely enough that a repeating model necessarily triggers it.
4. Use only Validation commands verbatim from `.agent-os/command-map.md`, or `Manual review` if none fits — never invent one.
5. Attach an HTML comment after each eval: the regression it catches, plus verbatim provenance quotes with date/label. Comments are stripped before parsing.
6. Hand additions to `improve-instructions`'s non-destructive-addition flow; deleting/rewriting an existing eval needs explicit approval. Confirm the new eval parses via `--show`/`--check`.

## Forbidden

- An eval without attached verbatim provenance quotes.
- A Forbidden behavior section missing the original failure's behavior.
- A Validation command not command-map-verbatim (other than `Manual review`).
- Deleting or rewriting an existing eval without approval, or duplicate `## Eval:` names.
- Treating `summarize-learning-log.sh` output as a semantic verdict.

## Claude-specific notes

- Builder-model-only work — never run it as part of a normal coding session. A dedicated maintenance pass over an installed project's `.agent-os/*` logs is in scope.
- Present the synthesis report with each eval's provenance quotes inline, so the user can approve additions without reopening the logs themselves.
