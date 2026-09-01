# Phase 5: The lift calculus

> **Purpose**: Specify the target Haskell capability to represent the closed effect-layer set, total
> transition relation, and consumed transition witness as one typed Haskell lift calculus.
> **Read this if**: the layer an effect runs at matters, or a transition needs a witness, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, documents/engineering/lift_and_compose_doctrine.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: The lift calculus](#sprint-51-the-lift-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 4, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

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

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent the closed effect-layer set, total transition
relation, and consumed transition witness as one typed Haskell lift calculus. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 4](phase_04_budget_calculus.md)
**Gate:** `pb validate phase 05`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — represent the closed effect-layer set, total transition relation, and consumed transition witness as one typed Haskell lift calculus. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 05` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 04; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. Until the local runner and oracle exist, these rows remain `UNRESOLVED`.

## Doctrine adopted

- [`lift_and_compose_doctrine.md` §7 — The lift calculus](../documents/engineering/lift_and_compose_doctrine.md#7-the-lift-calculus) — the rule behind the lift calculus.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 5.1: The lift calculus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 4](phase_04_budget_calculus.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Make where an effect runs part of its type, and make the relation between layers total.

### Deliverables

- A closed layer set: on the host, inside a frame, inside a container, with no `Other` arm.
- A transition relation that is total — every pair either has a constructor or has no inhabitant.
- A witness type per transition, produced only by observation and never by assertion.
- Composition typed so two lifts compose exactly when the inner target layer is the outer source layer.

### Validation

The compiler decides totality, and an asserted witness must fail to compile.

**Totality is a typechecker result, not a text result.** The relation is a closed GADT indexed by its source
and target layer, compiled under `-Wincomplete-patterns -Werror`, so a dispatch that omits an inhabited pair
does not build. A lexical scan cannot settle this claim: it inspects the spelling of the arms an author
happened to write, and a genuinely partial relation carrying enough hand-written constructors to satisfy the
scan passes it while leaving pairs undecided. The scan is retained only as a supplementary observation that no
`Other` arm and no catch-all were introduced; it is never the totality oracle.

**Each mutant removes a constructor rather than adding an arm.** Appending a catch-all to a relation that is
already total changes a locus the compiler never selects, so it reddens a scanner and not the subject — which
[§M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) excludes:
*"A deliberately broken alternate implementation that production can never select is not a mutant of the
subject."* Each of this phase's changed-subject mutants therefore deletes one constructor from the closed
relation, so the incomplete-pattern error names the missing pair at its own locus while the unrelated
positives stay green.

**A weaken-the-constraint mutant per foreclosure claim.** The witness claim and the composition claim are each
settled by a compile-fail twin, so each carries a mutant that loosens the constraint the twin violates — the
witness constructor made public, and the source/target layer equality on composition relaxed. The illegal twin
must compile under that mutant and only under it; a twin that fails for a parse error, an unbound name, or a
missing import satisfies nothing
([§M.8](development_plan_gate_integrity.md#m8-paired-negatives-assert-an-exact-reason-at-an-exact-locus)).

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. The relation is over primitive transitions and is deliberately not transitive, so
`on-host → in-container` has no inhabitant and reaching a container from the host is a composition; that
distinction is what a path is for, and a relation closed under transitivity would erase it. Whether teardown
is an obligation the type system tracks is the workflow calculus's claim, which is the next phase's and is
recorded `UNVERIFIED` here; nothing in this register enters a frame or asks an engine, so which frames exist
on which hardware remains [`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)'s
to observe.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — **done
  2026-08-20.** §7 gains the record that the calculus's three parts are built, and what is not: the layer set
  is closed at three members, so the "and so on outward" the section allows for is a change to the set rather
  than something the code already carries.
- [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md) — **historical pre-reset note from 2026-08-20 — cannot support a gate pass.** §4's
  "what is built today" paragraph said the per-transition witness type did not exist yet. It does.

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.
