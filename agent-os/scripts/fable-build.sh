#!/usr/bin/env bash
# fable-build.sh
#
# Mechanical helper for the fable-build protocol (skills/fable-build/SKILL.md).
# This script performs NO semantic judgment of any kind: no content
# similarity, no heuristics about meaning, no equivalence scoring. It only
# enumerates files, prints diffs, and validates file formats. Deciding
# whether a regenerated wrapper is semantically equivalent to its canonical
# skill is explicitly the builder model's job per skills/fable-build/SKILL.md
# and is out of scope here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: fable-build.sh (--list | --diff <build-dir> | --check | --help)

Mechanical helper for the fable-build protocol. Enumerates canonical
skills and their platform wrappers, presents diffs between a candidate
build directory and the repo, and validates file formats. Contains no
semantic-parity judgment (see skills/fable-build/SKILL.md).

Modes (exactly one required):
  --list              Enumerate canonical skills and their claude/codex
                       wrappers (OK/MISSING), detect orphan wrappers, and
                       report claude/codex agent-definition pairs.
  --diff <build-dir>   Compare a candidate build directory (mirroring the
                       agent-os/ layout) against the repo. Read-only;
                       never writes or applies anything. Prints
                       IDENTICAL/CHANGED/NEW per file plus unified diffs.
  --check             Validate SKILL.md frontmatter, codex agent TOML
                       keys, wrapper line-count and pointer guards, then
                       run validate-agent-os.sh.
  --help              Show this help text and exit.

Exit codes:
  0   success (for --diff, this includes the case where diffs exist)
  1   failures found (--list, --check)
  2   usage error
EOF
}

MODE=""
BUILD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      [[ -z "$MODE" ]] || { echo "ERROR: only one mode may be given" >&2; usage >&2; exit 2; }
      MODE="list"
      shift
      ;;
    --diff)
      [[ -z "$MODE" ]] || { echo "ERROR: only one mode may be given" >&2; usage >&2; exit 2; }
      [[ $# -ge 2 ]] || { echo "ERROR: --diff requires a <build-dir>" >&2; exit 2; }
      MODE="diff"
      BUILD_DIR="$2"
      shift 2
      ;;
    --check)
      [[ -z "$MODE" ]] || { echo "ERROR: only one mode may be given" >&2; usage >&2; exit 2; }
      MODE="check"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: exactly one mode is required" >&2
  usage >&2
  exit 2
fi

# ---- Counters -------------------------------------------------------------
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); echo "WARN: $*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $*"; }

