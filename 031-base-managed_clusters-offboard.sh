#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR"/utils/context.sh
source "$SCRIPT_DIR"/utils/filter.sh

use_tmc_source_context

MC_LIST_FOLDER=data/clusters
MC_LIST_FILE=$MC_LIST_FOLDER/mc_list.yaml

MATCHED_MC=$(yq -r '.managementClusters[].fullName.name' $MC_LIST_FILE)

# TMC_DEREGISTER_MC must be explicitly "true" to allow MC deregistration. The
# safe default is to unmanage workload clusters only — deregistering an MC is
# the "we're done with this whole supervisor" step and intentionally requires
# a separate confirmation pass.
DEREGISTER_REQUESTED="${TMC_DEREGISTER_MC:-false}"

# Returns 0 if $1 matches the comma-separated filter in $2, 1 otherwise. Empty
# filter means "match everything".
name_matches_filter() {
  local name="$1"
  local filter="$2"
  if [[ -z "$filter" ]]; then
    return 0
  fi
  local pattern
  pattern=$(build_filter_pattern "$filter")
  [[ "$name" =~ ^(${pattern})$ ]]
}

wait_for_unmanaged() {
  local mgmt_cluster="$1"
  local INTERVAL=10
  local TIMEOUT=600

  echo "Waiting for all clusters in management cluster '$mgmt_cluster' to become unmanaged..."

  local start_time
  start_time=$(date +%s)

  while true; do
    local output
    local count

    output=$(tanzu tmc cluster list -m $mgmt_cluster)
    count=$(echo "$output" | tail -n +2 | grep -v '^[[:space:]]*$' | wc -l)

    # Exit if no clusters are returned.
    if [ "$count" -eq 0 ]; then
      echo "No tmcManaged clusters found. Exiting successfully."
      return 0
    fi

    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))

    if (( elapsed >= TIMEOUT )); then
      echo "Timeout reached after $elapsed seconds. Exiting with failure."
      return 1
    fi

    echo "Found $count TMC managed cluster(s). Waiting $INTERVAL seconds..."
    sleep "$INTERVAL"
  done
}

# Enforce the rule "every workload cluster currently managed by the supervisor
# MC must be present in the exported wc_of_<mc>.yaml before deregister." This
# is the safety net against an operator running 031-export with TMC_WC_FILTER
# (or against a stale export) and then asking to deregister.
verify_complete_for_deregister() {
  local mc="$1"
  local wc_export_file="$MC_LIST_FOLDER/wc_of_$mc.yaml"

  if [[ ! -f "$wc_export_file" ]]; then
    echo "❌ Cannot deregister $mc: exported workload cluster list $wc_export_file is missing."
    echo "   Run 031-base-managed_clusters-export.sh (without TMC_WC_FILTER) first."
    return 1
  fi

  local live_wcs
  live_wcs=$(tanzu tmc cluster list -m "$mc" | tail -n +2 | awk '{print $1}' | grep -v '^$' || true)

  if [[ -z "$live_wcs" ]]; then
    echo "No live workload clusters under $mc — deregister allowed."
    return 0
  fi

  local exported_wcs
  exported_wcs=$(yq -r '.clusters[].fullName.name' "$wc_export_file" 2>/dev/null | grep -vx 'null' | grep -v '^$' || true)

  local missing=()
  while IFS= read -r wc; do
    [[ -z "$wc" ]] && continue
    if ! printf '%s\n' "$exported_wcs" | grep -qx "$wc"; then
      missing+=("$wc")
    fi
  done <<< "$live_wcs"

  if (( ${#missing[@]} > 0 )); then
    echo "❌ Cannot deregister $mc: workload cluster(s) live under the MC but absent from $wc_export_file:"
    for wc in "${missing[@]}"; do echo "    - $wc"; done
    echo "   Re-run 031-base-managed_clusters-export.sh (without TMC_WC_FILTER) before retrying with TMC_DEREGISTER_MC=true."
    return 1
  fi

  echo "✅ Every live workload cluster under $mc is present in $wc_export_file."
  return 0
}

# Unmanage workload clusters under each management cluster, respecting
# TMC_WC_FILTER. Deregister of the MC itself is gated on TMC_DEREGISTER_MC=true
# and a completeness check.
for name in $MATCHED_MC; do
  echo "Unmanaging workload clusters under mc $name"

  if [[ -n "$TMC_WC_FILTER" ]]; then
    echo "  TMC_WC_FILTER=$TMC_WC_FILTER (only matching workload clusters will be unmanaged)"
  fi

  # Snapshot the live list once so we can iterate safely in a single shell
  # (avoiding the subshell-variable trap of `... | while read`).
  WC_LINES=$(tanzu tmc cluster list -m "$name" | tail -n +2 | awk '{print $1, $2, $3}')
  while read -r wc_name mgmt prov; do
    [[ -z "$wc_name" ]] && continue
    if ! name_matches_filter "$wc_name" "$TMC_WC_FILTER"; then
      echo "  Skipping workload cluster $wc_name (not in TMC_WC_FILTER)"
      continue
    fi
    echo "  Unmanaging workload cluster $wc_name"
    tanzu tmc mc wc unmanage "$wc_name" -m "$mgmt" -p "$prov"
  done <<< "$WC_LINES"

  if [[ "$DEREGISTER_REQUESTED" != "true" ]]; then
    echo "Skipping deregister of $name (TMC_DEREGISTER_MC is not 'true')."
    continue
  fi

  if [[ -n "$TMC_WC_FILTER" ]]; then
    echo "❌ Refusing to deregister $name: TMC_WC_FILTER is set, which means only a subset of workload clusters were targeted."
    echo "   Deregister implies the entire MC is done — re-run without TMC_WC_FILTER once every workload cluster has been migrated."
    exit 1
  fi

  if ! verify_complete_for_deregister "$name"; then
    exit 1
  fi

  echo "Wait to ensure all the workload clusters are unmanaged from management cluster $name before deregister it"
  if ! wait_for_unmanaged "$name"; then
    echo "⏰ Timeout waiting for all workload clusters unmanaged from management cluster $name."
    exit 1
  fi
  echo "✅ All clusters unmanaged or none found under management cluster $name."

  echo "Deregister management cluster $name"
  tanzu tmc mc deregister "$name"
done
