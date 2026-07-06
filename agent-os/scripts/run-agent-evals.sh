#!/usr/bin/env bash
# run-agent-evals.sh
#
# Semi-automated eval runner for a project's .agent-os/evals.md. The AGENT
# still performs each eval's Task; this script automates enumeration,
# validation-command handling (with a safety gate against command-map.md),
# and recording pass/fail results into the Results table.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  run-agent-evals.sh --adapter <dir> --list
  run-agent-evals.sh --adapter <dir> --show <eval-name>
  run-agent-evals.sh --adapter <dir> --check <eval-name> [--exec]
  run-agent-evals.sh --adapter <dir> --record <eval-name> --result pass|fail --model <model-name> [--notes <text>]

<dir> must contain .agent-os/evals.md.

Modes (exactly one required):
  --list                 List all "## Eval: <name>" blocks: name, first
                          Task bullet, and most recent recorded result.
  --show <name>          Print the full eval block verbatim.
  --check <name>         Extract and display the Validation command(s).
                          Add --exec to actually run them, gated by
                          .agent-os/command-map.md (a command is only run
                          if it appears verbatim in the command map).
  --record <name>        Append a result row to the "## Results" table.
                          Requires --result pass|fail and --model <name>;
                          --notes <text> is optional.

Options:
  --adapter <dir>   Directory containing .agent-os/evals.md (required).
  --exec            With --check, execute allow-listed validation commands.
  --result <v>      With --record, "pass" or "fail".
  --model <name>    With --record, the model/agent name used for the run.
  --notes <text>    With --record, free-text notes (pipes/newlines stripped).
  --help            Show this help text and exit.

Exit codes:
  0   success (list/show/record done; check with no failures)
  1   --check --exec found a failing or refused validation command, or
      --record refused because evals.md is a symlink
  2   usage error (bad flags, unknown eval name, missing files)
EOF
}

