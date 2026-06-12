#!/bin/bash
# Resource: Access (Under Administration)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="$SCRIPT_DIR"/data/credential-access

if [ -d $DATA_DIR ]; then
  rm -rf $DATA_DIR/*
fi

mkdir -p $DATA_DIR
source "$SCRIPT_DIR"/utils/sm-api-call.sh

echo "************************************************************************"
echo "* Exporting Admin Access from source TMC SM ..."
echo "************************************************************************"

# No longer to support AZURE_AKS and AWS_EKS
credentialList=`tanzu tmc account credential list -o yaml | \
  yq eval -o=json - | jq '.' | \
  jq 'del(.totalCount)' | \
  jq '.credentials |=map(select(.spec.meta.provider != "AZURE_AKS" and .spec.meta.provider != "AWS_EKS"))' | \
  jq -c '.credentials[]'`

while IFS= read -r credential; do
  name=$(echo "$credential" | jq -r '.fullName.name // ""')
  curl_api_call -X GET "v1alpha1/account/credentials:iam/${name}" |jq '.' | yq eval -P - > $DATA_DIR/access---${name}.yaml
done  <<< "$credentialList"

relative_path="${DATA_DIR#*migration-scripts/}"
echo "Exported Admin Access from source TMC SM: $relative_path/*.yaml"