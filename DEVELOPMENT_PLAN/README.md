# Amoebius Development Plan

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: ../README.md, ../documents/documentation_standards.md, ../documents/engineering/README.md, ../documents/engineering/app_vs_deployment_doctrine.md, ../documents/engineering/chaos_failover_doctrine.md, ../documents/engineering/cluster_lifecycle_doctrine.md, ../documents/engineering/content_addressing_doctrine.md, ../documents/engineering/daemon_topology_doctrine.md, ../documents/engineering/dsl_doctrine.md, ../documents/engineering/host_cluster_comms_doctrine.md, ../documents/engineering/illegal_state_catalog.md, ../documents/engineering/image_build_doctrine.md, ../documents/engineering/manifest_generation_doctrine.md, ../documents/engineering/platform_services_doctrine.md, ../documents/engineering/pulsar_client_doctrine.md, ../documents/engineering/pulumi_iac_doctrine.md, ../documents/engineering/service_capability_doctrine.md, ../documents/engineering/storage_lifecycle_doctrine.md, ../documents/engineering/substrate_doctrine.md, ../documents/engineering/testing_doctrine.md, ../documents/engineering/tla_modelling_assumptions.md, ../documents/engineering/vault_pki_doctrine.md, development_plan_standards.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_00_documentation_suite.md, phase_01_bootstrap_kernel_kind.md, phase_02_platform_services_storage_vault.md, phase_03_dsl_control_plane_singleton.md, phase_04_pulsar_content_store_workflow.md, phase_05_determinism_infernix.md, phase_06_jitml_ha_coordinator.md, phase_07_host_compute_daemons.md, phase_08_mattandjames_app_logic.md, phase_09_multicluster_spawn_georeplication.md, phase_10_provider_clusters_provisioning.md, phase_11_test_topology_dsl.md, phase_12_spa_composition.md, substrates.md, system_components.md
**Generated sections**: none

> **Purpose**: The single, authoritative, numerically-ordered phased plan that delivers the whole amoebius
> vision. This is the live tracker for phase order, status, validation gates, and remaining work.

Amoebius is an **everything-orchestrator**: one Haskell binary running as a CLI, a sudo-capable host
daemon, and an in-cluster singleton service, whose **Dhall DSL makes illegal cluster state
unrepresentable**. This plan is the binding, executable decomposition of amoebius's grand,
non-binding vision.

The constituent projects are **not separate products** — they are libraries and behaviours unified under
the DSL: **prodbox** = the root single-node control-plane behaviour; **infernix** + **jitML** =
ML extension libraries; **hostbootstrap** = the bootstrap + DSL-`chain` core; **mattandjames** =
application logic only.

---

## Phase discipline

These rules are absolute and govern all work:

1. **Numeric order.** Phases are completed strictly in order. No work on phase *N+1* begins until phase
   *N* is validated.
2. **Independently validatable.** Each phase ends with a concrete acceptance gate (ideally an
   `amoebius.dhall` that spins up resources, runs a workflow, and tears down) that passes before the next
   phase opens.
3. **At most one substrate per validation.** A phase's acceptance gate requires **at most one** substrate
   (`apple` | `linux-cuda` | `linux-cpu` | `windows`). This prevents cross-substrate flip-flopping during
   development. The required substrate is named in each phase below.
4. **Phase 0 is the whole documentation suite.** The entire DSL is documented — comprehensively and
   explicitly — before any implementation phase begins. See [documents/engineering/README.md](../documents/engineering/README.md).
5. **Honest ledger.** Every validation emits a proven/tested/assumed ledger artifact; skipping an
   *applicable* test move marks that correctness layer UNVERIFIED, never green (see the chaos/failover
   doctrine).

This is a large body of work spanning many phases; that is expected.

---

## Cross-cutting invariants (documented in Phase 0; upheld by every phase)

- **No environment variables, ever — including `PATH`.** Host tools are discovered lazily via the
  substrate's package manager and invoked by full path.
- **Illegal/unsafe cluster state is unrepresentable in Dhall** — PVC↔PV binding, gateway, DNS, certs,
  taints/tolerations/affinity, NetworkPolicy, and insecure ingress cannot be expressed wrongly.
