# Phase 19: Platform backbone (MetalLB + MinIO + Pulsar HA)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_22_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_24_pulsar_client.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the platform backbone — MetalLB, MinIO, and Pulsar HA
> (brokers/ZooKeeper/BookKeeper/offload) — on a
> single-node linux-cpu cluster, each as its HA topology from Haskell-generated manifests and baked-binary
> images, rehoming the `distribution` registry's blob store onto the MinIO S3 driver and proving a
> size-triggered Pulsar offload bounds the hot tier.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 18 root-Vault/PKI
gate passes and runs on the **linux-cpu** substrate across **Register 3** (live infrastructure) — a
single-node `kind` cluster on a linux-cpu host, on top of the Phase-15 registry + baked base image, the
Phase-16 typed renderer + SSA reconciler, the Phase-17 no-provisioner retained storage, and the Phase-18
unsealed root Vault. The HA-topology, reconciled-manifest, and baked-binary shapes are inherited as **sibling
evidence from prodbox**, not amoebius results; **Pulsar is new relative to prodbox** and is the least
evidence-backed service in the set. Status transitions are recorded reverse-chronologically here once work
begins.

## Phase Summary

This phase turns the storage-and-secrets-provisioned cluster of Phase 18 into an amoebius cluster carrying the
platform backbone: the L4 LoadBalancer (MetalLB), the MinIO S3 object substrate, and the Pulsar
native-protocol event/workflow backbone (brokers, ZooKeeper metadata members, BookKeeper bookies, and
size-triggered S3 offload). Each is rendered as
the byte-identical **HA topology even at `replicas=1`**, each emitted as typed Kubernetes objects by the
Phase-16 `renderAll` path (no Helm, no third-party charts, and the emitted manifests are generated from Haskell
and never committed), each served from binaries **baked into the multi-arch base image** with no
public-registry pull, and each on the Phase-17 `no-provisioner` retained PVs where it holds durable state.

Two deferred gaps from earlier phases close here. First, the **registry→MinIO S3-driver rehoming**: the
Phase-15 `distribution` registry ran against **interim node-local (filesystem-driver) blob storage** with the
MinIO S3 driver named as this phase's target; Phase 19 moves the registry's blob store onto MinIO via the S3
driver, so the registry holds no PV of its own and its bytes live in the object substrate. Second, the
**Pulsar size-triggered S3 offload**: a topic's hot tier (BookKeeper on retained PVs) is bounded by a size
high-water mark that offloads closed ledgers to MinIO, and this phase drills that the offload actually fires
under sustained ingest and that the hot tier never exceeds its cap.

The rehome is a verified migration, not a driver-only configuration edit, and it does not erase or replace the
registry's capacity proof. Phase 19 preserves the artifact/upload
operands from Phase 15's canonical `RegistryStorageDemand` — every digest-keyed compressed
layer/config/manifest extent, bounded model-derived concurrent-upload workspace, and finite failed-upload residue through
observed GC — while the replacement demand changes only its backend arm from the interim volume to MinIO. The resulting private
`ProvisionedRegistryStorageDemand` must carry the same logical `objectSet`, structured physical-object plus
upload/partial `objectStorePeak`, scalar interim `derivedPeak`, mutation-admission, and upload/orphan witness;
its backend projection is intentionally different. A private `ProvisionedRegistryBackendMigration` derives an
exact source-digest→target-object map, transfer/verification Job `PodResourceEnvelope`, workspace, and
source+target per-backing high-water. Only the structured target peak enters MinIO's per-object
erasure/healing geometry. Every pre-existing Phase-15 artifact is copied and independently digest-verified
before atomic driver cutover, then pulled by its old digest through the registry. Source filesystem residents
stay charged and readable until verification/cutover and remain charged with partial targets on failure; no
cleanup/reclamation is credited before it is observed. The target gets no speculative cross-backing dedup
credit.

The scope deliberately stops at *standing the backbone up HA and proving its data-plane round-trips, the
registry rehoming, and the offload bound*. The Percona-operator-managed per-consumer Patroni Postgres
clusters, pgAdmin, Prometheus/Grafana, and the **full derived readiness-DAG bring-up of the whole standard
stack** are [Phase 20](phase_20_platform_services_2.md). The **Keycloak-owned ingress edge** — Envoy/Gateway
API terminating TLS and Keycloak owning all wild ingress so no workload publishes its own path — is
[Phase 21](phase_21_keycloak_ingress.md); this phase brings the backbone up behind no public edge. The
Deployment-`replicas=1` control-plane singleton that will eventually *own* this reconcile loop is
[Phase 22](phase_22_live_dsl_singleton.md); here the reconciler is driven from the operator/host path against a
fixed, hand-assembled service set so the backbone exists before the DSL and the singleton that will describe
it.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 19.

**Register:** 3 — live infrastructure (§K); this is not a pure/golden or fake-tool check but a real bring-up
on a real cluster, emitting a proven/tested/assumed ledger that names Register 3 and marks the runtime layer
*tested*, never *proven*.

