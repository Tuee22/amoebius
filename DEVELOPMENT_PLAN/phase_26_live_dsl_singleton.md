# Phase 26: Live DSL deploy via the replicas=1 singleton

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_19_object_reconciler.md, DEVELOPMENT_PLAN/phase_20_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_23_platform_backbone.md, DEVELOPMENT_PLAN/phase_24_platform_services_2.md, DEVELOPMENT_PLAN/phase_27_app_tenancy.md, DEVELOPMENT_PLAN/phase_30_release_lifecycle.md, DEVELOPMENT_PLAN/phase_31_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_37_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Turn the pre-cluster-proven DSL into a live deploy — hand the mandatory reconciler Lease from
> the observed bootstrap host to the Deployment-`replicas=1` control-plane singleton, then have that singleton
> decode one `.dhall` and reconcile the platform plus a trivial app onto a real cluster, with single-writer
> exclusion delegated to k8s/etcd and no amoebius election.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 25 gate (Keycloak-owned
ingress) and runs on the **linux-cpu** substrate in **Register 3** — live infrastructure: the single-node
`kind` cluster after Phases 17–25, with the full standing shape assembled by the registry/base-image work
(Phase 18), Vault/PKI (Phase 22), platform services (Phases 23–24), and Keycloak-owned edge (Phase 25), all
applied through the Phase-19 typed renderer + SSA reconciler onto Phase-21 retained storage. The control-plane singleton
role generalizes the prodbox root single-node control-plane behaviour and rides the shared daemon spine
proven in prodbox — but that is **sibling evidence, not an amoebius result**; amoebius has not yet built any
sprint here. Kubernetes/etcd supplies Lease exclusion; amoebius must still prove its bootstrap-host-holder →
observed release and holder absence on the same still-present Lease → singleton-holder handoff never
authorizes overlapping writers.

## Phase Summary

This phase makes the DSL **run live**. Its design half is already discharged in the pre-cluster band
(Registers 1–2, substrate `none`): the two typed gates — Gate 1, the Dhall typechecker (Phase 4), and Gate 2,
the in-process `Dhall.inputFile auto` decoder (Phase 5) — the illegal-state corpus and its per-entry
validation-locus ledger (Phase 6), the capacity/topology folds (Phase 7), the capability→provider→shape
binder and opaque provision seal (Phase 10), the pure `renderAll` goldens (Phase 13), and the
`chain`/`--dry-run` plan (Phase 14) were all
authored and proven **in-process, with no cluster**. Phase 26 adds the runtime residue: the in-cluster
**control-plane singleton** deployed as a Kubernetes **Deployment with `replicas=1`** — exactly one Lease-held
authority at a time, despite possible replacement-Pod overlap, holding total cluster + secret authority — that decodes the already-proven `InForceSpec` and runs the
idempotent `discover → diff → enact → re-observe` reconcile loop driving a **real** linux-cpu cluster toward
it, applying the standard platform stack plus a trivial app through the Phase-19 reconciler to convergence with
a leak-free teardown.

Single-writer authority for that singleton is **delegated to k8s/etcd**: the Deployment controller converges
to desired `replicas=1` and reschedules on node loss, but update/replacement may transiently expose distinct old,
terminating, and replacement Pod UIDs. Strict at-most-one-writer is therefore a Kubernetes `Lease` (the
etcd-backed client-go leader-election
object) — **never a bespoke amoebius election, no ranked-failover rule, no warm-standby candidate population,
no signed-commit-log protocol**. The singleton is **stateless at the pod level** — it holds no PVC; its
durable state is exclusively the Vault-enveloped MinIO bucket — so a lost pod loses nothing. As a regression
belt, the pre-cluster negative corpus of Phase 6 is re-run against this live deploy path and each fixture still
fails to type-check or decode — but that type/decode result was **already proven in the pre-cluster band**;
here it is a live guard, not the proof. Full app tenancy (own namespace, `<app>/<bucket>` ObjectStore,
in-namespace Sql) is deliberately deferred to Phase 27; the app here is trivial.

The initial ownership transition is explicit. Phase 19 acquired the deployment-global mandatory reconciler
Lease under the bootstrap-host holder before any host-driven apply and kept renewing it through Phases 21–25.
In this phase the host applies the singleton Deployment while retaining that Lease; the new Pod may load and
finish prerequisites but cannot mutate or advertise `/readyz`. The host then stops minting actions, drains
in-flight effects, releases the Lease, and freshly observes its holder absent/released. Only the authenticated
singleton Pod UID may acquire the same object. Its held-Lease readback plus `/readyz` Serving condition retires
the host's direct-apiserver authority. Lost responses, stale resourceVersions, watch gaps, or replacement-Pod
UID changes fail closed and re-observe; they never infer handoff from time.

**Substrate:** linux-cpu — the single-node `kind` cluster from Phases 17–25; no apple, linux-cuda, or windows
substrate is exercised by this phase's gate.

**Register:** 3 — live infrastructure (§K).

