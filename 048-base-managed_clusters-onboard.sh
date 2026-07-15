#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")"/utils/log.sh
source "$(dirname "${BASH_SOURCE[0]}")"/utils/context.sh
source "$(dirname "${BASH_SOURCE[0]}")"/utils/check-cluster.sh

CLUSTER_DATA_DIR="data/clusters"
MC_LIST_YAML_FILE=$CLUSTER_DATA_DIR/mc_list.yaml
MC_KUBECONFIG_INDEX_FILE=$CLUSTER_DATA_DIR/mc-kubeconfig-index-file
REGISTERED_FILE=$CLUSTER_DATA_DIR/mc_registered.txt
PLACEHOLDER_TEXT="/path/to/the/real/mc_kubeconfig/file"

MIN_VERSION="1.28.0"
ONBOARDED_CLUSTER_INDEX_FILE="$CLUSTER_DATA_DIR/onboarded-clusters-name-index"

# Configuration for parallel processing
CLUSTERS_ONBOARD_BATCH_SIZE=${CLUSTERS_ONBOARD_BATCH_SIZE:-1}

function init () {
  # If the $MC_KUBECONFIG_INDEX_FILE file is NOT completely updated, then stop to proceed.
  if grep -q "$PLACEHOLDER_TEXT" "$MC_KUBECONFIG_INDEX_FILE"; then
    log error "⚠️  Placeholder text '$PLACEHOLDER_TEXT' found in $MC_KUBECONFIG_INDEX_FILE. Please replace it."
    exit 1
  fi

  use_tmc_sm_context
}

# Clean up registration resources and recreate the config.
function prepare_for_vks() {
  namespaces=$(kubectl get ns --no-headers -o custom-columns=":metadata.name" | grep '^svc-tmc-')

  for ns in $namespaces; do
    log info "Checking namespace: $ns"

    # Delete the agentinstall if it exists.
    delete_agent_installs "$ns"

    # Uninstall the pre-installation.
    uninstall_stale_res "$ns"

    # Prepare agent config
    prepare_agent_config "$ns"
  done
}

function prepare_agent_config() {
  local ns="$1"

  if [[ -z $ns ]]; then
    ns=$(kubectl get ns -o custom-columns=":metadata.name" | grep '^svc-tmc-' | head -n 1)
  fi

  # Delete the agent config it exists.
  delete_agent_config "$ns"

  # Create agent config.
  create_agent_config "$ns"
}

function delete_agent_config() {
  local ns="$1"

  # Check and delete AgentConfig if exists
  if kubectl get agentconfig -n "$ns" &>/dev/null; then
    log info "Deleting AgentConfig(s) in $ns..."
    kubectl delete agentconfig --all -n "$ns"
  else
    log info "No AgentConfig in $ns"
  fi
}

function delete_agent_installs() {
  local ns="$1"

  # Check and delete AgentInstall if exists
  if kubectl get agentinstall -n "$ns" &>/dev/null; then
    log info "🧹 Deleting AgentInstall(s) in $ns..."
    kubectl delete agentinstall --all -n "$ns"
  else
    log info "No AgentInstall in $ns"
  fi
}

function create_agent_config() {
  local namespace="$1"
  local TMC_SM_CONTEXT="tmc-sm"

  local ENDPOINT DOMAIN CA_CERTIFICATE
  ENDPOINT=$(tanzu context get "$TMC_SM_CONTEXT" | yq .globalOpts.endpoint)
  DOMAIN=$(echo "$ENDPOINT" | cut -d':' -f1)
  CA_CERTIFICATE=$(openssl s_client -connect $ENDPOINT -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM)

  cat <<EOF | kubectl apply -f -
apiVersion: "installers.tmc.cloud.vmware.com/v1alpha1"
kind: "AgentConfig"
metadata:
  name: "tmc-agent-config"
  namespace: "$namespace"
spec:
  caCerts: |-
$(echo "$CA_CERTIFICATE" | sed 's/^/    /')
  allowedHostNames:
    - $DOMAIN
EOF

  log info "Created AgentConfig tmc-agent-config in $namespace for $DOMAIN"
}

