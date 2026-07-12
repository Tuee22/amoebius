# Phase 37: Live SPA deploy

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md
**Generated sections**: none

> **Purpose**: Deploy the Phase-12 decode-proven SPA composition live on `linux-cpu` — a multi-service app
> plus an ML-workflow demo app, reachable behind the Keycloak/Envoy edge, with a real inference request
> round-tripping through the composed infernix workflow and a leak-free teardown.

---

## Phase Status

📋 Planned. This is the **live** half of SPA composition, opened only after every live-band build phase it
consumes has closed; nothing here is implemented, every sprint below is 📋 Planned, and every prescriptive
statement is design intent, never a tested amoebius result. The phase runs on the **linux-cpu** substrate in
**Register 3** (live infrastructure) — a single-node `kind` cluster brought up by the Phase-13 midwife with
the standard HA platform stack (Phase 19), Keycloak-owned ingress (Phase 21), the live DSL deploy via the
Deployment-`replicas=1` singleton (Phase 22), app tenancy (Phase 23), the content store + workflow runtime
(Phase 25), the jit-build engine cache (Phase 32), and the infernix CPU-inference lift (Phase 33) all already
standing. It re-implements none of them; it composes them. The SPA app-spec type, the ML-workflow composition,
`prop_spaCompositionDecodes`, and the lifted PureScript demo SPA are **already proven in-process at Registers 1–2
in [Phase 13](phase_13_spa_composition_representational.md)** — that is the representational result this phase
now deploys live. Where a shape below is exercised in a sibling system — the `infernix`/`jitML` demo web apps and
their WebSocket inference/training runtimes, the prodbox single-node control plane — read it as **sibling
evidence, not an amoebius result**.

## Phase Summary

This phase is the composition apex of the whole doctrine suite, taken live: one `.dhall` composes a
multi-service single-page app (its dependencies declared as **capability needs**, never products) with an
ML-workflow demo app (a nested infernix/jitML `.dhall`, which is shared-library use and therefore application
logic), composed with a `linux-cpu` deployment-rules layer, and deploys onto the standing HA stack through the
typed SSA reconciler under the Deployment-`replicas=1` control-plane singleton. The SPA's published surface is
rendered as an Envoy/Gateway-API route gated by the Identity-owned (Keycloak) wild-ingress door, with no syntax
for an unauthenticated backdoor; the rendered manifests and the emitted HTTPRoute are generated from the Haskell
source of truth and **never committed**. The load-bearing new result is a **real inference round-trip**: an
inference request reaches the deployed SPA, is served by the composed infernix chatbot workflow on the
Phase-23 runtime with the inference engine **jit-resolved on first miss into the Phase-25 CacheBudget-bounded
content-addressed cache** (never baked, never URL-fetched), and returns to the caller. The jitML RL-gaming demo
composes and type-checks as a second worked composition, but running its workflow on a CUDA/Apple-Metal substrate
is out of contract here — the inference/training substrate is exactly the deployment dial this phase keeps
swappable without touching the SPA. The whole topology spins up, is reached, runs the workflow, and tears down
leak-free, emitting a per-run proven/tested/assumed ledger.

This phase adds **no** new capability, provider, reconciler, or election. The control-plane singleton stays a
`replicas=1` Deployment whose single-instance is a k8s/etcd property and whose only durable state is the
Vault-enveloped MinIO bucket; the workflow workers stay unelected; no geo-replication and no cross-cluster
gateway migration is claimed here (those are Phase 28). It proves that the established live surfaces compose
end to end for a spec-driven single-page app.

```mermaid
flowchart LR
  spa[Phase-12 decode-proven SPA .dhall: capability needs plus nested infernix workflow] --> compose[Compose with linux-cpu deployment-rules layer: replicas, provider plus shape, inference substrate]
  compose --> apply[Typed SSA reconciler applies under the replicas=1 singleton onto the HA stack]
  apply --> edge[Edge publish renders an HTTPRoute gated by Keycloak over Envoy Gateway API]
  edge --> infer[Inference request round-trips through the composed infernix workflow: engine jit-resolved into the CacheBudget cache]
  infer --> teardown[Idempotent leak-free teardown plus per-run ledger]
```

**Substrate:** linux-cpu — the whole gate composes and deploys the SPA on a single `linux-cpu` `kind` cluster
in Register 3 and exercises a CPU-bound infernix inference round-trip; no apple, linux-cuda, or windows
substrate is touched, and the jitML RL-gaming demo is built and type-checks as a second composition without its
workflow being run.

**Register:** 3 — live infrastructure (§K).

