---
name: synthesize-project-maps
description: Builder-model (Fable) protocol for synthesizing architecture-map.md and risk-map.md from a systematic whole-repository read, with mandatory evidence on every statement, why-dangerous evidence for risk entries, a mandatory Unobserved-areas disclosure, and diff-only proposals against existing map content. Builder-class model only, never a normal coding session.
---

Canonical procedure: `.agent-os/skills/synthesize-project-maps/SKILL.md` (inside the
Agent OS repository itself, canonical source is `agent-os/skills/synthesize-project-maps/SKILL.md`).
Read it first — this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Read the whole repository systematically: entry points, module
   boundaries, config, CI, recent git history. Track everything NOT read
   — it feeds the Unobserved-areas disclosure in step 4.
2. Synthesize `architecture-map.md`: layers, dependency directions,
   boundaries, extension points, update-together file groups. Every
   statement carries evidence (file path/git-history ref); unevidenced
   statements are hypotheses, labeled as such.
3. Synthesize `risk-map.md`: dangerous/fragile areas, each with WHY it
   is dangerous, evidenced by git history (hotfixes, reverts), warning
   comments, or missing tests — never from commit counts alone.
4. Add an explicit "Unobserved areas" note to each map listing what was
   not read. Implied full coverage without disclosure is a violation.
5. If an existing map has real content beyond placeholders, do not
   overwrite it — present changes as a diff proposal for approval
   (`improve-instructions`'s protocol). Filling a placeholder-only
   section may be applied directly.

## Codex-specific notes

- Observation-only: read files, run only read-only shell commands
  (`git log`, `git diff`, `git status`) — never edit source/config/test
  files, never build/install/test during synthesis, never read `.env`
  files, key material, or other secrets.
- Quote the supporting evidence (file paths / git-history references)
  verbatim in the final report so the user can approve map diffs
  without re-reading the repo.
- Builder-class model only — never inside a normal coding session; a
  maintenance pass over an installed adapter's `.agent-os/*` maps is in scope.

## Forbidden

- Modifying any source, configuration, or test file.
- A map statement without attached evidence, or omitting the
  Unobserved-areas note, or implying untrue coverage.
- Overwriting or deleting existing map content without an approved diff.
- Running build/test/state-changing/invented commands, or reading
  `.env`/key material/other secrets.
