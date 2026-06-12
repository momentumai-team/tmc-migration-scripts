#!/bin/bash
source $(dirname "${BASH_SOURCE[0]}")/log.sh
source $(dirname "${BASH_SOURCE[0]}")/common.sh
source $(dirname "${BASH_SOURCE[0]}")/filter.sh

download_offboard_clusters () {
    local FILE=$(data_dir)/offboard_clusters.txt
    log debug "Save offboard clusters to $FILE"

    rm -rf $FILE
    touch $FILE

    # TMC_WC_FILTER narrows the managed workload-cluster set to a subset of
    # names within each TMC_MC_FILTER-matched management cluster. Empty filter
    # is a no-op (passthrough).
    local WC_FILTER
    WC_FILTER=$(yq_filter_or_passthrough '.fullName.name' "$TMC_WC_FILTER")

    IFS=',' read -r -a MGMT_CLUSTERS <<< "$TMC_MC_FILTER"
    for MGMT in "${MGMT_CLUSTERS[@]}"; do
        tanzu tmc cluster list -m $MGMT -o yaml | yq ".clusters[] | $WC_FILTER | [.fullName.managementClusterName, .fullName.provisionerName, .fullName.name] | @tsv" - > $FILE
    done

    IFS="," read -r -a CLUSTER_NAMES <<< "$CLUSTER_NAME_FILTER"
    if [[ -n "${CLUSTER_NAMES[@]}" ]]; then
        local CLUSTERS=$(tanzu tmc cluster list -m attached -p attached -o yaml | \
        yq e 'del(.clusters[] | select(.status.infrastructureProvider? == "AWS_EC2" or .status.infrastructureProvider? == "GCP_GCE" or .status.infrastructureProvider? == "AZURE_COMPUTE"))' - | \
        yq '.clusters[].fullName.name' -)

        log debug "All attached clusters ${CLUSTERS}"
        set +e
        for NAME in "${CLUSTER_NAMES[@]}"; do
            log debug "Check attached cluster '${NAME}'"
            if printf "%s\n" "$CLUSTERS" | grep -q "^${NAME}$"; then
                log debug "Attached cluster '${NAME}' is found"
                echo -e "attached\tattached\t${NAME}" >> $FILE
            fi
        done
        set -e
    fi

    cat $FILE
    rm $FILE
}
