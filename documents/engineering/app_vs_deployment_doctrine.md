# Application Logic vs Deployment Rules

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

> **Purpose**: Define the hard separation between an app's **application logic** (what it *is* to a user)
> and its **deployment rules** (how, where, and how robustly it runs), so one app spec is written once and
> composes unchanged onto a single cluster or N geo-replicated clusters.

---

## 1. Two surfaces, one app written once

The single most leverage-bearing idea in amoebius is that **an app does not know how many of it exist.**
A developer describes *what their app is* — its UI, its users, the data it keeps, the libraries it leans on
— and **never** writes down how many replicas run, in how many regions, behind what failover policy, under
what chaos schedule. Those are someone else's decision, made later, in a separate place, and the app is none
the wiser.

Concretely, amoebius splits the Dhall DSL into two **orthogonal surfaces**:

| Surface | Answers | Written by | Example values |
|---------|---------|------------|----------------|
| **Application logic** (the app spec) | *What is this app?* | the app author, once | UI / LB services, Keycloak auth rules, durable-storage needs, Pulsar topics, shared-library use |
| **Deployment rules** | *How, where, how robustly does it run?* | the operator, per deployment | HA replica counts, geo-replication topology, gateway failover, chaos-test injection, inference substrate |

These are not two halves of one file that happen to be near each other — they are **separable inputs**. The
app spec joins with *a* deployment-rules layer to produce *a* deployment; swap the deployment-rules layer
and you get a different deployment from byte-identical app logic. The grammar of these two surfaces — the
Dhall record/union types, total composability, and the illegal-state-unrepresentable contract — is owned by
[dsl_doctrine.md](./dsl_doctrine.md). This document owns only the **dividing line**: which concerns live on
which surface, and why the line must never be crossed (DEVELOPMENT_PLAN
cross-cutting invariant "Application logic and deployment rules are separate DSL surfaces").

> **Honesty.** This split is *specified* doctrine for Phase 3 (the DSL type families) and *demonstrated* by
> the mattandjames reduction in Phase 8 — neither phase has been built. Read every prescriptive statement
> here as design intent, never as a tested amoebius result. Status and gates live only in
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) (per
> [documentation_standards.md §6](../documentation_standards.md)).

---

## 2. The application-logic surface — what an app *is*

Lead with the intuition: **everything on this surface survives a move.** If you tore the app off its cluster
and stood it up somewhere else, on a different substrate, at a different scale, these are the things that
would have to come *with* it because they *are* the app. An amoebius app is exactly two artifacts: one or
more container images that build for both `amd64` and `arm64`, and an **app-spec `.dhall`**. The image-build pipeline is owned by [image_build_doctrine.md](./image_build_doctrine.md);
this surface owns the spec.

The app-spec surface declares:

- **UI and user lifecycles** — what surfaces the app exposes and what a user can do with them.
- **LB services** — *which* of the app's services are reachable from the edge. (Whether they are reachable
  is never the app's call: all wild ingress is owned by Keycloak via the LB + Gateway API — see
  [platform_services_doctrine.md §9](./platform_services_doctrine.md). The app declares *what to publish*;
  it cannot publish a backdoor.)
- **Keycloak-backed auth rules** — the OIDC identity and authorization rules that gate the app's surfaces.
- **Durable-storage needs** — the MinIO buckets it keeps (named `<app>/<bucket>`), any `no-provisioner`
  block storage it provisions, and any Postgres database it requests in its own namespace. The app declares
  *what data it keeps*; the retained-PV mechanics, sizing, and deterministic rebind that make that data
  durable are owned by [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md), and the
  one-Patroni-cluster-per-consumer rule by [platform_services_doctrine.md §8](./platform_services_doctrine.md).
- **Pulsar topic lifecycles** — the event/workflow topics the app owns and how they live and die. The
  native-protocol client and topology algebra are owned by
  [pulsar_client_doctrine.md](./pulsar_client_doctrine.md); the app surface owns *which topics exist for
  this app*.
- **Use of shared libraries** — that the app builds on infernix, jitML, or (later) a Haskell extension
  module is part of what the app *is* (see §8).

Two structural facts pin app identity to the cluster: an app's **name is unique per
cluster**, and the app gets **its own namespace with that same name**. Secrets appear here **by name only** —
the app references a secret; it never contains one. The secret-by-name `SecretRef` contract and
parent-injects-into-child model are owned by [vault_pki_doctrine.md](./vault_pki_doctrine.md) and must not
be restated here.

What is *conspicuously absent* from this surface is the whole vocabulary of §3: there is no replica count, no
region, no failover policy, no chaos knob, no substrate selector. The app author cannot write those words
because the type does not have those fields.

