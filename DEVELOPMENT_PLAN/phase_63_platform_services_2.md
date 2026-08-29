# Phase 63: Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG)

> **Purpose**: Stand up Redis/Sentinel, Percona/Patroni with pgAdmin, and Prometheus/Grafana, then bring the
> whole standard stack up in the derived readiness-DAG order asserted from an external-observer trace.
> **Read this if**: phase 63 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 63.1: Percona/Patroni Postgres per consumer + pgAdmin + Prometheus/Grafana ⏸️](#sprint-631-perconapatroni-postgres-per-consumer--pgadmin--prometheusgrafana-)
- [Sprint 63.2: Ephemeral Redis/Sentinel realtime coordination ⏸️](#sprint-632-ephemeral-redissentinel-realtime-coordination-)
- [Sprint 63.3: The full derived readiness-DAG bring-up + the standard-stack gate ⏸️](#sprint-633-the-full-derived-readiness-dag-bring-up--the-standard-stack-gate-)
- [Sprint 63.4: Register-2.5 readiness-DAG bring-up under simulated partial failure ⏸️](#sprint-634-register-25-readiness-dag-bring-up-under-simulated-partial-failure-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 62, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target must complete the standard platform-service set on top of the future reviewer-approved
Phase-62 backbone. It must render and reconcile the cluster-wide **Percona operator**, one **Patroni Postgres cluster per consuming capability**
(each paired with its own **pgAdmin**), and the **Prometheus/Grafana** observability pair — each as the
byte-identical **HA topology even at `replicas=1`** (Postgres is a Patroni-via-Percona cluster, never a bare
`postgres` Pod), each rendered as typed Kubernetes objects by the Phase-58 `renderAll` path (no Helm and no
third-party charts); manifests are generated lazily from Haskell beneath `.build/**`, remain untracked, and are
absent from the repository. Each service is served from binaries **baked into the native-architecture base
image** with no public-registry pull and each is placed on the Phase-60 `no-provisioner`
retained PVs where it holds durable state. Every app, init, and sidecar container and every volume must be rendered
only from an opaque `ProvisionedServiceSpec`, with exact CPU/memory/ephemeral-storage requests and limits,
bounded pod-local storage, exact durable capacities, and explicit cache `None` plus accelerator `None` for this
linux-cpu stack. Prometheus's capacity is specifically descriptor-derived: a mandatory finite
`MonitoringWorkBudget` carries workflow/rule/series/sample-rate ceilings, evaluation interval, retention,
structural `QueryWorkBudget` concurrency/series/samples/range/timeout operands, one
claim/backing/`VolumePresentation`, and versioned evaluation/TSDB/query models. Its private provision witness
fixes both the compute envelope and the TSDB PVC/PV plus runtime retention configuration.
It also renders the platform-internal **Redis/Sentinel** topology used by replicated UI-server WebSockets:
one writable primary, at least two replicas, and three Sentinel voters in the distributed projection, with
TLS/Vault ACL credentials, bounded key/client/buffer/fanout/reconnect demand, and no PVC/AOF/RDB/backup. Redis
is not application capability or durable receipt state.
Each database consumer independently constructs a `PatroniSqlDemand`: exact operator-derived
child/controller/webhook envelopes, finite data/WAL/checkpoint/failover-replay operands, declared volume
presentation/backing and `StorageBudgetId`, bounded SQL connection/transaction/WAL mutation admission, and
rollout/failover overlap. The private `ProvisionedPatroniSql` includes the resulting SQL gateway envelope and
is required before its
CR can render; adding another consumer cannot reuse Grafana's database witness.

The Patroni configuration is **mandated**, not left to a per-service option: `synchronous_mode: on`, the
*decided* strict stance `synchronous_mode_strict: on` (when no synchronous standby is available the primary
**refuses new writes** rather than silently degrading to asynchronous replication — the non-strict
degrade-to-async alternative is rejected), and a bytes-bounded `maximum_lag_on_failover` (a replica lagging
past the bound is ineligible for promotion). This is the premise the RPO=0 / lossless-delegation obligation of
[`chaos_failover_doctrine.md §6`](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives)
rests on — that doctrine delegates intra-cluster synchronous-HA correctness to Patroni rather than re-proving
it, and the delegation holds **only** with these settings.

The phase then assembles the *whole* standard stack — the Phase-62 backbone plus these services — as one
**derived readiness DAG** and brings it up in the [`platform_services_doctrine.md §11`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
order by the Phase-58 reconciler's **event-driven wait-for-ready**: a dependent starts on its dependency's
observed-ready edge, never a timer. The bring-up order is asserted a pure function of the *declared* dependency
edges from an external-observer bring-up trace — not a self-report — and a hardcoded sequential list is
foreclosed by an applied Haskell changed-subject mutant whose external bytes, if any, are generated beneath `.build/**`.

The scope stops at *standing these services up HA, bringing the whole stack up in derived-DAG order, and
proving the mandated Patroni configuration and DAG derivation*. The **Keycloak-owned ingress edge** — the
browser surface Grafana and pgAdmin reach a user through — is [Phase 64](phase_64_keycloak_ingress.md); this
phase brings the observability surfaces up behind no public edge, and they reach a user only once that edge
exists. The Deployment-`replicas=1` control-plane daemon does not assume ownership until
[Phase 65](phase_65_live_dsl_deploy.md). Until then, a host-side operator drives this phase's fixed service
set.

**Phase scope:** one cohesive claim — *the whole standard stack comes up in the order its readiness DAG derives*. The order is asserted from an external observer's trace, never from the stack's own report.

**Substrate:** linux-cpu ([§L](development_plan_standards.md#l-one-substrate-discipline)) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host. This
is the universal baseline available on every hardware substrate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed));
the future contract requires real cluster bring-up and independent runtime observations. A candidate ledger
may classify only that bounded observation as *tested*, not proved, and cannot promote the phase.

**Depends on:** [Phase 62](phase_62_platform_backbone.md)
**Gate:** `pb validate phase 63`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *the whole standard stack comes up in the order its readiness DAG derives*. The order is asserted from an external observer's trace, never from the stack's own report. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 63` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 62; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_transactions.md` §4 — P1–P6](../documents/engineering/extension_conformance_transactions.md#4-p1p6) — platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) reaches a relational store, and P1-P6 close that surface to the transactions the domain has.
- [`ui_realtime_coordination_doctrine.md §5 — Redis is ephemeral platform-internal coordination`](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination):
  Phase 63's target must stand up the bounded TLS/ACL Redis/Sentinel topology with no persistence or application authority.

- [`platform_services_doctrine.md §8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin)
  with [`§2 — HA always, including replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1):
  Phase 63's target must stand up the cluster-wide Percona operator reconciling one Patroni Postgres cluster per consuming
  capability, each paired with pgAdmin, each the byte-identical HA topology with only the replica count
  changed, and each carrying the **mandated synchronous configuration** [`platform_services_doctrine.md` §8 — Postgres — Patroni-via-Percona, one cluster per consumer, with pgAdmin](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin) fixes — `synchronous_mode: on`,
  `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`.
- [`chaos_failover_doctrine.md §6 — the concentration principle: where the obligation lives`](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives):
  the RPO=0 / lossless-delegation premise holds **only** with the mandated Patroni settings; this phase's target must make
  the `PlannedIsLossless` premise a rendered, oracle-checked invariant rather than an assumed default, so an
  intra-cluster failover cannot promote a replica missing acknowledged commits.
- [`platform_services_doctrine.md §7 — Prometheus / Grafana, observability is not an add-on`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)
  with [`monitoring_doctrine.md §3 — derivation and the operator read-model`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model):
  Prometheus scrapes platform workloads and the derived recording/alert rules and dashboards are
  generated, never hand-authored — for every bound execution unit's mandatory `UnitMonitor` as well as every
  workflow SLO, so the monitored population is the execution set and a platform service is no more exempt from
  its monitor than from its `ResourceEnvelope`
  ([`monitoring_doctrine.md` §2.4 — Per-execution-unit obligation — `BoundExecutionUnit.monitor`](../documents/engineering/monitoring_doctrine.md#24-per-execution-unit-obligation--boundexecutionunitmonitor)).
  The **alert receiver** that groups, deduplicates, and silences the firing set stands up here beside
  Prometheus and Grafana as part of the same `Observability` capability, with its own complete envelope and a
  finite in-memory bound; it declares no outbound delivery target, and carrying a page beyond the cluster edge
  stays an operator-owned out-of-band integration. Its mandatory finite work budget derives both CPU/memory and the exact
  retained TSDB peak/configuration from the monitored-population/rule/series/sample-rate, interval, retention, structural
  query concurrency/series/samples/range/timeout, claim/backing, and versioned cost models. All queries enter
  through the generated admission proxy; the browser surfaces gated behind the (Phase 64) Keycloak edge
  under a mandatory `AccessScope` with no `Public` arm.
- [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  as the **derived readiness DAG** of [`readiness_ordering_doctrine.md` §4 — Ordering is a derived readiness DAG, not a hand-sequenced script](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
  and [`readiness_ordering_doctrine.md` §6 — The runtime enactor: the reconciler observes, never sleeps](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
  the whole standard stack's hard ordering edges are derived from the declared dependency graph and enacted as
  observed-ready conditions, never a duration-gated or prose-ordered installer.
- [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  and [`§2 — the typed manifest model (`renderAll` is the sole public pure function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
  Phase 63 reuses the Phase-58 pure `renderAll :: ProvisionedSpec -> [K8sObject]` and typed-action reconciler whose **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the set.
- [`image_build_doctrine.md` §2 — The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  every service binary (Redis, Percona operator, Patroni, pgAdmin, Prometheus, Grafana) is baked into the Phase-56
  native-architecture base image and resolved only in-cluster; nothing in this bring-up pulls from a public registry.
- [`platform_services_doctrine.md §10 — every execution unit declares its complete resource envelope`](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope)
  and [`resource_capacity_types.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`; “The systematic provision matrix”](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix):
  every app/init/sidecar container and volume is the exact rendered projection of the checked CPU, memory,
  ephemeral-storage, durable-storage, cache, and accelerator fields; `None`/empty provisions remain explicit
  rather than silently omitted from the pure model.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each Patroni cluster and Prometheus lands its durable bytes on the Phase-60 `no-provisioner` retained PVs.
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  as [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing): the
  readiness-DAG orchestration must run under `IOSimPOR` against an independently approved modeled substrate
  before the Register-3 live candidate.
- [`testing_doctrine.md §2 — the registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing):
  this phase's future gate is a Register-3 live bring-up on `linux-cpu`; a candidate ledger may mark only its
  bounded runtime observation *tested*, never proven, and must leave later edge/reconcile layers unverified.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and an authorized-reviewer tracker change.

## Sprint 63.1: Percona/Patroni Postgres per consumer + pgAdmin + Prometheus/Grafana ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 62](phase_62_platform_backbone.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`platform_services_doctrine.md §8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin),
[`§7 — Prometheus / Grafana`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)
with [`monitoring_doctrine.md §3`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model),
the lossless premise of [`chaos_failover_doctrine.md §6`](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives),
and [`resource_capacity_types.md §3.1 — the systematic provision matrix`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
as the projection every execution unit and volume is checked against:
stand up the Percona operator as a cluster-wide platform component reconciling per-consumer Patroni clusters —
each with pgAdmin and the mandated synchronous configuration — and Prometheus/Grafana with derived rules and
dashboards.

### Deliverables

- The Percona operator rendered as a cluster-wide platform component (from the shared inventory so it installs
  identically on every substrate), reconciling the per-consumer `PerconaPGCluster` for the named
  database-consumer set **`{Grafana}`** — HA Patroni even at `replicas=1` — each paired with its own pgAdmin;
  Distribution `registry:2` takes **no** database ([§3](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source)). The consumer set is pinned here (resolving the `platform_services_doctrine.md §8` "Phase 62 delivery detail"); a `PerconaPGCluster` consumed by nothing does
  not satisfy this deliverable.
- The **mandated Patroni configuration** on every rendered cluster: `synchronous_mode: on`,
  `synchronous_mode_strict: on` (the decided strict stance — no synchronous standby ⇒ the primary refuses new
  writes; the degrade-to-async alternative is rejected), and a bytes-bounded `maximum_lag_on_failover` (a
  replica lagging past the bound is promotion-ineligible). A separately authored Haskell Patroni configuration
  expectation must be independently reviewed, with the Haskell changed-production-subject mutant
  `M-patroni-async-default` named as the mutant this invariant MUST turn red (on the specific reason that
  `synchronous_mode_strict` is not `on`).
- Prometheus + Grafana scraping platform workloads, with the per-workflow recording/alert rules and
  dashboards **derived, never hand-authored**.
  - A mandatory finite `MonitoringWorkBudget` bounds workflow/rule/series cardinality, maximum scrape
    samples/second, evaluation work/interval, finite retention, a structural `QueryWorkBudget {
    maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout, costModel }`, and one
    StatefulSet claim/backing/presentation.
  - Version-pinned evaluation, TSDB, and query cost folds derive Prometheus CPU/memory requests+limits for
    evaluation overlapping maximum concurrent queries, the query-admission proxy's complete pod envelope,
    plus retained blocks, WAL/head, old+new compaction overlap, and query/temp headroom as required usable
    bytes; the private storage witness then adds filesystem overhead and backing allocation rounding and
    supplies exact PVC/PV capacity, volumeMode, and fsType.
  - Rendered Prometheus global and rule-group intervals, `--storage.tsdb.retention.time`,
    `--storage.tsdb.retention.size`, Prometheus query concurrency/sample/timeout flags, the sole-routable
    query-admission proxy series/range controls, and model-selected WAL/config settings equal those
    operands.
  - NetworkPolicy blocks direct query API access.
  - The live gate reads the effective configuration, argv, proxy controls, and claim back and refuses any
    shorter default/override or smaller volume.
  - A descriptor above a count/rate bound or a mounted usable capacity one byte below the derived peak, or
    raw backing one allocation quantum below `provisionedBytes`, rejects before any SSA or
    backing-allocation effect; fixed requests or an arbitrary tiny PVC have no fallback arm.
  - Optional local Thanos is a distinct bounded demand and cannot borrow the Prometheus claim.
  - The browser surfaces reach a user only through the (Phase 64) Keycloak edge under a mandatory
    `AccessScope` with no `Public` arm — deferred here, marked UNVERIFIED.
- Exact CR→child-envelope projection for every supported operator arm. In particular, each
  `PerconaPGCluster` CR's replicas, container resources, PVC sizes, and rollout fields equal the provisioned
  child pod/PVC/transition bound; after readiness, the operator-created StatefulSets/Pods/PVCs are enumerated
  and must conform to that bound. A CR field omitted to an operator default is not an acceptable projection.
- A `PatroniSqlDemand` per member of the exact consumer set. Its pinned storage model derives data+WAL+
  checkpoint+failover-replay/recovery required usable bytes and its private volume provision; its controller
  model derives every Percona/Patroni/backup child epoch plus the validating webhook's full pod envelope.
  `ProvisionedPatroniSql` retains those placements and per-backing peak. Database data fitting while one
  controller/webhook/SQL-gateway/member resource, pod/CSI slot, or raw/usable volume byte is short rejects before
  the CR.
- Exact complete provisions on every rendered app/init/sidecar container and volume:
  CPU/memory/ephemeral-storage requests+limits, bounded pod-local volumes, durable PVC/PV
  presentation/rounded sizes equal to their private checked demands, and cache `None` plus accelerator
  `None`/no device claim on linux-cpu; durable bytes live
  on retained PVs.
- Run-local resolution of the Postgres shared package through Phase 1's compatibility policy. The selected
  package identity and observed integrity are generated under `.build/toolchain/**`; no repository-retained
  checksum input is read by the Haskell/live gate.

### Validation

1. Assert the Percona operator is Ready before any `PerconaPGCluster`, then that the named consumer set
   `{Grafana}`'s cluster reconciles as an HA Patroni cluster (byte-identical modulo replica count to the
   multi-member topology, never a bare `postgres` Pod) paired with its own pgAdmin. The set is exactly
   `{Grafana}` because Keycloak's own store arrives with the [Phase 64](phase_64_keycloak_ingress.md) edge and
   Distribution `registry:2` takes no database at all
   ([§3](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source)).
   Then assert that the consumer uses its cluster end-to-end — Grafana authenticates with the credential from
   its Vault `SecretRef` and a SQL row written through Grafana's datastore is read back from its own Patroni
   cluster — rather than merely that an unattached `PerconaPGCluster` reconciles.
2. Assert each rendered Patroni config is structurally equal to the separately authored Haskell expectation
   (`synchronous_mode: on`, `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`), and that the
   Haskell changed-production-subject mutant `M-patroni-async-default` fails the synchronous-mode invariant with the specific reason that
   `synchronous_mode_strict` is not `on` — paired with a positive that differs only in that field.
3. Assert Prometheus scrapes platform targets and the derived rules/dashboards are present and generated lazily
   from Haskell beneath `.build/**`, never repository-authored static assets. Exceed `maxRules`, `maxSeries`, or
   `maxScrapeSamplesPerSecond` by one and require a
   pre-effect budget rejection; exceed each query concurrency/series/samples/range/timeout operand and require
   proxy rejection without direct-Prometheus reachability; independently under-size Prometheus or proxy
   CPU/memory for the evaluation + maximum-concurrent-query overlap and require pre-effect rejection; repeat
   with mounted usable capacity exactly one
   byte below the independently
   rederived retained-block + WAL/head + compaction-overlap + query/temp peak and with raw allocation one
   quantum below the presentation-derived `provisionedBytes`; assert the apiserver audit and
   backing observer record zero SSA/PV/allocation writes. A Haskell changed-production-subject
   fixed-Prometheus-requests/tiny-PVC mutant
   must turn this red. On the positive, read back effective global/rule-group intervals, process argv,
   TSDB/WAL configuration, PVC and PV: interval, `--storage.tsdb.retention.time`,
   `--storage.tsdb.retention.size`, Prometheus query flags, query-proxy limits, direct-query NetworkPolicy,
   model-selected WAL settings, claim slot/backing/presentation, rounded raw capacity, and mounted usable
   capacity must equal the provision witness exactly. Drive ingestion through a
   block compaction boundary and a bounded worst-case
   query at every structural bound, observe resident blocks + WAL/head + simultaneous old/new compaction files
   + query/temp high-water
   from the mounted filesystem, and require the peak to remain within the claim; restart at that boundary and
   require recovery to remain within the same bound. Assert every platform app/init/sidecar container and
   volume is an exact projection of its `ProvisionedServiceSpec` across CPU, memory, ephemeral and image
   storage, durable storage, cache `None`, and accelerator `None`, and each Patroni cluster's credentials
   resolve from Vault.
4. Compare every rendered `PerconaPGCluster` resource/replica/PVC/rollout field with its pure child envelope,
   then independently enumerate the operator-created child StatefulSets/Pods/PVCs after readiness and assert
   their aggregate request/limit/storage/rollout peak stays within it. A Haskell changed-production-subject
   mutant dropping the CR resource projection (thereby using operator defaults) must turn both the manifest and
   live-child Haskell expectation red.
   Independently recompute the `PatroniSqlDemand` data/WAL/checkpoint/failover/recovery peak and make only the
   controller, webhook, SQL admission proxy, one Patroni member CPU/memory/ephemeral/pod/CSI slot, mounted usable byte, or rounded
   backing byte one unit short. Each case rejects before CR/volume creation; the Haskell changed-production-subject
   mutants omitting the webhook or
   treating the finite data size as the complete physical peak go red.
5. Reject a seeded repository-retained package-checksum input, resolve the Postgres shared package dynamically,
   and verify its selected identity and integrity only through the run-local toolchain record and external
   attestation bound to that untracked run.

### Remaining Work

The historical repository-retained Postgres package checksum is condemned residue and cannot be recreated.
Route package acquisition through Phase 1's dynamic resolver and retain its integrity observation only in
untracked run evidence. Independently review the separately authored Haskell Patroni and monitoring
expectations. The Keycloak browser edge remains Phase 64 and control-plane-owned continuous
reconciliation remains Phase 65, both explicitly UNVERIFIED.

## Sprint 63.2: Ephemeral Redis/Sentinel realtime coordination ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 63.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`ui_realtime_coordination_doctrine.md §5 — Redis is ephemeral platform-internal coordination`](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination):
stand up the platform's bounded Redis/Sentinel topology from the baked image without introducing application
storage, durability, or a new DSL capability.

### Deliverables

- Typed Redis primary/replica and Sentinel manifests, TLS/ACL `SecretRef`s, default-deny NetworkPolicy,
  readiness, topology spread, disruption controls, and exact resource projections.
- Closed key-class policy with per-class TTL/cleanup, serialized-size/cardinality/rate bounds, Redis
  `maxmemory`, client/output-buffer limits, and a bounded failover/reconnect envelope.
- No PVC, AOF, RDB snapshot, backup, public Redis image, or application-visible endpoint.
- Separately authored Haskell failover/configuration/volume/receipt expectations and the four Haskell
  changed-production-subject mutants `M-redis-pvc`, `M-redis-unbounded-buffer`, `M-redis-public-image`, and
  `M-redis-receipt-authority`; any serialized runtime forms are generated lazily under `.build/**` and untracked.

### Validation

1. Connect with the least-authority Vault-issued TLS/ACL identity, write one TTL-bound challenge key, observe
   it on a replica, force primary loss, and require Sentinel promotion plus bounded reconnect.
2. Read live args/config, volume inventory, NetworkPolicy, image digest, memory/client buffers, key TTL, and
   topology; assert no PVC, AOF, RDB, or backup is present and that every key, client, output-buffer, memory,
   and rate bound exact-matches the independent Haskell expectation and the provision witness. Public
   Haskell image/persistence/unbounded changed-production-subject mutants fail before readiness.
3. Run an application command while Redis is flushed and prove its durable receipt/outcome remains solely in
   the effect-owning provider/Pulsar projection; the receipt-authority mutant must duplicate or lose the
   separately expected Haskell outcome and turn red.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Application-side WebSocket routing remains owned by its later UI-runtime phases; this sprint owns and
has sealed the platform Redis/Sentinel boundary.

## Sprint 63.3: The full derived readiness-DAG bring-up + the standard-stack gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 63.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
as the derived readiness DAG of [`readiness_ordering_doctrine.md §4`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
enacted by [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
fold the whole standard stack into one derived DAG, bring it up event-driven in that order, and close the
phase with the full-stack HA gate whose ordering claim is read from an external-observer trace.

### Deliverables

- A `BringUp` assembly that folds the whole standard-service set (Phase-62 backbone + Sprint-58.1 and Sprint-58.2 services)
  into an acyclic derived readiness DAG from the declared dependency graph (LoadBalancer → edge, Percona
  operator → Postgres consumers, Vault initialized-and-unsealed → secret-dependent startup), never a
  hand-sequenced script; the Vault-unsealed edge is the fail-closed condition of
  [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init).
- Live enactment by the Phase-58 reconciler's wait-for-ready — each dependent constructed to start on its
  dependency's observed-ready edge (a `runtime-checked` observation from the live object), never a duration;
  the control-plane daemon that will later own this loop is [Phase 65](phase_65_live_dsl_deploy.md) (Deployment `replicas=1`, no election).
- The phase-gate harness brings the standard stack onto Phase 62's live backbone and observes every required
  service in its HA-capable shape. It also verifies generated-manifest and baked-binary provenance, exact
  execution-unit/volume projection from `ProvisionedServiceSpec`, and a Register-3 ledger that labels only the
  observed runtime layer *tested*.
- The Haskell gate-oracle candidates, subject to recorded independent review under §M.1: a Register-1 property
  `prop_bringUpOrderDerivedFromEdges` asserting the derived bring-up order is a pure function of the
  *declared* dependency edges (adding or removing a declared edge changes the order; an introduced cycle is
  rejected) under a §M.4 cover/classify floor forcing a stated minimum fraction of cases through the
  declared-edge mutation and injected-cycle branches so neither passes vacuously, checked against a separately
  authored Haskell edge→order reference table independent of the `BringUp` fold (§M.3); and the Haskell
  changed-production-subject mutants **`M-dag-drop-edge`** (deletes the
  `perconaOperator → PerconaPGCluster` declared edge) and **`M-dag-inject-cycle`** (adds a back-edge making the
  declared graph cyclic), which the gate MUST turn red under the fixed §M.2 mutation quota and re-run on every
  candidate. Any external representation of cases or results is generated lazily under `.build/**` and untracked.

### Validation

1. Assert the bring-up honours the [§11](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering) DAG order — Percona operator
   before its Patroni consumers, Vault-unsealed before secret-dependent startup — with each edge an observed
   condition and no timer standing in for a condition, and the **live order read from an external-observer bring-up trace** (apiserver watch / pod-readiness event stream at the OS boundary), never a compliance trace
   amoebius emits about itself. Beyond the observed order, assert **derivation**: the Register-1 property
   `prop_bringUpOrderDerivedFromEdges` (checked against the separately authored Haskell edge→order reference
   table, independent of the `BringUp` fold) holds — the order is a pure function of the declared
   edges, adding/removing a declared edge changes it, an introduced cycle is rejected — under a §M.4
   cover/classify floor keeping the edge-mutation and injected-cycle branches above a stated minimum fraction
   of cases, and the Haskell changed-production-subject mutants `M-dag-drop-edge` and `M-dag-inject-cycle` turn
   this property (and the live
   precondition assertion) red. A
   hardcoded sequential list with wait-for-ready between steps does not satisfy this and MUST fail the property.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled stack; assert Postgres is a
   Patroni cluster, never a bare Pod, carrying the mandated synchronous config (the Sprint 63.1 Haskell expectation).
3. Assert the complete standard stack is ready and preserves Phase 62's already-gated backbone topology and
   provenance. For the Phase-63 additions, a one-versus-many replica render diff may change only count fields;
   Patroni must remain the multi-member projection rather than switch to a standalone variant. Recompute
   `renderAll` and exact-match its bytes to the normalized SSA objects. Separately, observe the kind node's CRI
   pull log and require every live `imageID` to equal the digest in the verified Phase-56 attestation and the
   current in-cluster catalog; public or side-loaded alternatives
   fail. Finally, exact-match every applied resource field to `ProvisionedServiceSpec`, including app/init/sidecar
   envelopes, bounded `emptyDir`, PVC/PV capacity, the two init-container lifecycle modes, overhead, and the
   cache-`None`/accelerator-`None` arms. Emit the Register-3
   ledger, runtime layer *tested* not *proven* (Keycloak edge + control-plane-owned reconcile marked UNVERIFIED).

### Remaining Work

The historical copied expected-base-digest input is condemned residue and cannot be recreated. Consume the
verified Phase-56 identity directly as authenticated run input and rerun the warm reconciliation under
universal artifact hygiene. The deterministic scheduler gate owns the cold/partial-
failure ordering claim.

## Sprint 63.4: Register-2.5 readiness-DAG bring-up under simulated partial failure ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 63.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md)
as [Register 2.5](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) over this
phase's own bring-up. The subject is the *real* Sprint-58.3 readiness-DAG orchestration: the derived graph
that deploys concurrently where services are independent and sequentially where they depend, carrying the
HA-always readiness ordering this phase owns. That orchestration runs unchanged under `IOSimPOR` against the
Phase-34.4 modeled substrates, so the ordering and fail-closed invariants are validated deterministically
in-process before the Register-3 live gate ever runs.

### Deliverables

- An `IOSimPOR` harness that drives the *unmodified* Sprint-58.3 `BringUp` orchestration (written against `io-classes`, no real IO) against the Phase-34.4 fake Pulsar/MinIO/apiserver/route53/Vault/clock (`src/Amoebius/Sim/Env.hs` + `src/Amoebius/Sim/Fakes/*`), with injected **partial failure, restart, and network partition** on the modeled dependencies.
- Schedule-exhaustive assertions over the partial-order search, four in all.
  (a) **No service starts before its readiness precondition**, on any explored schedule.
  (b) The concurrent bring-up is **deadlock-free** and **fail-closed**: a missing or unhealthy dependency
  halts the dependent and is never silently proceeded past.
  (c) The orchestration **does not report success until every service is Ready**.
  (d) A **concurrency witness**: on at least one explored schedule the bring-up intervals of two
  declared-dependency-independent services overlap — an assertion a hardcoded sequential program cannot
  satisfy. The Haskell changed-production-subject `M-dag-drop-edge` mutant MUST turn assertion (a) red here.
- A deterministically replayable seed on any failing schedule and a Register-2.5 ledger recording substrate `none`, the register, and the honest limit that modeled-substrate fidelity is *assumed*.

### Validation

1. Run the bring-up under `IOSimPOR`; assert across explored schedules that every [§11](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering) hard edge (LoadBalancer → edge, Percona operator → Postgres consumer, Vault-unsealed → secret-dependent startup) holds — no dependent observed to start before its precondition on any schedule.
2. Inject partial failure / restart / partition on a modeled dependency; assert the applicative-concurrent bring-up stays deadlock-free and fails closed on the missing/unhealthy dependency, never reporting success with a service not-Ready. Assert the concurrency witness: on at least one explored schedule the bring-up intervals of MinIO and the Percona operator (declared-dependency-independent) overlap — proving genuine applicative concurrency, not a hand-sequenced total order — and assert the Haskell changed-production-subject `M-dag-drop-edge` mutant turns the precondition assertion red.
3. Replay a captured seed and assert a bit-identical schedule and outcome; emit the Register-2.5 ledger — substrate `none`, Register 2.5 — recording the honest limit that modeled-substrate fidelity is *assumed* and is discharged only by this phase's Register-3 live gate (Sprint 63.3).

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The harness seals 256 deterministic healthy/partial-failure/restart/partition schedules and one
`IOSimPOR` exploration with byte-identical replay and an independent-chain overlap witness.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `platform_services_doctrine.md`, `chaos_failover_doctrine.md`, `readiness_ordering_doctrine.md`,
  `monitoring_doctrine.md`, `resource_capacity_doctrine.md`, `ui_realtime_coordination_doctrine.md`, and
  `deterministic_simulation_doctrine.md` now record the tested Phase-63 boundary and its honest limits.
- Each update states the universal substrate rule explicitly: every hardware substrate can always run
  `linux-cpu`; pristine Linux uses Incus for Linux/Linux-CUDA, Lima for Apple, and WSL2 for Windows.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `substrates.md`, and `system_components.md` point at the concrete
  implementations and sealed gate.

## Related Documents

- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the [§7](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)/[§8](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin) services + [§11](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering) bring-up ordering adopted here
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the [§6](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives) lossless-delegation premise the mandated Patroni config underwrites
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — the derived readiness DAG the reconciler enacts
- [Monitoring Doctrine](../documents/engineering/monitoring_doctrine.md) — the derived observability surfaces
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the Phase-58 renderer + SSA wait-for-ready that applies and sequences the set
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base image, pull-only-in-cluster
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — the ephemeral
  Redis/Sentinel topology and failure boundary delivered by Sprint 63.2
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained PVs the stateful services land on
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 `IOSim`/`IOSimPOR` simulation of the real bring-up over the Phase-34.4 modeled substrates
- [phase_61](phase_61_vault_pki.md) — the root Vault/PKI whose unseal edge gates secret-dependent startup here
- [phase_62](phase_62_platform_backbone.md) — the MetalLB/MinIO/Pulsar backbone this phase's services and DAG build on
- [phase_64](phase_64_keycloak_ingress.md) — the Keycloak-owned ingress edge that fronts Grafana and pgAdmin next
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