**Gate:** on a single-node linux-cpu `kind` cluster, one `.dhall` decodes and the **Deployment-`replicas=1`
control-plane singleton** — single-writer authority delegated to k8s/etcd, with **no amoebius election** — reconciles
the standard platform-service stack plus a trivial app to convergence and tears down leak-free, while the
pre-cluster (Phase-6) negative corpus, re-run against the same live deploy path, still fails at Gate 1 or
Gate 2 — a **Register-3** live-infrastructure check. Before the singleton's first mutation, the gate observes
the exact bootstrap-host holder drain and release, holder absence at a fresh resourceVersion, then acquisition
by the authenticated singleton Pod UID; the apiserver audit/watch history admits no overlapping holder or
mutation authority.

**Gate-integrity clauses (§M).** The gate is hardened as follows and passes only when every clause below holds:

- **Attribution via an OS-boundary observer (§M.5, forecloses the decorative-singleton cheat).** The gate
  harness (`test/integration/Phase22Gate.hs`) runs under a kubeconfig whose RBAC (a committed
  `test/fixtures/phase22/harness-rbac.yaml`) grants it exactly: `create`/`get`/`delete` on the singleton's own
  `Deployment`, `ServiceAccount`, and `RoleBinding`, and cluster-wide read-only (`get`/`list`/`watch`) —
  **and no write verb on any platform/app object kind**. Every platform-service and trivial-app object mutation
  observed in the gate window is read from the **apiserver audit log** (the OS-boundary observer — never a
  trace the singleton emits about itself) and each such write's `user.username` /
  `user.extra.authentication.kubernetes.io/…` MUST resolve to the singleton pod's in-cluster ServiceAccount;
  the audit log MUST record **zero** platform/app-object writes attributed to the harness principal. A run in
  which the harness principal issued any platform/app write, or in which the singleton SA issued none, fails.
- **History capacity is a gate precondition, not assumed retention.** Before the first platform/app mutation,
  the harness reads the Phase-17 `ControlPlaneStorageDemand` enforcement and proves Event/audit retention
  covers the complete declared gate observation window and that its rotated-byte peak remains inside
  `EngineSystemReserve`. A too-short history or over-carve configuration refuses before the positive run;
  absence of an audit record can therefore never be explained away as retention loss.
- **Concrete representative set (§M.7).** The Phase-23/24 service set reconciled by this fixture is exactly:
  stack: **MetalLB, the `distribution` registry re-homed onto MinIO's S3 driver, MinIO (distributed), Pulsar
  (broker + ZooKeeper metadata store + BookKeeper bookies), Prometheus+Grafana, the Percona operator, and the
  named per-consumer Patroni Postgres clusters with pgAdmin**; the "trivial app" is exactly the
  single-service Deployment+Service+HTTPRoute of `dhall/examples/platform_plus_trivial_app.dhall`. No other
  service set satisfies the gate.
- **Phase-0-pinned oracle (§M.1).** The positive fixture `dhall/examples/platform_plus_trivial_app.dhall`, the
  expected per-pass enact sets (`test/fixtures/phase22/expected-enact-pass1.json`,
  `…/expected-enact-pass2.json`), the perturbation target list (`…/perturb-targets.txt`), and the negative
  corpus's expected Gate-1/Gate-2 rejection-tag table (`…/negative-expected-tags.tsv`, hand-authored,
  independent of the singleton's own decoder output — §M.3) are all **committed in Phase 0 before
  `Singleton.hs`/`Reconcile.hs`/`Deploy.hs` exist**; none is regenerated from implementation output.
- **Committed seeded mutant (§M.2).** The gate names **≥1 committed seeded mutant** that MUST turn it red:
  the **dropped-effect** mutant `Reconcile.hs::enact` that returns success without issuing the SSA patch (so
  the perturbed platform component is never restored) — committed under
  `test/fixtures/phase22/mutants/enact-noop.patch` and re-run each gate, asserted red because pass-1 restores
  nothing. A second **effect-swap** mutant (the harness principal, not the singleton SA, issues the writes)
  MUST also go red via the attribution clause above.

## Resource provision — the singleton's sealed whole-deployment envelope

