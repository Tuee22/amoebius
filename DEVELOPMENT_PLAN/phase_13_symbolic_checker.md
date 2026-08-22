# Phase 13: The amoebius symbolic checker

> **Purpose**: Deliver an amoebius-owned SMT translation and induction schema over the supported Phase-11
> `Model` fragment, with explicit unsupported and inconclusive results outside a proved claim.
> **Read this if**: a finite-state search bound must be replaced by an inductive safety argument, or the exact
> limits of the symbolic result must be understood.

This phase owns QF linear-integer/boolean translation, base-and-step obligation construction, and proof
classification. It uses a dynamically resolved Z3 process as a decision procedure, but does not delegate the
checker or discover the solver through ambient `PATH`; it does not claim completeness, liveness, code
refinement, or runtime fidelity.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 13.1: Total symbolic boundary and inductive obligations ✅](#sprint-131-total-symbolic-boundary-and-inductive-obligations-)
- [Sprint 13.2: Solver differential and mutation evidence ✅](#sprint-132-solver-differential-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All twelve gate sides passed on natural `arm64`, untranslated: 11 metrics
matched, all three proof mutants were red at their own loci, and 21 surfaces joined to 23 enumerated items.
Attestation `sha256:4cf08cabb41f3c66082d6e7458d5299c2773103779c5a1628fe3aef2a46cb2c4` binds source
`sha256:0b10b77934700fda…` over 2,168 files. Repository-conformance and documentation support gates passed on
that same snapshot.

## Phase Summary

`Amoebius.Checker.Symbolic` translates the QF linear-integer/boolean subset of the shared `Model` to SMT-LIB.
For each named invariant it asks Z3 whether the initialized state violates the invariant, then whether the
conjunction of all invariants and each enabled action can lead to a violating successor. Unsatisfiable base
and step obligations produce an induction witness containing every obligation identity and query digest;
satisfiable obligations produce a solver-backed base or step counterexample. Unsupported model syntax and
solver `unknown` are first-class results, not proof successes.

**Phase scope:** One total symbolic-classification boundary, one QF_LIA/boolean induction schema, and one
solver/explicit-state correspondence gate; split if work adds a new SMT theory, invariant synthesis,
multi-step induction, liveness, implementation refinement, or a production protocol model.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the reified `Model` and interpreter semantics.
The implementation does not depend on Phase 12; the gate compares both independent readings where their
claims overlap.
**Gate:** `python3 tools/run_phase_gate.py 13` passes the hand-authored induction/relationship oracle,
absolute resolved-solver boundary, base/step proof suite, explicit-state comparison, three build mutants at
specific loci, generated-result discipline, surface join, ledger, containment, write guard, natural
architecture, and source-bound attestation.

## Gate integrity

- **Representative set:** seven authored models cover inductive success, initialization failure, reachable
  step failure, a reachable-safe but one-step-non-inductive invariant, a proof requiring conjoined invariants,
  a guard-sensitive boolean proof, and a set-valued model outside the supported theory.
- **Independent oracle:** `test/oracle/symbolic_checker/models.tsv` fixes each model's explicit bound,
  symbolic result class, exact failing invariant/action, explicit-state result, relationship class, and proof
  obligation count. It distinguishes agreement, conservative incompleteness, and unsupported syntax.
- **Owned checker boundary:** the dedicated-root implementation consumes `formal-model` but may import neither
  the Phase-11 explorer nor another checker. It owns variable-sort classification, SMT-LIB translation,
  parameter expansion, simultaneous transitions, induction hypotheses, and solver-result classification.
- **Totality:** every `Expr` constructor is matched. Bool/int QF_LIA terms are translated; sets, functions,
  finite quantifiers, constraints, expansion limits, and unsupported sorts return a named `Unsupported`
  feature. A rejected fragment cannot accidentally become an unbounded result.
- **Induction semantics:** base obligations assert the actual initialized state and negate one invariant.
  Step obligations assume the conjunction of every invariant, assert one action guard and its simultaneous
  transition, then negate the target invariant in the successor state.
- **Independent comparison:** five models yield the same safety class from symbolic induction/counterexample
  and Phase-12 enumeration. The safe-but-non-inductive model must be rejected conservatively, demonstrating
  that failure to prove is not relabeled as a reachable violation.
- **Solver boundary:** Z3 is an external decision procedure, dynamically ensured from the authored
  `>=4.13 <6` compatibility range and injected by absolute path. The amoebius checker owns the query and classification;
  the result still assumes Z3 correctly decides the submitted QF_LIA formula.
- **Seeded defects:** three Cabal/CPP builds assume only the target invariant, negate every action guard, or
  accept a satisfiable step obligation as proof. Each fails at a different registry-declared fixture/field.
- **Identity and evidence:** the independently implemented model digest equals Phase 12's digest for all seven
  fixtures. Successful witnesses bind all 14 obligation kinds to 64-hex query digests; counterexamples retain
  the satisfying solver model.
- **Generated-artifact discipline:** no SMT source is committed. The suite writes only
  `.build/checkers/symbolic/results.tsv`; the gate compares all eleven metrics to authored values and requires
  the result to remain outside the source snapshot.
- **Honesty boundary:** successful one-step induction is unbounded for the submitted transition relation and
  invariant within QF_LIA/boolean semantics. It does not prove that non-inductive properties are false, that
  unsupported syntax is safe, that the model matches an intended protocol, or that runtime code refines it.
- **Observer controls:** no authority-control apparatus applies to a pure SMT query. There is no service to
  authenticate or bypass and no observer pair to compare; independence instead comes from the hand-classified
  induction cases and a separately implemented bounded checker.
- **Extension conformance (§M.13).** This clause has no subject here: the implementation introduces no
  extension or domain declaration and returns only proof-engine results.

The gate proves its three fixture invariants by one-step induction and tests translation sensitivity to the
named defects. It neither establishes completeness of the supported theory nor treats a solver as the owner
of the proof schema.

## Doctrine adopted

- [`formal_model_doctrine.md` §2 — The `Model` is data](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data): symbolic obligations consume the same closed constructor tree as the other readings.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): five overlap fixtures compare independent checker results over identical model digests.
- [`formal_model_doctrine.md` §6 — What a green model-check proves](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): induction reach and solver/model premises remain explicit.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the corpus owns translation and induction while a dynamically resolved solver decides its formulas.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): every metric, check, and mutant joins to one authored Phase-13 surface.