- **Resource demand never exceeds capacity.** A workload / VM / compute-engine whose summed cpu/mem/storage
  demand exceeds its host or cluster capacity is decode-rejected — a total fold over per-host/per-node
  declared `Capacity` (decode-foreclosed; the substrate detects the real number and refuses if smaller).
- **No unbounded storage, anywhere.** Storage is host-bounded or cloud-quota-bounded; an app (MinIO **and**
  Pulsar) cannot consume more than its backing; every Pulsar topic carries a bounded retention + a
  **size-triggered** S3 offload so the hot tier never overflows; "unbounded" is representable only behind a
  quota-capped `ScalingPolicy`.
- **The compute engine matches its substrate, and topology matches its hosts.** rke2/kind need a Linux host
  (a Lima/WSL2 VM on apple/windows); multi-node kind is a single host; multi-node rke2 is one Linux host per
  node; EKS is a first-class managed engine — while heterogeneous **multi-substrate clusters are allowed**.
- **Dynamic provisioning is amoebius-owned and typed.** Capacity grows only through a `ScalingPolicy`
  (capacity-based + instance price-shopping, quota-capped) — arbitrary logic, never a bare "unbounded."
- **Application logic and deployment rules are separate DSL surfaces.** An app is written once; HA
  replicas, chaos testing, geo-replication, and failover are an orthogonal deployment-rules layer.
- **Secrets never live in Dhall** — only names. Parents inject secrets into a child's Vault.
- **Standard platform services on every cluster** (below), **HA always** (replicas configurable; the chart
  is HA even at `replicas=1`).
- **Only `no-provisioner` retained PVs** (`<namespace>/<statefulset>/pv_<integer>`, sized,
  host/EBS-bound). Clusters are ephemeral; durable storage is not.
- **Containers always declare cpu/ram.**
- **Keycloak owns all wild ingress** via the LB + Gateway API; the sole exceptions are host-origin
  NodePorts (see the host↔cluster comms doctrine).
