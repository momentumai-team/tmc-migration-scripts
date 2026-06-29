#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[025] Export the cluster helms" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterName' "$TMC_WC_FILTER")
tanzu tmc helm list -s cluster -p '*' -m '*' -o yaml | yq ".helms[] | $FILTER" -s '.fullName.managementClusterName + "_" + .fullName.provisionerName + "_" + .fullName.clusterName'
