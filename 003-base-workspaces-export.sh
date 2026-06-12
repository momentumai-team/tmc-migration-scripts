#!/bin/bash
# Resource: Workspace

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/workspace

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi

mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting Workspaces from source TMC SM ..."
echo "************************************************************************"

tanzu tmc workspace list -o yaml > "$DATA_DIR/workspaces.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported Workspaces from source TMC SM: $relative_path/*.yaml"