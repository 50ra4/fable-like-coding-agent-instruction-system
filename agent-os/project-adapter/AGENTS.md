<!--
Role: always-loaded entry point for this project. Starter-kit copy from
agent-os/project-adapter/AGENTS.md, filled in ({{PROJECT_NAME}} and links)
by the adapt-to-project skill. Kept short by improve-instructions if it
ever drifts or grows.
-->

# {{PROJECT_NAME}} — Agent Instructions

Global, project-agnostic principles live in `.agent-os/GLOBAL_AGENTS.md`,
installed alongside this project. Read it first; not repeated here.

## At the start of every task, read

1. `.agent-os/project-profile.md` — observed facts about this project.
2. `.agent-os/command-map.md` — the only commands you may run to verify work.
3. `.agent-os/risk-map.md` — areas needing explicit approval before touching.
4. `.agent-os/learned-rules.md` — honor every `Status: active` rule.
   `Status: candidate` rules are observations only, not yet binding.

## Safety (non-negotiable)

- No destructive operations (`rm -rf`, force-push, dropping data, migrations)
  without explicit user approval.
- Never read, print, or commit secrets (`.env`, keys, tokens, credentials).
- Only run commands listed in `.agent-os/command-map.md`. Never invent one.

## This file stays short

Procedures live in skills. Project facts and learning history live in
`.agent-os/`. Do not let this file grow into a manual.
