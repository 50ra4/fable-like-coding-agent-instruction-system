---
name: run-agent-evals
description: Run the project's recorded eval scenarios from .agent-os/evals.md to check whether current instructions still produce correct, safe behavior. Use after any change to CLAUDE.md, skills, or learned-rules.md, and periodically to catch regressions.
---

The canonical procedure lives in `agent-os/skills/run-agent-evals/SKILL.md`. Follow that file's steps in full; if this project vendored a copy of the canonical skills, use the vendored copy instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Read `.agent-os/evals.md` for scenarios, each with inputs, pass criteria, and a forbidden-behavior list.
2. Run each scenario and capture the agent's actual behavior/output.
3. Score against both the pass criteria and the forbidden-behavior list — a forbidden action is a hard fail even if the final output looks correct.
4. Record a pass/fail result per scenario; do not silently drop a failing one.
5. Feed failures back: add or update `.agent-os/failure-log.md`, and where a failure traces to a missing or wrong rule, route it through `learn-from-feedback`/`improve-instructions` rather than editing `evals.md` to make it pass.

## Forbidden

- Weakening an eval's pass criteria so it passes.
- Omitting or hiding a failing scenario from the report.
- Treating a forbidden-behavior violation as acceptable because the end output was fine.

## Claude-specific notes

- Run this as its own pass and report pass/fail per scenario plainly.
- Do not "fix" instructions in the same breath as running evals — that is `improve-instructions`' job, informed by these results.
