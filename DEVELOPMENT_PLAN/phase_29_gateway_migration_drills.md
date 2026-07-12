# Phase 29: Gateway-migration drills + model-correspondence

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_28_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Discharge the Register-3 residue of amoebius's one proof obligation — drive the built
> `src/Amoebius/Multicluster/*` gateway-migration runtime through **both** a `Planned` coordinated handover
> (RPO=0) and a `Failover` emergency takeover (bounded rebind) against the live [Phase
> 28](phase_28_multicluster_spawn_georepl.md) forest, trace-validate it against the Phase-3 emitted spec, and
> show that runtime *is* the Phase-3 design-model's decision core.

---

## Phase Status

📋 Planned. The gateway-migration runtime (both branches), the teardown-with-cleanup-vs-chaos distinction, the
unsatisfiable-`.dhall` push-back, the Register-2.5 trace-validation, and the Register-3 correspondence against
the Phase-3 design-model are all specified and unstarted; every sprint below is design intent and every
prescriptive statement is a target shape, not a tested amoebius result. This phase opens after the Phase 28 gate
(the geo-replicated forest) and runs on the **linux-cpu** substrate in **Register 3** (live infrastructure).
Where it leans on the sibling prodbox project — the gateway single-writer pattern — that is **sibling evidence,
not an amoebius result**. There is **no** First-Axis / singleton-election work here: the sole per-system
obligation amoebius owns is the cross-cluster gateway migration, both branches, and this phase discharges its
live residue.

## Phase Summary

Because [Phase 28](phase_28_multicluster_spawn_georepl.md) turned the single cluster into a geo-replicated
forest and classified the crossing boundary — leaving the gateway authority and any CAS "latest" pointer in the
non-confluent bucket — the one thing that remains is the authority hand-off across that boundary. This phase does
four things and stops there. First, **the gateway-migration runtime** — the built
`src/Amoebius/Multicluster/*` modules enact the wild-ingress gateway move in both branches: a `Planned`
coordinated `quiesce → drain → verify-caught-up → cutover` that loses no committed write (RPO=0), and a
`Failover` survivor-promotion through a fail-closed freshness gate that repoints route53 and the WireGuard hub
and rebinds within a declared data-loss budget, each keeping a live session bindable throughout. Second, **the
teardown-vs-chaos distinction** — a graceful teardown-with-cleanup is lossless by construction (it rides a
synchronization event and hands off the gateway as a `Planned` migration), a chaos-failover is bounded by
budget, the two are observably distinct, and a teardown that would make the root `InForceSpec` unsatisfiable
pushes back. Third, **the Register-2.5 trace-validation** — the real forest code runs under `IOSimPOR` against a
modeled route53/Pulsar and its observed transition log is validated step-by-step against the Phase-3 emitted
spec's `Next` relation, pulling the runtime-fidelity obligation forward from Register-3-only chaos into
deterministic, replayable simulation. Fourth, **the correspondence** — because Phase 3 rendered one reifiable
`Model` into both `interpret` (the runtime decision core) and `emitTLA` (the proven, never-committed `.tla`),
the built runtime's per-edge decision *is* that `interpret`; correspondence therefore holds by construction, and
what this phase adds is the Register-3 chaos injection against a running forest that confirms the abstracted
physics (real time, clock skew, actual replication lag, the MinIO/Pulsar/Patroni lossless delegation) actually
hold — never a hand-maintained variable→module table.

This phase consumes earlier phases and does not re-implement them: Phase 28's geo-replicated forest and
invariant-confluence classifier, Phase 3's `GatewayMigration` `Model` + `interpret` + decode-time
structural-fit fold, Phase 21's Keycloak-owned wild ingress, Phase 27's WireGuard fabric (whose hub role the
`Planned` handover repoints), and Phase 11 Sprint 11.4's `io-classes` seams and modeled route53/Pulsar. A
**stretched cluster is not geo-replication**: one etcd, one boundary owes no R9 budget and no Second-Axis
obligation and is out of scope here.

