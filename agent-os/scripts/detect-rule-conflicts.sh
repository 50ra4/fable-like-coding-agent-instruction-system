#!/usr/bin/env bash
# detect-rule-conflicts.sh
#
# Read-only analysis of a project's .agent-os/learned-rules.md: finds
# duplicate rule names, rules that overlap on the same "Applies to"
# target, a crude opposite-polarity heuristic (do-not/never vs
# always/must for the same target), and active rules missing required
# fields.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: detect-rule-conflicts.sh --adapter <dir>
       detect-rule-conflicts.sh --file <learned-rules.md>

Detect duplicate/overlapping/conflicting rules in a learned-rules.md
file. Read-only; makes no changes.

Options:
  --adapter <dir>   Directory containing .agent-os/learned-rules.md.
  --file <path>     Path directly to a learned-rules.md file.
  --help            Show this help text and exit.

Findings reported:
  DUPLICATE RULE NAME     - two or more rules share a name (case-insensitive)
  OVERLAP                 - two or more rules target the same "Applies to" item
  POSSIBLE CONFLICT       - overlapping rules use opposite-polarity language
                            (do not/never vs always/must)
  MALFORMED               - an active rule is missing a required field
                            (Status/Scope/Rule/Rationale)

Exit codes:
  0   no findings
  1   one or more findings
  2   usage error
EOF
}

