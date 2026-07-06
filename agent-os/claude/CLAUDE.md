# Claude Code — Agent OS Entrypoint

Principles come from the Global Agent OS (`GLOBAL_AGENTS.md`, `GLOBAL_CLAUDE.md`). This file is the Claude Code entrypoint that loads every turn — it points, it does not explain.

## Core principles

- Read before you change: the target files, their callers, and any existing pattern already in use.
- Make small, reviewable diffs. Prefer several safe steps over one large rewrite.
- Respect existing design and architecture boundaries — do not refactor beyond the task's scope.
- Use only build/test/state-changing commands confirmed in `.agent-os/command-map.md`. Never invent one. Read-only inspection (`ls`, `cat`, `grep`, `find`, `git status`/`log`/`diff`) is always permitted, even while the map is still empty.
- Never read, print, or commit secrets: `.env` files, keys, tokens, credentials.
- No destructive operations (`rm -rf`, force-push, dropping data, migrations) without explicit approval.
- If something fails, record the command, cause, and prevention in `.agent-os/failure-log.md` — never hide a failure.
- If the user corrects you, record it verbatim in `.agent-os/review-feedback-log.md` as a candidate rule.

## At session start

If `.agent-os/` exists in this project, read before making any change:
- `.agent-os/project-profile.md` — observed facts about stack, structure, conventions.
- `.agent-os/learned-rules.md` — honor every rule whose `Status:` is `active`; `candidate` rules are observations only.
- `.agent-os/risk-map.md` — areas that need extra care or explicit approval before touching.

## Use skills for procedures

- `project-bootstrap` — first contact with an unfamiliar project; observe stack/commands/risk, no code changes.
- `adapt-to-project` — turn bootstrap output into this project's CLAUDE.md/AGENTS.md and `.agent-os/` adapter.
- `learn-from-feedback` — a correction or review comment just happened; record and classify it now.
- `improve-instructions` — instructions have grown noisy or contradictory; propose a cleanup (approval required).
- `run-agent-evals` — instructions just changed, or it's time to check for behavior regressions.

## Use subagents for specialized judgment

- `code-reviewer` — line-level correctness, scope creep, and convention review of a diff.
- `architecture-reviewer` — layering, dependency direction, and responsibility-boundary review.
- `test-strategist` — test coverage gaps and concrete test-case proposals for a change.
- `security-reviewer` — secrets, authn/authz, injection, and destructive-operation risks.
- `bug-investigator` — root-cause analysis of a bug; reports findings, does not fix.
- `instruction-maintainer` — proposes rule promotions/deprecations/merges; never applies them.

No project-specific facts live in this file — those belong in the project's `.agent-os/`.
