#!/usr/bin/env bash
# detect-rule-conflicts.sh
#
# Read-only analysis of a project's .agent-os/learned-rules.md (and,
# when present, the split-by-scope .agent-os/rules/*.md files): finds
# duplicate rule names, rules that overlap on the same "Applies to"
# target, a crude opposite-polarity heuristic (do-not/never vs
# always/must for the same target), and active rules missing required
# fields. Findings are tagged with the source file each rule came from
# so cross-file duplicates/overlaps/conflicts are visible. This
# opposite-polarity heuristic is kept as-is for backward compatibility.
#
# The default mode above is mechanical findings for direct human review.
# --pairs is a second, distinct mode: mechanical candidate-pair
# enumeration meant as pre-processing for the `distill-rules` skill's
# semantic judgment pass. It keeps only Status: active rules, scores
# every pair (i<j) on purely structural proximity (shared exact
# "Applies to" targets, matching Scope, overlapping targets tokens) and
# prints them sorted by score -- it never inspects Rule body content or
# wording, that judgment is deliberately left to the model. --pairs
# always exits 0 (except on a usage error, which exits 2).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: detect-rule-conflicts.sh --adapter <dir> [--pairs]
       detect-rule-conflicts.sh --file <learned-rules.md> [--pairs]

Detect duplicate/overlapping/conflicting rules across a project's rule
files. Read-only; makes no changes.

