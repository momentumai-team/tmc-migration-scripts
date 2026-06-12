#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[017] Export the cluster group helm releases" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterGroupName' "$TMC_CG_FILTER")
tanzu tmc helm release list -s clustergroup -o yaml | yq ".releases[] | $FILTER | .fullName.clusterGroupName + \",\" + .fullName.namespaceName + \",\" + .fullName.name" > releases.txt

while IFS=, read -r cg ns name; do
  log info "Export helm release '$name' in namespace '$ns' for cluster group '$cg'"
  tanzu tmc helm release get "$name" -s clustergroup --cluster-group-name "$cg" --namespace-name "$ns" -o yaml > "${cg}_${ns}_${name}.yml"
done < releases.txt

rm releases.txt
