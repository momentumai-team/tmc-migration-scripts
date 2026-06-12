#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[015] Export the cluster group kustomizations" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterGroupName' "$TMC_CG_FILTER")
tanzu tmc continuousdelivery ks list -s clustergroup -o yaml | yq ".kustomizations[] | $FILTER" -s '.fullName.clusterGroupName + "_" + .fullName.name'
