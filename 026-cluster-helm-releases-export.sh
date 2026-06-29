#!/bin/bash
set -eE -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/common.sh
source $SCRIPT_DIR/utils/filter.sh

init "[026] Export the cluster helm releases" "true"

FILTER=$(yq_filter_or_passthrough '.fullName.clusterName' "$TMC_WC_FILTER")
tanzu tmc helm release list -s cluster -p '*' -m '*' -o yaml | yq ".releases[] | $FILTER | .fullName.managementClusterName + \",\" + .fullName.provisionerName + \",\" + .fullName.clusterName + \",\" + .fullName.name" > releases.txt

while IFS=, read -r mgmt ns cluster name; do
  log info "Export helm release '$name' in namespace '$ns' for cluster '$cluster' in mgmt '$mgmt'"
  tanzu tmc helm release get "$name" -s cluster -m "$mgmt" -c "$cluster" -p "$ns" -o yaml > "${mgmt}_${cluster}_${ns}_${name}.yml"
done < releases.txt

rm releases.txt
