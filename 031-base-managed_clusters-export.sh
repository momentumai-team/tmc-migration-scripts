#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/utils/context.sh

use_tmc_source_context

MC_LIST_FOLDER=data/clusters
MC_LIST_FILE=$MC_LIST_FOLDER/mc_list.yaml

if [[ -s $MC_LIST_FILE ]]; then
    echo "Please archive the data under $MC_LIST_FOLDER to avoid data lost before running this script."
    exit 1
fi

# Define the management cluster filter. e.g. "my_mc_1, my_mc_2".
# export TMC_MC_FILTER="my_mc_1, my_mc_2"

echo "Management cluster filter TMC_MC_FILTER=$TMC_MC_FILTER"

if [[ -z "$TMC_MC_FILTER" ]]; then
    echo "Export all management clusters"
    mkdir -p $MC_LIST_FOLDER && tanzu tmc mc list -o yaml | yq 'del(.managementClusters[] | select(.fullName.name == "attached" or .fullName.name == "eks" or .fullName.name == "aks")) | del(.totalCount)' > $MC_LIST_FILE
else
    # Only export the data of the manage clusters defined in the environment variable "TMC_MC_FILTER".
    IFS=',' read -ra FILTERED_NAMES <<< "${TMC_MC_FILTER:-}"
    FILTER_PATTERN=$(IFS='|'; echo "${FILTERED_NAMES[*]}")
    echo "Export management clusters matching pattern $FILTER_PATTERN"

    # Keep the raw data of all management clusters.
    # Process the data before using it later.
    mkdir -p $MC_LIST_FOLDER && tanzu tmc mc list -o yaml \
        | yq -o json '.managementClusters[]' \
        | jq -c 'select(.fullName.name | test("^('"$FILTER_PATTERN"')$"))' \
        | jq -s '{"managementClusters": .}' \
        | yq -P > $MC_LIST_FILE
fi

MATCHED_MC=$(yq -r '.managementClusters[].fullName.name' $MC_LIST_FILE)

#Export all the managed workload clusters under each management cluster first.
for name in $MATCHED_MC; do
    echo "Export the workload clusters under management cluster $name to $MC_LIST_FOLDER/wc_of_$name.yaml"
    tanzu tmc cluster list -o yaml -m "$name" > "$MC_LIST_FOLDER/wc_of_$name.yaml";
done