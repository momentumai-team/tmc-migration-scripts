#!/bin/bash
# Resource: Proxy Configuration(Under Administration)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/proxy

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi
mkdir -p $DATA_DIR

echo "************************************************************************"
echo "* Exporting Proxy from source TMC SM ..."
echo "************************************************************************"

tanzu tmc account credential list -o yaml | \
  yq eval -o=json - | jq '.' | \
  jq 'del(.totalCount)' | \
  jq '.credentials |=map(select(.spec.capability == "PROXY_CONFIG"))' | \
  yq eval -P -  > "$DATA_DIR/proxies.yaml"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported Proxy from source TMC SM: $relative_path/*.yaml"