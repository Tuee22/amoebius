# Phase 29: Execution-epoch + scheduler + accelerator + provider-root folds

> **Purpose**: Build the kind-indexed execution-epoch expansion, the scheduler-reservation algebra, the
> kubelet/CRI runtime-metadata and node-local OCI/image accounting, the accelerator residency/net-allocatable-VRAM
> fold, and the provider-root disk-template arithmetic as total in-process Haskell, then **compose** them with the
> Phase 9 base capacity fold and the Phase 28 storage geometry into the full-resource-vector `place` witness that
> must cover every axis in a Haskell corpus and reject every execution/accelerator/provider-root/runtime-metadata
> negative directly on its isolated insufficient axis — before any host or cluster exists.
> **Read this if**: phase 29 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 29.1: Execution-epoch expansion + scheduler-reservation algebra ⏸️](#sprint-291-execution-epoch-expansion--scheduler-reservation-algebra-)
- [Sprint 29.2: kubelet/CRI runtime-metadata + node-local OCI content/snapshot/image + physical-disk parent accounting ⏸️](#sprint-292-kubeletcri-runtime-metadata--node-local-oci-contentsnapshotimage--physical-disk-parent-accounting-)
- [Sprint 29.3: Accelerator residency/net-allocatable-VRAM + provider-root disk template + engine/build/etcd/monitoring compute ⏸️](#sprint-293-accelerator-residencynet-allocatable-vram--provider-root-disk-template--enginebuildetcdmonitoring-compute-)
- [Sprint 29.4: The composed full-resource-vector place-witness — properties + independent validator + per-axis mutants ⏸️](#sprint-294-the-composed-full-resource-vector-place-witness--properties--independent-validator--per-axis-mutants-)
- [Sprint 29.5: The execution/accelerator/provider-root fold-negative corpus + the composed gate ⏸️](#sprint-295-the-executionacceleratorprovider-root-fold-negative-corpus--the-composed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 28, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** A pure Haskell fold is to make amoebius's *"every resource provision
is explicit and impossible targets have no deployable value"* invariant executable along its **execution,
accelerator, and provider-root axes**, composing those
axes with the Phase-9 base fold and the Phase-28 storage geometry into the single whole-deployment place-witness.
Haskell values own every case and expectation; any serialized case or mutation is generated lazily beneath
`.build/**`.
Phase 31's post-bind provision seal invokes the same folds only after full bind/expansion; Phase 29 does not move
them into `Dhall.inputFile`.

The target Haskell model includes the private kind-indexed `BoundExecutionBody` and its expansion:

- The `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` `ExecutionTransitionSource`, the
  `PriorExecutionProvision` steady projection, and the desired `BoundExecutionSet` carried by
  `BoundExecutionInventory`; the closed controller bodies — Deployment `ReplicaCardinality` +
  `DeploymentRolloutPolicy`, native serial `StatefulSetRolloutPolicy`, `NodeEligibilitySelector` +
  `DaemonSetRolloutPolicy`, finite Job completions/parallelism/backoff/terminal retention, and supervised
  `HostProcessCardinality` + replacement policy — and the expansion into identity-keyed
  `MaterializedExecutionInstance`s, complete empty-capable `ExecutionEpoch`s, and `ProvisionedExecutionEpochs`.
- The scheduler-reservation algebra: `CompleteResourceReservation` — whose `PodComputeReservationAxes` carries
  the three declared-headroom pad scalars beside the request and limit debits, so the required and reserved
  components of a row stay separable and its `ResourceEnvelopeReservationProjectionWitness` proves the
  reservation is the envelope's required projection composed with its declared pad rather than an
  independently authored vector — the zero-capable release partitions, which partition all nine compute
  scalars exactly so a released row returns its pad rather than leaking it, the
  aggregate scheduler/host reservation ledger, `ProvisionedExecutionSchedulingGuard`, the Reserved →
  BindingInFlight → Bound states around Kubernetes Binding, the aggregate root-ledger CAS, the
  `LedgerOnlyAbsentRecovery` state-selected debit for a Pod whose ledger row lingers, and the private
  `ControllerChildEnvelope`/`ProvisionedControllerChildren` that lower to the same units and epochs.
- The kubelet/CRI runtime-metadata fold: `PodRuntimeMetadataSource`, `KubeletRuntimeMetadataShape`,
  planned-slot/observed-Pod-UID `KubeletRuntimeMetadataDemand`, `ProvisionedKubeletRuntimeMetadataDemand`,
  `PodRuntimeRole` (`KubeletNodefs | CriRuntimeRoot`), `KubeletMappedFileDemand`, and their resolution through
  the substrate-indexed `HostRuntimeEnforcement`/`KubeletFilesystemLayout` in the closed
  `Unified | SplitRuntime | SplitImage` routing.
- The node-local OCI content/snapshot/image accounting: `ImageStorageRole`, `NodeImageStorageModelVersion`,
  `ProvisionedNodeImageStorageDemand`, `ImageArtifact` index/manifest/config/layer joins, snapshot chains, and
  the scope-indexed `ProvisionedNodeRuntimeStorageAccounting` grouping combined metadata + image bytes by
  physical carve exactly once.
- The accelerator residency/net-allocatable-VRAM fold: the closed accelerator demand/offering types, the
  `Unsharded | ReplicatedPerDevice | Sharded` residency placement over every policy-permitted coexistence
  epoch, per-device aggregation, shard-id uniqueness/count/byte-sum, the required peer/NVLink graph, and the
  `driverRuntimeReserve + allocatableVram ≤ rawVram` net allocatable invariant.
- The provider-root arithmetic: the `ProvisionedPerInstanceDiskTemplate`, `InstanceStore.provisionedRawBytes`
  and `EphemeralRootEbs`→`ProvisionedNodeRootVolumeRequest` derivation, the distinct `nodeRootStorage`
  byte/volume-count quota, and the `PhysicalDiskPartition` two-equation parent accounting over
  `NamedDiskCarve (PhysicalRawExtent | VmGuestUsableExtent)` and `ProvisionedVmDiskCarve`.
- The compute-derivation envelopes feeding the vector: `BuildExecutionEnvelope`, role-indexed
  `EngineSystemReserve` (`ControlPlane | Worker` storage), `EtcdLogicalDemand`/`ProvisionedEtcdLogicalDemand`,
  the mandatory `MonitoringWorkBudget`, and `PulumiExecutionDemand`/`ProvisionedPulumiExecutionDemand`.

Above them it owns the **composed** `place`: the full-resource-vector pod→node witness that, for a fixed node
set, proves CPU/memory, pod-CNI and CSI slots, logical and physical node storage, OCI content/snapshots/workspace,
durable/cache demand (Phase 28), accelerator devices plus every identity-complete owner residency epoch, and every
execution/admission envelope all fit simultaneously — the componentwise peak, never a CPU-only or steady-only
multiplier — and, for an elastic node set, the capability-aware growth envelope over the same vector. In the
catalog's vocabulary, every check here is a total, **decode-foreclosed** decision over a constructible input at
`provision-seal`, not a type-inhabitance claim. Soundness means every accepted result satisfies the combined
resource envelope; each named execution, accelerator, provider-root, and runtime-metadata negative must instead
produce its structured rejection.

What is *not* here: the base `fits`/`carve`/`place`, `Quantity`/`Capacity`/`Demand`/`Budget`, the
CPU-limit/pod-ephemeral/tmpfs/memory-volume negatives, and the topology relation
([phase_09_resource_index.md](phase_09_resource_index.md)); the logical→physical
BookKeeper/MinIO/Vault/ZooKeeper/Patroni/registry/schema/object-store/Pulsar geometry, the native +
in-cluster cache-storage geometry, and `StorageBudget`/`Growable`/`planStorageScaling`
([phase_28_storage_geometry_folds.md](phase_28_storage_geometry_folds.md)); the capability→provider→shape
binder ([phase_30_capability_bind.md](phase_30_capability_bind.md)) and the whole-deployment provision seal
([phase_31_provision_seal.md](phase_31_provision_seal.md)) that re-exercise these folds post-bind; the
`InferenceEngine` capability + accelerator coexistence provision
([phase_32_inference_accelerator_provision.md](phase_32_inference_accelerator_provision.md)); and the live
residue — the same-binary scheduler role's Reserved→BindingInFlight→Bound around real Kubernetes Binding
([phase_59_capacity_scheduler.md](phase_59_capacity_scheduler.md)), the snapshot-bound live preflight and
action/token/CAS plumbing ([phase_58_object_reconciler.md](phase_58_object_reconciler.md)), retained-carve
allocation ([phase_60_retained_storage.md](phase_60_retained_storage.md)), provider-capacity creation
([phase_76_provider_deploy_checkpoint.md](phase_76_provider_deploy_checkpoint.md), [phase_79_provider_dynamic_nodes.md](phase_79_provider_dynamic_nodes.md)), and live CUDA/Metal enaction
([phase_93_jitml_rederivation.md](phase_93_jitml_rederivation.md), [phase_89_apple_metal_host_daemon.md](phase_89_apple_metal_host_daemon.md)). Phase 29 owns the pure
representation and fold only; it cannot validate or enact a live transition.

**Phase scope:** one target claim — the pure Haskell full-resource-vector fold returns a placement witness or
names the refusing axis. It observes no device, host, provider, or cluster.

**Substrate:** none — no host, cluster, device, or provider; the canonical Haskell gate owns the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 28](phase_28_storage_geometry_folds.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 29`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — the pure Haskell full-resource-vector fold returns a placement witness or one structured refusing axis. It consumes Haskell values; any serialized case or mutation is generated beneath `.build/**`; and it makes no hardware or live-capacity claim. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 29` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | MISSING — blocks validation: the current Phase 28 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes execution-epoch + scheduler + accelerator + provider-root folds causes to exist are charged to a grant that carries its ceiling and concurrency together.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  — the identity and derivation obligations checked construction adds beyond a record's fields. This phase's
  execution/accelerator/provider-root smart constructors discharge them: every demand it declares is derived
  through its stated operands rather than authored, and its identity keys (planned slot, observed Pod UID,
  per-device residency epoch) are checked at construction, not asserted downstream.
- [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the total fold `fits`/`carve`/`place` and the nesting: this phase composes the four total functions and the
  host → VM → workload nesting over the full resource vector, with `place` branching per
  [`resource_capacity_folds.md` §4.1 — `place` branches: static proves a placement, dynamic proves a growth envelope](../documents/engineering/resource_capacity_folds.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope)
  (a fixed node set proves a placement witness; an elastic one proves a growth envelope), reading the declared
  `Capacity`/`Demand`/`Budget` types of [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and the execution/accelerator/provider-root demands this phase's target must add atop the Phase-9 base fold.
- [`resource_capacity_doctrine.md` §2 — The load-bearing honesty limit: a capacity sum is a decode-foreclosed check, never type-foreclosed](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)
  — the load-bearing honesty limit: a capacity/accelerator/execution sum is a checked rejection
  (**decode-foreclosed** in the historical layer taxonomy), never type-foreclosed; its concrete locus is the
  post-bind `provision-seal`, and the composed compute placement is **sound, not complete** (first-fit-decreasing
  may reject a packable spec but never admits an unplaceable one). The QuickCheck properties assert soundness
  only for `place`; completeness is deliberately not claimed.
- [`illegal_state_techniques.md` §4.6 — Capacity accounting — placement witness (compute) and summed demand within capacity (storage), checked](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
  — the capacity-accounting placement-witness technique this phase's target must discharge along its seam, covering the
  execution/runtime-metadata/provider-root entries [`illegal_state_security.md` §3.11 — An unsafe workload (no resource limits, no hardened securityContext)](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)/[`illegal_state_capacity.md` §3.17 — An over-committed deploy or workload (host / VM / cluster capacity exceeded)](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)/[`illegal_state_storage.md` §3.19 — An application consuming more storage than its backing (MinIO and Pulsar)](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar) and the accelerator entries [`illegal_state_capacity.md` §3.27 — A deployment that fits in aggregate but has no resource-capable placement](../documents/illegal_state/illegal_state_capacity.md#327-a-deployment-that-fits-in-aggregate-but-has-no-resource-capable-placement)–[`illegal_state_capacity.md` §3.30 — An accelerator memory envelope that cannot fit the selected devices or unified-memory pool](../documents/illegal_state/illegal_state_capacity.md#330-an-accelerator-memory-envelope-that-cannot-fit-the-selected-devices-or-unified-memory-pool) at
  the honest layer
  ([`illegal_state_techniques.md` §6 — Three layers of foreclosure (and the honesty they force)](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
  every capacity/accelerator **sum** is checked at `provision-seal` and never type-foreclosed, honoring the
  load-bearing limit of
  [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it).
  (The [`illegal_state_techniques.md` §4.7 — Compatibility / topology relations by construction over a collection](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) compatibility/topology technique and the [`illegal_state_topology.md` §3.13 — A compute engine incompatible with its substrates (managed providers first-class)](../documents/illegal_state/illegal_state_topology.md#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class)–[`illegal_state_topology.md` §3.16 — A multi-node rke2 cluster with fewer Linux hosts than nodes (or a host reused)](../documents/illegal_state/illegal_state_topology.md#316-a-multi-node-rke2-cluster-with-fewer-linux-hosts-than-nodes-or-a-host-reused) topology entries are discharged by [phase_09_resource_index.md](phase_09_resource_index.md); the durable/object/Pulsar [`illegal_state_storage.md` §3.19 — An application consuming more storage than its backing (MinIO and Pulsar)](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar)–[`illegal_state_storage.md` §3.21 — Capacity growth without an amoebius-owned scaling policy](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy) storage-geometry entries by [phase_28_storage_geometry_folds.md](phase_28_storage_geometry_folds.md).)
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  (**Register 1** — pure/semantic-oracle, in-process, no cluster) and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) (the per-run proven/tested/assumed ledger): the
  register this gate reaches and the ledger it emits, with model↔runtime correspondence and runtime fidelity
  marked UNVERIFIED (owned by the live band).

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 29.1: Execution-epoch expansion + scheduler-reservation algebra ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`resource_capacity_doctrine.md §4/§4.1`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and the honesty limit of [`§2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
build the kind-indexed `BoundExecutionBody` expansion into `MaterializedExecutionInstance`s and complete
`ExecutionEpoch`s, and the scheduler-reservation algebra (Reserved→BindingInFlight→Bound, the aggregate
root-ledger CAS, and `LedgerOnlyAbsentRecovery`), as pure, checked `provision-seal` operations reading declared
numbers only — the pure expansion fold Phase 31's `provision` seal later invokes.

### Deliverables

- `BoundExecutionInventory` carries exactly one `FirstDeployment | UpdateFrom PriorExecutionProvisionRef`
  transition source and the desired `BoundExecutionSet`. `FirstDeployment` resolves to an exact empty prior map;
  an update resolves the exact digest-keyed prior steady projection from `ProvisionContext`, including
  prior-only removed units. No bound value carries a prior `Provisioned*` record or an implicit latest
  generation. Every `BoundExecutionUnit` carries one private kind/resource-compatible `BoundExecutionBody`:
  Deployment with `ReplicaCardinality` plus `DeploymentRolloutPolicy`; StatefulSet with its native serial
  `StatefulSetRolloutPolicy`; DaemonSet with `NodeEligibilitySelector` plus `DaemonSetRolloutPolicy`; Job with
  completions/parallelism/backoff/finite terminal retention; or supervised HostProcess with
  `HostProcessCardinality` plus its replacement policy. Each kind has only its renderable fields; the CUDA Pod
  arm is structurally a DaemonSet with serial `OnDelete`, while CUDA/Metal host arms carry only their
  corresponding release/drain lifecycle. `NodeEligibilitySelector` is the canonical closed conjunction of typed
  engine-role, provider-class, site, accelerator-profile, and inventory-taint constraints; it contains no
  free-text selector or toleration. No caller may replace any arm with a scalar peak.
- The pure expansion fold: it exact-joins every constraint, derives the eligible set, expands
  Deployment/StatefulSet replicas and Job active waves, derives one DaemonSet slot for every selected fixed
  `NodeId` or bounded elastic `ProviderInstanceId`/class slot, and resolves each HostProcess host→slot map; a
  planned elastic target retains its `PerInstanceKubeletFilesystemLayout` and `Elastic { instance, disk, carve }`
  runtime-storage backing references — never an invented concrete `DiskCarveId` — and is joined to an attested
  observed `NodeId`/backing/device materialization only at live readiness. A missing constraint target or
  missing, extra, or ineligible slot rejects. Every instance id derives from and exact-joins one planned
  `(ExecutionUnitId, revision, ordinal, kind)` slot key; duplicate, orphan, wrong-revision, dropped, or swapped
  instances reject. The steady map contains every desired live service/daemon/host slot but may be empty after a
  Job-only deployment completes; empty-capable rollout maps enumerate every reachable old/new/surge step,
  including the first-deploy/recreate zero-live gap. Old rows come only from the resolved prior projection with
  their own revision and full resource envelope; unchanged rows dedup, changed rows follow the new policy, added
  rows have no old twin, and removed rows persist through apply-before-prune. The same fold's live input
  exact-joins observed surviving/terminating identities to the referenced prior generation and unions them with
  desired instances, with equal ids deduplicated once and no reclamation credit before observed deletion. Each
  epoch is provisioned over the full resource vector, then the componentwise peak is selected; a CPU-only or
  steady-only multiplier is not a witness.
- The pure scheduler model seals prior+desired, controller-child-indexed candidate templates and one aggregate
  root-ledger transaction: static/bootstrap, foreign, resident, all active entries, and the candidate re-fold
  together. Additive CPU/memory/logical-ephemeral/Pod-CNI rows are Pod-qualified; CSI attachments union by
  `(node, driver, VolumeIdentity)`; OCI/snapshot identities union once per physical allocation domain; pull
  workspace is the policy top-n; distinct CUDA owners cannot share a device. Because terminating population is
  not a trustworthy author scalar, the fold derives `ProvisionedExecutionSchedulingGuard` quota, source/revision
  admission, and the exact scheduler-reservation projection. A ledger row whose Pod has disappeared selects the
  exact full or retained `LedgerOnlyAbsentRecovery` debit until state-specific release/cleanup CAS; changed
  observed/root/config/capacity state invalidates the token. The live same-binary role (implemented in
  [phase_59_capacity_scheduler.md](phase_59_capacity_scheduler.md)) performs Reserved→BindingInFlight→Bound
  around Kubernetes Binding, keeping unknown outcomes charged; Ordinary/CUDA/Job release partitions credit only
  separately observed axes, and physical artifacts stay in the root resident baseline until deletion/GC.
- A private `ControllerChildEnvelope` remains the descriptor/source-expansion explanation: its children lower to
  these same kind-indexed units and epochs, and its witness must exact-join them but is never a second resource
  debit.

### Validation

1. Generated kind-indexed execution-unit cases independently exact-fit and miss by one on each full
   steady/rollout/live epoch; the suite rejects a copied-new-as-old envelope, dropped
   removed/desired/surge/old/terminating instance, invented first-deploy predecessor, implicit-latest lookup, any
   broken prior/desired source-unit/revision/ordinal/resource join, any omitted reachable empty epoch, and any
   internal attempt to construct rolling `{ maxSurge = 0, maxUnavailable = 0 }`; both legal one-sided rolling
   controls reach epoch construction. A terminating-old-at-capacity case proves the derived scheduler guard
   leaves a replacement Pending until observed disappearance, and a post-validation terminating-set change
   invalidates the token. Reservation-algebra controls prove same-node/same-digest content unions once,
   two-node/same-digest content debits twice, equal bootstrap/workload image extents share once, distinct
   Pod-UID components add, same-PVC CSI dedups while different PVCs add, conflicting extent
   bytes/backing/model reject, device-owner intersection rejects, and terminal one-slot partition releases
   exactly one slot while retaining zero-slot physical bytes. `mutant_copy_new_execution_as_old`,
   `mutant_drop_removed_execution`, `mutant_invent_first_deploy_old`, `mutant_resolve_latest_execution`,
   `mutant_drop_execution_replica`, `mutant_drop_execution_surge`, and `mutant_drop_execution_old_revision` each
   turn the suite red, as do a non-aggregate/per-record CAS, timeout-based reservation release,
   crash/lost-response release from `BindingInFlight`, direct-nodeName/post-bind-delta bypass, and a second
   controller-child debit.
2. Every normalized controller policy is proved kind-valid before epoch construction, so the suite covers
   DaemonSet's exclusive Surge/Unavailable arms, the native serial `StatefulSetRolloutPolicy`, finite Job
   waves with terminal retention, and supervised host replacement beside the two legal Deployment one-sided
   pairs `{ 1, 0 }` and `{ 0, 1 }`; every zero-progress and every wrong-kind policy field turns it red. An
   update resolves the exact prior steady inventory from `ProvisionContext` before the suite expands the
   desired units, so added, new, changed, and removed semantics are each observed, every prior and desired
   materialized instance exact-joins its own source unit, revision, ordinal, and full resource envelope, and
   the reachable empty initial and recreate transition maps are exercised rather than skipped. The same epoch
   provisioner runs over controller-derived child units, where a second child debit or a free validating
   webhook turns the suite red.
3. The reservation algebra runs over that same expansion. Two concurrent candidates that each read the
   identical pre-reservation residual turn a property red, as does any orphan-drop of a ledger row whose Pod
   has disappeared: its Reserved, BindingInFlight, Bound, Terminating, or TerminalRetained state selects the
   exact full or retained `LedgerOnlyAbsentRecovery` debit instead.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 29.2: kubelet/CRI runtime-metadata + node-local OCI content/snapshot/image + physical-disk parent accounting ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`resource_capacity_doctrine.md §4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and the capacity-accounting technique of
[`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked):
derive per-Pod kubelet/CRI runtime-metadata components and node-local OCI content/snapshot/image demand from Pod
structure, route them through `KubeletNodefs | CriRuntimeRoot` and the selected
`Unified | SplitRuntime | SplitImage` layout, group aliased physical-carve debits once, and prove the two
`PhysicalDiskPartition` parent equations — all as pure, checked `provision-seal` operations invoked by Phase 31's
`provision` seal.

### Deliverables

- Each `NodeCapacity.localStorage` carries logical pod-ephemeral allocatable separately from physical
  `KubeletFilesystemLayout`, a pinned `NodeImageStorageModelVersion`, a pinned
  `kubeletMetadataModel : KubeletRuntimeMetadataModelVersion`, and enforced `Serial | BoundedParallel n` pull
  policy. Each platform-selected `ImageArtifact` exactly joins its OCI index, child manifest, config, and
  compressed layers by digest/stored bytes and its snapshot chain by id/unpacked bytes. Per node, the fold
  unions persistent content by object digest and snapshots by chain id, applies the pinned snapshotter
  metadata/active-snapshot model, and adds the largest `n` missing-image pull/import workspaces. Every Pod
  `ResourceEnvelope` carries a byte-free `PodRuntimeMetadataSource` containing its exact non-empty
  network-attachment ids and container→volume mount references. After execution-instance expansion, the fold
  combines that source with the Pod's container/volume inventories to derive one `KubeletRuntimeMetadataShape`;
  planned accounting wraps it with `PlannedExecutionSlotId`, live accounting with authenticated `PodUid` plus
  `ObservedExecutionSourceWitness`. Planned capacity identities are never reused as live Pod identities.
- The private `ProvisionedKubeletRuntimeMetadataDemand` applies that model to derive a non-empty component map,
  assigns every component exactly one `PodRuntimeRole`, proves the per-role sums, resolves each role through the
  selected layout, and proves the grouped physical-carve debits. Aliased roles are summed before their backing
  is checked once; they are never repeated as logical Pod ephemeral storage. For every planned epoch fingerprint,
  the fold builds one `ProvisionedNodeRuntimeStorageAccounting` per node; the same fold, invoked by
  snapshot-bound live preflight, builds the observed-inventory-fingerprint form. Its exact accounting-id domain
  equals the assigned planned slots or eligible observed Pod UIDs; its qualified `(accounting id, component id)`
  keys are disjoint from and exhaustive with the node image-model component keys; and its final backing map
  groups the combined metadata and `ProvisionedNodeImageStorageDemand` by physical carve exactly once. A
  component hole, overlap, role swap, scope/domain mismatch, or alias double debit has no provisioned
  representation. `PendingUnscheduled` is API-only and creates no node row; `Reserved` and an unbound/unknown
  `BindingInFlight` spend the planned placed vector; a confirmed Bound Pod whose ledger still says
  `BindingInFlight` enters the typed `BindingRecovery` arm and instantiates an observed-UID row immediately, as
  do `Bound`/`Terminating` and terminal-retained axes. A bound UID exact-joins its reservation so the same
  components are never debited as both planned and observed.
- Logical pod ephemeral always proves disk `emptyDir` + logs + writable layers + mapped files within the
  rendered pod/node values. Physical operands are then grouped exactly once by layout: `Unified` routes all
  Pod/image/snapshot/workspace bytes to nodefs; `SplitRuntime` routes disk volumes/logs/mapped files to nodefs
  and writable layers/images/snapshots/workspace to imagefs/containerfs; `SplitImage` routes complete logical
  Pod ephemeral to nodefs/containerfs and image content/snapshots/workspace to imagefs. Only aliases forced by
  the arm are legal, nodefs/imagefs swaps reject, and v1 containerd cannot construct the `SplitImage` support
  witness.
- The physical-disk parent accounting: raw `VmDiskCarve` has
  `{ id, presentation : FilesystemPresentation, allocation, guestSystem, kubelet }` and no editable aggregate
  bytes; `Block` cannot represent a guest root. On Lima/WSL2 the fold derives required usable bytes from guest OS
  reserve plus the unique layout-routed kubelet filesystem peaks, applies presentation overhead and allocation
  minimum/quantum, constructs private `ProvisionedVmDiskCarve`, and charges its provisioned high-water once
  beside retained/native-cache/role-tagged-host-storage pools to the physical disk. A `PhysicalDiskPartition`
  exposes `allocatableRawBytes`, the finite raw physical boundary after unmanaged-host reserve but before every
  amoebius child carve, including `systemReserve`. A parent-indexed `NamedDiskCarve PhysicalRawExtent` either
  supplies exact raw `parentBytes` or presented usable intent whose presentation/allocation geometry privately
  derives `ProvisionedNamedDiskCarve.parentDebitBytes`; a `NamedDiskCarve VmGuestUsableExtent` debits only the
  usable-byte budget inside its already provisioned VM. The fold therefore proves two separate equations:
  `guest OS/system parent debit + Σ unique layout usable parent debits ≤ requiredUsableBytes` for each VM, then
  `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique direct-node/retained/cache/host-storage
  raw parent debits ≤ allocatableRawBytes` for the physical partition. The parent index prevents either unit
  entering the other sum; each identity is charged once; `systemReserve` is not subtracted to manufacture the
  boundary and is not repeated in the child sum; and two aliases of one carve cannot spend it twice. Physical
  backing/carve ids are unique, every node/backing reference resolves exactly once, every logical
  `BackingId`/`CacheBackingId`/`HostStorageBackingId` maps injectively to the correct role carve, and an
  alias/orphan/role mismatch rejects.
- The declarations these two folds exchange live beside them rather than in the Phase-9 base
  `src/Amoebius/Capacity/Types.hs`. `src/Amoebius/Capacity/NodeLocalStorage.hs` owns the logical
  pod-ephemeral fold, the derived mapped-file/AtomicWriter demand, the closed layout routing, the exact OCI
  content/snapshot joins, and the model-versioned image peak;
  `src/Amoebius/Capacity/RuntimeStorage.hs` derives metadata components from the structural Pod graph, groups
  them by `KubeletNodefs | CriRuntimeRoot`, resolves role→layout-backing totally, builds the planned-epoch
  and observed-snapshot node aggregates, qualifies Pod/image component ownership, and groups aliased
  backings. `Types.hs` gains only the shared vocabulary: `KubeletMappedFileDemand`,
  `PodRuntimeMetadataSource`, `KubeletRuntimeMetadataShape`, the planned-slot/observed-Pod-UID
  `KubeletRuntimeMetadataDemand`, `ProvisionedKubeletRuntimeMetadataDemand`, `PodRuntimeRole`,
  `ImageStorageRole`, `NodeImageStorageModelVersion`, `KubeletRuntimeMetadataModelVersion`,
  `ProvisionedNodeImageStorageDemand`, the scope-indexed `ProvisionedNodeRuntimeStorageAccounting`,
  `NodeLocalStorageCapacity` with its filesystem layouts and image artifacts, `PhysicalDiskPartition`,
  `NamedDiskCarve`, and `ProvisionedVmDiskCarve`.

### Validation

1. Runtime-metadata cases exact-fit every grouped backing, fail with SplitRuntime nodefs one byte short for a
   kubelet component or imagefs/containerfs one byte short for a CRI component, and reject a missing/mismatched
   model, a dropped/swapped role, a planned/observed domain mismatch, a Pod/image ownership hole/overlap, an
   alias double debit, or a fold that omits the largest simultaneous epoch's metadata; `Unified` and `SplitImage`
   alias controls accept only when the grouped carve is charged once. The node-local fold returns its specific
   structured rejection for a missing OCI content/snapshot/model join, a physical overrun, a forbidden alias, a
   swapped layout, or unsupported `SplitImage`. A partition case satisfies
   `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ==
   allocatableRawBytes` while each VM separately exact-fits its nested usable-byte equation; either parent's
   one-byte-short pair rejects, and the no-double-debit property catches an alias, VM high-water, or
   `systemReserve` charged twice.
2. The reference side is built without the fold under test. For every planned Pod slot in each epoch it
   rebuilds `KubeletRuntimeMetadataShape` from the structural sandbox, Pod-directory, runtime, CNI, volume,
   and mount counts under `NodeCapacity.localStorage.kubeletMetadataModel`, and its live variant rebuilds the
   same shape from authenticated Pod UIDs and source witnesses. It resolves every component's role through
   the selected layout — `Unified` resolving both roles to nodefs, `SplitRuntime` resolving kubelet-owned
   components to nodefs and CRI-owned components to imagefs/containerfs, and `SplitImage` resolving both
   Pod-runtime roles to nodefs/containerfs — and starts each `PhysicalDiskPartition` from
   `allocatableRawBytes` after the unmanaged-host reserve, deriving every presented usable physical carve to
   a raw `parentDebitBytes` before it compares. `mutant_drop_largest_kubelet_metadata`,
   `mutant_missing_kubelet_metadata_model`, `mutant_partition_mixes_vm_usable_bytes`,
   `mutant_partition_drops_system_reserve`, and `mutant_partition_double_debits_child` each turn it red, as
   do a role drop or swap, a backing swap, a scope/domain mismatch, an ownership hole or overlap, and an
   alias double debit.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 29.3: Accelerator residency/net-allocatable-VRAM + provider-root disk template + engine/build/etcd/monitoring compute ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`resource_capacity_doctrine.md §4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and the capacity-accounting technique of
[`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked):
implement the accelerator residency/net-allocatable-VRAM fold, the provider-root
`ProvisionedPerInstanceDiskTemplate` VM/root-EBS arithmetic, and the host `BuildExecutionEnvelope` /
`EngineSystemReserve` / `EtcdLogicalDemand` / `MonitoringWorkBudget` / `PulumiExecutionDemand` compute
derivations as pure, checked `provision-seal` operations that feed the composed resource vector.

### Deliverables

- Closed pod/host accelerator demand and offering types, and the accelerator residency placement: the returned
  witness proves exact whole accelerator devices, identity-complete residency demand, every policy-permitted
  coexistence epoch's per-device assignment/aggregate, explicit shard-byte assignment, and required peer/NVLink
  graph. Each derived epoch fits against per-device **net allocatable VRAM** (raw minus the mandatory
  `driverRuntimeReserve`, so `driverRuntimeReserve + allocatableVram ≤ rawVram`) plus freshly observed free
  memory. Wholesale accelerator ownership remains, but its one linux-cuda owner pod's exactly-once named owner
  container still receives a derived extended-resource allocation while the pod receives the required affinity;
  different Pod owners cannot share the device. The accelerator capability arm treats `None` as neither CUDA nor
  Metal, and a host Metal demand must exact-join a compatible offering profile.
- The provider-root arithmetic: provider root policies require `FilesystemPresentation`; fixed `InstanceStore`
  bytes must cover system reserve plus all unique carves after presentation costs, while `EphemeralRootEbs`
  derives private
  `ProvisionedNodeRootVolumeRequest { volumeType, requiredUsableBytes, presentation, allocation, sizeGiB,
  provisionedBytes, witness }` from the same high-water and its catalog-cross-checked volume
  type/presentation/allocation rules; it debits `nodeRootStorage`, never durable quota. The private
  `ProvisionedPerInstanceDiskTemplate` derives `mountedUsableBytes` through the pinned filesystem presentation
  from either `InstanceStore.provisionedRawBytes` or the privately derived, presentation/quantum-rounded
  ephemeral-root-EBS request before proving
  `systemReserve.requiredUsableBytes + Σ unique carves.requiredUsableBytes ≤ mountedUsableBytes`; both root arms
  preserve presentation. Generated symbolic identity is qualified by `ClusterId/ClassId/coverSlot/full template
  path`, never a class-local label alone; a two-instance cover from one candidate template produces two disjoint
  concrete disk/carve/device identity sets.
- `BuildExecutionEnvelope` with a closed acyclic per-platform stage graph, per-stage host/engine-VM CPU/memory
  reservation+ceiling, intermediate and cache-write peaks, named `BuildScratch`/cache backings, and separate
  finite architecture/stage concurrency; observed cache residents plus the derived concurrent write delta fit the
  cache budget/backing. `EngineSystemReserve` is the exact role-indexed non-empty named static-process CPU/memory
  set plus a `ControlPlane | Worker` storage demand; kind expands every ordinal node-container and every rke2
  server/agent proves its own reserve. `EtcdLogicalDemand` first exact-joins serialized desired/live
  old/new/apply Kubernetes objects plus bounded revision/Lease/Event churn and proves the derived MVCC peak fits
  `backendQuotaBytes`; its separate physical formula consumes enforceable
  `etcd { backendQuotaBytes, maxWalFiles, retainedSnapshots, SerializedSnapshotAndDefrag, storageModel }` and
  derives backend + WAL segment/overshoot/preallocated-next + retained snapshot/snapshot-save temporary +
  serialized defrag old/new peak (Events included once), plus `(maxBackups + 1) × maxBytesPerFile` audit/runtime
  logs. A missing process/headroom field is not a zero.
- `MonitoringWorkBudget` with finite workflow/rule/series/sample-rate/interval/CPU/memory/retention, structural
  query concurrency/series/samples/range/timeout bounds, claim/backing/presentation, and pure version-indexed
  evaluation/TSDB/query cost primitives; derived Prometheus compute and presentation-rounded volume demand
  cannot bypass `place`/storage provisioning. `PulumiExecutionDemand` derives the deploy/plugin join and the
  concurrent executor/workspace peak as an executor envelope; its checkpoint storage remains the Phase-28
  object-store arm.

### Validation

1. A CUDA-family-absent topology, a device-count shortage, an `Unsharded` residency that fits no device, a
   `ReplicatedPerDevice` residency not chargeable on every owner device, an explicit shard/per-device epoch
   assignment that does not fit, a demand fitting raw `memory.total` but exceeding `allocatableVram` after the
   mandatory reserve, a host Metal profile with no compatible offering, and two cluster budgets claiming one
   physical device id each return the specific accelerator tag. An under-sized instance-store root, a
   root-EBS request outside its separate byte/volume-count quota, a raw authored VM/root-EBS aggregate, a skipped
   presentation/allocation rounding, and a root EBS debited from durable quota each reject; the two-instance
   cover produces disjoint concrete identity sets. Every host-only compute term (a build stage,
   scratch/cache-write/concurrency term, an observed cache resident, an engine-process map entry, a WAL
   preallocation/overshoot/snapshot-save/defrag operand, a control-plane/worker storage/retention term, a
   monitoring evaluation+query/proxy compute or TSDB presentation derivation, or a Pulumi
   deploy/plugin/concurrency executor envelope) is individually required: dropping it turns a property red.
2. The reference side is derived without the folds under test. It checks accelerator family, whole device
   count, exact source/workload and policy-class domains, every derived coexistence epoch, residency
   placement, per-device aggregation, shard-id uniqueness/count/byte-sum, and the required interconnect
   against each device's net allocatable VRAM after the mandatory `driverRuntimeReserve` rather than its raw
   total, so a single unshardable 40-GiB model on 2×24-GiB devices is rejected. For every
   `PhysicalDiskPartition` and provider node it recomputes the post-unmanaged-host `allocatableRawBytes`
   boundary, rederives the raw VM and ephemeral-root-EBS usable and provisioned high-water through the
   presentation and allocation rules, checks an instance store against its fixed bytes, and charges root-EBS
   bytes plus volume count only to `nodeRootStorage`. Generated host-only cases derive the per-stage build
   concurrency/scratch/cache-write peak, the role-indexed named engine-process totals, the rotated
   control-plane/worker storage and history fit, the monitoring CPU/memory cost, and the Pulumi
   deploy/plugin/concurrent-executor/workspace peak the same way.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 29.4: The composed full-resource-vector place-witness — properties + independent validator + per-axis mutants ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) (Register 1) and the honesty
limit of [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
express the composed full-resource-vector `place` witness as QuickCheck properties. For the checks that are
decidable in **both** directions on this seam — runtime-metadata role grouping, execution-epoch source-unit
equality, and provider-root arithmetic — assert `accepts ⟺ in-envelope` equivalence against a committed
hand-authored reference. Reserve **soundness-only** (the witness never admits an over-committed spec, but `place`
may reject a packable one) for the composed compute `place`, and never claim completeness there.

### Deliverables

- The **implementation-independent composed witness validator** (§M.3): a reference predicate that reads the
  generated fixture's declared allocatables directly and **never calls `podFits` or `place`**.
  - For every node in the returned `Placement` it recomputes effective
    app/sidecar/ordinary-init/restartable-init-sidecar requests and limits under the pinned Kubernetes
    semantics plus pod overhead;
    - asserts **Σ requests ≤ allocatable** for CPU/memory/ephemeral storage;
    - asserts **Σ effective CPU limits ≤ the node's finite policy-derived CPU-limit budget** and **Σ effective memory/ephemeral limits ≤ allocatable**;
    - validates durable/native-cache pool identity and residual bytes (deferring the durable geometry itself
      to the Phase-28 reference);
    - resolves the whole-deployment `FirstDeployment | UpdateFrom` source to an exact empty or digest-keyed
      prior steady map, then independently expands every desired `BoundExecutionUnit` by `revision` plus its
      kind-indexed controller body and rederives exact prior and desired `(sourceUnit, revision, ordinal,
      resource) → MaterializedExecutionInstance` equality over steady, empty-capable rollout, and
      normalized-live epochs;
    - derives the quota/admission/CAS-before-Binding scheduler guard;
    - lowers every private `ControllerChildEnvelope` to that same mechanism and places child Pod/PVC demands
      plus validating-webhook execution exactly once;
    - independently rebuilds `KubeletRuntimeMetadataShape` per planned slot or authenticated observed Pod
      UID, derives component→Pod-runtime-role maps, resolves roles through the selected layout, exact-joins
      the planned/observed node domain, combines qualified Pod components with the disjoint image-model
      component domain, and groups each physical carve once;
    - validates accelerator family, whole device count, exact source/workload and policy-class domains, all
      derived coexistence epochs, residency placement, per-device aggregation, shard-id
      uniqueness/count/byte-sum, and required interconnect against each device's net allocatable VRAM;
    - resolves the correct OCI index and platform child manifest/config/compressed layers for each assigned
      node OS/arch, exact-joins snapshot chain/unpacked costs, unions content by digest and snapshots by
      chain id, applies the pinned model, adds the largest `n` new-image workspaces, and routes logical pod
      + image operands under `Unified | SplitRuntime | SplitImage`;
    - For every `PhysicalDiskPartition`/provider node recomputes the post-unmanaged-host
      `allocatableRawBytes` boundary, derives every presented carve's private raw parent debit, proves
      `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ≤
      allocatableRawBytes` with no cross-unit or duplicate identity debit, separately exact-fits each VM's
      nested usable equation, and charges root EBS bytes plus volume count only to `nodeRootStorage`.
  - Thus two 3-CPU pods on one 4-CPU node, a disk-cache overflow, or one unshardable 40-GiB model on
    2×24-GiB devices is rejected independently of `place`. `place` may return `Left` on a packable spec but
    never a witness the independent validator rejects (the one-directional soundness caveat).
- Composed-placement properties: a feasible whole-deployment input yields a witness the validator accepts or a
  sound growth envelope; an over-committed one returns `Left Overcommit`/`Left Unschedulable`/the specific
  execution/accelerator/provider-root tag naming the offending axis. Generated execution cases exact-fit the
  largest epoch on every resource with a minimally differing one-unit-short case; runtime-metadata cases exact-fit
  SplitRuntime nodefs and imagefs/containerfs independently; accelerator cases exact-fit each coexistence epoch
  against net allocatable VRAM; provider-root cases exact-fit both parent equations.
- The per-axis/per-capability seeded-mutant battery: **one seeded mutant per resource/capability axis** — drop
  CPU-limit-policy or finite-limit/physical-peak fit; kind-indexed execution controller/rollout/live-epoch
  expansion and source/revision/ordinal equality; controller child lowering/source witness/single debit;
  runtime-metadata shape/component/role derivation, planned-slot/observed-Pod-UID domain equality,
  role→layout-backing resolution, qualified Pod/image ownership, and alias-aware node backing grouping;
  node-local mapped-file/OCI-object/snapshot/model/layout accounting; etcd logical API-object/churn quota fit and
  root-filesystem arm projection; accelerator family/count, source/workload/policy-domain equality, complete
  coexistence-epoch derivation, residency/per-device aggregation, shard/link topology, the
  raw→reserve→allocatable boundary; the physical-partition post-unmanaged-reserve→`allocatableRawBytes`
  boundary, parent-unit separation, and unique-child debit; any candidate-template
  uniqueness/reference/layout/root-backing/root-quota arithmetic check; the Pulumi deploy/plugin/concurrency
  executor envelope; and each eligibility clause (affinity, and the DaemonSet selector expansion) — each
  individually required to turn the suite red (§M.2), plus the host-only compute mutants of Sprint 29.3.
- A totality guard discharged **both ways**: (a) a compile-time exhaustiveness gate — every
  execution/accelerator/provider-root fold module compiles under `-Werror=incomplete-patterns` /
  `-Werror=incomplete-uni-patterns` with no `error` and no partial `head`/`fromJust`; **and** (b) the sampled
  QuickCheck run in which every property generator exercises the fold on arbitrary constructible inputs and no
  input yields an exception, `error`, or partial match. A green sample alone does not satisfy this guard.

### Validation

1. Every fold reaches its declared property-coverage floor. Re-run the complete seeded battery from
   [Gate integrity](#gate-integrity) — including the kind-indexed execution,
   scheduler-CAS, runtime-metadata, node-local, physical-partition, accelerator-residency, and
   provider-template mutants, not one hand-picked strawman — makes a property red when re-run individually. The
   validator carries the reference side of every `accepts ⟺ in-envelope` property as a **committed hand-authored predicate authored in this phase's oracle-pinning sprint, distinct from the fold under test** (§M.1, §M.3), never the
   fold's own comparison.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 29.5: The execution/accelerator/provider-root fold-negative corpus + the composed gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
and [`§3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent):
assemble the phase's single Register-1 gate — the composed folds place the whole-deployment positives feasibly
across every axis and reject each execution/accelerator/provider-root/runtime-metadata negative on its isolated
axis — and emit the per-entry validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables

- The fold-negative fixtures on this seam — `illegal_hard_ceiling_overcommit` ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)),
  whose case table separately makes only a controller webhook, object-write/query/registry gateway, Pulumi
  executor, storage/registry/schema migration executor, or ZooKeeper/Patroni child one CPU/memory/ephemeral
  unit or pod slot short, and separately makes a kind-indexed desired replica, DaemonSet-selected slot,
  surge instance, exact prior old/removed revision, or live terminating instance one unit short; other
  variants copy the new envelope into a deliberately larger/different old source, invent a predecessor under
  `FirstDeployment`, resolve the wrong/latest generation, omit the empty recreate step, or admit a
  replacement while an observed terminator holds the last provisioned unit;
  - `illegal_node_local_storage_over_backing` ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)/[§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere), logical pod ephemeral fits but the layout-routed union of OCI content, snapshots, writable layers, concurrent pull/import workspace, and model-derived per-Pod kubelet/CRI runtime metadata exceeds a physical backing; its case table drops the largest simultaneous metadata row, removes/changes the pinned model, drops/swaps a component role, mismatches planned/observed domains, overlaps or leaks qualified Pod/image ownership, double-debits an alias group, and makes either SplitRuntime nodefs or imagefs/containerfs exactly one byte short);
  - `illegal_disk_backing_alias_double_spend` ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded), duplicate backing/carve identity exposes one physical byte pool twice; its case table covers same-host duplicate-carve, cross-host duplicate-backing, the `PhysicalDiskPartition` VM-usable-for-raw substitution, an underived presented usable carve, an omitted `systemReserve`, and a child debit repeated through an alias);
  - `illegal_filesystem_layout_alias` (a split arm aliases nodefs/imagefs) and
    `illegal_filesystem_layout_swapped` (observed/declared nodefs and imagefs roles are reversed) → `Left
    FilesystemLayoutMismatch`;
  - `illegal_image_content_join_missing` (one required index/manifest/config/compressed-layer object has no
    exact catalog entry), `illegal_image_snapshot_join_missing` (one chain id has no
    unpacked/active-snapshot cost), and `illegal_image_storage_model_missing` (the pinned model has no
    supported catalog entry) → `Left ImageMetadataMissing`;
  - `illegal_split_image_unsupported` (v1 containerd cannot construct the required support witness), each
    returning its specific image/layout tag rather than an aggregate disk error;
  - `illegal_provider_instance_store_root_underprovisioned` (system reserve plus unique,
    presentation-adjusted carves exceed fixed instance-store bytes) and
    `illegal_provider_node_root_ebs_over_quota` (the privately derived, rounded root request exceeds the
    distinct root-EBS bytes or volume-count ceiling even while durable quota fits) → `Left
    ProviderNodeRootQuotaExceeded`;
  - `illegal_control_plane_storage_transition_overrun` (steady backend fits but the pinned
    max-WAL/preallocated-next, snapshot-save temporary, or serialized defrag old+new transition exceeds its
    system carve) → `Left EngineStorageOvercommit`;
  - `illegal_cuda_on_cpu_target` + `illegal_accelerator_count_shortage` ([§3.27](../documents/illegal_state/illegal_state_capacity.md#327-a-deployment-that-fits-in-aggregate-but-has-no-resource-capable-placement)/[§3.28](../documents/illegal_state/illegal_state_capacity.md#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim));
  - `illegal_accelerator_vram_fragmentation` ([§3.30](../documents/illegal_state/illegal_state_capacity.md#330-an-accelerator-memory-envelope-that-cannot-fit-the-selected-devices-or-unified-memory-pool) — aggregate residency bytes fit but one `Unsharded` residency fits no device, a `ReplicatedPerDevice` residency is not chargeable on every owner device, or an explicit shard/per-device epoch assignment does not fit);
  - `illegal_accelerator_vram_reserve_boundary` ([§3.30](../documents/illegal_state/illegal_state_capacity.md#330-an-accelerator-memory-envelope-that-cannot-fit-the-selected-devices-or-unified-memory-pool) — the demand fits raw `memory.total` but exceeds `allocatableVram` after the mandatory driver/runtime reserve);
  - `illegal_apple_metal_profile_mismatch` (host Metal demand has no compatible offering); and
    `illegal_shared_accelerator_double_owner` (two cluster budgets claim one physical device id).
  - Every case asserts its **specific** tagged `Left` and has a control that changes only the rejected axis.
  - Compile-time-foreclosed neighbours
    ([§3.14](../documents/illegal_state/illegal_state_topology.md#314-rke2kind-on-a-host-with-no-linux-node-applewindows-without-an-interposed-linux-vm)/[§3.15](../documents/illegal_state/illegal_state_topology.md#315-a-multi-node-kind-cluster-not-on-a-single-linux-host)/[§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere)/[§3.21](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)/[§3.24](../documents/illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain))
    noted as already foreclosed upstream and the base-fold/storage-geometry neighbours cross-referenced to
    [phase_09_resource_index.md](phase_09_resource_index.md) and
    [phase_28_storage_geometry_folds.md](phase_28_storage_geometry_folds.md).
- The composed positive fixtures `legal_multisubstrate_cluster` (the [§3.13](../documents/illegal_state/illegal_state_topology.md#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class) heterogeneous carve-out, exercising distinguishable `Unified` and `SplitRuntime` routing plus a presentation-adjusted VM/instance-store fit; its case table includes exact-fit physical-raw and nested-VM-usable parent equations, including `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits == allocatableRawBytes`, exact-empty `FirstDeployment`, a recreate zero-live step, an update with different old/new full execution envelopes plus added/removed units, and an exact component→role→layout-backing metadata accounting with one debit per grouped carve) and `legal_managed_eks` (EKS first-class, requiring two materialized instances from one candidate class, deriving each root-EBS request from its class-local system/carve high-water, debiting the distinct root quota, and proving instantiated backing/carve/device identities are disjoint), each asserted to decode and `place` feasibly across the whole resource vector. Their
  case tables include kind-valid Deployment, StatefulSet, DaemonSet, Job, and HostProcess bodies whose exact
  steady, rollout, and supplied live old+terminating epochs fit at equality, including distinct Deployment
  `{ maxSurge = 1, maxUnavailable = 0 }` and `{ 0, 1 }` rolling controls; these are variants of the two named
  composed positives, not additions to the exact representative set. `legal_tmpfs_two_concurrent_writers_single_debit`
  is owned by [phase_09_resource_index.md](phase_09_resource_index.md) but also places feasibly through
  the composed witness here.
- The Register-1 ledger gives each exercised entry its catalog identity, rejection layer, and `provision-seal`
  locus. It separately marks the runtime residue (VM boot, pod schedule, node join, accelerator
  device attach, S3 offload, autoscaler growth) deferred to the live band — sibling evidence where the capacity
  arithmetic generalizes prodbox's teardown push-back soundness, not an amoebius result.

### Validation

1. Rejected historical observation: the `execution-accelerator-spec` Cabal suite was recorded green — every
   one of the eighteen execution/accelerator/provider-root/runtime-metadata
   fold negatives ([Gate integrity](#gate-integrity) representative set) returns its **specific committed** tagged
   `Left`, both composed positives place feasibly across every axis, the QuickCheck battery holds at its coverage
   minima, and the committed per-fold seeded-mutant battery ([Gate integrity](#gate-integrity)) turns the suite
   red individually. Any negative that produces `Right` or the wrong tag fails the suite. The emitted ledger must
   retain an UNVERIFIED row for every effect that only a runtime observation can settle.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/resource_capacity_doctrine.md` — backlink §4's fold + §4.1 static/elastic branch to the
  implemented `Amoebius.Capacity.*` execution/accelerator/provider-root modules; confirm every
  capacity/accelerator sum stayed a checked pre-effect rejection at the post-bind `provision-seal` and
  sound-not-complete for the composed compute bin-pack.
- `documents/engineering/daemon_topology_doctrine.md` — reconcile §3's control-plane daemon reservation /
  five-kind control-plane-state producer read-side with the as-built scheduler-reservation and
  `EtcdLogicalDemand` folds; keep the live scheduler role residue deferred to
  [phase_59_capacity_scheduler.md](phase_59_capacity_scheduler.md).
- `documents/engineering/monitoring_doctrine.md` — reconcile the `MonitoringWorkBudget` compute read-side with
  the as-built fold; it remains the single owner of its number.
- `documents/engineering/substrate_doctrine.md` — reconcile the §8 node inventory / kubelet layout / accelerator
  profile / provider-root read-sides with the as-built folds; keep the runtime (VM boot, node join, device
  attach) residue deferred.
- `documents/illegal_state/illegal_state_catalog.md` — annotate the applicable §3.11/§3.17–§3.19/§3.27–§3.30
  parts with their realized checked-rejection / `provision-seal` layer (technique §4.6 → layer 2, Register-1);
  keep runtime-checked entries (layer 3) deferred.
- `documents/engineering/storage_lifecycle_doctrine.md` (§5.2 node-local backing) — reconcile the read-side with
  the as-built node-local/runtime-metadata fold; it remains the single owner of its number.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + composed-fold ledger this gate
  emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-29 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-29 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Capacity/{Scheduler,HostReservation,
  NodeLocalStorage,RuntimeStorage,ProviderRoot,Etcd,PulumiExecution}.hs`, the execution/accelerator/provider-root
  branches of `Types.hs`/`Fold.hs`, and the composed placement property + gate suites as Phase-29 design-first
  rows.
- `DEVELOPMENT_PLAN/phase_09_resource_index.md` / `DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md` —
  the base-fold and storage-geometry slices this phase composes into the full-resource-vector witness.
- `DEVELOPMENT_PLAN/phase_31_provision_seal.md` — the post-bind provision seal that re-exercises these folds.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the capacity/execution/accelerator invariants
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the `fits`/`carve`/`place`
  fold, the [§4.6](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) static/elastic branch, and the [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it) sound-not-complete honesty limit
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the execution/accelerator/
  provider-root entries and the [§4.6](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) capacity-accounting technique, with [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)/[§6](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) the load-bearing limit and honest
  layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_26](phase_26_gadt_decode_ir.md) — gadt-decode, the IR + decoder these folds decode into
- [phase_27](phase_27_illegal_state_covering.md) — the illegal-state corpus, properties, and validation-locus
  ledger this phase extends
- [phase_09_resource_index.md](phase_09_resource_index.md) — the base `fits`/`carve`/`place` fold and
  the `ComputeEngine`/`LinuxHost`/`Topology` relation this phase composes over
- [phase_28_storage_geometry_folds.md](phase_28_storage_geometry_folds.md) — the logical→physical storage
  geometry this phase composes into the full-resource vector
- [phase_30_capability_bind.md](phase_30_capability_bind.md) — the capability → provider → shape binder built
  atop these folds
- [phase_31_provision_seal.md](phase_31_provision_seal.md) — the whole-deployment provision seal that re-exercises
  these folds post-bind
- [phase_32_inference_accelerator_provision.md](phase_32_inference_accelerator_provision.md) — the
  `InferenceEngine` capability + accelerator residency/coexistence provision built atop the accelerator fold
- [phase_59_capacity_scheduler.md](phase_59_capacity_scheduler.md) — the live same-binary scheduler role that
  enacts Reserved→BindingInFlight→Bound around Kubernetes Binding
- Phase 29 execution/accelerator ledger — the human-readable
  Register-1 proof/test/assumption boundary
