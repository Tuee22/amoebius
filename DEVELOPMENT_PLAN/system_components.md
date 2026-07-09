# System Components

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, development_plan_standards.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_00_documentation_suite.md, phase_12_spa_composition_representational.md, phase_13_midwife_bootstrap_kind.md, phase_14_base_image_registry.md, phase_16_retained_storage.md, phase_17_vault_pki.md, phase_18_platform_services.md, phase_19_keycloak_ingress.md, phase_20_live_dsl_singleton.md, phase_21_app_tenancy.md, phase_22_pulsar_client.md, phase_23_content_store_workflow.md, phase_24_determinism_kernel.md, phase_25_jitbuild_engine_cache.md, phase_26_infernix_lift.md, phase_27_jitml_lift_cuda.md, phase_28_apple_metal_host_daemon.md, phase_29_multicluster_gateway_migration.md, phase_30_provider_clusters.md, phase_31_test_topology_dsl.md, phase_32_spa_live_deploy.md
**Generated sections**: none

> **Purpose**: The target component inventory for amoebius — every surface mapped to its owning doctrine, its
> planned Haskell module path, and the phase that builds it — honestly marked as intended layout, not
> existing code.

---

## How to read this inventory

This document is a **map of intent**, not a map of `src/`. The amoebius tree is greenfield: **nothing in the
tables below is built**. Every "Planned module path" is the *target* layout this plan commits to — the path a
sprint's `Implementation` field will name and that becomes concrete only when that sprint is ✅ Done
(`development_plan_standards.md` §F). Where this inventory leans on the sibling **prodbox** project for a
proven pattern, that is cited as *evidence* a shape works, never as amoebius proof.

The columns mean:

- **Component / Surface** — the named subsystem or behaviour.
- **Owning doctrine** — the single doctrine document (and section) that is the SSoT for *what the surface
  must be*. Every row's doctrine is cited by its human section name in the prose above its table, per the
  doctrine-citation rule (`development_plan_standards.md` §H).
- **Planned module path** — the intended Haskell module(s) / artifact(s). **PLANNED**: not yet built. Paths
  that carry a package prefix (`amoebius-pulsar/…`, `amoebius-store/…`, `amoebius-runtime/…`,
  `amoebius-pulumi/…`) live in their own cabal package; bare `src/Amoebius/…` paths live in the main
  `amoebius` package whose entrypoint is `app/amoebius/Main.hs`.
- **Phase** — the phase document that schedules the surface. Status for every surface is 📋 **Planned** until
  its phase gate runs on its substrate; this inventory carries no status of its own — status lives only in
  the phase docs and the [README.md](README.md) Phase Overview.

Status legend (full vocabulary in `development_plan_standards.md` §C): ✅ Done · 🔄 Active · 📋 Planned ·
⏸️ Blocked · 🧪 Live-proof-pending. **Pre-implementation, read every row as 📋 Planned.**

---

## 1. The single binary — three contexts

