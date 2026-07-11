---
name: distill-rules
description: Builder-model (Fable) protocol for distilling verbatim feedback/failure logs into minimal, non-contradictory rules — semantic clustering with effective recurrence counts, promotion/merge/deprecation proposals with verbatim evidence, wording-independent conflict detection — all via the improve-instructions diff+approval protocol.
---

## Purpose

Distillation from verbatim logs to a minimal, non-contradictory general rule set is precision-critical: one wrongly promoted active rule degrades EVERY later session, because active rules are always binding. Two failure modes must both be avoided — overgeneralization (universalizing a one-off preference into a global rule) and undergeneralization (missing that two differently-worded remarks are actually the same lesson, so neither ever reaches the recurrence threshold on its own). That judgment belongs to a builder-class model (like `fable-build`), not the runtime coding model that merely consumes the rules each session and has no incentive, and often no context budget, to reread the full history of a rule before applying it.

The mechanical scripts in this repo (`summarize-learning-log.sh`, `detect-rule-conflicts.sh --pairs`) only pre-process the logs: they count, they enumerate candidate pairs by structural proximity, and they never read the substance of a `Rule:` body. Substance judgment — is this cluster really the same lesson, is this pair really a contradiction, is this generalization narrow enough — happens only in this skill, by the builder model, never by the scripts and never by whichever runtime model happens to be running a normal session.

This skill produces proposals, not applied changes. It feeds its findings into `improve-instructions`, which owns the diff+approval mechanics (merge, deprecate, present, wait for approval); `distill-rules` supplies the semantic groundwork — clusters, evidence, conflict pairs — that `improve-instructions` alone cannot derive from wording comparison.

## When to use

- As the semantic pre-pass feeding `improve-instructions`' periodic maintenance, whenever promotion, merge, or conflict decisions depend on substance rather than surface wording.
- When promotion decisions hinge on whether two differently-worded log entries describe the same lesson.
- When `scripts/detect-rule-conflicts.sh --pairs` reports closely-related active-rule pairs that need semantic judgment beyond opposite-polarity keyword matching.
- Not for recording a single new piece of feedback — that is `learn-from-feedback`'s job; this skill only re-examines what has already accumulated.
- Never as part of a normal coding session in an installed target project — this is a builder-class-model task, run only when distilling the Agent OS's own accumulated knowledge, the same way `fable-build` is run only for wrapper regeneration.

## Inputs

- `.agent-os/review-feedback-log.md` and `.agent-os/failure-log.md` — the verbatim source logs.
- `.agent-os/learned-rules.md`, and `.agent-os/rules/*.md` if `.agent-os/rules/` exists (split-out active rules; equally binding).
- Mechanical helpers: `scripts/summarize-learning-log.sh --adapter <dir>` (entry counts, literal-duplicate candidates) and `scripts/detect-rule-conflicts.sh --pairs --adapter <dir>` (active-rule candidate-pair enumeration).
- The promotion criteria in `templates/learned-rules.md.template`'s header comment.

## Procedure

1. Run `scripts/summarize-learning-log.sh --adapter <dir>` and `scripts/detect-rule-conflicts.sh --pairs --adapter <dir>` as the mechanical pre-pass: entry counts, literal-duplicate-heading candidates, and active-rule candidate pairs ordered by Scope/Applies-to proximity. Treat this output as enumeration only — never as a verdict.
2. Semantic clustering: read every log entry in full and group entries by substance, independent of wording (e.g. "don't put business logic in controllers" and "controllers should only route and validate" belong to the same cluster even though they share no keywords). For each cluster, compute the **effective recurrence count** — the number of independent entries in the cluster, not the number of times a particular phrasing was literally repeated — and list every member entry with its **verbatim quote** and date/label so the count is auditable later.
   - A cluster of one entry is a candidate only. A cluster of two or more independently-observed entries, however differently phrased, has effective recurrence >= 2 even if `summarize-learning-log.sh`'s literal-heading match saw them as unrelated.
3. Promotion & merge proposals: a cluster with effective recurrence >= 2 → propose promoting the matching candidate rule to active, or merging same-substance rules while keeping the clearer wording and the stronger evidence trail. A cluster with effective recurrence of 1 stays a candidate. Apply the promotion criteria in `learned-rules.md.template` strictly.
4. Overgeneralization guard: every promotion, merge, or deprecation proposal MUST attach the verbatim supporting evidence entries (quotes) that justify exactly that generalization; choose the narrowest `Scope:` the evidence supports, and never promote a one-off personal preference to a global-scope rule or into the Global Layer.
5. Semantic conflict detection: starting from the `--pairs` enumeration (and any pair the clustering itself surfaces), judge each pair for genuine incompatibility on the same scope — including mutually exclusive procedures that contain no polarity keywords at all (the script's do-not/never vs. always/must heuristic misses these by design). Report every conflict as: **conflict pair + evidence (verbatim quotes of both rules) + resolution options**. Picking one side unilaterally is forbidden; the decision goes to the user.
   - Example of a wording-independent conflict the heuristic misses: "edit the current migration file in place" vs. "create a new timestamped migration file for every change" — both are procedures, neither contains an opposite-polarity keyword the scan could pair up (do not/never on one side, always/must on the other), yet they cannot both hold for the same `migrations/` target.
6. Deprecation proposals: rules that are stale or superseded by a merge get a `Status: deprecated` proposal with the reason — never a deletion.
7. Present every resulting change through the `improve-instructions` diff+approval protocol: a diff (before/after) with a one-line reason per change, applied only after approval. Nothing here is applied without approval.

## Outputs

A distillation report with:
- **Clusters** — semantic groups with effective recurrence counts and every verbatim member quote.
- **Promotion / merge / deprecation proposals** — each with its verbatim evidence and chosen `Scope:`.
- **Conflict findings** — in the pair + evidence + resolution-options format, with no side picked.
- **Deprecation proposals** — the stale or superseded rule, its replacement (if a merge), and the reason.
- Everything packaged as diffs awaiting approval, handed off through `improve-instructions`.

## Forbidden

- Applying any rule rewrite, promotion, deprecation, or deletion without approval (inherits `improve-instructions`' Forbidden list).
- Making any proposal without attached verbatim evidence quotes.
- Resolving a conflict by silently picking one side.
- Promoting a one-off preference to global scope or into the Global Layer.
- Deleting rules — deprecate instead, with a reason.
- Treating the mechanical scripts' output (`summarize-learning-log.sh`, `detect-rule-conflicts.sh --pairs`) as a semantic verdict rather than a candidate enumeration.
- Running this distillation with a runtime coding model, or as part of a normal coding session in an installed project.

## Done criteria

- Every proposal carries verbatim evidence quotes from the source logs.
- Every conflict is reported in the pair + evidence + resolution-options format, with the decision left to the user.
- All changes went through the diff+approval protocol; zero unapproved writes.
- Effective recurrence counts are derived from full-log semantic clustering, not literal string matching.
