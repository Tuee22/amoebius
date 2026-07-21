# Phase 12: Deterministic-simulation substrate

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/deterministic_simulation_doctrine.md
**Generated sections**: none

> **Purpose**: Build the `io-classes` environment substrate and the modeled, fault-injectable
> Pulsar/MinIO/apiserver/route53/Vault/clock so the *real* daemon/reconciler code, lifted onto `io-classes`, runs
> under `IOSim`/`IOSimPOR` and replays an injected partition/redelivery/reorder/crash schedule **deterministically**
> (same seed → byte-identical trace), gated in-process with no cluster.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement is
design intent, never a tested amoebius result. This phase opens after the Phase 11 gate (the boundary fake-tool
harness) and runs on **no substrate** (`none`) in **Register 2** — the in-process register, exercised without an
apiserver, broker, cloud, or Vault. It builds and gates the substrate on which the live-band phases later run
their **Register-2.5 deterministic-simulation activity**; the 2.5 label names that *activity*, not this phase's
gate register (a `**Register:**` field is never `2.5`,
[`development_plan_standards.md §K`](development_plan_standards.md#k-honesty-proven--tested--assumed)). Where a
shape below is already exercised in a sibling system — real concurrent code lifted onto `io-classes` and replayed
under `IOSim`/`IOSimPOR` from a fixed seed — that is **sibling evidence, not an amoebius result**.

## Phase Summary

This phase delivers the deterministic-simulation substrate: the typed `Env m` effect interface (publish/consume,
put/get-blob, apply-object, write-DNS, vault-op, now/delay) polymorphic over an `io-classes` monad `m`, its two
interpreters (real clients under `m = IO`; the modeled substrates under `m = IOSim s`), and the modeled,
fault-injectable Pulsar/MinIO/apiserver/route53/Vault/clock — each carrying the typed fault model (delay,
reorder, duplicate, partition, crash) named in the simulation doctrine. The *real* daemon/reconciler code,
written once and polymorphic over `m`, runs as the production daemon under `IO` and as a deterministic model under
test under `IOSim s` **from one source**: an injected partition/redelivery/reorder/crash schedule replays
byte-for-byte under a fixed seed, so a concurrency defect surfaces as a reproducible trace rather than a flaky
run. What is *not* here: the boundary fake-tool harness (Phase 11, which this phase's Sprint 12.1 generalizes),
the real subprocess tool invocations, and the live substrates themselves. The load-bearing honesty limit is that
the modeled environment's **fidelity to the real Pulsar/apiserver/route53/Vault is ASSUMED** — a narrow, testable
premise discharged later by a Register-3 conformance check that pins each fake's contract against the real system,
never waved away.

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test sim-spec` battery replaying the
real daemon/reconciler code under `IOSim`/`IOSimPOR` against the modeled substrates from committed schedule
fixtures.

**Register:** 2 — an in-process deterministic-replay battery, no cluster (§K). This phase *builds and gates* the
substrate the live-band phases later use for their Register-2.5 activity; the phase gate itself keys to Register 2,
never 2.5 ([`development_plan_standards.md §K`](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `cabal test sim-spec` is green — the real daemon/reconciler code, lifted onto the `Env m` interface,
replays the **committed schedule-fixture corpus** (Sprint 12.3, §M-7: a Phase-0-pinned set of injected
partition/redelivery/reorder/crash schedules) under `IOSim`/`IOSimPOR` with each named per-fake fault contract
asserted (§M-7: fake MinIO returns **412** on an `If-None-Match` conflict; fake apiserver yields a
**resourceVersion conflict** and a **watch-gap**; fake route53 serves the **stale record during propagation
delay** and offers **no CAS**; fake Vault **rejects ops while sealed**; a **partitioned Pulsar** link delivers
nothing until healed, then **redelivers with dedup**; the reorder/duplicate/crash knobs each produce their stated
observable). **Determinism is asserted by same-seed → byte-identical trace replay** (cache-bypass is N/A — an
`IOSim` replay recomputes the whole program every run, it is not served from a store), **paired with a
schedule-sensitivity control (§M-6): a distinct-seed / distinct-fault-schedule run MUST produce a *different*
trace** — a same-trace result under a perturbed schedule is red (it proves the faults are ignored, so the replay
assertion is a tautology about the library). The gate names **at least one committed seeded fault-mutant (§M-2),
re-run every gate run** — a dropped-partition-handling mutant (the reconciler that fails to await partition-heal
before acting on a stale read) — that MUST change the replayed invariant outcome to red; a green run against the
mutant fails the gate. The gate emits a **Register-2 proven/tested/assumed ledger**: the invariant-under-the-
modeled-schedules-and-faults result is marked **tested against a modeled environment**, and the modeled-env
**fidelity to the real substrate is marked ASSUMED / UNVERIFIED**, discharged later by a Register-3 conformance
check ([`deterministic_simulation_doctrine.md §5`](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys)).
A green run is quoted as *"the code upholds the invariants under the modeled schedules and faults,"* never as
*"the cluster is correct."* An in-process **Register-2** check that runs on no substrate.

**Independent oracle (§M.3).** The determinism assertion (same-seed → byte-identical trace) is guarded against
tautology by the §M-6 schedule-sensitivity control, but the *invariant verdicts* are checked against a
**Phase-0-committed, hand-authored expected-outcome table** — one row per committed schedule-fixture giving the
invariant verdict (`upheld` / `violated`, and for a violation the expected failing invariant) that the
reconciler must produce under that schedule — authored **independently of the `Env m` reconciler code** and
sharing none of it, so the equivalence `replayed-verdict ⟺ expected-verdict` cannot be a re-derivation of the
subject under test. A verdict table regenerated from the reconciler's own replay is not an oracle; the seeded
fault-mutant (§M-2) must flip a row of this table from `upheld` to `violated`, proving the table has
discriminating power.

## Doctrine adopted

- [`deterministic_simulation_doctrine.md §2 — the io-classes environment abstraction`](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole)
  — **build it pure, lift it whole**: the typed effect interface polymorphic over an `io-classes` monad `m`, so
  the *real* daemon/reconciler code is written once and runs as the production daemon (`m = IO`) and as a
  deterministic model under test (`m = IOSim s`) from one source. This phase builds precisely that abstraction.
- [`deterministic_simulation_doctrine.md §3 — the simulated environment and its fault model`](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model)
  — the modeled Pulsar/MinIO/apiserver/route53/Vault/clock and the typed fault model (delay, reorder, duplicate,
  partition, crash) each substrate carries: the fault knobs this phase's per-fake fault-contract corpus asserts.
- [`deterministic_simulation_doctrine.md §4 — Register 2.5, where deterministic simulation sits`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — the register the built substrate serves for the live band; this phase's own gate keys to Register 2 per
  [`development_plan_standards.md §K`](development_plan_standards.md#k-honesty-proven--tested--assumed), which
  forbids a `**Register:**` field of `2.5` and names 2.5 an *activity*, not a phase-gate register.
- [`deterministic_simulation_doctrine.md §5 — what DST establishes, and the one premise it buys`](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys)
  — the honesty limit the ledger records: a DST green is **tested**, not proven, and the modeled-env fidelity to
  the real substrate is an **assumed** premise discharged by a later Register-3 conformance suite.
- [`conformance_harness_doctrine.md §2 — the registers, as amoebius uses them for pre-cluster validation`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  — the **Register-2.5 deterministic-simulation** entry: the real daemon/reconciler code, lifted onto
  `io-classes`, run under `IOSim`/`IOSimPOR` against a modeled, fault-injectable environment, deterministically
  replayable — the activity this substrate exists to make possible, exercising the daemon's real *schedule* under
  faults, which Registers 1 and 2 structurally cannot reach.
- [`chaos_failover_doctrine.md §10 — simulate: the pure program lifted (io-sim)`](../documents/engineering/chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)
  — the "build it pure; lift it whole" ladder the two interpreters realize: one program, two runs.

## Sprints

## Sprint 12.1: The `io-classes` `Env` effect interface + its two interpreters + `sim-spec` skeleton 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Sim/Env.hs` (the typed effect interface — publish/consume, put/get-blob,
apply-object, write-DNS, vault-op, now/delay — polymorphic over an `io-classes` monad `m`),
`src/Amoebius/Sim/Interp/{Real,Sim}.hs` (the two interpreters: real clients under `IO`; the `IOSim s` model), and
a `sim-spec` test-suite stanza in `amoebius.cabal` — target paths, not yet built.
**Blocked by**: Phase 11 gate (the boundary fake-tool harness — its single `Exec/Tool.hs` IO seam is the seam
this sprint generalizes into a typed effect interface); Phase 10 gate (the `chain :: cfg -> [Step]` plan the toy
reconcile loop consumes); Phase 1's recorded `io-sim`/`io-classes` pin under GHC 9.12.4.
**Independent Validation**: a toy reconcile loop written against the `Env` interface compiles and runs under both
`m = IO` (no-op real clients) and `m = IOSim s`, producing an observable transition trace under each. A source
gate confirms concurrency-touching code is polymorphic in `m`. The one interpretation (resolving the
"concurrency-touching" / scope ambiguity): scope is `src/Amoebius/Sim/**` plus any `src/` module importing
`Control.Concurrent`, `Control.Concurrent.*`, or an `io-classes`/`io-sim` concurrency class; within that scope the
gate is red on any bare-`IO`-typed signature or any `forkIO`/`Control.Concurrent` token that is not routed through
the `MonadFork`/`io-classes` class methods. The gate is red if that scope is **empty** (the `Env` interface plus
its two interpreters must be in it), guarding against a vacuously-green empty scope.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (Phase-12 status backlink),
`documents/engineering/testing_doctrine.md` (the Register-2.5 substrate),
`documents/engineering/chaos_failover_doctrine.md` (§10 "build it pure; lift it whole" ladder, realized by the two
interpreters), `DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`deterministic_simulation_doctrine.md §2`](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole)
and the "build it pure; lift it whole" ladder
([`chaos_failover_doctrine.md §10`](../documents/engineering/chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)):
stand up the typed `Env m` effect interface and its two interpreters so the *real* daemon/reconciler code —
written once, polymorphic over `m` — runs as the production daemon (`m = IO`) and as a deterministic model under
test (`m = IOSim s`) from one source, generalizing the Phase-11 single IO seam.

### Deliverables
- `src/Amoebius/Sim/Env.hs`: the typed `Env m` effect interface (publish/consume, put/get-blob, apply-object,
  write-DNS, vault-op, now/delay), polymorphic over an `io-classes` monad `m`, reusing the `MonadTime`/`MonadTimer`
  clock and the seed seams the determinism kernel ([phase_31](phase_31_determinism_kernel.md)) also uses — one
  determinism substrate, two uses.
- `src/Amoebius/Sim/Interp/{Real,Sim}.hs`: the two interpreters (real clients under `IO`; the `IOSim s` model).
- The `sim-spec` test-suite stanza and a toy reconcile loop exercising the interface under both interpreters.

### Validation
1. `cabal build` and the toy-loop `sim-spec` skeleton are green on the Phase-1 pin under both interpreters; the
   `m`-polymorphism source gate reports its named non-empty scope is fully `m`-polymorphic.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 12.2: The modeled fault-injectable substrates + the per-fake fault-contract corpus 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Sim/Fakes/{Pulsar,MinIO,ApiServer,Route53,Vault,Clock}.hs` (the in-`IOSim`
modeled substrates, each with a typed fault model) and `test/sim/FaultContracts.hs` (the committed per-fake
fault-contract assertions) — target paths, not yet built.
**Blocked by**: Sprint 12.1.
**Independent Validation**: each modeled substrate honors its typed fault knob under a committed assertion — not
merely that the ADT compiles. The **per-fake fault-contract corpus (§M-7, the named representative set)**: fake
MinIO returns **412** on an `If-None-Match` conflict; fake apiserver yields a **resourceVersion conflict** and a
**watch-gap**; fake route53 serves the **stale record during propagation delay** and offers **no CAS**; fake
Vault **rejects ops while sealed**; a **partitioned Pulsar** link delivers nothing until healed, then
**redelivers with dedup**; and the reorder/duplicate/crash knobs each produce their stated observable. Each named
contract is paired with a positive that differs only in the fault knob (§M-8): `sim-spec` is red if any named
substrate's fault assertion is absent or passes with the knob disabled.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (§3 fault-model backlink),
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`deterministic_simulation_doctrine.md §3`](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model):
build the modeled, fault-injectable Pulsar/MinIO/apiserver/route53/Vault/clock, each carrying the typed fault
model (delay, reorder, duplicate, partition, crash), and commit the per-fake fault-contract corpus that asserts
each knob is actually honored — the named representative set foreclosing a substrate whose fault model is a
compiling-but-inert ADT.

### Deliverables
- The modeled Pulsar/MinIO/apiserver/route53/Vault/clock under `IOSim s`, each with the typed fault model named in
  the simulation doctrine §3.
- The committed **per-fake fault-contract corpus** (the six named substrate assertions above), each paired with a
  knob-disabled positive per §M-8, wired into `sim-spec`.

### Validation
1. Every named per-fake fault contract (MinIO 412, apiserver resourceVersion conflict + watch-gap, route53
   stale-read + no-CAS, Vault sealed-reject, Pulsar partition-then-dedup-redeliver, reorder/duplicate/crash)
   asserts red when its knob is disabled and green when enabled (§M-7/§M-8); a fault assertion absent from the
   corpus is a red gate.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 12.3: The deterministic-replay battery — same-seed determinism + schedule-sensitivity + fault-mutant — the gate 📋

**Status**: Planned
**Implementation**: `test/sim/SimSpec.hs` (the `IOSim`/`IOSimPOR` replay battery), `test/sim/schedules/` (the
committed schedule-fixture corpus — injected partition/redelivery/reorder/crash schedules, Phase-0-pinned), and
`test/sim/mutants/dropped_partition_handling/` (the committed seeded fault-mutant) — target paths, not yet built.
**Blocked by**: Sprint 12.2, Sprint 12.1; Phase 11 gate (the boundary harness); Phase 10 gate (the `[Step]` plan
the reconcile loop consumes).
**Schedule-fixture corpus (§M-7):** the replayed schedules are named explicitly here — a committed corpus of
injected partition/redelivery/reorder/crash schedules over the toy reconcile loop, each a `test/sim/schedules/`
fixture pinned in Phase 0, so every fault axis the modeled substrates expose is driven, not just a single
partition.
**Independent Validation**: `cabal test sim-spec` is green — the real daemon/reconciler code, lifted onto `Env m`,
replays the committed schedule-fixture corpus under `IOSim`/`IOSimPOR`. **Determinism is asserted by same-seed →
byte-identical trace** (cache-bypass is N/A — an `IOSim` replay recomputes the whole program every run, it is not
served from a content-addressed store; the honesty obligation is met instead by the schedule-sensitivity control).
**Schedule-sensitivity (§M-6):** a distinct-seed / distinct-fault-schedule run over the same fixture produces a
**different** trace; a same-trace result under a perturbed schedule is red (it proves the faults are ignored and
the same-seed assertion is a tautology about the library). **Committed seeded fault-mutant (§M-2), re-run every
gate run:** a dropped-partition-handling mutant — the reconciler that acts on a stale read without awaiting
partition-heal — MUST change the replayed invariant outcome to red; a green `sim-spec` against the mutant fails
the gate. The suite emits a **Register-2 proven/tested/assumed ledger** marking the invariant result *tested
against a modeled environment* and the modeled-env fidelity to the real substrate **ASSUMED / UNVERIFIED**
(§K), discharged later by a Register-3 conformance check.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-12 status when the gate passes),
`documents/engineering/deterministic_simulation_doctrine.md`, `documents/engineering/testing_doctrine.md`,
`documents/engineering/conformance_harness_doctrine.md` (§2 the Register-2.5 entry this substrate serves).

### Objective
Adopt [`deterministic_simulation_doctrine.md §4/§5`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
and [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
replay the real daemon/reconciler code under `IOSim`/`IOSimPOR` against the modeled substrates from the committed
schedule-fixture corpus, prove the replay is deterministic under a fixed seed and schedule-sensitive under a
perturbed one, and emit a Register-2 ledger that records the invariant result *tested* and the modeled-env
fidelity *assumed* — the honest premise this substrate buys
([`deterministic_simulation_doctrine.md §5`](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys)).

### Deliverables
- The committed **schedule-fixture corpus** (`test/sim/schedules/`, Phase-0-pinned per §M-1) — injected
  partition/redelivery/reorder/crash schedules over the toy reconcile loop.
- The committed **seeded fault-mutant** (`test/sim/mutants/dropped_partition_handling/`) with a harness that
  re-runs it and asserts `sim-spec` red (§M-2).
- `test/sim/SimSpec.hs` asserting: same-seed → byte-identical trace; a distinct-seed / distinct-schedule run
  yields a **different** trace (§M-6); the named per-fake fault contracts fire (§M-7, from Sprint 12.2); and the
  fault-mutant turns the replayed invariant outcome red.
- A Register-2 ledger: the invariant-under-the-modeled-schedules-and-faults result is *tested against a modeled
  environment*; the modeled-env fidelity to the real Pulsar/apiserver/route53/Vault is marked **ASSUMED /
  UNVERIFIED**, discharged later by a Register-3 conformance check — never quoted as *"the cluster is correct."*

### Validation
1. `cabal test sim-spec` is green — the committed schedule-fixture corpus replays byte-identically under the same
   seed, a distinct seed / fault schedule yields a different trace (§M-6), and every named per-fake fault contract
   fires (§M-7).
2. Demonstrated negative control (§M-2): the committed dropped-partition-handling fault-mutant is re-run and turns
   `sim-spec` red. A green run against the mutant fails the gate.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/deterministic_simulation_doctrine.md` — backlink §2/§3/§4 to the in-process Phase-12
  substrate; keep the Register-3 conformance check (the fidelity discharge) as the residue owned by the live band.
- `documents/engineering/testing_doctrine.md` — record the Register-2.5 deterministic-simulation substrate and the
  per-run ledger variant this gate emits (invariant *tested against a modeled environment*; modeled-env fidelity
  ASSUMED).
- `documents/engineering/chaos_failover_doctrine.md` — annotate §10 that the "build it pure; lift it whole" ladder
  is realized by the `Env m` interface and its two interpreters.
- `documents/engineering/conformance_harness_doctrine.md` — backlink §2's Register-2.5 deterministic-simulation
  entry to the in-process Phase-12 substrate that serves it.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-12 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-12 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Sim/Env.hs`,
  `src/Amoebius/Sim/Interp/{Real,Sim}.hs`, `src/Amoebius/Sim/Fakes/`, and the `sim-spec` test-suite as Phase-12
  design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (§K: a
  `**Register:**` field is never `2.5`; 2.5 names the *activity*, not the gate register)
- [overview.md](overview.md) — target architecture and the pre-cluster conformance vision
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — §2 the
  io-classes environment abstraction, §3 the simulated environment and its fault model, §4 where Register 2.5
  sits, §5 what DST establishes and the assumed-fidelity premise
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §2 the registers for
  pre-cluster validation (the Register-2.5 entry this substrate serves)
- [Chaos/Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — §10 simulate: the pure program
  lifted (io-sim), the ladder the two interpreters realize
- [phase_10](phase_10_chain_kernel_dryrun.md) — the `chain`/`Step` kernel + `--dry-run` plan the toy reconcile
  loop consumes
- [phase_11](phase_11_boundary_fake_tool_harness.md) — the boundary fake-tool harness whose single IO seam Sprint
  12.1 generalizes into the typed `Env m` effect interface
- [phase_31](phase_31_determinism_kernel.md) — the determinism kernel that shares the seed / `MonadTime` seams
  (one determinism substrate, two uses)
