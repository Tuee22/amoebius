# Phase 4: The budget calculus

> **Purpose**: Specify the target Haskell capability to represent storage authority, concurrency,
> admission, and reaping as one typed Haskell budget calculus in which no allocation lacks a prior
> bound.
> **Read this if**: a byte has to be accounted for before it is written, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, documents/engineering/jit_budget_doctrine.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: The budget calculus ⏸️](#sprint-41-the-budget-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 3, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to represent storage authority, concurrency, admission, and reaping as one
typed Haskell budget calculus in which no allocation lacks a prior bound.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent storage authority, concurrency, admission, and
reaping as one typed Haskell budget calculus in which no allocation lacks a prior bound.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 3](phase_03_artifact_calculus.md)
**Gate:** `pb validate phase 04`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — represent storage authority, concurrency, admission, and reaping as one typed Haskell budget calculus in which no allocation lacks a prior bound. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 04` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 03; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`jit_budget_doctrine.md` §2 — The grant is the authority to exist](../documents/engineering/jit_budget_doctrine.md#2-the-grant-is-the-authority-to-exist) — the rule behind the budget calculus.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 4.1: The budget calculus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 3](phase_03_artifact_calculus.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.

### Deliverables

- A `Grant` value issued from a finite pool, specific to a location and purpose, with no unbounded constructor.
- A ceiling and a concurrency bound that share one constructor, so neither can be stated alone.
- `admit` and `admitFirst` returning a reservation or a refusal, writing nothing on the refusal path.
- A retention grant that has no constructor without a reaper.

### Validation

Driving a grant to its ceiling must refuse at admission with the store byte-identical to its prior state, never mid-write.

**Both halves of that sentence are checked, and only the second one can fail.** `admit` has no store in its
type, so the ceiling refusal cannot touch one; the run reports the image on either side of it because a
contract that states the claim should be able to point at the observation, not because the observation could
come out otherwise. The mid-write refusal is the one with a store in reach: a demand admitted against a
declared worst case its rendering then exceeds is refused by `materializeUnder`, which returns the store on
both paths so that a seeded defect can move it. The seeded `admit-after-partial-write` mutant does exactly
that, and leaves every in-process check green — which is why the store image is read from a second invocation
of the suite rather than asserted inside it.

The refusal's *reason* is checked as well as its verdict. The authored capacity table names one of five
admission reasons per refused row, and the order the reasons are tested in is part of the expectation: three
rows are wrong in two ways at once and each names the earlier reason, so a refusal stays attributable to one
arm rather than to whichever check happened to run first
([§M.8](development_plan_gate_integrity.md#m8-paired-negatives-assert-an-exact-reason-at-an-exact-locus)).

**Each remaining deliverable carries its own selector.** `admit-after-partial-write` settles one deliverable;
the other three are unobserved without their own, which
[§M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) forbids. The
pool-specificity claim carries a mutant admitting a grant at a foreign location or purpose. The shared
ceiling/concurrency constructor carries a weaken-the-constraint mutant that splits it into two independently
statable fields, under which the illegal twin — a ceiling stated without its bound — must compile and only
then. The reaper-less retention grant carries the same shape of weaken-the-constraint mutant. A twin that
fails for a parse error, an unbound name, or a missing import satisfies none of them.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. Whether a composition's grant is the sum of its parts' is C5's claim over the lift
calculus, which is the next phase's, and is recorded `UNVERIFIED` here; nothing in this register observes a
running system, so the substrate's actual free space remains the live-effect observation
[`jit_budget_doctrine.md` §7](../documents/engineering/jit_budget_doctrine.md#7-the-residue) says it is.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — **historical pre-reset note from 2026-08-20 — cannot support a gate pass.** §7's
  "nothing here is built" is replaced by what is: the grant, admission, the staging rule, and the reaper, as
  pure values in Register 1. What stays unbuilt is named rather than dropped — §6's additivity is stated over
  the lift calculus above this one, and §7's free-space observation is not a decision result at all.

**Cross-references to add:**

- None beyond the doctrine update above. Generator/output ownership is a checked Haskell declaration; any
  registry projection or generated grant artifact is lazy output beneath `.build/**`, never a tracked table
  or Python gate.

## Related Documents

- [Development Plan](README.md)
- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.