This phase applies — as consumed background, not a newly adopted doctrine — the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_doctrine.md §3.1`](../documents/engineering/resource_capacity_doctrine.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting);
the singleton receives no bootstrap exception from those folds.

The singleton is itself part of `BoundDeployment`, never a resource-free bootstrap exception. Its pure demand
contains a complete `PodResourceEnvelope`: the singleton image and exact OCI/import footprint; CPU, memory,
and ephemeral-storage requests and limits for decode, bind, whole-deployment provision, discovery, diff, SSA
serialization, Lease renewal, watch/list buffering, and health/metrics service; runtime memory working set;
writable-root and bounded structured-log headroom; projected `InForceSpec`/ConfigMap/Secret/downward-API/
service-account-token bytes; any disk- or memory-backed `emptyDir`; exact byte-free
`PodRuntimeMetadataSource` network-attachment identities and container-to-volume mount identities; no PVC, no
cache, and `accelerator = None`. The singleton's `BoundExecutionBody` is structurally a Deployment with
`ReplicaCardinality = Once`, never a separate replica operand, and its only legal controller policy is
`DeploymentRolloutPolicy.Recreate`. The mandatory Lease supplies writer exclusion; it does not make a
RollingUpdate safe or erase the capacity of a manually deleted/evicted terminator plus replacement.
`provision`, not binding, expands that symbolic unit into identity-keyed planned slots and every reachable
old/zero-live/new transition, while live admission retains every distinct observed Pod UID until its
resource-indexed release. Rendered `replicas=1` is a projection of that witness, not permission to debit one
Pod during actual replacement overlap.

The mandatory `ProvisionedMandatoryReconcilerLease` is a deployment-global render source, not optional
singleton decoration. Its closed authority transition is `BootstrapHeld → ReleasedForHandoff →
SingletonHeld PodUid`; there is no direct first-to-third continuation and no anonymous holder.
Provisioning includes the Lease object bytes, exact bootstrap and singleton RBAC subjects, duration/deadline/
retry policy, maximum bootstrap renewals, release update on the still-present object, singleton acquisition/renewals, lost-
response retries, and replacement-Pod holder churn in `EtcdLogicalDemand`. Live preflight joins holder identity
and Lease resourceVersion into `ObservedInventory`/`ValidatedLiveTarget`. A missing Lease, unknown holder,
stale resourceVersion, concurrent holder, or singleton UID unequal to the authenticated execution identity has
no mutation continuation.

For every planned singleton, trivial-app, gateway, or other Pod slot, provision combines the exact
runtime-metadata source with its container/volume graph and the selected node's pinned `kubeletMetadataModel`
to derive one `KubeletRuntimeMetadataShape`; live discovery constructs the corresponding observed demand under
the actual `PodUid` plus its authenticated owner/source witness, never under the planned slot id. The private
provisioner derives every metadata component's bytes and `KubeletNodefs | CriRuntimeRoot` role, resolves that
role through the selected `Unified | SplitRuntime | SplitImage` layout, and groups aliases by physical carve
once. SplitRuntime therefore debits kubelet components to nodefs and CRI components to
imagefs/containerfs; Unified and SplitImage sum their forced aliases before one backing check. No physical
runtime-metadata debit is repeated as logical Pod ephemeral storage.

Pure provision emits one node-level `ProvisionedNodeRuntimeStorageAccounting` row per planned epoch; live
preflight emits the observed-inventory-scope form. Its accounting-id domain exactly equals assigned planned slots
or eligible observed Pod UIDs, its qualified Pod component keys are disjoint from and exhaustive with the node
image-model component keys, and its final backing map combines metadata and image demand once per physical
carve. The largest simultaneous scope retains every sandbox, Pod-directory, runtime-state, CNI-state,
volume-metadata, and mount-metadata component; a role drop/swap, domain mismatch, ownership hole/overlap, or
alias double debit refuses before mutation.

Durable singleton state is a closed `ControlPlaneState` arm of the six-arm `ObjectStoreProducerDemand` union
(`AppBucket | Content | Registry | PulsarOffload | PulumiCheckpoint | ControlPlaneState`), with the canonical
pure `ControlPlaneStateObjectDemand`. It names one `StorageBudgetId`; exact full store/tenant/bucket/key
identities for `InForceSpecSnapshot`, `ManagedResourceRegistry`, `ReconcileJournal`, `ValidationLedger`, and
content-addressed `JobCompletion`;
maximum canonical bytes per entry; retained-version count; serial update concurrency; finite failed-write and
orphan-GC horizons; model version; and `ObjectStoreMutationAdmission`. The private provisioned peak retains
resident, future-resident, transient, and failed-write extents. State mutations route only through the
resource-bearing object-write admission gateway; the singleton has no direct S3 PUT credential, and a failed
CAS remains charged until external inventory observes deletion.

The fixture's trivial app also carries its own complete Pod envelope in a Deployment-indexed
`BoundExecutionBody` with `ReplicaCardinality` and `DeploymentRolloutPolicy` even though its tenant fanout is deferred;
deferral of ObjectStore/Sql tenancy is not a resource exemption. Pure whole-deployment provision binds the
singleton execution, trivial app, admission gateway, every desired producer instance
across the closed six-arm union, service demands, namespace quotas, Pod/attachment slots, storage models, and
the exhaustive desired/prior object identity map. Live preflight then joins observed current/old/terminating
state and constructs the apply-action map before it creates the singleton Deployment or writes state. Every identity has a
`KubernetesApiObjectDemand`; bounded revision/Lease/Event `churn` and the pinned `model` form
`EtcdLogicalDemand { desiredObjects, churn, model }`. Only private
`ProvisionedEtcdLogicalDemand.derivedPeak <= ControlPlaneStorageDemand.etcd.backendQuotaBytes` may continue;
then the backend-at-quota plus WAL/snapshot/serialized-defrag peak must fit its physical backing. Only the private
provisioned projection reaches `renderAll`.
After enact, live Deployment/Pod requests, limits, images, local storage, projected files, observed-Pod-UID
runtime-metadata component/role/backing rows and scope-indexed node aggregate, rollout epoch, and
the exact MinIO object inventory normalize back to that value; an unmodeled pod, state key, revision, or byte
is `UnknownCommitment`. Exact-fit/one-short fixtures cover every envelope field and each state-object,
retention, concurrent/failure, budget, admission, API-object/revision/Event, and etcd term. Mutants dropping
Lease/API-client work, the terminating old Pod, one of the five state kinds, a failed CAS extent, or the
admission-gateway envelope, plus mutants dropping one desired API object, churn operand, or etcd model, must
refuse before the first apiserver or object-store mutation.

## Doctrine adopted

- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — *the control-plane singleton*: every cluster has exactly one brain holding total authority over the cluster
  and its secrets. Per [§3.1](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  ("exactly one pod" is a k8s/etcd property, not an amoebius election), the singleton is a **Deployment
  `replicas=1`**, **stateless** at the pod level (no PVC; durable state exclusively the Vault-enveloped MinIO
  bucket), and single-writer authority is **delegated to k8s/etcd** through the mandatory `Lease`, never a
  bespoke election. This phase also performs the one-way authority handoff from the observed Phase-19
  bootstrap-host holder through fresh release and observed holder absence on that same Lease object to the authenticated singleton Pod holder; Kubernetes
  supplies exclusion, while amoebius proves it never mints overlapping mutation capabilities. This phase
  delivers that role live; prodbox's root single-node control-plane behaviour is
  **sibling evidence, not an amoebius result**.
- [`daemon_topology_doctrine.md §5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
  — *single-instance and coordination — delegated, not elected*: amoebius builds no ranked-failover rule, no
  signed-commit-log election, and no warm-standby candidate population; re-deriving consensus etcd already
  provides would add a second coordination plane to prove correct and deadlock at cold-start. This phase honors
  that posture — the only intra-cluster single-writer machinery is the Deployment plus its mandatory `Lease`;
  the typed bootstrap release/acquire sequence is a client protocol around that Lease, not another election.