- **Pulsar payloads are exclusively CBOR** (canonical where content-addressed) — one message-body format via
  a typed codec; a non-CBOR application payload (JSON/base64/protobuf/raw) is unrepresentable. The protocol
  framing stays protobuf (Pulsar's wire).

## Standard platform services (every cluster, HA)

Registry (`distribution`, replaces Harbor) · MinIO · Vault · Pulsar · Prometheus/Grafana · Percona/Patroni
Postgres (per-service deployment + pgAdmin) · Envoy / Gateway API · Keycloak · MetalLB-or-cloud
LoadBalancer. Every third-party binary is **baked into the multi-arch base container** (no public-registry
pulls); the list above is the concrete providers behind the capabilities (see the service-capability +
manifest-generation doctrines).

## Toolchain

GHC **9.12.4**, Cabal 3.16.1.0, one shared pin across all packages. (GHC 9.14.1 is a
deferred, later-phase bump.)

---

## Document index

| Document | Purpose |
|----------|---------|
| [development_plan_standards.md](development_plan_standards.md) | The rulebook: file layout, status vocabulary, sprint format, the doctrine-citation rule, honesty + one-substrate disciplines. |
| [overview.md](overview.md) | Target architecture / vision / hard constraints / canonical gates — the "why/what" companion to this tracker. |
| [system_components.md](system_components.md) | Target component inventory: surface → owning doctrine → planned module path → building phase. |
| [substrates.md](substrates.md) | The substrate registry and the per-phase substrate map. |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | The migration-removal ledger (what the convergence retires, and when). |
| `phase_00_…` … `phase_12_…` | One substantive document per phase (linked in the Phase overview below). |
| [later_phases.md](later_phases.md) | The in-scope, high-numbered phases not yet given their own document. |

## Status vocabulary

✅ Done · 🔄 Active · 📋 Planned · ⏸️ Blocked · 🧪 Live-proof pending. Status lives **only** in this plan;
doctrine docs state the target shape and link back here. Full definitions in
[development_plan_standards.md §C](development_plan_standards.md). Pre-implementation, Phase 0 (this
documentation suite) is 🔄 **Active** and every later phase is 📋 **Planned**.

## Definition of Done (per phase)

A phase is ✅ Done only when its acceptance **Gate** has actually run on its substrate (the one-substrate
discipline) and emitted a green proven/tested/assumed ledger — never on "it compiles" (the honesty rule,
[development_plan_standards.md §K](development_plan_standards.md)).

## Phase overview

Each phase has its own document with the objective, the doctrine sections it adopts (cited by name), its
sprints, and its gate. *Substrate* is the single substrate the gate runs on.

| Phase | Name | Substrate | Gate (one line) | Status | Document |
|-------|------|-----------|-----------------|--------|----------|
| 0 | Documentation suite (whole DSL) | none | the documentation lint passes (headers, SSoT, no orphan links) | 🔄 Active | [phase_00](phase_00_documentation_suite.md) |
| 1 | Bootstrap + kernel + single kind cluster | linux-cpu | `amoebius bootstrap` brings up an empty cluster; re-run is a no-op | 📋 Planned | [phase_01](phase_01_bootstrap_kernel_kind.md) |
| 2 | Platform services + retained storage + root Vault/PKI | linux-cpu | all standard services up HA from generated manifests + baked binaries; ingress only via Keycloak; storage rebinds | 📋 Planned | [phase_02](phase_02_platform_services_storage_vault.md) |
| 3 | Orchestration Dhall DSL + control-plane singleton | linux-cpu | a `.dhall` deploys the platform + a trivial app; illegal `.dhall` files (bad PVC↔PV, open ingress, product-in-app-logic, overcommit, bad topology, unbounded storage, un-tiered topic) fail to type-check; a multi-substrate / managed-EKS `.dhall` decodes | 📋 Planned | [phase_03](phase_03_dsl_control_plane_singleton.md) |
| 4 | Native Pulsar client + content-addressed store + workflow-runtime | linux-cpu | round-trip a workflow over native Pulsar + store/fetch a content-addressed artifact; a worker fails over | 📋 Planned | [phase_04](phase_04_pulsar_content_store_workflow.md) |
| 5 | Determinism kernel + infernix migration | linux-cpu | an infernix CPU-inference workflow is reproducible (same `experimentHash` ⇒ same output) | 📋 Planned | [phase_05](phase_05_determinism_infernix.md) |
| 6 | jitML migration + HA coordinator | linux-cuda | a jitML run is bit-deterministic per its contract; the coordinator fails over | 📋 Planned | [phase_06](phase_06_jitml_ha_coordinator.md) |
| 7 | Host compute daemons (Apple Metal / Windows CUDA) | apple | an Apple-Silicon host daemon runs a Metal ML workload as a cluster Pulsar/MinIO peer | 📋 Planned | [phase_07](phase_07_host_compute_daemons.md) |
| 8 | mattandjames as application-logic-only | linux-cpu | mattandjames deploys from one app `.dhall` at a configurable replica count, inference via infernix | 📋 Planned | [phase_08](phase_08_mattandjames_app_logic.md) |
| 9 | Multi-cluster: amoebic spawning + geo-replication + failover | linux-cpu | two children geo-replicate; killing the lead triggers DNS failover within the loss budget; proofs green | 📋 Planned | [phase_09](phase_09_multicluster_spawn_georeplication.md) |
| 10 | Provider-managed clusters + dynamic provisioning | linux-cpu → provider | spin a provider cluster, dynamically provision a node, tear down leak-free | 📋 Planned | [phase_10](phase_10_provider_clusters_provisioning.md) |
| 11 | Test-topology DSL + suggest-test + storage-lifecycle safety | per generated test | a generated test `.dhall` runs a failover/election simulation and tears down leak-free | 📋 Planned | [phase_11](phase_11_test_topology_dsl.md) |
| 12 | SPA composition | linux-cpu | an SPA `.dhall` composes a multi-service app + an ML workflow, deployed and reachable | 📋 Planned | [phase_12](phase_12_spa_composition.md) |
| 13+ | Later phases | varies | each high-numbered in-scope phase gets its own gate when reached | 📋 Planned | [later_phases](later_phases.md) |

The detailed objective, sprint breakdown, doctrine adoptions, and gate for each phase live in that phase's
own document (linked above); this tracker holds only the one-line gate and status. The standing rules a
reader needs are in [development_plan_standards.md](development_plan_standards.md); the architecture and
constraints behind them are in [overview.md](overview.md).

---

## Cross-references
- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
