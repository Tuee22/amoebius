# Phase 3: Gateway-migration model (both branches)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_29_multicluster_gateway_migration.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Author amoebius's one formal proof obligation — the cross-cluster gateway migration, both the
> `Planned` and `Failover` branches — as a single reifiable `Model`, and discharge it in-process by rendering
> it with `emitTLA`, proving it with TLC, agreeing with io-sim, and reducing it to every `InForceSpec` by a
> decode-time structural-fit fold.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 2 gate (the
`Model`/`interpret`/`emitTLA` kernel) passes and runs on **no substrate** (`none`) — it stands up no host and
no cluster. The `Model`→{`interpret`, `emitTLA`} mechanism was confirmed end to end in a throwaway sibling
spike ([`formal_model_doctrine.md §7`](../documents/engineering/formal_model_doctrine.md)); that is sibling
evidence the mechanism works, not a built amoebius result.

## Phase Summary

This phase writes the *one* protocol amoebius proves about itself and checks it every way the design band
allows, before a single real resource exists. Amoebius delegates almost every consensus problem to a system
that already discharges it — intra-cluster replicated state to MinIO / Pulsar-BookKeeper / Percona-Patroni,
and single-instance of the control-plane singleton to k8s/etcd (the singleton is a Deployment `replicas=1`
with **no bespoke election**, [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)).
The single residue that no delegated system can cover — because it spans clusters — is the **asynchronous
cross-cluster gateway migration**: moving the wild-ingress gateway between clusters and repointing DNS across
geo-replication lag without stranding a live session or admitting two owners. There is **no** First-Axis /
singleton-election obligation; this is the only boundary amoebius model-checks.

Both branches are in scope. The `Planned` coordinated handover (target RPO = 0) and the `Failover`
availability-first emergency takeover (bounded rebind, named-and-capped divergence) are authored as **one**
reifiable Haskell `Model` value — state variables, the guarded `Planned` and `Failover` transitions, and the
four named invariants — from which the Phase-2 `interpret` (the runtime decision core) and `emitTLA` (the
generated, never-committed `.tla`/`.cfg`) are total renderings, so the model↔code correspondence holds by
construction rather than by a hand-maintained table. TLC proves it, io-sim agrees over the same value, and a
decode-time structural-fit fold reduces every accepted spec to the proven scope-2 envelope — TLC is never on
the spec-decode path.

