#!/usr/bin/env bash
# split-learned-rules.sh
#
# Move Status: active rule blocks out of a project's
# .agent-os/learned-rules.md into per-scope files under
# .agent-os/rules/<scope>.md (global|project|directory|file-pattern),
# based on each rule's Scope: field. learned-rules.md stays the
# entrypoint: promotion-criteria header + candidate/deprecated rules +
# an "## Active rules index" section pointing at the moved rules.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: split-learned-rules.sh --adapter <dir> [--dry-run]

Move Status: active rule blocks from <dir>/.agent-os/learned-rules.md
into per-scope files under <dir>/.agent-os/rules/<scope>.md, based on
each rule's Scope: field (global | project | directory | file-pattern).
learned-rules.md keeps its promotion-criteria header and candidate/
deprecated rules, and gains an "## Active rules index" section that
points at the moved rules.

Options:
  --adapter <dir>   Directory containing .agent-os/learned-rules.md.
  --dry-run         Print the move plan; make no changes.
  --help            Show this help text and exit.

Rules with a missing or unrecognized Scope: are left in place (WARN).
A rule already present in its target file is left in place (WARN) --
it is never appended twice. This script never deletes rule content;
it only moves verbatim blocks. Safe to rerun: once a rule has been
moved, later runs find no active blocks left to move.

Symlink safety: refuses to run (non-dry-run) if learned-rules.md, the
.agent-os/rules directory, or any rules/<scope>.md file it is about to
write into is a symlink, rather than writing through it.

Exit codes:
  0   completed (see summary line for counts; warnings do not fail)
  1   refused: a file/directory to be modified is a symlink
  2   usage error
EOF
}

