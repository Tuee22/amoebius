# Phase 62: Platform backbone (MetalLB + MinIO + Pulsar HA)

> **Purpose**: Stand up the platform backbone — MetalLB, MinIO, and Pulsar HA
> (brokers/ZooKeeper/BookKeeper/offload) — on a
> single-node linux-cpu cluster, each as its HA topology from Haskell-generated manifests and baked-binary
> images, rehoming Distribution `registry:2`'s blob store onto the MinIO S3 driver and proving a
> size-triggered Pulsar offload bounds the hot tier.
> **Read this if**: phase 62 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, documents/engineering/migration_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 62.1: MetalLB LoadBalancer + MinIO object substrate + registry S3-driver rehoming](#sprint-621-metallb-loadbalancer--minio-object-substrate--registry-s3-driver-rehoming-)
- [Sprint 62.2: Pulsar native-protocol backbone + size-triggered S3 offload drill](#sprint-622-pulsar-native-protocol-backbone--size-triggered-s3-offload-drill-)
- [Sprint 62.3: The backbone HA bring-up gate](#sprint-623-the-backbone-ha-bring-up-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 61, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase must turn the future gate-passed storage-and-secrets
cluster of Phase 61 into an amoebius cluster carrying the
platform backbone: the L4 LoadBalancer (MetalLB), the MinIO S3 object substrate, and the Pulsar
native-protocol event/workflow backbone (brokers, ZooKeeper metadata members, BookKeeper bookies, and
size-triggered S3 offload). Each must be rendered as
the byte-identical **HA topology even at `replicas=1`** and emitted as typed Kubernetes objects by the
Phase-58 `renderAll` path (no Helm and no third-party charts); emitted manifests are generated lazily from
Haskell beneath `.build/**`, remain untracked, and are absent from the repository. Each service is served from
binaries **baked into the native-architecture base image** with no
public-registry pull, and placed on the Phase-60 `no-provisioner` retained PVs where it holds durable state.

Two deferred gaps from earlier phases must close here. First, the **registry→MinIO S3-driver rehoming**: the
future Phase-56 Distribution `registry:2` state uses **interim node-local (filesystem-driver) blob storage**
with the MinIO S3 driver named as this phase's target; Phase 62 must move the registry's blob store onto MinIO
via the S3 driver, so the target registry holds no PV of its own and its bytes live in the object substrate. Second, the
**Pulsar size-triggered S3 offload**: a topic's hot tier (BookKeeper on retained PVs) is bounded by a size
high-water mark that offloads closed ledgers to MinIO, and the future gate must drill that the offload actually fires
under sustained ingest and that the hot tier never exceeds its cap.

The future rehome must be a verified migration, not a driver-only configuration edit, and must not erase or
replace the registry's capacity obligation. Phase 62 must preserve the artifact/upload
operands from Phase 56's canonical `RegistryStorageDemand` — every digest-keyed compressed
layer/config/manifest extent, bounded model-derived concurrent-upload workspace, and finite failed-upload residue through
observed GC — while the replacement demand changes only its backend arm from the interim volume to MinIO. The resulting private
`ProvisionedRegistryStorageDemand` must carry the same logical `objectSet`, structured physical-object plus
upload/partial `objectStorePeak`, scalar interim `derivedPeak`, mutation-admission, and upload/orphan witness;
its backend projection is intentionally different. A private `ProvisionedRegistryBackendMigration` derives an
exact source-digest→target-object map, transfer/verification Job `PodResourceEnvelope`, workspace, and
source+target per-backing high-water. Only the structured target peak enters MinIO's per-object
erasure/healing geometry. Every pre-existing Phase-56 artifact must be copied and independently digest-verified
before atomic driver cutover, then pulled by its old digest through the registry. Source filesystem residents
stay charged and readable until verification/cutover and remain charged with partial targets on failure; no
cleanup/reclamation is credited before it is observed. The target gets no speculative cross-backing dedup
credit.

The target scope stops at *standing the backbone up HA and establishing its data-plane round-trips, the
registry rehoming, and the offload bound*. The Percona-operator-managed per-consumer Patroni Postgres
clusters, pgAdmin, Prometheus/Grafana, and the **full derived readiness-DAG bring-up of the whole standard stack** are [Phase 63](phase_63_platform_services_2.md). The **Keycloak-owned ingress edge** — Envoy/Gateway
API terminating TLS and Keycloak owning all wild ingress so no workload publishes its own path — is
[Phase 64](phase_64_keycloak_ingress.md); this phase must bring the backbone up behind no public edge. The
Deployment-`replicas=1` control-plane daemon that will eventually *own* this reconcile loop is
[Phase 65](phase_65_live_dsl_deploy.md); the future gate must drive the reconciler from the operator/host path
against a fixed Haskell-declared service set so the backbone exists before the DSL and control-plane daemon that will describe
it.

**Phase scope:** one cohesive target claim — *the backbone must stand up as its HA topology from generated
manifests, and the registry's blobs must move onto it*. A size-triggered offload must establish that the
tiering path is exercised.

**Substrate:** linux-cpu ([§L](development_plan_standards.md#l-one-substrate-discipline)) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
specialized hardware feature is required. Every hardware substrate can always run this `linux-cpu` lane. If
the gate requires a pristine Linux host, use Incus on Linux or Linux-CUDA hardware, Lima on Apple hardware,
or WSL2 on Windows hardware.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed));
the future contract requires real cluster bring-up and independent runtime observations. A candidate ledger
may classify only that bounded observation as *tested*, never *proven*, and has no ability to set status.

**Depends on:** [Phase 61](phase_61_vault_pki.md)
**Gate:** `pb validate phase 62`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *the backbone stands up as its HA topology from generated manifests, and the registry's blobs move onto it*. A size-triggered offload is what proves the tiering is real. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 62` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 61; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes platform backbone (MetalLB + MinIO + Pulsar HA) causes to exist are charged to a grant that carries its ceiling and concurrency together.
- [`platform_services_doctrine.md §1 — the invariant: every cluster is the same cluster`](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster)
  with [`§2 — HA always, including replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1):
  Phase 62 materializes the backbone slice of the fixed standard service set on linux-cpu, each service the
  byte-identical HA topology a production cluster runs with only the replica count changed — no "dev topology,"
  no hand-special-cased single-Pod variant.
- [`platform_services_doctrine.md §4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate),
  [`§6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox),
  and [`§9 — the LoadBalancer and the single wild-ingress path`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (the MetalLB LoadBalancer half — the Keycloak edge is Phase 64): the concrete providers Phase 62 stands up
  behind the platform backbone.
- [`pulsar_client_doctrine.md §6.1 — topic storage lifecycle: bounded, tiered, retained, and the hot tier never overflows`](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows):
  the mandatory *size-triggered* S3 offload high-water mark on the BookKeeper hot tier — the load-bearing
  difference from a time-only trigger — is the invariant the offload drill exercises against the live cluster.
- [`image_build_doctrine.md §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster`](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster)
  and [`§9 — bring-up ordering: the registry chicken-and-egg dissolves`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
  every backbone binary is baked into the Phase-56 native-architecture base image and resolved only in-cluster; the
  registry stores its blobs in MinIO via the S3 driver, so MinIO must be serving before the registry — the
  thin ordering edge [`image_build_doctrine.md` §9 — Bring-up ordering — the registry chicken-and-egg dissolves](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves) names, and the rehoming Phase 62 delivers.
- [`manifest_generation_doctrine.md §5 — the apply/reconcile engine: snapshot-bound typed actions`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  and [`§2 — the typed manifest model (`renderAll` is the sole public pure function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
  Phase 62 reuses the Phase-58 pure `renderAll :: ProvisionedSpec -> [K8sObject]` and typed-action reconciler
  whose **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the backbone.
- [`platform_services_doctrine.md §10 — every execution unit declares its complete resource envelope`](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope)
  and [`resource_capacity_types.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`; “The systematic provision matrix”](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix) / [`§5.1 — durable demand is logical first, physical only after geometry`](../documents/engineering/resource_capacity_storage.md#51-durable-demand-is-logical-first-physical-only-after-geometry):
  every rendered app/init/sidecar container carries the exact provisioned CPU, memory, and ephemeral-storage
  requests/limits; bounded pod-local volumes and durable presentation/usable/raw sizes are exact; and accelerator `None` is
  explicit alongside cache `None` for this linux-cpu service set. Kubernetes fields are a projection of the
  checked pure value, not a second resource declaration. Durable sizes are the output of complete
  BookKeeper quorum/recovery, ZooKeeper metadata log/snapshot/recovery, and MinIO erasure/healing physical
  folds, while MinIO's logical input includes every exact physical resident map plus structural
  future/concurrent/orphan extents from the six closed producer arms; logical bytes are never copied
  straight into raw PVC capacities. Each slot first applies filesystem overhead and backing quantum; unequal
  ordinal requirements are then projected through the actual StatefulSet constraint: one uniform
  `provisionedBytes` per `volumeClaimTemplate`, debited as max rounded ordinal allocation times ordinal count.
  The rehomed registry contributes a MinIO-bound `ProvisionedRegistryStorageDemand` whose
  logical `objectSet`, structured `objectStorePeak`, scalar interim `derivedPeak`, admission, and upload/orphan
  witness are unchanged from Phase 56 — including compressed objects,
  configs/manifests, model-derived concurrent-upload workspace, and retained failed-upload extents — before that physical
  fold; it is not recounted from tags or a scalar blob allowance. The rehome additionally provisions the
  digest-complete old→new copy/verify transition and its Job/workspace before cutover.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each stateful backbone service (MinIO, Pulsar's ZooKeeper members and bookies) lands its durable bytes on the Phase-60
  `no-provisioner` retained PVs, born only from a StatefulSet `volumeClaimTemplate`.
- [`testing_doctrine.md §2 — the registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing):
  this phase's future gate is a Register-3 live bring-up on `linux-cpu`; a candidate ledger may mark only its
  bounded runtime observation *tested*, never proven, and must leave later edge/reconcile layers unverified.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.

## Sprint 62.1: MetalLB LoadBalancer + MinIO object substrate + registry S3-driver rehoming ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 61](phase_61_vault_pki.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`platform_services_doctrine.md §9 — the LoadBalancer`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
(the MetalLB half), [`§4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate),
and [`image_build_doctrine.md §9 — bring-up ordering`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
render and reconcile MetalLB as the linux-cpu L4 entry point and MinIO as the HA S3 object substrate, then
rehome the Phase-56 Distribution `registry:2` blob store off the interim node-local filesystem driver onto the
MinIO S3 driver — closing the Phase-56 deferred gap.

### Deliverables

- MetalLB rendered as a standard service that publishes a LoadBalancer address on the kind node, available
  before the (Phase 64) Envoy/Gateway edge needs one — the backbone's LoadBalancer root.
- MinIO (HA / distributed) as the S3 object substrate on Phase-60 retained PVs, holding the content store,
  the Pulumi backend, and app buckets (roles owned by their sibling doctrines; this phase only stands the
  service up); a put/get round-trips.
- A closed MinIO storage provision: logical object extents for every resident tenant; a
  six-arm `ObjectStoreProducerDemand` inventory whose every present producer carries a resolved
  `StorageBudgetId`, exact physical identities, an `ObjectStoreWriteBudget` with bounded concurrent write sets,
  bounded failed writes and a finite positive orphan-GC horizon, plus mutation admission; data/parity/block
  geometry; per-drive metadata and healing workspace; a finite fault
  policy whose complete drive-failure subsets are derived by the solver; claim/backing/`VolumePresentation`
  per drive; and the uniform `volumeClaimTemplate` plan
  (`max rounded provisionedBytes × ordinal count`) that debits the retained backing.
- The Distribution `registry:2` blob store rehomed onto the MinIO S3 driver — the registry holds no PV of its
  own, its bytes live in MinIO — asserted against a separately authored Haskell storage-stanza expectation,
  with the Haskell changed-production-subject mutant `M-registry-fs-driver` (registry left on the
  interim filesystem driver) named as the mutant this rehoming assertion MUST turn red. The logical tenant
  extent supplied to MinIO is a private `ProvisionedRegistryStorageDemand` whose logical
  `objectSet`, structured `objectStorePeak`, scalar interim `derivedPeak`, mutation admission, and upload/orphan
  witness exactly match Phase 56's interim provision and whose
  backend arm is MinIO. It is
  derived from canonical `RegistryStoredArtifact`/`RegistryStorageDemand`; the rehome cannot author a
  replacement byte total, omit configs/manifests or failed-upload residue, or claim deletion before the
  observer sees it.
- A `RegistryBackendMigrationDemand` from the still-live Phase-56 private provision to the MinIO replacement.
  Its private result retains the complete digest→target-object map, source and target provisions, copy/verify
  Job envelope, workspace, and per-backing high-water. Cutover occurs only after every pre-existing artifact
  digest verifies and can be pulled through the target; a failed copy keeps the source route and all partial
  target bytes. The old filesystem receives no new writes after cutover but remains charged until cleanup is
  observed.
- The sole object-write gateway's complete image/CPU/memory/ephemeral/log/writable/replica/rollout envelope,
  derived from the merged writer admission policies and placed before MinIO or any producer can mutate.
- Exact complete provision on every rendered app/init/sidecar container and volume: CPU, memory, and
  ephemeral-storage requests/limits; bounded pod-local `emptyDir` volumes; durable PVC/PV
  presentation/rounded sizes equal to the
  checked **uniform claim plan** (which may conservatively pad a smaller ordinal above its raw drive demand);
  cache `None`; and accelerator `None` with no device claim on linux-cpu. Images resolve only in-cluster.

### Validation

1. Apply through the Phase-58 reconciler; assert MetalLB advertises an address and MinIO reaches its Ready
   condition as a distributed StatefulSet on identity-named retained PVs.
2. Round-trip an admitted object-gateway put/get; assert the bytes are unchanged, and assert the same writer
   cannot issue a direct MinIO PUT.
3. Assert the registry is serving from the MinIO S3 driver: its storage config is structurally equal to the
   separately authored Haskell expectation (not read from the running config), every object of
   a pre-existing Phase-56 artifact was copied/verified and that artifact still pulls by the same digest, and a
   new blob pushed after cutover materializes in MinIO without changing the old filesystem. The Haskell
   changed-production-subject mutant `M-registry-fs-driver` turns this red.
   Compare the Phase-56 and Phase-62 private registry witnesses: `objectSet`, structured `objectStorePeak`,
   scalar interim `derivedPeak`, admission, and the upload/orphan witness must match in the replacement while
   its backend differs; then independently validate the additional migration witness and derive the MinIO
   physical demand from that logical tenant. Independently compare the exact source→target object map and
   source+target+workspace high-water, and assert the live transfer Job equals its complete provisioned
   envelope. Exercise resident/new digest dedup, conflicting stored
   bytes for one digest, maximum upload concurrency/model-derived workspace, partial-upload residue just before GC, and a
   retained target one byte under the physical result, old+new backing one byte short, transfer executor one
   unit short, and an injected verify mismatch. Capacity failures yield zero writes — no reconcile request and
   no publish request is issued; verify failure leaves the source route live and both source/partial-target
   charged; exact fit verifies then cuts over.
4. Run the independent MinIO capacity corpus.
   - Cover all six closed arms and require source↔producer equality for the present deployment; reject a
     dropped arm (including control-plane state), writer admission, storage budget, or mismatched owner.
   - For the same logical byte total, vary full physical object identities/counts and prove per-object
     stripe padding changes demand; the same digest under two namespaces remains two objects, while one
     identical full id deduplicates and conflicting sizes reject.
   - Vary data/parity geometry, stripe boundary, healing fault bound, concurrent-write bound, failed-write
     rate, and orphan-GC horizon; recompute every required unavailable-drive subset, the required cross-set
     Cartesian products, and each per-drive steady/healing peak independently.
   - Include exact-fit and one-byte-over usable cases, a one-quantum-under raw allocation, a
     logical-fit/erasure-physical-overflow case, an existing orphan just before its horizon, Pulsar
     segment-rate×deletion-lag and failed-offload horizon boundaries, Pulumi exact-state-field/encryption
     old+new-revision and failed-checkpoint horizon boundaries, control-plane-state old/new CAS plus
     failed-write horizon boundaries, and a deliberately skewed per-ordinal map where the pre-presentation
     sum fits but `max(provisionedBytes) × ordinalCount` does not.
   - Direct S3 writes are denied while each in-envelope writer capability succeeds through the gateway.
   - Also make producer storage fit while the gateway pod is one CPU, memory, ephemeral byte, or pod slot
     short; it must reject before any S3 write.
   - Require zero storage/API writes for every rejection and require the Haskell changed-production-subject
     mutants `M-storage-logical-as-physical`, `M-storage-drop-required-fault-scenario`,
     `M-storage-sum-unequal-ordinals`, and `M-content-store-immediate-gc` each to turn red.
5. Assert every app/init/sidecar container and volume in the `renderAll`-emitted MetalLB/MinIO/registry objects
   (scope = `amoebius` field-manager-owned objects only) is an **exact** projection of its
   `ProvisionedServiceSpec`: CPU/memory/ephemeral-storage requests+limits, each disk-backed
   `emptyDir.sizeLimit`, each PVC/PV's uniform presentation/rounded capacity and usable witness, cache `None`,
   and accelerator `None`/absence of a device claim.
   Recompute the effective pod request/limit using app sums, largest-init semantics, and pod overhead, and
   require equality with the stored placement witness. Then assert
   the containerd/CRI image-pull event log on the kind node (§M.5 OS-boundary observer, not amoebius's own
   logging) records no public-registry pull; every service image except Registry resolves to the Phase-56
   baked-base digest, while Registry resolves to the exact separately pinned and preloaded Distribution
   `registry:2` image digest. A deny-all egress test to `docker.io`/`quay.io` must
   break no startup, which shows the cluster does not reach outward — the digest check, not the egress test,
   is what discriminates a baked bring-up from a side-loaded upstream image.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 62.2: Pulsar native-protocol backbone + size-triggered S3 offload drill ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 62.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`platform_services_doctrine.md §6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox)
and [`pulsar_client_doctrine.md §6.1 — topic storage lifecycle`](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows):
render and reconcile Pulsar as the cluster's HA native-protocol pub/sub backbone with ZooKeeper metadata and
BookKeeper ledger storage on retained claims, delegating its intra-cluster consensus to those components
rather than re-proving it, and
drill that the mandatory size-triggered MinIO offload actually bounds the BookKeeper hot tier.

### Deliverables

- Pulsar (HA broker + ZooKeeper metadata ensemble + BookKeeper bookie) rendered as typed objects on retained
  PVs, images baked, every app/init/sidecar
  and volume carrying its exact provisioned CPU/memory/ephemeral-storage, bounded pod-local storage, durable
  uniform-claim size, cache-`None`, and accelerator-`None` projection; the native TCP binary protocol only (the
  no-WebSockets invariant), with the client-side
  `amoebius-pulsar` protocol details owned by the Pulsar client doctrine and referenced, not re-specified.
- A closed BookKeeper storage provision: explicit ensemble/write/ack quorum geometry and segment size;
  per-bookie journal/index reserve; a finite bookie fault policy from which the solver derives every required
  failure/re-replication subset; the per-bookie steady/recovery maximum; and the final uniform StatefulSet
  claim-template plan whose max ordinal size times bookie count, not logical hot bytes or the unequal raw sum,
  is debited from retained storage.
- A closed `PulsarMetadataStoreDemand = ZooKeeper` provision: exact persistent/session-ephemeral znode
  identities and maximum payloads, bounded transactions/sessions/watches, complete member pod envelopes,
  retained transaction-log/snapshot volumes, and a finite unavailable-member bound. The pinned model derives
  each member's steady/recovery high-water and uniform rounded claim plan; brokers cannot start until every
  member resource/volume fits and the ensemble is Ready. BookKeeper/offload bytes cannot fund this provision.
- Bounded per-topic retention with a **size-triggered MinIO offload** (no unbounded storage, no time-only
  trigger), wired to the Sprint-56.1 MinIO substrate; the drill topic's hot-tier size cap is a separately
  authored Haskell expectation, with the Haskell changed-production-subject mutant `M-offload-time-only`
  named as the mutant the offload drill MUST turn red.
- A produce/consume round-trip demonstrating at-least-once delivery with broker-side dedup.

### Validation

1. Apply Pulsar through the reconciler; assert the ZooKeeper metadata ensemble reaches Ready first and the
   broker/bookie set then reaches Ready on retained storage as an HA topology (never a single bare broker).
   Assert a secret-dependent Pulsar component that reaches a sealed Vault fails closed rather than starting
   degraded.
2. Produce then consume a message; assert an at-least-once round-trip. Dedup is **exercised**: inject a
   duplicate (a redelivery of the same producer-sequence id) and assert the consumer observes exactly one
   delivery — not merely that broker-side dedup is enabled on the topic. Assert a CBOR payload round-trips
   byte-for-byte (full native-client proof deferred to Phase 67, marked UNVERIFIED here).
3. Drill the size-triggered offload: produce past the separately authored Haskell hot-tier-cap expectation on
   the drill topic and assert (a) offloaded ledger objects appear in the MinIO bucket (external observer on the
   object substrate) and (b) BookKeeper/broker hot-tier occupancy — read from broker metrics at the OS boundary,
   never an amoebius self-report — never exceeds the cap. Assert the Haskell changed-production-subject
   `M-offload-time-only` mutant
   (size trigger removed) breaches the cap under the same ingest, since a time-only trigger cannot bound
   occupancy.
4. Run the independent BookKeeper capacity corpus across unequal quorum choices, segment-boundary rounding,
   journal/index reserve, and each complete failure-subset family derived from the declared fault bound.
   Include exact-fit and one-byte-over per-bookie cases, a logical-hot-total fit whose write-quorum physical
   demand fails, a recovery-only overflow, a filesystem-overhead/one-quantum overflow, and a skewed ordinal
   placement whose unequal pre-presentation sum fits but the uniform
   `max(provisionedBytes) × ordinalCount` plan fails. Every rejection performs zero storage/API writes; the
   Haskell changed-production-subject mutants `M-storage-logical-as-physical`,
   `M-storage-drop-required-fault-scenario`, and `M-storage-sum-unequal-ordinals` each turn red.
   Run the independent ZooKeeper corpus across znode payloads, transaction/session/watch bounds, retained
   logs/snapshots, and every failure-recovery case. A topology where brokers, bookies, and offload all fit but
   one ZooKeeper member CPU/memory/ephemeral/PVC/backing is one unit/byte short must reject before any Pulsar
   object is applied. Haskell changed-production-subject mutants dropping the metadata store, a znode class,
   or recovery overlap go red.
5. Assert every app/init/sidecar container and volume is an exact projection of its
   `ProvisionedServiceSpec` across CPU, memory, ephemeral storage, durable presentation/usable/raw storage,
   cache `None`, and accelerator `None`; every BookKeeper PVC/PV capacity equals the recomputed uniform rounded
   plan and each mounted fsType/usable capacity matches its witness, not an ordinal-specific raw demand.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 62.3: The backbone HA bring-up gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 62.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §5 — the apply/reconcile engine`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
and [`image_build_doctrine.md §9 — bring-up ordering`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
assemble the Sprint 62.1–27.2 backbone services, bring them up event-driven behind the reconciler's
wait-for-ready with the MinIO-before-registry and Vault-unsealed-before-Pulsar edges as observed conditions,
and close the phase with the backbone HA gate on a fresh cluster.

### Deliverables

- A backbone bring-up that applies MetalLB, MinIO, the rehomed Distribution `registry:2` service, and Pulsar through the
  Phase-58 reconciler, each dependent starting on its dependency's observed-ready edge (MinIO serving before
  the registry's S3-driver blob store; Vault initialized-and-unsealed before Pulsar's secret-dependent startup —
  the fail-closed condition of [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init)),
  never a `threadDelay`.
- The phase-gate harness: bring the whole backbone up on a fresh single-node linux-cpu `kind` cluster and
  assert the set is up, HA-shaped, from manifests generated lazily beneath `.build/**` and absent from the
  repository, plus baked binaries, with a
  proven/tested/assumed Register-3 ledger that marks the runtime layer *tested* and the Keycloak-edge,
  Postgres/observability (Phase 63), and control-plane-owned reconcile layers UNVERIFIED; the independent
  resource-projection checker compares every applied execution unit/volume exactly to its
  `ProvisionedServiceSpec`. Only the two thin MinIO→registry and Vault-unsealed→Pulsar edges are enacted here;
  the *full* derived readiness-DAG bring-up of the whole standard stack, with the
  [§11](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering) hard edges
  and the `M-dag-drop-edge` Haskell mutant, is [Phase 63](phase_63_platform_services_2.md)'s.
- The separately authored Haskell gate expectations reused here: the registry storage stanza, the drill-topic
  hot-tier cap, and the storage-geometry boundary table covering BookKeeper/MinIO exact-fit, one-byte-over,
  recovery/healing, orphan horizon, and uniform-ordinal rounding. The gate also reconstructs the Phase-25
  private registry logical witness from its Haskell case declaration and checks the independently authored
  mapping into MinIO physical geometry. The Haskell changed-production-subject mutants
  `M-registry-fs-driver`, `M-offload-time-only`, `M-storage-logical-as-physical`,
  `M-storage-drop-required-fault-scenario`, `M-storage-sum-unequal-ordinals`, and
  `M-content-store-immediate-gc` are re-run on every candidate; any serialized views are generated lazily under
  `.build/**` and remain untracked.

### Validation

1. Bring the backbone up on a fresh cluster; assert MetalLB advertises an address, MinIO and Pulsar reach
   Ready as HA topologies, and the registry serves from the MinIO S3 driver — each dependent observed to start
   only on its dependency's observed-ready condition, with no timer standing in for a condition.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled backbone; assert the registry
   rehoming holds (a pushed blob is a MinIO object) and the size-triggered offload holds the hot tier under the
   Haskell-declared cap; assert the Haskell changed-production-subject mutants `M-registry-fs-driver` and
   `M-offload-time-only` each
   turn their assertion red.
3. Recompute the Haskell storage-geometry boundary table with the independent Haskell checker and compare it with the opaque
   storage provision. Assert every BookKeeper recovery and MinIO healing subset required by its finite fault
   policy is present; every logical extent has its replication/erasure/metadata/workspace amplification; the
   content peak includes concurrent and full-horizon failed writes; the registry tenant's private
   replacement `objectSet`, `derivedPeak`, and upload/orphan witness exactly match Phase 56 while its backend
   is MinIO, and the separate source→target migration witness is complete, including
   manifest/config extents, bounded model-derived upload workspace, and pre-GC partial residue; and each
   StatefulSet template's PVC/PV presentation/rounded size and retained-backing debit equal
   `max(provisionedBytes) × ordinalCount`. Re-run all four storage mutants named in the
   deliverable and require each to turn red before any apply path receives a token.
4. Assert the whole backbone is up and HA-shaped from manifests generated lazily beneath `.build/**` plus
   baked-binary images. "HA-shaped"
   is the render-diff predicate: each service's applied manifest is byte-identical **modulo the replica-count field(s)** to the same service rendered at `replicas=n` (MinIO erasure-set, Pulsar
   multi-broker/ZooKeeper/bookie), not
   a standalone/single-broker variant. **Manifest provenance (§M.3):** re-run the pure `renderAll` in-process at
   gate time and assert the SSA-applied object bytes under the `amoebius` field manager are byte-identical to
   that output, foreclosing hand-written or `helm template`-derived YAML embedded as string constants. **Image provenance (§M.5):** "no public-registry pull recorded" is read from the containerd/CRI image-pull event log
   on the kind node (the OS-boundary observer, never amoebius's own logging) over the whole gate window,
   **and** every running container's `imageID` digest (`kubectl get pods -A -o jsonpath={..imageID}`) MUST
   equal the digest in the passing Phase-56 architecture test record and current in-cluster `registry:2` catalog — any
   other digest or public-registry reference (including
   an upstream image pre-side-loaded onto the node with `kind load`) fails. **Resource-provision identity:**
   independently compare every applied app/init/sidecar CPU/memory/ephemeral-storage request+limit, bounded
   `emptyDir`, uniform-template PVC/PV capacity, cache-`None`, and accelerator-`None` projection to the opaque
   `ProvisionedServiceSpec`; recompute each effective pod envelope including ordinary and restartable-init
   sidecar semantics plus overhead; and
   require exact equality, not field presence. Emit the Register-3 ledger, runtime
   layer *tested* not *proven*, with the Keycloak edge, Phase-63 Postgres/observability, and control-plane-owned
   reconcile marked UNVERIFIED.

### Remaining Work

The historical copied expected-base-digest input is condemned residue and cannot be recreated. Pass the
verified Phase-56 digest directly as authenticated run input and rerun only after the gate contract and
predecessor gate pass are resolved; any materialized view belongs under ignored `.build/**`.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §2 HA-always and §4 MinIO
  notes flip from "design intent" to a Register-3-tested amoebius result on linux-cpu, and the §6 Pulsar
  honesty note gains its first live evidence (still *tested*, never *proven*).
- `documents/engineering/image_build_doctrine.md` — the §9 "registry stores its blobs in MinIO via the S3
  driver" edge is delivered; the Phase-56 interim filesystem-driver residue is discharged, recorded as the
  Phase-62 rehoming.
- `documents/engineering/pulsar_client_doctrine.md` — the §6.1 size-triggered offload bound gains its first
  live drill (the platform-side bring-up); the native-client CBOR round-trip proof stays owned by Phase 67.
- `documents/engineering/resource_capacity_doctrine.md` — record the standard-backbone live assertion that
  every Kubernetes resource/volume field is the exact projection of its checked `ProvisionedServiceSpec`,
  including the logical→physical BookKeeper/MinIO folds and uniform StatefulSet claim-plan debit.
- `documents/engineering/storage_lifecycle_doctrine.md` — the §2 no-provisioner storage class and §4
  deterministic PV naming and explicit bind gain their first Register-3-tested evidence as MinIO and Pulsar's
  ZooKeeper/BookKeeper members land their durable bytes on identity-named retained PVs born from StatefulSet
  `volumeClaimTemplate`s.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-62 status when the gate passes and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 62's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — reconcile the Phase-62 `Amoebius.Platform` Haskell module names
  named in each sprint against the component inventory once they become concrete.

## Related Documents

- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the standard service set (MetalLB/MinIO/Pulsar backbone) adopted here
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the [§6.1](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows) size-triggered offload lifecycle the drill exercises
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the Phase-58 renderer + SSA wait-for-ready that applies and sequences the backbone
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base image, pull-only-in-cluster, and the registry→MinIO S3-driver edge
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained PVs the stateful backbone services land on
- [phase_56](phase_56_base_image_registry.md) — the base image + Distribution `registry:2` service whose interim filesystem-driver blob store this phase rehomes onto MinIO
- [phase_61](phase_61_vault_pki.md) — the root Vault/PKI whose unseal edge gates Pulsar's secret-dependent startup here
- [phase_63](phase_63_platform_services_2.md) — the Percona/Patroni + pgAdmin + observability services and the full derived readiness-DAG gate that build on this backbone
- [phase_64](phase_64_keycloak_ingress.md) — the Keycloak-owned ingress edge that fronts this backbone next
- [phase_67](phase_67_pulsar_client.md) — the native `amoebius-pulsar` client whose full CBOR round-trip proof this phase defers
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
