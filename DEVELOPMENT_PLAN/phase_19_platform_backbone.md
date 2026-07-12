# Phase 19: Platform backbone (MetalLB + MinIO + Pulsar HA)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_22_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_24_pulsar_client.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the platform backbone — MetalLB, MinIO, and Pulsar HA (brokers/bookies/offload) — on a
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
native-protocol event/workflow backbone (brokers, bookies, and size-triggered S3 offload). Each is rendered as
the byte-identical **HA topology even at `replicas=1`**, each emitted as typed Kubernetes objects by the
Phase-16 pure `render` (no Helm, no third-party charts, and the emitted manifests are generated from Haskell
and never committed), each served from binaries **baked into the multi-arch base image** with no
public-registry pull, and each on the Phase-17 `no-provisioner` retained PVs where it holds durable state.

Two deferred gaps from earlier phases close here. First, the **registry→MinIO S3-driver rehoming**: the
Phase-15 `distribution` registry ran against **interim node-local (filesystem-driver) blob storage** with the
MinIO S3 driver named as this phase's target; Phase 19 moves the registry's blob store onto MinIO via the S3
driver, so the registry holds no PV of its own and its bytes live in the object substrate. Second, the
**Pulsar size-triggered S3 offload**: a topic's hot tier (BookKeeper on retained PVs) is bounded by a size
high-water mark that offloads closed ledgers to MinIO, and this phase drills that the offload actually fires
under sustained ingest and that the hot tier never exceeds its cap.

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
(brokers + bookies + offload) — **comes up HA** (each is its HA topology even at `replicas=1`: MinIO in
distributed erasure-set mode, Pulsar multi-broker/multi-bookie) **from generated manifests + baked binaries**
(typed objects rendered by the Phase-16 `render`, images resolved only in-cluster with **no public-registry
pull**), with MinIO put/get and Pulsar produce/consume round-tripping and every container declaring explicit
CPU/RAM; **the registry→MinIO S3-driver rehoming lands here** — the `distribution` registry's blob store moves
off the interim node-local filesystem driver onto the MinIO S3 driver, closing the Phase-15 deferred gap and
verified by an external observer that the registry's pushed blobs materialize as objects in the MinIO bucket
(not on the node filesystem); **and a Pulsar size-triggered S3 offload drill** — producing past a topic's
hot-tier size bound, the offload fires and the hot tier never exceeds its cap, read from an external observer
on MinIO (offloaded ledger objects appear) and broker/BookKeeper metrics (hot-tier occupancy stays under the
high-water mark).

**Gate integrity (§M).** The gate is closed to a stub by five pinned cross-checks, all authored and committed
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
- **Render byte-identity (§M.3 independent provenance).** At gate time the pure `render` is re-run in-process
  and the SSA-applied object bytes under the `amoebius` field manager (`kubectl get ... -o yaml`, managedFields
  filtered) MUST be byte-identical to that fresh `render` output — pinning applied manifests to the Phase-16
  renderer, so hand-written or `helm template`-derived YAML embedded as string constants fails.
- **HA predicate (disambiguation).** "Its HA topology even at `replicas=1`" means the rendered manifest is
  **byte-identical modulo the replica-count field(s)** to the same service rendered at `replicas=n` (MinIO in
  distributed erasure-set mode, Pulsar multi-broker/multi-bookie) — asserted by a render-diff whose only
  tolerated difference is the replica count — NOT a standalone/single-drive or single-broker variant that
  merely avoids a bare Pod.
- **Registry rehoming (§M.3 independent oracle, §M.5 external observer, §M.2 committed mutant).** The
  registry's storage backend is asserted to be the MinIO S3 driver against the committed independent oracle
  `test/fixtures/phase19/registry-storage-driver.golden` (the expected `distribution` storage stanza — S3
  driver, MinIO endpoint, bucket — authored by hand, not read from the running config), and the rehoming is
  observed externally: a blob pushed to the registry materializes as an object in the MinIO bucket and the node
  filesystem path used by the interim driver stays empty. The committed seeded mutant
  **`mutant/registry-fs-driver`** — the `distribution` config left on the interim node-local filesystem driver
  — MUST turn this assertion red (the pushed blob never appears in MinIO).
