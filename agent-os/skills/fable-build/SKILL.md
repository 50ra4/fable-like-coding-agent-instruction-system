---
name: fable-build
description: Builder-model (Fable) protocol for regenerating the claude/ and codex/ wrappers from the canonical skills, producing a semantic-parity audit report, and checking repository-wide doc coherence — every change proposed as a diff and applied only after approval.
---

## Purpose

Make the canonical→wrapper pipeline executable instead of hand-maintained. The README reserves the builder role for Fable: the wrappers under `claude/` and `codex/` are consumed at runtime by Opus / Sonnet / Codex, so distilling a canonical skill into a shorter wrapper without dropping a single binding instruction must be done by a model stronger than the consumers. `generate-agent-files` remains the canonical procedure for *what* the per-platform files look like; `fable-build` is the source-repo execution protocol *around* it — who runs it, how regeneration diffs get approved, and how semantic parity is proven.

## When to use

- After any canonical skill (`skills/*/SKILL.md`), `GLOBAL_*.md`, or `templates/` file changes in the Agent OS source repo.
- When a new canonical skill is added and its wrappers must be created.
- Periodically, to detect drift between canonical skills and previously hand-edited wrappers.
- Never as part of a normal coding session in an installed target project — this build runs only in the Agent OS source repo, by a builder-class model.

## Inputs

- Canonical sources: `skills/*/SKILL.md`, `GLOBAL_AGENTS.md`, `GLOBAL_CLAUDE.md`, `templates/`.
- Current generated artifacts: `claude/skills/*`, `codex/skills/*`, `claude/agents/*.md`, `codex/agents/*.toml`.
- Mechanical helpers: `scripts/fable-build.sh`, `scripts/validate-agent-os.sh`.
- The previous parity report, if any: `reports/fable-build-parity.md`.

## Procedure

1. Run `bash scripts/fable-build.sh --list` to enumerate every canonical→wrapper pair and detect missing wrappers and orphan wrappers (a wrapper with no canonical source).
2. Read each canonical skill in full and extract its binding items — procedure steps, Forbidden entries, Done criteria. This extraction is the baseline the parity audit scores against.
3. Regenerate both wrapper candidates per skill into a build directory outside the repo tree: each wrapper stays shorter than its canonical, opens with the standard deferral sentence pointing back to the canonical path, and may use platform-native wording. Never author new procedure content inside a wrapper (see `generate-agent-files`).
4. Preserve documented platform asymmetries — e.g. for `context-checkpoint`, Claude's wrapper may mention manual `/compact` but must never claim it auto-runs, while Codex's wrapper must not instruct manual compaction at all. Never flatten an asymmetry to make the wrappers look alike, and never introduce a new asymmetry without recording its justification.
5. Regenerate `claude/agents/*.md` and `codex/agents/*.toml` candidates the same way — meaning-equivalent across platforms, native format per platform.
6. Run `bash scripts/fable-build.sh --diff <build-dir>` to present the candidate-vs-current diff, and give a one-line reason per changed file — the same diff+reason+approval protocol as `improve-instructions`.
7. Apply candidates only after approval; unapproved candidates stay in the build directory. A zero diff is a valid outcome and is still reported.
8. Write the semantic-parity audit to `reports/fable-build-parity.md`: per skill, a table of binding items × (Claude wrapper, Codex wrapper) coverage, with every platform asymmetry listed alongside its evidence. Merge cumulatively into the one existing report — never append a second report block.
9. Audit repository-wide doc coherence — stated file counts, paths, cross-references, and line-count guards across `README.md`, `INSTALL.md`, scripts, and templates — and propose fixes as diffs. This audit is mechanical coherence only; semantic layer-placement auditing is a separate concern, out of scope here.
10. After applying approved changes, run `bash scripts/fable-build.sh --check` and `bash scripts/validate-agent-os.sh`; both must pass.

## Outputs

- Regenerated wrappers and agent definitions (written only after approval).
- `reports/fable-build-parity.md` — one cumulative parity audit report.
- Doc coherence findings, each with a proposed diff and reason.

## Forbidden

- Delegating the semantic-equivalence judgment to the script — `fable-build.sh` enumerates, diffs, and format-checks only; equivalence is the builder model's call.
- Overwriting wrappers, agents, or docs without the diff+reason+approval step.
- Authoring new procedure content inside a wrapper instead of the canonical skill.
- Flattening a justified platform asymmetry, or introducing one without recorded justification.
- Producing a wrapper that is longer than its canonical skill, or missing the pointer back to it.
- Running this build inside an installed target project's normal coding session.

## Done criteria

- Every canonical skill has both wrappers; `--list` reports no missing and no orphan entries.
- `reports/fable-build-parity.md` covers every skill with a binding-item parity table, and every asymmetry carries a justification.
- `fable-build.sh --check` and `validate-agent-os.sh` both pass.
- Every applied change went through diff+reason+approval; zero unapproved writes.
- File-count, path, and cross-reference statements in `README.md` / `INSTALL.md` match the actual tree.