**Gate:** on a single-node linux-cpu `kind` cluster the platform backbone — MetalLB, MinIO, and Pulsar
(brokers + ZooKeeper metadata + BookKeeper bookies + offload) — **comes up HA** (each is its HA topology even
at `replicas=1`: MinIO in distributed erasure-set mode, Pulsar multi-broker/multi-ZooKeeper/multi-bookie)
**from generated manifests + baked binaries**
(typed objects rendered by the Phase-16 `renderAll`, images resolved only in-cluster with **no public-registry
pull**), with MinIO put/get and Pulsar produce/consume round-tripping and every app, init, and sidecar
container carrying the **exact complete provision derived in its `ProvisionedServiceSpec`** — CPU, memory, and
ephemeral-storage requests/limits; bounded pod-local volumes; exact durable claim/backing/presentation,
required-usable bytes, and rounded raw capacities; and explicit
cache `None` plus accelerator `None` on linux-cpu. BookKeeper's logical hot demand is expanded through
write-quorum/recovery geometry into a per-bookie physical witness, and MinIO's committed + in-flight +
failed-write-orphan peak is expanded through erasure/healing geometry into per-drive required usable bytes,
then filesystem overhead and backing minimum/quantum produce private raw allocations before each StatefulSet
claim-template group is rounded to its maximum `provisionedBytes` and debited uniformly;
**the registry→MinIO S3-driver rehoming lands here** — the
`distribution` registry's blob store moves
off the interim node-local filesystem driver onto the MinIO S3 driver, closing the Phase-15 deferred gap and
verified by an external observer that the registry's pushed blobs materialize as objects in the MinIO bucket
(not on the node filesystem). The MinIO-bound private `ProvisionedRegistryStorageDemand` preserves Phase 15's
logical `objectSet`, structured `objectStorePeak`, scalar interim `derivedPeak`, mutation admission, and
upload/orphan witness while changing the backend projection:
observed-resident/new objects are unioned by digest,
configs and manifests are counted as well as compressed layers, conflicting sizes reject, concurrent-upload
workspace/partial uploads remain structured extents until observed GC. The whole MinIO fold enumerates the
closed six-arm app/content/registry/Pulsar-offload/Pulumi-checkpoint/control-plane-state producer type and
requires exact equality for the sources present in this deployment, with every `StorageBudgetId`/owner and
writer admission retained. Its sole object-write gateway has a complete provisioned pod envelope. Pulsar also
constructs an independent ZooKeeper metadata-store provision—exact znode/session/watch/transaction demand,
member pods, retained transaction-log/snapshot volumes, and failure recovery overlap—before any broker can
start. Finally, a **Pulsar
size-triggered S3 offload drill** — producing past a topic's
hot-tier size bound, the offload fires and the hot tier never exceeds its cap, read from an external observer
on MinIO (offloaded ledger objects appear) and broker/BookKeeper metrics (hot-tier occupancy stays under the
high-water mark).

**Gate integrity (§M).** The gate is closed to a stub by seven pinned cross-checks, all authored and committed
in **Phase 0** before any `src/Amoebius/Platform/*` implementation exists (§M.1 oracle-pinning), and named as
gate oracles in the Sprint 19.1–19.3 Deliverables:

