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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md
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

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 12, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-13 semantic and resource payloads,
package-hidden serial supervisor, Haskell semantic oracle, run-local fake SMT boundary, and three
changed-production subjects are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The Haskell checker totally classifies the supported boolean/QF-LIA fragment through full-conjunction base/step induction and preserves unsupported or inconclusive outcomes. |
| `Subject` | `Amoebius.Checker.Symbolic` is acquired only through package-hidden `Amoebius.Validation.SymbolicCheckerRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 13`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `SymbolicCheckerSpec.hs` owns seven exact symbolic/explicit relation rows and drives a separately authored Haskell SMT semantic boundary without reading behavioral data. |
| `Positive controls` | Seven fixtures cover inductive, base-failure, step-failure, conservative non-induction, coupled invariants, booleans, and unsupported theory. |
| `Paired negatives` | Absolute solver injection is paired with relative-path refusal; positive induction is paired with base, step, conservative, and unsupported classifications. |
| `Mutants` | Conjoined-hypothesis deletion, guard negation, and satisfiable-step acceptance compile as changed production subjects and turn assigned oracle loci red. |
| `Discovery` | The production checker, independent oracle, and fake SMT boundary equal the fixed three-file source inventory bidirectionally. |
| `Challenge` | All three mutations execute after acquisition and must be distinguished by independent status observations. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, PATH solver lookup, host packages, network, hardware, live services, imports of other checker algorithms, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-13/work/**` root and requires equal opening/closing source identities. |
| `Qualification` | Clean controls, result-class negatives, exact discovery, contained fake execution, and all three changed-production subjects pass together. |
| `Cleanroom` | Fake solver, binaries, objects, transcripts, and results are generated lazily beneath the fresh run root. |
| `Legacy closure` | Retired Phase-13 serialized behavioral oracles and Python verdict gate are absent. |
| `Predecessor` | Consume exactly one durable Phase-12 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Refinement, reusable compile-fail machinery, simulation, concrete models, runtimes, live effects, and hardware remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-thirteen-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

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

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 13.1: Total symbolic boundary and inductive obligations ✅

**Status**: Done
**Implementation**: `src/symbolic-checker/Amoebius/Checker/Symbolic.hs`
**Blocked by**: [Phase 12](phase_12_explicit_state_checker.md) gate pass
**Independent Validation**: seven exact symbolic/explicit rows, fourteen obligations, three witnesses, three counterexamples, and unsupported classification
**Oracle**: `test/spec/formal/symbolic/SymbolicCheckerSpec.hs` with `FakeSmtSolver.hs` as the independent run-local decision boundary
**Legacy IDs**: none; retired Phase-13 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Adopt the symbolic proof-stack choice: own a small translation over the corpus's model language, inject a
dynamically resolved solver, and classify every input without promoting unsupported syntax or `unknown`.

### Deliverables

- Absolute-path `Solver` construction with no ambient executable discovery.
- Total `SymbolicResult`: `Inductive`, `NotInductive`, `Unsupported`, or `Inconclusive`.
- Sort inference and SMT-LIB emission for boolean/QF linear-integer expressions.
- Simultaneous action transition equations and full-conjunction one-step induction.
- Base/step counterexamples and successful obligation/query-digest witnesses.
- An authored version-capture pattern so `Z3 version 5.1.0` records `5.1.0`, not the digit in its name.

### Validation

1. Reject relative or non-executable solver paths.
2. Require exact base and step results from the authored oracle.
3. Require all induction witnesses to cover their declared obligation count with valid query digests.
4. Preserve satisfying solver models in every symbolic counterexample.
5. Compile with incomplete-pattern warnings as errors and reject partial/ambient-read tokens in the library.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 13.2: Solver differential and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/SymbolicCheckerRun/Internal.hs`
**Blocked by**: Sprint 13.1
**Independent Validation**: serialized fake/clean/three-mutant compiler matrix, exact red loci, source discipline, discovery, and containment
**Oracle**: the same Haskell semantic oracle; solver/result bytes are observations only
**Legacy IDs**: none; retired Phase-13 serialized oracles and Python gate are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Adopt independent correspondence and proof-failure honesty: compare only overlapping claims, retain the
expected conservative gap, and demonstrate sensitivity to hypotheses, guards, and solver classification.

### Deliverables

- Seven exact symbolic/explicit expectations and 14 declared proof obligations.
- Five explicit-state agreements, one conservative non-inductive case, and one unsupported-theory case.
- Three induction witnesses and three solver-backed counterexamples.
- Registry-backed conjoined-hypothesis, guard-polarity, and satisfiable-step-acceptance mutants.
- Eleven result metrics, 21 authored surfaces/23 run-time items, a machine-derived Register-1 ledger,
  containment, write guard, natural-architecture record, and exact source-bound run record.

### Validation

1. Compare every symbolic, explicit, relation, and obligation observation to its independently authored row;
   reject a run without the complete suite token.
2. Require digest and safety-class agreement on all five overlapping fixtures.
3. Require the safe-but-non-inductive fixture to remain explicitly conservative.
4. Compile the hypothesis, polarity, and satisfiable-step defects separately; each must redden only its named
   fixture field.
5. Join every run-time item to one authored surface and keep runtime fidelity `UNVERIFIED`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `formal_model_doctrine.md` — settle the symbolic ownership choice and record the supported-theory,
  induction, solver, and model/runtime premises.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  lane, implementation paths, dynamically resolved solver, and evidence.
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