ADAPTER_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --adapter)
      [[ $# -ge 2 ]] || { echo "ERROR: --adapter requires a value" >&2; exit 2; }
      ADAPTER_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ADAPTER_DIR" ]]; then
  echo "ERROR: --adapter <dir> is required" >&2
  usage >&2
  exit 2
fi

AO_DIR="$ADAPTER_DIR/.agent-os"
RULES_FILE="$AO_DIR/learned-rules.md"
RULES_DIR="$AO_DIR/rules"

echo "===== split-learned-rules: $RULES_FILE ====="

if [[ ! -f "$RULES_FILE" ]]; then
  echo "WARN: learned-rules.md not found: $RULES_FILE"
  echo "RESULT: nothing to do"
  exit 0
fi

low() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# ---- Parse "## Rule:" blocks (comment-aware) into raw line ranges --------
# Strips HTML comment blocks (same line-based semantics as the other
# scripts) before recognizing headings, so the commented-out example
# rule in the template is never treated as a real block. Emits:
#   start<TAB>end<TAB>name<TAB>status<TAB>scope
# "end" is inclusive: the line just before the next "## " heading, or
# EOF. Trailing blank lines inside that range are trimmed later so the
# spacing left behind in the source file looks natural.
find_blocks() {
  awk '
    function flush(end_line) {
      print start "\t" end_line "\t" name "\t" status "\t" scope
    }
    BEGIN { in_comment = 0; in_block = 0 }
    {
      if ($0 ~ /<!--/) in_comment = 1
      if (!in_comment) {
        if ($0 ~ /^## Rule:/) {
          if (in_block) flush(NR - 1)
          in_block = 1
          start = NR
          name = $0
          sub(/^## Rule:[ \t]*/, "", name)
          gsub(/[ \t]+$/, "", name)
          status = ""; scope = ""
        } else if (in_block && $0 ~ /^## /) {
          flush(NR - 1)
          in_block = 0
        } else if (in_block) {
          if ($0 ~ /^Status:/) {
            status = $0; sub(/^Status:[ \t]*/, "", status); gsub(/[ \t]+$/, "", status)
          } else if ($0 ~ /^Scope:/) {
            scope = $0; sub(/^Scope:[ \t]*/, "", scope); gsub(/[ \t]+$/, "", scope)
          }
        }
      }
      if ($0 ~ /-->/) in_comment = 0
    }
    END { if (in_block) flush(NR) }
  ' "$1"
}

target_has_rule() {
  # Case-insensitive lookup of a "## Rule: <name>" heading in a target
  # rules/<scope>.md file.
  local target="$1" name="$2" lname
  [[ -f "$target" ]] || return 1
  lname="$(low "$name")"
  grep -i '^## Rule:' "$target" 2>/dev/null \
    | sed -E 's/^## Rule:[ \t]*//; s/[ \t]+$//' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -qxF "$lname"
}

mapfile -t LINES < "$RULES_FILE"
TOTAL_LINES=${#LINES[@]}

declare -a B_START=() B_END=() B_NAME=() B_STATUS=() B_SCOPE=()
while IFS=$'\t' read -r s e n st sc; do
  [[ -z "$s" ]] && continue
  B_START+=("$s"); B_END+=("$e"); B_NAME+=("$n"); B_STATUS+=("$st"); B_SCOPE+=("$sc")
done < <(find_blocks "$RULES_FILE")
NUM_BLOCKS=${#B_START[@]}

echo
echo "Total rule blocks found: $NUM_BLOCKS"

# ---- Classify each block ---------------------------------------------
declare -a ACTION=() TARGET=() MSG=()
declare -A SEEN_IN_TARGET=()
MOVED=0
SKIPPED=0
WARNCOUNT=0

for ((i = 0; i < NUM_BLOCKS; i++)); do
  status_lower="$(low "${B_STATUS[$i]}")"
  if [[ "$status_lower" != "active" ]]; then
    ACTION[$i]="KEEP"
    continue
  fi

  name="${B_NAME[$i]}"
  scope="${B_SCOPE[$i]}"
  scope_lower="$(low "$scope")"

  valid=0
  case "$scope_lower" in
    global|project|directory|file-pattern) valid=1 ;;
  esac

  if [[ "$valid" -eq 0 ]]; then
    ACTION[$i]="SKIP_SCOPE"
    MSG[$i]="WARN: \"$name\" has unknown/missing Scope (\"$scope\") -- left in place"
    SKIPPED=$((SKIPPED + 1))
    WARNCOUNT=$((WARNCOUNT + 1))
    continue
  fi

  target="$RULES_DIR/$scope_lower.md"
  lname="$(low "$name")"
  key="$scope_lower|$lname"

  dup=0
  [[ -n "${SEEN_IN_TARGET[$key]:-}" ]] && dup=1
  if [[ "$dup" -eq 0 ]] && target_has_rule "$target" "$name"; then
    dup=1
  fi

  if [[ "$dup" -eq 1 ]]; then
    ACTION[$i]="SKIP_DUP"
    MSG[$i]="WARN: \"$name\" already present in rules/$scope_lower.md -- left in place"
    SKIPPED=$((SKIPPED + 1))
    WARNCOUNT=$((WARNCOUNT + 1))
    continue
  fi

  SEEN_IN_TARGET[$key]=1
  ACTION[$i]="MOVE"
  TARGET[$i]="$target"
  MSG[$i]="MOVE: \"$name\" (Scope: $scope) -> rules/$scope_lower.md"
  MOVED=$((MOVED + 1))
done

# ---- Print the plan ----------------------------------------------------
echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "--- Move plan (dry run; no files modified) ---"
else
  echo "--- Move plan ---"
fi
ANY=0
for ((i = 0; i < NUM_BLOCKS; i++)); do
  [[ "${ACTION[$i]}" == "KEEP" ]] && continue
  echo "${MSG[$i]}"
  ANY=1
done
[[ "$ANY" -eq 0 ]] && echo "(no active rule blocks to move)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "Summary (dry-run): would move $MOVED, skip $SKIPPED, warnings $WARNCOUNT"
  exit 0
fi

# ---- Symlink safety: refuse to write through a symlink -----------------
# learned-rules.md and .agent-os/rules/ are about to be modified below
# (rewritten in place / appended into); refuse outright if either is a
# symlink rather than silently writing through it to wherever it points.
if [[ -L "$RULES_FILE" ]]; then
  echo "ERROR: refusing to modify $RULES_FILE: it is a symlink (remove it manually if you want a regular file there)" >&2
  exit 1
fi
if [[ -e "$RULES_DIR" && -L "$RULES_DIR" ]]; then
  echo "ERROR: refusing to write into $RULES_DIR: it is a symlink (remove it manually if you want a regular directory there)" >&2
  exit 1
fi

# ---- Apply: append moved blocks to their target rules/*.md files -------
declare -a DEL_START=() DEL_END=()
declare -a NEW_INDEX_LINES=()

for ((i = 0; i < NUM_BLOCKS; i++)); do
  [[ "${ACTION[$i]}" != "MOVE" ]] && continue

  start=${B_START[$i]}
  end=${B_END[$i]}
  # Trim trailing blank lines so the source keeps natural spacing.
  trimmed_end=$end
  while [[ $trimmed_end -gt $start ]] && [[ -z "${LINES[$((trimmed_end - 1))]}" ]]; do
    trimmed_end=$((trimmed_end - 1))
  done

  target="${TARGET[$i]}"
  scope_lower="$(low "${B_SCOPE[$i]}")"

  if [[ -L "$target" ]]; then
    echo "ERROR: refusing to write into $target: it is a symlink (remove it manually if you want a regular file there)" >&2
    exit 1
  fi

  mkdir -p "$RULES_DIR"
  if [[ ! -f "$target" ]]; then
    {
      echo "<!-- Active rules for scope: $scope_lower. Populated by split-learned-rules.sh from learned-rules.md; entrypoint stays learned-rules.md. -->"
      echo
    } >"$target"
  else
    echo >>"$target"
  fi
  sed -n "${start},${trimmed_end}p" "$RULES_FILE" >>"$target"

  DEL_START+=("$start")
  DEL_END+=("$trimmed_end")
  NEW_INDEX_LINES+=("- ${B_NAME[$i]} → rules/${scope_lower}.md")
done

# ---- Locate an existing "## Active rules index" section, if any -------
EXIST_INDEX_START=0
EXIST_INDEX_END=0
for ((li = 0; li < TOTAL_LINES; li++)); do
  if [[ "${LINES[$li]}" == "## Active rules index" ]]; then
    EXIST_INDEX_START=$((li + 1))
    break
  fi
done
if [[ "$EXIST_INDEX_START" -gt 0 ]]; then
  EXIST_INDEX_END=$TOTAL_LINES
  for ((ln = EXIST_INDEX_START + 1; ln <= TOTAL_LINES; ln++)); do
    if [[ "${LINES[$((ln - 1))]}" == "## "* ]]; then
      EXIST_INDEX_END=$((ln - 1))
      break
    fi
  done
fi

declare -a EXISTING_INDEX_LINES=()
if [[ "$EXIST_INDEX_START" -gt 0 ]]; then
  for ((ln = EXIST_INDEX_START; ln <= EXIST_INDEX_END; ln++)); do
    content="${LINES[$((ln - 1))]}"
    if [[ "$content" == "- "*"rules/"*".md" ]]; then
      EXISTING_INDEX_LINES+=("$content")
    fi
  done
fi

# ---- Merge existing + new index lines, deduped by rule name -----------
ARROW=$'\xe2\x86\x92'  # UTF-8 "→", matches the literal char used above
declare -A INDEX_SEEN=()
declare -a ALL_INDEX_LINES=()
add_index_line() {
  local line="$1" rest namepart lname
  rest="${line#- }"
  namepart="${rest%% rules/*}"    # "<name> → " (name plus trailing arrow)
  namepart="${namepart% $ARROW}"  # strip the trailing " →"
  lname="$(low "$namepart")"
  [[ -n "${INDEX_SEEN[$lname]:-}" ]] && return
  INDEX_SEEN[$lname]=1
  ALL_INDEX_LINES+=("$line")
}
for line in "${EXISTING_INDEX_LINES[@]:-}"; do
  [[ -z "$line" ]] && continue
  add_index_line "$line"
done
for line in "${NEW_INDEX_LINES[@]:-}"; do
  [[ -z "$line" ]] && continue
  add_index_line "$line"
done

# ---- Find insertion point: right after "## Active rules" heading ------
INSERT_LINE=0
for ((li = 0; li < TOTAL_LINES; li++)); do
  if [[ "${LINES[$li]}" == "## Active rules" ]]; then
    INSERT_LINE=$((li + 1))
    break
  fi
done

# ---- Mark lines to delete: moved rule blocks + old index section ------
declare -a DEL=()
for ((li = 0; li < TOTAL_LINES; li++)); do DEL[$li]=0; done
for idx in "${!DEL_START[@]}"; do
  s=${DEL_START[$idx]}; e=${DEL_END[$idx]}
  for ((ln = s; ln <= e; ln++)); do DEL[$((ln - 1))]=1; done
done
if [[ "$EXIST_INDEX_START" -gt 0 ]]; then
  for ((ln = EXIST_INDEX_START; ln <= EXIST_INDEX_END; ln++)); do
    DEL[$((ln - 1))]=1
  done
fi

# ---- Rewrite learned-rules.md ------------------------------------------
TMP_FILE="$(mktemp "${RULES_FILE}.XXXXXX")"

write_index_section() {
  [[ "${#ALL_INDEX_LINES[@]}" -eq 0 ]] && return
  {
    echo
    echo "## Active rules index"
    echo
    for il in "${ALL_INDEX_LINES[@]}"; do
      echo "$il"
    done
  } >>"$TMP_FILE"
}

wrote_index=0
for ((li = 0; li < TOTAL_LINES; li++)); do
  ln=$((li + 1))
  if [[ "${DEL[$li]}" -eq 0 ]]; then
    printf '%s\n' "${LINES[$li]}" >>"$TMP_FILE"
  fi
  if [[ "$INSERT_LINE" -gt 0 && "$ln" -eq "$INSERT_LINE" && "$wrote_index" -eq 0 ]]; then
    write_index_section
    wrote_index=1
  fi
done
if [[ "$INSERT_LINE" -eq 0 && "$wrote_index" -eq 0 ]]; then
  write_index_section
fi

mv "$TMP_FILE" "$RULES_FILE"

# ---- Summary ------------------------------------------------------------
echo
echo "===== split-learned-rules summary ====="
echo "Moved: $MOVED   Skipped: $SKIPPED   Warnings: $WARNCOUNT"
echo "RESULT: done"
exit 0
