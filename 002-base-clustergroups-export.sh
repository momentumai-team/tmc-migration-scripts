#!/bin/bash
# Resource: Cluster group

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/utils/filter.sh
DATA_DIR="$SCRIPT_DIR"/data/clustergroup

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi
mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting ClusterGroups from source TMC SM ..."
echo "************************************************************************"

if [[ -n "$TMC_CG_FILTER" ]]; then
  echo "Cluster group filter TMC_CG_FILTER=$TMC_CG_FILTER"
fi

# Apply TMC_CG_FILTER (no-op when empty) and rebuild the wrapping object so
# downstream consumers continue to see `.clusterGroups: [...]`.
FILTER=$(yq_filter_or_passthrough '.fullName.name' "$TMC_CG_FILTER")
tanzu tmc clustergroup list -o yaml \
  | yq -o json ".clusterGroups[] | $FILTER" \
  | jq -c '.' \
  | jq -s '{"clusterGroups": .}' \
  | yq -P > "$DATA_DIR/clustergroups.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported ClusterGroups from source TMC SM: $relative_path/*.yaml"
