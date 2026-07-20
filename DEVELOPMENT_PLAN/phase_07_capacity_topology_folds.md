# Phase 7: Capacity / topology folds (representational)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the pure capacity-accounting fold (`fits`/`carve`/`place`) and the compute-engine/topology
> relation as total, in-process Haskell, and prove under QuickCheck that they hold on the positive corpus and
> reject every capacity/topology negative when consumed by the Phase-8 post-bind provision seal — before any
> host or cluster exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 6 gate (the illegal-state
corpus, its QuickCheck properties, and the validation-locus ledger) and runs on **no substrate** (`none`) in
**Register 1** — it stands up no host and no cluster, only an in-process fold + property battery. Where a shape
below is exercised in a sibling system (prodbox's `Prodbox/CLI/Rke2.hs` single-node rke2 base and the
teardown push-back soundness it proves), that is **sibling evidence, not an amoebius result**.

## Phase Summary

This phase makes amoebius's *"resource demand never exceeds capacity"* and *"the compute engine matches its
substrate, and topology matches its hosts"* invariants executable as pure provisioning folds, and proves
their implementation/properties under QuickCheck in-process. Phase 8 invokes them only after full
bind/expansion; Phase 7 does not move them into `Dhall.inputFile`. It delivers the capacity model — the
refined unit-tagged `Quantity`, the
`Capacity`/`Demand`/`Budget`/`ResourceEnvelope` family spanning CPU and memory; pod/CNI/CSI slots; logical
pod-local ephemeral storage including cache, writable/log, and mapped-file demand; separately derived per-Pod
kubelet/CRI runtime-metadata components routed by semantic role through the selected filesystem layout;
layout-routed OCI content/snapshot/workspace; durable/object/registry/ZooKeeper/Patroni/Vault/monitoring and migration storage;
API-object/etcd logical and physical state; every controller/webhook/gateway/build/Pulumi/copy/schema execution
unit, including kind-indexed Deployment, StatefulSet, DaemonSet, Job, and HostProcess multiplicity/transitions;
provider quota; accelerator device offerings; and per-device raw/reserved/allocatable plus demand-total
VRAM. It includes the host `BuildExecutionEnvelope`, named-process
`EngineSystemReserve`/`ControlPlaneStorageDemand`, and mandatory `MonitoringWorkBudget`; and the total functions
`fits` / `podFits` / `carve` / `place`
that nest host → VM → workload and branch `place` on a fixed node set (a concrete pod→node **witness**
bin-pack) versus an elastic one (a capability-aware candidate/instance-quota envelope) — together with the closed `StorageBudget` /
`Growable` unions, logical→physical BookKeeper/MinIO/Vault/registry geometry with complete recovery/healing
scenarios, finite failed-write/upload orphan exposure, filesystem presentation plus allocation rounding,
uniform StatefulSet claims, and the two-ceiling Pulsar fold. It delivers the topology relation — the closed
`ComputeEngine` union, the substrate-indexed `LinuxHost` witness, the explicit fixed/elastic `NodeSupply`,
and the **elementwise** compatible-pair relation over fixed/floor nodes and elastic candidate classes that
keeps heterogeneous multi-substrate clusters legal while rejecting an incompatible pairing. In the catalog's
historical layer taxonomy these are **decode-foreclosed** total checks over constructible values, never
type-inhabitance claims; their concrete validation locus is `provision-seal`. The phase proves the folds are
total, sound (they never
admit an over-committed or incompatible spec), and structurally rejecting on the capacity/topology negatives.
What is *not* here: the live re-run of any fixture against a real cluster, VM boot, pod schedule, S3 offload,
or autoscaler growth (the runtime-checked residue, deferred to the live band); the capability → provider →
shape binder ([Phase 8](phase_08_capability_binder.md)); and the `ScalingPolicy` enaction as Pulumi node
provisioning (a later live phase). Phase 7 owns the pure `ProvisionedStorageScalingEnvelope` /
`planStorageScaling` representation and fold, but not its live snapshot validation or mutation: Phase 16 owns
the generic snapshot-bound action/token/CAS plumbing, Phase 17 owns retained-carve allocation and verified
migration, and Phase 30 owns provider-capacity creation.

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test` fold + QuickCheck battery,
analogous to the Phase 5 decode battery and the Phase 6 property suite.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** the `fits`/`carve`/`place` capacity fold and the compute-engine/topology relation hold under
QuickCheck — every generated positive input yields a sound headroom/placement/compatibility result and the
folds are **provably total** (interpreted concretely in [Gate integrity](#gate-integrity): compile-time exhaustiveness under
`-Werror=incomplete-patterns` on every `Amoebius.Capacity.*` / `Amoebius.Dsl.Topology` module **and** a
sampled QuickCheck no-crash run — both, not either) — and the pure folds return their structured
`ProvisionError`/`Left` on each capacity/topology negative fixture when invoked through the post-bind
provision harness in the **representative set named in [Gate integrity](#gate-integrity)** (engine↔substrate
  mismatch, a reused rke2 host, host/VM/cluster overcommit, CPU-limit-policy, per-container/private,
  memory-writer, pod-ephemeral, finite-limit/physical-peak, node-local filesystem/image,
  OCI content/snapshot/model,
  filesystem-layout alias/support, provider node-root backing/quota, cache/backing, retention, taint, CUDA
  family/count/net-allocatable-VRAM, and Apple-Metal-profile failures, plus elastic largest-candidate, per-node-overhead,
  per-class-maximum, and outer-quota failures), while the positive
`legal_multisubstrate_cluster` and `legal_managed_eks` fixtures place feasibly. Every fixture, golden, and
expected `Left`-tag it checks against is **authored and committed in Phase 0 before the
`Amoebius.Capacity.*` / `Amoebius.Dsl.Topology` implementation exists** (§M.1); the gate turns red under the
**committed per-fold seeded-mutant battery named in [Gate integrity](#gate-integrity)** (§M.2) and green only when an
**implementation-independent witness validator** (§M.3, defined in Sprint 7.3) accepts every returned
placement — a **Register-1** in-process check that runs on no substrate.

<a id="n-gate-integrity-refinements"></a>
## Gate integrity

This section pins the concrete interpretations the [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
clauses require for Phase 7; it strengthens, never weakens, the Gate and sprint Validations above.

- **Representative set (§M.7).** The gate's fold-negative corpus is *exactly* the thirty-seven named fixtures:
  `illegal_engine_substrate_mismatch`, `illegal_rke2_reused_host`, `illegal_overcommit_{host,vm,cluster}`,
  `illegal_store_over_backing`, `illegal_topic_time_only_offload`, `illegal_hot_tier_over_bookie`,
  `illegal_untolerated_taint`, `illegal_pod_ephemeral_overcommit`, `illegal_hard_ceiling_overcommit`,
  `illegal_cpu_limit_over_policy`, `illegal_memory_backed_underreserved`,
  `illegal_tmpfs_init_persistence_underreserved`,
  `illegal_node_local_storage_over_backing`, `illegal_disk_backing_alias_double_spend`,
  `illegal_filesystem_layout_alias`, `illegal_filesystem_layout_swapped`,
  `illegal_image_content_join_missing`, `illegal_image_snapshot_join_missing`,
  `illegal_image_storage_model_missing`, `illegal_split_image_unsupported`,
  `illegal_provider_instance_store_root_underprovisioned`, `illegal_provider_node_root_ebs_over_quota`,
  `illegal_control_plane_storage_transition_overrun`,
  `illegal_cache_over_local_pool`, `illegal_incluster_cache_bound_mismatch`,
  `illegal_cuda_on_cpu_target`, `illegal_accelerator_count_shortage`,
  `illegal_accelerator_vram_fragmentation`, `illegal_accelerator_vram_reserve_boundary`,
  `illegal_apple_metal_profile_mismatch`,
  `illegal_shared_accelerator_double_owner`,
  `illegal_elastic_pod_exceeds_largest_candidate`, `illegal_elastic_class_max_exhausted`,
  `illegal_elastic_per_node_overhead_unplaceable`, and
  `illegal_elastic_worst_case_instances_over_quota`; the positive set is exactly
  `legal_multisubstrate_cluster`, `legal_managed_eks` (whose cover requires at least two nodes materialized
  from one candidate class), and
  `legal_tmpfs_two_concurrent_writers_single_debit`. All forty are committed in Phase 0 (§M.1).
  `illegal_hard_ceiling_overcommit` is a stable fixture identifier: its ephemeral-storage cases validate the
  finite limit plus routed physical peak, cache admission, and eviction-reserve relation; they do not assert
  that Kubernetes provides a synchronous per-container filesystem quota.
  `illegal_store_over_backing` has a committed case table for MinIO parity/healing, finite-horizon orphan
  exposure, filesystem overhead, backing minimum/quantum rounding, uniform claims, registry upload/partial
  retention, and Vault Raft compaction/recovery plus audit rotation; `illegal_hot_tier_over_bookie` has
  logical-fit/physical-overflow cases for BookKeeper replication and recovery. These are variants inside the
  two named fixtures, not unnamed additions to the exact corpus. Kind-indexed execution controller/rollout/live-epoch
  cases remain variants of `illegal_hard_ceiling_overcommit`; kubelet-runtime-metadata cases remain variants of
  `illegal_node_local_storage_over_backing`; and partition allocatable/exact-child-debit cases remain variants
  of `illegal_overcommit_host`/`illegal_disk_backing_alias_double_spend`. The Phase-5
  `illegal_decode_unspellable` zero-progress rolling case remains an inherited Gate-2 precondition, while this
  phase directly exercises legal Deployment `{ maxSurge = 1, maxUnavailable = 0 }` and `{ 0, 1 }` epoch controls and an
  internal guard-weakening mutant that attempts to inject `{ 0, 0 }`. They likewise do not change the
  thirty-seven-negative/three-positive representative count.
- **Committed per-fold seeded-mutant battery (§M.2).** One committed mutant per fold, each individually
  required to turn the suite red, drawn from the operator set: `fits` (drop the `memory` axis), `carve`
  (skip a subtraction), fixed `place` (admit a per-node aggregate overcommit), elastic `place` (return
  `Right` unconditionally), storage logical→physical placement (weaken the backing comparison; drop
  BookKeeper write-quorum/recovery, MinIO parity/healing/stripe padding, the complete derived fault-scenario
  product, concurrent/orphan exposure, filesystem overhead, backing minimum/quantum, uniform claim rounding,
  registry upload/partial retention, or Vault Raft/WAL/snapshot/compaction/recovery/audit rotation), each Pulsar ceiling
  (drop the physically expanded hot-tier ceiling; drop the durable-total ceiling), elementwise compatibility (admit an
  incompatible pair), `mkRke2` distinctness (accept a duplicate `HostId`), pod placement (drop
  `ephemeralStorage`), CPU-limit policy (ignore the finite overcommit ratio),
  finite-limit/physical-peak proof (check requests only), native cache-pool accounting (reuse the same bytes
  twice), in-cluster cache nesting (drop
  the exact catalog asset join/digest dedup/first-miss temporary peak, drop
  `ProvisionedCacheDemand.derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`, fail to reserve
  volume bounds + lifecycle-effective container-private headroom in the pod's ephemeral request, fail a
  private allowance to fit its own container request/limit, or charge the same bytes twice),
  memory-backed volume nesting (ignore access/persistence, assign zero or two reservation carriers in one
  concurrency epoch, miss init→app persistence, or charge the bytes twice), node-local filesystem/image
  accounting (ignore logical pod-ephemeral allocatable, target platform, OCI index/manifest/config/compressed
  content, snapshot chain/unpacked bytes, model version, pull concurrency/workspace, or layout routing; assume
  unpinned residents are free; fail to deduplicate object digests/chain ids; accept a missing join, a forbidden
  alias, swapped nodefs/imagefs roles, or unsupported `SplitImage`), disk identity (accept duplicate physical backing/carve ids), shared
  supply allocation (assign one physical accelerator id to two cluster budgets),
  accelerator capability (treat `None` as CUDA or ignore a Metal-profile mismatch), accelerator residency
  placement (drop a source/workload item, accept unequal source/workload or policy-class domains, choose a
  favorable rather than every policy-permitted coexistence epoch, split one `Unsharded` residency across
  devices, fail to charge `ReplicatedPerDevice` bytes on every owner device, accept non-unique or
  wrong-sum/over-count `Sharded` assignments, or spend raw VRAM without subtracting the mandatory
  driver/runtime reserve),
  provider-template instantiation (reuse one class-local disk/accelerator template id as the concrete physical
  id on two materialized nodes; accept duplicate/unresolved/layout-invalid template roles; author a raw VM or
  root-EBS byte aggregate; skip VM filesystem overhead/rounding; under-size an instance-store root; omit the
  root policy/presentation/allocation; fail to derive and round the private root-EBS request; or debit it from
  durable quota rather than the separate node-root-storage byte/volume-count ceiling),
  kind-indexed execution expansion (admit a zero-progress Deployment rolling policy or a policy field from
  the wrong controller kind; copy the desired envelope/revision into
  a prior row; drop a removed-prior unit, desired replica, selector-matched DaemonSet/host slot, surge instance,
  or retained old/terminating revision; invent an old row for `FirstDeployment`; resolve implicit latest
  instead of the exact prior generation; lose either prior or desired source-unit/revision/ordinal join; omit
  the reachable empty recreate/initial step; or charge only the steady epoch), kubelet/CRI runtime
  metadata (drop the largest simultaneous Pod, accept a missing/changed model, omit a structural component,
  drop or swap its `KubeletNodefs | CriRuntimeRoot` role, resolve a role to the wrong layout backing, admit a
  planned-slot/observed-UID domain mismatch, overlap or leave a hole in the qualified Pod/image component
  ownership, or charge an aliased backing twice), physical-disk
  parent accounting (mix a `VmGuestUsableExtent` debit into the physical-raw sum, use a VM's
  `requiredUsableBytes` instead of its derived `provisionedBytes`, fail to derive a presented usable carve's
  private raw parent debit, omit `systemReserve`, or debit one child twice),
  elastic class maximum (ignore `maxCount`), and elastic per-node expansion
  (fail to subtract a required DaemonSet/cache/accelerator owner from every selected candidate).
  Field-deletion operators are explicit members of this battery: delete one OCI stored object, snapshot
  chain, model version, filesystem-layout reference, root-backing policy/quota, presentation/allocation rule,
  cache asset, registry upload bound, or Vault Raft/audit operand and require a structured rejection rather
  than treating absence as zero or falling back to an aggregate.
  The per-axis/resource and eligibility
  mutants of Sprint 7.3 are additional and separately required.
- **Provably total (§M totality honesty).** Discharged by *both* a compile-time gate
  (`-Werror=incomplete-patterns` / `-Werror=incomplete-uni-patterns` on every fold module, no `error`,
  no partial `head`/`fromJust`) **and** the sampled QuickCheck no-crash run; a green sample alone does not
  satisfy the gate.
- **Independent witness validator (§M.3).** Defined in Sprint 7.3 Deliverables; it never calls `podFits`
  or `place`, computing residuals directly from the generated fixture's declared allocatables.

## Doctrine adopted

- [`resource_capacity_doctrine.md §4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the total fold `fits`/`carve`/`place` and the nesting: this phase implements the four total functions and
  the host → VM → workload nesting as pure Haskell, with `place` branching per
  [§4.1](../documents/engineering/resource_capacity_doctrine.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope)
  (a fixed node set proves a placement witness; an elastic one proves a growth envelope), reading the declared
  `Capacity`/`Demand`/`Budget` types of [§3](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget).
