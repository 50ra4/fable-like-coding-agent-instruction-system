<!--
Role: always-loaded entry point for this project in Claude Code. Starter-kit
copy from agent-os/project-adapter/CLAUDE.md, filled in ({{PROJECT_NAME}}
and links) by the adapt-to-project skill. Kept short by improve-instructions
if it ever drifts or grows.
-->

# {{PROJECT_NAME}} — Claude Code Instructions

Global, project-agnostic principles live in `.agent-os/GLOBAL_AGENTS.md` /
`.agent-os/GLOBAL_CLAUDE.md`, installed alongside this project. Read them
first; not repeated here.

## Where things live

- **This file** — short, always-loaded pointers only.
- **`.claude/skills/*/SKILL.md`** — on-demand procedures, if installed.
- **`.claude/agents/*.md`** — specialized subagents, if installed.
- **`.agent-os/`** — this project's observed facts and learned rules.

## At the start of every task, read

1. `.agent-os/project-profile.md`, `.agent-os/command-map.md`,
   `.agent-os/risk-map.md`.
2. `.agent-os/learned-rules.md` — honor every `Status: active` rule.
   `Status: candidate` rules are observations only, not yet binding.

## Safety (non-negotiable)

- No destructive operations (`rm -rf`, force-push, dropping data, migrations)
  without explicit user approval.
- Never read, print, or commit secrets (`.env`, keys, tokens, credentials).
- Only run commands listed in `.agent-os/command-map.md`. Never invent one.

## This file stays short

Procedures live in skills; project facts and learning history live in
`.agent-os/`. Do not let this file grow into a manual.