**Substrate:** `none` — no host, no cluster. The gate is an in-process check battery (TLC + io-sim +
explorer), analogous to the Phase-0 documentation lint and the Phase-2 kernel round-trip.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `emitTLA` renders the concrete `GatewayMigration` `Model` to a generated, never-committed
`.tla`/`.cfg` on which TLC reaches every named **safety** invariant — `UniqueGatewayOwner`,
`SessionAlwaysRebindable`, `PlannedIsLossless`, `NoWriteAfterStaleFailover` — with no counterexample **and**
proves the **liveness** `PROPERTY`s `MergeConverges` / `SessionEventuallyRebinds` under the declared weak
fairness, at bounded scope for **both** the `Planned` and `Failover` branches, the run passing its vacuity
check (no invariant trivially satisfied, no action dead), its **fairness-sensitivity** check (each liveness
`PROPERTY` goes red with fairness removed), and its scope-2 pairwise cutoff check (the decode-time
structural-fit fold's *accepts ⟺ in-envelope* equivalence holds under QuickCheck, with a shared-resource-modeled
over-scope stress run and the decomposition lemma recorded as an open obligation); the in-process io-sim /
reachability explorer over the same `Model`'s `interpret` agrees on the **safety** predicates (liveness is
TLC-only); and both a **safety** mutation (a transition that drops the fence or decommissions before
`drain-complete`, red in all instruments) and a **liveness** mutation (a stall that never reconverges, red only
in TLC's `PROPERTY`) are caught. Register 1, in-process, substrate `none`.

## Doctrine adopted

- [`gateway_migration_model_doctrine.md §1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation)
  — *the one obligation*: the cross-cluster gateway migration is the single place a per-system proof
  concentrates on amoebius itself; every intra-cluster consensus and the singleton's single-instance are
  delegated and **not** re-proven, and there is no singleton-election model.
- [`gateway_migration_model_doctrine.md §2` and §3](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model)
  — *the two branches* and *the `Model`*: `GatewayMigration = <Planned | Failover>` is one reifiable value
  whose state variables, guarded transitions, and four named invariants (`UniqueGatewayOwner`,
  `SessionAlwaysRebindable`, `PlannedIsLossless`, `FailoverBounded`) this phase authors in full.
- [`gateway_migration_model_doctrine.md §4`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove)
  — *simulate and prove*: both instruments read the same `Model` — io-sim's `IOSimPOR` scheduler over the
  lifted decision core, and TLC over the `emitTLA`-rendered spec — and a validated model is green in both and
  red in both under a seeded fault.
- [`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  — *one-and-done, plus a per-`InForceSpec` structural fit*: the protocol is proven once at design time; what
  runs per-spec is a total decode-time structural-fit fold whose pairwise / independent / acyclic envelope
  makes scope 2 a genuine cutoff, with §6 (*modelling bounds and honesty*) supplying the one over-scope stress
  run.
- [`formal_model_doctrine.md §4 — correspondence by construction`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction)
  and [`§6 — what a green model-check proves`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not):
  because `interpret` and `emitTLA` render one value, there is no variable→module table to maintain; a green
  TLC run is *proven-for-the-model at the bound*, generalized only by the stated §5 cutoff.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md) and
  [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
  the emitted `.tla`/`.cfg` are build artifacts, **never committed**, and every check here is Register 1,
  in-process, needing no cluster.

## Sprints

## Sprint 3.1: Author the `GatewayMigration` `Model` — both branches 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/GatewayMigration.hs` (the concrete `Model` value + its four named
invariants), atop the Phase-2 `src/Amoebius/Formal/{Model,Interpret,EmitTLA,Explore}.hs` kernel — target
paths, not yet built.
**Blocked by**: Phase 2 gate (the `Model`/`interpret`/`emitTLA` kernel and the in-process explorer).
**Independent Validation**: the value typechecks against the Phase-2 `Model` EDSL and the reachability explorer
enumerates a non-empty, constraint-bounded state space that visits **both** a `Planned` and a `Failover`
transition; no invariant references an undeclared variable.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md` (Phase-3 status backlink),
`DEVELOPMENT_PLAN/system_components.md` (the single formal `GatewayMigration` `Model` row).

### Objective
Adopt [`gateway_migration_model_doctrine.md §1–§3`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model):
express the migration as one reifiable value — state variables (per-cluster replication offset/log, gateway
owner, DNS record, migration phase, active branch), the ordered `Planned` guarded actions
(`stand-up-replica → quiesce → drain / verify-caught-up → promote → repoint-DNS → unfreeze → drain-monitor →
decommission`) and the `Failover` guarded actions (promote-survivor → repoint-DNS → bounded-rebind), and the
four named invariants — with **no** singleton-election variable anywhere.

### Deliverables
- The `GatewayMigration` `Model` value in the Phase-2 first-order fragment, both branches expressed as guarded
  parameterized actions.
- The **safety** invariants encoded as boolean `Expr` (`modelInvariants`): `UniqueGatewayOwner`,
  `SessionAlwaysRebindable`, `PlannedIsLossless` (cutover reachable only after `verify-caught-up`),
  `NoWriteAfterStaleFailover` (capped divergence within the declared budget).
- The **liveness** properties encoded as `Temporal` under a named weak-fairness annotation (`modelFairness` +
  `modelProperties`): `MergeConverges` (`ownerCount ~> ownerCount = 1` after heal) and `SessionEventuallyRebinds`
  — the properties a safety invariant cannot express, per
  [`gateway_migration_model_doctrine.md §3`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model).
- A `modelConstraint` bounding exploration at scope 2 (two clusters, one DNS record).

### Validation
1. The value typechecks; the explorer visits both branches and enumerates a bounded, non-empty state space;
   every invariant is well-formed over the declared variables.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 3.2: `emitTLA` render + TLC exhaustive proof (both branches) 📋

**Status**: Planned
**Implementation**: `test/formal/GatewayMigrationTLC.hs` (the TLC harness) rendering to
`gen/tla/GatewayMigration.{tla,cfg}` (emitted, git-ignored, never committed) and running `tla2tools` — target
paths, not yet built.
**Blocked by**: Sprint 3.1.
**Independent Validation**: TLC reaches every named safety invariant with no counterexample at scope 2 for
**both** branches, **and** proves each liveness `PROPERTY` (`MergeConverges`, `SessionEventuallyRebinds`) under
the declared weak fairness; a vacuity check confirms each invariant is non-trivially satisfied and no action is
dead, and a **fairness-sensitivity** check confirms each liveness `PROPERTY` goes red when its fairness
annotation is removed (it was not vacuously true); the emitted `.tla`/`.cfg` are absent from version control (a
`.gitignore` entry and a committed-artifact scan confirm it).
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md` (§4 prove row →
proven-for-the-model when green), `documents/engineering/generated_artifacts_doctrine.md` (the emitted
`.tla`/`.cfg` registered as generated).

### Objective
Adopt [`gateway_migration_model_doctrine.md §4`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove)
and [`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction):
render the one `Model` to a spec via `emitTLA` — a structural walk, never a hand-written `.tla` — and
exhaustively model-check it at the bounded scope, proving both branches reach every invariant.

### Deliverables
- The TLC harness invoking `emitTLA` → git-ignored `gen/tla/GatewayMigration.{tla,cfg}` → `tla2tools`, run
  over both the `Planned` and `Failover` branch scenarios, checking the `INVARIANT`s (safety) and the
  `PROPERTY`s (liveness, under the emitted `WF_`/`SF_` fairness).
- A vacuity assertion (invariants are not trivially true; every declared action is enabled on some reachable
  state), a **fairness-sensitivity** assertion (each liveness `PROPERTY` fails with fairness removed), and the
  scope-bound `CONSTRAINT` carried through from the `Model`.
- A committed-artifact scan proving no `.tla`/`.cfg` is versioned.

### Validation
1. TLC is green — every safety invariant and every liveness `PROPERTY`, both branches, no counterexample at
   scope 2 — with the vacuity and fairness-sensitivity checks passing and no committed emitted spec.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 3.3: io-sim agreement + seeded-mutation catch 📋

**Status**: Planned
**Implementation**: `test/formal/GatewayMigrationIOSim.hs` (the `IOSimPOR` harness over the lifted `interpret`)
and a seeded-mutation variant of the `Model` used by both the TLC and io-sim suites — target paths, not yet
built.
**Blocked by**: Sprint 3.1, Sprint 3.2.
**Independent Validation**: `IOSimPOR` and the in-process reachability explorer, both reading the *same*
`Model`'s `interpret`, assert the same safety predicates the TLC invariants name and find no violation on the
correct model; the seeded mutation (drop the fence / decommission before `drain-complete`) goes **red** in
both TLC and io-sim.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md` (§4 simulate row →
tested-for-design), `documents/engineering/conformance_harness_doctrine.md` (the Register-1 explorer + io-sim
ledger variant).

### Objective
Adopt [`gateway_migration_model_doctrine.md §4`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove)
and [`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction):
drive the lifted pure decision core against `io-classes`/`IOSimPOR`'s deterministic, partial-order-reduced
scheduler over adversarial interleavings, and demonstrate that both readings of the one value agree — and share
sensitivity to one seeded fault — the operational form of correspondence-by-construction.

### Deliverables
- The `IOSimPOR` harness asserting the TLC-mirrored **safety** predicates on explored schedules for both
  branches, labeled **TESTED (sampled schedules)** — io-sim and the explorer cover safety only; liveness is a
  TLC-only verdict ([`formal_model_doctrine.md §3`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings)).
- Two seeded-mutation `Model` variants: a **safety** mutant (drop the fence / decommission before
  `drain-complete`) reaching the illegal state — red in TLC, io-sim, and the explorer — and a **liveness**
  mutant (a stall/livelock that reaches no illegal state but never reconverges) — red only in TLC's `PROPERTY`,
  demonstrating the liveness check catches faults safety and the safety instruments miss.
- An assertion that the correct model is green in all instruments; the safety mutant is red in all three; the
  liveness mutant is red in TLC and (correctly) not flagged by the safety-only instruments.

### Validation
1. io-sim finds no safety violation on the correct model; the safety mutant is red in TLC + io-sim + explorer;
   the liveness mutant is red in TLC's `PROPERTY` (and not spuriously flagged by the safety instruments).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 3.4: Scope-2 pairwise cutoff + decode-time structural-fit fold 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/StructuralFit.hs` (the total decode-time fold over an
`InForceSpec` migration graph) and `test/formal/CutoffSpec.hs` (the envelope corpus + the over-scope stress
run) — target paths, not yet built.
**Blocked by**: Sprint 3.2.
**Independent Validation**: a QuickCheck generator over random migration graphs shows the fold **accepts ⟺**
the graph is pairwise (one active + one standby per DNS record), independent, and acyclic (equivalence, not just
soundness), and the fold is total; **no** per-spec model-check runs; and at least one over-scope TLC run
(3 clusters, chained) that **models the shared resources in** (a survivor reused across records, one route53
zone, one Vault) stresses the cutoff's shared-resource-independence assumption and finds no counterexample.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md` (§5/§6 — the cutoff and the
over-scope stress row), `documents/engineering/formal_model_doctrine.md` (§6 backlink — what scope 2 proves
here).

### Objective
Adopt [`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
and [`formal_model_doctrine.md §6`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not):
buy the scope-2 cutoff with the DSL shape — the decoder's pairwise / independence / acyclicity guarantee
reduces an N-cluster forest to a set of independent 2-cluster instances — and enforce it per-spec with a fast
total fold, never a per-`InForceSpec` TLC.

### Deliverables
- The structural-fit fold rejecting any spec whose migration graph falls outside the proven envelope, tagged
  with the illegal-state entry it forecloses.
- A QuickCheck property over random migration graphs asserting **accepts ⟺ pairwise ∧ independent ∧ acyclic**
  (equivalence), plus a corpus of in-envelope (accepted) and out-of-envelope (rejected: multi-active, cyclic,
  shared-DNS) fixtures.
- One over-scope (3-cluster, chained) TLC run that **models the shared resources in**, recorded as the §6
  stress check, with the abstracted premises (real-time / clock-skew; the MinIO/Pulsar/Patroni lossless
  delegation; shared-resource independence) named as assumptions.
- The **decomposition lemma** recorded as a named, still-open obligation — that the N-instance product refines
  the 2-instance model under the fold's independence predicate — to be discharged by a machine-checked proof
  (TLAPS/Lean) or a shared-resource-modeled scope-3–4 run; until then the cutoff is logged **argued/tested**,
  never *proven* ([`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)).

### Validation
1. The fold's **accepts ⟺ in-envelope** equivalence holds under QuickCheck and the fold is total; the
   shared-resource-modeled over-scope run confirms the cutoff assumption; the decomposition lemma is recorded as
   an open obligation and the cutoff is labelled argued/tested; TLC is never invoked on the per-spec decode path.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/gateway_migration_model_doctrine.md` — flip the §4 Model/Simulate rows to
  **proven-for-the-model** (TLC) / **tested-for-design** (io-sim) at green, for both branches; keep the §6
  Register-3 chaos injection against a running forest deferred to the multi-cluster phase.
- `documents/engineering/formal_model_doctrine.md` — record the concrete `GatewayMigration` `Model` as
  authored and validated, and correspondence-by-construction discharged for this one model.
- `documents/engineering/generated_artifacts_doctrine.md` — register the emitted `GatewayMigration.{tla,cfg}`
  as generated, never committed.
- `documents/engineering/chaos_failover_doctrine.md` — the Model → proven-for-the-model, Simulate →
  tested-for-design; Inject stays a Register-3 residue.
- `documents/engineering/conformance_harness_doctrine.md` — the Register-1 explorer + io-sim ledger this gate
  emits (no cluster).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase 3 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-3 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Formal/GatewayMigration.hs`, the
  `test/formal/*` TLC + io-sim harnesses, and `src/Amoebius/Multicluster/StructuralFit.hs` as one
  `GatewayMigration` `Model` row; retire any stale separate `CrossClusterFailover`/`SingletonElection` spec
  rows (there is one obligation, both branches, and no election model).
- `DEVELOPMENT_PLAN/phase_29_multicluster_gateway_migration.md` — backlink: this design-model is the artifact
  whose Register-3 correspondence against the built `Multicluster/*` forest is discharged there, never here.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *proven for the model*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one
  obligation, both branches, the `Model`, the cutoff, and the per-`InForceSpec` structural fit
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the one `Model` →
  {`interpret`, `emitTLA`} pattern and correspondence-by-construction
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the Extract→Model→Inject
  methodology and the proven/tested/assumed ledger
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the Register-1
  in-process explorer + io-sim, no cluster
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the emitted
  `.tla`/`.cfg` are never committed
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — the singleton is a Deployment `replicas=1`, single-instance delegated to k8s/etcd, no election
