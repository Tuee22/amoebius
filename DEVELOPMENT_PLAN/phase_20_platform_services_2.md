# Phase 20: Platform services-2 (Percona/Patroni + pgAdmin + observability + readiness-DAG)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/system_components.md
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
`postgres` Pod), each rendered as typed Kubernetes objects by the Phase-16 pure `render` (no Helm, no
third-party charts, manifests generated from Haskell and never committed), each served from binaries **baked
into the multi-arch base image** with no public-registry pull, and each on the Phase-17 `no-provisioner`
retained PVs where it holds durable state.

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
`maximum_lag_on_failover`) asserted against a committed oracle; **and the whole standard stack comes up in the
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
- **Render byte-identity (§M.3 independent provenance).** At gate time the pure `render` is re-run in-process
  and the SSA-applied object bytes under the `amoebius` field manager MUST be byte-identical to that fresh
  `render` output — pinning applied manifests to the Phase-16 renderer, so hand-written or `helm
  template`-derived YAML embedded as string constants fails.
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
  generated, never hand-authored — the browser surfaces gated behind the (Phase 21) Keycloak edge under a
  mandatory `AccessScope` with no `Public` arm.
- [`platform_services_doctrine.md §11 — bring-up and dependency ordering`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  as the **derived readiness DAG** of [`readiness_ordering_doctrine.md §4 — ordering is a derived readiness DAG`](../documents/engineering/readiness_ordering_doctrine.md#4-ordering-is-a-derived-readiness-dag-not-a-hand-sequenced-script)
  and [`§6 — the reconciler observes, never sleeps`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
  the whole standard stack's hard ordering edges are derived from the declared dependency graph and enacted as
  observed-ready conditions, never a duration-gated or prose-ordered installer.
- [`manifest_generation_doctrine.md §5 — the apply/reconcile engine: server-side apply, owned field manager, prune, wait`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  and [`§2 — the typed manifest model (render is a pure total function to objects)`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
  Phase 20 reuses the Phase-16 pure `render` and the SSA reconciler whose **wait-for-ready is observed from the
  live object, never a `threadDelay`** to apply and sequence the set.
- [`image_build_doctrine.md §2 — the single distribution rule`](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  every service binary (Percona operator, Patroni, pgAdmin, Prometheus, Grafana) is baked into the Phase-15
  multi-arch base image and resolved only in-cluster; nothing in this bring-up pulls from a public registry.
- [`platform_services_doctrine.md §10 — every container declares CPU and RAM`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram):
  every rendered container carries explicit CPU/RAM requests and limits.
- [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  and [`§4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
  each Patroni cluster and Prometheus lands its durable bytes on the Phase-17 `no-provisioner` retained PVs.
- [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md)
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
**Independent Validation**: the in-scope database-consumer set is named concretely as **exactly `{Grafana}`** — Grafana configured with an external Postgres (Patroni-via-Percona) backing datastore for its config/dashboard store (Keycloak is Phase 21; the `distribution` registry takes no database, §3); the cluster-wide Percona operator reconciles that consumer's `PerconaPGCluster` — an HA Patroni cluster even at one replica ("HA" meaning byte-identical modulo replica count to the multi-member Patroni topology), never a bare `postgres` Pod, paired with its own pgAdmin; each cluster carries the **mandated synchronous config** (`synchronous_mode: on`, `synchronous_mode_strict: on`, bounded `maximum_lag_on_failover`) asserted byte-equal to the committed `test/fixtures/phase20/patroni-sync-config.golden` oracle, with the committed `mutant/patroni-async-default` failing on the specific reason that `synchronous_mode_strict` is not `on`; the operator is up before any Postgres consumer; the consuming Grafana workload is observed to **use** the cluster end-to-end — it authenticates with the credential resolved from its Vault `SecretRef` and a SQL row it writes is read back from its own Patroni cluster (not merely that an unattached `PerconaPGCluster` reconciles); Prometheus scrapes platform workloads and the derived rules/dashboards are generated, not hand-authored; every container declares CPU/RAM.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/monitoring_doctrine.md`, `documents/engineering/chaos_failover_doctrine.md`

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
  **derived, never hand-authored**; the browser surfaces reach a user only through the (Phase 21) Keycloak edge
  under a mandatory `AccessScope` with no `Public` arm — deferred here, marked UNVERIFIED.
- Explicit CPU/RAM requests+limits on every rendered container; durable bytes on retained PVs.

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
   committed by hand; assert every platform pod declares CPU/RAM and each Patroni cluster's credentials resolve
   from Vault.

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
  proven/tested/assumed Register-3 ledger (runtime layer *tested*).
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
   multi-broker/bookie, Patroni multi-member), not a standalone/single-broker variant. **Manifest provenance
   (§M.3):** re-run the pure `render` in-process at gate time and assert the SSA-applied object bytes under the
   `amoebius` field manager are byte-identical to that output, foreclosing hand-written or `helm
   template`-derived YAML. **Image provenance (§M.5):** "no public-registry pull recorded" is read from the
   containerd/CRI image-pull event log on the kind node (the OS-boundary observer) over the whole gate window,
   **and** every running container's `imageID` digest MUST equal the Phase-15 baked base digest committed in
   `test/fixtures/phase20/expected-base-digest.txt` and present in the in-cluster `distribution` catalog — any
   other digest or public-registry reference (including a `kind load` side-load) fails. Emit the Register-3
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

**Engineering docs to update:**
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
