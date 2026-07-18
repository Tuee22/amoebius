# Phase 5: GADT-indexed IR + total decoder (Gate 2)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the GADT-indexed Haskell IR and the total, fail-fast `Dhall.inputFile auto` decoder
> — Gate 2 — that turns a Gate-1-well-typed Dhall value into a legal amoebius world or a structured `Left`,
> carrying normalized complete resource demands and target capacities in-process before any real resource
> exists, while preserving the later post-bind `ProvisionedSpec` boundary.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 4 Gate-1 gate
passes and runs on **no substrate** (`none`) in **Register 1** — it stands up no host and no cluster, only an
in-process decode battery. Where a shape below is already exercised in a sibling system (hostbootstrap's
`inputFile auto` decoder and its `Left (ContextDecodeFailed …)` fail-fast discipline), that is **sibling
evidence, not an amoebius result**.

## Phase Summary

This phase builds the second of the DSL's two typed gates. Gate 1 (Phase 4) rejects what is not even
well-typed Dhall; Gate 2 rejects what is well-typed Dhall but is not a legal amoebius world. It delivers the
GADT-indexed Haskell intermediate representation the Dhall surface decodes *into* — sum types, smart
constructors, phantom tenant references, and ownership indices designed so that an illegal combination has no
inhabitant — together with the fail-closed decoder `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)`
built on the native `dhall` library's `Dhall.inputFile auto` wrapped in an exception-catch. Totality here is
defined precisely: every input, well-typed or not, yields `Right` or a structured `Left` *without throwing*.
`ClusterIR` is not resource-agnostic: every execution unit carries stable id/revision, arm-specific
controller/cardinality/policy in a private `BoundExecutionBody`—Deployment, StatefulSet, DaemonSet, Job, or
HostProcess—with only kind-valid rollout/progress fields and a structurally compatible Pod/host/accelerator
resource arm, plus the normalized complete `ResourceEnvelope` declaration (CPU, memory, pod-local ephemeral
storage, durable/cache storage, structural runtime-metadata sources, and the closed identity-complete
accelerator-owner demand), and every target inventory carries normalized
`Capacity`, backing, and accelerator-offering declarations. The decoder also preserves the complete physical
disk identity graph (globally scoped physical-backing/carve ids, VM subcarves, each node's logical
pod-ephemeral allocatable, closed physical-filesystem layout, `imageStorageModel`, `imagePullConcurrency`, and
`kubeletMetadataModel`), the full provider target's authored `CloudAccountId`, node-class pod/CNI and
driver-indexed CSI slot policies, complete supply/quota/root-backing shape, and every Observability binding's
mandatory finite `MonitoringWorkBudget`, including its volume presentation. Every build also retains its
mandatory per-stage `BuildExecutionEnvelope`; every kind
engine and every rke2 server/agent retains its role-indexed named-process `EngineSystemReserve`, named system-
carve reference, and applicable finite `ControlPlane | Worker` engine-storage demand. Quantities are converted once to canonical unit-tagged
forms (millicores, bytes, whole devices); no later stage reparses free-form resource strings or invents omitted
defaults. This phase proves only
that those declarations are present, normalized, and structurally legal. Arithmetic feasibility and placement
remain checked folds, not type-inhabitance claims.
The pure decode code carries no `error`/`undefined`/partial head (checked non-partial); and because
`Dhall.inputFile auto` alone throws (`DhallErrors`, IO exceptions) rather than returning `Left`, the
exception-catch wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed) so no
throw escapes into a half-applied effect. What is *not* here: the chain
/ reconcile / singleton runtime (Phase 22), the pure capacity/topology fold implementation and properties
(Phase 7) consumed by the conditional infrastructure-planning/post-materialization provision seal (Phase 8),
the capability→provider binder (Phase 8), and
the exhaustive illegal-state corpus with its per-entry validation-locus
ledger and QuickCheck properties (Phase 6). This phase checks the decoder is non-partial, fail-closed, and structurally
rejecting on a representative Gate-2 negative set; the exhaustive corpus rides on top of it next.

The non-bypass ordering is fixed here even though its implementation lands after this decoder:

`ClusterIR → bind/expand → BoundDeployment → planInfrastructure(BoundDeployment, declared
supply | forest budget) → (NoInfrastructureRequired witnessing an explicit
ObservedInfrastructureMaterialization.AlreadyMaterialized state |
ProvisionedInfrastructurePlan → validate → CAS-enact → receipt-bound
ObservedInfrastructureMaterialization) → ProvisionContext → provision → Either ProvisionError
ProvisionedSpec → renderAll`.

