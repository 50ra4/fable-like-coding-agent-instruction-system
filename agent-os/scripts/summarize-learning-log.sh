#!/usr/bin/env bash
# summarize-learning-log.sh
#
# Read-only reporting over a project's .agent-os/failure-log.md and
# .agent-os/review-feedback-log.md: entry counts, category breakdown,
# and promotion candidates (recurring failures / duplicate feedback)
# that should become an active rule in learned-rules.md. The rule
# Status counts also cover .agent-os/rules/*.md when the project has
# split learned-rules.md by scope.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: summarize-learning-log.sh --adapter <dir>

Summarize a project's .agent-os/failure-log.md and
.agent-os/review-feedback-log.md: total entries, entries grouped by
category, promotion candidates (2+ occurrences), and the current
learned-rules.md status counts (including .agent-os/rules/*.md, when
present, with a per-file breakdown).

Options:
  --adapter <dir>   Directory containing .agent-os/ (required).
  --help            Show this help text and exit.

This is a pure read-only report; it never modifies any file. Exit code
is 0 unless the command itself was called incorrectly (exit 2).
EOF
}

ADAPTER_DIR=""

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
FAILURE_LOG="$AO_DIR/failure-log.md"
FEEDBACK_LOG="$AO_DIR/review-feedback-log.md"
RULES_FILE="$AO_DIR/learned-rules.md"
RULES_DIR="$AO_DIR/rules"

if [[ ! -d "$AO_DIR" ]]; then
  echo "WARN: .agent-os directory not found: $AO_DIR"
fi

# Extract "## " headings and any Category: / Recurrence count: fields
# from a log file. Emits one record per entry:
#   heading<FS_SEP>category<FS_SEP>recurrence
#
# Field separator between heading/category/recurrence in extract_entries'
# output. A plain tab cannot be used here: bash's `read` (and awk's default
# field splitting) treats runs of IFS whitespace as a single delimiter and
# trims it at field boundaries, so an *empty* middle field (a very common
# case: most failure-log entries have no Category:) silently disappears
# and shifts the remaining fields left. The ASCII Unit Separator (octal
# \037) is not whitespace, so empty fields are preserved correctly.
FS_SEP=$'\x1f'

extract_entries() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Strip HTML comment blocks first (templates ship "Example (delete me)"
  # entries inside <!-- --> comments; those are documentation, not real
  # log entries, and must not be counted).
  awk '
    /<!--/ { in_comment = 1 }
    !in_comment { print }
    /-->/ { in_comment = 0 }
  ' "$file" | awk -v FS_SEP="$FS_SEP" '
    /^## / {
      if (heading != "") print heading FS_SEP category FS_SEP recurrence
      heading = $0
      sub(/^## /, "", heading)
      gsub(/[ \t]+$/, "", heading)
      category = ""
      recurrence = ""
      next
    }
    /^Category:/ {
      category = $0
      sub(/^Category:[ \t]*/, "", category)
      gsub(/[ \t]+$/, "", category)
      next
    }
    /^Recurrence count:/ {
      recurrence = $0
      sub(/^Recurrence count:[ \t]*/, "", recurrence)
      gsub(/[ \t]+$/, "", recurrence)
      next
    }
    END {
      if (heading != "") print heading FS_SEP category FS_SEP recurrence
    }
  '
}

# ---- Load entries from both logs ----------------------------------------
mapfile -t FAILURE_ENTRIES < <(extract_entries "$FAILURE_LOG")
mapfile -t FEEDBACK_ENTRIES < <(extract_entries "$FEEDBACK_LOG")

echo "===== summarize-learning-log: $AO_DIR ====="
echo
echo "Total entries in failure-log.md:         ${#FAILURE_ENTRIES[@]}"
echo "Total entries in review-feedback-log.md: ${#FEEDBACK_ENTRIES[@]}"

# ---- Group by category (across both logs) --------------------------------
declare -A CATEGORY_COUNTS=()
ALL_HEADINGS_NORMALIZED=()
ALL_HEADINGS_ORIGINAL=()
ALL_HEADINGS_SOURCE=()

collect() {
  local source_label="$1"
  shift
  local entries=("$@")
  local line heading category recurrence
  for line in "${entries[@]}"; do
    [[ -z "$line" ]] && continue
    IFS="$FS_SEP" read -r heading category recurrence <<<"$line"
    if [[ -z "$category" ]]; then
      category="Uncategorized"
    fi
    CATEGORY_COUNTS["$category"]=$(( ${CATEGORY_COUNTS["$category"]:-0} + 1 ))

    local normalized
    normalized="$(echo "$heading" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
    ALL_HEADINGS_NORMALIZED+=("$normalized")
    ALL_HEADINGS_ORIGINAL+=("$heading")
    ALL_HEADINGS_SOURCE+=("$source_label")
  done
}

collect "failure-log" "${FAILURE_ENTRIES[@]:-}"
collect "review-feedback-log" "${FEEDBACK_ENTRIES[@]:-}"

echo
echo "--- Entries grouped by category ---"
if [[ "${#CATEGORY_COUNTS[@]}" -eq 0 ]]; then
  echo "(no entries found)"
