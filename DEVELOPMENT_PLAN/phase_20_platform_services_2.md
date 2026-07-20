# Phase 20: Platform services-2 (Percona/Patroni + pgAdmin + observability + readiness-DAG)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the remaining standard platform services — the Percona operator with one Patroni
> Postgres per consuming capability, pgAdmin, and Prometheus/Grafana — and bring the whole standard stack up in
> the derived readiness-DAG order, asserted from an external-observer bring-up trace.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 19 backbone gate
passes and runs on the **linux-cpu** substrate across **Register 3** (live infrastructure) — the same
single-node `kind` cluster on a linux-cpu host, on top of the Phase-15 registry + baked base image, the
Phase-16 typed renderer + SSA reconciler, the Phase-17 no-provisioner retained storage, the Phase-18 unsealed
root Vault, and the Phase-19 MetalLB/MinIO/Pulsar backbone. The Percona/Patroni, pgAdmin, and
Prometheus/Grafana topologies are inherited as **sibling evidence from prodbox**, not amoebius results; the
derived-DAG bring-up order is amoebius's own composition and is the least evidence-backed claim in the phase.
Status transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase completes the standard platform-service set on top of the Phase-19 backbone. It renders and
reconciles the cluster-wide **Percona operator**, one **Patroni Postgres cluster per consuming capability**
(each paired with its own **pgAdmin**), and the **Prometheus/Grafana** observability pair — each as the
byte-identical **HA topology even at `replicas=1`** (Postgres is a Patroni-via-Percona cluster, never a bare
`postgres` Pod), each rendered as typed Kubernetes objects by the Phase-16 `renderAll` path (no Helm, no
third-party charts, manifests generated from Haskell and never committed), each served from binaries **baked
into the multi-arch base image** with no public-registry pull, and each on the Phase-17 `no-provisioner`
retained PVs where it holds durable state. Every app, init, and sidecar container and every volume is rendered
only from an opaque `ProvisionedServiceSpec`, with exact CPU/memory/ephemeral-storage requests and limits,
bounded pod-local storage, exact durable capacities, and explicit cache `None` plus accelerator `None` for this
linux-cpu stack. Prometheus's capacity is specifically descriptor-derived: a mandatory finite
`MonitoringWorkBudget` carries workflow/rule/series/sample-rate ceilings, evaluation interval, retention,
structural `QueryWorkBudget` concurrency/series/samples/range/timeout operands, one
claim/backing/`VolumePresentation`, and versioned evaluation/TSDB/query models. Its private provision witness
fixes both the compute envelope and the TSDB PVC/PV plus runtime retention configuration.
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

