---
name: generate-agent-files
description: Generate the real per-platform agent files (Claude and Codex) from the Global Agent OS plus the project adapter, keeping both platforms in sync in meaning.
---

## Purpose

Materialize the layered design — Global Agent OS + project adapter — into the concrete files each platform actually reads at runtime, without letting the platforms drift apart or leaking project rules into the global layer.

## When to use

- After `adapt-to-project` has produced or updated the project adapter.
- When a new platform target is added to a project (e.g. Codex support added to a Claude-only project).
- When Global OS skills change and platform wrappers need regenerating to match.

## Inputs

- `GLOBAL_AGENTS.md` and `skills/*/SKILL.md` (canonical, read-only source of truth).
- The project adapter: `.agent-os/project-profile.md`, `.agent-os/learned-rules.md`, `AGENTS.md`, `CLAUDE.md`.
- Existing platform-specific files, if regenerating: `.claude/skills/*`, `.claude/agents/*.md`, `.agents/skills/*`, `.codex/agents/*.toml`.

## Procedure

1. Read the canonical `skills/*/SKILL.md` files — these are the single source of procedural truth. Never author new procedure content directly inside a platform wrapper.
2. Read the project adapter for project-specific facts, commands, and active rules.
3. Generate/update Claude targets:
   - `CLAUDE.md` — short, always-loaded, points to skills and `.agent-os/`.
   - `.claude/skills/*/SKILL.md` — thin wrappers that reference or restate the canonical skill for Claude's skill-invocation format.
   - `.claude/agents/*.md` — agent definitions split by specialty (e.g. bug-fix agent, review agent), each pointing at the relevant skills.
4. Generate/update Codex targets:
   - `AGENTS.md` — short, always-loaded, points to skills and `.agent-os/`.
   - `.agents/skills/*/SKILL.md` — thin wrappers equivalent in meaning to the Claude wrappers.
   - `.codex/agents/*.toml` — agent definitions equivalent in meaning to the Claude agent definitions.
5. Regenerate the common layer if stale: `.agent-os/project-profile.md`, `.agent-os/learned-rules.md`, `.agent-os/evals.md`, `.agent-os/failure-log.md`.
6. Diff Claude and Codex outputs side by side for the same source skill/rule — confirm they say the same thing in each platform's native format. A wording difference is fine; a behavioral or rule difference is not.
7. Confirm no project-specific fact or rule was written into `GLOBAL_AGENTS.md` or the canonical `skills/` — those stay project-agnostic.
8. Confirm always-loaded files (`CLAUDE.md`, `AGENTS.md`) stayed short; anything long got pushed into a skill file instead.
9. Confirm agents are split by specialty rather than one monolithic agent trying to do everything.
10. Report which files were generated/updated per platform.

## Outputs

- Claude: `CLAUDE.md`, `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`.
- Codex: `AGENTS.md`, `.agents/skills/*/SKILL.md`, `.codex/agents/*.toml`.
- Common: `.agent-os/project-profile.md`, `.agent-os/learned-rules.md`, `.agent-os/evals.md`, `.agent-os/failure-log.md`.

## Forbidden

- Letting Claude and Codex outputs diverge in meaning (different rules, different risk areas, different commands).
- Writing long, always-loaded instructions instead of pointing to a skill.
- Leaking project-specific rules or facts into `GLOBAL_AGENTS.md` or canonical `skills/`.
- Designing any file to be "re-read as a giant prompt every run" instead of structured, skill-based loading.
- Duplicating the same procedure text in more than one platform's skill file instead of both pointing to the same canonical content.

## Done criteria

- Both platforms' always-loaded files are short and structurally equivalent.
- A behavior described for Claude has a matching behavior described for Codex.
- No canonical Global OS file contains project-specific content.
- Agents/skills are organized by specialty, not as one do-everything file.