**Substrate:** linux-cpu — the gate drives the migration over the parent and both child clusters that Phase 28
spins up as `kind`/`rke2` clusters on a single linux-cpu host; no accelerator and no provider cluster is in
scope (provider-managed clusters are [Phase 30](phase_30_provider_clusters.md)). Partition tolerance is
exercised by killing a sibling on the same host — not a property a single root cluster exercises.

**Register:** 3 — live infrastructure: a real geo-replicated forest, a real DNS repoint, a real WireGuard
hub-role move, and adversarial fault injection against the running forest.

**Gate:** a `Planned` handover completes with **RPO=0** — proven not by a bare "loss = 0" but by the external
write-journal oracle of [§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists) below: the drill runs under a **non-idle** workload (the client journals every
source-acked write ID to a store *outside* the forest, and the harness asserts **≥ 8 acked-but-un-replicated
write IDs exist at the quiesce instant**, i.e. observed replication lag > 0, before authority moves), and
post-cutover every journaled ID is present on the new owner; killing the lead cluster mid-workflow (again with
≥ 8 acked-but-un-replicated IDs in flight) drives a `Failover` that promotes the surviving sibling only through
its fail-closed freshness gate, repoints route53 and the WireGuard hub, and **rebinds within the committed
numeric `DataLossBudget`** — the concrete budget (`lagBound = 5 s`, `RTO = 60 s`, scaled to the single-host kind
forest) is authored and committed in `test/dhall/phase_29_gateway_migration.dhall` **in Phase 0, before any
runtime exists**, its content hash recorded in the gate record, and the drill reports declared-vs-measured for
**both** dimensions so a post-hoc-tuned or absurd budget is visible red; the gate turns red on **at least one
committed seeded mutant** ([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists): the `verify-caught-up`-stub and `promote-before-fence` mutants); the built
`src/Amoebius/Multicluster/*` runtime is shown to correspond to the Phase-3 `GatewayMigration` design-model — the
built decision core is that model's `interpret` (correspondence-by-construction, discharged as step-by-step
trace-validation in Register 2.5 per Sprint 29.3, with the Register-3 drills adding only a
modeled-action-coverage assertion that every modeled action fired ≥ 1 time across the drill set); the Register-3
Inject drills assert the four named invariants (`UniqueGatewayOwner`, `SessionAlwaysRebindable`,
`PlannedIsLossless`, `NoWriteAfterStaleFailover` — the safety half of the superseded `FailoverBounded`; the
recovery-time half is carried separately as the *tested* RTO datapoint, not as a bounded-divergence invariant)
against the live forest; the forest tears down leak-free by the OS-boundary route53/`pulumi stack ls` observer
(retained `no-provisioner` PVs exempt); and the run emits a **machine-derived** proven/tested/assumed ledger
([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists)) recording recovery time as *tested* (drilled), the data-loss bound as *assumed* (monitored, not proven),
and the modeled safety/liveness as *proven-for-the-model at scope 2* (a Phase-3 design result, never a runtime
guarantee); layers outside Register 3 stay marked UNVERIFIED, and — as a Register-3 live-band gate — the runtime
layer is marked *tested*, never *proven*.

## N. Gate-integrity oracles (committed in Phase 0, before the runtime exists)

