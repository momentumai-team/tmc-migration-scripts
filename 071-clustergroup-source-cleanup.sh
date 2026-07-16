#!/bin/bash

# [071] Source-side cleanup — cluster group teardown (Tier 2)
#
# Deletes the NON-PROD cluster group(s) and their group-scoped migration
# objects (Continuous Delivery records and k8s secrets/secret-exports) from the
# SURVIVING production source TMC SM, once every non-prod workload cluster has
# been drained and the non-prod management cluster has been deregistered (031
# with TMC_DEREGISTER_MC=true). This is the "Final cleanup" step of the runbook.
#
# This is the most dangerous script in the repo: it deletes on a prod control
# plane, and group-scoped resources fan out to EVERY member of the group. It is
# guarded three ways:
#
#   1. Scope. Only cluster groups named in TMC_CG_FILTER are considered, and
#      only those present in the filtered ./data/clustergroup export. The
#      'default' group is always refused.
#   2. Shared-resource guard (fail-closed). Before a group — or any group-scoped
#      resource that services every member — is deleted, the source is queried
#      live for clusters still in that group. If ANY remain (a prod cluster that
#      shares the group, or a non-prod WC not yet migrated), the group is
#      REFUSED and skipped. If membership cannot be enumerated, it is also
#      refused: absence of evidence is not treated as an empty group.
#   3. Dry run by default. Set TMC_CLEANUP_SOURCE=true to actually delete.
#
# Per-group order: kustomizations -> git repositories -> repository secrets ->
# CD disable -> secret-exports -> secrets -> cluster group delete. Children are
# deleted explicitly first rather than relying on a cascade from the group
# delete.
#
# CLI-flag caveat: the group-scoped delete flags (`-g <cg>` for CD subcommands,
# `-g`/`-n` for secrets) follow the enable/create conventions in 042-047. The
# cluster-scoped quirks are battle-tested; the group-scoped ones are inferred —
# run the dry run and eyeball the emitted commands before the first apply.
#
# Usage
#   TMC_CG_FILTER=<cg> ./071-clustergroup-source-cleanup.sh
#   TMC_CG_FILTER=<cg> TMC_CLEANUP_SOURCE=true ./071-clustergroup-source-cleanup.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR"/utils/context.sh
source "$SCRIPT_DIR"/utils/source-cleanup.sh

use_tmc_source_context

# Cluster-group teardown must target specific groups — never run unfiltered.
if [[ -z "$TMC_CG_FILTER" ]]; then
  echo "❌ Refusing to run: TMC_CG_FILTER is empty." >&2
  echo "   Cluster-group teardown must target specific non-prod cluster group(s)." >&2
  exit 1
fi

DATA_DIR="$SCRIPT_DIR/data"
CG_EXPORT="$DATA_DIR/clustergroup/clustergroups.yaml"
if [[ ! -f "$CG_EXPORT" ]]; then
  echo "❌ Missing $CG_EXPORT — run 002-base-clustergroups-export.sh first." >&2
  exit 1
fi

if [[ "$CLEANUP_APPLY" == "true" ]]; then
  echo "=== 071 cluster-group teardown: APPLY (deletes will run) ==="
else
  echo "=== 071 cluster-group teardown: DRY RUN (set TMC_CLEANUP_SOURCE=true to apply) ==="
fi
echo "    TMC_CG_FILTER=${TMC_CG_FILTER}"
echo