- **Pulsar offload bound (§M.5 external observer, §M.2 committed mutant, §M.7 concrete drill).** The
  size-triggered offload is exercised, not merely configured: a named drill topic carries the hot-tier size
  cap committed in `test/fixtures/phase19/hot-tier-cap.golden`; sustained ingest past that cap MUST cause
  offloaded ledger objects to appear in MinIO (external observer on the object substrate) while BookKeeper/broker
  hot-tier occupancy (external observer on broker metrics, not an amoebius self-report) never exceeds the cap.
  The committed seeded mutant **`mutant/offload-time-only`** — a time-only offload policy with the size trigger
  removed — MUST turn this drill red (hot-tier occupancy exceeds the cap under the same ingest), since a
  time-only trigger cannot bound occupancy.

**Representative service set (§M.7).** The gate's "platform backbone" is exactly: MetalLB, MinIO (distributed),
and Pulsar (broker + bookie + size-triggered offload) — no more, no fewer. The registry (`distribution`, from
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
  and [`§2 — the typed manifest model (render is a pure total function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
  Phase 19 reuses the Phase-16 pure `render :: ServiceSpec -> [K8sObject]` and the SSA reconciler whose
  **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the backbone.
- [`platform_services_doctrine.md §10 — every container declares CPU and RAM`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram):
  every rendered container carries explicit CPU/RAM requests and limits — the per-container atom the capacity
  fold later reads.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each stateful backbone service (MinIO, Pulsar's bookies) lands its durable bytes on the Phase-17
  `no-provisioner` retained PVs, born only from a StatefulSet `volumeClaimTemplate`.
- [`testing_doctrine.md §2 — three registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate is a Register-3 live bring-up on linux-cpu, emitting a proven/tested/assumed ledger that
  names Register 3, marks the runtime layer *tested* (never *proven*), and marks the not-yet-built
  Keycloak-edge and singleton-owned reconcile layers UNVERIFIED.

## Sprints

## Sprint 19.1: MetalLB LoadBalancer + MinIO object substrate + registry S3-driver rehoming 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/LoadBalancer.hs`, `src/Amoebius/Platform/Minio.hs`, `src/Amoebius/Platform/Registry.hs` (target paths; not yet built)
**Blocked by**: Phase 16 (the typed `render` + SSA reconciler that applies these objects), Phase 17 (the retained PVs MinIO's StatefulSet binds), Phase 15 (the baked MetalLB/MinIO/`distribution` binaries in the in-cluster registry and the interim filesystem-driver blob store this rehomes)
**Independent Validation**: after apply, MetalLB advertises a LoadBalancer address on the linux-cpu node before any edge asks for one; MinIO runs as its HA (distributed) topology on identity-named retained PVs, never a bare Pod — "distributed" meaning the rendered StatefulSet is byte-identical modulo replica count to the `replicas=n` erasure-set topology, not a standalone single-drive variant; a put/get round-trips the same bytes; the `distribution` registry's blob store is rehomed onto the MinIO S3 driver, asserted against the committed `test/fixtures/phase19/registry-storage-driver.golden` oracle and observed externally — a blob pushed to the registry materializes as a MinIO object while the interim node-local filesystem path stays empty, and the committed `mutant/registry-fs-driver` (registry left on the filesystem driver) turns this red; **every container in every object `render` emits for MetalLB, MinIO, and the rehomed registry** (the CPU/RAM scope is exactly the amoebius-rendered objects, identified by `amoebius` field-manager ownership) declares CPU/RAM requests and limits; a deny-all egress test to `docker.io`/`quay.io` breaks no startup **and** the containerd/CRI image-pull event log on the kind node (the OS-boundary observer, §M.5) records no public-registry pull during the gate window.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/image_build_doctrine.md`

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
- The `distribution` registry's blob store rehomed onto the MinIO S3 driver — the registry holds no PV of its
  own, its bytes live in MinIO — asserted against the committed `test/fixtures/phase19/registry-storage-driver.golden`
  storage-stanza oracle, with the committed `mutant/registry-fs-driver` seeded mutant (registry left on the
  interim filesystem driver) named as the mutant this rehoming assertion MUST turn red.
- Explicit CPU/RAM requests+limits on every rendered container; images resolved only in-cluster.

### Validation
1. Apply through the Phase-16 reconciler; assert MetalLB advertises an address and MinIO reaches its Ready
   condition as a distributed StatefulSet on identity-named retained PVs.
2. Round-trip a MinIO put/get; assert the bytes are unchanged.
3. Assert the registry is serving from the MinIO S3 driver: its storage config is byte-equal to the committed
   `registry-storage-driver.golden` oracle (authored by hand, not read from the running config), a blob pushed
   to the registry materializes as an object in the MinIO bucket (external observer on MinIO), and the interim
   node-local filesystem path stays empty; the committed `mutant/registry-fs-driver` mutant turns this red.
4. Assert every container in the `render`-emitted MetalLB/MinIO/registry objects (scope = `amoebius`
   field-manager-owned objects only) declares CPU/RAM, and that the containerd/CRI image-pull event log on the
   kind node (§M.5 OS-boundary observer, not amoebius's own logging) records no public-registry pull and every
   running `imageID` digest resolves to the Phase-15 baked base digest in the in-cluster `distribution` catalog.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.2: Pulsar native-protocol backbone + size-triggered S3 offload drill 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Pulsar.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1 (MinIO backs Pulsar's size-triggered S3 offload), Phase 17 (retained bookie/broker storage), Phase 18 (Pulsar's credentials are Vault `SecretRef`s, resolved fail-closed)
**Independent Validation**: Pulsar comes up as an HA broker/bookie topology over its **native TCP binary protocol** (no WebSockets) on retained storage; a produce/consume round-trips at-least-once with broker-side dedup **exercised, not merely configured** — a duplicate/redelivery of the same producer-sequence message is injected and the consumer is asserted to receive it exactly once; the drill topic carries a bounded retention + a **size-triggered** MinIO offload whose high-water mark is the committed `test/fixtures/phase19/hot-tier-cap.golden` cap, and sustained ingest past that cap is drilled — offloaded ledger objects appear in MinIO (external observer) while BookKeeper/broker hot-tier occupancy (external observer on broker metrics) never exceeds the cap, with the committed `mutant/offload-time-only` (size trigger removed, time-only) asserted to breach the cap under the same ingest; every container declares CPU/RAM; a secret-dependent Pulsar component reaching a sealed Vault fails closed.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox)
and [`pulsar_client_doctrine.md §6.1 — topic storage lifecycle`](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows):
render and reconcile Pulsar as the cluster's HA native-protocol pub/sub backbone on retained bookie/broker
storage, delegating its intra-cluster HA consensus to its own brokers/bookies rather than re-proving it, and
drill that the mandatory size-triggered MinIO offload actually bounds the BookKeeper hot tier.

### Deliverables
- Pulsar (HA broker + bookie) rendered as typed objects on retained PVs, images baked, every container
  declaring CPU/RAM; the native TCP binary protocol only (the no-WebSockets invariant), with the client-side
  `amoebius-pulsar` protocol details owned by the Pulsar client doctrine and referenced, not re-specified.
- Bounded per-topic retention with a **size-triggered MinIO offload** (no unbounded storage, no time-only
  trigger), wired to the Sprint-19.1 MinIO substrate; the drill topic's hot-tier size cap committed in
  `test/fixtures/phase19/hot-tier-cap.golden`, with the committed `mutant/offload-time-only` seeded mutant
  named as the mutant the offload drill MUST turn red.
- A produce/consume round-trip demonstrating at-least-once delivery with broker-side dedup.

### Validation
1. Apply Pulsar through the reconciler; assert the broker/bookie set reaches Ready on retained storage as an
   HA topology (never a single bare broker).
2. Produce then consume a message; assert an at-least-once round-trip. Dedup is **exercised**: inject a
   duplicate (a redelivery of the same producer-sequence id) and assert the consumer observes exactly one
   delivery — not merely that broker-side dedup is enabled on the topic. Assert a CBOR payload round-trips
   byte-for-byte (full native-client proof deferred to Phase 24, marked UNVERIFIED here).
3. Drill the size-triggered offload: produce past the committed `hot-tier-cap.golden` size high-water mark on
   the drill topic and assert (a) offloaded ledger objects appear in the MinIO bucket (external observer on the
   object substrate) and (b) BookKeeper/broker hot-tier occupancy — read from broker metrics at the OS boundary,
   never an amoebius self-report — never exceeds the cap. Assert the committed `mutant/offload-time-only` mutant
   (size trigger removed) breaches the cap under the same ingest, since a time-only trigger cannot bound
   occupancy. Assert every container declares CPU/RAM.

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
  Postgres/observability (Phase 20), and singleton-owned reconcile layers UNVERIFIED.
- The gate oracles reused here, **authored and committed in Phase 0 before any implementation** (§M.1): the
  baked-base-image digest oracle `test/fixtures/phase19/expected-base-digest.txt`, the registry storage-stanza
  oracle `test/fixtures/phase19/registry-storage-driver.golden`, and the drill-topic hot-tier cap
  `test/fixtures/phase19/hot-tier-cap.golden`, with the committed seeded mutants `mutant/registry-fs-driver`
  and `mutant/offload-time-only` — committed and re-run, not run once.

### Validation
1. Bring the backbone up on a fresh cluster; assert MetalLB advertises an address, MinIO and Pulsar reach
   Ready as HA topologies, and the registry serves from the MinIO S3 driver — each dependent observed to start
   only on its dependency's observed-ready condition, with no timer standing in for a condition.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled backbone; assert the registry
   rehoming holds (a pushed blob is a MinIO object) and the size-triggered offload holds the hot tier under the
   committed cap; assert the committed mutants `mutant/registry-fs-driver` and `mutant/offload-time-only` each
   turn their assertion red.
3. Assert the whole backbone is up and HA-shaped from generated manifests + baked-binary images. "HA-shaped"
   is the render-diff predicate: each service's applied manifest is byte-identical **modulo the replica-count
   field(s)** to the same service rendered at `replicas=n` (MinIO erasure-set, Pulsar multi-broker/bookie), not
   a standalone/single-broker variant. **Manifest provenance (§M.3):** re-run the pure `render` in-process at
   gate time and assert the SSA-applied object bytes under the `amoebius` field manager are byte-identical to
   that output, foreclosing hand-written or `helm template`-derived YAML embedded as string constants. **Image
   provenance (§M.5):** "no public-registry pull recorded" is read from the containerd/CRI image-pull event log
   on the kind node (the OS-boundary observer, never amoebius's own logging) over the whole gate window,
   **and** every running container's `imageID` digest (`kubectl get pods -A -o jsonpath={..imageID}`) MUST
   equal the Phase-15 baked base digest committed in `test/fixtures/phase19/expected-base-digest.txt` and
   present in the in-cluster `distribution` catalog — any other digest or public-registry reference (including
   an upstream image pre-side-loaded onto the node with `kind load`) fails. Emit the Register-3 ledger, runtime
   layer *tested* not *proven*, with the Keycloak edge, Phase-20 Postgres/observability, and singleton-owned
   reconcile marked UNVERIFIED.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §2 HA-always and §4 MinIO
  notes flip from "design intent" to a Register-3-tested amoebius result on linux-cpu, and the §6 Pulsar
  honesty note gains its first live evidence (still *tested*, never *proven*).
- `documents/engineering/image_build_doctrine.md` — the §9 "registry stores its blobs in MinIO via the S3
  driver" edge is delivered; the Phase-15 interim filesystem-driver residue is discharged, recorded as the
  Phase-19 rehoming.
- `documents/engineering/pulsar_client_doctrine.md` — the §6.1 size-triggered offload bound gains its first
  live drill (the platform-side bring-up); the native-client CBOR round-trip proof stays owned by Phase 24.

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
