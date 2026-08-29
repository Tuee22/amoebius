# Phase 65: Live DSL deploy via the replicas=1 control-plane daemon

> **Purpose**: Turn the gate-passed pre-cluster DSL into a live deploy — hand the mandatory reconciler Lease from
> the observed bootstrap host to the Deployment-`replicas=1` control-plane daemon, then have that control-plane daemon
> decode one Haskell-declared spec (with any Dhall transport generated lazily beneath `.build/**`) and reconcile
> the platform plus a trivial app onto a real cluster, with single-writer
> exclusion delegated to k8s/etcd and no amoebius election.
> **Read this if**: phase 65 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/vault_pki_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 65.1: The control-plane daemon — a Deployment replicas=1, single-instance from k8s/etcd ⏸️](#sprint-651-the-control-plane-daemon--a-deployment-replicas1-single-instance-from-k8setcd-)
- [Sprint 65.2: Live reconcile of the platform + a trivial app from one Haskell declaration ⏸️](#sprint-652-live-reconcile-of-the-platform--a-trivial-app-from-one-haskell-declaration-)
- [Sprint 65.3: Phase gate harness — live deploy + the pre-cluster negative corpus as a live regression guard ⏸️](#sprint-653-phase-gate-harness--live-deploy--the-pre-cluster-negative-corpus-as-a-live-regression-guard-)
- [Sprint 65.4: The admin REST surface — `vault init/unseal`, `dhall update`, secret KV-CRUD ⏸️](#sprint-654-the-admin-rest-surface--vault-initunseal-dhall-update-secret-kv-crud-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 64, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase is to make the DSL **run live** only after every predecessor
and the Phase-49 hardware-free barrier have required predecessor gate passes. It may consume the Phase-25/26 typed
projection and decoder, Phase-27 illegal-state corpus, Phase-9 capacity/topology folds, Phase-30/31 binding and
provision seal, Phase-33 `renderAll`, and Phase-34 chain/dry-run semantics only through those exact gate passes;
none is currently discharged. The live target is the in-cluster **control-plane daemon** — the
`ControlPlaneDaemon` arm of `InClusterRole`
([daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)) — deployed as a Kubernetes
**Deployment with `replicas=1`** and exactly one Lease-held mutation authority at a time despite replacement-Pod
overlap. It must decode the passed `InForceSpec`, run `discover → diff → enact → re-observe`, drive a real
linux-cpu cluster toward it, apply the passed standard platform plus a trivial app through the Phase-58
reconciler, converge, and tear down without leaks.

Single-writer authority for that control-plane daemon is **delegated to k8s/etcd**: the Deployment controller converges
to desired `replicas=1` and reschedules on node loss, but update/replacement may transiently expose distinct old,
terminating, and replacement Pod UIDs. Strict at-most-one-writer is therefore a Kubernetes `Lease` (the
etcd-backed client-go leader-election
object) — **never a bespoke amoebius election, no ranked-failover rule, no warm-standby candidate population,
no signed-commit-log protocol**. The target daemon is **stateless at the pod level** — it holds no PVC; its
durable state is exclusively the Vault-enveloped MinIO bucket. As a regression guard, the future gate must
re-run the passed Phase-27 Haskell negative corpus through this live deploy path and require every case to
fail at its pinned type/decode locus. That is a live inheritance check, not a new proof. Full app tenancy (own namespace, `<app>/<bucket>` ObjectStore,
in-namespace Sql) is deliberately deferred to Phase 66; the app here is trivial.

The target initial ownership transition is explicit. After future Phase-58/59 gate pass, the bootstrap-host
holder retains the deployment-global reconciler Lease until this phase's handoff. It must apply the
control-plane daemon Deployment while retaining that Lease; the new Pod may load and finish prerequisites but
cannot mutate or advertise `/readyz`. The host then stops minting actions, drains
in-flight effects, releases the Lease, and freshly observes its holder absent/released. Only the authenticated
control-plane daemon Pod UID may acquire the same object. Its held-Lease readback plus `/readyz` Serving condition retires
the host's direct-apiserver authority. Lost responses, stale resourceVersions, watch gaps, or replacement-Pod
UID changes fail closed and re-observe; they never infer handoff from time.

**Phase scope:** one cohesive target claim — *the independently passed pre-cluster language deploys to a real cluster, written by exactly one holder of the Lease*. Single-writer exclusion is delegated, not re-implemented here.

**Substrate:** linux-cpu — the single-node `kind` cluster and services targeted by Phases 55–64; no apple, linux-cuda, or windows
substrate is exercised by this phase's gate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 64](phase_64_keycloak_ingress.md)
**Gate:** `pb validate phase 65`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive target claim — *the independently passed pre-cluster language deploys to a real cluster, written by exactly one holder of the Lease*. Single-writer exclusion is delegated, not re-implemented here. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 65` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 64; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

This phase applies — as consumed background, not a newly adopted doctrine — the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting);
the control-plane daemon receives no bootstrap exception from those folds.

The control-plane daemon is itself part of `BoundDeployment`, never a resource-free bootstrap exception. Its pure demand
contains a complete `PodResourceEnvelope`: the control-plane daemon image and exact OCI/import footprint; CPU, memory,
and ephemeral-storage requests and limits for decode, bind, whole-deployment provision, discovery, diff, SSA
serialization, Lease renewal, watch/list buffering, and health/metrics service; runtime memory working set;
writable-root and bounded structured-log headroom; projected `InForceSpec`/ConfigMap/Secret/downward-API/
service-account-token bytes; any disk- or memory-backed `emptyDir`; exact byte-free
`PodRuntimeMetadataSource` network-attachment identities and container-to-volume mount identities; no PVC, no
cache, and `accelerator = None`. The control-plane daemon's `BoundExecutionBody` is structurally a Deployment with
`ReplicaCardinality = Once`, never a separate replica operand, and its only legal controller policy is
`DeploymentRolloutPolicy.Recreate`. The mandatory Lease supplies writer exclusion; it does not make a
RollingUpdate safe or erase the capacity of a manually deleted/evicted terminator plus replacement.
`provision`, not binding, expands that symbolic unit into identity-keyed planned slots and every reachable
old/zero-live/new transition, while live admission retains every distinct observed Pod UID until its
resource-indexed release. Rendered `replicas=1` is a projection of that witness, not permission to debit one
Pod during actual replacement overlap.

The mandatory `ProvisionedMandatoryReconcilerLease` is a deployment-global render source, not optional
control-plane daemon decoration. Its closed authority transition is `BootstrapHeld → ReleasedForHandoff →
ControlPlaneHeld PodUid`; there is no direct first-to-third continuation and no anonymous holder.
Provisioning includes the Lease object bytes, exact bootstrap and control-plane daemon RBAC subjects, duration/deadline/
retry policy, maximum bootstrap renewals, release update on the still-present object, control-plane daemon acquisition/renewals, lost-
response retries, and replacement-Pod holder churn in `EtcdLogicalDemand`. Live preflight joins holder identity
and Lease resourceVersion into `ObservedInventory`/`ValidatedLiveTarget`. A missing Lease, unknown holder,
stale resourceVersion, concurrent holder, or control-plane daemon UID unequal to the authenticated execution identity has
no mutation continuation.

For every planned control-plane daemon, trivial-app, gateway, or other Pod slot, provision combines the exact
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

Durable control-plane daemon state is a closed `ControlPlaneState` arm of the six-arm `ObjectStoreProducerDemand` union
(`AppBucket | Content | Registry | PulsarOffload | PulumiCheckpoint | ControlPlaneState`), with the canonical
pure `ControlPlaneStateObjectDemand`. It names one `StorageBudgetId`; exact full store/tenant/bucket/key
identities for `InForceSpecSnapshot`, `ManagedResourceRegistry`, `ReconcileJournal`, `ValidationLedger`, and
content-addressed `JobCompletion`;
maximum canonical bytes per entry; retained-version count; serial update concurrency; finite failed-write and
orphan-GC horizons; model version; and `ObjectStoreMutationAdmission`. The private provisioned peak retains
resident, future-resident, transient, and failed-write extents. State mutations route only through the
resource-bearing object-write admission gateway; the control-plane daemon has no direct S3 PUT credential, and a failed
CAS remains charged until external inventory observes deletion.

The fixture's trivial app also carries its own complete Pod envelope in a Deployment-indexed
`BoundExecutionBody` with `ReplicaCardinality` and `DeploymentRolloutPolicy` even though its tenant fanout is deferred;
deferral of ObjectStore/Sql tenancy is not a resource exemption. Pure whole-deployment provision binds the
control-plane daemon execution, trivial app, admission gateway, every desired producer instance
across the closed six-arm union, service demands, namespace quotas, Pod/attachment slots, storage models, and
the exhaustive desired/prior object identity map. Live preflight then joins observed current/old/terminating
state and constructs the apply-action map before it creates the control-plane daemon Deployment or writes state. Every identity has a
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

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — live DSL deploy via the replicas=1 control-plane daemon provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`preflight_validation_doctrine.md` §2 — The `Check` algebra](../documents/engineering/preflight_validation_doctrine.md#2-the-check-algebra)
  — *the `Check` validation algebra*: the pure-functional free GADT (short-circuit `Bind`; accumulating
  `AllOf`/`Both`/`independently`) **is** the mechanism of this phase's `dhall update` admission gate, and its
  `SubtreeValidated` proof tree is what makes an unproven `SecretRef` refuse before reconcile. Adopted here;
  the credential/host/quota probe instances (AWS `DryRun` + STS join, SSH reach + hardware match) are adopted
  by [phase_76](phase_76_provider_deploy_checkpoint.md) / [phase_79](phase_79_provider_dynamic_nodes.md).
- [`daemon_topology_doctrine.md` §3 — The control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon)
  — *the control-plane daemon*: every cluster has exactly one brain holding total authority over the cluster
  and its secrets. Per [`daemon_topology_doctrine.md` §3.1 — "Exactly one pod" is a k8s/etcd property, not an amoebius election](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  ("exactly one pod" is a k8s/etcd property, not an amoebius election), the control-plane daemon is a **Deployment `replicas=1`**, **stateless** at the pod level (no PVC; durable state exclusively the Vault-enveloped MinIO
  bucket), and single-writer authority is **delegated to k8s/etcd** through the mandatory `Lease`, never a
  bespoke election. This phase also performs the one-way authority handoff from the observed Phase-58
  bootstrap-host holder through fresh release and observed holder absence on that same Lease object to the authenticated control-plane daemon Pod holder; Kubernetes
  supplies exclusion, while amoebius proves it never mints overlapping mutation capabilities. This phase
  delivers that role live; prodbox's root single-node control-plane behaviour is
  **sibling evidence, not an amoebius result**.
- [`daemon_topology_doctrine.md` §5 — Single-instance and coordination — delegated, not elected](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
  — *single-instance and coordination — delegated, not elected*: amoebius builds no ranked-failover rule, no
  signed-commit-log election, and no warm-standby candidate population; re-deriving consensus etcd already
  provides would add a second coordination plane to prove correct and deadlock at cold-start. This phase honors
  that posture — the only intra-cluster single-writer machinery is the Deployment plus its mandatory `Lease`;
  the typed bootstrap release/acquire sequence is a client protocol around that Lease, not another election.
- [`daemon_topology_doctrine.md` §6 — The shared daemon spine](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine)
  — *the shared daemon spine*: the control-plane daemon runs the `load → prereq → acquire → ready → serve → drain → exit`
  lifecycle with bounded concurrent connections and scoped threads (no unscoped `forkIO`), serves `/healthz` / `/readyz` / `/metrics`, logs
  structured JSON, and takes no `PATH` or environment-variable precedence; readiness is a witnessed condition,
  never a `threadDelay` or filesystem marker. The spine is **proven in prodbox** — inherited design intent, not
  a tested amoebius result.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — *the illegal-state-unrepresentable contract*: typecheck, decode, bind/expand, the provision seal, and
  `renderAll` must already have independently passed predecessor receipts from the pre-cluster band. This
  phase owns only the **runtime residue** — the live path must follow decoded IR → bind/expand → `planInfrastructure` → explicit
  already-materialized observation (or validated/CAS-enacted batch and receipt) → `ProvisionContext` →
  `provision` → opaque `ProvisionedSpec` → `renderAll`; an incompatible target returns `Left` before effects.
  The future live gate observes whether the apiserver admits the sealed desired objects; it cannot prove the
  apiserver or re-establish the pure contract itself.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 65.1: The control-plane daemon — a Deployment replicas=1, single-instance from k8s/etcd ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 64](phase_64_keycloak_ingress.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon),
[`§3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election),
[`§5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected),
and [`§6`](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine): deliver the
in-cluster control-plane daemon as a Deployment-`replicas=1` role that holds total cluster + secret
authority and runs the reconcile loop, with single-writer authority delegated to k8s/etcd, an observed
bootstrap-host-to-control-plane Lease handoff, and no amoebius election.

### Deliverables

- **The collapse of `app/singleton/` into the one executable.** The control-plane daemon branch reached its pod by being
  a second `executable` stanza — `amoebius.cabal:933`, whose `Main.hs` parses no arguments at all, because the
  file that was executed *was* the role selection. It becomes the `ControlPlaneDaemon` arm of the decoded
  role, dispatched from `app/amoebius/Main.hs`, and `amoebius.cabal` is left declaring one `executable`. The
  phase-ordinal identities that rode along go with it: the `/phase33-artifacts/` and `/phase33-dhall/` paths,
  the six `phase32-`/`phase33-` object names, and the `amoebius-phase33-singleton` field manager minted at
  `ControlPlane/Daemon.hs:138`
  ([legacy_tracking_for_deletion.md §4](legacy_tracking_for_deletion.md#4-host-image-and-lift-violations)).
  Closing this also retires the transitional half of Phase 43's search-path gate check, which can only fail by
  the tree regaining a second executable.
- A control-plane daemon deployed as a **generated typed `Deployment replicas=1`** by the Phase-58
  reconciler, **stateless** (no PVC; its durable `InForceSpec` state is the Vault-Transit-enveloped MinIO
  object), running the shared daemon spine (`load → prereq → acquire → ready → serve → drain → exit`, bounded
  concurrent HTTP connections with no unscoped `forkIO`, structured JSON logs, no env / `PATH`).
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
  (Phase-26 decoder), binds capabilities (Phase-30 binder), and applies the resulting manifests through the
  Phase-58 typed reconciler — idempotently, driven only by observed cluster state.
- Single-writer authority **delegated to k8s/etcd**: the Deployment controller converges desired `replicas=1`
  while old/terminating/replacement UIDs may overlap; a Kubernetes `Lease` (the
  etcd-backed client-go leader-election object) is the sole mechanism where strict at-most-one-writer must
  survive deletion/eviction replacement or partition — **no bespoke election, no signed commit log, no standby population**.
- A closed initial `AuthorityHandoff`: while holding the exact Lease the Phase-58 host applies the control-plane daemon
  Deployment; the waiting Pod can complete prerequisites but receives no mutation capability and keeps
  `/readyz` false. The host stops action issuance, drains in-flight work, executes the typed
  `BootstrapHeld → ReleasedForHandoff` release by expected-resourceVersion CAS, and observes its holder absent
  on the same object UID at the successor version. Only the typed `ReleasedForHandoff → ControlPlaneHeld`
  handoff action may then install the exact authenticated control-plane daemon Pod UID and mint reconcile/Serving
  authority after successor readback. Each action CAS-consumes a fresh snapshot-bound token and reserves its
  exact one-update/one-revision etcd debit; a stale CAS, timeout, or lost response retains the debit and
  re-observes with no authority. Holder identity/object UID/resourceVersion and every observation enter the
  fingerprint; unknown or changed state restarts the read-only prefix.
- Secret authority fused to the role (operates root Vault as the single in-cluster writer) and the admin-REST
  control surface stub through which the operator's Haskell command-mode client later drives the cluster — promoted to the real
  four-endpoint surface by [Sprint 65.4](#sprint-654-the-admin-rest-surface--vault-initunseal-dhall-update-secret-kv-crud-).

### Validation

1. The control-plane daemon manifest is a `Deployment replicas=1` with no PVC and carries no amoebius election
   controller, no ranked-failover configuration, and no standby Pod; the Pod comes up, runs the daemon spine,
   and serves `/healthz`, `/readyz`, and `/metrics`. During initial handoff, assert the Pod
   remains non-Serving and performs zero mutations while the bootstrap host holds the Lease; then observe host
   quiescence, release, fresh same-Lease holder absence, exact control-plane daemon UID acquisition, and only then
   `/readyz`, with no host mutation after release and no control-plane daemon mutation before acquire.
2. A Pod delete converges a replacement with no data loss. "At most one writer" is observed concretely
   (§M.5): an apiserver watch records every Pod UID, owner chain, protected source annotation, phase, and
   Lease transition across the whole delete-to-reschedule window, and at every resource version at most one
   authenticated UID holds the Lease while every simultaneously present or reserved UID stays in the capacity
   ledger. "No data loss" names the durable state probed: the `InForceSpec` object written to the
   Vault-Transit-enveloped MinIO bucket before the delete is read back once the replacement reports `/readyz`
   ready, and its decrypted bytes are byte-identical to the pre-delete write — which a stateless pod that had
   lost its durable MinIO state could not produce.
3. The reconcile loop runs one idempotent pass to convergence from a decoded spec and a re-run is a no-op,
   where **"no-op" is defined observably (§M.6) as: the second pass's apiserver audit log records zero mutating writes (`create`/`update`/`patch`/`delete`) under the control-plane daemon field manager** — unchanged end-state
   readiness alone does not satisfy this. To prove the compute path actually ran on the second pass (not a
   skipped/memoized short-circuit), the second pass executes with any reconcile result cache bypassed and its
   `discover` step is observed to have re-read live cluster state before concluding the empty diff. The
   codebase contains no election/ranked-failover module and no standby pod is ever scheduled.
4. Make each control-plane daemon CPU, memory, ephemeral, image/import, writable/log, projected-file, runtime-metadata,
   pod-slot, Deployment-cardinality, and Deployment-rollout operand one unit short; change the pinned metadata
   model; drop/swap a component role; mismatch the planned-slot/observed-UID domain; overlap/leak qualified
   Pod/image ownership; double-debit an alias; make either SplitRuntime nodefs or imagefs/containerfs one byte
   short; or drop the largest simultaneous metadata row. Separately make each control-plane-state resident/version/failure/budget term
   short or omit one state kind/admission envelope. Every negative rejects before Deployment creation or MinIO
   mutation. For the exact-fit twin, live Pod/Deployment and exact object-key readback equal the provisioned
   projection, including the replacement-Pod transition epoch.
5. Inject simultaneous acquire, stale-resourceVersion release, lost release/acquire response, watch gap,
   bootstrap crash before and after release, control-plane daemon crash before and after acquire, and replacement-Pod UID
   churn. Every trace either reaches one authenticated control-plane daemon holder or refuses with no overlapping
   mutation; audit history shows zero host writes after observed release and zero control-plane daemon writes before
   observed acquire. Assert every attempted Release/Handoff consumes its fresh token, every present-state
   mutation uses the exact expected resourceVersion, and a lost/ambiguous response remains charged one etcd
   update/revision until successor or no-write readback. Drop one Lease object/RBAC/churn operand or mutate
   only the holder UID and require preflight refusal before any other effect.

> **Honesty.** Kubernetes/etcd, not amoebius, supplies the exclusion property behind "never two simultaneous
> Lease holders" ([daemon_topology_doctrine.md §3.1](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)). amoebius's obligation here is narrower and
> real: it must not authorize either client on an unknown/stale transition and must observe bootstrap release
> before enabling the control-plane daemon. Cross-cluster gateway migration remains owned by the multi-cluster phase.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 65.2: Live reconcile of the platform + a trivial app from one Haskell declaration ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 65.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
at the runtime layer: the typed spec gates guard the **live** deploy, but decoded IR is never reconciled
directly. The control-plane daemon must bind/expand it, derive the conditional infrastructure result, authenticate the
already-materialized target (or receipt-bound enacted result), construct `ProvisionContext`, and successfully
`provision` the exact target into an opaque
`ProvisionedSpec`, and call deployment-level `renderAll`; any capacity or compatibility failure stops before
effects. This gate proves the apiserver admits what the complete pure pipeline sealed. The pure integrity
itself was proven in-process in the pre-cluster band; here it is exercised, not re-established.

### Deliverables

- A positive deploy value authored in Haskell and lazily rendered as Dhall beneath `.build/test-corpora/**`,
  composing the standard platform-service stack (Phases 41–42) and a **trivial**
  single-service app — deliberately narrower than the Phase-66 tenancy projection (no per-app namespace,
  ObjectStore, or in-namespace Sql fanout), but still carrying a complete app Pod/rollout envelope.
- The control-plane daemon's live reconcile of that spec: decode → capability-bind/expand → `planInfrastructure` →
  materialization observation/receipt → `ProvisionContext` → whole-deployment provision →
  observed-inventory preflight → `renderAll` → SSA-apply → wait-to-ready, each edge a witnessed condition — **the
  witness for each apply/ready edge is externally observable apiserver
  evidence (the object's live `status`/managed-fields and the audit-log write record), never a log line or
  metric the control-plane daemon emits about itself (§M.5)** — with a re-run proven idempotent (no drift, no re-apply)
  under the audit-log no-op definition the validation list below fixes.
- A hard effect boundary: pure whole-deployment provision includes the control-plane daemon, mutation-admission gateway,
  every desired Pod/controller child and producer, durable claims, Pod/CSI slots, and planned transition peaks.
  Snapshot-bound preflight then joins every observed/reserved/terminating/terminal-retained identity and builds
  the observed node runtime/image-storage aggregate before minting `ValidatedLiveTarget`. Any
  `Left ProvisionError` or live-preflight refusal exits before state PUT or SSA apply; no renderer accepts raw
  `InForceSpec`/`BoundDeployment` values.
- A leak-free teardown obligation carried by the Haskell deploy fixture; its generated test-topology Dhall
  projection remains beneath `.build/test-corpora/**` and its postflight
  sweep asserts every provisioned object (the run-unique-labelled set defined in the validation list below) was
  reclaimed, while the pre-existing Phase-62/42 service set and Phase-64 edge are restored to Ready rather than
  swept.

### Validation

1. Before the first pass the harness deletes the components named by a separately authored Haskell
   perturbation declaration. Its optional text projection is generated lazily beneath
   `.build/test-corpora/live_dsl_deploy/**`. It names at minimum one platform `Deployment` and its `Service`, for
   example Prometheus's — so a pre-converged Phase-62/42 stack cannot ride the gate (§M.6). The first pass
   then restores them and brings the platform + trivial app up on the linux-cpu cluster, its created/patched
   set read from the apiserver audit log rather than the control-plane daemon's self-report (§M.5), non-empty,
   and equal to the first-pass Haskell expectation. The app is reachable through the Phase-64
   Keycloak-owned edge; a re-run issues zero mutating writes under the control-plane daemon field manager and
   equals the second-pass Haskell expectation. Any JSON view is generated lazily beneath `.build/**`.
2. Teardown leaves no leaked resources. The postflight sweep is scoped to this run's provisioned objects,
   identified by the run-unique label `amoebius.dev/phase33-run=<run-id>` the control-plane daemon stamps on every object
   it creates — that label set is authored here, and Phase-48 flag-at-creation machinery is not assumed — and
   the sweep is empty over it. Separately, every platform component the harness perturbed is asserted back at
   Ready so the shared Phase-62/42 stack is left as found, and the apiserver audit log records that **every**
   platform/app write was issued by the control-plane daemon's in-cluster ServiceAccount and none by the harness
   principal.
3. A Haskell-authored changed-subject provision-bypass mutant that renders the raw bound spec, and omission mutants that drop the
   control-plane daemon, trivial-app, or gateway envelope, a present producer instance, or a union match branch must turn
   the gate red before apply. The positive run compares normalized live requests/limits/images/local storage,
   controller children, claims, and object keys with the opaque provisioned deployment rather than merely
   checking `Ready`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 65.3: Phase gate harness — live deploy + the pre-cluster negative corpus as a live regression guard ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 65.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
assemble the phase's single live acceptance gate — one Haskell-declared topology, rendered lazily as Dhall
beneath `.build/**`, deploys the platform + a trivial app on
linux-cpu and the live apiserver admits the rendered manifests — and, as a regression guard, re-run the
pre-cluster (Phase-27) Haskell negative corpus so each lazily generated illegal Dhall projection still fails to type-check or decode
against the live path, and the positive fixtures still decode. That type/decode result was proven in-process in
the pre-cluster band; here the guard confirms the live deploy path never admits an illegal spec.

### Deliverables

- The positive gate: the Sprint-60.2 platform + trivial-app deploy driven to ready by the control-plane daemon
  and torn down leak-free, declared in Haskell with any Dhall test-topology transport rendered lazily beneath
  `.build/**` and left untracked.
- The negative regression guard: the Phase-27 corpus (a bad PVC↔PV pairing, a Keycloak-bypassing open ingress, a
  product named in application logic, and the capacity/topology/bounded-storage set) **re-run** against the
  live deploy path (the same control-plane daemon `Deploy.hs` entry the positive fixture used), each asserted to fail at
  dhall-typecheck or gadt-decode **with its specific foreclosure tag matching a separately authored Haskell
  expectation** (each case maps to an expected `dhall type` error or `DecodeError` tag independently of the
  control-plane daemon's decoder — §M.3/§M.8), and each paired with a
  positive that differs only in the foreclosed dimension — **never re-establishing** the type discipline, only
  guarding that the deploy path inherits it.
- **Applied Haskell changed-subject mutants (§M.2):** at least `enact-noop` (the
  dropped-effect `Reconcile.hs::enact`, red because the perturbed component is never restored) and an
  attribution mutant (harness principal issues the writes, red because the audit clause detects a non-control-plane
  writer) — both applied to the Haskell production subject and re-run, each asserted to turn the gate red.
- The **independent Haskell oracle bundle** is checked before the subject; every Dhall/JSON/text/YAML form it
  needs is generated beneath the candidate's `.build/**` root and is never tracked source or authority.
- A **Register-3** proven/tested/assumed ledger recording the live-enforcement result (the apiserver admitted
  the rendered manifests) and marking the deferred surfaces — full app tenancy (Phase 66), and the
  cross-cluster gateway-migration correspondence (the multi-cluster phase) — as UNVERIFIED, never green.
- The Haskell-declared resource-boundary corpus: one exact-fit topology plus one-short and omission cases for the
  control-plane daemon envelope, rollout overlap, runtime component roles/layout backings and scope-indexed node
  domain/ownership/grouping, admission gateway, and all five `ControlPlaneState` entry kinds and
  their `StorageBudgetId`/retention/failure terms. Each negative also asserts zero audit writes and zero MinIO
  mutation.

### Validation

1. After perturbation, the positive Haskell-declared topology restores and brings the platform + trivial app
   up. Its first-pass audit-log enact set matches the independently authored Haskell expectation and all
   writes are attributed to the control-plane daemon SA; the app
   is reachable through the Keycloak edge, and teardown leaves no leaked resources over the run-unique label
   set; the applied Haskell `enact-noop` mutant turns this red.
2. "The live deploy path" is pinned to the identical entry point the positive fixture used, foreclosing the
   host-side re-run cheat (§M.3): every Phase-27 negative fixture is submitted through the exact same control-plane daemon
   spec-ingestion/`Deploy.hs` entry, never a separate host-side CorpusSpec decoder, and each yields a
   structured dhall-typecheck (`dhall type` error) or gadt-decode (`DecodeError` tag) rejection whose emitted
   tag equals the separately authored Haskell expectation for that case (§M.8) — a bare "it failed" does not satisfy
   this. That no fixture reaches the apiserver is proven rather than assumed (§M.5): across the whole corpus
   run the audit log shows zero platform/app-object writes and the pre/post full-cluster `resourceVersion`
   snapshot is equal, so cluster state is byte-for-byte unchanged. The positive fixtures decode, and the
   ledger honestly classifies each foreclosure (no runtime-checked or deferred claim — tenancy,
   gateway-migration — is reported as proven).
3. Run the resource-boundary and provision-bypass mutants through that same control-plane daemon entry. Assert each
   returns its specific `ProvisionError` before effects, while the exact-fit twin's live normalized
   Pod/controller/object-store projection is equal to the private provisioned value.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 65.4: The admin REST surface — `vault init/unseal`, `dhall update`, secret KV-CRUD ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 65.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`bootstrap_sequence_doctrine.md` §5 — the admin control plane: the CLI ↔ the control-plane daemon REST API](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-control-plane-daemon-rest-api)
in full, read with [`vault_pki_doctrine.md` §5 — the root cluster single-node password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal)
and [`dsl_doctrine.md` §6 — secrets are names, never values](../documents/engineering/dsl_doctrine.md#6-secrets-are-names-never-values):
deliver the **one surface** through which the operator drives a running cluster, so that "amoebius-level control
is the control-plane daemon's sole authority, reached only through the admin REST" has an inhabitant rather than a stub.
Two properties are load-bearing and are what this sprint's gate actually proves:

- **The reach is regime-split.** Seal-critical operations (`vault init/unseal`, including every reboot's unseal)
  are **node-local only** and **Vault-independent by construction** — they need no fabric, no gateway, and no
  secret from the Vault they are about to unseal. Post-unseal admin (`dhall update`, KV-CRUD) *may additionally*
  ride the authenticated WireGuard fabric once it exists
  ([`host_cluster_comms_doctrine.md` §5.1](../documents/engineering/host_cluster_comms_doctrine.md#51-the-generalization-localhost-or-the-authenticated-wireguard-fabric)).
  Unseal is **never** over the fabric: the fabric's peer keys are themselves Vault-KV
  ([`vault_pki_doctrine.md` §3.1](../documents/engineering/vault_pki_doctrine.md#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken)),
  so a fabric reach presupposes the unsealed Vault it is trying to produce.
- **`dhall update` admission is runtime-checked, and honestly labelled so ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).** A named `SecretRef`'s
  *existence* is a decode-time check; its *capability* is proven **live at upload**, against real hosts and
  cloud APIs. This is the one place in the phase where a gate reaches outside the cluster, and the ledger must
  say so rather than reporting it alongside the decode-time foreclosures.

The surface is **privileged, not wild** — network-restricted to the operator's trusted reach, never the
LB→Envoy→Keycloak door — so "Keycloak owns all *wild* ingress"
([`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path))
is untouched by its existence.

### Deliverables

- **`vault init/unseal`** — authenticated by the operator password (the Argon2id→AEAD unlock material of Sprint
  30.1, cited not restated), filling the *pluggable pre-Vault unseal seam* that doctrine leaves open. The
  password is transported and never persisted; `unseal` against an already-unsealed Vault is a typed no-op,
  never a re-init.
- **`dhall update`** — deliver a new `InForceSpec` to a running cluster (requires an unsealed Vault and a root
  token). The control-plane daemon decrypts/stores the envelope in-process and reconciles toward it via Sprint 65.2's loop.
  Admission **actively proves each named secret before admitting the upload**: the secret exists in Vault, an
  SSH key connects to each static host the spec names and that host's declared CPU, memory,
  pod-ephemeral/durable/native-cache pools, accelerator device vector and per-device memory match observation,
  and a cloud credential carries the IAM permissions and compute/storage/accelerator quotas to provision what
  the spec declares. Rejection is fail-fast, before any reconcile.
- **`kv put/get/list/delete`** — secret KV-CRUD by name. Operators populate every production `SecretRef` target
  in Vault before uploading the run-local transport generated from Haskell beneath `.build/**` or supplied as
  an external, untracked operator value; this command transports the value into envelope storage, while the
  specification continues to contain only its name
  ([`vault_pki_doctrine.md` §3](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)).
- **The Haskell command-mode admin-REST client** — the post-handoff operator client. It shares the one
  amoebius executable, consumes this surface, and adds no second control path; `pb` has already ended at exec.
- **The reach-class enforcement** as typed structure rather than deployment convention, so a seal-critical verb
  has no constructor reachable from a non-node-local source.
- **independent Haskell oracles (§M.1)**, authored before `AdminApi.hs` exists: a reach matrix mapping endpoint
  family × reach class to admit/refuse plus the exact refusal tag, an admission-tag inventory with one row per
  foreclosed cause, and a Haskell paired corpus for secrets capability — four
  negative/positive pairs (absent secret · SSH key that cannot connect · host short of its declared resources ·
  cloud credential lacking permission or quota), each pair differing **only** in the foreclosed dimension (§M.8).
- **Applied Haskell changed-subject mutants (§M.2)**, generated and re-run, each MUST turn Validation red: (i) a
  *dropped-effect* mutant `persist-password` that writes the operator password to the container
  filesystem (must fail the §M.5 non-persistence observer); (ii) a *guard-weakening* mutant
  `reach-any` that accepts a seal-critical verb over any reach (must fail the reach matrix); and
  (iii) a *guard-weakening* mutant `admit-unproven-secret` that admits an upload whose named
  secret fails its capability probe (must fail the paired corpus).
- A **Register-3** proven/tested/assumed ledger recording the admission gate as **runtime-checked, live**, and
  marking explicitly UNVERIFIED: the tenant-admin scope-narrowed `dhall update`
  ([phase_66](phase_66_app_tenancy.md)) and the parent→child `ParentReachChannel` use of this surface
  ([phase_77](phase_77_provider_child_bringup.md)), neither of which this phase exercises.

> **HTTP server resolution.** `app/amoebius/Amoebius/Entry/ControlPlane.hs` uses a small static Haskell HTTP/1.1 server over the
> already-frozen dependency surface established by [Phase 1](phase_01_toolchain_spike.md). It accepts bounded concurrent connections, serializes admin effects with
> one lock, and renews/rechecks Lease authority through a separate lock so long reconciles do not make the
> control-plane daemon lose readiness or act on stale authority.

### Validation

1. **The post-handoff operator sequence, end to end.** After Sprint 65.1's observed handoff, drive `vault
   init/unseal` → `dhall update` → `kv put/get/list/delete` through the NodePort surface only, and assert the
   cluster converges to the delivered `InForceSpec` via the Sprint-60.2 loop. The operator password crosses
   CLI → NodePort → control-plane daemon and is never persisted, and the observer that settles it is an OS-boundary one
   (§M.5): a write/`strace` observer over the control-plane daemon process and its container filesystem plus the
   apiserver audit log, never a log the endpoint emits about itself. Assert from that observer that the
   password appears in no file, environment variable, k8s object, or log line; the applied Haskell changed-subject
   `persist-password` mutant MUST turn this red.
2. **The reach matrix (§M.3).** For every (endpoint family × reach class) cell, assert the observed
   admit/refuse decision and exact refusal tag equal the independently authored Haskell reach matrix. Any TSV
   projection is generated lazily beneath `.build/test-corpora/**`. A seal-critical verb attempted over
   a fabric or LAN source is refused **before any Vault contact**, with its own reach-violation tag (asserted
   from the Vault audit device: zero contact for the refused attempt, not merely a failed one). The applied
   Haskell changed-subject
   `reach-any` mutant MUST turn this red.
3. **Specific-reason admission negatives (§M.8).** Each `dhall update` whose named `SecretRef` fails its
   capability probe is rejected before any reconcile: each of the four `secrets-capability` negatives is
   rejected with its own independently authored Haskell admission tag; any TSV projection is generated
   lazily beneath `.build/test-corpora/**`. A generic "rejected" fails the check, and each
   is paired with a positive differing only in the foreclosed dimension that is admitted. Assert the apiserver
   audit log records **zero** writes for every rejected attempt (rejection precedes reconcile, not merely
   precedes convergence). The Haskell-authored changed-subject `admit-unproven-secret` mutant MUST turn this red.
4. **The ledger** is emitted and honestly classifies the admission gate as runtime-checked/live, marking the
   tenant-admin and parent→child uses UNVERIFIED; a ledger reporting either as proven fails the gate.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/daemon_topology_doctrine.md` — the §3 / §3.1 control-plane-control-plane and the §5
  delegated-single-instance honesty notes flip from "design intent for the live-DSL-deploy phase" to a
  delivered Deployment-`replicas=1` control-plane daemon with its Register-3 ledger attached; record that single-instance
  landed as a k8s/etcd property with no amoebius election built.
- `documents/engineering/dsl_doctrine.md` — the §5 contract's runtime-enforcement note flips from "design
  intent" to live-enforced only once the gate runs — the two gates now guard the live deploy path.
- `documents/engineering/manifest_generation_doctrine.md` — record that the control-plane daemon is the role
  that runs the typed reconciler's loop, and that its own manifest is a generated `Deployment replicas=1`.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (tenancy
  and gateway-migration correspondence UNVERIFIED).
- `documents/engineering/bootstrap_sequence_doctrine.md` — the §5 admin-control-plane honesty note flips from
  "Phase 0 design intent" to a delivered four-endpoint surface with its Register-3 ledger attached; the §7
  planning-ownership orientation records that the whole surface — seal-critical verbs included — lands with the
  control-plane daemon in this phase, since no control-plane daemon exists to host an endpoint before it.
- `documents/engineering/substrate_doctrine.md` — the §6 pre-binary handoff contract leaves every
  post-handoff administrative verb to this phase's Haskell command mode.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-65 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — confirm the Phase-65 linux-cpu gate row (the replicas=1 control-plane daemon, no
  election).
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/ControlPlane/{Daemon,Reconcile,Deploy,AdminApi}.hs`
  as Phase-65 design-first rows, and re-anchor the in-cluster-control-plane row to the current
  `#3-the-control-plane-daemon` (no election).
- `DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md` — its exec handoff now names Sprint 65.4 as owner
  of the Haskell admin-REST client.
- `DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md` — its post-handoff child admin-REST bring-up can now
  name Sprint 65.4 in `Blocked by`.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the replicas=1 control-plane daemon)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map (the linux-cpu gate row)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the control-plane daemon
  as a Deployment `replicas=1`, single-instance delegated to k8s/etcd, and the shared daemon spine
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the typed spec gates and the illegal-state contract
  guarding the live deploy path
- [Bootstrap Sequence Doctrine](../documents/engineering/bootstrap_sequence_doctrine.md) — the [§5](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-control-plane-daemon-rest-api) admin control
  plane (CLI ↔ control-plane daemon REST) delivered by Sprint 65.4, and the [§4](../documents/engineering/bootstrap_sequence_doctrine.md#4-the-host-daemon--control-plane-daemon-handoff) handoff point at which it is exposed
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the password-encrypted unseal and the
  `SecretRef`-is-a-name contract the admin endpoints front
- [phase_55](phase_55_bootstrap_coordinator_kind.md) — the bootstrap-to-Haskell exec handoff that precedes
  the command-mode admin client Sprint 65.4 owns
- [phase_61](phase_61_vault_pki.md) — the root Vault, unlock-material envelope, and built-in Vault client the
  admin endpoints call
- [phase_77](phase_77_provider_child_bringup.md) — the parent→child bring-up that drives a child through this
  same surface over its `ParentReachChannel`
- [phase_58](phase_58_object_reconciler.md) — the typed renderer + SSA reconciler that renders and applies
  the control-plane daemon and its manifests
- [phase_62](phase_62_platform_backbone.md) — the standard platform-service stack the live Haskell-declared spec deploys
- [phase_64](phase_64_keycloak_ingress.md) — the Keycloak-owned edge the trivial app routes through
- [phase_66](phase_66_app_tenancy.md) — the app-tenancy projection (namespace + ObjectStore + Sql) deferred
  from this phase
