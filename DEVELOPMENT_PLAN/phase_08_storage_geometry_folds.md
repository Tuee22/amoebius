# Phase 8: Logical→physical storage geometry folds

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_07_capacity_core_folds.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_36_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_37_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the pure logical→physical storage-geometry fold — the closed `StorageBudget`/`Growable`
> arithmetic, the BookKeeper/MinIO/registry/ZooKeeper/Patroni/Vault/etcd geometry with complete
> recovery/healing/orphan scenarios, filesystem presentation + allocation rounding, uniform StatefulSet claims,
> schema/registry-backend migration storage, the six-arm object-store producer peak, and Pulsar's two ceilings —
> as total, in-process Haskell, and prove under QuickCheck that every producer's physical demand fits its
> single-owner backing and each storage-geometry negative decode-rejects directly on its isolated axis, on
> hand-authored logical-demand/backing fixtures, before any host or backing exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the [Phase 7 gate](phase_07_capacity_core_folds.md)
(the base `fits`/`carve`/`place` fold, the `Topology` relation, and the shared `Quantity`/`Residual`/
`ProvisionError`/`FilesystemPresentation`/`BackingAllocationPolicy`/`StorageBacking` base types) and runs on
**no substrate** (`none`) in **Register 1** — it stands up no host, no cluster, and no backing, only an
in-process storage-geometry fold + QuickCheck battery. Where a shape below is exercised in a sibling system
(prodbox's platform-backbone BookKeeper/MinIO/ZooKeeper recovery accounting), that is **sibling evidence, not
an amoebius result**.

## Phase Summary

This phase makes amoebius's *"no unbounded storage, anywhere; every producer's physical demand fits a
single-owner backing"* invariant executable as pure provisioning arithmetic, and proves its
implementation/properties under QuickCheck in-process. It owns the **logical→physical storage-geometry fold
only** — the slice of the capacity model that turns a producer's declared *logical* demand into a *physical*
byte requirement against a named backing, and the closed storage-budget arithmetic over it:

- The **closed `StorageBudget` / `Growable` unions' arithmetic**: the single-owner ceiling-per-arm
  `StorageBudget` fold (no unbounded arm) and the `Growable`/`ScalingPolicy` quota-bounded escape valve (no
  bare-unbounded arm). The union *shapes* are type-foreclosed upstream (Phase 4/6); the *arithmetic* over them
  is the pure fold this phase adds.
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
  plus one uniform size and `perBackingDebit[backing] = max ordinal provisioned demand × members on that
  backing`, so no aggregate can move spare bytes between backings.
- **Schema / registry-backend migration storage**: `provisionSchemaMigration`, `provisionStorageMigration`, and
  `provisionRegistryBackendMigration` fit old+new+workspace/temp/WAL high-water plus the transition's executor
  demand before any create/copy/DDL, retaining every old/new partial commitment on failed verification.
- The **six-arm object-store producer peak** (`app`/`content`/`registry`/`Pulsar-offload`/`Pulumi-checkpoint`/
  `control-plane-state`): `mergeObjectStoreLogicalPeaks` enforces source↔producer inventory equality, rejects
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

In the catalog's historical layer taxonomy these are **decode-foreclosed** total checks over constructible
values, never type-inhabitance claims; their concrete validation locus is `provision-seal`. Because the storage
`Σ ≤ backing` sum is decidable in **both** directions (unlike the sound-not-complete compute `place`), this
phase proves the stronger **accept ⟺ in-envelope** equivalence for the geometry fold.

**What is *not* here.** The base `fits`/`carve`/`place` capacity fold, the `Topology`/`ComputeEngine`/
compatibility relation, and `mkRke2` distinctness ([Phase 7](phase_07_capacity_core_folds.md)); the
execution-epoch expansion, scheduler-reservation algebra, kubelet/CRI runtime-metadata fold, logical
pod-ephemeral/memory-backed-volume fold, accelerator residency/VRAM fold, the VM parent-disk
`PhysicalDiskPartition` two-equation arithmetic, and the **composed full-resource-vector place-witness** that
integrates these storage folds ([Phase 9](phase_09_execution_accelerator_folds.md)); the logical etcd
API-object/churn diff whose derived MVCC total this phase's control-plane physical formula *consumes* as a
declared input (owned by [Phase 9](phase_09_execution_accelerator_folds.md)); the capability → provider → shape
binder and the whole-deployment provision seal that re-exercises these folds
([Phase 10](phase_10_capability_bind.md)/[Phase 11](phase_11_provision_seal.md)); and any live snapshot
validation or mutation of a scaling transition — [Phase 19](phase_19_object_reconciler.md) owns the generic
snapshot-bound action/token/CAS plumbing, [Phase 21](phase_21_retained_storage.md) enacts the retained-carve
arms, and [Phase 37](phase_37_provider_dynamic_nodes.md) enacts the `CreateProviderCapacity` arm.

**Substrate:** none — no host, no cluster, no backing; the gate is an in-process `cabal test` storage-geometry
fold + QuickCheck battery, analogous to the Phase 5 decode battery and the Phase 6 property suite.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** the logical→physical storage-geometry fold holds under QuickCheck — every generated in-envelope
producer yields a physical demand that fits its single-owner backing and the fold is **provably total**
(interpreted concretely in [Gate integrity](#gate-integrity): compile-time exhaustiveness under
`-Werror=incomplete-patterns` on every `Amoebius.Capacity.{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}`
module **and** a sampled QuickCheck no-crash run — both, not either) — and the pure folds return their
structured `ProvisionError`/`Left` on each storage-geometry negative fixture when applied **directly to the
hand-authored logical-demand/backing fixture that isolates its over-backing axis** (no `bind`/`provision` call;
the [Phase 11](phase_11_provision_seal.md) gate re-exercises these same folds through its post-bind provision
seal) in the **representative set named in [Gate integrity](#gate-integrity)**
(`illegal_store_over_backing` incl. its MinIO parity/healing/orphan/rounding/uniform-claim/registry-upload/
Vault-Raft/ZooKeeper/Patroni/schema/six-arm variants, `illegal_hot_tier_over_bookie`,
`illegal_topic_time_only_offload`, `illegal_cache_over_local_pool`, and
`illegal_incluster_cache_bound_mismatch`), while the storage-geometry variant rows of the two positive
fixtures named in [Gate integrity](#gate-integrity) fit feasibly. Every fixture, golden, and expected
`Left`-tag it checks against is **authored and committed in Phase 0 before the `Amoebius.Capacity.*` storage
implementation exists** (§M.1); the gate turns red under the **committed per-geometry seeded-mutant battery
named in [Gate integrity](#gate-integrity)** (§M.2) and green only when an **implementation-independent
storage-envelope reference predicate** (§M.3, defined in Sprint 8.3) accepts a returned physical demand *iff* it
is in-envelope — a **Register-1** in-process check that runs on no substrate.

<a id="n-gate-integrity-refinements"></a>
## Gate integrity

This section pins the concrete interpretations the [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
clauses require for Phase 8; it strengthens, never weakens, the Gate and sprint Validations above. It carries
**this seam's slice** of the storage-geometry corpus committed for the old capacity/topology phase; the base
capacity/topology negatives are gated by [Phase 7](phase_07_capacity_core_folds.md) and the execution/
accelerator/VM-partition negatives by [Phase 9](phase_09_execution_accelerator_folds.md). This phase does **not**
duplicate that corpus — it partitions it along the storage seam.

- **Representative set (§M.7).** The gate's storage-geometry fold-negative corpus is *exactly* the five named
  fixtures inherited from the source corpus:
  `illegal_store_over_backing`, `illegal_hot_tier_over_bookie`, `illegal_topic_time_only_offload`,
  `illegal_cache_over_local_pool`, and `illegal_incluster_cache_bound_mismatch`; the
  positive set is the storage-geometry variant rows of
  `legal_multisubstrate_cluster` (a store-fits-backing row, BookKeeper/MinIO physical-fits, uniform-claim
  exact-fit, presentation/quantum-rounding exact-fit, and ZooKeeper/Patroni/Vault recovery-fits plus a
  control-plane-storage-steady-fits row) and `legal_managed_eks` (a fixed-`InstanceStore` root-fits row and a
  derived-root-EBS-within-`nodeRootStorage`-quota row). All are committed in Phase 0 (§M.1) as part of the
  forty-fixture corpus; the compute/topology base-fold negatives (`illegal_engine_substrate_mismatch`,
  `illegal_rke2_reused_host`, `illegal_overcommit_*`, the elastic-branch negatives,
  `illegal_untolerated_taint`, `illegal_memory_backed_underreserved`,
  `illegal_tmpfs_init_persistence_underreserved`, …) are owned by
  [Phase 7](phase_07_capacity_core_folds.md) and the execution/accelerator/VM-partition and
  provider-root/control-plane-storage fixtures
  (`illegal_hard_ceiling_overcommit`, `illegal_node_local_storage_over_backing`,
  `illegal_disk_backing_alias_double_spend`, `illegal_filesystem_layout_*`, `illegal_image_*`, the
  accelerator/CUDA/Metal negatives, `illegal_provider_instance_store_root_underprovisioned`,
  `illegal_provider_node_root_ebs_over_quota`, `illegal_control_plane_storage_transition_overrun`, and
  `legal_tmpfs_two_concurrent_writers_single_debit`) by
  [Phase 9](phase_09_execution_accelerator_folds.md).
  `illegal_store_over_backing` is a stable fixture identifier with a **committed case table** for MinIO
  parity/healing, finite-horizon failed-write/upload orphan exposure, filesystem overhead, backing
  minimum/quantum rounding, uniform claims (a differing-backing ordinal short despite aggregate spare bytes
  elsewhere), registry upload/failed-partial or filesystem→MinIO old+new copy workspace, one ZooKeeper member's
  transaction-log/snapshot recovery, one Patroni data/WAL/failover ordinal, schema old+new/temp/WAL overlap, and
  Vault Raft compaction/recovery plus audit rotation; the same fixture's producer cases omit each of the six
  closed object-store arms (`app`/`content`/`registry`/`Pulsar-offload`/`Pulumi-checkpoint`/`control-plane-state`)
  in turn. `illegal_hot_tier_over_bookie` has logical-fit/physical-overflow cases for BookKeeper
  write-quorum/recovery placement. These are variants inside the named fixtures, not unnamed additions to the
  exact corpus, and do not change the five-negative/two-positive representative count.
- **Committed per-geometry seeded-mutant battery (§M.2).** One committed mutant per geometry obligation, each
  individually required to turn the suite red, drawn from the operator set:
  - **Storage `Σ` / backing comparison** — weaken the backing comparison (accept a physical demand one byte over
    its single-owner backing).
  - **BookKeeper** — drop write-quorum placement or the recovery/re-replication scenario derivation from its
    finite fault bound.
  - **MinIO** — drop stripe padding, data+parity shards, metadata, the healing workspace, or the complete
    per-set plus cross-set failure-scenario product.
  - **Fault-scenario product** — collapse the complete derived fault-policy scenario product to a favourable
    subset.
  - **Concurrent/orphan exposure** — drop the finite-horizon failed-write/upload orphan retention.
  - **Filesystem overhead** — skip the `Block`/version-pinned filesystem-presentation overhead.
  - **Backing minimum/quantum** — skip the `BackingAllocationPolicy` minimum/quantum rounding.
  - **Uniform claim rounding** — replace `max ordinal × members` with an aggregate that moves spare bytes
    between backings.
  - **Pulsar hot-tier ceiling** — drop the physically expanded hot-tier ceiling (accept a topic whose logical
    hot bytes fit but whose write-quorum/recovery placement exceeds one bookie).
  - **Pulsar durable-total ceiling** — drop the durable-total offload ceiling (accept a time-only-offload topic
    with no size-triggered durable bound).
  - **Native cache-pool accounting** — reuse the same cache bytes twice / exceed the named host cache backing.
  - **In-cluster cache nesting** — drop the exact catalog asset join/digest dedup/first-miss temporary peak,
    drop `ProvisionedCacheDemand.derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`, or charge the same bytes twice.
  - **Provider-root storage** — under-size a fixed `InstanceStore` root; omit the root policy/presentation/
    allocation; fail to derive and round the private `EphemeralRootEbs` request; or debit it from durable quota
    rather than the separate `nodeRootStorage` byte/volume-count ceiling. (The provider-root negatives
    `illegal_provider_instance_store_root_underprovisioned` and `illegal_provider_node_root_ebs_over_quota` are
    owned by [Phase 9](phase_09_execution_accelerator_folds.md); this mutant guards the shared geometry fold, not
    a Phase-8 gate fixture.)
  - **Control-plane etcd physical transition** — omit WAL preallocation/overshoot, the snapshot-save temporary,
    the serialized defrag old+new overlap, or the `(maxBackups + 1) × maxBytesPerFile` audit rotation term.
    (The control-plane-storage negative `illegal_control_plane_storage_transition_overrun` is owned by
    [Phase 9](phase_09_execution_accelerator_folds.md); this mutant guards the shared geometry fold, not a
    Phase-8 gate fixture.)
  - **Object-store producer** — omit a source-producer arm (any of the six, including the control-plane-state
    sixth arm); accept a physical-object identity/size conflict; accept a same-byte/different-object-count
    geometry; or drop a per-writer admission witness.
  - **Registry** — drop the OCI object dedup, the bounded concurrent upload workspace, or the failed-partial
    extents retained for the GC horizon.
  - **ZooKeeper** — drop a member's transaction-log/snapshot/failure-recovery overlap.
  - **Patroni** — drop the data/WAL/checkpoint/failover peak or the SQL-mutation admission proxy derivation.
  - **Vault** — drop the persisted-version/lease expansion, the Raft/WAL/snapshot model, the old+new compaction
    overlap, the recovery headroom, or the audit rotation term.
  - **Migration** — drop the old+new+workspace/temp/WAL high-water or the executor demand of any of
    `provisionStorageMigration` / `provisionSchemaMigration` / `provisionRegistryBackendMigration`.
  - **`planStorageScaling`** — return `AllocateWithinRetainedCarve` / `CreateProviderCapacity` /
    `ShrinkByVerifiedMigration` without witnessing the retained carve / residual quota / old+new migration
    high-water, or ignore the `ObservedStorageScalingSnapshot` fingerprint.

  Field-deletion operators are explicit members of this battery: delete one OCI stored object, snapshot chain,
  registry upload bound, root-backing policy/quota, or Vault Raft/audit operand and require a **structured
  rejection** rather than treating absence as zero or falling back to an aggregate.
- **Provably total (§M totality honesty).** Discharged by *both* a compile-time gate
  (`-Werror=incomplete-patterns` / `-Werror=incomplete-uni-patterns` on every storage fold module, no `error`,
  no partial `head`/`fromJust`) **and** the sampled QuickCheck no-crash run; a green sample alone does not
  satisfy the gate.
- **Independent reference predicate (§M.3).** Defined in Sprint 8.3 Deliverables; it never calls
  `bookKeeperPhysicalDemand`, `minioPhysicalDemand`, `provisionObjectStoreProducer`, `registryStoragePeak`,
  `vaultStoragePeak`, `uniformStatefulSetClaims`, or the Pulsar/cache/provider-root folds, deriving the complete
  fault-policy scenario product, presentation overhead, allocation rounding, and per-backing residual **directly**
  from the generated fixture's declared logical demands and backing rules, and asserting **accept ⟺ in-envelope**.

## Doctrine adopted

- [`resource_capacity_doctrine.md §5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)
  — **`StorageBudget` bounded by construction, single-owner ceiling per arm**: this phase implements the closed
  `StorageBudget` fold (every producer's required `StorageBudgetId` resolves once to its selected backing/quota
  owner; no aggregate moves spare bytes between backings) and the logical→physical BookKeeper/MinIO placement
  plus the complete fault-scenario/orphan/uniform-claim/presentation-rounding fold as pure Haskell.
- [`resource_capacity_doctrine.md §6`](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm)
  — **`Growable` + `ScalingPolicy`, the quota-bounded dynamic provisioning arm**: this phase implements the
  closed `Growable`/`ScalingPolicy` escape valve (no bare-unbounded arm) and the private policy-only
  `ProvisionedStorageScalingEnvelope`, complete `ObservedStorageScalingSnapshot` input carrier, and total
  observe-then-plan `planStorageScaling`; it cannot validate or enact a live transition.
- [`resource_capacity_doctrine.md §7`](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)
  — **Pulsar has two ceilings, the hot tier and the durable total**: this phase implements the two-ceiling
  Pulsar fold (physically expanded hot-tier fit built on the `bookKeeperPhysicalDemand` witness + durable-total
  offload fit), so a time-only or physically hot-tier-over-bookie topic decode-rejects.
- [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)
  — **the load-bearing honesty limit**: a storage sum is a checked rejection (**decode-foreclosed** in the
  historical layer taxonomy), never type-foreclosed; its concrete locus is the post-bind `provision-seal`. The
  union *shapes* are type-foreclosed (Phase 4/6); the *arithmetic* over them is the pure fold this phase adds.
  Because the storage `Σ ≤ backing` sum is decidable both ways, this phase asserts the stronger
  **accept ⟺ in-envelope** equivalence, not merely soundness.
- [`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
  — the capacity-accounting technique's **storage-checked** half (summed demand within capacity, storage
  checked), covering the storage/retention catalog entries §3.11/§3.17/§3.19/§3.20/§3.25 at the honest layer
  ([`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
  every storage **sum** is checked at `provision-seal` and never type-foreclosed, honoring the load-bearing
  limit of [`§2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it).
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) §2 (**Register 1** — pure/golden,
  in-process, no cluster) and §4 (the per-run proven/tested/assumed ledger): the register this gate reaches and
  the ledger it emits, with model↔runtime correspondence and runtime fidelity marked UNVERIFIED (owned by the
  live band — [Phase 19](phase_19_object_reconciler.md)/[Phase 21](phase_21_retained_storage.md)/
  [Phase 23](phase_23_platform_backbone.md)/[Phase 37](phase_37_provider_dynamic_nodes.md)).

## Sprints

## Sprint 8.1: The `StorageBudget`/`Growable` arithmetic + logical→physical geometry fold 📋

**Status**: Planned
**Implementation**:
`src/Amoebius/Capacity/Storage.hs` (identity-named disjoint local pools, the closed `StorageBudget` fold, the
native host-worker cache-pool accounting, and the two-ceiling Pulsar fold);
`src/Amoebius/Capacity/StorageGeometry.hs` (`bookKeeperPhysicalDemand`, `contentStoreLogicalPeak`,
`minioPhysicalDemand`, volume presentation/allocation rounding, `uniformStatefulSetClaims`,
`provisionObjectStoreProducer`/`mergeObjectStoreLogicalPeaks`, `provisionStorageMigration`,
`provisionSchemaMigration`, `provisionRegistryBackendMigration`, and the root-volume storage geometry
`provisionNodeRootVolume`);
`src/Amoebius/Capacity/ServiceStorage.hs` (exact cache nesting `provisionCacheDemand`, `registryStoragePeak`,
`provisionZooKeeperMetadataStore`, `provisionPatroniSql`, `vaultStoragePeak`, and the etcd/control-plane
physical storage-transition peak `provisionControlPlaneStorage`);
`src/Amoebius/Capacity/Growable.hs` (`Growable`/`ScalingPolicy`);
extends `src/Amoebius/Capacity/Types.hs` with the storage-geometry demand/provisioned type family
(`StorageBudget`, `Growable`, durable-geometry `DeclaredVolumeDemand` fields, `StatefulSetClaimSlot`,
`VolumePresentation`, `ProvisionedVolumeDemand`, `CachePopulationDemand`/`ProvisionedCacheDemand`,
`RegistryStorageDemand`, `VaultStorageDemand`, `ZooKeeperMetadataStoreDemand`/
`ProvisionedZooKeeperMetadataStoreDemand`, `PatroniSqlDemand`/`ProvisionedPatroniSql`, `ObjectStoreDemand`,
six-arm `ObjectStoreProducerDemand`/`ProvisionedObjectStoreLogicalPeak`, `ObjectStoreAdmissionGatewayDemand`,
`StorageMigrationDemand`/`ProvisionedStorageMigration`, `SchemaMigrationDemand`/`ProvisionedSchemaMigration`,
`RegistryBackendMigrationDemand`/`ProvisionedRegistryBackendMigration`, `ControlPlaneStorageDemand`, and the
provider-root storage types `ProvisionedNodeRootVolumeRequest`/`InstanceStore`/`EphemeralRootEbs`/
`nodeRootStorage`) — target paths, not yet built. The base `Quantity`/`Residual`/`AvailableCapacity`/
`ProvisionError`/`FilesystemPresentation`/`BackingAllocationPolicy`/`StorageBacking` declarations, and the VM
parent-disk `PhysicalDiskPartition` arithmetic, live in [Phase 7](phase_07_capacity_core_folds.md)/
[Phase 9](phase_09_execution_accelerator_folds.md); this sprint consumes them and adds the geometry arithmetic
only.
**Blocked by**: [Phase 7 gate](phase_07_capacity_core_folds.md) (the base capacity types + `fits`/`carve`
subtraction over zero-capable residuals this fold layers on); Phase 5 gate (the GADT-indexed IR + total decoder
these demands decode into).
**Independent Validation**: a unit suite runs the geometry folds over hand-authored logical-demand/backing
inputs: each producer's logical demand expands through its complete replication/erasure/metadata/recovery/
healing/concurrent/orphan scenario product, receives its `Block`/version-pinned filesystem overhead, rounds up
to the backing minimum/quantum, resolves its `ProvisionedVolumeDemand.provisionedBytes` exactly once, and fits
its single-owner backing; an over-backing store, a physically hot-tier-over-bookie topic, a time-only-offload
topic, a cache over its named pool, an in-cluster cache nesting violation, an under-provisioned instance-store
root, a root-EBS request outside its `nodeRootStorage` byte/volume-count quota, or a control-plane transition
overrun returns the fold's tagged `Left` naming the offending backing/axis; and dropping any scenario/overhead/
rounding term makes the property red.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md` (Phase-8 status backlink for §5/§6/§7),
`documents/engineering/storage_lifecycle_doctrine.md` (§5.2 backing read-side),
`documents/engineering/pulsar_client_doctrine.md` (§6 two-ceiling read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.19–§3.20 layer reconciliation),
`DEVELOPMENT_PLAN/system_components.md`.

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
  in-file honesty note records that the union *shapes* are type-foreclosed (Phase 4/6) while every capacity/
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
  uniform size and `perBackingDebit[backing] = max ordinal provisioned demand × members on that backing`; no
  aggregate can move spare bytes between backings.
- `provisionObjectStoreProducer` covers the closed
  `app`/`content`/`registry`/`Pulsar-offload`/`Pulumi-checkpoint`/`control-plane-state` six-arm union: it
  retains exact physical resident ids, structural future/transient extents, per-writer admission witnesses, and
  complete producer-specific retention/rate/failure operands. Source↔producer inventory equality is mandatory;
  `mergeObjectStoreLogicalPeaks` rejects identity/size or admission conflicts and preserves every writer before
  `minioPhysicalDemand` runs, and derives the merged `ObjectStoreAdmissionGatewayDemand` (the gateway's compute
  pod-`place` witness composes downstream in [Phase 9](phase_09_execution_accelerator_folds.md)).
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
  logical pod ephemeral (owned by [Phase 9](phase_09_execution_accelerator_folds.md)) and is not added again;
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
  [Phase 9](phase_09_execution_accelerator_folds.md)) and derives backend + WAL segment/overshoot/
  preallocated-next + retained snapshot/snapshot-save temporary + serialized defrag old/new peak (Events
  included once), plus `(maxBackups + 1) × maxBytesPerFile` audit/runtime logs; a missing headroom field is not
  a zero.

### Validation
1. A feasible input yields a physical demand that fits its single-owner backing after deriving BookKeeper
   replication/recovery, MinIO erasure/healing/in-flight/orphan/presentation/rounding/uniform-claim peaks,
   registry upload/partial/rehome exposure, ZooKeeper log/snapshot/recovery, Patroni data/WAL/failover, schema
   old+new/temp/WAL, and Vault Raft/compaction/recovery/audit peaks. An over-backing or un-tiered topic returns
   its tagged `Left`; a cache over its named pool, an in-cluster cache nesting violation, an under-sized
   instance-store root, a root-EBS request outside its separate byte/volume-count quota, and a control-plane
   transition overrun each return their specific tag naming the offending backing/axis. Exact-fit demand returns
   `Right Zero`/`Right`, a second debit from that residual rejects, and the folds never throw. Each negative
   asserts **which tag and which axis** it fails on (§M.8), each paired with a store-fits row differing only in
   that one axis being in-backing.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.2: The policy-only storage-scaling fold — `ProvisionedStorageScalingEnvelope` / `planStorageScaling` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Capacity/StorageScaling.hs` (`ProvisionedStorageScalingEnvelope`,
`ObservedStorageScalingSnapshot`, `planStorageScaling`) — target path, not yet built.
**Blocked by**: Sprint 8.1 (the `StorageBudget` arithmetic + backing/quota types the envelope retains and the
plan witnesses).
**Independent Validation**: a unit suite constructs a private `ProvisionedStorageScalingEnvelope` for each
`Growable` producer, feeds a complete fingerprinted `ObservedStorageScalingSnapshot`, and asserts
`planStorageScaling` returns exactly one of `NoChange | AllocateWithinRetainedCarve | CreateProviderCapacity |
ShrinkByVerifiedMigration` with current allocation, residual/quota, and old+new migration high-water witnessed;
a plan that emits a transition without its witness, or that ignores the snapshot fingerprint, is rejected. The
suite asserts this phase has **no mutation capability** — it observes and plans only.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md` (§6 `Growable`/`ScalingPolicy` policy
backlink), `documents/engineering/storage_lifecycle_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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
- An in-file honesty note: Phase 8 has no mutation capability; the generic live action is validated by
  [Phase 19 (the object reconciler)](phase_19_object_reconciler.md), the retained
  `AllocateWithinRetainedCarve`/`ShrinkByVerifiedMigration` arms are enacted by
  [Phase 21 (retained storage)](phase_21_retained_storage.md), and `CreateProviderCapacity` by
  [Phase 37 (provider dynamic nodes)](phase_37_provider_dynamic_nodes.md).

### Validation
1. Each generated envelope+snapshot pair resolves to exactly one arm; the arm's witness (retained carve,
   residual quota, or old+new migration high-water) is present and derived from the snapshot, not authored; a
   mutant that emits `AllocateWithinRetainedCarve`/`CreateProviderCapacity`/`ShrinkByVerifiedMigration` without
   its witness, or that ignores the snapshot fingerprint, turns the property red. No arm mutates or requires a
   live backing.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.3: QuickCheck properties — storage `accepts ⟺ in-envelope`, Pulsar two-ceiling, uniform-claim 📋

**Status**: Planned
**Implementation**: `test/dsl/StorageGeometryProps.hs` (QuickCheck generators for logical-demand/backing
inputs + the property battery: BookKeeper/MinIO scenario derivation, presentation/allocation rounding,
uniform-claim grouping, the six-arm object-store merge, the two Pulsar ceilings, cache nesting, provider-root
storage, control-plane physical transition, migration transitions, and the storage `Σ ≤ backing` equivalence),
reusing the Phase-6 property harness — target path, not yet built.
**Blocked by**: Sprint 8.1, Sprint 8.2.
**Independent Validation**: `cabal test dsl-spec` runs the property battery green — the geometry-fold
`accepts ⟺ in-envelope` equivalence, presentation/rounding, uniform-claim, Pulsar two-ceiling, cache-nesting,
provider-root, and control-plane-transition properties hold over generated inputs, each meeting its committed
`cover`/`checkCoverage` minimum (≥30% rejecting / out-of-backing, ≥30% accepting / in-backing per fold; §M.4);
and the **committed per-geometry seeded-mutant battery of [Gate integrity](#gate-integrity) turns the suite red
individually** (§M.2), not merely one hand-picked strawman.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`,
`documents/engineering/testing_doctrine.md` (the Register-1 property register),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) §2 (Register 1)
and the honesty limit of [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
express the storage-geometry fold as QuickCheck properties. Because the storage `Σ ≤ backing` sum is decidable
in **both** directions, assert the stronger **accept ⟺ in-envelope equivalence** (the fold accepts *exactly* the
in-backing inputs) over generated corpora, not merely soundness — the storage sum is not the sound-not-complete
compute `place`.

### Deliverables
- The **implementation-independent storage-envelope reference predicate** (§M.3): a committed, hand-authored
  envelope predicate authored in Phase 0, distinct from the fold under test, that **never calls**
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
- The reference predicate carries **one seeded mutant per geometry obligation** ([Gate integrity](#gate-integrity)
  §M.2), each individually required to turn the suite red: the storage-`Σ` backing comparison; BookKeeper
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
- A totality guard discharged **both ways** (§M totality honesty): (a) a compile-time exhaustiveness gate —
  every `Amoebius.Capacity.{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}` module compiles
  under `-Werror=incomplete-patterns` / `-Werror=incomplete-uni-patterns` with no `error` and no partial
  `head`/`fromJust`; **and** (b) the sampled QuickCheck run in which every generator exercises the fold on
  arbitrary constructible inputs and no input yields an exception, `error`, or partial match. A green sample
  alone does not satisfy this guard.

### Validation
1. The property battery is green with every fold meeting its coverage minimum; and **each committed mutant in
   the per-geometry seeded-mutant battery ([Gate integrity](#gate-integrity)) — including the storage `Σ`, both
   Pulsar ceilings, uniform-claim, cache-nesting, provider-root, control-plane, migration, and `planStorageScaling`
   mutants — makes a property red when re-run individually** — the properties have teeth on every geometry
   obligation, not two.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.4: The storage-geometry fold-negative corpus + the gate 📋

**Status**: Planned
**Implementation**: `dhall/examples/{illegal_store_over_backing,illegal_hot_tier_over_bookie,
illegal_topic_time_only_offload,illegal_cache_over_local_pool,
illegal_incluster_cache_bound_mismatch}.dhall` (the five storage-geometry/cache `provision-seal` fold negatives)
+ reuse of the storage-geometry variant rows of `legal_multisubstrate_cluster`/`legal_managed_eks`;
`test/dsl/StorageGeometryGate.hs` (the gate battery + validation-locus ledger) — target paths, not yet built.
All five negatives, the reused positive rows, and their expected results / `Left`-tags are authored and
committed in Phase 0 before the implementation exists (§M.1, [Gate integrity](#gate-integrity)) as part of the
forty-fixture corpus.
**Blocked by**: Sprint 8.1, Sprint 8.2, Sprint 8.3; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: the gate applies the Phase-8 storage-geometry folds directly to each hand-authored
logical-demand/backing fixture — no `bind`, `planInfrastructure`, `ProvisionContext`, or `provision` call (those
are [Phase 10](phase_10_capability_bind.md)/[Phase 11](phase_11_provision_seal.md) deliverables, and the
Phase-11 gate re-exercises these same folds through its post-bind provision seal) — so each positive row fits
its backing feasibly and each negative fixture returns the fold's structured `ProvisionError`/`Left` on its
isolated over-backing axis — **each negative asserting its specific expected tag** (e.g.
`illegal_store_over_backing` → `Left (StorageOverBacking …)`, `illegal_hot_tier_over_bookie` →
`Left (StorageOverBacking …)` on the BookKeeper hot-tier backing, `illegal_topic_time_only_offload` →
`Left (PulsarDurableCeilingUnbounded …)`, `illegal_cache_over_local_pool` → `Left (StorageOverBacking …)` on the
named cache backing, and `illegal_incluster_cache_bound_mismatch` → `Left (CacheBudgetNestingViolation …)`),
**not merely "some
`Left`", and each paired with a store-fits row differing only in the foreclosed dimension** (§M.8) — each
assertion annotated with its catalog entry (§3.11/§3.17/§3.19/§3.20/§3.25) and its checked-rejection layer at
the `provision-seal` locus; the run emits a Register-1 proven/tested/assumed ledger.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (the storage §3.11/§3.17/§3.19/§3.20/§3.25
checked-rejection / `provision-seal` entries → layer-2 Register-1),
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-8 status when the gate
passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-8 `none` gate row).

### Objective
Adopt [`illegal_state_catalog.md` §4.6 — capacity-accounting, storage checked](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
and [`§3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent):
assemble the phase's single Register-1 gate — the pure storage-geometry folds reject each over-backing negative
while the positive store-fits rows fit feasibly — and emit the per-entry validation-locus ledger that names the
honest foreclosure layer of each.

### Deliverables
- The fold-negative fixtures — `illegal_store_over_backing` (§3.19), whose case table includes logical committed
  bytes fitting while erasure/healing, finite-horizon failed-write orphans, filesystem overhead, backing
  minimum/quantum, uniform-claim rounding, a differing-backing ordinal short despite aggregate spare bytes
  elsewhere, registry upload/failed partials or filesystem→MinIO old+new copy workspace, one ZooKeeper member's
  transaction-log/snapshot recovery, one Patroni data/WAL/failover ordinal, schema old+new/temp/WAL overlap, or
  Vault Raft compaction/recovery/audit rotation exceeds a physical backing, and whose producer cases omit each of
  the six closed object-store arms in turn; `illegal_hot_tier_over_bookie` (§3.20), whose case table includes
  logical hot bytes fitting while write-quorum/recovery placement exceeds one bookie;
  `illegal_topic_time_only_offload` (§3.20), a topic whose only retention is time-based and therefore has no
  size-triggered durable ceiling; `illegal_cache_over_local_pool` (§3.17/§3.25), exact catalog residents plus
  bounded first-miss temporaries exceeding the named cache backing; `illegal_incluster_cache_bound_mismatch`
  (§3.11/§3.17), a cache peak/budget/`emptyDir` nesting or double-charge violation — each returning its
  **specific** tagged `Left` at the fold and paired with a store-fits row differing
  only in the foreclosed dimension, with the type-foreclosed neighbours noted as already foreclosed upstream
  (Phase 4/6) and the base capacity/topology (§3.13–§3.18/§3.22) and execution/accelerator (§3.21/§3.27–§3.30)
  negatives noted as owned by [Phase 7](phase_07_capacity_core_folds.md)/[Phase 9](phase_09_execution_accelerator_folds.md). This fold
  additionally *implements* the provider-root and control-plane-storage byte-fit — the under-provisioned
  instance-store root (§3.17), the privately derived, rounded root-EBS request over its distinct
  `nodeRootStorage` byte/volume-count ceiling (§3.17), and the control-plane etcd
  max-WAL/preallocated-next/snapshot-save/serialized-defrag transition overrun (§3.19) — but their **committed
  gate negatives** (`illegal_provider_instance_store_root_underprovisioned` /
  `illegal_provider_node_root_ebs_over_quota` / `illegal_control_plane_storage_transition_overrun`) are owned by
  [Phase 9](phase_09_execution_accelerator_folds.md) per the §M.7 partition — fold mechanics here, gate oracle in
  Phase 9; the cache negatives `illegal_cache_over_local_pool` / `illegal_incluster_cache_bound_mismatch` are
  this phase's **own** committed gate negatives. This phase's committed gate asserts exactly the five pure
  storage-geometry/cache negatives (`illegal_store_over_backing`, `illegal_hot_tier_over_bookie`,
  `illegal_topic_time_only_offload`, `illegal_cache_over_local_pool`,
  `illegal_incluster_cache_bound_mismatch`).
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
1. `cabal test dsl-spec` is green — every one of the five storage-geometry fold negatives
   ([Gate integrity](#gate-integrity) representative set) returns its **specific committed** tagged `Left`, both
   positive fixtures' storage-geometry rows fit feasibly, the QuickCheck battery holds at its coverage minima,
   and the committed per-geometry seeded-mutant battery ([Gate integrity](#gate-integrity)) turns the suite red
   individually; the suite is red if any storage-geometry negative provisions to `Right` or to the wrong tag;
   the validation-locus ledger is present and honestly classifies each foreclosure, marking the runtime residue
   UNVERIFIED.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-8 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-8 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register
  `src/Amoebius/Capacity/{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}.hs` and the
  storage-geometry property + gate suites as Phase-8 design-first rows.
- `DEVELOPMENT_PLAN/phase_07_capacity_core_folds.md` and `DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md`
  — the sibling sub-phases whose base fold and composed place-witness bracket this seam.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the no-unbounded-storage invariant
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — §5/§6/§7: the
  `StorageBudget`/`Growable` arithmetic and the two-ceiling Pulsar fold
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the backing read-side
  this fold reconciles with
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — §6 the two-ceiling read-side
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the storage entries and the
  §4.6 storage-checked technique, with §2/§6 the load-bearing limit and honest layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_07](phase_07_capacity_core_folds.md) — the base `fits`/`carve`/`place` fold and the shared capacity
  types this geometry fold layers on
- [phase_09](phase_09_execution_accelerator_folds.md) — the execution-epoch/accelerator folds and the composed
  full-resource-vector place-witness that integrates this storage geometry
- [phase_11](phase_11_provision_seal.md) — the whole-deployment provision seal that re-exercises these storage
  folds post-bind