function uninstall_stale_res() {
  local namespace="$1"

  log info "Apply uninstall operation"

  cat <<EOF | kubectl apply -f -
apiVersion: installers.tmc.cloud.vmware.com/v1alpha1
kind: AgentInstall
metadata:
  name: tmc-agent-installer-config
  namespace: "$namespace"
spec:
  operation: UNINSTALL
EOF

  wait_for_pods_cleaned $namespace

  # Wait until the agent installer config is deleted by the tmc-agent-installer
  log info "Wait until the uninstall operation is successfully completed"
  kubectl wait --for=delete agentinstall/tmc-agent-installer-config -n $namespace --timeout 3m
}

function wait_for_pods_cleaned() {
  local namespace="$1"

  TIMEOUT_SECONDS=300 # 5 minutes
  SLEEP_INTERVAL=5

  log info "Waiting for all pods in namespace '$namespace' to terminate..."

  elapsed=0
  while true; do
    # Get number of pods
    pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -v '^tmc-agent-installer-' | wc -l)

    # If no pods, break the loop
    if [[ "$pod_count" -eq 0 ]]; then
      log info "All pods in namespace '$namespace' are gone."
      break
    fi

    if [[ "$elapsed" -ge "$TIMEOUT_SECONDS" ]]; then
      log info "Timeout reached. Still $pod_count pod(s) remaining in namespace '$namespace'."
      exit 1
    fi

    log info "$pod_count pod(s) remaining... waited ${elapsed}s"

    sleep "$SLEEP_INTERVAL"
    ((elapsed += SLEEP_INTERVAL))

  done
}

wait_for_mc_healthy() {
  local mgmt_cluster="$1"
  local INTERVAL=10
  local TIMEOUT=600

  log info "Waiting for the management cluster '$mgmt_cluster' to become healthy"

  local start_time
  start_time=$(date +%s)

  while true; do
    local health
    health=$(tanzu tmc mc get $mgmt_cluster -o yaml | yq '.status.health // "UNKNOWN"')

    # Exit if the management cluster has already been healthy.
    if [[ $health == "HEALTHY" ]]; then
      log info "Management cluster '$mgmt_cluster' is HEALTHY"
      return 0
    fi

    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))

    if ((elapsed >= TIMEOUT)); then
      log info "Timeout reached after $elapsed seconds. Exiting with failure."
      return 1
    fi

    log info "Management cluster healthy status is '$health'. Waiting $INTERVAL seconds..."
    sleep "$INTERVAL"
  done
}


function onboard_mgmt_clusters() {
  # Reset tracking file
  : >"$REGISTERED_FILE"

  # Iterate through clusters
  local total
  total=$(yq '.managementClusters | length' $MC_LIST_YAML_FILE)

  for ((index=0; index<total; index+=1)); do
    local name health
    name=$(yq ".managementClusters[$index].fullName.name" $MC_LIST_YAML_FILE)
    health=$(yq ".managementClusters[$index].status.health" $MC_LIST_YAML_FILE)

    if [ "$health" == "HEALTHY" ] && [[ "$name" != "aks" && "$name" != "eks" && "$name" != "attached" ]]; then
      orgId=$(yq ".managementClusters[$index].fullName.orgId" $MC_LIST_YAML_FILE)
      file="$CLUSTER_DATA_DIR/mc_${orgId}_${name}.yaml"

      log info "Processing mc $name [health=$health]"

      # Save cluster data without .status field.
      yq "del(.managementClusters[$index].status) | .managementClusters[$index]" $MC_LIST_YAML_FILE >"$file"
      # Remove orgId.
      yq -i 'del(.fullName.orgId)' $file

      # Look up the kubeconfig file path from the provided index file
      local KUBECONFIG_PATH
      KUBECONFIG_PATH=$(grep "^$name:" "$MC_KUBECONFIG_INDEX_FILE" | awk '{print $2}')

      export KUBECONFIG=$KUBECONFIG_PATH

      # Register the cluster using cli.
      local provider proxy_name image_registry
      provider=$(yq .spec.kubernetesProviderType "$file")
      proxy_name=$(yq .spec.proxyName "$file")
      image_registry=$(yq .spec.imageRegistry "$file")

      local MGMT_YAML phase health
      MGMT_YAML=$(tanzu tmc mc get $name)
      phase=$(echo "$MGMT_YAML" | yq '.status.phase // "UNKNOWN"')
      health=$(echo "$MGMT_YAML" | yq '.status.health // "UNKNOWN"')

      set -e
      if [[ "$health" == "HEALTHY" ]]; then
        log info "Management cluster '$name' is HEALTHY, skip onboarding management cluster"
      elif [[ $health == "DISCONNECTED" || "$phase" == "PENDING" ]]; then
        if [[ $provider == "VMWARE_TANZU_KUBERNETES_GRID_SERVICE" ]]; then
          log info "Setup configurations for management cluster $name"
          prepare_agent_config
        fi

        log info "Reregister management cluster '$name'"
        tanzu tmc mc reregister "$name" --use-proxy --proxy-name "$proxy_name" --image-registry "$image_registry" --kubeconfig "$KUBECONFIG_PATH"
      else
        if [[ "$phase" == "READY_TO_ATTACH" ]]; then
          log info "Deregister management cluster '$name'"
          tanzu tmc mc deregister "$name" --kubeconfig "$KUBECONFIG_PATH" --force
        fi

        if [[ $provider == "VMWARE_TANZU_KUBERNETES_GRID_SERVICE" ]]; then
          # Prepare.
          log info "Setup configurations for management cluster $name"
          prepare_for_vks
        fi

        log info "Register management cluster '$name'"
        tanzu tmc mc register "$name" -f "$file" --kubeconfig "$KUBECONFIG_PATH"
      fi
      set +e

      if [[ "$health" != "HEALTHY" ]]; then
        # Wait for the registered MC is healthy.
        if ! wait_for_mc_healthy "$name"; then
          log error "Management cluster '$name' is not ready, exit ..."
          exit 1
        fi
      fi

      # Track the name of successfully registered management cluster for later use.
      if ! grep -qxF "$name" "$REGISTERED_FILE"; then
        echo "$name" >>"$REGISTERED_FILE"
      fi
    fi
  done
}

