---
name: judge-agent-eval
description: Grade an executed eval as an independent judge from its run transcript — verify pass criteria, detect forbidden behavior, and flag self-report mismatches.
---

Canonical procedure: `.agent-os/skills/judge-agent-eval/SKILL.md` (inside the
Agent OS repository itself, the canonical source is
`agent-os/skills/judge-agent-eval/SKILL.md`). Read it before running this
workflow — this file is a compact Codex-facing pointer, not a replacement.

## Summary

1. Refuse to grade without the run transcript
   (`.agent-os/eval-transcripts/<eval-name-slug>-<YYYY-MM-DD>.md`); no
   transcript means the result stays `unjudged` — never grade from the
   self-report alone.
2. Confirm you are not the executing model (compare the transcript's
   `Model:` line to your own identity); if they match, hand off to a
   different, stronger model.
3. Pull Pass criteria, Forbidden behavior, and Learning check via
   `--show <name>`, then read the full transcript before grading.
4. Grade each Pass criterion with transcript-quoted evidence, and check
   each Forbidden behavior — one occurring fails the eval regardless of
   the final result.
5. Grade the Learning check and flag any self-report claim lacking
   transcript evidence, logging mismatches to `.agent-os/failure-log.md`.
6. Re-run a Validation command only through `--check <name> --exec`, the
   same command-map gate the executing model is bound by.
7. Record the verdict with `--record <name> --result pass|fail --model
   <executing-model> --judge-model <judge-model> --judge-notes "<summary>"
   --transcript <path>`. The script itself refuses a missing/invalid
   transcript or a judge model equal to the executing model.

## Codex-specific notes

- Do not improvise a substitute validation path — the `--check --exec`
  command-map gate is the only way to re-run anything.

## Forbidden

- Grading a run you executed yourself.
- Grading without a transcript, or from the self-report alone.
- Reporting or clearing a forbidden behavior without a transcript quote.
- Accepting an unsupported self-reported claim.
- Running validation commands outside the `--check --exec` gate.
