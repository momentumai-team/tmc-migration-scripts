# Tanzu Mission Control Self Managed Migration Scripts

This repo holds bash scripts and a Jupyter notebook for migrating from a **TMC Self-Managed (SM) source** stack to a **TMC SM destination** stack. It is a fork of the [vmware-samples/tmc-migration-scripts](https://github.com/vmware-samples/tmc-migration-scripts) POC (originally TMC SaaS → SM); see [`migration-repurpose.md`](./migration-repurpose.md) for the rationale, fork-specific goals (non-prod-only, one cluster at a time), and the running change log.

## Testing the Export

Given that the migration process involves moving cluster management from a source to target TMC,
there is some risk to make sure the target ends up in the same state as the source.

For this reason the steps are separated into separate scripts,
and covered individually in the notebook.

Scripts 1->30 involve exporting TMC management data, and are non-destructive to the source TMC instance.

An example script is provided at `100-export.sh`.

Usage:

```bash
./100-export.sh <tmc api access username> <tmc api access password> <fqdn of tmc instance> \
     <management cluster filter> \
     <workload cluster filter> \
     <cluster group filter>
```

Example:

```bash
./100-export.sh admin '<tmc admin password>' tmc.lab1.mmtm.ai 'supervisor' 'dev1' 'dev'
```

where the name of the filtered management cluster is `supervisor`,
the name of the cluster group is `dev`,
and the name of the cluster is `dev1`.

You can also add multiple values for the filters via comma separation.

## Script Index

| Script                                                                                                   | Description                                                  | Status | Notes                                                                                                                                                      |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [001-base-source\_stack-connect.sh](./001-base-source_stack-connect.sh)                                  | Authenticate and connect to the source TMC SM stack          | READY  | Uses `TMC_SOURCE_USERNAME` / `TMC_SOURCE_PASSWORD` / `TMC_SOURCE_DNS` (optional `TMC_SOURCE_IDP_MFA_ENABLED`). Rerun if the `migration` context expires. |
| [002-base-clustergroups-export.sh](./002-base-clustergroups-export.sh)                                   | Export cluster groups                                        | READY  |                                                                                                                                                            |
| [003-base-workspaces-export.sh](./003-base-workspaces-export.sh)                                         | Export workspaces                                            | READY  |                                                                                                                                                            |
| [004-admin-roles-export.sh](./004-admin-roles-export.sh)                                                 | Export roles under Administration                            | READY  |                                                                                                                                                            |
| [005-admin-credentials-export.sh](./005-admin-credentials-export.sh)                                     | Export credentials under Administration-Accounts             | READY  |                                                                                                                                                            |
| [006-admin-access-export.sh](./006-admin-access-export.sh)                                               | Export access under Administration                           | READY  |                                                                                                                                                            |
| [007-admin-proxy-export.sh](./007-admin-proxy-export.sh)                                                 | Export proxy configuration under Administration              | READY  |                                                                                                                                                            |
| [008-admin-image-registry-export.sh](./008-admin-image-registry-export.sh)                               | Export image-registry under Administration                   | READY  |                                                                                                                                                            |
| [009-admin-settings-export.sh](./009-admin-settings-export.sh)                                           | Export settings under Administration                         | READY  |                                                                                                                                                            |
| [010-clustergroup-secrets-export.sh](./010-clustergroup-secrets-export.sh)                               | Export k8s secret resources of cluster groups                | READY  |                                                                                                                                                            |
| [011-clustergroup-secret-exports-export.sh](./011-clustergroup-secret-exports-export.sh)                 | Export k8s secret export resources of cluster groups         | READY  |                                                                                                                                                            |
| [012-clustergroup-continuous-deliveries-export.sh](./012-clustergroup-continuous-deliveries-export.sh)   | Export  fluxcd resources of cluster groups                   | READY  |                                                                                                                                                            |
| [013-clustergroup-repository-credentials-export.sh](./013-clustergroup-repository-credentials-export.sh) | Export git repo credential resources of cluster groups       | READY  | REST API call against the source stack (via `utils/sm-api-call.sh`)                                                                                       |
| [014-clustergroup-git-repositories-export.sh](./014-clustergroup-git-repositories-export.sh)             | Export git repository resources of cluster groups            | READY  |                                                                                                                                                            |
| [015-clustergroup-kustomizations-export.sh](./015-clustergroup-kustomizations-export.sh)                 | Export kustomization resources of cluster groups             | READY  |                                                                                                                                                            |
| [016-clustergroup-helms-export.sh](./016-clustergroup-helms-export.sh)                                   | Export helm resources of cluster groups                      | READY  |                                                                                                                                                            |
| [017-clustergroup-helm-releases-export.sh](./017-clustergroup-helm-releases-export.sh)                   | Export helm release resources of cluster groups              | READY  |                                                                                                                                                            |
| [018-cluster-namespaces-export.sh](./018-cluster-namespaces-export.sh)                                   | Export managed namespace resources of clusters               | READY  |                                                                                                                                                            |
| [019-cluster-secrets-export.sh](./019-cluster-secrets-export.sh)                                         | Export k8s secret resources of clusters                      | READY  |                                                                                                                                                            |
| [020-cluster-secret-exports-export.sh](./020-cluster-secret-exports-export.sh)                           | Export k8s secret export resources of clusters               | READY  |                                                                                                                                                            |
| [021-cluster-continuous-deliveries-export.sh](./021-cluster-continuous-deliveries-export.sh)             | Export  fluxcd resources of clusters                         | READY  |                                                                                                                                                            |
| [022-cluster-repository-credentials-export.sh](./022-cluster-repository-credentials-export.sh)           | Export git repo credential resources of clusters             | READY  |                                                                                                                                                            |
| [023-cluster-git-repositories-export.sh](./023-cluster-git-repositories-export.sh)                       | Export git repository resources of clusters                  | READY  |                                                                                                                                                            |
| [024-cluster-kustomizations-export.sh](./024-cluster-kustomizations-export.sh)                           | Export kustomization resources of clusters                   | READY  |                                                                                                                                                            |
| [025-cluster-helms-export.sh](./025-cluster-helms-export.sh)                                             | Export helm resources of clusters                            | READY  |                                                                                                                                                            |
| [026-cluster-helm-releases-export.sh](./026-cluster-helm-releases-export.sh)                             | Export helm release resources of clusters                    | READY  |                                                                                                                                                            |
| [027-cluster-data\_protection-export.sh](./027-cluster-data_protection-export.sh)                        | Export data protection resources                             | READY  |                                                                                                                                                            |
| [028-base-access-policies-export.sh](./028-base-access-policies-export.sh)                                       | Export access policies                                                             | READY  |                                                                                                                                                            |
| [029-base-policy-templates-export.sh](./029-base-policy-templates-export.sh)                                     | Export policy templates                                                            | READY |                                                                                                                                                            |
| [030-base-policy-assignments-export.sh](./030-base-policy-assignments-export.sh)                                 | Export policy assignments                                                     | READY |                                                                                                                                                            |
| [031-base-managed\_clusters-export.sh](./031-base-managed_clusters-export.sh)                        | Export the metadata of the managed TKG clusters from the source TMC SM before offboarding     | READY  | VKS (aka. TKGs) and TKGm clusters. Honors `TMC_MC_FILTER` and `TMC_WC_FILTER`.                                                                            |
| [031-base-managed\_clusters-offboard.sh](./031-base-managed_clusters-offboard.sh)                        | Unmanage workload clusters from the source TMC SM; optionally deregister the MC               | READY  | VKS (aka. TKGs) and TKGm clusters. Honors `TMC_WC_FILTER`. MC deregister gated by `TMC_DEREGISTER_MC=true` and a completeness check — see notes below.    |
| [032-base-attached\_clusters-export.sh](./032-base-attached_clusters-export.sh)    | Export the metadata of the attached clusters from the source TMC SM before offboarding        | READY  | Attached clusters                                                                                                                                          |
| [032-base-attached\_clusters-offboard.sh](./032-base-attached_clusters-offboard.sh)    | Offboard the attached clusters from the source TMC SM                                         | READY  | Attached clusters                                                                                                                                          |
| [033-base-sm\_stack-connect.sh](./033-base-sm_stack-connect.sh)                                          | Connect to the TMC SM stack                                                             |   READY     |                                                                                                                                                            |
| [034-base-clustergroups-import.sh](./034-base-clustergroups-import.sh)                                   | Import cluster-groups into TMC SM                            | READY  |                                                                                                                                                            |
| [035-base-workspaces-import.sh](./035-base-workspaces-import.sh)                                         | Import workspaces into TMC SM                                | READY  |                                                                                                                                                            |
| [036-admin-roles-import.sh](./036-admin-roles-import.sh)                                                 | Import roles into TMC SM                                     | READY  |                                                                                                                                                            |
| [037-admin-credentials-create-template.sh](./037-admin-credentials-create-template.sh)                   | Create post template yaml for each credential                | READY  | Notes: User need to manually fill in the missing field values such as credentials or CA/Certs                                                              |
| [037-admin-credentials-import.sh](./037-admin-credentials-import.sh)                                     | Import credentials with template yaml                        | READY  | Run 037-admin-credentials-create-template.sh before execute this step.                                                                                     |
| [038-admin-proxy-create-template.sh](./038-admin-proxy-create-template.sh)                               | Create post template yaml for each proxy                     | READY  | Notes: User need to manually fill in the missing field values such as credentials or CA/Certs                                                              |
| [038-admin-proxy-import.sh](./038-admin-proxy-import.sh)                                                 | Import proxy with template yaml                              | READY  | Run 038-admin-proxy-create-template.sh before execute this step.                                                                                           |
| [039-admin-image-registry-create-template.sh](./039-admin-image-registry-create-template.sh)             | Create post template yaml for each image-registry            | READY  | Notes: User need to manually fill in the missing field values such as credentials or CA/Certs                                                              |
| [039-admin-image-registry-import.sh](./039-admin-image-registry-import.sh)                               | Import image-registry with template yaml                     | READY  | Run 039-admin-image-registry-create-template.sh before execute this step.                                                                                  |
| [040-clustergroup-secrets-import.sh](./040-clustergroup-secrets-import.sh)                               | Import k8s secret resources to cluster groups                | READY  | Users must manually fill in the missing data field depending on the type of k8s secret                                                                    |
| [041-clustergroup-secret-exports-import.sh](./041-clustergroup-secret-exports-import.sh)                 | Import k8s secret export resources to cluster groups         | READY  |                                                                                                                                                            |
| [042-clustergroup-continuous-deliveries-import.sh](./042-clustergroup-continuous-deliveries-import.sh)   | Import fluxcd resources to cluster groups                    | READY  |                                                                                                                                                            |
| [043-clustergroup-repository-credentials-import.sh](./043-clustergroup-repository-credentials-import.sh) | Import git repository credential resources to cluster groups | READY  | Users must manually fill in the missing data field depending on the type of credential                                                                    |
| [044-clustergroup-git-repositories-import.sh](./044-clustergroup-git-repositories-import.sh)             | Import git repository resources to cluster groups            | READY  |                                                                                                                                                            |
| [045-clustergroup-kustomizations-import.sh](./045-clustergroup-kustomizations-import.sh)                 | Import kustomization resources to cluster groups             | READY  |                                                                                                                                                            |
| [046-clustergroup-helms-import.sh](./046-clustergroup-helms-import.sh)                                   | Import helm resources to cluster groups                      | READY  |                                                                                                                                                            |
| [047-clustergroup-helm-releases-import.sh](./047-clustergroup-helm-releases-import.sh)                   | Import helm release resources to cluster groups              | READY  |                                                                                                                                                            |
| [048-base-managed\_clusters-onboard.sh](./048-base-managed_clusters-onboard.sh)                          | Onboard the managed TKG clusters to TMC SM                   | READY    | - VKS (aka. TKGs) and TKGm clusters  - Prepare the required MC Kubeconfig index file with [048-base-managed\_clusters-input\_from\_user.sh](./048-base-managed_clusters-input_from_user.sh) - Ensure stale source-TMC annotations and agents on clusters get removed with [048-base-managed_clusters-ensure-cleanup.sh](./048-base-managed_clusters-ensure-cleanup.sh) |
| [049-base-attached\_clusters-onboard.sh](./049-base-attached_clusters-onboard.sh)                         | Onboard the attached clusters to TMC SM              | READY    | Attached clusters  - Prepare the required WC Kubeconfig index file with [049-base-attached\_clusters-input\_from\_user.sh](./049-base-attached_clusters-input_from_user.sh)           |
| [049-base-whole\_clusters-check\_readiness.sh](./049-base-whole_clusters-check_readiness.sh)                         | Check readiness of all onboarded clusters              | READY    | Include both managed clusters and attached clusters           |
| [050-cluster-namespaces-import.sh](./050-cluster-namespaces-import.sh)                                   | Import managed namespace resources to clusters               | READY  |                                                                                                                                                            |
| [051-cluster-secrets-import.sh](./051-cluster-secrets-import.sh)                                         | Import k8s secret resources to clusters                      | READY  | Users must manually fill in the missing data field depending on the type of k8s secret                                                                    |
| [052-cluster-secret-exports-import.sh](./052-cluster-secret-exports-import.sh)                           | Import k8s secret export resources to clusters               | READY  |                                                                                                                                                            |
| [053-cluster-continuous-deliveries-import.sh](./053-cluster-continuous-deliveries-import.sh)             | Import fluxcd resources to clusters                          | READY  |                                                                                                                                                            |
| [054-cluster-repository-credentials-import.sh](./054-cluster-repository-credentials-import.sh)           | Import git repository credential resources to clusters       | READY  | Users must manually fill in the missing data field depending on the type of credential                                                                    |
| [055-cluster-git-repositories-import.sh](./055-cluster-git-repositories-import.sh)                       | Import git repository resources to clusters                  | READY  |                                                                                                                                                            |
| [056-cluster-kustomizations-import.sh](./056-cluster-kustomizations-import.sh)                           | Import kustomization resources to clusters                   | READY  |                                                                                                                                                            |
| [057-cluster-helms-import.sh](./057-cluster-helms-import.sh)                                             | Import helm resources to clusters                            | READY  |                                                                                                                                                            |
| [058-cluster-helm-releases-import.sh](./058-cluster-helm-releases-import.sh)                             | Import helm releases resources to clusters                   | READY  |                                                                                                                                                            |
| [059-admin-settings-import.sh](./059-admin-settings-import.sh)                                           | Import settings to TMC SM                                    | Ready  |                                                                                                                                                            |
| [060-admin-access-import.sh](./060-admin-access-import.sh)                                               | Import access to TMC SM                                      | Ready  |                                                                                                                                                            |
| [061-base-access-policies-import.sh](./061-base-access-policies-import.sh)                               | Import access policies on organization/clustegroups/workspaces                                                             | READY | The customer should manually edit the access policies with correct user and usergroup identities in the idP of TMC SM after imported.                                                                                                                                                           |
| [061-cluster-access-policies-resync.sh](./061-cluster-access-policies-resync.sh)                         | Clean up stale rolebindings and resync them on clusters/namespaces                                                             | READY |                                                                                                                                                             |
| [062-base-policy-templates-import.sh](./062-base-policy-templates-import.sh)                             | Import policy templates                                                            | READY  |                                                                                                                                                            |
| [063-base-policy-assignments-import.sh](./063-base-policy-assignments-import.sh)                         | Import policy assignments on organization/clustergroups/workspaces                                                             | READY |                                                                                                                                                            |
| [063-cluster-policy-assignments-import.sh](./063-cluster-policy-assignments-import.sh)                   |  Import policy assignments on clusters                                                            | READY |                                                                                                                                                            |
| [064-cluster-data\_protection-import.sh](./064-cluster-data_protection-import.sh)                        |  Import data protections                                     | READY  |                                                                                                                                                            |
| [070-cluster-source-cleanup.sh](./070-cluster-source-cleanup.sh)                                         | Source-side cleanup (per WC): delete the orphan cluster-scoped CD records (kustomizations, git repositories, repository secrets, CD-enable) that `031`-offboard leaves on the **source** after a WC is unmanaged | READY | Runbook step 9, run while the source MC is still registered. Requires `TMC_WC_FILTER`. **Dry run by default** — set `TMC_CLEANUP_SOURCE=true` to delete. See migration-repurpose.md "Source-side cleanup". |
| [071-clustergroup-source-cleanup.sh](./071-clustergroup-source-cleanup.sh)                               | Source-side cleanup (final): tear down the non-prod cluster group(s) and their group-scoped CD/secret records on the **source** | READY | Run after all non-prod WCs are drained and the MC is deregistered. Requires `TMC_CG_FILTER`. **Dry run by default**; `TMC_CLEANUP_SOURCE=true` to delete. **Refuses (fail-closed)** any group that still has live member clusters, so it can never delete a group shared with prod. |
| [100-export.sh](./100-export.sh)                                                                         | Phase wrapper: archive `./data`, connect to the source, and run the exports `002`–`031-export` | READY | Non-destructive to the source. Args: `<username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>`. See [Using the phase wrapper scripts](#using-the-phase-wrapper-scripts-recommended). |
| [110-offboard.sh](./110-offboard.sh)                                                                     | Phase wrapper: offboard all WCs and deregister the MC from the source (`031-offboard`) | READY | Destructive to the source. Forces `TMC_DEREGISTER_MC=true` and unsets `TMC_WC_FILTER` (the `wc_filter` arg is ignored). Same 6 args as `100`. |
| [200-import-phase1.sh](./200-import-phase1.sh)                                                           | Phase wrapper: connect to the destination and import base/admin/cluster-group resources (`034`–`047`) | READY | Interactive (manual template/secret steps); fail-fast; idempotent. Args: `<username> <password> <dns>`. |
| [210-onboard.sh](./210-onboard.sh)                                                                       | Phase wrapper: connect to the destination and onboard managed (`048`) + attached (`049`) clusters, then readiness check | READY | Interactive (kubeconfig path placeholders). Attached-cluster onboarding auto-skipped when none exported. Args: `<username> <password> <dns>`. |
| [220-import-phase2.sh](./220-import-phase2.sh)                                                           | Phase wrapper: connect to the destination and import cluster add-ons, admin settings/access, policies, DP (`050`–`064`) | READY | Interactive (manual secret steps); fail-fast; idempotent. Needs `ADMIN_IDP_GROUP`/`MEMBER_IDP_GROUP` for `061-*`. Args: `<username> <password> <dns>`. |
| [300-source-cleanup.sh](./300-source-cleanup.sh)                                                         | Interactive wrapper that runs 070 then 071 with a preview-then-confirm gate | READY | For each phase: previews the deletes as a dry run, then requires the operator to **type the target name** to authorize the real delete (anything else skips). Non-TTY stdin stays a dry run. Establishes the `migration` context first (via 001), like the other source-side orchestrators. Args: `<username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>`. This is the recommended way to run the destructive source cleanup. |

**Note:**
Script file name follows pattern `<index>-<scope>-<resource>-<operation>.sh`.
The scope includes:

* Base

* Administration

* Cluster group

* Cluster

Operation includes:

* Connect: script used to authenticate and connect to a TMC stack (source or destination, both SM in this fork)

* Export: script used to export resources from the source TMC SM stack

* Import: script used to import previously-exported resources into the destination TMC SM stack

* Offboard: unmanage the workload cluster and (optionally, when explicitly opted in) deregister the management cluster from the source TMC SM

* Onboard: register the management cluster into the destination TMC SM and manage the workload clusters

* Source-cleanup: reclaim the source TMC SM by deleting the migration objects it still holds after offboarding — the cluster-scoped CD orphans per WC (070) and the non-prod cluster group(s) and their group-scoped resources (071). Both dry-run by default (`TMC_CLEANUP_SOURCE=true` to apply), filter-scoped, and never touch org-wide resources shared with prod. This step is unique to this fork: the upstream SaaS→SM POC skipped source cleanup because the SaaS org was discarded, whereas here the source is a surviving production instance.

## Run the Scripts

There are two ways to drive a migration run:

* **The phase wrapper scripts** (`100`/`110`/`200`/`210`/`220`/`300`) — recommended. Each wrapper takes the connection details as positional arguments, sets the env vars for you, establishes the tanzu CLI context, and runs the relevant numbered sub-scripts in order (pausing at the manual steps). See **[Using the phase wrapper scripts](#using-the-phase-wrapper-scripts-recommended)** below.
* **The individual numbered scripts** — run each `NNN-*.sh` yourself after exporting the env vars by hand. See **[In Manual way](#in-manual-way)**.

### Using the phase wrapper scripts (recommended)

The six wrappers split a single-cluster migration into ordered phases. Run them in numeric order; the source-side phases (`100`, `110`, `300`) take the **source** SM connection details and the destination-side phases (`200`, `210`, `220`) take the **destination** SM connection details. For every wrapper, set `TMC_SOURCE_IDP_MFA_ENABLED=true` (source phases) or `TMC_SM_IDP_MFA_ENABLED=true` (destination phases) beforehand if the corresponding IDP requires MFA. The destination phases (`200`/`220`) run fail-fast (`set -eE -o pipefail`) and the sub-scripts are idempotent, so a failed phase can be fixed and re-run safely.

> ⚠️ **These wrappers cannot be run unattended.** The `200`, `210`, and `220` wrappers **block on interactive `read` prompts** while you hand-edit generated template, secret, and kubeconfig files, and `300` blocks on a type-the-target-name confirmation before each destructive delete. Each pause halts the run until you edit the named file(s) and press **Enter** (or type the confirmation token) at the terminal. Run them **attached to an interactive terminal** — piping from a non-TTY stdin will either race past the edits (`200`/`210`/`220`) or fail safe to a dry run (`300`). The exact pause points for each wrapper are listed in its section below.

#### 100-export.sh — export from the source (non-destructive)

Archives any existing `./data` to `data_<timestamp>.tar.gz`, removes `./data`, connects to the source SM stack (via `001`), and runs the export scripts `002`–`031-export`. It does **not** offboard anything.

```bash
./100-export.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
```

Example:

```bash
./100-export.sh admin '<source password>' tmc.source.example.com 'supervisor' 'dev1' 'dev'
```

The three filters (`mc_filter`, `wc_filter`, `cg_filter`) map to `TMC_MC_FILTER` / `TMC_WC_FILTER` / `TMC_CG_FILTER` and accept comma-separated values or `'*'` for all. This is the wrapper equivalent of the `100-export.sh` example shown under [Testing the Export](#testing-the-export).

#### 110-offboard.sh — offboard from the source (destructive to the source)

Assumes the `migration` context from `100` already exists. Runs `031-base-managed_clusters-offboard.sh` to **unmanage the workload clusters and deregister the management cluster** from the source SM. This wrapper forces `TMC_DEREGISTER_MC=true` and unsets `TMC_WC_FILTER`, so it offboards **all** WCs under the MC and then deregisters it — the `wc_filter` argument is accepted for signature parity but ignored. Only run it once every WC under the MC has been migrated.

```bash
./110-offboard.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
```

Example:

```bash
./110-offboard.sh admin '<source password>' tmc.source.example.com 'supervisor' 'dev1' 'dev'
```

#### 200-import-phase1.sh — import base/admin/cluster-group resources into the destination

Connects to the destination SM stack (via `033`) and runs imports `034`–`047`: cluster groups, workspaces, roles, credentials/proxy/image-registry (generating templates and pausing for you to fill them in), and the cluster-group add-on resources (secrets, secret-exports, CD, repository credentials, git repos, kustomizations, helm, helm-releases). Run this **before** onboarding clusters.

> ⚠️ **Manual pause points (cannot run unattended).** This wrapper stops at four `read` prompts. At each one, edit the named file(s), then press **Enter** to continue:
>
> 1. **Credentials** — after `037-admin-credentials-create-template.sh`: fill in the missing CA/certificate and credential fields in `data/credential/template/*.yaml`.
> 2. **Proxy** — after `038-admin-proxy-create-template.sh`: fill in the missing fields in the generated proxy template files.
> 3. **Image registry** — after `039-admin-image-registry-create-template.sh`: fill in the missing fields in the generated image-registry template files.
> 4. **Cluster-group git repository credentials** — before `043-clustergroup-repository-credentials-import.sh`: fill in the missing `atomicSpec.data.data` fields in `data/clustergroup-repository-credentials/*.yml`. Base64-encode each value **without a trailing newline** (use `printf '%s' '<value>' | base64`, **not** `echo`). If this import fails, the wrapper aborts before creating git repositories — fix the `*.yml` and re-run.

```bash
./200-import-phase1.sh <username> <password> <dns>
```

Example:

```bash
./200-import-phase1.sh admin '<destination password>' tmc.destination.example.com
```

#### 210-onboard.sh — onboard clusters into the destination

Connects to the destination SM stack and onboards clusters: generates the MC kubeconfig index file (`048-input_from_user`, pausing for you to replace the path placeholders), ensures stale source-TMC annotations/agents are removed (`048-ensure-cleanup`), onboards the managed clusters (`048-onboard`), onboards attached clusters (`049`) **only if any were exported**, and runs the readiness check (`049-check_readiness`).

> ⚠️ **Manual pause points (cannot run unattended).** This wrapper stops to let you wire up real kubeconfigs. At each one, edit the named index file, then press **Enter** to continue:
>
> 1. **Managed-cluster kubeconfigs** — after `048-base-managed_clusters-input_from_user.sh`: replace every `/path/to/the/real/mc_kubeconfig/file` placeholder in `data/clusters/mc-kubeconfig-index-file` with the real kubeconfig path for each management cluster.
> 2. **Attached-cluster kubeconfigs** — *only when attached clusters were exported*, after `049-base-attached_clusters-input_from_user.sh`: replace every `/path/to/the/real/wc_kubeconfig/file` placeholder in `data/clusters/attached-wc-kubeconfig-index-file`. If no attached clusters were exported, the wrapper skips this prompt automatically.

```bash
./210-onboard.sh <username> <password> <dns>
```

Example:

```bash
./210-onboard.sh admin '<destination password>' tmc.destination.example.com
```

Onboarding tuning env vars still apply: set `CLUSTERS_ONBOARD_BATCH_SIZE` for the parallel batch size (default 1) and `CLUSTER_ONBOARD_TIMEOUT` for large clusters (default 10 min).

#### 220-import-phase2.sh — import cluster add-ons and policies into the destination

Connects to the destination SM stack and runs the post-onboarding imports `050`–`064`: cluster namespaces, secrets/secret-exports (pausing to fill in secret data), CD, repository credentials, git repos, kustomizations, helm/helm-releases, admin settings and access, access policies, policy templates, policy assignments, and data protection. The `061-*` scripts need the destination IDP admin/member group names; override the defaults if they differ from `tmc:admin` / `tmc:member`:

> ⚠️ **Manual pause points (cannot run unattended).** This wrapper stops at two `read` prompts. At each one, edit the named file(s), then press **Enter** to continue:
>
> 1. **Cluster k8s secrets** — before `051-cluster-secrets-import.sh`: fill in the missing `spec.data` fields in `data/cluster-secrets/*.yml` (secret data is not exported). Per type: `SECRET_TYPE_OPAQUE` → `spec.data.<key>: <base64 value>`; `SECRET_TYPE_DOCKERCONFIGJSON` → `spec.data.".dockerconfigjson": <base64 json>`.
> 2. **Cluster git repository credentials** — before `054-cluster-repository-credentials-import.sh`: fill in the missing data fields in `data/cluster-repository-credentials/*.yml` (per credential type: USERNAME_PASSWORD / SSH / CACert). If this import fails, the wrapper aborts before creating git repositories — fix the `*.yml` and re-run. (Cluster-group-derived secrets are skipped here; they were imported at cluster-group scope in phase 1 and propagated by TMC.)
>
> Also note the `061-*` access policies are imported with the **source** IDP identities — after this phase completes, manually edit them with the correct destination user/usergroup identities.

```bash
export ADMIN_IDP_GROUP="tmc:admin"
export MEMBER_IDP_GROUP="tmc:member"
./220-import-phase2.sh <username> <password> <dns>
```

Example:

```bash
./220-import-phase2.sh admin '<destination password>' tmc.destination.example.com
```

#### 300-source-cleanup.sh — reclaim the source (interactive, destructive)

Runs the two source-side cleanup phases (`070` per-WC CD orphans, then `071` cluster-group teardown) behind a preview-then-confirm gate. For each phase it first runs a dry run, prints exactly what would be deleted, and only applies the deletes if you type the target name (the WC filter for `070`, the CG filter for `071`); anything else skips the phase, and non-terminal stdin stays a dry run. Establishes the `migration` context first (via `001`). See step 22 of [In Manual way](#in-manual-way) for when to run each phase.

> ⚠️ **Manual confirmation gate (cannot run unattended).** This wrapper is destructive and runs against the **production source**. It never deletes on its own — for each phase it stops after the dry-run preview and waits for you to authorize:
>
> 1. **Phase 070 (per-WC CD orphans)** — type the **WC filter** (`<wc_filter>`) exactly to apply; anything else skips the phase.
> 2. **Phase 071 (cluster-group teardown)** — type the **CG filter** (`<cg_filter>`) exactly to apply; anything else skips the phase. `071` fails closed on any group that still has live members, so previewing it mid-migration is safe.
>
> If stdin is **not** a terminal, both phases are left as dry runs (fail-safe) — nothing is deleted.

```bash
./300-source-cleanup.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
```

Example:

```bash
./300-source-cleanup.sh admin '<source password>' tmc.source.example.com non-prod-mgr dev2 dev
```

### In Manual way

1. Export the source-side connection env vars. Both source and destination are TMC Self-Managed, so source uses a distinct set of variable names to avoid colliding with the destination's `TMC_SELF_MANAGED_*` vars (step 5).

    ```shell
    export TMC_SOURCE_USERNAME=<source-admin-user@customer.com>
    export TMC_SOURCE_PASSWORD=<SOURCE-PASSWORD>
    export TMC_SOURCE_DNS=<source-tmc.tanzu.io>
    # If the source IDP requires MFA:
    # export TMC_SOURCE_IDP_MFA_ENABLED=true
    ```

    Run script [001-base-source\_stack-connect.sh](./001-base-source_stack-connect.sh) to create the `migration` tanzu CLI context against the source SM stack.

2. Export resources from the source TMC SM stack by running scripts **002 - 030**. Three optional filters narrow the export when only a subset is being migrated (all comma-separated, all independent, AND-combined with one another):

    ```shell
    # Cluster-group filter — honored by 002 and inline by 010–017.
    export TMC_CG_FILTER="cg1,cg2"

    # Management-cluster filter — honored by 031-export, utils/offboard-clusters.sh
    # (and transitively 019/022).
    export TMC_MC_FILTER="my_mc_1,my_mc_2"

    # Workload-cluster filter — honored by 031-export, 031-offboard (unmanage loop),
    # utils/offboard-clusters.sh (transitively 019/022), the cluster export scripts
    # 020/021/023–027 (inline on their cluster list calls; 027 also skips
    # non-matching clusters in its per-cluster data-protection loop), and 028/030.
    export TMC_WC_FILTER="wc_cluster_1,wc_cluster_2"
    ```

3. Export the managed clusters with script [031-base-managed\_clusters-export.sh](./031-base-managed_clusters-export.sh), then offboard them with script [031-base-managed\_clusters-offboard.sh](./031-base-managed_clusters-offboard.sh).

    By default `031-offboard` only **unmanages** workload clusters (respecting `TMC_WC_FILTER` when set); it does **not** deregister the management cluster itself. Deregister is the "we're done with this whole supervisor" step and is gated:

    ```shell
    # Optional, only when every WC under the MC has already been migrated:
    export TMC_DEREGISTER_MC=true
    ```

    With that flag set, the script also refuses deregister if `TMC_WC_FILTER` is set, or if any live WC under the MC is missing from the exported `data/clusters/wc_of_<mc>.yaml`. Re-run `031-export` (without `TMC_WC_FILTER`) before retrying.

4. Export the attached clusters with script [032-base-attached\_clusters-export.sh](./032-base-attached_clusters-export.sh). Then offboard the attached clusters from the source TMC SM by running script [032-base-attached\_clusters-offboard.sh](./032-base-attached_clusters-offboard.sh). Set the environment variable `CLUSTER_NAME_FILTER` to export the specified attached clusters only.

    ```shell
    export CLUSTER_NAME_FILTER="attached1,attached2"
    ```

5. Export the necessary environment variables to set up connection context of SM.

    ```shell
    export TMC_SELF_MANAGED_USERNAME=admin-user@customer.com
    export TMC_SELF_MANAGED_PASSWORD=Fake@Pass
    export TMC_SELF_MANAGED_DNS=tmc.tanzu.io
    ```

    Run script [033-base-sm\_stack-connect.sh](./033-base-sm_stack-connect.sh) to create context for connecting the SM stack.

    **Notes:** If MFA is enabled for the IDP, export this environment variable `export TMC_SM_IDP_MFA_ENABLED=true`.

6. Import resources `[cluster group, workspace, roles]` into SM by running scripts **034-036**.

7. \[👤 **USER ACTION REQUIRED**] List user actions needed for running scripts **037-039**.

* 7.1 Run 037-admin-credentials-create-template.sh to generate template yaml for each credential

    ```shell
      # data/credentials/template/*.yaml
      # Notes: User need to manually fill in the missing field values for each template yaml.
      ./037-admin-credentials-create-template.sh
    ```

    Template spec formats:

    ```yaml

    # 1.Spec Format for Self-provisioned: AWS S3 or S3 compatible
    spec:
        capability: DATA_PROTECTION
        data:
            keyValue:
                data:
                    aws_access_key_id: "<Your aws_access_key_id>"
                    aws_secret_access_key: "<Your aws_secret_access_key>"
                type: SECRET_TYPE_UNSPECIFIED
        meta:
            provider: GENERIC_S3
            temporaryCredentialSupport: false

    # 2.Spec Format for Self-provisioned: Azure Blob
    spec:
        capability: DATA_PROTECTION
        data:
            azureCredential:
                servicePrincipal:
                    azureCloudName: <AzurePublicCloud | AzureUSGovernmentCloud | AzureChinaCloud | AzureGermanCloud>
                    clientId: <Your clientId>
                    clientSecret: <Your clientSecret>
                    resourceGroup: <Your resource group>
                    subscriptionId: <Your subscriptionId>
                    tenantId: <Your tenantId>
        meta:
            provider: AZURE_AD
            temporaryCredentialSupport: false

    #3.Spec Format for Self-provisioned: AWS_EC2
    spec:
        capability: DATA_PROTECTION
        data:
            awsCredential:
                accountId: "<Your accountId or empty string>"
                iamRole:
                    arn: "<Your arn>"
                    extId: "<Your extId>"
        meta:
            provider: AWS_EC2
            temporaryCredentialSupport: false
    ```

* 7.2 Run 037-admin-credentials-import.sh to import credentials with template yaml files.

    ```shell
      # Please make sure you have already fill in the missing values for each template yaml file.
      # Notes: User need to manually fill in the missing field values for each template yaml.
      ./037-admin-credentials-import.sh
    ```

* 7.3 Run 038-admin-proxy-create-template.sh to generate template yaml for each proxy

    ```shell
      # data/proxy/template/*.yaml
      # Notes: User need to manually fill in the missing field values for each template yaml.
      ./038-admin-proxy-create-template.sh
    ```

    Template spec formats:

    ```yaml
    # remove the key pair under spec.data.data if empty or it can not pass the base64 validation by backend API.
    spec:
        capability: PROXY_CONFIG
        data:
            keyValue:
                data:
                    httpUserName: "<base64 string>"
                    httpPassword: "<base64 string>"
                    httpsUserName: "<base64 string>"
                    httpsPassword: "<base64 string>"
                    proxyCABundle: "<base64 string>"
                type: SECRET_TYPE_UNSPECIFIED
        meta:
            provider: PROVIDER_UNSPECIFIED
            temporaryCredentialSupport: false
    ```

* 7.4 Run 038-admin-proxy-import.sh to import proxy with template yaml files.

    ```shell
      # Please make sure you have already fill in the missing values for each template yaml file.
      # Notes: User need to manually fill in the missing field values for each template yaml.
      ./038-admin-proxy-import.sh
    ```

* 7.5 Run 039-admin-image-registry-create-template.sh to generate template yaml for each image-registry

    ```shell
      # data/image-registry/template/*.yaml
      # Notes: User need to manually fill in the missing field values for each template yaml.
      ./039-admin-image-registry-create-template.sh
    ```

    Template spec formats:

    ```yaml
    # 1. Spec Format for Image registry without username and password
    spec:
        capability: IMAGE_REGISTRY
        data:
            keyValue:
                data:
                    registry-url: <registry-url in base64 string>
        meta:
            provider: GENERIC_KEY_VALUE
            temporaryCredentialSupport: false


    # 2. Spec Format for Image registry with username and password
    spec:
        capability: IMAGE_REGISTRY
        data:
            keyValue:
                data:
                    .dockerconfigjson: "<base64 string or call ./utils/create-docker-config-json-base64.sh to generate base64 string>"
                    ca-cert: "<base64 string or remove key/value if not needed >"
                type: DOCKERCONFIGJSON_SECRET_TYPE
        meta:
            provider: GENERIC_KEY_VALUE
            temporaryCredentialSupport: false
    ```

  * 7.6 Run 039-admin-image-registry-import.sh to import proxy with template yaml files.

      ```shell
        # Please make sure you have already fill in the missing values for each template yaml file.
        # Notes: User need to manually fill in the missing field values for each template yaml.
        ./039-admin-image-registry-import.sh
      ```

8. \[👤 **USER ACTION REQUIRED**] List user action needed for running script **040**.

    User must manually fill in the missing data fields depending on the type of k8s secret into the manifests in directory `./data/clustergroup-secrets`

    * SECRET_TYPE_OPAQUE

    ```yaml
    spec:
      atomicSpec:
        data: # filled data field
          key1: base64-encoded-value1
          key2: base64-encoded-value2
        secretType: SECRET_TYPE_OPAQUE
    ```

    * SECRET_TYPE_DOCKERCONFIGJSON

    ```yaml
    spec:
      atomicSpec:
        data: # filled data field
          .dockerconfigjson: base64-encoded-dockerconfig-json-file
        secretType: SECRET_TYPE_DOCKERCONFIGJSON
    ```

9. Import resources `[secrets-exports, CD]` into SM by running scripts **041-042**.

10. \[👤 **USER ACTION REQUIRED**] List user action needed for running script **043**.

    Users must manually fill in the missing data field depending on the type of credential into the manifests in directory `./data/clustergroup-repository-credentials`

    * Username/Password

    ```yaml
    spec:
      atomicSpec:
        data: # filled data field
          data:
            username: bas64-encoded-username
            password: base64-encoded-password
        sourceSecretType: USERNAME_PASSWORD
    ```

    * SSH Authentication

    ```yaml
    spec:
      atomicSpec:
        data: # filled data field
          data:
            identity: bas64-encoded-ssh-identity
            known_hosts: base64-encoded-ssh-known-hosts
        sourceSecretType: SSH
    ```

    * CA Certificate

    ```yaml
    spec:
      atomicSpec:
        data: # filled data field
          data:
            ca.crt: bas64-encoded-ca-crt
            username: base64-encoded-username  # username and password are optional
            password: base64-encoded-password  # username and password are optional
        sourceSecretType: CACert
    ```

11. Imports resources `[clustergroup:git repo, clustergroup:kustomization, clustergroup:helm, clustergroup:helm-release]` by running scripts **044-047**.

12. Run script [048-base-managed\_clusters-input\_from\_user.sh](./048-base-managed_clusters-input_from_user.sh) to generate a Kubeconfig index file for the onboarding management clusters. Replace the path placeholders `/path/to/the/real/mc_kubeconfig/file` in the generated Kubeconfig index file.

    Then run script [048-base-managed_clusters-ensure-cleanup.sh](./048-base-managed_clusters-ensure-cleanup.sh) to check and ensure the stale source-TMC annotations and agents on clusters get removed.

    Then run script [048-base-managed\_clusters-onboard.sh](./048-base-managed_clusters-onboard.sh) to onboard the exported clusters onto SM.

    By default, clusters are onboarded sequentially. Set the CLUSTERS_ONBOARD_BATCH_SIZE environment variable to control the parallel batch size.
    By default, the timeout of onboarding a cluster is 10 min, set the CLUSTER_ONBOARD_TIMEOUT environment variable if the cluster has many nodes, it also depends on the performance of customer's environment, e.g approximate 3 min per node

13. Run script [049-base-attached\_clusters-input\_from_user.sh](./049-base-attached_clusters-input_from_user.sh) to generate a Kubeconfig index file for the attached clusters. Replace the path placeholders `/path/to/the/real/wc_kubeconfig/file` in the generated Kubeconfig index file.

    Then run script [049-base-attached\_clusters-onboard.sh](./049-base-attached_clusters-onboard.sh) to onboard the attached clusters onto SM.

14. Import resource `[namespace]` into SM by running script **050**.

15. \[👤 **USER ACTION REQUIRED**] List user actions for **051**.

    Users must manually fill in the missing data field depending on the type of k8s secret into the manifests in directory `./data/cluster-secrets`

    * SECRET_TYPE_OPAQUE

    ```yaml
    spec:
      data: # filled data field
        key1: base64-encoded-value1
        key2: base64-encoded-value2
      secretType: SECRET_TYPE_OPAQUE
    ```

    * SECRET_TYPE_DOCKERCONFIGJSON

    ```yaml
    spec:
      data: # filled data field
        .dockerconfigjson: base64-encoded-dockerconfig-json-file
      secretType: SECRET_TYPE_DOCKERCONFIGJSON
    ```

16. Import resources `[cluster:secret export, cluster:CD]` into SM by running scripts **052-053**

17. \[👤 **USER ACTION REQUIRED**] List user actions for 054.

    Users must manually fill in the missing data field depending on the type of credential into the manifests in directory `./data/cluster-repository-credentials`

    * Username/Password

    ```yaml
    spec:
      data: # filled data field
        data:
          username: bas64-encoded-username
          password: base64-encoded-password
      sourceSecretType: USERNAME_PASSWORD
    ```

    * SSH Authentication

    ```yaml
    spec:
      data: # filled data field
        data:
          identity: bas64-encoded-ssh-identity
          known_hosts: base64-encoded-ssh-known-hosts
      sourceSecretType: SSH
    ```

    * CA Certificate

    ```yaml
    spec:
      data: # filled data field
        data:
          ca.crt: bas64-encoded-ca-crt
          username: base64-encoded-username  # username and password are optional
          password: base64-encoded-password  # username and password are optional
      sourceSecretType: CACert
    ```

18. Import resources `[cluster:git, cluster:kustomization, cluster:helm, cluster:helm-release, admin:settings, admin:access]` into SM by running scripts **055-060**

19. Import resources `[access policies, policy templates, policy assignments]` into the destination SM by running scripts **061-063**.  **Notes**: The initial access policies are imported with the identity settings from the source TMC SM; the customer should manually edit the access policies with correct user and usergroup identities in the destination TMC SM's idP. To run the scripts **061-\***, also export the below env vars, which should be the same values as the settings idpGroupRoles.admin and idpGroupRoles.member of the destination TMC SM deployment.
    ```shell
    export ADMIN_IDP_GROUP="tmc:admin"
    export MEMBER_IDP_GROUP="tmc:member"
    ```
21. Import resources `[Data protection]` 064. **Notes**: TBD to clarify the credentials depends on by DP should be imported in the previous steps.

22. **Source-side cleanup (recommended: the interactive wrapper).** Reclaim the migration objects the offboarded clusters/groups left on the **source**. The wrapper [300-source-cleanup.sh](./300-source-cleanup.sh) runs both cleanup phases behind a preview-then-confirm gate — it dry-runs each phase, prints the deletes, and only applies the ones you authorize by typing the target name:

    ```shell
    ./300-source-cleanup.sh <username> <password> <dns> <mc_filter> <wc_filter> <cg_filter>
    ```

    Run it after each WC is healthy in the destination (confirm Phase 070, skip Phase 071 — it will refuse the group while the WC is still live), and again at the very end once every non-prod WC is drained and the MC is deregistered with `TMC_DEREGISTER_MC=true` (confirm Phase 071).

    To run the phases directly instead (both **dry-run by default**; `TMC_CLEANUP_SOURCE=true` to apply):

    ```shell
    # Per-WC CD orphans — while the source MC is still registered:
    TMC_MC_FILTER=<mc> TMC_WC_FILTER=<wc> ./070-cluster-source-cleanup.sh                     # dry run
    TMC_MC_FILTER=<mc> TMC_WC_FILTER=<wc> TMC_CLEANUP_SOURCE=true ./070-cluster-source-cleanup.sh

    # Cluster-group teardown — after the MC is deregistered (fail-closed on live members):
    TMC_CG_FILTER=<cg> ./071-clustergroup-source-cleanup.sh                                   # dry run
    TMC_CG_FILTER=<cg> TMC_CLEANUP_SOURCE=true ./071-clustergroup-source-cleanup.sh
    ```

### Use jupyter notebook

1. Install the jupyter lab by following its [guide](https://jupyter.org/install).

    ```shell
    pip install jupyterlab
    ```

1. Clone the repo and cd to the code folder.
1. Start the jupyter lab from the code folder.

    ```shell
    # --no-browser and --allow-root is optional.
    jupyter lab --no-browser --ip=0.0.0.0 --port=80 --allow-root
    ```

1. Open notebook `tmc-sm-migration.ipynb` to run migration steps.
