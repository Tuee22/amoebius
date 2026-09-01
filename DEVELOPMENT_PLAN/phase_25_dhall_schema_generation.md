# Phase 25: Haskell-derived Dhall projection and smart-constructor prelude

> **Purpose**: Define the typed DSL surfaces and smart-constructor prelude in Haskell, then lazily project the
> Dhall representation and all typechecking cases beneath `.build/dhall/**` for a Haskell-owned verdict.
> **Read this if**: phase 25 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 25.1: Dhall prelude + typed surfaces + smart constructors](#sprint-251-dhall-prelude--typed-surfaces--smart-constructors-)
- [Sprint 25.2: dhall-typecheck positive corpus](#sprint-252-dhall-typecheck-positive-corpus-)
- [Sprint 25.3: dhall-typecheck-class negative corpus + partial-foreclosure ledger](#sprint-253-dhall-typecheck-class-negative-corpus--partial-foreclosure-ledger-)
- [Sprint 25.4: The shared `SecretRef` union and the plaintext-secret negative](#sprint-254-the-shared-secretref-union-and-the-plaintext-secret-negative-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 24, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Haskell declarations are the sole repository-owned source for the
cluster, application, and deployment-rules surfaces. A total Haskell generator is to materialize their Dhall
projection, positive cases, and minimally different negative cases only beneath `.build/dhall/**`; none of
those rendered files is tracked source or an oracle. The Haskell validator is to run the Dhall typechecker over
that run-local projection and compare its observations with separately authored Haskell expectations. This
layer can foreclose only structural syntax; binding- and index-shaped refusals remain Phase-26 obligations.

**Phase scope:** one target claim — the Haskell-defined structural language projects to Dhall with no syntax
for the named illegal shapes. The target gate runs through the Haskell binary and mints no verdict about
binding, effects, hardware, or runtime enforcement.

**Substrate:** none — no host, cluster, browser, or hardware; only the canonical Haskell gate may interpret
the generated typechecker observations.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 24](phase_24_conformance_gate_generator.md)
**Gate:** `pb validate phase 25`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target only — Haskell declarations generate the Dhall structural language and Haskell-owned cases beneath `.build/dhall/**`; the generated projection has no syntax for the named illegal shapes. Binding, effects, hardware, and runtime enforcement remain outside the claim. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 25` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Legacy closure` | UNRESOLVED — blocks validation: Phase-25-owned `LTD-SRC-002` remains active. Its exact whole-family zero-finding check (278 `.dhall` paths plus `dhall/examples/locus_registry.tsv`), reintroduction negatives, separately authored Haskell binding, and sprint-level owner assignment have not yet been demonstrated by a passing gate. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 24; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every Dhall schema and
  case is a lazy projection beneath `.build/**`, never repository-owned source.
- [`dsl_doctrine.md` §2 — Two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
  the hard split between the two languages. Haskell owns the repository-side declarations and generates the
  Dhall data projection lazily; an external operator may supply a Dhall value, but amoebius tracks no Dhall
  source. The Dhall never "runs"; it is type-checked and, from Phase 26 onward, decoded by Haskell.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  specifically **dhall-typecheck — the Dhall typechecker**, targeted here as the authoring-time structural boundary
  of the later `decode → bind/expand → plan/resolve infrastructure → provision → ProvisionedSpec → renderAll` contract. A union with no arm
  for insecure ingress gives no syntax to request it; a record that requires a reference gives no way to
  omit it. gadt-decode (the in-process typed decoder) is deferred to [Phase 26](phase_26_gadt_decode_ir.md);
  whole-deployment feasibility and the opaque deployable seal are Phase 31.
- [`illegal_state_catalog.md §1 — Illegal states fail to type-check`](../documents/illegal_state/illegal_state_catalog.md#1-illegal-states-fail-to-type-check),
  [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it),
  [`illegal_state_catalog.md` §3 — The catalog — states a valid spec cannot represent](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent),
  and [`illegal_state_catalog.md` §4 — Planning ownership](../documents/illegal_state/illegal_state_catalog.md#4-planning-ownership): the catalog of
  illegal states and the typing techniques that foreclose each, adopted **at the honest foreclosure layer**.
  The target Haskell corpus must cover layer-1 closed unions, required fields, and missing arms through the
  generated Dhall projection; decoder-local checked rejections defer to Phase 26, whole-deployment checks to
  Phase 31's `provision-seal`, and runtime-checked entries defer to the live band. The catalog's [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it) limit is
  honored verbatim: *a type-check proves the spec composes, not that the
  cluster enforces it.*
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget):
  the one pure resource vocabulary. The target typecheck boundary owns the **presence and closed shape** of every
  `ResourceEnvelope`/`Capacity` declaration; Phases 26, 9, and 28 own normalization, arithmetic feasibility, and
  post-bind provisioning respectively. Explicit declarations here are not a claim that the target has enough
  real capacity. This doctrine carries no Documentation-Requirements doc-sync line here because its honest
  verification layer flips at Phase 9 (capacity arithmetic), not at dhall-typecheck; its absence from the doc-update
  block is therefore intentional.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Historical sprint results.** Every earlier completion statement or result in the sprint bodies below is historical context. The material is retained
> only as a target-capability inventory and is not a current gate result.

## Sprint 25.1: Dhall prelude + typed surfaces + smart constructors ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 24](phase_24_conformance_gate_generator.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`dsl_doctrine.md §2/§5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
stand up the three typed Dhall surfaces (cluster, app-spec, deployment-rules) as *data* carrying parameters
not logic, and expose them only through smart constructors so that dhall-typecheck — the Dhall typechecker — becomes
an authoring-time boundary that fires before any binary runs.

### Deliverables

- The last three schema modules close doctrine surfaces that no phase previously owned, so each is delivered
  here rather than left absent:
  - The Haskell `ExtensionSpec` declaration projects `.build/dhall/amoebius/Extension.dhall` with its
    **mandatory, non-optional**
    `extMonitoring : NonEmpty MonitoringSurface` and the closed `MonitoringSurface` union
    ([`dsl_doctrine.md §8`](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-extension-astcheck-admits)),
    so an extension declaring no monitoring has no inhabitant.
  - The Haskell consistency declaration projects `.build/dhall/amoebius/Consistency.dhall` with the PACELC surface
    ([`consistency_pacelc_doctrine.md`](../documents/engineering/consistency_pacelc_doctrine.md)) that
    [Phase 75](phase_75_gateway_migration_drills.md) consumes.
  - The Haskell backup declaration projects `.build/dhall/amoebius/Backup.dhall` with the closed `BackupPolicy`
    ([`backup_recovery_doctrine.md`](../documents/engineering/backup_recovery_doctrine.md)), cross-cutting
    invariant #23. Phases 0–95 own the *declarable* policy; its live enactment — the put-only credential and
    the copy/verify `Job` — is the named candidate phase in [`later_phases.md`](later_phases.md), so the
    surface is owned rather than merely absent.
- A Dhall prelude and record/union types exposing only *smart constructors* — a vocabulary with no illegal
  words: the **9-arm** no-product `Capability` union (catalog [§3.12](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability)) — `ObjectStore`, `SecretStore`,
  `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`, and `InferenceEngine`, the ninth arm
  ([`service_capability_doctrine.md` §4.1](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored));
  eight of the nine are cluster-invariant, `InferenceEngine` is offered where an ML extension provides it, and
  the arm-inventory oracle pins all nine so Phase 30 binds and Phase 32 provisions the same union;
  no-unbounded-arm `StorageBacking` /
  `Growable` (catalog [§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere)/[§3.21](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)); the odd-quorum `Rke2Servers = ⟨Single|Ha3|Ha5⟩` (catalog [§3.24](../documents/illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)); the
  explicit `Rke2AgentPool = ⟨Fixed|Autoscaled { floor, policy }⟩` and derived
  `NodeSupply = ⟨Fixed (NonEmpty Node)|Elastic { floor, candidates, quota }⟩`;
  mandatory size-triggered `RetentionPolicy` (catalog [§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)); and a `Ingress`/route surface with **no**
  insecure/backdoor arm (catalog [§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)) — each encoded as a closed union, a required field, or a no-arm shape.
- The Haskell **build/image closures**, lazily projected as `.build/dhall/amoebius/Image.dhall`, apply the same
  shape to the artifact an app
  ships as rather than the spec it is described by: the three-arm `ImageIdentity`
  (`KindNode | Base | Runtime { linked }`) with **no foreign, free-digest, or `Url` arm** (catalog
  [§3.74](../documents/illegal_state/illegal_state_lifecycle.md#374-a-container-image-amoebius-did-not-generate)); the
  `BakeStep` content union with **no `RunShell : Text` arm** (catalog
  [§3.76](../documents/illegal_state/illegal_state_lifecycle.md#376-a-build-stage-whose-content-is-unmodeled)); and the
  required `ContainerProcess` naming what a container executes (catalog
  [§3.75](../documents/illegal_state/illegal_state_lifecycle.md#375-a-container-whose-process-is-unnamed)). Their
  negatives — Haskell-generated cases naming a foreign image, requesting an unmodeled shell fragment, or
  omitting `process` — must each fail `dhall type` at the separately authored Haskell expectation; serialized
  cases and diagnostics exist only beneath `.build/**`.
- The pure resource declarations of
  [`resource_capacity_doctrine.md §3`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget):
  unit-tagged quantity fields; `PodResourceVec = { cpu, memory, ephemeralStorage }`; `Resources = {
  requests, limits }`; the optional declared compute headroom `ComputeHeadroomDemand = { reason, pad }` on
  `PodResourceEnvelope` and its `HostComputeHeadroomDemand` mirror on `HostResources`, whose `reason` is the
  closed `⟨VerticalGrowth {horizon}|BurstAbsorption|NeighbourIsolation|DefragmentationReserve⟩` and whose
  `pad` is a `Residualized` vector — required and non-defaultable when the headroom is present, so a pad has
  a stated justification or no constructor at all, exactly as an rke2 agent has no editable empty
  control-plane placeholder.
  - dhall-typecheck offers **no reserved/padded-total field anywhere**: `requests`, `limits`, and the pad are
    authorable, the reservation they sum to is not, mirroring the deliberately absent authorable rounded
    physical-byte shortcut for durable and root-EBS creation.
  - The `requests + pad ≤ limits` bound and the all-`Zero` pad rejection are cross-field and arithmetic, so
    dhall-typecheck proves only presence and closed shape and [Phase 26](phase_26_gadt_decode_ir.md) refines both;
    raw `ExecutionUnitIntent` with stable id/revision and one kind-specific controller arm; the structural
    `NodeEligibilitySelector = { allOf : Set NodeEligibilityConstraint }`, where the constraint is the
    closed union `EngineRole | ProviderClass | Site | AcceleratorProfile | CarriesTaint` over typed
    inventory handles and has no free-text label-selector/toleration arm.
  - Deployment/StatefulSet carry only `Once | Replicated { desiredReplicas : PositiveNatural }`;
  - DaemonSet carries the selector directly;
  - Job carries positive completions/parallelism, finite backoff, `podRestartPolicy=Never`, a finite
    amoebius terminal-cleanup horizon/model, and `podReplacementPolicy=Failed`;
  - HostProcess carries `Once | PerNode`.
  - Policies are kind-specific as pinned by the field oracle.
  - Dhall preserves Deployment's two `Natural` rolling operands but cannot express their cross-field
    progress invariant;
  - gadt-decode rejects both zero.
  - DaemonSet RollingUpdate is structurally `Surge PositiveNatural | Unavailable PositiveNatural`, and
    StatefulSet uses only native serial partition zero; every deployment rules value carries exactly one
    `ExecutionTransitionIntent = FirstDeployment | UpdateFrom PriorProvisionRefSource`, and the update ref
    retains exact deployment/generation plus the `Execution` resource arm—never `Optional`, implicit
    `latest`, or a prior `Provisioned*` value; `PodRuntimeMetadataSource` with exact network/mount
    identities; the closed accelerator owner family/profile/device-count, exact source/workload maps,
    residency-placement and finite coexistence-policy shapes; the closed `CpuOvercommitPolicy =
    ⟨NoCpuOvercommit|BoundedCpuOvercommit RatioAtLeastOne⟩`; typed durable-volume and cache
    demands/backings; mandatory BookKeeper quorum/fault geometry and `BookKeeperLogicalDemand` whose four
    byte fields are required and positive;
  - MinIO erasure/fault geometry, content-store concurrent/failed-write bounds plus finite positive
    orphan-GC horizon, and StatefulSet claim-slot records from which the private uniform plan is later
    derived; content-digested `ImageArtifact` values carrying OCI index bytes and, per platform,
    child-manifest/config stored bytes, compressed layer bytes, snapshot chain/unpacked bytes, and
    pull/import workspace; `NodeLocalStorageCapacity` carrying logical `podEphemeralAllocatable`, a closed
    `Unified | SplitRuntime | SplitImage` physical-filesystem layout, `NodeImageStorageModelVersion`, finite
    pull concurrency, and `KubeletRuntimeMetadataModelVersion`; `PhysicalHostCapacity` with a non-empty
    physical-partition graph, globally scoped `PhysicalDiskBackingId` / `DiskCarveId` fields, parent-indexed
    `NamedDiskCarve` and nested layout-shaped `VmDiskCarve` relationships whose nodefs/imagefs aliases are
    forced by the chosen arm; a distinct reusable `ProviderNodeCapacityTemplate` whose per-instance
    disk/carve and accelerator-slot names cannot be mistaken for already-materialized global ids; canonical
    exact cache-population, registry publication/rehome intents, six-arm object-producer and gateway
    intents, ZooKeeper metadata, Patroni SQL source intent, volume/schema-transition intents, and Vault
    persisted-object/Raft/audit demands; `VolumePresentation` and backing allocation minimum/quantum; and
    the complete `ResourceEnvelope`; the non-optional `BuildExecutionEnvelope`; and the kind/rke2-node →
    role-indexed `EngineSystemReserve` → `ControlPlane | Worker` storage nesting, including every named
    static process envelope, system-carve reference, and applicable finite history requirement.
  - dhall-typecheck proves those fields and closed arms are present.
  - Phase 26 refines/normalizes the quantities and preserves the identity graph in opaque, unit-tagged
    values;
  - [Phase 28](phase_28_storage_geometry_folds.md) checks global backing/carve uniqueness and exactly-once reference resolution as storage
    geometry, while [Phase 9](phase_09_resource_index.md) checks `requests ≤ limits` and the core capacity arithmetic.
  - Kubernetes resource maps, uniform claim-template PVC sizes, cache volumes, and accelerator extended
    resources are later rendered projections of these pure values, never authorable parallel fields.
- An in-file **honesty caveat**: because Dhall has no opaque types, binding- and phantom-index foreclosures
  (catalog [§4.1](../documents/illegal_state/illegal_state_techniques.md#41-pvcpv-binding-by-construction)–[§4.3](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)) are only *partially* dhall-typecheck-foreclosed by smart-constructor convention and get real
  teeth at the Haskell GADT decoder in [Phase 26](phase_26_gadt_decode_ir.md) (gadt-decode).

#### Wired surfaces (forecloses detached-ornament stubs)

The three surface records carry the foreclosing types as REQUIRED fields, not as standalone unreferenced
modules:
- `App` demands `caps : List Capability` and storage via `StorageBacking` + `RetentionPolicy`
- every execution-unit record reachable from `App` or `Deployment` is an `ExecutionUnitIntent` requiring
  id/revision, one kind-specific controller/cardinality/ policy arm, and a complete `ResourceEnvelope`, with
  every pod arm carrying a non-empty container list whose every app/sidecar/init/restartable-init member has
  `Resources`, private memory/ephemeral allowances with a closed root-filesystem arm, and a platform-indexed
  digested `ImageArtifact`, a required structural `PodRuntimeMetadataSource`, plus a required
  `PodLocalStorageDemand` whose memory volumes name access modes and stage-local/pod-lifetime persistence
  (from which provisioning derives one reservation carrier per lifecycle epoch), and every in-cluster cache
  referencing one of its disk-backed volume ids, while the host-worker arm carries host CPU/memory
  reservation+ceiling, named local/cache backing, and only host-valid accelerator demand
- every build definition reachable from the deployment/cluster surfaces carries a non-optional
  `BuildExecutionEnvelope` with a non-empty `BuildStageDemand` graph (stage id, target platform, dependency
  ids, `runtime : HostResources`, intermediate-byte peak, and cache-write delta), a named `BuildScratch`
  `HostStorageBackingId`, `cache : HostCacheDemand` (named backing plus `CacheBudget`), and separate `Serial
  | BoundedParallel PositiveNatural` architecture and stage concurrency policies
- no caller-authored terminating-count promise exists
- a raw rolling policy retains both finite operands even when both are zero, and the validation-locus ledger
  assigns that cross-field case to gadt-decode rather than falsely claiming Dhall arithmetic forecloses it
- and `Cluster` demands `Rke2Servers` plus an explicit fixed/autoscaled `Rke2AgentPool` for an rke2 engine,
  `Ingress` for every route, and a node/host inventory whose `Capacity` explicitly declares CPU, memory, and
  `NodeLocalStorageCapacity`: logical pod-ephemeral allocatable remains separate from the physical `Unified
  | SplitRuntime | SplitImage` nodefs/imagefs layout, while the image storage-model version, finite
  pull-concurrency policy, and kubelet/runtime-metadata model are required
- `SplitImage` additionally requires its typed runtime-support field.

Durable/native-host-cache/role-tagged-host-storage backing pools remain disjoint. Its kind engine arm
requires `KindEngineDemand` with non-empty ordinal-indexed node-container runtime, full `NodeCapacity`, and
in-node `KindControlPlane | KindWorker` reserve plus a distinct host-only Docker/containerd/kind-supervisor
reserve. Every rke2 server and fixed/floor agent carries a `Rke2Server` or `Rke2Agent` reserve respectively.
Each reserve has `processes : NonEmpty EngineProcessEnvelope` with the role's required `EngineProcessId`
entries, each with `runtime : HostResources`, plus non-optional `storage.carve : DiskCarveId`.
Kind/rke2-server storage uses `ControlPlaneStorageDemand`, including `staticEngineBytes` and
`historyRequirement : FiniteDuration`; rke2-agent storage uses `WorkerEngineStorageDemand`, including
bounded kubelet/runtime logs. Every autoscaled rke2 candidate carries the template-local equivalent (exact
agent processes, worker-storage demand, per-instance raw host `cpu`/`memory`/disk supply, and system-carve
reference), while a managed- provider candidate carries the distinct no-invented-reserve arm plus a
mandatory `ProviderSkuRef { provider, region, machineType, catalogVersion }`. Every physical host carries a
non-empty partition inventory: each partition has a globally scoped `PhysicalDiskBackingId`,
`allocatableRawBytes` after unmanaged-host reserve but before all amoebius child carves (including its named
system carve), and raw VM-disk carves with presentation/allocation policy, named guest-system, and
layout-shaped kubelet filesystem carves but no editable aggregate byte field; the private provisioner
derives their usable/provisioned high-water. `NamedDiskCarve PhysicalRawExtent` and `NamedDiskCarve
VmGuestUsableExtent` are distinct parent-indexed values; an exact-parent arm supplies bytes already in that
parent's unit, while a presented-usable arm supplies usable intent plus presentation/allocation geometry for
deriving its private parent debit. Direct-node filesystem carves sit beside retained, host-cache, and
purpose-tagged host-storage pools. Only `Unified` aliases nodefs/imagefs; `SplitRuntime` and `SplitImage`
require distinct nodefs/imagefs references, and containerfs is derived from the arm rather than authored as
a third capacity. Those pools carry the typed logical ids consumed by durable/cache/ host-worker/build
demands and their physical `NamedDiskCarve`; build scratch has its own required purpose tag. The globally
scoped ids and all parent/reference edges are required schema fields; their value-level uniqueness,
one-parent ownership, and arithmetic are the [Phase 28](phase_28_storage_geometry_folds.md) storage-geometry fold over the [Phase 9](phase_09_resource_index.md) capacity core, rather
than a dishonest Dhall type claim. The
inventory also carries a closed accelerator offering: CUDA family/wholesale whole-device count, Apple Metal
profile with unified memory charged to host memory, or `None`; every non-None owner demand carries exact
equal-keyed source/workload maps plus structural residency and finite class-based coexistence policy. The
source classes exactly equal both coexistence-map domains; no missing class defaults to zero/serial and no
extra class is accepted. Residency bytes mean total bytes for `Unsharded`/`Sharded` and per-device bytes for
`ReplicatedPerDevice`; sharded bytes sum exactly to the residency bytes, shard ids are unique, and shard
count cannot exceed owner devices. Each CUDA device supply requires stable identity/profile, raw VRAM, a
mandatory driver/runtime reserve, and net allocatable VRAM, and every node capacity also carries the closed
finite CPU-overcommit policy. In-cluster cache is a typed nested consumer of pod ephemeral, never a second
backing pool. Its `CachePopulationDemand` carries exact selected assets, content digests, resident bytes,
temporary bytes, and finite first-miss concurrency. Registry storage similarly carries exact OCI object
kinds/digests/stored bytes plus bounded upload failure/GC operands; Vault carries bounded persisted-object
versions/live leases, its Raft model/claim set, and a rotated audit demand with a named backing. The
`Managed Eks` arm is exactly `{ account : CloudAccountId, nodeClasses : NonEmpty ProviderNodeClass, quota :
ProviderQuota }`. Its `ProviderNodeCapacityTemplate` is exactly `{ allocatableCpu, allocatableMemory,
podSlots, cniSlots, attachableVolumes, localDisks, cpuOvercommit, localStorage, accelerator }`, where
`podSlots` is a `ProviderPodSlotPolicy`, `cniSlots` is a driver-keyed map of `ProviderCniSlotPolicy`,
`attachableVolumes` is a driver-keyed map of `ProviderAttachSlotPolicy`, and `localStorage` is exactly `{
podEphemeralAllocatable, filesystems, imageStorageModel, imagePullConcurrency, kubeletMetadataModel }`. The
non-empty per-instance `localDisks` retain class-local carve references and the closed `accelerator` retains
per-instance accelerator slots/links. Each disk template has exactly one node-root backing: `InstanceStore {
skuDevice, provisionedRawBytes, presentation : FilesystemPresentation }` or `EphemeralRootEbs { policy :
ProviderNodeRootVolumePolicy { volumeType, presentation : FilesystemPresentation, allocation :
BackingAllocationPolicy } }`. It also has `systemReserve : ProviderUsableDiskCarveTemplate` and `carves :
NonEmpty ProviderUsableDiskCarveTemplate`, whose exact shape is `{ id, requiredUsableBytes }`; these bytes
are usable filesystem demand, never raw supply. No raw spec field supplies a root-EBS byte request because
provisioning derives and rounds that private request from system reserve plus the unique carve set. Later
checked construction privately produces one `ProvisionedPerInstanceDiskTemplate`, derives
`mountedUsableBytes` through the instance-store or root-EBS presentation, and only then proves system
reserve plus unique carves fit; dhall-typecheck contains neither that private conversion result nor a
raw-versus-usable comparison. Each class carries the exact fields `name`, catalog-pinned `sku`,
`allocatable`, `quotaVcpu`, `zones`, `price`, `baseCount`, and `maxCount`. The outer account-bound quota is
exactly `ProviderQuota { maxInstances, maxVcpu, acceleratorCaps, nodeRootStorage, durable }`, where
`nodeRootStorage = NoNodeRootEbs | BoundedNodeRootEbs { bytes, volumeCount }`, `durable = NoDurable |
Bounded { bytes, volumeCount }`, and `acceleratorCaps` is a canonical profile-keyed map (no duplicate rows);
“hostless control plane” is not a capability-less worker pool, and `NoDurable` means zero durable supply
rather than omitted/unbounded capacity. `NoNodeRootEbs` permits only instance-store roots; it is not
durable-volume quota and cannot be debited as one. A class never embeds one concrete global `DiskCarveId` or
`AcceleratorDeviceId` for all future instances: a globally scoped `ProviderInstanceId { account, cluster,
class, ordinal }`, whose `account` is copied unchanged from `Managed Eks.account`, plus the complete
disk/carve/accelerator-slot template path derives distinct promised slots, and provider backing/device ids
attach only when each node materializes. That same `CloudAccountId` exact-joins the
`SharedSupplyLedger.accounts` entry; credentials or provider output cannot invent it. Required fields expose
the later constructor checks: class-local template-id uniqueness, filesystem references and layout aliases,
role bytes within their carve, conversion of instance-store raw supply or the derived ephemeral-root-EBS
request to mounted usable capacity before fitting system reserve plus unique usable carves, and reserved
plus allocatable VRAM within raw VRAM. Their value arithmetic is the [Phase 28](phase_28_storage_geometry_folds.md) storage-geometry fold for the
template, filesystem and carve terms, and the [Phase 29](phase_29_execution_accelerator_folds.md) accelerator and provider-root folds for the raw-to-mounted
conversion and the VRAM bound, not a Dhall type claim. Every
`Observability` deployment binding also requires a non-optional finite `MonitoringWorkBudget { maxWorkflows,
maxRules, maxSeries, maxScrapeSamplesPerSecond, evaluationInterval, evaluationCpu, evaluationMemory,
retention, query : QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange,
timeout, costModel }, volume : { claim : StatefulSetClaimSlot, backing : BackingId, presentation :
VolumePresentation }, tsdbCostModel }`, with positive counts/rate, finite intervals/retention/query bounds,
typed CPU/memory, and an exact StatefulSet claim/backing/presentation; no default, omitted field, scalar
query-temp, or descriptor-independent fixed Prometheus provision is an alternate arm. Non-applicable
resource arms use their closed `None`/empty form; omission of the envelope or capacity declaration itself is
impossible. A separately authored Haskell schema-shape oracle pins these required field-name→type bindings;
Sprint 25.1 must compare the generated record types against it semantically. A separate Haskell resource-field
oracle recursively pins every nested resource field
and closed arm, so an envelope containing only CPU/memory, a bucket name without its structural
retention/write demand, a free-standing pair of pod/image byte pools, an image reference without complete
stored-object/snapshot/workspace metadata, a backing without presentation/minimum/quantum, or scalar-only
cache/registry/Vault storage cannot pass.

### Validation

1. `dhall type` and `dhall lint` accept each generated schema module on its own, every surface type is
   well-formed, and each generated union's arm inventory matches a separately authored Haskell arm oracle, so
   no freeform escape arm survives. Every smart constructor elaborates to a value of its
   declared type, and a smart constructor cannot be applied to an out-of-schema argument
   without a type error — discharged by named Haskell cases that generate
   `.build/test-corpora/ctor-reject/*.dhall` (at least one expect-fail application per smart constructor,
   discovered in both directions), each of
   which MUST fail `dhall type`; this is not discharged by appeal to Dhall function typing alone.
2. The generated record types match the independent Haskell surface/resource-field oracles semantically (the
   wiring above), red on any missing required foreclosing field or any dropped/collapsed
   CPU, memory, logical pod-ephemeral/root-filesystem arm, node filesystem layout/model/object/snapshot
   metadata, physical-backing/carve/logical-pool identity, provider account identity, provider
   `podSlots`/CNI-IP `cniSlots`/driver-indexed `attachableVolumes`, all five `ProviderQuota` fields and both storage quota unions,
   provider node-root backing policy, `InstanceStore.provisionedRawBytes`, and
   `ProviderUsableDiskCarveTemplate.requiredUsableBytes`,
   `DeclaredVolumeDemand`/presentation/backing-allocation policy, durable/cache/registry/Vault storage,
   `PhysicalDiskPartition.allocatableRawBytes`, the `NamedDiskCarve` parent index and closed extent arms,
   execution identity/revision/controller-kind-specific
   cardinality/policy operands and the required first-deploy/update-from transition source with exact prior deployment,
   generation, and `Execution` arm,
   `PodRuntimeMetadataSource` or `kubeletMetadataModel`, accelerator source/workload/coexistence domains and
   residency placement, accelerator-count, raw/reserved/net/shard/link VRAM,
   provider-node-class/per-instance-template, per-stage `BuildExecutionEnvelope`, role-indexed named engine-
   process/engine-storage demand, or any `MonitoringWorkBudget` provision including
   `volume.presentation`. The oracle is also red if any dhall-typecheck field is a `Provisioned*` record, if a
   binder-output migration/SQL/object-gateway demand replaces its source intent, or if Event operands appear
   anywhere except `ControlPlaneStorageDemand.etcd.logical.churn`.

### Remaining Work

The pre-reset record said `None`; that statement and its schema/mutant results cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 25.2: dhall-typecheck positive corpus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 25.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`illegal_state_catalog.md §1 — Illegal states fail to type-check`](../documents/illegal_state/illegal_state_catalog.md#1-illegal-states-fail-to-type-check): assemble the
Haskell-declared positive cases that generate legal Dhall values beneath `.build/**` and prove those projections
pass the dhall-typecheck typechecker —
the authoring-time demonstration that the schema *admits* every intended world.

### Deliverables

- Positive Haskell case declarations — the explicit representative set `legal_multisubstrate_cluster`,
  `legal_managed_eks`, `trivial_app`, and `legal_deployment_rules` — each lazily renders a well-typed Dhall
  value beneath `.build/test-corpora/**` built entirely through the
  Sprint-17.1 smart constructors, and each populating every REQUIRED foreclosing field of its surface record
  (a `Cluster` carrying `Rke2Servers` + `Ingress`; an `App` carrying `List Capability` + `StorageBacking` +
  `RetentionPolicy`; every execution unit carrying `ResourceEnvelope`; every target inventory carrying the
  complete `Capacity` shape; every build carrying `BuildExecutionEnvelope`; the kind engine carrying its
  node-container demand and role-indexed named-process/system-carve-backed control-plane reserve; and each
  rke2 server/agent carrying its applicable role reserve). `legal_deployment_rules` specifically contains an `Observability` binding
  with nontrivial, pairwise-distinguishable values for all required `MonitoringWorkBudget` fields, including
  `volume.claim`, `volume.backing`, and `volume.presentation`, so its presence
  and later decode preservation cannot pass vacuously. A positive that routes through none of the foreclosing
  types does not satisfy this set. Across `legal_multisubstrate_cluster` and `legal_managed_eks`, the positives
  exercise distinguishable `Unified` and `SplitRuntime` layouts, complete OCI object/snapshot/model metadata,
  raw VM presentation/allocation without aggregate bytes, both instance-store and ephemeral-root-EBS backing
  policies, distinguishable SKU raw `provisionedRawBytes` and system/layout-carve
  `requiredUsableBytes` operands, the authored `CloudAccountId`, nontrivial `podSlots` and two distinguishable driver-indexed
  `attachableVolumes` policies, every exact `ProviderNodeClass` field, all five `ProviderQuota` fields, the
  separate root-EBS/durable quota arms, volume presentation/allocation rounding inputs, and exact cache,
  registry, and Vault demand structures. `SplitImage` remains a well-shaped union arm but has no v1
  containerd positive because its runtime witness cannot be constructed.
- Each of the eight dhall-typecheck negatives of Sprint 25.3 names one of these positives as its paired sibling (the
  fixture it is a one-construct mutation of); this set is the source of those paired positives.
- A corpus harness that runs `dhall type` over the positive set and reports one aggregate result.

### Validation

1. Every positive fixture type-checks; the harness is red if any positive fixture fails `dhall type`.
2. Each Haskell-declared positive instantiates every required foreclosing field named by the independent
   Haskell surface-field and resource-field oracles. The harness compares the run-local Dhall projections with
   those checked `.hs` expectations, so the positives exercise the Sprint-17.1 foreclosures rather than a toy
   `{ name : Text }` skeleton or a CPU/memory-only envelope.

### Remaining Work

The pre-reset record said `None`; that statement and its positive-corpus result cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 25.3: dhall-typecheck-class negative corpus + partial-foreclosure ledger ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 25.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`illegal_state_catalog.md §2 — the load-bearing limit`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it),
[`§3 — the catalog`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent),
and [`§4 — planning ownership`](../documents/illegal_state/illegal_state_catalog.md#4-planning-ownership): assemble the
dhall-typecheck-class negative corpus — the fixtures the schema makes unspellable — and prove each fails `dhall type`,
honestly recording which foreclosures are complete at dhall-typecheck and which are only conventional here and finished
at gadt-decode.

### Deliverables

- The eight canonical dhall-typecheck negatives named in the **Gate** representative set are checked Haskell
  case declarations. Each lazily generates one `illegal_*.dhall` beneath `.build/test-corpora/**` and MUST fail
  `dhall type`: product-named capability ([§3.12](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability)), insecure/backdoor ingress
  arm ([§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)), a missing complete resource envelope on an execution unit ([§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)), unbounded storage backing
  ([§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere)), un-tiered / no-retention topic ([§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)), capacity-growth-without-scaling-policy ([§3.21](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)),
  even/zero-server rke2 control plane ([§3.24](../documents/illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)), and an un-offered substrate/topology arm ([§3.14](../documents/illegal_state/illegal_state_topology.md#314-rke2kind-on-a-host-with-no-linux-node-applewindows-without-an-interposed-linux-vm)/[§3.15](../documents/illegal_state/illegal_state_topology.md#315-a-multi-node-kind-cluster-not-on-a-single-linux-host)). The
  [§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext) fixture is `illegal_missing_resource_envelope.dhall`: it deletes only the required envelope field
  from a legal workload, and its pinned error names that missing field. Each is a MINIMAL one-construct mutation of its named `legal_*.dhall`
  paired positive, and each embeds its illegal construct inside a full positive-derived cluster/app spec —
  NOT a detached import of an ornamental type — so the illegal state is exercised in a wired surface.
- The malformed-received-body subcase of the non-CBOR payload entry ([§3.23](../documents/illegal_state/illegal_state_capability_messaging.md#323-a-non-cbor-pulsar-payload)) is explicitly NOT authored as a
  dhall-typecheck fixture: it is layer-2 decode-foreclosed and appears in the ledger as a deferred row owned by
  [Phase 26](phase_26_gadt_decode_ir.md)'s gadt-decode. The separate produce-side no-constructor subcase is
  outside this representative set and lands in Phase 27's exhaustive registry-driven corpus.
- A separately authored Haskell predicate per negative pins the targeted union/arm/field and structured reason;
  raw `dhall type` transcripts are run-local observations beneath `.build/**`, never tracked goldens.
- An applied Haskell union-arm-addition mutant lazily renders its altered Dhall projection beneath
  `.build/test-corpora/**`; the harness re-runs it and MUST report red.
- The **partial-foreclosure ledger** is the [§K](development_plan_standards.md#k-honesty-proven--tested--assumed) proven/tested/assumed artifact this phase emits under `.build/runs/`,
  with schema and external retention per `testing_doctrine.md`. It names Register 1,
  carries the acceptance token *spec-composition proven*, maps each of the eight negatives to its catalog
  entry and foreclosure layer (fully no-arm/required-field vs. conventional binding/index residue), marks
  layer-2/3 residue UNVERIFIED, and routes that residue to [Phase 26](phase_26_gadt_decode_ir.md). This
  ledger is the single [§K](development_plan_standards.md#k-honesty-proven--tested--assumed) artifact the Definition of Done requires; there is no separate coverage note.

### Validation

1. Every one of the eight Haskell-declared dhall-typecheck-class negatives fails `dhall type` in the generated
   run-local corpus; the Haskell phase gate is red if any tagged negative type-checks.
2. Per negative, the harness asserts the paired positive (the fixture with only the tagged illegal construct
   reverted) type-checks (§M.8/§M.3), AND the observed structured `dhall type` failure satisfies the separately
   authored Haskell predicate naming the targeted type/arm/field (§M.8); red if either the paired positive
   fails or the expected rejection locus differs.
3. The harness re-runs the applied Haskell union-arm-addition mutant and is red
   unless the mutant is caught — i.e. the arm-inventory oracle goes red on the extra `Custom : Text` arm. If
   instead the mutant passes the arm-inventory oracle or lets the product-named negative type-check, the
   mutant has escaped and the seeded-mutant gate is invalid (§M.2).
4. The run-local partial-foreclosure ledger maps all eight negatives to a catalog entry and foreclosure layer
   — fully no-arm/required-field, versus the residue owned by Phase 26's gadt-decode — records the
   malformed-received-body
   [§3.23](../documents/illegal_state/illegal_state_capability_messaging.md#323-a-non-cbor-pulsar-payload)
   subcase as deferred rather than counted green, passes its schema, and is externally observed; the gate is
   incomplete without it.

### Remaining Work

The pre-reset record said `None`; that statement and its negative/mutant/ledger results cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 25.4: The shared `SecretRef` union and the plaintext-secret negative ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 25.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`vault_pki_doctrine.md §3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)
at the boundary that owns it: give a sensitive field a type whose only inhabitants are references, so a
production config cannot express a secret value.

### Deliverables

- A checked Haskell declaration that lazily projects `.build/dhall/amoebius/SecretRef.dhall`: the closed
  union with `Vault`, `TransitKey`, and `Prompt` arms, no inline-value arm, smart constructors, and the
  `Sensitive` record that types a sensitive field.
- A row in the arm-inventory oracle pinning those three arms, and one in the surface-field oracle pinning
  `Sensitive`.
- A Haskell-declared positive and one-place negative with a separately authored Haskell error-class/locus
  expectation. Any rendered case, raw diagnostic, or metric projection exists only beneath `.build/**`.
- The `schema-modules` oracle amended from intent to 18 with its checked inventory extended.

### Validation

1. The schema module is `dhall type` and `dhall lint` clean and joins the module inventory.
2. The positive fixture type-checks with all three arms exercised.
3. The negative fails `dhall type`, names the sensitive field, and satisfies the independent Haskell
   error-class/locus predicate; raw compiler wording is run-local diagnostic output, not a golden source.
4. The `secret-reference-policy` surface joins to the recorded metric.

### Remaining Work

The pre-reset `None` claim is permanently invalid. Current remaining work includes every
`UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and the Haskell case/oracle/
mutation obligations above. Decoder rejection remains [Phase 26](phase_26_gadt_decode_ir.md)'s target; live
presence remains [Phase 61](phase_61_vault_pki.md)'s target.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/dsl_doctrine.md` — backlink §5's dhall-typecheck to this in-process Phase-25 proof; keep gadt-decode
  (the typed decoder) as the companion boundary owned by Phase 26, and runtime enforcement as the deferred
  live-band residue.
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry exercised here with its realized
  dhall-typecheck foreclosure layer (type-foreclosed → layer 1); keep decode-foreclosed (layer 2) and runtime-checked
  (layer 3) entries deferred.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the pass criterion may change Phase 25 after checking a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-25 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the Phase-25 Haskell declaration/generator/oracle modules;
  `.build/dhall/amoebius/**` and `.build/dhall/examples/**` are lazy products, never components or source rows.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) the two languages, [§5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) the typed spec gates and
  the illegal-state contract
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the catalog, the typing
  techniques, and the honest foreclosure-layer split
- [phase_26](phase_26_gadt_decode_ir.md) — gadt-decode, the GADT-indexed IR and total decoder, the companion boundary
