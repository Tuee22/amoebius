# Phase 14: The amoebius refinement checker

> **Purpose**: Specify the target Haskell capability to check a bounded GHC-compiled Haskell
> function fragment against source-local refinements and an explicit
> postcondition-to-model-invariant correspondence obligation.
> **Read this if**: a model property must constrain implementation source, or the exact boundary of that
> code-refinement claim must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 14.1: Compiled-source refinement boundary](#sprint-141-compiled-source-refinement-boundary-)
- [Sprint 14.2: Correspondence, negatives, and mutation evidence](#sprint-142-correspondence-negatives-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

✅ Done.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-13 predecessor and its compatible evidence chain.

## Phase Summary

The audit showed that a raw-line parser can select a safe equation inside a comment while GHC compiles an unsafe multiline definition. The required repair is compiler-owned syntax and identity correspondence, not another text filter. The existing arithmetic examples remain regression controls and must not be described as verification of production DSL source.

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to check a bounded GHC-compiled Haskell function fragment against source-local
refinements and an explicit postcondition-to-model-invariant correspondence obligation.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — check a bounded GHC-compiled Haskell function fragment
against source-local refinements and an explicit postcondition-to-model-invariant correspondence
obligation. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 13](phase_13_symbolic_checker.md)
**Gate:** `pb validate phase 14`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | The Haskell refinement checker derives its admitted function fragment from the exact compiler-parsed and typechecked source, then uses authenticated SMT observations for preservation and explicit implementation-to-model correspondence; unsupported source is refused. |
| `Subject` | `Amoebius.Checker.Refinement` is acquired only through package-hidden `Amoebius.Validation.RefinementCheckerRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 14`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `test/spec/formal/refinement/RefinementCheckerSpec.hs` and `RefinementModelProjection.hs` independently specify compiled behavior, accepted syntax, preservation and correspondence, including comments, layout, shadowing and compiler-transformation counterexamples. |
| `Positive controls` | Admitted compiled Integer functions agree with independently authored source/AST projections and runtime boundary examples; real SMT observations establish their stated preservation and model-correspondence formulas. |
| `Paired negatives` | Retain arithmetic/correspondence/unknown-invariant negatives; add commented safe equations paired with actual unsafe multiline definitions, duplicate annotations, unsupported constructs, rebinding and compiler/source identity mismatch, each requiring its specific refusal or counterexample. |
| `Mutants` | Production changes selecting commented code, using a separately reparsed equation, omitting source/AST custody, deleting preconditions, omitting correspondence or weakening postconditions fail independently assigned exact cases. |
| `Discovery` | Join supported compiler-AST constructors, annotations and exact compiled function identities to independent cases, named model obligations and production mutation/build assignments; six arithmetic fixtures cannot define production DSL coverage. |
| `Challenge` | All three mutations execute after acquisition and must be distinguished at their independent status observations. |
| `Observer` | The supervisor records absolute executable, argv, exit, transcript digest, and bounded failure text for every compiler, projection, and oracle process. |
| `Authority/bypass` | `pb`, PATH solver lookup, network, host/hardware effects, writes outside the run root, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-14/work/**` root and requires equal opening/closing source identities. |
| `Qualification` | Exact compiler-AST/source correspondence, real solver decisions, independently observed compiled behavior, all supported syntax/refusal pairs and every assigned changed subject must qualify together. |
| `Cleanroom` | Fake solver, binaries, objects, projected invariants, transcripts, and results are generated lazily beneath the fresh run root. |
| `Legacy closure` | Retired Phase-14 Python checker/gate and serialized behavioral oracles are absent. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 13 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | The admitted fragment remains explicit and narrow; effects, recursion and other unsupported Haskell require later specified obligations. No production DSL refinement is claimed without its registered function, invariant and demonstrated correspondence. |
| `Pass criterion` | `qualified-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Resource provision

Phase 14 owns one run-local fake SMT process, serial GHC children, and generated products beneath
`.build/runs/phase-14/**`. Preflight requires absolute authenticated compiler and freshly compiled solver paths.
Allowed mutations are stdin SMT-LIB queries, fixture compilation, and writes inside the run root; PATH lookup,
network, host/hardware effects, writes elsewhere, and compiler overlap are forbidden. The parent supervisor is
the external observer, cleanup is run-root scoped, and no external owned residue is permitted.

## Doctrine adopted

- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): code refinement is a separate layer from model safety.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the target Haskell corpus and checker must own the verdict and may delegate only raw formula observations.

## Sprints

The sprint requirements below remain part of the target acceptance scope. Each owner must bind them in
Haskell and qualify the mechanism that first admits their result; component observations cannot close a sprint.

## Sprint 14.1: Compiled-source refinement boundary ✅

**Status**: Done
**Implementation**: `src/refinement-checker/Amoebius/Checker/Refinement.hs` and the six compiled Haskell fixture modules
**Blocked by**: [Phase 13](phase_13_symbolic_checker.md) gate pass
**Independent Validation**: Compile and prove the admitted source through one authenticated compiler identity; pair it with the commented-equation audit counterexample and require its actual violation or exact unsupported-source refusal; kill AST/source-substitution mutants; exclude unsupported Haskell.
**Oracle**: `test/spec/formal/refinement/RefinementCheckerSpec.hs` and compiled `RefinementModelProjection.hs`
**Legacy IDs**: none; retired Python and serialized Phase-14 behavioral sources are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Settle the ownership choice with a small, total checker over the Haskell fragment the current corpus needs,
while keeping compiler and solver responsibilities explicit.

### Deliverables

- A Haskell compiler-API boundary binds exact source bytes, language options, preprocessing inputs, parsed/typechecked function identity and admitted expression tree. The checker consumes that tree rather than selecting equations or signatures from raw lines.
- Annotations resolve to the exact compiled binding, arguments and model projection. Comments, source layout, duplicate declarations, local rebinding, imports and preprocessing cannot supply a different function to the checker.

- Closed six-field source annotation and exact `Integer` function-equation boundary.
- Owned linear-integer/boolean parser, sort checker, SMT translation, and rejection diagnostics.
- GHC `-fno-code` compilation plus absolute injected compiler and solver paths.
- Preservation query with solver-backed counterexamples and source line/digest identity.
- Compiled projection of two safe Phase-11 `Model` invariant expressions into generated checker input.
- Exact `proved`, `postcondition-counterexample`, `correspondence-mismatch`, and `unknown-invariant` results.

### Validation

- Compile a module with a commented `f x = x + 1` and a real multiline `f x = x - 1`. With precondition `x >= 0` and postcondition `result >= 0`, require the counterexample at zero or an exact unsupported-fragment refusal; never report `Proved` for the comment.
- Pair legal layout/comment variants with duplicate or ambiguous annotations and changed compiler options; require stable semantics for the legal variants and named identity/syntax refusals for the others.

1. Compile each of the six source modules before checking annotations.
2. Reject missing/duplicate annotation fields, signature/equation disagreement, unbound variables,
   ill-sorted terms, unsupported expressions, relative tools, and non-decision solver results.
3. Require all source identities, line numbers, result classes, and reasons to equal the authored oracle.
4. Retain a satisfying solver model for every preservation or correspondence counterexample.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Sprint 14.2: Correspondence, negatives, and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/RefinementCheckerRun/Internal.hs`
**Blocked by**: Sprint 14.1
**Independent Validation**: Require independently registered preservation and model correspondence through the qualified real solver; matched weakening and wrong-model negatives fail specifically; assigned checker mutants are detected; each unregistered production obligation remains unverified.
**Oracle**: the same two independently authored Haskell oracles; generated projection and result bytes are observations only
**Legacy IDs**: none; retired Python and serialized Phase-14 behavioral sources are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Make the implementation-to-model assertion visible as an obligation, cover each negative class by its exact
reason, and demonstrate that the gate detects weakened hypotheses, omitted correspondence, and vacuous posts.

### Deliverables

- Use the authenticated solver/response boundary established by Phase 13 and independently replay known counterexamples. The bounded Haskell fake remains a protocol fault control.
- A Haskell registry identifies every function actually claimed refined, its exact compiler binding, precondition, postcondition, model invariant and projection. Fixture coverage cannot discharge an absent production entry.

- Two required `(model, invariant)` registry rows covered by three proved functions.
- One postcondition counterexample, one correspondence mismatch, and one missing-invariant rejection.
- Three registry-backed checker mutation modes, each red at its declared result field.
- Eleven result metrics, 21 authored surfaces/24 run-time items, a Register-1 ledger, containment, write guard,
  natural-architecture record, and exact source-bound run record.

### Validation

- Join claimed functions to compiler-derived source identities and model obligations in both directions; reject missing, duplicate, unrelated and fixture-only substitutions.
- Keep preservation, source correspondence and model correspondence as separate required observations; a source digest or successful GHC invocation cannot stand in for any of them.

1. Require all required model/invariant pairs to exist in the registry and have a proved function mapping.
2. Compare full compiler-derived binding, formula and result observations to independent expectations;
   generated metrics are supplemental summaries, not semantic verdicts.
3. Run each mutant in isolation and require the exact sum, negative-identity, or broken-decrement mismatch.
4. Join every run-time item to an authored surface and leave runtime fidelity `UNVERIFIED`.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `formal_model_doctrine.md` — settle the refinement ownership choice and record the supported source,
  correspondence, compiler, solver, and runtime premises.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  implementation paths, evidence, and the substrate-none claim.

## Related Documents

- [Development Plan Tracker](README.md) — order, status, and the accepted evidence record.
- [Phase 11](phase_11_formal_model_kernel.md) — the formal-model vocabulary behind the correspondence names.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — proof-stack ownership and honesty.
