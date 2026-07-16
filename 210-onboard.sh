#!/bin/bash

# TMC SM source → SM destination migration
# This script runs one phase of a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# Usage:
#   ./210-onboard.sh <username> <password> <dns>
#
# Example:
#   ./210-onboard.sh admin 'p@ss' tmc.destination.example.com
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

# Onboard managed clusters (VKS/TKGs and TKGm)

## Generate the MC Kubeconfig index file for the onboarding management clusters.
./048-base-managed_clusters-input_from_user.sh
read -p "⚠️ MANUAL STEP: replace the '/path/to/the/real/mc_kubeconfig/file' placeholders in data/clusters/mc-kubeconfig-index-file, then press Enter to continue..."

## Ensure stale source-TMC annotations and agents on the clusters are removed.
./048-base-managed_clusters-ensure-cleanup.sh

## Onboard the exported managed clusters onto the destination SM stack.
### Set CLUSTERS_ONBOARD_BATCH_SIZE to control the parallel batch size (default 1).
### Set CLUSTER_ONBOARD_TIMEOUT if clusters have many nodes (default 10 min).
./048-base-managed_clusters-onboard.sh

# Onboard attached clusters — only if any were exported from the source.
ATTACHED_CLUSTERS_FILE="data/clusters/attached_clusters.yaml"
attached_count=0
[ -f "$ATTACHED_CLUSTERS_FILE" ] && attached_count=$(yq '.clusters | length' "$ATTACHED_CLUSTERS_FILE" 2>/dev/null || echo 0)

if [ "${attached_count:-0}" -gt 0 ]; then
  ## Generate the WC Kubeconfig index file for the attached clusters.
  ./049-base-attached_clusters-input_from_user.sh
  read -p "⚠️ MANUAL STEP: replace the '/path/to/the/real/wc_kubeconfig/file' placeholders in data/clusters/attached-wc-kubeconfig-index-file, then press Enter to continue..."

  ## Onboard the attached clusters onto the destination SM stack.
  ./049-base-attached_clusters-onboard.sh
else
  echo "ℹ️  No attached clusters found in $ATTACHED_CLUSTERS_FILE; skipping attached-cluster onboarding and kubeconfig prompt."
fi

# Check readiness of all onboarded clusters (managed and attached).
./049-base-whole_clusters-check_readiness.sh
