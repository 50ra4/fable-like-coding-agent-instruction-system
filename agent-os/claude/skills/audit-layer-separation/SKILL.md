---
name: audit-layer-separation
description: Builder-model semantic audit of where statements live — classify every statement in GLOBAL_* files, canonical skills, installed CLAUDE.md/AGENTS.md, and learned rules as universal principle vs. project-specific fact, report only placement mismatches, and propose demotions as diffs requiring approval; never propose promotion into the Global Layer.
---

The canonical procedure lives in `.agent-os/skills/audit-layer-separation/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/audit-layer-separation/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Adopt the README's layer-separation section plus `GLOBAL_AGENTS.md`'s self-description as the only judgment standard — never invent another one.
2. Classify every statement in `GLOBAL_AGENTS.md`/`GLOBAL_CLAUDE.md`, canonical `skills/*/SKILL.md`, the installed `CLAUDE.md`/`AGENTS.md`, and `learned-rules.md` (plus `.agent-os/rules/*.md`) as universal principle, project-specific fact, or intermediate — judge by meaning and scope of applicability, not surface markers (no project name in the text does not make a statement universal).
3. Report only placement mismatches, each with the verbatim quote, which part of the standard it violates, and a before/after move diff.
4. Global → Adapter is a demotion proposal; adapter-side universal should-statements are flagged only — never propose promotion into the Global Layer (promotion goes only through `learn-from-feedback`'s promotion criteria).
5. Intermediate cases (e.g. "keep PRs small") go to Needs manual confirmation with both readings — never settle them yourself.
6. Treat `validate-agent-os.sh` contamination warnings as mechanical candidate leads only: confirm or dismiss each one semantically.
7. Apply nothing — no moves, no deletions — without the diff being presented and approved.

Out of scope: checkpoint ⇄ rules/Global contamination is `audit-checkpoint`'s job; rule promotion/merge/deprecation lifecycle is `distill-rules`/`learn-from-feedback`'s.

## Forbidden

- Proposing promotion of any statement into the Global Layer.
- Applying, moving, or deleting anything without an approved diff.
- Ruling on intermediate cases instead of routing them to Needs manual confirmation.
- Treating a mechanical warning as a confirmed finding, or inventing a judgment standard beyond the README section and `GLOBAL_AGENTS.md`.

## Claude-specific notes

- This is a builder-model (Fable-class) task: run it with the strongest available model, since the execution model running the learning loop is itself the contamination source.
- Auditing text you wrote yourself in the same session is only a self-check, not an independent audit — say so in the report. Recommended timing: during `improve-instructions` maintenance passes and before PRs touching `GLOBAL_*`/canonical skills.
