---
name: run-agent-evals
description: Run the project's recorded agent evaluation scenarios and check for precision regressions after an instruction change.
---

Canonical procedure: `agent-os/skills/run-agent-evals/SKILL.md`. Read it
before running this workflow — this file is a compact Codex-facing pointer,
not a replacement.

## Summary

1. Load the scenarios recorded in `.agent-os/evals.md`.
2. For each scenario, run it and check both the stated pass criteria and
   the absence of any explicitly forbidden behavior.
3. Record each result: date, eval name, model, pass/fail, and notes.
4. Route any failure to `.agent-os/failure-log.md` and, if the same
   failure pattern recurs, propose it as a rule candidate (via
   `learn-from-feedback` / `improve-instructions`).
5. Run this workflow whenever `AGENTS.md`, a skill, or
   `.agent-os/learned-rules.md` changes, to confirm no regression was
   introduced.

## Codex-specific notes

- Only execute commands already confirmed in `.agent-os/command-map.md`;
  do not improvise a command to make a scenario runnable.
- Do not invent pass/fail criteria beyond what a scenario in `evals.md`
  actually states — if a scenario is ambiguous, report that instead of
  guessing a criterion.

## Forbidden

- Reporting a scenario as passing when a forbidden behavior occurred.
- Skipping the failure-log/rule-candidate step after a failed eval.
- Modifying source files as part of running an eval.