The decoder never constructs `ProvisionedSpec`, the binder never renders, and the renderer never accepts
`ClusterIR` or `BoundDeployment`. Neither value contains a `Provisioned*` record. `planInfrastructure`
derives its demand from that exact bound expansion; no caller-authored demand vector can bypass it. A required
plan is one batch-owned Pulumi graph/checkpoint/dependency/concurrency/quota value and cannot render. Only its
CAS-consumed, provider-read-back result (or the explicit no-plan materialized arm) can construct
`ProvisionContext`; only then may `provision` resolve opaque prior-execution/volume/registry refs and
construct the opaque checked value. Provider expansion has already made every platform pod, sidecar, init
container, volume, cache owner, and accelerator owner explicit.

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` battery analogous to the
Phase-0 documentation lint and the Phase-4 `dhall type` corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `cabal test dsl-spec` is green — each positive fixture decodes through the fail-closed `decodeCluster`
into its `ClusterIR`, each Gate-2-class negative fixture **first passes `dhall type` (Gate-1-green
precondition, so its rejection is attributable to the decoder alone, not to Gate 1)** and then returns a
structured `Left DecodeError` with its expected tag, and the decode path is checked non-partial and fail-closed
(deep-NF strict evaluation via an `NFData ClusterIR` instance forced by `evaluate . force` on the decode path;
`-Wall` + a partiality grep proving no `error`/`undefined`/partial match in the pure code; and an
exception-catch wrapper mapping every thrown `DhallError`/IO exception to a structured `Left`). A structural
oracle also traverses every positive `ClusterIR` and proves the complete normalized resource/capacity tree was
retained. This is a **Register-1** in-process check that runs on no substrate. It checks non-partiality of the
pure code and fail-closure on thrown exceptions; it is not a proof of termination or of exception-freedom of
the underlying `dhall` library.

**Committed oracle, corpus, and mutants (§M clauses 1/2/7/8).** The gate's oracle side is authored and
committed in **Phase 0 before the decoder exists** — never regenerated from `decodeCluster`'s own output. It
comprises: (a) the **representative Gate-2 negative set**, defined concretely as **exactly one negative fixture
per named `DecodeError` failure class** — `SchemaMismatch`, `OutOfDomainArm`, `UnspellableCombination` — each
`illegal_decode_*.dhall` fixture mapped in its committed header to a specific `illegal_state_catalog.md` entry
and pinned to its expected tag; the suite is **red if any of the three tag arms has zero fixtures** (so a
blanket catch-all tag cannot pass) and red if any negative fails its `dhall type` precondition. (b) The
**minimal-pair compile-fail set** for each of §4.2/§4.3/§4.4 (see Sprint 5.2). (c) A **committed seeded mutant
set that must go red, committed and re-run** (not run once): the mutant `illegal_decode_schema.dhall`
→ legalized twin (a negative whose Gate-2-illegal index is corrected so it would decode) **must turn the suite
red**, demonstrating the "any illegal fixture decodes ⇒ red" polarity is an executed check, not a restated
assertion. The resource decoder mutants independently drop logical `ephemeralStorage`, a physical carve
reference, `PhysicalDiskPartition.allocatableRawBytes`, a `NamedDiskCarve` parent index or extent-arm
geometry field, `kubeletMetadataModel`, a pod runtime-metadata
network/mount identity, one execution id/revision/cardinality/replicated-count/per-node-selector/rollout
operand, admit a raw rolling policy whose surge and unavailable operands are both zero, or erase one
accelerator source/workload/residency/coexistence operand; mismatch either coexistence-map
domain from the exact source classes; make sharded totals/ids/count disagree; drop provider `podSlots`,
provider `attachableVolumes`, the target `CloudAccountId`, any one of
`ProviderQuota.maxInstances`/`maxVcpu`/`acceleratorCaps`/`nodeRootStorage`/`durable`, or provider-class
`quotaVcpu`; coerce a class-local disk/accelerator template id into a concrete physical id; replace the decoded
`MonitoringWorkBudget` with descriptor-independent fixed Prometheus resources; replace a storage fault policy
with an editable favorable-scenario list; drop orphan-GC/claim-slot fields; or delete one of the filesystem
layout, `NodeImageStorageModelVersion`, an OCI index/manifest/config/compressed-layer object, a snapshot-chain
cost, provider root backing policy, node-root-storage quota arm, `VolumePresentation`,
`MonitoringWorkBudget.volume.presentation`, backing allocation minimum/quantum, exact cache population,
registry upload operands, or Vault Raft/audit operands. Each must fail the independent positive-tree
traversal/type inventory.
The expected-tag reference table and expected resource-field inventory are committed Phase-0 oracles,
independent of the decoder's own output (§M clause 3).

## Doctrine adopted

- [`dsl_doctrine.md §5 — the illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  adopt **Gate 2 — the Haskell typed decoder**. A well-typed Dhall value becomes a Haskell value through the
  native `dhall` library in-process (`Dhall.inputFile auto`); decoding is total and fail-fast (a structured
  `Either`, never a throw), and the ADTs make illegal combinations un-spellable — *because the value cannot
  be constructed, it cannot be decoded, and because it cannot be decoded, it cannot be deployed.*