---

## 3. The deployment-rules surface — how the same app *runs*

The intuition is the mirror image of §2: **everything on this surface is about robustness, scale, and
placement — and none of it changes what the app is.** Turn every one of these dials and a user sees the
identical app; they just see it survive more, scale wider, or run on different hardware.

The deployment-rules surface declares:

- **HA replica counts.** How many of each component run. The app spec never names a number; the chart is
  **HA even at `replicas=1`** ([platform_services_doctrine.md §2](./platform_services_doctrine.md)), so the
  replica value is a pure deployment dial that rides an unchanged chart. Where the replica value physically
  lives in the DSL (a cluster-scoped `cluster.dhall` value seeded at `bootstrap` vs a per-app deployment
  block) is a [dsl_doctrine.md](./dsl_doctrine.md) concern; this doc owns only the rule that it is **never**
  app logic.
- **Geo-replication topology.** Whether the app runs on one cluster or N geographically-replicated clusters,
  and how their durable state is kept in step (via the Pulsar / MinIO / Postgres idioms — see §9). The
  cross-cluster mechanics are owned by [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md).
- **Failover policy.** When and how the lead cluster's gateway fails over and DNS is repointed. The async cross-cluster correctness boundary — the one place a per-system proof
  obligation concentrates — is owned by [chaos_failover_doctrine.md](./chaos_failover_doctrine.md).
- **Chaos-test injection.** The app **does not know it is being chaos-tested.** A chaos schedule is attached
  here, never in the app spec; the Extract→Model→Inject methodology and the proven/tested/assumed ledger are
  owned by [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), and the test-as-a-`.dhall`-topology
  model by [testing_doctrine.md](./testing_doctrine.md).
- **Inference substrate.** Whether an ML workload runs on Apple Metal on the host, CUDA on the cluster, or
  linux-cpu is a deployment decision, not app logic — see §7.
- **Dynamic node provisioning policy.** Scaling nodes by arbitrary logic — load, spot-instance cost, or
  workflow completion — is a deployment rule, owned operationally by
  [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md).

This surface is **keyed by app**: a deployment-rules layer references an app by name and says *how to run
it*. The same app name can appear in two different deployment-rules layers and run two completely different
ways, with zero edits to its app spec.

---

## 4. The dividing line — a litmus test

When it is unclear which surface a concern belongs to, apply one rule:

> **If changing it changes what the app *is* to a user, it is application logic. If changing it changes only
> how many copies run, where they run, or how robustly they run, it is a deployment rule.**

App logic answers **WHAT**; deployment rules answer **HOW MANY / WHERE / HOW ROBUST**. Worked through some
deliberately tricky cases:

| Concern | Surface | Why |
|---------|---------|-----|
| "The app exposes a chat UI" | application logic | it is *what the app is* |
| "The chat UI is reachable from the edge" | application logic (declares the LB service) | *what to publish*; the edge is still Keycloak's |
| "Run 5 replicas of the chat backend" | deployment rule | a scale dial; same app at 1 or 5 |
| "The app keeps a `messages` bucket and a Postgres DB" | application logic | *what data it keeps* |
| "Those PVs are 50Gi, retained, host-bound" | neither — owned by [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) | a platform mechanic, not an app or deployment dial |
| "The app uses infernix for inference" | application logic | a shared-library dependency (§8) |
| "Inference runs on Apple Metal vs CUDA" | deployment rule | a placement choice (§7) |
| "Replicate the app across us-east and eu-west and fail over" | deployment rule | topology + robustness; the app is unchanged (§9) |
| "Inject a broker kill every 10 minutes" | deployment rule | the app does not know it is being tested |
| "A login requires MFA for the admin role" | application logic | an auth rule that *defines* the app's behaviour |

**Misfiling is a bug, not a style preference.** A replica count that leaks into the app spec re-couples
scale to logic and breaks write-once; a UI route that leaks into deployment rules makes the deployment layer
non-swappable. [dsl_doctrine.md](./dsl_doctrine.md) and
[illegal_state_catalog.md](./illegal_state_catalog.md) are the SSoTs for *which* of these boundaries are
lifted into the type layer so that a misfiled field is **unrepresentable** rather than merely discouraged —
this doc states the policy; those docs own the enforcement.

---

## 5. Why the split matters — cashing it out

Three concrete payoffs, each a direct consequence of keeping the line clean:

