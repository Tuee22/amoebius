# Phase 19: Reconcile decision core under deterministic simulation

> **Purpose**: Specify the target Haskell capability to plan from observed inventory to desired
> index with a pure Haskell decision core and exercise fixed-point, bounded-convergence, token,
> reservation, and three-valued-observation behavior under deterministic modeled schedules.
> **Read this if**: the pure reconcile boundary, typed delete authority, modeled schedules, or the boundary
> between simulated evidence and effectful runtime fidelity must change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 19.1: Pure typed decision core](#sprint-191-pure-typed-decision-core-)
- [Sprint 19.2: Four deterministic reconcile schedules](#sprint-192-four-deterministic-reconcile-schedules-)
- [Sprint 19.3: Historical protocol/gate work](#sprint-193-protocol-correspondence-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 18 and every earlier gate have current passing receipts. The Phase-19 implementation and compiled
semantic contract are bound below; completion still requires the exact integrated Phase-19 gate.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase has a bound Haskell implementation but does not report a passing result until its complete gate
runs. It plans from observed inventory to desired index with a pure typed decision core and exercises
fixed-point, bounded-convergence, token, reservation, and three-valued-observation behavior under deterministic
modeled schedules.

The production subject, behavioral controls, independent oracle, fixtures, and mutants are authored as `.hs`.
The former JSON/TSV behavioral declarations and test-local mutant module are retired. Derived results are
created lazily beneath the acquired `.build/runs/phase-19/**` root and remain run-scoped evidence only.

This phase precedes Phase 49 and is confined to modeled Register-2 boundary behavior only. It cannot
use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — plan from observed inventory to desired index with a pure
Haskell decision core and exercise fixed-point, bounded-convergence, token, reservation, and
three-valued-observation behavior under deterministic modeled schedules. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 2 — Haskell behavior against modeled boundaries only; no live correspondence claim. NOT VALIDATED.

**Depends on:** [Phase 18](phase_18_dsl_formal_model.md)
**Gate:** `pb validate phase 19`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | The complete Phase-19 claim is the pure typed reconcile decision core plus four deterministic modeled schedules, bounded POR, snapshot-token and reservation protocols, typed deletion authority, and four honest Phase-18 formal links. Effectful runtime fidelity is excluded. |
| `Subject` | `src/reconcile-core/Amoebius/Reconcile/{Core,Sim}.hs` and the reservation debit fold in `src/execution-accelerator-folds/Amoebius/Capacity/Scheduler.hs`, acquired and exercised by the package-hidden Phase-19 supervisor. |
| `Command` | `pb validate phase 19` is the future public spelling. This pre-handoff gate instead invokes the exact absolute source-bound Haskell executable as `validate phase 19`, then runs exact Cabal 3.16.1.0 and GHC 9.12.4 paths offline with `--jobs=1`; `pb` is not used. |
| `Oracle` | `test/spec/reconcile/ReconcileCoreOracle.hs` owns the closed semantic corpus, while `test/harness/reconcile_core/ReferencePlanner.hs` independently plans from its textual vocabulary without importing production reconcile modules. |
| `Positive controls` | Nine actual/reference cases with exactly two fixed points; four schedules converging to the exact three-object inventory; four same-seed and POR controls; one changed-seed control; token and reservation races; four formal links; and the present-observation delete twin. |
| `Paired negatives` | Reachable versus unreachable observation, present versus unreachable deletion witness, same versus changed seed, first token use versus reuse, and retained reservation versus every crash cut are checked at exact properties. |
| `Mutants` | Four Cabal flags change production fixed-point, apply convergence, token reuse, and reservation crash behavior and must fail at `FixedPoint`, `Convergence`, `NoTokenReuse`, and `BoundRetainedAfterCrash`; the fifth weakens the production delete constructor and is killed when the unreachable witness compiles. |
| `Discovery` | The acquired source snapshot must equal the exact three production and four oracle/harness `.hs` paths in both directions; empty, missing, or extra discovery fails. |
| `Challenge` | The production mutation matrix and changed-seed schedule are evaluated after source acquisition; each exact property must change while the clean controls remain green. |
| `Observer` | The supervisor retains absolute executable, argv, exit, stdout/stderr, and digest observations for Cabal version, each production mutant, the delete pair, and the clean run. |
| `Authority/bypass` | Authority is limited to the exact Cabal/compiler/store paths and run root; every build is offline and serial. `pb`, network, host, container, cluster, service, and hardware arguments are forbidden. |
| `Freshness` | One unique `.build/runs/phase-19/work/candidate-*` root is acquired; the clean result is regenerated there and opening/closing Git source identities must match. |
| `Qualification` | The supervisor first kills all five changed-production mutations at exact loci, then requires the legal delete twin and clean independent corpus to pass. |
| `Cleanroom` | The authenticated source repository cache is copied beneath the unique run root, Cabal builds there, and the clean generated result must exist only below that root. |
| `Legacy closure` | The four JSON schedules, five serialized TSV/surface authorities, and test-local mutant module are absent; reintroduction is an exact failure. |
| `Predecessor` | Exact durable `ImmediatePredecessorPass` for Phase 18 on the current source snapshot; absent, stale, replayed, or different-source evidence fails. |
| `Residue` | Modeled environment fidelity is `ASSUMED`; effectful runtime, host, service, cluster, and hardware correspondence remain `UNVERIFIED` and later-phase-owned. |
| `Pass criterion` | Every one of the eighteen rows passes in one qualified run for the exact source; that complete pass is sufficient for the mechanical status-only transition. |

## Doctrine adopted

- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits): the target may seek same-seed replay and bounded-POR evidence over a modeled environment; no such evidence is currently accepted.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): the target Haskell decision core must consume three-valued observation and fail closed on unreachable state.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): linking tested code properties to invariant names does not prove runtime correspondence.
- [`resource_capacity_doctrine.md` §10 — Planning ownership](../documents/engineering/resource_capacity_doctrine.md#10-planning-ownership): an active reservation remains one debit across binding and recovery.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 19.1: Pure typed decision core ✅

**Status**: Done
**Implementation**: `src/reconcile-core/Amoebius/Reconcile/Core.hs`; typed observations and actions, total planner, fixed points, and production mutation loci.
**Blocked by**: [Phase 18](phase_18_dsl_formal_model.md) gate pass
**Independent Validation**: Nine exact actual/reference rows, two fixed points, and the present/unreachable compile pair.
**Oracle**: `test/spec/reconcile/ReconcileCoreOracle.hs`; `test/harness/reconcile_core/ReferencePlanner.hs`.
**Legacy IDs**: Phase-local legacy closure for the retired core/schedule TSV/JSON declarations and test-local mutant.
**Docs to update**: `cluster_lifecycle_doctrine.md`; `system_components.md`.

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 19.2: Four deterministic reconcile schedules ✅

**Status**: Done
**Implementation**: `src/reconcile-core/Amoebius/Reconcile/Sim.hs`; four schedule values, versioned snapshot tokens, and bounded deterministic execution.
**Blocked by**: Sprint 19.1
**Independent Validation**: Exact final inventories and transition counts, two fresh same-seed readings, changed-seed order, and four bounded POR runs.
**Oracle**: `test/spec/reconcile/ReconcileCoreOracle.hs`; `test/spec/reconcile/ReconcileCoreSimulationSpec.hs`.
**Legacy IDs**: Phase-local legacy closure for the retired four JSON schedule fixtures and schedule-outcome TSV.
**Docs to update**: `deterministic_simulation_doctrine.md`; `system_components.md`.

### Objective

Run the actual core against a bounded versioned store under four named schedules and retain deterministic,
convergent semantic evidence without committing trace bytes.

### Deliverables

- Baseline, duplicate, crash-before-apply, and stale-snapshot fixtures.
- Exact modeled final inventory and accepted/rejected transition counts.
- Four same-seed controls, one changed-seed control, and four bounded POR runs.

### Validation

1. Require all four schedules to converge to the exact three-object inventory within their authored bound.
2. Compare only two fresh same-seed encodings; traces remain run-local beneath `.build/**`.
3. Require a changed seed to change semantic action order.
4. Require every bounded POR replay to converge.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 19.3: Protocol correspondence and sealed gate ✅

**Status**: Done
**Implementation**: `src/reconcile-core/Amoebius/Reconcile/Sim.hs`; `src/execution-accelerator-folds/Amoebius/Capacity/Scheduler.hs`; package-hidden `Amoebius.Validation.ReconcileCoreRun.Internal`.
**Blocked by**: Sprint 19.2
**Independent Validation**: Concurrent token and reservation controls, three recovery cuts, four exact formal links, five production mutations, source discovery, containment, and acquired evidence.
**Oracle**: `test/spec/reconcile/ReconcileCoreOracle.hs`; typed deletion witness in `test/negative/compile_fail/reconcile_core/DeleteWitnessCompile.hs`.
**Legacy IDs**: Phase-local legacy closure for all ten retired Phase-19 behavioral paths.
**Docs to update**: `resource_capacity_doctrine.md`; `formal_model_doctrine.md`; `system_components.md`.

### Objective

Exercise one-use and one-debit protocol behavior in code, link it honestly to the formal vocabulary, and seal
the bounded result with mutation and repository-hygiene evidence.

### Deliverables

- One concurrent token race and one concurrent reservation CAS.
- Three actual scheduler recovery cuts reaching `Bound` with one retained debit.
- Four formal-invariant links and five exact mutants.
- Thirteen metrics, 21-surface/23-item join, ledger, containment, write guard, and exact run binding.

### Validation

1. Require exactly one accepted token use and exactly one reuse rejection.
2. Require one reservation debit and `Bound` recovery across all three crash cuts.
3. Resolve all four correspondence rows against actual Phase-18 model/invariant names.
4. Require every mutant to redden its authored property and no generic failure token.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `cluster_lifecycle_doctrine.md` — record the pure core, typed delete witness, and exact tested boundary.
- `deterministic_simulation_doctrine.md` — record the four Phase-19 schedules and dynamic trace control.
- `resource_capacity_doctrine.md` — record the one-debit/three-crash-cut reservation evidence.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile order, evidence, and
  implementation paths; update the reader-facing `legacy_tracking_for_deletion.md` explanation only after the
  corresponding typed Haskell byte-expectation binding closes.

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
