#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh

# enable has no update verb; tolerate re-runs where helm is already enabled.
export IGNORE_TANZU_ERROR="AlreadyExists"

init "[057] Import the cluster helms"

find . -type f -name '*.yml' | while read -r file; do
  if is_clustergroup_derived "$file"; then
    log info "Skipping cluster-group-derived $(basename "$file"); managed at cluster-group scope"
    continue
  fi
  REASON=`yq '.status.conditions.Ready.reason' $file`
  if [ $REASON == "Enabled" ] || [ $REASON == "Enabling" ]; then
    set +e
    check_onboarded_cluster_for_yaml $file

    if [ $? -eq 1 ]; then
      set -e
      CLUSTER_NAME=`yq '.fullName.clusterName' $file`
      MGMT_CLUSTER_NAME=`yq '.fullName.managementClusterName' $file`
      PROVISIONER_NAME=`yq '.fullName.provisionerName' $file`
      tanzu tmc helm enable -s cluster -m $MGMT_CLUSTER_NAME -p $PROVISIONER_NAME -c $CLUSTER_NAME
      mark_success "Cluster" "Import" $file
    fi
  fi
done
