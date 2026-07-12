# Amoebius Development Plan

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_12_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_14_midwife_bootstrap_kind.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_21_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_22_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_23_app_tenancy.md, DEVELOPMENT_PLAN/phase_24_pulsar_client.md, DEVELOPMENT_PLAN/phase_25_content_store_workflow.md, DEVELOPMENT_PLAN/phase_26_release_lifecycle.md, DEVELOPMENT_PLAN/phase_27_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_28_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_29_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_30_provider_clusters.md, DEVELOPMENT_PLAN/phase_31_determinism_kernel.md, DEVELOPMENT_PLAN/phase_32_jitbuild_engine_cache.md, DEVELOPMENT_PLAN/phase_33_infernix_lift.md, DEVELOPMENT_PLAN/phase_34_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_35_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_36_test_topology_dsl.md, DEVELOPMENT_PLAN/phase_37_spa_live_deploy.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: The single, authoritative, numerically-ordered phased plan that delivers the whole amoebius
> vision. This is the live tracker for phase order, status, validation gates, and remaining work.

Amoebius is an **everything-orchestrator**: one Haskell binary running as a CLI, a sudo-capable host
daemon, and an in-cluster singleton service, whose **Dhall DSL makes illegal cluster state
unrepresentable**. This plan is the binding, executable decomposition of amoebius's grand,
non-binding vision.

The constituent projects are **not separate products** — they are libraries and behaviours amoebius
**lifts and composes** under the DSL rather than reimplements
([`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md)): **prodbox** = the
root single-node control-plane behaviour; **infernix** + **jitML** = the two ML extension libraries (the
closed extension set), each shipping a **PureScript demo web app** that renders its ML results; **hostbootstrap**
= the bootstrap + DSL-`chain` core. Those demo web apps are amoebius's application-logic-only demonstrators and
the SPA-composition shakedown fixtures.

---

## Phase discipline

These rules are absolute and govern all work:

1. **Numeric order.** Phases are completed strictly in order. No work on phase *N+1* begins until phase
   *N* is validated.
2. **Independently validatable.** Each phase ends with **one** concrete acceptance gate that passes before the
   next phase opens — a Register-1/2 in-process check for the pre-cluster band, or a live `InForceSpec`
   topology that spins up resources, runs a workflow, and tears down for the live band.
3. **At most one substrate per validation.** A phase's acceptance gate requires **at most one** substrate
   (`none` | `apple` | `linux-cuda` | `linux-cpu` | `windows`). This prevents cross-substrate flip-flopping
   during development. The required substrate is named in each phase below.
4. **Phase 0 is the whole documentation suite.** The entire DSL is documented — comprehensively and
   explicitly — before any implementation phase begins. See [documents/engineering/README.md](../documents/engineering/README.md).
5. **Validate in the registers; pre-cluster before live.** Validation happens in registers
   ([`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md),
   [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md)): **Register 1** (pure/golden,
   in-process, no cluster), **Register 2** (boundary integration with fake tools, no cluster),
   **Register 2.5** (deterministic simulation — the real daemon/reconciler code under `IOSim`/`IOSimPOR`
   against a modeled fault-injectable environment, no cluster;
   [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md)), and
   **Register 3** (live infrastructure). The **pre-cluster band (phases 1–13, substrate `none`)** discharges
   Registers 1–2 — the DSL's illegal-state-unrepresentable discipline, the pure `render`/plan/`--dry-run`, the
   SPA composition, and the gateway-migration design invariants (both `Planned` and `Failover` branches) — via
   Dhall typecheck + Haskell decoder + QuickCheck + generated-TLA+/TLC + io-sim, **before any phase provisions
   a real resource**. Rendering a plan must never require live infrastructure. Front-loading a *design* proof
   ahead of the phase that builds the runtime it later corresponds to is legitimate **provided** the ledger
   marks model↔code correspondence and runtime fidelity UNVERIFIED — a Tier-1-only in-process ledger can never
   advance a production `PromotionGate`.
6. **Honest ledger.** Every validation emits a proven/tested/assumed ledger artifact that names the register
   it reached; skipping an *applicable* test move marks that correctness layer UNVERIFIED, never green (see the
   chaos/failover doctrine).

This is a large body of work spanning many small, individually-gated phases; that is expected and preferred.