- [`illegal_state_catalog.md §4`](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
  — the typing techniques discharged at the decode boundary: **GADT-indexed state machines** (§4.3, only legal
  transitions are typed), **capability & phantom tenant tags** (§4.2, cross-tenant references are
  uninhabitable), and **ownership indices** (§4.4, single-owner SSoT structurally). This phase builds the IR
  that carries those indices; the capacity-accounting and topology-relation folds (§4.6/§4.7) are deferred to
  Phase 7.
- [`resource_capacity_doctrine.md §3/§4`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  — the complete pure resource vocabulary and its checked-construction boundary. This phase carries and
  normalizes the declarations in `ClusterIR`; Phase 7 implements the arithmetic/placement folds; Phase 8 runs
  them after capability binding and provider expansion to construct an opaque `ProvisionedSpec` and its
  unique whole-deployment render-source set. Private service projections contribute sources but never cross
  the public boundary; a raw decoded or merely bound value can never reach Phase 9's `renderAll`.
- [`illegal_state_catalog.md §2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  and [`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — the load-bearing limit and the three layers of foreclosure: layers 1–2 (type-/decode-foreclosed) are
  Register-1 and honestly discharged here; layer 3 (runtime-checked) stays deferred. Honors §2 verbatim: *a
  type-check proves the spec composes, not that the cluster enforces it.*
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md) — **Register 1** (pure/golden,
  in-process, no cluster): the register this phase's gate reaches; and [`§4`](../documents/engineering/testing_doctrine.md)
  — the per-run proven/tested/assumed ledger the battery emits, marking model↔runtime correspondence
  UNVERIFIED.

## Sprints

## Sprint 5.1: The amoebius cabal package + `dsl-spec` test-suite skeleton 📋

**Status**: Planned
**Implementation**: `amoebius.cabal`, `cabal.project` (the real package, not the Phase-1 throwaway probe), a
`dsl-spec` test-suite stanza, and an empty `src/Amoebius/Dsl/` module tree — target paths, not yet built.
**Blocked by**: Phase 4 gate (the Gate-1 Dhall schema + smart-constructor prelude the decoder mirrors); the
Phase 1 toolchain spike's recorded `allow-newer`/patch/pin for `dhall` under GHC 9.12.4.
**Independent Validation**: `cabal build` of the empty package and `cabal test dsl-spec` (zero tests)
succeed under GHC 9.12.4 / Cabal 3.16.1.0 using the Phase-1 pin. Disambiguation of "no `PATH`-resolved tool"
(the one interpretation both engineers now share, since this validation has no amoebius binary): the harness
resolves `ghc`/`cabal`/`dhall` to the **absolute paths recorded in the Phase-1 pin manifest** and invokes them
by absolute path, and an **OS-boundary argv observer** (an argv-recording shim on `PATH`, per §M clause 5)
records that every toolchain and `dhall` invocation during this sprint's build/test carried an absolute
program path — the shim's own log is red if any invocation resolved a bare name via ambient `PATH`. This is an
external-observer trace, not a self-report by the build script.
**Docs to update**: `DEVELOPMENT_PLAN/system_components.md` (register the `amoebius` package + `dsl-spec`
suite), this document.

### Objective
Adopt the pinned toolchain from the Phase 1 spike and stand up the real `amoebius` cabal package with a
`dsl-spec` test-suite target, so every later sprint has a buildable in-process surface — the minimal skeleton
Gate 2 needs, with **no** chain/reconcile/singleton kernel.

### Deliverables
- `amoebius.cabal` + `cabal.project` pinned to GHC 9.12.4 / Cabal 3.16.1.0 with the Phase-1 `allow-newer`
  set, exposing an empty `src/Amoebius/Dsl/` tree and a `dsl-spec` test-suite stanza.

### Validation
1. `cabal build` and `cabal test dsl-spec` (zero tests) succeed on the pinned toolchain.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.2: GADT-indexed IR + smart constructors + phantom tenant refs + ownership indices 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Types.hs` (the GADT-indexed `ClusterIR`, normalized resource/capacity
declaration fields, and component ADTs),
`src/Amoebius/Dsl/SmartConstructors.hs`, `src/Amoebius/Dsl/Ref.hs` (the phantom tenant `Ref tenant a` and
ownership indices) — target paths, not yet built.
**Blocked by**: Sprint 5.1.
**Independent Validation**: the catalog's decode-foreclosed classes (§4.2/§4.3/§4.4) have no inhabitant,
proven by **committed minimal-pair compile-fail fixtures** (not absence-by-omission). For each of §4.2 (phantom
tenant), §4.3 (GADT transition index), and §4.4 (ownership index) the phase commits **two source fixtures
differing only in the one index** (tenant tag / state index / owner): the **legal twin must compile** *and*
must be the exact constructor a **named Phase-4 positive fixture demonstrably decodes through** (the fixture
header cites which `legal_*.dhall`), while the **illegal twin must fail `ghc -fno-code` with a type error whose
message names that same constructor/index**. Because the legal twin is a required-to-compile, actually-decoded
constructor, an impoverished vocabulary that spells cross-tenant references freely fails its legal twin (or
fails to decode the cited positive), so the pair cannot be satisfied by a strawman `mkCrossTenantRef` that was
simply never defined. The compile-fail message locus (expected type-error text) is committed in Phase 0
alongside the fixtures. The exhaustive compile-fail corpus is assembled in Phase 6.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry layer reconciliation — which
entries this IR type-forecloses), `documents/engineering/dsl_doctrine.md` (Phase-5 status backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`illegal_state_catalog.md §4.2/§4.3/§4.4`](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed):
build the Haskell types the Dhall decodes into — GADT-indexed so only legal transitions are typed, phantom
tenant-tagged so a cross-tenant reference is uninhabitable, and ownership-indexed so a resource has one
structural owner. These are the ADTs that make an illegal combination un-spellable at the decode boundary.

### Deliverables
- `ClusterIR` and its component ADTs as GADT-indexed types + smart constructors exposing only a legal
  vocabulary; the phantom tenant `Ref tenant a` and ownership indices catalogued at §4.2/§4.4.
- Normalized resource declarations wired into the real IR, not ornamental side records: every execution-unit
  component carries stable id/revision plus one private controller-indexed body: Deployment/StatefulSet use
  `Once | Replicated`; DaemonSet embeds `PerNode`; Job uses completions/parallelism/backoff/
  `podRestartPolicy=Never`/`podReplacementPolicy=Failed`/finite terminal retention; HostProcess uses
  `Once | PerNode` under a
  supervisor. Deployment, StatefulSet, and DaemonSet retain only their kind-valid policies; StatefulSet is
  native serial partition zero and DaemonSet rolling is exactly `Surge | Unavailable`. The body also contains
  a complete structurally compatible Pod/host `ResourceEnvelope` and the identity required for Phase 8's
  exactly-once `BoundExecutionSet` join. The Deployment rollout constructor is private and returns
  `Left (UnspellableCombination "rollout.rollingProgress")` for `{ maxSurge = 0, maxUnavailable = 0 }`.
  `{ 1, 0 }` and `{ 0, 1 }` are required positive controls, so the guard cannot be strengthened into an
  accidental both-positive requirement. Gate 2 rejects Deployment↔Host, HostProcess↔Pod, kind-policy,
  kind-cardinality, CUDA-with-rolling, ordinary-with-device-release, and Metal-without-Metal-envelope
  mismatches at their exact field paths;
  every pod resource retains exact structural network/mount identities in `PodRuntimeMetadataSource`. Every
  node/host/storage target carries the corresponding
  `Capacity`, durable/native-host-cache backing, and closed accelerator offering; in-cluster cache remains a
  typed reference to one declared disk-backed pod volume and therefore a nested consumer of pod ephemeral
  storage, never a second allocation. CPU is normalized to millicores; memory, pod ephemeral storage,
  durable/cache storage, and accelerator residency to bytes; accelerator count remains a positive wholesale
  whole-device quantity. CUDA/Metal owner inputs preserve exact equal-keyed served-model/training-job/JIT/
  library source and workload maps, structural residency placement, and finite class-based coexistence maps.
  `domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)`; missing/extra classes reject.
  Residency bytes mean total for `Unsharded`/`Sharded` and per device for `ReplicatedPerDevice`; sharded bytes
  sum to the residency total, shard ids are unique, and shard count cannot exceed owner devices.
  Concrete and provider-template offerings preserve their device/slot link graphs. A zero
  quantity/device count, locally inconsistent accelerator, or structurally incomplete declaration returns the
  existing structured `OutOfDomainArm`/`UnspellableCombination` class with the exact field path rather than
  surviving as an unvalidated scalar. Whether a target offers the requested accelerator family/device count
  and can place every identity-complete, policy-permitted residency epoch against net per-device or unified
  memory is deliberately deferred to post-bind provisioning.
  Each container preserves a closed `ReadOnlyRootfs | WritableRootfs { allowance }` arm; omission cannot mean
  zero writable bytes. Its `ImageArtifact` retains the OCI index digest/stored bytes and, for every platform,
  child-manifest and config digest/stored bytes, every compressed-layer digest/stored bytes, snapshot chain id/
  unpacked bytes, and peak pull/import workspace. Each pod `DeclaredVolumeDemand` preserves its
  `StatefulSetClaimSlot`, `BackingId`, logical bytes, typed direct/BookKeeper/MinIO geometry owner, and
  `VolumePresentation = Block | Filesystem { fsType, overheadModel }`; each selected volume-producing host/
  provider backing preserves
  `allocation : BackingAllocationPolicy { minimumBytes, quantumBytes }`. No raw IR field can author physical
  bytes; Phase 8's post-bind `provision` boundary constructs the private rounded `ProvisionedVolumeDemand`
  consumed by render, using the geometry and folds implemented in Phase 7.
- Canonical bounded service-storage inputs remain structural rather than being collapsed to caller-authored
  peak scalars. `InClusterCacheDemand`/`HostCacheDemand` preserve `CachePopulationDemand` with the exact
  catalog asset identity/digest/resident/temporary bytes and finite first-miss concurrency.
  `RegistryStorageIntent` preserves exact image-digest identities, finite upload concurrency, failure
  window/count, GC horizon, model, mutation policy, required storage budget, and typed interim-volume/MinIO
  backend; Phase 8 alone exact-joins those digests to `RegistryStoredArtifact` metadata and constructs
  `RegistryStorageDemand`.
  Every deployment preserves exactly one raw
  `FirstDeployment | UpdateFrom PriorProvisionRefSource`; Gate 2 requires the update's `Execution` resource
  arm and brands it as `PriorExecutionProvisionRef`. `StorageMigrationIntent` and
  `RegistryBackendMigrationIntent` preserve `PriorProvisionRefSource { deployment, generation, resource }`;
  Gate 2 checks those resource arms and brands them as `PriorVolumeProvisionRef` or
  `PriorRegistryProvisionRef`. No arm decodes a prior `Provisioned*` record or an implicit latest generation.
  They also preserve replacement/policy/workspace/chunk/concurrency inputs. `SchemaMigrationIntent` preserves
  exact old/new table/index identities plus its data/workspace backing and cost model. `ZooKeeperMetadataStoreDemand`
  preserves every member pod/claim, persistent/session znode, transaction/session/watch bound, retained
  log/snapshot and failure operands; the v1 `PulsarMetadataStoreDemand` has no non-ZooKeeper or omitted arm.
  `PatroniSqlIntent` preserves finite data/WAL/checkpoint/failover source operands, required
  `StorageBudgetId`, declared volume, and bounded connection/transaction/WAL mutation intent rather than a
  fixed “database size”; it contains no `ControllerChildEnvelope` or provisioned child.
  `VaultStorageDemand` preserves the exact bounded persisted-object versions, maximum active leases, pinned
  Raft model/claim set, and rotated audit file/backups/retention plus named ephemeral or retained backing.
  Only private cache/registry/Vault witnesses constructed at Phase 8's post-bind `provision` boundary, using
  Phase 7's folds, may carry derived peaks.
- Every durable platform declaration retains normalized `BookKeeperGeometry` (ensemble/write/ack quorums,
  segment bytes, bookie claim slots, journal/index reserve, finite fault bound), `MinioErasureGeometry`
  (data/parity/block geometry, drive claim slots, metadata/healing reserve, finite fault bound and replacement
  supply), and `ObjectStoreDemand` (exact store/tenant/bucket/full-key resident map, structural additional
  retained object extents, concurrent write sets, failed-write bound, finite positive orphan-GC horizon,
  admission cost model, and `StorageBudgetId`). The six-arm closed producer union retains app/content/registry,
  Pulsar-offload segment/rate/lag/failure operands, Pulumi exact state fields/revisions/failures, and the
  closed control-plane state entry kinds in `ObjectStoreProducerIntent`. `ObjectStoreGatewayIntent` preserves
  only gateway identity and execution-model selection; Phase 8 merges producer writer policies and constructs
  `ObjectStoreProducerDemand` plus `ObjectStoreAdmissionGatewayDemand`. Gate 2
  retains only the fault-policy bounds, never a caller-curated list
  of favorable failure scenarios, and retains the `(StatefulSet, volumeClaimTemplate, ordinal)` identity needed
  for the later uniform max-ordinal projection. It normalizes/refines these operands but does not claim their
  logical→physical or rounded-backing arithmetic fits; that remains the provisioning fold. Its normalized
  `BookKeeperLogicalDemand` always carries required positive byte quantities for `retainedHotBytes`,
  `openLedgerHeadroom`, `inFlightOffloadBytes`, and `deletionLagBytes`; zero, omission, and an `Optional` bypass
  have no IR representation.
- The normalized capacity tree retains the physical identity graph without alias-erasing or synthesizing ids:
  `PhysicalHostCapacity` has a non-empty `PhysicalDiskPartition` list keyed by globally scoped
  `PhysicalDiskBackingId`; each retains `allocatableRawBytes` after unmanaged-host reserve but before all
  amoebius child carves, including `systemReserve`. Every `NamedDiskCarve parent` keeps its globally scoped
  `DiskCarveId`, its `PhysicalRawExtent | VmGuestUsableExtent` parent index, and exactly one closed extent arm:
  `ExactParentExtent { parentBytes }` or `PresentedUsableExtent { requiredUsableBytes, presentation,
  allocation }`. Gate 2 therefore cannot erase whether a debit belongs to the physical-raw parent or the
  nested VM-usable parent, but does not claim either parent sum fits.
  Raw `VmDiskCarve` instead retains
  `{ id, presentation : FilesystemPresentation, allocation, guestSystem, kubelet }` with no authorable
  aggregate bytes: checked construction later derives private
  `ProvisionedVmDiskCarve { id, requiredUsableBytes, provisionedBytes, presentation, allocation, witness }`,
  with `id` copied unchanged from the raw `VmDiskCarve`; provisioning charges that raw high-water once to the
  parent partition keyed by the same id and preserves its layout-shaped kubelet filesystem carves. Every node's
  `NodeLocalStorageCapacity` separately retains logical `podEphemeralAllocatable`, the closed
  `KubeletFilesystemLayout`, `NodeImageStorageModelVersion`, finite image-pull concurrency, and
  `KubeletRuntimeMetadataModelVersion`. `Unified`
  retains one nodefs reference and derives the nodefs=imagefs=containerfs alias; `SplitRuntime` retains
  distinct nodefs/imagefs and derives imagefs=containerfs; `SplitImage` retains distinct nodefs/imagefs plus
  its runtime-support requirement and derives nodefs=containerfs. There is no arbitrary third filesystem or
  two free-standing pod/image pools. Every retained, host-cache, and purpose-tagged host-storage pool also
  preserves both its typed logical
  `BackingId`/`CacheBackingId`/`HostStorageBackingId` and its `NamedDiskCarve`; a build-scratch pool preserves
  the `BuildScratch` purpose rather than relying on a name. Gate 2 preserves this graph as opaque branded ids;
  Phase 7 owns value-level global uniqueness, exactly-one parent/reference, layout alias/support checks,
  injective logical-id→carve resolution, role compatibility, and arithmetic. CUDA device supply likewise preserves stable identity/profile plus `rawVram`, mandatory
  `driverRuntimeReserve`, and net `allocatableVram`; only the net value is a later fold operand.
- A managed provider target preserves the exact normalized
  `{ account : CloudAccountId, nodeClasses : NonEmpty ProviderNodeClass, quota : ProviderQuota }` shape. Each
  class retains a distinct catalog-pinned `ProviderSkuRef` and the exact
  `ProviderNodeCapacityTemplate { allocatableCpu, allocatableMemory, podSlots, cniSlots, attachableVolumes, localDisks,
  cpuOvercommit, localStorage, accelerator }`. `podSlots` remains a `ProviderPodSlotPolicy`,
  `attachableVolumes` remains a driver-keyed map of `ProviderAttachSlotPolicy`, and `localStorage` remains
  `{ podEphemeralAllocatable, filesystems, imageStorageModel, imagePullConcurrency,
  kubeletMetadataModel }`; neither slot policy is
  inferred from CPU. The non-empty per-instance disk/carve templates and closed accelerator offering retain
  template-local link endpoints/kinds. Each disk template retains the closed node-root backing:
  `InstanceStore { skuDevice, provisionedRawBytes, presentation : FilesystemPresentation }` or
  `EphemeralRootEbs { policy : ProviderNodeRootVolumePolicy { volumeType,
  presentation : FilesystemPresentation,
  allocation : BackingAllocationPolicy } }`. The same `PerInstanceDiskTemplate` separately retains
  `systemReserve : ProviderUsableDiskCarveTemplate` and
  `carves : NonEmpty ProviderUsableDiskCarveTemplate`, each exactly
  `{ id, requiredUsableBytes }`. Gate 2 preserves `InstanceStore.provisionedRawBytes` as fixed SKU raw supply
  and every carve's `requiredUsableBytes` as mounted-filesystem usable demand; it never normalizes one unit
  into the other. The EBS arm deliberately has no author-supplied byte request. Phase 7 derives a private
  `ProvisionedNodeRootVolumeRequest { volumeType, requiredUsableBytes, presentation, allocation, sizeGiB,
  provisionedBytes, witness }` from system reserve plus the unique carve set and catalog/provider allocation
  rules, then privately constructs `ProvisionedPerInstanceDiskTemplate`. For either backing arm that private
  value converts the SKU raw bytes or allocation-rounded root request through the pinned filesystem
  presentation into `mountedUsableBytes`; only afterward may it prove
  `systemReserve.requiredUsableBytes + Σ unique carves.requiredUsableBytes ≤ mountedUsableBytes`. Its
  `DiskTemplateId`, `DiskCarveTemplateId`, and
  `AcceleratorSlotTemplateId` remain class-local recipe names in types distinct from concrete
  `PhysicalDiskBackingId`/`DiskCarveId`/`AcceleratorDeviceId`; Gate 2 never invents or reuses a future node's
  physical identity. It preserves the fields needed to derive a globally scoped
  `ProviderInstanceId { account, cluster, class, ordinal }`, copying `account` unchanged from the managed
  target, plus the full disk/carve/slot template path and the
  operands for the Phase-7 local uniqueness, reference, layout alias/support, role-byte, provider-disk
  raw-to-mounted-usable/nested-fit arithmetic, and accelerator raw-reserve-net checks.
  Each class also preserves the exact `name`, `sku`, `allocatable`, `quotaVcpu`, `zones`, `price`, `baseCount`,
  and `maxCount` fields. The outer normalized quota preserves all five exact fields:
  `ProviderQuota { maxInstances, maxVcpu, acceleratorCaps, nodeRootStorage, durable }`, with
  `nodeRootStorage = NoNodeRootEbs | BoundedNodeRootEbs { bytes, volumeCount }` and
  `durable = NoDurable | Bounded { bytes, volumeCount }`. `acceleratorCaps` remains a profile-keyed map whose
  selected classes cumulatively debit one entry; duplicate-profile input has no normalized representation.
  The target `CloudAccountId` is the exact join key into `SharedSupplyLedger.accounts`; a missing or different
  key cannot be reconstructed from credentials. The hostless control plane never erases worker supply from
  `ClusterIR`, and `quotaVcpu` is never inferred from net `allocatableCpu`.
- Every normalized `Observability` deployment binding retains a mandatory finite
  `MonitoringWorkBudget { maxWorkflows, maxRules, maxSeries, maxScrapeSamplesPerSecond,
  evaluationInterval, evaluationCpu, evaluationMemory, retention,
  query : QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout,
  costModel }, volume : { claim : StatefulSetClaimSlot, backing : BackingId,
  presentation : VolumePresentation }, tsdbCostModel }`. Counts/rate become `PositiveNatural`, intervals become
  `FiniteDuration`, and CPU, memory, and storage remain unit-tagged quantities with an exact StatefulSet
  claim/backing/presentation; omission, a
  defaulted field, scalar query-temp, or a descriptor-independent fixed Prometheus provision has no normalized bypass. Phase 8
  owns the later descriptor-count and cost fold; Gate 2 guarantees the fold's operand survived decode.
- Every normalized build retains a mandatory `BuildExecutionEnvelope`: a non-empty list of
  `BuildStageDemand` values with branded stage id, platform, dependency ids, per-stage `HostResources`, and
  per-stage intermediate-byte peak plus cache-write delta; `scratchBacking : HostStorageBackingId`; `cache : HostCacheDemand` with
  typed `CacheBackingId` plus `CacheBudget`; and separate
  `Serial | BoundedParallel PositiveNatural` architecture and stage concurrency policies. The decoder proves
  dependency references are closed and the graph acyclic; Phase 7 derives maxima over every legal concurrent
  set. All quantities and references survive in their refined domains; there is no optional, editable-
  aggregate, or descriptor-independent builder-resource bypass. Phase 15 owns snapshot-bound live admission,
  not decoding.
- Every normalized `KindEngineDemand` retains non-empty ordinal-indexed node-container runtime, full
  `NodeCapacity`, and in-node `KindControlPlane | KindWorker` reserve plus a distinct host-only
  Docker/containerd/kind-supervisor reserve. The decoder preserves the nesting; Phase 7 proves in-node reserve
  + allocatable fits the container and then charges that container once plus only the host reserve. Every normalized rke2
  server/agent node retains a mandatory `Rke2Server`/`Rke2Agent` reserve. Each reserve carries
  `processes : NonEmpty EngineProcessEnvelope`, `storage.carve : DiskCarveId`, and a role-indexed
  `storage.demand : ControlPlane | Worker`. Kind/server process ids contain the applicable runtime, kubelet,
  apiserver, etcd, controller-manager, scheduler, and role-overhead entries; an agent contains runtime,
  kubelet, and agent overhead. Each has `runtime : HostResources`. A kind host reserve additionally retains
  its exact node-container `ImageArtifact`, host container storage-model/driver, finite pull concurrency,
  per-ordinal writable/log allowances, and named data-root carve; it cannot collapse host OCI content and
  active snapshots into process log bytes. A control-plane demand retains
  `staticEngineBytes`,
  `etcd { backendQuotaBytes, maxWalFiles, retainedSnapshots,
  maintenance = SerializedSnapshotAndDefrag, storageModel : EtcdStorageModelVersion,
  logical : EtcdLogicalDemand { desiredObjects, churn, model } }`, with
  `churn { maxEventsPerWindow, eventWindow, maxEventBytes, eventRetention }` as the sole Event authority;
  `audit { maxBytesPerFile, maxBackups, retention }`,
  `kubeletRuntimeLogs { maxBytesPerFile, maxBackups, retention }`, and `historyRequirement`; the worker arm
  retains static bytes and the same bounded per-file/backups/retention log shape. Each retention/history value
  is a `FiniteDuration`. A role/
  storage mismatch, missing/duplicate/foreign process, unexplained aggregate reserve, omitted storage class,
  or optional/defaulted applicable history requirement returns a structured decode error. Each autoscaled
  rke2 candidate retains the template-local agent reserve/system-carve reference and declared raw per-instance
  host CPU/memory/disk supply, distinct from the managed-provider SKU/no-reserve arm. Missing raw host supply,
  process-template qualification, or SKU identity is a decoder-field-inventory failure. Phase 14 owns kind
  fit/enforcement; live multi-node rke2 admission/enforcement
  remains an explicitly unassigned Phase-N gate and no current live phase may claim it.
- An in-file honesty note that binding/capacity/topology totals (§4.6/§4.7) are *not* foreclosed by these
  types — the decoded declarations are intentionally **unprovisioned**. Phase 7 owns the total feasibility
  folds and Phase 8 invokes them on the fully expanded `BoundDeployment`; only their private constructor
  produces `ProvisionedSpec`. `ClusterIR` and `BoundDeployment` are forbidden renderer inputs and a structural
  type-inventory check rejects any `Provisioned*` field in either.

### Deliverables
- The committed minimal-pair compile-fail fixtures: for each of §4.2/§4.3/§4.4, a legal twin (compiles; cited
  to a named `legal_*.dhall` positive it decodes through) and an illegal twin (fails `ghc -fno-code` with a
  type error naming the same constructor/index), plus each pair's committed expected type-error locus.

### Validation
1. For each of §4.2/§4.3/§4.4, the committed minimal pair holds: the legal twin compiles **and** is the
   constructor a named Phase-4 positive fixture decodes through, and the illegal twin fails `ghc -fno-code`
   with a type error naming that same constructor/index (matching the committed locus). The check is red if the
   legal twin fails to compile or to decode its cited positive (foreclosing absence-by-omission), or if the
   illegal twin's failure locus does not match. The legal vocabulary compiles.
2. Every named positive fixture decodes with a complete normalized resource/capacity tree, and a structural
   traversal finds no execution unit without id/revision and one kind/cardinality/policy/resource-compatible
   private body; no zero-progress Deployment, invalid/both-positive DaemonSet rolling pair, feature-gated or
   nonzero-partition StatefulSet field, Job without finite terminal retention, or CUDA/Metal lifecycle
   mismatch; and no incomplete
   `ResourceEnvelope`; no target without `Capacity`, no unnormalized
   resource string, no empty pod container list or lifecycle-tagged container without `Resources` plus private
   runtime-memory, closed root-filesystem arm, and log allowance; no container whose content-digested
   `ImageArtifact` lacks index digest/stored bytes or a platform's child-manifest, config, compressed-layer,
   snapshot-chain/unpacked, and bounded workspace entry; no target without logical pod-ephemeral allocatable,
   a closed filesystem layout, pinned image/kubelet-metadata models, and finite pull-concurrency policy; no
   physical host without globally scoped backing/carve ids, `allocatableRawBytes`, parent-indexed carve
   extent arms, and its complete partition/VM-layout plus logical-pool-id graph;
   no `VmDiskCarve.id` dropped, substituted, or detached from its parent partition (the later provisioned id
   must equal this normalized raw id);
   no retained/cache/host-storage logical id without exactly one role-compatible physical carve; no node
   filesystem reference lost or renumbered; no managed provider target missing its authored `CloudAccountId`,
   any of the five exact `ProviderQuota` fields, or either closed storage arm; no provider node class missing
   `allocatableCpu`/`allocatableMemory`, `podSlots`, CNI/IP `cniSlots`, driver-indexed
   `attachableVolumes`, finite
   `cpuOvercommit`, per-instance `localDisks`, exact `localStorage` layout/model/pull fields, closed
   instance-store/ephemeral-root-EBS backing policy, `InstanceStore.provisionedRawBytes`,
   `ProviderUsableDiskCarveTemplate.requiredUsableBytes`, or per-instance `accelerator` slot/link template; no
   provider class missing `name`/`sku`/`quotaVcpu`/`zones`/`price`/`baseCount`/`maxCount`; no class-local
   template id occupying a concrete physical
   id field and no provider-instance scope/path field lost; no migration prior-ref
   deployment/generation/resource arm, replacement, or policy field lost; no `RegistryStorageIntent` image
   digest, `PatroniSqlIntent` source operand, `ObjectStoreProducerIntent` arm, or `ObjectStoreGatewayIntent`
   field lost; no binder-output demand or `Provisioned*` record present in `ClusterIR`; no duplicate Event
   authority outside `ControlPlaneStorageDemand.etcd.logical.churn`; no Observability binding without every refined
   `MonitoringWorkBudget` field including `volume.claim`/`volume.backing`/`volume.presentation`, no build
   definition without every refined per-stage/dependency/concurrency
   `BuildExecutionEnvelope` field, no kind or rke2 self-managed node without the exact role-indexed named
   static-process envelopes or any applicable `ControlPlane | Worker` storage/history field, no durable platform declaration missing normalized BookKeeper
   quorum/fault/bookie-slot fields or any of the four required `BookKeeperLogicalDemand` byte fields, MinIO
   erasure/fault/drive-slot fields, content-store
   resident/concurrent/failed-write/orphan-horizon fields, or the identities required for a uniform
   claim-template projection; no `DeclaredVolumeDemand` without a StatefulSet slot/backing/logical-byte/
   geometry-owner/presentation value or backing allocation minimum/quantum; no exact cache population,
   registry object/upload, or Vault persisted/Raft/audit operand collapsed to an editable aggregate;
   no pod arm without bounded pod-local volumes or exact structural runtime-metadata network/mount sources, no memory-backed
   volume whose non-empty access ids fail to resolve or whose stage-local/pod-lifetime persistence is invalid
   for the container lifecycle, no in-cluster cache
   whose `VolumeId` fails to resolve to exactly one disk-backed volume, no Apple-Metal or host-cache arm inside
   a pod envelope, no in-cluster-volume cache inside a host-worker envelope, no pod CUDA owner `ContainerId`
   that fails to resolve exactly once, and no accelerator owner demand whose source/workload keys differ,
   whose coexistence domains differ from `classes(sources)`, whose residency byte semantics/shard sum/unique
   ids/count are inconsistent, or that has lost family/profile, CUDA wholesale device count/interconnect,
   concrete/template raw/reserve/net VRAM/link graph, or Apple Metal profile/unified-memory residency. The
   traversal is red on a decoder mutant that drops any one resource field.
   The positive set round-trips distinguishable `Unified` and `SplitRuntime` layouts, both provider root
   backing arms, unequal `InstanceStore.provisionedRawBytes` and
   `ProviderUsableDiskCarveTemplate.requiredUsableBytes` operands without collapsing their units, raw VM
   id/presentation/allocation without aggregate bytes, exact cache/Vault structures, and
   a Registry arm whose `RegistryStorageIntent` image digests round-trip without a pre-bound
   `RegistryStorageDemand`. There is deliberately no v1 containerd `SplitImage` positive.
   In particular, `legal_deployment_rules` contains an `Observability` binding with nontrivial,
   pairwise-distinguishable values for every `MonitoringWorkBudget` field, and the test asserts exact field-by-field round-trip
   equality rather than merely accepting any present budget. `legal_managed_eks` likewise uses
   pairwise-distinguishable account, slot-policy, attach-driver, class, and quota values, and the traversal
   asserts exact field-by-field equality so an account-substitution decoder mutant or collapsed quota/slot
   field turns the gate red. The later shared-ledger property separately rejects a wrong-account join.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.3: The fail-closed decoder (`Dhall.inputFile auto` + exception-catch) + structured `DecodeError` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Decode.hs` (`decodeCluster :: FilePath -> IO (Either DecodeError
ClusterIR)` = `Dhall.inputFile auto` wrapped in an exception-catch that maps thrown `DhallErrors`/IO
exceptions to `Left DecodeError`; non-partial + fail-closed) and `src/Amoebius/Dsl/Error.hs` (the tagged
`DecodeError` type) — target paths, not yet built.
**Blocked by**: Sprint 5.2.
**Independent Validation**: the decode path returns `Either DecodeError ClusterIR` and never throws into a
half-applied effect; a `-Wall` + partiality grep gate confirms no `error`/`undefined`/partial head reachable
from `decodeCluster`; and "strictness forces the decoded value" is disambiguated to **deep normal form**: an
`NFData ClusterIR` instance is derived and the decode path runs `evaluate . force` on the `Right` value, so a
hidden unevaluated bottom in any field surfaces as a caught exception mapped to `Left` rather than passing a
shallow `Right _` match. `DecodeError` distinguishes at least the three named failure classes as distinct
constructors — `SchemaMismatch`, `OutOfDomainArm`, `UnspellableCombination` — so a blanket catch-all tag is a
type-level regression, not a passing implementation.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§5 Gate-2 backlink to the in-process decoder),
`documents/engineering/testing_doctrine.md` (the Register-1 in-process ledger variant),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §5 — Gate 2, the Haskell typed decoder`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
implement the fail-closed in-process decoder that mirrors hostbootstrap's `decodeContextFile = inputFile
auto` and its `Left (ContextDecodeFailed …)` fail-fast return — *sibling evidence, not an amoebius result* —
so nothing is ever reconciled against a config that did not fully decode.

### Deliverables
- `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)` over the native `dhall` library, with a
  structured `DecodeError` whose class of failure is carried by **distinct constructors** — `SchemaMismatch`,
  `OutOfDomainArm`, `UnspellableCombination` — not a single catch-all arm; and an `NFData ClusterIR` instance
  the decode path forces with `evaluate . force` so the `Right` value is proven deep-NF-total, not merely WHNF.
- Resource normalization is part of that same total decode: quantities are converted to canonical typed units,
  every required envelope/capacity field is retained, and invalid refined values are returned as a structured
  `Left` naming the field path. Normalization does **not** claim target feasibility; it produces only the
  unchecked declarations later consumed by the post-bind `planInfrastructure`/materialization/`provision`
  pipeline.
- An exception-catch wrapper around `Dhall.inputFile auto`: because `Dhall.inputFile auto` alone throws
  (`DhallErrors`, IO exceptions) rather than returning `Left`, it does not satisfy the never-throw contract on
  its own; the wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed).
- A non-partiality guard: the pure decode code is strict and, under `-Wall` + a partiality grep, free of
  `error`/`undefined`/partial matches. Together with the wrapper this delivers a checked-non-partial,
  fail-closed decode — not a proof of termination or of exception-freedom of the underlying `dhall` library.

### Validation
1. A malformed or out-of-domain value returns a structured `Left DecodeError` — including inputs on which
   `Dhall.inputFile auto` throws, which the wrapper catches and tags rather than propagating; the partiality
   gate reports no partial call reachable from the pure decode code; and the `evaluate . force` on the decoded
   value converts any hidden bottom into a caught `Left` (deep-NF check, not a shallow `Right _` match).
2. The three named failure classes are **distinct constructors** and each is reachable: a decode reproducing a
   thunked/bottom field is caught as `Left` rather than escaping — proving the deep force is on the live path.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.4: The Gate-2 decode battery (`dsl-spec`) — the gate 📋

**Status**: Planned
**Implementation**: `test/dsl/DecodeSpec.hs`; positive fixtures reuse Phase 4's
`dhall/examples/legal_*.dhall`; a representative Gate-2 negative set `dhall/examples/illegal_decode_*.dhall`
— target paths, not yet built.
**Blocked by**: Sprint 5.3, Sprint 5.1; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: `cabal test dsl-spec` is green — each positive fixture decodes to its
`ClusterIR`; **each `illegal_decode_*.dhall` negative first passes `dhall type` (Gate-1-green precondition)
and then** returns a structured `Left` with the expected tag pinned in its committed header; the suite is red
if any negative fails `dhall type` (so the rejection is Gate-2's, not Gate-1's — foreclosing negatives that
are merely ill-typed Dhall), red if any Gate-2-illegal fixture decodes, and red if any of the three
`DecodeError` tag arms has zero fixtures. The "red if any illegal fixture decodes" polarity is proven by an
**executed committed mutant** (below), not a restated assertion. The expected-tag oracle is the committed
Phase-0 fixture-header table, independent of the decoder's own fold (§M clause 3).
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (backlink: the decode-foreclosed entries
exercised here → layer-2 Register-1), `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-5 status when the gate passes).