**Gate:** an SPA `.dhall` composes a **multi-service app + an ML-workflow demo app, deployed and reachable behind
Keycloak/Envoy; an inference request round-trips; leak-free teardown** — concretely, a single SPA spec declaring
a multi-service UI surface against capability needs (`ObjectStore` / `Sql` / `MessageBus` / `Identity` / `Edge`)
and composing the infernix chatbot demo app's ML workflow, composed with a `linux-cpu` deployment-rules layer,
deploys via the typed reconciler under the `replicas=1` singleton onto the standard HA stack, its UI is reachable
only through the Keycloak/Envoy edge, an inference request round-trips through the composed infernix workflow with
the engine jit-resolved into the CacheBudget cache, the topology tears down leak-free (postflight sweep empty) and
re-runs idempotently, and each run emits a proven/tested/assumed ledger recording the composition as *tested on
linux-cpu* and recording that no GPU/Apple-Metal ML-workflow claim and no geo-replication claim was made.

The gate runs over the **representative set pinned in [§N](#n-representative-set-oracle-pins-and-seeded-mutants)**
and is **red unless every committed seeded mutant named in [§N](#n-representative-set-oracle-pins-and-seeded-mutants) goes red**. Three load-bearing observables are
pinned so no stub, canned handler, or alternate exposure passes: (a) the inference round-trip counts **only** when
the returned bytes **byte-match the Phase-0-committed Phase-26 reproducible golden**
(`spa_gate/infernix_cpu_response.cbor`, authored from Phase-26's reproducible CPU output for the fixed
`spa_gate/prompt.json`, never regenerated from the deployed workflow) for the run's unchanged `experimentHash`
`H_spa`, **and** the run's canonical-CBOR manifest + `.ready` sentinel appear in the Phase-23 content store under
that `experimentHash` namespace; (b) the engine is proven jit-resolved by a **cache-empty preflight** plus a
**first-miss materialization event** whose postflight content-addressed entry hashes to the Phase-25 catalog
identity `spa_gate/engine_identity.txt` within `CacheBudget`, with the deployed images carrying no engine layer;
(c) the UI is reachable **only** through the Keycloak edge, proven by a live exposure sweep matching the
hand-authored `spa_gate/expected_exposures.txt` and a refused pod-IP/Service bypass. The exposure sweep, the
pod-IP-bypass refusal, the first-miss materialization, the zero-election audit, and the postflight inventory diff
are all read from **OS-boundary observers** (the live k8s API server and its audit log, a foreign-pod CNI probe,
the on-disk Phase-25 store, a containerd image inspection), never a self-emitted compliance trace, per [§N](#n-representative-set-oracle-pins-and-seeded-mutants).

## N. Representative set, oracle pins, and seeded mutants

This section fixes the one shared interpretation of the gate's "representative set", committed oracles,
OS-boundary observers, and seeded mutants, so two engineers implement the same gate (§M clauses 1–8). All
artifacts named here are authored and committed **in Phase 0**, before `Amoebius.Spa.{Deploy,Edge}` and
`SpaGateSpec` exist; an oracle regenerated from the deployed implementation is not a test.

- **Representative set (explicit, §M-7):** the gate exercises exactly the composing fixture
  `dhall/examples/spa_chatbot.dhall` (the Phase-12 infernix multi-service surface: `ObjectStore` + `Sql` +
  `MessageBus` + `Identity` + `Edge`) composed with **two** committed deployment-rules layers —
  `spa_chatbot_deploy_linux_cpu.dhall` at `replicas=1` and `spa_chatbot_deploy_linux_cpu_r3.dhall` at a distinct
  replica count — plus `dhall/examples/spa_rl_gaming.dhall` (jitML) as the type-check-only second composition and
  the gate topology `phase_37_spa_live.dhall`. No other surface satisfies "representative".
- **Committed oracle pins (Phase 0, §M-1 / §M-3):**
  - `spa_gate/infernix_cpu_response.cbor` — the expected inference response, **byte-identical to Phase-26's
    reproducible CPU output** for the fixed prompt `spa_gate/prompt.json` at pinned `experimentHash` `H_spa`;
    authored from the Phase-26 reproducible build, independent of the deployed workflow's emitter.
  - `spa_gate/engine_identity.txt` — the expected named Phase-25 catalog engine identity (content hash) the
    resolver must materialize; authored from the catalog, independent of the resolver's runtime output.
  - `spa_gate/expected_exposures.txt` — a hand-authored table naming the single permitted wild exposure (the
    Keycloak-fronted `HTTPRoute` name) and asserting no other `Service`/`NodePort`/`Ingress`/`LoadBalancer` in the
    tenant namespace; the reference side of the exposure check, never derived from the SUT's render output.
  - `spa_gate/spa_edge_negatives.expected` — the expected Gate-1 `dhall type` error locus / Gate-2 `DecodeError`
    tag for the backdoor negative `illegal_spa_open_edge.dhall`, paired with `spa_chatbot.dhall` differing only in
    the gated-vs-open edge dimension; the gate asserts the *tag*, not merely a non-zero exit (§M-8).
- **OS-boundary observers (§M-5), never a self-emitted trace:**
  - Exposure sweep and election audit read from the **live k8s API server** (object enumeration) and its
    **audit log** (zero `coordination.k8s.io` `Lease` acquisitions by any amoebius principal); the pod-IP/Service
    bypass is driven from a **foreign pod via a CNI probe** and must be refused by the derived `NetworkPolicy`.
  - The no-baked-engine check reads from a **containerd image inspection** of the deployed app/workflow images
    (no engine layer) and the registry-pull log (no engine blob pulled at deploy).
  - The first-miss materialization and cache reuse read from the **on-disk Phase-25 content-addressed store**
    (a preflight showing no entry for `H_spa`'s engine identity; a postflight entry whose hash equals
    `engine_identity.txt` within `CacheBudget`), not a workflow self-report.
- **Determinism honesty (§M-6):** cache **reuse** and output **determinism** are distinct claims. Reuse is proven
  by a same-namespace second request that produces **no** new materialization event (a store hit). Determinism is
  proven by a **third run in a distinct tenant namespace with the CacheBudget cache bypassed (cold)** that
  **independently re-resolves the engine and recomputes** the inference, whose response MUST again byte-match
  `spa_gate/infernix_cpu_response.cbor` — proving the compute path, not a memoized store hit, produced the pinned
  bytes.
- **Committed seeded mutants (§M-2), each committed and re-run, from the operator set:**
  - **M-canned** (effect swap): replace the workflow inference call with a canned non-empty handler — the
    byte-match against `infernix_cpu_response.cbor` and the Phase-23 manifest/`.ready` assertion MUST go red.
  - **M-baked** (dropped effect): bake the engine into the app/workflow image and skip the resolver — the
    cache-empty preflight + first-miss materialization assertion and the containerd no-engine-layer check MUST go
    red.
  - **M-openedge** (union-arm addition): emit an ungated `NodePort` alongside the `HTTPRoute` — the exposure
    sweep against `expected_exposures.txt` MUST go red.
  - **M-nopolicy** (dropped effect): omit the derived `NetworkPolicy` — the foreign-pod pod-IP bypass probe MUST
    reach the pod and turn the gate red.
  - **M-election** (guard weakening): introduce a `Lease`-based leader election — the API-server audit-log
    zero-election check MUST go red.

## Doctrine adopted

This phase is the first live amoebius realization of the SPA composition. Each bullet names the section it
adopts; individual sprints cite the same sections where they build on them.

- [`app_vs_deployment_doctrine.md §2`](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is)
  and [`§3`](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)
  — *the application-logic surface* / *the deployment-rules surface*: the SPA spec is a write-once
  application-logic artifact deployed unchanged, while replica counts, the capability provider+shape bindings,
  and the inference substrate live entirely in the orthogonal deployment-rules layer keyed by the SPA app name.
- [`app_vs_deployment_doctrine.md §6`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-demo-web-app-as-application-logic-only)
  — *the proof case: a demo web app as application-logic-only*: the lifted infernix/jitML demo web app is
  application logic that *uses* its extension, deployed here with no extension-specific deployment vocabulary on
  its surface.
- [`app_vs_deployment_doctrine.md §7`](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)
  and [`§8`](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic)
  — *infernix is a shared library; the inference substrate is a deployment rule* / *shared-library use is
  application logic*: the SPA composes the ML workflow by naming *that* it uses infernix; *where* it runs
  (`linux-cpu` here) is bound only in the deployment-rules layer, so the same SPA bytes would accept a
  CUDA/Apple-Metal binding without an app edit.
- [`service_capability_doctrine.md §2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set)
  and [`§7`](../documents/engineering/service_capability_doctrine.md#7-expressing-a-capability-in-the-dsl)
  — *the capability set* / *expressing a capability in the DSL*: the SPA's service dependencies are drawn from
  the fixed no-product union, its `Edge` publishes a route while the Identity-owned door still gates it, and its
  east-west reachability is derived from the declared capability dependency graph, not hand-authored.
- [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  and [`§6`](../documents/engineering/service_capability_doctrine.md#6-fungibility-reconciled-app-surface-invariant-shape-deployment-ruled)
  — *capability → provider → shape: the binding* / *fungibility, reconciled*: the SPA surface is byte-invariant
  across clusters while the provider+shape binding varies in the deployment-rules layer.
- [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-substrate-selected-and-jit-resolved-never-authored)
  — *the InferenceEngine capability — the engine is substrate-selected and jit-resolved, never authored*: the
  inference engine backing the round-trip is a named catalog identity resolved on first miss, not an authored URL
  or a baked payload, keyed to the `linux-cpu` selection of the deployment-rules layer.
- [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  — *the ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss*: the engine materializes
  into the CacheBudget-bounded content-addressed cache (`CacheBudget ≤` host storage), never baked and never
  fetched by arbitrary URL.
- [`platform_services_doctrine.md §2`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1)
  and [`§9`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  — *HA always (including `replicas=1`)* / *the LoadBalancer and the single wild-ingress path*: the SPA rides the
  unchanged HA charts (HA even at `replicas=1`) and its published surface is the sole wild-ingress path, behind
  Keycloak over Envoy/Gateway API.
- [`daemon_topology_doctrine.md §3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  — *exactly one pod is a k8s/etcd property, not an amoebius election*: the SPA is deployed by the
  Deployment-`replicas=1` control-plane singleton (Phase 22), whose single-instance is delegated to k8s/etcd, so
  nothing in this phase runs an election of any kind.

## Sprints

## Sprint 32.1: The SPA deployment-rules layer + live apply via the typed reconciler under the `replicas=1` singleton 📋

**Status**: Planned
**Implementation**: `amoebius-spa/src/Amoebius/Spa/Deploy.hs`,
`amoebius-spa/dhall/examples/spa_chatbot_deploy_linux_cpu.dhall` (target paths; not yet built); consumes the
Phase-12 `Amoebius.Spa.Spec` + `dhall/amoebius/Spa.dhall`, the Phase-15 SSA reconciler, and the Phase-20
`replicas=1` singleton, re-implementing none of them.
**Blocked by**: Phase 13 (the decode-proven SPA spec `Amoebius.Spa.Spec` + `dhall/amoebius/Spa.dhall` +
`prop_spaCompositionDecodes` this deploys); Phase 8 (the capability → provider → shape binder the SPA's needs
resolve against); Phase 16 (the typed SSA reconciler); Phase 19 (the standard HA platform stack); Phase 22 (the
live DSL deploy via the Deployment-`replicas=1` singleton); Phase 23 (the app-tenancy namespace + `<app>/<bucket>`
ObjectStore the SPA deploys into) — all external earlier-phase prerequisites.
**Independent Validation**: a deployment-rules `.dhall` keyed by the SPA app name binds replica counts, the
capability provider+shape bindings (canonical providers; single-node shapes on a small cluster), and the
inference substrate (`linux-cpu`); composed with the **byte-identical** Phase-12 SPA spec it deploys via the
typed reconciler onto the HA stack, a re-run is a no-op (owned field manager, ApplySet prune, wait), and a second
deployment-rules layer at a different replica count composes with the *same* SPA spec — the SPA app-spec normal
form (its hash) unchanged across both.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/service_capability_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`app_vs_deployment_doctrine.md §3 — the deployment-rules surface`](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)
with the binding model of [`service_capability_doctrine.md §4 — capability → provider → shape`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
and [`daemon_topology_doctrine.md §3.1 — exactly one pod is a k8s/etcd property`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election):
author the `linux-cpu` deployment-rules layer that runs the byte-identical Phase-12 SPA spec, and apply it live
through the typed reconciler under the `replicas=1` singleton — none of it touching the SPA app surface.

### Deliverables
- An `Amoebius.Spa.Deploy` model and a `spa_chatbot_deploy_linux_cpu.dhall` keyed by the SPA app name, declaring
  the replica count on the unchanged HA chart (HA even at `replicas=1`), the capability provider+shape bindings
  (canonical providers by default; single-node shapes on a small cluster), and the inference-substrate binding
  set to `linux-cpu`.
- The composition of that layer with the byte-identical Phase-12 SPA spec, rendered by the typed reconciler
  (owned field manager, ApplySet prune, wait) into the Phase-21 tenant namespace + `<app>/<bucket>` ObjectStore,
  applied under the Deployment-`replicas=1` singleton — the singleton stateless (no PVC), its durable state the
  Vault-enveloped MinIO bucket, and its single-instance a k8s/etcd property.
- A demonstration that a second deployment-rules layer at a different replica count composes with the *same* SPA
  spec, the SPA app-spec hash unchanged across both; the rendered manifests are generated artifacts and are
  **not committed**.

### Validation
1. The deployment-rules `.dhall` composes with the SPA spec and renders to the standard HA stack at the chosen
   replica count in the tenant namespace; a **second reconcile while the topology is still deployed** is a no-op,
   defined concretely as an **empty ApplySet prune set** and **zero SSA managed-field mutations** — every owned
   object's `resourceVersion` unchanged across the second apply, as reported by the owned field manager against
   the live k8s API server (not a reconciler self-report). Full teardown→re-spin idempotence is the separate 32.4
   claim.
2. Changing the replica count or the inference-substrate binding changes no SPA `.dhall` or `.hs` source — the
   SPA app-spec normal-form hash is byte-identical across `spa_chatbot_deploy_linux_cpu.dhall` and
   `spa_chatbot_deploy_linux_cpu_r3.dhall`, asserted against a Phase-0-committed expected hash independent of the
   deploy renderer.
3. No orchestration path runs an election, proven by the OS-boundary check: the **k8s API-server audit log**
   records **zero `coordination.k8s.io` `Lease` acquisitions by any amoebius principal** over the run, and the
   only workload controller is the `replicas=1` Deployment whose single-instance is delegated to k8s/etcd. The
   committed seeded mutant **M-election** ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)) — introducing a `Lease`-based leader election — MUST turn this
   check red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 32.2: The SPA behind Keycloak/Envoy — Edge publishes, Identity gates (live) 📋

**Status**: Planned
**Implementation**: `amoebius-spa/src/Amoebius/Spa/Edge.hs`,
`amoebius-spa/test/live/SpaEdgeSpec.hs` (target paths; not yet built); consumes the Phase-19
`Amoebius.Platform.Keycloak` + `Amoebius.Platform.Edge` plumbing and the Phase-8 capability binding,
re-implementing neither. The emitted HTTPRoute is a **generated artifact and is not committed**.
**Blocked by**: Sprint 32.1; Phase 21 (Keycloak owns all wild ingress via Envoy/Gateway API — the wild-ingress
door this route rides).
**Independent Validation**: the SPA's `Edge` publish renders a live Envoy/Gateway-API `HTTPRoute` gated by
Keycloak; a request without a valid session is refused at the edge and an authenticated session **reaches the SPA
UI**, where "reaches the UI" is defined as a **driven browser interaction (Playwright-style) through a real
Keycloak session that loads the served PureScript bundle** — the bundle bytes hashing to the Phase-12 Register-1
golden bundle hash — and completes one UI interaction, **not** a bare HTTP 200. A **live exposure sweep** over the
tenant namespace, read from the k8s API server, matches the hand-authored `spa_gate/expected_exposures.txt` ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)):
the sole wild exposure is the Keycloak-fronted `HTTPRoute`, and a **direct pod-IP/Service request bypassing Envoy,
driven from a foreign pod via a CNI probe, is refused by the derived `NetworkPolicy`**. The backdoor negative
`illegal_spa_open_edge.dhall` fails at its **Phase-0-pinned tagged reason** recorded in
`spa_gate/spa_edge_negatives.expected` (its `dhall type` error locus / `DecodeError` tag), paired with
`spa_chatbot.dhall` differing only in the gated-vs-open edge dimension. Each capability the SPA consumes appears
in the derived east-west graph and a surface consuming an undeclared capability has no derived connectivity to it.
The committed seeded mutants **M-openedge** (an ungated `NodePort`) and **M-nopolicy** (dropped `NetworkPolicy`)
of [§N](#n-representative-set-oracle-pins-and-seeded-mutants) MUST turn the exposure sweep and the bypass probe red respectively.
**Docs to update**: `documents/engineering/service_capability_doctrine.md`,
`documents/engineering/platform_services_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §7 — expressing a capability in the DSL`](../documents/engineering/service_capability_doctrine.md#7-expressing-a-capability-in-the-dsl)
and [`platform_services_doctrine.md §9 — the single wild-ingress path`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
render the SPA's `Edge` publish into a live route fronted by the Identity-owned Keycloak door over Envoy/Gateway
API, deriving east-west reachability from the declared capability dependencies, with no representable
unauthenticated backdoor.

### Deliverables
- An `Amoebius.Spa.Edge` rendering that turns the SPA's `Edge` publish declaration into a live Envoy/Gateway-API
  `HTTPRoute` fronted by Keycloak (consuming the Phase-19 `Platform.Keycloak` / `Platform.Edge` plumbing), with
  the `Identity` auth rule bound to that route — the SPA declares *what to publish*, never *whether* wild traffic
  reaches it.
- The SPA's east-west reachability derived from its declared capability dependencies, so it can reach exactly the
  providers it declared consuming and nothing else; the rendered route/NetworkPolicy objects are generated and
  not committed.
- A structural guarantee that no SPA surface can express an unauthenticated published route: the only edge the
  type admits is one behind the Identity-owned door (this is the [`app_vs_deployment_doctrine.md §6`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-demo-web-app-as-application-logic-only)
  demo-web-app-as-application-logic-only surface, deployed live).

### Validation
1. The chatbot SPA's published surface renders a live `HTTPRoute` gated by Keycloak; a request without a valid
   session is refused at the edge and an authenticated session reaches the UI **via a driven Playwright
   interaction serving the Phase-12-golden PureScript bundle bytes** (not a bare 200). The API-server exposure
   sweep matches `spa_gate/expected_exposures.txt` — the Keycloak `HTTPRoute` is the sole wild exposure — and a
   foreign-pod pod-IP/Service bypass is refused by the derived `NetworkPolicy`; **M-openedge** and **M-nopolicy**
   ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)) MUST turn these red.
