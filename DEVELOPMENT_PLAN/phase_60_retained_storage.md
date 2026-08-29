# Phase 60: No-provisioner retained storage + lossless rebind

> **Purpose**: Install the single inert `no-provisioner`/`Retain` StorageClass and the deterministic
> `<namespace>/<statefulset>/pv_<integer>` retained-PV bind on the live linux-cpu kind cluster, enforce
> `Σ(ProvisionedVolumeDemand.provisionedBytes) <= DurableBacking` after presentation/allocation and uniform
> StatefulSet claim-template grouping, enforce a real per-volume host-side hard ceiling, then prove the
> lossless-teardown guarantee — durable bytes rebind across a cluster delete + recreate with a Postgres row
> and a MinIO object marker round-tripping unchanged.
> **Read this if**: phase 60 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/storage_lifecycle_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 60.1: The one inert `no-provisioner` StorageClass ⏸️](#sprint-601-the-one-inert-no-provisioner-storageclass-)
- [Sprint 60.2: Deterministic retained-PV generation + the explicit bind ⏸️](#sprint-602-deterministic-retained-pv-generation--the-explicit-bind-)
- [Sprint 60.3: The lossless-rebind gate — Postgres row + MinIO marker round-trip ⏸️](#sprint-603-the-lossless-rebind-gate--postgres-row--minio-marker-round-trip-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 59, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target must make durable storage a *different kind of thing* from the cluster that mounts it. It
must install the
one inert StorageClass amoebius allows — `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
`volumeBindingMode: WaitForFirstConsumer` — and remove every other StorageClass and competing default
annotation, so a claim can never fall through to a dynamic provisioner. It must render retained PVs whose names
and `claimRef`s are pure functions of `(namespace, statefulset, ordinal)`, each pinned to the exact
`(namespace, PVC-name)` it serves and (for host-backed volumes) node-affine to the node holding its bytes,
each carrying an explicit capacity against an explicitly-sized claim. The authorable input is instead a
`DeclaredVolumeDemand`: logical bytes, claim-slot/backing identity, attachment mode, geometry, and
`VolumePresentation = Block | Filesystem { fsType, overheadModel }`. Pure provisioning derives each slot's
`requiredUsableBytes`, adds the versioned filesystem overhead where applicable, applies the backing's non-zero
`minimumBytes`/`quantumBytes`, and alone constructs private
`ProvisionedVolumeDemand.provisionedBytes`; neither raw allocation bytes nor a rounded PV size is authorable.
Before any backing is allocated or PV is applied, the complete post-reconcile retained-volume inventory —
existing images plus proposed new volumes, deduplicated by stable PV identity — is folded against the
observed, separately-owned `DurableBacking`; `Σ(provisionedBytes) > DurableBacking` is a checked rejection and
cannot borrow bytes from the node's ephemeral-storage or native-host-cache pools. A
`volumeClaimTemplate` has one capacity for all of its ordinals, so every ordinal is presented and
allocation-rounded first, then grouped by `(StatefulSet, template)`; the group maximum rounded
`provisionedBytes × ordinalCount` is debited and unused padding stays reserved. On the kind host, every
accepted filesystem PV is backed by its own fixed-raw-size filesystem image under the retained root and
mounted at the PV path: its raw length is the private `provisionedBytes`, its observed fs type matches the
presentation, and its mounted usable capacity supplies `requiredUsableBytes` without being mistaken for the
raw allocation. It closes with the
load-bearing proof:
write a marker row into a Postgres witness and a marker object into a MinIO witness, `cluster delete` (the
apiserver/etcd and PVC/PV API objects disappear while the external retained backing bytes remain), `cluster
recreate` (fresh PV objects whose pre-bound `claimRef` omits `uid`/`resourceVersion` point at that backing),
and read the same bytes back — the deterministic rebind.

This phase is also the live owner of the retained-backing arms of the storage-scaling state machine. Phase
8 supplies the policy-only `ProvisionedStorageScalingEnvelope` and pure observe-then-plan fold, and Phase 58
supplies snapshot validation plus the single-use action/token dispatcher. Here,
`AllocateWithinRetainedCarve` allocates only within a freshly observed residual carve, while
`ShrinkByVerifiedMigration` follows the same old+new+workspace/copy/verify/cutover discipline as retained-PV
resize. `CreateProviderCapacity` has no retained-host mutation capability and remains owned by Phase 75.

The scope deliberately stops at *standing the retained-storage substrate up and proving it rebinds*. The
witness workloads are minimal single-ordinal StatefulSets that exercise the bind; distributed MinIO lands in
Phase 62 and HA Patroni-via-Percona Postgres in Phase 63, the Vault-enveloping of secrets is Phase 61, and the
Keycloak-owned edge is Phase 64 — none of which this phase requires. The control plane
itself is out of the retained-storage picture by construction: it is a stateless Deployment `replicas=1` that
holds **no PVC**, its durable state exclusively the Vault-enveloped MinIO bucket, so MinIO here is a retained
volume holder while the control plane is only a client of that bucket.

**Phase scope:** one cohesive claim — *a retained volume rebinds losslessly to the claim that owned it*. Determinism in the bind name is what makes the rebind checkable rather than hopeful.

**Substrate:** `linux-cpu` — this universal lane is always available on every hardware substrate. When a
pristine Linux host is required, use Incus on native Linux or Linux-CUDA, Lima on Apple, and WSL2 on Windows.
The live gate uses the Phase-55 single-node `kind` cluster; pure StorageClass/PV rendering remains Register 1–2.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 59](phase_59_capacity_scheduler.md)
**Gate:** `pb validate phase 60`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *a retained volume rebinds losslessly to the claim that owned it*. Determinism in the bind name is what makes the rebind checkable rather than hopeful. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 60` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 59; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_transactions.md` §4 — P1–P6](../documents/engineering/extension_conformance_transactions.md#4-p1p6) — no-provisioner retained storage + lossless rebind reaches a relational store, and P1-P6 close that surface to the transactions the domain has.
- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes no-provisioner retained storage + lossless rebind causes to exist are charged to a grant that carries its ceiling and concurrency together.
This phase's target is to become the first live amoebius realization of the storage-lifecycle contract. Each
bullet names the section the target must implement; individual sprints cite the same sections where they must
adopt them.

- [`storage_lifecycle_doctrine.md` §2 — One storage class, and it provisions nothing](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  — *one storage class, and it provisions nothing*: the single inert `no-provisioner` / `Retain` /
  `WaitForFirstConsumer` StorageClass, with every other class removed and every competing default annotation
  stripped, so there is no second way to get a volume.
- [`storage_lifecycle_doctrine.md` §4 — Deterministic PV naming and the explicit bind](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind)
  — *deterministic PV naming and the explicit bind*: PV names on the `<namespace>/<statefulset>/pv_<integer>`
  scheme, an explicit `claimRef` to the exact `(namespace, PVC-name)`, and node affinity to the host-path
  node for host-backed volumes.
- [`storage_lifecycle_doctrine.md` §5 — Sizes are explicit, hard-capped, and one-volume-per-claim](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim)
  — *sizes are explicit, hard-capped, one-volume-per-claim*: every demand declares logical intent,
  presentation, and backing; geometry derives required usable bytes and the private provision witness derives
  the rounded raw PVC/PV capacity. This phase's target must deliver the linux-cpu host mechanism as one fixed-raw-size
  filesystem image per PV, never a raw
  shared-filesystem directory, and drills its presentation and actual `ENOSPC` ceiling. The 1:1 invariant is
  identity/cardinality — one claim slot, one PVC, one PV, one enforced backing extent — not equality between
  logical bytes, usable bytes, filesystem raw bytes, and allocation-rounded bytes.
- [`resource_capacity_doctrine.md` §5 — `StorageBudget`: bounded by construction, single-owner ceiling per arm](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)
  — *bounded storage with a single ceiling owner*: the entire post-reconcile retained inventory must be checked as
  `Σ(provisionedBytes) <= DurableBacking` before allocation, counting existing/proposed identities once, with
  durable, cache, and pod-ephemeral pools disjoint so the same physical bytes cannot satisfy multiple budgets.
  Its [`resource_capacity_storage.md` §5.1 — Durable demand is logical first, physical only after geometry](../documents/engineering/resource_capacity_storage.md#51-durable-demand-is-logical-first-physical-only-after-geometry)
  presentation/allocation and uniform-claim projection is enacted here: unequal usable ordinal requirements
  are presented and backing-rounded individually, then grouped per `volumeClaimTemplate`; the maximum private
  `provisionedBytes` times ordinal count is the retained debit.
- [`storage_lifecycle_doctrine.md` §3 — PVCs are born only from StatefulSets](../documents/engineering/storage_lifecycle_doctrine.md#3-pvcs-are-born-only-from-statefulsets)
  — *PVCs are born only from StatefulSets*: the witness claims exist only as StatefulSet `volumeClaimTemplate`
  claims; there are no bare PVCs or Deployment-owned claims. Only a private provisioned migration Job may
  temporarily mount its exact old/replacement claims; it creates/owns no claim and has no generic PVC field.
- [`storage_lifecycle_doctrine.md` §6 — The lossless-teardown guarantee: deterministic rebind](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — *the lossless-teardown guarantee: deterministic rebind*: the phase's gate — a destroyed-then-recreated
  cluster recomputes the same claims which re-bind to the same retained backing, with nothing restored from a
  backup because the backing bytes were never deleted.
- [`storage_lifecycle_doctrine.md` §7 — Deleting durable data is forbidden under normal operation](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation)
  and [`storage_lifecycle_doctrine.md` §7.2 — amoebius' own control-plane state is the MinIO bucket, not a PVC](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc)
  — *deleting durable data is forbidden under normal operation* / *the control plane holds no PVC*: the
  cluster delete in the gate discards the cluster-local API objects and never reclaims backing volumes; the
  sole automated actor that may destroy the test-flagged witness bytes is the elevated harness; MinIO sits on
  a retained PV while the stateless control-plane daemon keeps its durable state in the Vault-enveloped
  MinIO bucket, holding no volume of its own.
- [`cluster_lifecycle_doctrine.md` §7 — Ephemeral spin-up/down with deterministic rebind](../documents/engineering/cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind)
  (cross-reference, not adopted here) — the ephemeral spin-up/down whose teardown removes ephemeral
  infrastructure and never durable backing, which the rebind gate exercises; and
  [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  (targeted by Phase 58) — the SSA reconciler that must render and apply the StorageClass and PV objects; its
  future predecessor gate pass, not this sentence, is the only admissible dependency evidence.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.

## Sprint 60.1: The one inert `no-provisioner` StorageClass ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 59](phase_59_capacity_scheduler.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing):
render the single inert StorageClass and delete the dynamic-provisioning machinery outright, so volumes exist
only because amoebius placed them and nothing in the normal cluster lifecycle can mint or reclaim one.

### Deliverables

- A single rendered StorageClass — `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
  `volumeBindingMode: WaitForFirstConsumer` — applied through the Phase-58 reconciler under the `amoebius`
  field manager.
- Removal of every other StorageClass the base `kind` image ships and stripping of any competing default-class
  annotation, so a claim can never silently fall through to a dynamic provisioner.

### Validation

1. Assert post-bring-up that the live StorageClass observation is structurally equal to a separately authored
   Haskell expectation which is not derived from the renderer: exactly one class,
   `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
   `volumeBindingMode: WaitForFirstConsumer`, and no `storageclass.kubernetes.io/is-default-class` annotation on
   any object.
2. Specific-reason negatives, each paired with the positive differing only in the foreclosed dimension: (a) a
   PVC with no matching PV stays `Pending` **with the specific event reason `WaitForFirstConsumer`** (no
   provisioner attempted) — asserting the reason string, not merely the `Pending` phase; the paired positive is
   an identical PVC that binds once its PV exists. (b) The Haskell negative case `two_storageclasses` adds a
   second class and a default-class annotation and makes assertion 1 fail with the **specific reason
   `count != 1` / `default-class annotation present`**, distinguishing it from an unrelated structural mismatch.

### Remaining Work

Generate the sprint run record lazily under `.build/runs/phase_60/` and bind it to that run-local,
untracked evidence bundle; the complete passing gate is the pass criterion.

## Sprint 60.2: Deterministic retained-PV generation + the explicit bind ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 60.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`storage_lifecycle_doctrine.md §4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind),
[`§5 — sizes are explicit, hard-capped, one-volume-per-claim`](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim),
and [`§3 — PVCs are born only from StatefulSets`](../documents/engineering/storage_lifecycle_doctrine.md#3-pvcs-are-born-only-from-statefulsets),
together with [`resource_capacity_doctrine.md §5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)
and its [`§5.1`](../documents/engineering/resource_capacity_storage.md#51-durable-demand-is-logical-first-physical-only-after-geometry)
presentation/allocation and uniform-claim projection, and
[`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
for applying the rendered PVs through the reconciler:
compute both ends of the bind from stable identity so rebinding is never assigned by a race, and confine the
PVC creation path to exactly one shape.

### Deliverables

- Deterministic PV generation from `(namespace, statefulset, ordinal)`: the logical identity
  `<namespace>/<statefulset>/pv_<integer>` realized as the injective RFC-1123-subdomain `metadata.name`
  `<namespace>.<statefulset>.pv-<integer>`, repeated in the RFC-1123-valued `amoebius.io/pv-identity` label,
  with the verbatim logical identity carried in the `amoebius.io/pv-logical-identity` annotation, explicit
  `claimRef` to the exact `(namespace, PVC-name)`, and node affinity to the host-path node for
  host-backed volumes (the trivial single-node case on this substrate). The encoding exists because the
  logical identity is not itself a legal `metadata.name` — `/` and `_` are forbidden — and it is safe because
  the `.` separator is illegal inside either label-shaped component, so the encoding is injective and two
  distinct identities can never collide on one cluster-scoped name
  ([`storage_lifecycle_doctrine.md` §4](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind)).
- An authorable `DeclaredVolumeDemand` per claim slot with logical bytes, geometry, backing, and explicit
  `attachment = NodeLocal | Csi { driver }`, with
  `VolumePresentation = Block | Filesystem { fsType, overheadModel }` and each backing's explicit
  `BackingAllocationPolicy { minimumBytes, quantumBytes }`. A pure total join derives
  `requiredUsableBytes`, applies filesystem metadata/journal/reserved-block overhead, rounds raw bytes to the
  backing policy, and is the only constructor of private
  `ProvisionedVolumeDemand { claim, backing, attachment, requiredUsableBytes, provisionedBytes,
  presentation, allocation, witness }`;
  callers and the renderer cannot author or recompute `provisionedBytes`.
- Explicit per-PVC request and per-PV capacity, both rendered unchanged from the private rounded
  `provisionedBytes`, one enforced backing extent per claim. The host filesystem arm uses one fixed-raw-size
  filesystem image mounted at the PV path; raw retained-root subdirectories are forbidden. The invariant is
  `DeclaredVolumeDemand : PVC : PV : backing extent = 1:1:1:1` by identity/cardinality, not equality among
  logical, required-usable, pre-rounding raw, and provisioned byte quantities.
- A private `UniformClaimPlan` projection for multi-ordinal services: retain the complete map from each
  `(StatefulSet, volumeClaimTemplate, ordinal)` slot to exactly one derived
  `ProvisionedVolumeDemand` **after**
  presentation and allocation, require one compatible presentation/allocation policy per template, render
  the group's maximum `provisionedBytes` as the exact PVC/PV capacity on every ordinal, recheck that it supplies
  the group's maximum `requiredUsableBytes`, and derive a distinct
  `perBackingDebit[backing] = max(provisionedBytes) × membersOnBacking` plus a uniformity witness. An
  ordinal-varying rendered size, pre-allocation grouping shortcut, or aggregate that spends only a logical,
  usable, unequal rounded, or ownership-erased map rejects before render.
- A pre-allocation aggregate fold over the complete post-reconcile retained inventory:
  `∀ backing. Σ UniformClaimPlan.perBackingDebit[backing] <= observed[backing]`, where every named durable backing is disjoint from cache and node ephemeral storage and existing/proposed volumes are keyed by stable identity so an unchanged re-run is counted once. Spare bytes on one backing cannot cover another. A failed fold has no continuation that can create an image, mount, PV, or PVC. - Host-retained resize enactment consumes only a private `ProvisionedStorageMigration`: the binder starts from the still-live old private volume, replacement `DeclaredVolumeDemand`, and structural chunk/concurrency/ workspace policy; provisioning derives the new rounded volume, exact copy/verify Job `PodResourceEnvelope`, and per-backing old+new+workspace high-water. The Phase-58 snapshot-bound reconciler creates the replacement and renders/adopts that Job only when the complete transition still fits CPU, memory, ephemeral storage, pod/CSI slots, and backing bytes. Independent byte verification gates cutover and `ReclaimEligible`; failure keeps the old claim active and both volumes/partial workspace charged. Normal operation never deletes either backing. - The Phase-60 enactors for `AllocateWithinRetainedCarve` and `ShrinkByVerifiedMigration`. They accept only Phase 58's fresh, snapshot-bound `ValidatedStorageScalingAction`, immediately recheck the exact retained allocation map/backing/fingerprint, consume its plan-id-indexed token once, and return a post-attempt observed scaling snapshot. Allocation cannot exceed the witnessed residual carve; shrink delegates to the private migration above and never credits the old extent before verified cutover and observed cleanup. `CreateProviderCapacity` is absent from this host capability surface. - The invariant that a PVC is only ever born from a StatefulSet `volumeClaimTemplate` — no bare PVCs or Deployment-owned claims — exercised with a minimal one-ordinal witness StatefulSet. The only Job mount constructor consumes a private `ProvisionedStorageMigration` and is checked to name exactly its old and replacement claims while creating none.

### Validation

1. Against a separately authored Haskell durable-backing expectation and the Phase-55/37-observed durable backing (cache
   and node ephemeral pools excluded), derive the complete post-reconcile PV inventory
   (existing plus proposed, deduplicated by stable identity) and assert that every named backing
   independently satisfies `Σ(perBackingDebit) <= observedBacking`; an unchanged re-run produces the same
   map, not twice the debit.
   - Run `pv_aggregate_over_backing`; assert the specific `durable-demand-exceeds-backing` error and, from
     independent host/apiserver observers, zero image creation, zero mount, and zero PV/PVC writes.
   - Then run three Haskell boundary cases: (a) `presentation_overhead_over_backing`, whose usable demand fits
     but filesystem metadata/journal/reserved space does not; (b) `allocation_quantum_over_backing`, whose
     raw need is one byte above a backing quantum and therefore spends the next full quantum; and (c)
     `uniform_claim_skew_over_backing`, whose three ordinal usable demands are intentionally unequal and
     whose per-slot rounded sum fits, but `max(provisionedBytes) × 3` exceeds the backing.
   - A second Haskell case places ordinals on two named backings whose aggregate bytes fit but one
     member backing is one byte short; it must reject rather than transferring spare capacity.
   - Assert each separately authored Haskell rejection expectation and the same zero-write boundary; each positive differs only by sufficient
     backing or by one byte on the accepted side of the boundary.
   - The Haskell changed-production-subject mutants **M-skip-durable-aggregate**,
     **M-sum-unequal-ordinals**, **M-uniform-before-allocation**, and
     **M-collapse-uniform-backing-debits** must turn these checks red.
   - Run the Haskell migration boundary corpus with steady old and
     target states each fitting but (d) `migration_backing_below_highwater` — backing one byte below
     old+new+workspace, (e) `migration_copy_envelope_short` — copy Job CPU/memory/ephemeral or pod/CSI slots
     one unit short, and (f) `migration_verify_mismatch` — an injected post-copy byte mismatch.
   - Assert each against its pinned reason (`old+new+workspace-exceeds-backing`,
     `copy-job-envelope-exceeds-headroom`, `byte-verification-mismatch`): cases (d)/(e) perform zero
     replacement/Job writes; (f) leaves the old binding live, emits no `ReclaimEligible`, and the next
     inventory charges both volumes and partial workspace — the Haskell case's independently authored expected
     post-ledger, never a bare
     "nothing happened".
   - **Then drive the positive Haskell case `migration_shrink_complete` and assert the full observed sequence in order:** the copy/verify Job runs, an independent byte verification of the copied extent
     **passes**, the claim cuts over to the new volume, `ReclaimEligible` is emitted **only after** that
     pass, the new volume serves the pre-migration nonce byte-for-byte, and the old extent is retired **only after** its deletion is independently observed — never before.
   - The Haskell changed-production-subject migration mutants **M-cutover-before-verify** (cuts over / emits `ReclaimEligible` before
     verification passes), **M-credit-before-cleanup** (retires the old extent before observed deletion),
     and **M-fake-verify** (verification always reports match) must each turn this positive assertion red,
     and **M-fake-verify** and **M-cutover-before-verify** additionally turn `migration_verify_mismatch` red
     by admitting a corrupt copy; a stubbed enactor that skips copy/verify/cutover fails the positive
     assertion, not just the negatives.
2. Render the accepted multi-ordinal counterpart and assert every PVC/PV projected from the same
   `volumeClaimTemplate` has byte-identical capacity equal to the Haskell case's maximum rounded private
   `provisionedBytes`, that this supplies the maximum `requiredUsableBytes`, and that the provision witness
   debits the rounded capacity times ordinal count. Then deploy the one-ordinal rebind
   witness StatefulSet; assert its claim binds to the PV whose `metadata.name`,
   `amoebius.io/pv-identity` label, `amoebius.io/pv-logical-identity` annotation, `claimRef`
   `(namespace, PVC-name)`, and capacity **exactly equal** (`==`, not merely `>=`) to the PVC request and the
   private `UniformClaimPlan.provisionedBytes` all
   match the table's provisioned-witness column, and that node affinity pins the host-backed volume to its
   node. That raw rounded number may be larger than the logical or required usable demand. From the host block/image observer assert raw image length `== provisionedBytes`; from inside the
   mounted pod assert the filesystem type equals `VolumePresentation.fsType` and usable capacity
   `>= requiredUsableBytes`. Fill the usable filesystem and issue one more byte; assert `ENOSPC` occurs while
   the raw image length, sibling-volume usage, native-host-cache backing, and node-ephemeral usage do not grow.
   An omitted overhead model or a rounded value not divisible by `quantumBytes` fails the pure provision before
   materialization. Separately, deliberately materialize the one-byte-short-raw-image and wrong-fs-type Haskell
   cases beneath `.build/**`; those generated forms
   fail the post-create observation before PV/PVC apply or workload start, then are swept by the elevated test
   harness. The Haskell changed-production-subject **M-raw-host-directory** mutant must turn this red because the overflow succeeds or
   spills into shared backing.
3. Write a nonce byte-string through the claim, then delete the PVC; assert the PV drops to `Released`. **Then exercise re-bind for real:** re-create the identical PVC and assert it re-binds to the same
   identity-named/`claimRef`-pinned PV and that the nonce reads back unchanged through the re-bound claim.
   Assert no PVC exists outside a StatefulSet `volumeClaimTemplate`.
4. The Haskell changed-production-subject mutant **M-no-rebind** (a reconciler variant that leaves the PV `Released` but never clears the
   stale `claimRef.uid`, so a re-created PVC cannot bind) must turn assertion 3 red; a validation that checked
   only `.status.phase == Released` would leave it green and is therefore insufficient. The Haskell changed-production-subject mutant
   **M-reclaim-delete** (PV rendered with `reclaimPolicy: Delete`) must turn assertion 3 red (the PV vanishes on
   PVC delete instead of going `Released`). The Haskell negative case `pv_capacity_mismatch` changes the PV capacity
   away from the private uniform `provisionedBytes` while leaving the logical/usable demand unchanged; it must
   fail assertion 2 with the specific reason `capacity != provisioned witness`, paired with the exact-witness
   positive. This forecloses independently upsizing or downsizing a PV without re-running presentation,
   allocation rounding, uniformity, and backing admission; it does not assert logical-byte equality.
5. Drive the same retained budget through the storage-scaling dispatcher. A fitting residual produces and
   enacts only `AllocateWithinRetainedCarve`; a shrink produces only `ShrinkByVerifiedMigration` and obeys
   assertion 1's old+new+workspace/verification checks. Retained growth and shrink proceed only through a
   fresh `ValidatedStorageScalingAction`: mutating the allocation map, backing extent, or
   fingerprint after validation invalidates the action, and a stale readback or a replayed token produces
   zero host, Job, PV, or PVC writes. Replaying its consumed token
   is impossible; and an injected lost response requires re-observation while retaining every possibly
   allocated extent. A provider-capacity action is rejected because this phase supplies no cloud capability.

### Remaining Work

The pre-reset `None` claim is permanently invalid. Any future live observation, external-reader evidence,
Haskell mutant result, and receipt is generated under `.build/runs/phase_60/` as an untracked run-local bundle,
never an authored root and never pass criterion.

## Sprint 60.3: The lossless-rebind gate — Postgres row + MinIO marker round-trip ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 60.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`storage_lifecycle_doctrine.md §6 — the lossless-teardown guarantee: deterministic rebind`](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind),
[`§7 — deleting durable data is forbidden under normal operation`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation),
and [`§7.2 — the control plane holds no PVC`](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc):
prove that a destroyed-then-recreated cluster finds its durable bytes unchanged because the original backing
bytes were never deleted — nothing is restored from a backup — while the cluster delete never reclaims
durable backing and no normal-operation path can.

### Deliverables

- Minimal single-ordinal Postgres and MinIO witness StatefulSets on retained PVs (from Sprint 60.2), served
  from baked-binary images; these are rebind witnesses, not distributed MinIO (Phase 62) or HA
  Patroni-via-Percona (Phase 63), and carry no Vault-enveloping (Phase 61).
- The `Rebind.hs` gate harness: write a marker row into the Postgres witness and a marker object into the
  MinIO witness bucket, `cluster delete` (cluster/PVC/PV API objects gone, retained backing bytes intact),
  `cluster recreate` (the same fixed-raw-size filesystem images remounted and fresh PV objects rendered over
  them), then read the same bytes back — with the delete
  driven by the ordinary safe teardown that frees compute and never storage.
- A live `RebindSpec` that asserts the round-trip and, honestly, that this phase never deletes durable bytes:
  the eventual reclaim of the test-flagged witness volumes is the elevated harness's sole prerogative, kept
  out of the normal path.
- The Haskell gate-integrity declarations required by [Gate integrity](#gate-integrity): the two-witness
  representative set, separately authored claimRef and StorageClass expectations, a Haskell semantic source
  audit for forbidden reclaim capabilities, the negative-plus-positive verified-migration corpus, and Haskell
  changed-production-subject mutants **M-soft-delete**, **M-seed-marker**,
  **M-reclaim-delete**, **M-no-rebind**, **M-raw-host-directory**, **M-skip-durable-aggregate**,
  **M-sum-unequal-ordinals**, **M-uniform-before-allocation**, **M-collapse-uniform-backing-debits**,
  **M-cutover-before-verify**, **M-credit-before-cleanup**, and **M-fake-verify** the
  gate re-runs and requires red.

### Validation

1. Run the cycle on the concrete representative set of [Gate integrity](#gate-integrity) (exactly two witnesses): generate a per-run nonce, assert its absence, write it as the Postgres row and the MinIO object,
   `cluster delete`, confirm via the host OS-boundary observer that the cluster is genuinely absent
   (`kind get clusters` empty, no kind node container in `docker ps`, apiserver unreachable) while
   `${RETAINED_ROOT}` still holds the bytes, `cluster recreate` as a fresh Phase-55 bootstrap (new apiserver
   UID, PV objects re-rendered and re-applied), then read back; assert the nonce is byte-for-byte unchanged,
   re-bound by identity against the separately authored Haskell claimRef expectation, and that no witness write
   path executed post-recreate (apiserver audit log + `strace` observer). The Haskell
   changed-production-subject mutants **M-soft-delete** and **M-seed-marker** must
   both turn this assertion red.
2. Assert the full deletion reclaimed no backing volume (fresh PV objects re-appear post-recreate and
   `${RETAINED_ROOT}` bytes persist throughout). The "no normal-operation code path destroys retained backing
   bytes" universal negative is discharged two concrete ways: (a) an separately authored Haskell semantic
   source audit discovers every non-harness module in `src/` and asserts that none can issue a backing-store
   reclaim/destruction call; scoped PVC/PV binding-object deletion and whole-cluster deletion are
   allowed because neither deletes the external backing), and (b) post-cycle the fresh PV objects exist and
   host bytes are present. The control-plane daemon is a Phase-65 subject with **no realized instance at Phase 60**, so its "mounts
   no PVC" property is **not asserted as passing here** — it is recorded **UNVERIFIED** in the honesty ledger,
   not treated as a vacuously-true pass.

### Remaining Work

Generate the two-service live evidence, audit observation, mutant results, and phase ledger lazily under
`.build/runs/phase_60/`; observe that untracked run-local bundle from outside the subject and rerun after Phase 59 closes.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/storage_lifecycle_doctrine.md` — the §6 lossless-rebind guarantee gains its first
  amoebius proof on linux-cpu; the §5 host-side hard-cap mechanism is recorded as the delivered fixed-raw-size
  image-backed implementation and the §5.2 aggregate durable-backing fold gains its live check; the §10
  planning-ownership pointer resolves to delivered Phase-60 sprints.
- `documents/engineering/cluster_lifecycle_doctrine.md` — the §7 ephemeral-rebind claim gains its first
  amoebius witness (teardown frees compute, never storage) on this substrate.
- `documents/engineering/manifest_generation_doctrine.md` — the §5 reconciler is recorded as the applier of
  the StorageClass and retained-PV objects, not just service workloads.
- `documents/engineering/resource_capacity_doctrine.md` — the durable aggregate is live-checked against its
  disjoint backing, presentation/filesystem overhead and backing minimum/quantum are boundary-tested before
  uniform StatefulSet claim-plan grouping, and the linux-cpu raw-size/usable-size/fs-type/hard-ceiling tuple is
  verified live.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-60 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 60's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Storage/StorageClass.hs`,
  `src/Amoebius/Storage/RetainedPV.hs`, `src/Amoebius/Storage/Rebind.hs`, and the `RebindSpec` live suite as
  Phase-60 design-first rows.

## Related Documents

- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no-provisioner retained PVs; no unbounded storage; the control plane holds no PVC)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner
  retained-PV model, the deterministic bind, and the lossless-rebind guarantee adopted here
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — the ephemeral
  spin-up/down whose teardown the rebind gate exercises (cross-reference)
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the
  Phase-58 SSA reconciler that applies the StorageClass and retained-PV objects
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live) and the elevated harness
  as the sole sanctioned deleter of test-flagged durable storage
- [phase_58](phase_58_object_reconciler.md) — the typed renderer + live SSA reconciler this phase builds on
- [phase_61](phase_61_vault_pki.md) — the root Vault whose durable KV rebinds on the retained storage proven here
- [phase_62](phase_62_platform_backbone.md) / [phase_63](phase_63_platform_services_2.md) — the HA
  MinIO/Postgres platform stack that supersedes the witnesses
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