else
  for cat in "${!CATEGORY_COUNTS[@]}"; do
    echo "$cat"$'\t'"${CATEGORY_COUNTS[$cat]}"
  done | sort | awk -F'\t' '{printf "  %-30s %s\n", $1, $2}'
fi

# ---- Promotion candidates -------------------------------------------------
echo
echo "===== PROMOTION CANDIDATES (2+ occurrences -- promote to active rule) ====="

FOUND_CANDIDATE=0

# (a) failure-log entries with recurrence count >= 2
echo "--- Recurring failures (recurrence count >= 2) ---"
RECUR_FOUND=0
for line in "${FAILURE_ENTRIES[@]:-}"; do
  [[ -z "$line" ]] && continue
  IFS="$FS_SEP" read -r heading category recurrence <<<"$line"
  if [[ "$recurrence" =~ ^[0-9]+$ ]] && [[ "$recurrence" -ge 2 ]]; then
    echo "  [failure-log] \"$heading\" (recurrence count: $recurrence)"
    RECUR_FOUND=1
    FOUND_CANDIDATE=1
  fi
done
[[ "$RECUR_FOUND" -eq 0 ]] && echo "  (none)"

# (b) duplicate/similar headings across all entries (normalized, 2+ times)
echo
echo "--- Duplicate/similar headings across entries (2+ occurrences) ---"
declare -A HEADING_SEEN_COUNT=()
DUP_FOUND=0
if [[ "${#ALL_HEADINGS_NORMALIZED[@]}" -gt 0 ]]; then
  for h in "${ALL_HEADINGS_NORMALIZED[@]}"; do
    HEADING_SEEN_COUNT["$h"]=$(( ${HEADING_SEEN_COUNT["$h"]:-0} + 1 ))
  done
  for h in "${!HEADING_SEEN_COUNT[@]}"; do
    count="${HEADING_SEEN_COUNT[$h]}"
    if [[ "$count" -ge 2 ]]; then
      DUP_FOUND=1
      FOUND_CANDIDATE=1
      echo "  \"$h\" seen $count times:"
      for i in "${!ALL_HEADINGS_NORMALIZED[@]}"; do
        if [[ "${ALL_HEADINGS_NORMALIZED[$i]}" == "$h" ]]; then
          echo "      - [${ALL_HEADINGS_SOURCE[$i]}] ${ALL_HEADINGS_ORIGINAL[$i]}"
        fi
      done
    fi
  done
fi
[[ "$DUP_FOUND" -eq 0 ]] && echo "  (none)"

if [[ "$FOUND_CANDIDATE" -eq 0 ]]; then
  echo
  echo "No promotion candidates found."
fi

# ---- learned-rules.md status counts ---------------------------------------
# Covers learned-rules.md plus, when the project has split rules by
# scope, every .agent-os/rules/*.md file.
echo
echo "--- learned-rules.md: rule counts by Status ---"
declare -a STATUS_FILES=()
[[ -f "$RULES_FILE" ]] && STATUS_FILES+=("$RULES_FILE")
if [[ -d "$RULES_DIR" ]]; then
  while IFS= read -r f; do
    STATUS_FILES+=("$f")
  done < <(find "$RULES_DIR" -maxdepth 1 -name '*.md' -type f | sort)
fi

if [[ "${#STATUS_FILES[@]}" -eq 0 ]]; then
  echo "  (learned-rules.md not found: $RULES_FILE)"
else
  count_status() {
    # $1 = file, $2 = status word; prints a count, always numeric.
    local n
    n="$(grep -cE "^Status:[[:space:]]*$2[[:space:]]*\$" "$1" || true)"
    echo "${n:-0}"
  }

  TOTAL_CANDIDATE=0
  TOTAL_ACTIVE=0
  TOTAL_DEPRECATED=0
  for f in "${STATUS_FILES[@]}"; do
    TOTAL_CANDIDATE=$((TOTAL_CANDIDATE + $(count_status "$f" candidate)))
    TOTAL_ACTIVE=$((TOTAL_ACTIVE + $(count_status "$f" active)))
    TOTAL_DEPRECATED=$((TOTAL_DEPRECATED + $(count_status "$f" deprecated)))
  done
  echo "  candidate:  $TOTAL_CANDIDATE"
  echo "  active:     $TOTAL_ACTIVE"
  echo "  deprecated: $TOTAL_DEPRECATED"

  if [[ "${#STATUS_FILES[@]}" -gt 1 ]]; then
    echo
    echo "  --- per-file breakdown (split layout detected) ---"
    for f in "${STATUS_FILES[@]}"; do
      case "$f" in
        */rules/*) label="rules/$(basename "$f")" ;;
        *) label="$(basename "$f")" ;;
      esac
      printf '  %-24s candidate: %-3s active: %-3s deprecated: %s\n' \
        "$label" "$(count_status "$f" candidate)" "$(count_status "$f" active)" "$(count_status "$f" deprecated)"
    done
  fi
fi

echo
echo "===================================================="
exit 0
