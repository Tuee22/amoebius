# Phase 28: Logical→physical storage geometry folds

> **Purpose**: Build the pure logical→physical storage-geometry fold — the closed `StorageBudget`/`Growable`
> arithmetic, the BookKeeper/MinIO/registry/ZooKeeper/Patroni/Vault/etcd geometry with complete
> recovery/healing/orphan scenarios, filesystem presentation + allocation rounding, uniform StatefulSet claims,
> schema/registry-backend migration storage, the six-arm object-store producer peak, and Pulsar's two ceilings —
> as total, in-process Haskell, with Haskell laws requiring every producer's physical demand to fit its
> single-owner backing and each storage-geometry negative decode-rejects directly on its isolated axis, on
> separately authored Haskell logical-demand/backing values, before any host or backing exists; serialized
> cases, if needed, are lazy `.build/test-corpora/**` output.
> **Read this if**: phase 28 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 28.1: The `StorageBudget`/`Growable` arithmetic + logical→physical geometry fold](#sprint-281-the-storagebudgetgrowable-arithmetic--logicalphysical-geometry-fold-)
- [Sprint 28.2: The policy-only storage-scaling fold — `ProvisionedStorageScalingEnvelope` / `planStorageScaling`](#sprint-282-the-policy-only-storage-scaling-fold--provisionedstoragescalingenvelope--planstoragescaling-)
- [Sprint 28.3: QuickCheck properties — storage `accepts ⟺ in-envelope`, Pulsar two-ceiling, uniform-claim](#sprint-283-quickcheck-properties--storage-accepts--in-envelope-pulsar-two-ceiling-uniform-claim-)
- [Sprint 28.4: The storage-geometry fold-negative corpus + the gate](#sprint-284-the-storage-geometry-fold-negative-corpus--the-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 27, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** The Haskell-only target makes amoebius's *"no unbounded storage,
anywhere; every producer's physical demand fits a single-owner backing"* invariant a pure provisioning fold.
Haskell values own every case and expectation; any serialized case or mutation is generated lazily beneath
`.build/**`. The phase is limited to the **logical→physical storage-geometry fold** — the slice of the capacity model that turns a producer's declared *logical* demand into a *physical*
byte requirement against a named backing, and the closed storage-budget arithmetic over it:

- The **closed `StorageBudget` / `Growable` unions' arithmetic**: the single-owner ceiling-per-arm
  `StorageBudget` fold (no unbounded arm) and the `Growable`/`ScalingPolicy` quota-bounded escape valve (no
  bare-unbounded arm). The union *shapes* are type-foreclosed upstream (Phase 25/13); the *arithmetic* over them
  is the pure fold this phase's target must add.
- The **logical→physical geometry** for `bookKeeperPhysicalDemand` (write-quorum placement, journal/index
  reserve, and **every** failure/re-replication subset derived from its finite fault bound), `minioPhysicalDemand`
  (stripe padding, data+parity shards, metadata, healing workspace, and every per-set plus cross-set failure
  combination), the six-arm `provisionObjectStoreProducer` peak, `registryStoragePeak`,
  `provisionZooKeeperMetadataStore`, `provisionPatroniSql`, `vaultStoragePeak`, and the etcd/control-plane
  physical storage-transition expansion — each with its **complete recovery/healing/orphan** scenario product.
- **Filesystem presentation + allocation rounding**: each logical demand receives its `Block` or version-pinned
  filesystem overhead and rounds up to the backing's `BackingAllocationPolicy { minimumBytes, quantumBytes }`
  before its private `ProvisionedVolumeDemand.provisionedBytes` resolves exactly once.
- **Uniform StatefulSet claims**: `uniformStatefulSetClaims` groups each durable demand to a private member map
  plus one uniform size and `perBackingDebit[backing] = max ordinal provisioned demand × members on that backing`, so no aggregate can move spare bytes between backings. - **Schema / registry-backend migration storage**: `provisionSchemaMigration`, `provisionStorageMigration`, and `provisionRegistryBackendMigration` fit old+new+workspace/temp/WAL high-water plus the transition's executor demand before any create/copy/DDL, retaining every old/new partial commitment on failed verification. - The **six-arm object-store producer peak** (`app`/`content`/`registry`/`Pulsar-offload`/`Pulumi-checkpoint`/ `control-plane-state`): `mergeObjectStoreLogicalPeaks` enforces source↔producer inventory equality, rejects
  identity/size or admission conflicts, preserves every writer, and derives each per-writer admission witness
  and the merged `ObjectStoreAdmissionGatewayDemand`.
- The **two-ceiling Pulsar fold**: the physically expanded hot-tier ceiling (built on the `bookKeeperPhysicalDemand`
  witness) *and* the durable-total offload ceiling, so a time-only-offload or physically hot-tier-over-bookie
  topic decode-rejects.
- The **cache storage geometry**: the in-cluster cache-owner nesting
  `ProvisionedCacheDemand.derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit` (catalog assets joined by
  identity/digest, residents deduplicated by digest, the largest finitely concurrent first-miss temporary peak
  derived) versus a native host-worker cache pool (`derivedPeak ≤ CacheBudget ≤ named host cache backing`).
- The **provider-root storage geometry**: the `ProvisionedNodeRootVolumeRequest` presentation/allocation-rounded
  derivation from either fixed `InstanceStore` bytes or a private `EphemeralRootEbs` request, debiting the
  distinct `nodeRootStorage` byte/volume-count ceiling — never durable quota.
- The **`ProvisionedStorageScalingEnvelope` / `planStorageScaling`** representation and observe-then-plan fold —
  **policy only, no live mutation**: the private envelope retains the exact budget/backing, finite backing-indexed
  policy, and desired demand projection; the total `planStorageScaling` consumes a complete fingerprinted
  `ObservedStorageScalingSnapshot` and returns only
  `NoChange | AllocateWithinRetainedCarve | CreateProviderCapacity | ShrinkByVerifiedMigration`, witnessing
  current allocation, residual/quota, and old+new migration high-water.

These storage checks consume constructible values and may reject them at `provision-seal`; in the catalog
vocabulary they are **decode-foreclosed**, not type-inhabitance claims. Because the storage
`Σ ≤ backing` sum is decidable in **both** directions (unlike the sound-not-complete compute `place`), this
target contract requires the stronger **accept ⟺ in-envelope** equivalence for the geometry fold.

**What is *not* here.** The base `fits`/`carve`/`place` capacity fold, the `Topology`/`ComputeEngine`/
compatibility relation, and `mkRke2` distinctness ([Phase 9](phase_09_resource_index.md)); the
execution-epoch expansion, scheduler-reservation algebra, kubelet/CRI runtime-metadata fold, logical
pod-ephemeral/memory-backed-volume fold, accelerator residency/VRAM fold, the VM parent-disk
`PhysicalDiskPartition` two-equation arithmetic, and the **composed full-resource-vector place-witness** that
integrates these storage folds ([Phase 29](phase_29_execution_accelerator_folds.md)); the logical etcd
API-object/churn diff whose derived MVCC total this phase's control-plane physical formula *consumes* as a
declared input (owned by [Phase 29](phase_29_execution_accelerator_folds.md)); the capability → provider → shape
binder and the whole-deployment provision seal that re-exercises these folds
([Phase 30](phase_30_capability_bind.md)/[Phase 31](phase_31_provision_seal.md)); and any live snapshot
validation or mutation of a scaling transition — [Phase 58](phase_58_object_reconciler.md) owns the generic
snapshot-bound action/token/CAS plumbing, [Phase 60](phase_60_retained_storage.md) enacts the retained-carve
arms, and [Phase 79](phase_79_provider_dynamic_nodes.md) enacts the `CreateProviderCapacity` arm.

**Phase scope:** one target claim — the pure Haskell fold accepts only when a producer's physical demand fits
the single backing that owns it. No live backing is inspected.

**Substrate:** none — no host, cluster, backing, or hardware; the canonical Haskell gate owns all observations
and the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 27](phase_27_illegal_state_covering.md)
**Gate:** `pb validate phase 28`; see [Gate integrity](#gate-integrity).

<a id="n-gate-integrity-refinements"></a>

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target only — a pure Haskell geometry fold accepts only when each producer's physical demand fits its single owning backing; Haskell-owned cases and mutations generate any transient bytes beneath `.build/**`. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 28` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 27; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes logical→physical storage geometry folds causes to exist are charged to a grant that carries its ceiling and concurrency together.
- [`resource_capacity_doctrine.md` §5 — `StorageBudget`: bounded by construction, single-owner ceiling per arm](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)
  — **`StorageBudget` bounded by construction, single-owner ceiling per arm**: the target is to implement the closed
  `StorageBudget` fold (every producer's required `StorageBudgetId` resolves once to its selected backing/quota
  owner; no aggregate moves spare bytes between backings) and the logical→physical BookKeeper/MinIO placement
  plus the complete fault-scenario/orphan/uniform-claim/presentation-rounding fold as pure Haskell.
- [`resource_capacity_doctrine.md` §6 — `Growable` / `ScalingPolicy`: the quota-bounded dynamic-provisioning arm](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm)
  — **`Growable` + `ScalingPolicy`, the quota-bounded dynamic provisioning arm**: the target is to implement the
  closed `Growable`/`ScalingPolicy` escape valve (no bare-unbounded arm) and the private policy-only
  `ProvisionedStorageScalingEnvelope`, complete `ObservedStorageScalingSnapshot` input carrier, and total
  observe-then-plan `planStorageScaling`; it cannot validate or enact a live transition.
- [`resource_capacity_doctrine.md` §7 — Pulsar has two ceilings: the hot tier and the durable total](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)
  — **Pulsar has two ceilings, the hot tier and the durable total**: the target is to implement the two-ceiling
  Pulsar fold (physically expanded hot-tier fit built on the `bookKeeperPhysicalDemand` witness + durable-total
  offload fit), so a time-only or physically hot-tier-over-bookie topic decode-rejects.
- [`resource_capacity_doctrine.md` §2 — The load-bearing honesty limit: a capacity sum is a decode-foreclosed check, never type-foreclosed](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)
  — **the load-bearing honesty limit**: a storage sum is a checked rejection (**decode-foreclosed** in the
  historical layer taxonomy), never type-foreclosed; its concrete locus is the post-bind `provision-seal`. The
  union *shapes* are type-foreclosed (Phase 25/13); the *arithmetic* over them is the pure fold this phase's
  target must add.
  Because the storage `Σ ≤ backing` sum is decidable both ways, the target contract requires the stronger
  **accept ⟺ in-envelope** equivalence, not merely soundness.
- [`illegal_state_techniques.md` §4.6 — Capacity accounting — placement witness (compute) and summed demand within capacity (storage), checked](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
  — the capacity-accounting technique's **storage-checked** half (summed demand within capacity, storage
  checked), covering the storage/retention catalog entries [`illegal_state_security.md` §3.11 — An unsafe workload (no resource limits, no hardened securityContext)](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)/[`illegal_state_capacity.md` §3.17 — An over-committed deploy or workload (host / VM / cluster capacity exceeded)](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)/[`illegal_state_storage.md` §3.19 — An application consuming more storage than its backing (MinIO and Pulsar)](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar)/[`illegal_state_storage.md` §3.20 — A Pulsar topic without a bounded / tiered / retained lifecycle](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)/[`illegal_state_ml_asset.md` §3.25 — An ML asset named by arbitrary URL (or an unready / unlanded model)](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model) at the honest layer
  ([`illegal_state_techniques.md` §6 — Three layers of foreclosure (and the honesty they force)](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
  every storage **sum** is checked at `provision-seal` and never type-foreclosed, honoring the load-bearing
  limit of [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it).
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) (**Register 1** — pure/semantic-oracle, in-process, no cluster) and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) (the per-run proven/tested/assumed ledger): the register this gate reaches and
  the ledger it emits, with model↔runtime correspondence and runtime fidelity marked UNVERIFIED (owned by the
  live band — [Phase 58](phase_58_object_reconciler.md)/[Phase 60](phase_60_retained_storage.md)/
  [Phase 62](phase_62_platform_backbone.md)/[Phase 79](phase_79_provider_dynamic_nodes.md)).

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Historical sprint results.** Every earlier completion statement or result in the sprint bodies below is historical context. The material is retained
> only as a target-capability inventory and is not a current gate result.

## Sprint 28.1: The `StorageBudget`/`Growable` arithmetic + logical→physical geometry fold ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 27](phase_27_illegal_state_covering.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`resource_capacity_doctrine.md` §5 — StorageBudget bounded by construction, single-owner ceiling per arm](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)
and [`§7` — Pulsar's two ceilings, the hot tier and the durable total](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total):
implement the logical→physical storage-geometry fold as pure, checked provision-seal arithmetic — genuine
per-backing subtractions for the single-owner carves, complete fault-scenario derivation for the replicated/
erasure-coded producers, presentation/allocation rounding for every volume, and both Pulsar ceilings — reading
declared logical numbers only (the substrate backing inventory and PV sizes are owned elsewhere).

### Deliverables

- The closed `StorageBudget`/`Growable` unions (no unbounded / no bare-unbounded arm) and the aggregate backing
  fold: every producer's required `StorageBudgetId` resolves once to its selected backing/quota owner; the
  provider-object `CloudQuota` arm remains a distinct bounded object-count plus model-indexed `Logical | Billed`
  byte ceiling rather than inventing a filesystem allocation rule or accepting an implicit unit conversion. An
  in-file honesty note records that the union *shapes* are type-foreclosed (Phase 25/13) while every capacity/
  retention **sum** here is a total checked provision-seal operation.
- Every durable `DeclaredVolumeDemand` carries a `StatefulSetClaimSlot`, `BackingId`, logical bytes, a
  direct/BookKeeper/MinIO geometry owner, and a `VolumePresentation`; each volume-producing host/provider
  `StorageBacking` arm carries `allocation : BackingAllocationPolicy { minimumBytes, quantumBytes }`. The fold
  rederives geometry and filesystem overhead, rounds to backing rules, and alone constructs private
  `ProvisionedVolumeDemand.provisionedBytes`, which resolves exactly once and later renders unchanged.
- `bookKeeperPhysicalDemand` expands the required positive logical-hot/headroom fields through write-quorum
  placement, journal/index reserve, and **every** failure/re-replication subset derived from its finite fault
  bound. `minioPhysicalDemand` expands each object through stripe padding, data+parity shards, metadata, healing
  workspace, and every per-set plus cross-set failure combination derived from its finite fault bound. Each
  logical demand then receives its `Block` or version-pinned filesystem overhead and rounds up to the backing's
  allocation minimum/quantum before `uniformStatefulSetClaims` groups it to a private member map plus one
  uniform size and `perBackingDebit[backing] = max ordinal provisioned demand × members on that backing`; no aggregate can move spare bytes between backings. - `provisionObjectStoreProducer` covers the closed `app`/`content`/`registry`/`Pulsar-offload`/`Pulumi-checkpoint`/`control-plane-state` six-arm union: it retains exact physical resident ids, structural future/transient extents, per-writer admission witnesses, and complete producer-specific retention/rate/failure operands. Source↔producer inventory equality is mandatory; `mergeObjectStoreLogicalPeaks` rejects identity/size or admission conflicts and preserves every writer before `minioPhysicalDemand` runs, and derives the merged `ObjectStoreAdmissionGatewayDemand` (the gateway's compute pod-`place` witness composes downstream in [Phase 29](phase_29_execution_accelerator_folds.md)).
- `registryStoragePeak` exact-joins all selected OCI objects, deduplicates by digest, and adds structured
  bounded concurrent upload workspace plus failed-partial extents retained for the declared GC horizon; only its
  interim filesystem projection uses scalar `derivedPeak`. `vaultStoragePeak` exact-expands bounded persisted
  versions/live leases through the pinned Raft record/WAL/snapshot model and charges old+new compaction overlap,
  recovery headroom, and `(maxBackups + 1) × maxBytesPerFile` audit rotation to its named backing.
  `provisionZooKeeperMetadataStore` derives persistent/session paths, transaction logs, snapshots, and
  failure-recovery overlap per member and places every member's volume. `provisionPatroniSql` derives
  data/WAL/checkpoint/failover peaks, resolves the database `StorageBudgetId`, and derives the bounded
  SQL-mutation admission proxy from connection/transaction/WAL operands.
- The two-ceiling Pulsar fold uses the physical BookKeeper witness plus the durable-total offload target, so a
  time-only or physically hot-tier-over-bookie topic decode-rejects.
- Storage, registry-backend, and schema transitions (`provisionStorageMigration`,
  `provisionRegistryBackendMigration`, `provisionSchemaMigration`) each fit old+new+workspace/temp/WAL plus
  their transition executor demand before any create/copy/DDL; failed verification retains every old/new partial
  commitment.
- The cache storage geometry: `provisionCacheDemand` distinguishes an in-cluster cache-owner (the
  `CachePopulationDemand` joined by identity/digest, residents deduplicated by digest, the largest finitely
  concurrent first-miss temporaries deriving private `ProvisionedCacheDemand.derivedPeak`; then
  `derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`) from a native host-worker cache
  (`derivedPeak ≤ CacheBudget ≤ named host cache backing`). The in-cluster owner's `emptyDir` is already inside
  logical pod ephemeral (owned by [Phase 29](phase_29_execution_accelerator_folds.md)) and is not added again;
  this phase owns only the cache-peak derivation and the nesting inequality.
- The provider-root storage geometry: `provisionNodeRootVolume` requires `FilesystemPresentation` on every root
  policy; a fixed `InstanceStore` must cover system reserve plus all unique carves after presentation costs,
  while `EphemeralRootEbs` derives private
  `ProvisionedNodeRootVolumeRequest { volumeType, requiredUsableBytes, presentation, allocation, sizeGiB,
  provisionedBytes, witness }` from the same high-water and its catalog-cross-checked volume type/presentation/
  allocation rules; it debits the distinct `nodeRootStorage` byte/volume-count ceiling, never durable quota.
- The etcd/control-plane physical storage-transition peak: `provisionControlPlaneStorage` consumes the
  enforceable `etcd { backendQuotaBytes, maxWalFiles, retainedSnapshots, SerializedSnapshotAndDefrag,
  storageModel }` plus the declared MVCC logical total (derived upstream in
  [Phase 29](phase_29_execution_accelerator_folds.md)) and derives backend + WAL segment/overshoot/
  preallocated-next + retained snapshot/snapshot-save temporary + serialized defrag old/new peak (Events
  included once), plus `(maxBackups + 1) × maxBytesPerFile` audit/runtime logs; a missing headroom field is not
  a zero.

The five modules and the declarations each owns:

```
Storage.hs          identity-named disjoint local pools; the closed StorageBudget fold; native
                    host-worker cache-pool accounting; the two-ceiling Pulsar fold
StorageGeometry.hs  bookKeeperPhysicalDemand, contentStoreLogicalPeak, minioPhysicalDemand, volume
                    presentation/allocation rounding, uniformStatefulSetClaims,
                    provisionObjectStoreProducer, mergeObjectStoreLogicalPeaks,
                    provisionStorageMigration, provisionSchemaMigration,
                    provisionRegistryBackendMigration, provisionNodeRootVolume
ServiceStorage.hs   provisionCacheDemand (the exact cache nesting), registryStoragePeak,
                    provisionZooKeeperMetadataStore, provisionPatroniSql, vaultStoragePeak,
                    provisionControlPlaneStorage (the etcd/control-plane transition peak)
Growable.hs         Growable, ScalingPolicy
Types.hs (extended) StorageBudget, Growable, the durable-geometry DeclaredVolumeDemand fields,
                    StatefulSetClaimSlot, VolumePresentation, ProvisionedVolumeDemand,
                    CachePopulationDemand / ProvisionedCacheDemand, RegistryStorageDemand,
                    VaultStorageDemand, ZooKeeperMetadataStoreDemand /
                    ProvisionedZooKeeperMetadataStoreDemand, PatroniSqlDemand /
                    ProvisionedPatroniSql, ObjectStoreDemand, the six-arm
                    ObjectStoreProducerDemand / ProvisionedObjectStoreLogicalPeak,
                    ObjectStoreAdmissionGatewayDemand, StorageMigrationDemand /
                    ProvisionedStorageMigration, SchemaMigrationDemand /
                    ProvisionedSchemaMigration, RegistryBackendMigrationDemand /
                    ProvisionedRegistryBackendMigration, ControlPlaneStorageDemand, the
                    provider-root ProvisionedNodeRootVolumeRequest / InstanceStore /
                    EphemeralRootEbs / nodeRootStorage, and the storage-presentation
                    FilesystemPresentation / BackingAllocationPolicy / StorageBacking
```

Shared declarations live beside their owning folds rather than enlarging the Phase-9 base `Types.hs` module.
[Phase 9](phase_09_resource_index.md)'s base subset defers every storage member of `Types.hs` to this
phase; this sprint consumes that base and owns the storage declarations plus the geometry arithmetic.

### Validation

1. A feasible input yields a physical demand that fits its single-owner backing after deriving BookKeeper
   replication/recovery, MinIO erasure/healing/in-flight/orphan/presentation/rounding/uniform-claim peaks,
   registry upload/partial/rehome exposure, ZooKeeper log/snapshot/recovery, Patroni data/WAL/failover, schema
   old+new/temp/WAL, and Vault Raft/compaction/recovery/audit peaks. An over-backing or un-tiered topic returns
   its tagged `Left`; a cache over its named pool, an in-cluster cache nesting violation, an under-sized
   instance-store root, a root-EBS request outside its separate byte/volume-count quota, and a control-plane
   transition overrun each return their specific tag naming the offending backing/axis. Exact fit consumes the
   available residual exactly; attempting another debit then rejects without any exception. Each negative
   asserts **which tag and which axis** it fails on (§M.8), each paired with a store-fits row differing only in
   that one axis being in-backing.
2. Each producer's logical demand expands through its complete
   replication/erasure/metadata/recovery/healing/concurrent/orphan scenario product, receives its `Block` or
   version-pinned filesystem overhead, rounds up to the backing minimum/quantum, and resolves its
   `ProvisionedVolumeDemand.provisionedBytes` exactly once before the fit is judged; dropping any scenario,
   overhead, or rounding term makes the property red.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 28.2: The policy-only storage-scaling fold — `ProvisionedStorageScalingEnvelope` / `planStorageScaling` ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 28.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`resource_capacity_doctrine.md` §6 — Growable + ScalingPolicy, the quota-bounded dynamic provisioning arm](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm):
implement the policy-only `ProvisionedStorageScalingEnvelope` representation and the total observe-then-plan
`planStorageScaling` fold, so a scaling *decision* is a pure function of the retained envelope and a complete
observed snapshot — never a live mutation, and never a check that requires a live backing.

### Deliverables

- A private `ProvisionedStorageScalingEnvelope` retaining the exact budget/backing, finite backing-indexed
  policy, and desired provisioned demand projection, but no observation or speculative transition.
- A complete `ObservedStorageScalingSnapshot` input carrier fingerprinting current allocation, residual/quota,
  and any old+new migration state.
- The total `planStorageScaling :: ProvisionedStorageScalingEnvelope -> ObservedStorageScalingSnapshot ->
  StorageScalingPlan`, returning only `NoChange | AllocateWithinRetainedCarve | CreateProviderCapacity |
  ShrinkByVerifiedMigration`, with current allocation, residual/quota, and old+new migration high-water
  witnessed on every non-`NoChange` arm.
- An in-file honesty note: Phase 28 has no mutation capability; the generic live action must later be validated by
  [Phase 58 (the object reconciler)](phase_58_object_reconciler.md), the retained
  `AllocateWithinRetainedCarve`/`ShrinkByVerifiedMigration` arms are enacted by
  [Phase 60 (retained storage)](phase_60_retained_storage.md), and `CreateProviderCapacity` by
  [Phase 79 (provider dynamic nodes)](phase_79_provider_dynamic_nodes.md).

### Validation

1. Each generated envelope+snapshot pair resolves to exactly one arm; the arm's witness (retained carve,
   residual quota, or old+new migration high-water) is present and derived from the snapshot, not authored; a
   mutant that emits `AllocateWithinRetainedCarve`/`CreateProviderCapacity`/`ShrinkByVerifiedMigration` without
   its witness, or that ignores the snapshot fingerprint, turns the property red. No arm mutates or requires a
   live backing.
2. The suite constructs a private `ProvisionedStorageScalingEnvelope` for each `Growable` producer, feeds it
   a complete fingerprinted `ObservedStorageScalingSnapshot`, and asserts `planStorageScaling` returns
   exactly one of `NoChange | AllocateWithinRetainedCarve | CreateProviderCapacity |
   ShrinkByVerifiedMigration` with current allocation, residual/quota, and old+new migration high-water
   witnessed.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 28.3: QuickCheck properties — storage `accepts ⟺ in-envelope`, Pulsar two-ceiling, uniform-claim ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 28.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) (Register 1)
and the honesty limit of [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
express the storage-geometry fold as QuickCheck properties. Because the storage `Σ ≤ backing` sum is decidable
in **both** directions, assert the stronger **accept ⟺ in-envelope equivalence** (the fold accepts *exactly* the
in-backing inputs) over generated corpora, not merely soundness — the storage sum is not the sound-not-complete
compute `place`.

### Deliverables

- The **implementation-independent storage-envelope reference predicate** (§M.3): a separately authored Haskell
  envelope predicate authored in this phase's oracle-pinning sprint, distinct from the fold under test, that **never calls**
  `bookKeeperPhysicalDemand`, `minioPhysicalDemand`, `provisionObjectStoreProducer`, `mergeObjectStoreLogicalPeaks`,
  `registryStoragePeak`, `vaultStoragePeak`, `provisionZooKeeperMetadataStore`, `provisionPatroniSql`,
  `uniformStatefulSetClaims`, the Pulsar/cache/provider-root/control-plane folds, or the migration folds. It
  reads the generated fixture's declared logical demands and backing rules directly and independently derives:
  the complete fault-policy scenario product; replication/erasure/metadata/recovery/healing/concurrent/orphan
  peaks; presentation overhead; allocation minimum/quantum rounding; registry upload/partials/rehome; ZooKeeper
  and Patroni recovery; schema/storage/registry-backend transition old+new+workspace/temp/WAL high-water; Vault
  Raft/compaction/recovery/audit peaks; the uniform claim-template debit (`max ordinal × members` per backing);
  and asserts every resulting per-backing value is within capacity. It further asserts: provider-root
  construction accepts **iff** the derived VM/root usable and rounded provisioned high-water fits its fixed
  `InstanceStore` provision **or** the separate `nodeRootStorage` byte/volume-count quota; the Pulsar two-ceiling
  fold accepts **iff** both the physically expanded hot tier and the durable-total ceiling hold; the in-cluster
  cache accepts **iff** `derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit` and the native cache **iff**
  `derivedPeak ≤ CacheBudget ≤ named host cache backing`; and the control-plane transition accepts **iff** the
  derived backend + WAL + snapshot-save + defrag old+new + audit peak fits its system carve.
- Equivalence (both-directions) properties for the complete checks: the storage/retention fold accepts **iff**
  the independent predicate derives the complete fault-policy scenario product and every resulting per-backing
  value is within capacity; each over generated corpora that reach both directions, not just a fixed fixture
  set. Each equivalence property carries QuickCheck `cover`/`checkCoverage` obligations forcing **≥30% rejecting
  (out-of-backing) and ≥30% accepting (in-backing) generated inputs per fold, the suite failing when the
  coverage minimum is unmet** (§M.4) — so a generator that emits near-constant in-backing inputs cannot
  vacuously pass the reject direction.
- The reference predicate carries **one seeded mutant per geometry obligation** ([Gate integrity](#gate-integrity) §M.2), each individually required to turn the suite red: the storage-`Σ` backing comparison; BookKeeper
  quorum/recovery and complete scenario derivation; MinIO stripe/parity/healing and complete cross-set
  scenarios; concurrent/orphan horizon; filesystem overhead; backing minimum/quantum; uniform claim rounding;
  each Pulsar ceiling; native cache-pool accounting; in-cluster cache nesting/single-charge; provider-root
  under-size/omit-policy/derive-round/quota-vs-durable; control-plane WAL/snapshot/defrag/audit; source-producer
  arm omission (including the control-plane-state sixth arm); physical-object identity/size conflict;
  same-byte/different-object-count geometry; per-writer admission omission; registry object/upload/partial
  exposure; ZooKeeper member/log/snapshot/recovery; Patroni data/WAL/failover; Vault persisted/Raft/compaction/
  recovery/audit; storage/registry-backend/schema migration old+new+workspace/temp/WAL/executor; and the
  `planStorageScaling` witness/fingerprint. Two 3-object erasure sets that fit logically but overflow after
  healing workspace, one MinIO object whose parity padding rounds over its backing, and a topic whose logical
  hot bytes fit but whose write-quorum placement exceeds one bookie are each rejected independently of the fold
  under test.
- A totality guard discharged **both ways** ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) totality honesty): (a) a compile-time exhaustiveness gate —
  every `Amoebius.Capacity.{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}` module compiles
  under `-Werror=incomplete-patterns` / `-Werror=incomplete-uni-patterns` with no `error` and no partial
  `head`/`fromJust`; **and** (b) a QuickCheck sample that drives every generator through the fold and observes no
  partial match, explicit `error`, or exception. Sampling is corroborating evidence, not the totality proof.

### Validation

1. The geometry-fold `accepts ⟺ in-envelope` equivalence, presentation/rounding, uniform-claim, Pulsar
   two-ceiling, cache-nesting, provider-root, and control-plane-transition properties hold over generated
   inputs, each meeting its Haskell-declared `cover`/`checkCoverage` minimum of ≥30% rejecting (out-of-backing) and
   ≥30% accepting (in-backing) inputs per fold (§M.4).
2. **Each checked Haskell operator in the per-geometry seeded-mutant battery ([Gate integrity](#gate-integrity))
   is applied to a temporary subject beneath `.build/mutants/**` and makes a property red when re-run
   individually**. This includes the storage `Σ`, both Pulsar ceilings, uniform-claim, cache-nesting,
   provider-root, control-plane, migration, and `planStorageScaling` mutants; the properties have teeth on
   every geometry obligation, not two.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 28.4: The storage-geometry fold-negative corpus + the gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 28.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`illegal_state_catalog.md` §4.6 — capacity-accounting, storage checked](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
and [`§3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent):
assemble the phase's single Register-1 gate — the pure storage-geometry folds reject each over-backing negative
while the positive store-fits rows fit feasibly — and emit the per-entry validation-locus ledger that names the
honest foreclosure layer of each.

### Deliverables

- The fold-negative fixtures — `illegal_store_over_backing` ([§3.19](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar)),
  whose case table includes logical committed bytes fitting while erasure/healing, finite-horizon
  failed-write orphans, filesystem overhead, backing minimum/quantum, uniform-claim rounding, a
  differing-backing ordinal short despite aggregate spare bytes elsewhere, registry upload/failed partials
  or filesystem→MinIO old+new copy workspace, one ZooKeeper member's transaction-log/snapshot recovery, one
  Patroni data/WAL/failover ordinal, schema old+new/temp/WAL overlap, or Vault Raft
  compaction/recovery/audit rotation exceeds a physical backing, and whose producer cases omit each of the
  six closed object-store arms in turn;
  - `illegal_hot_tier_over_bookie` ([§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)),
    whose case table includes logical hot bytes fitting while write-quorum/recovery placement exceeds one
    bookie;
  - `illegal_topic_time_only_offload` ([§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)),
    a topic whose only retention is time-based and therefore has no size-triggered durable ceiling;
  - `illegal_cache_over_local_pool` ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)/[§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)),
    exact catalog residents plus bounded first-miss temporaries exceeding the named cache backing;
  - `illegal_incluster_cache_bound_mismatch` ([§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)/[§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)),
    a cache peak/budget/`emptyDir` nesting or double-charge violation — each returning its **specific**
    tagged `Left` at the fold and paired with a store-fits row differing only in the foreclosed dimension,
    with the type-foreclosed neighbours noted as already foreclosed upstream (Phase 25/13) and the base
    capacity/topology ([§3.13](../documents/illegal_state/illegal_state_topology.md#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class)–[§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere)/[§3.22](../documents/illegal_state/illegal_state_capacity.md#322-a-hand-authored-un-derived-toleration))
    and execution/accelerator ([§3.21](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)/[§3.27](../documents/illegal_state/illegal_state_capacity.md#327-a-deployment-that-fits-in-aggregate-but-has-no-resource-capable-placement)–[§3.30](../documents/illegal_state/illegal_state_capacity.md#330-an-accelerator-memory-envelope-that-cannot-fit-the-selected-devices-or-unified-memory-pool))
    negatives noted as owned by
    [Phase 9](phase_09_resource_index.md)/[Phase 29](phase_29_execution_accelerator_folds.md).
  - This fold additionally *implements* the provider-root and control-plane-storage byte-fit — the
    under-provisioned instance-store root
    ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)),
    the privately derived, rounded root-EBS request over its distinct `nodeRootStorage` byte/volume-count
    ceiling
    ([§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)),
    and the control-plane etcd max-WAL/preallocated-next/snapshot-save/serialized-defrag transition overrun
    ([§3.19](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar))
    — but their **Haskell-declared gate negatives** (`illegal_provider_instance_store_root_underprovisioned` /
    `illegal_provider_node_root_ebs_over_quota` / `illegal_control_plane_storage_transition_overrun`) are
    owned by [Phase 29](phase_29_execution_accelerator_folds.md) per the §M.7 partition — fold mechanics
    here, gate oracle in Phase 29; the cache negatives `illegal_cache_over_local_pool` /
    `illegal_incluster_cache_bound_mismatch` are this phase's **own** Haskell-declared gate negatives.
  - This phase's Haskell gate contract asserts exactly the five pure storage-geometry/cache negatives
    (`illegal_store_over_backing`, `illegal_hot_tier_over_bookie`, `illegal_topic_time_only_offload`,
    `illegal_cache_over_local_pool`, `illegal_incluster_cache_bound_mismatch`).
- The positive storage-geometry variant rows of `legal_multisubstrate_cluster` (a store-fits-backing row,
  BookKeeper/MinIO physical-fits, uniform-claim exact-fit, presentation/quantum-rounding exact-fit,
  ZooKeeper/Patroni/Vault recovery-fits, and a control-plane-storage-steady-fits row) and `legal_managed_eks` (a
  fixed-`InstanceStore` root-fits row and a derived-root-EBS-within-`nodeRootStorage`-quota row), asserted to
  fit feasibly; these are variants of the two named positives, not additions to the exact representative set.
- A Register-1 validation-locus ledger mapping every entry to its catalog id, checked-rejection layer, and
  `provision-seal` locus, explicitly marking the runtime residue (S3 offload, healing, autoscaler growth,
  live migration) deferred to the live band — sibling evidence where the storage arithmetic generalizes
  prodbox's platform-backbone recovery accounting, not an amoebius result.

### Validation

1. Rejected historical observation: the `storage-geometry-spec` Cabal suite was recorded green — every one of
   the five storage-geometry fold negatives
   ([Gate integrity](#gate-integrity) representative set) returns its **specific Haskell-expected** tagged `Left`, both
   positive fixtures' storage-geometry rows fit feasibly, the QuickCheck battery holds at its coverage minima,
   and the applied Haskell per-geometry seeded-mutant battery ([Gate integrity](#gate-integrity)) turns the suite red
   individually. A negative that provisions successfully or returns the wrong tag is a failure; the ledger must
   keep live-only storage behavior explicitly UNVERIFIED.
2. The gate applies the Phase-28 storage-geometry folds directly to each hand-authored logical-demand/backing
   fixture, testing the lower fold boundary on purpose: binding and whole-deployment provisioning belong to
   [Phase 30](phase_30_capability_bind.md) and [Phase 31](phase_31_provision_seal.md), so each positive row
   fits its backing feasibly and each negative fixture returns the fold's structured `ProvisionError`/`Left`
   on its isolated over-backing axis.
3. Each negative asserts its **specific expected tag**, paired with a store-fits row differing only in the
   foreclosed dimension (§M.8): `illegal_store_over_backing` → `Left (StorageOverBacking …)`;
   `illegal_hot_tier_over_bookie` → `Left (StorageOverBacking …)` on the BookKeeper hot-tier backing;
   `illegal_topic_time_only_offload` → `Left (PulsarDurableCeilingUnbounded …)`;
   `illegal_cache_over_local_pool` → `Left (StorageOverBacking …)` on the named cache backing; and
   `illegal_incluster_cache_bound_mismatch` → `Left (CacheBudgetNestingViolation …)`.
4. Each assertion is annotated with its catalog entry
   ([§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)/[§3.17](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)/[§3.19](../documents/illegal_state/illegal_state_storage.md#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar)/[§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)/[§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model))
   and its checked-rejection layer at the `provision-seal` locus, and the storage-geometry run emits its own
   Register-1 proven/tested/assumed ledger over the logical-to-physical obligations above.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/resource_capacity_doctrine.md` — backlink §5/§6/§7 storage arithmetic to the
  implemented `Amoebius.Capacity.{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}`; confirm
  every storage/retention sum stayed a checked pre-effect rejection at the post-bind `provision-seal`, and that
  the storage `Σ ≤ backing` check is asserted as the stronger `accepts ⟺ in-envelope` equivalence.
- `documents/engineering/storage_lifecycle_doctrine.md` (§5.2) — reconcile the backing read-side with the
  as-built geometry fold; it remains the single owner of its number.
- `documents/engineering/pulsar_client_doctrine.md` (§6) — reconcile the two-ceiling read-side with the as-built
  hot-tier + durable-total fold.
- `documents/illegal_state/illegal_state_catalog.md` — annotate the applicable §3.11/§3.17/§3.19/§3.20/§3.25
  storage parts with their realized checked-rejection / `provision-seal` layer (technique §4.6 storage-checked →
  layer 2, Register-1); keep runtime-checked entries (layer 3 — S3 offload, healing, live migration) deferred.
- `documents/engineering/testing_doctrine.md` — record the Register-1 storage-geometry property + fold ledger
  this gate emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the pass criterion may change Phase 28 after checking a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-28 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register
  `src/Amoebius/Capacity/{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}.hs` and the
  storage-geometry property + gate suites as Phase-28 design-first rows.
- `DEVELOPMENT_PLAN/phase_09_resource_index.md` and `DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md`
  — the sibling sub-phases whose base fold and composed place-witness bracket this seam.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the no-unbounded-storage invariant
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — [§5](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)/[§6](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm)/[§7](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total): the
  `StorageBudget`/`Growable` arithmetic and the two-ceiling Pulsar fold
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the backing read-side
  this fold reconciles with
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — [§6](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra) the two-ceiling read-side
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the storage entries and the
  [§4.6](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) storage-checked technique, with [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)/[§6](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) the load-bearing limit and honest layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_9](phase_09_resource_index.md) — the base `fits`/`carve`/`place` fold and the shared capacity
  types this geometry fold layers on
- [phase_29](phase_29_execution_accelerator_folds.md) — the execution-epoch/accelerator folds and the composed
  full-resource-vector place-witness that integrates this storage geometry
- [phase_31](phase_31_provision_seal.md) — the whole-deployment provision seal that re-exercises these storage
  folds post-bind
- Phase 28 storage-geometry ledger — the human-readable Register-1 proof/test/assumption boundary