### Objective
Adopt [`testing_doctrine.md §2 — Register 1`](../documents/engineering/testing_doctrine.md): assemble the
in-process decode battery that exercises the fail-closed decoder over every positive fixture and confirms it
returns a structured `Left` on each representative Gate-2 negative, emitting a Register-1 proven/tested/assumed ledger
with model↔runtime correspondence marked UNVERIFIED (owned by Phase 22). The exhaustive per-catalog-entry
corpus, the QuickCheck closure/round-trip/fold-totality properties, and the per-entry validation-locus ledger
are the front-loaded next phase ([Phase 6](phase_06_illegal_state_corpus.md)); the capacity/topology fold
negatives are [Phase 7](phase_07_capacity_topology_folds.md), and provider-expanded/capability feasibility is
checked at [Phase 8](phase_08_capability_binder.md)'s conditional post-bind infrastructure-planning and
provisioning boundary.

### Deliverables
- `test/dsl/DecodeSpec.hs` asserting: each `legal_*.dhall` positive fixture decodes to its `ClusterIR`; each
  `illegal_decode_*.dhall` Gate-2 negative first passes `dhall type` then returns the expected structured
  `Left DecodeError` whose tag matches its committed header; and every positive's decoded resource/capacity
  traversal exactly preserves execution id/revision and the complete kind-indexed controller/cardinality/
  policy/resource body while proving every kind's progress/render invariant; every deployment retains exactly one normalized
  `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` source with exact deployment/generation identity;
  CPU, memory,
  logical ephemeral-storage; `PodRuntimeMetadataSource`; physical-backing/carve identity and
  `PhysicalDiskPartition.allocatableRawBytes` plus each `NamedDiskCarve` parent index and extent-arm geometry;
  allocatable pod slots, driver-scoped CSI attach slots, each durable demand's node-local/CSI driver identity,
  layout-shaped node/VM filesystems, non-authorable mapped-file source/accounting-model operands, raw-VM
  presentation/allocation without an editable byte total, complete
  OCI stored-object/snapshot/workspace metadata and image model, durable/cache/registry/Vault storage,
  volume presentation and backing allocation policy, the provider target `CloudAccountId`, exact
  `podSlots`/CNI-IP `cniSlots`/driver-indexed `attachableVolumes`, complete provider-node-class/root-backing shape, and every
  `ProviderQuota` field/storage arm, every `PriorProvisionRefSource` deployment/generation/resource arm,
  the required whole-deployment first/update arm and separately branded `PriorExecutionProvisionRef`, plus
  each storage/registry/schema migration intent's replacement/policy/backing/chunk/concurrency operands,
  every `RegistryStorageIntent` image digest, ZooKeeper metadata, and every `PatroniSqlIntent` source operand,
  every supported controller descriptor's replica/rollout and complete child
  pod/PVC resource-source operands, every mandatory
  `MonitoringWorkBudget` field including `volume.presentation`, every `BuildExecutionEnvelope`
  stage/dependency/concurrency field, every
  role-indexed named `EngineSystemReserve` process and applicable engine-storage/history field, exact etcd
  desired-object/churn operands, exact Pulumi deploy/state-field/plugin/concurrency/workspace operands,
  BookKeeper quorum/fault/bookie-slot geometry, MinIO
  erasure/fault/drive-slot geometry, exact physical-id-keyed object-store residents plus structural
  additional-retention/concurrent/failed-write/orphan/admission bounds, `ObjectStoreGatewayIntent`, and all six
  `ObjectStoreProducerIntent` arms including the raw Registry arm's `RegistryStorageIntent`,
  every producer's required `StorageBudgetId` and the unique closed budget inventory/owner reference,
  uniform claim-slot/`DeclaredVolumeDemand` identity, root-filesystem arms, accelerator owner family/profile/
  device-count, exact source/workload key equality, coexistence-domain equality, structural residency byte/
  shard/interconnect declarations, concrete/template supply raw/reserved/net-VRAM/link declarations,
  and the substrate-indexed host enforcement arm plus finite Apple supervisor operands.