- [`daemon_topology_doctrine.md §6`](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine)
  — *the shared daemon spine*: the singleton runs the `load → prereq → acquire → ready → serve → drain → exit`
  lifecycle (nested `bracket`/`withAsync`, no `forkIO`), serves `/healthz` / `/readyz` / `/metrics`, logs
  structured JSON, and takes no `PATH` or environment-variable precedence; readiness is a witnessed condition,
  never a `threadDelay` or filesystem marker. The spine is **proven in prodbox** — inherited design intent, not
  a tested amoebius result.
- [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — *the illegal-state-unrepresentable contract*: Gate 1, Gate 2, bind/expand, the Phase-11 provision seal,
  and Phase-13 `renderAll` were discharged in-process in the pre-cluster band. This phase runs the **runtime
  residue** — the live path must follow decoded IR → bind/expand → `planInfrastructure` → explicit
  already-materialized observation (or validated/CAS-enacted batch and receipt) → `ProvisionContext` →
  `provision` → opaque `ProvisionedSpec` → `renderAll`; an incompatible target returns `Left` before effects.
  The live gate proves the apiserver
  admits the sealed desired objects without re-establishing the pure contract itself.

## Sprints

## Sprint 26.1: The control-plane singleton — a Deployment replicas=1, single-instance from k8s/etcd 📋

**Status**: Planned
**Implementation**: `src/Amoebius/ControlPlane/Singleton.hs` (the in-cluster singleton role + the shared
daemon spine); `src/Amoebius/ControlPlane/Reconcile.hs` (the `discover → diff → enact → re-observe` loop
wrapping the Phase-19 typed reconciler and its observed-Pod/runtime-storage normalization);
`src/Amoebius/ControlPlane/AuthorityHandoff.hs` (bootstrap-holder drain/release/readback and singleton acquire);
`src/Amoebius/Capacity/RuntimeStorage.hs` (shared component-role/layout and scope-indexed node-accounting fold)
— target paths, not yet built.
**Blocked by**: Phase 19 gate (the typed renderer + SSA reconciler and observed bootstrap-host Lease holder —
the singleton is itself a rendered, applied object); Phase 22 gate (root Vault — the singleton is the in-cluster principal that operates Vault);
Phase 17 gate (the `kind` cluster + the host-daemon→singleton handoff the midwife begins).
**Independent Validation**: on the single-node linux-cpu cluster the singleton manifest is a **Deployment with
`replicas=1`** carrying **no PVC**; the Pod comes up, runs the daemon spine, and serves `/healthz` / `/readyz`
/ `/metrics`; deleting the Pod causes Kubernetes to converge a replacement with no data
loss; the manifest contains **no amoebius election controller, no ranked-failover config, and no standby
Pod**. **"At most one writer" is observed concretely (§M.5):** an apiserver watch records every Pod UID,
owner chain, protected source annotation, phase, and Lease transition across the full delete→reschedule window;
at every resource version at most one authenticated UID holds the Lease, while every simultaneously present or
reserved UID remains in the capacity ledger. Initial bring-up must additionally show bootstrap holder →
quiesced/released → fresh same-Lease holder absence → authenticated singleton Pod UID holder, with no host mutation after release
and no singleton mutation before acquire. **"No data loss" names the durable state
probed:** before the delete the singleton's `InForceSpec` object is written to the Vault-Transit-enveloped
MinIO bucket; after the replacement reports `/readyz` ready it reads that object back and the decrypted bytes
are byte-identical to the pre-delete write (a stateless pod losing its durable MinIO state would fail this).
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton),
[`§3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election),
[`§5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected),
and [`§6`](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine): deliver the
in-cluster control-plane singleton as a Deployment-`replicas=1` role that holds total cluster + secret
authority and runs the reconcile loop, with single-writer authority delegated to k8s/etcd, an observed
bootstrap-host-to-singleton Lease handoff, and no amoebius election.

