# Phase 16: Deterministic-simulation substrate

> **Purpose**: Specify the target Haskell capability to execute one polymorphic Haskell reconcile
> program under deterministic modeled effects and fault schedules while making no claim of
> live-substrate fidelity.
> **Read this if**: a concurrent reconciler needs deterministic schedule evidence, or a modeled trace must be
> distinguished from live-system proof.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 16.1: Polymorphic environment and interpreters ⏸️](#sprint-161-polymorphic-environment-and-interpreters-)
- [Sprint 16.2: Modeled contracts and semantic schedules ⏸️](#sprint-162-modeled-contracts-and-semantic-schedules-)
- [Sprint 16.3: Determinism, exploration, and mutation ⏸️](#sprint-163-determinism-exploration-and-mutation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 15, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to execute one polymorphic Haskell reconcile program under deterministic
modeled effects and fault schedules while making no claim of live-substrate fidelity.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to modeled Register-2 boundary behavior only. It cannot
use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — execute one polymorphic Haskell reconcile program under
deterministic modeled effects and fault schedules while making no claim of live-substrate fidelity.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 2 — Haskell behavior against modeled boundaries only; no live correspondence claim. NOT VALIDATED.

**Depends on:** [Phase 15](phase_15_compile_fail_harness.md)
**Gate:** `pb validate phase 16`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — execute one polymorphic Haskell reconcile program under deterministic modeled effects and fault schedules while making no claim of live-substrate fidelity. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 16` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 15; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`deterministic_simulation_doctrine.md` §2 — The io-classes environment abstraction — build it pure, lift it whole](../documents/engineering/deterministic_simulation_doctrine.md#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole): one program is interpreted under `IO` and `IOSim`.
- [`deterministic_simulation_doctrine.md` §3 — The simulated environment and its fault model](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model): the six modeled interfaces carry typed fault controls.
- [`deterministic_simulation_doctrine.md` §5 — What DST establishes, and the one premise it buys](../documents/engineering/deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys): modeled-schedule evidence is tested while environmental fidelity stays assumed.
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits): the target contract is Register 2 modeled behavior only; the current gate is rejected and no Register-2.5 or live claim is admitted.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 16.1: Polymorphic environment and interpreters ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 15](phase_15_compile_fail_harness.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 16.2: Modeled contracts and semantic schedules ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 16.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Make modeled faults and the composition-to-reconcile boundary observable as semantic facts rather than
implementation snapshots.

### Deliverables

- Six Haskell fake-contract values with enabled/disabled fault controls.
- Four checked Haskell schedules spanning all typed axes and four separately authored Haskell invariant
  expectations. JSON schedule projections are generated only beneath `.build/**`.
- Focused-package adapter that constructs the real five-calculus composition.
- Semantic projection oracle over ordered kinds/names, exact resources, emitted commands, and outcome.

### Validation

1. Require the exact schedule corpus, names, typed fault fields, and axis coverage.
2. Require all four authored outcomes to be `Upheld` under the reference program.
3. Require the exact five semantic projection facts and reject any missing or changed row.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 16.3: Determinism, exploration, and mutation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 16.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Show that explored modeled faults are reproducible and that the gate rejects a missing partition response.

### Deliverables

- Same-seed encoded-trace equality over all four schedules.
- One changed-seed inequality control and four bounded `IOSimPOR` checks.
- Registry-backed dropped-partition mutant red at `NoActOnStaleRead`.
- Ten exact metrics, complete run-time surface join, ledger, containment, and exact run binding.

### Validation

1. Replay every schedule twice and compare both outcome and encoded trace.
2. Perturb the partition schedule seed and require a different trace.
3. Bound POR exploration explicitly and require `Upheld` for every observed result.
4. Run the mutant independently and require its exact invariant token and non-zero status.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

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
