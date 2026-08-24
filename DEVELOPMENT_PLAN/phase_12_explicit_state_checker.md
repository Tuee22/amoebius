# Phase 12: The amoebius explicit-state checker

> **Purpose**: Specify the target Haskell capability to perform bounded explicit-state search over
> the Phase 11 Haskell model with deterministic replay and counterexample products generated only
> beneath `.build/**`.
> **Read this if**: a finite model has to be checked without delegating frontier semantics to another checker,
> or the exact reach of the resulting Register-1 evidence must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 12.1: Independent bounded checker and replayable verdicts ⏸️](#sprint-121-independent-bounded-checker-and-replayable-verdicts-)
- [Sprint 12.2: Differential oracle and mutation evidence ⏸️](#sprint-122-differential-oracle-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 11, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to perform bounded explicit-state search over the Phase 11 Haskell model with
deterministic replay and counterexample products generated only beneath `.build/**`.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — perform bounded explicit-state search over the Phase 11
Haskell model with deterministic replay and counterexample products generated only beneath
`.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 11](phase_11_formal_model_kernel.md)
**Gate:** `pb validate phase 12`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target capability only — perform bounded explicit-state search over the Phase 11 Haskell model with deterministic replay and counterexample products generated only beneath `.build/**`. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 12` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 11; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): the target checker must consume the same total Haskell interpreter semantics without reusing the explorer frontier.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): checker/explorer parity is stated over the same reified model value.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): the bound and model-fidelity limits remain explicit.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the target first checker layer requires an amoebius-owned Haskell implementation and independent evidence boundary; neither is currently accepted.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): all run-time metrics, checks, and mutants join to the independently authored Phase-12 surface expectation.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 12.1: Independent bounded checker and replayable verdicts ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 11](phase_11_formal_model_kernel.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt the amoebius-owned first proof-stack layer: implement bounded search independently over the shared
`Model`/`interpret` semantics and make every non-safe outcome explicit and replayable.

### Deliverables

- A private positive `SearchBound` and total `checkModel` API over well-formed `Model` values.
- Independently managed BFS frontier, constraints, expansion limits, invariants, and deadlock detection.
- Safe, unsafe, and bound-exhausted results with exact distinct-state accounting.
- Minimal BFS counterexamples whose steps carry source/event/target evidence.
- Verdict binding to the complete model constructor tree and declared search bound.

### Validation

1. Reject zero and negative bounds before search.
2. Match all four result classes and exact state counts in the seven-row oracle.
3. Replay every unsafe trace and reject a forged target at `TraceReplayFailure`.
4. Require a 64-hex-character model digest and observe it change when the model changes.
5. Compile with incomplete-pattern warnings as errors and reject partial/ambient reads in the library source.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 12.2: Differential oracle and mutation evidence ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 12.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt single-source correspondence and bounded-proof honesty: require exact finite outcomes, independent
checker parity, counterexample replay, and mechanism-specific mutation sensitivity in one contained gate.

### Deliverables

- Seven hand-enumerated model expectations covering four verdict classes and exact boundary behavior.
- Five explorer-parity comparisons and two replayed counterexamples.
- Registry-backed guard-widening, invariant-skip, and frontier-truncation build mutants.
- Ten result metrics, 18 authored surfaces/21 run-time items, a machine-derived Register-1 ledger, containment,
  write guard, natural-architecture record, and source-bound attestation.

### Validation

1. Require exact equality with every oracle field and the suite acceptance token.
2. Require checker/explorer state-count and invariant-verdict parity on all five applicable fixtures.
3. Build each seeded mutant independently and require its exact declared locus to turn red.
4. Join every metric, check, and mutant to exactly one authored surface; retain runtime fidelity as
   `UNVERIFIED`.
5. Require generated-only results, closed project roots, an unchanged outside-host inventory, and a
   source-bound attestation.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `formal_model_doctrine.md` — record the built explicit-state layer and preserve the finite/model-fidelity
  boundary.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  lane, implementation paths, and evidence.
- `DEVELOPMENT_PLAN/phase_13_symbolic_checker.md` — open only after this phase seals; retain its independent
  route from the Phase-11 kernel.

## Related Documents

- [Development Plan Standards](development_plan_standards.md), [Gate Integrity](development_plan_gate_integrity.md), and [Phase Model](development_plan_phase_model.md) — phase/gate rules.
- [Development Plan Tracker](README.md), [Overview](overview.md), [Substrates](substrates.md), and [System Components](system_components.md) — order, lane, and implementation inventory.
- [Phase 11](phase_11_formal_model_kernel.md) — the reified model and interpreter semantics consumed here.
- [Phase 13](phase_13_symbolic_checker.md) — the independent symbolic route that follows in numeric order.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the proof-stack and honesty boundary.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register-1 placement and the no-live-infrastructure boundary.