- **Write once.** An app is authored a single time, deployment-agnostic. There is no "dev version" and
  "prod version" of the app spec; there is one app spec and many deployment-rules layers. This kills the
  whole *works-on-my-laptop, breaks-in-prod* class of bug at the source — the laptop deployment and the
  production deployment run the **same app bytes on the same HA charts**
  ([platform_services_doctrine.md §2](./platform_services_doctrine.md)); only the deployment dials differ.
- **Orthogonal evolution.** Operators tune replicas, add a failover region, or schedule chaos without ever
  opening the app's source — and app authors ship features without ever reasoning about topology. The two
  teams change different files.
- **Composability.** Because the surfaces are separable inputs, the *same* app composes with *any* valid
  deployment-rules layer (total composability). The proof case is §6 and the
  extreme case is §9.

The deepest payoff is that the split makes a whole category of mistakes **unrepresentable**: the app surface
literally has no field in which to name a replica count or a region, and the deployment surface has no field
in which to name a UI route or a bucket. You cannot accidentally hard-code "3 replicas" into application
logic because there is nowhere to type it. That structural guarantee is owned by
[dsl_doctrine.md](./dsl_doctrine.md) / [illegal_state_catalog.md](./illegal_state_catalog.md); this doc owns
the *reason* it is worth enforcing.

---

## 6. The proof case: mattandjames boiled to application-logic-only

mattandjames is the canonical demonstration of this doctrine, because it currently violates it and the plan
is to fix it.

**Today**, mattandjames bakes deployment decisions into the app: it ships a naive **CPU-only inference
engine**, it deploys itself **exclusively on kind** in a **mock 3-replica mode**, and it simulates HA by
standing up *multiple kind clusters*. Scale, substrate, and HA strategy are all welded into the application
— so the "3" is unchangeable without editing the app, and the inference engine cannot move off CPU without a
rewrite.

**Target**: mattandjames is **boiled down to application logic only** — the UI,
the user lifecycles, the durable data, the auth rules. Then a *single* amoebius `.dhall` deployment-rules
layer configures, **with zero extra effort from the application itself**:

- the k8s cluster distro (kind / rke2 / provider),
- the replication count (the "3" becomes a `replicas=n` dial on an unchanged HA chart), and
- the model-inference substrate (Apple Metal on the host, CUDA on the cluster, or linux-cpu).

The mock-3-replica pattern collapses to a `replicas=n` value; the multi-kind-cluster HA simulation collapses
to the standard HA stack at the chosen replica count
([platform_services_doctrine.md §2](./platform_services_doctrine.md)); the naive CPU inference is replaced
by an infernix workflow (§7).

> **Honesty.** This reduction is **Phase 8** in [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md)
> and is **not started**. The current mattandjames behaviour above is observed fact; the boiled-down target
> is design intent, not a proven amoebius result.

---

## 7. infernix is a shared library; the inference substrate is a deployment rule

This is the subtlest application of the litmus test, so make the distinction explicit:

- **"The app uses infernix"** is **application logic.** infernix is an ML extension *library*; depending on
  it is part of what the app is (§8). A workflow that calls infernix is the same call graph regardless of
  where it runs.
- **"Inference runs on Apple Metal vs CUDA vs linux-cpu"** is a **deployment rule.** *Where* the inference
  workload is placed — a host compute daemon using Apple Silicon's unified memory, a CUDA pod on the
  cluster, or a CPU pod — is a substrate/placement choice, configured in the deployment-rules layer with no
  change to the app.

infernix is "an amoebius extension: a single Haskell binary that can be deployed as a distributed system
either at node-system level (in an Apple cluster) or cluster level (as a stateless deployment)". That *dual* placement is precisely a deployment decision — the same infernix logic,
two placements. Consequently **the infernix `.dhall` nests inside the amoebius `.dhall`**: infernix's own configuration is composed into the larger deployment spec rather than living as a
parallel system. The host-vs-cluster placement mechanics (host compute daemons as Pulsar/MinIO peers over
host-only NodePorts, no mTLS) are owned by [platform_services_doctrine.md §9](./platform_services_doctrine.md)
and the host↔cluster comms doctrine; the determinism and content-addressing that make an infernix run
reproducible are owned by the content-addressing doctrine. This section owns only the *classification*: the
dependency is app logic, the placement is a deployment rule.

---

## 8. Shared-library use is application logic

Which libraries an app builds on — infernix, jitML, and (a later phase) Haskell extension modules validated
by a custom AST checker — is part of what the app *is*, and therefore lives
on the application-logic surface. The clean way to hold this with §7:

- The library **call graph** — *that* the app invokes infernix, *which* workflows it composes — is
  application logic; it would travel with the app to any cluster.
