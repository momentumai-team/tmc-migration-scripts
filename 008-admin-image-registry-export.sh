#!/bin/bash
# Resource: Local Image Registry (Under Administration)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/image-registry

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi
mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting Image Registry from source TMC SM ..."
echo "************************************************************************"

tanzu tmc account credential list -o yaml | \
  yq eval -o=json - | jq '.' | \
  jq 'del(.totalCount)' | \
  jq '.credentials |=map(select(.spec.capability == "IMAGE_REGISTRY"))' | \
  yq eval -P -  > "$DATA_DIR/image-registries.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported Image Registry from source TMC SM: $relative_path/*.yaml"