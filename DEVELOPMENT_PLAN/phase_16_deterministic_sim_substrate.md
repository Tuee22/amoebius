# Phase 16: Deterministic-simulation substrate

> **Purpose**: Make one polymorphic reconcile program reproducible under a modeled, fault-injectable
> environment while keeping live-substrate fidelity outside the claim.
> **Read this if**: a concurrent reconciler needs deterministic schedule evidence, or a modeled trace must be
> distinguished from live-system proof.

This phase owns the `io-classes` environment seam, its structural `IO` client interpreter, its `IOSim`
interpreter, six modeled contracts, and the bounded replay gate. It validates a committed reference reconciler
and a semantic projection from the five-calculus composition. Later phases must run their own production code
through the same seam; this phase does not pre-validate them.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 16.1: Polymorphic environment and interpreters ✅](#sprint-161-polymorphic-environment-and-interpreters-)
- [Sprint 16.2: Modeled contracts and semantic schedules ✅](#sprint-162-modeled-contracts-and-semantic-schedules-)
- [Sprint 16.3: Determinism, exploration, and mutation ✅](#sprint-163-determinism-exploration-and-mutation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All twelve gate sides passed on natural `arm64`, untranslated. Both interpreters,
six fake contracts, four schedules, the actual five-calculus projection, same-seed determinism, changed-seed
sensitivity, four bounded POR replays, and the exact-reason mutant passed; all ten metrics matched and 28
surfaces joined to 38 run-time items. Attestation
`sha256:f532c640a409bca78bb309721749c314d7f57cebf76c795558da5e3a0eb72e7d` binds source
`sha256:0e946733b9f1fb06…` over 2,186 files. Repository-conformance and documentation support gates passed on
that snapshot. Model fidelity remains ASSUMED and live runtime remains UNVERIFIED.

## Phase Summary

`Env m` carries publish/consume, blob, object, DNS, Vault, and clock effects without fixing `m`. One reference
reconciler runs through `Env IO` backed by injected client functions and through `Env (IOSim s)` backed by
typed models. The gate uses `noOpRealClients` only to validate the structural `IO` interpretation; it does not
contact a live service. Six fake-contract modules exercise Pulsar, MinIO, apiserver, route53, Vault, and clock
semantics with enabled and disabled controls.

Four authored schedules cover delay, reorder, duplicate/redelivery, partition/heal, and crash/retry. A fixed
seed must produce equal encoded traces in two independent replays, a changed seed must change the trace, and
bounded `IOSimPOR` must uphold the reference invariant. This is a dynamic determinism assertion, not a
committed byte snapshot. The authored expected-outcome table decides schedule semantics, while a separate
five-row table fixes calculus order, component names, exact resource sum, published commands, and outcome for
the actual Phase-10 composition projection.

**Phase scope:** One polymorphic effect interface, two interpreters, six modeled service contracts, four
fault schedules, one five-calculus semantic projection, and one bounded replay/mutation gate; split if another
simulation engine, another service-model family, or a production reconciler's domain semantics enter the
substrate itself.
**Substrate:** none
**Lane:** none
**Register:** 2 — boundary integration with modeled services
**Depends on:** [Phase 10](phase_10_calculus_composition.md) — supplies the real indexed composition projected
into the reference program; [Phase 15](phase_15_compile_fail_harness.md) — supplies the preceding validated
compiler-evidence boundary and numeric opening condition.
**Gate:** `python3 tools/run_phase_gate.py 16` passes toolchain and source-boundary checks, the two
interpreters, six fake contracts, four schedule verdicts, five-calculus semantic projection, same-seed
determinism, changed-seed sensitivity, four bounded `IOSimPOR` replays, the registry-backed
dropped-partition mutant, ten metrics, complete surface join, containment, write guard, natural
architecture, and source-bound attestation.

## Gate integrity

- **Representative set:** the four schedules collectively enable every typed fault axis, the six fake
  contracts cover each modeled interface, and the actual five-calculus composition crosses the Phase-10/16
  boundary without replacing either vocabulary.
- **Independent oracles:** `expected_outcomes.tsv` fixes the invariant result for every schedule, and
  `calculus_projection.tsv` fixes order, names, resource total, published command multiset, and outcome. The
  suite reads both tables; neither is generated from its observations.
- **Positive counterparts:** every fake fault has a disabled-knob control. The reference reconciler must also
  uphold its invariant under the injected `IO` interpreter and every unmutated schedule.
- **Specific-reason negative:** the committed mutant drops partition handling and must report
  `NoActOnStaleRead`; a generic non-zero exit or another violated invariant cannot satisfy the gate.
- **Determinism control:** equal same-seed bytes alone are insufficient. The gate also perturbs a seed and
  requires a different trace, preventing an invariant constant trace from passing.
- **Bounded exploration:** `IOSimPOR` uses explicit branching and schedule limits for each authored schedule.
  The result is tested only inside those bounds and makes no exhaustive concurrency claim.
- **Composition correspondence:** test-support code constructs real artifact, budget, lift, workflow, and
  evidence components at one real request-scope index. Only plain projected facts cross into `sim-spec`,
  avoiding the older duplicate module identities still exposed by `dsl-core`.
- **Generated-artifact discipline:** encoded traces are compared during the run and are never committed.
  Metrics, locus ledgers, surface enumerations, logs, and attestations remain beneath `.build/**`.
- **Honesty boundary:** schedule invariants are tested against modeled services. Model fidelity remains
  **ASSUMED**, the structural `IO` interpreter does not constitute service contact, and live runtime remains
  **UNVERIFIED**.
- **Observer controls:** no authenticated or live authority path exists in this Register-2 process. Disabled
  knobs, independent semantic tables, changed-seed sensitivity, and the exact mutant locus are the applicable
  anti-tautology controls.
- **Fresh challenge:** not applicable. The phase has no live substrate; committed semantic schedules and the
  independent mutant are the reproducible challenge.
- **Extension conformance (§M.13).** Not applicable. Phase 16 declares no extension or domain member.

## Doctrine adopted

- [`deterministic_simulation_doctrine.md` §2 — The io-classes environment abstraction](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole): one program is interpreted under `IO` and `IOSim`.
- [`deterministic_simulation_doctrine.md` §3 — The simulated environment and its fault model](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model): the six modeled interfaces carry typed fault controls.
- [`deterministic_simulation_doctrine.md` §5 — What DST establishes](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys): modeled-schedule evidence is tested while environmental fidelity stays assumed.
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits): the phase gate is Register 2; Register 2.5 is the later activity this substrate serves, never this gate's register.

## Sprints

## Sprint 16.1: Polymorphic environment and interpreters ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Sim/{Env,Reconcile}.hs`,
`src/Amoebius/Sim/Interp/{Real,Sim}.hs`, and the `sim-spec` Cabal component.
**Blocked by**: None.
**Independent Validation**: one reference program returns `Upheld` under both injected-client `IO` and
`IOSim`; a non-empty ten-module source scan rejects bare `IO` signatures and raw concurrency while requiring
`MonadAsync`, `MonadSTM`, `MonadDelay`, and `IOSim`.
**Docs to update**: `documents/engineering/{deterministic_simulation_doctrine,testing_doctrine}.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

### Objective

Keep concurrency-bearing reconcile code independent of the interpreter used to execute its effects.

### Deliverables

- Typed `Env m` interface and injected real-client function record.
- Deterministic `IOSim` state/trace interpreter.
- One polymorphic reference reconciler, including its data-driven command seam.
- Exact source-boundary scan over the ten simulation modules.

### Validation

1. Build `lib:dsl-core` and `test:sim-spec` with dynamically resolved Cabal/GHC.
2. Require both interpreters to uphold the same reference invariant.
3. Reject bare-`IO` signatures, raw concurrency, an empty scope, or missing polymorphism tokens.

### Remaining Work

None.

## Sprint 16.2: Modeled contracts and semantic schedules ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Sim/Fakes/**`, `test/spec/sim/FaultContracts.hs`,
`test/fixture/deterministic_simulation/schedules/**`, `test/oracle/deterministic_simulation/{expected_outcomes,calculus_projection,validation_locus}.tsv`, and
`test/harness/deterministic_simulation/CalculusProjection.hs`.
**Blocked by**: Sprint 16.1's environment interface and interpreters.
**Independent Validation**: authored service controls and four expected schedule verdicts are checked
separately from the implementation; a five-row semantic table checks the real Phase-10 composition projection.
**Docs to update**: `documents/engineering/{deterministic_simulation_doctrine,testing_doctrine}.md` and
`DEVELOPMENT_PLAN/{legacy_tracking_for_deletion,system_components}.md`.

### Objective

Make modeled faults and the composition-to-reconcile boundary observable as semantic facts rather than
implementation snapshots.

### Deliverables

- Six fake contracts with enabled/disabled fault controls.
- Four JSON schedules spanning all typed axes and four authored invariant verdicts.
- Focused-package adapter that constructs the real five-calculus composition.
- Semantic projection oracle over ordered kinds/names, exact resources, emitted commands, and outcome.

### Validation

1. Require the exact schedule corpus, names, typed fault fields, and axis coverage.
2. Require all four authored outcomes to be `Upheld` under the reference program.
3. Require the exact five semantic projection facts and reject any missing or changed row.

### Remaining Work

None.

## Sprint 16.3: Determinism, exploration, and mutation ✅

**Status**: Done.
**Implementation**: `test/spec/sim/{SimSpec,DroppedPartitionMutant}.hs`,
`test/mutant/registry.tsv`, `test/oracle/deterministic_simulation_surfaces.tsv`, and
`tools/deterministic_simulation_gate.py`.
**Blocked by**: Sprint 16.2's authored schedules and semantic oracles.
**Independent Validation**: four two-run byte comparisons are paired with changed-seed sensitivity, four
bounded POR replays, and one exact-reason mutation result.
**Docs to update**: `DEVELOPMENT_PLAN/{README,overview,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Show that explored modeled faults are reproducible and that the gate rejects a missing partition response.

### Deliverables

- Same-seed encoded-trace equality over all four schedules.
- One changed-seed inequality control and four bounded `IOSimPOR` checks.
- Registry-backed dropped-partition mutant red at `NoActOnStaleRead`.
- Ten exact metrics, complete run-time surface join, ledger, containment, and attestation.

### Validation

1. Replay every schedule twice and compare both outcome and encoded trace.
2. Perturb the partition schedule seed and require a different trace.
3. Bound POR exploration explicitly and require `Upheld` for every observed result.
4. Run the mutant independently and require its exact invariant token and non-zero status.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `deterministic_simulation_doctrine.md` — record the five-calculus projection and the dynamic-trace/no-golden distinction.
- `testing_doctrine.md` — record the concrete Register-2 substrate instance and honesty boundary.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `system_components.md`, and
  `legacy_tracking_for_deletion.md` — reconcile order, evidence, implementation paths, and retired debt.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Canonical Phase Model](development_plan_phase_model.md) — reopening and status semantics.
- [Gate Integrity Standard](development_plan_gate_integrity.md) — universal gate and surface obligations.
- [Architecture Overview](overview.md) — the verification-band role of this phase.
- [Phase 10](phase_10_calculus_composition.md) — the indexed composition projected by this gate.
- [Phase 15](phase_15_compile_fail_harness.md) — the preceding sealed phase.
- [Phase 17](phase_17_gateway_migration_model.md) — the next numeric contract.
- [Phase 34](phase_34_chain_kernel_boundary.md) — the later subprocess-boundary generalization.
- [Phase 80](phase_80_determinism_jitcache.md) — the shared determinism-seam owner.
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — effect, fault, and honesty rules.
- [Chaos and Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the simulate/lift ladder.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the pre-cluster validation spine.