Everything amoebius does is the *same executable*; it merely *runs* three ways. This is owned by
[`daemon_topology_doctrine.md` §1 — One binary, three contexts](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts):
a CLI one-shot, a sudo-capable long-running host daemon, and an in-cluster pod. Which in-cluster role that
pod holds is split between
[`daemon_topology_doctrine.md` §3 — The control-plane singleton](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
(one Deployment-`replicas=1` brain with total cluster + secret authority, single-instance delegated to k8s/etcd) and
[`daemon_topology_doctrine.md` §4 — Worker daemons — N, unelected](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
(the N unelected workflow workers). The same-binary policy — one dependency closure, one config loader, one
error type, daemons-as-`Command` constructors — is generalized from prodbox's distributed-gateway
architecture as *evidence* the shape holds; amoebius proof is each phase's gate.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Executable entrypoint (argv dispatch, exit orchestration) | [daemon_topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts) | `app/amoebius/Main.hs` (PLANNED) | [phase_10_chain_kernel_dryrun.md](phase_10_chain_kernel_dryrun.md) |
| CLI context — `Command` ADT, `--help`, reconcile triggers, status | [daemon_topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts) | `src/Amoebius/Cli.hs` (PLANNED) | [phase_10_chain_kernel_dryrun.md](phase_10_chain_kernel_dryrun.md) |
| Sudo host-daemon context — distro bring-up, host-tool ensure, supervise host subprocesses | [daemon_topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts) | `src/Amoebius/Host/Context.hs` (PLANNED) | [phase_13_midwife_bootstrap_kind.md](phase_13_midwife_bootstrap_kind.md) |
| Long-running host compute daemon (the sudo-context daemon's worker form) | [daemon_topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts) | `src/Amoebius/HostWorker/Lifecycle.hs`, `src/Amoebius/HostWorker/Supervise.hs` (PLANNED) | [phase_28_apple_metal_host_daemon.md](phase_28_apple_metal_host_daemon.md) |
| In-cluster singleton — the control-plane brain, Deployment `replicas=1` (reconcile loop + secret authority) | [daemon_topology §3](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) | `src/Amoebius/Daemon/InClusterSingleton.hs`, `src/Amoebius/ControlPlane/Singleton.hs`, `src/Amoebius/ControlPlane/Reconcile.hs` (PLANNED) | [phase_20_live_dsl_singleton.md](phase_20_live_dsl_singleton.md) |
| Bootstrap sequence + host→singleton handoff + admin control-plane REST (`vault init/unseal`, `dhall update`) | [bootstrap_sequence_doctrine](../documents/engineering/bootstrap_sequence_doctrine.md) | `src/Amoebius/Cluster/BringUp.hs`, `src/Amoebius/ControlPlane/AdminApi.hs` (PLANNED; sequence+handoff Phase 13, admin REST Phase 20) | [phase_13_midwife_bootstrap_kind.md](phase_13_midwife_bootstrap_kind.md) |
| In-cluster worker roles — N unelected workflow daemons | [daemon_topology §4](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected) | `amoebius-runtime/src/Amoebius/Workflow/Worker.hs`, `amoebius-runtime/src/Amoebius/Workflow/Orchestrator.hs` (PLANNED) | [phase_23_content_store_workflow.md](phase_23_content_store_workflow.md) |

---

## 2. The DSL — Dhall decoder + chain/Step kernel

The DSL is a hard split between two languages, owned by
[`dsl_doctrine.md` §2 — Two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
Dhall is typed, total, side-effect-free *data*; Haskell is the *logic*, adopting hostbootstrap's chain/Step
algebra. The composability guarantee — fragments nest without limit or leakage — is owned by
[`dsl_doctrine.md` §4 — Total composability](../documents/engineering/dsl_doctrine.md#4-total-composability),
and the second of the two typed gates (the one that turns Dhall into Haskell values) is
[`dsl_doctrine.md` Gate 2 — the Haskell typed decoder](../documents/engineering/dsl_doctrine.md#gate-2--the-haskell-typed-decoder).
The kernel itself — the `Step` algebra and `chain :: cfg -> [Step]` — is seeded from hostbootstrap in
Phase 10 and is the spine every later phase composes onto.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| `Step` algebra (the unit of idempotent work) | [dsl_doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) | `src/Amoebius/Kernel/Step.hs` (PLANNED) | [phase_10_chain_kernel_dryrun.md](phase_10_chain_kernel_dryrun.md) |
| `chain` combinator (`cfg -> [Step]`, total composition) | [dsl_doctrine §4](../documents/engineering/dsl_doctrine.md#4-total-composability) | `src/Amoebius/Kernel/Chain.hs` (PLANNED) | [phase_10_chain_kernel_dryrun.md](phase_10_chain_kernel_dryrun.md) |
| Dhall surface types (cluster / app-spec / deployment-rules) | [dsl_doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) | `dhall/amoebius/{Cluster,App,Deployment,prelude}.dhall` (PLANNED) | [phase_04_dhall_gate1_schema.md](phase_04_dhall_gate1_schema.md) |
| Haskell typed decoder (Gate 2) | [dsl_doctrine Gate 2](../documents/engineering/dsl_doctrine.md#gate-2--the-haskell-typed-decoder) | `src/Amoebius/Dsl/Decode.hs`, `src/Amoebius/Dsl/Types.hs` (PLANNED) | [phase_05_gadt_decoder_gate2.md](phase_05_gadt_decoder_gate2.md) |
| Smart constructors (illegal-state-unrepresentable values; incl. compatible-pair `Node`, derived `Toleration`) | [dsl_doctrine §4](../documents/engineering/dsl_doctrine.md#4-total-composability) | `src/Amoebius/Dsl/SmartConstructors.hs` (PLANNED) | [phase_04_dhall_gate1_schema.md](phase_04_dhall_gate1_schema.md) |
| `Readiness` gate (condition-not-duration `Step` edge, no `AfterDuration` arm; derived bring-up DAG + `mkBringUpOrder` fold) | [readiness_ordering_doctrine §3](../documents/engineering/readiness_ordering_doctrine.md#3-readiness-is-a-condition-never-a-duration) | `src/Amoebius/Kernel/Readiness.hs`, `src/Amoebius/Cluster/BringUp.hs` (PLANNED; bootstrap-tier `discover`/`RuntimeWitness` gates Phase 13) | [phase_10_chain_kernel_dryrun.md](phase_10_chain_kernel_dryrun.md) |
| Cluster-topology types (`ComputeEngine` / `LinuxHost` witness / `Topology`; §4.7 relation) | [cluster_topology_doctrine](../documents/engineering/cluster_topology_doctrine.md) | `dhall/amoebius/Topology.dhall`, `src/Amoebius/Dsl/Topology.hs` (PLANNED) | [phase_07_capacity_topology_folds.md](phase_07_capacity_topology_folds.md) |
| Capacity accounting (`Capacity`/`Demand`/`Budget`, §4.6 `fits`/`carve`/`place`, `Growable`/`ScalingPolicy`) | [resource_capacity_doctrine](../documents/engineering/resource_capacity_doctrine.md) | `dhall/amoebius/Capacity.dhall`, `src/Amoebius/Capacity/{Types,Fold,Growable}.hs` (PLANNED; enaction Phase 30) | [phase_07_capacity_topology_folds.md](phase_07_capacity_topology_folds.md) |
| Bounded-storage surface (`StorageBacking` union, `RetentionPolicy`) | [storage_lifecycle §5.2](../documents/engineering/storage_lifecycle_doctrine.md), [pulsar_client §6.1](../documents/engineering/pulsar_client_doctrine.md) | `dhall/amoebius/{Storage,Retention}.dhall` (PLANNED) | [phase_04_dhall_gate1_schema.md](phase_04_dhall_gate1_schema.md) |

---

## 3. Manifests — typed renderer + the SSA reconciler

Types render Kubernetes manifests; Helm does not. The renderer is the pure, total function owned by
[`manifest_generation_doctrine.md` §2 — The typed manifest model: `render` is a pure, total function to objects](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
`render :: ServiceSpec -> [K8sObject]`, each object a typed Haskell record serialized via Aeson — the record
*is* the manifest. Making the cluster match that object set idempotently is owned by
[`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: server-side apply, owned field manager, prune, wait](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
server-side apply under a fixed `amoebius` field manager, ApplySet prune, wait-for-ready — run only by the
control-plane singleton (§1), never by a CLI poke racing another writer.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Typed `K8sObject` model (records for Deployment/StatefulSet/Service/RBAC/NetworkPolicy/HTTPRoute/…) | [manifest_generation §2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects) | `src/Amoebius/Manifest/Types.hs` (PLANNED) | [phase_09_render_manifest_goldens.md](phase_09_render_manifest_goldens.md) |
| `render` — pure, total `ServiceSpec -> [K8sObject]` | [manifest_generation §2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects) | `src/Amoebius/Manifest/Render.hs` (PLANNED) | [phase_09_render_manifest_goldens.md](phase_09_render_manifest_goldens.md) |
| SSA reconciler (`amoebius` field manager, ApplySet prune, wait) | [manifest_generation §5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait) | `src/Amoebius/Manifest/Reconcile.hs` (PLANNED) | [phase_15_renderer_reconciler.md](phase_15_renderer_reconciler.md) |

---

## 4. Capabilities — the capability→provider→shape binder

Application logic names *capabilities* (an `ObjectStore`, a `Sql` database, a set of `MessageBus` topics);
deployment rules bind the provider and the per-cluster shape. The three-part binding is owned by
[`service_capability_doctrine.md` §4 — Capability → provider → shape: the binding](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding):
the capability is the app's travelling identity, the provider defaults to the canonical platform service, and
the shape (single-node vs distributed, replica counts, the structural object graph) is a deployment-rules
edit. The binder turns a named capability + a provider + a shape into the `ServiceSpec` the §3 renderer
consumes.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Capability union + binding records (Dhall surface) | [service_capability §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | `dhall/amoebius/Capability.dhall` (PLANNED) | [phase_08_capability_binder.md](phase_08_capability_binder.md) |
| Capability→provider→shape binder (capability need ⇒ `ServiceSpec`) | [service_capability §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | `src/Amoebius/Capability/Binding.hs` (PLANNED) | [phase_08_capability_binder.md](phase_08_capability_binder.md) |
| Per-app tenancy (own namespace, `<app>/<bucket>` ObjectStore, in-namespace Sql) | [service_capability §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | `src/Amoebius/App/Tenancy.hs` (PLANNED) | [phase_21_app_tenancy.md](phase_21_app_tenancy.md) |

---

## 5. Platform services — baked binaries + the `distribution` registry

Every cluster is the same cluster: the standard services come up identically on every substrate, owned by
[`platform_services_doctrine.md` §1 — The Invariant: every cluster is the same cluster](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster).
The in-cluster registry that every workload pulls from is the single-binary `distribution`, replacing Harbor,
owned by
[`platform_services_doctrine.md` §3 — The registry — the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source).
None of these services is pulled from a public registry: each third-party binary is **baked** into the
multi-arch base image, owned by
[`image_build_doctrine.md` §2 — The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster).
Each service below is rendered by the §3 typed renderer and applied by the §3 reconciler — these module paths
are the per-service spec builders, not the providers' own binaries (those are baked; see §9).

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Platform-service orchestration (bring-up order, dependency graph) | [platform_services §1](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster) | `src/Amoebius/Platform/Services.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| `distribution` registry (the sole image source) | [platform_services §3](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source) | `src/Amoebius/Image/Registry.hs` (PLANNED) | [phase_14_base_image_registry.md](phase_14_base_image_registry.md) |
| MinIO — object substrate | [platform_services §1](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster) | `src/Amoebius/Platform/Minio.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| Pulsar — event/workflow backbone (server-side render) | [platform_services §1](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster) | `src/Amoebius/Platform/Pulsar.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| Postgres — Patroni-via-Percona, per-consumer, pgAdmin | [platform_services §8 — Postgres](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin) | `src/Amoebius/Platform/Postgres.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| Prometheus / Grafana — observability | [platform_services §1](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster) | `src/Amoebius/Platform/Observability.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| LoadBalancer (MetalLB-or-cloud, the one substrate-driven difference) | [platform_services §9 — The LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) | `src/Amoebius/Platform/LoadBalancer.hs` (PLANNED) | [phase_18_platform_services.md](phase_18_platform_services.md) |
| Keycloak owning all wild ingress (via Gateway API / Envoy) | [platform_services §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) | `src/Amoebius/Platform/Keycloak.hs`, `src/Amoebius/Platform/Edge.hs` (PLANNED) | [phase_19_keycloak_ingress.md](phase_19_keycloak_ingress.md) |

---

## 6. The native Pulsar client — `amoebius-pulsar`

There is exactly one way to talk to Pulsar: a native-protocol Haskell library speaking Pulsar's TCP binary
protocol — no WebSockets, no fallback — owned by
[`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets).
It starts as a fork of `cr-org/supernova`, inheriting the handshake / LOOKUP / produce / consume foundation
and adding the production concerns, per
[`pulsar_client_doctrine.md` §4 — Forked from supernova — what amoebius inherits and what it builds](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-amoebius-inherits-and-what-it-builds).
Its capability surface — lookup, produce, consume, subscribe, seek — is owned by
[`pulsar_client_doctrine.md` §5 — The capability surface: lookup · produce · consume · subscribe · seek](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek).
This is the `amoebius-pulsar` package, distinct from the §5 `Platform/Pulsar.hs` *spec builder* that renders
the broker into the cluster.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Wire framing / binary protocol (forked `proto-lens` `PulsarApi`) | [pulsar_client §3 / §4](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-amoebius-inherits-and-what-it-builds) | `amoebius-pulsar/src/Amoebius/Pulsar/Frame.hs`, `amoebius-pulsar/src/Amoebius/Pulsar/Proto/PulsarApi.hs` (PLANNED) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |
| Connection / CONNECT handshake / LOOKUP discovery | [pulsar_client §4](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-amoebius-inherits-and-what-it-builds) | `amoebius-pulsar/src/Amoebius/Pulsar/Connection.hs` (PLANNED) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |
| Producer / Consumer / Subscription / Seek | [pulsar_client §5](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek) | `amoebius-pulsar/src/Amoebius/Pulsar/{Producer,Consumer,Subscription,Seek}.hs` (PLANNED) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |
| CBOR payload codec (exclusively CBOR bodies; `serialise`/`cborg`; canonical where content-addressed) | [pulsar_client §3.1](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor), [illegal_state_catalog §3.23](../documents/illegal_state/illegal_state_catalog.md) | `amoebius-pulsar/src/Amoebius/Pulsar/Cbor.hs` (PLANNED; `serialise`/`cborg` dep in the `amoebius-pulsar` cabal package) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |
| Broker-side dedup wiring + declarative topology algebra | [pulsar_client §6 — The declarative topology algebra](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra) | `amoebius-pulsar/src/Amoebius/Pulsar/{Dedup,Topology,Namespace}.hs` (PLANNED) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |
| Topic storage lifecycle (retention + size-triggered offload + backlog quota reconcile) | [pulsar_client §6.1](../documents/engineering/pulsar_client_doctrine.md), [resource_capacity §7](../documents/engineering/resource_capacity_doctrine.md) | `amoebius-pulsar/src/Amoebius/Pulsar/Retention.hs` (PLANNED) | [phase_22_pulsar_client.md](phase_22_pulsar_client.md) |

---

## 7. The content-addressed store + determinism kernel

The store is three tiers — blobs ← manifests ← pointers — with write-once content-addressed blobs/manifests
and a single ETag-CAS pointer flip, owned by
[`content_addressing_doctrine.md` §2 — The three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers).
Identity is `experimentHash = sha256(resolved-dhall ‖ substrate-fingerprint)` and determinism is built from
pinned inputs + pure stages + a derived seed, owned by
[`content_addressing_doctrine.md` §3 — `experimentHash`: identity is *what was requested* ‖ *where it ran*](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
and
[`content_addressing_doctrine.md` §4 — Determinism by construction: pinned inputs + pure stages + derived seed](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed).
The store object lands in Phase 23 (the `amoebius-store` package); the determinism kernel primitives land in
Phase 24 (in the main `amoebius` package's `Kernel/`).

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Content-addressed blob/manifest writer (write-once, self-naming) | [content_addressing §2](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers) | `amoebius-store/src/Amoebius/Store/ContentAddress.hs`, `amoebius-store/src/Amoebius/Store/Manifest.hs` (PLANNED) | [phase_23_content_store_workflow.md](phase_23_content_store_workflow.md) |
| Pointer tier (ETag-CAS `latest`/`best`/`trial` flip) | [content_addressing §2](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers) | `amoebius-store/src/Amoebius/Store/Pointer.hs` (PLANNED) | [phase_23_content_store_workflow.md](phase_23_content_store_workflow.md) |
| `ContentAddress` typeclass (determinism kernel primitive) | [content_addressing §4](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed) | `src/Amoebius/Kernel/ContentAddress.hs` (PLANNED) | [phase_24_determinism_kernel.md](phase_24_determinism_kernel.md) |
| `experimentHash` + SplitMix seed derivation | [content_addressing §3](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran) | `src/Amoebius/Kernel/ExperimentHash.hs`, `src/Amoebius/Kernel/Rng.hs` (PLANNED) | [phase_24_determinism_kernel.md](phase_24_determinism_kernel.md) |

---

## 8. Vault, secrets & PKI

Secrets are names in the DSL, never values: a sensitive field is a typed `SecretRef`, owned by
[`vault_pki_doctrine.md` §3 — The SecretRef contract: a name, never a value](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value).
The root cluster runs a single-node, password-encrypted, human-gated Vault — the prodbox root behaviour,
cited as *evidence* — owned by
[`vault_pki_doctrine.md` §5 — The root cluster: single-node, password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal).
The forest's one self-signed trust anchor sits at the root and issues down the tree, owned by
[`vault_pki_doctrine.md` §8 — The root cluster owns the PKI trust anchor](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor).

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| Root Vault init (single-node, password-encrypted, fail-closed) | [vault_pki §5](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal) | `src/Amoebius/Vault/Init.hs` (PLANNED) | [phase_17_vault_pki.md](phase_17_vault_pki.md) |
| Unseal (root human-gated; parent/child later) | [vault_pki §5](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal) | `src/Amoebius/Vault/Unseal.hs` (PLANNED) | [phase_17_vault_pki.md](phase_17_vault_pki.md) |
| Root PKI trust anchor (root CA + intermediate issuance) | [vault_pki §8](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor) | `src/Amoebius/Vault/Pki.hs` (PLANNED) | [phase_17_vault_pki.md](phase_17_vault_pki.md) |
| `SecretRef` typed surface (names, never values) | [vault_pki §3](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) | `dhall/amoebius/Capability.dhall` + `src/Amoebius/Dsl/Types.hs` (PLANNED) | [phase_04_dhall_gate1_schema.md](phase_04_dhall_gate1_schema.md) |

---

## 9. Substrate tool-ensure + base-image build

amoebius never reads an environment variable — including `PATH` — and resolves every host tool by absolute
path through the substrate's package manager, owned by
[`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract).
The single shell script amoebius owns — ensure a toolchain, build the binary, hand off — is owned by
[`substrate_doctrine.md` §6 — The midwife contract](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off).
The base image carrying every baked third-party binary (apt → official binary → build-from-source, plus a
Temurin JRE for the JVM services) is owned by
[`image_build_doctrine.md` §7 — What amoebius bakes vs builds — the base container is the supply chain](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain).

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| The `pb` midwife CLI (ensure toolchain, build binary, hand off) | [substrate §6](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) | `pb` Python CLI (PLANNED) | [phase_13_midwife_bootstrap_kind.md](phase_13_midwife_bootstrap_kind.md) |
| Substrate detection (pure classify over three reads) | [substrate §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) | `src/Amoebius/Host/Substrate.hs` (PLANNED) | [phase_13_midwife_bootstrap_kind.md](phase_13_midwife_bootstrap_kind.md) |
| Lazy tool-ensure (probe → install → resolve abs path → invoke) | [substrate §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) | `src/Amoebius/Host/HostTool.hs`, `src/Amoebius/Host/Ensure.hs` (PLANNED) | [phase_13_midwife_bootstrap_kind.md](phase_13_midwife_bootstrap_kind.md) |
| Virtualized-substrate management (Lima / brew on Apple) | [substrate §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) | `src/Amoebius/Substrate/{Apple,Lima,Brew}.hs` (PLANNED) | [phase_28_apple_metal_host_daemon.md](phase_28_apple_metal_host_daemon.md) |
| Apple-Metal headless build/run (fixed `/usr/bin/clang` Metal bridge + runtime MSL, **no Tart/VM**) | [apple_metal_headless_builds](../documents/engineering/apple_metal_headless_builds.md) | `src/Amoebius/HostWorker/MetalBridge.hs`, `src/Amoebius/HostWorker/AppleMetalBuild.hs` (PLANNED) | [phase_28_apple_metal_host_daemon.md](phase_28_apple_metal_host_daemon.md) |
| Multi-arch base-image build (bake binaries, buildx `amd64`/`arm64`) | [image_build §7](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | `docker/base/Dockerfile`, `src/Amoebius/Image/Build.hs` (PLANNED) | [phase_14_base_image_registry.md](phase_14_base_image_registry.md) |

---

## 10. Pulumi backend (IaC)

Pulumi runs only from inside an existing amoebius cluster, owned by
[`pulumi_iac_doctrine.md` §1 — Pulumi runs only from inside an existing amoebius cluster](../documents/engineering/pulumi_iac_doctrine.md#1-pulumi-runs-only-from-inside-an-existing-amoebius-cluster).
Every byte of its checkpoint is a Vault-Transit-enveloped object in MinIO, owned by
[`pulumi_iac_doctrine.md` §2 — The backend: every byte of state is a Vault-enveloped object in MinIO](../documents/engineering/pulumi_iac_doctrine.md#2-the-backend-every-byte-of-state-is-a-vault-enveloped-object-in-minio).
What it provisions — provider clusters, node groups, per-PV EBS sized to its PVC — is owned by
[`pulumi_iac_doctrine.md` §4 — What Pulumi provisions (the resource catalog)](../documents/engineering/pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog).
The engine and EBS programs land with provider clusters in Phase 30; multi-cluster child-spawn keying
(Phase 29 — see [phase_29_multicluster_gateway_migration.md](phase_29_multicluster_gateway_migration.md)) reuses the same backend.

| Component / Surface | Owning doctrine | Planned module path | Phase |
|---|---|---|---|
| In-cluster Pulumi engine seam (under the singleton) | [pulumi_iac §1](../documents/engineering/pulumi_iac_doctrine.md#1-pulumi-runs-only-from-inside-an-existing-amoebius-cluster) | `amoebius-pulumi/src/Amoebius/Pulumi/Engine.hs` (PLANNED) | [phase_30_provider_clusters.md](phase_30_provider_clusters.md) |
| Vault-enveloped MinIO state backend | [pulumi_iac §2](../documents/engineering/pulumi_iac_doctrine.md#2-the-backend-every-byte-of-state-is-a-vault-enveloped-object-in-minio) | `src/Amoebius/Pulumi/Backend/EncryptedMinio.hs` (PLANNED) | [phase_30_provider_clusters.md](phase_30_provider_clusters.md) |
| Resource provisioning (provider cluster, node groups, EBS, teardown) | [pulumi_iac §4](../documents/engineering/pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog) | `amoebius-pulumi/src/Amoebius/Pulumi/{Ebs,NodeGroup,Teardown}.hs`, `src/Amoebius/Pulumi/Provider/Eks.hs` (PLANNED) | [phase_30_provider_clusters.md](phase_30_provider_clusters.md) |
| EBS create-vs-delete credential model | [pulumi_iac §6 — The EBS create-vs-delete credential model](../documents/engineering/pulumi_iac_doctrine.md#6-the-ebs-create-vs-delete-credential-model) | `src/Amoebius/Pulumi/Credential.hs` (PLANNED) | [phase_30_provider_clusters.md](phase_30_provider_clusters.md) |

---

## 11. The pre-cluster (Register 1–2) design-first validation surface

The **pre-cluster band (phases 1–12, substrate `none`)** discharges the suite's design-time / in-process
integrity — that the spec composes, renders coherently, and the one protocol obligation is sound in the
abstract — before any real resource exists (Registers 1–2,
[`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md)). It proves the
DSL's illegal-state-unrepresentable **type discipline** (Dhall Gate 1 `dhall type` + the Haskell decoder Gate 2
+ QuickCheck), the **rendered-output** correctness (a pure `render` byte-for-byte golden-locked), the
**SPA-composition** representational validity, and the cross-cluster **gateway-migration** design invariants
for **both** branches — the reifiable Haskell `Model` rendered to a generated `.tla` and model-checked by TLC,
plus an io-sim schedule check. The model-as-data pattern is owned by
[`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md); the one obligation by
[`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md); the DSL
gates by [`dsl_doctrine.md` Gate 2](../documents/engineering/dsl_doctrine.md#gate-2--the-haskell-typed-decoder);
the foreclosure layers + validation-locus by
[`illegal_state_catalog.md` §6](../documents/illegal_state/illegal_state_catalog.md).

> **Generated, never committed.** The `.tla`/`.cfg`, the reflected Dhall schema, the rendered manifests, and
> the PureScript contracts are **emitted from a Haskell source of truth and never committed**
> ([`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)); the
> committed module path is the Haskell source (the `Model`, the decoder, `render`), not the emitted artifact.
> Most rows below **also appear at their live build phase** (Register 3) — registering them here at their
> design-first phase is deliberate register bookkeeping, not a second owner.

> **Honesty — design-time, never runtime.** A green Dhall typecheck, a green decoder, a green QuickCheck, a
> byte-for-byte render golden, or a TLC run that reaches every invariant at scope is a **design/spec-layer**
> result — *proven for the model at scope* / type- or decode-foreclosed / tested-and-sampled — and **never** a
> runtime guarantee. Correspondence-to-built-code and runtime enforcement stay **UNVERIFIED** until each
> surface's Register-3 phase, and a Register-1/2 in-process ledger is structurally insufficient to advance a
> production PromotionGate.

| Component / Surface | Owning doctrine | Planned module path (source; emitted artifacts not committed) | Phase |
|---|---|---|---|
| Formal-model EDSL (`Model` → `interpret` runtime fn + `emitTLA` generated `.tla`) | [formal_model_doctrine](../documents/engineering/formal_model_doctrine.md) | `src/Amoebius/Formal/{Model,Interpret,EmitTLA}.hs` (the `.tla`/`.cfg` are generated, not committed) | [phase_02](phase_02_formal_model_kernel.md) |
| Gateway-migration **design model**, both branches (TLC `UniqueGatewayOwner` / `SessionAlwaysRebindable` / `PlannedIsLossless` / `FailoverBounded`; proven-for-the-model at scope, cutoff) + io-sim | [gateway_migration_model_doctrine](../documents/engineering/gateway_migration_model_doctrine.md) | `src/Amoebius/Multicluster/{Model,GatewayDecision}.hs`, `test/formal/*` (generated `spec/tla/*.tla` not committed) | [phase_03](phase_03_gateway_migration_model.md) |
| Dhall schema **type discipline** (Gate 1 `dhall type`; illegal-state-unrepresentable surface) | [dsl_doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic), [illegal_state_catalog §6](../documents/illegal_state/illegal_state_catalog.md) | `dhall/amoebius/*.dhall` (authored) + the schema reflected from `src/Amoebius/Dsl/Types.hs` (generated) | [phase_04](phase_04_dhall_gate1_schema.md) |
| GADT IR + total decoder + smart constructors (Gate 2 + QuickCheck) | [dsl_doctrine Gate 2](../documents/engineering/dsl_doctrine.md#gate-2--the-haskell-typed-decoder) | `src/Amoebius/Dsl/{Types,Decode,SmartConstructors}.hs` | [phase_05](phase_05_gadt_decoder_gate2.md) |
| Illegal-state corpus + property tests + validation-locus ledger | [illegal_state_catalog §6](../documents/illegal_state/illegal_state_catalog.md) | `test/dsl/*`, `dhall/examples/{legal_*,illegal_*}.dhall` | [phase_06](phase_06_illegal_state_corpus.md) |
| Capacity / topology folds (`fits` / `carve` / `place` properties) | [resource_capacity_doctrine](../documents/engineering/resource_capacity_doctrine.md) | `src/Amoebius/Capacity/*` | [phase_07](phase_07_capacity_topology_folds.md) |
| Capability → provider → shape binder (capability need ⇒ `ServiceSpec`, type-level) | [service_capability §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | `src/Amoebius/Capability/Binding.hs` | [phase_08](phase_08_capability_binder.md) |
| Pure `render` + rendered-output goldens (hardened context / derived NetworkPolicy / no backdoor ingress) | [manifest_generation §2/§3](../documents/engineering/manifest_generation_doctrine.md) | `src/Amoebius/Manifest/{Types,Render}.hs` (the rendered manifests are generated, not committed) | [phase_09](phase_09_render_manifest_goldens.md) |
| chain/Step kernel + `--dry-run` plan render | [dsl_doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) | `src/Amoebius/Kernel/{Step,Chain}.hs` | [phase_10](phase_10_chain_kernel_dryrun.md) |
| SPA composition (representational) + PureScript demo SPA | [lift_and_compose](../documents/engineering/lift_and_compose_doctrine.md) | `src/Amoebius/Spa/*`, `web/` (the PureScript contracts are generated, not committed) | [phase_12](phase_12_spa_composition_representational.md) |

---

## Related Documents

- [README.md](README.md) — the live tracker and Phase index this inventory's rows point into
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (§F `Implementation`, §H doctrine-citation, §K honesty) this inventory obeys
- [overview.md](overview.md) — the target architecture narrative behind these components
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [Daemon Topology](../documents/engineering/daemon_topology_doctrine.md) — the one-binary / three-context owner
- [The Amoebius DSL](../documents/engineering/dsl_doctrine.md) — the Dhall-data / Haskell-logic split and chain/Step kernel owner
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — the `ComputeEngine`/`Topology` types owner
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the capacity fold + `StorageBudget`/`Growable` owner
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the renderer and SSA reconciler owner
- [Service Capabilities](../documents/engineering/service_capability_doctrine.md) — the capability→provider→shape binding owner
- [Platform Services](../documents/engineering/platform_services_doctrine.md) — the standard-services-every-cluster owner
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binaries and `distribution` registry owner
- [The Native Pulsar Client](../documents/engineering/pulsar_client_doctrine.md) — the `amoebius-pulsar` owner
- [Content Addressing & Determinism](../documents/engineering/content_addressing_doctrine.md) — the three-tier store and determinism kernel owner
- [Vault, PKI & Secret Injection](../documents/engineering/vault_pki_doctrine.md) — the secrets root and PKI trust anchor owner
- [Substrates](../documents/engineering/substrate_doctrine.md) — the tool-ensure and midwife CLI owner
- [Pulumi IaC](../documents/engineering/pulumi_iac_doctrine.md) — the Pulumi backend owner
