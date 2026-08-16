# Phase 37: Content store + workflow runtime (Pulsar-Failover single-writer)

> **Purpose**: Stand up amoebius's durable-artifact substrate — the three-tier content-addressed MinIO store —
> and the orchestrator/worker workflow runtime on top of the Phase-35 native Pulsar client, gated live on
> linux-cpu by a store/fetch-by-manifest-SHA round-trip whose active worker fails over to a Pulsar
> Failover standby with no bespoke election and a leak-free teardown.
> **Read this if**: phase 37 is next in the queue, or a later phase depends on what its gate establishes.

Phase 37 delivers the content store + workflow runtime (Pulsar-Failover single-writer); its design is owned by [content_addressing_doctrine.md](../documents/engineering/content_addressing_doctrine.md), [resource_capacity_storage.md](../documents/engineering/resource_capacity_storage.md), [daemon_topology_doctrine.md](../documents/engineering/daemon_topology_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate. Validated 2026-08-11 with
`python3 tools/phase37_gate.py --reuse-fresh-live`; ledger
`dynamically-resolved`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_26_object_reconciler.md, DEVELOPMENT_PLAN/phase_35_pulsar_client.md, DEVELOPMENT_PLAN/phase_38_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_39_release_lifecycle.md, DEVELOPMENT_PLAN/phase_48_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_54_test_topology_dsl.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — the four-Pod runtime plus gateway/collector envelope](#resource-provision--the-four-pod-runtime-plus-gatewaycollector-envelope)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 37.1: Three-tier content-addressed MinIO store ⏸️](#sprint-371-three-tier-content-addressed-minio-store-)
- [Sprint 37.2: Orchestrator/worker workflow runtime + store/fetch by manifest SHA ⏸️](#sprint-372-orchestratorworker-workflow-runtime--storefetch-by-manifest-sha-)
- [Sprint 37.3: Pulsar Failover standby takeover + leak-free teardown (gate) ⏸️](#sprint-373-pulsar-failover-standby-takeover--leak-free-teardown-gate-)
- [Sprint 37.4: Register-2.5 workflow failover takeover under simulated fault ⏸️](#sprint-374-register-25-workflow-failover-takeover-under-simulated-fault-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Observed artifact migration — 2026-08-11:** `manifest_canonical.cbor`,
`manifest_canonical.sha256`, and `manifest_noncanonical.cbor` are reproducible from one logical manifest and
the independent canonicalizer/mutation definition. They must be generated during the run. The authored
logical manifest, canonicalization rules, reference adapter, and expected mismatch locus remain eligible
source after independent review.

**Invalidated historical record:**

✅ Done. The phase runs on the **linux-cpu** substrate in **Register 3** (live infrastructure) — a single-node
`kind` cluster brought up by the Phase 24 bootstrap coordinator with
Pulsar and MinIO already standing as HA platform services (Phase 30) on retained storage (Phase 28), and it
opens only after the Phase 35 gate (the native-protocol Pulsar client, CBOR codec, four subscription types,
and broker-side dedup) closes, because the workflow runtime consumes that client rather than reimplementing a
transport. The three-tier store shape is proven in the sibling `jitML` checkpoint format
(`jitML/src/JitML/Checkpoint/Format.hs`) and the Failover-subscription worker path in the sibling `infernix`
ML-workflow runtime; those remain sibling context, while the Phase-37 evidence is an amoebius result. The
gate sealed the canonical store, terminal-Job protocol, two native Failover cycles, full three-class cleanup,
256 deterministic schedules, and all ten red mutants. Cross-cluster replication, the Phase-48 experiment-hash
derivation, and Pulsar consensus internals remain explicitly UNVERIFIED.

## Phase Summary

This phase delivers the durable-artifact and workflow core that every later ML-workflow phase consumes, in two
composed pieces on one substrate. First, the **three-tier content-addressed MinIO store** — write-once
self-naming `blobs/<sha256>` and canonical-CBOR `manifests/<sha256>` under `If-None-Match: *` (with `412
Precondition Failed` treated as success), and the only mutable objects, `pointers/*`, advanced by an
`If-Match` compare-and-swap that is the single atomic commit point — keyed under a caller-supplied
`experiment-hash` namespace within an app's Phase-34 ObjectStore bucket. Every namespace also binds a finite
`ObjectStoreDemand`: exact store/tenant/bucket/full-key resident identities, structural additional-retention
object extents, bounded concurrent write sets, bounded failed writes, a positive finite orphan-GC horizon,
required `StorageBudgetId`, and exclusive writer admission. Blob/manifest bytes uploaded before a failed pointer CAS stay
charged until an observed GC deletion; the logical peak consumes Phase 30's MinIO erasure/healing and uniform
claim-plan witness rather than assuming logical bytes equal physical disk. Second, an **orchestrator/worker workflow runtime** on top of the Phase-35 client: an orchestrator worker produces a workflow `command` on a
derived topic; worker daemons attached over a Pulsar **Failover** subscription have one active
consumer and the rest as name-ordered hot standbys; the active worker writes a content-addressed artifact and
produces an `event` carrying the manifest SHA the orchestrator fetches back by that SHA.

This phase also closes the Job-terminal live-proof boundary deliberately left open in Phase 26. Phase 26
builds and model-checks the closed success/failure completion state machine but has no MinIO or sole content
mutation gateway, so its live terminal Pod remains retained and charged. Here the already-provisioned
collector/verification Job is driven through the full live sequence: terminal outcome → exact
content-addressed `JobCompletion` write through the sole gateway → independent MinIO digest/outcome/revision
readback → cleanup deadline plus scheduler release partition → authenticated terminal-Pod cleanup. A failed or
ambiguous write retains the Pod and all modeled resident axes; an equal persisted completion yields
`CompletedJobNoOp` and cannot recreate the Job until a new execution revision.

The load-bearing property this phase proves live is that **standby takeover is delegated to Pulsar, not elected by amoebius**. Killing the active worker triggers the subscription's own ranked failover to the
name-ordered standby, with the Phase-35 at-least-once contract redelivering the un-acked command; the store's
ETag-CAS single atomic commit point plus the typed `AdvancePredicate` keep the mutable pointer race-free, and
content-addressed confluence makes the standby's re-fetch of the artifact by manifest SHA safe without any
distributed lock. There is no bespoke ranked-failover election, no signed-commit-log kernel, and no
warm-standby singleton: the workflow itself is deployed by the Deployment-`replicas=1` control-plane singleton
whose single-instance is a k8s/etcd property, and the workers are unelected. The scope deliberately consumes
the `experiment-hash` namespace as an opaque pinned string; `deriveExperimentHash`, the `ContentAddress`
typeclass, and SplitMix seed derivation are the Phase 48 determinism kernel, not this phase.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host, in
Register 3 (live infrastructure); no apple, linux-cuda, or windows substrate is touched, and the store's CAS
protocol and worker failover are substrate-agnostic in design but validated only here.

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `cabal test content-store-workflow-live` is green: the `round_trip_failover.dhall` topology passes
the round trip, critical-window failover, capacity drill, terminal-Job protocol, leak-free teardown, and
seeded mutants of [Gate integrity](#gate-integrity), on the linux-cpu kind cluster at Register 3.

## Gate integrity

The acceptance run is one `InForceSpec` test topology, and every claim it makes is read from something other
than the runtime under test. It is checked against the reviewed expectations and run-time references named in
Sprints 37.1 and 37.3, and MUST turn red on the mutants named there — among them the insertion-order-leaking
CBOR encoder and the ack-before-store-write worker.

- **Representative service set:** exactly the `round_trip_failover.dhall` topology's **one orchestrator +
  three workers** (one active, two name-ordered standbys) over the standing single-node Pulsar + MinIO.
  Nothing larger is in gate scope.
- **Store and fetch by manifest SHA:** a worker writes the artifact into the three-tier MinIO store and the
  orchestrator reads it back by the manifest SHA carried in the workflow `event`, so what crosses the wire is
  a content address rather than a payload.
- **The critical-window kill:** the active worker is killed **after its store write and before its `event`
  ack** — the same window Sprint 37.4 injects in simulation — and that placement (store-write-done,
  event-unacked) is recorded in the per-run ledger. A kill against an already-drained worker would exercise
  nothing.
- **Takeover delegated to Pulsar, read externally:** the **lexically next-in-name-order** standby takes over
  the Pulsar Failover subscription, with the promoted consumer's identity read from the Pulsar admin
  `subscription/{sub}/consumers` API rather than a self-emitted worker log, and the un-acked command
  redelivered at least once. Single-writer liveness is the subscription's, never a bespoke amoebius election.
- **The safety story asserted live:** the promoted standby re-fetches the artifact by manifest SHA, the
  resulting `pointers/latest` HEAD is **byte-identical to a fresh independent no-fault reference run**
  retained only in the run bundle, and an **external Pulsar consumer** observes the workflow command **exactly
  once**.
- **The failed-commit capacity drill:** a separate drill uploads the maximum blob/manifest write set and
  deliberately loses the pointer CAS. An external MinIO inventory proves those orphan bytes remain resident
  and debited before the positive finite GC horizon, an over-capacity follow-on write is refused with zero
  object mutation, and capacity is credited only after the GC horizon has elapsed **and** a fresh inventory
  observes deletion. The independent checker projects committed + concurrent + orphan logical extents through
  the Phase-30 per-drive erasure/healing and uniform-claim witness.
- **The first live Phase-26 terminal protocol:** the collector/verification Job's exact completion variant is
  gateway-written and independently read back before deadline/release-authorized Pod deletion; a forced
  gateway-write failure proves retention, and a rerun proves `CompletedJobNoOp`.
- **Leak-free teardown and an independent re-run:** the whole topology spins up, runs, and tears down
  leak-free — the postflight sweep inventories every resource class enumerated in Sprint 37.3 and fails hard
  on any non-empty remainder outside its explicitly named retained-by-design set — and **re-runs idempotently
  under a distinct `experiment-hash` namespace**, a cache-bypassing independent recompute rather than a
  content-addressed store-hit. Each run emits a per-run proven/tested/assumed ledger artifact.

## Resource provision — the four-Pod runtime plus gateway/collector envelope

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
inventory and MinIO physical fold before the collector Pod is created. The same sole gateway is the only
mutation route. Cleanup consumes a fresh external MinIO readback plus deadline and scheduler-release evidence;
neither a Job status condition nor a gateway acknowledgement alone is sufficient.

The committed boundary corpus makes each runnable source envelope, exact four-instance steady expansion,
gateway/collector, kind-indexed controller/rollout/failover
overlap, runtime-metadata shape/component/role/backing, topic cursor/backlog, object identity/count/size, concurrent/failure/orphan term, storage budget,
API-object revision/Event, and etcd term one unit short. Omission mutants dropping either standby, the gateway
or collector, the largest simultaneous runtime-metadata row, a role/domain/ownership/grouping witness, or pinned kubelet model, a failed CAS object, a declared pointer object, the `Content` producer arm, one desired API
object, the collector's `JobCompletion` identity/retention/failure extent, a churn operand, or the etcd model
refuse before any k8s/Pulsar/MinIO effect; exact-fit twins render
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

This phase is the first live amoebius realization of the content store and the delegated-single-writer workflow
runtime. Each bullet names the section it adopts; individual sprints cite the same sections where they build on
them.

- [`content_addressing_doctrine.md §2`](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  — *the three-tier store: blobs ← manifests ← pointers*: the three object classes and two write protocols
  ([`§2.1`](../documents/engineering/content_addressing_doctrine.md#21-three-object-classes-two-write-protocols) three classes / two protocols; [`§2.2`](../documents/engineering/content_addressing_doctrine.md#22-why-this-shape-removes-the-races) why the shape removes the write/write and write/read hazards), keyed under the
  [`§3 experimentHash`](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
  namespace consumed here as an opaque pinned prefix. The same [§2.1](../documents/engineering/content_addressing_doctrine.md#21-three-object-classes-two-write-protocols) capacity contract and
  [`resource_capacity_storage.md §5.1`](../documents/engineering/resource_capacity_storage.md#51-durable-demand-is-logical-first-physical-only-after-geometry)
  require committed residents + bounded in-flight writes + every failed-write orphan through the finite
  positive GC horizon to remain charged through MinIO's physical and uniform-claim witness.
- [`content_addressing_doctrine.md §5`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely)
  — *confluence*: content-addressed data is a join-semilattice, which is what makes the standby's re-fetch by
  manifest SHA and the at-least-once redelivery idempotent without a distributed lock.
- [`content_addressing_doctrine.md §6`](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
  — *the honest ceiling*: store bookkeeping totality (immutability + a commutative/associative/idempotent
  pointer join) is a proven-in-types argument; this phase validates the CAS protocol's runtime behaviour, and
  claims neither compute determinism nor cross-cluster replication.
- [`daemon_topology_doctrine.md §5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
  and [`§5.2`](../documents/engineering/daemon_topology_doctrine.md#52-the-coordination-plane-is-for-worker-events-and-audit-not-leadership)
  — *single-instance and coordination — delegated, not elected*: worker single-consumer semantics come from a
  Pulsar `Exclusive`/`Failover` subscription, never a bespoke election; Pulsar + MinIO are the workflow event
  stream and audit trail, not an election substrate.
- [`daemon_topology_doctrine.md §4`](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
  and [`§4.3`](../documents/engineering/daemon_topology_doctrine.md#43-the-feed-sourced-continuous-trainer-single-writer-delegated)
  — *worker daemons, N, unelected* / *single-writer delegated*: the orchestrator and workers are unelected
  worker daemons; liveness (at most one active per subscription) is the Pulsar subscription and safety
  (race-free `latest`) is the store's ETag-CAS commit point plus the typed `AdvancePredicate`.
- [`daemon_topology_doctrine.md §3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  — *exactly one pod is a k8s/etcd property*: the workflow is deployed by the Deployment-`replicas=1`
  control-plane singleton (Phase 33), whose single-instance is delegated to k8s/etcd, so nothing in this phase
  runs an election of any kind.
- [`pulsar_client_doctrine.md §5`](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek)
  and [`§7`](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default)
  — *the capability surface (the Failover subscription)* / *at-least-once with broker-side dedup*: the Phase-35
  subscription surface this phase consumes for standby takeover and the redelivery/dedup contract that keeps a
  retried produce or a redelivered consume idempotent.
- [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — *Register 2.5 — where deterministic simulation sits*: Sprint 37.4 runs the real Sprint-37.2/32.3 workflow
  runtime under `IOSimPOR` against the Phase-15 modeled environment as a Register-2.5 lower-register cross-check
  of the same leak-free-takeover / no-double-application properties the Register-3 live gate asserts.
- [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  (cross-reference) — *proven, tested, assumed*: each gate run emits a proven/tested/assumed ledger; skipping
  an applicable failover-injection move marks that layer UNVERIFIED, never green. The asynchronous
  **cross-cluster** failover boundary and its formal model are owned by
  [`§16`](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
  and realized by Phase 42's geo-replication plus Phase 43's gateway-migration drills, not here — this phase
  exercises the intra-cluster subscription only.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 37.1: Three-tier content-addressed MinIO store ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `amoebius-store/src/Amoebius/Store/ContentAddress.hs`,
`amoebius-store/src/Amoebius/Store/Manifest.hs`, `amoebius-store/src/Amoebius/Store/Pointer.hs`,
`amoebius-store/src/Amoebius/Store/ControlPlaneState.hs`, and
`amoebius-runtime/src/Amoebius/Execution/JobTerminalLive.hs` (built and validated)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: at Register 3 against the cluster's live MinIO, the write-once blob and canonical
manifest protocols, the single `pointers/latest` CAS commit point, the failed-commit capacity drill, and the
live `JobCompletion` write-and-readback each hold, while every direct-PUT or over-capacity route is refused.
The numbered `### Validation` list below carries the cases.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md` (§2),
`documents/engineering/resource_capacity_doctrine.md` (§5.1 — the content-store logical peak this sprint
provisions), `documents/engineering/storage_lifecycle_doctrine.md` (the retained-PV MinIO the bytes land
on), `DEVELOPMENT_PLAN/system_components.md`, this document.

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
  of Sprint 37.2.
- `pointers/*` (`latest`, `best/<metric>`, `trial/<id>/…`) — the only mutable objects; each body is a 32-byte
  manifest SHA, updated by `If-Match: <etag>` compare-and-swap as the single atomic commit point; the pure CAS
  decision (`PointerWritten` vs `PointerConflict`) and a typed `AdvancePredicate` resolve a lost CAS.
- A mandatory `ObjectStoreDemand` per namespace: exact physical-id-keyed committed residents, structural
  maximum additional retained extents/retention, maximum concurrent write sets, maximum object extents per
  set, maximum failed write sets per finite window, a positive finite orphan-GC horizon, the bucket's required
  `StorageBudgetId`, and `ObjectStoreMutationAdmission`. Provisioning returns the private resident +
  future/transient extent peak, merges it with all Phase-30 producer arms, and feeds that structure—not a byte
  scalar—into MinIO geometry. The sole gateway enforces object identity/count/size/concurrency/retention;
  direct S3 writes are denied, and observed orphan/multipart bytes remain resident until post-GC inventory.
- The demand enters the closed producer inventory only through its `Content` arm. The resource-bearing write
  gateway and collector/verification Job have complete Pod envelopes, and content concurrency includes the
  active/promoted-worker overlap; there is no free admission or GC process.
- The collector/verification Job consumes the Phase-26 terminal state machine live for the first time. Its
  success and `FailedBackoffExhausted` variants lower to the `JobCompletion` control-plane-state kind with an
  exact content-addressed key. The sole gateway writes it, a distinct read-only MinIO client verifies canonical
  bytes/digest/outcome/revision, and only fresh cleanup-deadline plus scheduler-release evidence authorizes
  deletion. Failed/unknown write outcome keeps the terminal UID and all retained axes charged; equal readback
  constructs `CompletedJobNoOp` and a changed execution revision is required to run again.
- Store keys taken under a caller-supplied `experiment-hash` namespace string within the app's ObjectStore
  bucket; this sprint does **not** build `deriveExperimentHash`, the `ContentAddress` typeclass, or SplitMix
  seed derivation (Phase 48 kernel work).
- **Independent canonicalization apparatus:** one reviewed logical manifest, the canonical-CBOR convention,
  and an independent canonicalizer generate the reference bytes and SHA under the run bundle. The tracked
  `.cbor` and `.sha256` copies are removed. A reviewed mutation definition emits the same logical manifest in
  non-sorted component order under `.build/test-corpora/`; its expected failure is a byte mismatch at the first
  component-ordering offset and a different key. Committed seeded mutant:
  `mutant/insertion-order-encoder` — an encoder that emits map/component bytes in insertion order rather than
  sorted order; the gate MUST turn this mutant **red** against the golden vector. The independently authored
  `amoebius-store/test/golden/write_budget_boundaries.csv` pins committed/concurrent/failed/horizon inputs and
  expected logical peaks, including one-byte-under/over and a pre-horizon resident orphan. The committed
  mutants `mutant/orphan-free-on-pointer-conflict` (credits failed PUTs immediately) and
  `mutant/orphan-budget-omitted` (drops the full-horizon failure term) MUST turn that corpus red.

### Validation
1. Run this suite at **Register 3** against the **single-node kind cluster's live MinIO** — the standing
   Phase-30 HA service on the Phase-28 retained PV, never an in-process or local S3 fake, so the evidential
   weight of every item below is unambiguous. Write the same blob twice through the gateway under
   `If-None-Match: *` and assert first-write success, second-write `412` treated as a no-op success.
2. Encode the same logical manifest from **two writers that each first construct it with a distinct component
   insertion order/permutation**, then compare both with fresh reference bytes and SHA produced by the
   independent canonicalizer under `.build/runs/phase_37/`. Assert the generated noncanonical case fails
   with a **byte mismatch at the first component-ordering offset** (not merely "differs"), and that the
   committed `mutant/insertion-order-encoder` turns this validation **red**.
3. Race two `pointers/latest` `If-Match` updates; assert one commits, the loser gets `412`, re-reads, and the
   typed advance predicate converges both to the same HEAD; assert a reader always observes a 32-byte SHA
   naming an immutable manifest, never a torn pointer body.
4. Run `write_budget_boundaries.csv`, then upload the maximum blob/manifest set and force its pointer CAS to
   lose. From an external MinIO inventory, assert the orphan is resident before the configured GC horizon and
   remains in residual capacity; a one-byte-over follow-on admission returns the specific capacity error with
   zero object mutation. After the horizon, run the collector but grant no capacity credit until a fresh
   inventory observes deletion. Assert `mutant/orphan-free-on-pointer-conflict` and
   `mutant/orphan-budget-omitted` each turns this validation red.
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
Remove the tracked canonical CBOR, SHA, and noncanonical CBOR copies. Retain or create the independently
reviewed logical input, independently review the write-budget table, generate reference/mutated bytes during
the run, and rerun the Phase-37 gate.

## Sprint 37.2: Orchestrator/worker workflow runtime + store/fetch by manifest SHA ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `amoebius-runtime/src/Amoebius/Workflow/Runtime.hs`,
`amoebius-runtime/src/Amoebius/Workflow/Orchestrator.hs`,
`amoebius-runtime/src/Amoebius/Workflow/Worker.hs`, and
`amoebius-runtime/src/Amoebius/Workflow/Resources.hs` (kind-indexed runnable sources and structural
runtime-metadata sources consumed by the shared capacity provisioner) (built and validated)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the orchestrator's `command` → artifact → `event` round trip returns the artifact
by its manifest SHA byte-for-byte, and a retried produce or a redelivered consume is observed once downstream
through the Phase-35 dedup. The numbered `### Validation` list below adds the no-election audit and the
one-short provision cases.
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md` (§4, §5),
`documents/engineering/content_addressing_doctrine.md` (§5), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`daemon_topology_doctrine.md §4 — worker daemons, N, unelected`](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
and [`content_addressing_doctrine.md §5 — confluence`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
wire the Phase-35 client, its topology algebra, and the Sprint-37.1 store into an orchestrator/worker runtime
whose command → artifact → event round-trip is idempotent by construction — the workers unelected, the
artifact reference a content address.

### Deliverables
- An orchestrator daemon that, using the Phase-35 topology algebra, produces a workflow `command` on the
  derived topic and consumes the corresponding `event`; it is an unelected worker daemon, not a leader.
- Worker daemons that consume the command, write a content-addressed artifact to the store (Sprint 37.1), and
  produce an `event` carrying the manifest SHA — CBOR payloads throughout (Phase 35), a large artifact carried
  by its manifest SHA reference and never inline.
- The orchestrator's fetch-by-manifest-SHA read path over the store, exercising [§5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely) confluence: re-fetching the
  same immutable manifest/blob is a no-op, which is exactly what the at-least-once contract needs.
- The runtime is scheduled under the Deployment-`replicas=1` singleton (Phase 33); no orchestrator/worker role
  runs a bespoke election, and the singleton's single-instance stays a k8s/etcd property.
- A `WorkflowRuntimeDemand` whose one orchestrator and three worker sources lower to identity-keyed symbolic
  Deployment-indexed `BoundExecutionUnit`s with complete envelopes, `ReplicaCardinality`,
  `DeploymentRolloutPolicy`, client buffers and artifact workspace, Pod slots, and bounded failover overlap.
  The collector lowers separately to a finite Job body. Provision derives the exact
  four-instance all-running standby epoch before any command is produced.

### Validation
1. Run the command → event round-trip and assert the artifact the worker wrote is fetched by the orchestrator
   by its manifest SHA and matches byte-for-byte.
2. Assert a retried produce and a redelivered consume are collapsed by the Phase-35 broker-side dedup so
   downstream idempotent state observes each exactly once.
3. Assert no orchestrator/worker code path performs a leadership election or holds cluster-wide authority, by a
   **two-part mechanism** (not code review): (a) a **static dependency/import audit** of the
   `amoebius-runtime` build plan asserting no leader-election or distributed-lock dependency is linked
   (no `etcd`/Raft lease client, no k8s `Lease`/`coordination.k8s.io` client, no ZooKeeper/consensus library)
   — the reference list of forbidden packages committed as a Phase-0 hand table; and (b) an **OS-boundary runtime trace** (`strace`/network capture at the pod boundary, not a self-emitted compliance log) over a full
   round-trip asserting zero calls to a k8s `Lease`/`coordination.k8s.io` endpoint or any external lock API.
   Committed seeded mutant (operator: added-effect): `mutant/lease-election` — a worker that acquires a k8s
   `Lease` before consuming; both checks MUST turn it **red**.
4. Run one-short fixtures for each orchestrator/worker CPU, memory, ephemeral, image/log, projected-file,
   Pulsar-buffer, artifact-workspace, Pod slot, Deployment rollout/failover term, runtime component role, and
   grouped layout backing. A mutant that drops either standby
   from the provision fold must reject before Pod creation or command production; live readback must contain
   exactly the four provisioned identities and envelopes.

### Remaining Work
None. Delivered and validated by the Phase-37 gate.

## Sprint 37.3: Pulsar Failover standby takeover + leak-free teardown (gate) ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `amoebius-runtime/dhall/test/round_trip_failover.dhall`,
`amoebius-runtime/test/live/FailoverSpec.hs`, `amoebius-runtime/src/Amoebius/Workflow/Resources.hs`, and
`tools/phase37_workflow_live.py` (built and validated)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the gate `InForceSpec` stores and fetches by manifest SHA, the critical-window
kill promotes the specific name-ordered standby read from the Pulsar admin API, the resulting HEAD matches a
fresh no-fault run, and the topology tears down leak-free and re-runs under a distinct `experiment-hash`
namespace. The numbered `### Validation` list below carries the assertions and mutants.
**Docs to update**:
`documents/engineering/pulsar_client_doctrine.md` (§5, §7),
`documents/engineering/daemon_topology_doctrine.md` (§5, §5.2),
`documents/engineering/chaos_failover_doctrine.md` (§12), `DEVELOPMENT_PLAN/README.md`.

### Objective
Adopt [`pulsar_client_doctrine.md §5 — the capability surface (the Failover subscription)`](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek),
[`§7 — at-least-once with broker-side dedup`](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default),
and [`daemon_topology_doctrine.md §5 / §5.2 — single-instance and coordination, delegated not elected`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected):
prove that killing the active worker yields standby takeover through Pulsar's own ranked failover — not a
bespoke amoebius election — and assemble the phase gate.

### Deliverables
- Worker daemons attached over a Pulsar **Failover** subscription (Phase 35): one active, the rest
  name-ordered hot standbys; single-writer liveness is the subscription, safety is the store's ETag-CAS commit
  point plus the typed `AdvancePredicate` (Sprint 37.1), so even a bounded failover overlap cannot regress
  HEAD.
- The **critical-window kill-injection path**: the kill lands **after the active worker has completed its store write and before it acks the `event`** (the same window Sprint 37.4 injects in simulation, restated for the
  live gate), so the load-bearing standby re-fetch + bounded failover overlap are actually exercised — not a kill
  against an idle, already-drained worker. Pulsar promotes the name-ordered standby, the Phase-35 at-least-once
  contract redelivers the un-acked command, and [§5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely) confluence makes the standby's re-fetch of the artifact by
  manifest SHA safe without a distributed lock. The window placement is asserted from broker/consumer state
  (the store object exists; the `event` message is still unacked) and recorded in the per-run ledger.
- The **postflight sweep's explicit inventory contract**: the sweep MUST inventory, and the ledger MUST record,
  every one of these resource classes: (i) k8s objects the topology applied, enumerated by the run's **field manager / ApplySet**; (ii) **Pulsar topics, subscriptions, consumers, and producers** created for the run;
  (iii) **MinIO objects under the run's `experiment-hash` prefix** outside a **named retained-by-design set**
  (the durable test-flagged bytes reclaimed by Phase 54). The sweep emits its **full inventory list and the named retained set** into the per-run ledger; **any non-empty remainder outside the retained set is a hard gate failure**. (Durable-byte reclaim staying with Phase 54 is the *only* exemption, and only for the
  explicitly named retained set — not a blanket class exemption.)
- **Reference and mutant apparatus:** execute the independent no-fault path during the run and retain its
  `pointers/latest` HEAD only beneath `.build/runs/phase_37/`; remove
  `amoebius-runtime/test/golden/head_nofault.bin`. Retain the promoted-consumer name table
  `amoebius-runtime/test/golden/failover_rank.txt` only after independent review. Committed seeded
  mutants the gate MUST turn **red** — `mutant/ack-before-store-write` (operator: effect reorder — worker acks
  the `event` before the store write completes, so a mid-window kill loses the command) and
  `mutant/sweep-skips-pulsar` (operator: invariant-clause delete — the sweep omits the Pulsar topic/subscription
  class and thus reports leak-free vacuously while topics leak).
- The gate `round_trip_failover.dhall` test topology — the named **representative service set: one orchestrator + three workers (one active, two name-ordered standbys)** over the standing Pulsar + MinIO — and its
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
   matched against the independently reviewed `failover_rank.txt`, so the assertion names the specific
   expected consumer and not merely "some standby") is promoted; (b) the un-acked command is redelivered with
   **none lost and none double-applied** — an **external Pulsar consumer** (OS-boundary, not the runtime) sees
   it **exactly once**; and (c) the resulting `pointers/latest` HEAD is byte-identical to the fresh no-fault
   reference retained in the run bundle. Assert the committed `mutant/ack-before-store-write` turns this
   validation **red** (a mid-window kill loses its command).
2. **Idempotency and leak-free teardown, disambiguated.** "**Idempotent setup**" means a *second `apply` of the
   topology against the still-standing topology is a byte-stable no-op* (the Phase-26 sense — zero fields
   diverge). "**Re-runs idempotently**" (the gate line) means a *second full spin-up → run → teardown cycle from
   clean state passes green*, and that second cycle runs under a **distinct `experiment-hash` namespace** so the
   store/fetch path is an **independent recompute, cache-bypassed** (never served from a content-addressed
   store-hit of the first run) with the compute path asserted to have executed. Assert leak-free teardown: the
   postflight sweep emits its **full inventory across all three enumerated classes** (ApplySet k8s objects;
   Pulsar topics/subscriptions/consumers/producers; MinIO objects under the run's `experiment-hash` prefix) plus
   the **named retained set** into the ledger, and **any non-empty remainder outside the retained set fails the gate**. Assert the committed `mutant/sweep-skips-pulsar` turns this validation **red** (leaked Pulsar topics
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
> and realized by Phase 42's geo-replication plus Phase 43's gateway-migration drills, not here. Pulsar's own
> broker/bookie consensus is delegated, not re-proven. The
> Failover-subscription worker shape is proven over WebSockets in the sibling `infernix` — sibling evidence,
> not an amoebius result; this sprint proves it over the native protocol for the first time. The eventual
> reclaim of test-flagged durable bytes is the elevated harness's prerogative (Phase 54), kept out of the
> normal teardown path.

### Remaining Work
Remove the tracked no-fault HEAD, generate the comparison run at gate time, independently review or replace
the failover-rank table, and rerun under universal artifact hygiene.

## Sprint 37.4: Register-2.5 workflow failover takeover under simulated fault ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `amoebius-runtime/test/sim/WorkflowFailoverSimSpec.hs` (the
`IOSimPOR` property harness), `amoebius-runtime/test/sim/WorkflowSimScenario.hs` (the injected
kill/redelivery/partition schedule), and the same `Amoebius.Workflow.Runtime` state transitions exercised by
the live suite (built and validated).
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the real `io-classes` workflow runtime, run under `IOSimPOR` against the modeled
fake Pulsar and MinIO with the gate's critical-window kill, redelivery, and partition faults injected, holds
leak-free takeover and no-double-application on every explored schedule. The numbered `### Validation` list
below carries the properties, mutants, and Register-2.5 ledger.
**Docs to update**:
`documents/engineering/deterministic_simulation_doctrine.md` (the Register-2.5 workflow failover simulation
entry), `documents/engineering/chaos_failover_doctrine.md` (§12 — the Register-2.5 ledger feeding the same
proven/tested/assumed ledger as the live gate), `DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`deterministic_simulation_doctrine.md §4 — Register 2.5 — where deterministic simulation sits`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits) at
**Register 2.5** on the **`none`** substrate: run the *real* Sprint-37.2/32.3 workflow runtime and its
Failover-takeover path — the daemon/workflow code written against `io-classes` — under `IOSimPOR` against the
Phase 15 Sprint 15.2 modeled fault-injectable environment, and assert the same load-bearing properties the Sprint 37.3
live gate asserts (leak-free standby takeover; no double-application), now **deterministically replayable** under
adversarial schedules instead of a single live wall-clock trace.

### Deliverables
- A `WorkflowFailoverSimSpec` that binds `Amoebius.Workflow.Runtime`/`Orchestrator`/`Worker` (Sprints 37.2–37.3)
  to the Phase 15 Sprint 15.2 `Amoebius.Sim.Env` substrate through `io-classes` and drives it under `IOSimPOR` — the
  production code path, not a simulation-only re-implementation.
- The injected fault schedule (`WorkflowSimScenario`): a `kill-worker-mid-workflow` inside the gate's critical
  window — after the store write and before the `event` ack — at-least-once **redelivery** of the un-acked
  command, and a broker/consumer
  **partition** — modeled by the fake Pulsar/MinIO of Phase 15 Sprint 15.2, not a live cluster.
- A property that, over *every* schedule `IOSimPOR` explores, asserts the Pulsar-Failover subscription takeover
  is **leak-free** (no orphaned consumer/producer/artifact handle survives the promotion) and that **no effect is double-applied** — content-addressed re-fetch is a no-op and log-fold dedup collapses the redelivery — so
  the committed pointer HEAD and downstream state are identical across all explored interleavings.
- A **Register-2.5 ledger** artifact per run, recording the explored-schedule count and the leak-free /
  no-double-application properties discharged, feeding the same proven/tested/assumed ledger
  ([`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed))
  as the Sprint-37.3 live gate.
- **Reviewed seeded mutants the sim MUST turn red:**
  `mutant/double-apply-on-redelivery` (operator: dropped dedup — the runtime applies the redelivered command a
  second time, so the pointer HEAD diverges on the fault-firing schedules) and
  `mutant/orphan-consumer-on-promotion` (operator: leaked effect — the old active worker's consumer handle
  survives the promotion), each of which some explored `IOSimPOR` schedule MUST falsify.

### Validation
1. Run `WorkflowFailoverSimSpec` under `IOSimPOR` and assert that, on every explored schedule with the
   `kill-worker-mid-workflow` fault, a name-ordered standby takes over the Failover subscription and the run is
   leak-free — no orphaned consumer, producer, or artifact handle outlives the promoted standby. Assert the
   committed `mutant/orphan-consumer-on-promotion` turns this validation red.
2. Assert **no double-application**: across all interleavings of redelivery and partition the content-addressed
   re-fetch is a no-op and the log-fold dedup collapses the redelivered command, so the pointer HEAD and
   downstream state are byte-identical whether or not the fault fired. Assert the committed
   `mutant/double-apply-on-redelivery` turns this validation red.
3. Assert the run emits a Register-2.5 ledger recording the explored-schedule count and the discharged
   properties, and that a failure replays deterministically from its seed and schedule.

> **Honesty.** This is a **Register 2.5** result on the **`none`** substrate: it tests the runtime's failover
> logic and dedup are correct under *every schedule the model explores*, not that the modeled fake Pulsar/MinIO
> match the live broker/bookie and object store. **Modeled-substrate fidelity is assumed** and is discharged
> only by this phase's **Register-3 live gate** (Sprint 37.3) on the linux-cpu kind cluster — the deterministic
> simulation is a fast, adversarial, replayable **lower-register cross-check**, never a substitute for it. The properties asserted
> here are exactly the ones the live gate asserts; the register is lower because the environment is modeled.

### Remaining Work
None. Delivered and validated by the Phase-37 gate.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/content_addressing_doctrine.md` — record that §2 (the three-tier store + the two write
  protocols) is realized in `amoebius-store`, namespaced under an opaque `experiment-hash` prefix, with the §3
  `experimentHash` derivation and seed kernel explicitly deferred to Phase 48; note §5 confluence is consumed
  (idempotent re-fetch/redelivery) but cross-cluster replication remains unexercised. Record the live
  failed-pointer-CAS drill: orphan bytes remain charged through the finite positive GC horizon and reclamation
  earns capacity only after an external inventory observes deletion.
- `documents/engineering/resource_capacity_doctrine.md` — record the content-store logical peak boundary
  corpus and its consumption of Phase 30's MinIO physical/uniform-claim witness.
- `documents/engineering/storage_lifecycle_doctrine.md` — record that the store's blob/manifest/pointer bytes
  land on the Phase-28 retained PV under the standing Phase-30 MinIO service, and that CAS-loser orphans stay
  charged through the finite positive GC horizon until an external inventory observes deletion.
- `documents/engineering/daemon_topology_doctrine.md` — record the orchestrator/worker scaffolding and that
  standby takeover is the §5/§5.2 delegated Pulsar `Exclusive`/`Failover` subscription, with no bespoke
  election anywhere in the runtime.
- `documents/engineering/pulsar_client_doctrine.md` — flip the §5 Failover-subscription and §7
  at-least-once/dedup sibling-evidence honesty notes to live-proof status once the gate runs (status itself
  stays in this plan).
- `documents/engineering/chaos_failover_doctrine.md` — record the §12 per-run proven/tested/assumed ledger for
  the intra-cluster failover injection, and that the §16 cross-cluster boundary stays deferred to Phase 42
  geo-replication plus Phase 43 gateway-migration drills.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the §4 Register-2.5 `IOSimPOR`
  cross-check that replays the failover-takeover leak-free / no-double-application properties over adversarial
  schedules, feeding the same proven/tested/assumed ledger as the live gate.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-37 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 37's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius-store` and `amoebius-runtime` packages and
  their target module paths, mapped to the owning content-addressing and daemon-topology doctrines, as
  Phase-37 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker; Phase 37 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (skeleton, sprint format, the doctrine-citation rule, the register + honesty + one-substrate disciplines)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no bespoke election; single-instance delegated to k8s/etcd; the content-addressed store)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — the
  three-tier store, the two write protocols, confluence, and the honest ceiling adopted here
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — unelected worker daemons
  and single-instance/coordination delegated to Pulsar and k8s/etcd, never a bespoke election
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the Phase-35 capability
  surface (the Failover subscription) and the at-least-once/dedup contract this phase consumes
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed
  ledger and the deferred cross-cluster (Second Axis) boundary
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the
  Register-2.5 `IOSimPOR`-over-modeled-environment lower-register cross-check that replays the failover-takeover
  properties under adversarial schedules
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live), the spin-up → run →
  always-tear-down contract, and the elevated harness as the sole deleter of test-flagged durable storage
- [phase_35](phase_35_pulsar_client.md) — the native Pulsar client this workflow runtime is built on
- [phase_48](phase_48_determinism_jitcache.md) — the `experimentHash` derivation + SplitMix seed kernel deferred
  from this phase's store namespace
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