### Deliverables
- A control-plane singleton deployed as a **generated typed `Deployment replicas=1`** by the Phase-19
  reconciler, **stateless** (no PVC; its durable `InForceSpec` state is the Vault-Transit-enveloped MinIO
  object), running the shared daemon spine (`load → prereq → acquire → ready → serve → drain → exit`, no
  `forkIO`, structured JSON logs, no env / `PATH`).
- Its complete symbolic `BoundExecutionUnit`, including
  Deployment-indexed `ReplicaCardinality = Once` and the sole legal
  `DeploymentRolloutPolicy.Recreate`, image/import bytes, CPU/memory/
  ephemeral requests and limits, working set, writable/log headroom, projected files, Lease/API-client work,
  exact runtime-metadata network/mount identities, component roles/layout backings, planned/observed node
  aggregate witnesses, and provision-derived old/new/surge/terminating instances;
  the private provisioned value, not the authored demand, is the only manifest-renderer input.
- A `ControlPlaneStateObjectDemand` for the exact five durable state kinds, carrying its `StorageBudgetId`,
  version/failure/orphan bounds, and mutation admission, merged through the closed six-arm object-producer
  inventory before a state write can occur. The sole gateway has its own complete Pod envelope.
- The `discover → diff → enact → re-observe` reconcile loop that decodes the `InForceSpec` in-process
  (Phase-5 decoder), binds capabilities (Phase-10 binder), and applies the resulting manifests through the
  Phase-19 typed reconciler — idempotently, driven only by observed cluster state.
- Single-writer authority **delegated to k8s/etcd**: the Deployment controller converges desired `replicas=1`
  while old/terminating/replacement UIDs may overlap; a Kubernetes `Lease` (the
  etcd-backed client-go leader-election object) is the sole mechanism where strict at-most-one-writer must
  survive deletion/eviction replacement or partition — **no bespoke election, no signed commit log, no
  standby population**.
- A closed initial `AuthorityHandoff`: while holding the exact Lease the Phase-19 host applies the singleton
  Deployment; the waiting Pod can complete prerequisites but receives no mutation capability and keeps
  `/readyz` false. The host stops action issuance, drains in-flight work, executes the typed
  `BootstrapHeld → ReleasedForHandoff` release by expected-resourceVersion CAS, and observes its holder absent
  on the same object UID at the successor version. Only the typed `ReleasedForHandoff → SingletonHeld`
  handoff action may then install the exact authenticated singleton Pod UID and mint reconcile/Serving
  authority after successor readback. Each action CAS-consumes a fresh snapshot-bound token and reserves its
  exact one-update/one-revision etcd debit; a stale CAS, timeout, or lost response retains the debit and
  re-observes with no authority. Holder identity/object UID/resourceVersion and every observation enter the
  fingerprint; unknown or changed state restarts the read-only prefix.
- Secret authority fused to the role (operates root Vault as the single in-cluster writer) and the admin-REST
  control surface stub through which the operator `pb` client later drives the cluster.

### Validation
1. The singleton manifest is a `Deployment replicas=1` with no PVC. During initial handoff, assert the Pod
   remains non-Serving and performs zero mutations while the bootstrap host holds the Lease; then observe host
   quiescence, release, fresh holder absence, exact singleton UID acquisition, and only then `/readyz`. A Pod
   delete converges a replacement, and the apiserver watch proves at most one
   authenticated Pod UID holds the Lease at each resource version while all present/reserved UIDs remain
   capacity-debited, with the MinIO-held `InForceSpec` read back byte-identical afterward.
2. The reconcile loop runs one idempotent pass to convergence from a decoded spec and a re-run is a no-op,
   where **"no-op" is defined observably (§M.6) as: the second pass's apiserver audit log records zero mutating
   writes (`create`/`update`/`patch`/`delete`) under the singleton field manager** — unchanged end-state
   readiness alone does not satisfy this. To prove the compute path actually ran on the second pass (not a
   skipped/memoized short-circuit), the second pass executes with any reconcile result cache bypassed and its
   `discover` step is observed to have re-read live cluster state before concluding the empty diff. The
   codebase contains no election/ranked-failover module and no standby pod is ever scheduled.
