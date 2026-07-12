---
name: synthesize-project-maps
description: Builder-model (Fable) protocol for synthesizing architecture-map.md and risk-map.md from a systematic whole-repository read — layers, dependency directions, boundaries, and update-together file groups with mandatory file-path/git-history evidence on every statement, why-dangerous evidence for every risk entry, a mandatory Unobserved-areas disclosure, and diff-only proposals against existing map content.
---

## Purpose

`project-bootstrap` writes the first version of `architecture-map.md` and `risk-map.md` from lightweight first-contact observation, so the initial maps reflect what one session happened to touch. Extracting layering, dependency direction, responsibility boundaries, and fragility from a whole repository — code, configuration, CI, and recent git history — requires reading all of it under one consistent view, which is a builder-class task for the same artifact > executor reason as `distill-rules` and `synthesize-evals`: the maps are consumed by every later session and by the `architecture-reviewer` subagent.

A wrong map is worse than no map. A risk-map that misses a dangerous area implicitly labels it safe; an architecture-map that asserts a layer boundary that does not exist binds every later session to a false premise. Fragility estimation from git history (frequently hotfixed files, repeatedly reverted areas) requires reading why changes happened, not surface commit counts.

## When to use

- After `project-bootstrap` has produced the initial maps and the adapter needs a full-repository synthesis pass. Division of labor: `project-bootstrap` owns the initial maps (first-contact observation); this skill owns their deepening from a systematic whole-repository read.
- Never as part of a normal coding session — this is a builder-class maintenance pass, like `distill-rules`. An installed project's `.agent-os/` adapter is exactly in scope.
- Not for first contact with a project — that is `project-bootstrap`'s job.
- Not for `command-map.md` — commands must be executed to be verified, which is outside this observe-only skill; the command map stays `project-bootstrap`'s responsibility.

## Inputs

- The repository root, read-only: entry points, module/package boundaries, build and runtime configuration, CI workflows.
- Recent git history, read-only (`git log`, `git diff`, `git log --follow` on suspect files) — read-only inspection is always permitted (`GLOBAL_AGENTS.md`), even while `command-map.md` is still sparse.
- Existing `.agent-os/architecture-map.md`, `.agent-os/risk-map.md`, and `.agent-os/project-profile.md` — prior observations are a learning asset, never a scratch buffer.

## Procedure

1. Systematic whole-repository read: entry points, module boundaries, configuration, CI workflows, and recent git history. Keep a running list of everything NOT actually read — it becomes the Unobserved-areas disclosure in step 4, so coverage is claimed only for what was truly read.
2. Synthesize `architecture-map.md` content: layers/modules and their responsibilities, allowed dependency directions, boundaries that must not be crossed, extension points, and file groups that must be updated together when one of them changes. Every statement carries its evidence — one or more file paths, or a git-history reference. A statement without evidence is a hypothesis and must be labeled as one, never written as fact.
3. Synthesize `risk-map.md` content: dangerous areas, approval-gated paths, fragile spots — each with WHY it is dangerous, evidenced by git history (frequent hotfixes, reverts), in-code warning comments, or missing tests. Never infer fragility from commit counts alone; read the change reasons behind the numbers.
4. Apply the fact/hypothesis golden rule of `templates/project-profile.md.template`, and add an explicit "Unobserved areas" note to each map listing what was not read (directories, generated trees, vendored code, history beyond the window). Self-reported coverage is mandatory — implied full coverage is a violation.
5. If an existing map has real content (anything beyond its "Not yet observed" placeholders), do not overwrite it: present the changes as a diff proposal for approval, following `improve-instructions`' protocol — both maps are protected learning assets in `bootstrap-project.sh`'s PROTECTED set, surviving even `--force`. Filling a placeholder-only section is a non-destructive addition and may be applied directly.

## Outputs

- Synthesized `architecture-map.md` / `risk-map.md` content in the section layout of `project-adapter/.agent-os/`'s scaffolds, every statement with attached evidence.
- An "Unobserved areas" note in each map.
- For a map with prior content: a diff proposal awaiting approval, not an edited file.
- A short report to the user: what was read, what was skipped, and the highest-risk findings.

## Forbidden

- Modifying any source, configuration, or test file — this skill is observe-only, same discipline as `project-bootstrap`.
- A map statement without attached evidence (file path or git-history reference).
- Omitting the Unobserved-areas note, or implying coverage of areas that were not read.
- Overwriting or deleting existing map content without an approved diff.
- Running build/test/state-changing commands or inventing commands — read-only inspection only.
- Reading `.env` files, key material, or other secrets, even to "understand config".
- Running this synthesis with a runtime coding model or as part of a normal coding session — a dedicated builder-model maintenance pass over an installed adapter is in scope, not forbidden.

## Done criteria

- Every statement in both maps carries evidence; everything unevidenced is labeled a hypothesis.
- Both maps contain an Unobserved-areas note.
- Any change to pre-existing map content exists only as a diff proposal awaiting approval.
- No file outside `.agent-os/` was modified, and no state-changing command was run.
- The user has the short report: read/skipped areas and highest-risk findings.
