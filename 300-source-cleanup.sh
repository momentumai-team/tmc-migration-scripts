#!/bin/bash

# TMC SM source → SM destination migration
# This script runs one phase of a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# 300 — Source-side cleanup wrapper (INTERACTIVE, DESTRUCTIVE)
#
# Combines the two source-side cleanup scripts behind an interactive,
# preview-then-confirm gate:
#
#   070-cluster-source-cleanup.sh      per-WC cluster-scoped CD orphans (Tier 1)
#   071-clustergroup-source-cleanup.sh non-prod cluster-group teardown  (Tier 2)
#
# Both delete on the SURVIVING production source TMC SM. This wrapper never
# deletes anything on its own — for each phase it first runs the underlying
# script as a DRY RUN, prints exactly what would be deleted, and only then asks
# the operator to type the target name to authorize the real delete. Typing
# anything else SKIPS that phase. If stdin is not a terminal, both phases are
# left as dry runs (fail-safe).
#
# The two phases run at different points in the per-cluster runbook:
#   * Phase 070 — after each WC is verified healthy in the destination, while
#     the source MC is still registered.
#   * Phase 071 — only once every non-prod WC is drained and the source MC has
#     been deregistered (031 with TMC_DEREGISTER_MC=true). Run before then and
#     071 will refuse (fail-closed) any group that still has live members — that
#     refusal is expected, just skip Phase 071 until the final pass.
# You can run this wrapper at either point and skip the phase that does not
# apply yet.
#
# Usage:
#   ./300-source-cleanup.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
#
# Example:
#   ./300-source-cleanup.sh admin 'p@ss' tmc.source.example.com non-prod-mgr dev2 dev
#
# Positional arguments:
#   $1  TMC_SOURCE_USERNAME   Username for the source TMC SM stack.
#   $2  TMC_SOURCE_PASSWORD   Password for the source TMC SM stack (not echoed).
#   $3  TMC_SOURCE_DNS        DNS hostname of the source TMC SM stack.
#   $4  TMC_MC_FILTER         Management-cluster name filter (Phase 070 guard).
#   $5  TMC_WC_FILTER         Workload-cluster name filter   (Phase 070 target).
#   $6  TMC_CG_FILTER         Cluster-group name filter      (Phase 071 target).
#
# Additional env vars:
#   TMC_SOURCE_IDP_MFA_ENABLED  Defaults to false. Set true if the source IDP
#                               requires MFA during login.
#
# Like the other source-side orchestrators, this establishes the 'migration'
# tanzu CLI context against the source stack (via 001) before doing any work.
# -----------------------------------------------------------------------------

uname -a
echo "PWD=$PWD"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Usage check: ensure all required arguments are provided before doing any work.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
  echo "ERROR: missing required arguments." >&2
  echo "Usage:   $0 <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>" >&2
  echo "Example: $0 admin 'p@ss' tmc.source.example.com non-prod-mgr dev2 dev" >&2
  exit 1
fi

export TMC_SOURCE_USERNAME="$1"
export TMC_SOURCE_PASSWORD="$2"
export TMC_SOURCE_DNS="$3"
export TMC_SOURCE_IDP_MFA_ENABLED="${TMC_SOURCE_IDP_MFA_ENABLED:-false}"
export TMC_MC_FILTER="$4"
export TMC_WC_FILTER="$5"
export TMC_CG_FILTER="$6"

export TANZU_CLI_CEIP_OPT_IN_PROMPT_ANSWER=no

# Connect to the source TMC SM stack — create the 'migration' tanzu CLI context.
echo "Environment variables needed:"
echo "TMC_SOURCE_USERNAME=$TMC_SOURCE_USERNAME"
echo "TMC_SOURCE_DNS=$TMC_SOURCE_DNS"
echo "TMC_SOURCE_IDP_MFA_ENABLED=${TMC_SOURCE_IDP_MFA_ENABLED:-false}"
# Note: TMC_SOURCE_PASSWORD is intentionally not echoed.

tanzu config eula accept
"$SCRIPT_DIR"/001-base-source_stack-connect.sh

echo "============================================================================"
echo " ⚠️  SOURCE-SIDE CLEANUP — DESTRUCTIVE, runs against the PRODUCTION source"
echo "============================================================================"
echo "   TMC_MC_FILTER = $TMC_MC_FILTER"
echo "   TMC_WC_FILTER = $TMC_WC_FILTER   (Phase 070 — per-WC CD orphans)"
echo "   TMC_CG_FILTER = $TMC_CG_FILTER   (Phase 071 — cluster-group teardown)"
echo
echo "   Each phase previews its deletes (dry run) and then asks you to type the"
echo "   target name to authorize the real delete. Type anything else to skip."
echo

# run_phase <phase-label> <expected-confirm-token> <target-description> <cleanup-script> [extra env assignments...]
#
# 1. Runs <cleanup-script> as a DRY RUN (TMC_CLEANUP_SOURCE=false) so the
#    operator sees exactly what would be deleted.
# 2. Prompts for confirmation. Applies (TMC_CLEANUP_SOURCE=true) only if the
#    operator types <expected-confirm-token> exactly. Non-tty stdin => skip.
run_phase() {
  local label="$1"; shift
  local token="$1"; shift
  local target="$1"; shift
  local script="$1"; shift

  echo
  echo "----------------------------------------------------------------------------"
  echo " Phase ${label} — DRY RUN preview (nothing is deleted yet)"
  echo "----------------------------------------------------------------------------"
  TMC_CLEANUP_SOURCE=false "$script"
  local dry_rc=$?
  if [ $dry_rc -ne 0 ]; then
    echo "⚠️  Phase ${label} dry run exited non-zero (rc=$dry_rc). Skipping apply for safety." >&2
    return 1
  fi

  if [ ! -t 0 ]; then
    echo "ℹ️  stdin is not a terminal — leaving Phase ${label} as a dry run (no deletes)."
    return 0
  fi

  echo
  echo " Phase ${label} targets: ${target}"
  local answer
  read -r -p " To APPLY these deletes on the SOURCE, type '${token}' exactly (anything else skips): " answer
  if [ "$answer" != "$token" ]; then
    echo "⏭️  Skipped Phase ${label} (got '${answer}', expected '${token}')."
    return 0
  fi

  echo
  echo "----------------------------------------------------------------------------"
  echo " Phase ${label} — APPLYING deletes"
  echo "----------------------------------------------------------------------------"
  TMC_CLEANUP_SOURCE=true "$script"
  local apply_rc=$?
  if [ $apply_rc -ne 0 ]; then
    echo "⚠️  Phase ${label} apply exited non-zero (rc=$apply_rc) — review the output above." >&2
    return 1
  fi
  echo "✅ Phase ${label} apply complete."
  return 0
}

# Phase 070 — per-WC cluster-scoped CD orphans. Confirm token is the WC filter.
run_phase "070 (per-WC CD orphans)" "$TMC_WC_FILTER" "workload cluster(s) '$TMC_WC_FILTER'" \
  "$SCRIPT_DIR/070-cluster-source-cleanup.sh"

# Phase 071 — cluster-group teardown. Confirm token is the CG filter. Refuses
# (fail-closed) any group that still has live members, so it is safe to preview
# even mid-migration.
run_phase "071 (cluster-group teardown)" "$TMC_CG_FILTER" "cluster group(s) '$TMC_CG_FILTER'" \
  "$SCRIPT_DIR/071-clustergroup-source-cleanup.sh"

echo
echo "============================================================================"
echo " Source-side cleanup wrapper finished."
echo "============================================================================"
