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
   Registers 1–2 — the DSL's illegal-state-unrepresentable discipline, the pure `renderAll`/plan/`--dry-run`, the
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
- **The control-plane singleton is a Deployment `replicas=1`.** Single-writer authority is **delegated to
  k8s/etcd through the mandatory reconciler `Lease`** — **no bespoke election**; the singleton is stateless (no PVC), its
  durable state exclusively the Vault-enveloped MinIO bucket. The singleton still has a complete pod/rollout
  envelope, and its exact five-kind control-plane state is a budgeted/admitted object-store producer
  ([`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)).
- **Cluster infrastructure is ephemeral; durable backing is retained independently.** Root, child,
  self-managed, and provider-managed cluster infrastructure may be replaced; production does not acquire a
  TTL or an always-teardown rule. A rebuilt cluster reconciles toward the persistent root `InForceSpec` and
  reattaches retained backing, which routine teardown cannot delete
  ([`cluster_lifecycle_doctrine.md §4`](../documents/engineering/cluster_lifecycle_doctrine.md#4-the-root-inforcespec-is-the-persistent-contract),
  [`§7`](../documents/engineering/cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind);
  [`storage_lifecycle_doctrine.md §1`](../documents/engineering/storage_lifecycle_doctrine.md#1-cluster-and-storage-have-independent-lifetimes),
  [`§7`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation)).
- **The one formal obligation is the cross-cluster gateway migration**, both the `Planned` and `Failover`
  branches — modelled once as data, simulated (io-sim) and proven (TLC), reduced to every `InForceSpec` by a
  decode-time structural-fit fold, never a per-spec model-check
  ([`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md)).
  Intra-cluster consensus is delegated to MinIO/Pulsar/Patroni/etcd and not re-proven.
- **No unbounded storage, anywhere.** Storage is host-bounded or cloud-quota-bounded; every Pulsar topic carries
  a bounded retention + a **size-triggered** S3 offload; "unbounded" is representable only behind a quota-capped
  `ScalingPolicy`. OCI content/snapshots, BuildKit cache/scratch, enforceable etcd
  DB/WAL/snapshot/defrag transitions, Events/Leases/API objects and AtomicWriter files, ZooKeeper metadata,
  Patroni data/WAL/recovery, registry partial uploads/rehome, Pulumi checkpoints/plugins/workspace, release and
  control-plane state, Prometheus TSDB compaction/query work, Vault Raft/audit storage, object-store
  parity/healing space, and failed-write orphans all have typed source operands, named owners, attached
  `StorageBudgetId`s where applicable, and finite GC/retention/rotation bounds.
