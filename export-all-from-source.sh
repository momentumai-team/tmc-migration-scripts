#!/bin/bash

set -euo pipefail

# Simple runner to execute scripts 002 through 030 in order.
# Usage:
#   ./export-all-from-source.sh            # stop on first error
#   ./export-all-from-source.sh --continue-on-error
#
# Notes:
# - Assumes prerequisites are met (e.g., 001-base-source_stack-connect.sh already run).
# - Stops on first failure by default. Use --continue-on-error to keep going.

CONTINUE_ON_ERROR=false
if [[ "${1:-}" == "--continue-on-error" ]]; then
  CONTINUE_ON_ERROR=true
fi

shopt -s nullglob

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Initialize arrays explicitly to avoid unbound with set -u on some shells
SUCCESS_LIST=()
FAIL_LIST=()
MISSING_LIST=()

print_summary() {
  echo "Summary:"
  echo "  Success: ${#SUCCESS_LIST[@]}"
  if ((${#SUCCESS_LIST[@]})); then
    for s in "${SUCCESS_LIST[@]}"; do echo "    - $s"; done
  fi
  echo "  Failed: ${#FAIL_LIST[@]}"
  if ((${#FAIL_LIST[@]})); then
    for f in "${FAIL_LIST[@]}"; do echo "    - $f"; done
  fi
  echo "  Skipped (not found): ${#MISSING_LIST[@]}"
  if ((${#MISSING_LIST[@]})); then
    for m in "${MISSING_LIST[@]}"; do echo "    - $m"; done
  fi
}

start_ts=$(date +%s)
echo "Running scripts 002..030"

for i in $(seq -w 002 030); do
  pattern="${i}-*.sh"
  scripts=(./$pattern)
  # Ensure deterministic order when multiple scripts match the same prefix
  IFS=$'\n' scripts=($(printf '%s\n' "${scripts[@]}" | sort))
  if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "[$i] No script found matching $pattern, skipping"
    MISSING_LIST+=("$pattern")
    continue
  fi

  for script in "${scripts[@]}"; do
    echo "[$i] >>> $script"
    ts=$(date +%s)
    if $CONTINUE_ON_ERROR; then
      set +e
      bash "$script"
      exit_code=$?
      set -e
      if [[ $exit_code -ne 0 ]]; then
        echo "[$i] !!! $script exited with code $exit_code (continuing)"
        FAIL_LIST+=("$script (code $exit_code)")
      else
        echo "[$i] <<< Completed in $(( $(date +%s) - ts ))s"
        SUCCESS_LIST+=("$script")
      fi
    else
      set +e
      bash "$script"
      exit_code=$?
      set -e
      if [[ $exit_code -ne 0 ]]; then
        echo "[$i] !!! $script exited with code $exit_code"
        FAIL_LIST+=("$script (code $exit_code)")
        echo
        print_summary
        echo "All done (stopped on error) in $(( $(date +%s) - start_ts ))s"
        exit $exit_code
      fi
      echo "[$i] <<< Completed in $(( $(date +%s) - ts ))s"
      SUCCESS_LIST+=("$script")
    fi
  done
done

echo
print_summary
echo "All done in $(( $(date +%s) - start_ts ))s"

# In continue-on-error mode, return non-zero if any failures occurred
if $CONTINUE_ON_ERROR && [[ ${#FAIL_LIST[@]} -gt 0 ]]; then
  exit 1
fi