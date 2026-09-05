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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md
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

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 13, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-14 semantic and resource payloads,
package-hidden serial supervisor, Haskell source/refinement oracle, compiled model projection, and three
changed-production subjects are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The Haskell checker compiles and checks a closed source-annotation fragment for postcondition preservation and explicit implementation-to-model correspondence. |
| `Subject` | `Amoebius.Checker.Refinement` is acquired only through package-hidden `Amoebius.Validation.RefinementCheckerRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 14`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `RefinementCheckerSpec.hs` embeds six exact outcomes and two correspondence predicates; `RefinementModelProjection.hs` independently projects the Phase-11 model expressions. |
| `Positive controls` | Increment, decrement, and sum compile and prove with exact source line/digest identity and complete required-pair coverage. |
| `Paired negatives` | Relative solver, unbound variable, ill-sorted precondition, counterexample, correspondence mismatch, and unknown invariant paths are exact refusals or classifications. |
| `Mutants` | Precondition-conjunct deletion, correspondence omission, and postcondition weakening compile as changed production subjects and turn their assigned result loci red. |
| `Discovery` | Production checker, two Haskell oracles, shared fake SMT boundary, and six compiled Haskell fixtures equal the fixed ten-file inventory bidirectionally. |
| `Challenge` | All three mutations execute after acquisition and must be distinguished at their independent status observations. |
| `Observer` | The supervisor records absolute executable, argv, exit, transcript digest, and bounded failure text for every compiler, projection, and oracle process. |
| `Authority/bypass` | `pb`, PATH solver lookup, network, host/hardware effects, writes outside the run root, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-14/work/**` root and requires equal opening/closing source identities. |
| `Qualification` | Model projection, six fixture compiles, clean classifications, exact discovery, and all three changed-production subjects pass together. |
| `Cleanroom` | Fake solver, binaries, objects, projected invariants, transcripts, and results are generated lazily beneath the fresh run root. |
| `Legacy closure` | Retired Phase-14 Python checker/gate and serialized behavioral oracles are absent. |
| `Predecessor` | Consume exactly one durable Phase-13 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Reusable compile-fail machinery, simulation, concrete models, runtimes, live effects, and hardware remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-fourteen-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

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

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 14.1: Compiled-source refinement boundary ✅

**Status**: Done
**Implementation**: `src/refinement-checker/Amoebius/Checker/Refinement.hs` and the six compiled Haskell fixture modules
**Blocked by**: [Phase 13](phase_13_symbolic_checker.md) gate pass
**Independent Validation**: six exact outcomes, source identities, paired grammar/type refusals, and two required correspondence pairs
**Oracle**: `test/spec/formal/refinement/RefinementCheckerSpec.hs` and compiled `RefinementModelProjection.hs`
**Legacy IDs**: none; retired Python and serialized Phase-14 behavioral sources are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 14.2: Correspondence, negatives, and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/RefinementCheckerRun/Internal.hs`
**Blocked by**: Sprint 14.1
**Independent Validation**: serial projection/fixture/clean/three-mutant matrix, exact red loci, discovery, containment, and process receipts
**Oracle**: the same two independently authored Haskell oracles; generated projection and result bytes are observations only
**Legacy IDs**: none; retired Python and serialized Phase-14 behavioral sources are checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `testing_doctrine.md`, and `system_components.md`

### Objective

Make the implementation-to-model assertion visible as an obligation, cover each negative class by its exact
reason, and demonstrate that the gate detects weakened hypotheses, omitted correspondence, and vacuous posts.

### Deliverables

- Two required `(model, invariant)` registry rows covered by three proved functions.
- One postcondition counterexample, one correspondence mismatch, and one missing-invariant rejection.
- Three registry-backed checker mutation modes, each red at its declared result field.
- Eleven result metrics, 21 authored surfaces/24 run-time items, a Register-1 ledger, containment, write guard,
  natural-architecture record, and exact source-bound run record.

### Validation

1. Require all required model/invariant pairs to exist in the registry and have a proved function mapping.
2. Compare all eleven generated metrics to the authored expectations.
3. Run each mutant in isolation and require the exact sum, negative-identity, or broken-decrement mismatch.
4. Join every run-time item to an authored surface and leave runtime fidelity `UNVERIFIED`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

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