---

## Cross-cutting invariants (documented in Phase 0; upheld by every phase)

- **Amoebius never resolves a tool against the host's `PATH`.** Host tools are discovered lazily via the
  substrate's package manager and invoked by absolute path; only the outermost host tool is absolute-path-resolved,
  while a nested amoebius subcommand running inside a VM or container uses that guest's own `PATH`.
- **Illegal/unsafe cluster state is unrepresentable in a decoded `InForceSpec`** — foreclosed at the Dhall
  typecheck (Gate 1) *or* the typed Haskell decoder (Gate 2) per each entry's catalog locus: gateway, DNS,
  certs, and insecure ingress are type-foreclosed at Gate 1, while PVC↔PV binding and taints/tolerations/affinity
  get their teeth at the Gate-2 decoder (Dhall alone cannot hide a record's constructors).
- **Generated artifacts are never committed.** The k8s manifests, the emitted TLA+ `.tla`/`.cfg`, the reflected
  Dhall schema, and the PureScript frontend contracts are rendered from a Haskell source of truth and never
  committed; only the source is versioned
  ([`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)).
- **The control-plane singleton is a Deployment `replicas=1`.** Single-instance is **delegated to k8s/etcd** (a
  k8s `Lease` if a hard lock is ever needed) — **no bespoke election**; the singleton is stateless (no PVC), its
  durable state exclusively the Vault-enveloped MinIO bucket
  ([`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)).
- **The one formal obligation is the cross-cluster gateway migration**, both the `Planned` and `Failover`
  branches — modelled once as data, simulated (io-sim) and proven (TLC), reduced to every `InForceSpec` by a
  decode-time structural-fit fold, never a per-spec model-check
  ([`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md)).
  Intra-cluster consensus is delegated to MinIO/Pulsar/Patroni/etcd and not re-proven.
- **Resource demand never exceeds capacity.** A workload / VM / compute-engine whose summed cpu/mem/storage
  demand exceeds its host or cluster capacity is decode-rejected — a total fold over per-host/per-node
  declared `Capacity`.
- **No unbounded storage, anywhere.** Storage is host-bounded or cloud-quota-bounded; every Pulsar topic carries
  a bounded retention + a **size-triggered** S3 offload; "unbounded" is representable only behind a quota-capped
  `ScalingPolicy`.
- **ML engines/models/kernels are jit-resolved into a bounded cache, never baked or URL-fetched.** Each asset
  is a **named catalog identity** the shared `jit-build` resolver materializes on first miss into a
  `CacheBudget`-bounded content-addressed cache (`CacheBudget ≤` host storage) — no arbitrary-`Url` arm
  ([`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).
- **The compute engine matches its substrate, and topology matches its hosts.** rke2/kind need a Linux host
  (a Lima/WSL2 VM on apple/windows); multi-node kind is a single host; multi-node rke2 is one Linux host per
  node; EKS is a first-class managed engine — while heterogeneous **multi-substrate clusters are allowed**.
- **Application logic and deployment rules are separate DSL surfaces.** An app is written once; HA
  replicas, chaos testing, geo-replication, and failover are an orthogonal deployment-rules layer.
- **Secrets never live in Dhall** — only names. Parents inject secrets into a child's Vault.
- **Standard platform services on every cluster** (below), **HA always** (the chart is HA even at `replicas=1`).
- **Only `no-provisioner` retained PVs** (`<namespace>/<statefulset>/pv_<integer>`, sized, host/EBS-bound) for
  platform-service and workload durable storage; the control plane itself holds no PVC.
- **Containers always declare cpu/ram.**
- **Keycloak owns all wild ingress** via the LB + Gateway API; the sole exception is host-origin, localhost-only traffic (host-only NodePorts).
- **Pulsar payloads are exclusively CBOR** (canonical where content-addressed) — a non-CBOR application payload
  (JSON/base64/protobuf/raw) is unrepresentable; the protocol framing stays protobuf.

## Standard platform services (every cluster, HA)

Registry (`distribution`, replaces Harbor) · MinIO · Vault · Pulsar · Prometheus/Grafana · Percona/Patroni
Postgres (per-service deployment + pgAdmin) · Envoy / Gateway API · Keycloak · MetalLB-or-cloud
LoadBalancer. Every third-party **service** binary is **baked into the multi-arch base container** (no
public-registry pulls); the ML **engine payloads** are the deliberate exception — jit-resolved into a bounded
cache, not baked (above). The list is the concrete providers behind the capabilities.

## Toolchain

GHC **9.12.4**, Cabal 3.16.1.0, one shared pin across all packages. (GHC 9.14.1 is a
deferred, later-phase bump — phase 33.) The pre-binary **midwife** is a **Python `pb` CLI** (not a shell
script), unified with the operator CLI.

The formal-model phases (Phase 2, Phase 3) run TLC through a **pinned `tla2tools.jar`** (a fixed release) on a
**JRE ≥ 17** floor; both are pinned here and located by the Phase-2/3 harness — a JVM toolchain independent of
the GHC pin, so it is a named acquisition path even though its buildability is not gated by the Phase-1 probe.

---

## Document index

| Document | Purpose |
|----------|---------|
| [development_plan_standards.md](development_plan_standards.md) | The rulebook: file layout, status vocabulary, sprint format, the doctrine-citation rule, the three-register + honesty + one-substrate disciplines. |
| [overview.md](overview.md) | Target architecture / vision / hard constraints / canonical gates — the "why/what" companion to this tracker. |
| [system_components.md](system_components.md) | Target component inventory: surface → owning doctrine → planned module path → building phase. |
| [substrates.md](substrates.md) | The substrate registry and the per-phase substrate map. |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | The migration-removal ledger (what the convergence retires, and when). |
| `phase_00_…` … `phase_37_…` | One substantive document per phase (linked in the Phase overview below). |
| [later_phases.md](later_phases.md) | The in-scope, high-numbered phases (38+) not yet given their own document. |

## Status vocabulary

✅ Done · 🔄 Active · 📋 Planned · ⏸️ Blocked · 🧪 Live-proof pending. Status lives **only** in this plan;
doctrine docs state the target shape and link back here. Full definitions in
[development_plan_standards.md §C](development_plan_standards.md). Pre-implementation, Phase 0 (this
documentation suite) is 🔄 **Active** and every later phase is 📋 **Planned**.

## Definition of Done (per phase)

A phase is ✅ Done only when its acceptance **Gate** has actually run in its register on its substrate and
emitted a green, committed, `ledger_lint`-checked proven/tested/assumed ledger — never on "it compiles" (the
honesty rule, [development_plan_standards.md §K](development_plan_standards.md)). The ✅ Done flip **records the
exact re-runnable gate command, the run date, the substrate, and the ledger hash** in the phase row or doc; a
flip missing them is rejected by the documentation lint. Every Gate is written to the gate-integrity discipline
([development_plan_standards.md §M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)):
fixtures, goldens, and expected error tags pinned in Phase 0 before the implementation exists; ≥1 committed
seeded mutant that must go red; and any equivalence check using an oracle independent of the code under test —
so a stub, a self-regenerated golden, or a wrong-reason negative cannot pass it.

## Phase overview

Each phase has its own document with the objective, the doctrine sections it adopts (cited by name), its
sprints, and its **one** gate. *Substrate* is the single substrate the gate runs on. Phases **1–13** are the
**pre-cluster band** (substrate `none`, Registers 1–2); phases **14–37** are the **live band** (Register 3),
ordered by substrate; phases **38+** are the backlog.

| Phase | Name | Substrate | Register | Gate (one line) | Status | Document |
|-------|------|-----------|----------|-----------------|--------|----------|
| 0 | Documentation suite (whole DSL) | none | — | the documentation lint passes two-sided — headers, anchors, bidirectional Referenced-by, near-duplicate detection, status-consistency, gate-integrity — and fails on every committed seeded negative | 🔄 Active | [phase_00](phase_00_documentation_suite.md) |
| 1 | Toolchain spike | none | 1 | a probe of `dhall` + `io-sim`/`io-classes` + the jit-build resolver + `purescript-bridge` + the Pulsar `supernova` fork builds on the pinned GHC/Cabal, or the exact `allow-newer`/patch/blocker is recorded (with a build transcript) | 📋 Planned | [phase_01](phase_01_toolchain_spike.md) |
| 2 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | 1 | the `Model` explorer + `emitTLA` round-trip (safety **and** a liveness `PROPERTY` under fairness, fairness-sensitivity checked); a differential generator (≥200 non-degenerate models, coverage floors) finds no explorer/TLC disagreement on safety; committed renderer mutants are caught; the `.tla` is TLC-checkable, never committed | 📋 Planned | [phase_02](phase_02_formal_model_kernel.md) |
| 3 | Gateway-migration model (both branches) | none | 1 | TLC reaches every safety invariant + every liveness `PROPERTY` (under fairness) at scope for both `Planned` and `Failover` with passing vacuity/fairness-sensitivity/cutoff checks; io-sim agrees on safety; every mechanical mutant (incl. one per invariant) is caught | 📋 Planned | [phase_03](phase_03_gateway_migration_model.md) |
| 4 | Dhall Gate-1 schema + smart-constructor prelude | none | 1 | `dhall type` accepts the positive corpus and rejects each Gate-1-class negative at its committed expected error (no binary; no open escape arm) | 📋 Planned | [phase_04](phase_04_dhall_gate1_schema.md) |
| 5 | GADT IR + fail-closed decoder (Gate 2) | none | 1 | `cabal test dsl-spec` green — each positive decodes; each Gate-2 negative returns a structured `Left` with its expected tag; the decode path is checked non-partial + fail-closed (exception-catch wrapper) | 📋 Planned | [phase_05](phase_05_gadt_decoder_gate2.md) |
| 6 | Illegal-state corpus + validation-locus ledger | none | 1 | every negative fixture is rejected at its tagged locus (Gate-1 / Gate-2 / compile-fail); QuickCheck green with coverage floors; the per-entry validation-locus ledger is emitted | 📋 Planned | [phase_06](phase_06_illegal_state_corpus.md) |
| 7 | Capacity / topology folds | none | 1 | `fits`/`carve`/`place` (sound pod→node witness) + topology QuickCheck properties hold; the decode-foreclosed folds reject each capacity/topology negative | 📋 Planned | [phase_07](phase_07_capacity_topology_folds.md) |
| 8 | Capability → provider → shape binder | none | 1 | a capability need decodes to a `ServiceSpec` at the type level; a product-named app fails Gate 1 at its committed locus | 📋 Planned | [phase_08](phase_08_capability_binder.md) |
| 9 | Pure `render` + rendered-output goldens | none | 1 | `render :: ServiceSpec -> [K8sObject]` byte-for-byte golden-locked against committed goldens; the rendered-output illegal states (hardened context, no backdoor ingress, derived NetworkPolicy) hold; a seeded mutant turns it red | 📋 Planned | [phase_09](phase_09_render_manifest_goldens.md) |
| 10 | chain/Step kernel + `--dry-run` plan render | none | 1 | `chain :: cfg -> [Step]` renders a byte-for-byte `--dry-run` plan with no effects (zero `stepRun`, external-observer verified); the pure descent is golden-locked | 📋 Planned | [phase_10](phase_10_chain_kernel_dryrun.md) |
| 11 | Boundary-integration fake-tool harness | none | 2 | the binary runs the plan against fake `kubectl`/`docker`/`pulumi` by absolute path (the `helm` fake a zero-invocations negative); recorded argv == the committed hand-authored transcript and applied bytes == the goldens; committed argv/byte/PATH mutants turn it red | 📋 Planned | [phase_11](phase_11_boundary_fake_tool_harness.md) |
| 12 | Deterministic-simulation substrate | none | 2 | the real daemon/reconciler code under `IOSim`/`IOSimPOR` replays a committed fault/partition/redelivery schedule; same-seed → byte-identical trace (a distinct seed must differ); a committed fault-mutant turns the invariant red; modeled-env fidelity marked assumed | 📋 Planned | [phase_12](phase_12_deterministic_sim_substrate.md) |
| 13 | SPA composition (representational) + demo-SPA local | none | 1/2 | `prop_spaCompositionDecodes` holds over generated pairs (coverage floors); the PureScript demo SPA runs locally against a faked backend (Playwright), the contract from a committed golden | 📋 Planned | [phase_13](phase_13_spa_composition_representational.md) |
| 14 | Python midwife + substrate detect + single kind cluster | linux-cpu | 3 | `pb bootstrap --distro=kind` brings up an empty single-node kind cluster; re-run is a no-op; every external invocation went through an absolute path (OS-boundary observer) | 📋 Planned | [phase_14](phase_14_midwife_bootstrap_kind.md) |
| 15 | Multi-arch base image + jit-build resolver + `distribution` registry | linux-cpu | 3 | the multi-arch base image (service binaries + resolver/toolchain, amoebius binary alone) publishes atomically into the in-cluster `distribution` registry; no public-registry pulls | 📋 Planned | [phase_15](phase_15_base_image_registry.md) |
| 16 | Typed renderer + live SSA reconciler | linux-cpu | 3 | a `render`ed object set is applied by the SSA reconciler (owned field manager, `force`, ApplySet prune, wait) to convergence; re-run is a no-op | 📋 Planned | [phase_16](phase_16_renderer_reconciler.md) |
| 17 | No-provisioner retained storage + lossless rebind | linux-cpu | 3 | storage rebinds after a real cluster delete+recreate with no data loss (fresh uid-less-`claimRef` PV over preserved bytes; OS-boundary observer confirms real teardown) | 📋 Planned | [phase_17](phase_17_retained_storage.md) |
| 18 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | 3 | the root password-encrypted Vault inits + unseals fail-closed; the PKI anchor issues; the built-in Haskell client reads a `SecretRef` | 📋 Planned | [phase_18](phase_18_vault_pki.md) |
| 19 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | 3 | the backbone comes up HA from generated manifests + baked binaries, no public pull; the `distribution` registry re-homes onto the MinIO S3 driver; a size-triggered Pulsar S3 offload fires and the hot tier never exceeds its cap | 📋 Planned | [phase_19](phase_19_platform_backbone.md) |
| 20 | Platform services-2 (Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | 3 | Percona/Patroni (mandated `synchronous_mode`) + pgAdmin + Prometheus/Grafana come up HA; the whole stack comes up in the derived readiness-DAG order (external-observer trace; a hardcoded sequence is a caught mutant) | 📋 Planned | [phase_20](phase_20_platform_services_2.md) |
| 21 | Keycloak-owned ingress | linux-cpu | 3 | every wild route is reachable only through Keycloak/Envoy; a workload cannot publish its own wild ingress | 📋 Planned | [phase_21](phase_21_keycloak_ingress.md) |
| 22 | Live DSL deploy via the `replicas=1` singleton | linux-cpu | 3 | a `.dhall` deploys the platform + a trivial app via the Deployment-`replicas=1` singleton (`strategy: Recreate` + Lease, no election); the Phase-6 negative corpus still fails against the live spec-ingestion path | 📋 Planned | [phase_22](phase_22_live_dsl_singleton.md) |
| 23 | App tenancy + `TenantSpec` | linux-cpu | 3 | an app gets its own namespace, `<app>/<bucket>` ObjectStore, and in-namespace Sql; a spec cannot name a foreign tenant's resource | 📋 Planned | [phase_23](phase_23_app_tenancy.md) |
| 24 | Native Pulsar client (CBOR) | linux-cpu | 3 | a command→event round-trips over native-protocol Pulsar with broker-side (produce-path) dedup; a CBOR payload round-trips byte-for-byte; a non-CBOR fixture fails type-check | 📋 Planned | [phase_24](phase_24_pulsar_client.md) |
| 25 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | 3 | a workflow stores/fetches a content-addressed artifact by manifest SHA; killing the active worker triggers Pulsar-Failover takeover with no double-applied fenced effect; leak-free teardown | 📋 Planned | [phase_25](phase_25_content_store_workflow.md) |
| 26 | Release lifecycle (ledger + PromotionGate + RolloutPlan) | linux-cpu | 3 | a live Release-ledger write emits a `releaseHash`; the PromotionGate refuses an under-verified→prod promotion (committed fixture); a satisfied gate advances the ETag-CAS pointer; a readiness-gated RolloutPlan (incl. a DB schema-migration phase) applies in order; a mutant admitting a bad promotion turns it red | 📋 Planned | [phase_26](phase_26_release_lifecycle.md) |
| 27 | WireGuard network fabric | linux-cpu | 3 | the singleton renders each peer config from Vault-KV Curve25519 keys (SecretRef names only) and reconciles raw-kernel WireGuard so every cluster draws its VPN IP and the gateway-role hub is reachable (external-observer probe); a committed golden pins the config; a rotated/missing key mutant turns it red | 📋 Planned | [phase_27](phase_27_network_fabric_wireguard.md) |
| 28 | Multi-cluster spawn + geo-replication | linux-cpu | 3 | a parent spawns two children (Pulumi-from-inside first built here) that geo-replicate a workflow; each child receives `project(subtree)` (compile-fail corpus); leak-free teardown | 📋 Planned | [phase_28](phase_28_multicluster_spawn_georepl.md) |
| 29 | Gateway-migration drills + model-correspondence | linux-cpu | 3 | a `Planned` handover is RPO=0 (external out-of-forest write-journal oracle, ≥8 acked-but-un-replicated writes at quiesce) and a `Failover` rebinds within the Phase-0-committed `DataLossBudget`; trace-validated against the Phase-3 model; committed `verify-caught-up`-stub / `promote-before-fence` mutants turn it red | 📋 Planned | [phase_29](phase_29_gateway_migration_drills.md) |
| 30 | Provider-managed clusters + dynamic provisioning | linux-cpu → provider | 3 | spin a provider (EKS) cluster from a parent (reusing the Phase-28 Pulumi engine), dynamically provision a node by a declared rule, refuse a growth past the quota cap, tear down leak-free (tag-sweep backstop) | 📋 Planned | [phase_30](phase_30_provider_clusters.md) |
| 31 | Determinism kernel | linux-cpu | 3 | `experimentHash = sha256(dhall‖substrate)` + SplitMix seed derivation reproduce byte-identical output on the same substrate (independent recompute, cache-bypassed); a changed input changes the hash | 📋 Planned | [phase_31](phase_31_determinism_kernel.md) |
| 32 | jit-build engine resolver + `CacheBudget` cache | linux-cpu | 3 | a named engine identity resolves on first miss into the `CacheBudget`-bounded content-addressed cache; a second pod reuses it; budget-pressure eviction keeps Σ≤budget; over-budget is decode-rejected | 📋 Planned | [phase_32](phase_32_jitbuild_engine_cache.md) |
| 33 | infernix lift + CPU inference reproducibility | linux-cpu | 3 | an infernix CPU-inference workflow is reproducible (same `experimentHash`, independent recompute ⇒ same output); its demo web app deploys as application-logic-only | 📋 Planned | [phase_33](phase_33_infernix_lift.md) |
| 34 | jitML lift + checkpoints + coordinator + CUDA | linux-cuda | 3 | a jitML run is bit-deterministic per contract; the single-writer trainer fails over via a Pulsar Failover subscription (no election, no torn `latest`); its demo web app deploys as application-logic-only | 📋 Planned | [phase_34](phase_34_jitml_lift_cuda.md) |
| 35 | Apple-Metal host compute daemon | apple | 3 | an Apple-Silicon host daemon runs a Metal ML workload as a cluster Pulsar/MinIO peer over a host-only NodePort | 📋 Planned | [phase_35](phase_35_apple_metal_host_daemon.md) |
| 36 | Test-topology DSL + suggest-test + elevated harness | per generated test | 3 | a generated test `.dhall` runs a failover simulation on its single substrate and tears down leak-free (postflight sweep over all resource classes empty) | 📋 Planned | [phase_36](phase_36_test_topology_dsl.md) |
| 37 | Live SPA deploy | linux-cpu | 3 | an SPA `.dhall` composes a multi-service app + an ML-workflow demo app, deployed and reachable behind Keycloak/Envoy; an inference request round-trips through the composed workflow | 📋 Planned | [phase_37](phase_37_spa_live_deploy.md) |
| 38+ | Later phases | varies | — | each high-numbered in-scope phase gets its own gate when reached (GHC 9.14 bump, schema-migration automation, the Haskell extension DSL + AST checker + JIT, niche substrates incl. Windows-CUDA) | 📋 Planned | [later_phases](later_phases.md) |

The detailed objective, sprint breakdown, doctrine adoptions, and gate for each phase live in that phase's
own document (linked above); this tracker holds only the one-line gate and status. The standing rules a
reader needs are in [development_plan_standards.md](development_plan_standards.md); the architecture and
constraints behind them are in [overview.md](overview.md).

---

## Cross-references
- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
