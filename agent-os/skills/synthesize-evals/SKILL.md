---
name: synthesize-evals
description: Builder-model (Fable) protocol for synthesizing discriminative evals from failure clusters — semantic clustering of failure-log/review-feedback-log entries by root cause and task shape, drafting standard-Eval-format scenarios whose Forbidden behavior reproduces the original failure, with verbatim provenance quotes and command-map-verbatim validation commands — additions flow through improve-instructions' non-destructive-addition rules.
---

## Purpose

An eval written by the runtime model that later executes evals tends to test what that model already does right — it is not adversarial to itself. A good eval is *discriminative*: only a model still carrying the targeted regression fails it. Designing the Task and the Forbidden behavior adversarially requires the author to foresee the subject model's failure modes better than the subject itself can, which is the same judge > judged principle behind `distill-rules` and `fable-build`, and belongs to a builder-class model for the same reason.

Extracting the "shape of the failure" — its task shape and root cause — from verbatim `failure-log.md` / `review-feedback-log.md` entries, and reducing that shape to a minimal concrete Task, requires clustering by cause structure rather than surface wording. `summarize-learning-log.sh` only counts entries and matches literal headings; it never reads a `Root cause:` or `Feedback:` body, so the substance judgment that makes clustering meaningful happens only in this skill.

Scope stays separated from neighboring skills: the output here is evals, never rules — rule distillation is `distill-rules`'s job. Grading an executed eval belongs to `judge-agent-eval`. This skill only synthesizes draft evals and their provenance, then hands additions to `improve-instructions`'s approval flow; it never edits `evals.md` directly.

## When to use

- As the drafting destination when `run-agent-evals` step 1 notes an eval-perspective gap rather than skipping it silently.
- When `improve-instructions` step 8 finds a cluster of failures that needs a regression eval.
- Never as part of a normal coding session — this is a builder-class-model task, run as a dedicated maintenance pass, like `distill-rules`. Also like `distill-rules`, it is not limited to the Agent OS source repo: an installed project's `.agent-os/*` logs are exactly in scope.
- Not for recording a new failure — that is `learn-from-feedback`'s job.
- Not for running or grading evals — that is `run-agent-evals` / `judge-agent-eval`'s job.

## Inputs

- `.agent-os/failure-log.md` and `.agent-os/review-feedback-log.md` — the verbatim source logs.
- `.agent-os/evals.md` — the existing eval catalog, for duplicate-coverage checks.
- `.agent-os/command-map.md` — the only source of legal Validation commands.
- Mechanical helper: `scripts/summarize-learning-log.sh --adapter <dir>` (entry counts, literal-duplicate candidates — enumeration only).
- The standard Eval format defined in `run-agent-evals`'s SKILL.md and `templates/agent-evals.md.template`.

## Procedure

1. Mechanical pre-pass: run `scripts/summarize-learning-log.sh --adapter <dir>` and treat its output as enumeration only, never a verdict. Then read every `failure-log.md` / `review-feedback-log.md` entry in full and cluster by substance — same root cause and same task shape, independent of wording (same principle as `distill-rules` step 2). Read `.agent-os/evals.md` and drop any cluster an existing eval already covers.
2. Draft exactly one eval per remaining cluster, using the standard Eval format from `run-agent-evals` — all seven sections (Task / Expected files to inspect / Expected behavior / Forbidden behavior / Pass criteria / Validation command / Learning check), under a `## Eval: <name>` heading unique in the catalog. The Task must be a minimal, concrete reproduction of the cluster's task shape — the situation the original failure actually happened in, not a generic exercise.
3. Discriminative-power guarantee: the Forbidden behavior section MUST include the behavior that produced the original failure, stated concretely enough that a model repeating that failure necessarily triggers it. An eval whose Forbidden behavior does not reproduce the original failure does not catch the regression and must not be proposed.
4. Validation command gate: use only commands that appear verbatim (character-for-character) in `.agent-os/command-map.md`; if no mapped command can validate the eval, write `Manual review` — matching `run-agent-evals.sh --exec`'s exact-match gate and its manual-placeholder gate. Never invent or adapt a command.
5. Provenance attachment: immediately after each drafted eval block, attach an HTML comment stating (a) the regression this eval catches, one line, and (b) the verbatim quote(s) of the supporting failure-log / feedback-log entries with their date/label, so the evidence stays auditable. `run-agent-evals.sh` strips HTML comments before parsing, so this attachment never breaks `--show` / `--check` compatibility.
6. Hand additions to `improve-instructions`'s non-destructive-addition handling: new evals may be added once the reasoning (cluster + provenance) is presented; deleting or rewriting an EXISTING eval always requires explicit approval. After insertion, confirm `scripts/run-agent-evals.sh --adapter <dir> --show <name>` and `--check <name>` parse the new eval.

## Outputs

- A synthesis report with clusters — root cause, task shape, and member entries with verbatim quotes.
- The drafted evals in standard format, each immediately followed by its provenance comment.
- A coverage note: which gap/perspective each eval fills, and which clusters were dropped as already covered.
- A separate approval-required list for anything that touches an existing eval.

## Forbidden

- Proposing an eval without attached verbatim provenance quotes.
- A Forbidden behavior section that does not include the original failure's behavior.
- A Validation command not present verbatim in `command-map.md`, other than `Manual review`.
- Deleting or rewriting an existing eval without explicit approval.
- Duplicate `## Eval:` names.
- Treating `summarize-learning-log.sh` output as a semantic verdict rather than enumeration.
- Running this synthesis with a runtime coding model or as part of a normal coding session — a dedicated builder-model maintenance pass over an installed adapter is in scope, not forbidden.

## Done criteria

- Every drafted eval has all seven sections and parses via `run-agent-evals.sh --show`/`--check`.
- Every eval carries its "regression caught" line and verbatim provenance quotes.
- Every Validation command is command-map-verbatim or `Manual review`.
- Clusters were derived from full-log semantic reading, not literal heading matching.
- Zero unapproved changes to existing evals.
