---
name: audit-checkpoint
description: Builder-model audit of .agent-os/context-checkpoints.md — cross-check confirmed facts against git/log evidence, re-compress bloat into one cumulative handoff summary, and detect rule/checkpoint contamination; every correction is proposed as a diff requiring approval.
---

## Purpose

The `context-checkpoint` protocol's Forbidden list (unverified facts recorded as confirmed, tests recorded as passed when not run, hidden failures, dropped user instructions) is enforced only by the self-restraint of the model writing the checkpoint. This skill is the auditor-side enforcement: an independent, stronger reader cross-checks the checkpoint against real evidence, re-compresses bloat with full fidelity, and checks layer contamination. An auditor no stronger than the author inherits the author's blind spots, so this is a builder-model (Fable-class) task, like `fable-build` and `distill-rules` — it applies both inside the Agent OS repository and to any installed project adapter.

## When to use

- `validate-agent-os.sh` warns that `context-checkpoints.md` exceeded the line threshold.
- At long-session milestones, or before handing off to another model or session.
- Delegated from `improve-instructions` step 5 when the checkpoint has bloated.
- When checkpoint trustworthiness is in doubt (e.g. it was written by a weaker execution model under context pressure).
- Not for writing checkpoints — that is `context-checkpoint`'s job. Not a repo-wide layer-separation audit — only checkpoint ⇄ rules/Global contamination is in scope here.

## Inputs

- `.agent-os/context-checkpoints.md` — the checkpoint under audit.
- Evidence sources: `git diff` / `git log` / `git status`, real command output available in the session or its logs, `.agent-os/failure-log.md`.
- `skills/context-checkpoint/SKILL.md` — its 12-section format and Forbidden list are the audit checklist.
- `.agent-os/learned-rules.md`, `.agent-os/rules/*.md`, `GLOBAL_*` files, canonical skills — contamination-check targets, read-only.

## Procedure

1. Read the checkpoint and the canonical `context-checkpoint` protocol. Use the protocol's 12 sections and Forbidden list as the audit checklist — do not invent a different standard.
2. **Evidence cross-check**: for every entry in "Confirmed facts", "Commands run and results", and "Files changed", find corroborating evidence — `git diff`/`git log`/`git status`, actual command output, or the failure log. An entry with no corroboration gets a *demotion proposal* into "Assumptions and uncertainties" (never a silent rewrite). A test recorded as passed with no evidence it ran gets a proposal to move to "Known failures / unresolved issues" marked "not verified". Plausibility is not evidence.
3. **Latest-intent check**: confirm the newest user instruction is present in "Objective and latest user intent" and not dropped or downgraded by older plans, and that every superseded decision carries a one-line reason.
4. **Re-compression**: if the file has multiple `# Context Checkpoint` blocks, duplicated content, or has bloated past the threshold, draft one merged cumulative summary: deduplicate; resolve contradictions in favor of the newest user intent; keep superseded decisions marked superseded with their reason rather than deleting them; preserve all unresolved failures and remaining work. Nothing may be lost or altered in meaning by the compression — when unsure whether two entries are duplicates, keep both and flag the pair.
5. **Contamination check**, both directions: no rule text copied from `learned-rules.md` / `.agent-os/rules/` / `GLOBAL_*` / canonical skills into the checkpoint (adapter files are referenced by name only), and no checkpoint content promoted into those files — rule promotion goes only through `learn-from-feedback`. Flag violations; do not edit rules files from here.
6. **Format conformance**: exactly one `# Context Checkpoint`; the 12 `##` sections in canonical order; ends with the next recommended step.
7. Present every correction — demotions, the re-compressed draft, contamination removals — as a before/after diff with a one-line reason per change, and apply only after approval.
8. Record the outcome so it can feed the checkpoint-related eval axes in `run-agent-evals` (no unverified content; no Global Layer contamination; latest intent retained).

## Outputs

- An audit report grouped by: unverified entries (with demotion proposals), re-compression draft (if bloated), contamination findings (both directions), and format violations.
- A single diff proposal covering all corrections; the updated checkpoint is written only after approval.

## Forbidden

- Rewriting the checkpoint without presenting the diff and receiving approval.
- Accepting an entry as confirmed because it is plausible, well-written, or internally consistent — corroboration must be actual evidence.
- Losing content in re-compression: dropping unresolved failures, remaining work, or the latest user instruction, or deleting superseded decisions instead of keeping them marked with a reason.
- "Fixing" contamination by promoting checkpoint content into `learned-rules.md` or the Global Layer.
- Treating an audit of a checkpoint you wrote yourself in the same session as an independent audit — that is a self-check at best; say so in the report.

## Done criteria

- Every entry in the evidence-bearing sections either cites corroborating evidence or appears in the diff as a demotion proposal.
- The proposed checkpoint is a single cumulative `# Context Checkpoint` with the 12 sections in order, latest user intent intact, superseded decisions preserved with reasons.
- Contamination in both directions was checked and either cleared or flagged.
- No change was applied without the diff being presented and approved.
