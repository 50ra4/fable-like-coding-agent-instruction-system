---
name: judge-agent-eval
description: Grade an executed eval as an independent judge — read the run transcript, verify pass criteria, detect forbidden behavior, and flag mismatches with the executing model's self-report.
---

## Purpose

Replace self-graded eval results with third-party grading. The executing model performs the eval's Task and saves a run transcript; a stronger, independent judge model reads that transcript and grades the run — catching exactly the deviations self-grading cannot detect: faked verification, hidden failures, and skipped learning checks.

## When to use

- After an eval run performed via `run-agent-evals`, when its transcript exists.
- When a recorded Results row shows `unjudged` and the run's transcript is still available.
- When a self-reported pass looks suspicious (e.g. claims verification but the notes show no command output).

## Inputs

- The full eval block: `scripts/run-agent-evals.sh --adapter <dir> --show <eval-name>`.
- The run transcript: `.agent-os/eval-transcripts/<eval-name-slug>-<YYYY-MM-DD>.md`, written by the executing model (format defined in `run-agent-evals`).
- The executing model's self-reported result (pass/fail, notes, Learning check answers) — normally the transcript's final report.
- `.agent-os/command-map.md`, if a Validation command needs re-running.

## Procedure

1. Confirm the transcript file exists and names the executing model. If there is no transcript, refuse to grade: the result stays `unjudged`. Never grade from the self-report alone.
2. Confirm you are not the executing model: compare the transcript's `Model:` line against your own identity. If they match — or you performed the run in this session — stop and hand off to a different, stronger model.
3. Read the full eval block with `--show`; extract Pass criteria, Forbidden behavior, and Learning check as your grading checklist.
4. Read the transcript end to end — commands, outputs, changed files, final report. Do not skim and do not stop at the final report.
5. Grade each Pass criterion individually: met / not met / not verifiable from the transcript, each with its evidence (a transcript quote, or an explicit "no evidence found").
6. Check each Forbidden behavior: if one occurred, quote the exact transcript passage where it happens. An occurred forbidden behavior means fail, even if the end result looks correct.
7. Grade the Learning check: which learned rule should have been used, and does the transcript show it was actually consulted and applied — not merely claimed.
8. Cross-check the self-report against the transcript: flag every claim with no supporting evidence (e.g. "tests passed" but no test command appears in the transcript). Any such mismatch fails the eval and gets an entry in `.agent-os/failure-log.md`.
9. If a Validation command should be re-run, use only `scripts/run-agent-evals.sh --adapter <dir> --check <eval-name> --exec` — the same command-map gate the executing model is bound by. Never run validation commands through any other path.
10. Record the verdict: `scripts/run-agent-evals.sh --adapter <dir> --record <eval-name> --result pass|fail --model <executing-model> --judge-model <judge-model> --judge-notes "<verdict summary>" --transcript <path>`. The script itself refuses to record a judged verdict with a missing/invalid `--transcript`, or when `--judge-model` equals `--model` — it enforces the transcript-mandatory and never-self-judge rules above, not just this procedure.

## Outputs

- A per-criterion verdict list (met / not met / not verifiable, each with evidence).
- Forbidden-behavior findings, each with a transcript quote — or an explicit "none found".
- A Learning check verdict (rule actually applied vs merely claimed).
- Mismatch flags between the self-report and the transcript.
- A Results row recorded with `--judge-notes` and `--transcript`.

## Forbidden

- Grading a run you executed yourself — the judge must never be the executing model.
- Grading without a transcript, or from the self-report alone; such results stay `unjudged`.
- Reporting a forbidden behavior — or clearing one — without quoting the transcript evidence.
- Accepting a self-reported claim that has no supporting evidence in the transcript.
- Running a validation command outside the `--check --exec` command-map gate.
- Softening a fail because the final artifact looks fine — process violations fail the eval.

## Done criteria

- Every Pass criterion, Forbidden behavior, and Learning check question has an explicit verdict with evidence.
- Self-report/transcript mismatches are flagged, and each mismatch is logged in `failure-log.md`.
- The Results row carries the judge model, judge notes, and the transcript path.
- Nothing was graded without a transcript.
