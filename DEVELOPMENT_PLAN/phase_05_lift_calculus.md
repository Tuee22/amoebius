# Phase 5: The lift calculus

> **Purpose**: Specify the target Haskell capability to represent the closed effect-layer set, total
> transition relation, and consumed transition witness as one typed Haskell lift calculus.
> **Read this if**: the layer an effect runs at matters, or a transition needs a witness, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_11_calculus_composition.md, documents/engineering/lift_and_compose_doctrine.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: The lift calculus ⏸️](#sprint-51-the-lift-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 4, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to represent the closed effect-layer set, total transition relation, and
consumed transition witness as one typed Haskell lift calculus.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 50 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — represent the closed effect-layer set, total transition
relation, and consumed transition witness as one typed Haskell lift calculus. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-50; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 4](phase_04_budget_calculus.md)
**Gate:** `pb validate phase 5`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target capability only — represent the closed effect-layer set, total transition relation, and consumed transition witness as one typed Haskell lift calculus. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 5` is future public spelling only. Before current human approval of Phase 51, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 4; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`lift_and_compose_doctrine.md` §7 — The lift calculus](../documents/engineering/lift_and_compose_doctrine.md#7-the-lift-calculus) — the rule behind the lift calculus.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 5.1: The lift calculus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 4](phase_04_budget_calculus.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Make where an effect runs part of its type, and make the relation between layers total.

### Deliverables

- A closed layer set: on the host, inside a frame, inside a container, with no `Other` arm.
- A transition relation that is total — every pair either has a constructor or has no inhabitant.
- A witness type per transition, produced only by observation and never by assertion.
- Composition typed so two lifts compose exactly when the inner target layer is the outer source layer.

### Validation

A wildcard-arm scan over the dispatch must find no fallback, and an asserted witness must fail to compile.

**The scan reads the preprocessed source, not the file.** Three of this phase's mutations live behind
`#ifdef`s in the modules being scanned, so raw text contains every one of them at once and a scan over it
would report the clean tree as carrying a fallback. The gate selects the branches the run's own defines choose
and scans what remains — which is the source the compiler sees, and therefore the source the claim is about.

**A catch-all is decided by its pattern, not by its spelling.** `_ ->` is the obvious form and
`(_from, _to) ->` is the one that gets past a scan looking for the obvious form, so the rule is stated over
the pattern's atoms: an alternative is a catch-all when every atom is a variable or a wildcard. One
constructor anywhere in it — including an operator constructor like `:` — makes it a real alternative.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. The relation is over primitive transitions and is deliberately not transitive, so
`on-host → in-container` has no inhabitant and reaching a container from the host is a composition; that
distinction is what a path is for, and a relation closed under transitivity would erase it. Whether teardown
is an obligation the type system tracks is the workflow calculus's claim, which is the next phase's and is
recorded `UNVERIFIED` here; nothing in this register enters a frame or asks an engine, so which frames exist
on which hardware remains [`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)'s
to observe.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — **done
  2026-08-20.** §7 gains the record that the calculus's three parts are built, and what is not: the layer set
  is closed at three members, so the "and so on outward" the section allows for is a change to the set rather
  than something the code already carries.
- [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md) — **historical pre-reset note from 2026-08-20 — permanently invalid for promotion.** §4's
  "what is built today" paragraph said the per-transition witness type did not exist yet. It does.

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.