3. Make each singleton CPU, memory, ephemeral, image/import, writable/log, projected-file, runtime-metadata,
   pod-slot, Deployment-cardinality, and Deployment-rollout operand one unit short; change the pinned metadata
   model; drop/swap a component role; mismatch the planned-slot/observed-UID domain; overlap/leak qualified
   Pod/image ownership; double-debit an alias; make either SplitRuntime nodefs or imagefs/containerfs one byte
   short; or drop the largest simultaneous metadata row. Separately make each control-plane-state resident/version/failure/budget term
   short or omit one state kind/admission envelope. Every negative rejects before Deployment creation or MinIO
   mutation. For the exact-fit twin, live Pod/Deployment and exact object-key readback equal the provisioned
   projection, including the replacement-Pod transition epoch.
4. Inject simultaneous acquire, stale-resourceVersion release, lost release/acquire response, watch gap,
   bootstrap crash before and after release, singleton crash before and after acquire, and replacement-Pod UID
   churn. Every trace either reaches one authenticated singleton holder or refuses with no overlapping
   mutation; audit history shows zero host writes after observed release and zero singleton writes before
   observed acquire. Assert every attempted Release/Handoff consumes its fresh token, every present-state
   mutation uses the exact expected resourceVersion, and a lost/ambiguous response remains charged one etcd
   update/revision until successor or no-write readback. Drop one Lease object/RBAC/churn operand or mutate
   only the holder UID and require preflight refusal before any other effect.

> **Honesty.** Kubernetes/etcd, not amoebius, supplies the exclusion property behind "never two simultaneous
> Lease holders" ([daemon_topology_doctrine.md §3.1](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)). Amoebius's obligation here is narrower and
> real: it must not authorize either client on an unknown/stale transition and must observe bootstrap release
> before enabling the singleton. Cross-cluster gateway migration remains owned by the multi-cluster phase.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 26.2: Live reconcile of the platform + a trivial app from one `.dhall` 📋