- [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)
  — the load-bearing honesty limit: a capacity check is a checked rejection
  (**decode-foreclosed** in the historical layer taxonomy), never type-foreclosed; its concrete locus is the
  post-bind `provision-seal`, and the
  compute placement is **sound, not complete** (first-fit-decreasing may reject a packable spec but never
  admits an unplaceable one). The QuickCheck properties assert soundness only; completeness is deliberately not
  claimed.
- [`resource_capacity_doctrine.md §5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm),
  [`§6`](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-escape-valve-amoebius-owns),
  and [`§7`](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)
  — the storage arithmetic: the closed `StorageBudget` union (no unbounded arm), the `Growable`/`ScalingPolicy`
  escape valve (no bare-unbounded arm), the logical→physical BookKeeper/MinIO placement plus complete
  fault-scenario/orphan/uniform-claim fold, and Pulsar's two ceilings
  (physically expanded hot-tier fit + durable-total fit) — the union *shapes* are type-foreclosed (Phase 4/6); the
  *arithmetic* over them is the pure fold this phase adds for Phase-8 `provision`. This phase also owns the
  private policy-only `ProvisionedStorageScalingEnvelope`, complete `ObservedStorageScalingSnapshot` input
  carrier, and total observe-then-plan `planStorageScaling`; it cannot validate or enact a live transition.
- [`cluster_topology_doctrine.md §2`](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm),
  [`§3`](../documents/engineering/cluster_topology_doctrine.md#3-the-linuxhost-witness-rke2kind-on-a-host-with-no-linux-node-is-uninhabitable),
  and [`§4`](../documents/engineering/cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction)
  — the compute-engine axis: the closed `ComputeEngine` union with `Managed Eks` as a first-class arm, the
  substrate-indexed `LinuxHost` witness (whose only apple/windows constructor is `limaHost`/`wsl2Host`), and
  the `Topology` with a derived
  `NodeSupply = Fixed (NonEmpty Node) | Elastic { floor, candidates, quota }` in which cardinality/supply is
  explicit — this phase realizes the distinctness-over-`servers ∪ agentFloor` provisioning fold and the placement
  fold over that `Topology`.
- [`cluster_topology_doctrine.md §5`](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor)
  — the compatibility relation (catalog technique §4.7): the compatible-pair smart constructor at the element
  level and the **total elementwise fold** over fixed/floor nodes plus elastic candidate classes at the
  collection level, returning the full list of incompatible entries so heterogeneous multi-substrate stays
  legal by construction.
- [`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
  and [`§4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  — the two typing techniques this phase discharges (capacity-accounting placement + compatibility/topology
  relations over a collection), covering the capacity/topology and accelerator entries
  §3.13–§3.22/§3.27–§3.30 at the honest layer
  ([`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
  every capacity **sum** is checked at `provision-seal` and never type-foreclosed, honoring the load-bearing limit of
  [`§2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it).
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) §2 (**Register 1** — pure/golden,
  in-process, no cluster) and §4 (the per-run proven/tested/assumed ledger): the register this gate reaches and
  the ledger it emits, with model↔runtime correspondence and runtime fidelity marked UNVERIFIED (owned by the
  live band).

## Sprints

## Sprint 7.1: The `Topology` relation — `ComputeEngine` / `LinuxHost` witness / elementwise compatibility fold 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Topology.hs` (`ComputeEngine`, the substrate-indexed `LinuxHost`
  witness, opaque `Topology = { engine, supply : NodeSupply }` with the supply derived from the engine, the
  compatible-pair smart constructor, the total elementwise compatibility fold, and the `mkRke2` distinctness
  fold over `servers ∪ agentFloor`); extends
`src/Amoebius/Dsl/SmartConstructors.hs` — target paths, not yet built.
**Blocked by**: Phase 5 gate (the GADT-indexed IR + total decoder the topology types live in); Phase 6 gate
(the property/corpus framework + validation-locus ledger).
**Independent Validation**: a unit + property suite decodes each positive `Topology` (heterogeneous
multi-substrate, managed EKS) and returns a structured `Left` naming the full set of incompatible nodes for a
mismatched pair and a duplicate `HostId` for a reused host; the no-inhabitant claim for `bareAppleHost` /
`bareWindowsHost` / an even-server quorum is machine-gated by a **Phase-6-style `ghc -fno-code` expect-fail
compile golden** — a committed source snippet that attempts each construction, wired into `dsl-spec`, that
must fail to compile with the **specific committed expected type error** (§M.8: e.g. "No instance /
no constructor for `bareAppleHost`", the even-quorum refinement rejection), re-checked on every run — not an
informal typed-hole probe. The three expect-fail goldens and their expected error text are authored and
committed in Phase 0 before `Amoebius.Dsl.Topology` exists (§M.1).
**Docs to update**: `documents/engineering/cluster_topology_doctrine.md` (Phase-7 status backlink),
`documents/engineering/substrate_doctrine.md` (§8 node inventory read-side), `documents/illegal_state/illegal_state_catalog.md`
(§3.13–§3.16 per-entry layer reconciliation), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`cluster_topology_doctrine.md §2/§3/§4`](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm)
and the compatibility relation of [`§5`](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor):
build the declared compute-engine axis as pure Haskell so that a cluster is a `Topology` fold over its nodes,
cardinality is by construction, and the element/collection compatibility relation admits every legal
heterogeneous cluster while rejecting an incompatible pairing at the pure
bind/plan-or-resolve-infrastructure/materialization/provision boundary.

### Deliverables
- The closed `ComputeEngine` union (`Kind { host, replicas, demand : KindEngineDemand }` /
  `Rke2 { servers : Rke2Servers, agents : Fixed [Rke2AgentNode] | Autoscaled { floor, policy } }` /
  `Managed Eks { account : CloudAccountId, nodeClasses : NonEmpty ProviderNodeClass,
  quota : ProviderQuota, workers : ProviderWorkerPool }`) and the
  substrate-indexed `LinuxHost` witness — kind's single `host` field *is* the
  cardinality bound; the only apple/windows `LinuxHost` constructor is `limaHost`/`wsl2Host`.
- The derived closed
  `NodeSupply = Fixed (NonEmpty Node) | Elastic { floor : [Node], candidates : NonEmpty CandidateNodeClass,
  quota : GrowthQuota }`, so fixed placement has real nodes while elastic placement has a non-empty compatible
  candidate supply and bounded quota, never fictitious current nodes. Provider candidate `baseCount`s derive
  the stable hostless floor slots and must be at most their `maxCount`, with the aggregate base supply inside
  quota; `NoDurable` means zero provider durable supply, not an absent ceiling. A candidate carries
  per-instance disk-carve and accelerator-slot **templates**, not concrete global physical ids; each
  hypothetical cover slot receives fresh instance-scoped symbolic ids, and node join binds those slots to
  fresh observed concrete backing/carve/device ids. Template constructors prove local disk/carve/slot-id
  uniqueness, exact filesystem-reference resolution and only layout-mandated aliases, role bytes within their
  explicit `ProviderUsableDiskCarveTemplate.requiredUsableBytes`, and construct a private
  `ProvisionedPerInstanceDiskTemplate`. That value derives `mountedUsableBytes` through the pinned filesystem
  presentation from either `InstanceStore.provisionedRawBytes` or the privately derived,
  presentation/quantum-rounded ephemeral-root-EBS request before proving
  `systemReserve.requiredUsableBytes + Σ unique carves.requiredUsableBytes <= mountedUsableBytes`. The latter
  also debits the distinct
  `nodeRootStorage` bytes/volume-count quota, not durable quota; both root arms preserve presentation, and
  `driverRuntimeReserve + allocatableVram ≤ rawVram`. Generated symbolic identity is qualified by
  `ClusterId/ClassId/coverSlot/full template path`, never a class-local label alone.
- Each fixed/floor rke2 node carries its exact `NodeCapacity` plus role-indexed reserve. Each autoscaled rke2
  candidate uses the distinct agent-provision arm with declared raw per-instance host CPU/memory/disk supply,
  template-local process/storage ids, and an agent reserve; checked construction proves node allocatable +
  reserve fits raw host supply before cover. Managed-provider candidates use the no-invented-reserve arm.
- The compatible-pair smart constructor for `Node` and candidate classes, and the **total elementwise**
  compatibility fold over fixed/floor nodes plus elastic candidates, returning the complete list of
  incompatible entries (not just the first) so heterogeneous multi-substrate is legal element by element.
- The `mkRke2` distinctness fold over `servers ∪ agentFloor` rejecting a duplicate `HostId` — the checked
  `provision-seal`
  floor Dhall cannot express as a type — with an in-file note that the odd-quorum shape and "more nodes than
  hosts" are already type-foreclosed upstream (Phase 4/5).

### Validation
1. Each positive `Topology` decodes; a mismatched pair returns a structured `Left` listing every incompatible
   node; a reused host returns a duplicate-`HostId` `Left`; the illegal constructors have no inhabitant, proven
   by the committed `ghc -fno-code` expect-fail compile goldens ([Gate integrity](#gate-integrity), §M.8) whose specific expected type errors
   are re-checked on every `dsl-spec` run.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.2: The capacity fold — `fits` / `podFits` / `carve` / `place` + logical→physical storage 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Capacity/Types.hs` (`Quantity`, `PodResourceVec`, the closed
pod/host-worker `ResourceEnvelope`, pod/host accelerator demands and offerings, `Capacity`/`Demand`/`Budget`,
zero-capable `Residual`/`AvailableCapacity`, `BuildExecutionEnvelope`, role-indexed `EngineSystemReserve`,
`ControlPlaneStorageDemand`/`WorkerEngineStorageDemand`, `KindHostRuntimeStorageDemand`,
`ProvisionedKindHostRuntimeStorageDemand`, `EtcdLogicalDemand`/`ProvisionedEtcdLogicalDemand`,
`KubeletMappedFileDemand`, `PodRuntimeMetadataSource`, `KubeletRuntimeMetadataShape`,
planned-slot/observed-Pod-UID `KubeletRuntimeMetadataDemand`,
`ProvisionedKubeletRuntimeMetadataDemand`, `PodRuntimeRole`, `ImageStorageRole`,
`ProvisionedNodeImageStorageDemand`, and scope-indexed `ProvisionedNodeRuntimeStorageAccounting`,
pod-slot/CSI-attach capacity, `NodeLocalStorageCapacity`/filesystem layouts/
image artifacts, `FilesystemPresentation`/`VolumePresentation`/`BackingAllocationPolicy`, private
`BoundExecutionBody`/kind-indexed controller policies, `ExecutionTransitionSource`/
`PriorExecutionProvision`, `MaterializedExecutionInstance`/`ExecutionEpoch`/
`ProvisionedExecutionEpochs`,
state-indexed observed Pod/process identities, fixed/elastic `ProvisionedNodeTarget`,
`CompleteResourceReservation`/zero-capable release partitions, aggregate scheduler/host reservation ledger
types, child-indexed `ProvisionedSchedulerGuardConfig`, `CapacitySchedulerSystemDemand`/
`ProvisionedCapacitySchedulerSystem`, and mandatory reconciler-Lease demand,
`ControllerChildEnvelope`/`ProvisionedControllerChildren`, `PhysicalDiskPartition`, exact
`StorageMigrationDemand`/`ProvisionedStorageMigration`,
`SchemaMigrationDemand`/`ProvisionedSchemaMigration`,
`RegistryBackendMigrationDemand`/`ProvisionedRegistryBackendMigration`,
`CachePopulationDemand`/`RegistryStorageDemand`/`VaultStorageDemand`,
`ZooKeeperMetadataStoreDemand`/`ProvisionedZooKeeperMetadataStoreDemand`,
`PatroniSqlDemand`/`ProvisionedPatroniSql`,
`ObjectStoreDemand`/six-arm `ObjectStoreProducerDemand`/`ProvisionedObjectStoreLogicalPeak` plus
`ObjectStoreAdmissionGatewayDemand`/private gateway provision, provider root
backing/quota types,
`PulumiExecutionDemand`/`ProvisionedPulumiExecutionDemand`, `MonitoringWorkBudget`, closed
substrate-indexed `HostRuntimeEnforcement`,
`requests ≤ limits`);
`src/Amoebius/Capacity/Fold.hs` (`fits`/`podFits`/`carve`/`place`, reservation +
finite-limit/physical-peak proofs, the
host → VM → workload nesting, the §4.1 static/elastic branch);
`src/Amoebius/Capacity/Scheduler.hs` (complete reservation algebra; allocation-domain identity union;
Pod-qualified additive components; CSI volume identity; exclusive CUDA device rows; image-pull top-n;
static/foreign/resident/ledger/candidate fold; prior+desired child templates; aggregate-root byte/churn and
state transitions);
`src/Amoebius/Capacity/HostReservation.hs` (host reserve/launch/recovery/release ledger and retained
cache/log/local-artifact partitions);
`src/Amoebius/Capacity/NodeLocalStorage.hs` (logical pod-ephemeral fold, derived mapped-file/AtomicWriter,
closed layout routing, exact OCI content/snapshot joins, and model-versioned image peak);
`src/Amoebius/Capacity/RuntimeStorage.hs` (derive metadata components from the structural Pod graph; group
them by `KubeletNodefs | CriRuntimeRoot`; total role→layout-backing resolution; planned-epoch and
observed-snapshot node aggregates; qualified Pod/image component ownership; alias-aware backing grouping);
`src/Amoebius/Capacity/Storage.hs` (identity-named disjoint local pools, `StorageBudget`
fold + the two-ceiling Pulsar fold);
`src/Amoebius/Capacity/StorageGeometry.hs` (`bookKeeperPhysicalDemand`, `contentStoreLogicalPeak`,
`minioPhysicalDemand`, volume presentation/allocation rounding, `uniformStatefulSetClaims`,
`provisionStorageMigration`, `provisionSchemaMigration`);
`src/Amoebius/Capacity/ServiceStorage.hs` (exact cache, registry/rehome, ZooKeeper, Patroni, and Vault peaks);
`src/Amoebius/Capacity/Etcd.hs` (exact desired/live API-object transition and churn quota fit before physical
WAL/snapshot/defrag expansion);
`src/Amoebius/Capacity/PulumiExecution.hs` (deploy/plugin join and concurrent executor/workspace peak);
`src/Amoebius/Capacity/ProviderRoot.hs` (private VM/root-EBS high-water derivation and node-root quota);
`src/Amoebius/Capacity/Growable.hs`
(`Growable`/`ScalingPolicy`), `src/Amoebius/Capacity/StorageScaling.hs`
(`ProvisionedStorageScalingEnvelope`, `ObservedStorageScalingSnapshot`, `planStorageScaling`) —
target paths, not yet built.
**Blocked by**: Sprint 7.1 (the `Topology` `place` folds over); Phase 5 gate (the IR + decoder).
**Independent Validation**: a unit + property suite runs `fits`/`carve`/`place` over generated envelopes: a
feasible workload set yields a placement witness or a **sound growth envelope — where "sound" is fixed
concretely as: every pod fits at least one declared candidate including capability, finite limits, and
physical peaks, and the
worst-case instance count forced by atomic pods/anti-affinity stays within quota, verified against the
fixture's declared candidate set and quota, not merely that a `Right`-valued envelope was returned**; an over-committed one returns
`Left Overcommit`/`Left Unschedulable` naming the offending axis; the storage/Pulsar folds return `Left` on
an over-backing or un-tiered topic after deriving BookKeeper replication/recovery, MinIO
  erasure/healing/in-flight/orphan/presentation/rounding/uniform-claim peaks, registry upload/partial/rehome
  exposure, ZooKeeper log/snapshot/recovery, Patroni data/WAL/failover, schema old+new/temp/WAL,
  and Vault Raft/compaction/recovery/audit peaks. The node-local fold returns its specific structured rejection
for a missing OCI content/snapshot/model join, physical overrun, forbidden alias, swapped layout, or
unsupported `SplitImage`; provider-root construction rejects an under-sized instance store or a derived root
EBS request outside its separate byte/volume-count quota. The over-commit / over-backing / un-tiered negatives here assert **which
tag and which axis** they fail on (§M.8), each paired with a positive differing only in that one axis being
in-envelope. Generated host-only cases independently derive per-stage build concurrency/scratch/cache-write
peak, role-indexed named engine-process totals, rotated control-plane/worker storage/history fit, and
monitoring CPU/memory cost; dropping any
term makes the property red. Generated execution cases take the deployment-level
`FirstDeployment | UpdateFrom` source plus the desired `BoundExecutionSet`; an update resolves the exact prior
steady inventory from `ProvisionContext` before independently expanding desired units into identity-keyed
steady/rollout epochs and exercising the same epoch provisioner over controller-derived child units. They
prove every normalized controller policy is kind-valid before epoch construction, cover legal Deployment
one-sided pairs `{ 1, 0 }` and `{ 0, 1 }`, DaemonSet's exclusive Surge/Unavailable arms, serial StatefulSet,
finite Job waves/terminal retention, and supervised host replacement, and make every zero-progress/
kind-mismatch mutant red. They
exact-join every desired and prior materialized instance to its own source unit/revision/ordinal/full resource,
preserve added/new/changed/removed semantics, and include reachable empty initial/recreate transition maps.
They provision every resource in each epoch and reject a scalar peak, copied-new-as-old envelope, omitted
removed/replica/surge/old instance, invented first-deploy old row, omitted child, second controller-child
debit, or free webhook. Generated live-fold inputs additionally exact-join and union every observed old and still-terminating
   instance with desired instances before selecting the peak. Each planned Pod slot derives one model-pinned
   metadata shape; observed accounting instead keys the same structural source by authenticated Pod UID. The
   provision result derives component→`KubeletNodefs | CriRuntimeRoot`→layout-backing rows and a per-node,
   per-planned-epoch or per-observed-snapshot aggregate with an exact planned/observed domain witness, disjoint
   qualified Pod/image-component ownership, and one grouped debit per physical carve. Omitting the largest
   epoch's row, changing/omitting its model, dropping/swapping a role, resolving a role to the wrong backing,
   overlapping/leaking ownership, or making either SplitRuntime nodefs (kubelet role) or
   imagefs/containerfs (CRI role) one byte short rejects; `Unified` and `SplitImage` alias groups debit once.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md` (Phase-7 status backlink),
`documents/engineering/storage_lifecycle_doctrine.md` (§5.2 backing read-side),
`documents/engineering/pulsar_client_doctrine.md` (§6 two-ceiling read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.17–§3.21 layer reconciliation),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`resource_capacity_doctrine.md §3/§4/§4.1`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and the storage arithmetic of [`§5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)/[`§7`](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total):
implement the total capacity functions and storage/retention folds as pure, checked provision-seal operations — a
concrete all-resource pod→node witness for a fixed node set, a capability-aware growth envelope for an elastic one, genuine
subtractions for the single-owner carves, and logical→physical per-backing placement for durable storage — reading declared numbers
only (the substrate node inventory and PV sizes are owned elsewhere).

### Deliverables
- `Quantity` (refined non-zero, unit-tagged) for declarations plus
  `Residual = Zero | Remaining Quantity`/`AvailableCapacity` for subtraction results,
  `PodResourceVec = { cpu, memory, ephemeralStorage }`, the full
  pod/host-worker `ResourceEnvelope`, including non-empty lifecycle-tagged per-container resources, pod
  overhead, per-container runtime-memory working sets, a closed
  `ReadOnlyRootfs | WritableRootfs { allowance }` plus log allowance, and explicit
  `PodLocalStorageDemand` (bounded disk-backed volumes plus access-/persistence-indexed memory-backed volumes).
  Every private
  allowance must fit its own container ephemeral request/limit; disk-volume bounds plus the
  lifecycle-effective private allowance fit the pod request/limit. For tmpfs, the lifecycle fold assigns each
  resident volume to exactly one request carrier per concurrency epoch and proves live working sets + unique
  resident volume bounds fit the effective pod request/limit; every possible charged accessor's hard limit
  covers its writable volumes. Concurrent writers therefore do not double reserve and init→app persistence
  does not disappear. Each effective pod envelope is charged once. Typed durable demands and a closed cache
  demand distinguish an in-cluster cache-owner
  (the exact catalog-selected `CachePopulationDemand` is joined by identity/digest, resident objects are
  deduplicated by digest, and the largest finitely concurrent first-miss temporary peaks derive private
  `ProvisionedCacheDemand.derivedPeak`; then
  `derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`, with shared volume bounds + lifecycle-effective private
  allowances reserved by `ownerPod.ephemeralStorage.request ≤ limit` and the cache referencing that
  disk-backed volume by typed id, one node-ephemeral debit) from a native host-worker
  cache (`derivedPeak ≤ CacheBudget ≤ named host cache backing`), plus closed accelerator demand/offering types
  and the required `NoCpuOvercommit | BoundedCpuOvercommit RatioAtLeastOne` policy on every node capacity.
  `Capacity`/`Demand`/`Budget` keep `requests ≤ limits`. Every durable `DeclaredVolumeDemand` carries a
  `StatefulSetClaimSlot`, `BackingId`, logical bytes, direct/BookKeeper/MinIO geometry owner, and
  `VolumePresentation`; each volume-producing host/provider `StorageBacking` arm carries
  `allocation : BackingAllocationPolicy { minimumBytes, quantumBytes }`. The fold rederives geometry and
  filesystem overhead, rounds to backing rules, and alone constructs private
  `ProvisionedVolumeDemand.provisionedBytes`,
  which resolves exactly once and later renders unchanged; the provider-object `CloudQuota` arm remains a
  distinct bounded object-count plus model-indexed `Logical | Billed` byte ceiling rather than inventing a
  filesystem allocation rule or accepting an implicit unit conversion.
- The whole `BoundExecutionInventory` carries exactly one
  `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` transition source and the desired
  `BoundExecutionSet`. `FirstDeployment` resolves to an exact empty prior map; an update resolves the exact
  digest-keyed prior steady projection from `ProvisionContext`, including prior-only removed units. No bound
  value carries a prior `Provisioned*` record or an implicit latest generation. Every
  `BoundExecutionUnit` carries one private kind/resource-compatible `BoundExecutionBody`: Deployment with
  `ReplicaCardinality` plus `DeploymentRolloutPolicy`; StatefulSet with its native serial
  `StatefulSetRolloutPolicy`; DaemonSet with `NodeEligibilitySelector` plus
  `DaemonSetRolloutPolicy`; Job with completions/parallelism/backoff/finite terminal retention; or supervised
  HostProcess with `HostProcessCardinality` plus its replacement policy. Each kind has only its renderable fields; the CUDA Pod arm is
  structurally a DaemonSet with serial `OnDelete`, while CUDA/Metal host arms carry only their corresponding
  release/drain lifecycle. `NodeEligibilitySelector` is the canonical closed conjunction of typed engine-role,
  provider-class, site, accelerator-profile, and inventory-taint constraints; it contains no free-text
  selector or toleration. Topology-aware provision exact-joins every constraint, derives the eligible set,
  expands Deployment/StatefulSet replicas and Job active waves, derives one DaemonSet slot for every selected
  fixed NodeId or bounded elastic ProviderInstanceId/class slot, and resolves each HostProcess host→slot map;
  a planned elastic target retains its `PerInstanceKubeletFilesystemLayout` and
  `Elastic { instance, disk, carve }` runtime-storage backing references—never an invented concrete
  `DiskCarveId`. It is joined to an attested observed NodeId/backing/device materialization only at live
  readiness, where every template reference must map exactly once. A missing constraint target or missing, extra, or
  ineligible slot rejects. No caller may
  replace any arm with a scalar peak. `provision` alone expands the unit into
  `MaterializedExecutionInstance`s and complete `ExecutionEpoch`s. Every instance id is derived from and
  exact-joins one planned `(ExecutionUnitId, revision, ordinal, kind)` slot key; duplicate, orphan, wrong-revision, dropped,
  or swapped instances reject.
  The steady map contains every desired live service/daemon/host slot but may be empty after a Job-only
  deployment completes; empty-capable rollout maps enumerate every
  reachable old/new/surge step, including the first-deploy/recreate zero-live gap. Old rows come only from the
  resolved prior projection with their own revision and full resource envelope; unchanged rows dedup, changed
  rows follow the new policy, added rows have no old twin, and removed rows persist through
  apply-before-prune. The same fold's live input exact-joins observed surviving/terminating identities to the
  referenced prior generation and unions them with desired instances, with equal ids deduplicated once and no
  reclamation credit before observed deletion. Each epoch is provisioned over the full resource
  vector—CPU, memory, pod/CNI and CSI slots, logical and physical node storage, OCI content/snapshots/workspace,
  durable/cache demand, accelerator devices plus all identity-complete owner residency epochs, and every
  execution/admission envelope—then the componentwise peak is
  selected; a CPU-only or steady-only multiplier is not a witness. Because terminating population is not a
  trustworthy author scalar, the fold derives `ProvisionedExecutionSchedulingGuard` quota, source/revision
  admission, and exact scheduler-reservation projection. The pure scheduler model seals prior+desired,
  controller-child-indexed candidate templates and one aggregate root-ledger transaction:
  static/bootstrap, foreign, resident, all active entries, and the candidate re-fold together. Additive
  CPU/memory/logical-ephemeral/Pod-CNI rows are Pod-qualified; CSI attachments union by
  `(node,driver,VolumeIdentity)`; OCI/snapshot identities union once per physical allocation domain; pull
  workspace is the policy top-n; distinct CUDA owners cannot share a device. The live same-binary role
  (implemented in Phase 16) performs Reserved→BindingInFlight→Bound around Kubernetes Binding, keeping unknown
  outcomes charged. Ordinary/CUDA/Job release partitions credit only separately observed axes, and physical
  artifacts stay in the root resident baseline until deletion/GC. A ledger row whose Pod has disappeared is
  not dropped as an orphan: its Reserved/BindingInFlight/Bound/Terminating/TerminalRetained state selects the
  exact full or retained `LedgerOnlyAbsentRecovery` debit until state-specific release/cleanup CAS. Changed observed/root/config/capacity state
  invalidates the token.
  A private
  `ControllerChildEnvelope` remains
  the descriptor/source-expansion explanation: its children lower to these same kind-indexed units and epochs, and
  its witness must exact-join them but is never a second resource debit.
- Each `NodeCapacity.localStorage` carries logical pod-ephemeral allocatable separately from physical
  `KubeletFilesystemLayout`, a pinned `NodeImageStorageModelVersion`, a pinned
  `kubeletMetadataModel : KubeletRuntimeMetadataModelVersion`, and enforced
  `Serial | BoundedParallel n` pull policy. Each platform-selected `ImageArtifact` exactly joins its OCI index,
  child manifest, config, and compressed layers by digest/stored bytes and its snapshot chain by id/unpacked
  bytes. Per node, the fold unions persistent content by object digest and snapshots by chain id, applies the
  pinned snapshotter metadata/active-snapshot model, and adds the largest `n` missing-image pull/import
  workspaces. Every Pod `ResourceEnvelope` carries a byte-free `PodRuntimeMetadataSource` containing its exact
  non-empty network-attachment ids and container→volume mount references. After execution-instance expansion,
  the fold combines that source with the Pod's container/volume inventories to derive one
  `KubeletRuntimeMetadataShape`. Planned accounting wraps it with `PlannedExecutionSlotId`; live accounting
  wraps it with authenticated `PodUid` plus `ObservedExecutionSourceWitness`. Planned capacity identities are
  never reused as live Pod identities. The shape carries exact sandbox, Pod-directory, runtime-state,
  CNI-state, volume-metadata, and mount-metadata counts plus the target's pinned model; there is no authorable
  byte total or route.

  The private `ProvisionedKubeletRuntimeMetadataDemand` applies that model to derive a non-empty component map,
  assigns every component exactly one `PodRuntimeRole` (`KubeletNodefs | CriRuntimeRoot`), proves the per-role
  sums, resolves each role through the selected layout, and proves the grouped physical-carve debits. Thus
  `Unified` resolves both roles to nodefs; `SplitRuntime` resolves kubelet-owned components to nodefs and
  CRI-owned components to imagefs/containerfs; `SplitImage` resolves both Pod-runtime roles to
  nodefs/containerfs. Aliased roles are summed before their backing is checked once. They are never repeated as
  logical Pod ephemeral storage.

  For every planned epoch fingerprint, pure `provision` builds one
  `ProvisionedNodeRuntimeStorageAccounting` per node. The same pure fold, invoked by snapshot-bound live
  preflight, builds the observed-inventory-fingerprint form. Its exact accounting-id domain equals the assigned
  planned slots or eligible observed Pod UIDs respectively; its qualified `(accounting id, component id)` keys are disjoint
  from and exhaustive with the node image-model component keys; and its final backing map groups the combined
  metadata and `ProvisionedNodeImageStorageDemand` by physical carve exactly once. A component hole, overlap,
  role swap, scope/domain mismatch, or alias double debit has no provisioned representation.
  `PendingUnscheduled` is API-only and creates no node row; `Reserved` and an unbound/unknown
  `BindingInFlight` spend the planned placed vector in the scheduler ledger. A confirmed Bound Pod whose
  ledger still says `BindingInFlight` enters the typed `BindingRecovery` arm and instantiates an observed-UID
  row immediately, as do `Bound`/`Terminating` and terminal-retained axes. A bound UID
  exact-joins its reservation so the same components are never debited as both planned and observed.
  Logical pod ephemeral always proves disk `emptyDir` + logs + writable layers + mapped files
  within the rendered pod/node values. Physical operands are then grouped exactly once by layout: `Unified`
  routes all Pod/image/snapshot/workspace bytes to nodefs; `SplitRuntime` routes disk volumes/logs/mapped files
  to nodefs and writable layers/images/snapshots/workspace to imagefs/containerfs; `SplitImage` routes complete
  logical Pod ephemeral to nodefs/containerfs and image content/snapshots/workspace to imagefs. Only aliases forced by the arm are legal,
  nodefs/imagefs swaps reject, and v1 containerd cannot construct the `SplitImage` support witness.
- `BuildExecutionEnvelope` with a closed acyclic per-platform stage graph, per-stage host/engine-VM CPU/memory
  reservation+ceiling, intermediate and cache-write peaks, named `BuildScratch`/cache backings, and separate
  finite architecture/stage concurrency; observed cache residents plus the derived concurrent write delta fit
  the cache budget/backing. `EngineSystemReserve` is the exact role-indexed non-empty named static-process
  CPU/memory set plus a `ControlPlane | Worker` storage demand. Kind expands every ordinal node-container;
  every rke2 server/agent proves its own reserve. The control-plane first exact-joins serialized desired/live
  old/new/apply Kubernetes objects plus bounded revision/Lease/Event churn through
  `EtcdLogicalDemand` and proves the derived MVCC peak fits `backendQuotaBytes`. Its separate physical formula
  then consumes enforceable
  `etcd { backendQuotaBytes, maxWalFiles, retainedSnapshots, SerializedSnapshotAndDefrag, storageModel }` and
  derives backend + WAL segment/overshoot/preallocated-next + retained snapshot/snapshot-save temporary +
  serialized defrag old/new peak (Events included once), plus
  `(maxBackups + 1) × maxBytesPerFile` audit/runtime logs; Event/audit retention covers history. A missing
  process/headroom field is not a zero.
- `MonitoringWorkBudget` with finite workflow/rule/series/sample-rate/interval/CPU/memory/retention,
  structural query concurrency/series/samples/range/timeout bounds, claim/backing/presentation, and pure
  version-indexed evaluation/TSDB/query cost primitives. Derived
  Prometheus compute and presentation-rounded volume demand cannot bypass `place`/storage provisioning.
- `fits`/`podFits`/`carve`/`place` — fixed topology → first-fit-decreasing witness; elastic topology → floor
  witness + per-class effective capacity after topology-expanded per-node units + a sound candidate-class
  count cover within each `maxCount` + selected cover within the outer instance/vCPU/device/durable and
  separate node-root-EBS byte/volume-count quotas. Both branches spend one pod slot per simultaneously live
  pod and driver-scoped unique-PVC attach slots.
  The returned witness proves both request
  reservation and finite-limit/physical-peak fit, including memory/ephemeral limits,
  storage locality/pools, exact whole
  accelerator devices, identity-complete residency demand, every policy-permitted coexistence epoch's
  per-device assignment/aggregate, explicit shard-byte assignment, and required peer/NVLink graph.
  Wholesale accelerator ownership remains, but its one
  linux-cuda owner pod's exactly-once named owner container still receives a derived extended-resource
  allocation while the pod receives the required affinity.
- Nested/disjoint physical-disk arithmetic: raw `VmDiskCarve` has
  `{ id, presentation : FilesystemPresentation, allocation, guestSystem, kubelet }` and no editable aggregate
  bytes; `Block` cannot represent a guest root. On Lima/WSL2 the
  fold derives required usable bytes from guest OS reserve plus the unique layout-routed kubelet filesystem
  peaks, applies presentation overhead and allocation minimum/quantum, constructs private
  `ProvisionedVmDiskCarve`, and charges its provisioned high-water once beside retained/native-cache/
  role-tagged-host-storage pools to the physical disk. Direct Linux groups each routed operand by the actual
  backing and charges every unique carve once; only the selected layout's forced alias may share one carve.
  A `PhysicalDiskPartition` exposes `allocatableRawBytes`, the finite raw physical boundary after unmanaged-
  host reserve but before every amoebius child carve, including `systemReserve`. A parent-indexed
  `NamedDiskCarve PhysicalRawExtent` either supplies exact raw `parentBytes` or presented usable intent whose
  presentation/allocation geometry privately derives `ProvisionedNamedDiskCarve.parentDebitBytes`; a
  `NamedDiskCarve VmGuestUsableExtent` debits only the usable-byte budget inside its already provisioned VM.
  The fold therefore proves two separate equations: `guest OS/system parent debit + Σ unique layout usable
  parent debits ≤ requiredUsableBytes` for each VM, then `systemReserve raw parent debit + Σ unique VM
  provisionedBytes + Σ unique direct-node/retained/cache/host-storage raw parent debits ≤
  allocatableRawBytes` for the physical partition. The parent index prevents either unit entering the other
  sum. Each identity is charged once; `systemReserve` is not subtracted to manufacture the boundary and is not
  repeated in the child sum, and two aliases of one carve cannot spend it twice.
  The in-cluster cache owner's `emptyDir` is already inside logical pod ephemeral and is not added again;
  provider durable block storage remains separate. Provider root policies likewise require
  `FilesystemPresentation`; fixed `InstanceStore` bytes must cover
  system reserve plus all unique carves after presentation costs, while `EphemeralRootEbs` derives private
  `ProvisionedNodeRootVolumeRequest { volumeType, requiredUsableBytes, presentation, allocation, sizeGiB,
  provisionedBytes, witness }` from the same high-water and its
  catalog-cross-checked volume type/presentation/allocation rules; it debits `nodeRootStorage`, never durable
  quota. Physical backing/carve ids are unique, every node/backing reference resolves exactly once, every logical
  `BackingId`/`CacheBackingId`/`HostStorageBackingId` maps injectively to the correct role carve, and an
  alias/orphan/role mismatch rejects.
- `allocateForestSupply` over the parent-owned ledger, carving owner-distinct per-cluster host/account/backing
  budgets before each single-cluster `place`. A `Managed Eks.account : CloudAccountId` must exact-join the
  same `SharedSupplyLedger.accounts` entry used by credentials and observed provider quota; sibling cluster
  carves on one account accumulate against that one residual. A missing/mismatched account, independently
  treating two declarations as the full account ceiling, or reusing co-resident engine/VM/storage/host-worker
  and physical-accelerator identities rejects before either cluster can spend them.
- The closed `StorageBudget`/`Growable` unions (no unbounded / no bare-unbounded arm) and the aggregate
  backing fold. Every producer's required `StorageBudgetId` resolves once to its selected backing/quota owner.
  A private `ProvisionedStorageScalingEnvelope` retains the exact budget/backing, finite backing-indexed
  policy, and desired provisioned demand projection, but no observation or speculative transition. The pure
  `planStorageScaling` consumes a complete fingerprinted `ObservedStorageScalingSnapshot` and returns only
  `NoChange | AllocateWithinRetainedCarve | CreateProviderCapacity | ShrinkByVerifiedMigration`, with current
  allocation, residual/quota, and old+new migration high-water witnessed. Phase 7 has no mutation capability;
  Phase 16 validates the generic live action, while Phases 17 and 30 enact the retained and provider arms.
  `bookKeeperPhysicalDemand` expands the four required positive logical-hot/headroom fields
  through write-quorum placement, journal/index reserve, and **every** failure/re-replication subset derived
  from its finite fault bound. `provisionObjectStoreProducer` covers the closed app/content/registry/
  Pulsar-offload/Pulumi-checkpoint/control-plane-state six-arm union: it retains exact physical resident ids,
  structural future/transient extents, per-writer admission witnesses, and complete producer-specific
  retention/rate/failure operands. The merged writer set derives and places the object-write gateway's complete
  pod envelope.
  Source↔producer inventory equality is mandatory; `mergeObjectStoreLogicalPeaks` rejects identity/size or
  admission conflicts and preserves every writer before
  `minioPhysicalDemand` expands each object through stripe padding, data+parity shards, metadata, healing
  workspace, and every per-set plus cross-set failure combination derived from its finite fault bound.
  Each logical demand then receives its `Block` or version-pinned filesystem overhead and rounds up to the
  backing's allocation minimum/quantum before `uniformStatefulSetClaims` groups it to
  a private member map plus one uniform size and
  `perBackingDebit[backing] = max ordinal provisioned demand × members on that backing`; no aggregate can
  move spare bytes between backings. `registryStoragePeak` exact-joins all selected OCI objects,
  deduplicates by digest, and adds structured bounded concurrent upload workspace plus failed-partial extents
  retained for the declared GC horizon; only its interim filesystem projection uses scalar `derivedPeak`.
  `vaultStoragePeak` exact-expands bounded persisted versions/live leases through the
  pinned Raft record/WAL/snapshot model and charges old+new compaction overlap, recovery headroom, and
  `(maxBackups + 1) × maxBytesPerFile` audit rotation to its named backing. No caller-authored peak, scenario
  list, logical aggregate, immediate-GC credit, or unequal ordinal sum is a witness. The two-ceiling Pulsar fold uses that
  physical BookKeeper witness plus the durable-total offload target, so a time-only or physically
  hot-tier-over-bookie topic decode-rejects.
  Independently, `provisionZooKeeperMetadataStore` derives persistent/session paths, transaction logs,
  snapshots and failure-recovery overlap per member and places every member pod/volume before broker startup.
  `provisionPatroniSql` derives data/WAL/checkpoint/failover peaks and operator child epochs.
  It also resolves the database `StorageBudgetId` and derives/places the bounded SQL-mutation admission proxy
  from connection/transaction/WAL operands.
  Storage, registry-backend, and schema transitions each fit old+new+workspace/temp plus their complete
  executor pod before any create/copy/DDL; failed verification retains every old/new partial commitment.
- An in-file honesty note: the union *shapes* are type-foreclosed (Phase 4/6); every capacity/retention **sum**
  here is a total checked provision-seal operation, sound-not-complete for the compute bin-pack; the fold re-runs after
  any `Growable` growth so growth never silently invalidates an earlier check.

### Validation
1. A feasible input yields a witness or a sound envelope (soundness fixed as the §4.1 floor witness,
  topology-expanded effective candidate capacity, candidate capability/finite-limit/physical-peak fit,
  per-class
   `maxCount`, and outer-quota conditions holding with every class sharing the one profile-keyed accelerator
   cap, per this sprint's Independent Validation); an over-committed
   host/VM/cluster, an over-backing store, a node-local content/layout/model failure, an under-provisioned or
   over-quota provider root, or an un-tiered topic returns the tagged `Left` naming the offending axis;
   exact-fit `fits`/`carve` returns `Right Zero`, a second debit from that residual rejects, and the folds never
   throw. Generated kind-indexed execution-unit cases independently exact-fit and miss by one on each full steady/rollout/
   live epoch, and the suite rejects a copied-new-as-old envelope, dropped removed/desired/surge/old/terminating
   instance, invented first-deploy predecessor, implicit-latest lookup, any broken prior/desired
   source-unit/revision/ordinal/resource join, any omitted reachable empty epoch, and any internal attempt to
   construct rolling
   `{ maxSurge = 0, maxUnavailable = 0 }`. Both legal one-sided rolling controls reach epoch construction.
   A terminating-old-at-capacity case proves the derived scheduler guard leaves a replacement Pending until observed
   disappearance, and a post-validation terminating-set change invalidates the token.
   Runtime-metadata cases exact-fit every grouped backing, fail with SplitRuntime nodefs one byte short for a
   kubelet component or imagefs/containerfs one byte short for a CRI component, and reject a missing/mismatched
   model, a dropped/swapped role, a planned/observed domain mismatch, a Pod/image ownership hole/overlap, an
   alias double debit, or a fold that omits the largest simultaneous epoch's metadata. `Unified` and
   `SplitImage` alias controls accept only when the grouped carve is charged once. A partition case satisfies
   `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ==
   allocatableRawBytes`, while each VM separately exact-fits its nested usable-byte equation; either parent's
   one-byte-short pair rejects, and the no-double-debit property catches an alias, VM high-water, or
   `systemReserve` charged twice.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.3: QuickCheck properties — soundness, totality, elementwise compatibility 📋

**Status**: Planned
**Implementation**: `test/dsl/CapacityTopologyProps.hs` (QuickCheck generators for `Topology` / envelope /
workload sets + the property battery) and `test/dsl/RuntimeStorageProps.hs` (planned-slot and observed-Pod-UID
metadata shapes, component-role grouping, layout resolution, qualified Pod/image ownership, per-scope node
aggregation, reservation/observed no-double-debit, and alias/one-byte-short mutants), reusing the Phase-6 property harness — target paths, not yet built.
**Blocked by**: Sprint 7.1, Sprint 7.2.
**Independent Validation**: `cabal test dsl-spec` runs the property battery green — the fold/relation
soundness, totality, headroom-non-negativity, carve-subtraction, elementwise-compatibility, and Pulsar
two-ceiling properties hold over generated inputs, each meeting its committed `cover`/`checkCoverage` minimum
(≥30% rejecting, ≥30% accepting per fold; §M.4); and the **committed per-fold seeded-mutant battery of [Gate integrity](#gate-integrity) — one
mutant each for `fits`, `carve`, fixed `place`, elastic `place`, storage `Σ`, each Pulsar ceiling, elementwise
compatibility, and `mkRke2` distinctness, plus the per-axis and per-eligibility validator mutants — turns the
suite red individually** (§M.2), not merely one hand-picked strawman.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`,
`documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/testing_doctrine.md` (the
Register-1 property register), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) §2 (Register 1) and the honesty
limit of [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
express the capacity fold and the topology relation as QuickCheck properties. For the checks that are decidable
in **both** directions — the storage `Σ ≤ backing` sum and the elementwise-compatibility relation — assert the
stronger **accept ⟺ in-envelope equivalence** (the fold accepts *exactly* the in-envelope inputs) over generated
corpora, not merely soundness. Reserve **soundness-only** (the fold never admits an over-committed spec, but may
reject a packable one) for the single sound-not-complete check, compute `place`
([`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)),
and never claim completeness there.

### Deliverables
- Capacity properties: `fits d c = Right h ⟹` `d + h` reconstructs `c` per axis with no underflow; `carve` is
  total subtraction over zero-capable residuals, including a generated exact-fit case that returns `Zero` and
  refuses a one-unit second debit; a returned `place` witness is judged sound by an **implementation-independent witness
  validator** (§M.3) that reads the generated fixture's declared allocatables directly and **never calls
  `podFits` or `place`**: for every node in the returned `Placement`, it recomputes effective
  app/sidecar/ordinary-init/restartable-init-sidecar requests and limits under the pinned Kubernetes semantics
  plus pod overhead; asserts **Σ requests ≤ allocatable** for CPU/memory/ephemeral storage;
  asserts **Σ effective CPU limits ≤ the node's finite policy-derived CPU-limit budget**;
  asserts **Σ effective memory/ephemeral limits ≤ allocatable**; validates durable/native-cache pool identity
  and residual bytes; exact-joins cache catalog assets, deduplicates residents by digest, adds the largest
  finitely concurrent first-miss temporary peaks, and validates
  `ProvisionedCacheDemand.derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`; proves the pod's ephemeral
  request covers all disk-backed volume bounds plus lifecycle-effective private allowances, proves each
  `ReadOnlyRootfs` renders/charges no writable layer while `WritableRootfs` has an explicit allowance, proves
  each private allowance fits its own container request/limit, and proves that envelope was charged exactly once to
  node ephemeral; resolves every memory-volume access id, derives lifecycle concurrency epochs, proves exactly
  one reservation carrier per resident volume/epoch and
  `Σ live runtime working sets + Σ unique resident volume bounds ≤ effective pod memory request/limit`, and
  checks every possible charged accessor's hard limit; rederives every durable `DeclaredVolumeDemand` through
  its geometry, StatefulSet claim slot, `VolumePresentation` overhead, backing minimum/quantum, and exactly-one
  backing/carve, and rejects an understated-physical
  mutant because raw input has no accepted physical override; resolves the whole-deployment
  `FirstDeployment | UpdateFrom` source to an exact empty or digest-keyed prior steady map, then independently
  expands every desired `BoundExecutionUnit` by `revision` plus its kind-indexed controller body: Deployment
  cardinality/rollout, StatefulSet serial rollout, DaemonSet selected-node/rollout, finite Job execution, or
  supervised host replacement.
  It rederives exact prior and desired
  `(sourceUnit, revision, ordinal, resource) → MaterializedExecutionInstance` equality and evaluates complete
  steady, empty-capable rollout, and normalized-live epochs. The live epoch exact-joins every observed old and
  still-terminating identity to the referenced prior generation before unioning desired demand. It derives
  the quota/admission/CAS-before-Binding scheduler guard that prevents binding a replacement while that union
  would exceed any provisioned axis. It lowers every private
  `ControllerChildEnvelope` to that same kind-indexed unit/epoch mechanism, checks the controller source witness,
  and places child Pod/PVC demands plus validating-webhook execution exactly once rather than accepting a
  caller scalar or a second controller-only debit. For every planned Pod slot in each epoch, it independently
  rebuilds `KubeletRuntimeMetadataShape` from the structural sandbox, Pod-directory, runtime, CNI, volume, and
  mount counts under `NodeCapacity.localStorage.kubeletMetadataModel`; the live variant uses authenticated Pod
  UIDs and source witnesses. It derives component→Pod-runtime-role maps, resolves roles through the selected
  filesystem layout, exact-joins the planned/observed node domain, combines qualified Pod components with the
  disjoint image-model component domain, and groups each physical carve once; validates
  accelerator family, whole device count, exact source/workload and policy-class domains, all derived
  coexistence epochs, residency placement, per-device aggregation, shard-id uniqueness/count/byte-sum, and
  required interconnect against each device's **net allocatable VRAM** after its mandatory driver/runtime
  reserve, never its raw total; resolves the correct OCI index and platform child manifest,
  config, and compressed layers for each assigned node OS/arch, exact-joins snapshot chain/unpacked costs,
  rejects conflicting or missing metadata/model entries, unions content by object digest and snapshots by
  chain id, applies the pinned image storage model, adds the largest `n` simultaneous new-image workspaces,
  independently routes logical pod and image operands under `Unified | SplitRuntime | SplitImage`, verifies
  only forced aliases and runtime support, and proves every physical backing peak fits; and
  checks every assigned pod's taints/affinity. Candidate validation independently checks duplicate
  disk/carve/accelerator-slot template ids, unresolved/swapped/forbidden-alias filesystem references, image
  model/runtime support, and root-backing arithmetic. For every `PhysicalDiskPartition` it recomputes the
  post-unmanaged-host `allocatableRawBytes` boundary, derives every presented physical carve's private raw
  parent debit, and proves `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other
  raw parent debits ≤ allocatableRawBytes` with no cross-unit or duplicate identity debit. It separately
  proves every VM's `VmGuestUsableExtent` carves fit its `requiredUsableBytes`, and derives raw VM and
  ephemeral-root-EBS usable/
  provisioned high-water through presentation and allocation rules, rejects a raw authored aggregate,
  checks an instance store against its fixed bytes, and charges root EBS bytes plus volume count only to
  `nodeRootStorage`; it also checks accelerator-link endpoints/topology and the raw/reserve/allocatable VRAM
  invariant before any cover can use the class. Thus two 3-CPU pods on one 4-CPU node, a disk-cache overflow,
  or one unshardable 40-GiB model on 2×24-GiB devices is rejected independently of `place`.
  `place` may return `Left` on a packable spec but never a witness the independent validator rejects
  (the one-directional soundness caveat); the fold re-runs consistently after a `Growable` growth. This
  validator carries **one seeded mutant per resource/capability axis** (drop CPU, memory,
  ephemeral storage, pod-slot/CSI-attach fit and unique-PVC dedup, CPU-limit policy,
  finite-limit/physical-peak fit, native cache pool,
  exact cache population/first-miss
  peak and in-cluster cache nesting/single-charge, memory-backed-volume nesting/single-charge, durable
  presentation/backing minimum/quantum resolution, object-store producer inventory/budget/admission/extent
  merge, kind-indexed execution controller/rollout/live-epoch expansion and source/revision/ordinal equality,
  controller child lowering/source witness/single debit, runtime-metadata shape/component/role derivation,
  planned-slot/observed-Pod-UID domain equality, role→layout-backing resolution, qualified Pod/image ownership,
  and alias-aware node backing grouping,
  storage/registry/schema migration old+new+workspace/temp/WAL/executor transitions,
  ZooKeeper member/log/snapshot/recovery and Patroni data/WAL/failover derivation,
  Pulumi deploy/plugin/concurrency executor envelope,
  node-local mapped-file/OCI-object/snapshot/model/layout accounting, etcd logical API-object/churn quota fit,
  root-filesystem arm projection, host-enforcement/substrate compatibility, accelerator family/count,
  source/workload/policy-domain equality, complete coexistence-epoch derivation, residency/per-device
  aggregation, shard/link topology,
  the raw→reserve→allocatable boundary, the physical-partition
  post-unmanaged-reserve→`allocatableRawBytes` boundary, parent-unit separation, and unique-child debit, or any candidate-template
  uniqueness/reference/layout/root-backing/root-quota arithmetic check), one for each durable geometry obligation (BookKeeper
  quorum/recovery and complete scenario derivation; MinIO stripe/parity/healing and complete cross-set
  scenarios; concurrent/orphan horizon; uniform claim rounding), one each for source-producer arm omission,
  physical-object identity/size conflict, same-byte/different-object-count geometry, per-writer admission
  omission (including the control-plane-state sixth arm), Pulsar segment-rate/lag/failure exposure,
  Pulumi field/encryption/revision/failure exposure,
  registry object/upload/partial
  exposure and Vault persisted/Raft/compaction/recovery/audit derivation, and one per
  host-only provision (drop a build stage, scratch/cache-write/concurrency term, or observed cache resident;
  collapse an engine process map to an aggregate; double-charge Events outside etcd; omit WAL preallocation/
  overshoot, snapshot-save, or defrag overlap; omit one control-plane/worker storage/retention term; drop kind
  host OCI content, per-ordinal active snapshots/writable layers, pull workspace, or data-root identity; or bypass
  monitoring evaluation+query/proxy compute or TSDB presentation derivation; or drop a registry/object-write
  admission-gateway envelope), and one per
  eligibility clause (taint, affinity), each individually required to turn the suite red (§M.2,
  [Gate integrity](#gate-integrity)).
- Execution/metadata/partition boundary properties are explicit, not implied by the general placement check.
  For every legal Deployment, StatefulSet, DaemonSet, Job, and HostProcess body, independently enumerated prior and desired
  source-unit/revision/ordinal/resource maps must equal the materialized maps in both directions for steady,
  every empty-capable rollout step, and a normalized live old+terminating union. Cases cover exact-empty first
  deployment, the recreate zero-live gap, different/larger prior envelopes, unchanged/changed/added/removed
  units, and exact-generation lookup. Generated cases exact-fit the largest epoch on every resource and have a
  minimally differing one-unit-short case. `mutant_copy_new_execution_as_old`,
  `mutant_drop_removed_execution`, `mutant_invent_first_deploy_old`,
  `mutant_resolve_latest_execution`, `mutant_drop_execution_replica`,
  `mutant_drop_execution_surge`, and `mutant_drop_execution_old_revision` each turn the suite red, as do an
  omitted empty step, swapped revision/ordinal/PVC child, a guard that admits a replacement while a terminator
  consumes the last unit, two concurrent candidates that each read the same pre-reservation residual,
  non-aggregate/per-record CAS, timeout-based reservation release, crash/lost-response release from
  BindingInFlight, direct-nodeName/post-bind-delta bypass, a post-validation
  terminating/pending/resident/config set change that fails to invalidate the token,
  and a second
  controller-child debit. Reservation-algebra controls prove same-node/same-digest content unions once,
  two-node/same-digest content debits twice, equal bootstrap/workload image extents share once, distinct
  Pod-UID components add, same-PVC CSI dedups while different PVCs add, conflicting extent bytes/backing/model
  reject, device-owner intersection rejects, and terminal one-slot partition releases exactly one slot while
  retaining zero-slot physical bytes. Mutants that credit lingering content/snapshots after Pod absence or
  CUDA device rows while an NVML process lives turn red. For runtime metadata, the reference fold derives every structural count and pinned
  model per planned slot or authenticated observed Pod UID, every component's exact role and bytes, the total
  role→layout-backing resolution, and each scope-indexed node aggregate. It proves planned/observed domain
  equality, disjoint/exhaustive qualified Pod/image ownership, and one grouped debit per carve. It exact-fits
  SplitRuntime nodefs and imagefs/containerfs independently and rejects either one byte short, while Unified
  and SplitImage alias controls charge the shared carve once. `mutant_drop_largest_kubelet_metadata`,
  `mutant_missing_kubelet_metadata_model`, role-drop/swap, backing-swap, scope/domain, ownership-hole/overlap,
  reservation/observed double-debit, and alias-double-debit mutants each turn red. For each
  `PhysicalDiskPartition`, the reference starts from `allocatableRawBytes` after unmanaged-host reserve,
  derives any presented usable physical carve to a raw `parentDebitBytes`, and proves exact fit of
  `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits`; each
  VM separately exact-fits its nested usable-byte sum. Either parent's one-byte-short pair rejects, while
  `mutant_partition_mixes_vm_usable_bytes`, `mutant_partition_drops_system_reserve`, and
  `mutant_partition_double_debits_child` each turn red.
- Equivalence (both-directions) properties for the complete checks: the storage/retention fold accepts
  **iff** an independent implementation derives the complete fault-policy scenario product, replication/
  erasure/metadata/recovery/healing/concurrent/orphan peaks, presentation overhead, allocation rounding,
  registry upload/partials/rehome, ZooKeeper and Patroni recovery, schema-transition high-water,
  Vault Raft/compaction/recovery/audit peaks, uniform claim-template debit, and every
  resulting per-backing value is within capacity. The node-local fold accepts **iff** every exact OCI content/
  snapshot/model join exists, the selected layout's alias/support rules hold, and the independent logical plus
  physical backing sums fit. Provider root construction accepts **iff** the derived VM/root usable and rounded
  provisioned high-water fits its instance-store provision or the separate root-EBS bytes/volume-count quota;
  the Pulsar two-ceiling fold accepts **iff** both the physically
  expanded hot tier and durable-total ceiling hold; **the elastic `place` branch accepts iff the independent floor witness is sound, every remaining pod
  fits an effective candidate after per-node-unit subtraction, the independent class-count cover stays within
  every `maxCount`, and its independently computed instance/vCPU/device/durable/node-root-EBS totals stay
  within their distinct quotas** —
  each over generated corpora that reach both directions, not just a fixed fixture
  set (the `accepts ⟺ in-envelope` strengthening). Each equivalence and soundness property carries QuickCheck
  `cover` / `checkCoverage` obligations forcing **≥30% rejecting (out-of-envelope) and ≥30% accepting
  (in-envelope) generated inputs per fold, the suite failing when the coverage minimum is unmet** (§M.4) — so a
  generator that emits near-constant in-envelope inputs cannot vacuously pass the reject direction. The
  reference side of every `accepts ⟺ in-envelope` property is a **committed hand-authored envelope predicate
  authored in Phase 0, distinct from the fold under test** (§M.1, §M.3), never the fold's own comparison.
- Topology properties: the elementwise compatibility fold accepts a heterogeneous multi-substrate fixed/elastic
  `NodeSupply` iff every fixed/floor node and candidate class is compatible and returns the exact incompatible
  entry set otherwise; `mkRke2` rejects a duplicate floor `HostId`; kind cardinality is fixed at one host
  regardless of `replicas`; an elastic supply with no candidate or no finite quota has no constructor. A
  two-instance cover from one candidate template produces two disjoint concrete disk/carve/device identity
  sets, each symbolic path qualified by cluster/class/cover-slot/full template path; mutants that copy
  template ids as physical ids, accept duplicate template ids, leave a filesystem reference unresolved, force
  an alias not permitted by its layout, swap nodefs/imagefs, accept unsupported `SplitImage`, under-size an
  instance-store root, author rather than derive a VM/root-EBS aggregate, skip presentation/allocation
  rounding, debit root EBS from durable quota, omit/mismatch the authored provider account, give two sibling
  carves the whole shared account ceiling, or overstate accelerator allocatable VRAM must be rejected by
  the independent ledger. Duplicate accelerator-profile quota rows reject at normalization, two candidate
  classes drawing one profile cap are summed rather than each receiving the whole ceiling, and root-EBS
  bytes/volume counts aggregate independently from durable storage.
- A totality guard discharged **both ways** (ambiguity resolved): (a) a compile-time exhaustiveness gate —
  every `Amoebius.Capacity.*` / `Amoebius.Dsl.Topology` fold module compiles under
  `-Werror=incomplete-patterns` / `-Werror=incomplete-uni-patterns` with no `error` and no partial
  `head`/`fromJust`; **and** (b) the sampled QuickCheck run in which every property generator exercises the
  fold on arbitrary constructible inputs and no input yields an exception, `error`, or partial match. A green
  sample alone does not satisfy this guard.

### Validation
1. The property battery is green with every fold meeting its coverage minimum; and **each committed mutant in
   the per-fold seeded-mutant battery ([Gate integrity](#gate-integrity)) — including the storage `Σ`, both Pulsar ceilings, `carve`, elastic
   `place`, and `mkRke2` distinctness mutants, not only the compute-axis and compatibility ones — makes a
   property red when re-run individually** — the properties have teeth on every fold, not two.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.4: The capacity/topology fold-negative corpus + the gate 📋

**Status**: Planned
**Implementation**: `dhall/examples/{illegal_engine_substrate_mismatch,illegal_rke2_reused_host,
illegal_overcommit_host,illegal_overcommit_vm,illegal_overcommit_cluster,illegal_store_over_backing,
illegal_topic_time_only_offload,illegal_hot_tier_over_bookie,illegal_untolerated_taint,
illegal_pod_ephemeral_overcommit,illegal_hard_ceiling_overcommit,illegal_cpu_limit_over_policy,
illegal_memory_backed_underreserved,illegal_tmpfs_init_persistence_underreserved,
illegal_node_local_storage_over_backing,illegal_disk_backing_alias_double_spend,
illegal_filesystem_layout_alias,illegal_filesystem_layout_swapped,
illegal_image_content_join_missing,illegal_image_snapshot_join_missing,
illegal_image_storage_model_missing,illegal_split_image_unsupported,
illegal_provider_instance_store_root_underprovisioned,illegal_provider_node_root_ebs_over_quota,
illegal_control_plane_storage_transition_overrun,
illegal_cache_over_local_pool,
illegal_incluster_cache_bound_mismatch,
illegal_cuda_on_cpu_target,illegal_accelerator_count_shortage,illegal_accelerator_vram_fragmentation,
illegal_accelerator_vram_reserve_boundary,
illegal_apple_metal_profile_mismatch,illegal_shared_accelerator_double_owner,
illegal_elastic_pod_exceeds_largest_candidate,
illegal_elastic_class_max_exhausted,illegal_elastic_per_node_overhead_unplaceable,
illegal_elastic_worst_case_instances_over_quota}.dhall` (the `provision-seal` fold negatives, including the
four elastic-branch negatives) + reuse of
`legal_multisubstrate_cluster`/`legal_managed_eks` plus
`legal_tmpfs_two_concurrent_writers_single_debit`; `test/dsl/CapacityTopologyGate.hs` (the gate battery +
validation-locus ledger) — target paths, not yet built. All forty fixtures and their expected results /
`Left`-tags
are authored and committed in Phase 0 before the implementation exists (§M.1, [Gate integrity](#gate-integrity)).
**Blocked by**: Sprint 7.1, Sprint 7.2, Sprint 7.3; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: the gate decodes and binds each positive fixture, runs the conditional
`planInfrastructure` arm, constructs `ProvisionContext` only from the explicit already-materialized fixture
or receipt-bound modeled materialization, and only then calls `provision` to obtain a feasible opaque result;
each fold negative returns a structured `ProvisionError`/`Left` at the provision
seal — **each negative asserting its specific expected tag** (e.g.
`illegal_elastic_pod_exceeds_largest_candidate` → `Left Unschedulable`,
`illegal_elastic_worst_case_instances_over_quota` → `Left Overcommit`, `illegal_store_over_backing` →
`Left (StorageOverBacking …)`, `illegal_filesystem_layout_swapped` →
   `Left FilesystemLayoutMismatch`, `illegal_image_content_join_missing` →
   `Left ImageMetadataMissing`, and `illegal_provider_node_root_ebs_over_quota` →
   `Left ProviderNodeRootQuotaExceeded`, and `illegal_control_plane_storage_transition_overrun` →
   `Left EngineStorageOvercommit`), **not merely "some `Left`", and each paired with a positive differing only in
the foreclosed dimension** (§M.8) — each assertion annotated with its catalog entry
(§3.11/§3.13–§3.22/§3.27–§3.30) and its
checked-rejection layer at the `provision-seal` locus; the run emits a Register-1 proven/tested/assumed ledger.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (the resource/capability
§3.11/§3.13–§3.22/§3.27–§3.30 checked-rejection / `provision-seal`
entries → layer-2 Register-1), `documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip
the Phase-7 status when the gate passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-7 `none` gate row).

### Objective
Adopt [`illegal_state_catalog.md §4.6/§4.7`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
and [`§3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent):
assemble the phase's single Register-1 gate — the pure folds reject each capacity/topology
negative while the positive multi-substrate / managed-EKS fixtures place feasibly — and emit the per-entry
validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables
- The fold-negative fixtures — `illegal_engine_substrate_mismatch` (§3.13), `illegal_rke2_reused_host` (§3.16
  distinctness), `illegal_overcommit_{host,vm,cluster}` (§3.17), whose host case table includes a
  `PhysicalDiskPartition.allocatableRawBytes` one byte short of the derived
  `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits` and a
  separate VM `requiredUsableBytes` one byte short of its nested usable debits, `illegal_store_over_backing`
  (§3.19),
  whose case table includes logical committed bytes fitting while erasure/healing, finite-horizon failed-write
  orphans, filesystem overhead, backing minimum/quantum, uniform-claim rounding, a differing-backing ordinal
  is short despite aggregate spare bytes elsewhere, registry upload/failed partials or filesystem→MinIO
  old+new copy workspace, one ZooKeeper member's transaction-log/snapshot recovery, one Patroni data/WAL/
  failover ordinal, schema old+new/temp/WAL overlap, or Vault Raft compaction/recovery/audit rotation exceeds a
  physical backing; the same fixture's producer cases omit each of the six closed object-store arms in turn;
  `illegal_topic_time_only_offload` + `illegal_hot_tier_over_bookie` (§3.20), whose latter case table includes
  logical hot bytes fitting while write-quorum/recovery placement exceeds one bookie; `illegal_untolerated_taint`
  (§3.22 placeable-node existence), `illegal_pod_ephemeral_overcommit` and
  `illegal_hard_ceiling_overcommit` (whose case table separately makes only a controller webhook,
  object-write/query/registry gateway, Pulumi executor, storage/registry/schema migration executor, or
  ZooKeeper/Patroni child one CPU/memory/ephemeral unit or pod slot short, and separately makes a kind-indexed
  desired replica, surge instance, exact prior old/removed revision, or live terminating instance one unit
  short; other variants copy the new envelope into a deliberately larger/different old source, invent a
  predecessor under `FirstDeployment`, resolve the wrong/latest generation, omit the empty recreate step, or
  admit a replacement while an observed terminator holds the last provisioned unit),
  `illegal_cpu_limit_over_policy`, and
  `illegal_memory_backed_underreserved` plus `illegal_tmpfs_init_persistence_underreserved`
  (§3.11/§3.17), `illegal_node_local_storage_over_backing` (logical pod ephemeral fits, but the
  layout-routed union of OCI content, snapshots, writable layers, concurrent pull/import workspace, and
  model-derived per-Pod kubelet/CRI runtime metadata exceeds a physical backing; its case table drops the
  largest simultaneous metadata row, removes/changes the pinned model, drops/swaps a component role, mismatches
  planned/observed domains, overlaps or leaks qualified Pod/image ownership, double-debits an alias group, and
  makes either SplitRuntime nodefs or imagefs/containerfs exactly one byte short),
  `illegal_disk_backing_alias_double_spend` (duplicate backing/carve identity exposes one physical byte pool
  twice; its case table covers same-host duplicate-carve, cross-host duplicate-backing,
  `PhysicalDiskPartition` VM-usable-for-raw substitution, an underived presented usable carve, omitted
  `systemReserve`, and a child debit repeated through an alias),
  `illegal_filesystem_layout_alias` (a split arm aliases nodefs/imagefs),
  `illegal_filesystem_layout_swapped` (observed/declared nodefs and imagefs roles are reversed),
  `illegal_image_content_join_missing` (one required index/manifest/config/compressed-layer object has no
  exact catalog entry), `illegal_image_snapshot_join_missing` (one chain id has no unpacked/active-snapshot
  cost), `illegal_image_storage_model_missing` (the pinned model has no supported catalog entry), and
  `illegal_split_image_unsupported` (v1 containerd cannot construct the required support witness), each
  returning its specific image/layout tag rather than falling through to an aggregate disk error;
  `illegal_provider_instance_store_root_underprovisioned` (system reserve plus unique, presentation-adjusted
  carves exceed fixed instance-store bytes) and `illegal_provider_node_root_ebs_over_quota` (the privately
  derived, rounded root request exceeds the distinct root-EBS bytes or volume-count ceiling even while durable
  quota fits); `illegal_control_plane_storage_transition_overrun` (steady backend fits but the pinned
  max-WAL/preallocated-next, snapshot-save temporary, or serialized defrag old+new transition exceeds its
  system carve); `illegal_cache_over_local_pool` (§3.17/§3.25, exact catalog residents plus bounded first-miss
  temporaries exceed the cache backing),
  `illegal_incluster_cache_bound_mismatch` (§3.11/§3.17 — cache peak/budget/volume/ephemeral nesting or
  double-charge violation),
  `illegal_cuda_on_cpu_target` + `illegal_accelerator_count_shortage` (§3.27/§3.28),
  `illegal_accelerator_vram_fragmentation` (§3.30 — aggregate residency bytes fit but one `Unsharded`
  residency fits no device, a `ReplicatedPerDevice` residency is not chargeable on every owner device, or an
  explicit shard/per-device epoch assignment does not fit),
  `illegal_accelerator_vram_reserve_boundary` (§3.30 — the demand fits raw `memory.total` but exceeds
  `allocatableVram` after the mandatory driver/runtime reserve),
  `illegal_apple_metal_profile_mismatch` (host Metal demand has no compatible offering), and
  `illegal_shared_accelerator_double_owner` (two cluster budgets claim one physical device id),
  plus the four **elastic-branch negatives**
  `illegal_elastic_pod_exceeds_largest_candidate` (a single pod larger than the largest declared candidate node
  type → `Left Unschedulable`), `illegal_elastic_class_max_exhausted` (two pods fit only a class capped at one
  node even though the account quota is larger), `illegal_elastic_per_node_overhead_unplaceable` (a pod fits
  raw candidate allocatable but not the effective capacity after required per-node units), and
  `illegal_elastic_worst_case_instances_over_quota` (atomic placement and
  anti-affinity force more candidate instances than the declared quota → `Left Overcommit`), which foreclose a stubbed elastic `place` that
  returns `Right` unconditionally — each asserted to return its **specific** tagged `Left` at the fold and
  paired with a positive differing only in the foreclosed dimension, with the type-foreclosed neighbours
  (§3.14/§3.15/§3.18/§3.21/§3.24) noted as already foreclosed upstream.
- The positive fixtures `legal_multisubstrate_cluster` (the §3.13 heterogeneous carve-out, exercising
  distinguishable `Unified` and `SplitRuntime` routing plus a presentation-adjusted VM/instance-store fit; its
  case table includes exact-fit physical-raw and nested-VM-usable parent equations, including
  `systemReserve raw parent debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ==
  allocatableRawBytes`,
  exact-empty `FirstDeployment`, a recreate zero-live step, an update with different old/new full execution
  envelopes plus added/removed units, and an
  exact component→role→layout-backing metadata accounting and one debit per grouped carve),
  `legal_managed_eks` (EKS first-class, requiring two materialized instances from one candidate class,
  deriving each root-EBS request from its class-local system/carve high-water, debiting the distinct root
  quota, and proving instantiated backing/carve/device identities are disjoint), and
  `legal_tmpfs_two_concurrent_writers_single_debit` (one shared
  tmpfs volume, two concurrent writers, one reservation carrier per epoch) asserted to decode and `place`
  feasibly. The existing positive case tables also include kind-valid Deployment, StatefulSet, DaemonSet, Job,
  and HostProcess bodies whose exact steady, rollout, and supplied live old+terminating epochs fit at equality,
  including distinct Deployment `{ maxSurge = 1, maxUnavailable = 0 }` and `{ 0, 1 }` rolling controls; these are variants of the
  three named positives, not additions to the exact representative set.
- A Register-1 validation-locus ledger mapping every entry to its catalog id, checked-rejection layer, and
  `provision-seal` locus,
  explicitly marking the runtime residue (VM boot, pod schedule, S3 offload, autoscaler growth) deferred to the
  live band — sibling evidence where the capacity arithmetic generalizes prodbox's teardown push-back
  soundness, not an amoebius result.

### Validation
1. `cabal test dsl-spec` is green — every one of the thirty-seven fold negatives
   ([Gate integrity](#gate-integrity) representative set, including the four elastic negatives)
   returns its **specific committed** tagged `Left`, all three positives place feasibly,
   the QuickCheck battery holds at its coverage minima, and the committed per-fold seeded-mutant battery ([Gate integrity](#gate-integrity))
   turns the suite red individually; the suite is red if any capacity/topology negative provisions to `Right` or
   to the wrong tag; the validation-locus ledger is present and honestly classifies each foreclosure, marking
   the runtime residue UNVERIFIED.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/resource_capacity_doctrine.md` — backlink §4's fold + §5/§6/§7 storage arithmetic to
  the implemented `Amoebius.Capacity.*`; confirm every capacity/retention sum stayed a checked pre-effect
  rejection at the post-bind `provision-seal` and
  sound-not-complete.
- `documents/engineering/cluster_topology_doctrine.md` — backlink §2/§3/§4 and the §5 compatible-pair fold to
  the implemented `Amoebius.Dsl.Topology`; keep the runtime (VM boot, node join) residue deferred.
- `documents/illegal_state/illegal_state_catalog.md` — annotate the applicable
  §3.11/§3.13–§3.22/§3.27–§3.30 parts with their realized checked-rejection / `provision-seal`
  layer (technique §4.6/§4.7 → layer 2, Register-1); keep runtime-checked entries (layer 3) deferred.
- `documents/engineering/storage_lifecycle_doctrine.md` (§5.2), `documents/engineering/pulsar_client_doctrine.md`
  (§6), `documents/engineering/substrate_doctrine.md` (§8 node inventory) — reconcile each read-side with the
  as-built fold; each remains the single owner of its number.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + fold ledger this gate emits
  (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-7 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-7 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Dsl/Topology.hs`,
  `src/Amoebius/Capacity/{Types,Fold,Storage,Growable}.hs`, and the capacity/topology property + gate suites as
  Phase-7 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the capacity/topology invariants
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the `fits`/`carve`/`place` fold, `StorageBudget`/`Growable`, and the two-ceiling Pulsar arithmetic
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — the `ComputeEngine`/`LinuxHost`/`Topology` types and the elementwise compatibility relation
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the resource/topology/
  accelerator entries and the §4.6/§4.7 techniques, with §2/§6 the load-bearing limit and honest layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the IR + decoder these folds decode into
- [phase_06](phase_06_illegal_state_corpus.md) — the illegal-state corpus, properties, and validation-locus ledger this phase extends
- [phase_08](phase_08_capability_binder.md) — the capability → provider → shape binder built atop these folds
