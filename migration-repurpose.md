# TMC-SM migration

## What this is

A fork of [vmware-samples/tmc-migration-scripts](https://github.com/vmware-samples/tmc-migration-scripts), originally a POC for migrating an entire TMC SaaS organization to a TMC Self-Managed (SM) instance via numbered bash scripts.

**Fork goal:** repurpose the same pipeline to migrate a **subset** of clusters — specifically, **non-prod** workload clusters, their cluster groups, and their management server (a VKS supervisor) — out of a TMC instance that hosts both prod and non-prod. Prod must not be touched.

**Source/destination pair for this fork:** both sides are TMC Self-Managed. The source is an existing **TMC SM 1.4.2** instance hosting prod and non-prod; the destination is a separate TMC SM instance that will own non-prod only. **Both sides start on 1.4.2.** The destination will be upgraded in place to **1.4.4** partway through the migration window, after a small version-matched soak — see [Sequencing the destination 1.4.4 upgrade](#sequencing-the-destination-144-upgrade) below. The source stays on 1.4.2 throughout (prod still lives on it).

This differs from the upstream POC, which assumed a SaaS source → SM destination. The auth flow, context names, and several script names in the upstream still encode the "SaaS source" assumption and must be reworked or parameterized.

The original POC assumes "migrate everything." This fork must introduce filtering so that only non-prod resources are exported, offboarded from the source, and onboarded into the destination.

## Pipeline shape

Scripts are numbered `<NNN>-<scope>-<resource>-<operation>.sh` and meant to run in order. Phases:

| Range | Phase | Notes |
| --- | --- | --- |
| `001` | Connect to source | **Reworked in this fork.** Now does SM auth against the source SM 1.4.2 stack (was SaaS/CSP token auth upstream). Reads `TMC_SOURCE_USERNAME` / `TMC_SOURCE_PASSWORD` / `TMC_SOURCE_DNS` (and optional `TMC_SOURCE_IDP_MFA_ENABLED`). Creates tanzu CLI context named `migration`. Renamed `001-base-saas_stack-connect.sh` → `001-base-source_stack-connect.sh`. |
| `002`–`030` | Export resources from source | Cluster groups, workspaces, admin (roles/creds/proxy/registry/settings), per-cluster-group resources (secrets, FluxCD, git, helm), per-cluster resources, data protection, access policies, policy templates, policy assignments. Driven by `export-all-from-source.sh` (renamed from `export-all-from-saas.sh`). REST-API-using scripts (`006`, `012`, `027`, `028`) now source `utils/sm-api-call.sh` against the active `migration` context; the old `utils/saas-api-call.sh` (CSP-token-based) has been removed. |
| `031` | Managed cluster export + offboard | `TMC_MC_FILTER` env var selects management clusters by name. Excludes the synthetic `attached`/`eks`/`aks` MC names. |
| `032` | Attached cluster export + offboard | `CLUSTER_NAME_FILTER` env var selects by name. |
| `033` | Connect to destination (SM) | Creates tanzu CLI context named `tmc-sm` |
| `034`–`047` | Import cluster groups, workspaces, admin, per-cluster-group resources | |
| `048` | Onboard managed clusters to SM | Has companion `-input_from_user.sh` (build kubeconfig index) and `-ensure-cleanup.sh` (strip stale TMC annotations / agents from source-side clusters) |
| `049` | Onboard attached clusters to SM | Plus `-whole_clusters-check_readiness.sh` |
| `050`–`064` | Import per-cluster resources, admin settings/access, policies, data protection | |

Re-run scripts after fixing inputs — most are idempotent on the SM side (skip-if-exists patterns) but **destructive on the source side** (offboard = unmanage + deregister).

## Conventions

- **Shell:** bash. Scripts source helpers from `utils/`; not all scripts use `set -e` consistently — some use `set -eE -o pipefail`, others rely on manual exit codes. Don't tighten this without checking downstream.
- **Data layout:** every script writes under `./data/<resource>/...` relative to the script. `utils/common.sh::data_dir` derives the subdirectory from the script filename (drops trailing token like `-export`).
- **CLI tools required:** `tanzu` CLI (with `tmc` plugin), `yq`, `jq`, `kubectl`, `openssl`, `curl`, `base64`.
- **Two tanzu contexts:** `migration` (source) and `tmc-sm` (destination). `utils/context.sh` provides `use_tmc_source_context` (activates `migration`) and `use_tmc_sm_context` (activates `tmc-sm`) — these switch the CLI's active context, so don't run source and destination scripts interleaved without checking. The name pair is asymmetric on purpose: both sides are SM, but the destination context name `tmc-sm` and its helper predate this fork; the source helper was renamed from the misleading upstream `use_tmc_saas_context` to reflect its actual role.
- **Logging:** `utils/log.sh` exposes `log info|warn|error|debug`. Set `DEBUG=on` for verbose. Don't replace with `echo` in new scripts.
- **Filters (env vars):**

  - `TMC_MC_FILTER` — comma-separated management cluster names. Honored by `031-export`, `utils/offboard-clusters.sh` (and transitively `019`/`020`/`022`).
  - `CLUSTER_NAME_FILTER` — comma-separated attached cluster names. Honored by `032`, `utils/offboard-clusters.sh`.
  - `TMC_CG_FILTER` *(new in this fork)* — comma-separated cluster-group names. Honored by `002` (filters the exported CG list) and inline by `010`–`017` (filters per-CG resource lists). Whitespace around names is tolerated.
  - `TMC_WC_FILTER` *(new in this fork)* — comma-separated workload-cluster names. Honored by `031-export` (filters `wc_of_<mc>.yaml`), `utils/offboard-clusters.sh` (filters the managed-WC TSV), `031-offboard` (filters the unmanage loop, refuses MC deregister when set), and `028`/`030` (filters the direct `tanzu tmc cluster list` calls that don't read the already-filtered files).
  - `TMC_DEREGISTER_MC` *(new in this fork)* — must be set to `true` to allow `031-offboard` to deregister the management cluster. Default behavior is "unmanage workload clusters only." Combined with the completeness check below, this enforces "every WC under the supervisor MC has been exported before the MC itself is deregistered."
  - All filters are independent axes, AND-combined. The yq/regex pattern they expand into is whole-name (`^(a|b|c)$`), so partial matches don't surprise.
  - Helper: `utils/filter.sh` exposes `build_filter_pattern` and `yq_filter_or_passthrough` so call sites compose a yq pipeline without conditional branches — `yq ".clusters[] | $FILTER"` works whether the filter is set or empty.

- **Hardcoded skip list:** `031` and `048` skip MC names equal to `attached`, `eks`, `aks` (synthetic MCs in TMC for non-MC-managed clusters). Preserve this behavior when filtering.
- **Connection env vars:**

  - Source (this fork, SM 1.4.2): `TMC_SOURCE_USERNAME`, `TMC_SOURCE_PASSWORD`, `TMC_SOURCE_DNS`, optional `TMC_SOURCE_IDP_MFA_ENABLED`. Consumed only by `001`, which maps them onto the `TMC_SELF_MANAGED_*` names the `tanzu tmc context create --basic-auth` command reads — for the duration of that single invocation — so the destination's `TMC_SELF_MANAGED_*` vars (set for `033`) stay distinct in the operator's shell.
  - Destination: `TMC_SELF_MANAGED_USERNAME`, `TMC_SELF_MANAGED_PASSWORD`, `TMC_SELF_MANAGED_DNS`, optional `TMC_SM_IDP_MFA_ENABLED`. Consumed by `033`.
  - Upstream (no longer used in this fork): `TANZU_API_TOKEN`, `ORG_NAME` / `TMC_ENDPOINT`, `TMC_ENV`, `CSP_URL`. These were the SaaS/CSP-token inputs to upstream's `001` and `utils/saas-api-call.sh`. Both are gone; do not export them.

## Changes made in this fork so far

Tracked here so the rest of the document keeps its forward-looking framing without losing sight of what's already landed.

- **`001` rewritten for SM source auth and renamed.** Replaces the CSP/refresh-token flow with `tanzu tmc context create ... -i pinniped --basic-auth` against the source SM stack. New env vars: `TMC_SOURCE_USERNAME`, `TMC_SOURCE_PASSWORD`, `TMC_SOURCE_DNS`, optional `TMC_SOURCE_IDP_MFA_ENABLED`. File renamed `001-base-saas_stack-connect.sh` → `001-base-source_stack-connect.sh` via `git mv`.
- **`utils/sm-api-call.sh` is now context-aware.** Previously hardcoded to read auth from the `tmc-sm` context; now derives the context name via `tanzu context current --short`. This lets the same helper serve both source-side callers (`migration` context) and destination-side callers (`tmc-sm` context).
- **`utils/saas-api-call.sh` deleted.** Source-side scripts that needed REST APIs against the source (`006-admin-access-export.sh`, `012-clustergroup-continuous-deliveries-export.sh`, `027-cluster-data_protection-export.sh`, `028-base-access-policies-export.sh`) now source `utils/sm-api-call.sh` instead. The old helper's CSP-token flow no longer matches the source's auth model.
- **Misleading "TMC SaaS" log/echo strings updated to "source TMC SM"** across the affected export scripts so operator output reflects reality.
- **`TMC_CG_FILTER` and `TMC_WC_FILTER` added** as independent narrowing axes on top of `TMC_MC_FILTER`. Threaded through the export-side scripts listed in the env-var bullet above. Shared regex/passthrough logic lives in `utils/filter.sh`.
- **`031-base-managed_clusters-offboard.sh` split into "unmanage" and "deregister" phases.** The unmanage loop honors `TMC_WC_FILTER`. MC deregister is gated by `TMC_DEREGISTER_MC=true` and a completeness check that refuses deregister if (a) `TMC_WC_FILTER` is set (the operator only targeted a subset, so the MC isn't actually done) or (b) any workload cluster currently live under the MC is missing from the exported `data/clusters/wc_of_<mc>.yaml` (the export wasn't refreshed). This encodes the "every WC managed by the supervisor MC must be exported before the MC is deregistered" invariant directly into the script.
- **`028-base-access-policies-export.sh` and `030-base-policy-assignments-export.sh` now honor `TMC_WC_FILTER`** on the direct `tanzu tmc cluster list` they each issue — without this they would silently re-include prod clusters even when the rest of the pipeline was filtered. (`TMC_MC_FILTER` honoring in these two scripts is still a separate latent gap; see TODO below.)
- **Remaining SaaS-named files and the function were renamed.** `git mv export-all-from-saas.sh export-all-from-source.sh` (with its self-referential comments updated), and `utils/context.sh::use_tmc_saas_context` → `use_tmc_source_context` (with its "context not found" error message updated to point at the new `001` filename, and both callers in `031-export`/`031-offboard` updated). `grep -rin saas --include="*.sh"` is now empty.
- **README.md reworked for source-SM → dest-SM flow.** Title, intro, script-index rows, "Operations" definitions, and the "Run the Scripts" setup flow now reference `TMC_SOURCE_*` and the new `001-base-source_stack-connect.sh` filename. New step-2 documents `TMC_CG_FILTER`/`TMC_MC_FILTER`/`TMC_WC_FILTER`; step-3 documents the `TMC_DEREGISTER_MC` gate and completeness check. The historical "originally TMC SaaS → SM" fork attribution is the only SaaS mention retained.
- **Notebook reworked and renamed.** `git mv tmc-saas-migration-toi.ipynb tmc-sm-migration.ipynb` (dropping both the "saas" and "toi" tokens — the latter was a stale "Transfer of Information" framing from the upstream POC and added no value to operators running the notebook). Title, connect-to-source section, offboard section (filter env-var docs + `TMC_DEREGISTER_MC` note), destination-connect section, and the "double-check from the SaaS stack" trailing note all rewritten for the source-SM → dest-SM flow. **Secret cleanup:** the previously-committed real `TANZU_API_TOKEN`, the destination test password `VMware1!`, and the environment-specific values (`trh`, `sc-803`, `wc-02`, etc.) are replaced with placeholders. The connect-to-source markdown carries a prominent revoke note for the historical token — it is still visible in git history and must be revoked at the CSP if that hasn't already happened. Password echoes in the connect cells were also removed so the rewritten notebook doesn't leak whatever value the operator pastes in.

What is still TODO (in order of how blocking they are for an end-to-end run):

1. **Import-side filters not yet threaded.** Today imports (`034`, `040`–`047`, `050`–`058`, `061-cluster`, `063-cluster`, `064`) iterate whatever sits under `data/`. Filtered exports therefore produce filtered imports without further work — but if an operator runs imports against a `data/` tree built by a different filter, that assumption breaks silently. Add explicit filter enforcement on the import side once a real need surfaces.
2. **`027-cluster-data_protection-export.sh` is not yet filtered.** It iterates clusters via the backup-location assignments rather than the filtered `wc_of_<mc>.yaml`, so prod clusters assigned to org-scope backup locations would still be exported. Defer until data-protection is actually in scope for the migration.
3. **`032-base-attached_clusters-*` still uses only `CLUSTER_NAME_FILTER`.** Attached clusters are a separate offboarding path; align with `TMC_WC_FILTER` later if/when attached clusters move through this fork.
4. **`048-base-managed_clusters-onboard.sh` does not yet honor `TMC_WC_FILTER`** for the workload-cluster loop. Per the per-cluster runbook below, onboard needs the same narrowing so per-cluster runs only onboard the single target WC.
5. **The previously-committed `TANZU_API_TOKEN` in the old notebook remains in git history.** Replacement in the working tree only prevents future leaks, not past ones — revoke at the CSP console if not already done.

## Fork-specific goal: non-prod only, one cluster at a time

The user's environment has one TMC instance covering both prod and non-prod. Non-prod has its own management cluster (VKS supervisor) and its own cluster group(s). Prod has separate ones. Goal: lift just the non-prod side over and leave prod alone.

**Hard constraint: migrate one workload cluster per run.** Blast radius must stay small — if a single cluster move fails, the rest of non-prod (and all of prod) must be unaffected and the operator must be able to roll forward to the next cluster on their own schedule. The original POC was designed for one big "do all of non-prod" sweep; this fork must support repeated single-cluster runs against a stable, already-prepared destination.

This reshapes the pipeline into two distinct kinds of runs:

1. **One-time preparation (per non-prod environment).** Connect to source and destination; export and import the cluster-group, workspace, admin, and policy metadata that any non-prod cluster could reference. Register the non-prod management cluster in the destination. Done once.
2. **Per-cluster run (repeatable).** For a single target workload cluster: export its per-cluster resources, offboard *only that workload cluster* from the source MC (do **not** deregister the MC), then manage that workload cluster in the destination MC and import its per-cluster resources. Verify. Stop. Operator decides when to do the next one.

**What's already adequate for the MC dimension:**

- `031` and the per-cluster export scripts (`019`, `020`, `022`) already filter by `TMC_MC_FILTER`. Setting this to the non-prod management cluster name gets you the right managed/workload clusters and their per-cluster resources.

**What's missing (the meaningful gaps).** Originally captured as the gap analysis before any fork work; status annotations track what's since been closed.

1. ~~**No cluster-group filter.**~~ **RESOLVED.** `TMC_CG_FILTER` now narrows `002` and `010`–`017` on the export side. Imports still iterate `data/`, which inherits the narrowing.
2. ~~**No single-cluster filter.**~~ **PARTIALLY RESOLVED.** `TMC_WC_FILTER` is honored on the export side (`031-export`, `utils/offboard-clusters.sh`, `028`, `030`) and on the unmanage side (`031-offboard`). MC deregister is now gated by `TMC_DEREGISTER_MC=true` plus a completeness check. The destination-side onboard loop in `048` does **not** yet honor `TMC_WC_FILTER` — still outstanding.
3. **Workspaces (`003`, `035`, `040`-namespace etc.).** Workspaces are an org-wide concept in TMC, not bound to a cluster group. For per-cluster runs, the workspace(s) referenced by the target cluster's namespaces must already exist in the destination. Simplest: import all non-prod-referenced workspaces during the one-time preparation, derived from `data/cluster-namespaces/`.
4. ~~**Access policies (`028`, `061`)** and **policy assignments (`030`, `063`)** iterate all cluster groups and all clusters from their exported lists.~~ **PARTIALLY RESOLVED.** The CG iteration already inherited filtering through `data/clustergroup/clustergroups.yaml`. The cluster iteration via direct `tanzu tmc cluster list -oyaml` in `028`/`030` now honors `TMC_WC_FILTER`. Symmetric work on the import side (`061`/`063`) is still outstanding.
5. **Admin resources (`004`–`009`, `036`–`039`, `059`–`060`).** Roles, credentials, proxy, image registry, settings, access — all org-wide. Most likely want to copy verbatim during preparation, but credentials/proxy/registry referenced only by prod could be skipped. Lowest priority.
6. **Hardcoded `attached`/`eks`/`aks` exclusion stays correct,** but the per-MC iteration in `031` line 41 and `048` will need to additionally filter cluster-group and single-cluster membership when narrowing.
7. **`048-base-managed_clusters-onboard.sh` re-registers the MC every run.** In per-cluster mode, the MC should be registered exactly once (during preparation) and skipped on subsequent per-cluster runs. The script already checks MC health and skips re-registration when `HEALTHY` (`:240`), which mostly handles this — verify it stays a no-op once the MC is established.
8. ~~**`utils/common.sh::ONBOARDED_CLUSTER_INDEX_FILE`** is append-only, which is friendly to repeated per-cluster runs, but the per-cluster export scripts (`019`, `020`, `022`) iterate everything in `offboard-clusters.sh` output rather than a single cluster — they will need to honor the same `TMC_WC_FILTER`.~~ **RESOLVED.** `019`/`020`/`022` consume `download_offboard_clusters` from `utils/offboard-clusters.sh`, which now applies `TMC_WC_FILTER`.

**Recommendations to consider before coding:**

- Add `TMC_CG_FILTER` (comma-separated CG names) and `TMC_WC_FILTER` (single `name` or `mgmt/provisioner/name` triple) env vars. Thread `TMC_CG_FILTER` through `002`, `010`–`017`, `028`/`030`, and `034`/`040`–`047`. Thread `TMC_WC_FILTER` through `019`–`027`, `031` (offboard), `048` (onboard workload-cluster loop), and `050`–`058`, `063`-cluster, `064`.
- Treat filters as independent axes — `TMC_MC_FILTER` for MC-scoped, `TMC_CG_FILTER` for CG-scoped, `TMC_WC_FILTER` for single-cluster scope. AND-combined semantics get confusing fast and don't match the existing axis-per-env-var pattern.
- For per-cluster scripts that already read the filtered `mc_list.yaml` / `wc_of_<mc>.yaml`, the existing inheritance is fine — only add `TMC_WC_FILTER` enforcement at the iteration loops.
- Re-check `028-base-access-policies-export.sh` and `030-base-policy-assignments-export.sh` — they call `tanzu tmc cluster list -oyaml` directly instead of reusing the filtered list from `031`. This is a latent bug for the non-prod use case.
- Split `031-base-managed_clusters-offboard.sh` into two behaviors: (a) WC unmanage (the inner `while read` block at `:52`-`:55`), which runs per-cluster; (b) MC deregister (`:67`-`:68`), which runs once at the very end of the non-prod migration, gated by an explicit `TMC_DEREGISTER_MC=true` env var. Default to (a) only.
- **Offboarding is destructive.** Add a dry-run / confirm step that prints exactly which workload cluster(s) are about to be unmanaged from which MC before `tanzu tmc mc wc unmanage` runs. In per-cluster mode, this should print exactly one line.
- Add an orchestrator script (companion to `export-all-from-saas.sh`) that runs only the preparation phase, and a second one that runs a single per-cluster cycle given `TMC_WC_FILTER`. Keep them thin — just sequenced calls to the existing numbered scripts.
- The README now describes the source-SM → dest-SM flow with the new env vars and filter/deregister gate. The "originally TMC SaaS → SM" fork attribution in the intro is intentional — it explains why this repo exists.

## Suggested per-cluster runbook (target shape)

This is the end-state the fork should support, not what works today:

**Once per non-prod environment (preparation):**

1. `001` — connect to source TMC.
2. `033` — connect to destination TMC.
3. With `TMC_CG_FILTER` set to the non-prod cluster group(s): run `002` (CG export), `003` (workspaces export — full or derived), `004`–`009` (admin export), `028`/`030` (policy/IAM export, CG-filtered).
4. `034`–`047` — import CGs, workspaces, admin, per-CG resources into destination.
5. `031` (export half only) with `TMC_MC_FILTER` set to the non-prod MC — produces `mc_list.yaml` and `wc_of_<mc>.yaml` so per-cluster runs have a stable input.
6. `048` — register the non-prod MC in the destination (workload-cluster loop skipped via `TMC_WC_FILTER=__none__` or a "register MC only" flag). MC must reach `HEALTHY` before any per-cluster run.

**Per cluster (repeat for each non-prod WC, one at a time):**

1. Set `TMC_WC_FILTER=<wc_name>` (and `TMC_MC_FILTER`, `TMC_CG_FILTER` as before).
2. Run `019`–`027` — export that cluster's resources only.
3. Run `031` (offboard half) — unmanage that single WC from the source MC. **Do not deregister the MC.**
4. Run `048-base-managed_clusters-ensure-cleanup.sh` for that single WC — strip TMC annotations/agents.
5. Run `048` (workload-cluster loop only) — manage that single WC under the already-registered destination MC.
6. Run `049-base-whole_clusters-check_readiness.sh` — confirm the WC is healthy in the destination.
7. Run `050`–`058`, `061`-cluster, `063`-cluster, `064` — import per-cluster resources for that WC only.
8. Verify the workload on the cluster. Stop. Operator chooses when to start the next cluster.

**Final cleanup (once all non-prod WCs are migrated):**

1. Run `031` with `TMC_DEREGISTER_MC=true` — deregister the empty non-prod MC from the source.
2. Optionally delete the non-prod cluster groups from the source.

## Sequencing the destination 1.4.4 upgrade

The destination TMC SM is provisioned at **1.4.2** to match the source, and is upgraded to **1.4.4** during the migration window — not before it starts, and not after it finishes. The early non-prod clusters act as a real-traffic shakedown of the destination at the matched version, then the upgrade happens, then the rest of the clusters migrate cross-version.

**Phasing:**

1. **Phase A — version-matched soak (source 1.4.2 → dest 1.4.2).** Migrate a small batch of low-impact non-prod workload clusters first (e.g. 2–3). These exercise the migration scripts against a same-version pair, where resource schema compatibility is the simplest case. Confirm the clusters are healthy under the destination, workloads keep running, and basic TMC operations (policy push, agent reporting) work.
2. **Phase B — destination upgrade (dest 1.4.2 → 1.4.4).** Per the [TMC SM upgrade docs](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-mission-control-self-managed/1-4/tmc-self-managed-documentation/install-and-run-tmc-self-managed/upgrading-tmc-self-managed.html), this is an ordered sequence on the TMC SM target cluster: stage images → `tanzu package repository update tanzu-mission-control-packages --url ...` (bumps the **Tanzu Standard Package Repository** from `v2025.6.18` to `v2026.1.21`) → wait for kapp-controller reconciliation → `tanzu package installed update tanzu-mission-control`. Don't compress the gap between the repo bump and the TMC package update — that gap is the only debug window if a downstream package (FluxCD especially — see [FluxCD and Standard Repository upgrade](#fluxcd-and-standard-repository-upgrade) below) reconciles poorly. After upgrade, verify:
   - Phase A workload clusters are still `HEALTHY` in the destination (their TMC agents are bumped by the platform as part of the upgrade — confirm before continuing).
   - The non-prod MC registration in the destination is still healthy.
   - The cluster-group / workspace / admin / policy state imported during preparation is intact.
   - The `tanzu` CLI and `tmc` plugin used by the migration scripts are still compatible — may require bumping to match 1.4.4.
   - Flux on every CD-enabled Phase A cluster: source-controller, kustomize-controller, helm-controller pods all running on the post-upgrade image versions; CRD storage versions for `gitrepositories.source.toolkit.fluxcd.io`, `kustomizations.kustomize.toolkit.fluxcd.io`, `helmreleases.helm.toolkit.fluxcd.io` unchanged or cleanly migrated; one real `flux reconcile kustomization ...` succeeds end-to-end. Logs should be free of `failed to get API group resources` errors against any `*.toolkit.fluxcd.io` group.
3. **Phase C — cross-version migration (source 1.4.2 → dest 1.4.4).** Resume the per-cluster runbook for the remaining non-prod WCs. The source still emits 1.4.2 YAML; the destination accepts it at 1.4.4. Schema changes between 1.4.2 and 1.4.4 are expected to be additive, but validate end-to-end with the first post-upgrade cluster before continuing the batch.

**Risks specific to the mid-migration upgrade:**

- **CLI/plugin drift.** The `tanzu` and `tmc` plugin versions used by the migration scripts may need to be bumped after Phase B. Record the exact CLI/plugin versions used in Phase A so a Phase A re-run (if needed) stays reproducible.
- **Resource schema additions in 1.4.4.** If 1.4.4 introduces new required fields on a resource the source (1.4.2) doesn't emit, Phase C imports will fail. The first post-upgrade cluster catches this — don't batch through Phase C blind.
- **In-place agent upgrades on already-managed clusters.** The destination platform upgrade bumps cluster agents on every already-onboarded WC, including the Phase A clusters. Treat this as a real change to those clusters — verify health before starting Phase C, not just after Phase B finishes.
- **Source stays on 1.4.2.** Don't upgrade the source during the migration window. Source-side schema drift mid-pipeline isn't something the export scripts handle, and prod still depends on it.
- **Standard Package Repository rebrand.** The TMC SM 1.4.3 release notes already flag a documented known issue — the Available Packages page shows duplicate entries when the Standard Repository contains rebranded packages alongside legacy ones. Between `v2025.6.18` and `v2026.1.21`, expect at least one renamed package; this is cosmetic at the TMC catalog layer but can surface as install collisions if both the old and new package names get installed on the same cluster. Confirm against the v2026.1.21 release notes before Phase B (see below — they were not yet public when this doc was written).
- **FluxCD dual-ownership.** Covered in detail in [FluxCD and Standard Repository upgrade](#fluxcd-and-standard-repository-upgrade) — TMC's CD extension *defers to existing Flux CRDs* if the Tanzu Standard `fluxcd2` package is already installed on the same cluster. This means a Standard Repo upgrade can mutate Flux CRDs out from under TMC without TMC knowing.

**Why not just upgrade first.** Upgrading the destination to 1.4.4 before migrating anything makes the very first migration also a version-skew test. Doing a version-matched soak first separates "are the migration scripts correct" from "does cross-version schema work" — two failure modes that are much easier to debug independently.

## FluxCD and Standard Repository upgrade

The Phase B upgrade bumps **two** things in close succession on the TMC SM target cluster: the **Tanzu Standard Package Repository** (`v2025.6.18` → `v2026.1.21`) and the **TMC SM package** (`1.4.2` → `1.4.4`). The Standard Repo bump is the one that ships new FluxCD component versions; the TMC SM bump does not appear to change the FluxCD version bundled with the Continuous Delivery extension (TMC SM 1.4.x has shipped Flux v2.1.x throughout 1.4 GA, 1.4.3, and 1.4.4, per the release notes). So the Flux risk lives in the Standard Repo bump, not in the TMC SM bump.

**Documented Flux versions in `v2025.6.18` (your starting point):**

| Component | Version |
| --- | --- |
| `fluxcd-source-controller` | `v1.5.0+vmware.1-tkg.1` |
| `fluxcd-kustomize-controller` | `v1.5.1+vmware.1-tkg.1` |
| `fluxcd-helm-controller` | `v1.2.0+vmware.1-tkg.1` |

**`v2026.1.21` Flux versions:** not yet public at the time of writing. Upstream Flux policy states "Flux can be upgraded from any v2.x release to any other v2.x release," so a within-`v1.x` bump for the Vmware-repackaged controllers should be safe — but Vmware repackaging adds its own version envelope, and the rebrand flagged in TMC SM 1.4.3 may also apply to `fluxcd2`. **Treat unavailable release notes for v2026.1.21 as a Phase B hold-point**, not a go-ahead with assumptions.

### Dual-Flux ownership: the main break vector

TMC's CD enable behavior, per the [Enable CD docs](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-mission-control-self-managed/1-4/tmc-self-managed-documentation/using-tmc/managing-cluster-resources-with-continuous-delivery/enable-continuous-delivery-for-a-cluster-or-cluster-group.html):

> If Flux CRDs are present, TMC uses the currently installed instance rather than installing a new one. If the CRDs are not present, TMC installs the Flux source controller and Kustomize controller and subsequently manages their lifecycles.

Translation: on any cluster that already has the Tanzu Standard `fluxcd2` package installed, TMC's CD piggybacks on those CRDs and *kapp-controller* — not TMC — owns the Flux lifecycle. When Phase B bumps the Standard Repo, kapp-controller reconciles a new `fluxcd2` package version, which can:

- Change the `helm.toolkit.fluxcd.io` / `source.toolkit.fluxcd.io` / `kustomize.toolkit.fluxcd.io` CRD `storage` version.
- Trigger the documented [API-group resolution error](https://knowledge.broadcom.com/external/article/369984/enable-continuous-delivery-for-a-tkgs-cl.html) (`failed to get API group resources: unable to retrieve the complete list of server APIs: helm.toolkit.fluxcd.io/v2`) on subsequent CD reconciliations.
- Leave TMC's CD agents pointing at API versions the controller no longer serves.

This is the most plausible way the Phase B upgrade silently breaks a Phase A cluster's CD without breaking the TMC SM upgrade itself.

### Pre-Phase B inventory

On the TMC SM target cluster and on every CD-enabled Phase A workload cluster, capture:

- Whether `fluxcd2` (or any `fluxcd-*` package) is installed via `tanzu package installed list -A` and which namespace owns it.
- Image tags currently running for source/kustomize/helm/notification controllers (`kubectl -n <ns> get deploy -o wide`).
- CRD storage versions: `kubectl get crd helmreleases.helm.toolkit.fluxcd.io -o jsonpath='{.spec.versions[?(@.storage)].name}'` (and equivalents for `gitrepositories`, `kustomizations`, `ocirepositories`, `helmrepositories`, `helmcharts`, `buckets`).
- Whether CD is TMC-managed on each cluster, and whether any non-TMC Flux `HelmRelease`/`Kustomization` resources exist.

This inventory is what tells you, after Phase B, whether anything actually changed underneath you.

### Mitigation options

- **Get v2026.1.21 release notes before scheduling Phase B.** Confirm component versions, package renames, and CRD storage version changes. If notes aren't published, hold Phase B.
- **Consider disabling TMC CD on CD-enabled Phase A clusters across the Phase B window**, then re-enabling after. Brief CD outage; in return, TMC owns Flux lifecycle on those clusters again (CRDs reinstalled by TMC after re-enable) and Phase B can't break the CD path. Note that disable does not remove `tanzu-fluxcd-packageinstalls` resources cleanly — per [KB 375864](https://knowledge.broadcom.com/external/article/375864/how-to-remove-the-flux-cd-package-after.html), expect to clean up orphan package installs manually.
- **If both `fluxcd2` and TMC CD remain co-resident across Phase B**, treat the *first* CD reconciliation after Phase B as the canary — a forced `flux reconcile kustomization ...` against a known-good GitRepository on a Phase A cluster, with controller logs tailed. If it fails with `failed to get API group resources`, halt Phase C and disable/re-enable CD on the affected clusters before continuing.
- **Update Phase B verification** to include the explicit Flux checks already listed under Phase B above. They aren't optional — they are the only check that distinguishes "TMC SM upgraded cleanly" from "Phase B silently moved Flux out from under CD."

## What not to do

- Don't refactor the numbered-scripts structure; keep new behavior behind env vars and minor edits to the existing scripts.
- Don't add filtering inside `utils/` helpers in a way that silently changes behavior of scripts that don't opt in — start by passing the new filter explicitly per script.
- Don't reorder phases. Cluster-group and workspace import must precede cluster onboarding (cluster spec references `clusterGroupName`; namespace imports reference workspaces).
- Don't deregister the source MC as part of a per-cluster run — that is the "all non-prod WCs done" final step, not part of the inner loop.
- Don't run any `*-offboard.sh` against the real source without first dry-running the corresponding `*-export.sh` and visually confirming `data/clusters/mc_list.yaml` (and the per-cluster filter, when set) match *only* the intended target.
- Don't upgrade the source TMC during the migration window, and don't upgrade the destination to 1.4.4 before the Phase A soak finishes — see [Sequencing the destination 1.4.4 upgrade](#sequencing-the-destination-144-upgrade).
- Don't run Phase B against an unread set of release notes. v2026.1.21 Standard Repo contents and TMC SM 1.4.4 known-issue list are the inputs that decide whether Phase B's Flux behavior is safe — see [FluxCD and Standard Repository upgrade](#fluxcd-and-standard-repository-upgrade).