**Status**: Planned
**Implementation**: `dhall/examples/platform_plus_trivial_app.dhall` (the positive deploy fixture);
`src/Amoebius/ControlPlane/Deploy.hs` (the singleton's platform + trivial-app reconcile entry) — target paths,
not yet built.
**Blocked by**: Sprint 26.1 (the running singleton + reconcile loop); Phase 23 and Phase 24 gates (the service
set the `.dhall` deploys); Phase 25 gate (the Keycloak-owned edge through which the app is validated); Phase 5
(the Gate-2 decoder producing the in-memory IR the loop consumes).
**Independent Validation**: one `.dhall` decodes through `Dhall.inputFile auto` to its IR and the singleton
reconciles the standard platform stack plus a trivial single-service app to ready on the linux-cpu cluster.
**Because Phases 17–25 leave the platform and edge pre-converged, the harness first perturbs the Phase-23/24
service set (§M.6, forecloses the
pre-converged-ride cheat):** before the first pass it deletes the named components in
`test/fixtures/phase22/perturb-targets.txt` (at minimum one platform `Deployment` and its `Service` — e.g. the
Prometheus `Deployment`+`Service`), then asserts **per-pass enact records read from the apiserver audit log
(§M.5), not the singleton's self-report:** the **first** pass's created/patched set is **non-empty** and
matches `expected-enact-pass1.json` (it restores the deleted components to Ready), and the **second**
invocation's enact set is **empty** and matches `expected-enact-pass2.json` — a `no-op` meaning **zero mutating
writes under the singleton field manager in the audit log**, not merely unchanged end-state readiness. A
teardown then leaves **no leaked resources**: the postflight sweep is scoped explicitly to **this run's
provisioned objects, identified by the run-unique label `amoebius.dev/phase22-run=<run-id>` the singleton
stamps on every object it creates** (Phase-42 flag-at-creation machinery is not assumed; this label set is
authored here), and the sweep is empty over that label set; separately, every platform component perturbed by
the harness is asserted back at Ready so the shared Phase-23/24 stack is left as found.
**Docs to update**: `documents/engineering/dsl_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
at the runtime layer: the two typed gates guard the **live** deploy, but decoded IR is never reconciled
directly. The singleton must bind/expand it, derive the conditional infrastructure result, authenticate the
already-materialized target (or receipt-bound enacted result), construct `ProvisionContext`, and successfully
`provision` the exact target into an opaque
`ProvisionedSpec`, and call deployment-level `renderAll`; any capacity or compatibility failure stops before
effects. This gate proves the apiserver admits what the complete pure pipeline sealed. The pure integrity
itself was proven in-process in the pre-cluster band; here it is exercised, not re-established.

### Deliverables
- A positive deploy `.dhall` composing the standard platform-service stack (Phases 23–24) and a **trivial**
  single-service app — deliberately narrower than the Phase-27 tenancy projection (no per-app namespace,
  ObjectStore, or in-namespace Sql fanout), but still carrying a complete app Pod/rollout envelope.
- The singleton's live reconcile of that spec: decode → capability-bind/expand → `planInfrastructure` →
  materialization observation/receipt → `ProvisionContext` → whole-deployment provision →
  observed-inventory preflight → `renderAll` → SSA-apply → wait-to-ready, each edge a witnessed condition — **the
  witness for each apply/ready edge is externally observable apiserver
  evidence (the object's live `status`/managed-fields and the audit-log write record), never a log line or
  metric the singleton emits about itself (§M.5)** — with a re-run proven idempotent (no drift, no re-apply)
  under the audit-log no-op definition above.
- A hard effect boundary: pure whole-deployment provision includes the singleton, mutation-admission gateway,
  every desired Pod/controller child and producer, durable claims, Pod/CSI slots, and planned transition peaks.
  Snapshot-bound preflight then joins every observed/reserved/terminating/terminal-retained identity and builds
  the observed node runtime/image-storage aggregate before minting `ValidatedLiveTarget`. Any
  `Left ProvisionError` or live-preflight refusal exits before state PUT or SSA apply; no renderer accepts raw
  `InForceSpec`/`BoundDeployment` values.
- A leak-free teardown obligation carried by the deploy fixture — a test-topology `.dhall` whose postflight
  sweep asserts every provisioned object (the run-unique-labelled set defined in Independent Validation) was
  reclaimed, while the pre-existing Phase-23/24 service set and Phase-25 edge are restored to Ready rather than
  swept.

### Validation
1. After the harness perturbs the named platform components, the `.dhall` reconcile's first pass restores them
   and brings the platform + trivial app up on the linux-cpu cluster (first-pass audit-log enact set non-empty,
   matching `expected-enact-pass1.json`); the app is reachable through the Phase-25 Keycloak-owned edge; a
   re-run is a no-op (second-pass audit-log enact set empty, matching `expected-enact-pass2.json`).
2. Teardown leaves no leaked resources (the postflight sweep over the run-unique label set is empty and the
   perturbed platform components are back at Ready); the apiserver audit log records that **every** platform/app
   write was issued by the singleton's in-cluster ServiceAccount and none by the harness principal.
3. A committed provision-bypass mutant that renders the raw bound spec, and omission mutants that drop the
   singleton, trivial-app, or gateway envelope, a present producer instance, or a union match branch must turn
   the gate red before apply. The positive run compares normalized live requests/limits/images/local storage,
   controller children, claims, and object keys with the opaque provisioned deployment rather than merely
   checking `Ready`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 26.3: Phase gate harness — live deploy + the pre-cluster negative corpus as a live regression guard 📋

**Status**: Planned
**Implementation**: `test/integration/Phase22Gate.hs` (linux-cpu spin-up / reconcile / teardown + the negative
regression assertions); `test/integration/Phase22RuntimeStorage.hs` (planned-slot→observed-Pod-UID readback,
SplitRuntime backing boundaries, node scope/domain/ownership equality, reservation/observed no-double-debit,
and alias controls); the reused Phase-6
negative corpus under `dhall/examples/illegal_*.dhall` (re-run, not
re-authored) — target paths, not yet built.
**Blocked by**: Sprint 26.1, Sprint 26.2; Phase 6 (the pre-cluster illegal-state negative corpus +
validation-locus ledger, already proven in Registers 1–2); Phase 25 gate (the Keycloak-owned edge the deployed
app must route through).
**Independent Validation**: the harness deploys the platform + trivial app from one `.dhall` on linux-cpu
(under the perturbation + attribution regime of the Gate-integrity clauses and Sprint 26.2) and tears down
leak-free, then re-runs each Phase-6 negative fixture against the live deploy path and asserts each still
**fails at Gate 1 or Gate 2**, and each positive fixture still decodes; the run emits a **Register-3**
proven/tested/assumed ledger naming the live substrate. **"The live deploy path" is pinned to the identical
entry point the positive fixture used (§M.3, forecloses the host-side re-run cheat):** each negative `.dhall`
is submitted through the exact same singleton spec-ingestion/`Deploy.hs` entry the positive gate fixture flowed
through (not a separate host-side CorpusSpec decoder), and each yields a **structured Gate-1 (`dhall type`
error) or Gate-2 (`DecodeError` tag) rejection whose emitted tag equals the Phase-0-committed expected tag for
that fixture in `test/fixtures/phase22/negative-expected-tags.tsv` (§M.8)** — a bare "it failed" does not
satisfy this. **"No fixture reaches the apiserver" is proven, not assumed (§M.5):** across the entire negative
corpus run the apiserver audit log shows **zero** platform/app-object writes, and a full-cluster
`resourceVersion` snapshot taken before and after the corpus run is equal — cluster state is byte-for-byte
unchanged.
**Docs to update**: `DEVELOPMENT_PLAN/substrates.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-26 status when the gate passes).

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
assemble the phase's single live acceptance gate — one `.dhall` deploys the platform + a trivial app on
linux-cpu and the live apiserver admits the rendered manifests — and, as a regression guard, re-run the
pre-cluster (Phase-6) negative corpus so each deliberately-illegal `.dhall` still fails to type-check or decode
against the live path, and the positive fixtures still decode. That type/decode result was proven in-process in
the pre-cluster band; here the guard confirms the live deploy path never admits an illegal spec.

### Deliverables
- The positive gate: the Sprint-22.2 platform + trivial-app deploy driven to ready by the singleton and torn
  down leak-free, expressed as a test-topology `.dhall` with a teardown obligation.