2. The backdoor variant `illegal_spa_open_edge.dhall` fails Gate 1 **at its Phase-0-pinned tag in
   `spa_gate/spa_edge_negatives.expected`** (the recorded `dhall type` error locus / `DecodeError` tag, not a mere
   non-zero exit), paired with `spa_chatbot.dhall` differing only in the edge-gating dimension; a surface
   consuming an undeclared capability has no derived connectivity to it.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 32.3: The composed ML-workflow inference round-trip — live infernix on linux-cpu 📋

**Status**: Planned
**Implementation**: `amoebius-spa/test/live/SpaInferenceSpec.hs` (target path; not yet built); consumes the
Phase-23 content store + workflow runtime, the Phase-26 infernix CPU-inference lift, and the Phase-25 jit-build
engine cache, re-implementing none of them.
**Blocked by**: Sprint 32.1; Phase 25 (the content store + orchestrator/worker workflow runtime the inference
request round-trips over); Phase 33 (the infernix CPU-inference lift + its demo web app); Phase 32 (the
jit-build engine resolver + CacheBudget content-addressed cache the engine materializes into); Phase 34 (the
jitML lift whose RL-gaming demo composes and type-checks as the second worked composition).
**Independent Validation**: an inference request reaches the deployed SPA and round-trips through the composed
infernix chatbot workflow on the Phase-23 runtime, and the response **byte-matches the Phase-0-committed Phase-26
reproducible golden `spa_gate/infernix_cpu_response.cbor`** for the fixed `spa_gate/prompt.json` at unchanged
`experimentHash` `H_spa`, **and** the run's canonical-CBOR manifest + `.ready` sentinel appear in the Phase-23
content store under that `experimentHash` namespace — pinning the bytes to infernix output, not a canned handler.
The engine is proven jit-resolved on first miss, **not** baked or pre-warmed, by three OS-boundary reads ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)): a
**preflight** showing the Phase-25 content-addressed store holds **no entry** for `H_spa`'s engine identity; a
**first-miss materialization event** whose postflight entry hashes to `spa_gate/engine_identity.txt` within
`CacheBudget`; and a **containerd image inspection** confirming the deployed app/workflow images carry **no engine
layer**. A same-namespace **second request is served from the cache with no new materialization event** (reuse,
not re-resolution). Output determinism is proven separately (§M-6) by a **third run in a distinct tenant namespace
with the cache cold/bypassed** that independently re-resolves and recomputes, whose response MUST again byte-match
the same golden. The jitML RL-gaming SPA composes and type-checks against the same SPA spec, while a grep of
neither SPA surface names a substrate; running the jitML workflow on a CUDA/Apple-Metal substrate is explicitly
out of contract for this single-substrate gate. The committed seeded mutants **M-canned** and **M-baked** ([§N](#n-representative-set-oracle-pins-and-seeded-mutants))
MUST turn the byte-match and the first-miss/no-engine-layer checks red respectively.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/service_capability_doctrine.md`, `documents/engineering/content_addressing_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`app_vs_deployment_doctrine.md §7 — infernix is a shared library; the inference substrate is a deployment rule`](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule),
[`service_capability_doctrine.md §4.1 — the engine is substrate-selected and jit-resolved`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-substrate-selected-and-jit-resolved-never-authored),
and [`content_addressing_doctrine.md §4.5 — one bounded content-addressed cache, resolved on first miss`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
round-trip a real inference request through the composed infernix workflow on `linux-cpu`, the engine jit-resolved
into the bounded cache rather than baked or URL-fetched, while the jitML composition is proven to type-check
without being run.

### Deliverables
- A live inference round-trip: a request reaches the deployed chatbot SPA, is served by the composed infernix
  workflow on the Phase-23 orchestrator/worker runtime (unelected workers; single-writer delegated to the Pulsar
  subscription), and the response returns to the caller.
- The inference engine backing the round-trip resolved as a **named catalog identity on first miss** into the
  Phase-25 CacheBudget-bounded content-addressed cache (`CacheBudget ≤` host storage) — never baked into the base
  image, never fetched by arbitrary URL — and reused from cache by a second request, keyed to the `linux-cpu`
  substrate selection of the deployment-rules layer (Sprint 32.1).
- The jitML RL-gaming demo SPA composed and type-checked against the same SPA spec (the "any combination" claim),
  with an explicit note that *running* its workflow on a GPU/Apple-Metal substrate is out of contract for this
  single-substrate gate — the substrate is a deployment dial, not an app edit.

### Validation
1. An inference request round-trips through the composed infernix workflow and the response **byte-matches
   `spa_gate/infernix_cpu_response.cbor` at `experimentHash` `H_spa`**, with the run's manifest + `.ready` sentinel
   present in the Phase-23 store; a cache-empty **preflight** and a **first-miss materialization** to
   `spa_gate/engine_identity.txt` (within `CacheBudget`) plus a **containerd no-engine-layer** inspection prove
   jit-resolution; a same-namespace second request reuses the cache with **no new materialization event**; and a
   **distinct-namespace cold-cache third run recomputes to the same golden** (§M-6). **M-canned** and **M-baked**
   ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)) MUST go red.
