#!/bin/bash

# [070] Source-side cleanup — per workload cluster (Tier 1)
#
# `031`-offboard `unmanage`s a workload cluster from the source management
# cluster but leaves its cluster-scoped Continuous Delivery records orphaned on
# the SOURCE: kustomizations, git repositories, repository secrets, and the
# CD-enable record itself. This script deletes those, in the required order
# (kustomizations -> git repositories -> repository secrets -> CD disable),
# for the workload cluster(s) selected by TMC_WC_FILTER.
#
# WHERE THIS RUNS
#   On the surviving production source TMC SM, while the source management
#   cluster is STILL registered — otherwise `-m <source-MC>` resolves to nothing
#   and the deletes fail. This is runbook step 9, after the WC is confirmed
#   healthy in the destination and before the final MC deregister.
#
# SAFETY MODEL
#   * Targets are read from the already-filtered ./data/cluster-* exports, not
#     from a fresh live list — a live list on a prod control plane is exactly how
#     a prod object sneaks into a delete loop.
#   * Every target is re-checked against TMC_WC_FILTER (and TMC_MC_FILTER) before
#     it is touched, so a stale data/ tree left over from a broader export can
#     never delete a workload cluster outside the current filter.
#   * Cluster-scoped CD records belong to exactly one workload cluster and never
#     fan out to siblings, so there is no cross-WC sharing to guard against at
#     this tier (that concern lives at cluster-group scope — see 071).
#   * Default is a DRY RUN. Set TMC_CLEANUP_SOURCE=true to actually delete.
#
# Usage
#   TMC_MC_FILTER=<mc> TMC_WC_FILTER=<wc> ./070-cluster-source-cleanup.sh
#   TMC_MC_FILTER=<mc> TMC_WC_FILTER=<wc> TMC_CLEANUP_SOURCE=true ./070-cluster-source-cleanup.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR"/utils/context.sh
source "$SCRIPT_DIR"/utils/source-cleanup.sh

use_tmc_source_context

# Per-WC cleanup must target a specific workload cluster — never run unfiltered.
if [[ -z "$TMC_WC_FILTER" ]]; then
  echo "❌ Refusing to run: TMC_WC_FILTER is empty." >&2
  echo "   Per-WC source cleanup must target a specific workload cluster." >&2
  exit 1
fi

DATA_DIR="$SCRIPT_DIR/data"

if [[ "$CLEANUP_APPLY" == "true" ]]; then
  echo "=== 070 source cleanup: APPLY (deletes will run) ==="
else
  echo "=== 070 source cleanup: DRY RUN (set TMC_CLEANUP_SOURCE=true to apply) ==="
fi
echo "    TMC_MC_FILTER=${TMC_MC_FILTER:-<unset>}  TMC_WC_FILTER=${TMC_WC_FILTER}"
echo

# in_scope <mgmt> <cluster> — 0 if this cluster-scoped record is inside the
# active filters, 1 otherwise. This is the "don't touch anything outside the
# filter" guard applied to every exported record before it is deleted.
in_scope() {
  local mgmt="$1" cluster="$2"
  name_matches_filter "$cluster" "$TMC_WC_FILTER" || return 1
  name_matches_filter "$mgmt" "$TMC_MC_FILTER"   || return 1
  return 0
}

# process_cluster_files <data-subdir> <label> <delete-fn>
# For each exported record under <data-subdir>, parse its fullName, apply the
# in_scope guard, and hand the file path + coordinates to <delete-fn>.
process_cluster_files() {
  local subdir="$1" label="$2" delfn="$3"
  [[ -d "$subdir" ]] || return 0
  local f
  for f in "$subdir"/*.yml "$subdir"/*.yaml; do
    [[ -e "$f" ]] || continue
    local mgmt prov cluster
    mgmt=$(yq -r '.fullName.managementClusterName' "$f")
    prov=$(yq -r '.fullName.provisionerName' "$f")
    cluster=$(yq -r '.fullName.clusterName' "$f")
    if ! in_scope "$mgmt" "$cluster"; then
      echo "  SKIP (out of filter): $label $(basename "$f")"
      continue
    fi
    "$delfn" "$f" "$mgmt" "$prov" "$cluster"
  done
}

# Delete functions. `repositorysecret` uses --cluster-name where the other CD
# subcommands use -c; -m and -p are de facto required on all of them (an
# omitted flag yields an unhelpful generic error). See migration-repurpose.md
# "Source-side cleanup".
del_ks()      { local f=$1 m=$2 p=$3 c=$4 n; n=$(yq -r '.fullName.name' "$f")
                run_delete "kustomization $m/$p/$c/$n"     tmc continuousdelivery ks delete "$n" -s cluster -m "$m" -p "$p" -c "$c"; }
del_gitrepo() { local f=$1 m=$2 p=$3 c=$4 n; n=$(yq -r '.fullName.name' "$f")
                run_delete "gitrepository $m/$p/$c/$n"     tmc continuousdelivery gitrepository delete "$n" -s cluster -m "$m" -p "$p" -c "$c"; }
del_secret()  { local f=$1 m=$2 p=$3 c=$4 n; n=$(yq -r '.fullName.name' "$f")
                run_delete "repositorysecret $m/$p/$c/$n"  tmc continuousdelivery repositorysecret delete "$n" -s cluster -m "$m" -p "$p" --cluster-name "$c"; }
del_disable() { local f=$1 m=$2 p=$3 c=$4
                run_delete "cd-disable $m/$p/$c"           tmc continuousdelivery disable -s cluster -m "$m" -p "$p" -c "$c"; }

echo "-- kustomizations --"
process_cluster_files "$DATA_DIR/cluster-kustomizations"        "kustomization"    del_ks
echo "-- git repositories --"
process_cluster_files "$DATA_DIR/cluster-git-repositories"      "gitrepository"    del_gitrepo
echo "-- repository secrets --"
process_cluster_files "$DATA_DIR/cluster-repository-credentials" "repositorysecret" del_secret
echo "-- continuous delivery disable --"
process_cluster_files "$DATA_DIR/cluster-continuous-deliveries" "cd-disable"       del_disable

echo
if [[ "$CLEANUP_APPLY" == "true" ]]; then
  echo "✅ 070 source cleanup apply complete."
else
  echo "ℹ️  Dry run only. Re-run with TMC_CLEANUP_SOURCE=true to delete the records listed above."
fi
