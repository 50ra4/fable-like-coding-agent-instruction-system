#!/usr/bin/env bash
# bootstrap-project.sh
#
# Install the Adaptive Agent OS into a target project: copies the
# project-adapter skeleton (.agent-os/, CLAUDE.md/AGENTS.md), the
# per-assistant skills/agents, and vendors the canonical skills library.
#
# This script only ever writes files that belong to its own known
# manifest (never arbitrary user files) and never deletes anything.
set -euo pipefail

# Resolve paths relative to this script's location so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bootstrap-project.sh --target <dir> --for claude|codex|both [--force]

Install the Agent OS into a target project directory.

Options:
  --target <dir>   Path to the project to install into (must already exist).
  --for <which>     Which assistant(s) to wire up: claude, codex, or both.
  --force           Overwrite files that already exist (only files this
                    script owns/copies are ever touched).
  --help            Show this help text and exit.

Examples:
  bootstrap-project.sh --target ../my-app --for claude
  bootstrap-project.sh --target ../my-app --for both --force
EOF
}

# ---- Argument parsing -------------------------------------------------
TARGET=""
FOR=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --target)
      [[ $# -ge 2 ]] || { echo "ERROR: --target requires a value" >&2; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    --for)
      [[ $# -ge 2 ]] || { echo "ERROR: --for requires a value" >&2; exit 2; }
      FOR="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$TARGET" || -z "$FOR" ]]; then
  echo "ERROR: --target and --for are required" >&2
  usage >&2
  exit 2
fi

case "$FOR" in
  claude|codex|both) ;;
  *)
    echo "ERROR: --for must be one of: claude, codex, both (got: $FOR)" >&2
    exit 2
    ;;
esac

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: target directory does not exist: $TARGET" >&2
  exit 1
fi

TARGET_ABS="$(cd "$TARGET" && pwd)"
PROJECT_NAME="$(basename "$TARGET_ABS")"

# ---- Bookkeeping -------------------------------------------------------
INSTALLED_COUNT=0
SKIPPED_COUNT=0
INSTALLED_LIST=()
SKIPPED_LIST=()
LAST_ACTION=""

warn() { echo "WARN: $*"; }
info() { echo "INFO: $*"; }

# Copy a single file to a destination path, honoring --force / skip rules.
# Sets LAST_ACTION to "installed" or "skipped".
copy_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    warn "source file missing, skipping: $src"
    LAST_ACTION="skipped"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SKIPPED_LIST+=("$dest (source missing)")
    return
  fi

  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    warn "already exists, skipping (use --force to overwrite): $dest"
    LAST_ACTION="skipped"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SKIPPED_LIST+=("$dest")
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  LAST_ACTION="installed"
  INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
  INSTALLED_LIST+=("$dest")
}

# Recursively copy all files under a source directory into a destination
# directory, preserving relative structure, file by file (so per-file
# skip/force rules apply even inside vendored skill directories).
copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"

  if [[ ! -d "$src_dir" ]]; then
    warn "source directory missing, skipping: $src_dir"
    return
  fi

  local rel
  while IFS= read -r file; do
    rel="${file#"$src_dir"/}"
    copy_file "$file" "$dest_dir/$rel"
  done < <(find "$src_dir" -type f | sort)
}

# Copy top-level files matching a glob from a source dir into a dest dir
# (non-recursive; used for claude/agents/*.md and codex/agents/*.toml).
copy_flat_glob() {
  local src_dir="$1"
  local dest_dir="$2"
  local pattern="$3"

  if [[ ! -d "$src_dir" ]]; then
    warn "source directory missing, skipping: $src_dir"
    return
  fi

  shopt -s nullglob
  local matched=0
  local f
  for f in "$src_dir"/$pattern; do
    matched=1
    copy_file "$f" "$dest_dir/$(basename "$f")"
  done
  shopt -u nullglob

  if [[ "$matched" -eq 0 ]]; then
    info "no files matching '$pattern' in $src_dir yet, nothing to copy"
  fi
}

# Replace the {{PROJECT_NAME}} placeholder in a copied file, in place.
# Only ever run on files this script just installed (the copies), never
# on arbitrary user files.
apply_project_name() {
  local file="$1"
  [[ -f "$file" ]] || return
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file"
  rm -f "$file.bak"
}

VENDORED=0
vendor_canonical_skills() {
  [[ "$VENDORED" -eq 1 ]] && return
  VENDORED=1

  local vendor_dir="$TARGET_ABS/.agent-os/skills"
  if [[ -d "$vendor_dir" ]] && [[ -n "$(find "$vendor_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]] && [[ "$FORCE" -ne 1 ]]; then
    warn "canonical skills already vendored, skipping (use --force to refresh): $vendor_dir"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SKIPPED_LIST+=("$vendor_dir (already vendored)")
    return
  fi

  copy_dir_contents "$AGENT_OS_ROOT/skills" "$vendor_dir"
}

# ---- 1. Core project-adapter .agent-os/ files (always installed) -----
copy_dir_contents "$AGENT_OS_ROOT/project-adapter/.agent-os" "$TARGET_ABS/.agent-os"

# ---- 2. Claude wiring ---------------------------------------------------
if [[ "$FOR" == "claude" || "$FOR" == "both" ]]; then
  copy_file "$AGENT_OS_ROOT/project-adapter/CLAUDE.md" "$TARGET_ABS/CLAUDE.md"
  [[ "$LAST_ACTION" == "installed" ]] && apply_project_name "$TARGET_ABS/CLAUDE.md"

  copy_dir_contents "$AGENT_OS_ROOT/claude/skills" "$TARGET_ABS/.claude/skills"
  copy_flat_glob "$AGENT_OS_ROOT/claude/agents" "$TARGET_ABS/.claude/agents" "*.md"

  vendor_canonical_skills
fi

# ---- 3. Codex wiring ----------------------------------------------------
if [[ "$FOR" == "codex" || "$FOR" == "both" ]]; then
  copy_file "$AGENT_OS_ROOT/project-adapter/AGENTS.md" "$TARGET_ABS/AGENTS.md"
  [[ "$LAST_ACTION" == "installed" ]] && apply_project_name "$TARGET_ABS/AGENTS.md"

  copy_dir_contents "$AGENT_OS_ROOT/codex/skills" "$TARGET_ABS/.agents/skills"
  copy_flat_glob "$AGENT_OS_ROOT/codex/agents" "$TARGET_ABS/.codex/agents" "*.toml"

  vendor_canonical_skills
fi

# ---- Summary --------------------------------------------------------
echo
echo "===== bootstrap-project summary ====="
echo "Target:   $TARGET_ABS"
echo "For:      $FOR"
echo "Installed: $INSTALLED_COUNT file(s)"
for f in "${INSTALLED_LIST[@]:-}"; do
  [[ -n "$f" ]] && echo "  + $f"
done
echo "Skipped:   $SKIPPED_COUNT file(s)"
for f in "${SKIPPED_LIST[@]:-}"; do
  [[ -n "$f" ]] && echo "  - $f"
done
echo
echo "Next step: run the project-bootstrap skill before changing any code."
echo "======================================"

exit 0