ADAPTER_DIR=""
FILE_ARG=""

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
    --file)
      [[ $# -ge 2 ]] || { echo "ERROR: --file requires a value" >&2; exit 2; }
      FILE_ARG="$2"
      shift 2
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ADAPTER_DIR" && -z "$FILE_ARG" ]]; then
  echo "ERROR: one of --adapter <dir> or --file <path> is required" >&2
  usage >&2
  exit 2
fi

if [[ -n "$FILE_ARG" ]]; then
  RULES_FILE="$FILE_ARG"
else
  RULES_FILE="$ADAPTER_DIR/.agent-os/learned-rules.md"
fi

echo "===== detect-rule-conflicts: $RULES_FILE ====="

if [[ ! -f "$RULES_FILE" ]]; then
  echo "WARN: learned-rules.md not found: $RULES_FILE"
  echo "RESULT: no findings (nothing to check)"
  exit 0
fi

# Parse "## Rule:" blocks and emit tagged, tab-separated records:
#   RULE_START
#   NAME<TAB>name
#   STATUS<TAB>status
#   SCOPE<TAB>scope
#   HAS_STATUS/HAS_SCOPE/HAS_RULE/HAS_RATIONALE<TAB>0|1
#   APPLIES<TAB>target        (0..N lines)
#   NEG<TAB>0|1               (Rule: body contains do not / never)
#   POS<TAB>0|1               (Rule: body contains always / must)
#   RULE_END
parse_rules() {
  local file="$1"
  # Strip HTML comment blocks first (templates ship a "## Rule: <short
  # name>" example inside a "<!-- Example (delete me) -->" comment; that
  # is documentation, not a real rule, and must not be parsed as one).
  awk '
    /<!--/ { in_comment = 1 }
    !in_comment { print }
    /-->/ { in_comment = 0 }
  ' "$file" | awk '
    function flush_block() {
      print "RULE_START"
      print "NAME\t" name
      print "STATUS\t" status
      print "SCOPE\t" scope
      print "HAS_STATUS\t" has_status
      print "HAS_SCOPE\t" has_scope
      print "HAS_RULE\t" has_rule
      print "HAS_RATIONALE\t" has_rationale
      for (i = 0; i < applies_count; i++) print "APPLIES\t" applies[i]
      lower_body = tolower(rule_body)
      neg = (lower_body ~ /do not/ || lower_body ~ /never/) ? 1 : 0
      pos = (lower_body ~ /always/ || lower_body ~ /must/) ? 1 : 0
      print "NEG\t" neg
      print "POS\t" pos
      print "RULE_END"
    }
    BEGIN { in_block = 0 }
    /^## Rule:/ {
      if (in_block) flush_block()
      in_block = 1
      name = $0
      sub(/^## Rule:[ \t]*/, "", name)
      gsub(/[ \t]+$/, "", name)
      status = ""; scope = ""; rule_body = ""
      has_status = 0; has_scope = 0; has_rule = 0; has_rationale = 0
      applies_count = 0
      delete applies
      cur_section = ""
      next
    }
    in_block && /^## / {
      flush_block()
      in_block = 0
      next
    }
    in_block {
      line = $0
      if (line ~ /^Status:/) {
        has_status = 1
        status = line; sub(/^Status:[ \t]*/, "", status); gsub(/[ \t]+$/, "", status)
        cur_section = ""
        next
      }
      if (line ~ /^Scope:/) {
        has_scope = 1
        scope = line; sub(/^Scope:[ \t]*/, "", scope); gsub(/[ \t]+$/, "", scope)
        cur_section = ""
        next
      }
      if (line ~ /^Source:/) { cur_section = ""; next }
      if (line ~ /^Applies to:/) { cur_section = "applies"; next }
      if (line ~ /^Rule:/) { has_rule = 1; cur_section = "rule"; next }
      if (line ~ /^Rationale:/) { has_rationale = 1; cur_section = ""; next }
      if (line ~ /^Examples:/) { cur_section = ""; next }
      if (line ~ /^Validation:/) { cur_section = ""; next }
      if (line ~ /^[ \t]*$/) { cur_section = ""; next }
      if (cur_section == "applies" && line ~ /^-/) {
        item = line; sub(/^-[ \t]*/, "", item); gsub(/[ \t]+$/, "", item)
        applies[applies_count++] = item
        next
      }
      if (cur_section == "rule") {
        rule_body = rule_body " " line
        next
      }
    }
    END { if (in_block) flush_block() }
  '
}

declare -a NAMES=()
declare -a STATUSES=()
declare -a HAS_STATUS=()
declare -a HAS_SCOPE=()
declare -a HAS_RULE=()
declare -a HAS_RATIONALE=()
declare -a NEGS=()
declare -a POSS=()
# APPLIES_LIST[i] holds a newline-separated list of targets for rule i.
declare -a APPLIES_LIST=()

idx=-1
while IFS=$'\t' read -r tag val; do
  case "$tag" in
    RULE_START)
      idx=$((idx + 1))
      APPLIES_LIST[$idx]=""
      ;;
    NAME) NAMES[$idx]="$val" ;;
    STATUS) STATUSES[$idx]="$val" ;;
    HAS_STATUS) HAS_STATUS[$idx]="$val" ;;
    HAS_SCOPE) HAS_SCOPE[$idx]="$val" ;;
    HAS_RULE) HAS_RULE[$idx]="$val" ;;
    HAS_RATIONALE) HAS_RATIONALE[$idx]="$val" ;;
    APPLIES)
      if [[ -z "${APPLIES_LIST[$idx]}" ]]; then
        APPLIES_LIST[$idx]="$val"
      else
        APPLIES_LIST[$idx]="${APPLIES_LIST[$idx]}"$'\n'"$val"
      fi
      ;;
    NEG) NEGS[$idx]="$val" ;;
    POS) POSS[$idx]="$val" ;;
    RULE_END) : ;;
  esac
done < <(parse_rules "$RULES_FILE")

TOTAL_RULES=$((idx + 1))

FINDINGS=0

echo
echo "Total rule blocks found: $TOTAL_RULES"

if [[ "$TOTAL_RULES" -eq 0 ]]; then
  echo "RESULT: no findings"
  exit 0
fi

# ---- (a) Duplicate rule names (case-insensitive) --------------------------
echo
echo "--- Duplicate rule names ---"
declare -A NAME_COUNT=()
for n in "${NAMES[@]}"; do
  lower="$(echo "$n" | tr '[:upper:]' '[:lower:]')"
  NAME_COUNT["$lower"]=$(( ${NAME_COUNT["$lower"]:-0} + 1 ))
done
DUP_NAME_FOUND=0
for lower in "${!NAME_COUNT[@]}"; do
  if [[ "${NAME_COUNT[$lower]}" -ge 2 ]]; then
    echo "DUPLICATE RULE NAME: \"$lower\" appears ${NAME_COUNT[$lower]} times"
    DUP_NAME_FOUND=1
    FINDINGS=$((FINDINGS + 1))
  fi
done
[[ "$DUP_NAME_FOUND" -eq 0 ]] && echo "(none)"

