# Phase 18: Standard platform-service stack

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, legacy_tracking_for_deletion.md, overview.md, phase_14_base_image_registry.md, phase_16_retained_storage.md, phase_17_vault_pki.md, phase_20_live_dsl_singleton.md, phase_22_pulsar_client.md, system_components.md
**Generated sections**: none

> **Purpose**: Stand up the complete standard platform-service set — MetalLB, MinIO, Pulsar,
> Prometheus/Grafana, and the Percona-operator-managed per-service Patroni Postgres clusters with pgAdmin — on
> a single-node linux-cpu cluster, each as its HA chart from Haskell-generated manifests and baked-binary
> images, brought up in the derived readiness-DAG order by the Phase-15 reconciler's event-driven
> wait-for-ready.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 17 root-Vault/PKI
gate passes and runs on the **linux-cpu** substrate across **Register 3** (live infrastructure) — a
single-node `kind` cluster on a linux-cpu host, on top of the Phase-14 registry + baked base image, the
Phase-15 typed renderer + SSA reconciler, the Phase-16 no-provisioner retained storage, and the Phase-17
unsealed root Vault. The HA-chart, reconciled-manifest, and derived-DAG-ordering shapes are inherited as
**sibling evidence from prodbox**, not amoebius results; **Pulsar is new relative to prodbox** and is the
least evidence-backed service in the set. Status transitions are recorded reverse-chronologically here once
work begins.

## Phase Summary

This phase turns the storage-and-secrets-provisioned cluster of Phase 17 into a fully-stocked amoebius
cluster carrying the standard platform-service backbone. It renders and reconciles the L4 LoadBalancer
(MetalLB), the MinIO S3 object substrate, the Pulsar native-protocol event/workflow backbone, the
Prometheus/Grafana observability pair, and the Percona operator with its per-consumer Patroni Postgres
clusters and paired pgAdmin — each as the byte-identical **HA chart even at `replicas=1`**, each rendered as
typed Kubernetes objects by the Phase-15 pure `render` (no Helm, no third-party charts, and the emitted
manifests are generated from Haskell and never committed), each served from binaries **baked into the
multi-arch base image** with no public-registry pull, and each on the Phase-16 `no-provisioner` retained PVs
where it holds durable state. The whole set is assembled as one **derived readiness DAG** and brought up in
that order by the Phase-15 reconciler's **event-driven wait-for-ready** — a dependent starts on its
dependency's observed-ready edge, never on a timer.

The scope deliberately stops at *standing the backbone up HA in the right order and proving its data-plane
round-trips*. The registry (Phase 14) and the root Vault (Phase 17) are already up and are consumed here as
ordering dependencies, not re-delivered. The **Keycloak-owned ingress edge** — Envoy/Gateway API terminating
TLS and Keycloak owning all wild ingress so no workload publishes its own path — is [Phase 19](phase_19_keycloak_ingress.md);
this phase brings the backbone up behind no public edge, and observability's browser surfaces reach a user
only once that edge exists. The Deployment-`replicas=1` control-plane singleton that will eventually *own*
this reconcile loop is [Phase 20](phase_20_live_dsl_singleton.md) — single-instance delegated to k8s, no
bespoke election; here the reconciler is driven from the operator/host path against a fixed, hand-assembled
service set so the platform exists before the DSL and the singleton that will describe it.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 18.

**Register:** 3 — live infrastructure (§K); this is not a pure/golden or fake-tool check but a real bring-up
on a real cluster, emitting a proven/tested/assumed ledger that names Register 3.

**Gate:** on a single-node linux-cpu `kind` cluster the complete standard backbone — MetalLB, MinIO, Pulsar,
Prometheus/Grafana, and the Percona-operator-managed per-service Patroni Postgres clusters with pgAdmin —
**comes up HA** (each is its HA chart even at `replicas=1`; Postgres is a Patroni-via-Percona cluster, never a
bare Pod) **from generated manifests + baked binaries** (typed objects rendered by the Phase-15 `render`,
images resolved only in-cluster with **no public-registry pull**), **in the derived readiness-DAG order**
(§11 hard edges — LoadBalancer before the edge, Percona operator before any Postgres consumer, Vault
initialized-and-unsealed before secret-dependent startup — each a condition observed by the reconciler's
wait-for-ready, never an elapsed duration), with MinIO put/get and Pulsar produce/consume round-tripping and
every container declaring explicit CPU/RAM.

## Doctrine adopted