# Strip v prefix and metadata from version (e.g., v1.29.4+ -> 1.29.4)
sanitize_version() {
  echo "$1" | sed -E 's/^v//' | cut -d'+' -f1
}

compare_versions() {
  # Returns 0 if $1 >= $2
  [ "$(printf "%s\n%s" "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

onboard_workload_cluster() {
  local wc_file="$1"
  local i="$2"
  local name mgmt prov group proxy registry
  name=$(yq eval ".clusters[$i].fullName.name" "$wc_file")
  mgmt=$(yq eval ".clusters[$i].fullName.managementClusterName" "$wc_file")
  prov=$(yq eval ".clusters[$i].fullName.provisionerName" "$wc_file")
  group=$(yq eval ".clusters[$i].spec.clusterGroupName" "$wc_file")
  proxy=$(yq eval ".clusters[$i].spec.proxyName // \"\"" "$wc_file")
  registry=$(yq eval ".clusters[$i].spec.imageRegistry // \"\"" "$wc_file")

  local version clean_version
  version=$(yq eval ".clusters[$i].spec.topology.version" "$wc_file")
  clean_version=$(sanitize_version "$version")
  if ! compare_versions "$clean_version" "$MIN_VERSION"; then
    log warn "Skipping: the version '$version' of cluster '$name' in namespace '$prov' is NOT supported (< v$MIN_VERSION)"
    return 0
  fi

  # Build the command
  local cmd
  cmd="tanzu tmc mc wc manage \"$name\" -m \"$mgmt\" -p \"$prov\" --cluster-group \"$group\""
  [[ -n "$proxy" ]] && cmd+=" --proxy-name \"$proxy\""
  [[ -n "$registry" ]] && cmd+=" --image-registry \"$registry\""

  log info "Run $cmd"
  if ! eval "$cmd"; then
    log error "❌ Failed to manage $name, please re-run this script later (required)"
    return 1
  fi

  # Record the managed cluster immediately so the final readiness check (049)
  # covers it even if it is not READY yet.
  local onboarded_cluster_name="$mgmt.$prov.$name"
  if ! grep -qxF "$onboarded_cluster_name" "$ONBOARDED_CLUSTER_INDEX_FILE"; then
    echo "$onboarded_cluster_name" >>"$ONBOARDED_CLUSTER_INDEX_FILE"
  fi

  # Wait for readiness (best-effort). Return non-zero on timeout so the caller
  # can pause for investigation; the cluster stays recorded regardless.
  if wait_cluster_ready "$mgmt" "$prov" "$name"; then
    return 0
  else
    log error "❌ Cluster $name is not READY yet (managed and recorded; see pause below)"
    return 1
  fi
}

# Pause after a batch when one or more clusters are managed but not READY yet.
# The clusters are already recorded in $ONBOARDED_CLUSTER_INDEX_FILE, so the final
# readiness check (049) will verify them regardless of the choice made here.
function handle_not_ready_clusters() {
  local clusters=("$@")
  local choice c m p n

  while true; do
    log warn "⚠️  ${#clusters[@]} managed cluster(s) are not READY yet:"
    for c in "${clusters[@]}"; do
      log warn "    - $c  (management.provisioner.cluster)"
    done

    # Don't block automation when there is no interactive terminal.
    if [[ ! -t 0 ]]; then
      log warn "No interactive terminal detected; continuing. The final readiness check (049) will verify these clusters."
      return 0
    fi

    echo "" >&2
    echo "Investigate the cluster(s) in TMC-SM, then choose an action:" >&2
    echo "  [Enter] re-check readiness now   [c] continue   [q] quit" >&2
    read -r choice

    case "$choice" in
      ""|r|R)
        local still_not_ready=()
        for c in "${clusters[@]}"; do
          IFS='.' read -r m p n <<< "$c"
          if is_cluster_ready "$m" "$p" "$n"; then
            log info "✅ Cluster $n is now READY"
          else
            still_not_ready+=("$c")
          fi
        done
        if [[ ${#still_not_ready[@]} -eq 0 ]]; then
          log info "All previously not-ready clusters are now READY"
          return 0
        fi
        clusters=("${still_not_ready[@]}")
        ;;
      c|C)
        log warn "Continuing. Not-ready clusters remain recorded; the final readiness check (049) will verify them."
        return 0
        ;;
      q|Q)
        log error "Aborting onboarding at user request."
        exit 1
        ;;
      *)
        echo "Unrecognized choice: '$choice'" >&2
        ;;
    esac
  done
}

function onboard_workload_clusters () {
  # Ensure the index file exists before grepping
  [ -f "$ONBOARDED_CLUSTER_INDEX_FILE" ] || touch "$ONBOARDED_CLUSTER_INDEX_FILE"

  # Read management cluster name from $REGISTERED_FILE.
  while IFS= read -r mc_name; do
    local wc_file
    wc_file="$CLUSTER_DATA_DIR/wc_of_${mc_name}.yaml"

    if [[ ! -f "$wc_file" ]]; then
      log warn "File $wc_file not found. Skipping..."
      continue
    fi

    # Remove orgId first
    yq -i '(.clusters[] | .fullName) |= del(.orgId)' "$wc_file"

    # Count how many workload clusters exist in the file
    cluster_count=$(yq eval '.clusters | length' "$wc_file")
    log info "Processing $cluster_count clusters in parallel batches of $CLUSTERS_ONBOARD_BATCH_SIZE"
  
    local batch_num=0
    for ((start=0; start<cluster_count; start+=CLUSTERS_ONBOARD_BATCH_SIZE)); do
      batch_num=$((batch_num + 1))
      local end=$((start + CLUSTERS_ONBOARD_BATCH_SIZE - 1))
      if [[ $end -ge $cluster_count ]]; then
        end=$((cluster_count - 1))
      fi
      
      log info "Processing batch $batch_num: clusters $((start + 1))-$((end + 1)) of $cluster_count"
      local pids=()
      local pid_names=()
      for ((i=start; i<=end; i++)); do
        # Start the cluster processing in background
        onboard_workload_cluster "$wc_file" "$i" &
        pids+=($!)
        pid_names+=("$(yq eval ".clusters[$i].fullName.managementClusterName" "$wc_file").$(yq eval ".clusters[$i].fullName.provisionerName" "$wc_file").$(yq eval ".clusters[$i].fullName.name" "$wc_file")")
      done

      local failed_clusters=()
      local pi=0
      for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
          failed_clusters+=("${pid_names[$pi]}")
        fi
        pi=$((pi + 1))
      done

      if [[ ${#failed_clusters[@]} -gt 0 ]]; then
        log warn "Batch $batch_num completed with ${#failed_clusters[@]} not-ready cluster(s) out of $((end - start + 1))"
        # Pause for investigation; clusters are already recorded for the final check.
        handle_not_ready_clusters "${failed_clusters[@]}"
      else
        log info "Batch $batch_num completed successfully"
      fi
    done
    
    log info "All clusters processing completed for management cluster: $mc_name"
  done <$REGISTERED_FILE
  
  log info "All management clusters processing completed"
}

function main() {
  init

  # Register the management clusters.
  onboard_mgmt_clusters

  # Manage the workload clusters.
  onboard_workload_clusters
}

main