# process_cg_files <data-subdir> <cg> <delete-fn>
# For each exported record under <data-subdir> whose fullName.clusterGroupName
# equals <cg>, hand the group name + file path to <delete-fn>.
process_cg_files() {
  local subdir="$1" cg="$2" delfn="$3"
  [[ -d "$subdir" ]] || return 0
  local f
  for f in "$subdir"/*.yml "$subdir"/*.yaml; do
    [[ -e "$f" ]] || continue
    local fcg
    fcg=$(yq -r '.fullName.clusterGroupName' "$f")
    [[ "$fcg" == "$cg" ]] || continue
    "$delfn" "$cg" "$f"
  done
}

del_cg_ks()           { local cg=$1 f=$2 n; n=$(yq -r '.fullName.name' "$f")
                        run_delete "ks clustergroup/$cg/$n"           tmc continuousdelivery ks delete "$n" -s clustergroup -g "$cg"; }
del_cg_gitrepo()      { local cg=$1 f=$2 n; n=$(yq -r '.fullName.name' "$f")
                        run_delete "gitrepo clustergroup/$cg/$n"      tmc continuousdelivery gitrepository delete "$n" -s clustergroup -g "$cg"; }
del_cg_reposecret()   { local cg=$1 f=$2 n; n=$(yq -r '.fullName.name' "$f")
                        run_delete "reposecret clustergroup/$cg/$n"   tmc continuousdelivery repositorysecret delete "$n" -s clustergroup -g "$cg"; }
del_cg_secretexport() { local cg=$1 f=$2 n ns; n=$(yq -r '.fullName.name' "$f"); ns=$(yq -r '.fullName.namespaceName' "$f")
                        run_delete "secretexport clustergroup/$cg/$ns/$n" tmc secret export delete "$n" -s clustergroup -g "$cg" -n "$ns"; }
del_cg_secret()       { local cg=$1 f=$2 n ns; n=$(yq -r '.fullName.name' "$f"); ns=$(yq -r '.fullName.namespaceName' "$f")
                        run_delete "secret clustergroup/$cg/$ns/$n"   tmc secret delete "$n" -s clustergroup -g "$cg" -n "$ns"; }

# The cluster groups we may operate on: exported AND selected by the filter.
EXPORTED_CGS=$(yq -r '.clusterGroups[].fullName.name' "$CG_EXPORT" | grep -vx 'null' | grep -v '^$')

for cg in $EXPORTED_CGS; do
  if ! name_matches_filter "$cg" "$TMC_CG_FILTER"; then
    echo "SKIP (out of filter): cluster group $cg"
    continue
  fi
  if [[ "$cg" == "default" ]]; then
    echo "SKIP: refusing to delete the 'default' cluster group"
    continue
  fi

  echo "== cluster group: $cg =="

  # Shared-resource / membership guard (fail-closed).
  members=$(clusters_in_cluster_group "$cg")
  rc=$?
  if [[ $rc -eq 2 ]]; then
    echo "  ❌ REFUSE $cg: could not enumerate cluster membership on the source (list failed). Not deleting."
    echo
    continue
  fi
  if [[ -n "$members" ]]; then
    echo "  ❌ REFUSE $cg: cluster(s) still live in this group on the source:"
    echo "$members" | sed 's/^/       - /'
    echo "     Group-scoped deletes fan out to these members. Drain/migrate every non-prod WC"
    echo "     (or confirm any remaining cluster is prod and must not move) before tearing the group down."
    echo
    continue
  fi
  echo "  ✅ no live member clusters — safe to tear down"

  # Group-scoped children first, in dependency order.
  process_cg_files "$DATA_DIR/clustergroup-kustomizations"         "$cg" del_cg_ks
  process_cg_files "$DATA_DIR/clustergroup-git-repositories"       "$cg" del_cg_gitrepo
  process_cg_files "$DATA_DIR/clustergroup-repository-credentials" "$cg" del_cg_reposecret
  if [[ -f "$DATA_DIR/clustergroup-continuous-deliveries/$cg.yml" ]]; then
    run_delete "cd-disable clustergroup/$cg" tmc continuousdelivery disable -s clustergroup -g "$cg"
  fi
  process_cg_files "$DATA_DIR/clustergroup-secret-exports"         "$cg" del_cg_secretexport
  process_cg_files "$DATA_DIR/clustergroup-secrets"                "$cg" del_cg_secret

  # Finally the cluster group itself.
  run_delete "clustergroup $cg" tmc clustergroup delete "$cg"
  echo
done

if [[ "$CLEANUP_APPLY" == "true" ]]; then
  echo "✅ 071 cluster-group teardown apply complete."
else
  echo "ℹ️  Dry run only. Re-run with TMC_CLEANUP_SOURCE=true to delete the records listed above."
fi
