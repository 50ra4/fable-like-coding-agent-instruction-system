#!/usr/bin/env bash
# bootstrap-project.sh
#
# Install the Adaptive Agent OS into a target project: copies the
# project-adapter skeleton (.agent-os/, CLAUDE.md/AGENTS.md), the
# per-assistant skills/agents, vendors the canonical skills library, and
# vendors the global principle files (GLOBAL_AGENTS.md / GLOBAL_CLAUDE.md).
#
# This script only ever writes files that belong to its own known
# manifest (never arbitrary user files) and never deletes anything
# (--reset-adapter moves files into a timestamped backup, it does not
# remove them).
#
# Ownership split:
#   - OS-owned (regenerable, --force overwrites them): .claude/skills/,
#     .claude/agents/, .codex/agents/, .agents/skills/, the vendored
#     .agent-os/skills/, and the vendored .agent-os/GLOBAL_AGENTS.md /
#     .agent-os/GLOBAL_CLAUDE.md.
#   - Protected (project-owned learning state, --force never overwrites
#     these): the 8 adapter state files under <target>/.agent-os/*.md
#     (project-profile, learned-rules, failure-log, review-feedback-log,
#     evals, command-map, architecture-map, risk-map) and the root entry
#     files <target>/CLAUDE.md and <target>/AGENTS.md. Use
#     --reset-adapter to explicitly replace them (with an automatic
#     backup first).
#
# .agent-os/rules/ (the optional split-rule layout) and .agent-os/backup-*/
# directories are never written to, read from, or deleted by this script.
set -euo pipefail

# Resolve paths relative to this script's location so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bootstrap-project.sh --target <dir> --for claude|codex|both [--force] [--reset-adapter]

Install the Agent OS into a target project directory.

