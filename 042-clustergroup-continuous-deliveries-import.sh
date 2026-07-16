#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh

# enable has no update verb; tolerate re-runs where CD is already enabled.
export IGNORE_TANZU_ERROR="AlreadyExists"

init "[042] Import the cluster group continuous deliveries"

find . -type f -name '*.yml' | while read -r file; do
  PHASE=`yq '.status.phase' $file`
  if [ $PHASE == "APPLIED" ]; then
    GROUP_NAME=`yq '.fullName.clusterGroupName' $file`
    tanzu tmc continuousdelivery enable -s clustergroup -g $GROUP_NAME
    mark_success "ClusterGroup" "Import" $file
  fi
done
