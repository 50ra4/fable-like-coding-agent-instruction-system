---
name: fable-build
description: Regenerate the claude/ and codex/ wrappers from the canonical skills, produce a semantic-parity audit report, and check doc coherence — a builder-model task run only in the Agent OS source repo; all diffs require approval.
---

Canonical procedure: `agent-os/skills/fable-build/SKILL.md` (when vendored into
a project, `.agent-os/skills/fable-build/SKILL.md`). Read it before running
this workflow — this file is a compact Codex-facing pointer, not a replacement.
This build runs only inside the Agent OS source repository, by a builder-class
model — never as part of a normal coding session in an installed project.

## Summary

1. `bash agent-os/scripts/fable-build.sh --list` — enumerate every
   canonical→wrapper pair; flag missing wrappers and orphan wrappers.
2. Read each canonical skill in full and extract its binding items
   (procedure steps, Forbidden entries, Done criteria) as the parity baseline.
3. Regenerate wrapper candidates into a build directory outside the repo
   tree — each shorter than its canonical, pointing back to it, with
   documented platform asymmetries preserved and justified. Codex agent
   definitions are regenerated as `.toml` files with the `name`,
   `description`, and `developer_instructions` keys.
4. `bash agent-os/scripts/fable-build.sh --diff <build-dir>` — present the
   diff with a one-line reason per file; apply only after approval. Zero
   diff is a valid, reported outcome.
5. Write the cumulative parity audit to
   `agent-os/reports/fable-build-parity.md` (merge into the one report,
   never append a second), and audit README/INSTALL file counts, paths, and
   cross-references, proposing fixes as diffs.
6. Finish with `bash agent-os/scripts/fable-build.sh --check` and
   `bash agent-os/scripts/validate-agent-os.sh` — both must pass.

## Forbidden

- Letting the script decide semantic equivalence — that judgment is the
  builder model's, not `fable-build.sh`'s.
- Applying regenerated files or doc fixes without the diff+reason+approval
  step.
- Writing new procedure content in a wrapper, flattening a justified
  platform asymmetry, or producing a wrapper longer than its canonical.