- A Phase-0-committed `tests/oracle/gate2/resource_field_inventory.tsv` that names the complete normalized
  field/union inventory independently of `decodeCluster`, plus committed decoder mutants that drop
  `ephemeralStorage`, erase a physical-carve or `allocatableRawBytes` field, erase a `NamedDiskCarve` parent
  index/extent arm/geometry field, erase `kubeletMetadataModel`
  or one runtime-metadata source identity, erase an execution id/revision/controller-kind/cardinality/
  replicated-count/per-node-selector/policy/Job-terminal-retention operand, weaken Deployment rolling to
  accept `{ 0, 0 }`, admit DaemonSet both-positive, add a StatefulSet feature-gated field/nonzero partition,
  cross a controller with the wrong resource/accelerator/replacement arm, drop the execution transition/ref
  deployment/generation/resource arm, accept `UpdateFrom` with the wrong resource arm or implicit latest
  generation, erase an accelerator
  source/workload/residency/coexistence operand, mismatch the
  coexistence domains, or corrupt sharded totals/ids/count; erase provider `podSlots`, `cniSlots`, or
  `attachableVolumes`, erase the
  target `CloudAccountId`, erase any exact `ProviderQuota` field, erase provider-class `quotaVcpu`, conflate a class-local
  template id with a concrete physical id, drop/substitute a raw `VmDiskCarve.id`, replace
  `MonitoringWorkBudget` with fixed Prometheus resources,
  replace a storage fault policy with an editable scenario list, drop orphan-GC/claim-slot fields, or delete
  layout/model/OCI-object/snapshot, VM presentation/allocation, provider root backing/root quota, volume
  presentation/backing allocation or `MonitoringWorkBudget.volume.presentation`, mapped-file/API-object/etcd-logical operands, storage/registry/schema-
  migration-intent/prior-ref operands, substitute a wrong prior resource arm/generation, admit both
  first-deploy and update fields instead of the closed union, inject a
  `Provisioned*` field into `ClusterIR`, add a duplicate Event record, drop one of the four nested Event-churn
  fields, or delete ZooKeeper/Patroni-intent operands,
  Pulumi-execution operands, controller child/rollout source operands,
  exact cache population, registry
  upload, object-store resident/retention/admission/producer identity, Vault Raft/audit, or host enforcement
  fields; the
  traversal/type inventory must reject each mutant independently.
