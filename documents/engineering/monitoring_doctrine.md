# Monitoring Doctrine

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/illegal_state/illegal_state_catalog.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md
**Generated sections**: none

> **Purpose**: Make monitoring a mandatory, non-vacuous property of a workflow and of an extension — so an
> unmonitored workflow, an unmonitored extension, and an unauthenticated monitoring surface are all
> unrepresentable — and define the derived dashboards, the operator read-model, the admin/per-user access
> model, the extensible per-workflow surfaces (TensorBoard), the parent-monitoring posture, and the honest
> foreclosure layer each obligation reaches.

---

## 1. Monitoring is a property of the workflow, not a bolt-on

**The problem.** A workflow can decode, deploy, and then go dark: its daemons run, its topics carry traffic,
and nothing observes whether it is healthy. Observability today is a **cluster** capability
([service_capability_doctrine.md](./service_capability_doctrine.md), Prometheus/Grafana) — never a property
of a workflow. So a `RouteEntry`, an `ExtensionSpec`, and an app spec can all be constructed with no
monitoring obligation attached; the gap surfaces only at runtime, as an unmonitored production workflow
nobody is alerted on.

**Why the obvious alternative fails.** The tempting fix is an *optional* monitoring field plus a convention
that operators fill it in, and a Grafana instance operators are trusted to add panels to. Optionality and
operator diligence are exactly what the catalog rejects elsewhere: the mandatory non-optional `RetentionPolicy`
([illegal_state_catalog.md §3.20](../illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)) exists because "keep forever" as an optional
default is a disk-full outage, and `TestTopology`'s non-optional `teardown`
([testing_doctrine.md](./testing_doctrine.md)) exists because "tear down if the operator remembers" leaks
resources. An optional monitor is monitored-if-remembered.

