#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[010] Export the cluster group secrets" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterGroupName' "$TMC_CG_FILTER")
tanzu tmc secret list -s clustergroup -o yaml | yq ".secrets[] | $FILTER" -s '.fullName.clusterGroupName + "_" + .fullName.namespaceName  + "_" + .fullName.name'
