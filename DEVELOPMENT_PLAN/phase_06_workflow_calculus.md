# Phase 6: The workflow calculus

> **Purpose**: Specify the target Haskell capability to represent provision, build, deploy, observe,
> and teardown as one Haskell workflow algebra in which teardown remains a type-level obligation.
> **Read this if**: something has to happen to a running system, or teardown has to be reasoned about, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The workflow calculus ⏸️](#sprint-61-the-workflow-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 5, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to represent provision, build, deploy, observe, and teardown as one Haskell
workflow algebra in which teardown remains a type-level obligation.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent provision, build, deploy, observe, and teardown
as one Haskell workflow algebra in which teardown remains a type-level obligation. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 5](phase_05_lift_calculus.md)
**Gate:** `pb validate phase 06`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — represent provision, build, deploy, observe, and teardown as one Haskell workflow algebra in which teardown remains a type-level obligation. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 06` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 05; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §2 — Five arms, one algebra](../documents/engineering/workflow_calculus_doctrine.md#2-five-arms-one-algebra) — the rule behind the workflow calculus.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 6.1: The workflow calculus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 5](phase_05_lift_calculus.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Make teardown an obligation the type system tracks rather than a step somebody remembers.

### Deliverables

- Five arms — provision, build, deploy, observe, teardown — over one vocabulary.
- Provision returning a handle and a teardown obligation together.
- Discharge by teardown or by explicit transfer to a longer-lived declaration, with no way to drop it.
- Sequential and parallel composition typed by the witnesses each arm consumes.

### Validation

A workflow ending while holding an undischarged obligation must fail to compile; a transferred obligation must name its condition.

**Both are compile-fail pairs, and a third joined them.** Discharging an obligation is discharging a *named*
one, so tearing down something the workflow never provisioned is as much a defect as ending while still owing.
Left to the ordinary machinery that would have been a stuck type family — a diagnostic a reader has to decode
— so `Remove`'s empty case is a `TypeError` that names the resource, and the fixture asserts that message
rather than merely asserting that something failed. Each of the three pairs differs from its twin in exactly
one dimension: whether the obligation is discharged, whether the transfer states a condition, and which
resource is named.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. Parallel composition is admitted over disjoint resources and the disjointness is a
constraint rather than a convention, but nothing here executes: what parallel composition asserts is that the
two orders are equally admissible, not that anything ran at once. Binding a claim to the fixture that
discharges it is the evidence calculus's, which is the next phase's and is recorded `UNVERIFIED` here; and a
provider that fails to delete what amoebius asked it to delete remains the `live-effect` residue
[`workflow_calculus_doctrine.md` §3](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation)
names, which no type discipline reaches.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — **done
  2026-08-20.** §3's "the compile-fail fixture establishing that is owed by the phase that builds the workflow
  calculus; none exists" is replaced by the three that do, and by what they establish: the obligation is a type
  index, and dropping one is unspellable rather than refused.

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.
