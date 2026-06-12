#!/bin/bash
# Resource: Credential(Accounts) (Under Administration)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/credential

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi

mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting Credentials from source TMC SM ..."
echo "************************************************************************"

tanzu tmc account credential list -o yaml > "$DATA_DIR/credentials.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported Credentials from source TMC SM: $relative_path/*.yaml"