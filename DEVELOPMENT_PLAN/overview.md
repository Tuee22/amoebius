# Amoebius Overview

> **Purpose**: The target-architecture / vision / current-baseline narrative — the "why and what" companion
> to [README.md](README.md)'s "where and when" — for the everything-orchestrator amoebius is becoming.
> **Read this if**: the shape of the whole system has to be understood before any single phase or doctrine makes sense.

This document is the narrative entry point to amoebius: what it is, what it is assembled from, and the
constraints every phase upholds. It owns the target-architecture narrative and the invariant set; it owns no
phase status, which belongs to [README.md](README.md), and no subsystem doctrine, which belongs to the
document each invariant cites. It presumes nothing.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents

- [1. The everything-orchestrator shape: one runtime binary, three contexts](#1-the-everything-orchestrator-shape-one-runtime-binary-three-contexts)
- [2. The seed projects: reference implementations amoebius re-derives from](#2-the-seed-projects-reference-implementations-amoebius-re-derives-from)
- [3. The hard constraints (cross-cutting invariants)](#3-the-hard-constraints-cross-cutting-invariants)
- [4. The phase index (one line per phase)](#4-the-phase-index-one-line-per-phase)
- [5. Reset baseline and live status authority](#5-reset-baseline-and-live-status-authority)
- [Related Documents](#related-documents)

This document explains *what amoebius is and why it is shaped that way*. It does not track status, order, or
remaining work — that is [README.md](README.md)'s job, and per
[development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed) status lives **only** in the plan tracker.
The doctrine under [`../documents/engineering/`](../documents/engineering/README.md) owns the normative
detail of each subsystem; this overview summarizes and links, and **never restates** doctrine content
([documentation_standards.md §5](../documents/documentation_standards.md#5-duplication-rules)). This document is the target-architecture companion to that grand, non-binding
vision; the plan specifies the required decomposition. Haskell owns executable acceptance contracts.

> **Reopened implementation, read this first.** Source and tests exist, but the
> [generation-2 reset](README.md#generation-2-reset) withdraws every generation-1 certification, so a phase
> status in this document's prose would go stale the moment it was written. [README.md](README.md)'s tracker is
> the sole record of which phase is where
> ([development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary)); read it, not a
> summary of it. Every prescriptive sentence remains design intent until the complete qualified phase gate
> passes and the human records it with one `accept`. A component diagnostic alone is never sufficient. Where
> this overview leans on the sibling `prodbox` project, that is cited as *evidence* that a shape works — never
> as amoebius proof.

## 1. The everything-orchestrator shape: one runtime binary, three contexts

amoebius has one Haskell runtime binary that runs in three contexts from the same build artifact. The bounded
Python `pb` pre-binary handoff exists only to make the minimum platform-adapter distinction, establish the
contained Haskell toolchain, build that binary, and exec it with argv unchanged; it is outside this
runtime-role count, is not the Haskell `BootstrapCoordinator`, and owns no public-command, post-handoff
product, or validation decision:

1. a one-shot **Haskell command mode** on the operator's host, normally entered by `pb` during bootstrap,
2. a **sudo-capable host daemon** that owns substrate detection, lazy tool-ensure, and host-level worker
   subprocesses, and
3. an **in-cluster pod/process context** in which the executable runs as the control-plane daemon, the
   capacity scheduler, or an unelected worker. The control-plane daemon is one Kubernetes Deployment `replicas=1` with
   cluster/secret authority and a mandatory Kubernetes `Lease`; UI webservers and projection workers are
   separate horizontally scalable worker Deployments.

There is no second Haskell runtime executable, no runtime sidecar fleet, and no shell-glue control plane:
context is a runtime fact, and *role* is orthogonal to context. Both reach a running copy as one decoded
`Process` value on its frame config — never as the identity of the file that was executed, never from argv
sniffing, and never from the environment. This is the doctrine of
[`daemon_topology_doctrine.md` §1 — one runtime binary, three contexts](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts).
The cluster authority is one Deployment-`replicas=1` pod, reconciled with the common HA-capable topology rule
(one replica has restart semantics, not replica redundancy), per
[`daemon_topology_doctrine.md` §3 — The control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon):
"one desired pod" is a Deployment property, while the mandatory k8s/etcd `Lease` supplies at-most-one-writer
authority across termination/replacement overlap; this is **not** an amoebius election. The pod is stateless —
no PVC; its durable state is the Vault-enveloped MinIO bucket. A distinct `amoebius-capacity` scheduler
Deployment runs the same Haskell binary in its scheduler role, consumes only its named Pending Pods, performs
the sealed placement/root-ledger CAS/Binding protocol, and holds no control-plane daemon or secret authority.
The low-code UI server is another closed **worker responsibility** of that executable, paired with a generic
PureScript browser interpreter and an owner-scoped projection worker; it is not another privileged binary or
application-specific server build. Browser interaction uses authenticated same-origin WebSockets; the
replicated UI-server workers use the platform's ephemeral Redis coordination service to route connections and
fanout across pods, while Pulsar/projection/provider state remains authoritative
([`ui_realtime_coordination_doctrine.md`](../documents/engineering/ui_realtime_coordination_doctrine.md)).

```mermaid
flowchart TD
%% register: orientation
  src[One Haskell binary] --> cli[CLI context: operator host]
  src --> host[Sudo host daemon: substrate detect, lazy tool-ensure, host workers]
  src --> pod[In-cluster pod context]
  pod --> daemon[Control-plane daemon role: Deployment replicas 1, single-instance from k8s and etcd]
  pod --> sched[Capacity scheduler role: same binary, dedicated Deployment]
  pod --> ui[UI server and projection worker roles: same binary, replicated and least authority]
  host --> kube[kube-apiserver via distro mTLS, localhost only]
  control-plane daemon --> recon[Typed reconciler: observe, bind/provision, renderAll, enact typed actions]
  sched --> bind[Sealed placement, aggregate CAS ledger, Kubernetes Binding]
  ui --> redis[Redis: ephemeral cross-pod WebSocket routing]
```
*Orientation. Design intent. One binary, three contexts, and the roles the in-cluster context selects; the grid is owned by [daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid). None of it is built.*

The host daemon reaches the cluster only over localhost-restricted channels (kube-apiserver via the distro's
own mTLS, and Pulsar/MinIO over host-only NodePorts), never the public ingress path — see
[`host_cluster_comms_doctrine.md` §1 — The whole surface: two channels, both localhost-only](../documents/engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only).

## 2. The seed projects: reference implementations amoebius re-derives from

**amoebius absorbs nothing, and depends on nothing.** The five projects below are **seed projects**: reference
implementations that are authoritative about what their domain requires and about none of the solution.
amoebius takes no dependency on any of them and none depends on amoebius, so each remains an independent
observation rather than a component. What amoebius does instead is **re-derive** their pure structures under
stronger obligations, and a re-derivation is admissible only once the doctrine specifying it names, in one
sentence, the guarantee amoebius adds that the seed's version does not carry
([`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md)). The table below
therefore reads as a map of *what amoebius re-derives from where*, never as a list of parts being assembled:

| Project | Becomes | Role under the DSL |
|---------|---------|--------------------|
| **prodbox** | root control-plane behaviour | the single-node root cluster: password-encrypted Vault unseal, PKI trust anchor, the human-gated init — see [`vault_pki_doctrine.md` §5 — The root cluster: single-node, password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal) |
| **infernix** + **jitML** | ML extension libraries | shared inference/training libraries whose hardware substrate is a *deployment rule*, not app code — [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library; the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule); jitML is the seed of the forward-looking Haskell extension DSL noted in [`dsl_doctrine.md` §8](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-extension-astcheck-admits) |
| **hostbootstrap** | bootstrap + DSL-`chain` core | the bounded Python `pb` pre-binary handoff (minimal platform adapter selection, contained toolchain establishment, source-bound build, unchanged-argv exec) plus the Haskell `dsl-step`/`chain` kernel — [`substrate_doctrine.md` §6 — The pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract) |

Each of **infernix** and **jitML** additionally ships a handwritten demo single-page app in its sibling repo.
Those clients are evidence and migration fixtures, not the amoebius application model: their interaction flows
are re-expressed as bounded `UiSource`, bound to trusted Haskell workflow/artifact ports, and interpreted by the
generic client/server runtime. The program contains no arbitrary browser code, provider address, credential,
authorization decision, tenant claim, or deployment knob — see
[`app_vs_deployment_doctrine.md` §6 — The proof case: a low-code workflow UI as application-logic-only](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only).

Their shared execution path is fixed: a UI server admits a typed start under one scope-qualified `CommandId`;
the infernix/jitML adapter preserves it as the Phase-69 work-id through native-CBOR Pulsar commands, redelivery,
progress, and terminal events; the effect owner commits the artifact and Phase 70 folds the terminal event into
a durable owner/command-qualified receipt. Redis only wakes or routes to the replica owning the authenticated
WebSocket, and any replica repairs loss from the Pulsar-backed projection/receipt. For the initial offline
surface, only infernix workflow start and jitML training start may opt into a complete bounded queue contract;
progress is a cached cursor projection, and signals, cancellation, and model/artifact invocation are
online-only.

The unifying surface is the Haskell-authored DSL: Haskell carries both the authoritative types and logic, and
an app names
*capabilities* (ObjectStore, Sql, MessageBus, …) rather than products — see
[`service_capability_doctrine.md` §1 — Why capabilities, not products](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)
and [`service_capability_doctrine.md` §2 — The capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set).

**Convergence stance.** The sibling projects are **frozen typed evidence** that a shape works, not lockstep
peers to track: amoebius lifts each sibling's *role* onto its own seams and reimplements nothing
([`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md)), while what stops being
carried forward is recorded in typed Haskell migration bindings and explained in
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md). infernix and
jitML join as the closed **workload-extension set** linked into trusted runtime variants — never a migration
through hostbootstrap first — with their engines jit-resolved into a bounded content-addressed cache rather than baked.
Low-code applications remain checked release data; only an optional gate-admitted server adapter joins the linked set
([`capability_extension_doctrine.md`](../documents/engineering/capability_extension_doctrine.md), [`content_addressing_determinism.md` §4.5](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).

## 3. The hard constraints (cross-cutting invariants)

These are the README "Cross-cutting invariants" — documented in Phase 0, upheld by every later phase. Each is
owned by exactly one doctrine SSoT; the overview only names and links them. The first block is the product
invariant set; the second block is the cycle-breaking invariant set that certification generation 2 adds
([DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel)),
each enforced by code the runner executes rather than by prose alone.

| Invariant | Owning doctrine (cited by name) |
|-----------|----------------------------------|
| **Host invocation takes no ambient configuration and never resolves tools through host `PATH`.** Host tools are discovered lazily, **installed when absent**, and invoked by full path; a deliberately entered VM/container guest may use its own environment. What a host must already supply is the per-substrate floor — a package-manager root, a hardware or firmware fact, a credentialed account — and a tool is never on it. | [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) |
| **Illegal/unsafe state is foreclosed before effects at its honest layer** — closed illegal shapes are unrepresentable in the Haskell DSL; constructible value and target failures are rejected by total decode/provision checks; generated foreign-language projections may be typechecked only as derived artifacts; only opaque `ProvisionedSpec` can reach `renderAll`. | [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract); the enumerated catalog in [`illegal_state_catalog.md` §1 — Illegal states fail to type-check](../documents/illegal_state/illegal_state_catalog.md#1-illegal-states-fail-to-type-check) |
| **Every resource provision is explicit in the pure model, and an unprovisionable pairing has no deployable representation** — CPU/memory; pod/CNI/CSI slots; mapped/API/etcd state; logical+physical pod/image/cache storage; durable/object/database/migration storage; controller/gateway/build/Pulumi/copy/schema execution; provider quotas; and accelerator devices/net VRAM are checked before render. CUDA-on-CPU-only, one-short admission/executor, or raw-VRAM-fits/net-fails cannot produce the opaque `ProvisionedSpec` required by apply. | [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md); catalog [`§3.17`](../documents/illegal_state/illegal_state_capacity.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded), [`§3.27`](../documents/illegal_state/illegal_state_capacity.md#327-a-deployment-that-fits-in-aggregate-but-has-no-resource-capable-placement), and [`§3.30`](../documents/illegal_state/illegal_state_capacity.md#330-an-accelerator-memory-envelope-that-cannot-fit-the-selected-devices-or-unified-memory-pool) |
| **No unbounded storage** — host-bounded or cloud-quota-bounded; kubelet/mapped/API/etcd, OCI, build/engine/fabric, registry/Pulumi/release/control-state, ZooKeeper/Patroni/Vault/TSDB, and MinIO/Pulsar transition/recovery/in-flight/orphan peaks have structural typed sources, attached budgets, and finite owners; every topic has bounded retention + size-triggered offload. | [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md); [`storage_lifecycle_doctrine.md` §5.2](../documents/engineering/storage_lifecycle_doctrine.md#52-the-storage-backing-is-bounded--the-closed-storagebacking-union); [`pulsar_client_doctrine.md` §6.1](../documents/engineering/pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows) |
| **Compute engine matches its substrate; topology matches its hosts** — rke2/kind need a Linux host (a VM on apple/windows), multi-node kind is one host, multi-node rke2 is one Linux host per node, EKS is first-class; multi-substrate clusters are allowed. | [`cluster_topology_doctrine.md`](../documents/engineering/cluster_topology_doctrine.md); catalog [`§3.13`–`§3.16`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent) |
| **Dynamic provisioning is amoebius-owned and typed** — capacity grows only through a quota-capped `ScalingPolicy` (capacity-based + instance price-shopping), never a bare "unbounded." | [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md); [`cluster_lifecycle_doctrine.md` §8](../documents/engineering/cluster_lifecycle_doctrine.md#8-dynamic-node-provisioning) |
| **Pulsar payloads are exclusively CBOR** (canonical where content-addressed) — a typed codec; a non-CBOR application body (JSON/base64/protobuf/raw) is unrepresentable; protocol framing stays protobuf. | [`pulsar_client_doctrine.md` §3.1](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor); catalog [`§3.23`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent) |
| **Application logic and deployment rules are separate DSL surfaces** — write the app once; HA, chaos, geo-replication, and failover are an orthogonal layer. | [`app_vs_deployment_doctrine.md` §1 — Two surfaces, one app written once](../documents/engineering/app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once) |
| **A low-code UI is bounded checked data, never arbitrary browser/server code.** One `BoundUiProgram` projects into a public `ClientPlan` and private `UiServerPlan`; every effect binds to a typed server port, current authorization, mandatory tenant/owner scope, and an abstract capability. | [`low_code_ui_runtime_doctrine.md` §3 — One checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) and [§§8–9](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations) |
| **A browser is never an authority source.** The UI server derives identity/scope from the authenticated edge, reauthorizes every action, issues only opaque scoped handles, and exposes no direct SQL/MinIO/Pulsar/Vault/inference path or credential. | [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge) |
| **Replicated UI servers use one authenticated same-origin WebSocket and cross-pod Redis routing without sticky-session correctness.** Redis is ephemeral presence/fanout only; Pulsar/projections/providers own durable cursors, receipts, outcomes, and repair. | [`ui_realtime_coordination_doctrine.md`](../documents/engineering/ui_realtime_coordination_doctrine.md) |
| **Offline continuity is explicit, bounded, encrypted, and server-authoritative on replay.** `UiSource` declares offline projections/queueable ports/local blobs; the generic runtime owns browser APIs, and queued intent never carries execution authority. | [`browser_offline_runtime_doctrine.md`](../documents/engineering/browser_offline_runtime_doctrine.md) |
| **Secrets never live in DSL values or generated projections — only names do.** Parents inject secrets directly into a child's Vault. | [`dsl_doctrine.md` §6 — Secrets are names, never values](../documents/engineering/dsl_doctrine.md#6-secrets-are-names-never-values); [`vault_pki_doctrine.md` §3 — The SecretRef contract: a name, never a value](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) |
| **One HA-capable topology across replica counts; one replica is not HA.** Topology parity prevents a dev/prod fork, while an HA claim requires redundant admitted failure domains and an externally observed live fault. | [`platform_services_doctrine.md` §2 — HA always, including `replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1) |
| **Only `no-provisioner` retained PVs** (`<ns>/<sts>/pv_<n>`, sized, host/EBS-bound); cluster infrastructure is replaceable rather than TTL-bound, while durable backing has an independent lifetime. | [`cluster_lifecycle_doctrine.md` §4](../documents/engineering/cluster_lifecycle_doctrine.md#4-the-root-inforcespec-is-the-persistent-contract) and [`§7`](../documents/engineering/cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind); [`storage_lifecycle_doctrine.md` §1](../documents/engineering/storage_lifecycle_doctrine.md#1-cluster-and-storage-have-independent-lifetimes) and [`§2`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing) |
| **Every execution unit declares its complete resource envelope.** Every rendered container, controller child, webhook/gateway, build/Pulumi/copy/schema/ACME Job, host worker, and static engine process has explicit CPU/memory and relevant storage/rollout bounds; pod cache/scratch/mapped files are nested in ephemeral or memory accounting, while durable/native-cache/accelerator provisions remain separately owned. | [`platform_services_doctrine.md` §10](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope); [`resource_capacity_doctrine.md` §3](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget) |
| **Keycloak owns all wild ingress** via the LB + Gateway API; the sole exception is host-origin, localhost-only traffic. | [`platform_services_doctrine.md` §9 — The LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path); the host-only carve-out in [`host_cluster_comms_doctrine.md` §1](../documents/engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only) |
| **No Helm, no third-party charts** — every k8s object comes from the sole public whole-deployment `renderAll :: ProvisionedSpec -> [K8sObject]`; private service/global projections first seal one identity-keyed source set, and live mutation proceeds through activation-gated typed actions. | [`manifest_generation_doctrine.md` §1 — Why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) |
| **Baked service binaries + only `registry:2`** — every third-party *service* binary except the Registry provider, explicitly including `redis-server`/Sentinel mode and `redis-cli`, is baked into the base container for each architecture on hardware that natively runs it. The sole registry is the separately pinned and preloaded Distribution `registry:2` image; its binary is not baked into `amoebius-base`. The ML **engine payloads** are the other exception — jit-resolved into a `CacheBudget`-bounded cache, never baked or URL-fetched. | [`image_build_doctrine.md` §2](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster); [`content_addressing_determinism.md` §4.5](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) |
| **All amoebius-owned state is repository-contained** — `.build/**` is reproducible/transient/evidentiary, `.data/**` is production runtime/durable state, and `.test_data/**` is marker-owned test state. Test secrets are supplied or generated at run time under the owned test root; no cleartext secret source file is tracked. No system temp/data root, user home, or host-global engine is an amoebius storage backend. | [`repository_layout_doctrine.md` §2.3](../documents/engineering/repository_layout_doctrine.md#23-the-closed-local-state-roots); [`testing_doctrine.md` §3](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down); [`vault_pki_doctrine.md` §3.3](../documents/engineering/vault_pki_doctrine.md#33-the-test-secrets-seam-the-operators-prompt-automated) |
| **Version-controlled behavioral source is Haskell only** — Python under `pb/**` is the sole bootstrap exception. Dhall, PureScript, JavaScript, Python outside `pb/**`, shell, Proto, Pulumi, Dockerfiles, manifests, fixtures, checking tools, oracle serializations, mutants, emitted `.tla`/`.cfg`, dependency resolution, enumerations, ledgers, receipts, and run evidence are generated lazily from Haskell under `.build/**`. Independently authored test expectations are Haskell values; serialized forms are generated. | [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md); [`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md) |
| **The one formal obligation is the cross-cluster gateway migration** (both `Planned` and `Failover` branches), modelled as data, **safety + liveness-under-fairness** proven (TLC) and simulated (io-sim) once; its runtime fidelity is bridged by deterministic simulation + trace validation before live; intra-cluster consensus is delegated, not re-proven. The model is owned by Phase 75; the formal checkers are parked in the later-phases proof-assistant track. | [`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md); [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md); [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md) |
| **A test generates the enumeration, authors the expectation** — the spec generates the *enumeration* of surfaces requiring coverage; the operator authors the *expectations* asserted against them; an uncovered surface emits an UNVERIFIED `coverage` ledger row, never a silent pass. | [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation); [`chaos_failover_doctrine.md` §11.2](../documents/engineering/chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation) |
| **An effectful gate cannot pass on a replay or self-report.** A post-start challenge must appear in an authenticated observation outside the subject; security gates pair authority-minted own-scope success with foreign-scope denial, zero forbidden effect, and direct-bypass probes. | [`testing_spoof_resistance.md` §12](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) |
| **Backups are write-only for amoebius; deletion/retention is out of band** — a backup names a bounded medium in a distinct failure domain, is written under a put-only credential (no delete/expire/lifecycle action is representable), is append-only/WORM where declared, and its restore **seeds a fresh coordinate, never overwrites** live bytes; a `ColdSeedFromBackup` down-primary secondary takes the gateway only after proven freshness — consistency over availability. | [`backup_recovery_doctrine.md`](../documents/engineering/backup_recovery_doctrine.md); [`storage_lifecycle_doctrine.md` §7](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation); [`consistency_pacelc_doctrine.md` §3.7](../documents/engineering/consistency_pacelc_doctrine.md#37-the-cold-dr-seed-recovery-source) |
| **amoebius depends on no seed project, and no seed depends on amoebius.** The five seeds are reference implementations whose pure structures amoebius re-derives; a re-derivation is admissible only once the guarantee amoebius adds has been named. | [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) |
| **Every artifact that is not Haskell source is generated from Haskell types**, under a closed exception list admitting only what must exist before the generator can run. Each is named by a content address that folds in its own rendered text, charged against a grant, and reaped when its region ends. | [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md), [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) |
| **A domain or a hardware substrate joins by satisfying one contract** — one `ExtensionSpec` record linked into the shipped binary, a component in each of the five calculi, and the four law families — and its conformance gate is generated from its own declaration rather than authored beside it, so an author cannot weaken it. The five calculi remain the target design; the artifact, budget, evidence, and composition libraries are parked under `LTD-LIB-001` pending Phase 9's decision ([legacy register §5](legacy_tracking_for_deletion.md#5-dsl-divergence)). | [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md); [DL-0002](../documents/decision_log.md#dl-0002--one-extensionspec-record-is-the-extension-seam) |
| **Teardown is a type obligation, not an activity.** Provisioning returns a handle and an obligation together, and the obligation is specified to be linear, so a workflow ending while it still holds one is rejected at compile time. | [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) |
| **An insecure state has no inhabitant.** Attestation is a type index, a tenant learned at run time is skolemised into a fresh type variable, an absent scope is a missing field rather than a widened query, and every derived keyspace is rendered injectively. | [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) |
| **Reproducibility.** A receipt is a content-addressed record of one runner execution, never a signature; every verifier command is agent-run without `sudo` or an issuer key; `replay` re-derives each receipt's reproducible digest and voids one that does not reproduce. | [`AGENTS.md` — Reproducibility](../AGENTS.md#reproducibility); [DL-0013](../documents/decision_log.md#dl-0013--validation-authority-is-mechanical-and-receipts-are-reproducible) |
| **One transition per accept.** An agent never edits a status line by hand; `amoebius-validate accept --phase NN` runs the complete gate, prints the Claim, specification digest, kill table, spine outcome, and corpus delta, records the receipt with its digest beside the Done status, and applies exactly one phase's patch. | [`gate_runner_doctrine.md` §6 — commands, generations, and receipts](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts); [DL-0009](../documents/decision_log.md#dl-0009--status-authority-is-one-human-act-per-transition) |
| **Verifier binding.** Every gate compares the tree's verifier digest with the accepted seed's and refuses `KERNEL-VERIFIER-DIVERGED`; a generation identifier is the verifier's content address, and a reseed archives the prior store under a decision identifier and never deletes it. | [`gate_runner_doctrine.md` §5 — preflight refusals and predecessor chaining](../documents/engineering/gate_runner_doctrine.md#5-preflight-refusals-and-predecessor-chaining); [§6](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts) |
| **Kernel budget.** The validator — the gate-specification library, the runner, and the retained custody core — is at most 14,000 lines and never above the last accepted count, with no conditional compilation, no `*Run*` module, no phase-number literal, and one phase table; no other stanza exposes a validator module. | [`AGENTS.md` — Kernel budget](../AGENTS.md#kernel-budget); [`gate_runner_doctrine.md` §3 — the runner](../documents/engineering/gate_runner_doctrine.md#3-the-runner) |
| **Subjects are shipped code.** Every gate subject and every mutated module belongs to exactly one library stanza inside the transitive closure of `executable amoebius`, which links no validator module; a validator-only corpus never counts as product coverage, and `SUBJECT-NOT-SHIPPED` refuses a subject outside the closure. | [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary); [DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel) |
| **Runner-held verdicts.** A suite writes bytes; a separate oracle executable with no product or validator dependency prints its ledger from literals in its own source; the runner digests suite output, ledger, and kill table into the receipt. A `PASS` token, a count, or a matching substring is not a verdict. | [`gate_runner_doctrine.md` §4 — runner-held verdicts and the oracle protocol](../documents/engineering/gate_runner_doctrine.md#4-runner-held-verdicts-and-the-oracle-protocol) |
| **Generated mutants only.** No authored mutant seam exists under `src/`, `app/`, or `test/`; the runner generates mutants from a fixed operator catalogue with deterministic sampling, applies them to copies beneath `.build/runs/**`, and rebuilds serially; a stillborn mutant is excluded, not counted. | [`gate_runner_doctrine.md` §3 — the runner](../documents/engineering/gate_runner_doctrine.md#3-the-runner); [`development_plan_gate_integrity.md` §M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) |
| **The spine runs through the shipped binary.** Every non-seed `GateSpec` carries a `BinaryFact` — a public `amoebius` command, a runner-perturbed input, and runner-digested outputs; the `DSL_BARRIER` specification carries a `SpineFact` whose rendered `.dhall` the runner rewrites after the run starts. | [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary); [§3](../documents/engineering/gate_runner_doctrine.md#3-the-runner) |
| **Corpus and coverage.** Examples are Haskell values in `Amoebius.Dsl.Examples` linked by the executable, organised as distinguishing pairs with expected manifest deltas or negatives with an exact tag and stage; oracle rows are authored before the stage exists, and `AuthoredFieldUnconsumed` refuses a field that reaches no byte. | [`gate_runner_doctrine.md` §7 — the example corpus and the hardware rule](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule); [`testing_doctrine.md` §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) |
| **Hardware consumes the barrier.** Every hardware specification binds the `DSL_BARRIER` receipt digest and runs a corpus command through its own subject; hardware evidence that consumes no barrier example is refused as `HARDWARE-BEFORE-BARRIER`. | [`gate_runner_doctrine.md` §7 — the example corpus and the hardware rule](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule); [`AGENTS.md` — Validation outcome and ordering](../AGENTS.md#validation-outcome-and-ordering) |
| **Chain on closure.** Predecessor binding is the digest of the predecessor's product closure plus the verifier and governance digests; an edit outside that closure keeps the receipt, an edit inside it reopens the predecessor, and a refresh is an identity projection that cannot weaken a specification. | [`gate_runner_doctrine.md` §5 — preflight refusals and predecessor chaining](../documents/engineering/gate_runner_doctrine.md#5-preflight-refusals-and-predecessor-chaining); [`development_plan_gate_integrity.md` §M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass) |
| **Doctrine freeze and honesty.** Every governed document, `AGENTS.md`, the plan rulebooks, and the legacy register are frozen behind baseline rows `(path, digest, DecisionId)`; a frozen body changes only with a decision-log entry in the same change, and a paragraph naming a module or path is observed, historical, or specification voice. | [`documentation_standards.md` §17 — the doctrine freeze](../documents/documentation_standards.md#17-the-doctrine-freeze); [§6 — honesty](../documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline); [`AGENTS.md` — Doctrine freeze](../AGENTS.md#doctrine-freeze) |
| **Typed reset cause.** A reset is receipt-bearing and carries `ResetCause { validatorGap, productGap }`, where the product gap is a legacy identifier with an owning phase; `NoProductGap` is refused while any `LTD-DSL` row is open, and the phase and gate tables at or below the frontier are digested into the generation record. | [`gate_runner_doctrine.md` §6 — commands, generations, and receipts](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts); [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice) |

The standard service set behind these capabilities — Registry (Distribution `registry:2`) · MinIO · Vault · Pulsar ·
Redis/Sentinel · Prometheus/Grafana · Percona/Patroni Postgres + pgAdmin · Envoy/Gateway-API · Keycloak · LoadBalancer — is
inventoried in [system_components.md](system_components.md) and owned by
[`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md).

## 4. The phase index (one line per phase)

Each phase ends in a single, checkable acceptance gate on **at most one** substrate (the one-substrate
discipline, [development_plan_standards.md §L](development_plan_standards.md#l-one-substrate-discipline)). Each
phase document owns its gate text; the tracker owns phase order and status. The lines below are a navigation
index, not a second status ledger — so it names no status at all. [README.md](README.md)'s tracker is the
sole record of which phase is where
([development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary)); a status restated
here goes stale the moment a gate runs, which is what happened to the sentence this replaces.

The DSL is designed to be validated and **simulated per phase**, never as a monolithic pre-implementation: each
slice phase discharges an in-process Register-2 gate against a runner-materialized fake boundary, and each
live-band phase a Register-3 gate, before the next opens. The formal checkers are parked in the later-phases
proof-assistant track; the gateway model is owned by Phase 75. The **Register-2.5 deterministic-simulation
activity is never a phase gate**
([development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)); where a
live-band phase eventually runs it, the activity may compare built code with the gateway model only after
[Phase 75](phase_75_gateway_migration_drills.md) has passed its qualified gate. Its status and evidence belong
to the [tracker](README.md#phase-overview). Front-loading a *design* model ahead of its runtime is legitimate
only while correspondence and runtime fidelity remain explicitly unverified
([development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed), [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md)).

The phase domain is 0 through 9 and 50 through 95; the ordinals between are a reserved gap recorded by
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice). The four ordering
barriers are named by role: `DSL_BARRIER` is Phase 9, `BOOTSTRAP_HANDOFF` is Phase 50, `HOST_ENSURE` is Phase
51, and `FIRST_HARDWARE` is Phase 52; the compiled phase-identity table, not this index, resolves each role to
its ordinal.

### Hardware-free slices and the barrier

*Foundations (substrate `none`):*
- **Phase 0 — Documentation, governance, and the validation seed** → [phase_0](phase_00_documentation_suite.md).
- **Phase 1 — Haskell toolchain and probe-source closure** → [phase_1](phase_01_toolchain_spike.md).
- **Phase 2 — Repository layout conformance and source closure** → [phase_2](phase_02_repository_layout_conformance.md).

*The typed DSL slices — one growing corpus, every stage typed and consumed (substrate `none`, Register 2):*
- **Phase 3 — The typed spine from one spec to fake-applied bytes** → [phase_3](phase_03_typed_spine.md).
- **Phase 4 — Witness-driven manifests, capacity, and storage** → [phase_4](phase_04_witness_manifests_capacity_storage.md).
- **Phase 5 — Substrates, lanes, rke2 quorum, and the image recipe** → [phase_5](phase_05_substrates_lanes_image_recipe.md).
- **Phase 6 — Extension admission and attested scope** → [phase_6](phase_06_extension_admission_attested_scope.md).
- **Phase 7 — Child clusters and obligation-indexed teardown** → [phase_7](phase_07_child_clusters_obligation_teardown.md).
- **Phase 8 — UI program language, binding, and plans** → [phase_8](phase_08_ui_program_language_binding.md).

*The DSL barrier — the `DSL_BARRIER` role (substrate `none`, Register 2):*
- **Phase 9 — The DSL barrier through the shipped binary** (the `DSL_BARRIER` role) → [phase_9](phase_09_dsl_barrier.md).

*Reserved — ordinals 10 through 49:* no phase occupies these ordinals, no phase file or tracker row exists for
them, and the gap is not a promise of later insertion
([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)).

### Host realization, live platform, and domain instances

*Pre-binary and host — the first machine (Registers 2–3):*
- **Phase 50 — Bounded `pb` bootstrap and Haskell handoff** (the `BOOTSTRAP_HANDOFF` role) → [phase_50](phase_50_host_assert_cli.md).
- **Phase 51 — The host-ensure kernel** (the `HOST_ENSURE` role) → [phase_51](phase_51_host_ensure_kernel.md).
- **Phase 52 — Linux: sudoless Docker and the native image** (the `FIRST_HARDWARE` role) → [phase_52](phase_52_linux_engine_bringup.md).
- **Phase 53 — Apple: Homebrew, Colima, and the native image** → [phase_53](phase_53_apple_engine_bringup.md).
- **Phase 54 — Windows: WSL2 and the lifted Linux engine** → [phase_54](phase_54_windows_engine_bringup.md).
- **Phase 55 — Haskell substrate coordinator and single kind cluster** → [phase_55](phase_55_bootstrap_coordinator_kind.md).
- **Phase 56 — The base image, the jit-build resolver, and the in-cluster registry** → [phase_56](phase_56_base_image_registry.md).
- **Phase 57 — The complementary-architecture base image** → [phase_57](phase_57_complementary_arch_child.md).

*The live platform (Register 3):*
- **Phase 58 — Typed renderer + object reconciler** → [phase_58](phase_58_object_reconciler.md).
- **Phase 59 — amoebius-capacity scheduler + bootstrap cutover** → [phase_59](phase_59_capacity_scheduler.md).
- **Phase 60 — No-provisioner retained storage + lossless rebind** → [phase_60](phase_60_retained_storage.md).
- **Phase 61 — Root Vault + PKI + built-in Haskell Vault client** → [phase_61](phase_61_vault_pki.md).
- **Phase 62 — Platform backbone (MetalLB + MinIO + Pulsar HA)** → [phase_62](phase_62_platform_backbone.md).
- **Phase 63 — Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG)** → [phase_63](phase_63_platform_services_2.md).
- **Phase 64 — Keycloak-owned ingress** → [phase_64](phase_64_keycloak_ingress.md).
- **Phase 65 — Live DSL deploy via the replicas=1 control-plane daemon** → [phase_65](phase_65_live_dsl_deploy.md).
- **Phase 66 — Tenant/provider provisioning** → [phase_66](phase_66_app_tenancy.md).
- **Phase 67 — Native Pulsar client (CBOR)** → [phase_67](phase_67_pulsar_client.md).
- **Phase 68 — Live subject/tenant isolation** → [phase_68](phase_68_user_tenant_isolation_live.md).
- **Phase 69 — Content store + workflow runtime (Pulsar-Failover single-writer)** → [phase_69](phase_69_content_store_workflow.md).
- **Phase 70 — Owner-scoped UI projection runtime** → [phase_70](phase_70_ui_projection_runtime.md).
- **Phase 71 — Release lifecycle** → [phase_71](phase_71_release_lifecycle.md).
- **Phase 72 — Atomic immutable UI-program release** → [phase_72](phase_72_ui_program_release.md).
- **Phase 73 — WireGuard network fabric** → [phase_73](phase_73_network_fabric_wireguard.md).
- **Phase 74 — Multi-cluster spawn + geo-replication** → [phase_74](phase_74_multicluster_spawn_georepl.md).
- **Phase 75 — Gateway-migration drills + model-correspondence** → [phase_75](phase_75_gateway_migration_drills.md).
- **Phase 76 — Haskell-derived provider Pulumi program and enveloped checkpoint** → [phase_76](phase_76_provider_deploy_checkpoint.md).
- **Phase 77 — Hostless provider child + convergence + Lease handoff** → [phase_77](phase_77_provider_child_bringup.md).
- **Phase 78 — Per-PV EBS decoupling + create-vs-delete credential** → [phase_78](phase_78_provider_ebs_credential.md).
- **Phase 79 — Dynamic node provisioning by signal + leak-free provider gate** → [phase_79](phase_79_provider_dynamic_nodes.md).
- **Phase 80 — Determinism kernel + jit-build CacheBudget cache** → [phase_80](phase_80_determinism_jitcache.md).
- **Phase 81 — Single-tenant low-code UI live path** → [phase_81](phase_81_ui_single_tenant_live.md).
- **Phase 82 — Multi-tenant low-code UI isolation** → [phase_82](phase_82_ui_multi_tenant_live.md).
- **Phase 83 — UI rollout, projection catch-up, and reconnect** → [phase_83](phase_83_ui_rollout_reconnect.md).
- **Phase 84 — Initial online UI multi-zone high availability** → [phase_84](phase_84_ui_ha_multizone.md).
- **Phase 85 — Offline replay and durable receipts** → [phase_85](phase_85_offline_replay_receipts.md).
- **Phase 86 — Offline blobs and partition isolation** → [phase_86](phase_86_offline_blobs_isolation.md).
- **Phase 87 — Offline release and schema evolution** → [phase_87](phase_87_offline_release_evolution.md).
- **Phase 88 — Offline multi-zone continuity** → [phase_88](phase_88_offline_multizone_continuity.md).
- **Phase 89 — Apple-Metal host compute daemon** → [phase_89](phase_89_apple_metal_host_daemon.md).
- **Phase 90 — The live test topology and elevated harness** → [phase_90](phase_90_test_topology_live.md).

*Domain instances — the seeds re-derived as conforming extensions (Register 3):*
- **Phase 91 — The infernix inference core, re-derived** → [phase_91](phase_91_infernix_rederivation.md).
- **Phase 92 — The infernix workflow and artifact contracts, re-derived** → [phase_92](phase_92_infernix_ui_rederivation.md).
- **Phase 93 — The jitML numerical core, re-derived** → [phase_93](phase_93_jitml_rederivation.md).
- **Phase 94 — The jitML training and checkpoint contracts, re-derived** → [phase_94](phase_94_jitml_ui_rederivation.md).
- **Phase 95 — The multi-tenant web application re-derived** → [phase_95](phase_95_webapp_rederivation.md).

---

## 5. Reset baseline and live status authority

- **Implementation footprints do not imply validation.** Except for the bounded `pb/**` bootstrap, every
  non-Haskell behavioral source is migration input owed to a numbered owner, and typed Haskell legacy
  bindings account bijectively for each such violation until that owner closes it.
  [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) explains those bindings to readers
  and supplies no IDs, owners, predicates, counts, or verdict inputs;
  [system_components.md](system_components.md) remains target-only.
- **Certification generation 2.** A generation identifier is the content address of the verifier, seeded by
  the human under [DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel);
  a gate whose verifier digest differs from the seed's refuses `KERNEL-VERIFIER-DIVERGED`. Generation-1 stores
  are archived, never deleted, and supply no authority; a generation-1 receipt is not evidence for any phase.
- **The frontier is Phase 0.** Every other phase is blocked behind it. The frontier advances by exactly one
  phase per human `accept`
  ([DL-0009](../documents/decision_log.md#dl-0009--status-authority-is-one-human-act-per-transition)); an
  agent's `preview` runs the complete gate and mints nothing, and no agent edits a status line.
- **Status posture:** the authoritative live per-phase projection lives only in [README.md](README.md) and its
  mechanically joined phase/sprint fields. This summary cannot restate or promote it.
- **Artifact posture:** only Haskell behavioral source and the bounded Python `pb/**` bootstrap may be
  version-controlled. The
  complete repository and generated-output structure is owned by
  [`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md). Even `pb/**`
  bytecode and caches must be redirected beneath `.build/**`; there is no source-adjacent cache exception.
- **Toolchain posture:** dependencies and tools resolve dynamically from authored compatibility requirements.
  Lock/freeze files, resolved paths, and hard-coded library/package SHA values are generated and untracked.
- **Evidence posture:** a gate writes beneath `.build/runs/**` and the receipt store of the current generation;
  a receipt carries the verifier digest, the governance digest, the kill table, and the status postimage
  ([`gate_runner_doctrine.md` §6](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts)).
- **Hardware posture:** no hardware validation may begin until the DSL barrier (Phase 9) and every preceding
  gate pass; each hardware specification binds the barrier's receipt digest and runs a corpus command through
  its own subject.

---

## Related Documents
- [README.md](README.md) — the live tracker: phase order, status, gates, and remaining work (the "where/when" to this "why/what")
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys ([§A](development_plan_standards.md#a-header-metadata-same-block-as-the-doctrine-suite) header, [§H](development_plan_standards.md#h-the-doctrine-citation-rule-cite-by-name) citation rule, [§K](development_plan_standards.md#k-honesty-proven--tested--assumed) honesty, [§L](development_plan_standards.md#l-one-substrate-discipline) one-substrate)
- [system_components.md](system_components.md) — the target component inventory: surface → owning doctrine → planned module path
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — the reader-facing explanation of typed Haskell migration bindings as prodbox/infernix/jitML converge
- [later_phases.md](later_phases.md) — the in-scope, high-numbered phases not yet given their own document
- [Decision log](../documents/decision_log.md) — the entries the cycle-breaking invariants cite
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md) — the runner, the gate-specification vocabulary, and the human commands
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine SSoTs this overview summarizes and links
- [Documentation Standards](../documents/documentation_standards.md) — the header/link mechanics this inherits
