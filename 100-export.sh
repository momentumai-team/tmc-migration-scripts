#!/bin/bash

# TMC SM source → SM destination migration
# This script runs one phase of a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# Usage:
#   ./100-export.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
#
# Example:
#   ./100-export.sh admin 'p@ss' tmc.source.example.com '*' '*' '*'
#
# Positional arguments (mapped to env vars consumed by the export scripts):
#   $1  TMC_SOURCE_USERNAME       Username for the source TMC SM stack.
#   $2  TMC_SOURCE_PASSWORD       Password for the source TMC SM stack (not echoed).
#   $3  TMC_SOURCE_DNS            DNS hostname of the source TMC SM stack
#                                 (e.g. tmc.source.example.com).
#   $4  TMC_MC_FILTER             Management-cluster name filter; limits which
#                                 management clusters are exported.
#   $5  TMC_WC_FILTER             Workload-cluster name filter; limits which
#                                 workload clusters (and their add-on/DP
#                                 resources) are exported.
#   $6  TMC_CG_FILTER             Cluster-group name filter; limits which
#                                 cluster groups (and their add-on resources)
#                                 are exported.
#
# Additional env vars set below:
#   TMC_SOURCE_IDP_MFA_ENABLED    Defaults to false. Set true (or uncomment the
#                                 override further down) if the source IDP
#                                 requires MFA during login.
# -----------------------------------------------------------------------------

uname -a
echo "PWD=$PWD"

# Usage check: ensure all required arguments are provided before doing any work.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
  echo "ERROR: missing required arguments." >&2
  echo "Usage:   $0 <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>" >&2
  echo "Example: $0 admin 'p@ss' tmc.source.example.com '*' '*' '*'" >&2
  exit 1
fi

# Clean up before execution

namesuffix=(date +%s) tar -zcf data_
namesuffix.tar.gz ./data
ls -l data_$namesuffix.tar.gz

rm -rf ./data
ls -l ./data

# Connect to source TMC SM stack
## Set the source-side env vars and run ./001-base-source_stack-connect.sh to create the migration tanzu CLI context.

# ⚠️ A previous version of this repo (the old migration notebook) committed a real TANZU_API_TOKEN. If that token has not already been revoked at the CSP console, revoke it now — it remains visible in git history.

export TMC_SOURCE_USERNAME="$1"
export TMC_SOURCE_PASSWORD="$2"
export TMC_SOURCE_DNS="$3"
export TMC_SOURCE_IDP_MFA_ENABLED=false
export TMC_MC_FILTER="$4"
export TMC_WC_FILTER="$5"
export TMC_CG_FILTER="$6"
# If the source IDP requires MFA, uncomment:
# export TMC_SOURCE_IDP_MFA_ENABLED=true

export TANZU_CLI_CEIP_OPT_IN_PROMPT_ANSWER=no

echo "Source TMC SM env vars set (password not echoed)."

## Run ./001-base-source_stack-connect.sh to create the migration tanzu CLI context against the source SM stack.

echo "Create the 'migration' tanzu CLI context against the source SM stack."

echo "Environment variables needed:"
echo "TMC_SOURCE_USERNAME=$TMC_SOURCE_USERNAME"
echo "TMC_SOURCE_DNS=$TMC_SOURCE_DNS"
echo "TMC_SOURCE_IDP_MFA_ENABLED=${TMC_SOURCE_IDP_MFA_ENABLED:-false}"
# Note: TMC_SOURCE_PASSWORD is intentionally not echoed.

tanzu config eula accept
./001-base-source_stack-connect.sh

# Export the base resources

## Export cluster group

./002-base-clustergroups-export.sh

## Export Workspaces (TODO: workspace namespace is incorrect)
./003-base-workspaces-export.sh

# Export administration resources

## Export Roles
./004-admin-roles-export.sh

## Export Credentials
./005-admin-credentials-export.sh

## Export Access
./006-admin-access-export.sh

## Export Proxy
./007-admin-proxy-export.sh

## Export Image Registry
./008-admin-image-registry-export.sh

## Export Settings (Token Error blows up here)
./009-admin-settings-export.sh

# Export add-on resources of cluster group

## Export k8s secret resources of cluster groups
./010-clustergroup-secrets-export.sh

## Export k8s secret export resources of cluster groups
./011-clustergroup-secret-exports-export.sh

## Export fluxcd resources of cluster groups
./012-clustergroup-continuous-deliveries-export.sh

## Export git repo credential resources of cluster groups
./013-clustergroup-repository-credentials-export.sh

## Export git repository resources of cluster groups
./014-clustergroup-git-repositories-export.sh

## Export kustomization resources of cluster groups
./015-clustergroup-kustomizations-export.sh

## Export helm resources of cluster groups
./016-clustergroup-helms-export.sh

## Export helm release resources of cluster groups
./017-clustergroup-helm-releases-export.sh

# Export add-on resources of clusters

## Export managed namespace resources of clusters
./018-cluster-namespaces-export.sh

## Export k8s secret resources of clusters
./019-cluster-secrets-export.sh

## Export k8s secret export resources of clusters
./020-cluster-secret-exports-export.sh

## Export fluxcd resources of clusters
./021-cluster-continuous-deliveries-export.sh

## Export git repo credential resources of clusters
./022-cluster-repository-credentials-export.sh

## Export git repository resources of clusters
./023-cluster-git-repositories-export.sh

# Export kustomization resources of clusters
./024-cluster-kustomizations-export.sh

## Export helm resources of clusters
./025-cluster-helms-export.sh

## Export helm release resources of clusters
./026-cluster-helm-releases-export.sh

# Export data protection resources

./027-cluster-data_protection-export.sh

# Export Polices

## ES-28: Export Access Policies from source TMC SM

./028-base-access-policies-export.sh

## ES-29: Export Policy Templates

./029-base-policy-templates-export.sh

## ES-30: Export Policy Assignments

./030-base-policy-assignments-export.sh

## ES-31: Export managed clusters (DO NOT OFFBOARD YET!)

./031-base-managed_clusters-export.sh
