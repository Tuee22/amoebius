# Phase 13: The amoebius symbolic checker

> **Purpose**: Specify the target Haskell capability to classify the supported Phase 11 model
> fragment through a Haskell-owned SMT translation and induction schema, with any SMT-LIB or solver
> products generated only beneath `.build/**` and no shell or Python verdict.
> **Read this if**: a finite-state search bound must be replaced by an inductive safety argument, or the exact
> limits of the symbolic result must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 13.1: Total symbolic boundary and inductive obligations](#sprint-131-total-symbolic-boundary-and-inductive-obligations-)
- [Sprint 13.2: Solver differential and mutation evidence](#sprint-132-solver-differential-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

✅ Done.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-12 predecessor and its compatible evidence chain.

## Phase Summary

The audit found both a semantic translation error and an unsound qualification oracle: parameter/state shadowing differed between runtime and SMT, while the fake solver reported unsatisfiability after finite sampling. This phase must establish actual symbolic observations over its admitted theory with authenticated offline solver input. It does not turn a checker capability into a proof of every production DSL function.

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to classify the supported Phase 11 model fragment through a Haskell-owned SMT
translation and induction schema, with any SMT-LIB or solver products generated only beneath
`.build/**` and no shell or Python verdict.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — classify the supported Phase 11 model fragment through a
Haskell-owned SMT translation and induction schema, with any SMT-LIB or solver products generated
only beneath `.build/**` and no shell or Python verdict. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 12](phase_12_explicit_state_checker.md)
**Gate:** `pb validate phase 13`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | The Haskell checker translates the admitted boolean/QF-LIA fragment with the same bindings and transitions as the runtime and discharges full-conjunction base/step obligations through an authenticated complete SMT solver; unsupported, failure and unknown outcomes remain non-proofs. |
| `Subject` | `Amoebius.Checker.Symbolic` is acquired only through package-hidden `Amoebius.Validation.SymbolicCheckerRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 13`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `test/spec/formal/symbolic/SymbolicCheckerSpec.hs` independently owns formula meaning, known satisfying assignments, invariant classifications, and explicit-state comparisons. `FakeSmtSolver.hs` is a protocol/fault control only and cannot certify integer unsatisfiability. |
| `Positive controls` | Use source-bound formulas with independently established inductive invariants and satisfying witnesses beyond any finite sampling domain; compare emitted obligations, runtime transitions and a pinned real SMT engine. |
| `Paired negatives` | Admitted models are paired with the same-name parameter/state audit case, satisfiable base/step obligations, unsupported theory, solver error/unknown/truncation/nonzero exit and substituted solver identity; each result has a specific reason. |
| `Mutants` | Retain conjoined-hypothesis deletion, guard negation and sat-step acceptance; add binder-precedence change, sample-exhaustion-as-unsat and ignored-solver-failure subjects, each assigned to an independently literal exact-case oracle. |
| `Discovery` | Reconcile the admitted model/translation constructor universe, oracle cases, exact solver input identity, protocol fault controls, and all production/build/selector assignments in both directions. |
| `Challenge` | All three mutations execute after acquisition and must be distinguished by independent status observations. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | Before bootstrap handoff, invoke only the exact Haskell supervisor and authenticated absolute compiler/solver inputs, offline and serially. No network, bootstrap transport, live host effect or hardware discovery is admitted. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-13/work/**` root and requires equal opening/closing source identities. |
| `Qualification` | Run real solver observations, independent formula witnesses, runtime/translation binding comparisons, fault-protocol controls and every assigned changed subject together. A bounded fake emitting `unsat` cannot qualify a proof. |
| `Cleanroom` | The authenticated solver and compiler inputs are available without acquisition from the network; generated queries, process receipts and products remain beneath the unique run root. |
| `Legacy closure` | Retired Phase-13 serialized behavioral oracles and Python verdict gate are absent. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 12 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | SMT engine correctness remains an explicitly named trusted assumption; unsupported theories, concrete DSL-model obligations, production source refinement, simulation and live fidelity retain their separate owners. |
| `Pass criterion` | `qualified-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Resource provision

Phase 13 owns one run-local Haskell fake SMT process beneath `.build/runs/phase-13/**`. Preflight requires its
fresh source-bound compilation and absolute executable path. Allowed mutations are stdin SMT-LIB queries and
process execution inside that run root; network, package installation, PATH discovery, host tools, writes
outside the run root, and compiler overlap are forbidden. The parent Haskell supervisor observes compiler and
oracle process exits, argv, streams, and digests, retains only contained generated evidence, and reports zero
owned external residue.

## Doctrine adopted

- [`formal_model_doctrine.md` §2 — The `Model` is data](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data): symbolic obligations consume the same closed constructor tree as the other readings.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): the target requires independently authored `.hs` overlap fixtures that compare checker results over identical model digests.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): induction reach and solver/model premises remain explicit.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): Haskell must own translation, induction, and the verdict; a dynamically resolved solver may only return raw formula observations through lazy `.build/**` products.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): every metric, check, and mutant joins to one authored Phase-13 surface.

## Sprints

The sprint requirements below remain part of the target acceptance scope. Each owner must bind them in
Haskell and qualify the mechanism that first admits their result; component observations cannot close a sprint.

## Sprint 13.1: Total symbolic boundary and inductive obligations ✅

**Status**: Done
**Implementation**: `src/symbolic-checker/Amoebius/Checker/Symbolic.hs`
**Blocked by**: [Phase 12](phase_12_explicit_state_checker.md) gate pass
**Independent Validation**: Match an independently authored inductive model and its formula obligations; reject the audit shadowing counterexample or classify its reachable violation consistently; kill binding and induction-schema mutants at assigned cases; name SMT correctness as a trust assumption.
**Oracle**: `test/spec/formal/symbolic/SymbolicCheckerSpec.hs` with `FakeSmtSolver.hs` as the independent run-local decision boundary
**Legacy IDs**: none; retired Phase-13 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Adopt the symbolic proof-stack choice: own a small translation over the corpus's model language, inject a
dynamically resolved solver, and classify every input without promoting unsupported syntax or `unknown`.

### Deliverables

- Use the Phase-11 binding policy in translation. Variable, parameter and constant environments cannot apply a different precedence from executable interpretation.
- Bind each complete SMT response, exact executable identity, argv, query bytes, exit and stderr to the owning obligation; unknown, malformed/truncated response and failing process outcomes never mint induction evidence.

- Absolute-path `Solver` construction with no ambient executable discovery.
- Total `SymbolicResult`: `Inductive`, `NotInductive`, `Unsupported`, or `Inconclusive`.
- Sort inference and SMT-LIB emission for boolean/QF linear-integer expressions.
- Simultaneous action transition equations and full-conjunction one-step induction.
- Base/step counterexamples and successful obligation/query-digest witnesses.
- An authored version-capture pattern so `Z3 version 5.1.0` records `5.1.0`, not the digit in its name.

### Validation

- Retain the model with state `x = 0`, parameter `x` drawn from `{1}`, update `x := x`, and invariant `x == 0`. Either model admission rejects shadowing consistently or explicit and symbolic outcomes both expose the transition to one; `Inductive` is forbidden when the runtime violates the invariant.
- Check conjunction, initialization, unchanged variables and every admitted expression translation against authored formula meanings and real solver observations, rather than emitted substrings.

1. Reject relative or non-executable solver paths.
2. Require exact base and step results from the authored oracle.
3. Require all induction witnesses to cover their declared obligation count with valid query digests.
4. Preserve satisfying solver models in every symbolic counterexample.
5. Compile with incomplete-pattern warnings as errors and reject partial/ambient-read tokens in the library.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Sprint 13.2: Solver differential and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/SymbolicCheckerRun/Internal.hs`
**Blocked by**: Sprint 13.1
**Independent Validation**: A pinned authenticated SMT executable accepts known formulas and finds independently known witnesses outside sample bounds; exact unknown/error/identity pairs refuse; sampled-unsat and ignored-exit mutants fail their assigned cases; broader theories remain excluded.
**Oracle**: the same Haskell semantic oracle; solver/result bytes are observations only
**Legacy IDs**: none; retired Phase-13 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Adopt independent correspondence and proof-failure honesty: compare only overlapping claims, retain the
expected conservative gap, and demonstrate sensitivity to hypotheses, guards, and solver classification.

### Deliverables

- Acquire the real SMT executable from authenticated, network-independent toolchain input before candidate execution, with bounded process resources and complete observation custody.
- Restrict the Haskell fake SMT process to deterministic protocol and error-injection controls. Exhausting a finite search domain is an inconclusive sample result, never an integer-theory `unsat` proof.

- Seven exact symbolic/explicit expectations and 14 declared proof obligations.
- Five explicit-state agreements, one conservative non-inductive case, and one unsupported-theory case.
- Three induction witnesses and three solver-backed counterexamples.
- Registry-backed conjoined-hypothesis, guard-polarity, and satisfiable-step-acceptance mutants.
- Eleven result metrics, 21 authored surfaces/23 run-time items, a machine-derived Register-1 ledger,
  containment, write guard, natural-architecture record, and exact source-bound run record.

### Validation

- The formula `x = 100 + 100` must be satisfiable with witness `x = 200`. Add arithmetic witnesses outside literal-neighbor domains and ensure the historical fake result cannot enter a proof receipt.
- Run each supported theory obligation through the real solver; independently replay satisfying witnesses and refuse unexpected solver exits, missing answers, stale responses or executable substitutions.

1. Compare every symbolic, explicit, relation, and obligation observation to its independently authored row;
   reject any missing acquired case observation even if a complete suite token is printed.
2. Require digest and safety-class agreement on all five overlapping fixtures.
3. Require the safe-but-non-inductive fixture to remain explicitly conservative.
4. Compile the hypothesis, polarity, and satisfiable-step defects separately; each must redden only its named
   fixture field.
5. Join every run-time item to one authored surface and keep runtime fidelity `UNVERIFIED`.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `formal_model_doctrine.md` — settle the symbolic ownership choice and record the supported-theory,
  induction, solver, and model/runtime premises.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  lane, implementation paths, authenticated offline solver input, and evidence.
- `DEVELOPMENT_PLAN/phase_14_refinement_checker.md` — open only after this phase seals; its code-refinement
  claim remains independent of the model-checking algorithms.

## Related Documents

- [Development Plan Standards](development_plan_standards.md), [Gate Integrity](development_plan_gate_integrity.md), and [Phase Model](development_plan_phase_model.md) — phase/gate rules.
- [Development Plan Tracker](README.md), [Overview](overview.md), [Substrates](substrates.md), and [System Components](system_components.md) — order, lane, and implementation inventory.
- [Phase 11](phase_11_formal_model_kernel.md) — the model constructor tree translated here.
- [Phase 12](phase_12_explicit_state_checker.md) — the independent bounded reading used only by the test differential.
- [Phase 14](phase_14_refinement_checker.md) — the implementation-refinement layer that follows in numeric order.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the proof-stack and honesty boundary.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register-1 placement and the no-live-infrastructure boundary.
