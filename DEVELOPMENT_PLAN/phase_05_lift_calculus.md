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

✅ Done.

The complete Phase-4 gate is recorded for the same source identity before this phase may run. The phase remains
Active until its complete integrated gate authorizes the mechanical status projection.

## Phase Summary

This phase implements the closed effect-layer set, total transition relation, observation-produced
witnesses, and layer-safe composition as one typed Haskell lift calculus. A package-hidden supervisor
builds the independent Haskell relations, seven changed-production subjects, and both compile-negative pairs
directly and serially.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The source-bound Haskell dispatcher invokes the
authenticated compiler directly and synchronously.

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-5 semantic payload, package-hidden serial
supervisor, independent Haskell relations, paired compile negatives, and changed-production matrix are complete;
only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The closed three-layer set, total primitive relation, observation-produced transition witness, and meeting-layer composition satisfy one source-bound lift calculus contract. |
| `Subject` | `Amoebius.Calculus.Lift.{Layer,Transition,Witness,Compose}` is acquired only through package-hidden `Amoebius.Validation.LiftCalculusRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 05`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly, synchronously, and without `-j`. |
| `Oracle` | `test/spec/calculus/LiftCalculusSpec.hs` contains separately authored nine-pair and twenty-observation Haskell relations and observes only public production interfaces. |
| `Positive controls` | All eleven clean predicates pass and both legal compile twins succeed. |
| `Paired negatives` | An asserted witness is refused for the hidden constructor; paths whose boundary layers differ are refused at the exact type mismatch. |
| `Mutants` | Fallback admission, witness forgery, unchecked runtime joins, two missing relation arms, exposed witness constructor, and relaxed typed composition are each killed at their assigned observation. |
| `Discovery` | The four lift modules, Haskell oracle, and four compile twins are discovered from the Git snapshot and equal the fixed inventory bidirectionally. |
| `Challenge` | All seven changed-production subjects execute after acquisition and must be distinguished at their assigned locus. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-05/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, exact negatives, totality diagnostics, and all seven mutants pass together; any survivor or wrong-locus failure refuses. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 5 owns no legacy-debt identifier; all non-circular prerequisites must pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-4 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Workflow obligations, five-calculus composition, actual effects, runtimes, hardware, and live services remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-five-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. The local runner owns these pairs until Phase 15 consolidates their reusable machinery.

## Doctrine adopted

- [`lift_and_compose_doctrine.md` §7 — The lift calculus](../documents/engineering/lift_and_compose_doctrine.md#7-the-lift-calculus) — the rule behind the lift calculus.

## Sprints

The sprint seam is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 5.1: The lift calculus ✅

**Status**: Done
**Implementation**: `src/Amoebius/Calculus/Lift/{Layer,Transition,Witness,Compose}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/LiftCalculusRun/Internal.hs`
**Blocked by**: [Phase 4](phase_04_budget_calculus.md) gate pass
**Independent Validation**: eleven clean predicates over nine pairs and twenty observations; two exact compile-negative pairs; seven assigned changed-production subjects; later effects remain residue
**Oracle**: `test/spec/calculus/LiftCalculusSpec.hs`, separately authored in Haskell against public calculus modules
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file, `DEVELOPMENT_PLAN/README.md`, and `documents/engineering/lift_and_compose_doctrine.md`

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

The relation is over primitive transitions and is deliberately not transitive, so
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

- `DEVELOPMENT_PLAN/README.md` and the adjacent Phase 4/6 backlinks remain the phase-order routing authority.

## Related Documents

- [Development Plan](README.md)
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.
