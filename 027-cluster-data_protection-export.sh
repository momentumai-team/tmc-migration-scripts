#!/bin/bash

set +e

source utils/sm-api-call.sh

DPDIR=data/data-protection
rm -fr ${DPDIR}
mkdir -p ${DPDIR}

# Save backup location for both org and clsuter
echo "Saving backup-location ......"
tanzu tmc data-protection backup-location list -o yaml -s org > ${DPDIR}/backup_location_org.yaml
i=0
while read -r name; do
    ca_certs=$(tanzu tmc data-protection backup-location get ${name} -o yaml | yq -r '.spec.caCert')
    yq -i ".backupLocations[$i].spec.caCert=\"${ca_certs}\"" ${DPDIR}/backup_location_org.yaml
    i=$((i+1))
done < <(yq -r '.backupLocations[] | .fullName.name' ${DPDIR}/backup_location_org.yaml)

tanzu tmc data-protection backup-location list -o yaml -s cluster > ${DPDIR}/backup_location_cluster.yaml

# Save schedule
echo "Saving schedule for clusters ......"
tanzu tmc data-protection schedule list -s cluster -o yaml > ${DPDIR}/schedule-cluster.yaml
echo "Saving schedule for clustergroups ......"
yq -r '.backupLocations[] | .spec.assignedGroups[] | select(.clustergroup) | .clustergroup.name' ${DPDIR}/backup_location_org.yaml | while read -r groupname; do
    echo "    clustergroup: ${groupname}"
    schd=$(tanzu tmc data-protection schedule list -s clustergroup --cluster-group-name ${groupname} -o json)
    if [[ "${schd}" != "{}" ]]; then
        schds=$(echo -n "${schd}" | yq -o yaml -P '.schedules')
        if [[ "${schds}" != "null" ]] && [[ "${schds}" != "[]" ]]; then
            echo "${schds}" >> ${DPDIR}/schedule-clustergroup.yaml
        fi
    fi
done

# Save backup
echo "Saving backup ......"
tanzu tmc data-protection backup list -o yaml > ${DPDIR}/backup.yaml

# Save restore
echo "Saving restore ......"
tanzu tmc data-protection restore list -o yaml > ${DPDIR}/restore.yaml

# The others, these commands support only get/list
echo "Saving others ......"
tanzu tmc data-protection snapshot-location list -o yaml > ${DPDIR}/snapshot_location.yaml
tanzu tmc data-protection template list | while read -r line; do
    templ="${line%% *}"
    if [[ "${templ}" != "NAME" ]]; then
        tanzu tmc data-protection template get ${templ} > ${DPDIR}/template_${templ}.yaml
    fi
done

# dataprotection on clusters/clustergroups

echo "Saving dataprotection for clustergroups ......"
yq -r '.backupLocations[] | .spec.assignedGroups[] | select(.clustergroup) | .clustergroup.name' ${DPDIR}/backup_location_org.yaml | while read -r groupname; do
    echo "    clustergroup: ${groupname}"
    dpgrp=$(curl_api_call v1alpha1/clustergroups/${groupname}/dataprotection)
    if [[ "${dpgrp}" != "{}" ]]; then
        dps=$(echo ${dpgrp} | yq -o yaml -P '.dataProtections')
        if [[ "${dps}" != "null" ]] && [[ "${dps}" != "[]" ]]; then
           echo "${dps}"  >> ${DPDIR}/dataprotection_clustergroups.yaml
        fi
    fi
done

echo "Saving dataprotection for clusters ......"
#yq -r '.backupLocations[] | .fullName | .managementClusterName + " " + .provisionerName + " " + .clusterName' ${DPDIR}/backup_location_cluster.yaml | while read -r mgmtname provname clname; do
yq -r '.backupLocations[] | .spec.assignedGroups[] | select(.cluster) | .cluster.managementClusterName + " " + .cluster.provisionerName + " " + .cluster.name' ${DPDIR}/backup_location_org.yaml | while read -r mgmtname provname clname; do
    echo "    cluster: ${clname}"
    dpcl=$(curl_api_call v1alpha1/clusters/${clname}/dataprotection\?fullName.managementClusterName=${mgmtname}\&fullName.provisionerName=${provname})
    if [[ "${dpcl}" != "{}" ]]; then
        echo ${dpcl} | yq -o yaml -P '.dataProtections' >> ${DPDIR}/dataprotection_clusters.yaml
    fi
done