In --adapter mode this covers <dir>/.agent-os/learned-rules.md plus,
when the project has split rules by scope, every
<dir>/.agent-os/rules/*.md file -- duplicates/overlaps/conflicts are
detected across all of them combined, and each finding names the
source file(s) involved. --file mode analyzes a single given file only.

Options:
  --adapter <dir>   Directory containing .agent-os/learned-rules.md
                    (and, optionally, .agent-os/rules/*.md).
  --file <path>     Path directly to a single rules file.
  --pairs           Candidate-pair enumeration mode instead of the
                    default findings (see below). Combine with
                    --adapter or --file.
  --help            Show this help text and exit.

Findings reported (default mode):
  DUPLICATE RULE NAME     - two or more rules share a name (case-insensitive)
  OVERLAP                 - two or more rules target the same "Applies to" item
  POSSIBLE CONFLICT       - overlapping rules use opposite-polarity language
                            (do not/never vs always/must) -- kept for
                            backward compatibility
  MALFORMED               - an active rule is missing a required field
                            (Status/Scope/Rule/Rationale)

--pairs mode (mechanical pre-pass for the `distill-rules` skill):
  Keeps only Status: active rules, enumerates every pair (i<j), and
  scores each pair by purely structural proximity -- no Rule-body
  content or wording is inspected, that semantic judgment is left to
  the model consuming this output:
    +3 for EACH shared exact "Applies to" target (case/whitespace
       normalized)
    +2 if both rules have the same Scope (case-insensitive)
    +1 (flat, not per token) if, beyond any exact target matches, the
       two rules' remaining "Applies to" targets share at least one
       token (targets split on / whitespace . _ -, lowercased)
  Pairs are printed sorted by score descending (ties broken
  alphabetically by the pair's rule names). This mode replaces the
  default findings output and always exits 0, except on a usage error.

Exit codes:
  0   no findings (default mode); always in --pairs mode
  1   one or more findings (default mode only)
  2   usage error
EOF
}

ADAPTER_DIR=""
FILE_ARG=""
PAIRS=0

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
    --pairs)
      PAIRS=1
      shift
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

# SOURCE_FILES holds every rules file to analyze, in order. In --file
# mode that is exactly the one path given (unchanged single-file
# behavior). In --adapter mode it is learned-rules.md plus, when the
# project has split rules by scope, every .agent-os/rules/*.md file --
# all of them are concatenated (comment-stripped) before parsing so
# duplicates/overlaps/conflicts are caught across files too.
declare -a SOURCE_FILES=()

if [[ -n "$FILE_ARG" ]]; then
  SOURCE_FILES=("$FILE_ARG")
  if [[ "$PAIRS" -eq 1 ]]; then
    echo "===== detect-rule-conflicts --pairs: $FILE_ARG ====="
  else
    echo "===== detect-rule-conflicts: $FILE_ARG ====="
  fi
else
  AO_DIR="$ADAPTER_DIR/.agent-os"
  LEARNED_RULES="$AO_DIR/learned-rules.md"
  RULES_DIR="$AO_DIR/rules"
  if [[ "$PAIRS" -eq 1 ]]; then
    echo "===== detect-rule-conflicts --pairs: $AO_DIR ====="
  else
    echo "===== detect-rule-conflicts: $AO_DIR ====="
  fi

  [[ -f "$LEARNED_RULES" ]] && SOURCE_FILES+=("$LEARNED_RULES")
  if [[ -d "$RULES_DIR" ]]; then
    while IFS= read -r f; do
      SOURCE_FILES+=("$f")
    done < <(find "$RULES_DIR" -maxdepth 1 -name '*.md' -type f | sort)
  fi

  echo "Sources: ${SOURCE_FILES[*]:-(none found)}"
fi

if [[ "${#SOURCE_FILES[@]}" -eq 0 ]]; then
  if [[ "$PAIRS" -eq 1 ]]; then
    echo
    echo "Total active rules: 0"
    echo
    echo "(no pairs)"
    exit 0
  fi
  echo "WARN: learned-rules.md not found: ${FILE_ARG:-$ADAPTER_DIR/.agent-os/learned-rules.md}"
  echo "RESULT: no findings (nothing to check)"
  exit 0
fi

# Parse "## Rule:" blocks and emit tagged, tab-separated records:
#   RULE_START
#   SOURCE<TAB>source label (which file this rule came from)
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
  local source_label="$2"
  # Strip HTML comment blocks first (templates ship a "## Rule: <short
  # name>" example inside a "<!-- Example (delete me) -->" comment; that
  # is documentation, not a real rule, and must not be parsed as one).
  # Also strips a trailing \r from every line first, so a CRLF-converted
  # rules file still parses correctly (name/status/scope exact-match
  # comparisons below would otherwise carry a trailing \r and never match).
  awk '
    {
      sub(/\r$/, "")
      # Span-aware HTML comment strip: iteratively remove "<!-- ... -->"
      # spans from the line so a same-line open+close (e.g. "<!-- note
      # --> ## Rule: Bravo") does not swallow trailing real content the
      # way a simple line-based in_comment toggle would. Text before an
      # unclosed "<!--" is kept and in_comment carries into the next
      # line; while in_comment, text up to a closing "-->" is dropped
      # and the remainder of the line is processed normally.
      line = $0; out = ""; trimmed = 0
      while (length(line) > 0) {
        if (in_comment) {
          p = index(line, "-->")
          if (p == 0) {
            line = ""
          } else {
            line = substr(line, p + 3)
            in_comment = 0
            if (out == "") trimmed = 1
          }
        } else {
          p = index(line, "<!--")
          if (p == 0) {
            out = out line
            line = ""
          } else {
            out = out substr(line, 1, p - 1)
            line = substr(line, p + 4)
            in_comment = 1
          }
        }
      }
      # A comment that prefixed a heading/field on this line can leave
      # leading whitespace in `out`; strip it (only when it was actually
      # introduced by a stripped leading comment span) so the downstream
      # parser'"'"'s "^## " / "^Status:" / etc. anchors still match.
      if (trimmed) sub(/^[ \t]+/, "", out)
      print out
    }
  ' "$file" | awk -v source_label="$source_label" '
    function flush_block() {
      print "RULE_START"
      print "SOURCE\t" source_label
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

# Emit parsed records for every source file, tagging each rule with the
# basename of the file it came from (e.g. "learned-rules.md",
# "rules/directory.md") so findings can report where each rule lives.
all_rules() {
  local f label
  for f in "${SOURCE_FILES[@]}"; do
    case "$f" in
      */rules/*) label="rules/$(basename "$f")" ;;
      *) label="$(basename "$f")" ;;
    esac
    parse_rules "$f" "$label"
  done
}

declare -a SOURCES=()
declare -a NAMES=()
declare -a STATUSES=()
declare -a SCOPES=()
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
    SOURCE) SOURCES[$idx]="$val" ;;
    NAME) NAMES[$idx]="$val" ;;
    STATUS) STATUSES[$idx]="$val" ;;
    SCOPE) SCOPES[$idx]="$val" ;;
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
done < <(all_rules)

TOTAL_RULES=$((idx + 1))

# ---- --pairs mode: mechanical candidate-pair enumeration ------------------
# Pre-processing for the `distill-rules` skill. Reuses the SOURCES/NAMES/
# STATUSES/SCOPES/APPLIES_LIST arrays parsed above unchanged; scores pairs
# on structural proximity only (no Rule-body content inspected) and always
# exits 0. This branch fully replaces the default findings output below.
do_pairs_output() {
  local -a active_idx=()
  local i j st_lower
  for i in $(seq 0 $((TOTAL_RULES - 1))); do
    st_lower="$(echo "${STATUSES[$i]:-}" | tr '[:upper:]' '[:lower:]')"
    [[ "$st_lower" == "active" ]] && active_idx+=("$i")
  done

  local n_active=${#active_idx[@]}
  echo
  echo "Total active rules: $n_active"
  echo

  if [[ "$n_active" -lt 2 ]]; then
    echo "(no pairs)"
    return 0
  fi

  # Precompute, per rule, lowercased/trimmed targets and their tokens
  # (split on / whitespace . _ -, empty tokens dropped).
  local -a targets_lower=()
  local -a tokens_flat=()
  for i in $(seq 0 $((TOTAL_RULES - 1))); do
    local lowered=""
    if [[ -n "${APPLIES_LIST[$i]:-}" ]]; then
      lowered="$(printf '%s\n' "${APPLIES_LIST[$i]}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[ \t]+//; s/[ \t]+$//')"
    fi
    targets_lower[$i]="$lowered"
    if [[ -n "$lowered" ]]; then
      tokens_flat[$i]="$(printf '%s\n' "$lowered" | tr '/ \t._-' '\n\n\n\n\n\n' | sed '/^$/d')"
    else
      tokens_flat[$i]=""
    fi
  done

  local -a pair_lines=()
  local a_pos b_pos score exact_count shared_str t tok
  local -A seen_a shared_set rem_a_tokens
  for a_pos in $(seq 0 $((n_active - 2))); do
    for b_pos in $(seq $((a_pos + 1)) $((n_active - 1))); do
      i="${active_idx[$a_pos]}"
      j="${active_idx[$b_pos]}"

      seen_a=()
      while IFS= read -r t; do
        [[ -n "$t" ]] && seen_a["$t"]=1
      done <<<"${targets_lower[$i]}"

      local -a shared=()
      shared_set=()
      while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        if [[ -n "${seen_a[$t]:-}" ]]; then
          shared+=("$t")
          shared_set["$t"]=1
        fi
      done <<<"${targets_lower[$j]}"

      exact_count=${#shared[@]}
      score=$((exact_count * 3))

      local scope_a scope_b
      scope_a="$(echo "${SCOPES[$i]:-}" | tr '[:upper:]' '[:lower:]')"
      scope_b="$(echo "${SCOPES[$j]:-}" | tr '[:upper:]' '[:lower:]')"
      if [[ -n "$scope_a" && "$scope_a" == "$scope_b" ]]; then
        score=$((score + 2))
      fi

      # Token overlap beyond exact target matches: tokenize only the
      # targets that are not themselves an exact shared match.
      rem_a_tokens=()
      while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        [[ -n "${shared_set[$t]:-}" ]] && continue
        while IFS= read -r tok; do
          [[ -n "$tok" ]] && rem_a_tokens["$tok"]=1
        done < <(printf '%s\n' "$t" | tr '/ \t._-' '\n\n\n\n\n\n' | sed '/^$/d')
      done <<<"${targets_lower[$i]}"

      local token_overlap=0
      while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        [[ -n "${shared_set[$t]:-}" ]] && continue
        while IFS= read -r tok; do
          [[ -n "$tok" ]] || continue
          if [[ -n "${rem_a_tokens[$tok]:-}" ]]; then
            token_overlap=1
          fi
        done < <(printf '%s\n' "$t" | tr '/ \t._-' '\n\n\n\n\n\n' | sed '/^$/d')
      done <<<"${targets_lower[$j]}"

      [[ "$token_overlap" -eq 1 ]] && score=$((score + 1))

      shared_str="-"
      if [[ "$exact_count" -gt 0 ]]; then
        shared_str=""
        for t in "${shared[@]}"; do
          if [[ -z "$shared_str" ]]; then
            shared_str="\"$t\""
          else
            shared_str="$shared_str, \"$t\""
          fi
        done
      fi

      local sort_key line
      sort_key="$(printf '%05d|%s|%s' $((99999 - score)) "$(echo "${NAMES[$i]}" | tr '[:upper:]' '[:lower:]')" "$(echo "${NAMES[$j]}" | tr '[:upper:]' '[:lower:]')")"
      line="PAIR score=$score: \"${NAMES[$i]}\" [${SOURCES[$i]:-?}] <-> \"${NAMES[$j]}\" [${SOURCES[$j]:-?}] | scope: ${SCOPES[$i]:-} / ${SCOPES[$j]:-} | shared: $shared_str"
      pair_lines+=("$sort_key"$'\t'"$line")
    done
  done

  printf '%s\n' "${pair_lines[@]}" | sort -t $'\t' -k1,1 | cut -f2-
  return 0
}

if [[ "$PAIRS" -eq 1 ]]; then
  do_pairs_output
  exit 0
fi

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
declare -A NAME_SOURCES=()
for i in $(seq 0 $((TOTAL_RULES - 1))); do
  lower="$(echo "${NAMES[$i]}" | tr '[:upper:]' '[:lower:]')"
  NAME_COUNT["$lower"]=$(( ${NAME_COUNT["$lower"]:-0} + 1 ))
  if [[ -z "${NAME_SOURCES[$lower]:-}" ]]; then
    NAME_SOURCES["$lower"]="${SOURCES[$i]:-?}"
  else
    NAME_SOURCES["$lower"]="${NAME_SOURCES[$lower]}, ${SOURCES[$i]:-?}"
  fi
done
DUP_NAME_FOUND=0
for lower in "${!NAME_COUNT[@]}"; do
  if [[ "${NAME_COUNT[$lower]}" -ge 2 ]]; then
    echo "DUPLICATE RULE NAME: \"$lower\" appears ${NAME_COUNT[$lower]} times (in: ${NAME_SOURCES[$lower]})"
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
      names_str="$names_str \"${NAMES[$i]}\" [${SOURCES[$i]:-?}]"
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
    names_str="$names_str \"${NAMES[$i]}\"($polarity) [${SOURCES[$i]:-?}]"
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
    echo "MALFORMED -- rule \"${NAMES[$i]}\" [${SOURCES[$i]:-?}] (Status: active) is missing:$missing"
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