The phase then assembles the *whole* standard stack — the Phase-19 backbone plus these services — as one
**derived readiness DAG** and brings it up in the [`platform_services_doctrine.md §11`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
order by the Phase-16 reconciler's **event-driven wait-for-ready**: a dependent starts on its dependency's
observed-ready edge, never a timer. The bring-up order is asserted a pure function of the *declared* dependency
edges from an external-observer bring-up trace — not a self-report — and a hardcoded sequential list is
foreclosed by a committed mutant.

The scope stops at *standing these services up HA, bringing the whole stack up in derived-DAG order, and
proving the mandated Patroni configuration and DAG derivation*. The **Keycloak-owned ingress edge** — the
browser surface Grafana and pgAdmin reach a user through — is [Phase 21](phase_21_keycloak_ingress.md); this
phase brings the observability surfaces up behind no public edge, and they reach a user only once that edge
exists. The Deployment-`replicas=1` control-plane singleton that will eventually *own* this reconcile loop is
[Phase 22](phase_22_live_dsl_singleton.md); here the reconciler is driven from the operator/host path against a
fixed, hand-assembled service set.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 20.

**Register:** 3 — live infrastructure (§K); a real bring-up on a real cluster, emitting a proven/tested/assumed
ledger that names Register 3 and marks the runtime layer *tested*, never *proven*.

**Gate:** on the Phase-19 backbone cluster the remaining standard services — the Percona operator, the
per-consumer Patroni Postgres clusters with pgAdmin, and Prometheus/Grafana — **come up HA** (each its HA
topology even at `replicas=1`; Postgres a Patroni-via-Percona cluster, never a bare Pod) **from generated
manifests + baked binaries** (no public-registry pull), each Patroni cluster carrying the **mandated
synchronous configuration** (`synchronous_mode: on`, `synchronous_mode_strict: on`, bounded
`maximum_lag_on_failover`) asserted against a committed oracle, and every execution unit/volume carrying the
exact complete provision derived by its `ProvisionedServiceSpec` — including Prometheus's exact
budget-derived compute, evaluation/retention/WAL configuration, and TSDB claim/backing/capacity, with the
one-byte-under and compaction/recovery high-water witnesses passing; **and the whole standard stack comes up in the
§11 derived readiness-DAG order** — the LoadBalancer before the edge, the Percona operator before any Postgres
consumer, Vault initialized-and-unsealed before secret-dependent startup — each edge a condition observed by
the reconciler's wait-for-ready, the bring-up order asserted a pure function of the declared edges from an
**external-observer bring-up trace** (not a self-report), with a hardcoded sequential list foreclosed by a
committed mutant and the async-default Patroni configuration foreclosed by a committed mutant.

**Gate integrity (§M).** The gate is closed to a stub by the pinned cross-checks below, all authored and
committed in **Phase 0** before any `src/Amoebius/Platform/*` implementation exists (§M.1 oracle-pinning), and
named as gate oracles in the Sprint 20.1–20.3 Deliverables:

- **Derived-DAG order (§M.2 committed mutant, §M.3 independent oracle, §M.5 external-observer trace).** The
  bring-up order is asserted a pure function of the *declared* dependency edges by a Register-1 property
  (Sprint 20.2), checked against a committed hand-authored edge→order reference table
  `test/fixtures/phase20/dag-edges.golden` independent of the `BringUp` fold; and the *live* order is read from
  an external-observer bring-up trace (the apiserver watch / pod-readiness event stream at the OS boundary, not
  a compliance trace amoebius emits about itself). The gate names a committed seeded mutant —
  **`mutant/dag-drop-edge`**, deleting the `perconaOperator → PerconaPGCluster` edge — that MUST turn the order
  property and the live precondition assertion red. A hardcoded sequential list cannot satisfy the "edge
  change ⇒ order change / injected cycle rejected" property.
- **Mandated Patroni config (§M.3 independent oracle, §M.2 committed mutant, §M.8 specific-reason negative).**
  Each rendered `PerconaPGCluster`'s Patroni configuration is asserted byte-equal to the committed
  hand-authored oracle `test/fixtures/phase20/patroni-sync-config.golden` (`synchronous_mode: on`,
  `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`), authored independently of the renderer.
  The committed seeded mutant **`mutant/patroni-async-default`** — a Patroni config left at the async default
  (`synchronous_mode` off, or non-strict so it silently degrades to async) — MUST fail the synchronous-mode
  invariant with the **specific reason** that `synchronous_mode_strict` is not `on` (paired with the positive
  that differs only in that field), so the negative cannot pass by failing for an unrelated reason.
- **Image-identity provenance (§M.5 OS-boundary observer).** Every running container's `imageID` digest
  (`kubectl get pods -A -o jsonpath={..imageID}`) MUST equal the Phase-15 baked base-image digest committed in
  `test/fixtures/phase20/expected-base-digest.txt` and present in the in-cluster `distribution` registry
  catalog; any digest not in that catalog, or any `docker.io`/`quay.io`/other public-registry reference (including
  an upstream image pre-side-loaded with `kind load`), fails. The pull-observation window is the
  containerd/CRI image-pull event log on the kind node read from the OS boundary over the whole gate window.
- **Render byte-identity (§M.3 independent provenance).** At gate time the pure `renderAll` is re-run in-process
  and the SSA-applied object bytes under the `amoebius` field manager MUST be byte-identical to that fresh
  `renderAll` output — pinning applied manifests to the Phase-16 renderer, so hand-written or `helm
  template`-derived YAML embedded as string constants fails.
- **Exact resource-provision identity (§M.3 independent projection).** For every amoebius-owned app, init, and
  sidecar container, the applied CPU/memory/ephemeral-storage requests and limits are byte-for-byte the
  projection of the opaque `ProvisionedServiceSpec`; every disk-backed `emptyDir` has a `sizeLimit` covered by
  that ephemeral-storage ceiling (a kubelet measurement/eviction boundary, not a synchronous quota); every
  cache owner also enforces its private admission bound, and every PVC/PV presentation and capacity equal the
  private `ProvisionedVolumeDemand`'s presentation and backing-rounded `provisionedBytes`, which witness the
  service-derived required usable demand and retained backing;
  every Percona controller, validating webhook, Patroni member, backup/recovery unit, and pgAdmin pod is
  included with its exact old/new/surge/failover envelope, and the database volume peak includes data, WAL,
  checkpoint, failover replay, and recovery overlap;
  and every service in this linux-cpu corpus carries cache `None` and accelerator `None` with no device
  extended-resource claim. The checker independently recomputes the effective pod reservation/ceiling from
  app-container sums, sequential and restartable-init-sidecar semantics, and pod/runtime overhead and matches
  the provisioned placement witness. Presence-only checks over a subset of resources are insufficient.
- **Prometheus retained-state identity and boundary (§M.3 independent projection, §M.5 OS-boundary
  observer).** A Phase-0-pinned monitoring oracle independently folds the bounded scrape-sample rate and
  retention into resident blocks, WAL/head, old+new compaction overlap, and derives query/temp headroom from
  the structural query operands. The applied
  StatefulSet claim/backing and PVC/PV capacity plus effective evaluation interval,
  `--storage.tsdb.retention.time`, `--storage.tsdb.retention.size`, Prometheus
  concurrency/sample/timeout flags, sole-routable query-admission proxy series/range limits, and model-selected
  WAL/config settings must equal the private witness; NetworkPolicy denies direct query API access. The
  one-byte-under case records zero apiserver/backing effects; the positive
  drives a compaction/restart/query high-water and reads filesystem usage from the mounted-volume boundary.
- **HA predicate (disambiguation).** "Its HA topology even at `replicas=1`" means the rendered manifest is
  **byte-identical modulo the replica-count field(s)** to the same service rendered at `replicas=n` (Patroni
  multi-member) — asserted by a render-diff whose only tolerated difference is the replica count — NOT a
  standalone/single-member variant that merely avoids a bare Pod.
- **Consumer end-to-end (§M.7 concrete corpus).** A `PerconaPGCluster` consumed by nothing does not satisfy
  the gate: the named consumer set is observed to **use** its cluster — authenticating with the credential
  resolved from its Vault `SecretRef` and reading back a SQL row it wrote — not merely that an unattached
  cluster reconciles.

**Representative service set (§M.7).** The gate's "remaining standard services" are exactly: the Percona
operator, the per-consumer Patroni Postgres clusters with pgAdmin for the named consumer set of Sprint 20.1,
and Prometheus + Grafana — no more, no fewer. The full derived DAG spans these plus the Phase-19 backbone
(MetalLB, MinIO, Pulsar) and the Phase-18 Vault.

## Doctrine adopted

- [`platform_services_doctrine.md §8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin)
  with [`§2 — HA always, including replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1):
  Phase 20 stands up the cluster-wide Percona operator reconciling one Patroni Postgres cluster per consuming
  capability, each paired with pgAdmin, each the byte-identical HA topology with only the replica count
  changed, and each carrying the **mandated synchronous configuration** §8 fixes — `synchronous_mode: on`,
  `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`.
- [`chaos_failover_doctrine.md §6 — the concentration principle: where the obligation lives`](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives):
  the RPO=0 / lossless-delegation premise holds **only** with the mandated Patroni settings; this phase makes
  the `PlannedIsLossless` premise a rendered, oracle-checked invariant rather than an assumed default, so an
  intra-cluster failover cannot promote a replica missing acknowledged commits.
- [`platform_services_doctrine.md §7 — Prometheus / Grafana, observability is not an add-on`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)
  with [`monitoring_doctrine.md §3 — derivation and the operator read-model`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model):
  Prometheus scrapes platform workloads and the derived recording/alert rules and per-workflow dashboards are
  generated, never hand-authored. Its mandatory finite work budget derives both CPU/memory and the exact
  retained TSDB peak/configuration from workflow/rule/series/sample-rate, interval, retention, structural
  query concurrency/series/samples/range/timeout, claim/backing, and versioned cost models. All queries enter
  through the generated admission proxy; the browser surfaces gated behind the (Phase 21) Keycloak edge
  under a mandatory `AccessScope` with no `Public` arm.
- [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  as the **derived readiness DAG** of [`readiness_ordering_doctrine.md §4 — ordering is a derived readiness DAG`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
  and [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
  the whole standard stack's hard ordering edges are derived from the declared dependency graph and enacted as
  observed-ready conditions, never a duration-gated or prose-ordered installer.
- [`manifest_generation_doctrine.md §5 — the apply/reconcile engine: server-side apply, owned field manager, prune, wait`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  and [`§2 — the typed manifest model (`renderAll` is the sole public pure function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
  Phase 20 reuses the Phase-16 pure `renderAll :: ProvisionedSpec -> [K8sObject]` and typed-action reconciler
  whose **wait-for-ready is observed from the live object, never a `threadDelay`** to apply and sequence the
  set.
- [`image_build_doctrine.md §2 — the single distribution rule`](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  every service binary (Percona operator, Patroni, pgAdmin, Prometheus, Grafana) is baked into the Phase-15
  multi-arch base image and resolved only in-cluster; nothing in this bring-up pulls from a public registry.
- [`platform_services_doctrine.md §10 — every execution unit declares its complete resource envelope`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)
  and [`resource_capacity_doctrine.md §3.1`](../documents/engineering/resource_capacity_doctrine.md#31-the-systematic-provision-matrix):
  every app/init/sidecar container and volume is the exact rendered projection of the checked CPU, memory,
  ephemeral-storage, durable-storage, cache, and accelerator fields; `None`/empty provisions remain explicit
  rather than silently omitted from the pure model.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each Patroni cluster and Prometheus lands its durable bytes on the Phase-17 `no-provisioner` retained PVs.
- [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  as [Register 2.5](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing): the
  *real* readiness-DAG orchestration runs unchanged under `IOSimPOR` against the Phase-11.4 modeled substrates
  before the Register-3 live gate.
- [`testing_doctrine.md §2 — three registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate is a Register-3 live bring-up on linux-cpu, emitting a ledger that names Register 3, marks
  the runtime layer *tested* (never *proven*), and marks the not-yet-built Keycloak-edge and singleton-owned
  reconcile layers UNVERIFIED.

## Sprints

## Sprint 20.1: Percona/Patroni Postgres per consumer + pgAdmin + Prometheus/Grafana 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Postgres.hs`, `src/Amoebius/Platform/Observability.hs` (target paths; not yet built)
**Blocked by**: Phase 19 (the MetalLB/MinIO/Pulsar backbone these services sit on), Phase 16 (reconciler), Phase 17 (retained PVs for the Patroni clusters and Prometheus), Phase 18 (each Patroni cluster's credentials are Vault secrets)
**Independent Validation**: the in-scope database-consumer set is named concretely as **exactly `{Grafana}`** — Grafana configured with an external Postgres (Patroni-via-Percona) backing datastore for its config/dashboard store (Keycloak is Phase 21; the `distribution` registry takes no database, §3); the cluster-wide Percona operator reconciles that consumer's `PerconaPGCluster` — an HA Patroni cluster even at one replica ("HA" meaning byte-identical modulo replica count to the multi-member Patroni topology), never a bare `postgres` Pod, paired with its own pgAdmin; each cluster carries the **mandated synchronous config** (`synchronous_mode: on`, `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`) asserted byte-equal to the committed `test/fixtures/phase20/patroni-sync-config.golden` oracle, with the committed `mutant/patroni-async-default` failing on the specific reason that `synchronous_mode_strict` is not `on`; the operator is up before any Postgres consumer; the consuming Grafana workload is observed to **use** the cluster end-to-end — it authenticates with the credential resolved from its Vault `SecretRef` and a SQL row it writes is read back from its own Patroni cluster (not merely that an unattached `PerconaPGCluster` reconciles); Prometheus scrapes platform workloads, the derived rules/dashboards are generated rather than hand-authored, and its exact retained-state projection plus one-byte-under/compaction boundary checks pass; every app/init/sidecar container and volume exactly matches its complete `ProvisionedServiceSpec` projection.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/monitoring_doctrine.md`,
`documents/engineering/chaos_failover_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md §8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin`](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin),
[`§7 — Prometheus / Grafana`](../documents/engineering/platform_services_doctrine.md#7-prometheus--grafana--observability-is-not-an-add-on)
with [`monitoring_doctrine.md §3`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model),
and the lossless premise of [`chaos_failover_doctrine.md §6`](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives):
stand up the Percona operator as a cluster-wide platform component reconciling per-consumer Patroni clusters —
each with pgAdmin and the mandated synchronous configuration — and Prometheus/Grafana with derived rules and
dashboards.

### Deliverables
- The Percona operator rendered as a cluster-wide platform component (from the shared inventory so it installs
  identically on every substrate), reconciling the per-consumer `PerconaPGCluster` for the named
  database-consumer set **`{Grafana}`** — HA Patroni even at `replicas=1` — each paired with its own pgAdmin;
  the `distribution` registry takes **no** database (§3). The consumer set is pinned here (resolving the
  `platform_services_doctrine.md §8` "Phase 19 delivery detail"); a `PerconaPGCluster` consumed by nothing does
  not satisfy this deliverable.
- The **mandated Patroni configuration** on every rendered cluster: `synchronous_mode: on`,
  `synchronous_mode_strict: on` (the decided strict stance — no synchronous standby ⇒ the primary refuses new
  writes; the degrade-to-async alternative is rejected), and a bytes-bounded `maximum_lag_on_failover` (a
  replica lagging past the bound is promotion-ineligible), authored as the committed independent oracle
  `test/fixtures/phase20/patroni-sync-config.golden`, with the committed seeded mutant
  `mutant/patroni-async-default` named as the mutant this invariant MUST turn red (on the specific reason that
  `synchronous_mode_strict` is not `on`).
- Prometheus + Grafana scraping platform workloads, with the per-workflow recording/alert rules and dashboards
  **derived, never hand-authored**. A mandatory finite `MonitoringWorkBudget` bounds workflow/rule/series
  cardinality, maximum scrape samples/second, evaluation work/interval, finite retention, a structural
  `QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout,
  costModel }`, and one StatefulSet claim/backing/presentation. Version-pinned evaluation, TSDB, and query cost
  folds derive Prometheus
  CPU/memory requests+limits for evaluation overlapping maximum concurrent queries, the query-admission
  proxy's complete pod envelope, plus retained blocks, WAL/head, old+new compaction overlap, and query/temp
  headroom as required usable bytes; the private storage witness then adds filesystem overhead and backing
  allocation rounding and supplies exact PVC/PV capacity, volumeMode, and fsType. Rendered Prometheus global and
  rule-group intervals, `--storage.tsdb.retention.time`, `--storage.tsdb.retention.size`, Prometheus
  query concurrency/sample/timeout flags, the sole-routable query-admission proxy series/range controls, and
  model-selected WAL/config settings equal those operands. NetworkPolicy blocks direct query API access. The
  live gate reads the effective configuration, argv, proxy controls, and claim
  back and refuses any shorter default/override or smaller volume. A descriptor above a count/rate bound or a
  mounted usable capacity one byte below the derived peak, or raw backing one allocation quantum below
  `provisionedBytes`, rejects before any SSA or backing-allocation effect; fixed requests or
  an arbitrary tiny PVC have no fallback arm. Optional local Thanos is a distinct bounded demand and cannot
  borrow the Prometheus claim. The browser surfaces reach a user
  only through the (Phase 21) Keycloak edge under a mandatory `AccessScope` with no `Public` arm — deferred
  here, marked UNVERIFIED.
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

### Validation
1. Assert the Percona operator is Ready before any `PerconaPGCluster`, then that the named consumer set
   `{Grafana}`'s cluster reconciles as an HA Patroni cluster (byte-identical modulo replica count to the
   multi-member topology, never a bare Pod) paired with pgAdmin, and that the consumer uses it end-to-end:
   Grafana authenticates with the credential from its Vault `SecretRef` and a SQL row written through Grafana's
   datastore is read back from its own Patroni cluster.
2. Assert each rendered Patroni config is byte-equal to the committed `patroni-sync-config.golden` oracle
   (`synchronous_mode: on`, `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`), and that the
   committed `mutant/patroni-async-default` fails the synchronous-mode invariant with the specific reason that
   `synchronous_mode_strict` is not `on` — paired with a positive that differs only in that field.
3. Assert Prometheus scrapes platform targets and the derived rules/dashboards are present and generated, not
   committed by hand. Exceed `maxRules`, `maxSeries`, or `maxScrapeSamplesPerSecond` by one and require a
   pre-effect budget rejection; exceed each query concurrency/series/samples/range/timeout operand and require
   proxy rejection without direct-Prometheus reachability; independently under-size Prometheus or proxy
   CPU/memory for the evaluation + maximum-concurrent-query overlap and require pre-effect rejection; repeat
   with mounted usable capacity exactly one
   byte below the independently
   rederived retained-block + WAL/head + compaction-overlap + query/temp peak and with raw allocation one
   quantum below the presentation-derived `provisionedBytes`; assert the apiserver audit and
   backing observer record zero SSA/PV/allocation writes. A committed fixed-Prometheus-requests/tiny-PVC mutant
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
   their aggregate request/limit/storage/rollout peak stays within it. A committed mutant dropping the CR
   resource projection (thereby using operator defaults) must turn both the manifest and live-child oracle red.
   Independently recompute the `PatroniSqlDemand` data/WAL/checkpoint/failover/recovery peak and make only the
   controller, webhook, SQL admission proxy, one Patroni member CPU/memory/ephemeral/pod/CSI slot, mounted usable byte, or rounded
   backing byte one unit short. Each case rejects before CR/volume creation; mutants omitting the webhook or
   treating the finite data size as the complete physical peak go red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 20.2: The full derived readiness-DAG bring-up + the standard-stack gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Services.hs`, `src/Amoebius/Platform/BringUp.hs` (target paths; not yet built)
**Blocked by**: Sprint 20.1, Phase 19 (the backbone the DAG folds in), Phase 18 (the Vault-initialized-and-unsealed → secret-dependent-startup edge)
**Independent Validation**: the full standard stack (Phase-19 backbone + the Sprint-20.1 services) is assembled as one acyclic derived readiness DAG whose edges are the §11 hard edges; the reconciler brings the set up strictly in that order, each dependent starting on its dependency's observed-ready condition (never a `threadDelay`); the live bring-up order is read from an **external-observer trace** (the apiserver watch / pod-readiness event stream at the OS boundary), the derived order asserted a pure function of the declared edges against the committed `test/fixtures/phase20/dag-edges.golden` table (independent of the `BringUp` fold), the committed `mutant/dag-drop-edge` (deleting the `perconaOperator → PerconaPGCluster` edge) turning both the order property and the live precondition red; no image request leaves the cluster for a public registry; the whole set is up, HA-shaped, and reachable in-cluster.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/readiness_ordering_doctrine.md`, `DEVELOPMENT_PLAN/README.md`

### Objective
Adopt [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
as the derived readiness DAG of [`readiness_ordering_doctrine.md §4`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
enacted by [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
fold the whole standard stack into one derived DAG, bring it up event-driven in that order, and close the
phase with the full-stack HA gate whose ordering claim is read from an external-observer trace.

### Deliverables
- A `BringUp` assembly that folds the whole standard-service set (Phase-19 backbone + Sprint-20.1 services)
  into an acyclic derived readiness DAG from the declared dependency graph (LoadBalancer → edge, Percona
  operator → Postgres consumers, Vault initialized-and-unsealed → secret-dependent startup), never a
  hand-sequenced script; the Vault-unsealed edge is the fail-closed condition of
  [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init).
- Live enactment by the Phase-16 reconciler's wait-for-ready — each dependent constructed to start on its
  dependency's observed-ready edge (a `runtime-checked` observation from the live object), never a duration;
  the singleton that will later own this loop is [Phase 22](phase_22_live_dsl_singleton.md) (Deployment
  `replicas=1`, no election).
- The phase-gate harness: bring the whole standard stack up on the Phase-19 backbone cluster and assert the
  complete set is up, HA-shaped, from generated (never-committed) manifests and baked binaries, with a
  proven/tested/assumed Register-3 ledger (runtime layer *tested*), and assert every applied execution
  unit/volume is an exact projection of its complete `ProvisionedServiceSpec`.
- The gate oracles, **authored and committed in Phase 0 before any implementation** (§M.1): a Register-1
  property `prop_bringUpOrderDerivedFromEdges` asserting the derived bring-up order is a pure function of the
  *declared* dependency edges (adding or removing a declared edge changes the order; an introduced cycle is
  rejected), checked against the committed hand-authored edge→order reference table
  `test/fixtures/phase20/dag-edges.golden` — an oracle **independent of** the `BringUp` fold (§M.3); the
  committed baked-base-image digest oracle `test/fixtures/phase20/expected-base-digest.txt`; and the committed
  seeded mutant **`mutant/dag-drop-edge`** (deletes the `perconaOperator → PerconaPGCluster` declared edge)
  which the gate MUST turn red (§M.2 committed mutation quota) — committed and re-run, not run once.

### Validation
1. Assert the bring-up honours the §11 DAG order — MetalLB address before the edge slot, Percona operator
   before its Patroni consumers, Vault-unsealed before secret-dependent startup — with each edge an observed
   condition and no timer standing in for a condition, and the **live order read from an external-observer
   bring-up trace** (apiserver watch / pod-readiness event stream at the OS boundary), never a compliance trace
   amoebius emits about itself. Beyond the observed order, assert **derivation**: the Register-1 property
   `prop_bringUpOrderDerivedFromEdges` (checked against the committed `test/fixtures/phase20/dag-edges.golden`
   reference table, independent of the `BringUp` fold) holds — the order is a pure function of the declared
   edges, adding/removing a declared edge changes it, an introduced cycle is rejected — and the committed
   seeded mutant `mutant/dag-drop-edge` turns this property (and the live precondition assertion) red. A
   hardcoded sequential list with wait-for-ready between steps does not satisfy this and MUST fail the property.
2. Round-trip MinIO put/get and Pulsar produce/consume against the assembled stack; assert Postgres is a
   Patroni cluster, never a bare Pod, carrying the mandated synchronous config (§20.1 oracle).
3. Assert the whole standard stack is up and HA-shaped from generated manifests + baked-binary images.
   "HA-shaped" is the render-diff predicate: each service's applied manifest is byte-identical **modulo the
   replica-count field(s)** to the same service rendered at `replicas=n` (MinIO erasure-set, Pulsar
   multi-broker/ZooKeeper/bookie, Patroni multi-member), not a standalone/single-broker variant. **Manifest provenance
   (§M.3):** re-run the pure `renderAll` in-process at gate time and assert the SSA-applied object bytes under the
   `amoebius` field manager are byte-identical to that output, foreclosing hand-written or `helm
   template`-derived YAML. **Image provenance (§M.5):** "no public-registry pull recorded" is read from the
   containerd/CRI image-pull event log on the kind node (the OS-boundary observer) over the whole gate window,
   **and** every running container's `imageID` digest MUST equal the Phase-15 baked base digest committed in
   `test/fixtures/phase20/expected-base-digest.txt` and present in the in-cluster `distribution` catalog — any
   other digest or public-registry reference (including a `kind load` side-load) fails. **Resource-provision
   identity:** compare every applied app/init/sidecar CPU/memory/ephemeral-storage request+limit, bounded
   `emptyDir`, PVC/PV capacity, cache-`None`, and accelerator-`None` projection to the opaque
   `ProvisionedServiceSpec`; recompute each effective pod envelope including ordinary and restartable-init
   sidecar semantics plus overhead; and
   require exact equality, not field presence. Emit the Register-3
   ledger, runtime layer *tested* not *proven* (Keycloak edge + singleton-owned reconcile marked UNVERIFIED).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 20.3: Register-2.5 readiness-DAG bring-up under simulated partial failure 📋

**Status**: Planned
**Implementation**: `test/Amoebius/Platform/BringUpSim.hs` (the `IOSimPOR` harness driving the *unmodified* Sprint-20.2 `src/Amoebius/Platform/BringUp.hs` orchestration; target paths, not yet built) over the Phase-11.4 modeled substrate `src/Amoebius/Sim/Env.hs` + `src/Amoebius/Sim/Fakes/*`
**Blocked by**: Sprint 20.2 (the derived readiness-DAG bring-up this sprint drives unchanged), Sprint 20.1 (the services it assembles), Phase 11 Sprint 11.4 (the modeled fault-injectable environment — fake Pulsar/MinIO/apiserver/route53/Vault/clock — this runs against)
**Independent Validation**: the exact Sprint-20.2 bring-up orchestration, written against `io-classes` with no real IO, runs under `IOSimPOR` against the Phase-11.4 fakes with injected partial failure / restart / partition on the modeled dependencies, and across the explored schedules asserts (a) no service starts before its readiness precondition, (b) the applicative-concurrent bring-up is deadlock-free and fail-closed on a missing/unhealthy dependency, (c) it never reports success until every service is Ready, and (d) a **concurrency witness** — on at least one explored schedule the bring-up intervals of two declared-dependency-independent services (MinIO and the Percona operator) **overlap**, proving genuine applicative concurrency a hand-sequenced total order cannot produce; the committed seeded mutant `mutant/dag-drop-edge` (Sprint 20.2) is asserted to turn assertion (a) red under `IOSimPOR`; each run is deterministically replayable from its seed on substrate `none` and emits a Register-2.5 ledger.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective
Adopt [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md) as [Register 2.5](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) over this phase's own bring-up: take the *real* Sprint-20.2 readiness-DAG orchestration — the derived DAG with **applicative concurrent deploy where services are independent and sequential where they depend**, the HA-always readiness ordering this phase owns — and run it unchanged under `IOSimPOR` against the Phase-11.4 modeled substrates, validating the ordering and fail-closed invariants deterministically in-process before the Register-3 live gate ever runs.

### Deliverables
- An `IOSimPOR` harness that drives the *unmodified* Sprint-20.2 `BringUp` orchestration (written against `io-classes`, no real IO) against the Phase-11.4 fake Pulsar/MinIO/apiserver/route53/Vault/clock (`src/Amoebius/Sim/Env.hs` + `src/Amoebius/Sim/Fakes/*`), with injected **partial failure, restart, and network partition** on the modeled dependencies.
- Schedule-exhaustive assertions over the partial-order search: (a) **no service starts before its readiness precondition** on any explored schedule, (b) the concurrent bring-up is **deadlock-free** and **fail-closed** — a missing or unhealthy dependency halts the dependent and is never silently proceeded past, (c) the orchestration **does not report success until every service is Ready**, and (d) a **concurrency witness**: on at least one explored schedule the bring-up intervals of two declared-dependency-independent services (MinIO and the Percona operator) overlap — an assertion a hardcoded sequential program cannot satisfy. The committed `mutant/dag-drop-edge` seeded mutant MUST turn assertion (a) red here.
- A deterministically replayable seed on any failing schedule and a Register-2.5 ledger recording substrate `none`, the register, and the honest limit that modeled-substrate fidelity is *assumed*.

### Validation
1. Run the bring-up under `IOSimPOR`; assert across explored schedules that every §11 hard edge (LoadBalancer → edge, Percona operator → Postgres consumer, Vault-unsealed → secret-dependent startup) holds — no dependent observed to start before its precondition on any schedule.
2. Inject partial failure / restart / partition on a modeled dependency; assert the applicative-concurrent bring-up stays deadlock-free and fails closed on the missing/unhealthy dependency, never reporting success with a service not-Ready. Assert the concurrency witness: on at least one explored schedule the bring-up intervals of MinIO and the Percona operator (declared-dependency-independent) overlap — proving genuine applicative concurrency, not a hand-sequenced total order — and assert the committed `mutant/dag-drop-edge` mutant turns the precondition assertion red.
3. Replay a captured seed and assert a bit-identical schedule and outcome; emit the Register-2.5 ledger — substrate `none`, Register 2.5 — recording the honest limit that modeled-substrate fidelity is *assumed* and is discharged only by this phase's Register-3 live gate (Sprint 20.2).

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §8 "which standard
  services take a database" detail resolves to the delivered consumer set `{Grafana}`, and the §8 mandated
  synchronous-Patroni configuration flips from "required configuration" design intent to a Register-3-tested,
  oracle-checked amoebius result on linux-cpu.
- `documents/engineering/chaos_failover_doctrine.md` — the §6 `PlannedIsLossless` premise gains its first
  live evidence that the mandated `synchronous_mode`/`synchronous_mode_strict`/`maximum_lag_on_failover`
  settings are actually rendered and enforced (the delegation is *tested*, never *proven*).
- `documents/engineering/readiness_ordering_doctrine.md` — the §11-derived-DAG bring-up gains its first live
  amoebius enactment over the whole standard stack; the §6 reconciler-observes-never-sleeps claim gains its
  first Register-3 evidence, read from an external-observer trace.
- `documents/engineering/monitoring_doctrine.md` — the §3 derived rules/dashboards are recorded as stood up
  (browser access still behind the Phase-21 edge, marked UNVERIFIED here).
- `documents/engineering/resource_capacity_doctrine.md` — record the full standard-stack live assertion that
  every Kubernetes resource/volume field is the exact projection of its checked `ProvisionedServiceSpec`.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-20 status when the gate passes and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 20's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — reconcile the `src/Amoebius/Platform/*` target module paths named
  in each sprint against the component inventory once they become concrete.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the §7/§8 services + §11 bring-up ordering adopted here
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the §6 lossless-delegation premise the mandated Patroni config underwrites
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — the derived readiness DAG the reconciler enacts
- [Monitoring Doctrine](../documents/engineering/monitoring_doctrine.md) — the derived observability surfaces
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the Phase-16 renderer + SSA wait-for-ready that applies and sequences the set
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base image, pull-only-in-cluster
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained PVs the stateful services land on
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 `IOSim`/`IOSimPOR` simulation of the real bring-up over the Phase-11.4 modeled substrates
- [phase_18](phase_18_vault_pki.md) — the root Vault/PKI whose unseal edge gates secret-dependent startup here
- [phase_19](phase_19_platform_backbone.md) — the MetalLB/MinIO/Pulsar backbone this phase's services and DAG build on
- [phase_21](phase_21_keycloak_ingress.md) — the Keycloak-owned ingress edge that fronts Grafana and pgAdmin next
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
