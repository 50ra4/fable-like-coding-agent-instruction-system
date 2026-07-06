---
name: adapt-to-project
description: Turn project-bootstrap output into the project's adapter — AGENTS.md and .agent-os/ files — without ever editing the Global Agent OS.
---

Canonical procedure: `.agent-os/skills/adapt-to-project/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/adapt-to-project/SKILL.md`). Read it before running this workflow —
this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Read `GLOBAL_AGENTS.md` to confirm what already applies globally; do
   not repeat it in the project adapter.
2. Read `.agent-os/project-profile.md`, `.agent-os/command-map.md`, and
   `.agent-os/risk-map.md`; pull only verified facts, never hypotheses.
3. Write/update a short `AGENTS.md` at the project root pointing to
   `.agent-os/` and to relevant skills for detail — no long procedures
   inline.
4. Create `.agent-os/learned-rules.md` and `.agent-os/evals.md` if absent
   (empty shells, not pre-populated with unverified rules).
5. Every rule placed in the adapter must trace back to an observed fact
   or a repeated failure/feedback item — never a single guess.

## Codex-specific notes

- Generate `AGENTS.md` for the Codex entrypoint; only generate files for
  other platforms (e.g. Claude-facing files) if the user separately asks
  for them.
- Never modify anything under the Global Agent OS root
  (`GLOBAL_AGENTS.md`, `skills/`, `templates/`, `scripts/`) — the adapter
  is project-local only.

## Forbidden

- Writing strong rules up front with no evidence.
- Promoting a single failure or single review comment straight to an
  active rule (that requires 2+ occurrences — see `learn-from-feedback`).
- Letting the generated `AGENTS.md` grow long — details belong in skills.
