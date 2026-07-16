#!/bin/bash

# TMC SM source → SM destination migration
# This script runs one phase of a single migration run from a TMC Self-Managed source stack to a TMC Self-Managed destination stack. Replace every placeholder (<...>) with values for your environment before running.

# -----------------------------------------------------------------------------
# Usage:
#   ./110-offboard.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
#
# Example:
#   ./110-offboard.sh admin 'p@ss' tmc.source.example.com '*' '*' '*'
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

# Usage check: ensure all required arguments are provided.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
  echo "ERROR: missing required arguments." >&2
  echo "Usage:   $0 <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>" >&2
  echo "Example: $0 admin 'p@ss' tmc.source.example.com '*' '*' '*'" >&2
  exit 1
fi

export TMC_SOURCE_USERNAME="$1"
export TMC_SOURCE_PASSWORD="$2"
export TMC_SOURCE_DNS="$3"
export TMC_SOURCE_IDP_MFA_ENABLED=false
export TMC_MC_FILTER="$4"
export TMC_WC_FILTER="$5"
export TMC_CG_FILTER="$6"
export TMC_DEREGISTER_MC=true
unset TMC_WC_FILTER

echo "Source TMC SM env vars set (password not echoed)."

## assumed migration tanzu CLI context against the source SM stack already exists.

echo "Environment variables needed:"
echo "TMC_SOURCE_USERNAME=$TMC_SOURCE_USERNAME"
echo "TMC_SOURCE_DNS=$TMC_SOURCE_DNS"
echo "TMC_SOURCE_IDP_MFA_ENABLED=${TMC_SOURCE_IDP_MFA_ENABLED:-false}"
# Note: TMC_SOURCE_PASSWORD is intentionally not echoed.

## Offboard managed clusters
./031-base-managed_clusters-offboard.sh
