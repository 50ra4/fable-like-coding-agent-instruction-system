---
name: audit-layer-separation
description: Builder-model semantic audit of where statements live — classify every statement in GLOBAL_* files, canonical skills, installed CLAUDE.md/AGENTS.md, and learned rules as universal principle vs. project-specific fact, report only placement mismatches, and propose demotions as diffs requiring approval; never propose promotion into the Global Layer.
---

## Purpose

The Global/Project layer separation (README "global layer と project adapter の責務分離"; `GLOBAL_AGENTS.md`: "Project-specific facts live in each project's `.agent-os/` adapter — never here.") is stated everywhere but verified nowhere: `validate-agent-os.sh` checks structure, not which layer a statement belongs to. Contamination accumulates silently as the learning loop runs — project-specific text in the Global Layer destroys reuse across every project, and universal should-statements in an adapter breed duplication and contradiction. Whether a statement is "always true in every project" or "an observed local fact" is a judgment about meaning and scope of applicability, not surface text (a statement can be project-specific with no project name in it, e.g. a "principle" that assumes one directory layout). The execution model running the learning loop is itself the contamination source, so an auditor of the same class inherits its misjudgments — this is a builder-model (Fable-class) task, like `fable-build` and `distill-rules`.

## When to use

- As part of an `improve-instructions` maintenance pass.
- Before merging a PR that changes the Global Layer (`GLOBAL_*.md` or canonical `skills/*/SKILL.md`).
- When `validate-agent-os.sh` emits Global-Layer contamination warnings (its mechanical pre-pass; this skill is the semantic judgment it explicitly does not attempt).
- Not for checkpoint ⇄ rules/Global copy detection — that is `audit-checkpoint`'s scope. Not for rule promotion/merge/deprecation lifecycle — that is `distill-rules` / `learn-from-feedback`.

## Inputs

- Global Layer: `GLOBAL_AGENTS.md`, `GLOBAL_CLAUDE.md`, canonical `skills/*/SKILL.md`.
- Adapter side: the installed project's `CLAUDE.md` / `AGENTS.md`, `.agent-os/learned-rules.md`, and `.agent-os/rules/*.md` if present.
- Judgment standard: the README's layer-separation section and `GLOBAL_AGENTS.md`'s self-description — adopt them as-is; do not invent a different standard.
- Optional mechanical pre-pass: `validate-agent-os.sh` warnings (concrete command strings / package-manager names in `GLOBAL_*.md`).

## Procedure

1. Read the judgment standard first, then every target file in full.
2. Classify each statement as **universal principle** (holds in every project, always), **project-specific fact** (true here because it was observed here), or **intermediate** (defensible either way, context-dependent — e.g. "keep PRs small", "migrations need manual review"). Judge by meaning and scope of applicability, not by surface markers: no project name in the text does not make it universal.
3. Compare each classification against where the statement currently lives. **Report only mismatches** — statements whose classification and location agree are not findings.
4. For each mismatch, attach: the verbatim statement, why it does not belong in its layer (which part of the standard it violates), and a move proposal as a before/after diff. Global → Adapter is a *demotion proposal*. For universal should-statements found in an adapter, flag them with the duplication/contradiction risk — do **not** propose promoting them into the Global Layer; promotion goes only through `learn-from-feedback`'s promotion criteria.
5. Put every intermediate statement under **Needs manual confirmation** (same section semantics as `improve-instructions`' output) with the arguments both ways — never settle it yourself.
6. Treat `validate-agent-os.sh` warnings as candidate leads only: confirm or dismiss each one semantically (a tool name can appear legitimately, e.g. as a "what does NOT belong here" example), and say which.
7. Present the whole result as a report plus one diff proposal set; apply nothing — no moves, no deletions — until the user approves.

## Outputs

- An audit report grouped by: Global-Layer contamination (demotion diffs), adapter-side universal statements (flags, no promotion), Needs manual confirmation (intermediate cases with both readings), and the disposition of each mechanical warning.
- Each finding carries the verbatim statement, the standard it violates, and a before/after diff. No finding = state "no contamination found" explicitly.

## Forbidden

- Proposing promotion of any statement into the Global Layer — demotions and flags only; promotion is `learn-from-feedback`'s job under its promotion criteria (one-off preferences never qualify).
- Applying, moving, or deleting any statement without the diff being presented and approved.
- Ruling on intermediate cases instead of routing them to Needs manual confirmation.
- Treating a mechanical warning from `validate-agent-os.sh` as a confirmed finding without semantic confirmation, or inventing a judgment standard beyond the README section and `GLOBAL_AGENTS.md`'s self-description.
- Auditing Global/adapter text you wrote yourself in the same session and calling it an independent audit — that is a self-check; say so in the report.

## Done criteria

- Every target file was read and every statement classified; only placement mismatches were reported.
- Every finding has a verbatim quote, a standard-based reason, and a move diff (or an explicit flag for adapter-side universals).
- Intermediate cases sit in Needs manual confirmation, undecided.
- No promotion into the Global Layer was proposed anywhere, and nothing was applied without approval.
