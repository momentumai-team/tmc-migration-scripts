#!/bin/bash

# TMC SM source → SM destination migration
# This script runs one phase of a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# Usage:
#   ./220-import-phase2.sh <username> <password> <dns>
#
# Example:
#   ./220-import-phase2.sh admin 'p@ss' tmc.destination.example.com
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

# Usage check: ensure all required arguments are provided.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "ERROR: missing required arguments." >&2
  echo "Usage:   $0 <username> <password> <dns>" >&2
  echo "Example: $0 admin 'p@ss' tmc.destination.example.com" >&2
  exit 1
fi

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

# Import add-on resources of clusters (post-onboarding)

## Import managed namespace resources to clusters
./050-cluster-namespaces-import.sh

## Import k8s secret resources to clusters
### The exported secret manifests are missing their data fields (secret data is not
### exported). Fill them in before importing, per k8s secret type:
###   SECRET_TYPE_OPAQUE            -> spec.data.<key>: base64-encoded-value
###   SECRET_TYPE_DOCKERCONFIGJSON  -> spec.data.".dockerconfigjson": base64-encoded-json
read -p "⚠️ MANUAL STEP: fill in the missing data fields in ./data/cluster-secrets/*.yml, then press Enter to continue..."
./051-cluster-secrets-import.sh

## Import k8s secret export resources to clusters
./052-cluster-secret-exports-import.sh

## Import fluxcd resources to clusters
./053-cluster-continuous-deliveries-import.sh

## Import git repository credential resources to clusters
### The exported credential manifests are missing their data fields. Fill them in
### before importing, per credential type (USERNAME_PASSWORD / SSH / CACert).
read -p "⚠️ MANUAL STEP: fill in the missing data fields in ./data/cluster-repository-credentials/*.yml, then press Enter to continue..."
./054-cluster-repository-credentials-import.sh

## Import git repository resources to clusters
./055-cluster-git-repositories-import.sh

## Import kustomization resources to clusters
./056-cluster-kustomizations-import.sh

## Import helm resources to clusters
./057-cluster-helms-import.sh

## Import helm release resources to clusters
./058-cluster-helm-releases-import.sh

# Import administration resources

## Import settings to TMC SM
./059-admin-settings-import.sh

## Import access to TMC SM
./060-admin-access-import.sh

# Import access policies, policy templates, and policy assignments

## The 061-* scripts require the destination SM's admin/member IDP group names.
## These must match idpGroupRoles.admin and idpGroupRoles.member of the destination
## TMC SM deployment. Override the example values below for your environment.
export ADMIN_IDP_GROUP="${ADMIN_IDP_GROUP:-tmc:admin}"
export MEMBER_IDP_GROUP="${MEMBER_IDP_GROUP:-tmc:member}"
echo "ADMIN_IDP_GROUP=$ADMIN_IDP_GROUP"
echo "MEMBER_IDP_GROUP=$MEMBER_IDP_GROUP"

## Import access policies on organization/clustergroups/workspaces
### Note: access policies are imported with the identity settings from the SOURCE
### TMC SM. After import, the customer must manually edit them with the correct user
### and usergroup identities in the destination TMC SM's IDP.
./061-base-access-policies-import.sh

## Import access policies on clusters
./061-cluster-access-policies-import.sh

## Import policy templates
./062-base-policy-templates-import.sh

## Import policy assignments on organization/clustergroups/workspaces
./063-base-policy-assignments-import.sh

## Import policy assignments on clusters
./063-cluster-policy-assignments-import.sh

# Import data protection resources
./064-cluster-data_protection-import.sh