- [`platform_services_doctrine.md §1 — the invariant: every cluster is the same cluster`](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster)
  with [`§2 — HA always, including replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1):
  Phase 18 materializes the fixed standard service set on linux-cpu, each service the byte-identical HA chart
  a production cluster runs with only the replica count changed — no "dev topology," no hand-special-cased
  single-Pod variant.
- [`platform_services_doctrine.md §4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate),
  [`§6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox),
  [`§7 — Prometheus / Grafana, observability is not an add-on`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on),
  [`§8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin),
  and [`§9 — the LoadBalancer and the single wild-ingress path`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (the MetalLB LoadBalancer half — the Keycloak edge is Phase 19): the concrete providers Phase 18 stands up
  behind the platform capabilities.
- [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  as the **derived readiness DAG** of [`readiness_ordering_doctrine.md §4 — ordering is a derived readiness DAG`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
  and [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
  the hard ordering edges are derived from the declared dependency graph and enacted as observed-ready
  conditions, never a duration-gated or prose-ordered installer.
- [`manifest_generation_doctrine.md §5 — the apply/reconcile engine: server-side apply, owned field manager, prune, wait`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  and [`§2 — the typed manifest model (render is a pure total function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
  Phase 18 reuses the Phase-15 pure `render :: ServiceSpec -> [K8sObject]` and the SSA reconciler whose
  **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the set.
- [`image_build_doctrine.md §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster`](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  every standard-service binary is baked into the Phase-14 multi-arch base image and resolved only in-cluster;
  nothing in this bring-up pulls from a public registry. (The ML *engine payloads* are the deliberate
  jit-resolved exception and are out of scope here.)
- [`platform_services_doctrine.md §10 — every container declares CPU and RAM`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram):
  every rendered container carries explicit CPU/RAM requests and limits — the per-container atom the capacity
  fold later reads.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each stateful service (MinIO, Pulsar's bookies, the Patroni clusters) lands its durable bytes on the
  Phase-16 `no-provisioner` retained PVs, born only from a StatefulSet `volumeClaimTemplate`.
- [`monitoring_doctrine.md §3 — derivation and the operator read-model`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model):
  Prometheus scrapes platform workloads and the derived recording/alert rules and per-workflow dashboards are
  generated, never hand-authored — with the browser surfaces gated behind the (Phase 19) Keycloak edge under a
  mandatory `AccessScope` with no `Public` arm.
- [`testing_doctrine.md §2 — three registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate is a Register-3 live bring-up on linux-cpu, emitting a proven/tested/assumed ledger that
  names Register 3 and marks the not-yet-built Keycloak-edge and singleton-owned reconcile layers UNVERIFIED.

## Sprints

## Sprint 18.1: MetalLB LoadBalancer + MinIO object substrate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/LoadBalancer.hs`, `src/Amoebius/Platform/Minio.hs` (target paths; not yet built)
**Blocked by**: Phase 15 (the typed `render` + SSA reconciler that applies these objects), Phase 16 (the retained PVs MinIO's StatefulSet binds), Phase 14 (the baked MetalLB/MinIO binaries in the in-cluster registry)
**Independent Validation**: after apply, MetalLB advertises a LoadBalancer address on the linux-cpu node before any edge asks for one; MinIO runs as its HA (distributed) chart on identity-named retained PVs, never a bare Pod; a put/get round-trips the same bytes; every MetalLB and MinIO container declares CPU/RAM requests and limits; a deny-all egress test to `docker.io`/`quay.io` breaks no startup.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §9 — the LoadBalancer`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
(the MetalLB half) and [`§4 — MinIO, the object substrate`](../documents/engineering/platform_services_doctrine.md#4-minio--the-object-substrate):
render and reconcile MetalLB as the linux-cpu L4 entry point and MinIO as the HA S3 object substrate, both as
HA charts on baked binaries and retained storage — the two roots of the standard-service DAG.

### Deliverables
- MetalLB rendered as a standard service that publishes a LoadBalancer address on the kind node, available
  before the (Phase 19) Envoy/Gateway edge needs one — the DAG's LoadBalancer-before-edge root.
- MinIO (HA / distributed) as the S3 object substrate on Phase-16 retained PVs, holding the content store,
  the Pulumi backend, and app buckets (roles owned by their sibling doctrines; this phase only stands the
  service up); a put/get round-trips.
- Explicit CPU/RAM requests+limits on every rendered container; images resolved only in-cluster.

### Validation
1. Apply through the Phase-15 reconciler; assert MetalLB advertises an address and MinIO reaches its Ready
   condition as a distributed StatefulSet on identity-named retained PVs.
2. Round-trip a MinIO put/get; assert the bytes are unchanged.
3. Assert every container declares CPU/RAM and no image request left the cluster for a public registry.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.2: Pulsar native-protocol event/workflow backbone 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Pulsar.hs` (target paths; not yet built)
**Blocked by**: Sprint 18.1 (MinIO backs Pulsar's size-triggered S3 offload), Phase 16 (retained bookie/broker storage), Phase 17 (Pulsar's credentials are Vault `SecretRef`s, resolved fail-closed)
**Independent Validation**: Pulsar comes up as an HA broker/bookie chart over its **native TCP binary protocol** (no WebSockets) on retained storage; a produce/consume round-trips at-least-once with broker-side dedup; each topic carries a bounded retention + a size-triggered MinIO offload; every container declares CPU/RAM; a secret-dependent Pulsar component reaching a sealed Vault fails closed.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §6 — Pulsar, the event and workflow backbone (new vs prodbox)`](../documents/engineering/platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox):
render and reconcile Pulsar as the cluster's HA native-protocol pub/sub backbone on retained bookie/broker
storage, delegating its intra-cluster HA consensus to its own brokers/bookies rather than re-proving it.

### Deliverables
- Pulsar (HA broker + bookie) rendered as typed objects on retained PVs, images baked, every container
  declaring CPU/RAM; the native TCP binary protocol only (the no-WebSockets invariant), with the client-side
  `amoebius-pulsar` protocol details owned by the Pulsar client doctrine and referenced, not re-specified.
- Bounded per-topic retention with a **size-triggered MinIO offload** (no unbounded storage), wired to the
  Sprint-18.1 MinIO substrate.
- A produce/consume round-trip demonstrating at-least-once delivery with broker-side dedup.

### Validation
1. Apply Pulsar through the reconciler; assert the broker/bookie set reaches Ready on retained storage as an
   HA chart (never a single bare broker).
2. Produce then consume a message; assert an at-least-once round-trip with dedup, and that a CBOR payload
   round-trips byte-for-byte (full native-client proof deferred to Phase 22, marked UNVERIFIED here).
3. Assert bounded retention + size-triggered offload to MinIO is configured, and every container declares
   CPU/RAM.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.3: Percona/Patroni Postgres per consumer + pgAdmin + Prometheus/Grafana 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Postgres.hs`, `src/Amoebius/Platform/Observability.hs` (target paths; not yet built)
**Blocked by**: Phase 15 (reconciler), Phase 16 (retained PVs for the Patroni clusters and Prometheus), Phase 17 (each Patroni cluster's credentials are Vault secrets)
**Independent Validation**: the cluster-wide Percona operator reconciles a per-consumer `PerconaPGCluster` — each an HA Patroni cluster even at one replica, never a bare `postgres` Pod, each paired with its own pgAdmin; the operator is up before any Postgres consumer; Prometheus scrapes platform workloads and the derived rules/dashboards are generated, not hand-authored; every container declares CPU/RAM.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/monitoring_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin)
and [`§7 — Prometheus / Grafana`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)
with [`monitoring_doctrine.md §3 — derivation and the operator read-model`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model):
stand up the Percona operator as a cluster-wide platform component reconciling per-consumer Patroni clusters,
each with pgAdmin, and Prometheus/Grafana with derived rules and dashboards.

### Deliverables
- The Percona operator rendered as a cluster-wide platform component (from the shared inventory so it
  installs identically on every substrate), reconciling a per-consumer `PerconaPGCluster` — HA Patroni even at
  `replicas=1` — each paired with its own pgAdmin; the `distribution` registry takes **no** database (§3).
- Prometheus + Grafana scraping platform workloads, with the per-workflow recording/alert rules and
  dashboards **derived, never hand-authored**; the browser surfaces reach a user only through the (Phase 19)
  Keycloak edge under a mandatory `AccessScope` with no `Public` arm — deferred here, marked UNVERIFIED.
- Explicit CPU/RAM requests+limits on every rendered container; durable bytes on retained PVs.

### Validation
1. Assert the Percona operator is Ready before any `PerconaPGCluster`, then that a per-consumer cluster
   reconciles as an HA Patroni cluster (never a bare Pod) each paired with pgAdmin.
2. Assert Prometheus scrapes platform targets and the derived rules/dashboards are present and generated, not
   committed by hand.
3. Assert every platform pod declares CPU/RAM and each Patroni cluster's credentials resolve from Vault.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.4: The derived readiness-DAG bring-up + the HA-stack gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Services.hs`, `src/Amoebius/Platform/BringUp.hs` (target paths; not yet built)
**Blocked by**: Sprint 18.1, Sprint 18.2, Sprint 18.3, Phase 17 (the Vault-initialized-and-unsealed → secret-dependent-startup edge)
**Independent Validation**: the full standard backbone is assembled as one acyclic derived readiness DAG whose edges are the §11 hard edges; the reconciler brings the set up strictly in that order, each dependent starting on its dependency's observed-ready condition (never a `threadDelay`); no image request leaves the cluster for a public registry; the whole set is up, HA-shaped, and reachable in-cluster.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/readiness_ordering_doctrine.md`, `DEVELOPMENT_PLAN/README.md`

### Objective
Adopt [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
as the derived readiness DAG of [`readiness_ordering_doctrine.md §4`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
enacted by [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
assemble the Sprint 18.1–18.3 services into one derived DAG and bring them up event-driven in that order,
closing the phase with the full-stack HA gate.

### Deliverables
- A `BringUp` assembly that folds the standard-service set into an acyclic derived readiness DAG from the
  declared dependency graph (LoadBalancer → edge, Percona operator → Postgres consumers, Vault
  initialized-and-unsealed → secret-dependent startup), never a hand-sequenced script; the Vault-unsealed edge
  is the fail-closed condition of [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init).
- Live enactment by the Phase-15 reconciler's wait-for-ready — each dependent constructed to start on its
  dependency's observed-ready edge (a `runtime-checked` observation from the live object), never a duration;
  the singleton that will later own this loop is [Phase 20](phase_20_live_dsl_singleton.md) (Deployment
  `replicas=1`, no election).
- The phase-gate harness: bring the whole backbone up on a fresh single-node linux-cpu `kind` cluster and
  assert the complete set is up, HA-shaped, from generated (never-committed) manifests and baked binaries,
  with a proven/tested/assumed Register-3 ledger.

### Validation
1. Assert the bring-up honours the §11 DAG order — MetalLB address before the edge slot, Percona operator
   before its Patroni consumers, Vault-unsealed before secret-dependent startup — with each edge an observed
   condition and no timer standing in for a condition.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled stack; assert Postgres is a
   Patroni cluster, never a bare Pod.
3. Assert the whole standard backbone is up and HA-shaped from generated manifests + baked-binary images with
   **no public-registry pull recorded**, and emit the Register-3 ledger (Keycloak edge + singleton-owned
   reconcile marked UNVERIFIED).

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §13 planning-ownership
  pointer and the §8 "which standard services take a database" detail resolve to delivered Phase 18 sprints;
  the §2 HA-always and §6 Pulsar honesty notes flip from "design intent" to a Register-3-tested amoebius
  result on linux-cpu.
- `documents/engineering/readiness_ordering_doctrine.md` — the §11-derived-DAG bring-up gains its first live
  amoebius enactment; the §6 reconciler-observes-never-sleeps claim gains its first Register-3 evidence.
- `documents/engineering/monitoring_doctrine.md` — the §3 derived rules/dashboards are recorded as stood up
  (browser access still behind the Phase-19 edge, marked UNVERIFIED here).
- `documents/engineering/pulsar_client_doctrine.md` — the platform-side Pulsar bring-up is delivered; the
  native-client CBOR round-trip proof stays owned by Phase 22.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-18 status when the gate passes and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 18's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — reconcile the `src/Amoebius/Platform/*` target module paths named
  in each sprint against the component inventory once they become concrete.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the standard service set + §11 bring-up ordering adopted here
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — the derived readiness DAG the reconciler enacts
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the Phase-15 renderer + SSA wait-for-ready that applies and sequences the set
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base image, pull-only-in-cluster
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained PVs the stateful services land on
- [Monitoring Doctrine](../documents/engineering/monitoring_doctrine.md) — the derived observability surfaces
- [phase_17](phase_17_vault_pki.md) — the root Vault/PKI whose unseal edge gates secret-dependent startup here
- [phase_19](phase_19_keycloak_ingress.md) — the Keycloak-owned ingress edge that fronts this backbone next
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
