---
name: context-checkpoint
description: Compress the current working state of a long-running session into a cumulative handoff checkpoint in .agent-os/context-checkpoints.md so a later turn, session, or different agent can continue safely.
---

## Purpose

A prompt-level checkpoint/handoff protocol for long sessions. This skill does **not** delete or shrink the real conversation history — it produces an explicit handoff summary in `.agent-os/context-checkpoints.md` that subsequent work treats as the preferred reference. It complements platform-native compaction where one exists; it never claims to be one.

## When to use

- After long stretches of work, large tool output, a large diff, or a multi-file investigation.
- Before switching task phases.
- Before an intentional platform-native compact.
- When resuming work after suspected context loss.
- Not after every small step — checkpoint at safe, stable boundaries, never mid-edit or with failing/uncommitted state left unrecorded.

## Inputs

- The current session's working state.
- `.agent-os/context-checkpoints.md` (the existing checkpoint, if any).
- The user's latest instructions, constraints, and priorities.
- `.agent-os/learned-rules.md` and other adapter files — referenced by name, never copied in.

## Procedure

1. Assess context-budget risk (long session, big outputs, many files touched) and decide whether a checkpoint is warranted now.
2. Pick a safe boundary — a completed sub-task or stable state — not an arbitrary moment.
3. Capture the latest user instructions, constraints, prohibitions, and priorities first: these must never be lost, and newer instructions supersede older plans.
4. Separate confirmed facts (verified this session), assumptions/uncertainties, and known failures/unresolved issues into their own sections — never blend them.
5. Record files changed, important files inspected, commands actually run with their real results, and what was verified vs. not verified.
6. If a checkpoint already exists, merge into one cumulative handoff summary — never simply append a new block. Deduplicate, resolve contradictions in favor of the newest user intent, and mark superseded decisions as superseded with a one-line reason instead of silently deleting them.
7. Keep the checkpoint distinct from adapter state: reference `.agent-os/learned-rules.md` and other adapter files by name; do not copy their content in — a checkpoint is working state, not rules.
8. If the platform offers a native compact flow, use it only after the checkpoint is updated, and report honestly that the checkpoint itself did not shrink history.
9. If no native compact is available (or it cannot be triggered), treat `.agent-os/context-checkpoints.md` as the fallback: re-read it at the start of subsequent work and after any suspected context loss, and prefer it over older conversation memory.
10. End the checkpoint with the next smallest unit of work, so the next agent can start immediately.

**Checkpoint format** — a single cumulative `# Context Checkpoint` with these `##` sections, in order (the full template lives in `.agent-os/context-checkpoints.md`):

- Objective and latest user intent
- Active constraints and rules
- Confirmed facts
- Assumptions and uncertainties
- Work completed
- Files changed
- Important files inspected
- Commands run and results
- Known failures / unresolved issues
- Decisions made
- Remaining work
- Next recommended step
- Do not forget

## Outputs

- An updated `.agent-os/context-checkpoints.md` containing exactly one cumulative `# Context Checkpoint`.
- A stated next step.

## Forbidden

- Writing unverified information as confirmed facts.
- Recording a test as passed when it was not run.
- Hiding failures.
- Dropping or downgrading the latest user instruction.
- Treating candidate rules in `learned-rules.md` as active.
- Claiming conversation history was actually compacted or deleted when it was not.
- Assuming platform features that do not exist.
- Letting the checkpoint itself bloat by appending instead of merging.
- Copying project rules into the checkpoint, or checkpoint content into rules.

## Done criteria

- A next model/agent reading only the checkpoint understands the objective, constraints, current state, and next step.
- Latest user intent is preserved.
- Confirmed facts, assumptions, and unresolved issues are separated.
- Changed files and verification status are clear.
- Remaining work is explicit.
- The checkpoint stayed compact — one cumulative summary, not a growing log.
- Nothing project-specific leaked toward the Global Layer.
