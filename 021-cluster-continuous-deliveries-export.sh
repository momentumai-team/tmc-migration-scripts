#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[021] Export the cluster continuous deliveries" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterName' "$TMC_WC_FILTER")
tanzu tmc continuousdelivery list -s cluster -o yaml | yq ".continuousDeliveries[] | $FILTER" -s '.fullName.managementClusterName + "_" + .fullName.provisionerName + "_" + .fullName.clusterName'
