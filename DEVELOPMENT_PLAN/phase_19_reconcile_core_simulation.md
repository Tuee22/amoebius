# Phase 19: Reconcile decision core under deterministic simulation

> **Purpose**: Build a pure observed-inventory/desired-index planner and test its fixed-point, bounded
> convergence, snapshot-token, reservation, and three-valued-observation behavior under deterministic
> simulation before any live correspondence claim.
> **Read this if**: the pure reconcile boundary, typed delete authority, modeled schedules, or the boundary
> between simulated evidence and effectful runtime fidelity must change.

This phase owns one pure reconcile library and a four-schedule `IOSim`/`IOSimPOR` battery. It consumes the
Phase-16 simulation method and links four tested properties to Phase-18 model invariant names. It does not
claim that a live driver captures fresh observations, enacts actions faithfully, or matches the modeled store.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 19.1: Pure typed decision core ✅](#sprint-191-pure-typed-decision-core-)
- [Sprint 19.2: Four deterministic reconcile schedules ✅](#sprint-192-four-deterministic-reconcile-schedules-)
- [Sprint 19.3: Protocol correspondence and sealed gate ✅](#sprint-193-protocol-correspondence-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated: all thirteen
metrics matched and 21 surfaces joined to 23 run-time items. Attestation
`sha256:1967ded20d6c6db55b1b75e074d021ff860b4a075d4d31909d93a23e03a4cf4c` binds source
`sha256:1ab645d7ff28a43b…` over 2,208 files. Repository-conformance attestation
`sha256:7d287969c51160585cffba08aad433a66798a0b80d626d292b81dae03bf090b4` and documentation attestation
`sha256:0ab6555f2a0edfaa37c3b1398582647a74c2a46fc98658a60c03528a0ca2f33a` passed on that snapshot. The
decision/protocol claims are tested only over the declared corpora and schedules; modeled-environment fidelity
is ASSUMED and runtime fidelity is UNVERIFIED.

## Phase Summary

`lib:reconcile-core` separates the pure function
`ObservedInventory -> DesiredIndex -> Either Refusal ActionSet` from every client and live driver. Nine
authored cases cover converged, create, apply, delete, mixed, empty, unreachable, and missing-observation
outcomes. Actual output must equal the authored row and a second flat textual planner that imports no
production reconcile module. The two converged rows produce an empty action set; this is a fixed-point claim,
not the ill-typed equation of applying an action-producing function to its own output.

Observations are indexed by `IsPresent`, `IsAbsent`, or `IsUnreachable`. `DeleteObject` accepts only an
`Observation 'IsPresent`; the legal twin compiles and the unreachable mutation fails at the exact
`IsUnreachable`/`IsPresent` mismatch. The planner fails closed for every unreachable entry and for a desired
identity absent from the observation domain, returning no partial action set.

Four authored schedules—baseline, duplicate delivery, crash before apply, and stale snapshot—drive a
three-action reconcile through the actual core and a modeled versioned store. Each reaches the exact final
inventory within its bound. Two fresh same-seed executions encode identical trace bytes, a changed seed changes
semantic action order, and bounded `IOSimPOR` replays all four. The store accepts one of two concurrent uses of
one snapshot token and rejects the other. The actual scheduler reservation algebra admits one concurrent
reservation and retains one debit while reaching `Bound` across crashes at `Reserved`, `BindingInFlight`, and
`Bound`.

Four correspondence rows bind tested properties to Phase-18 invariants: `NoTokenReuse`,
`OneDebitPerReservation`, `RefuseOnUnreachable`, and `ConvergedIsStable`. This checks vocabulary and evidence
alignment; it does not turn simulation into a refinement proof. Four behavioral mutants and the typed-delete
mutant each redden one authored property.

**Phase scope:** One nine-case pure planner corpus, one three-action scenario under four authored schedules,
one concurrent token race, three reservation crash cuts, four formal-invariant links, and five mutants; add a
new phase owner for an effectful driver, live service, larger state domain, or model-to-code refinement proof.
**Substrate:** none
**Lane:** none
**Register:** 2 — boundary integration with modeled stores and deterministic schedules, no cluster.
**Depends on:** [Phase 16](phase_16_deterministic_sim_substrate.md) — supplies the `io-classes`/`IOSim`
method and determinism contract; [Phase 18](phase_18_dsl_formal_model.md) — supplies the named token,
reservation, unreachable-refusal, and convergence invariants this suite links to.
**Gate:** `python3 tools/run_phase_gate.py 19` passes thirteen exact metrics, the actual-core and
independent-reference corpus, four schedule/POR runs, typed-delete negative, five exact mutants, complete
surface join, architecture, containment, write guard, ledger, and source-bound attestation; [Gate
integrity](#gate-integrity) owns the anti-tautology apparatus.

## Gate integrity

- **Representative set (§M.7):** `core_cases.tsv` names nine planner cases; four JSON fixtures name baseline,
  duplicate, crash, and stale-snapshot schedules; the simulated scenario requires apply/create/delete; the
  protocol set is one token race and reservation crashes at three exact transition cuts.
- **Independent oracle (§M.1/§M.3):** authored expected results decide every core row. `ReferencePlanner`
  independently parses the flat textual vocabulary and imports no production reconcile module. The schedule
  table fixes verdict, accepted/rejected counts, and one required semantic event per schedule.
- **No generated-output oracle:** no trace snapshot is committed. Same-seed bytes compare two fresh runs, a
  changed seed must alter semantic order, and authored outcomes/counts/events decide meaning.
- **Mutation quota (§M.2):** fixed-point re-emission, oscillating application, token-guard deletion,
  reservation-loss-on-crash, and an unreachable delete witness redden `FixedPoint`, `Convergence`,
  `NoTokenReuse`, `BoundRetainedAfterCrash`, and `DeleteRequiresPresentWitness` respectively.
- **Positive and adjacent controls (§M.8):** two correct fixed points precede re-emission; correct convergence
  precedes oscillation; the correct token race admits one/rejects one; all three correct reservation recoveries
  reach `Bound`; and the Present delete twin compiles before the Unreachable twin is required to fail.
- **Finite coverage honesty (§M.4):** the nine cases, one three-action world, four schedules, POR branching
  bound 3/schedule bound 32, and three crash cuts are exact finite evidence. No unscheduled fault combination,
  arbitrary inventory, or real-store behavior is inferred.
- **External observation (§M.5/§M.10):** the independent textual planner observes actual semantic outputs;
  the compiler observes the type negative; `IOSim` traces and store counters observe transitions. No component
  self-reports compliance.
- **Authority/bypass (§§M.11–M.12):** Delete requires a compiler-checked Present witness and unreachable input
  returns `Refusal`. Live credentials, alternate clients, and effectful bypass paths do not exist in this
  Register-2 boundary and remain UNVERIFIED.
- **Fresh challenge (§M.9):** not applicable. No effectful service response is accepted; fresh snapshot
  behavior is exercised as a modeled version/CAS transition and its fidelity to a real store is ASSUMED.
- **Proof boundary:** all code correspondence here is tested. Phase-18 safety remains proven only for its
  models; the four name links are not a refinement proof. Live driver and model-to-runtime fidelity remain
  UNVERIFIED.
- **Extension conformance (§M.13).** Not applicable. Phase 19 declares no extension or domain member.

## Doctrine adopted

- [`deterministic_simulation_doctrine.md` §4](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits): same-seed replay and bounded POR are tested evidence over a modeled environment.
- [`cluster_lifecycle_doctrine.md` §9](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): the decision core consumes three-valued observation and fails closed on unreachable state.
- [`formal_model_doctrine.md` §6](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): linking tested code properties to invariant names does not prove runtime correspondence.
- [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md): an active reservation remains one debit across binding and recovery.

## Sprints

## Sprint 19.1: Pure typed decision core ✅

**Status**: Done.
**Implementation**: `src/reconcile-core/Amoebius/Reconcile/Core.hs`,
`test/harness/reconcile_core/ReferencePlanner.hs`, `test/oracle/reconcile_core/core_cases.tsv`, and
`test/negative/compile_fail/reconcile_core/DeleteWitnessCompile.hs`.
**Blocked by**: None.
**Independent Validation**: actual output, authored output, and a production-independent textual planner must
agree; the compiler checks the Present/Unreachable boundary.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md` and
`DEVELOPMENT_PLAN/system_components.md`.

### Objective

Make the planner pure and total over its declared observed/desired inputs, with deletion authority carried by
the observation type rather than a runtime flag.

### Deliverables

- Standalone `reconcile-core` library with desired, observation, refusal, and typed action vocabulary.
- Nine-case actual/reference corpus with two exact fixed points.
- Present legal twin and Unreachable compile negative for deletion.

### Validation

1. Match every actual and independent-reference result to the authored semantic row.
2. Require both converged cases to produce exactly the empty action set.
3. Require the illegal delete to fail at the exact presence-index mismatch.
4. Exclude effect/client/process/network imports from the pure core.

### Remaining Work

None.

## Sprint 19.2: Four deterministic reconcile schedules ✅

**Status**: Done.
**Implementation**: `src/reconcile-core/Amoebius/Reconcile/Sim.hs`,
`test/spec/reconcile/ReconcileCoreSimulationSpec.hs`, and
`test/{fixture,oracle}/reconcile_core/{schedules,schedule_outcomes.tsv}`.
**Blocked by**: Sprint 19.1's planner and action semantics.
**Independent Validation**: authored verdict/count/event rows and exact final inventory are distinct from the
actual trace; changed-seed sensitivity prevents a constant trace from satisfying determinism.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md`.

### Objective

Run the actual core against a bounded versioned store under four named schedules and retain deterministic,
convergent semantic evidence without committing trace bytes.

### Deliverables

- Baseline, duplicate, crash-before-apply, and stale-snapshot fixtures.
- Exact modeled final inventory and accepted/rejected transition counts.
- Four same-seed controls, one changed-seed control, and four bounded POR runs.

### Validation

1. Require all four schedules to converge to the exact three-object inventory within their authored bound.
2. Compare only two fresh same-seed encodings; retain no committed generated trace.
3. Require a changed seed to change semantic action order.
4. Require every bounded POR replay to converge.

### Remaining Work

None.

## Sprint 19.3: Protocol correspondence and sealed gate ✅

**Status**: Done.
**Implementation**: `test/spec/reconcile/ReconcileCoreSimulationSpec.hs`,
`test/mutant/reconcile_core/ReconcileCoreMutants.hs`,
`test/oracle/reconcile_core/{formal_correspondence,mutation_catalog}.tsv`,
`test/oracle/reconcile_core_simulation_surfaces.tsv`, and `tools/reconcile_core_simulation_gate.py`.
**Blocked by**: Sprint 19.2's modeled store and schedules.
**Independent Validation**: concurrent token/reservation outcomes, actual scheduler transitions, Phase-18
model structure, and exact mutant loci are separate readings.
**Docs to update**: `documents/engineering/{resource_capacity,deterministic_simulation}_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Exercise one-use and one-debit protocol behavior in code, link it honestly to the formal vocabulary, and seal
the bounded result with mutation and repository-hygiene evidence.

### Deliverables

- One concurrent token race and one concurrent reservation CAS.
- Three actual scheduler recovery cuts reaching `Bound` with one retained debit.
- Four formal-invariant links and five exact mutants.
- Thirteen metrics, 21-surface/23-item join, ledger, containment, write guard, and attestation.

### Validation

1. Require exactly one accepted token use and exactly one reuse rejection.
2. Require one reservation debit and `Bound` recovery across all three crash cuts.
3. Resolve all four correspondence rows against actual Phase-18 model/invariant names.
4. Require every mutant to redden its authored property and no generic failure token.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `cluster_lifecycle_doctrine.md` — record the pure core, typed delete witness, and exact tested boundary.
- `deterministic_simulation_doctrine.md` — record the four Phase-19 schedules and dynamic trace control.
- `resource_capacity_doctrine.md` — record the one-debit/three-crash-cut reservation evidence.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `system_components.md`, and
  `legacy_tracking_for_deletion.md` — reconcile order, evidence, implementation paths, and retired byte-golden
  debt.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Gate Integrity Standard](development_plan_gate_integrity.md) — independent oracle, mutation, and bounded-honesty requirements.
- [Phase 16](phase_16_deterministic_sim_substrate.md) — deterministic-simulation method and substrate.
- [Phase 18](phase_18_dsl_formal_model.md) — named formal invariants linked here.
- [Phase 20](phase_20_extension_declaration.md) — next numeric contract.
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — modeled schedule contract.
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — reconcile semantics.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — proof/correspondence boundary.
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — reservation debit semantics.
