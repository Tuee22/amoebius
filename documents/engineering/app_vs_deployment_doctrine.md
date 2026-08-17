# Application Logic vs Deployment Rules

> **Purpose**: Define the hard separation between an app's **application logic** (what it *is* to a user)
> and its **deployment rules** (how, where, and how robustly it runs), so one app spec is written once and
> composes unchanged onto a single cluster or N geo-replicated clusters.
> **Read this if**: it is unclear whether something belongs to an application or to the rules that deploy it.

This document owns the split between the two authoring surfaces and the test that decides which side a given
concern falls on. It owns neither surface's contents: the application surface is owned by
[low_code_ui_runtime_doctrine.md](./low_code_ui_runtime_doctrine.md) and the deployment surface by the
capacity, capability, and platform doctrines it cites. It presumes only that a specification exists.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_23_ui_local_composition.md, DEVELOPMENT_PLAN/phase_40_release_lifecycle.md, DEVELOPMENT_PLAN/phase_48_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_50_infernix_lift.md, DEVELOPMENT_PLAN/phase_55_test_topology_dsl.md, documents/engineering/README.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_sources.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/glossary.md, documents/illegal_state/illegal_state_lifecycle.md, documents/reading_order.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Phase-run and implementation-result statements predate the 2026-08-11 reopen unless the owning phase is Done; target doctrine remains normative, and current state is in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Two surfaces, one app written once](#1-two-surfaces-one-app-written-once)
- [2. The application-logic surface — what an app *is*](#2-the-application-logic-surface--what-an-app-is)
- [3. The deployment-rules surface — how the same app *runs*](#3-the-deployment-rules-surface--how-the-same-app-runs)
- [4. The dividing line — a litmus test](#4-the-dividing-line--a-litmus-test)
- [5. Why the split matters — cashing it out](#5-why-the-split-matters--cashing-it-out)
- [6. The proof case: a low-code workflow UI as application-logic-only](#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only)
- [7. infernix is a shared library; the inference substrate is a deployment rule](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)
- [8. Shared-library use is application logic](#8-shared-library-use-is-application-logic)
- [9. Composition: one cluster → N geo-replicated clusters, zero app change](#9-composition-one-cluster--n-geo-replicated-clusters-zero-app-change)
- [10. Application-authored expectations are application logic](#10-application-authored-expectations-are-application-logic)
- [11. What this document does not own](#11-what-this-document-does-not-own)
- [12. Planning ownership](#12-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Two surfaces, one app written once

In amoebius, **an app does not know how many of it exist.** A developer describes *what their app is* — its
UI, its users, the data it keeps, the libraries it leans on — and **never** writes down how many replicas
run, in how many regions, behind what failover policy, under what chaos schedule. Those are someone else's
decision, made later, in a separate place, and the app is none the wiser.

Concretely, amoebius splits the Dhall DSL into two **orthogonal surfaces**:

| Surface | Answers | Written by | Example values |
|---------|---------|------------|----------------|
| **Application logic** (the app spec) | *What is this app?* | the app author, once | bounded `UiSource` modules/routes/ports, auth-policy references, durable-data needs, workflows, shared-library use |
| **Deployment rules** | *How, where, how robustly does it run?* | the operator, per deployment | HA replica counts, geo-replication topology, gateway failover, chaos-test injection, inference substrate |

These are not two halves of one file that happen to be near each other — they are **separable inputs**. The
app spec joins with *a* deployment-rules layer to produce *a* deployment; swap the deployment-rules layer
and a different deployment results from byte-identical app logic. The grammar of these two surfaces — the
Dhall record/union types, total composability, and the illegal-state-unrepresentable contract — is owned by
[dsl_doctrine.md](./dsl_doctrine.md). This document owns only the **dividing line**: which concerns live on
which surface, and why the line must never be crossed (DEVELOPMENT_PLAN
cross-cutting invariant "Application logic and deployment rules are separate DSL surfaces").

> **Honesty.** This split and the low-code UI/runtime boundary are specified design intent. The generic
> `UiSource` checker, client interpreter, UI server, and infernix/jitML artifact interaction are not thereby
> claimed as built or tested. Read every prescriptive statement here as design intent, never as a tested
> amoebius result. Status and gates live only in
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) (per > [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## 2. The application-logic surface — what an app *is*

**Everything on this surface survives a move.** An app torn off its cluster and stood up somewhere else — on a
different substrate, at a different scale — carries these things *with* it because they *are* the app. Its
mandatory authored source is an **app-spec `.dhall`** containing or importing a bounded `UiSource`, semantic
service/workflow requirements, and typed port bindings. That source checks to one `BoundUiProgram`, from which
the generic PureScript client plan and amoebius UI-server plan derive
([low_code_ui_runtime_doctrine.md §3](./low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans)).

An app may also select a trusted linked Haskell adapter when a declared data, workflow, or artifact port needs
server semantics absent from the existing catalog. The adapter is admitted by Gate 3; it is not the UI and is
not mandatory for an app whose ports bind entirely to existing handlers. The bounded view, state, and transition
logic remains `UiSource` data, while effect implementations remain trusted Haskell. Generated client/server
plans and per-app content manifests are release artifacts, not additional authored sources; the one generic
client bundle changes only with its runtime ABI/component catalog.

**An app has no image of its own.** The generic client and UI-server responsibility run from the applicable
amoebius `Runtime` image, whose linked set contains only the trusted workload/effect adapters that its bound
ports require. "Ship a container amoebius did not build" still has no syntax. The image-build pipeline and the
closed image identity are owned by [image_build_doctrine.md](./image_build_doctrine.md); this surface owns the
application/deployment classification.

The app-spec surface declares:

- **UI and user lifecycles** — the bounded `UiSource` modules, state, routes, forms, typed effects, workflow
  views, and artifact interactions that define the user experience. Their checked representation and runtime
  boundary are owned by
  [low_code_ui_runtime_doctrine.md §4](./low_code_ui_runtime_doctrine.md#4-the-authored-dhall-surface).
- **LB services** — *which* of the app's services are reachable from the edge. (Whether they are reachable
  is never the app's call: all wild ingress is owned by Keycloak via the LB + Gateway API — see
  [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path). The app declares *what to publish*;
  it cannot publish a backdoor.)
- **Authentication and authorization requirements** — mandatory semantic `AuthPolicyRef` values on routes and
  effects. Keycloak/Envoy and server policy are derived/bound projections; the app cannot author provider policy
  or treat client visibility as authority
  ([low_code_ui_runtime_doctrine.md §9](./low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge)).
- **Durable-storage needs** — the MinIO buckets it keeps (named `<app>/<bucket>`), any `no-provisioner`
  block storage it provisions, and any Postgres database it requests in its own namespace. The app declares
  *what data it keeps*; the retained-PV mechanics, sizing, and deterministic rebind that make that data
  durable are owned by [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md), and the
  one-Patroni-cluster-per-consumer rule by [platform_services_doctrine.md §8](./platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin).
- **Pulsar topic lifecycles** — the event/workflow topics the app owns and how they live and die. The
  native-protocol client and topology algebra are owned by
  [pulsar_client_doctrine.md](./pulsar_client_doctrine.md); the app surface owns *which topics exist for
  this app*.
- **Monitoring obligations** — that each workflow carries an SLO and each topic a liveness bound, that an
  extension stands up its surfaces (jitML → TensorBoard), and the `AccessScope` each surface publishes under
  (admin-global vs a per-user Keycloak-backed filter). The app declares *that it is monitored and to whom its
  surfaces are visible*; there is no arm for "unmonitored" and none for "public." The obligation types, the
  derived dashboards, and the no-`Public`-arm rule are owned by
  [monitoring_doctrine.md](./monitoring_doctrine.md).
- **Use of shared libraries** — that the app consumes infernix, jitML, or a trusted Haskell adapter through
  typed ports is part of what the app *is* (see [§8](#8-shared-library-use-is-application-logic)).

Two structural facts pin app identity to the cluster: an app's **name is unique per cluster**, and the app gets **its own namespace with that same name**. Secrets appear here **by name only** —
the app references a secret; it never contains one. The secret-by-name `SecretRef` contract and
parent-injects-into-child model are owned by [vault_pki_doctrine.md](./vault_pki_doctrine.md) and must not
be restated here.

What is *conspicuously absent* from this surface is the whole vocabulary of [§3](#3-the-deployment-rules-surface--how-the-same-app-runs): there is no replica count, no
region, no failover policy, no chaos knob, no substrate selector. The app author cannot write those words
because the type does not have those fields.

[Phase 10](../../DEVELOPMENT_PLAN/phase_10_capability_bind.md) tests the capability instance of this split:
the app-facing `CapabilityNeed` has no product, provider, or shape field, while two distinct composed files
normalize to identical app slices and bind to structurally different provider graphs.

---

## 3. The deployment-rules surface — how the same app *runs*

The Phase-10 `CapabilityBinding` realizes the provider/shape portion of this surface as a one-built-arm
provider choice plus `SingleNode | Distributed n`; neither field is admitted by the app need.

The deployment-rules surface is the mirror image of [§2](#2-the-application-logic-surface--what-an-app-is): **everything on this surface is about robustness, scale, and placement — and none of it changes what the app is.** Turn every one of these dials and a user sees the
identical app; they just see it survive more, scale wider, or run on different hardware.

The deployment-rules surface declares:

- **HA replica counts.** How many of each component run. The app spec never names a number; the deployable
  shape remains horizontally scalable at `replicas=1`, but one UI-server replica is not redundant and is not
  described as highly available
  ([low_code_ui_runtime_doctrine.md §14](./low_code_ui_runtime_doctrine.md#14-runtime-role-deployment-and-high-availability)).
  The replica value is a pure deployment dial that rides an unchanged shape. Where the value physically
  lives in the DSL (a cluster-scoped `cluster.dhall` value seeded at `bootstrap` vs a per-app deployment
  block) is a [dsl_doctrine.md](./dsl_doctrine.md) concern; this doc owns only the rule that it is **never**
  app logic.
- **Geo-replication topology.** Whether the app runs on one cluster or N geographically-replicated clusters,
  and how their durable state is kept in step (via the Pulsar / MinIO / Postgres idioms — see [§9](#9-composition-one-cluster--n-geo-replicated-clusters-zero-app-change)). The
  cross-cluster mechanics are owned by [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md).
- **Failover policy.** When and how the lead cluster's gateway fails over and DNS is repointed. The async cross-cluster correctness boundary — the one place a per-system proof
  obligation concentrates — is owned by [chaos_failover_doctrine.md](./chaos_failover_doctrine.md).
- **Chaos-test injection.** The app **does not know it is being chaos-tested.** A chaos schedule is attached
  here, never in the app spec; the Extract→Model→Inject methodology and the proven/tested/assumed ledger are
  owned by [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), and the test-as-an-`InForceSpec`-topology
  model by [testing_doctrine.md](./testing_doctrine.md).
- **Monitoring dials.** The SLO budget *numbers* (freshness, error-budget), the alert severities, and the
  derived `AuthPolicyRef` that scopes a `SubjectScoped` or `TenantRoleScoped` surface are deployment dials —
  a robustness/visibility setting, never app logic — carrying **no** "off" arm and **no** "public" arm. The
  `AccessScope` union and its three arms are owned by
  [monitoring_doctrine.md §4](./monitoring_doctrine.md#4-access-one-admin-delegated-per-user-scope-no-public-arm).
- **Inference substrate.** Whether an ML workload runs on Apple Metal on the host, CUDA on the cluster, or
  linux-cpu is a deployment decision, not app logic — this is the *serving* substrate (the *producing*
  substrate that made a model's weight bytes is provenance, not a deployment dial — see [§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)).
- **Dynamic node provisioning policy.** Scaling nodes by arbitrary logic — load, spot-instance cost, or
  workflow completion — is a deployment rule, owned operationally by
  [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md), and typed as a `ScalingPolicy` owned by
  [resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm).
- **Resource budgets, storage backings, and the compute engine.** The per-host/cluster capacities and storage
  budgets a workload must fit, the `StorageBacking` each app's storage draws from, and the compute engine +
  node topology (kind / rke2 / EKS) are all deployment rules — an app declares *what* it needs, never *how
  much the cluster has* or *which engine runs it*. The capacity fold is owned by
  [resource_capacity_doctrine.md](./resource_capacity_doctrine.md); the compute-engine/topology axis by
  [cluster_topology_doctrine.md](./cluster_topology_doctrine.md).
- **Environment (dev/staging/prod).** *Which* environment a deployment targets is a deployment rule, never
  app logic: the **app bytes are byte-identical across environments**, and only the deployment rules differ.
  The environment is not a field in the app spec but a mutable, per-environment **ETag-CAS pointer** — living
  in the content store — that resolves to a `Release`; "promote to prod" is a pointer CAS. The `Environment`
  type, the promotion pointer, and the immutable release ledger are owned by
  [release_lifecycle_doctrine.md §3](./release_lifecycle_doctrine.md#3-environment-and-the-etag-cas-promotion-pointer). This is the type-level reason there is
  no separate "dev version" and "prod version" of an app ([§5](#5-why-the-split-matters--cashing-it-out)).
  Phase 40 validated this rule by pointing Dev, Staging, and Prod at the same immutable release hash without
  rebuilding any app bytes, while environment changes remained CAS operations on pointer objects.
- **Offline policy and realtime topology.** The application decides whether it is `OnlineOnly` or defines
  offline projections, queueable ports, blob classes, and an offline view: those choices change what the app
  does for a user. The deployment decides maximum offline lease, permitted persisted flow labels, local
  unlock, device/count/byte/age limits, reconnect concurrency, receipt retention, compatibility horizon,
  UI-server replica/spread counts, and Redis/Sentinel capacity/topology. Neither surface exposes Redis keys,
  WebSocket routes, IndexedDB, OPFS, or service-worker mechanisms. The boundary is owned precisely by
  [Browser Offline Runtime §§3 and 12](./browser_offline_runtime_doctrine.md#3-the-authored-continuity-surface)
  and [UI Realtime Coordination](./ui_realtime_coordination_doctrine.md).

This surface is **keyed by app**: a deployment-rules layer references an app by name and says *how to run
it*. The same app name can appear in two different deployment-rules layers and run two completely different
ways, with zero edits to its app spec.

---

## 4. The dividing line — a litmus test

When it is unclear which surface a concern belongs to, apply one rule:

> **If changing it changes what the app *is* to a user, it is application logic. If changing it changes only > how many copies run, where they run, or how robustly they run, it is a deployment rule.**

App logic answers **WHAT**; deployment rules answer **HOW MANY / WHERE / HOW ROBUST**. Worked through some
deliberately tricky cases:

| Concern | Surface | Why |
|---------|---------|-----|
| "The app exposes a chat UI" | application logic | it is *what the app is* |
| "The chat UI is reachable from the edge" | application logic (declares the LB service) | *what to publish*; the edge is still Keycloak's |
| "Run 5 replicas of the chat backend" | deployment rule | a scale dial; same app at 1 or 5 |
| "The app keeps a `messages` bucket and a Postgres DB" | application logic | *what data it keeps* |
| "Those PVs are 50Gi, retained, host-bound" | neither — owned by [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) | a platform mechanic, not an app or deployment dial |
| "The app uses infernix for inference" | application logic | a shared-library dependency ([§8](#8-shared-library-use-is-application-logic)) |
| "Inference runs on Apple Metal vs CUDA" | deployment rule | a placement choice ([§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)) |
| "Replicate the app across us-east and eu-west and fail over" | deployment rule | topology + robustness; the app is unchanged ([§9](#9-composition-one-cluster--n-geo-replicated-clusters-zero-app-change)) |
| "Inject a broker kill at a bounded offset after the workflow's quiesce edge" | deployment rule | a typed `FaultSchedule` in logical/simulated time ([chaos_failover_doctrine.md §11.2](./chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation)); the app does not know it is being tested |
| "Promote a build from staging to prod" | deployment rule | a pointer CAS over byte-identical app bytes; only the deployment rules differ ([§3](#3-the-deployment-rules-surface--how-the-same-app-runs)) |
| "These projections and commands work offline" | application logic | it changes the user's available behavior and queue/conflict semantics |
| "Permit those offline records for 24 hours on two devices" | deployment rule | lease, labels, device quota, retention, and reconnect capacity are robustness/security dials |
| "Route sockets across three UI replicas with Redis/Sentinel" | deployment rule | transport coordination and replica topology do not change app semantics |
| "A login requires MFA for the admin role" | application logic | an auth rule that *defines* the app's behaviour |

**Misfiling is a bug, not a style preference.** A replica count that leaks into the app spec re-couples
scale to logic and breaks write-once; a UI route that leaks into deployment rules makes the deployment layer
non-swappable. [dsl_doctrine.md](./dsl_doctrine.md) and
[illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md) are the SSoTs for *which* of these boundaries are
lifted into the type layer so that a misfiled field is **unrepresentable** rather than merely discouraged —
this doc states the policy; those docs own the enforcement.

---

## 5. Why the split matters — cashing it out

Three concrete properties, each a direct consequence of keeping the line clean:

- **Write once.** An app is authored a single time, deployment-agnostic. There is no "dev version" and
  "prod version" of the app spec; there is one app spec and many deployment-rules layers. This kills the
  whole *works-on-my-laptop, breaks-in-prod* class of bug at the source — the laptop deployment and the
  production deployment run the **same app bytes on the same derived deployment shapes**
  ([platform_services_doctrine.md §2](./platform_services_doctrine.md#2-ha-always--including-replicas1)); only the deployment dials differ.
- **Orthogonal evolution.** Operators tune replicas, add a failover region, or schedule chaos without ever
  opening the app's source — and app authors ship features without ever reasoning about topology. The two
  teams change different files.
- **Composability.** Because the surfaces are separable inputs, the *same* app composes with *any* valid
  deployment-rules layer (total composability). The proof case is [§6](#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only) and the
  extreme case is [§9](#9-composition-one-cluster--n-geo-replicated-clusters-zero-app-change).

The most fundamental consequence is that the split makes a whole category of mistakes **unrepresentable**: the app surface
literally has no field in which to name a replica count or a region, and the deployment surface has no field
in which to name a UI route or a bucket. A "3 replicas" value cannot be accidentally hard-coded into application
logic because there is nowhere to type it. That structural guarantee is owned by
[dsl_doctrine.md](./dsl_doctrine.md) / [illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md); this doc owns
the *reason* it is worth enforcing.

---

## 6. The proof case: a low-code workflow UI as application-logic-only

The canonical demonstration is a low-code application that presents an infernix or jitML workflow and lifts its
ready artifact into an interactive UX. The sibling demo SPAs supply UX evidence and migration fixtures; their
handwritten component trees and client effects are not the amoebius application model. The amoebius app authors
bounded `UiSource` modules, binds typed workflow/artifact ports, and lets the generic runtime render and dispatch
them. Trusted Haskell adapters preserve the sibling workflow semantics
([low_code_ui_runtime_doctrine.md §12](./low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux)).

That application is authored once as application logic: its UI program, user lifecycle, durable-data
requirements, authorization-policy references, and use of infernix/jitML. Everything about robustness and
placement is a separate deployment-rules surface:

- the k8s cluster distro (kind / rke2 / provider),
- the UI-server and backend replica counts, with redundancy only when the admitted count exceeds one,
- chaos-test injection, geo-replication topology, and gateway failover — the app never knows it is scaled,
  replicated, failed over, or tested, and
- the model-inference substrate (Apple Metal on the host, CUDA on the cluster, or linux-cpu).

The same checked application therefore runs at one replica on a single kind cluster or geo-replicated across N
clusters with failover, served on whatever inference substrate the deployment picks — and its `UiSource` never
names a replica count, a region, a chaos schedule, or a substrate, because the app surface has no field
for them ([§2](#2-the-application-logic-surface--what-an-app-is)). The inference itself is an infernix/jitML
workflow ([§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)), not a bespoke
engine welded into the app.

> **Honesty.** This is design intent, not a proven amoebius result. Representational, browser, live workflow,
> tenant-isolation, and HA evidence must pass the gates recorded in
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); this classification supplies none of
> that evidence itself.

---

## 7. infernix is a shared library; the inference substrate is a deployment rule

This is the subtlest application of the litmus test, so make the distinction explicit:

- **"The app uses infernix"** is **application logic.** infernix is an ML extension *library*; depending on
  it is part of what the app is ([§8](#8-shared-library-use-is-application-logic)). A workflow that calls infernix is the same call graph regardless of
  where it runs.
- **"Inference runs on Apple Metal vs CUDA vs linux-cpu"** is a **deployment rule.** *Where* the inference
  workload is placed — a host compute daemon using Apple Silicon's unified memory, a CUDA pod on the
  cluster, or a CPU pod — is a substrate/placement choice, configured in the deployment-rules layer with no
  change to the app.
- **Serving substrate vs producing substrate.** The substrate an inference workload is *placed on to serve*
  is this deployment-rule dial — and it **need not equal** the **producing substrate**, the accelerator whose
  reduction order actually made a model's weight bytes. The producing substrate is **provenance, not a placement choice**: this round's doctrine folds it into the checkpoint's `experimentHash` namespace so it
  travels *with* the artifact, owned by [content_addressing_doctrine.md](./content_addressing_doctrine.md);
  the engine-family-on-serving-substrate landing check is owned by
  [service_capability_doctrine.md](./service_capability_doctrine.md). This section classifies only the
  **serving/placement** axis: a model produced on one accelerator may be served on another (cross-substrate
  serving), with reproducibility scoped to the serving substrate — never a change to what the app *is*.

infernix is "an amoebius extension: a single Haskell binary that can be deployed as a distributed system
either at node-system level (in an Apple cluster) or cluster level (as a stateless deployment)". That *dual* placement is precisely a deployment decision — the same infernix logic,
two placements. Consequently **the infernix `.dhall` nests inside the `InForceSpec`**: infernix's own configuration is composed into the larger deployment spec rather than living as a
parallel system. The host-vs-cluster placement mechanics (host compute daemons as Pulsar/MinIO peers over
host-only NodePorts, no mTLS) are owned by [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
and the host↔cluster comms doctrine; the determinism and content-addressing that make an infernix run
reproducible are owned by the content-addressing doctrine. This section owns only the *classification*: the
dependency is app logic, the placement is a deployment rule.

---

## 8. Shared-library use is application logic

Which libraries and typed server adapters an app consumes — infernix, jitML, and later Haskell extension
modules validated by a custom AST checker — is part of what the app *is*, and therefore lives
on the application-logic surface. The clean way to hold this with [§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule):

- The typed **port/workflow graph** — *that* the app invokes infernix and *which* workflows/artifacts it
  composes — is application logic; it travels with the `UiSource` to any cluster.
- The **placement** of the workload that executes that call graph — host vs cluster, Metal vs CUDA vs CPU,
  at what replica count — is a deployment rule.

The trusted Haskell shape behind that dependency is the **`ExtensionSpec`** contract. Each in-tree extension in the v1
closed set — **{infernix, jitML}** — plugs in by contributing one `ExtensionSpec` — a typed Dhall sub-catalog **nested inside the `InForceSpec`** ([§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)), whose full record shape is owned by [dsl_doctrine.md §4](./dsl_doctrine.md#4-total-composability). These specs are
merged at **compile/link time into the single binary** — there is no per-extension image and no `dlopen`.
The application's requirement for that linked workload is application logic; the workload's placement remains
a deployment rule ([§7](#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)). A pure
low-code app whose ports bind to the trusted catalog contributes no Haskell and is not an extension. Only a new
server-side effect or workflow semantic needs an optional `ExtensionSpec 'App` adapter admitted by the
constrained Haskell checker
([dsl_doctrine.md §8](./dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-gate-3-admits)).
There remains no path for arbitrary browser code or an arbitrary application container.

Treating shared-library use as app logic is what lets jitML and infernix be *unified libraries under the
DSL* rather than separate products (DEVELOPMENT_PLAN: "the constituent projects are not separate products").
The later-phase Haskell extension DSL is tracked in
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); this doc does not own its design, only
its classification.

---

## 9. Composition: one cluster → N geo-replicated clusters, zero app change

The extreme case proves the doctrine: take an app running on a single kind cluster and replicate it across N
geographically-distributed clusters with automatic gateway failover — **and change not one byte of the app spec.** Everything that makes that move happen lives in deployment rules and platform idioms.

Diagram vocabulary: [diagram_conventions.md](./diagram_conventions.md).

```mermaid
flowchart TD
%% register: algebra
  app["App spec Dhall written once: UiSource, typed ports, auth refs, durable data, workflows"]:::intent -->|joined with| r1["Deployment rules A: single cluster, replicas=1"]:::intent
  app -->|same bytes, joined with| r2["Deployment rules B: N clusters, geo-replicated, gateway failover"]:::intent
  r1 -->|renders| d1["Deployment: one cluster, one region"]:::runtime
  r2 -->|renders| d2["Deployment: N geo-replicated clusters, route53 failover"]:::runtime
  classDef intent   fill:#e8eef7,stroke:#33587a,color:#12283f,stroke-width:1px
  classDef runtime  fill:#e4e4e7,stroke:#71717a,color:#2f2f35,stroke-width:1px
```

*Design intent. The app spec and the deployment-rules layers are Tier-1 in-process values; the rendered deployments are the running-cluster residue, runtime-checked and not proven here.*

Cashing out "zero app change":

- The app already declares its durable state — MinIO buckets, Pulsar topics, a Postgres DB ([§2](#2-the-application-logic-surface--what-an-app-is)). The
  deployment-rules layer says *replicate them across clusters*; the **platform idioms carry the state**:
  Pulsar geo-replication, MinIO replication, and Patroni/Postgres replication. The app's data model is unchanged; only its replication topology is.
- Gateway failover and route53 repointing are deployment-rules + cluster-lifecycle
  concerns — the app never repoints its own DNS.
- The app spec is **byte-identical** across the single-cluster and N-cluster deployments; the diff is
  entirely in the deployment-rules layer.

> **Honesty.** Geo-replication is **Phase 43**; cross-cluster gateway failover is **Phase 44**; neither is
> started. Synchronous
> intra-cluster HA is delegated to the systems that do their own consensus (MinIO / Pulsar / Postgres /
> Patroni); the **asynchronous** cross-cluster boundary — what happens if a cluster dies mid-geo-sync and amoebius
> fails over to it — is an open correctness obligation owned by
> [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), not a proven result. This doc claims only that
> the *app surface is unchanged* across the two topologies — it makes no claim that the failover is correct.

---

<a id="10-application-author-testing-is-a-deliberate-v1-exclusion"></a>
## 10. Application-authored expectations are application logic

An application author may declare typed expectations and driven interactions alongside `UiSource`. They
state what a route, event, state transition, port invocation, or visible outcome must uphold; they do not
choose where the application runs or which infrastructure fails. These values are application logic because
the same expectation must remain true when the byte-identical application is joined to different deployment
rules.

The checker derives the complete enumeration of reachable event constructors, routes, ports, transitions,
and scoped actions from `CheckedUiProgram`. That enumeration is generated at gate time and never committed.
The expected observation and the interaction that produces it are independently authored and committed;
generating either from the program under test would create a self-agreeing oracle. An enumerated surface with
no authored expectation remains explicitly UNVERIFIED. This is the derivation boundary owned by
[testing_doctrine.md §9 — generated enumeration, authored expectation](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation)
and applied to UI verification by
[low_code_ui_runtime_doctrine.md §17 — verification obligations](./low_code_ui_runtime_doctrine.md#17-verification-obligations).

The boundary is strict. Application source has no constructor for a chaos schedule, replica count, placement,
rollout policy, topology, failover target, or fault injection. Those remain operator-authored deployment
rules under [§3](#3-the-deployment-rules-surface--how-the-same-app-runs). Application expectations may be
composed with an operator-selected topology and fault schedule, but cannot author or weaken either. This keeps
the concentration principle intact: distribution behavior is still exercised and discharged at its platform
boundary rather than duplicated inside each application
([chaos_failover_doctrine.md §6](./chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives)).

[Phase 23](../../DEVELOPMENT_PLAN/phase_23_ui_local_composition.md) supplies concrete local evidence for this
split. Five application-authored interactions and four visible-state expectations exact-join the generated
workflow surface for single- and multi-tenant sources, while neither source contains a replica, topology,
rollout, failover, or fault-schedule choice. The same expectations still require later operator-selected live
topologies before any deployment, replica-loss, or HA claim becomes verified.

Phase 48 supplies the concrete provider-node classification boundary: workflow-completion and load may be
inputs to a declared deployment `ScalingPolicy`, but application logic cannot request a node, select a provider
SKU, weaken quota/capability admission, or bypass taint and scheduler authority. The contract and a retained-
Kubernetes signal analogue pass; real EKS node mutation remains UNVERIFIED. This separation is portable because
every hardware substrate can always run `linux-cpu`; when the parent must be a pristine Linux host use Incus on
Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

Phase 50 exercises this split at the core boundary: the application-facing contract names a scope-bound
artifact workflow, while `linux-cpu`, the finite CPU resource envelope, the named engine, cache placement,
Pulsar/MinIO/Vault wiring, and worker topology remain deployment/runtime choices. The scoped gate uses a pinned
micro-decoder and one untouched sibling compacted-topic module; a production TinyLlama engine and the full
sibling inference core remain UNVERIFIED. Every hardware substrate can always select `linux-cpu`. If the gate
needs a pristine Linux host, use Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

---

## 11. What this document does not own

This doc owns the **classification** — which surface a concern lives on — and nothing else. The owners of the
mechanics it points at:

| Topic | Owner |
|-------|-------|
| The DSL grammar, the cluster / app-spec / deployment-rules type families, total composability | [dsl_doctrine.md](./dsl_doctrine.md) |
| Which misfiling boundaries are type-enforced (made unrepresentable) | [illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md) |
| The standard service set, HA-always, Keycloak-owns-all-ingress | [platform_services_doctrine.md](./platform_services_doctrine.md) |
| Durable-storage mechanics: retained `no-provisioner` PVs, sizing, rebind | [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) |
| Secrets-by-name, `SecretRef`, parent-injects-into-child | [vault_pki_doctrine.md](./vault_pki_doctrine.md) |
| Services as **capabilities** (ObjectStore, Sql, …), one canonical provider, per-cluster shape | [service_capability_doctrine.md](./service_capability_doctrine.md) |
| Rendering a shape into typed manifests + the typed reconciler (no Helm) | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| Image build (buildx multi-arch, baked binaries + the `distribution` registry, versioning) | [image_build_doctrine.md](./image_build_doctrine.md) |
| Geo-replication / failover mechanics, dynamic node provisioning, teardown | [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md) |
| The async cross-cluster proof obligation + chaos methodology | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) |
| Test-as-an-`InForceSpec`-topology, `suggest-test`, the ledger | [testing_doctrine.md](./testing_doctrine.md) |
| The `Environment` promotion pointer, the immutable `Release` ledger, `RolloutPlan` | [release_lifecycle_doctrine.md](./release_lifecycle_doctrine.md) |

---

## 12. Planning ownership

This document is normative classification doctrine only. Delivery sequencing, completion status, validation
gates, and remaining work are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md):
the tracker sequences the general DSL, generic low-code UI checker/runtime, trusted infernix/jitML adapters,
live artifact interaction, and zero-app-change geo-replication. This document never maintains a competing
status ledger; it states the target classification and links back for status.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [DSL Doctrine](./dsl_doctrine.md)
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — [§2](./low_code_ui_runtime_doctrine.md#2-scope-and-single-source-ownership) owns the UI language/runtime boundary; [§14](./low_code_ui_runtime_doctrine.md#14-runtime-role-deployment-and-high-availability) keeps UI-server HA on the deployment surface
- [Platform Services Doctrine](./platform_services_doctrine.md)
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md)
- [Testing Doctrine](./testing_doctrine.md)
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md)
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md)
- [Vault / PKI Doctrine](./vault_pki_doctrine.md)
- [Image Build Doctrine](./image_build_doctrine.md)
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md)
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — capacity budgets and scaling policy are deployment rules
- [Cluster Topology Doctrine](./cluster_topology_doctrine.md) — the compute engine and node topology are deployment rules
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the environment (dev/staging/prod) promotion pointer is a deployment rule
- [Browser Offline Runtime](./browser_offline_runtime_doctrine.md) — offline app semantics versus deployment `OfflinePolicy`
- [UI Realtime Coordination](./ui_realtime_coordination_doctrine.md) — WebSocket and Redis topology remain platform/deployment mechanisms
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