Options:
  --target <dir>     Path to the project to install into (must already exist).
  --for <which>       Which assistant(s) to wire up: claude, codex, or both.
  --force             Overwrite OS-owned files that already exist (skills,
                      agents, vendored .agent-os/skills/, GLOBAL_*.md).
                      Never overwrites project-owned adapter state: the 8
                      .agent-os/*.md state files (project-profile,
                      learned-rules, failure-log, review-feedback-log,
                      evals, command-map, architecture-map, risk-map) and
                      the root CLAUDE.md/AGENTS.md entry files. Existing
                      protected files print a PROTECTED: line and are left
                      untouched.
  --reset-adapter     Explicitly reset project-owned adapter state: every
                      existing protected file (the 8 .agent-os/*.md state
                      files plus root CLAUDE.md/AGENTS.md) is moved into
                      .agent-os/backup-<timestamp>/ and fresh starter
                      copies are installed in their place. Does not imply
                      --force for OS-owned files.
  --help              Show this help text and exit.

Symlink safety: this script never writes through or replaces a symlinked
destination. If a destination path is itself a symlink, or a directory
component of it is a symlink that would redirect the write outside the
target directory, the write is refused and reported as a
"BLOCKED (symlink):" line (counted separately in the summary). Remove
the symlink manually if you want a regular file installed there.

Examples:
  bootstrap-project.sh --target ../my-app --for claude
  bootstrap-project.sh --target ../my-app --for both --force
  bootstrap-project.sh --target ../my-app --for both --reset-adapter
EOF
}

# ---- Argument parsing -------------------------------------------------
TARGET=""
FOR=""
FORCE=0
RESET_ADAPTER=0

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
    --reset-adapter)
      RESET_ADAPTER=1
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
# Physical (symlink-resolved) path of the target, used by copy_file()'s
# containment check to detect a symlinked intermediate directory that
# would otherwise silently redirect a write outside the target project.
TARGET_PHYS="$(cd "$TARGET_ABS" && pwd -P)"
# PROJECT_NAME escaped for safe use as a sed replacement string: a target
# directory basename containing &, /, or \ would otherwise break (or
# misbehave in) the {{PROJECT_NAME}} substitution in apply_project_name().
PROJECT_NAME_ESCAPED="$(printf '%s' "$PROJECT_NAME" | sed 's/[&/\]/\\&/g')"

# The 8 project-owned adapter state files (relative to <target>/.agent-os/,
# without the .md extension). Must match project-adapter/.agent-os/*.md and
# validate-agent-os.sh's ADAPTER_FILES list.
ADAPTER_STATE_FILES=(project-profile learned-rules failure-log review-feedback-log evals command-map architecture-map risk-map)

# ---- Bookkeeping -------------------------------------------------------
INSTALLED_COUNT=0
SKIPPED_COUNT=0
PROTECTED_COUNT=0
BACKED_UP_COUNT=0
BLOCKED_COUNT=0
INSTALLED_LIST=()
SKIPPED_LIST=()
PROTECTED_LIST=()
BACKED_UP_LIST=()
BLOCKED_LIST=()
BACKUP_DIR=""
LAST_ACTION=""

warn() { echo "WARN: $*"; }
info() { echo "INFO: $*"; }

# Copy a single file to a destination path, honoring --force / skip /
# protected rules. Sets LAST_ACTION to "installed", "skipped", "protected",
# or "blocked".
#
# protected=1 marks a file as project-owned adapter state: if it already
# exists and --force was passed, it is preserved (never overwritten) and a
# PROTECTED: line is printed instead. Without --force, or when the file
# does not yet exist, behavior is identical to protected=0.
#
# Symlink safety (checked FIRST, before protected/exists logic, so a
# symlinked protected file is reported as BLOCKED rather than silently
# PROTECTED): if $dest already exists and is itself a symlink, this
# script refuses to write through or replace it -- plain `cp` would
# follow the link and overwrite whatever it points at, possibly outside
# the target project. It also refuses if a directory component of $dest
# is a symlink that resolves outside the target project (a symlinked
# parent directory silently redirecting the write).
copy_file() {
  local src="$1"
  local dest="$2"
  local protected="${3:-0}"

  if [[ ! -f "$src" ]]; then
    warn "source file missing, skipping: $src"
    LAST_ACTION="skipped"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SKIPPED_LIST+=("$dest (source missing)")
    return
  fi

  if [[ -L "$dest" ]]; then
    echo "BLOCKED (symlink): destination is a symlink; refusing to write through or replace it: $dest (remove the symlink manually if you want a regular file installed here)"
    LAST_ACTION="blocked"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    BLOCKED_LIST+=("$dest (destination is a symlink)")
    return
  fi

  if [[ -e "$dest" ]]; then
    if [[ "$protected" -eq 1 && "$FORCE" -eq 1 ]]; then
      echo "PROTECTED: preserving project-owned state, not overwritten by --force: $dest (run with --reset-adapter to replace it; a backup is made automatically)"
      LAST_ACTION="protected"
      PROTECTED_COUNT=$((PROTECTED_COUNT + 1))
      PROTECTED_LIST+=("$dest")
      return
    fi
    if [[ "$FORCE" -ne 1 ]]; then
      warn "already exists, skipping (use --force to overwrite): $dest"
      LAST_ACTION="skipped"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      SKIPPED_LIST+=("$dest")
      return
    fi
    # protected=0 and --force was passed: fall through and overwrite.
  fi

  mkdir -p "$(dirname "$dest")"

  # Physical containment check: resolve the destination's parent directory
  # and require it to be the target directory or a descendant of it. This
  # catches a symlinked intermediate directory (e.g. .claude/agents ->
  # /somewhere/else) that the -L check on $dest alone would miss, since
  # $dest itself may not exist yet even though a parent component does.
  local phys_parent
  phys_parent="$(cd "$(dirname "$dest")" && pwd -P)"
  if [[ "$phys_parent" != "$TARGET_PHYS" && "$phys_parent" != "$TARGET_PHYS"/* ]]; then
    echo "BLOCKED (symlink): a symlinked parent directory redirected this write outside the target project: $dest (resolved parent: $phys_parent); refusing to write. Remove the symlink manually if you want a regular directory here."
    LAST_ACTION="blocked"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    BLOCKED_LIST+=("$dest (symlinked parent directory escapes target)")
    return
  fi

  cp "$src" "$dest"
  LAST_ACTION="installed"
  INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
  INSTALLED_LIST+=("$dest")
}

# Recursively copy all files under a source directory into a destination
# directory, preserving relative structure, file by file (so per-file
# skip/force/protected rules apply even inside vendored skill directories).
copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"
  local protected="${3:-0}"

  if [[ ! -d "$src_dir" ]]; then
    warn "source directory missing, skipping: $src_dir"
    return
  fi

  local rel
  while IFS= read -r file; do
    rel="${file#"$src_dir"/}"
    copy_file "$file" "$dest_dir/$rel" "$protected"
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
# on arbitrary user files. Uses PROJECT_NAME_ESCAPED (computed once above)
# rather than PROJECT_NAME directly, so a target directory basename
# containing sed-special characters (&, /, \) is substituted literally
# instead of corrupting or breaking the substitution.
apply_project_name() {
  local file="$1"
  # Defense in depth: copy_file() already refuses to write through a
  # symlinked destination, so this should never see one; guard anyway.
  [[ -L "$file" ]] && return
  [[ -f "$file" ]] || return
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME_ESCAPED/g" "$file"
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

# ---- --reset-adapter: back up existing protected files, then let the ----
# ---- normal install steps below install fresh copies in their place. ----
reset_adapter() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="$TARGET_ABS/.agent-os/backup-$ts"
  local any=0
  local f src was_symlink note

  # Note: if a protected file is itself a symlink, `mv` moves the link
  # entry itself (it does not follow it and does not write through it),
  # so this is safe. The backup list simply calls out that it was a
  # symlink so the summary is honest about what got backed up.
  for f in "${ADAPTER_STATE_FILES[@]}"; do
    src="$TARGET_ABS/.agent-os/$f.md"
    if [[ -f "$src" || -L "$src" ]]; then
      was_symlink=0
      [[ -L "$src" ]] && was_symlink=1
      mkdir -p "$backup_dir"
      mv "$src" "$backup_dir/$f.md"
      any=1
      BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
      note="was .agent-os/$f.md"
      [[ "$was_symlink" -eq 1 ]] && note="was .agent-os/$f.md, a symlink -- the link itself was moved, not its target"
      BACKED_UP_LIST+=("$backup_dir/$f.md ($note)")
    fi
  done

  for f in CLAUDE.md AGENTS.md; do
    src="$TARGET_ABS/$f"
    if [[ -f "$src" || -L "$src" ]]; then
      was_symlink=0
      [[ -L "$src" ]] && was_symlink=1
      mkdir -p "$backup_dir"
      mv "$src" "$backup_dir/$f"
      any=1
      BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
      note="was $f"
      [[ "$was_symlink" -eq 1 ]] && note="was $f, a symlink -- the link itself was moved, not its target"
      BACKED_UP_LIST+=("$backup_dir/$f ($note)")
    fi
  done

  if [[ "$any" -eq 1 ]]; then
    BACKUP_DIR="$backup_dir"
    info "reset-adapter: backed up existing protected file(s) to $backup_dir"
  else
    info "reset-adapter: no existing protected files found, nothing to back up"
  fi
}

if [[ "$RESET_ADAPTER" -eq 1 ]]; then
  reset_adapter
fi

# ---- 1. Core project-adapter .agent-os/ files (protected state) ------
copy_dir_contents "$AGENT_OS_ROOT/project-adapter/.agent-os" "$TARGET_ABS/.agent-os" 1

# ---- 1b. Global principle files (OS-owned, always vendored) ----------
copy_file "$AGENT_OS_ROOT/GLOBAL_AGENTS.md" "$TARGET_ABS/.agent-os/GLOBAL_AGENTS.md"

# ---- 2. Claude wiring ---------------------------------------------------
if [[ "$FOR" == "claude" || "$FOR" == "both" ]]; then
  copy_file "$AGENT_OS_ROOT/project-adapter/CLAUDE.md" "$TARGET_ABS/CLAUDE.md" 1
  [[ "$LAST_ACTION" == "installed" ]] && apply_project_name "$TARGET_ABS/CLAUDE.md"

  copy_file "$AGENT_OS_ROOT/GLOBAL_CLAUDE.md" "$TARGET_ABS/.agent-os/GLOBAL_CLAUDE.md"

  copy_dir_contents "$AGENT_OS_ROOT/claude/skills" "$TARGET_ABS/.claude/skills"
  copy_flat_glob "$AGENT_OS_ROOT/claude/agents" "$TARGET_ABS/.claude/agents" "*.md"

  vendor_canonical_skills
fi

# ---- 3. Codex wiring ----------------------------------------------------
if [[ "$FOR" == "codex" || "$FOR" == "both" ]]; then
  copy_file "$AGENT_OS_ROOT/project-adapter/AGENTS.md" "$TARGET_ABS/AGENTS.md" 1
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
echo "Protected: $PROTECTED_COUNT file(s) (project-owned state, preserved despite --force)"
for f in "${PROTECTED_LIST[@]:-}"; do
  [[ -n "$f" ]] && echo "  ! $f"
done
echo "Blocked:   $BLOCKED_COUNT file(s) (refused: symlinked destination or symlinked parent directory)"
for f in "${BLOCKED_LIST[@]:-}"; do
  [[ -n "$f" ]] && echo "  x $f"
done
if [[ "$RESET_ADAPTER" -eq 1 ]]; then
  echo "Backed up: $BACKED_UP_COUNT file(s)$( [[ -n "$BACKUP_DIR" ]] && echo " -> $BACKUP_DIR" )"
  for f in "${BACKED_UP_LIST[@]:-}"; do
    [[ -n "$f" ]] && echo "  ~ $f"
  done
fi
echo
if [[ "$BLOCKED_COUNT" -gt 0 ]]; then
  echo "Next step: review BLOCKED (symlink) lines above; remove the offending symlink(s) manually, then rerun."
elif [[ "$PROTECTED_COUNT" -gt 0 ]]; then
  echo "Next step: review PROTECTED: lines above; run with --reset-adapter (backs up first) if you really want to replace them."
else
  echo "Next step: run the project-bootstrap skill before changing any code."
fi
echo "======================================"

exit 0
