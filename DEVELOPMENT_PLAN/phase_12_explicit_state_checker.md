# Phase 12: The amoebius explicit-state checker

> **Purpose**: Specify the target Haskell capability to perform bounded explicit-state search over
> the Phase 11 Haskell model with deterministic replay and counterexample products generated only
> beneath `.build/**`.
> **Read this if**: a finite model has to be checked without delegating frontier semantics to another checker,
> or the exact reach of the resulting Register-1 evidence must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
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
- [Sprint 12.1: Independent bounded checker and replayable verdicts](#sprint-121-independent-bounded-checker-and-replayable-verdicts-)
- [Sprint 12.2: Differential oracle and mutation evidence](#sprint-122-differential-oracle-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 11, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

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
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — perform bounded explicit-state search over the Phase 11
Haskell model with deterministic replay and counterexample products generated only beneath
`.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 11](phase_11_formal_model_kernel.md)
**Gate:** `pb validate phase 12`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-12 semantic payload, package-hidden serial
supervisor, independent Haskell oracle, generated-result containment check, and three changed-production
subjects are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The pure Haskell checker performs bounded BFS over the shared model, returns all four verdict classes with exact distinct-state counts, and produces replayable minimal counterexamples. |
| `Subject` | `Amoebius.Checker.ExplicitState` is acquired only through package-hidden `Amoebius.Validation.ExplicitStateCheckerRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 12`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `ExplicitStateCheckerSpec.hs` owns seven hand-enumerated verdict/count rows, five explorer-parity rows, and two counterexample replays without reading behavioral data. |
| `Positive controls` | Seven fixtures cover safe, invariant-unsafe, deadlock-unsafe, bound-exceeded, constrained, and branching behavior with exact outcomes. |
| `Paired negatives` | Positive bounds are paired with zero/negative refusal, and authentic counterexample replay is paired with a forged-target rejection. |
| `Mutants` | Guard widening, invariant skipping, and frontier truncation compile as changed production subjects and turn the unchanged oracle red at assigned loci. |
| `Discovery` | The production checker and independent Haskell oracle are discovered from the source snapshot and equal the fixed two-file inventory bidirectionally. |
| `Challenge` | All three mutations execute after source acquisition and must be distinguished by independent status or state-count observations. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, network, JVM, hardware, live services, compiler substitution, oracle imports of the Phase-11 explorer, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-12/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, paired negatives, trace replay, exact discovery, contained generation, and all three changed-production subjects pass together. |
| `Cleanroom` | Binaries, objects, transcripts, and the result observation are generated lazily beneath the fresh run root. |
| `Legacy closure` | Retired Phase-12 serialized behavioral oracles and Python verdict gate are absent. |
| `Predecessor` | Consume exactly one durable Phase-11 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Symbolic/refinement checking, reusable compile-fail machinery, simulation, concrete models, runtimes, live effects, and hardware remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-twelve-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): the target checker must consume the same total Haskell interpreter semantics without reusing the explorer frontier.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): checker/explorer parity is stated over the same reified model value.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): the bound and model-fidelity limits remain explicit.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the target first checker layer requires an amoebius-owned Haskell implementation and independent evidence boundary; neither is currently accepted.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): all run-time metrics, checks, and mutants join to the independently authored Phase-12 surface expectation.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 12.1: Independent bounded checker and replayable verdicts ✅

**Status**: Done
**Implementation**: `src/explicit-state-checker/Amoebius/Checker/ExplicitState.hs`
**Blocked by**: [Phase 11](phase_11_formal_model_kernel.md) gate pass
**Independent Validation**: seven exact fixture outcomes, five explorer-parity rows, two trace replays, and bound/digest negatives
**Oracle**: `test/spec/formal/explicit/ExplicitStateCheckerSpec.hs`, separately authored in Haskell against public production interfaces
**Legacy IDs**: none; retired Phase-12 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 12.2: Differential oracle and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/ExplicitStateCheckerRun/Internal.hs`
**Blocked by**: Sprint 12.1
**Independent Validation**: serialized clean/three-mutant compiler matrix, exact failure loci, source discipline, discovery, and containment
**Oracle**: the same Haskell semantic oracle; generated result bytes are observations only
**Legacy IDs**: none; retired Phase-12 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Adopt single-source correspondence and bounded-proof honesty: require exact finite outcomes, independent
checker parity, counterexample replay, and mechanism-specific mutation sensitivity in one contained gate.

### Deliverables

- Seven hand-enumerated model expectations covering four verdict classes and exact boundary behavior.
- Five explorer-parity comparisons and two replayed counterexamples.
- Registry-backed guard-widening, invariant-skip, and frontier-truncation build mutants.
- Ten result metrics, 18 authored surfaces/21 run-time items, a machine-derived Register-1 ledger, containment,
  write guard, natural-architecture record, and exact source-bound run record.

### Validation

1. Require exact equality with every oracle field and the suite acceptance token.
2. Require checker/explorer state-count and invariant-verdict parity on all five applicable fixtures.
3. Build each seeded mutant independently and require its exact declared locus to turn red.
4. Join every metric, check, and mutant to exactly one authored surface; retain runtime fidelity as
   `UNVERIFIED`.
5. Require generated-only results, closed project roots, an unchanged outside-host inventory, and a
   exact source-bound run record.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

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