**The chosen rule.** Monitoring is a **mandatory, non-vacuous field** of the workflow and extension types, and
the surfaces it drives are **derived** from that field, never hand-authored. A `Workflow` without a
`WorkflowMonitor`, a `RouteEntry` without a `Liveness`, and an `ExtensionSpec` without its `extMonitoring`
surfaces each have **no inhabitant** ([§2](#2-the-three-mandatory-obligations)). This is the
required-field-by-construction technique ([illegal_state_catalog.md §4.1](../illegal_state/illegal_state_techniques.md#41-pvcpv-binding-by-construction)) applied to observability, and it
mirrors the `TrainBudget` `Continuous`-requires-`checkpointCadence` foreclosure
([content_addressing_doctrine.md](./content_addressing_doctrine.md)).

**What it forecloses.** An author loses the freedom to ship a workflow with monitoring deferred to later — the
obligation must be discharged for the spec to decode. And the guarantee is honest about its limit: the type
forces a monitor to *exist* and be *non-vacuous by construction*, not to be *operationally meaningful* — that
an SLI names a live metric series, and that the objective is actually met, is runtime-checked
([§8](#8-the-three-foreclosure-layers)), never claimed stronger.

---

## 2. The three mandatory obligations

Monitoring attaches at three points, each a required field whose omission is uninhabitable.

### 2.1 Per-workflow SLO — `Workflow.monitor`

The topology SSoT is promoted from a bare `List RouteEntry` to a per-workflow grouping record. `monitor` is
mandatory; the routing lanes carry their own per-topic liveness ([§2.2](#22-per-topic-liveness--routeentryliveness)):

```
Workflow = { name : Text, routes : NonEmpty RouteEntry, monitor : WorkflowMonitor }

WorkflowMonitor = { sli : NonEmpty Sli, objective : Objective, sink : AlertBinding }
Sli          = { name : MetricName, kind : SliKind, objective : Objective }
SliKind      = < Availability | Latency | Saturation | Freshness | Backlog >
Objective    = { threshold : Quantity, window : Duration }
AlertBinding = < ToObservability : { severity : Severity } >
Severity     = < Page | Warn >
```

`sli` is `NonEmpty` — the same no-empty-list idiom that makes a routing entry with no lanes unroutable
([pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra)). `AlertBinding` has **one** arm, routing to the cluster
`Observability` capability by name — no URL arm and no product arm, mirroring the capability surface's
no-product rule ([service_capability_doctrine.md](./service_capability_doctrine.md)) — and it has **no**
`Off`/`None`/`Silent` arm, mirroring `RetentionPolicy`'s absent keep-forever arm. `Objective.threshold` is a
refined non-zero `Quantity` ([resource_capacity_doctrine.md](./resource_capacity_doctrine.md)). The promotion
is **not** purely additive: `topicFor`/`validateTopology` re-base onto `Workflow`, and a decode-time fold
reconciles `routes[].workflow` against `Workflow.name` ([§3](#3-derivation-and-the-operator-read-model)).

### 2.2 Per-topic liveness — `RouteEntry.liveness`

Every routing entry additionally carries a mandatory per-derived-topic liveness obligation:

```
RouteEntry = { workflow : Text, phase : Phase, lanes : List Substrate, liveness : Liveness }
Liveness   = { freshness : Freshness, backlog : BacklogBound }   -- closed; no Silent arm
```

`Freshness` is a refined newtype (`0 < d < ceiling`, no `Infinity`), so a topic that is never expected to
produce — a silent lane — is not constructible. `BacklogBound` composes with the topic's existing mandatory
backlog quota ([pulsar_client_doctrine.md §6.1](./pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows)).

### 2.3 Per-extension surfaces — `ExtensionSpec.extMonitoring`

An extension declares the monitoring surfaces it stands up. The v1 extension set is closed at
`{infernix, jitML}` and linked, not loaded ([dsl_doctrine.md §4](./dsl_doctrine.md#4-total-composability)), so the surfaces it may
declare are a **closed** union with no open "other service" arm — the same closure the capability union
carries ([service_capability_doctrine.md](./service_capability_doctrine.md)):

```
ExtensionSpec = { extDhall, extChain, extCapabilities, extMonitoring : NonEmpty MonitoringSurface }

MonitoringSurface =
  < Slo         : WorkflowMonitor
  | TensorBoard : { backing : ObjectStoreRef, access : AccessScope } >
```

`extMonitoring` is `NonEmpty` and mandatory, so an extension's `extDhall` cannot be constructed without at
least one declared surface — jitML's is a `TensorBoard` surface backed by MinIO
([§5](#5-extensible-surfaces-tensorboard)), so an unmonitored jitML run has no inhabitant. infernix and
jitML (and every app, including the demo web apps) declare at least the generic `Slo` surface.

---

## 3. Derivation and the operator read-model

Monitoring artifacts are **derived**, never authored, so coverage cannot be forgotten. The derivation is a
total function of the same descriptor the topology fold already walks:

```
monitorFor       :: Workflow -> ([PrometheusRule], GrafanaPanel)   -- total
validateTopology :: [Workflow] -> [ExtensionSpec] -> Either [TopologyError] MonitoredTopology
```

`validateTopology` ([pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra)) is extended to fold every `monitor`,
`liveness`, and `extMonitoring` alongside its existing one-sided-link checks, and returns the **full**
violation list. Two new violations:

- `MonitoringInfeasible workflow reason` — a declared freshness below the achievable scrape interval, or a
  derived recording-rule cost that overflows the `Observability` workload's `Capacity` ([§7](#7-fit-within-resource-limits)).
- `UnroutedMonitor workflow` — a `routes[].workflow` with no owning `Workflow` record (the promotion's
  reconciliation hole).

The operator sees monitoring two ways, both on pre-existing surfaces:

- **Grafana (human browser).** The derived Prometheus recording/alert rules and a per-workflow health
  dashboard are provisioned into the existing Grafana, reachable only through the Keycloak-owned edge
  ([platform_services_doctrine.md §7](./platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)). This adds panels, not a new browser surface.
- **The `workflow-health` read-model (typed).** A compacted `workflow-health` Pulsar topic is projected
  through the existing compaction + TableView machinery ([pulsar_client_doctrine.md §5.1](./pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones),
  [daemon_topology_doctrine.md §5.1](./daemon_topology_doctrine.md#52-the-coordination-plane-is-for-worker-events-and-audit-not-leadership)) as `WorkflowName -> SLOStatus`, the first
  operator-facing TableView beside the internal leader-election one. The singleton produces the projection
  inside its existing reconcile loop — no new container — and the operator reads it via a `pb workflow health`
  verb on the singleton admin REST ([bootstrap_sequence_doctrine.md](./bootstrap_sequence_doctrine.md)).

```
SLOStatus = Fresh | Degraded BudgetRemaining | Breached BreachReason | NotYetObserved
```

`NotYetObserved` is the lag-tailed state past a replication watermark ([§6](#6-the-parent-monitoring-posture)); the read-model is
eventually-consistent, never live truth.

---

## 4. Access: one admin, delegated per-user scope, no public arm

Every renderable monitoring surface carries a mandatory access scope with no unauthenticated arm:

```
AccessScope = < AdminGlobal | UserScoped : { rule : AuthRule } >   -- no Public / Unauthenticated arm
```

**The problem.** A monitoring surface that publishes without authentication, or a per-user view that leaks
another user's data, is a data-exposure defect that a convention ("remember to gate it") does not prevent.

**Why the obvious alternative fails.** An optional `public : Bool` or an ungated default route is the same
optionality [§1](#1-monitoring-is-a-property-of-the-workflow-not-a-bolt-on) rejects, and it reproduces the
insecure-ingress state the catalog already forecloses ([illegal_state_catalog.md §3.7](../illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)).

**The chosen rule.** `AccessScope` has no `Public` arm, so an unauthenticated monitoring surface has no
inhabitant — reinforcing the existing rule that only the Keycloak edge holds `ExposeToWild`
([illegal_state_catalog.md §3.7](../illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)); every surface reaches the browser only through that edge
([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)). Two arms:

- **`AdminGlobal`** — the single admin identity. There is exactly one admin login, named in the `InForceSpec`
  and uploaded to Vault before any gateway deploys, and it reaches every console (Grafana, Prometheus, MinIO,
  Keycloak, Vault, Postgres). This is the admin-dashboard answer; the admin identity itself is owned by
  [vault_pki_doctrine.md](./vault_pki_doctrine.md) and the bootstrap admin plane
  ([bootstrap_sequence_doctrine.md](./bootstrap_sequence_doctrine.md)).
- **`UserScoped { rule }`** — a Keycloak-managed user sees only a subset (a TensorBoard showing one user's own
  experiments). amoebius models **that a scope is declared and non-public**; the per-user object filtering
  itself is a Keycloak-backed `AuthRule` — application logic, the same altitude as the recorded
  "a login requires MFA for the admin role" example ([app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md)) — evaluated by the
  Envoy ext-authz path against the token's `sub` claim ([service_capability_doctrine.md](./service_capability_doctrine.md)).

**What it forecloses.** The type does **not** introduce a per-user ownership grain: ownership stops at
app/namespace and tenant/cluster-subtree ([content_addressing_doctrine.md](./content_addressing_doctrine.md),
[illegal_state_catalog.md §4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)). A `UserScoped` surface that leaks another user's data is therefore a
Keycloak-auth-rule bug, runtime-checked ([§8](#8-the-three-foreclosure-layers)), not type-foreclosed. Extending the phantom-tenant-tag
machinery to a user index — so a cross-user leak is uninhabitable — is a later hardening, recorded here as an
open question, not built.

---

## 5. Extensible surfaces: TensorBoard

`MonitoringSurface` is a closed union whose arms cover the closed extension set's needs: the generic `Slo`
(Prometheus/Grafana), and `TensorBoard { backing : ObjectStoreRef, access : AccessScope }` for jitML.

**TensorBoard is a baked binary.** amoebius runs identically on an offline laptop and forbids pod-startup
fetches, so TensorBoard is baked into the base image beside Prometheus/Grafana
([image_build_doctrine.md §7](./image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain)), never pulled at start-up.

**The MinIO backing.** jitML's checkpoints are content-addressed in MinIO with a `metrics` manifest field
([content_addressing_doctrine.md](./content_addressing_doctrine.md)), but TensorBoard reads `tfevents` files.
So jitML emits `tfevents` to a per-experiment MinIO prefix (`jitml-checkpoints/<experiment-hash>/tb/`) that
the `TensorBoard` surface reads over MinIO's S3 API — MinIO is the S3-shaped `ObjectStore`
([service_capability_doctrine.md](./service_capability_doctrine.md)). Those objects are bounded by the store's
budget ([§7](#7-fit-within-resource-limits)); their retention/GC follows the deferral to the sibling jitML
checkpoint-format doctrine ([content_addressing_doctrine.md](./content_addressing_doctrine.md)).

**Per-user is an access filter, not a pod per user.** A per-user jitML TensorBoard is a `UserScoped` view over
the **one shared** TensorBoard instance ([§4](#4-access-one-admin-delegated-per-user-scope-no-public-arm)),
filtered by the `sub` claim — not a TensorBoard pod per user, which would multiply `Demand`
([§7](#7-fit-within-resource-limits)).

---

## 6. The parent-monitoring posture

Monitoring aggregation is split by cluster topology, and both cross-cluster transports that would violate the
fabric's invariants are rejected.

- **Peer / sibling clusters (HA of one workflow).** A monitor breach is an event on the workflow's own event
  topic, already carried sibling↔sibling by the existing async Pulsar geo-replication + write-once
  content-addressed MinIO channel ([cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md),
  [chaos_failover_doctrine.md](./chaos_failover_doctrine.md)), alongside the exported live-lag monitor and
  `DataLossBudget` the failover boundary already ships. A peer pulls from a log it already consumes — no new
  edge, nothing pushed outward.
- **The spawn forest (parent↔child): foreclosed by design.** A child cannot name or replicate to its parent —
  a `ChildInForceSpec` projection has no field in which a sibling or **ancestor**-only branch can appear
  ([cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)), and geo-replication is a parent-configured
  *sibling* mesh, not an upward channel. A parent reaching across the boundary to pull a child's telemetry is
  the synchronous cross-cluster RPC / multicluster service-mirroring ruled actively anti-doctrinal
  ([network_fabric_doctrine.md](./network_fabric_doctrine.md)). So in-cluster parent→child telemetry is
  foreclosed by the same isolation invariant that makes cross-tenant references unrepresentable
  ([illegal_state_catalog.md §3.10](../illegal_state/illegal_state_security.md#310-a-child-spec-that-reaches-beyond-its-own-subtree)). The accepted cross-forest viewer is the out-of-forest
  human operator, whose laptop reaches each cluster's own Grafana and `pb` admin plane through Keycloak — a
  privileged admin path, not a forest data edge.

**What it forecloses.** A spawned child can be unhealthy indefinitely with its in-cluster parent structurally
unable to observe it; only the out-of-forest operator sees it. This blind spot is a deliberate consequence of
per-child crypto isolation, not a defect to patch. A one-way, human-triggered, out-of-forest sealed
attestation channel is a possible later relaxation, recorded as open, not built.

---

## 7. Fit within resource limits

The generic monitoring path adds **zero** per-workflow pod `Demand`: it is pull/scrape of the `/healthz`
`/readyz` `/metrics` endpoints every daemon already exposes ([daemon_topology_doctrine.md](./daemon_topology_doctrine.md)),
with **no per-workflow sidecar** — honouring the no-sidecar-fleet stance and the Linkerd-rejected-for-being-a-sidecar
precedent ([network_fabric_doctrine.md](./network_fabric_doctrine.md)). Each remaining cost folds against the
existing capacity machinery ([resource_capacity_doctrine.md](./resource_capacity_doctrine.md)):

- Recording/alert-rule evaluation runs inside the already-budgeted `Observability` Prometheus workload and is
  folded **as a function of N workflows** (N × rules), not a flat add.
- The `workflow-health` topic and the jitML `tfevents` prefix are Pulsar/MinIO objects, bounded by the
  mandatory retention/offload/backlog triple ([pulsar_client_doctrine.md §6.1](./pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows)) and the closed
  `StorageBudget` with no unbounded arm.
- The optional local Thanos downsample/long-term store is one companion beside the single Prometheus — a
  strictly **local** role for the baked-but-otherwise-roleless binary, never a cross-cluster Query/Store/Receive
  — whose one pod declares refined non-zero cpu/mem and folds via `place`.
- The **one shared** TensorBoard pod declares cpu/mem `requests`/`limits` and folds via `place`/`podFits` like
  any pod. Per-user scoping is an access filter over that shared instance
  ([§5](#5-extensible-surfaces-tensorboard)), not a pod per user, so it does not multiply `Demand`.
- **No parent-rollup budget exists** — the forest rollup flow is foreclosed
  ([§6](#6-the-parent-monitoring-posture)), so there is no parent-side storage to budget.

One residue is named honestly: recording-rule series-count and evaluation CPU grow with descriptor size while
the Prometheus workload carries fixed `requests`, so a large descriptor can outrun provisioned Prometheus at
runtime. `StorageBudget` bounds bytes, not query performance. An optional decode-foreclosed rule-cardinality
budget (`Σ derived rules ≤ declared rule-capacity`) closes this and is recorded as an optional improvement.

---

## 8. The three foreclosure layers

Per the honesty discipline ([illegal_state_catalog.md §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force),
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)), each guarantee names the layer it reaches. The
monitoring obligation is the same three-way split `RetentionPolicy` publishes ([illegal_state_catalog.md §3.20](../illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)),
not a flat "type-foreclosed":

- **type-foreclosed** — field *presence* (`monitor`, `liveness`, `extMonitoring`), the `NonEmpty` lists, and
  the absent arms (`AlertBinding` no-off, `AccessScope` no-public): a `Workflow`/`RouteEntry`/`ExtensionSpec`
  omitting its obligation, a "monitoring off" value, or a public surface has no syntax and no inhabitant.
- **decode-foreclosed** — non-vacuousness of the bounds (refinement smart constructors on `Freshness`,
  `ErrorBudget`), coverage across derived topics (a relation-over-a-collection fold that, per
  [illegal_state_catalog.md §4.7](../illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection), degrades to a decode-foreclosed fold and is **never**
  type-foreclosed), feasibility (`MonitoringInfeasible`), and the `routes[].workflow`-vs-`name` reconciliation
  (`UnroutedMonitor`).
- **runtime-checked** — that the SLO is actually met, the alert actually fires, the named `/metrics` series
  actually exists, and a `UserScoped` surface actually filters correctly. These are the "a type cannot prove a
  port is responsive" residues ([illegal_state_catalog.md §2](../illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)), owned by
  [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) and the review tier, never claimed stronger.

> **Honesty.** amoebius has not built Phase 4. Every type-foreclosed and decode-foreclosed claim here is the
> intended property of the type discipline, not a tested result; the runtime-checked residues are explicitly
> deferred. Where a mechanism reuses a behaviour proven in a sibling system (Pulsar Failover subscriptions,
> Keycloak ext-authz), that is evidence, not proof in amoebius.

---

## 9. Planning ownership

Phase order, status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). The monitoring obligation types land in **Phase 4** and the
`validateTopology` fold in **Phase 7**; the derived rules/panels, the baked TensorBoard renderer, the
optional local Thanos companion, and the `workflow-health` TableView projection in **Phases 9, 15, and 18**;
the orchestrator/worker SLO-status event in **Phases 22–23**; the extension surfaces in **Phase 26**
(infernix) and **Phase 27** (jitML → TensorBoard); the peer-cluster posture and the forest foreclosure in
**Phase 29**; and the decode-rejection tests in **Phase 31**. This doc never maintains a competing status
ledger; it states the target shape and links back for status, per
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

## Cross-references
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md)
- [The Native Pulsar Client](./pulsar_client_doctrine.md)
- [DSL Doctrine](./dsl_doctrine.md)
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md)
- [Service Capability Doctrine](./service_capability_doctrine.md)
- [Platform Services Doctrine](./platform_services_doctrine.md)
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md)
- [Content Addressing Doctrine](./content_addressing_doctrine.md)
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md)
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md)
- [Image Build Doctrine](./image_build_doctrine.md)
