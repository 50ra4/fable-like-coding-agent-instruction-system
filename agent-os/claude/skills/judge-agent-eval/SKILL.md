---
name: judge-agent-eval
description: Grade an executed eval as an independent judge — read the run transcript, verify pass criteria, detect forbidden behavior, and flag mismatches with the executing model's self-report.
---

The canonical procedure lives in `.agent-os/skills/judge-agent-eval/SKILL.md` (inside the Agent OS repository itself, the canonical source is `agent-os/skills/judge-agent-eval/SKILL.md`). Follow that file's steps in full instead of this summary. What follows is a standalone-usable condensation.

## Procedure summary

1. Refuse to grade without a run transcript (`.agent-os/eval-transcripts/<eval-name-slug>-<YYYY-MM-DD>.md`) — a result with no transcript stays `unjudged`, and self-report alone is never a substitute.
2. Confirm you are not the executing model (check the transcript's `Model:` line against your own identity); if they match, or you performed the run this session, hand off to a different, stronger model.
3. Use `--show <eval-name>` to pull Pass criteria, Forbidden behavior, and Learning check as your checklist, then read the transcript end to end.
4. Grade each Pass criterion (met / not met / not verifiable) with a transcript quote as evidence, and check each Forbidden behavior — one occurring is a fail even if the end result looks fine.
5. Grade the Learning check (rule actually applied vs merely claimed), and flag any self-report claim with no supporting transcript evidence — log mismatches to `.agent-os/failure-log.md`.
6. Re-run a Validation command only via `--check <name> --exec`, the same command-map gate the executing model is bound by — never any other path.
7. Record the verdict with `--record <name> --result pass|fail --model <executing-model> --judge-notes "<judge-model>: <verdict summary>" --transcript <path>`, always naming the judge model.

## Forbidden

- Grading a run you executed yourself.
- Grading without a transcript, or from the self-report alone.
- Reporting or clearing a forbidden behavior without a transcript quote.
- Accepting an unsupported self-reported claim.
- Running validation commands outside the `--check --exec` gate.
- Softening a fail because the final artifact looks fine.

## Claude-specific notes

- Quote transcript passages verbatim in your verdict — do not paraphrase evidence.
