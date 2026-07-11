---
name: run-agent-evals
description: Run the project's recorded eval scenarios from .agent-os/evals.md to check whether current instructions still produce correct, safe behavior. Use after any change to CLAUDE.md, skills, or learned-rules.md, and periodically to catch regressions.
---

The canonical procedure lives in `.agent-os/skills/run-agent-evals/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/run-agent-evals/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Use `scripts/run-agent-evals.sh --adapter <dir> --list` to enumerate scenarios from `.agent-os/evals.md`, then `--show <name>` to read one in full before starting. A perspective with no eval yet is a gap for `improve-instructions`/`synthesize-evals`, not something to skip or improvise.
2. Run each scenario yourself and capture the agent's actual behavior/output — the script enumerates and records but does not perform the task.
3. Score against both the pass criteria and the forbidden-behavior list — a forbidden action is a hard fail even if the final output looks correct. Use `--check <name>` to see the Validation command(s); only add `--exec` for commands listed verbatim in `.agent-os/command-map.md`.
4. Save a run transcript to `.agent-os/eval-transcripts/<eval-name-slug>-<YYYY-MM-DD>.md` (commands run, files changed, final self-assessed report).
5. Record a pass/fail result per scenario with `--record <name> --result pass|fail --model <name> [--notes <text>] [--transcript <path>]`; do not silently drop a failing one. Without `--judge-notes` the Judge cell records `unjudged`.
6. Request grading from `judge-agent-eval`, run by an independent, stronger model — never by yourself — passing the eval name and transcript path. Grading records via `--judge-model <judge-model> --judge-notes "<verdict>" --transcript <path>`; the script itself refuses judge notes without a valid transcript and refuses a judge model equal to the executing model.
7. Feed failures back: add or update `.agent-os/failure-log.md`, and where a failure traces to a missing or wrong rule, route it through `learn-from-feedback`/`improve-instructions` rather than editing `evals.md` to make it pass.

## Forbidden

- Weakening an eval's pass criteria so it passes.
- Omitting or hiding a failing scenario from the report.
- Treating a forbidden-behavior violation as acceptable because the end output was fine.
- Passing `--exec` for a validation command not listed in `.agent-os/command-map.md` — the script refuses this itself, but do not work around it.
- Acting as your own judge — never supply `--judge-notes` for a run you performed yourself; ungraded rows stay `unjudged`. The script refuses to record when `--judge-model` equals `--model`.

## Claude-specific notes

- Run this as its own pass and report pass/fail per scenario plainly.
- Do not "fix" instructions in the same breath as running evals — that is `improve-instructions`' job, informed by these results.
