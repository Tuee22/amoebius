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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 19.1: Pure typed decision core ⏸️](#sprint-191-pure-typed-decision-core-)
- [Sprint 19.2: Four deterministic reconcile schedules ⏸️](#sprint-192-four-deterministic-reconcile-schedules-)
- [Sprint 19.3: Historical protocol/gate work ⏸️](#sprint-193-protocol-correspondence-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 18, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to plan from observed inventory to desired index with a pure Haskell decision
core and exercise fixed-point, bounded-convergence, token, reservation, and three-valued-observation
behavior under deterministic modeled schedules.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to modeled Register-2 boundary behavior only. It cannot
use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — plan from observed inventory to desired index with a pure
Haskell decision core and exercise fixed-point, bounded-convergence, token, reservation, and
three-valued-observation behavior under deterministic modeled schedules. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 2 — Haskell behavior against modeled boundaries only; no live correspondence claim. NOT VALIDATED.

**Depends on:** [Phase 18](phase_18_dsl_formal_model.md)
**Gate:** `pb validate phase 19`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — plan from observed inventory to desired index with a pure Haskell decision core and exercise fixed-point, bounded-convergence, token, reservation, and three-valued-observation behavior under deterministic modeled schedules. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 19` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 18; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits): the target may seek same-seed replay and bounded-POR evidence over a modeled environment; no such evidence is currently accepted.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): the target Haskell decision core must consume three-valued observation and fail closed on unreachable state.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): linking tested code properties to invariant names does not prove runtime correspondence.
- [`resource_capacity_doctrine.md` §10 — Planning ownership](../documents/engineering/resource_capacity_doctrine.md#10-planning-ownership): an active reservation remains one debit across binding and recovery.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 19.1: Pure typed decision core ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 18](phase_18_dsl_formal_model.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

## Sprint 19.2: Four deterministic reconcile schedules ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 19.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

## Sprint 19.3: Protocol correspondence and sealed gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 19.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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
