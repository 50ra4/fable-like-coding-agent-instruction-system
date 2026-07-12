---
name: audit-layer-separation
description: Builder-model semantic audit of where statements live — classify every statement in GLOBAL_* files, canonical skills, installed CLAUDE.md/AGENTS.md, and learned rules as universal principle vs. project-specific fact, report only placement mismatches, and propose demotions as diffs requiring approval; never propose promotion into the Global Layer.
---

Canonical procedure: `.agent-os/skills/audit-layer-separation/SKILL.md` (inside
the Agent OS repository itself, the canonical source is
`agent-os/skills/audit-layer-separation/SKILL.md`). Read it before running
this workflow — this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Adopt the README's layer-separation section plus
   `GLOBAL_AGENTS.md`'s self-description as the only judgment standard —
   never invent another one.
2. Classify every statement in `GLOBAL_AGENTS.md`/`GLOBAL_CLAUDE.md`,
   canonical `skills/*/SKILL.md`, the installed `CLAUDE.md`/`AGENTS.md`,
   and `learned-rules.md` (plus `.agent-os/rules/*.md`) as universal
   principle, project-specific fact, or intermediate. Judge by meaning
   and scope of applicability, not surface markers — no project name in
   the text does not make a statement universal.
3. Report only placement mismatches, each with the verbatim quote, which
   part of the standard it violates, and a before/after move diff.
4. Global → Adapter is a demotion proposal; adapter-side universal
   should-statements are flagged only — never propose promotion into
   the Global Layer (promotion goes only through `learn-from-feedback`'s
   promotion criteria).
5. Intermediate cases (e.g. "keep PRs small") go to Needs manual
   confirmation with both readings — never settle them yourself.
6. Treat `validate-agent-os.sh` contamination warnings as mechanical
   candidate leads only: confirm or dismiss each one semantically.
7. Apply nothing — no moves, no deletions — without an approved diff.
   Out of scope: checkpoint ⇄ rules/Global contamination
   (`audit-checkpoint`'s job) and rule lifecycle
   (`distill-rules`/`learn-from-feedback`'s job).

## Codex-specific notes

- Builder-model (Fable-class) task only: never run this as part of a
  normal Codex coding session. The auditor must be stronger than the
  models that wrote the audited text — a same-class auditor inherits
  the same blind spots.

## Forbidden

- Proposing promotion of any statement into the Global Layer.
- Applying, moving, or deleting anything without an approved diff.
- Ruling on intermediate cases instead of routing them to Needs manual
  confirmation.
- Treating a mechanical warning as a confirmed finding, or inventing a
  judgment standard beyond the README section and `GLOBAL_AGENTS.md`.