- The **concretely named representative Gate-2 negative set** (§M clause 7), committed in Phase 0: **exactly
  one `illegal_decode_*.dhall` fixture per named `DecodeError` class** — `illegal_decode_schema.dhall`
  (`SchemaMismatch`), `illegal_decode_domain.dhall` (`OutOfDomainArm`), `illegal_decode_unspellable.dhall`
  (`UnspellableCombination`, a raw
  `RawDeploymentRolloutPolicy.RollingUpdate { maxSurge = 0, maxUnavailable = 0 }`) — each header citing
  the `illegal_state_catalog.md` entry it targets and each
  paired with a positive `legal_*.dhall` differing only in the foreclosed dimension (§M clause 8). Every one
  passes `dhall type` (Gate-1-green) by construction; the rollout case has both `{ 1, 0 }` and `{ 0, 1 }`
  legal controls.
- **A committed seeded mutant** (§M clause 2), committed and re-run: a legalized twin of
  `illegal_decode_schema.dhall` whose Gate-2-illegal index is corrected so the value would decode; the suite
  **must go red** when the mutant replaces its negative, demonstrating the "any illegal fixture decodes ⇒ red"
  check actually executes.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the decoder is checked non-partial and fail-closed
  in-process, but no runtime-enforcement claim is made.