- The **placement** of the workload that executes that call graph — host vs cluster, Metal vs CUDA vs CPU,
  at what replica count — is a deployment rule.

Treating shared-library use as app logic is what lets jitML and infernix be *unified libraries under the
DSL* rather than separate products (DEVELOPMENT_PLAN: "the constituent projects are not separate products").
The later-phase Haskell extension DSL is tracked in
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); this doc does not own its design, only
its classification.

---

## 9. Composition: one cluster → N geo-replicated clusters, zero app change

The extreme case proves the doctrine: take an app running on a single kind cluster and replicate it across N
geographically-distributed clusters with automatic gateway failover — **and change not one byte of the app
spec.** Everything that makes that move happen lives in deployment rules and platform idioms.

```mermaid
flowchart LR
  app[App spec dhall written once: UI, LB services, auth rules, durable storage, Pulsar topics, shared libraries] -->|joined with| r1[Deployment rules A: single cluster, replicas=1]
  app -->|same bytes, joined with| r2[Deployment rules B: N clusters, geo-replicated, gateway failover]
  r1 -->|renders| d1[Deployment: one cluster, one region]
  r2 -->|renders| d2[Deployment: N geo-replicated clusters, route53 failover]
```

Cashing out "zero app change":

- The app already declares its durable state — MinIO buckets, Pulsar topics, a Postgres DB (§2). The
  deployment-rules layer says *replicate them across clusters*; the **platform idioms carry the state**:
  Pulsar geo-replication, MinIO replication, and Patroni/Postgres replication. The app's data model is unchanged; only its replication topology is.
- Gateway failover and route53 repointing are deployment-rules + cluster-lifecycle
  concerns — the app never repoints its own DNS.
- The app spec is **byte-identical** across the single-cluster and N-cluster deployments; the diff is
  entirely in the deployment-rules layer.

> **Honesty.** Geo-replication and cross-cluster failover are **Phase 9** and **not started**. Synchronous
> intra-cluster HA is delegated to the systems that do their own consensus (MinIO / Pulsar / Postgres /
> Patroni); the **asynchronous** cross-cluster boundary — what happens if a cluster dies mid-geo-sync and we
> fail over to it — is an open correctness obligation owned by
> [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), not a proven result. This doc claims only that
> the *app surface is unchanged* across the two topologies — it makes no claim that the failover is correct.

---

## 10. What this document does not own

This doc owns the **classification** — which surface a concern lives on — and nothing else. The owners of the
mechanics it points at:

| Topic | Owner |
|-------|-------|
| The DSL grammar, the cluster / app-spec / deployment-rules type families, total composability | [dsl_doctrine.md](./dsl_doctrine.md) |
| Which misfiling boundaries are type-enforced (made unrepresentable) | [illegal_state_catalog.md](./illegal_state_catalog.md) |
| The standard service set, HA-always, Keycloak-owns-all-ingress | [platform_services_doctrine.md](./platform_services_doctrine.md) |
| Durable-storage mechanics: retained `no-provisioner` PVs, sizing, rebind | [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) |
| Secrets-by-name, `SecretRef`, parent-injects-into-child | [vault_pki_doctrine.md](./vault_pki_doctrine.md) |
| Services as **capabilities** (ObjectStore, Sql, …), one canonical provider, per-cluster shape | [service_capability_doctrine.md](./service_capability_doctrine.md) |
| Rendering a shape into typed manifests + the typed reconciler (no Helm) | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| Image build (buildx multi-arch, baked binaries + the `distribution` registry, versioning) | [image_build_doctrine.md](./image_build_doctrine.md) |
| Geo-replication / failover mechanics, dynamic node provisioning, teardown | [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md) |
| The async cross-cluster proof obligation + chaos methodology | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) |
| Test-as-a-`.dhall`-topology, `suggest-test`, the ledger | [testing_doctrine.md](./testing_doctrine.md) |

---

## 11. Planning ownership

This document is normative classification doctrine only. Delivery sequencing, completion status, validation
gates, and remaining work are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md):
the two DSL surfaces land with the type families in **Phase 3**, the mattandjames reduction is **Phase 8**,
and the zero-app-change geo-replication case is **Phase 9**. This doc never maintains a competing status
ledger; it states the target shape and links back for status.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [DSL Doctrine](./dsl_doctrine.md)
- [Platform Services Doctrine](./platform_services_doctrine.md)
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md)
- [Testing Doctrine](./testing_doctrine.md)
- [Illegal State Catalog](./illegal_state_catalog.md)
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md)
- [Vault / PKI Doctrine](./vault_pki_doctrine.md)
- [Image Build Doctrine](./image_build_doctrine.md)
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