2. The jitML RL-gaming SPA composes and type-checks against the same SPA spec; neither SPA surface names an
   inference/training substrate.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 32.4: The live SPA gate — deployed, reachable, inference round-trips, leak-free teardown 📋

**Status**: Planned
**Implementation**: `amoebius-spa/dhall/test/phase_37_spa_live.dhall` (the gate topology),
`amoebius-spa/test/live/SpaGateSpec.hs` (target paths; not yet built).
**Blocked by**: Sprint 32.2 (the live Keycloak/Envoy edge the gate reaches through); Sprint 32.3 (the composed
inference round-trip the gate exercises); Phase 14 / Phase 17 (the cluster-lifecycle + retained-storage teardown
the InForceSpec drives).
**Independent Validation**: a gate `InForceSpec` over the **[§N](#n-representative-set-oracle-pins-and-seeded-mutants) representative set** composes the multi-service SPA
+ the infernix demo app's ML workflow with the `linux-cpu` deployment-rules layer, deploys via the typed
reconciler under the `replicas=1` singleton, reaches the SPA UI through the Keycloak/Envoy edge (a driven
Playwright interaction serving the Phase-12-golden bundle, with the API-server exposure sweep matching
`spa_gate/expected_exposures.txt` and the pod-IP bypass refused), round-trips an inference request whose response
**byte-matches `spa_gate/infernix_cpu_response.cbor`** with the engine proven first-miss-materialized ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)), and
tears the deployment down **leak-free**. "Leak-free (postflight sweep empty)" is defined as the union of (a) the
**Phase-31 tag-scoped sweep** AND (b) a **full preflight→postflight substrate inventory diff** (tenant namespaces,
PVs/PVCs, CRs, MinIO buckets, `kind` containers) read from the k8s API server and host, which MUST be empty
**except for the single documented retained-by-design item**: the materialized `CacheBudget` engine entry on the
host cache, asserted present-and-within-budget, never counted as a leak; any retained PV, orphaned namespace, or
leftover `kind` container fails the gate. The gate is **red unless the committed seeded mutants of [§N](#n-representative-set-oracle-pins-and-seeded-mutants)
(M-canned, M-baked, M-openedge, M-nopolicy, M-election) each go red**. The run re-runs idempotently and emits a
per-run proven/tested/assumed ledger that marks no GPU/Apple-Metal ML-workflow claim and no geo-replication claim
green.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/service_capability_doctrine.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md`.

### Objective
Adopt [`app_vs_deployment_doctrine.md §2 — the application-logic surface`](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is)
and [`service_capability_doctrine.md §7 — expressing a capability in the DSL`](../documents/engineering/service_capability_doctrine.md#7-expressing-a-capability-in-the-dsl),
with the Register-3 spin-up → run → always-tear-down contract of `testing_doctrine.md §2`: prove the whole
composition live on `linux-cpu` — one SPA `.dhall` composing a multi-service app + an ML-workflow demo app,
deployed, reachable behind Keycloak/Envoy, its inference round-tripped, and torn down leak-free.

### Deliverables
- A gate `phase_37_spa_live.dhall` `InForceSpec` and its `SpaGateSpec` that spins up the SPA composing the
  infernix chatbot demo app from one app spec plus the `linux-cpu` deployment-rules layer, deploys it via the
  typed reconciler under the `replicas=1` singleton, reaches the SPA UI through the Keycloak/Envoy edge,
  round-trips an inference request through the composed infernix workflow, and always tears the deployment down.
- A check that the jitML RL-gaming demo app SPA also composes and type-checks (the "any combination" claim), with
  an explicit note that *running* its workflow on a GPU/Apple-Metal substrate is out of contract for this
  single-substrate gate.
- The **Phase-0-committed [§N](#n-representative-set-oracle-pins-and-seeded-mutants) oracle set and mutant set** the gate checks against: `spa_gate/prompt.json`,
  `spa_gate/infernix_cpu_response.cbor` (the Phase-26 reproducible golden), `spa_gate/engine_identity.txt`,
  `spa_gate/expected_exposures.txt`, `spa_gate/spa_edge_negatives.expected`, the backdoor negative
  `illegal_spa_open_edge.dhall`, and the committed seeded mutants M-canned, M-baked, M-openedge, M-nopolicy, and
  M-election — all authored and committed before `SpaGateSpec` exists.
- A per-run proven/tested/assumed ledger artifact recording: the multi-service + ML-workflow composition as
  **tested on linux-cpu**, the SPA app-surface byte-invariance across the deployment-rules variations as
  **tested**, edge reachability behind Keycloak and the inference round-trip as **tested**, and any GPU/Apple-Metal
  ML-workflow claim and any geo-replication claim as **explicitly not asserted**.

### Validation
1. The SPA deploys on the standard HA stack and its UI is reachable **only** through the Identity-owned edge —
   proven by the API-server exposure sweep matching `spa_gate/expected_exposures.txt` and the refused foreign-pod
   pod-IP bypass — and an inference request is served by the composed infernix workflow whose response
   **byte-matches `spa_gate/infernix_cpu_response.cbor`** with the engine first-miss-materialized to
   `spa_gate/engine_identity.txt` ([§N](#n-representative-set-oracle-pins-and-seeded-mutants)).
2. The RL-gaming SPA composes and type-checks; the topology tears down leak-free — the Phase-31 tag-scoped sweep
   **and** the preflight→postflight substrate inventory diff are empty save the documented retained `CacheBudget`
   engine entry — and a second reconcile-while-deployed is a no-op (empty ApplySet prune, zero SSA field
   mutations). All committed [§N](#n-representative-set-oracle-pins-and-seeded-mutants) mutants (M-canned, M-baked, M-openedge, M-nopolicy, M-election) go red.
3. The run emits a proven/tested/assumed ledger; it marks no GPU-substrate or geo-replication claim green, and
   skipping an applicable move marks that layer UNVERIFIED, never green.

> **Honesty.** This gate deploys the SPA composition already decode-proven at Registers 1–2 in
> [Phase 13](phase_13_spa_composition_representational.md); the representational battery and the local
> Playwright run are that phase's result, not this one's. The infernix/jitML demo web apps and their inference
> runtimes are proven over WebSockets in the siblings — **sibling evidence, not an amoebius result** — this phase
> deploys them live under the amoebius edge and runtime for the first time. No cross-cluster gateway migration and
> no geo-replication is claimed here; those are Phase 28.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/app_vs_deployment_doctrine.md` — record the SPA as the live composition apex of §2/§3/§8:
  a write-once application-logic artifact composing an ML workflow as shared-library use, deployed with its
  replicas, provider+shape, and inference substrate bound only in the deployment-rules layer (§7), the same SPA
  bytes across the variations.
- `documents/engineering/service_capability_doctrine.md` — backlink §7 to the live SPA `.dhall` as a worked
  multi-service surface whose `Edge` publishes behind the Identity-owned door, and §4.1 to the jit-resolved,
  substrate-selected inference engine backing the round-trip (status recorded here in the plan, never as doctrine
  status).
- `documents/engineering/content_addressing_doctrine.md` — note §4.5 realized: the inference engine materialized
  on first miss into the CacheBudget-bounded content-addressed cache and reused, never baked or URL-fetched.
- `documents/engineering/platform_services_doctrine.md` — note the SPA's published surface as a live consumer of
  the §9 single wild-ingress path (Keycloak over Envoy/Gateway API) on the §2 HA-always charts.
- `documents/engineering/testing_doctrine.md` — record the Phase-32 gate `InForceSpec` as a worked Register-3
  spin-up/run-workflow/tear-down composition test emitting a per-run proven/tested/assumed ledger.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-32 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 37's gate substrate (`linux-cpu`) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `amoebius-spa/src/Amoebius/Spa/{Deploy,Edge}.hs` and the
  Phase-32 live gate topology, mapped to the owning app-vs-deployment and service-capability doctrines, as
  Phase-32 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker; Phase 37 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the skeleton,
  the sprint format, the doctrine-citation rule, and the three-register + honesty + one-substrate disciplines)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no bespoke election;
  single-instance delegated to k8s/etcd; the two DSL surfaces; jit-resolved engines)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Application Logic vs Deployment Rules Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — the
  SPA as application logic; ML-workflow composition as shared-library use; the inference substrate as a deployment rule
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — the capabilities the SPA
  composes (never products), the Edge-behind-Identity door, and the jit-resolved InferenceEngine capability
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — §4.5 the
  ML engine jit-resolved into a bounded content-addressed cache, never baked or URL-fetched
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the HA-always charts and
  the single wild-ingress path the SPA edge rides
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — §3.1 exactly one pod is a
  k8s/etcd property, not an amoebius election
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live), the spin-up → run →
  always-tear-down contract, and the per-run ledger
- [phase_13](phase_13_spa_composition_representational.md) — the representational SPA composition proven in-process
  (`prop_spaCompositionDecodes` + the local demo SPA) that this phase deploys live
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
