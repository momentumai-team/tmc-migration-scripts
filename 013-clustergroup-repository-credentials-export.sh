#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[013] Export the cluster group repository credentials" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterGroupName' "$TMC_CG_FILTER")
tanzu tmc continuousdelivery repositorysecret list -s clustergroup -o yaml | yq ".sourceSecrets[] | $FILTER" -s '.fullName.clusterGroupName + "_" + .fullName.name'