# ---- Argument parsing -----------------------------------------------------
ADAPTER_DIR=""
MODE=""
MODE_ARG=""
MODE_COUNT=0
EXEC_FLAG=0
RESULT_VAL=""
MODEL_VAL=""
NOTES_VAL=""

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
    --list)
      MODE="list"
      MODE_COUNT=$((MODE_COUNT + 1))
      shift
      ;;
    --show)
      [[ $# -ge 2 ]] || { echo "ERROR: --show requires an eval name" >&2; exit 2; }
      MODE="show"
      MODE_ARG="$2"
      MODE_COUNT=$((MODE_COUNT + 1))
      shift 2
      ;;
    --check)
      [[ $# -ge 2 ]] || { echo "ERROR: --check requires an eval name" >&2; exit 2; }
      MODE="check"
      MODE_ARG="$2"
      MODE_COUNT=$((MODE_COUNT + 1))
      shift 2
      ;;
    --record)
      [[ $# -ge 2 ]] || { echo "ERROR: --record requires an eval name" >&2; exit 2; }
      MODE="record"
      MODE_ARG="$2"
      MODE_COUNT=$((MODE_COUNT + 1))
      shift 2
      ;;
    --exec)
      EXEC_FLAG=1
      shift
      ;;
    --result)
      [[ $# -ge 2 ]] || { echo "ERROR: --result requires a value" >&2; exit 2; }
      RESULT_VAL="$2"
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || { echo "ERROR: --model requires a value" >&2; exit 2; }
      MODEL_VAL="$2"
      shift 2
      ;;
    --notes)
      [[ $# -ge 2 ]] || { echo "ERROR: --notes requires a value" >&2; exit 2; }
      NOTES_VAL="$2"
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

if [[ "$MODE_COUNT" -eq 0 ]]; then
  echo "ERROR: one of --list, --show, --check, --record is required" >&2
  usage >&2
  exit 2
fi

if [[ "$MODE_COUNT" -gt 1 ]]; then
  echo "ERROR: --list/--show/--check/--record are mutually exclusive" >&2
  usage >&2
  exit 2
fi

if [[ "$EXEC_FLAG" -eq 1 && "$MODE" != "check" ]]; then
  echo "ERROR: --exec is only valid with --check" >&2
  exit 2
fi

if [[ -n "$RESULT_VAL" || -n "$MODEL_VAL" || -n "$NOTES_VAL" ]] && [[ "$MODE" != "record" ]]; then
  echo "ERROR: --result/--model/--notes are only valid with --record" >&2
  exit 2
fi

EVALS_FILE="$ADAPTER_DIR/.agent-os/evals.md"
COMMAND_MAP_FILE="$ADAPTER_DIR/.agent-os/command-map.md"

if [[ ! -f "$EVALS_FILE" ]]; then
  echo "ERROR: evals.md not found: $EVALS_FILE" >&2
  exit 2
fi

# ---- Shared helpers ---------------------------------------------------

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Extract exact-match candidate command strings from a (comment-stripped)
# command-map.md. Two sources, both emitted one candidate per line:
#   (a) every backtick-delimited span (how commands are quoted in the
#       command-map table, e.g. `npm test -- --grep widgets`)
#   (b) every line trimmed of leading "-"/"|"/whitespace and trailing
#       table pipes/whitespace (covers plain bullet-style entries)
# The validation command must equal one of these candidates EXACTLY
# (after trimming) -- a containment/substring match is not enough, since
# a shorter command being a substring of a longer verified one does not
# mean the shorter command itself was ever verified.
command_map_candidates() {
  local content="$1"
  grep -oE '`[^`]+`' <<<"$content" 2>/dev/null | sed -E 's/^`//; s/`$//'
  sed -E '
    s/^[[:space:]]+//
    s/^[-|][[:space:]]*//
    s/[[:space:]]+$//
    s/\|+[[:space:]]*$//
    s/[[:space:]]+$//
  ' <<<"$content"
}

strip_html_comments() {
  # Remove HTML comment blocks (<!-- ... -->, possibly multi-line) before
  # parsing, so the commented-out "Example (delete me)" eval in the
  # template is never treated as a real eval.
  local file="$1"
  awk '
    /<!--/ { in_comment = 1 }
    !in_comment { print }
    /-->/ { in_comment = 0 }
  ' "$file"
}

# List all eval names, in file order. The inner grep is wrapped with
# "|| true" so an evals.md with zero evals (grep exit 1) does not trip
# "set -o pipefail" and abort the script.
list_eval_names() {
  strip_html_comments "$EVALS_FILE" | { grep -E '^## Eval:' || true; } | \
    sed -E 's/^## Eval:[ \t]*//; s/[ \t]+$//'
}

eval_exists() {
  local target="$1"
  list_eval_names | grep -qxF "$target"
}

die_unknown_eval() {
  local target="$1"
  echo "ERROR: no such eval: $target" >&2
  echo "Available evals:" >&2
  list_eval_names | sed 's/^/  - /' >&2
  exit 2
}

# Print the full "## Eval: <name>" block verbatim (up to but excluding the
# next top-level "## " heading, e.g. the next eval or "## Results").
get_eval_block() {
  local target="$1"
  strip_html_comments "$EVALS_FILE" | awk -v target="$target" '
    BEGIN { capturing = 0 }
    /^## Eval:/ {
      name = $0
      sub(/^## Eval:[ \t]*/, "", name)
      gsub(/[ \t]+$/, "", name)
      if (name == target) { capturing = 1; print; next }
      capturing = 0
      next
    }
    /^## / { capturing = 0; next }
    capturing { print }
  '
}

# First bullet under the "Task:" section of an eval block (read on stdin).
get_task_first_bullet() {
  awk '
    /^Task:/ { infield = 1; next }
    infield && /^-/ {
      line = $0
      sub(/^-[ \t]*/, "", line)
      print line
      exit
    }
    infield && /^[[:space:]]*$/ { next }
    infield { exit }
  '
}

# Validation command bullet(s) under the "Validation command:" section of
# an eval block (read on stdin).
get_validation_commands() {
  awk '
    /^Validation command:/ { infield = 1; next }
    infield && /^-/ {
      line = $0
      sub(/^-[ \t]*/, "", line)
      print line
      next
    }
    infield && /^[[:space:]]*$/ { infield = 0; next }
    infield { infield = 0 }
  '
}

# Most recent recorded result for an eval, from the "## Results" table.
# Prints "date\tresult\tmodel" or nothing if never run.
get_latest_result() {
  local target="$1"
  strip_html_comments "$EVALS_FILE" | awk -v target="$target" -F'|' '
    /^## Results/ { in_results = 1; next }
    in_results && /^\|/ {
      date = $2; gsub(/^[ \t]+|[ \t]+$/, "", date)
      ev = $3; gsub(/^[ \t]+|[ \t]+$/, "", ev)
      model = $4; gsub(/^[ \t]+|[ \t]+$/, "", model)
      result = $5; gsub(/^[ \t]+|[ \t]+$/, "", result)
      if (date == "Date" || date ~ /^-+$/) next
      if (ev == target) { last_date = date; last_result = result; last_model = model }
    }
    END {
      if (last_date != "") print last_date "\t" last_result "\t" last_model
    }
  '
}

# ---- Mode: --list -----------------------------------------------------
run_list() {
  local names
  mapfile -t names < <(list_eval_names)
  echo "===== run-agent-evals: $EVALS_FILE ====="
  echo
  if [[ "${#names[@]}" -eq 0 ]]; then
    echo "(no evals defined)"
    echo
    echo "Total evals: 0"
    exit 0
  fi
  local n block task latest date result model
  for n in "${names[@]}"; do
    block="$(get_eval_block "$n")"
    task="$(echo "$block" | get_task_first_bullet)"
    [[ -z "$task" ]] && task="(no Task bullet found)"
    latest="$(get_latest_result "$n")"
    if [[ -z "$latest" ]]; then
      echo "- $n"
      echo "    Task: $task"
      echo "    Last result: never run"
    else
      IFS=$'\t' read -r date result model <<<"$latest"
      echo "- $n"
      echo "    Task: $task"
      echo "    Last result: $result ($date, $model)"
    fi
  done
  echo
  echo "Total evals: ${#names[@]}"
  exit 0
}

# ---- Mode: --show -------------------------------------------------------
run_show() {
  local target="$1"
  eval_exists "$target" || die_unknown_eval "$target"
  get_eval_block "$target"
  exit 0
}

# ---- Mode: --check ------------------------------------------------------
run_check() {
  local target="$1"
  eval_exists "$target" || die_unknown_eval "$target"

  local block
  block="$(get_eval_block "$target")"

  local commands
  mapfile -t commands < <(echo "$block" | get_validation_commands)

  if [[ "${#commands[@]}" -eq 0 ]]; then
    echo "No Validation command found for eval: $target"
    exit 0
  fi

  echo "===== validation command(s) for: $target ====="

  if [[ "$EXEC_FLAG" -eq 0 ]]; then
    local c
    for c in "${commands[@]}"; do
      echo "  - $c"
    done
    echo
    echo "Not executed (pass --exec to run allow-listed commands). Run manually and record the result."
    exit 0
  fi

  # --exec: gate each command against command-map.md before running.
  # The gate is an EXACT match against candidate command strings extracted
  # from command-map.md, not a substring/containment check -- a command
  # that merely happens to be a substring of a longer verified command
  # (e.g. "npm test" vs. a mapped "npm test -- --grep widgets") was never
  # itself verified and must not be allowed to run.
  local overall_fail=0
  local stripped_map=""
  local map_candidates=""
  if [[ -f "$COMMAND_MAP_FILE" ]]; then
    stripped_map="$(strip_html_comments "$COMMAND_MAP_FILE")"
    map_candidates="$(command_map_candidates "$stripped_map")"
  fi

  local c lower c_trimmed
  for c in "${commands[@]}"; do
    lower="$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" == *manual* ]]; then
      echo "MANUAL: $c"
      continue
    fi

    c_trimmed="$(trim "$c")"
    if [[ -z "$stripped_map" ]] || ! grep -qxF -- "$c_trimmed" <<<"$map_candidates"; then
      echo "REFUSED: command does not appear exactly in .agent-os/command-map.md -- run manually after verifying"
      echo "  command: $c"
      overall_fail=1
      continue
    fi

    echo "RUN: $c"
    if bash -c "$c"; then
      echo "PASS: $c"
    else
      local rc=$?
      echo "FAIL (exit $rc): $c"
      overall_fail=1
    fi
  done

  if [[ "$overall_fail" -ne 0 ]]; then
    exit 1
  fi
  exit 0
}

# ---- Mode: --record -------------------------------------------------------
run_record() {
  local target="$1"
  eval_exists "$target" || die_unknown_eval "$target"

  # Symlink safety: --record rewrites evals.md in place (via a temp file
  # + mv). Refuse outright if evals.md is a symlink rather than writing
  # a fresh file over/through it.
  if [[ -L "$EVALS_FILE" ]]; then
    echo "ERROR: refusing to record into $EVALS_FILE: it is a symlink (remove it manually if you want a regular file there)" >&2
    exit 1
  fi

  if [[ "$RESULT_VAL" != "pass" && "$RESULT_VAL" != "fail" ]]; then
    echo "ERROR: --result must be 'pass' or 'fail' (got: '$RESULT_VAL')" >&2
    exit 2
  fi

  if [[ -z "$MODEL_VAL" ]]; then
    echo "ERROR: --model <model-name> is required with --record" >&2
    exit 2
  fi

  # Sanitize notes: strip pipes and newlines so the markdown table stays
  # well-formed.
  local notes="$NOTES_VAL"
  notes="${notes//$'\n'/ }"
  notes="${notes//$'\r'/ }"
  notes="${notes//|/}"

  local today
  today="$(date +%F)"
  local new_row="| $today | $target | $MODEL_VAL | $RESULT_VAL | $notes |"

  local tmp_file
  tmp_file="$(mktemp "${EVALS_FILE}.XXXXXX")"

  awk -v newrow="$new_row" '
    { lines[NR] = $0 }
    END {
      n = NR
      results_line = 0
      for (i = 1; i <= n; i++) {
        if (lines[i] == "## Results") { results_line = i; break }
      }
      if (results_line == 0) {
        for (i = 1; i <= n; i++) print lines[i]
        print ""
        print "## Results"
        print ""
        print "| Date | Eval | Model | Pass/Fail | Notes |"
        print "|------|------|-------|-----------|-------|"
        print newrow
        exit
      }
      for (i = 1; i <= results_line; i++) print lines[i]
      i = results_line + 1
      while (i <= n && lines[i] ~ /^[[:space:]]*$/) { print lines[i]; i++ }
      header_line = 0
      if (i <= n && lines[i] ~ /^\|.*Date.*\|.*Eval.*\|/) header_line = i
      if (header_line > 0) {
        print lines[header_line]
        i++
        if (i <= n && lines[i] ~ /^\|[-| ]+\|$/) { print lines[i]; i++ }
        while (i <= n && lines[i] ~ /^\|/) { print lines[i]; i++ }
        print newrow
        while (i <= n) { print lines[i]; i++ }
      } else {
        print "| Date | Eval | Model | Pass/Fail | Notes |"
        print "|------|------|-------|-----------|-------|"
        print newrow
        while (i <= n) { print lines[i]; i++ }
      }
    }
  ' "$EVALS_FILE" > "$tmp_file"

  mv "$tmp_file" "$EVALS_FILE"

  echo "Recorded: $new_row"
  exit 0
}

case "$MODE" in
  list)
    run_list
    ;;
  show)
    run_show "$MODE_ARG"
    ;;
  check)
    run_check "$MODE_ARG"
    ;;
  record)
    run_record "$MODE_ARG"
    ;;
esac
