# Phase 69: Content store + workflow runtime (Pulsar-Failover single-writer)

> **Purpose**: Stand up amoebius's durable-artifact substrate — the three-tier content-addressed MinIO store —
> and the orchestrator/worker workflow runtime on top of the Phase-67 native Pulsar client, gated live on
> linux-cpu by a store/fetch-by-manifest-SHA round-trip whose active worker fails over to a Pulsar
> Failover standby with no bespoke election and a leak-free teardown.
> **Read this if**: phase 69 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 69.1: Three-tier content-addressed MinIO store ⏸️](#sprint-691-three-tier-content-addressed-minio-store-)
- [Sprint 69.2: Orchestrator/worker workflow runtime + store/fetch by manifest SHA ⏸️](#sprint-692-orchestratorworker-workflow-runtime--storefetch-by-manifest-sha-)
- [Sprint 69.3: Pulsar Failover standby takeover + leak-free teardown (gate) ⏸️](#sprint-693-pulsar-failover-standby-takeover--leak-free-teardown-gate-)
- [Sprint 69.4: Register-2.5 workflow failover takeover under simulated fault ⏸️](#sprint-694-register-25-workflow-failover-takeover-under-simulated-fault-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 68, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target is the durable-artifact and workflow core that every later ML-workflow phase may consume only after reviewer approval, in two
composed pieces on one substrate. First, the **three-tier content-addressed MinIO store** — write-once
self-naming `blobs/<sha256>` and canonical-CBOR `manifests/<sha256>` under `If-None-Match: *` (with `412
Precondition Failed` treated as success), and the only mutable objects, `pointers/*`, advanced by an
`If-Match` compare-and-swap that is the single atomic commit point — keyed under a caller-supplied
`experiment-hash` namespace within an app's Phase-66 ObjectStore bucket. Every namespace also binds a finite
`ObjectStoreDemand`: exact store/tenant/bucket/full-key resident identities, structural additional-retention
object extents, bounded concurrent write sets, bounded failed writes, a positive finite orphan-GC horizon,
required `StorageBudgetId`, and exclusive writer admission. Blob/manifest bytes uploaded before a failed pointer CAS stay
charged until an observed GC deletion; the logical peak consumes Phase 62's MinIO erasure/healing and uniform
claim-plan witness rather than assuming logical bytes equal physical disk. Second, an **orchestrator/worker workflow runtime** on top of the Phase-67 client: an orchestrator worker produces a workflow `command` on a
derived topic; worker daemons attached over a Pulsar **Failover** subscription have one active
consumer and the rest as name-ordered hot standbys; the active worker writes a content-addressed artifact and
produces an `event` carrying the manifest SHA the orchestrator fetches back by that SHA.

This phase's gate must also close the Job-terminal live-proof boundary deliberately left open in Phase 58. Reviewer-approved Phase 58
must supply the closed success/failure completion state machine but has no MinIO or sole content
mutation gateway, so its live terminal Pod remains retained and charged. Here the predecessor-provisioned
collector/verification Job is driven through the full live sequence: terminal outcome → exact
content-addressed `JobCompletion` write through the sole gateway → independent MinIO digest/outcome/revision
readback → cleanup deadline plus scheduler release partition → authenticated terminal-Pod cleanup. A failed or
ambiguous write retains the Pod and all modeled resident axes; an equal persisted completion yields
`CompletedJobNoOp` and cannot recreate the Job until a new execution revision.

The future gate must test the load-bearing property that **standby takeover is delegated to Pulsar, not elected by amoebius**. Killing the active worker must trigger the subscription's own ranked failover to the
name-ordered standby, with the Phase-67 at-least-once contract redelivering the un-acked command; the store's
ETag-CAS single atomic commit point plus the typed `AdvancePredicate` keep the mutable pointer race-free, and
content-addressed confluence makes the standby's re-fetch of the artifact by manifest SHA safe without any
distributed lock. There is no bespoke ranked-failover election, no signed-commit-log kernel, and no
warm-standby control-plane daemon: the workflow itself is deployed by the Deployment-`replicas=1` control-plane daemon
whose single-instance is a k8s/etcd property, and the workers are unelected. The scope deliberately consumes
the `experiment-hash` namespace as an opaque pinned string; `deriveExperimentHash`, the `ContentAddress`
typeclass, and SplitMix seed derivation are the Phase 80 determinism kernel, not this phase.

**Phase scope:** one cohesive claim — *an artifact is fetched by its manifest hash, and a failed worker's successor resumes without bespoke coordination*. Failover is the broker's, not amoebius's.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host, in
Register 3 (live infrastructure); no apple, linux-cuda, or windows substrate is touched. This phase owns the
future bounded live validation of the otherwise substrate-agnostic CAS protocol and worker failover.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 68](phase_68_user_tenant_isolation_live.md)
**Gate:** `pb validate phase 69`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *an artifact is fetched by its manifest hash, and a failed worker's successor resumes without bespoke coordination*. Failover is the broker's, not amoebius's. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 69` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 68; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The representative runtime's provisioned steady epoch contains exactly four resource-bearing Pods: one
orchestrator and three workers. A pure `WorkflowRuntimeDemand` contains the exact identity-keyed runnable
sources; binding lowers each source to a `BoundExecutionUnit` whose `resource` contains one complete
`PodResourceEnvelope`, not a pre-expanded replica list or an envelope multiplied by an assumed scalar. Each
includes immutable image and OCI
image-store/import bytes; CPU, memory, and ephemeral-storage requests and limits; runtime working set;
writable-root, log, artifact staging, CBOR encode/decode, Pulsar frame/redelivery, and store upload/download
headroom; projected credentials/config/service-account-token bytes; local/durable/cache/accelerator arms;
exact byte-free `PodRuntimeMetadataSource` network-attachment identities and container-to-volume mount
identities; and pod slots. Each standing orchestrator/worker/gateway unit is structurally a Deployment body
with exactly one `ReplicaCardinality` (`Once | Replicated`) and one `DeploymentRolloutPolicy`: `Recreate` or
`RollingUpdate { maxSurge, maxUnavailable }`, with
`maxSurge + maxUnavailable > 0`; there is no separate Deployment replica or
strategy-plus-inapplicable-fields record. The finite verification/collector unit is structurally a Job body
with its own completions, parallelism, backoff, replacement, and terminal-retention policy—not a Deployment
rollout record. `provision` alone expands those symbolic units into
`MaterializedExecutionInstance`s and every reachable old/new/surge/terminating epoch. All three workers are
debited while two are hot standbys, and the transition peak includes the bounded old-active + promoted-worker
work overlap. Any artifact cache is a bounded `InClusterCacheDemand` (otherwise
`cache = None`), and linux-cpu binds `accelerator = None`.

For each planned orchestrator, worker, mutation-gateway, or collector/verification Pod slot, provision derives
one `KubeletRuntimeMetadataShape` from that exact source, its complete container/volume graph, and the selected
node's pinned `kubeletMetadataModel`; live normalization instead keys the observed form by authenticated
`PodUid` plus owner/source witness. The Pulumi runtime-storage rule then derives the component roles, routes
them through the selected layout, and collapses aliases so each physical carve is debited once. That physical
accounting is disjoint from logical Pod ephemeral demand.

Pure provision gives each planned epoch, and live preflight each observed snapshot, one
`ProvisionedNodeRuntimeStorageAccounting` per node: exact planned-slot/observed-UID domain, a disjoint and
exhaustive partition between qualified Pod metadata keys and image-model component keys, and one combined
debit per physical carve. Missing/swapped roles, wrong layout backing, scope/domain mismatch, ownership
hole/overlap, or alias double debit are `UnknownCommitment`/preflight refusal, never free capacity.

The content writer is exactly the `Content` arm of the closed six-arm `ObjectStoreProducerDemand` union, never
an open producer list or a scalar "artifact bytes" field. Its `ContentStoreLogicalDemand`/`ObjectStoreDemand`
retains one `StorageBudgetId`; exact store/tenant/bucket/full-key identities for every blob, manifest, and
pointer; committed residents; future retained extents; concurrent write sets; multipart/upload workspace;
failed-write sets, CAS-loser orphans, and positive finite GC horizon; and `ObjectStoreMutationAdmission` for
the exclusive writer. The concurrency bound includes the declared active/failover overlap. Same digest under
different namespaces remains two objects unless the full physical object identity is equal.

The sole-routable content mutation gateway and the orphan collector/verification Job are also runnable units
with complete `PodResourceEnvelope`s. Their CPU/memory/ephemeral/image/log and scan/upload workspace enter the
same peak as the four runtime Pods; direct worker S3 PUT stays denied. Whole-deployment provision merges the
Content peak with every desired producer in the other five arms, MinIO geometry/healing, Pulsar hot/offload
demand, namespace quotas, Pod/CSI slots, storage models, and planned rollout/failover transition. Snapshot-bound
preflight then joins the live residual before it creates a Pod, topic, or object. Pure controller expansion
gives every desired/prior object a `KubernetesApiObjectDemand`; live preflight joins the observed old/new/apply map.
`EtcdLogicalDemand { desiredObjects, churn, model }` derives the private logical peak, which must fit
`ControlPlaneStorageDemand.etcd.backendQuotaBytes`, before the backend-at-quota plus
WAL/snapshot/serialized-defrag peak separately fits its physical backing. Render
accepts only opaque provisioned projections. External
Pod/controller/Pulsar/MinIO readback must normalize to those projections, and unknown children, consumers,
keys, multiparts, observed-UID runtime-metadata components/roles/backings, scope rows, or bytes are `UnknownCommitment`.

The collector's terminal record is the `JobCompletion` member of `ControlPlaneState`, not a content blob or an
unaccounted side table. Its exact execution-identity digest, outcome variant, revision, canonical byte bound,
retention/failure/orphan horizon, `StorageBudgetId`, and mutation admission join the global object-producer
inventory and MinIO physical fold before the collector Pod may be created. The same sole gateway must be the only
mutation route. Cleanup consumes a fresh external MinIO readback plus deadline and scheduler-release evidence;
neither a Job status condition nor a gateway acknowledgement alone is sufficient.

The Haskell-declared boundary corpus makes each runnable source envelope, exact four-instance steady expansion,
gateway/collector, kind-indexed controller/rollout/failover
overlap, runtime-metadata shape/component/role/backing, topic cursor/backlog, object identity/count/size, concurrent/failure/orphan term, storage budget,
API-object revision/Event, and etcd term one unit short. Omission mutants dropping either standby, the gateway
or collector, the largest simultaneous runtime-metadata row, a role/domain/ownership/grouping witness, or pinned kubelet model, a failed CAS object, a declared pointer object, the `Content` producer arm, one desired API
object, the collector's `JobCompletion` identity/retention/failure extent, a churn operand, or the etcd model
refuse before any k8s/Pulsar/MinIO effect; any serialized case is generated beneath
`.build/test-corpora/**`, and exact-fit twins render
and match live readback.

```mermaid
flowchart LR
%% register: orientation
  dhall[InForceSpec test topology] --> up[Bring up on linux-cpu kind: Pulsar plus MinIO already HA]
  up --> produce[Orchestrator worker produces workflow command on the derived topic]
  produce --> worker[Active worker consumes via Failover subscription]
  worker --> store[Worker writes content-addressed artifact to the three-tier MinIO store]
  store --> event[Worker produces workflow event carrying the manifest SHA]
  event --> kill[Kill the active worker inside the critical window: store write done, event unacked]
  kill --> failover[Pulsar promotes the name-ordered standby: no amoebius election]
  failover --> fetch[Orchestrator fetches artifact by manifest SHA from the promoted standby]
  fetch --> teardown[Idempotent leak-free teardown plus per-run ledger]
```
*Orientation. Design intent. The sequence this phase's gate exercises, including the kill inside the critical window; the acceptance condition itself is stated in [Phase Summary](#phase-summary), not by the picture. Nothing here has run.*

## Doctrine adopted

- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes content store + workflow runtime (Pulsar-Failover single-writer) causes to exist are charged to a grant that carries its ceiling and concurrency together.
This phase's target is to become the first live amoebius realization of the content store and the
delegated-single-writer workflow runtime. Each bullet names the section the target must adopt; individual
sprints cite the same sections where they must build on them.

- [`content_addressing_doctrine.md` §2 — The three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  — *the three-tier store: blobs ← manifests ← pointers*: the three object classes and two write protocols
  ([`content_addressing_doctrine.md` §2.1 — Three object classes, two write protocols](../documents/engineering/content_addressing_doctrine.md#21-three-object-classes-two-write-protocols) three classes / two protocols; [`content_addressing_doctrine.md` §2.2 — Why this shape removes the races](../documents/engineering/content_addressing_doctrine.md#22-why-this-shape-removes-the-races) why the shape removes the write/write and write/read hazards), keyed under the
  [`content_addressing_doctrine.md` §3 — `experimentHash`: identity is *what was requested* ‖ *where it ran*](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
  namespace consumed here as an opaque pinned prefix. The same [`content_addressing_doctrine.md` §2.1 — Three object classes, two write protocols](../documents/engineering/content_addressing_doctrine.md#21-three-object-classes-two-write-protocols) capacity contract and
  [`resource_capacity_storage.md` §5.1 — Durable demand is logical first, physical only after geometry](../documents/engineering/resource_capacity_storage.md#51-durable-demand-is-logical-first-physical-only-after-geometry)
  require committed residents + bounded in-flight writes + every failed-write orphan through the finite
  positive GC horizon to remain charged through MinIO's physical and uniform-claim witness.
- [`content_addressing_doctrine.md` §5 — Confluence: content-addressed data crosses cluster boundaries safely](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely)
  — *confluence*: content-addressed data is a join-semilattice, which is what makes the standby's re-fetch by
  manifest SHA and the at-least-once redelivery idempotent without a distributed lock.
- [`content_addressing_doctrine.md` §6 — The honest ceiling: types make the bookkeeping total, not the physics deterministic](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
  — *the honest ceiling*: store bookkeeping totality (immutability + a commutative/associative/idempotent
  pointer join) is a proven-in-types argument; this phase's future gate must validate the CAS protocol's runtime
  behaviour and must claim neither compute determinism nor cross-cluster replication.
- [`daemon_topology_doctrine.md` §5 — Single-instance and coordination — delegated, not elected](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
  and [`daemon_topology_doctrine.md` §5.2 — The coordination plane is for worker events and audit, not leadership](../documents/engineering/daemon_topology_doctrine.md#52-the-coordination-plane-is-for-worker-events-and-audit-not-leadership)
  — *single-instance and coordination — delegated, not elected*: worker single-consumer semantics come from a
  Pulsar `Exclusive`/`Failover` subscription, never a bespoke election; Pulsar + MinIO are the workflow event
  stream and audit trail, not an election substrate.
- [`daemon_topology_doctrine.md` §4 — Worker daemons — N, unelected](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
  and [`daemon_topology_doctrine.md` §4.3 — The Feed-sourced continuous trainer: single-writer delegated](../documents/engineering/daemon_topology_doctrine.md#43-the-feed-sourced-continuous-trainer-single-writer-delegated)
  — *worker daemons, N, unelected* / *single-writer delegated*: the orchestrator and workers are unelected
  worker daemons; liveness (at most one active per subscription) is the Pulsar subscription and safety
  (race-free `latest`) is the store's ETag-CAS commit point plus the typed `AdvancePredicate`.
- [`daemon_topology_doctrine.md` §3.1 — "Exactly one pod" is a k8s/etcd property, not an amoebius election](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  — *exactly one pod is a k8s/etcd property*: the workflow is deployed by the Deployment-`replicas=1`
  control-plane daemon (Phase 65), whose single-instance is delegated to k8s/etcd, so nothing in this phase
  runs an election of any kind.
- [`pulsar_client_doctrine.md` §5 — The capability surface: lookup · produce · consume · subscribe · seek](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek)
  and [`pulsar_client_doctrine.md` §7 — Delivery: at-least-once with broker-side dedup (the robust default)](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default)
  — *the capability surface (the Failover subscription)* / *at-least-once with broker-side dedup*: the Phase-67
  subscription surface this phase's target must consume for standby takeover and the redelivery/dedup contract that keeps a
  retried produce or a redelivered consume idempotent.
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — *Register 2.5 — where deterministic simulation sits*: Sprint 69.4 runs the real Sprint-64.2/32.3 workflow
  runtime under `IOSimPOR` against the Phase-16 modeled environment as a Register-2.5 lower-register cross-check
  of the same leak-free-takeover / no-double-application properties the Register-3 live gate asserts.
- [`chaos_failover_doctrine.md` §12 — The moral core — proven, tested, assumed](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  (cross-reference) — *proven, tested, assumed*: each gate run emits a proven/tested/assumed ledger; skipping
  an applicable failover-injection move marks that layer UNVERIFIED, never green. The asynchronous
  **cross-cluster** failover boundary and its formal model are owned by
  [`chaos_failover_second_axis.md` §16 — The Second Axis — when one cluster becomes a forest](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
  and realized by Phase 74's geo-replication plus Phase 75's gateway-migration drills, not here — this phase
  exercises the intra-cluster subscription only.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and an authorized-reviewer tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 69.1: Three-tier content-addressed MinIO store ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 68](phase_68_user_tenant_isolation_live.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`content_addressing_doctrine.md §2 — the three-tier store: blobs ← manifests ← pointers`](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers),
namespaced under [`§3 experimentHash`](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
as an opaque pinned prefix: build the three object classes and two write protocols so the only race in the whole
store is a single one-object atomic pointer flip.

### Deliverables

- `blobs/<sha256>` — write-once content-addressed payloads keyed by `sha256(bytes)`, PUT with
  `If-None-Match: *`, `412` treated as success (the bytes already exist by definition).
- `manifests/<sha256>` — write-once **canonical-CBOR** manifests keyed by `sha256(canonical-cbor(manifest))`,
  naming their constituent blob SHAs; the canonical encoder sorts components deterministically so two writers
  with equal logical content emit the same key. The manifest SHA is the artifact id used in the workflow events
  of Sprint 69.2.
- `pointers/*` (`latest`, `best/<metric>`, `trial/<id>/…`) — the only mutable objects; each body is a 32-byte
  manifest SHA, updated by `If-Match: <etag>` compare-and-swap as the single atomic commit point; the pure CAS
  decision (`PointerWritten` vs `PointerConflict`) and a typed `AdvancePredicate` resolve a lost CAS.
- A mandatory `ObjectStoreDemand` per namespace: exact physical-id-keyed committed residents, structural
  maximum additional retained extents/retention, maximum concurrent write sets, maximum object extents per
  set, maximum failed write sets per finite window, a positive finite orphan-GC horizon, the bucket's required
  `StorageBudgetId`, and `ObjectStoreMutationAdmission`. Provisioning returns the private resident +
  future/transient extent peak, merges it with all Phase-62 producer arms, and feeds that structure—not a byte
  scalar—into MinIO geometry. The sole gateway enforces object identity/count/size/concurrency/retention;
  direct S3 writes are denied, and observed orphan/multipart bytes remain resident until post-GC inventory.
- The demand enters the closed producer inventory only through its `Content` arm. The resource-bearing write
  gateway and collector/verification Job have complete Pod envelopes, and content concurrency includes the
  active/promoted-worker overlap; there is no free admission or GC process.
- The collector/verification Job consumes the Phase-58 terminal state machine live for the first time. Its
  success and `FailedBackoffExhausted` variants lower to the `JobCompletion` control-plane-state kind with an
  exact content-addressed key. The sole gateway writes it, a distinct read-only MinIO client verifies canonical
  bytes/digest/outcome/revision, and only fresh cleanup-deadline plus scheduler-release evidence authorizes
  deletion. Failed/unknown write outcome keeps the terminal UID and all retained axes charged; equal readback
  constructs `CompletedJobNoOp` and a changed execution revision is required to run again.
- Store keys taken under a caller-supplied `experiment-hash` namespace string within the app's ObjectStore
  bucket; this sprint does **not** build `deriveExperimentHash`, the `ContentAddress` typeclass, or SplitMix
  seed derivation (Phase 80 kernel work).
- **Independent canonicalization apparatus:** one reviewed Haskell logical manifest, the canonical-CBOR
  convention, and a separately implemented Haskell canonicalizer generate the reference bytes and SHA under
  the run bundle. No CBOR or SHA transport is repository source. A reviewed Haskell mutation definition emits
  the same logical manifest in
  non-sorted component order under `.build/test-corpora/`; its expected failure is a byte mismatch at the first
  component-ordering offset and a different key. The applied Haskell `insertion-order-encoder` changed-subject
  operator emits map/component bytes in insertion order rather than
  sorted order; the gate MUST turn this mutant **red** against the golden vector. The independently authored
  Haskell write-budget expectation pins committed/concurrent/failed/horizon inputs and expected logical
  peaks, including one-byte-under/over and a pre-horizon resident orphan. Its CSV projection is generated
  lazily beneath `.build/test-corpora/content_store/**`. The applied Haskell
  `orphan-free-on-pointer-conflict` and `orphan-budget-omitted` operators must turn that corpus red.

### Validation

1. Run this suite at **Register 3** against the **single-node kind cluster's live MinIO** — the standing
   Phase-62 HA service on the Phase-60 retained PV, never an in-process or local S3 fake, so the evidential
   weight of every item below is unambiguous. Write the same blob twice through the gateway under
   `If-None-Match: *` and assert first-write success, second-write `412` treated as a no-op success.
2. Encode the same logical manifest from **two writers that each first construct it with a distinct component
   insertion order/permutation**, then compare both with fresh reference bytes and SHA produced by the
   independent canonicalizer under `.build/runs/phase_63/`. Assert the generated noncanonical case fails
   with a **byte mismatch at the first component-ordering offset** (not merely "differs"), and that the
   Haskell-authored `insertion-order-encoder` changed subject turns this validation **red**.
3. Race two `pointers/latest` `If-Match` updates; assert one commits, the loser gets `412`, re-reads, and the
   typed advance predicate converges both to the same HEAD; assert a reader always observes a 32-byte SHA
   naming an immutable manifest, never a torn pointer body.
4. Run the Haskell-declared write-budget boundary corpus, then upload the maximum blob/manifest set and force its pointer CAS to
   lose. From an external MinIO inventory, assert the orphan is resident before the configured GC horizon and
   remains in residual capacity; a one-byte-over follow-on admission returns the specific capacity error with
   zero object mutation. After the horizon, run the collector but grant no capacity credit until a fresh
   inventory observes deletion. Assert the Haskell-authored `orphan-free-on-pointer-conflict` and
   `orphan-budget-omitted` changed subjects each turn this validation red.
   Also reject the writer's direct MinIO PUT credential/route, too many same-total-byte objects, a
   missing/conflicting writer admission, and a dropped physical object id before backing usage changes.
   Assert the same SHA under two `experiment-hash` namespaces is charged as two physical objects, that an
   identical full physical object id deduplicates, and that conflicting sizes for one id reject.
5. Make the gateway or collector CPU, memory, ephemeral/image/log/workspace term one unit short, or omit the
   closed `Content` arm, one blob/manifest/pointer identity, one multipart, one CAS-loser orphan, or one
   `JobCompletion` identity/retained-version/failed-write extent. Assert each
   case rejects before object mutation; the exact-fit twin's full MinIO inventory and live gateway/Job
   envelope equal the private provisioned projection.
6. Drive the collector Job once to `Succeeded` and once to `FailedBackoffExhausted`. For each variant, use an
   apiserver watch plus an independent MinIO `HEAD`/`GET` reader to prove gateway write and exact
   digest/outcome/revision readback precede terminal-Pod deletion. Inject failed/ambiguous PUT, wrong digest,
   wrong outcome/revision, early deadline, and incomplete scheduler release: each retains and charges the exact
   terminal UID with no delete. After matching persistence and authorized cleanup, an immediate reconcile
   yields `CompletedJobNoOp`, creates no Pod, and changes no object version. Seeded cleanup-on-Job-status and
   trust-gateway-ack-without-readback mutants must turn red.

> **Honesty.** Blob/manifest conflict-freedom and pointer lattice-convergence are *proven-in-types* arguments
> (immutability + a commutative/associative/idempotent join) per
> [`content_addressing_doctrine.md §6`](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic);
> the CAS protocol's runtime behaviour is validated here, but cross-cluster replication ([§5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely) confluence) is not
> exercised in this phase. This generalizes the sibling `jitML` checkpoint format — sibling evidence, not an
> amoebius result.

### Remaining Work

Replace the pre-reset transport inventory with reviewed Haskell logical inputs, canonicalization expectations,
and write-budget declarations. Generate reference and mutated bytes lazily beneath `.build/**` during the run.

## Sprint 69.2: Orchestrator/worker workflow runtime + store/fetch by manifest SHA ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 69.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`daemon_topology_doctrine.md §4 — worker daemons, N, unelected`](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
and [`content_addressing_doctrine.md §5 — confluence`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
wire the Phase-67 client, its topology algebra, and the Sprint-64.1 store into an orchestrator/worker runtime
whose command → artifact → event round-trip is idempotent by construction — the workers unelected, the
artifact reference a content address.

### Deliverables

- An orchestrator daemon that, using the Phase-67 topology algebra, produces a workflow `command` on the
  derived topic and consumes the corresponding `event`; it is an unelected worker daemon, not a leader.
- Worker daemons that consume the command, write a content-addressed artifact to the store (Sprint 69.1), and
  produce an `event` carrying the manifest SHA — CBOR payloads throughout (Phase 67), a large artifact carried
  by its manifest SHA reference and never inline.
- The orchestrator's fetch-by-manifest-SHA read path over the store, exercising [§5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely) confluence: re-fetching the
  same immutable manifest/blob is a no-op, which is exactly what the at-least-once contract needs.
- The runtime is scheduled under the Deployment-`replicas=1` control-plane daemon (Phase 65); no orchestrator/worker role
  runs a bespoke election, and the control-plane daemon's single-instance stays a k8s/etcd property.
- A `WorkflowRuntimeDemand` whose one orchestrator and three worker sources lower to identity-keyed symbolic
  Deployment-indexed `BoundExecutionUnit`s with complete envelopes, `ReplicaCardinality`,
  `DeploymentRolloutPolicy`, client buffers and artifact workspace, Pod slots, and bounded failover overlap.
  The collector lowers separately to a finite Job body. Provision derives the exact
  four-instance all-running standby epoch before any command is produced.

### Validation

1. Run the command → event round-trip and assert the artifact the worker wrote is fetched by the orchestrator
   by its manifest SHA and matches byte-for-byte.
2. Assert a retried produce and a redelivered consume are collapsed by the Phase-67 broker-side dedup so
   downstream idempotent state observes each exactly once.
3. Assert no orchestrator/worker code path performs a leadership election or holds cluster-wide authority, by a
   **two-part mechanism** (not code review): (a) a **static dependency/import audit** of the
   `amoebius-runtime` build plan asserting no leader-election or distributed-lock dependency is linked
   (no `etcd`/Raft lease client, no k8s `Lease`/`coordination.k8s.io` client, no ZooKeeper/consensus library)
   — the forbidden-package expectation is a separately reviewed Haskell value; and (b) an **OS-boundary runtime trace** (`strace`/network capture at the pod boundary, not a self-emitted compliance log) over a full
   round-trip asserting zero calls to a k8s `Lease`/`coordination.k8s.io` endpoint or any external lock API.
   The applied Haskell `lease-election` changed-subject operator adds a worker that acquires a k8s
   `Lease` before consuming; both checks MUST turn it **red**.
4. Run one-short fixtures for each orchestrator/worker CPU, memory, ephemeral, image/log, projected-file,
   Pulsar-buffer, artifact-workspace, Pod slot, Deployment rollout/failover term, runtime component role, and
   grouped layout backing. A mutant that drops either standby
   from the provision fold must reject before Pod creation or command production; live readback must contain
   exactly the four provisioned identities and envelopes.

### Remaining Work

The pre-reset record said `None` and claimed delivery/validation by the old Phase-69 gate; both statements are
permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row,
predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 69.3: Pulsar Failover standby takeover + leak-free teardown (gate) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 69.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`pulsar_client_doctrine.md §5 — the capability surface (the Failover subscription)`](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek),
[`§7 — at-least-once with broker-side dedup`](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default),
and [`daemon_topology_doctrine.md §5 / §5.2 — single-instance and coordination, delegated not elected`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected):
prove that killing the active worker yields standby takeover through Pulsar's own ranked failover — not a
bespoke amoebius election — and assemble the phase gate.

### Deliverables

- Worker daemons attached over a Pulsar **Failover** subscription (Phase 67): one active, the rest
  name-ordered hot standbys; single-writer liveness is the subscription, safety is the store's ETag-CAS commit
  point plus the typed `AdvancePredicate` (Sprint 69.1), so even a bounded failover overlap cannot regress
  HEAD.
- The **critical-window kill-injection path**: the kill lands **after the active worker has completed its store write and before it acks the `event`** (the same window Sprint 69.4 injects in simulation, restated for the
  live gate), so the load-bearing standby re-fetch + bounded failover overlap are actually exercised — not a kill
  against an idle, already-drained worker. Pulsar promotes the name-ordered standby, the Phase-67 at-least-once
  contract redelivers the un-acked command, and [§5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely) confluence makes the standby's re-fetch of the artifact by
  manifest SHA safe without a distributed lock. The window placement is asserted from broker/consumer state
  (the store object exists; the `event` message is still unacked) and recorded in the per-run ledger.
- The **postflight sweep's explicit inventory contract**: the sweep MUST inventory, and the ledger MUST record,
  every one of these resource classes: (i) k8s objects the topology applied, enumerated by the run's **field manager / ApplySet**; (ii) **Pulsar topics, subscriptions, consumers, and producers** created for the run;
  (iii) **MinIO objects under the run's `experiment-hash` prefix** outside a **named retained-by-design set**
  (the durable test-flagged bytes reclaimed by Phase 48). The sweep emits its **full inventory list and the named retained set** into the per-run ledger; **any non-empty remainder outside the retained set is a hard gate failure**. (Durable-byte reclaim staying with Phase 48 is the *only* exemption, and only for the
  explicitly named retained set — not a blanket class exemption.)
- **Reference and mutation apparatus:** execute the independent no-fault path during the run and retain its
  `pointers/latest` HEAD only beneath `.build/runs/phase_63/`; remove
  `.build/test-corpora/workflow_runtime/head_nofault.bin`. A separately authored Haskell promoted-consumer
  expectation may generate a text projection beneath `.build/test-corpora/workflow_runtime/**`. Applied
  Haskell changed-subject operators the gate must turn red include `ack-before-store-write` (effect reorder — worker acks
  the `event` before the store write completes, so a mid-window kill loses the command) and
  `sweep-skips-pulsar` (invariant-clause delete — the sweep omits the Pulsar topic/subscription
  class and thus reports leak-free vacuously while topics leak).
- A Haskell-declared failover test topology, rendered lazily as Dhall beneath `.build/test-corpora/**` — the
  named **representative service set: one orchestrator + three workers (one active, two name-ordered standbys)**
  over the standing Pulsar + MinIO — and its
  `FailoverSpec`: spin up, run the store/fetch-by-manifest-SHA round-trip, inject the critical-window worker
  kill, observe the specific name-ordered standby take over, and always tear down — emitting a per-run ledger
  artifact.
- The opaque whole-deployment provision witness for exactly those four runtime Pods plus gateway/collector,
  all topic/cursor/offload and closed `Content` object demands, and the active→standby/rollout transition peak;
  the live gate cannot start from a raw bound topology.

### Validation

1. Run the gate topology end-to-end on the linux-cpu kind cluster and assert the artifact is fetched by manifest
   SHA and matches. **Land the kill inside the critical window** — after the active worker's store write and
   before its `event` ack, the window verified from broker/consumer state — and assert live that (a) the
   **lexically next-in-name-order** standby (read from the Pulsar admin `subscription/{sub}/consumers` API and
   matched against the independently reviewed Haskell promoted-consumer expectation, so the assertion names the specific
   expected consumer and not merely "some standby") is promoted; (b) the un-acked command is redelivered with
   **none lost and none double-applied** — an **external Pulsar consumer** (OS-boundary, not the runtime) sees
   it **exactly once**; and (c) the resulting `pointers/latest` HEAD is byte-identical to the fresh no-fault
   reference retained in the run bundle. Assert the applied Haskell `ack-before-store-write` operator turns this
   validation **red** (a mid-window kill loses its command).
2. **Idempotency and leak-free teardown, disambiguated.** "**Idempotent setup**" means a *second `apply` of the
   topology against the still-standing topology is a byte-stable no-op* (the Phase-58 sense — zero fields
   diverge). "**Re-runs idempotently**" (the gate line) means a *second full spin-up → run → teardown cycle from
   clean state passes green*, and that second cycle runs under a **distinct `experiment-hash` namespace** so the
   store/fetch path is an **independent recompute, cache-bypassed** (never served from a content-addressed
   store-hit of the first run) with the compute path asserted to have executed. Assert leak-free teardown: the
   postflight sweep emits its **full inventory across all three enumerated classes** (ApplySet k8s objects;
   Pulsar topics/subscriptions/consumers/producers; MinIO objects under the run's `experiment-hash` prefix) plus
   the **named retained set** into the ledger, and **any non-empty remainder outside the retained set fails the gate**. Assert the applied Haskell `sweep-skips-pulsar` operator turns this validation **red** (leaked Pulsar topics
   go undetected under a class-omitting sweep).
3. Assert the run emits a proven/tested/assumed ledger per
   [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed);
   skipping the applicable failover-injection move marks that layer UNVERIFIED, never green.
4. Assert every one-short/omission case in the phase resource corpus—including both SplitRuntime metadata
   backings, role resolution, planned/observed domains, qualified Pod/image ownership, and alias grouping—has zero apiserver, broker-admin, and
   MinIO mutations. For the exact-fit run, normalize the live four-Pod/controller set, gateway/collector,
   topics/subscriptions, and exact object/multipart inventory and compare it with the opaque provisioned value;
   `Ready` plus an unexplained resource is a gate failure.

> **Honesty.** This sprint exercises the **intra-cluster** Failover subscription only; the
> asynchronous cross-cluster failover boundary and its formal gateway-migration model are owned by
> [`chaos_failover_second_axis.md §16`](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
> and realized by Phase 74's geo-replication plus Phase 75's gateway-migration drills, not here. Pulsar's own
> broker/bookie consensus is delegated, not re-proven. The
> Failover-subscription worker shape is proven over WebSockets in the sibling `infernix` — sibling evidence,
> not an amoebius result; this sprint proves it over the native protocol for the first time. The eventual
> reclaim of test-flagged durable bytes is the elevated live harness's prerogative (Phase 90), kept out of the
> normal teardown path.

### Remaining Work

Replace the pre-reset no-fault HEAD and failover-rank transport inventory with reviewed Haskell declarations;
generate comparison material at gate time beneath `.build/**` and rerun under universal artifact hygiene.

## Sprint 69.4: Register-2.5 workflow failover takeover under simulated fault ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 69.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md §4 — Register 2.5 — where deterministic simulation sits`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits) at
**Register 2.5** on the **`none`** substrate: run the *real* Sprint-64.2/32.3 workflow runtime and its
Failover-takeover path — the daemon/workflow code written against `io-classes` — under `IOSimPOR` against the
Phase 16 Sprint 16.2 modeled fault-injectable environment, and assert the same load-bearing properties the Sprint 69.3
live gate asserts (leak-free standby takeover; no double-application), now **deterministically replayable** under
adversarial schedules instead of a single live wall-clock trace.

### Deliverables

- A `WorkflowFailoverSimSpec` that binds `Amoebius.Workflow.Runtime`/`Orchestrator`/`Worker` (Sprints 59.2–38.3)
  to the Phase 16 Sprint 16.2 `Amoebius.Sim.Env` substrate through `io-classes` and drives it under `IOSimPOR` — the
  production code path, not a simulation-only re-implementation.
- The injected fault schedule (`WorkflowSimScenario`): a `kill-worker-mid-workflow` inside the gate's critical
  window — after the store write and before the `event` ack — at-least-once **redelivery** of the un-acked
  command, and a broker/consumer
  **partition** — modeled by the fake Pulsar/MinIO of Phase 16 Sprint 16.2, not a live cluster.
- A property that, over *every* schedule `IOSimPOR` explores, asserts the Pulsar-Failover subscription takeover
  is **leak-free** (no orphaned consumer/producer/artifact handle survives the promotion) and that **no effect is double-applied** — content-addressed re-fetch is a no-op and log-fold dedup collapses the redelivery — so
  the committed pointer HEAD and downstream state are identical across all explored interleavings.
- A **Register-2.5 ledger** artifact per run, recording the explored-schedule count and the leak-free /
  no-double-application properties discharged, feeding the same proven/tested/assumed ledger
  ([`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed))
  as the Sprint-64.3 live gate.
- **Reviewed Haskell changed-subject operators the simulation must turn red:**
  `double-apply-on-redelivery` (dropped dedup — the runtime applies the redelivered command a
  second time, so the pointer HEAD diverges on the fault-firing schedules) and
  `orphan-consumer-on-promotion` (leaked effect — the old active worker's consumer handle
  survives the promotion), each of which some explored `IOSimPOR` schedule MUST falsify.

### Validation

1. Run `WorkflowFailoverSimSpec` under `IOSimPOR` and assert that, on every explored schedule with the
   `kill-worker-mid-workflow` fault, a name-ordered standby takes over the Failover subscription and the run is
   leak-free — no orphaned consumer, producer, or artifact handle outlives the promoted standby. Assert the
   applied Haskell `orphan-consumer-on-promotion` operator turns this validation red.
2. Assert **no double-application**: across all interleavings of redelivery and partition the content-addressed
   re-fetch is a no-op and the log-fold dedup collapses the redelivered command, so the pointer HEAD and
   downstream state are byte-identical whether or not the fault fired. Assert the applied Haskell
   `double-apply-on-redelivery` operator turns this validation red.
3. Assert the run emits a Register-2.5 ledger recording the explored-schedule count and the discharged
   properties, and that a failure replays deterministically from its seed and schedule.

> **Honesty.** This is a **Register 2.5** result on the **`none`** substrate: it tests the runtime's failover
> logic and dedup are correct under *every schedule the model explores*, not that the modeled fake Pulsar/MinIO
> match the live broker/bookie and object store. **Modeled-substrate fidelity is assumed** and is discharged
> only by this phase's **Register-3 live gate** (Sprint 69.3) on the linux-cpu kind cluster — the deterministic
> simulation is a fast, adversarial, replayable **lower-register cross-check**, never a substitute for it. The properties asserted
> here are exactly the ones the live gate asserts; the register is lower because the environment is modeled.

### Remaining Work

The pre-reset record said `None` and claimed delivery/validation by the old Phase-69 gate; both statements are
permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row,
predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/content_addressing_doctrine.md` — record that §2 (the three-tier store + the two write
  protocols) is realized in `amoebius-store`, namespaced under an opaque `experiment-hash` prefix, with the §3
  `experimentHash` derivation and seed kernel explicitly deferred to Phase 80; note §5 confluence is consumed
  (idempotent re-fetch/redelivery) but cross-cluster replication remains unexercised. Record the live
  failed-pointer-CAS drill: orphan bytes remain charged through the finite positive GC horizon and reclamation
  earns capacity only after an external inventory observes deletion.
- `documents/engineering/resource_capacity_doctrine.md` — record the content-store logical peak boundary
  corpus and its consumption of Phase 62's MinIO physical/uniform-claim witness.
- `documents/engineering/storage_lifecycle_doctrine.md` — record that the store's blob/manifest/pointer bytes
  land on the Phase-60 retained PV under the standing Phase-62 MinIO service, and that CAS-loser orphans stay
  charged through the finite positive GC horizon until an external inventory observes deletion.
- `documents/engineering/daemon_topology_doctrine.md` — record the orchestrator/worker scaffolding and that
  standby takeover is the §5/§5.2 delegated Pulsar `Exclusive`/`Failover` subscription, with no bespoke
  election anywhere in the runtime.
- `documents/engineering/pulsar_client_doctrine.md` — flip the §5 Failover-subscription and §7
  at-least-once/dedup sibling-evidence honesty notes to live-proof status once the gate runs (status itself
  stays in this plan).
- `documents/engineering/chaos_failover_doctrine.md` — record the §12 per-run proven/tested/assumed ledger for
  the intra-cluster failover injection, and that the §16 cross-cluster boundary stays deferred to Phase 74
  geo-replication plus Phase 75 gateway-migration drills.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the §4 Register-2.5 `IOSimPOR`
  cross-check that replays the failover-takeover leak-free / no-double-application properties over adversarial
  schedules, feeding the same proven/tested/assumed ledger as the live gate.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-69 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 69's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius-store` and `amoebius-runtime` packages and
  their target module paths, mapped to the owning content-addressing and daemon-topology doctrines, as
  Phase-69 design-first rows.

## Related Documents

- [README.md](README.md) — the live tracker; Phase 69 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (skeleton, sprint format, the doctrine-citation rule, the register + honesty + one-substrate disciplines)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no bespoke election; single-instance delegated to k8s/etcd; the content-addressed store)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — the
  three-tier store, the two write protocols, confluence, and the honest ceiling adopted here
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — unelected worker daemons
  and single-instance/coordination delegated to Pulsar and k8s/etcd, never a bespoke election
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the Phase-67 capability
  surface (the Failover subscription) and the at-least-once/dedup contract this phase consumes
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed
  ledger and the deferred cross-cluster (Second Axis) boundary
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the
  Register-2.5 `IOSimPOR`-over-modeled-environment lower-register cross-check that replays the failover-takeover
  properties under adversarial schedules
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live), the spin-up → run →
  always-tear-down contract, and the elevated harness as the sole deleter of test-flagged durable storage
- [phase_67](phase_67_pulsar_client.md) — the native Pulsar client this workflow runtime is built on
- [phase_80](phase_80_determinism_jitcache.md) — the `experimentHash` derivation + SplitMix seed kernel deferred
  from this phase's store namespace
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
