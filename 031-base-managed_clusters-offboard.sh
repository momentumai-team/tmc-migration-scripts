#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/utils/context.sh

use_tmc_source_context

MC_LIST_FOLDER=data/clusters
MC_LIST_FILE=$MC_LIST_FOLDER/mc_list.yaml

MATCHED_MC=$(yq -r '.managementClusters[].fullName.name' $MC_LIST_FILE)

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

#Unmanage all the workload clusters under the management cluster before deregister.
for name in $MATCHED_MC; do
    echo "Unmanaging workload clusters under mc $name"
    tanzu tmc cluster list -m "$name" | tail -n +2 | awk '{print $1, $2, $3}' | while read wc_name mgmt prov; do
        echo "Unmanging workload cluster $wc_name"
        tanzu tmc mc wc unmanage "$wc_name" -m "$mgmt" -p "$prov"
    done

    # Deregister the management cluster.
    echo "Wait to ensure all the workload clusters are unmanaged from management cluster $name before deregister it"
    wait_for_unmanaged $name
    if [[ $? -eq 0 ]]; then
        echo "✅ All clusters unmanaged or none found under management cluster $name."
    else
        echo "⏰ Timeout waiting for all workload clusters unmanaged from management cluster $name."
        exit 1
    fi

    echo "Deregister management cluster $name"
    tanzu tmc mc deregister "$name"
done