- **ML engines/models/kernels are jit-resolved into a bounded cache, never baked or URL-fetched.** Each asset
  is a **named catalog identity** the shared `jit-build` resolver materializes on first miss through one
  per-node cache-owner execution unit. Catalog-owned resident and peak-temporary bytes plus finite first-miss
  concurrency derive a private peak bounded by
  `ProvisionedCacheDemand.derivedPeak ≤ CacheBudget ≤ emptyDir.sizeLimit`; the owner's explicit
  `ephemeral-storage` request reserves that volume
  bound plus writable/log headroom. CPU is throttled at its finite limit, memory is bounded reactively by the
  kernel, and Kubernetes measures local ephemeral use and evicts after a limit breach rather than providing
  synchronous `ENOSPC`. The cache owner's private admission guard prevents materialization beyond the
  provisioned peak, while the layout-routed filesystem carve supplies the hard physical bound. Those storage
  proofs are one node-ephemeral debit, and clients receive typed handles rather than a writable host path.
  There is no arbitrary-`Url` arm
  ([`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).
- **The compute engine matches its substrate, and topology matches its hosts.** rke2/kind need a Linux host
  (a Lima/WSL2 VM on apple/windows); multi-node kind is a single host; multi-node rke2 is one Linux host per
  node; EKS is a first-class managed engine — while heterogeneous **multi-substrate clusters are allowed**.
- **Application logic and deployment rules are separate DSL surfaces.** An app is written once; HA
  replicas, chaos testing, geo-replication, and failover are an orthogonal deployment-rules layer.
- **Secrets never live in Dhall** — only names. Parents inject secrets into a child's Vault.
- **Standard platform services on every cluster** (below), **HA always** (the chart is HA even at `replicas=1`).
- **Only `no-provisioner` retained PVs** (`<namespace>/<statefulset>/pv_<integer>`, sized, host/EBS-bound) for
  platform-service and workload durable storage; every volume pins block/filesystem presentation, required
  usable bytes, and a backing-rounded raw allocation. One PVC/PV/EBS is 1:1:1 by identity, not by pretending
  filesystem-usable bytes equal a provider's whole-GiB raw volume. The control plane itself holds no PVC.
- **Every resource provision is explicit, pure first, and impossible targets have no deployable value.**
  Dhall/ClusterIR carries structural demand—not precomputed Kubernetes numbers—for every app, init,
  controller/operator child, webhook/gateway, build/Pulumi/copy/schema/ACME Job, host process, engine process,
  and network-fabric role. Binding source-expands all runnable members into stable identity/revision-keyed
  `BoundExecutionUnit`s. `planInfrastructure` derives—not accepts—the matching demand and either proves the
  declared target already materialized or returns one non-renderable `ProvisionedInfrastructurePlan` whose
  `ProvisionedProviderActionBatch` owns the closed cloud-provider/SSH-host actions and the one Pulumi graph.
  Fresh validation joins that batch to a `ValidatedInfrastructureActionBatch` and fresh plan/action tokens;
  only their CAS enaction and receipt-bound provider/host readback can construct `ProvisionContext`. The only
  deployable representation is then the opaque whole-deployment `ProvisionedSpec` returned by
  `provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec`;
  a CPU-, memory-, disk-, slot-, device-, or VRAM-incompatible workload/topology pair returns `Left` and
  cannot call deployment-global `renderAll`.

  - **CPU and memory:** every container declares non-zero request/limit operands; every host process declares
    reservation/ceiling plus an enforceable Linux-cgroup, Windows-Job, or finite Apple-supervisor policy.
    Pod overhead, tmpfs/accessor residency, working sets, controller children, old/new/surge/terminating
    overlap, Job waves/terminal retention, host launch/drain overlap, and the scheduler/singleton themselves
    are derived and fitted before any projection. Kubernetes requests/limits or host controls are exact
    private witness projections, never defaults.
  - **Storage:** each container declares finite logical `ephemeral-storage` request/limit; every disk-backed
    `emptyDir`, cache, scratch, writable root, log, mapped file, pull/import workspace, and failure residue has
    an explicit bound, identity, lifetime, and physical route. An in-cluster cache is an explicit
    `CacheBudget` nested inside `emptyDir.sizeLimit`; the Pod request covers it plus writable/log headroom and
    the envelope is charged once. Kubelet and CRI runtime-metadata components derive from Pod structure,
    resolve through `KubeletNodefs | CriRuntimeRoot` and the selected
    `Unified | SplitRuntime | SplitImage` layout, then group aliased backing debits once. OCI content and
    snapshots deduplicate by allocation-domain-scoped identity; missing-pull workspace uses the bounded
    concurrency high-water and remains charged after failures until observed cleanup. Durable volumes,
    object-store extents, host caches, VM/root disks, filesystem overhead, allocation quanta, recovery,
    replacement, and retained artifacts each name their backing/quota and old+new high-water. A
    `PhysicalDiskPartition` proves the unit-safe physical equation
    `systemReserve raw debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ≤
    allocatableRawBytes`; each VM separately proves its guest-system and layout usable-byte debits fit its
    `requiredUsableBytes`. Provider-node recipes make the same unit boundary explicit:
    `InstanceStore.provisionedRawBytes` is SKU-pinned raw supply, while `systemReserve` and layout `carves` are
    `ProviderUsableDiskCarveTemplate.requiredUsableBytes`; an `EphemeralRootEbs` arm instead derives its
    allocation-rounded raw request from those usable demands. Private `ProvisionedPerInstanceDiskTemplate`
    derives presentation-pinned `mountedUsableBytes` from either raw source before proving the usable nested
    fit, so no raw provider byte count pays a usable filesystem carve directly.
  - **Multiplicity, slots, and live races:** controller kind fixes its legal shape—Deployment
    `Once | Replicated` with Recreate/nonzero-progress RollingUpdate; StatefulSet serial partition-zero or
    staged OnDelete; DaemonSet fixed/elastic per-node targets with staged OnDelete or exactly one positive
    Surge/Unavailable; finite Job completions/parallelism/backoff/retention; or HostProcess
    `Once | PerNode` with arm-specific replacement. Planned slots are not Pod UIDs. The live inventory keeps
    every UID/process plus Pod/CNI slots and identity-keyed CSI attachments distinct. The same-binary
    `amoebius-capacity` scheduler authenticates a sealed prior+desired child template, re-folds the static,
    foreign, resident, whole-ledger, and candidate resource algebra under one aggregate CAS, then alone binds
    the Pod. Terminating/replacement UIDs cannot become free through a replica scalar.
  - **Accelerators and accelerator memory:** CUDA/Metal demand is a closed owner arm with exact
    source/workload identities, finite coexistence epochs, placement/shards, and release policy. CUDA
    provisioning selects matching topology/device identities, gives one owner the full generic GPU offering,
    and fits each derived epoch against per-device **net allocatable VRAM** (raw minus mandatory reserve) plus
    freshly observed free memory; different Pod owners cannot share the device. Metal epoch bytes debit Apple
    unified host memory. CUDA serial OnDelete and Metal host replacement require fresh device/process/memory
    release evidence before the next owner can start; a cluster without the required accelerator family or
    sufficient VRAM cannot produce `ProvisionedSpec`.

  Static engine processes are named `EngineSystemReserve` components, and BuildKit/buildx, the scheduler,
  singleton Lease, admission gateways, observers, and the topology-derived network fabric all carry the same
  explicit compute/storage/slot cost rather than hiding as overhead.
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
| 7 | Capacity / topology folds | none | 1 | `fits`/`carve`/`place` produce a sound whole-deployment witness across CPU/memory, pod/CNI/CSI slots, mapped/API/etcd state, logical and physical ephemeral/image storage, durable/object/database/migration storage, all controller/gateway/executor units, provider quotas, accelerator availability, and net allocatable VRAM; every one-short axis rejects | 📋 Planned | [phase_07](phase_07_capacity_topology_folds.md) |
| 8 | Capability → provider → shape binder | none | 1 | capability/provider shapes fully expand; exact demand first passes the conditional infrastructure planner/materialization boundary, then the whole deployment can become an opaque `ProvisionedSpec`; a product-named app fails Gate 1 and a CUDA-requiring workload paired with a non-CUDA topology returns its committed `ProvisionError` at the post-bind provision seal | 📋 Planned | [phase_08](phase_08_capability_binder.md) |
| 9 | Pure `renderAll` + rendered-output goldens | none | 1 | `renderAll :: ProvisionedSpec -> [K8sObject]` is byte-for-byte golden-locked; it total-maps Phase 8's unique identity-keyed render-source set, and every workload, webhook/gateway/Job, mapped source, CR child, volume/migration, etcd control, and accelerator field is an exact opaque-witness projection | 📋 Planned | [phase_09](phase_09_render_manifest_goldens.md) |
| 10 | chain/Step kernel + `--dry-run` plan render | none | 1 | `chain :: cfg -> [Step]` renders a byte-for-byte `--dry-run` plan with no effects (zero `stepRun`, external-observer verified); the pure descent is golden-locked | 📋 Planned | [phase_10](phase_10_chain_kernel_dryrun.md) |
| 11 | Boundary-integration fake-tool harness | none | 2 | the binary runs the plan against fake `kubectl`/`docker`/`pulumi` by absolute path (the `helm` fake a zero-invocations negative); recorded argv == the committed hand-authored transcript and applied bytes == the goldens; committed argv/byte/PATH mutants turn it red | 📋 Planned | [phase_11](phase_11_boundary_fake_tool_harness.md) |
| 12 | Deterministic-simulation substrate | none | 2 | the real daemon/reconciler code under `IOSim`/`IOSimPOR` replays a committed fault/partition/redelivery schedule; same-seed → byte-identical trace (a distinct seed must differ); a committed fault-mutant turns the invariant red; modeled-env fidelity marked assumed | 📋 Planned | [phase_12](phase_12_deterministic_sim_substrate.md) |
| 13 | SPA composition (representational) + demo-SPA local | none | 1/2 | `prop_spaCompositionDecodes` holds over generated pairs (coverage floors); the PureScript demo SPA runs locally against a faked backend (Playwright), the contract from a committed golden | 📋 Planned | [phase_13](phase_13_spa_composition_representational.md) |
| 14 | Python midwife + substrate detect + single kind cluster | linux-cpu | 3 | `pb bootstrap --distro=kind` admits engine CPU/memory, pod/CNI/CSI slots, mapped/API/etcd logical+physical state, presentation-aware disk, kubelet aliases, and inner/outer OCI content/snapshots; re-run is a no-op; teardown is leak-free | 📋 Planned | [phase_14](phase_14_midwife_bootstrap_kind.md) |
| 15 | Multi-arch base image + jit-build resolver + `distribution` registry | linux-cpu | 3 | a snapshot-bound host envelope admits buildx CPU/memory/scratch/cache/concurrency before execution; the resulting multi-arch base image publishes atomically into the in-cluster registry with no public-registry pulls | 📋 Planned | [phase_15](phase_15_base_image_registry.md) |
| 16 | Typed renderer + live SSA reconciler | linux-cpu | 3 | before any write, one live snapshot admits the complete transition across CPU/memory, pod/CNI/CSI slots, mapped/API/etcd state, filesystem/content/snapshots, object/durable/migration backings, controller/webhook/gateway/executor overlap, and accelerator/net-free-VRAM; mismatch writes nothing | 📋 Planned | [phase_16](phase_16_renderer_reconciler.md) |
| 17 | No-provisioner retained storage + lossless rebind | linux-cpu | 3 | required usable bytes pass through filesystem overhead/backing quantum before uniform PVC/PV render; verified shrink reserves old+new+workspace and its copy Job, and raw/usable caps rebind after cluster replacement with no data loss | 📋 Planned | [phase_17](phase_17_retained_storage.md) |
| 18 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | 3 | bounded Vault populations derive Raft WAL/snapshot/compaction/recovery and rotated-audit storage before init; the root Vault unseals fail-closed, the PKI anchor issues, and the built-in client reads a `SecretRef` | 📋 Planned | [phase_18](phase_18_vault_pki.md) |
| 19 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | 3 | BookKeeper and explicit ZooKeeper recovery plus six-arm MinIO producer geometry fit; the registry rehome reserves source+target+workspace/Job and verifies every old digest before cutover; size-triggered offload passes | 📋 Planned | [phase_19](phase_19_platform_backbone.md) |
| 20 | Platform services-2 (Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | 3 | each SQL consumer provisions Patroni children/webhook/gateway plus data/WAL/recovery storage; monitoring work derives Prometheus/proxy compute and rounded TSDB compaction/query capacity; live children match | 📋 Planned | [phase_20](phase_20_platform_services_2.md) |
| 21 | Keycloak-owned ingress | linux-cpu | 3 | Envoy controller/children, Keycloak, ACME Job/Vault delta, and Keycloak Patroni DB provision before effects; every wild route is reachable only through Keycloak/Envoy | 📋 Planned | [phase_21](phase_21_keycloak_ingress.md) |
| 22 | Live DSL deploy via the `replicas=1` singleton | linux-cpu | 3 | the singleton/trivial app/gateway have complete envelopes and the exact five-kind control-plane-state producer fits before `.dhall` persistence or reconcile; `Recreate` + the mandatory Lease supplies single-writer authority | 📋 Planned | [phase_22](phase_22_live_dsl_singleton.md) |
| 23 | App tenancy + `TenantSpec` | linux-cpu | 3 | the app pod, object producer/gateway, and distinct Patroni SQL provision fit before its namespace/bucket/database; a spec cannot name a foreign tenant's resource | 📋 Planned | [phase_23](phase_23_app_tenancy.md) |
| 24 | Native Pulsar client (CBOR) | linux-cpu | 3 | embedded client buffers/sessions are debited to the consumer and the gate runner has a complete envelope; command→event/dedup/CBOR checks pass and non-CBOR fails type-check | 📋 Planned | [phase_24](phase_24_pulsar_client.md) |
| 25 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | 3 | one orchestrator + three workers, gateway/collector, takeover overlap, and the closed Content producer fit before the artifact/failover workflow; no double-applied fenced effect | 📋 Planned | [phase_25](phase_25_content_store_workflow.md) |
| 26 | Release lifecycle (ledger + PromotionGate + RolloutPlan) | linux-cpu | 3 | exact release/pointer Content objects and gateway fit before writes; schema migration reserves executor + table/index/temp/WAL old+new high-water; verified CAS/promotion/rollout passes and bad promotion fails | 📋 Planned | [phase_26](phase_26_release_lifecycle.md) |
| 27 | WireGuard network fabric | linux-cpu | 3 | the topology-derived peer/rate/queue/log cost fits each node before raw-kernel mutation; the singleton renders peers from Vault key names, reconciles WireGuard, and externally proves hub reachability and zero-effect overdraw | 📋 Planned | [phase_27](phase_27_network_fabric_wireguard.md) |
| 28 | Multi-cluster spawn + geo-replication | linux-cpu | 3 | checkpoint objects/gateway and bounded Pulumi executor Jobs/plugins/workspace plus both child supplies fit the parent before either stack mutates; two projected children geo-replicate a workflow and tear down leak-free | 📋 Planned | [phase_28](phase_28_multicluster_spawn_georepl.md) |
| 29 | Gateway-migration drills + model-correspondence | linux-cpu | 3 | source+overlap+target edge/fabric, Pulumi/checkpoint, non-idle workflow, API/etcd, and external-journal harness fit before handoff; `Planned` proves RPO=0 and `Failover` stays within the pinned budget and Phase-3 trace | 📋 Planned | [phase_29](phase_29_gateway_migration_drills.md) |
| 30 | Provider-managed clusters + dynamic provisioning | linux-cpu → provider | 3 | spin EKS for an authored cloud-account identity from complete node classes with pod/CSI slot policies, raw `InstanceStore.provisionedRawBytes` or rounded root-EBS requests, usable system/layout carves with private mounted-usable fit, content/snapshot geometry, and all independent provider-quota fields; materialize and probe exact launch-template filesystems, refuse incompatible/over-quota growth before mutation, prove rounded durable EBS rebind, then sweep only ephemeral cluster resources to zero while retained durable EBS remains for Phase-36 privileged reclamation | 📋 Planned | [phase_30](phase_30_provider_clusters.md) |
| 31 | Determinism kernel | linux-cpu | 3 | each fresh workflow run, gateway/collector, topic/store state, API/etcd transition, and host observer provision before serial-after-gone execution; independent cache-bypassed recompute is byte-identical and a changed input changes the hash | 📋 Planned | [phase_31](phase_31_determinism_kernel.md) |
| 32 | jit-build engine resolver + `CacheBudget` cache | linux-cpu | 3 | catalog resident/temp operands and finite first-miss concurrency derive each cache owner's private peak; it fits budget/volume/pod request, serves typed handles, and rejects deletion/conflict/concurrent overflow | 📋 Planned | [phase_32](phase_32_jitbuild_engine_cache.md) |
| 33 | infernix lift + CPU inference reproducibility | linux-cpu | 3 | a finite inference work budget derives workflow/cache/SPA/build/registry/harness and cold-run overlap before effects; independent same-hash CPU recompute matches and the application-logic-only demo deploys | 📋 Planned | [phase_33](phase_33_infernix_lift.md) |
| 34 | jitML lift + checkpoints + coordinator + CUDA | linux-cuda | 3 | observed CUDA family/count and per-device allocatable/free VRAM after mandatory reserve must satisfy the pure envelope; the named owner container receives the exact whole-device claim and pod affinity before effects; raw-fits/net-fails writes nothing | 📋 Planned | [phase_34](phase_34_jitml_lift_cuda.md) |
| 35 | Apple-Metal host compute daemon | apple | 3 | physical CPU/unified memory/storage fit system reserve + a presentation/quantum-derived Lima disk + Metal worker + host cache; outputs route through the provisioned mutation gateway, raw MinIO stays unexposed, and every high-water is read back | 📋 Planned | [phase_35](phase_35_apple_metal_host_daemon.md) |
| 36 | Test-topology DSL + suggest-test + elevated harness | per generated test | 3 | a generated test provisions all observed compute/storage/accelerator/quota classes plus closed registry-publication, Pulumi/checkpoint, and old+new migration/copy-Job branches, then tears down with every applicable resource-class delta empty | 📋 Planned | [phase_36](phase_36_test_topology_dsl.md) |
| 37 | Live SPA deploy | linux-cpu | 3 | the full app/rollout, surviving platform/workflow/cache, cold-tenant rematerialization, object/topic/database, image, slot, and API/etcd transition provisions before apply; the composed inference path round-trips behind Keycloak/Envoy | 📋 Planned | [phase_37](phase_37_spa_live_deploy.md) |
| 38+ | Later phases | varies | — | each high-numbered in-scope phase gets its own gate when reached (GHC 9.14 bump, schema-migration automation, the Haskell extension DSL + AST checker + JIT, niche substrates incl. Windows-CUDA) | 📋 Planned | [later_phases](later_phases.md) |

The detailed objective, sprint breakdown, doctrine adoptions, and gate for each phase live in that phase's
own document (linked above); this tracker holds only the one-line gate and status. The standing rules a
reader needs are in [development_plan_standards.md](development_plan_standards.md); the architecture and
constraints behind them are in [overview.md](overview.md).

---

## Cross-references
- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
