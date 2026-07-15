#!/bin/bash

# Notebook for TMC SM source → SM destination migration
## This notebook walks through a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# Usage:
#   ./200-import-phase1.sh <username> <password> <dns>
#
# Example:
#   ./200-import-phase1.sh admin 'p@ss' tmc.destination.example.com
#
# Positional arguments (mapped to env vars consumed by the import scripts):
#   $1  TMC_SELF_MANAGED_USERNAME       Username for the destination TMC SM stack.
#   $2  TMC_SELF_MANAGED_PASSWORD       Password for the destination TMC SM stack (not echoed).
#   $3  TMC_SELF_MANAGED_DNS            DNS hostname of the destination TMC SM stack
#
# Additional env vars set below:
#   TMC_SELF_MANAGED_IDP_MFA_ENABLED    Defaults to false. Set true (or uncomment the
#                                       override further down) if the destination IDP
#                                       requires MFA during login.
# -----------------------------------------------------------------------------

uname -a
echo "PWD=$PWD"

echo "Environment variables needed:"
echo "TMC_SOURCE_USERNAME=$TMC_SOURCE_USERNAME"
echo "TMC_SOURCE_DNS=$TMC_SOURCE_DNS"
echo "TMC_SOURCE_IDP_MFA_ENABLED=${TMC_SOURCE_IDP_MFA_ENABLED:-false}"
# Note: TMC_SOURCE_PASSWORD is intentionally not echoed.

export TMC_SELF_MANAGED_USERNAME="$1"
export TMC_SELF_MANAGED_PASSWORD="$2"
export TMC_SELF_MANAGED_DNS="$3"

echo "TMC_SELF_MANAGED_USERNAME=$TMC_SELF_MANAGED_USERNAME"
echo "TMC_SELF_MANAGED_DNS=$TMC_SELF_MANAGED_DNS"
# Note: TMC_SELF_MANAGED_PASSWORD is intentionally not echoed.

echo "Run 033-base-sm_stack-connect.sh to init CLI context for destination SM stack"
./033-base-sm_stack-connect.sh

./034-base-clustergroups-import.sh

## Import Workspaces
./035-base-workspaces-import.sh

# Import administration resources

## Import Roles
./036-admin-roles-import.sh

## Import Credentials
### Generate credential templates, then fill in the missing values
### (CA, credentials) under data/credential/template/*.yaml before importing.
./037-admin-credentials-create-template.sh
read -p "⚠️ MANUAL STEP: fill in the missing fields in data/credential/template/*.yaml, then press Enter to continue..."
./037-admin-credentials-import.sh

## Import Proxy
### Generate proxy templates, then fill in the missing values before importing.
./038-admin-proxy-create-template.sh
read -p "⚠️ MANUAL STEP: fill in the missing fields in the proxy template files, then press Enter to continue..."
./038-admin-proxy-import.sh

## Import Image Registry
### Generate image-registry templates, then fill in the missing values before importing.
./039-admin-image-registry-create-template.sh
read -p "⚠️ MANUAL STEP: fill in the missing fields in the image-registry template files, then press Enter to continue..."
./039-admin-image-registry-import.sh

# Import add-on resources of cluster groups

## Import k8s secret resources of cluster groups
./040-clustergroup-secrets-import.sh

## Import k8s secret export resources of cluster groups
./041-clustergroup-secret-exports-import.sh

## Import fluxcd resources of cluster groups
./042-clustergroup-continuous-deliveries-import.sh

## Import git repo credential resources of cluster groups
./043-clustergroup-repository-credentials-import.sh

## Import git repository resources of cluster groups
./044-clustergroup-git-repositories-import.sh

## Import kustomization resources of cluster groups
./045-clustergroup-kustomizations-import.sh

## Import helm resources of cluster groups
./046-clustergroup-helms-import.sh

## Import helm release resources of cluster groups
./047-clustergroup-helm-releases-import.sh
