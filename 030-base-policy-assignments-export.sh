#! /bin/bash

source utils/log.sh

register_last_words "Export policy assignments"

log "************************************************************************"
log "* Exporting Policy Assignments from source TMC SM ..."
log "************************************************************************"

INTERVAL=2
DATA_DIR="data"
DIR="$DATA_DIR/policies/assignments"
mkdir -p $DIR

org_scope="$DIR/organization"
mkdir -p $org_scope

log info "Exporting policies on organization ..."
org_policies="$org_scope/policies.yaml"
tanzu mission-control policy list -s organization -o yaml > $org_policies

workspace_scope="$DIR/workspaces"
mkdir -p $workspace_scope

log info "Exporting policies on workspaces ..."
workspaces="$DATA_DIR/workspace/workspaces.yaml"
yq '.workspaces[] | .fullName.name' $workspaces | \
while read -r name
do
    workspace_policies="$workspace_scope/$name.yaml"
    log info "Exporting policies on workspace $name ..."
    tanzu mission-control policy list -s workspace -n $name -o yaml > $workspace_policies
    sleep $INTERVAL
done

clustergroup_scope="$DIR/clustergroups"
mkdir -p $clustergroup_scope

log info "Exporting policies on clustergroups ..."
clustergroups="$DATA_DIR/clustergroup/clustergroups.yaml"
yq '.clusterGroups[] | .fullName.name' $clustergroups | \
while read -r name
do
    clustegroup_policies="$clustergroup_scope/$name.yaml"
    log info "Exporting policies on clustergroup $name ..."
    tanzu mission-control policy list -s clustergroup -n $name -o yaml > $clustegroup_policies
    sleep $INTERVAL
done

cluster_scope="$DIR/clusters"
mkdir -p $cluster_scope

log info "Exporting policies on clusters ..."
clusters="$cluster_scope/clusters.yaml"
tanzu tmc cluster list -oyaml > $clusters
yq '.clusters[] | [.fullName.managementClusterName, .fullName.provisionerName, .fullName.name] | @tsv' $clusters | \
while IFS=$'\t' read -r mgmt prvn name
do
    # skip empty data
    if [ -z $name ]; then
        continue
    fi
    cluster_policies="$cluster_scope/${mgmt}_${prvn}_${name}.yaml"
    log info "Exporting policies on cluster /${mgmt}/${prvn}/${name} ..."
    tanzu mission-control policy list -s cluster -n $name -m $mgmt -p $prvn -o yaml > $cluster_policies
    sleep $INTERVAL
done