## Sprints

## Sprint 13.1: Total symbolic boundary and inductive obligations ✅

**Status**: Done
**Implementation**: `lib:symbolic-checker`,
`src/symbolic-checker/Amoebius/Checker/Symbolic.hs`, the three `symbolic-*-mutant` Cabal flags, and the `z3`
entry in `tools/toolchain_requirements.json`.
**Blocked by**: None.
**Independent Validation**: The source boundary rejects imports of other checker algorithms; unsupported
syntax is an exact result, and every proof is a list of solver-decided base/step obligations.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

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

None.

## Sprint 13.2: Solver differential and mutation evidence ✅

**Status**: Done
**Implementation**: `test/spec/formal/symbolic/SymbolicCheckerSpec.hs`,
`test/oracle/symbolic_checker/**`, `test/oracle/symbolic_checker_surfaces.tsv`,
`test/mutant/registry.tsv`, and `tools/symbolic_checker_gate.py`.
**Blocked by**: Sprint 13.1's total symbolic classification and induction schema.
**Independent Validation**: A hand-authored relationship table distinguishes exact agreement from conservative
non-induction and theory rejection, then three real builds attack different proof decisions.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Adopt independent correspondence and proof-failure honesty: compare only overlapping claims, retain the
expected conservative gap, and demonstrate sensitivity to hypotheses, guards, and solver classification.

### Deliverables

- Seven exact symbolic/explicit expectations and 14 declared proof obligations.
- Five explicit-state agreements, one conservative non-inductive case, and one unsupported-theory case.
- Three induction witnesses and three solver-backed counterexamples.
- Registry-backed conjoined-hypothesis, guard-polarity, and satisfiable-step-acceptance mutants.
- Eleven result metrics, 21 authored surfaces/23 run-time items, a machine-derived Register-1 ledger,
  containment, write guard, natural-architecture record, and source-bound attestation.

### Validation

1. Compare every symbolic, explicit, relation, and obligation observation to its independently authored row;
   reject a run without the complete suite token.
2. Require digest and safety-class agreement on all five overlapping fixtures.
3. Require the safe-but-non-inductive fixture to remain explicitly conservative.
4. Compile the hypothesis, polarity, and satisfiable-step defects separately; each must redden only its named
   fixture field.
5. Join every run-time item to one authored surface and keep runtime fidelity `UNVERIFIED`.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
