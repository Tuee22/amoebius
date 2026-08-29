# Phase 14: The amoebius refinement checker

> **Purpose**: Specify the target Haskell capability to check a bounded GHC-compiled Haskell
> function fragment against source-local refinements and an explicit
> postcondition-to-model-invariant correspondence obligation.
> **Read this if**: a model property must constrain implementation source, or the exact boundary of that
> code-refinement claim must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 14.1: Compiled-source refinement boundary ⏸️](#sprint-141-compiled-source-refinement-boundary-)
- [Sprint 14.2: Correspondence, negatives, and mutation evidence ⏸️](#sprint-142-correspondence-negatives-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 13, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — check a bounded GHC-compiled Haskell function fragment
against source-local refinements and an explicit postcondition-to-model-invariant correspondence
obligation. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 13](phase_13_symbolic_checker.md)
**Gate:** `pb validate phase 14`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target capability only — check a bounded GHC-compiled Haskell function fragment against source-local refinements and an explicit postcondition-to-model-invariant correspondence obligation. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 14` is future public spelling only. Before current reviewer approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 13; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): code refinement is a separate layer from model safety.
- [`formal_model_doctrine.md` §6.1 — The proof stack is amoebius-owned](../documents/engineering/formal_model_doctrine.md#61-the-proof-stack-is-amoebius-owned): the target Haskell corpus and checker must own the verdict and may delegate only raw formula observations.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 14.1: Compiled-source refinement boundary ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 13](phase_13_symbolic_checker.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 14.2: Correspondence, negatives, and mutation evidence ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 14.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `formal_model_doctrine.md` — settle the refinement ownership choice and record the supported source,
  correspondence, compiler, solver, and runtime premises.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  implementation paths, evidence, and the substrate-none claim.

## Related Documents

- [Development Plan Tracker](README.md) — order, status, and the accepted evidence record.
- [Phase 11](phase_11_formal_model_kernel.md) — the formal-model vocabulary behind the correspondence names.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — proof-stack ownership and honesty.