# =============================================================================
# --list
# =============================================================================
run_list() {
  echo "===== fable-build --list: canonical skills and wrappers ====="

  local canonical_names=()
  local d name
  for d in "$AGENT_OS_ROOT"/skills/*/; do
    [[ -f "${d}SKILL.md" ]] || continue
    name="$(basename "$d")"
    canonical_names+=("$name")

    local claude_status="OK" codex_status="OK"
    if [[ -f "$AGENT_OS_ROOT/claude/skills/$name/SKILL.md" ]]; then
      pass
    else
      claude_status="MISSING"
      fail "claude wrapper missing for skill '$name': claude/skills/$name/SKILL.md"
    fi
    if [[ -f "$AGENT_OS_ROOT/codex/skills/$name/SKILL.md" ]]; then
      pass
    else
      codex_status="MISSING"
      fail "codex wrapper missing for skill '$name': codex/skills/$name/SKILL.md"
    fi
    echo "SKILL $name: canonical=skills/$name/SKILL.md claude=$claude_status codex=$codex_status"
  done

  echo "--- orphan wrapper detection ---"
  local platform base found
  for platform in claude codex; do
    [[ -d "$AGENT_OS_ROOT/$platform/skills" ]] || continue
    for d in "$AGENT_OS_ROOT/$platform/skills"/*/; do
      [[ -d "$d" ]] || continue
      base="$(basename "$d")"
      found=0
      for name in "${canonical_names[@]}"; do
        [[ "$name" == "$base" ]] && found=1 && break
      done
      if [[ "$found" -eq 0 ]]; then
        fail "orphan wrapper (no canonical skills/$base): $platform/skills/$base"
      else
        pass
      fi
    done
  done

  echo "--- agent definition pairs (claude/agents/*.md <-> codex/agents/*.toml) ---"
  local a base_name
  if [[ -d "$AGENT_OS_ROOT/claude/agents" ]]; then
    for a in "$AGENT_OS_ROOT/claude/agents"/*.md; do
      [[ -f "$a" ]] || continue
      base_name="$(basename "$a" .md)"
      if [[ -f "$AGENT_OS_ROOT/codex/agents/$base_name.toml" ]]; then
        echo "AGENT $base_name: claude=OK codex=OK"
        pass
      else
        echo "AGENT $base_name: claude=OK codex=MISSING"
        fail "codex agent definition missing: codex/agents/$base_name.toml"
      fi
    done
  fi
  if [[ -d "$AGENT_OS_ROOT/codex/agents" ]]; then
    for a in "$AGENT_OS_ROOT/codex/agents"/*.toml; do
      [[ -f "$a" ]] || continue
      base_name="$(basename "$a" .toml)"
      if [[ ! -f "$AGENT_OS_ROOT/claude/agents/$base_name.md" ]]; then
        echo "AGENT $base_name: claude=MISSING codex=OK"
        fail "claude agent definition missing: claude/agents/$base_name.md"
      fi
    done
  fi

  echo
  echo "===== fable-build --list summary ====="
  echo "PASS: $PASS_COUNT   WARN: $WARN_COUNT   FAIL: $FAIL_COUNT"
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "RESULT: FAIL"
    exit 1
  fi
  echo "RESULT: PASS"
  exit 0
}

# =============================================================================
# --diff <build-dir>
# =============================================================================
run_diff() {
  if [[ ! -d "$BUILD_DIR" ]]; then
    echo "ERROR: build dir does not exist or is not a directory: $BUILD_DIR" >&2
    exit 2
  fi
  BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

  echo "===== fable-build --diff: $BUILD_DIR vs $AGENT_OS_ROOT ====="

  local identical=0 changed=0 new=0
  local candidate relpath repo_file

  while IFS= read -r candidate; do
    relpath="${candidate#"$BUILD_DIR"/}"
    repo_file="$AGENT_OS_ROOT/$relpath"
    if [[ ! -f "$repo_file" ]]; then
      echo "NEW: $relpath"
      diff -u /dev/null "$candidate" || true
      new=$((new + 1))
    elif diff -q "$repo_file" "$candidate" >/dev/null 2>&1; then
      echo "IDENTICAL: $relpath"
      identical=$((identical + 1))
    else
      echo "CHANGED: $relpath"
      diff -u "$repo_file" "$candidate" || true
      changed=$((changed + 1))
    fi
  done < <(find "$BUILD_DIR" -type f | sort)

  echo
  echo "===== fable-build --diff summary ====="
  echo "IDENTICAL: $identical   CHANGED: $changed   NEW: $new"
  echo "RESULT: read-only diff complete (no files were written)"
  exit 0
}

# =============================================================================
# --check
# =============================================================================
check_skill_md() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    fail "missing SKILL.md: $f"
    return
  fi
  local first_line
  first_line="$(sed -n '1p' "$f")"
  first_line="${first_line%$'\r'}"
  if [[ "$first_line" != "---" ]]; then
    fail "SKILL.md frontmatter must start with '---' on line 1: $f"
    return
  fi
  local block
  block="$(awk 'NR==1{next} /^---\r?$/{exit} {print}' "$f")"
  local ok=1
  if ! grep -q '^name:' <<<"$block"; then
    fail "SKILL.md frontmatter missing 'name:' key: $f"
    ok=0
  fi
  if ! grep -q '^description:' <<<"$block"; then
    fail "SKILL.md frontmatter missing 'description:' key: $f"
    ok=0
  fi
  [[ "$ok" -eq 1 ]] && pass
}

check_codex_toml() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    fail "missing codex agent TOML: $f"
    return
  fi
  local ok=1
  grep -qE '^[[:space:]]*name[[:space:]]*=' "$f" || { fail "TOML missing 'name' key: $f"; ok=0; }
  grep -qE '^[[:space:]]*description[[:space:]]*=' "$f" || { fail "TOML missing 'description' key: $f"; ok=0; }
  grep -qE '^[[:space:]]*developer_instructions[[:space:]]*=' "$f" || { fail "TOML missing 'developer_instructions' key: $f"; ok=0; }
  [[ "$ok" -eq 1 ]] && pass
}

run_check() {
  echo "===== fable-build --check: $AGENT_OS_ROOT ====="

  echo "--- SKILL.md frontmatter (canonical + wrappers) ---"
  local d name
  for d in "$AGENT_OS_ROOT"/skills/*/; do
    [[ -f "${d}SKILL.md" ]] || continue
    check_skill_md "${d}SKILL.md"
  done
  local platform
  for platform in claude codex; do
    [[ -d "$AGENT_OS_ROOT/$platform/skills" ]] || continue
    for d in "$AGENT_OS_ROOT/$platform/skills"/*/; do
      [[ -f "${d}SKILL.md" ]] || continue
      check_skill_md "${d}SKILL.md"
    done
  done

  echo "--- codex agent TOML keys ---"
  local t
  if [[ -d "$AGENT_OS_ROOT/codex/agents" ]]; then
    for t in "$AGENT_OS_ROOT/codex/agents"/*.toml; do
      [[ -f "$t" ]] || continue
      check_codex_toml "$t"
    done
  fi

  echo "--- wrapper line-count and pointer guards ---"
  for d in "$AGENT_OS_ROOT"/skills/*/; do
    [[ -f "${d}SKILL.md" ]] || continue
    name="$(basename "$d")"
    local canon_lines
    canon_lines="$(awk 'END{print NR}' "${d}SKILL.md")"
    for platform in claude codex; do
      local wrapper="$AGENT_OS_ROOT/$platform/skills/$name/SKILL.md"
      [[ -f "$wrapper" ]] || continue
      local wrap_lines
      wrap_lines="$(awk 'END{print NR}' "$wrapper")"
      if [[ "$wrap_lines" -lt "$canon_lines" ]]; then
        pass
      else
        fail "wrapper not shorter than canonical ($wrap_lines >= $canon_lines lines): $platform/skills/$name/SKILL.md"
      fi
      if grep -q "skills/$name/SKILL.md" "$wrapper"; then
        pass
      else
        fail "wrapper missing pointer back to canonical (expected 'skills/$name/SKILL.md' in content): $platform/skills/$name/SKILL.md"
      fi
    done
  done

  echo
  echo "===== fable-build --check summary (own checks) ====="
  echo "PASS: $PASS_COUNT   WARN: $WARN_COUNT   FAIL: $FAIL_COUNT"

  echo
  echo "--- running validate-agent-os.sh ---"
  local validate_exit=0
  bash "$SCRIPT_DIR/validate-agent-os.sh" || validate_exit=$?

  echo
  echo "===== fable-build --check overall result ====="
  if [[ "$FAIL_COUNT" -gt 0 || "$validate_exit" -ne 0 ]]; then
    echo "RESULT: FAIL (own FAIL=$FAIL_COUNT, validate-agent-os.sh exit=$validate_exit)"
    exit 1
  fi
  echo "RESULT: PASS"
  exit 0
}

case "$MODE" in
  list) run_list ;;
  diff) run_diff ;;
  check) run_check ;;
esac
