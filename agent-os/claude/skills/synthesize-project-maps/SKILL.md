---
name: synthesize-project-maps
description: Builder-model (Fable) protocol for synthesizing architecture-map.md and risk-map.md from a systematic whole-repository read, with mandatory evidence on every statement, why-dangerous evidence for risk entries, a mandatory Unobserved-areas disclosure, and diff-only proposals against existing map content. Builder-class model only, never a normal coding session.
---

The canonical procedure lives in `.agent-os/skills/synthesize-project-maps/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/synthesize-project-maps/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Read the whole repository systematically: entry points, module boundaries, configuration, CI, and recent git history. Track everything NOT read — it feeds step 4's disclosure.
2. Synthesize `architecture-map.md`: layers, dependency directions, boundaries, extension points, update-together file groups. Every statement carries a file-path or git-history evidence citation; unevidenced statements are hypotheses, labeled as such.
3. Synthesize `risk-map.md`: dangerous/fragile areas, each with WHY it is dangerous, evidenced by git history, warning comments, or missing tests — never from commit counts alone.
4. Add a mandatory "Unobserved areas" note to each map listing what was not read. Implied full coverage is a violation.
5. If a map already has real content (beyond placeholders), propose changes as a diff for approval (`improve-instructions` protocol) — never overwrite. Filling a placeholder-only section may be applied directly.

## Forbidden

- Modifying any source, configuration, or test file — observe-only.
- A map statement without attached evidence.
- Omitting the Unobserved-areas note or implying untrue coverage.
- Overwriting or deleting existing map content without an approved diff.
- Running non-read-only or invented commands; reading secrets.
- Running this as part of a normal coding session — builder-model maintenance pass only.

## Claude-specific notes

- Use Read/Grep/Glob and read-only Bash (`git log`, `git diff`, `git status`) for inspection only — never a state-changing command.
- Edit is permitted only on `.agent-os/architecture-map.md` / `.agent-os/risk-map.md`, and only to fill placeholder-only sections directly or to apply an already-approved diff.
- Close with a short report to the user: what was read, what was skipped, and the highest-risk findings.
