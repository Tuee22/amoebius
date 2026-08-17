# Phase 15: Deterministic-simulation substrate

> **Purpose**: Build the `io-classes` environment substrate and the modeled, fault-injectable
> Pulsar/MinIO/apiserver/route53/Vault/clock so the *real* daemon/reconciler code, lifted onto `io-classes`, runs
> under `IOSim`/`IOSimPOR` and replays an injected partition/redelivery/reorder/crash schedule **deterministically**
> (same seed → byte-identical trace), gated in-process with no cluster.
> **Read this if**: phase 15 is next in the queue, or a later phase depends on what its gate establishes.

Phase 15 delivers the deterministic-simulation substrate; its design is owned by [deterministic_simulation_doctrine.md](../documents/engineering/deterministic_simulation_doctrine.md), [conformance_harness_doctrine.md](../documents/engineering/conformance_harness_doctrine.md), [chaos_failover_doctrine.md](../documents/engineering/chaos_failover_doctrine.md), and the plan for reaching it is owned here.
Register 2: an in-process deterministic-simulation boundary.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_27_object_reconciler.md, DEVELOPMENT_PLAN/phase_28_capacity_scheduler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 15.1: The `io-classes` `Env` effect interface + its two interpreters + `sim-spec` skeleton ✅](#sprint-151-the-io-classes-env-effect-interface--its-two-interpreters--sim-spec-skeleton-)
- [Sprint 15.2: The modeled fault-injectable substrates + the per-fake fault-contract corpus ✅](#sprint-152-the-modeled-fault-injectable-substrates--the-per-fake-fault-contract-corpus-)
- [Sprint 15.3: The deterministic-replay battery — same-seed determinism + schedule-sensitivity + fault-mutant — the gate ✅](#sprint-153-the-deterministic-replay-battery--same-seed-determinism--schedule-sensitivity--fault-mutant--the-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-14 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Done (invalidated) — resealed 2026-08-15. `python3 tools/deterministic_simulation_gate.py` passed all eleven sides: both
interpreters, six fake contracts, four schedules, trace determinism/sensitivity, IOSimPOR, the seeded mutant,
all nine metrics, and the exact simulation source checks pass; 26 surfaces join to 36 enumerated items. The
project-contained attestation is `sha256:6be4c197c0739f6ffaa5950391b49ede59c758bc8373609a545acea513de1465`,
bound to source snapshot `sha256:4a7809fb4d96d811…`; Phase 15 owns no remaining migration deferral.

**Pre-containment status record (invalidated where it claims completion):**

Done (invalidated) — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:2b3c1bd5…`
(1940 non-ignored files) and published a verified pre-containment external attestation
`sha256:8a27796e30cb0da4b538fd20e3d758bdf4dff3417669cbf1766c7bc247eaa0b3`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The Register-2 claim is unchanged and re-run: one
reference reconciler runs under both the real-client and `IOSim` interpreters, six fake contracts each expose
their knob controls, four oracle-pinned schedules replay, same-seed traces are byte-identical while a distinct
seed is demonstrably distinct, four bounded `IOSimPOR` replays are green, and the dropped-partition mutant
reddens at `NoActOnStaleRead`. Evidence and the ledger move into `.build/runs/phase_15/<run-id>/`.

**This is the first phase whose contract vocabulary and battery observations line up completely.** All 25
surfaces have evidence — 22 validation-locus entries and mutant names partitioned one-to-one, seven recorded
metrics, and two source-level checks that the gate always performed but never named: the bare-IO-signature scan
over the simulation scope and the non-vacuous polymorphism-token check. Nothing is carried UNVERIFIED except
the two rows that must be: `modeled-environment-fidelity` stays **ASSUMED**, because a modeled environment's
faithfulness to a real substrate is exactly what this register cannot establish, and `live-substrate-runtime`
stays UNVERIFIED. The Runtime ledger layer is pinned UNVERIFIED for the same reason — Register 2.5 runs the
real reconciler against a model, never against a substrate.

**Invalidated historical record:**

Done (invalidated). The Register-2 gate passes on no substrate. It validates the committed reference reconciler under the
real-client and `IOSim` interpreters, six modeled fault contracts, four deterministic schedules, IOSimPOR
exploration, schedule sensitivity, and the dropped-partition mutant. Model fidelity to live substrates remains
ASSUMED and live runtime remains UNVERIFIED. See the
Phase-15 ledger.

## Phase Summary

This phase delivers the deterministic-simulation substrate: the typed `Env m` effect interface (publish/consume,
put/get-blob, apply-object, write-DNS, vault-op, now/delay) polymorphic over an `io-classes` monad `m`, its two
interpreters (real clients under `m = IO`; the modeled substrates under `m = IOSim s`), and the modeled,
fault-injectable Pulsar/MinIO/apiserver/route53/Vault/clock — each carrying the typed fault model (delay,
reorder, duplicate, partition, crash) named in the simulation doctrine. The *real* daemon/reconciler code,
written once and polymorphic over `m`, runs as the production daemon under `IO` and as a deterministic model under
test under `IOSim s` **from one source**: an injected partition/redelivery/reorder/crash schedule replays
byte-for-byte under a fixed seed, so a concurrency defect surfaces as a reproducible trace rather than a flaky
run. What is *not* here: the boundary fake-tool harness (Phase 14, which this phase's Sprint 15.1 generalizes),
the real subprocess tool invocations, and the live substrates themselves. The load-bearing honesty limit is that
the modeled environment's **fidelity to the real Pulsar/apiserver/route53/Vault is ASSUMED** — a narrow, testable
premise discharged later by a Register-3 conformance check that pins each fake's contract against the real system,
never waved away.

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test sim-spec` battery replaying the
real daemon/reconciler code under `IOSim`/`IOSimPOR` against the modeled substrates from committed schedule
fixtures.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 2 — an in-process deterministic-replay battery, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)). This phase *builds and gates* the
substrate the live-band phases later use for their Register-2.5 activity; the phase gate itself keys to Register 2,
never 2.5 ([`development_plan_standards.md §K`](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `python3 tools/deterministic_simulation_gate.py` passes the build, six fake-contract,
four-schedule replay, byte-determinism, sensitivity, IOSimPOR, explicit mutant-red, and ledger checks. The
Phase-15 ledger records the exact tested/model-proven boundary
and the assumed fidelity premise.

**Independent oracle (§M.3).** The determinism assertion (same-seed → byte-identical trace) is guarded against
tautology by the [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-6 schedule-sensitivity control, but the *invariant verdicts* are checked against a
**oracle-pinned, hand-authored expected-outcome table** — one row per committed schedule-fixture giving the
invariant verdict (`upheld` / `violated`, and for a violation the expected failing invariant) that the
reconciler must produce under that schedule — authored **independently of the `Env m` reconciler code** and
sharing none of it, so the equivalence `replayed-verdict ⟺ expected-verdict` cannot be a re-derivation of the
subject under test. A verdict table regenerated from the reconciler's own replay is not an oracle; the seeded
fault-mutant ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-2) must flip a row of this table from `upheld` to `violated`, proving the table has
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

> **Current validation record.** Every sprint is covered by the 2026-08-15 reseal. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure was
> established by the current phase gate plus universal artifact hygiene.

## Sprint 15.1: The `io-classes` `Env` effect interface + its two interpreters + `sim-spec` skeleton ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Sim/Env.hs` (the typed effect interface —
publish/consume, put/get-blob, apply-object, write-DNS, vault-op, now/delay — polymorphic over an
`io-classes` monad `m`), `src/Amoebius/Sim/Interp/{Real,Sim}.hs` (the two interpreters: real clients under
`IO`; the `IOSim s` model), and the `sim-spec` test-suite stanza in `amoebius.cabal` — built and validated.
**Blocked by**: None.
**Independent Validation**: the reference reconciler runs under both `Env IO` with no-op clients and
`Env (IOSim s)`. The non-empty source gate rejects bare-`IO` signatures and raw concurrency primitives while
requiring the `MonadAsync`, `MonadSTM`, `MonadDelay`, and `IOSim` seams.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (Phase-15 status
backlink), `documents/engineering/testing_doctrine.md` (the Register-2.5 substrate),
`documents/engineering/chaos_failover_doctrine.md` (§10 "build it pure; lift it whole" ladder, realized by
the two interpreters), `DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`deterministic_simulation_doctrine.md §2`](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole)
and the "build it pure; lift it whole" ladder
([`chaos_failover_doctrine.md §10`](../documents/engineering/chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)):
stand up the typed `Env m` effect interface and its two interpreters so the *real* daemon/reconciler code —
written once, polymorphic over `m` — runs as the production daemon (`m = IO`) and as a deterministic model under
test (`m = IOSim s`) from one source, generalizing the Phase-14 single IO seam.

### Deliverables
- `src/Amoebius/Sim/Env.hs`: the typed `Env m` effect interface (publish/consume, put/get-blob, apply-object,
  write-DNS, vault-op, now/delay), polymorphic over an `io-classes` monad `m`, reusing the `MonadTime`/`MonadTimer`
  clock and the seed seams the determinism kernel ([phase_49](phase_49_determinism_jitcache.md)) also uses — one
  determinism substrate, two uses.
- `src/Amoebius/Sim/Interp/{Real,Sim}.hs`: the two interpreters (real clients under `IO`; the `IOSim s` model).
- The `sim-spec` test-suite stanza and a toy reconcile loop exercising the interface under both interpreters.

### Validation
1. `cabal build` and the toy-loop `sim-spec` skeleton are green on the Phase-1 pin under both interpreters; the
   `m`-polymorphism source gate reports its named non-empty scope is fully `m`-polymorphic.

### Remaining Work
Done. Live client behavior remains UNVERIFIED.

## Sprint 15.2: The modeled fault-injectable substrates + the per-fake fault-contract corpus ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**:
`src/Amoebius/Sim/Fakes/{Pulsar,MinIO,ApiServer,Route53,Vault,Clock}.hs` (the in-`IOSim` modeled substrates,
each with a typed fault model) and `test/spec/sim/FaultContracts.hs` (the committed per-fake fault-contract
assertions) — built and validated.
**Blocked by**: None.
**Independent Validation**: MinIO 412, apiserver conflict/watch-gap/crash, route53 stale/no-CAS, Vault sealed,
Pulsar partition/heal/dedup/reorder/duplicate, and modeled-clock delay all match their contract assertions.
Each fault has a disabled-knob control.
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
  the simulation doctrine [§3](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model).
- The committed **per-fake fault-contract corpus** (the six named substrate assertions above), each paired with a
  knob-disabled positive per [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-8, wired into `sim-spec`.

### Validation
1. Every named per-fake fault contract (MinIO 412, apiserver resourceVersion conflict + watch-gap, route53
   stale-read + no-CAS, Vault sealed-reject, Pulsar partition-then-dedup-redeliver, reorder/duplicate/crash)
   asserts red when its knob is disabled and green when enabled ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-7/[§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-8); a fault assertion absent from the
   corpus is a red gate.

### Remaining Work
Done. Model fidelity to each real substrate remains ASSUMED.

## Sprint 15.3: The deterministic-replay battery — same-seed determinism + schedule-sensitivity + fault-mutant — the gate ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `test/spec/sim/SimSpec.hs` (the `IOSim`/`IOSimPOR` replay battery),
`test/fixture/deterministic_simulation/schedules/` (the committed schedule-fixture corpus — injected partition/redelivery/reorder/crash
schedules, oracle-pinned), and `test/mutant/deterministic_simulation/dropped_partition_handling/` (the committed seeded
fault-mutant) — built and validated.
**Blocked by**: None.
**Independent Validation**: all four schedules match the hand-authored `upheld` table and replay to identical
trace bytes for the same seed. Perturbing the seed changes message order and trace bytes. IOSimPOR explores each
fixture, and the dropped-partition mutant yields `Violated "NoActOnStaleRead"` in an explicit red run.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-15 status
when the gate passes), `documents/engineering/deterministic_simulation_doctrine.md`,
`documents/engineering/testing_doctrine.md`, `documents/engineering/conformance_harness_doctrine.md` (§2 the
Register-2.5 entry this substrate serves).

### Objective
Adopt [`deterministic_simulation_doctrine.md §4/§5`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
and [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
replay the real daemon/reconciler code under `IOSim`/`IOSimPOR` against the modeled substrates from the committed
schedule-fixture corpus, prove the replay is deterministic under a fixed seed and schedule-sensitive under a
perturbed one, and emit a Register-2 ledger that records the invariant result *tested* and the modeled-env
fidelity *assumed* — the honest premise this substrate buys
([`deterministic_simulation_doctrine.md §5`](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys)).

### Deliverables
- The committed **schedule-fixture corpus** (`test/fixture/deterministic_simulation/schedules/`, oracle-pinned per [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-1) — injected
  partition/redelivery/reorder/crash schedules over the toy reconcile loop.
- The committed **seeded fault-mutant** (`test/mutant/deterministic_simulation/dropped_partition_handling/`) with a harness that
  re-runs it and asserts `sim-spec` red ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-2).
- `test/spec/sim/SimSpec.hs` asserting: same-seed → byte-identical trace; a distinct-seed / distinct-schedule run
  yields a **different** trace ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-6); the named per-fake fault contracts fire ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-7, from Sprint 15.2); and the
  fault-mutant turns the replayed invariant outcome red.
- A Register-2 ledger: the invariant-under-the-modeled-schedules-and-faults result is *tested against a modeled
  environment*; the modeled-env fidelity to the real Pulsar/apiserver/route53/Vault is marked **ASSUMED / UNVERIFIED**, discharged later by a Register-3 conformance check — never quoted as *"the cluster is correct."*

### Validation
1. `cabal test sim-spec` is green — the committed schedule-fixture corpus replays byte-identically under the same
   seed, a distinct seed / fault schedule yields a different trace ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-6), and every named per-fake fault contract
   fires ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-7).
2. Demonstrated negative control ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)-2): the committed dropped-partition-handling fault-mutant is re-run and turns
   `sim-spec` red. A green run against the mutant fails the gate.

### Remaining Work
Done. Later phases must replay their own reconcilers; live conformance remains UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/deterministic_simulation_doctrine.md` — backlink §2/§3/§4 to the in-process Phase-15
  substrate; keep the Register-3 conformance check (the fidelity discharge) as the residue owned by the live band.
- `documents/engineering/testing_doctrine.md` — record the Register-2.5 deterministic-simulation substrate and the
  per-run ledger variant this gate emits (invariant *tested against a modeled environment*; modeled-env fidelity
  ASSUMED).
- `documents/engineering/chaos_failover_doctrine.md` — annotate §10 that the "build it pure; lift it whole" ladder
  is realized by the `Env m` interface and its two interpreters.
- `documents/engineering/conformance_harness_doctrine.md` — backlink §2's Register-2.5 deterministic-simulation
  entry to the in-process Phase-15 substrate that serves it.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-15 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-15 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Sim/Env.hs`,
  `src/Amoebius/Sim/Interp/{Real,Sim}.hs`, `src/Amoebius/Sim/Fakes/`, and the `sim-spec` test-suite as Phase-15
  design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed): a `**Register:**` field is never `2.5`; 2.5 names the *activity*, not the gate register)
- [overview.md](overview.md) — target architecture and the pre-cluster conformance vision
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — [§2](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole) the
  io-classes environment abstraction, [§3](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model) the simulated environment and its fault model, [§4](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits) where Register 2.5
  sits, [§5](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys) what DST establishes and the assumed-fidelity premise
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — [§2](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) the registers for
  pre-cluster validation (the Register-2.5 entry this substrate serves)
- [Chaos/Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — [§10](../documents/engineering/chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim) simulate: the pure program
  lifted (io-sim), the ladder the two interpreters realize
- [phase_14](phase_14_chain_kernel_boundary.md) — the `chain`/`Step` kernel + `--dry-run` plan the toy reconcile
  loop consumes
- [phase_14](phase_14_chain_kernel_boundary.md) — the boundary fake-tool harness whose single IO seam Sprint
  12.1 generalizes into the typed `Env m` effect interface
- [phase_49](phase_49_determinism_jitcache.md) — the determinism kernel that shares the seed / `MonadTime` seams
  (one determinism substrate, two uses)
