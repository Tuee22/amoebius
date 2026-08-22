# Phase 14: The amoebius refinement checker

> **Purpose**: Check a bounded, GHC-compiled Haskell function fragment against source-local refinements and
> an explicit correspondence to a named model invariant.
> **Read this if**: a model property must constrain implementation source, or the exact boundary of that
> code-refinement claim must be understood.

This phase owns a deliberately small refinement checker rather than a vendored general-purpose type system.
It checks actual Haskell source with GHC, parses the supported function body and annotation independently,
constructs the preservation and correspondence obligations, and injects Z3 only as their decision procedure.
It does not claim arbitrary-Haskell semantics, effectful or recursive code refinement, or runtime fidelity.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 14.1: Compiled-source refinement boundary ✅](#sprint-141-compiled-source-refinement-boundary-)
- [Sprint 14.2: Correspondence, negatives, and mutation evidence ✅](#sprint-142-correspondence-negatives-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All twelve gate sides passed on natural `arm64`, untranslated: six Haskell
functions compiled, two safe `Model` values projected their invariants after eight reachable states, all
eleven metrics matched, all three proof mutants were red at their own loci, and 21 surfaces joined to 24
enumerated items. Attestation `sha256:49a4add5639a432da7f97d798a0012e6163000a98deb1dab9c335438ca027e45`
binds source `sha256:dfccfc0bf4d2c531…` over 2,180 files. Repository-conformance and documentation support
gates passed on that same snapshot.

## Phase Summary

`tools/refinement_checker.py` checks one-line, first-order `Integer` functions carrying a closed
`amoebius-refinement` block. GHC first syntax- and type-checks the actual fixture. The checker then parses the
same equation into its owned linear-integer/boolean expression tree, proves that the annotated precondition
and body establish the postcondition, and separately proves that the postcondition implies the predicate in
the predicate projected from a compiled Phase-11 `Model` value named by `(model, invariant)`. A satisfiable query retains a solver model and
becomes a named counterexample result; a missing mapping and unsupported source syntax are rejections rather
than proofs.

**Phase scope:** One bounded Haskell-source grammar, one preservation obligation, and one explicit
postcondition-to-model-invariant correspondence obligation; split if work admits effects, recursion,
higher-order values, algebraic data, polymorphism, nonlinear arithmetic, automatic correspondence inference,
or production-runtime trace fidelity.
**Substrate:** none
**Lane:** none
**Register:** 1 — pure/golden
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the named invariant vocabulary whose
implementation correspondence is recorded; the checker does not call the Phase-11 interpreter or either
model-checking algorithm.
**Gate:** `python3 tools/run_phase_gate.py 14` passes GHC compilation, the hand-authored function and
invariant oracles, exact preservation/correspondence results, three registry-backed checker mutants at their
own loci, generated-result discipline, surface join, ledger, containment, write guard, natural architecture,
and source-bound attestation.

## Gate integrity

- **Representative set:** six actual Haskell modules cover two proved counter functions, a proved two-argument
  sum, a body that violates its postcondition, a postcondition that does not imply its registered invariant,
  and an annotation naming no invariant.
- **Independent oracle:** `test/oracle/refinement_checker/functions.tsv` fixes source, function, model,
  invariant, exact result class, diagnostic reason, correspondence requirement, and source line.
  `model_invariants.tsv` separately fixes the expected semantics of the two required model/invariant
  predicates; the checker consumes the generated projection, not that oracle.
- **Compiled source, owned semantics:** all six sources pass GHC `-fno-code` through an injected absolute
  compiler path. The checker owns the annotation parser, the supported Haskell-expression parser, sort
  checking, SMT-LIB query construction, and result classification; unsupported syntax is an error.
- **Supported fragment:** a source has one `Integer -> ... -> Integer` signature and one single-line equation
  over named integer arguments, literals, unary negation, `+`, `-`, comparisons, equality, boolean connectives,
  and `if`/`then`/`else`. Preconditions and postconditions use the same closed grammar, with `result` admitted
  only there.
- **Two obligations:** correspondence asks whether `post ∧ ¬registeredInvariant` is satisfiable. Preservation
  asks whether `pre ∧ result = body ∧ ¬post` is satisfiable. Only two unsatisfiable answers yield `proved`;
  satisfiable answers become `correspondence-mismatch` or `postcondition-counterexample` with a solver model.
- **Model projection:** `RefinementModelProjection.hs` constructs two actual Phase-11 `Model` values, requires
  their structural validity and green explorer verdict over eight reachable states, and projects their named
  invariant expressions into `.build/checkers/refinement/model_invariants.tsv`. The checker consumes that
  generated projection; the authored registry is only a semantic oracle over its identities and expressions.
- **Registry honesty:** the fixture annotation asserts which model result the function implements, and both
  bounded models deliberately name that state variable `result`. The gate proves the function postcondition
  implies the projected invariant and complete coverage of the two required pairs; it does not infer a
  general state projection or prove that a production call site applies the function as the model's action.
- **Solver/compiler boundary:** GHC and Z3 are dynamically resolved from authored compatibility requirements
  and injected as absolute paths. Neither is discovered from ambient `PATH`; Z3 decides the submitted QF_LIA
  formulas but does not own the checker.
- **Seeded defects:** three registry modes delete one conjunct from a precondition, skip the correspondence
  obligation, or replace the checked postcondition with `true`. They fail independently at the sum,
  negative-identity, and broken-decrement status fields.
- **Generated-artifact discipline:** the suite writes only `.build/checkers/refinement/results.tsv`. Eleven
  metrics must equal authored values, 21 surfaces must join to 24 run-time items, and both outputs must remain
  outside the source snapshot.
- **Honesty boundary:** the proof concerns the checker-defined semantics of the compiled, supported function
  fragment. Equivalence between that parser and all GHC semantics, effects, runtime call sites, actual protocol
  behavior, and live execution remain assumed or `UNVERIFIED`.
- **Observer controls:** this compiler/SMT process reaches no authenticated service and exercises no authority
  boundary, so a privileged/unprivileged observer pair has no subject. Its anti-spoofing evidence is instead
  the separate model projection, function-result oracle, and three obligation-specific defects.
- **Extension conformance (§M.13).** Phase 14 declares neither an extension nor a domain member; clause 13
  therefore has no declaration boundary to exercise, and the only outputs are refinement verdicts.

The gate establishes a useful but narrow code-refinement claim. It does not turn a source annotation into a
proof that an arbitrary daemon implements a Phase-11 transition system.

## Doctrine adopted

- [`formal_model_doctrine.md` §6 — What a green model-check proves](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): code refinement is a separate layer from model safety.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the corpus owns the bounded checker and delegates only formula decisions.

## Sprints

## Sprint 14.1: Compiled-source refinement boundary ✅

**Status**: Done
**Implementation**: `tools/refinement_checker.py`,
`test/spec/formal/refinement/RefinementModelProjection.hs`, `test/fixture/refinement_checker/**`, and the
`ghc`/`z3` entries resolved through `tools/toolchain.py`.
**Blocked by**: None.
**Independent Validation**: GHC accepts every actual source module before the separately implemented parser
and solver obligations classify it.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

### Objective

Settle the ownership choice with a small, total checker over the Haskell fragment the current corpus needs,
while keeping compiler and solver responsibilities explicit.

### Deliverables

- Closed six-field source annotation and exact `Integer` function-equation boundary.
- Owned linear-integer/boolean parser, sort checker, SMT translation, and rejection diagnostics.
- GHC `-fno-code` compilation plus absolute injected compiler and solver paths.
- Preservation query with solver-backed counterexamples and source line/digest identity.
- Compiled projection of two safe Phase-11 `Model` invariant expressions into generated checker input.
- Exact `proved`, `postcondition-counterexample`, `correspondence-mismatch`, and `unknown-invariant` results.

### Validation

1. Compile each of the six source modules before checking annotations.
2. Reject missing/duplicate annotation fields, signature/equation disagreement, unbound variables,
   ill-sorted terms, unsupported expressions, relative tools, and non-decision solver results.
3. Require all source identities, line numbers, result classes, and reasons to equal the authored oracle.
4. Retain a satisfying solver model for every preservation or correspondence counterexample.

### Remaining Work

None.

## Sprint 14.2: Correspondence, negatives, and mutation evidence ✅

**Status**: Done
**Implementation**: `test/oracle/refinement_checker/**`,
`test/oracle/refinement_checker_surfaces.tsv`, `test/mutant/registry.tsv`, and
`tools/refinement_checker_gate.py`.
**Blocked by**: Sprint 14.1's total compiled-source boundary and exact classifications.
**Independent Validation**: two authored semantic expectations are joined to invariant expressions projected
from compiled `Model` values, and six authored function expectations are challenged by three logically
distinct checker defects.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` and
`DEVELOPMENT_PLAN/{README,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Make the implementation-to-model assertion visible as an obligation, cover each negative class by its exact
reason, and demonstrate that the gate detects weakened hypotheses, omitted correspondence, and vacuous posts.

### Deliverables

- Two required `(model, invariant)` registry rows covered by three proved functions.
- One postcondition counterexample, one correspondence mismatch, and one missing-invariant rejection.
- Three registry-backed checker mutation modes, each red at its declared result field.
- Eleven result metrics, 21 authored surfaces/24 run-time items, a Register-1 ledger, containment, write guard,
  natural-architecture record, and source-bound attestation.

### Validation

1. Require all required model/invariant pairs to exist in the registry and have a proved function mapping.
2. Compare all eleven generated metrics to the authored expectations.
3. Run each mutant in isolation and require the exact sum, negative-identity, or broken-decrement mismatch.
4. Join every run-time item to an authored surface and leave runtime fidelity `UNVERIFIED`.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `formal_model_doctrine.md` — settle the refinement ownership choice and record the supported source,
  correspondence, compiler, solver, and runtime premises.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  implementation paths, evidence, and the substrate-none claim.

## Related Documents

- [Development Plan Tracker](README.md) — order, status, and the accepted evidence record.
- [Phase 11](phase_11_formal_model_kernel.md) — the formal-model vocabulary behind the correspondence names.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — proof-stack ownership and honesty.