# ---- (b) Overlapping "Applies to" targets ---------------------------------
echo
echo "--- Overlapping Applies-to targets ---"
declare -A TARGET_RULES=()
for i in $(seq 0 $((TOTAL_RULES - 1))); do
  [[ -z "${APPLIES_LIST[$i]:-}" ]] && continue
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ -z "${TARGET_RULES[$target]:-}" ]]; then
      TARGET_RULES["$target"]="$i"
    else
      TARGET_RULES["$target"]="${TARGET_RULES[$target]} $i"
    fi
  done <<<"${APPLIES_LIST[$i]}"
done

OVERLAP_FOUND=0
declare -A CONFLICT_TARGETS=()
for target in "${!TARGET_RULES[@]}"; do
  rule_idxs="${TARGET_RULES[$target]}"
  # count distinct rule indices for this target
  count="$(tr ' ' '\n' <<<"$rule_idxs" | grep -c . || true)"
  if [[ "$count" -ge 2 ]]; then
    OVERLAP_FOUND=1
    FINDINGS=$((FINDINGS + 1))
    names_str=""
    has_neg=0
    has_pos=0
    for i in $rule_idxs; do
      names_str="$names_str \"${NAMES[$i]}\""
      [[ "${NEGS[$i]:-0}" -eq 1 ]] && has_neg=1
      [[ "${POSS[$i]:-0}" -eq 1 ]] && has_pos=1
    done
    echo "OVERLAP -- review for conflict: target \"$target\" is claimed by rules:$names_str"
    if [[ "$has_neg" -eq 1 && "$has_pos" -eq 1 ]]; then
      CONFLICT_TARGETS["$target"]="$rule_idxs"
    fi
  fi
done
[[ "$OVERLAP_FOUND" -eq 0 ]] && echo "(none)"

# ---- (c) Possible conflicts (opposite polarity on the same target) --------
echo
echo "--- Possible conflicts (opposite polarity) ---"
CONFLICT_FOUND=0
for target in "${!CONFLICT_TARGETS[@]}"; do
  rule_idxs="${CONFLICT_TARGETS[$target]}"
  names_str=""
  for i in $rule_idxs; do
    polarity="neutral"
    [[ "${NEGS[$i]:-0}" -eq 1 ]] && polarity="do-not/never"
    [[ "${POSS[$i]:-0}" -eq 1 ]] && polarity="always/must"
    names_str="$names_str \"${NAMES[$i]}\"($polarity)"
  done
  echo "POSSIBLE CONFLICT -- target \"$target\":$names_str"
  CONFLICT_FOUND=1
  FINDINGS=$((FINDINGS + 1))
done
[[ "$CONFLICT_FOUND" -eq 0 ]] && echo "(none)"

# ---- (d) Malformed active rules (missing required fields) -----------------
echo
echo "--- Malformed active rules (missing required fields) ---"
MALFORMED_FOUND=0
for i in $(seq 0 $((TOTAL_RULES - 1))); do
  status_lower="$(echo "${STATUSES[$i]:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$status_lower" != "active" ]] && continue
  missing=""
  [[ "${HAS_STATUS[$i]:-0}" -eq 0 ]] && missing="$missing Status"
  [[ "${HAS_SCOPE[$i]:-0}" -eq 0 ]] && missing="$missing Scope"
  [[ "${HAS_RULE[$i]:-0}" -eq 0 ]] && missing="$missing Rule"
  [[ "${HAS_RATIONALE[$i]:-0}" -eq 0 ]] && missing="$missing Rationale"
  if [[ -n "$missing" ]]; then
    echo "MALFORMED -- rule \"${NAMES[$i]}\" (Status: active) is missing:$missing"
    MALFORMED_FOUND=1
    FINDINGS=$((FINDINGS + 1))
  fi
done
[[ "$MALFORMED_FOUND" -eq 0 ]] && echo "(none)"

# ---- Summary --------------------------------------------------------
echo
echo "===== detect-rule-conflicts summary ====="
echo "Total findings: $FINDINGS"

if [[ "$FINDINGS" -gt 0 ]]; then
  echo "RESULT: FINDINGS"
  exit 1
fi

echo "RESULT: no findings"
exit 0