This phase's gate binds to the
following named, committed artifacts so no self-authored harness or post-hoc fixture can pass it:
- **Write-journal oracle (independent of the SUT).** The drill client writes every source-acked write ID to
  `test/inject/journal/` (a store outside the forest, never the SUT's own replication log). "Committed write"
  means *source-acked*, not *already-replicated*; the harness asserts **≥ 8** such IDs are
  acked-but-not-yet-replicated at the quiesce/kill instant (a positive observed lag), then asserts set-equality
  of journaled-vs-present IDs on the new owner. The ledger embeds the raw journal counts (acked,
  un-replicated-at-cut, recovered), never a bare "loss = 0".
- **Committed numeric budget fixture.** `test/dhall/phase_29_gateway_migration.dhall` fixes `lagBound = 5 s`,
  `RTO = 60 s`; authored and committed in Phase 0; its hash is pinned in the gate record and re-checked at gate
  time so a budget edited after measuring the drill fails the hash check.
- **Committed seeded mutants (≥ 1 must go red).** From the §M operator set: (a) `verify-caught-up`-stub — the
  `Planned` `verify-caught-up` edge is weakened to `const True` (dropped-guard); the journal oracle must catch
  the lost un-replicated suffix red. (b) `promote-before-fence` — the `Failover` `PromotionGate` guard is negated
  so it promotes without a proven watermark/fence (guard-negation); `NoWriteAfterStaleFailover` must go red. Both
  mutants are committed under `test/inject/mutants/` and re-run every gate, not hand-run once.
- **External-observer teardown check.** "Tears down leak-free" is scoped for Phase 29 (the flagged-credential +
  postflight tag-sweep machinery of testing_doctrine §6–§7 is Phase 36) to: after teardown, an **OS-boundary
  observer** — the route53 API (`ListResourceRecordSets`) and `pulumi stack ls`, read outside the forest —
  reports zero surviving migration DNS records and zero surviving child stacks, while the retained
  `no-provisioner` PVs that Sprint 29.2 deliberately preserves are explicitly exempt (named in the fixture as the
  retained set).
- **Machine-derived ledger + validator.** The ledger is generated from the run record (measured RPO/RTO,
  observed max lag, the raw journal counts, drill seeds, timestamps, the teardown-observer result), and a
  committed validator cross-checks every ledger figure against the harness's raw journal and the OS-boundary
  observer, failing the gate on any mismatch or hand-edited field.

## Doctrine adopted

- [`consistency_pacelc_doctrine.md §3`](../documents/engineering/consistency_pacelc_doctrine.md#3-the-one-configurable-axis--the-deployment-rules-pacelc-surface)
  — **the PACELC failover budget (`rto` / `dnsTtl` / `lagBound`) and its decode folds.** The `Failover` drill
  rebinds within the declared `FailoverBudget`; the phase corpus includes an `rto < dnsTtl` spec that is Gate-2
  decode-rejected ([§3.5](../documents/engineering/consistency_pacelc_doctrine.md#35-the-upload-time-feasibility-push-back)),
  and "clients/resolvers honor the record TTL" is recorded as a named R8 **assumed** premise.
- [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)
  and [`§7`](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership)
  — *correspondence by construction* and *planning ownership*: because `interpret` and `emitTLA` render one
  `Model`, there is **no** separate variable→module correspondence table to complete; what remains for the live
  phase is the Register-3 chaos injection against a running forest (that the abstracted physics hold), and this
  phase is exactly that gate. It also inherits the [`§1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation)
  one-obligation framing (no First-Axis election model) and the [`§5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  scope-2 pairwise cutoff the built forest must stay inside.
- [`gateway_migration_doctrine.md §2`](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)
  and [`§3`](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover)
  — the two arms of `GatewayMigration = <Planned | Failover>`: the coordinated strong-consistency handover
  (RPO=0, argued-design-level) and the availability-first emergency takeover (RPO>0, bounded by the data-loss
  budget, reconciling to a single owner) — with the client-rebind protocol of
  [`§4`](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway)
  and the typed, edge-observed state machine of
  [`§5`](../documents/engineering/gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine)
  built as the effectful shell around the Phase-3 decision core, honest per
  [`§6`](../documents/engineering/gateway_migration_doctrine.md#6-honesty-and-layer-markers).
- [`chaos_failover_doctrine.md §18`](../documents/engineering/chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary)
  and [`§19`](../documents/engineering/chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows)
  — the R7/R8/R9 cross-boundary rules: the fail-closed promotion-freshness gate and active-merge reconciliation
  (R7), the named-bounded-monitored replication lag (R8), and the two-dimensional failover budget — bounded
  permanent data loss and bounded recovery time (R9) — with the
  [Inject move (§11)](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
  run against the running forest and the [proven/tested/assumed ledger (§12)](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  kept honest. The doctrine works this exact shape through in its
  [Appendix B](../documents/engineering/chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question)
  worked example; this phase realizes it live.
- [`cluster_lifecycle_doctrine.md §5`](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction),
  [`§6`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
  and [`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  — the central distinction between a lossless teardown-with-cleanup and a bounded-loss chaos-failover, and the
  declarative push-back on a teardown that would make the root `InForceSpec` unsatisfiable — all enacted as
  `discover → diff → enact → re-observe` reconciles over a managed-resource registry, never a bespoke lifecycle
  state machine.
- [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — the Register-2.5 runtime-fidelity stage: the real forest code under `IOSimPOR` against a modeled
  route53/Pulsar, trace-validated against the Phase-3 emitted spec's `Next` relation before the Register-3 live
  drills, so the code↔model bridge is a formal, early, replayable check rather than only sampled live chaos.
- [`testing_doctrine.md §3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  (the test-as-`InForceSpec` spin-up → run → always-tear-down contract) and §4 (the per-run
  proven/tested/assumed ledger): the register this gate reaches and the ledger it emits.

## Sprints

## Sprint 29.1: The gateway-migration runtime — both branches over the Phase-3 `interpret` core 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/GatewayMigration.hs` (the effectful orchestrator whose per-edge
decision delegates to the Phase-3 `src/Amoebius/Formal/GatewayMigration.hs` `interpret`),
`src/Amoebius/Multicluster/PlannedHandover.hs`, `src/Amoebius/Multicluster/PromotionGate.hs`,
`src/Amoebius/Multicluster/DnsRepoint.hs`, `src/Amoebius/Multicluster/ClientRebind.hs` — target paths, not yet
built.
**Blocked by**: Phase 28 (the geo-replicated forest + invariant-confluence classifier, Sprint 28.2); Phase 3
(the `GatewayMigration` `Model` + `interpret` + structural-fit fold); Phase 21 (Keycloak-owned wild ingress via
the LB + Gateway API); Phase 27 (the WireGuard fabric — the `Planned` handover repoints the hub role).
**Independent Validation**: a `Planned` handover drives the ordered edge-observed state machine
(`stand-up-replica → quiesce → drain / verify-caught-up → promote → source-proxy + repoint DNS → unfreeze →
drain-monitor → decommission`) and loses no committed write (RPO=0), the old gateway serving as a transparent
proxy for the whole DNS-drain window so a live session always has a working endpoint; a `Failover` promotes the
survivor *only after* its freshness gate proves a known commit watermark (or holds a fence), then repoints
route53 and the WireGuard hub, accounting for the un-replicated suffix **only** by the R9 data-loss budget, never
silently resolved to "absent."
**Docs to update**: `documents/engineering/gateway_migration_doctrine.md`,
`documents/engineering/chaos_failover_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`.

### Objective
Adopt [`gateway_migration_doctrine.md §2`](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)/[`§3`](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover),
the client-rebind protocol of [`§4`](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway),
and the R7/R8/R9 cross-boundary rules of
[`chaos_failover_doctrine.md §18`](../documents/engineering/chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary):
build the effectful gateway-migration shell for **both** branches whose every branch decision is the Phase-3
pure `interpret` value (a *liveness* coercion is licensed; a *durability* claim is forbidden — the tail beyond
the watermark stays a typed `NotYetObserved`), so the runtime realizes the proven model rather than re-deriving
it.

### Deliverables
- A `Planned` coordinated `quiesce → drain → verify-caught-up → cutover` (repoint the gateway DNS record, the
  WireGuard hub role, and the apiserver VPN-IP, then unfreeze) whose `decommission(source-ingress)` edge is
  reachable only from an observed `drain-monitor` edge, so no transition removes the last working endpoint.
- A `Failover` fail-closed `PromotionGate`: the survivor promotes only on a proven commit watermark or a held
  fence, trading recovery time (R9 RTO) for zero divergence beyond the already-lost suffix; a route53 repoint via
  Pulumi-from-inside; and a deterministic, total, timestamp-free merge of the non-confluent CAS "latest" pointer
  on failback.
- The client-rebind mechanisms — old-gateway transparent proxy, a low steady-state DNS TTL, stable per-cluster
  addresses, and the 307 fallback — plus an exported live-lag monitor (R8) and a declared `DataLossBudget` =
  (data-loss window, recovery time).

### Validation
1. A `Planned` handover under a **non-idle** workflow (the drill client journals every source-acked write ID to
   the out-of-forest store of [§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists), and the harness asserts **≥ 8 acked-but-un-replicated IDs exist at the quiesce
   instant** — observed replication lag > 0 — so an idle-workload rubber stamp cannot pass) moves authority with
   **measured loss = 0 proven by set-equality of journaled-vs-present IDs on the new owner** (not by a
   self-defined "committed = already replicated"), and a session that never loses its endpoint; a `Failover`
   after killing the lead (again with ≥ 8 acked-but-un-replicated IDs in flight) resumes through one authority
   with **measured loss ≤ the committed `lagBound` and authority transfer within the committed `RTO`**, where
   those budgets are the Phase-0-committed numeric values in `test/dhall/phase_29_gateway_migration.dhall`
   (`lagBound = 5 s`, `RTO = 60 s`) whose hash is pinned before the drill runs — the drill **reports
   declared-vs-measured for both dimensions**, so a generous or post-hoc-tuned budget is visible; driving lag
   past the committed bound makes the freshness gate refuse to promote and the lag monitor alarm before a breach;
   and the committed `promote-before-fence` mutant ([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists)) — the `PromotionGate` guard negated — must go red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.2: Teardown-with-cleanup vs chaos-failover + unsatisfiable-`.dhall` push-back 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/Teardown.hs`, `src/Amoebius/Multicluster/Pushback.hs` — target
paths, not yet built.
**Blocked by**: Phase 28 (the spawn managed-resource registry, Sprint 28.1); Sprint 29.1 (a clean gateway
handoff is part of a graceful teardown).
**Independent Validation**: a graceful teardown of a child drains workloads, flushes Pulsar/MinIO/Postgres
replication to a synchronization event, hands off the gateway (a `Planned` migration), and releases compute while
preserving retained `no-provisioner` PVs — losing nothing; a teardown that would make the root `InForceSpec`
unsatisfiable pushes back, names what stops working and the declared failback, and proceeds only under an
explicit override.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`.

### Objective
Adopt [`cluster_lifecycle_doctrine.md §5`](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)/[`§6`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
enacted as the reconciler of
[`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine):
implement a graceful teardown as a controlled handoff that is lossless by construction, and the declarative
push-back that refuses — by default — a teardown that would leave the persistent global `.dhall` unsatisfiable,
with an explicit operator override the only escape.

### Deliverables
- A `gracefulTeardown` reconcile: idempotent drain/flush/handoff ordering timed to a synchronization event,
  releasing compute and preserving retained PVs so a later spin-up rebinds the same bytes.
- A `satisfiability` check over the root `InForceSpec` using each container's declared CPU/RAM: if the surviving
  forest can no longer satisfy the spec without cluster C, push back naming the loss and the `.dhall` failback,
  with the same fail-closed `Unreachable → refuse` posture as the reconciler.
- A managed-resource registry entry per cluster/child/node/stack/PV so teardown is one `reconcileAbsent` loop
  with "cannot observe" never collapsed to "absent."

### Validation
1. A graceful child teardown loses nothing (rides a sync event, preserves PVs) and a later spin-up rebinds the
   identical shape and bytes; a teardown of a load-bearing cluster pushes back and aborts by default, and the
   explicit override falls to the declared failback; a graceful teardown and a chaos-failover are observably
   distinct — lossless-by-construction vs bounded-by-budget — and the code reports which guarantee held.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.3: Register-2.5 gateway-migration runtime fidelity — simulation + trace validation 📋

**Status**: Planned
**Implementation**: `test/sim/GatewayMigrationSimSpec.hs` (the `IOSimPOR` battery over the modeled
route53 + geo-replicated Pulsar) and `test/sim/GatewayMigrationTrace.hs` (the trace-validator checking observed
transitions against the emitted `Next`), driving the real `src/Amoebius/Multicluster/*` forest code lifted onto
the Phase-11.4 `io-classes` `Env` interface — target paths, not yet built.
**Blocked by**: Sprint 29.1 (the built `Multicluster/*` forest code); Phase 28 (the geo-replicated forest);
Phase 3 (the emitted TLA+ spec + `interpret`); Phase 11 Sprint 11.4 (the `io-classes` seams + the modeled
route53/Pulsar).
**Independent Validation**: the real `Multicluster/*` forest code runs under `IOSimPOR` against the modeled
route53 (short-TTL, **no compare-and-swap**, propagation delay) and modeled geo-replicated Pulsar with injected
partition, kill-cluster-mid-geo-sync, and replication-lag; the suite asserts the four **safety** invariants
(`UniqueGatewayOwner`, `SessionAlwaysRebindable`, `PlannedIsLossless`, `NoWriteAfterStaleFailover`) hold on
every explored schedule, **and** trace-validates the forest's observed transition log step-by-step against the
Phase-3 emitted spec's `Next` relation
([`formal_model_doctrine.md §8`](../documents/engineering/formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge))
— pulling the runtime-fidelity (Tier-2) obligation **forward** from Register-3-only chaos into deterministic,
replayable simulation. Substrate `none`, Register 2.5.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (Phase-29 status backlink),
`documents/engineering/gateway_migration_model_doctrine.md` (§6 the Register-2.5 trace-validation bridge),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
and [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty):
discharge the runtime-fidelity obligation in two stages, not one — first as trace-validated deterministic
simulation against the modeled world here (Register 2.5), then as live Inject drills (Sprint 29.4, Register 3)
— so the code↔model bridge is a formal, early, replayable check rather than only sampled live chaos.

### Deliverables
- The `GatewayMigrationSimSpec` battery: the real forest code under `IOSimPOR` against the modeled
  route53/Pulsar, asserting the four safety invariants under injected partition/kill-cluster-mid-geo-sync/lag.
- The `GatewayMigrationTrace` validator: each observed transition of the simulated forest is a legal `Next`-step
  of the Phase-3 emitted spec (a mismatch is a code↔model divergence, red).
- A Register-2.5 proven/tested/assumed ledger — the built forest upholds the safety invariants and refines the
  model's `Next` under the modeled schedules and faults; honest limit: modeled route53/Pulsar fidelity and real
  replication-lag / clock-skew physics remain the Register-3 residue (Sprint 29.4).

### Validation
1. `cabal test gateway-migration-sim` is green — no schedule violates a safety invariant and no observed
   transition falls outside `Next`; a deliberately broken forest (a fence dropped, a decommission-before-drain)
   is caught red; the discovered counterexample replays identically under its seed.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.4: Register-3 correspondence — Inject drills against the running forest + live gate `.dhall` + ledger 📋

**Status**: Planned
**Implementation**: `test/dhall/phase_29_gateway_migration.dhall` (the live gate topology) and
`test/inject/GatewayMigrationForest.hs` (the Register-3 Inject harness re-using the Phase-3 named invariants
against the built runtime) — target paths, not yet built. The Phase-3 `GatewayMigration` `Model`, its `emitTLA`
proof, and its io-sim agreement were authored and discharged in Phase 3; this sprint consumes them, it does not
re-author them.
**Blocked by**: Phase 3 (the proven-for-the-model `GatewayMigration` `Model` + `interpret` + structural-fit
fold); Phase 28 (the geo-replicated forest); Sprint 29.1; Sprint 29.2; Sprint 29.3 (the Register-2.5 simulation
+ trace validation that precedes the live drills).
**Independent Validation**: the built `src/Amoebius/Multicluster/*` decision core is shown to be the Phase-3
`interpret` (correspondence-by-construction — no variable→module table, per the superseded framing's reversal);
the Register-3 Inject drills (cut replication, kill the lead mid-`Planned`-handover, kill the lead with no drain
to force `Failover`, drive lag past the bound, fail back with late + duplicate arrivals) run against the live
forest and assert the four named invariants (`UniqueGatewayOwner`, `SessionAlwaysRebindable`,
`PlannedIsLossless`, `NoWriteAfterStaleFailover`); and `phase_29_gateway_migration.dhall` spins the forest up,
runs both branches, asserts RPO=0 for `Planned` **via the out-of-forest write-journal set-equality oracle ([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists))
under a workload carrying ≥ 8 acked-but-un-replicated IDs at the cut** and measured loss ≤ the
**Phase-0-committed, hash-pinned numeric budget** for `Failover`, tears down leak-free **as read by the
OS-boundary route53/`pulumi stack ls` observer (retained `no-provisioner` PVs exempt)**, turns the committed
seeded mutants red, and emits a machine-derived proven/tested/assumed ledger validated against the raw journal.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md`,
`documents/engineering/chaos_failover_doctrine.md`, `documents/engineering/testing_doctrine.md`.

### Objective
Adopt [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)/[`§7`](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership):
because correspondence holds by construction (one `Model` → `interpret` + `emitTLA`), run the deferred
Register-3 residue — the [Inject move (§11)](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
against the running forest confirming the abstracted physics actually hold — as the test-`.dhall` of
[`testing_doctrine.md §3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down),
ledgered per [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
and [`§19`](../documents/engineering/chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows).

### Deliverables
- The Register-3 Inject drill set run in the inter-cluster dimension against the running forest, asserting the
  Phase-3 named invariants — the concrete confirmation that the built runtime, which *is* the model's
  `interpret`, upholds under real physics what the model proves in logical time (never a re-authored TLA+ spec,
  never a paper variable→module table).
- `test/dhall/phase_29_gateway_migration.dhall`: spin two children up, geo-replicate, run a `Planned` handover
  asserting RPO=0 via the write-journal oracle, kill the lead to force `Failover` asserting rebind within the
  Phase-0-committed numeric budget (`lagBound = 5 s`, `RTO = 60 s`, hash-pinned), reconcile divergent
  histories, and always tear down leak-free (verified by the OS-boundary route53/`pulumi stack ls` observer) —
  emitting the machine-derived per-run ledger artifact. **Committed in Phase 0 before the runtime exists**, along
  with `test/inject/journal/` (the out-of-forest write-ID journal), `test/inject/mutants/` (the
  `verify-caught-up`-stub and `promote-before-fence` seeded mutants that must go red), and the committed ledger
  validator.
- A machine-derived per-run proven/tested/assumed ledger that marks `Planned` RPO=0 **argued-design-level +
  drilled (tested)**, the `Failover` recovery time + reconciliation **tested (drilled)**, the data-loss /
  replication-lag bound **assumed (monitored, never proven)**, and the modeled safety/liveness
  **proven-for-the-model at scope 2** (Phase-3, a design-layer result) — and never reports an
  assumed-and-monitored result as proven.

### Validation
1. The built decision core resolves to the Phase-3 `interpret` — the correspondence-check mechanic is fixed as:
   the step-by-step trace-validation of Sprint 29.3 (Register 2.5) **plus** a Register-3 **modeled-action-coverage
   assertion** that every modeled action fired ≥ 1 time across the drill set (no orphaned modeled action); live
   trace-validation is the Sprint-29.3 obligation and is not re-run in Register 3. The Inject drills run against
   the live forest and pass, each asserting the four named safety invariants (`NoWriteAfterStaleFailover` is the
   safety half; the recovery-time half is the separate *tested* RTO datapoint). `phase_29_gateway_migration.dhall`
   reports **RPO=0 for `Planned` proven by the write-journal set-equality oracle ([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists)) under a workload with ≥ 8
   acked-but-un-replicated IDs at the cut** — not a bare "loss = 0" — and **measured loss ≤ the Phase-0-committed
   `lagBound` and transfer ≤ the committed `RTO`** (hash pinned before the drill; declared-vs-measured reported
   for both). Teardown is **leak-free by the OS-boundary observer of [§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists)**: the route53 API and `pulumi stack ls`,
   read outside the forest, report zero surviving migration DNS records and zero surviving child stacks, with the
   retained `no-provisioner` PVs of Sprint 29.2 explicitly exempt. The committed seeded mutants ([§N](#n-gate-integrity-oracles-committed-in-phase-0-before-the-runtime-exists):
   `verify-caught-up`-stub and `promote-before-fence`) each go red. The ledger is **machine-derived from the run
   record** and passes its committed validator — every ledger figure (RPO/RTO, observed max lag, raw journal
   counts, seeds, timestamps, teardown-observer result) cross-checks against the raw journal, and any mismatch or
   hand-edited field fails the gate; out-of-Register-3 layers stay marked UNVERIFIED.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/gateway_migration_model_doctrine.md` — flip §6's Register-3 chaos-injection residue to
  *run against a live forest* for both branches, recording that correspondence held by construction (the built
  runtime is `interpret`) and that no variable→module table was needed; keep the abstracted premises assumed.
- `documents/engineering/gateway_migration_doctrine.md` — backlink §2/§3/§4/§5 to the built
  `src/Amoebius/Multicluster/*` runtime; confirm `Planned` RPO=0 stayed argued-design-level (now drilled) and
  `Failover` stayed bounded-by-budget.
- `documents/engineering/chaos_failover_doctrine.md` — the §19 cross-boundary ledger and the §15/§19 conformance
  rows gain an amoebius-tested linux-cpu datapoint (recovery-time drilled, data-loss assumed), so the matrix
  stops resting on prodbox sibling-evidence alone; cross-reference the realized `Multicluster/*` module paths.
- `documents/engineering/cluster_lifecycle_doctrine.md` — §5/§6/§9 gain the realized module paths for the
  teardown-vs-chaos distinction, the push-back, and the reconciler/registry.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the Register-2.5 io-sim + trace-validation
  of the gateway-migration runtime.
- `documents/engineering/pulumi_iac_doctrine.md` — record the route53 failover repoint and the WireGuard hub-role
  move as realized DNS/hub failover owners.
- `documents/engineering/testing_doctrine.md` — record the Register-3 Inject + live-gate ledger this phase emits.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-29 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — register the `src/Amoebius/Multicluster/GatewayMigration.hs`,
  `PlannedHandover.hs`, `PromotionGate.hs`, `DnsRepoint.hs`, `ClientRebind.hs`, `Teardown.hs`, `Pushback.hs`
  modules and the Register-2.5 simulation + Register-3 Inject + gate suites as Phase-29 rows.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-29 → linux-cpu row in the per-phase substrate map.

## Related Documents
- [README.md](README.md) — the live tracker; Phase 29 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [system_components.md](system_components.md) — target component inventory (the `Multicluster/*` module paths)
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one obligation, both branches, correspondence-by-construction, and the Register-3 chaos residue this phase discharges
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 io-sim + trace-validation (Sprint 29.3) that pulls the runtime-fidelity obligation forward from Register-3-only chaos
- [Gateway Migration Doctrine](../documents/engineering/gateway_migration_doctrine.md) — the `GatewayMigration = <Planned | Failover>` taxonomy, client rebind, and the typed edge-observed state machine
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the Inject move, the R7/R8/R9 cross-boundary rules, and the proven/tested/assumed cross-boundary ledger
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — teardown-vs-chaos and push-back
- [phase_03](phase_03_gateway_migration_model.md) — the `GatewayMigration` design-model whose Register-3 correspondence against the built forest is discharged here
- [phase_28](phase_28_multicluster_spawn_georepl.md) — the prior phase; the geo-replicated forest and confluence classifier this phase runs over
- [phase_30](phase_30_provider_clusters.md) — the next phase; the forest extended to provider-managed clusters
