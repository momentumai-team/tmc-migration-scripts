#!/bin/bash
# Resource: Cluster group

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/clustergroup

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi
mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting ClusterGroups from source TMC SM ..."
echo "************************************************************************"

tanzu tmc clustergroup list -o yaml > "$DATA_DIR/clustergroups.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported ClusterGroups from source TMC SM: $relative_path/*.yaml"