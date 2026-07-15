#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/log.sh
source "$(dirname "${BASH_SOURCE[0]}")"/sm-api-call.sh

wait_cluster_ready() {
  local management_cluster=$1
  local provisioner=$2
  local cluster=$3

  local START_TIME
  START_TIME=$(date +%s)

  local TIMEOUT=600
  if [[ -n "$CLUSTER_ONBOARD_TIMEOUT" ]]; then
    TIMEOUT=$CLUSTER_ONBOARD_TIMEOUT
  fi

  log info "Checking cluster: $cluster (management_cluster: $management_cluster, provisioner: $provisioner) ..."

  while true; do
    local now elapsed
    now=$(date +%s)
    elapsed=$((now - START_TIME))

    if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
      log error "❌ Timeout reached. Cluster $cluster is not READY."
      return 1
    fi

    cluster_api="v1alpha1/clusters/$cluster?full_name.managementClusterName=$management_cluster&full_name.provisionerName=$provisioner"
    output=$(curl_api_call $cluster_api 2>/dev/null || true)

    if [[ -z "$output" ]]; then
      log warn "Failed to get cluster info for $cluster"
    else
      local health phase
      health=$(echo "$output" | yq '.cluster.status.health // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
      phase=$(echo "$output" | yq '.cluster.status.phase // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
      log info "Cluster '$cluster' health: $health, phase: $phase"
      if [[ "$health" == "HEALTHY" && "$phase" == "READY" ]]; then
        return 0
      fi
    fi
    sleep 20s
  done
}

# Single-shot readiness check (no waiting). Returns 0 if HEALTHY+READY, else 1.
is_cluster_ready() {
  local management_cluster=$1
  local provisioner=$2
  local cluster=$3

  local cluster_api output health phase
  cluster_api="v1alpha1/clusters/$cluster?full_name.managementClusterName=$management_cluster&full_name.provisionerName=$provisioner"
  output=$(curl_api_call $cluster_api 2>/dev/null || true)
  if [[ -z "$output" ]]; then
    log warn "Failed to get cluster info for $cluster"
    return 1
  fi

  health=$(echo "$output" | yq '.cluster.status.health // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
  phase=$(echo "$output" | yq '.cluster.status.phase // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
  log info "Cluster '$cluster' health: $health, phase: $phase"
  [[ "$health" == "HEALTHY" && "$phase" == "READY" ]]
}
