# Phase 3: Gateway-migration model (both branches)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_33_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md
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
spike ([`formal_model_doctrine.md §7`](../documents/engineering/formal_model_doctrine.md#7-prototype-validation)); that is sibling
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
five named invariants — from which the Phase-2 `interpret` (the runtime decision core) and `emitTLA` (the
generated, never-committed `.tla`/`.cfg`) are total renderings, so the model↔code correspondence holds by
construction rather than by a hand-maintained table. TLC proves it, io-sim agrees over the same value, and a
decode-time structural-fit fold reduces every accepted spec to the proven scope-2 envelope — TLC is never on
the spec-decode path.

**Substrate:** `none` — no host, no cluster. The gate is an in-process check battery (TLC + io-sim +
explorer), analogous to the Phase-0 documentation lint and the Phase-2 kernel round-trip.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `emitTLA` renders the concrete `GatewayMigration` `Model` to a generated, never-committed
`.tla`/`.cfg` on which TLC reaches every named **safety** invariant — `UniqueGatewayOwner`,
`SessionAlwaysRebindable`, `PlannedIsLossless`, `NoWriteAfterStaleFailover`, `NoTakeWithoutProvenFreshness` —
with no counterexample **and**
proves the **liveness** `PROPERTY`s `MergeConverges` / `SessionEventuallyRebinds` under the declared weak
fairness, at bounded scope for **both** the `Planned` and `Failover` branches, the run passing its vacuity
check — **defined** (§M.4) as the conjunction of two committed sub-checks: (a) *antecedent-reachability* —
every implication-form invariant has its antecedent reached on some enumerated state (a data-aware
`PlannedIsLossless` whose promoted-log clause is exercised, an over-budget path that reaches
`NoWriteAfterStaleFailover`'s guard, a cold-seed path that reaches `NoTakeWithoutProvenFreshness`'s
`FreshnessWitness` guard), and (b) *no dead action* — every declared action, **including the
environment actions `client-write`, `replication-tick`, `active-crash`, and `cold-seed`** authored in
Sprint 3.1, is
enabled on some reachable state; an invariant whose antecedent is unreachable or whose falsifying mutant (below)
does not exist fails vacuity — its **fairness-sensitivity** check (each liveness `PROPERTY` goes red with
fairness removed), and its scope-2 pairwise cutoff check (the decode-time structural-fit fold's
*accepts ⟺ pairwise ∧ independent ∧ acyclic ∧ in-parameter-envelope* equivalence — the parameter-envelope
conjunct co-equal with the graph-shape conjuncts (each edge's `Failover` data-loss budget ≤ the proven cap, its
`dnsRecord` TTL within the modelled TTL regime, every `ColdSeedFromBackup` edge's `freshnessBound` within the
modelled freshness regime, its clusters' offset/log domains within the model `CONSTANTS`), per doctrine §5 —
holds under QuickCheck against an **independently-authored reference predicate** (§M.3) that shares no code with
`StructuralFit.hs` and decides **both** axes, with committed `cover`/`checkCoverage` thresholds (§M.4) firing
each graph violation class, each parameter-out-of-envelope class (over-budget / TTL-out-of-regime /
freshnessBound-out-of-regime / offset-domain-over-`CONSTANTS`), and each over-scope-2 shape at a stated minimum
rate, **all eight clause-delete fold-mutants (four graph + four parameter-envelope) going red** (§M.2), a
shared-resource-modeled over-scope stress run **whose shared-resource actions are non-dead and whose committed
seeded shared-resource mutant goes red**, and the decomposition lemma recorded as an open obligation); the
in-process io-sim / reachability explorer over the same `Model`'s `interpret` agrees on the **safety**
predicates (liveness is TLC-only), io-sim exploring schedules **exhaustively within a committed IOSimPOR
depth/interleaving bound recorded in the harness and ledger** (not N random seeds), labeled
**TESTED (bounded-exhaustive schedules)**; and **every** mutant of a mechanical mutation-operator set over the
fragment (guard negation/weakening, effect swap, dropped effect entry/`UNCHANGED`, quantifier flip, fairness
drop, invariant-clause delete) is caught, **including a committed per-invariant mutant catalogue (§M.2) that
names, for each of the five safety invariants, at least one seeded mutant violating exactly that invariant and
red in all safety instruments — specifically a `verify-caught-up`-passes-while-offsets-lag mutant caught by the
data-aware `PlannedIsLossless`, an over-budget-divergence mutant caught by `NoWriteAfterStaleFailover`, and a
take-without-witness mutant caught by `NoTakeWithoutProvenFreshness`** —
each safety mutant (a transition that drops the fence or decommissions before `drain-complete`) red in all
instruments, each fairness-drop/liveness mutant (a stall that never reconverges) red only in TLC's `PROPERTY` —
so a single surviving mutant, or any safety invariant with no committed falsifying mutant, fails the gate.
**Oracle-pinning (§M.1):** the oracles this gate checks against — the `emitTLA GatewayMigration` byte-for-byte
`.tla`/`.cfg` golden (a committed test fixture under `test/formal/golden/`, distinct from the never-committed
emitted `gen/tla/` output), the hand-derived expected reachable-distinct-state fingerprint set the explorer/TLC run
is compared to, and the per-invariant expected-outcome catalogue (which invariant each seeded mutant must
violate) — are **authored and committed in Phase 0 before `interpret`/`emitTLA` exist**, exactly as
[`phase_02`](phase_02_formal_model_kernel.md#phase-summary) §M.1
pins the `ToyModel` oracles; a golden regenerated from `emitTLA`'s own output is not a test.
Register 1, in-process, substrate `none`.

## Doctrine adopted

- [`gateway_migration_model_doctrine.md §1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation)
  — *the one obligation*: the cross-cluster gateway migration is the single place a per-system proof
  concentrates on amoebius itself; every intra-cluster consensus and the singleton's single-instance are
  delegated and **not** re-proven, and there is no singleton-election model.
- [`gateway_migration_model_doctrine.md §2` and §3](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model)
  — *the two branches* and *the `Model`*: `GatewayMigration = <Planned | Failover>` is one reifiable value
  whose state variables, guarded transitions, and five named invariants (`UniqueGatewayOwner`,
  `SessionAlwaysRebindable`, `PlannedIsLossless`, `NoWriteAfterStaleFailover`, `NoTakeWithoutProvenFreshness`)
  this phase authors in full.
- [`backup_recovery_doctrine.md §8`](../documents/engineering/backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability)
  — *the gateway dovetail — seed from backup under consistency-over-availability*: the fifth invariant
  `NoTakeWithoutProvenFreshness` generalizes the `Planned` `verify-caught-up` precondition into a
  `FreshnessWitness` guard on the promote / gateway-take transition that a cold backup-seeded standby also
  discharges within its declared `freshnessBound`.
- [`gateway_migration_model_doctrine.md §4`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove)
  — *simulate and prove*: both instruments read the same `Model` — io-sim's `IOSimPOR` scheduler over the
  lifted decision core, and TLC over the `emitTLA`-rendered spec — and a validated model is green in both and
  red in both under a seeded fault.
- [`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  — *one-and-done, plus a per-`InForceSpec` structural fit*: the protocol is proven once at design time; what
  runs per-spec is a total decode-time structural-fit fold whose **graph** envelope (pairwise / independent /
  acyclic) **and co-equal parameter envelope** (data-loss budget ≤ proven cap, `dnsRecord` TTL in the modelled
  regime, `ColdSeedFromBackup` `freshnessBound` in the modelled freshness regime, offset/log domains within the
  model `CONSTANTS`) together make scope 2 a genuine cutoff, with §6 (*modelling bounds and honesty*) supplying
  the one over-scope stress run.
- [`formal_model_doctrine.md §4 — correspondence by construction`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction)
  and [`§6 — what a green model-check proves`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not):
  because `interpret` and `emitTLA` render one value, there is no variable→module table to maintain; a green
  TLC run is *proven-for-the-model at the bound*, generalized only by the stated §5 cutoff.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) and
  [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
  the emitted `.tla`/`.cfg` are build artifacts, **never committed**, and every check here is Register 1,
  in-process, needing no cluster.

## Sprints

## Sprint 3.1: Author the `GatewayMigration` `Model` — both branches 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/GatewayMigration.hs` (the concrete `Model` value + its five named
invariants), atop the Phase-2 `src/Amoebius/Formal/{Model,Interpret,EmitTLA,Explore}.hs` kernel — target
paths, not yet built.
**Blocked by**: Phase 2 gate (the `Model`/`interpret`/`emitTLA` kernel and the in-process explorer).
**Independent Validation**: the value typechecks against the Phase-2 `Model` EDSL and the reachability explorer
enumerates a non-empty, constraint-bounded state space that visits **both** a `Planned` and a `Failover`
transition; the explorer confirms the environment actions (`client-write`, `replication-tick`, `active-crash`,
`cold-seed`) each fire on some reachable state — so the replication-offset/log variables carry live dynamics
and are not inert — and confirms a reachable state where `PlannedIsLossless`'s promoted-log clause, one where
`NoWriteAfterStaleFailover`'s divergence budget, and one where `NoTakeWithoutProvenFreshness`'s
`FreshnessWitness` guard are each materially exercised (non-vacuous antecedents); no
invariant references an undeclared variable.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md` (Phase-3 status backlink),
`documents/engineering/backup_recovery_doctrine.md` (§8 — the `FreshnessWitness` /
`NoTakeWithoutProvenFreshness` proof at model scope),
`DEVELOPMENT_PLAN/system_components.md` (the single formal `GatewayMigration` `Model` row).

### Objective
Adopt [`gateway_migration_model_doctrine.md §1–§3`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model):
express the migration as one reifiable value — state variables (per-cluster replication offset/log, gateway
owner, DNS record, migration phase, active branch), the ordered `Planned` guarded actions
(`stand-up-replica → quiesce → drain / verify-caught-up → promote → repoint-DNS → unfreeze → drain-monitor →
decommission`) and the `Failover` guarded actions (promote-survivor → repoint-DNS → bounded-rebind), and the
five named invariants — the fifth, `NoTakeWithoutProvenFreshness`, generalizes the `Planned` `verify-caught-up`
precondition into a `FreshnessWitness` guard on the promote / gateway-take transition that a cold secondary
seeded from backup within its `freshnessBound` also discharges
([`gateway_migration_model_doctrine.md §3`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model),
[`backup_recovery_doctrine.md §8`](../documents/engineering/backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability))
— with **no** singleton-election variable anywhere.

### Deliverables
- The `GatewayMigration` `Model` value in the Phase-2 first-order fragment, both branches expressed as guarded
  parameterized actions, **plus the environment actions `client-write` (accrues a committed write on the active
  owner's log), `replication-tick` (advances a standby's replication offset toward the active's), and
  `active-crash` (the fault that triggers `Failover`)** — so the replication offset/log variables are driven by
  live transitions and neither `PlannedIsLossless` nor `NoWriteAfterStaleFailover` can hold vacuously; all
  actions (control-plane and environment) enter the no-dead-action vacuity check.
- The **safety** invariants encoded as boolean `Expr` (`modelInvariants`): `UniqueGatewayOwner`,
  `SessionAlwaysRebindable`, `PlannedIsLossless` — **data-aware**: the promoted log contains every write
  committed before cutover (cutover reachable only after `verify-caught-up` **and** the promoted offset covers
  every committed write), so a `verify-caught-up`-passes-while-offsets-lag transition violates it —
  `NoWriteAfterStaleFailover` (accrued divergence stays within the declared budget; an over-budget write
  violates it) — and `NoTakeWithoutProvenFreshness` (no cluster takes the wild-ingress role from a data plane
  whose freshness is unproven): the promote / gateway-take action is guarded by a `FreshnessWitness`
  dischargeable by a warm caught-up replica **or** a cold backup-seeded standby proven within `freshnessBound`,
  and a `cold-seed` environment action (populates a standby's log from a backup watermark, never past the
  active's committed offset) drives the seed dynamics so the invariant cannot hold vacuously; a take-without-
  witness transition violates it.
- The **liveness** properties encoded as `Temporal` under a named weak-fairness annotation (`modelFairness` +
  `modelProperties`): `MergeConverges` (`ownerCount ~> ownerCount = 1` after heal) and `SessionEventuallyRebinds`
  — the properties a safety invariant cannot express, per
  [`gateway_migration_model_doctrine.md §3`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model).
- A `modelConstraint` bounding exploration at scope 2 (two clusters, one DNS record).

### Validation
1. The value typechecks; the explorer visits both branches and enumerates a bounded, non-empty state space;
   every invariant is well-formed over the declared variables; the environment actions (including `cold-seed`)
   each fire and the `PlannedIsLossless` promoted-log clause, the `NoWriteAfterStaleFailover` divergence budget,
   and the `NoTakeWithoutProvenFreshness` `FreshnessWitness` guard are each materially
   exercised on some reachable state (no inert data variable).

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
the declared weak fairness; a vacuity check — **defined** as (a) *antecedent-reachability*: every implication-form
invariant has its antecedent reached on some enumerated state (in particular the data-aware `PlannedIsLossless`
promoted-log clause, the `NoWriteAfterStaleFailover` over-budget path, and the `NoTakeWithoutProvenFreshness`
cold-seed / `FreshnessWitness` antecedent are each reachable), and (b) *no dead
action*: every declared action **including the environment actions `client-write`, `replication-tick`,
`active-crash`, `cold-seed`** is enabled on some reachable state — confirms each invariant is non-trivially
satisfied and no action is dead, and a **fairness-sensitivity** check confirms each liveness `PROPERTY` goes red
when its fairness annotation is removed (it was not vacuously true); the emitted `.tla`/`.cfg` under `gen/tla/`
are absent from version control (a `.gitignore` entry and a committed-artifact scan of `gen/` confirm it).
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
- A vacuity assertion — (a) antecedent-reachability of every implication-form invariant (the `PlannedIsLossless`
  promoted-log clause, the `NoWriteAfterStaleFailover` over-budget path, and the `NoTakeWithoutProvenFreshness`
  cold-seed antecedent each reached) and (b) no dead action
  across control-plane **and** environment actions (`client-write`, `replication-tick`, `active-crash`,
  `cold-seed`) — a
  **fairness-sensitivity** assertion (each liveness `PROPERTY` fails with fairness removed), and the
  scope-bound `CONSTRAINT` carried through from the `Model` on the **safety** runs only — the **liveness**
  `PROPERTY` runs instead finitize the model via `CONSTANTS` and finite, saturating variable domains and run
  **`CONSTRAINT`-free**, since a state `CONSTRAINT` truncates the behaviour graph and distorts `WF`/`SF`
  enabledness, admitting a spurious green liveness within the bound
  ([`formal_model_doctrine.md §6`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)).
- A committed-artifact scan proving no emitted `.tla`/`.cfg` under `gen/` is versioned (the committed Phase-0
  golden fixture under `test/formal/golden/` is exempt).

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
correct model — `IOSimPOR` exploring schedules **exhaustively within a committed depth/interleaving bound
recorded in the harness and ledger** (bounded-exhaustive, not N random seeds); **every** mutant of a mechanical
mutation-operator set over the fragment is caught, **including the committed per-invariant mutant catalogue**:
for each of the five safety invariants at least one seeded mutant that violates exactly that invariant and is
red in TLC, io-sim, and the explorer — notably a `verify-caught-up`-passes-while-offsets-lag mutant caught by
the data-aware `PlannedIsLossless`, an over-budget-divergence mutant caught by `NoWriteAfterStaleFailover`, and
a take-without-witness mutant caught by `NoTakeWithoutProvenFreshness`,
so no safety invariant can be inert; each generic safety mutant (drop the fence / decommission before
`drain-complete`) red in TLC, io-sim, and the explorer, each fairness-drop/liveness mutant red only in TLC's
`PROPERTY`.
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
- The `IOSimPOR` harness asserting the TLC-mirrored **safety** predicates on schedules explored
  **bounded-exhaustively within a committed depth/interleaving bound named in the harness and ledger** (not N
  random seeds) for both branches, labeled **TESTED (bounded-exhaustive schedules)** — io-sim and the explorer
  cover safety only; liveness is a TLC-only verdict ([`formal_model_doctrine.md §3`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings)).
- A **mechanical mutation set** over the `GatewayMigration` fragment, not two hand-picked strawmen: the
  operator family (guard negation/weakening, effect swap, dropped effect entry/`UNCHANGED`, quantifier flip,
  fairness drop, invariant-clause delete) is applied exhaustively, and **every** generated mutant must be
  caught — each **safety** mutant (e.g. drop the fence / decommission before `drain-complete`, reaching the
  illegal state) red in TLC, io-sim, and the explorer; each **fairness-drop/liveness** mutant (e.g. a
  stall/livelock that reaches no illegal state but never reconverges) red only in TLC's `PROPERTY` — a single
  surviving mutant fails the gate, demonstrating the liveness check catches faults the safety instruments miss.
- A **committed per-invariant mutant catalogue** (§M.2), pinned before the correct `Model` is finalized: for
  **each** of the five safety invariants (`UniqueGatewayOwner`, `SessionAlwaysRebindable`, `PlannedIsLossless`,
  `NoWriteAfterStaleFailover`, `NoTakeWithoutProvenFreshness`) at least one named committed mutant that violates
  **exactly** that invariant and
  is red in TLC, io-sim, and the explorer — including the `verify-caught-up`-passes-while-offsets-lag mutant
  (must go red under the data-aware `PlannedIsLossless`), the over-budget-divergence mutant (must go red
  under `NoWriteAfterStaleFailover`), and the take-without-witness mutant (must go red under
  `NoTakeWithoutProvenFreshness`); a safety invariant with no committed falsifying mutant fails the gate, so
  no guarantee can pass vacuously.
- An assertion that the correct model is green in all instruments; each safety mutant (generic and
  per-invariant) is red in all three; the liveness mutant is red in TLC and (correctly) not flagged by the
  safety-only instruments.

### Validation
1. io-sim finds no safety violation on the correct model (schedules explored bounded-exhaustively within the
   committed IOSimPOR bound named in the ledger); **every** mutant of the mechanical mutation set **and every
   entry of the committed per-invariant mutant catalogue** is caught — each safety mutant red in TLC + io-sim +
   explorer, each fairness-drop/liveness mutant red in TLC's `PROPERTY` (and not spuriously flagged by the
   safety-only instruments); a safety invariant with no committed falsifying mutant fails the gate.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 3.4: Scope-2 pairwise cutoff + decode-time structural-fit fold 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/StructuralFit.hs` (the total decode-time fold over an
`InForceSpec` migration graph) and `test/formal/CutoffSpec.hs` (the envelope corpus + the over-scope stress
run) — target paths, not yet built.
**Blocked by**: Sprint 3.2.
**Independent Validation**: a QuickCheck generator over random migration graphs shows the fold **accepts ⟺
pairwise ∧ independent ∧ acyclic ∧ in-parameter-envelope** — *in-envelope* spanning **both** the graph-shape
axis (pairwise / independent / acyclic) **and** the co-equal **parameter-envelope** axis
([`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)):
each edge's `Failover` data-loss budget ≤ the proven cap, its `dnsRecord` TTL within the modelled TTL regime,
every `ColdSeedFromBackup` edge's `freshnessBound` within the modelled freshness regime the
`NoTakeWithoutProvenFreshness` guard was proven over, and its clusters' offset/log domains within the model's
`CONSTANTS` — the four regime bounds being the Sprint-3.1 model `CONSTANTS`, **Phase-0-pinned in the §M.1 oracle
and hard-coded in the reference predicate** (never read back from `StructuralFit.hs`) — where the whole
*in-envelope* side (graph **and** parameter) is decided by an **independently-authored naive reference predicate
living in `test/formal/CutoffSpec.hs` that shares no code with
`src/Amoebius/Multicluster/StructuralFit.hs`** (§M.3) — not the fold or its helpers — so the equivalence cannot
be a tautology; the property carries committed `cover`/`checkCoverage` thresholds (§M.4) that force each graph
violation class (**multi-active, cyclic, shared-DNS, cluster-reuse-across-records**), each
parameter-out-of-envelope class (**over-budget, TTL-out-of-regime, freshnessBound-out-of-regime,
offset-domain-over-`CONSTANTS`**), and each graph larger than
scope 2 to be generated at a stated minimum rate, so every reject and boundary branch actually fires; **each of
eight fold-mutation checks — deleting the pairwise clause, the graph-independence clause, the
resource-independence clause (cluster-reuse-across-records), or the acyclicity clause, and deleting each of the
four parameter-envelope clauses (the budget-≤-cap, TTL-in-regime, `freshnessBound`-in-regime, or
offset-domain-within-`CONSTANTS` check) from `StructuralFit.hs` — turns the equivalence property red** (§M.2),
each parameter mutant paired with the graph-identical positive it now wrongly accepts; the resource-independence mutant is distinct
because a fold implementing graph-independence alone would otherwise survive every other mutant while
admitting the shared survivor ([`illegal_state_multicluster.md §3.52`](../documents/illegal_state/illegal_state_multicluster.md#352-a-gateway-failover-graph-reusing-one-cluster-across-two-dns-records)); the fold is total, discharged by a committed
QuickCheck no-exception property forcing the fold to normal form over arbitrary (including malformed and
oversized) graphs; **no** per-spec model-check runs; and at least one over-scope TLC run (3 clusters, chained)
that **models the shared resources in** (a survivor reused across records, one route53 zone, one Vault) with
*live contention semantics* (a rate-limited zone-repoint action and a shared-commit-log/shared-survivor
interaction), whose shared-resource interaction actions are each non-dead (enabled on some reachable state) and
whose **committed seeded shared-resource mutant — the shared survivor accepting both active roles concurrently,
or the rate-limited zone dropping a repoint — the run catches red**, stresses the cutoff's
shared-resource-independence assumption and otherwise finds no counterexample.
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
  with the illegal-state entry it forecloses. **`independent` is defined** (per
  [`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit))
  as **both** graph-independence (no shared edge/cycle structure across pairs) **and resource-independence** (no
  cluster/survivor reused as active or standby across two DNS records); the fold **rejects cluster-reuse-across-
  records**, not only edge/cycle structure. Beyond graph shape the fold enforces a **co-equal parameter
  envelope** ([`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)):
  it rejects any edge whose `Failover` data-loss budget exceeds the proven cap, whose `dnsRecord` TTL falls
  outside the modelled TTL regime, whose `ColdSeedFromBackup` `freshnessBound` falls outside the modelled
  freshness regime, or whose clusters' offset/log domains fall outside the model's `CONSTANTS` — so a
  parameter-out-of-envelope spec the scope-2 proof does not cover cannot slip through on graph shape alone. The owning doctrine states the same strict reading and records the
  excluded shared-survivor topology as a deferred obligation gated on the decomposition lemma
  ([`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)).
- A QuickCheck property over random migration graphs asserting **accepts ⟺ pairwise ∧ independent ∧ acyclic ∧
  in-parameter-envelope** (equivalence) — the *in-parameter-envelope* conjunct co-equal with the graph-shape
  conjuncts per [`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  (data-loss budget ≤ proven cap; `dnsRecord` TTL in the modelled TTL regime; every `ColdSeedFromBackup` edge's
  `freshnessBound` in the modelled freshness regime; offset/log domains within the model's `CONSTANTS` — the four
  regime bounds being the Sprint-3.1 model `CONSTANTS`, Phase-0-pinned in the §M.1 oracle) — decided against an
  **independently-authored naive reference predicate** (§M.3) sharing no code with `StructuralFit.hs`, with
  committed `cover`/`checkCoverage` thresholds forcing each graph violation class
  (multi-active, cyclic, shared-DNS, **cluster-reuse-across-records**), each **parameter-out-of-envelope** class
  (**over-budget, TTL-out-of-regime, freshnessBound-out-of-regime, offset-domain-over-`CONSTANTS`**), and each
  over-scope-2 graph at a stated
  minimum rate; plus **eight** fold-mutation checks (delete pairwise / graph-independence / resource-independence
  / acyclicity clause, **and** delete the budget-≤-cap / TTL-in-regime / `freshnessBound`-in-regime /
  offset-domain-within-`CONSTANTS` clause → each of the eight turns the equivalence red, every parameter mutant
  paired with the graph-identical positive it now wrongly accepts); plus a **committed Phase-0-pinned corpus** of in-envelope (accepted) and
  out-of-envelope fixtures, each rejected fixture asserting **which** clause it violates — multi-active,
  cyclic, shared-DNS, cluster-reuse-across-records, **and one graph-valid reject per parameter dimension
  (over-budget, TTL-out-of-regime, freshnessBound-out-of-regime, offset-domain-over-`CONSTANTS`)** — each paired
  with an accepted positive differing only in that
  one dimension, the four parameter fixtures **graph-identical** to their positive so only the parameter clause
  can be the cause of the reject (§M.8); and a committed no-exception totality property forcing the fold to normal form over
  arbitrary (malformed/oversized) graphs (§M.4).
- One over-scope (3-cluster, chained) TLC run that **models the shared resources in** with live contention
  semantics (rate-limited zone-repoint, shared survivor / shared commit log), recorded as the §6 stress check,
  with its shared-resource interaction actions each non-dead and one committed seeded shared-resource mutant
  (shared survivor holding two active roles, or the rate-limited zone dropping a repoint) that the run catches
  red — proving the stress model can detect a cutoff violation, not merely fail to express one; the abstracted
  premises (real-time / clock-skew; the MinIO/Pulsar/Patroni lossless delegation; shared-resource independence)
  named as assumptions.
- The **decomposition lemma** recorded as a named, still-open obligation — that the N-instance product refines
  the 2-instance model under the fold's independence predicate — to be discharged by a machine-checked proof
  (TLAPS/Lean) or a shared-resource-modeled scope-3–4 run; until then the cutoff is logged **argued/tested**,
  never *proven* ([`gateway_migration_model_doctrine.md §5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)).

### Validation
1. The fold's **accepts ⟺ pairwise ∧ independent ∧ acyclic ∧ in-parameter-envelope** equivalence holds under
   QuickCheck against the independently-authored
   reference predicate (no code shared with `StructuralFit.hs`), with the coverage thresholds met for **both**
   the graph violation classes and the four parameter-out-of-envelope classes (over-budget, TTL-out-of-regime,
   freshnessBound-out-of-regime, offset-domain-over-`CONSTANTS`) and each of
   the **eight** fold-mutation checks (pairwise / graph-independence / resource-independence / acyclicity clause
   deleted, **and** the budget-≤-cap / TTL-in-regime / `freshnessBound`-in-regime /
   offset-domain-within-`CONSTANTS` clause deleted) turning the equivalence
   red; the committed corpus passes with each rejected fixture — including the four graph-valid parameter
   rejects, each graph-identical to its accepted positive — asserting its specific violated clause; the fold
   is total (no-exception property to normal form over arbitrary graphs); the shared-resource-modeled over-scope
   run has non-dead interaction actions and catches its committed seeded shared-resource mutant red while finding
   no counterexample on the correct model; the decomposition lemma is recorded as an open obligation and the
   cutoff is labelled argued/tested; TLC is never invoked on the per-spec decode path.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/gateway_migration_model_doctrine.md` — flip the §4 Model/Simulate rows to
  **proven-for-the-model** (TLC) / **tested-for-design** (io-sim) at green, for both branches; keep the §6
  Register-3 chaos injection against a running forest deferred to the multi-cluster phase.
- `documents/engineering/formal_model_doctrine.md` — record the concrete `GatewayMigration` `Model` as
  authored and validated, and correspondence-by-construction discharged for this one model.
- `documents/engineering/backup_recovery_doctrine.md` — the §8 gateway dovetail: at green, the
  `FreshnessWitness` / `NoTakeWithoutProvenFreshness` proof flips to proven-for-the-model at model scope.
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
- `DEVELOPMENT_PLAN/phase_32_multicluster_spawn_georepl.md` — backlink: this design-model is the artifact
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
