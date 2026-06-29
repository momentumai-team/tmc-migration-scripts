#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[020] Export the cluster secret exports" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterName' "$TMC_WC_FILTER")
tanzu tmc secret export list -s cluster -o yaml | \
yq ".secretExports[] | $FILTER" -s '.fullName.managementClusterName + "_" + .fullName.provisionerName + "_" + .fullName.clusterName + "_" + .fullName.namespaceName  + "_" + .fullName.name'
