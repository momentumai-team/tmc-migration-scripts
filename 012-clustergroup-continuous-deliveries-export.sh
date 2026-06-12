#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/sm-api-call.sh
source $SCRIPT_DIR/utils/filter.sh

init "[012] Export the cluster group continuous deliveries" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.name' "$TMC_CG_FILTER")
tanzu tmc clustergroup list -o yaml | yq ".clusterGroups[] | $FILTER | .fullName.name" > cluster_groups.txt

while read cg; do
  log info "Export continuous delivery for cluster group '$cg'"
  echo "$(curl_api_call "/v1alpha1/clustergroups/$cg/fluxcd/continuousdelivery")" | yq -p json '.continuousDeliveries[0]' > $cg.yml
done < cluster_groups.txt

rm cluster_groups.txt
