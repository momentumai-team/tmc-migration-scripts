#!/bin/bash

# Shared helpers for the source-side cleanup scripts (070, 071).
#
# These scripts DELETE migration objects from the SURVIVING production source
# TMC SM instance. Unlike the export/offboard path — which only ever had to
# avoid *reading* prod — cleanup deletes on a live prod control plane, so every
# helper here is built around two rules:
#
#   1. Default to a dry run. Nothing is deleted unless TMC_CLEANUP_SOURCE=true.
#   2. Never operate outside the active migration filters, and never delete a
#      shared object without first proving it does not service anything the
#      filters did not select.
#
# Sourced by 070-cluster-source-cleanup.sh and 071-clustergroup-source-cleanup.sh.

source "$(dirname "${BASH_SOURCE[0]}")"/log.sh
source "$(dirname "${BASH_SOURCE[0]}")"/filter.sh

# CLEANUP_APPLY is "true" only when the operator has explicitly opted in via
# TMC_CLEANUP_SOURCE=true. Any other value (including unset) leaves the scripts
# in dry-run mode: they print the exact delete they *would* issue and change
# nothing. Mirrors the TMC_DEREGISTER_MC gate on 031-offboard.
CLEANUP_APPLY="false"
if [[ "${TMC_CLEANUP_SOURCE:-false}" == "true" ]]; then
  CLEANUP_APPLY="true"
fi

# name_matches_filter <name> <comma-separated-filter>
# Returns 0 if <name> matches the whole-name filter, 1 otherwise. An empty
# filter matches everything — callers that must never run unfiltered guard for
# an empty filter themselves before invoking any delete. Same semantics as the
# copy in 031-offboard, kept here so the cleanup scripts don't depend on it.
name_matches_filter() {
  local name="$1"
  local filter="$2"
  if [[ -z "$filter" ]]; then
    return 0
  fi
  local pattern
  pattern=$(build_filter_pattern "$filter")
  [[ "$name" =~ ^(${pattern})$ ]]
}

# run_delete <human-description> <tanzu args...>
# Dry-run-aware delete. In dry-run mode it prints the command; in apply mode it
# runs `tanzu <args>`. A single failing delete is logged and swallowed (returns
# 1) rather than aborting the whole run, so one already-gone record does not
# strand the remaining cleanup — these operations are meant to be idempotent.
run_delete() {
  local desc="$1"; shift
  if [[ "$CLEANUP_APPLY" == "true" ]]; then
    echo "  DELETE  $desc"
    if ! tanzu "$@"; then
      echo "  ⚠️  delete failed (may already be gone): tanzu $*" >&2
      return 1
    fi
  else
    echo "  DRY-RUN would delete: $desc"
    echo "            tanzu $*"
  fi
  return 0
}

# clusters_in_cluster_group <cg-name>
# Prints "<mgmt>/<prov>/<name>" for every cluster live on the SOURCE whose
# spec.clusterGroupName equals <cg-name>, across managed and attached MCs, then
# returns 0. Returns 2 (printing nothing) if the managed-cluster enumeration
# fails — the membership query is FAIL-CLOSED so a transient list error can
# never be mistaken for "the group is empty".
#
# This is the shared-resource guard for Tier 2: a cluster group, and any
# group-scoped resource that fans out to every member, must have zero live
# members before it is deleted. Any remaining member — a prod cluster sharing
# the group, or a non-prod WC not yet migrated — must block the teardown.
clusters_in_cluster_group() {
  local cg="$1"
  local expr='.clusters[]? | select(.spec.clusterGroupName == "'"$cg"'") | .fullName.managementClusterName + "/" + .fullName.provisionerName + "/" + .fullName.name'

  local managed
  if ! managed=$(tanzu tmc cluster list -o yaml 2>/dev/null); then
    # Could not enumerate managed clusters — refuse to assume the group is empty.
    return 2
  fi

  # Attached clusters live under the synthetic 'attached' MC. A failure here is
  # treated as "no attached members found"; it is warned about at the call site
  # rather than failing closed, because the managed list above is the primary
  # membership source and attached clusters are a rare CG member.
  local attached
  attached=$(tanzu tmc cluster list -m attached -p attached -o yaml 2>/dev/null || true)

  {
    echo "$managed"  | yq "$expr" 2>/dev/null
    [[ -n "$attached" ]] && echo "$attached" | yq "$expr" 2>/dev/null
  } | grep -vx 'null' | grep -v '^$' | sort -u
  return 0
}