### Validation
1. `cabal test dsl-spec` is green — positives decode; every `illegal_decode_*.dhall` negative first passes
   `dhall type` (suite red otherwise) and then returns the tagged `Left` matching its committed header; all
   three `DecodeError` tag arms have >=1 fixture (suite red if any arm is empty); and the deep-NF force and
   fail-closed assertions hold. Each positive's resource/capacity traversal is complete and normalized, and
   the dropped-resource-field decoder mutant turns the suite red.
2. The committed seeded mutant (the legalized twin of `illegal_decode_schema.dhall`) turns the suite **red**
   when substituted — a re-run, executed demonstration that "any illegal fixture decodes ⇒ red" is a live
   check, not a tautological restatement of the assertion's polarity.
3. The normalized resource-tree traversal matches `resource_field_inventory.tsv` on every positive and turns
   red under the committed dropped-`ephemeralStorage` decoder mutant; a decoder cannot pass by preserving only
   CPU/memory or collapsing accelerator/VRAM structure.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §5's Gate 2 to the in-process Phase-5 decoder; keep the
  runtime-enforcement half as Tier-2 residue owned by Phase 22.
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry the IR type-/decode-forecloses here
  with its realized foreclosure layer (layers 1–2 → Register-1); keep runtime-checked entries (layer 3)
  deferred, and keep capacity/topology/provider-feasibility entries deferred to the Phase-7 fold and Phase-8
  conditional infrastructure-planning/materialization/provisioning boundary.
- `documents/engineering/testing_doctrine.md` — record the Register-1 in-process ledger variant this gate
  emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-5 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-5 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius` cabal package, `src/Amoebius/Dsl/{Types,
  SmartConstructors,Ref,Decode,Error}.hs`, and the `dsl-spec` test-suite as Phase-5 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates; Gate 2 is adopted here
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §4 the typing techniques the
  IR carries; §2/§6 the load-bearing limit and the honest foreclosure-layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_04](phase_04_dhall_gate1_schema.md) — Gate 1, the Dhall schema this decoder mirrors
- [phase_06](phase_06_illegal_state_corpus.md) — the exhaustive illegal-state corpus, properties, and
  validation-locus ledger built atop this decoder
- [phase_07](phase_07_capacity_topology_folds.md) — the pure capacity/topology fold implementation and
  properties deferred from here; Phase 8 invokes them after bind/expansion while deriving the conditional
  infrastructure plan and again at the post-materialization provision seal
- [phase_22](phase_22_live_dsl_singleton.md) — the Tier-2 runtime-enforcement half of the DSL
