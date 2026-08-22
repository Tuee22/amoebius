# Phase 12: The amoebius explicit-state checker

> **Purpose**: Deliver an amoebius-owned bounded explicit-state checker over the Phase-11 `Model`, with
> replayable minimal counterexamples and verdicts bound to the checked model and search bound.
> **Read this if**: a finite model has to be checked without delegating frontier semantics to another checker,
> or the exact reach of the resulting Register-1 evidence must be understood.

This phase owns the independent breadth-first checking algorithm and its bounded-verdict evidence. It consumes
the Phase-11 model/interpreter semantics but does not call that phase's explorer; it does not claim liveness,
unbounded induction, code refinement, or runtime fidelity.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 12.1: Independent bounded checker and replayable verdicts ✅](#sprint-121-independent-bounded-checker-and-replayable-verdicts-)
- [Sprint 12.2: Differential oracle and mutation evidence ✅](#sprint-122-differential-oracle-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All twelve gate sides passed on natural `arm64`, untranslated: 10 metrics
matched, all three mutants were red at their own loci, and 18 surfaces joined to 21 enumerated items.
Attestation `sha256:a3c020f5fabd75e5a96295fb4895694852b102e0ac16bff95af92d9f0215761e` binds source
`sha256:8c15e647c970372c…` over 2,163 files. Repository-conformance and documentation support gates passed on
that same snapshot.

## Phase Summary

`Amoebius.Checker.ExplicitState` independently breadth-first searches the Phase-11 `Model` fragment. A private
positive `SearchBound` makes the boundary convention explicit. The result distinguishes safe completion,
invariant/deadlock counterexamples, and frontier exhaustion; each verdict records the checker-local model
digest, declared bound, distinct-state count, and result. Counterexample steps bind their source and target
fingerprints and can be replayed through `interpret`.

**Phase scope:** One bounded explicit-state algorithm and one independent correspondence gate; split if work
adds liveness, symbolic induction, refinement checking, a production protocol model, or runtime simulation.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the closed `Model`, interpreter semantics, and
reference explorer against which the separately implemented checker is compared.
**Gate:** `python3 tools/run_phase_gate.py 12` passes the hand-enumerated verdict oracle, bounded BFS
and replay suite, Phase-11 explorer parity, three build mutants at specific loci, generated-result discipline,
surface join, ledger, containment, write guard, natural architecture, and source-bound attestation.

## Gate integrity

- **Representative set:** seven authored fixtures cover an eight-state branching model at the exact bound,
  the same model one state below the bound, safe and unsafe counters, an initial deadlock, a constrained
  frontier, and a parameterized branch. Their outcomes cover all four result classes.
- **Independent oracle:** `test/oracle/explicit_state_checker/models.tsv` fixes each fixture's bound, verdict
  class, exact distinct-state count, violation name, and trace length. Those finite state spaces were
  hand-enumerated; generated checker output is not used as its own expectation.
- **Independent frontier:** the checker lives in a dedicated-root sublibrary, consumes the `formal-model`
  public API, and may import interpreter semantics but not `Amoebius.Formal.Explore`. A source check enforces
  that boundary and rejects partial or ambient-read tokens in the checker module.
- **Differential:** the Phase-11 explorer and the Phase-12 checker agree on state count and invariant verdict
  for the five fixtures where their contracts overlap. Bound exhaustion and deadlock are checked directly
  because the reference explorer does not expose those Phase-12 result classes.
- **Counterexample validity:** both unsafe verdicts replay to the reported terminal fingerprint. A forged
  target fingerprint must fail specifically as `TraceReplayFailure`, so an event list alone cannot masquerade
  as a trace for another state.
- **Seeded defects:** three real Cabal/CPP builds widen every action guard, skip invariant checking, or retain
  only one successor per frontier node. Each must fail at its registry-declared fixture/field locus.
- **Verdict identity:** the checker-local SHA-256 digest changes with the complete reified model constructor
  tree and is recorded with the bound and result. It is evidence identity, not a content-addressed artifact
  name, a general-scope proof, or a protocol compatibility identifier.
- **Generated-artifact discipline:** the suite rewrites `.build/checkers/explicit-state/results.tsv`; the gate
  compares all ten metrics to authored values and requires the result to remain outside the source snapshot.
- **Honesty boundary:** finite-scope invariant/deadlock claims are proven-for-the-model; algorithmic parity,
  trace replay, and mutation sensitivity are tested. Liveness, unbounded scope, intended-protocol fidelity,
  and running-code fidelity remain `UNVERIFIED`.
- **Observer controls:** this is a deterministic pure checker over authored values, with no authority endpoint
  or live service. Nonces, authenticated observers, bypass attempts, and authority pairs are not applicable;
  the independent instruments are the hand oracle and the separately implemented Phase-11 explorer.
- **Extension conformance (§M.13).** Not applicable: this phase delivers proof infrastructure, not an extension
  declaration, provider/hardware domain, or extension-conformance verdict.

The gate establishes a bounded checker whose own frontier is sensitive to the named defect families. It does
not prove that the hand-authored model is the intended protocol or that all possible checker defects have been
enumerated.

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): the checker consumes the same total interpreter semantics without reusing the explorer frontier.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): checker/explorer parity is stated over the same reified model value.
- [`formal_model_doctrine.md` §6 — What a green model-check proves](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): the bound and model-fidelity limits remain explicit.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the first checker layer has an amoebius-owned implementation and evidence boundary.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): all run-time metrics, checks, and mutants join to the independently authored Phase-12 surface expectation.

## Sprints

## Sprint 12.1: Independent bounded checker and replayable verdicts ✅

**Status**: Done
**Implementation**: `lib:explicit-state-checker`,
`src/explicit-state-checker/Amoebius/Checker/ExplicitState.hs`, and the three
`explicit-state-{widens-action-guard,skips-invariant,truncates-frontier}-mutant` Cabal flags.
**Blocked by**: None.
**Independent Validation**: The dedicated checker source is rejected if it imports the Phase-11 explorer;
the seven-model result oracle and replay checks exercise its public API directly.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

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

None.

## Sprint 12.2: Differential oracle and mutation evidence ✅

**Status**: Done
**Implementation**: `test/spec/formal/explicit/ExplicitStateCheckerSpec.hs`,
`test/oracle/explicit_state_checker/**`, `test/oracle/explicit_state_checker_surfaces.tsv`,
`test/mutant/registry.tsv`, and `tools/explicit_state_checker_gate.py`.
**Blocked by**: Sprint 12.1's independent checker API.
**Independent Validation**: Hand-authored model outcomes are compared both with Phase-12 observations and,
where contracts overlap, with the separately implemented Phase-11 explorer.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,legacy_tracking_for_deletion,system_components}.md`.

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

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