- **Image-identity provenance (§M.5 OS-boundary observer).** "No public-registry pull" is not a self-emitted
  claim: every running container's `imageID` digest (`kubectl get pods -A -o jsonpath={..imageID}` over the
  amoebius-rendered namespaces) MUST equal the Phase-15 baked base-image digest resolved from the in-cluster
  `distribution` registry catalog; any digest not in that catalog, or any `docker.io`/`quay.io`/other
  public-registry image reference, fails the gate. This discriminates a genuine baked-binary bring-up from
  upstream images side-loaded onto the node (which `kind load` and a deny-all egress test cannot tell apart —
  only image identity can). The pull-observation window is the containerd/CRI image-pull event log on the kind
  node read from the OS boundary (not amoebius's own logging), covering the whole gate window; a committed
  fixture-oracle `test/fixtures/phase19/expected-base-digest.txt` pins the accepted digest.
- **Render byte-identity (§M.3 independent provenance).** At gate time the pure `renderAll` is re-run in-process
  and the SSA-applied object bytes under the `amoebius` field manager (`kubectl get ... -o yaml`, managedFields
  filtered) MUST be byte-identical to that fresh `renderAll` output — pinning applied manifests to the Phase-16
  renderer, so hand-written or `helm template`-derived YAML embedded as string constants fails.
- **Exact resource-provision identity (§M.3 independent projection).** For every amoebius-owned app, init, and
  sidecar container, the applied CPU/memory/ephemeral-storage requests and limits are byte-for-byte the
  projection of the opaque `ProvisionedServiceSpec`; every disk-backed `emptyDir` has a `sizeLimit` covered by
  that ephemeral-storage ceiling (a kubelet measurement/eviction boundary, not a synchronous quota); every
  cache owner also enforces its private admission bound, and every PVC/PV presentation and rounded size equals
  its uniform durable claim
  plan and the retained
  aggregate witness; and these linux-cpu services carry cache `None` and accelerator `None` with no device
  extended-resource claim. The checker independently recomputes the effective pod reservation/ceiling from
  the concurrent app/sidecar sum, ordinary sequential-init maxima, restartable init-sidecars accumulated
  according to their lifecycle, and pod/runtime overhead, then matches the provisioned placement witness.
  Merely declaring a subset of built-in resource fields does not pass.
- **Physical-storage geometry and write-peak identity (§M.3 independent projection, §M.2 committed mutants).**
  An independent checker recomputes BookKeeper's per-bookie steady/re-replication maximum from its
  ensemble/write/ack quorums and finite bookie-fault policy, and MinIO's per-drive steady/healing maximum from
  logical object extents, stripe padding, data/parity shards, replacement drives, and finite drive-fault
  policy. It also reconstructs the closed six-arm app/content/registry/Pulsar-offload/Pulumi-checkpoint/
  control-plane-state source type, covers every arm in the capacity corpus, and requires the present source set
  to equal the producer set with exactly one resolved `StorageBudgetId`/owner and writer
  admission each, unions exact store/tenant/bucket/full-key resident identities, and retains all structural
  future/concurrent/deletion-lag/failed-orphan extents. The fault
  scenarios are the complete subsets derived from the policies, never caller-selected lists. The checked
  usable maps must equal the opaque geometry witnesses; then the checker applies each slot's
  `VolumePresentation` and backing allocation policy, groups compatible claim slots by StatefulSet template,
  recomputes `provisionedBytes = max rounded ordinal allocation`, and proves every rendered PVC/PV equals that
  uniform raw size, exposes at least the maximum required usable bytes, and debits
  `provisionedBytes × ordinalCount`. A fitting logical total, pre-presentation/unequal raw-map sum, or
  cluster-wide disk average does not pass. The committed mutants
  **`mutant/storage-logical-as-physical`**, **`mutant/storage-drop-required-fault-scenario`**,
  **`mutant/storage-sum-unequal-ordinals`**, and **`mutant/content-store-immediate-gc`** MUST each turn the
  boundary corpus red.
- **HA predicate (disambiguation).** "Its HA topology even at `replicas=1`" means the rendered manifest is
  **byte-identical modulo the replica-count field(s)** to the same service rendered at `replicas=n` (MinIO in
  distributed erasure-set mode, Pulsar multi-broker/multi-ZooKeeper/multi-bookie) — asserted by a render-diff whose only
  tolerated difference is the replica count — NOT a standalone/single-drive or single-broker variant that
  merely avoids a bare Pod.
- **Registry rehoming (§M.3 independent oracle, §M.5 external observer, §M.2 committed mutant).** The
  registry's storage backend is asserted to be the MinIO S3 driver against the committed independent oracle
  `test/fixtures/phase19/registry-storage-driver.golden` (the expected `distribution` storage stanza — S3
  driver, MinIO endpoint, bucket — authored by hand, not read from the running config), and the rehoming is
  observed externally: every digest in a Phase-15 preexisting artifact is copied to its exact target object,
  independently verified, and remains pullable by the same digest after cutover; a newly pushed blob
  materializes only in the MinIO bucket. The source path remains charged/readable through verification and is
  reclaimed only after observed successful cleanup. The committed seeded mutant
  **`mutant/registry-fs-driver`** — the `distribution` config left on the interim node-local filesystem driver
  — MUST turn this assertion red (the pushed blob never appears in MinIO). The checker also requires every
  artifact/upload operand in `RegistryStorageDemand` and the private `objectSet`, `derivedPeak`, and
  upload/orphan witness to match Phase 15. It also independently derives the private
  `ProvisionedRegistryBackendMigration` source→target map, transfer/verify Job, workspace, and
  old+new per-backing high-water; only after verification does the active backend arm change from the interim
  volume to MinIO. It
  may not replace the digest map
  with a tag count or total. Resident/new digest overlap debits once within the target, a same-digest size
  conflict rejects, model-derived upload workspace and pre-GC partial residue overlap the stored union, and a target backing
  one byte under the resulting physical witness, a one-unit-short transfer executor, or an injected digest
  verification failure rejects before cutover. The failure keeps the source route and all old/partial-new
  commitments.
- **Pulsar offload bound (§M.5 external observer, §M.2 committed mutant, §M.7 concrete drill).** The
  size-triggered offload is exercised, not merely configured: a named drill topic carries the hot-tier size
  cap committed in `test/fixtures/phase19/hot-tier-cap.golden`; sustained ingest past that cap MUST cause
  offloaded ledger objects to appear in MinIO (external observer on the object substrate) while BookKeeper/broker
  hot-tier occupancy (external observer on broker metrics, not an amoebius self-report) never exceeds the cap.
  The committed seeded mutant **`mutant/offload-time-only`** — a time-only offload policy with the size trigger
  removed — MUST turn this drill red (hot-tier occupancy exceeds the cap under the same ingest), since a
  time-only trigger cannot bound occupancy.

**Representative service set (§M.7).** The gate's "platform backbone" is exactly: MetalLB, MinIO (distributed),
and Pulsar (broker + ZooKeeper metadata member + BookKeeper bookie + size-triggered offload) — no more, no
fewer. The registry (`distribution`, from
Phase 15) is present as a rehoming consumer of MinIO, not re-delivered here.

## Doctrine adopted

- [`platform_services_doctrine.md §1 — the invariant: every cluster is the same cluster`](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster)
  with [`§2 — HA always, including replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1):
  Phase 19 materializes the backbone slice of the fixed standard service set on linux-cpu, each service the
  byte-identical HA topology a production cluster runs with only the replica count changed — no "dev topology,"
  no hand-special-cased single-Pod variant.
- [`platform_services_doctrine.md §4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate),
  [`§6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox),
  and [`§9 — the LoadBalancer and the single wild-ingress path`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (the MetalLB LoadBalancer half — the Keycloak edge is Phase 21): the concrete providers Phase 19 stands up
  behind the platform backbone.
- [`pulsar_client_doctrine.md §6.1 — topic storage lifecycle: bounded, tiered, retained, and the hot tier never overflows`](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows):
  the mandatory *size-triggered* S3 offload high-water mark on the BookKeeper hot tier — the load-bearing
  difference from a time-only trigger — is the invariant the offload drill exercises against the live cluster.
- [`image_build_doctrine.md §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster`](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster)
  and [`§9 — bring-up ordering: the registry chicken-and-egg dissolves`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
  every backbone binary is baked into the Phase-15 multi-arch base image and resolved only in-cluster; the
  registry stores its blobs in MinIO via the S3 driver, so MinIO must be serving before the registry — the
  thin ordering edge §9 names, and the rehoming Phase 19 delivers.
- [`manifest_generation_doctrine.md §5 — the apply/reconcile engine: server-side apply, owned field manager, prune, wait`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  and [`§2 — the typed manifest model (`renderAll` is the sole public pure function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
  Phase 19 reuses the Phase-16 pure `renderAll :: ProvisionedSpec -> [K8sObject]` and typed-action reconciler whose
  **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the backbone.
- [`platform_services_doctrine.md §10 — every execution unit declares its complete resource envelope`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)
  and [`resource_capacity_doctrine.md §3.1`](../documents/engineering/resource_capacity_doctrine.md#31-the-systematic-provision-matrix) / [`§5.1`](../documents/engineering/resource_capacity_doctrine.md#51-durable-demand-is-logical-first-physical-only-after-geometry):
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
  witness are unchanged from Phase 15 — including compressed objects,
  configs/manifests, model-derived concurrent-upload workspace, and retained failed-upload extents — before that physical
  fold; it is not recounted from tags or a scalar blob allowance. The rehome additionally provisions the
  digest-complete old→new copy/verify transition and its Job/workspace before cutover.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each stateful backbone service (MinIO, Pulsar's ZooKeeper members and bookies) lands its durable bytes on the Phase-17
  `no-provisioner` retained PVs, born only from a StatefulSet `volumeClaimTemplate`.
- [`testing_doctrine.md §2 — three registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate is a Register-3 live bring-up on linux-cpu, emitting a proven/tested/assumed ledger that
  names Register 3, marks the runtime layer *tested* (never *proven*), and marks the not-yet-built
  Keycloak-edge and singleton-owned reconcile layers UNVERIFIED.

## Sprints

## Sprint 19.1: MetalLB LoadBalancer + MinIO object substrate + registry S3-driver rehoming 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/LoadBalancer.hs`, `src/Amoebius/Platform/Minio.hs`, `src/Amoebius/Platform/Registry.hs` (target paths; not yet built)
**Blocked by**: Phase 16 (the typed `renderAll` + SSA reconciler that applies these objects), Phase 17 (the retained PVs MinIO's StatefulSet binds), Phase 15 (the baked MetalLB/MinIO/`distribution` binaries in the in-cluster registry and the interim filesystem-driver blob store this rehomes)
**Independent Validation**: after apply, MetalLB advertises a LoadBalancer address on the linux-cpu node before any edge asks for one; MinIO runs as its HA (distributed) topology on identity-named retained PVs, never a bare Pod — "distributed" meaning the rendered StatefulSet is byte-identical modulo replica count to the `replicas=n` erasure-set topology, not a standalone single-drive variant; a put/get round-trips the same bytes; the `distribution` registry's blob store is rehomed onto the MinIO S3 driver, asserted against the committed `test/fixtures/phase19/registry-storage-driver.golden` oracle and observed externally — every pre-existing Phase-15 artifact is copied and digest-verified, remains pullable after cutover, and a post-cutover blob materializes in MinIO without changing the old filesystem; the committed `mutant/registry-fs-driver` (registry left on the filesystem driver) turns this red; **every app/init/sidecar container, gateway, migration Job, and volume in every object `renderAll` emits for MetalLB, MinIO, and the rehomed registry** (scope exactly the amoebius field-manager-owned objects) carries resource fields exactly equal to its `ProvisionedServiceSpec`: CPU/memory/ephemeral-storage requests+limits, bounded pod-local volumes, durable presentation/required-usable/rounded capacities, cache `None`, and accelerator `None`; the independent storage checker derives every fault-policy-required healing case, charges committed + concurrent + finite-horizon orphan extents through erasure geometry, applies presentation/allocation rounding before uniformity, and rejects usable-byte or raw-quantum boundary failures before apply; a deny-all egress test to `docker.io`/`quay.io` breaks no startup **and** the containerd/CRI image-pull event log on the kind node (the OS-boundary observer, §M.5) records no public-registry pull during the gate window.
Rehome admission preserves every Phase-15 artifact/upload operand and the private logical `objectSet`,
structured `objectStorePeak`, scalar interim `derivedPeak`, mutation admission, and upload/orphan witness,
making MinIO the replacement `RegistryStorageDemand.backend` rather than
inventing a fresh
aggregate: the independent checker unions observed and
new compressed layers/configs/manifests by digest, rejects conflicting sizes, derives bounded concurrent
workspace and partial-upload object extents through finite GC, feeds that structured peak into MinIO geometry,
and rejects a one-byte-under target with zero reconcile and zero publish requests.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`,
`documents/engineering/image_build_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §9 — the LoadBalancer`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
(the MetalLB half), [`§4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate),
and [`image_build_doctrine.md §9 — bring-up ordering`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
render and reconcile MetalLB as the linux-cpu L4 entry point and MinIO as the HA S3 object substrate, then
rehome the Phase-15 `distribution` registry's blob store off the interim node-local filesystem driver onto the
MinIO S3 driver — closing the Phase-15 deferred gap.

### Deliverables
- MetalLB rendered as a standard service that publishes a LoadBalancer address on the kind node, available
  before the (Phase 21) Envoy/Gateway edge needs one — the backbone's LoadBalancer root.
- MinIO (HA / distributed) as the S3 object substrate on Phase-17 retained PVs, holding the content store,
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
- The `distribution` registry's blob store rehomed onto the MinIO S3 driver — the registry holds no PV of its
  own, its bytes live in MinIO — asserted against the committed `test/fixtures/phase19/registry-storage-driver.golden`
  storage-stanza oracle, with the committed `mutant/registry-fs-driver` seeded mutant (registry left on the
  interim filesystem driver) named as the mutant this rehoming assertion MUST turn red. The logical tenant
  extent supplied to MinIO is a private `ProvisionedRegistryStorageDemand` whose logical
  `objectSet`, structured `objectStorePeak`, scalar interim `derivedPeak`, mutation admission, and upload/orphan
  witness exactly match Phase 15's interim provision and whose
  backend arm is MinIO. It is
  derived from canonical `RegistryStoredArtifact`/`RegistryStorageDemand`; the rehome cannot author a
  replacement byte total, omit configs/manifests or failed-upload residue, or claim deletion before the
  observer sees it.
- A `RegistryBackendMigrationDemand` from the still-live Phase-15 private provision to the MinIO replacement.
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
1. Apply through the Phase-16 reconciler; assert MetalLB advertises an address and MinIO reaches its Ready
   condition as a distributed StatefulSet on identity-named retained PVs.
2. Round-trip an admitted object-gateway put/get; assert the bytes are unchanged, and assert the same writer
   cannot issue a direct MinIO PUT.
3. Assert the registry is serving from the MinIO S3 driver: its storage config is byte-equal to the committed
   `registry-storage-driver.golden` oracle (authored by hand, not read from the running config), every object of
   a pre-existing Phase-15 artifact was copied/verified and that artifact still pulls by the same digest, and a
   new blob pushed after cutover materializes in MinIO without changing the old filesystem. The committed
   `mutant/registry-fs-driver` mutant turns this red.
   Compare the Phase-15 and Phase-19 private registry witnesses: `objectSet`, structured `objectStorePeak`,
   scalar interim `derivedPeak`, admission, and the upload/orphan witness must match in the replacement while
   its backend differs; then independently validate the additional migration witness and derive the MinIO
   physical demand from that logical tenant. Independently compare the exact source→target object map and
   source+target+workspace high-water, and assert the live transfer Job equals its complete provisioned
   envelope. Exercise resident/new digest dedup, conflicting stored
   bytes for one digest, maximum upload concurrency/model-derived workspace, partial-upload residue just before GC, and a
   retained target one byte under the physical result, old+new backing one byte short, transfer executor one
   unit short, and an injected verify mismatch. Capacity failures yield zero writes; verify failure leaves the
   source route live and both source/partial-target charged; exact fit verifies then cuts over.
4. Run the independent MinIO capacity corpus. Cover all six closed arms and require source↔producer equality
   for the present deployment; reject a dropped arm (including control-plane state), writer admission, storage
   budget, or mismatched owner. For the same logical byte
   total, vary full physical object identities/counts and prove per-object stripe padding changes demand; the
   same digest under two namespaces remains two objects, while one identical full id deduplicates and
   conflicting sizes reject. Vary data/parity geometry,
  stripe boundary, healing fault bound, concurrent-write bound, failed-write rate, and orphan-GC horizon;
   recompute every required unavailable-drive subset, the required cross-set Cartesian products, and each
   per-drive steady/healing peak independently. Include
   exact-fit and one-byte-over usable cases, a one-quantum-under raw allocation, a
   logical-fit/erasure-physical-overflow case, an existing orphan just before its horizon, Pulsar
   segment-rate×deletion-lag and failed-offload horizon boundaries, Pulumi exact-state-field/encryption
   old+new-revision and failed-checkpoint horizon boundaries, control-plane-state old/new CAS plus failed-write
   horizon boundaries, and a deliberately
   skewed per-ordinal map where the pre-presentation sum fits but
   `max(provisionedBytes) × ordinalCount` does not. Direct S3 writes are denied while each in-envelope writer
   capability succeeds through the gateway. Also make producer storage fit while the gateway pod is one CPU,
   memory, ephemeral byte, or pod slot short; it must reject before any S3 write. Require zero storage/API
   writes for every rejection and require
   `mutant/storage-logical-as-physical`, `mutant/storage-drop-required-fault-scenario`,
   `mutant/storage-sum-unequal-ordinals`, and `mutant/content-store-immediate-gc` each to turn red.
5. Assert every app/init/sidecar container and volume in the `renderAll`-emitted MetalLB/MinIO/registry objects
   (scope = `amoebius` field-manager-owned objects only) is an **exact** projection of its
   `ProvisionedServiceSpec`: CPU/memory/ephemeral-storage requests+limits, each disk-backed
   `emptyDir.sizeLimit`, each PVC/PV's uniform presentation/rounded capacity and usable witness, cache `None`,
   and accelerator `None`/absence of a device claim.
   Recompute the effective pod request/limit using app sums, largest-init semantics, and pod overhead, and
   require equality with the stored placement witness. Then assert
   the containerd/CRI image-pull event log on the kind node (§M.5 OS-boundary observer, not amoebius's own
   logging) records no public-registry pull and every running `imageID` digest resolves to the Phase-15 baked
   base digest in the in-cluster `distribution` catalog.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.2: Pulsar native-protocol backbone + size-triggered S3 offload drill 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Pulsar.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1 (MinIO backs Pulsar's size-triggered S3 offload), Phase 17 (retained bookie/broker storage), Phase 18 (Pulsar's credentials are Vault `SecretRef`s, resolved fail-closed)
**Independent Validation**: Pulsar comes up as an HA broker/ZooKeeper/BookKeeper topology over its **native TCP binary protocol** (no WebSockets) on retained storage; a produce/consume round-trips at-least-once with broker-side dedup **exercised, not merely configured** — a duplicate/redelivery of the same producer-sequence message is injected and the consumer is asserted to receive it exactly once; the drill topic carries a bounded retention + a **size-triggered** MinIO offload whose high-water mark is the committed `test/fixtures/phase19/hot-tier-cap.golden` cap, and sustained ingest past that cap is drilled — offloaded ledger objects appear in MinIO (external observer) while BookKeeper/broker hot-tier occupancy (external observer on broker metrics) never exceeds the cap, with the committed `mutant/offload-time-only` (size trigger removed, time-only) asserted to breach the cap under the same ingest; the independent checker expands ZooKeeper's exact znode/session/watch/transaction demand into member log/snapshot/recovery peaks and BookKeeper logical hot bytes through write-quorum recovery, rounding every physical ordinal to the uniform claim-template debit, with logical-fit/physical-overflow and one-byte-over cases rejected before apply; every app/init/sidecar and volume exactly matches its complete provisioned envelope; a secret-dependent Pulsar component reaching a sealed Vault fails closed.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

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
  trigger), wired to the Sprint-19.1 MinIO substrate; the drill topic's hot-tier size cap committed in
  `test/fixtures/phase19/hot-tier-cap.golden`, with the committed `mutant/offload-time-only` seeded mutant
  named as the mutant the offload drill MUST turn red.
- A produce/consume round-trip demonstrating at-least-once delivery with broker-side dedup.

### Validation
1. Apply Pulsar through the reconciler; assert the ZooKeeper metadata ensemble reaches Ready first and the
   broker/bookie set then reaches Ready on retained storage as an HA topology (never a single bare broker).
2. Produce then consume a message; assert an at-least-once round-trip. Dedup is **exercised**: inject a
   duplicate (a redelivery of the same producer-sequence id) and assert the consumer observes exactly one
   delivery — not merely that broker-side dedup is enabled on the topic. Assert a CBOR payload round-trips
   byte-for-byte (full native-client proof deferred to Phase 24, marked UNVERIFIED here).
3. Drill the size-triggered offload: produce past the committed `hot-tier-cap.golden` size high-water mark on
   the drill topic and assert (a) offloaded ledger objects appear in the MinIO bucket (external observer on the
   object substrate) and (b) BookKeeper/broker hot-tier occupancy — read from broker metrics at the OS boundary,
   never an amoebius self-report — never exceeds the cap. Assert the committed `mutant/offload-time-only` mutant
   (size trigger removed) breaches the cap under the same ingest, since a time-only trigger cannot bound
   occupancy.
4. Run the independent BookKeeper capacity corpus across unequal quorum choices, segment-boundary rounding,
   journal/index reserve, and each complete failure-subset family derived from the declared fault bound.
   Include exact-fit and one-byte-over per-bookie cases, a logical-hot-total fit whose write-quorum physical
   demand fails, a recovery-only overflow, a filesystem-overhead/one-quantum overflow, and a skewed ordinal
   placement whose unequal pre-presentation sum fits but the uniform
   `max(provisionedBytes) × ordinalCount` plan fails. Every rejection performs zero storage/API writes;
   `mutant/storage-logical-as-physical`, `mutant/storage-drop-required-fault-scenario`, and
   `mutant/storage-sum-unequal-ordinals` each turns red.
   Run the independent ZooKeeper corpus across znode payloads, transaction/session/watch bounds, retained
   logs/snapshots, and every failure-recovery case. A topology where brokers, bookies, and offload all fit but
   one ZooKeeper member CPU/memory/ephemeral/PVC/backing is one unit/byte short must reject before any Pulsar
   object is applied. Mutants dropping the metadata store, a znode class, or recovery overlap go red.
5. Assert every app/init/sidecar container and volume is an exact projection of its
   `ProvisionedServiceSpec` across CPU, memory, ephemeral storage, durable presentation/usable/raw storage,
   cache `None`, and accelerator `None`; every BookKeeper PVC/PV capacity equals the recomputed uniform rounded
   plan and each mounted fsType/usable capacity matches its witness, not an ordinal-specific raw demand.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.3: The backbone HA bring-up gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Backbone.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1, Sprint 19.2, Phase 18 (the Vault-initialized-and-unsealed → secret-dependent-startup edge Pulsar depends on)
**Independent Validation**: the backbone — MetalLB, MinIO (with the rehomed registry), and Pulsar — is brought up on a fresh single-node linux-cpu `kind` cluster and the whole set is up, HA-shaped, and reachable in-cluster, with MinIO put/get and Pulsar produce/consume round-tripping, the registry serving from the MinIO S3 driver, the size-triggered offload holding the hot tier under its cap, no image request leaving the cluster for a public registry, and a Register-3 proven/tested/assumed ledger emitted. The thin MinIO→registry and Vault-unsealed→Pulsar edges are enacted by the reconciler's wait-for-ready as observed conditions, never timers; the *full* derived readiness-DAG bring-up of the whole standard stack (with the §11 hard edges and the `mutant/dag-drop-edge` mutant) is [Phase 20](phase_20_platform_services_2.md).
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/image_build_doctrine.md`, `DEVELOPMENT_PLAN/README.md`

### Objective
Adopt [`manifest_generation_doctrine.md §5 — the apply/reconcile engine`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
and [`image_build_doctrine.md §9 — bring-up ordering`](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
assemble the Sprint 19.1–19.2 backbone services, bring them up event-driven behind the reconciler's
wait-for-ready with the MinIO-before-registry and Vault-unsealed-before-Pulsar edges as observed conditions,
and close the phase with the backbone HA gate on a fresh cluster.

### Deliverables
- A backbone bring-up that applies MetalLB, MinIO, the rehomed `distribution` registry, and Pulsar through the
  Phase-16 reconciler, each dependent starting on its dependency's observed-ready edge (MinIO serving before
  the registry's S3-driver blob store; Vault initialized-and-unsealed before Pulsar's secret-dependent startup —
  the fail-closed condition of [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init)),
  never a `threadDelay`.
- The phase-gate harness: bring the whole backbone up on a fresh single-node linux-cpu `kind` cluster and
  assert the set is up, HA-shaped, from generated (never-committed) manifests and baked binaries, with a
  proven/tested/assumed Register-3 ledger that marks the runtime layer *tested* and the Keycloak-edge,
  Postgres/observability (Phase 20), and singleton-owned reconcile layers UNVERIFIED; the independent
  resource-projection checker compares every applied execution unit/volume exactly to its
  `ProvisionedServiceSpec`.
- The gate oracles reused here, **authored and committed in Phase 0 before any implementation** (§M.1): the
  baked-base-image digest oracle `test/fixtures/phase19/expected-base-digest.txt`, the registry storage-stanza
  oracle `test/fixtures/phase19/registry-storage-driver.golden`, and the drill-topic hot-tier cap
  `test/fixtures/phase19/hot-tier-cap.golden`, plus the independently computed
  `test/fixtures/phase19/storage-geometry-boundaries.csv` covering BookKeeper/MinIO exact-fit, one-byte-over,
  recovery/healing, orphan horizon, and uniform-ordinal rounding. The gate also reuses
  `test/fixtures/phase15/registry_storage_demand.dhall` unchanged and pins the expected mapping from its private
  registry logical witness into the MinIO physical geometry. The committed seeded mutants
  `mutant/registry-fs-driver`, `mutant/offload-time-only`, `mutant/storage-logical-as-physical`,
  `mutant/storage-drop-required-fault-scenario`, `mutant/storage-sum-unequal-ordinals`, and
  `mutant/content-store-immediate-gc` are committed and re-run, not run once.

### Validation
1. Bring the backbone up on a fresh cluster; assert MetalLB advertises an address, MinIO and Pulsar reach
   Ready as HA topologies, and the registry serves from the MinIO S3 driver — each dependent observed to start
   only on its dependency's observed-ready condition, with no timer standing in for a condition.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled backbone; assert the registry
   rehoming holds (a pushed blob is a MinIO object) and the size-triggered offload holds the hot tier under the
   committed cap; assert the committed mutants `mutant/registry-fs-driver` and `mutant/offload-time-only` each
   turn their assertion red.
3. Recompute `storage-geometry-boundaries.csv` with the independent checker and compare it with the opaque
   storage provision. Assert every BookKeeper recovery and MinIO healing subset required by its finite fault
   policy is present; every logical extent has its replication/erasure/metadata/workspace amplification; the
   content peak includes concurrent and full-horizon failed writes; the registry tenant's private
   replacement `objectSet`, `derivedPeak`, and upload/orphan witness exactly match Phase 15 while its backend
   is MinIO, and the separate source→target migration witness is complete, including
   manifest/config extents, bounded model-derived upload workspace, and pre-GC partial residue; and each
   StatefulSet template's PVC/PV presentation/rounded size and retained-backing debit equal
   `max(provisionedBytes) × ordinalCount`. Re-run all four storage mutants named in the
   deliverable and require each to turn red before any apply path receives a token.
4. Assert the whole backbone is up and HA-shaped from generated manifests + baked-binary images. "HA-shaped"
   is the render-diff predicate: each service's applied manifest is byte-identical **modulo the replica-count
   field(s)** to the same service rendered at `replicas=n` (MinIO erasure-set, Pulsar
   multi-broker/ZooKeeper/bookie), not
   a standalone/single-broker variant. **Manifest provenance (§M.3):** re-run the pure `renderAll` in-process at
   gate time and assert the SSA-applied object bytes under the `amoebius` field manager are byte-identical to
   that output, foreclosing hand-written or `helm template`-derived YAML embedded as string constants. **Image
   provenance (§M.5):** "no public-registry pull recorded" is read from the containerd/CRI image-pull event log
   on the kind node (the OS-boundary observer, never amoebius's own logging) over the whole gate window,
   **and** every running container's `imageID` digest (`kubectl get pods -A -o jsonpath={..imageID}`) MUST
   equal the Phase-15 baked base digest committed in `test/fixtures/phase19/expected-base-digest.txt` and
   present in the in-cluster `distribution` catalog — any other digest or public-registry reference (including
   an upstream image pre-side-loaded onto the node with `kind load`) fails. **Resource-provision identity:**
   independently compare every applied app/init/sidecar CPU/memory/ephemeral-storage request+limit, bounded
   `emptyDir`, uniform-template PVC/PV capacity, cache-`None`, and accelerator-`None` projection to the opaque
   `ProvisionedServiceSpec`; recompute each effective pod envelope including ordinary and restartable-init
   sidecar semantics plus overhead; and
   require exact equality, not field presence. Emit the Register-3 ledger, runtime
   layer *tested* not *proven*, with the Keycloak edge, Phase-20 Postgres/observability, and singleton-owned
   reconcile marked UNVERIFIED.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §2 HA-always and §4 MinIO
  notes flip from "design intent" to a Register-3-tested amoebius result on linux-cpu, and the §6 Pulsar
  honesty note gains its first live evidence (still *tested*, never *proven*).
- `documents/engineering/image_build_doctrine.md` — the §9 "registry stores its blobs in MinIO via the S3
  driver" edge is delivered; the Phase-15 interim filesystem-driver residue is discharged, recorded as the
  Phase-19 rehoming.
- `documents/engineering/pulsar_client_doctrine.md` — the §6.1 size-triggered offload bound gains its first
  live drill (the platform-side bring-up); the native-client CBOR round-trip proof stays owned by Phase 24.
- `documents/engineering/resource_capacity_doctrine.md` — record the standard-backbone live assertion that
  every Kubernetes resource/volume field is the exact projection of its checked `ProvisionedServiceSpec`,
  including the logical→physical BookKeeper/MinIO folds and uniform StatefulSet claim-plan debit.
- `documents/engineering/content_addressing_doctrine.md` — record that committed residents, bounded concurrent
  writes, and failed-write orphans through the finite positive GC horizon all remain in MinIO's capacity peak;
  GC creates credit only after observed deletion.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-19 status when the gate passes and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 19's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — reconcile the `src/Amoebius/Platform/*` target module paths named
  in each sprint against the component inventory once they become concrete.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the standard service set (MetalLB/MinIO/Pulsar backbone) adopted here
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the §6.1 size-triggered offload lifecycle the drill exercises
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the Phase-16 renderer + SSA wait-for-ready that applies and sequences the backbone
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base image, pull-only-in-cluster, and the registry→MinIO S3-driver edge
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained PVs the stateful backbone services land on
- [phase_15](phase_15_base_image_registry.md) — the base image + `distribution` registry whose interim filesystem-driver blob store this phase rehomes onto MinIO
- [phase_18](phase_18_vault_pki.md) — the root Vault/PKI whose unseal edge gates Pulsar's secret-dependent startup here
- [phase_20](phase_20_platform_services_2.md) — the Percona/Patroni + pgAdmin + observability services and the full derived readiness-DAG gate that build on this backbone
- [phase_21](phase_21_keycloak_ingress.md) — the Keycloak-owned ingress edge that fronts this backbone next
- [phase_24](phase_24_pulsar_client.md) — the native `amoebius-pulsar` client whose full CBOR round-trip proof this phase defers
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