- The negative regression guard: the Phase-6 corpus (a bad PVC↔PV pairing, a Keycloak-bypassing open ingress, a
  product named in application logic, and the capacity/topology/bounded-storage set) **re-run** against the
  live deploy path (the same singleton `Deploy.hs` entry the positive fixture used), each asserted to fail at
  Gate 1 or Gate 2 **with its specific foreclosure tag matching the Phase-0-committed hand-authored oracle
  `test/fixtures/phase22/negative-expected-tags.tsv`** (each row: fixture → expected `dhall type` error or
  `DecodeError` tag, authored independently of the singleton's decoder — §M.3/§M.8), and each paired with a
  positive that differs only in the foreclosed dimension — **never re-establishing** the type discipline, only
  guarding that the deploy path inherits it.
- **Committed seeded mutants (§M.2):** at least `test/fixtures/phase22/mutants/enact-noop.patch` (the
  dropped-effect `Reconcile.hs::enact`, red because the perturbed component is never restored) and an
  attribution mutant (harness principal issues the writes, red because the audit clause detects a non-singleton
  writer) — both committed and re-run each gate, each asserted to turn the gate red.
- The **Phase-0-pinned oracle bundle** committed before any implementation exists:
  `dhall/examples/platform_plus_trivial_app.dhall`, `expected-enact-pass1.json`, `expected-enact-pass2.json`,
  `perturb-targets.txt`, `negative-expected-tags.tsv`, and `harness-rbac.yaml` (under `test/fixtures/phase22/`).
- A **Register-3** proven/tested/assumed ledger recording the live-enforcement result (the apiserver admitted
  the rendered manifests) and marking the deferred surfaces — full app tenancy (Phase 27), and the
  cross-cluster gateway-migration correspondence (the multi-cluster phase) — as UNVERIFIED, never green.
- The committed resource-boundary corpus: one exact-fit topology plus one-short and omission cases for the
  singleton envelope, rollout overlap, runtime component roles/layout backings and scope-indexed node
  domain/ownership/grouping, admission gateway, and all five `ControlPlaneState` entry kinds and
  their `StorageBudgetId`/retention/failure terms. Each negative also asserts zero audit writes and zero MinIO
  mutation.

### Validation
1. After perturbation, the positive `.dhall` restores and brings the platform + trivial app up (first-pass
   audit-log enact set matches `expected-enact-pass1.json`, all writes attributed to the singleton SA), the app
   is reachable through the Keycloak edge, and teardown leaves no leaked resources over the run-unique label
   set; the committed `enact-noop` mutant turns this red.
2. Every Phase-6 negative fixture, submitted through the same singleton `Deploy.hs` entry the positive used, is
   rejected at Gate 1/Gate 2 with its emitted tag equal to the committed `negative-expected-tags.tsv` oracle;
   the apiserver audit log shows zero writes and the pre/post full-cluster `resourceVersion` snapshot is equal
   across the corpus run; the positive fixtures decode; and the ledger honestly classifies each foreclosure (no
   runtime-checked or deferred claim — tenancy, gateway-migration — is reported as proven).
3. Run the resource-boundary and provision-bypass mutants through that same singleton entry. Assert each
   returns its specific `ProvisionError` before effects, while the exact-fit twin's live normalized
   Pod/controller/object-store projection is equal to the private provisioned value.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/daemon_topology_doctrine.md` — the §3 / §3.1 control-plane-singleton and the §5
  delegated-single-instance honesty notes flip from "design intent for the live-DSL-deploy phase" to a
  delivered Deployment-`replicas=1` singleton with its Register-3 ledger attached; record that single-instance
  landed as a k8s/etcd property with no amoebius election built.
- `documents/engineering/dsl_doctrine.md` — the §5 contract's runtime-enforcement note flips from "design
  intent" to live-enforced only once the gate runs — the two gates now guard the live deploy path.
- `documents/engineering/manifest_generation_doctrine.md` — record that the control-plane singleton is the role
  that runs the typed reconciler's loop, and that its own manifest is a generated `Deployment replicas=1`.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (tenancy
  and gateway-migration correspondence UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-26 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — confirm the Phase-26 linux-cpu gate row (the replicas=1 singleton, no
  election).
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/ControlPlane/{Singleton,Reconcile,Deploy}.hs`
  as Phase-26 design-first rows, and re-anchor the in-cluster-singleton row to the current
  `#3-the-control-plane-singleton` (no election).

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the replicas=1 singleton)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map (the linux-cpu gate row)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the control-plane singleton
  as a Deployment `replicas=1`, single-instance delegated to k8s/etcd, and the shared daemon spine
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the two typed gates and the illegal-state contract
  guarding the live deploy path
- [phase_19](phase_19_object_reconciler.md) — the typed renderer + SSA reconciler that renders and applies
  the singleton and its manifests
- [phase_23](phase_23_platform_backbone.md) — the standard platform-service stack the live `.dhall` deploys
- [phase_25](phase_25_keycloak_ingress.md) — the Keycloak-owned edge the trivial app routes through
- [phase_27](phase_27_app_tenancy.md) — the app-tenancy projection (namespace + ObjectStore + Sql) deferred
  from this phase
