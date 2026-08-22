# Phase 5: The lift calculus

> **Purpose**: A closed layer set, a total transition relation, and a witness for each transition.
> **Read this if**: the layer an effect runs at matters, or a transition needs a witness, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make where an effect runs part of its type, and make the relation between layers total.
Its first deliverable is a closed layer set: on the host, inside a frame, inside a container, with no `Other` arm, and this phase sits where the vocabulary it consumes first exists.
The rule behind the lift calculus is owned by [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, documents/engineering/lift_and_compose_doctrine.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: The lift calculus ✅](#sprint-51-the-lift-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — built and sealed 2026-08-20, the third of the five inserted calculi to be built. `python3
tools/lift_calculus_gate.py` passes all fourteen sides on substrate `none`, lane `none`, natural `arm64`,
untranslated. Two authored tables decide the calculus and neither is read off it: the pair table names all
nine ordered layer pairs and the relation agrees with it in both directions, and the observation table crosses
every admitted pair with every observation and `observe` agrees with that. The four calculus modules carry no
ambient read and no partial token; the suite reaches its acceptance token with eleven checks green; the
composition whose layers do not meet and the witness written down rather than observed each have no type while
their twins compile; and all three seeded mutants redden their own locus and no other.

**The fallback scan is the part worth reading twice.** A dispatch that grows a catch-all arm answers every
pair exactly as it did before, so no table sees it — and it is still the arm a fourth layer would silently fall
into, which is the defect [`lift_and_compose_doctrine.md` §7](../documents/engineering/lift_and_compose_doctrine.md#7-the-lift-calculus)
names when it says there is no fallback arm. The gate therefore scans the source, and it scans the source
**the compiler actually sees**: it selects the `#ifdef` branches the run's defines choose before looking, since
raw text carries every seeded mutant at once and a check that cannot tell the clean tree from a mutated one
decides nothing. The seeded fallback leaves both tables green and every in-process check passing, and only the
scan reacts.

**One mutant was narrowed rather than accepted.** The witness forgery first licensed a frame entry whatever
was observed, which reddened the transition-specificity check as well as the observation table — and a mutant
that reddens two checks says nothing about which of them was holding the property. It now forges only where
*nothing* was observed, which is both the narrowest form of the defect and the purest: there is not even a
mistaken observation behind the evidence.

## Phase Summary

Make where an effect runs part of its type, and make the relation between layers total.

**Phase scope:** one cohesive claim — *where an effect runs is part of its type, and no pair of layers is left undecided*. A closed set, a total relation over it, and a witness consumed by each transition are exactly what that requires.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, which supplies the first effects a layer has to place. This phase is independent of the budget calculus; the ordinal between them is sequence, not dependency.
**Gate:** `python3 tools/run_phase_gate.py 05` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
- **Committed mutants.** Mutants add a fallback arm, forge a witness without an observation, and compose two lifts whose layers do not meet.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in composition typed so two lifts compose exactly when the inner target layer is the outer source layer.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.

## Sprints

## Sprint 5.1: The lift calculus ✅

**Status**: Done — 2026-08-20.
**Implementation**: `src/Amoebius/Calculus/Lift/{Layer,Witness,Transition,Compose}.hs`,
`tools/lift_calculus_gate.py`, `test/spec/calculus/LiftCalculusSpec.hs`,
`test/oracle/lift_calculus/{transition_pairs,witness_observations}.tsv`,
`test/oracle/lift_calculus_surfaces.tsv`,
`test/negative/compile_fail/lift_calculus/{paths_meet_at_a_layer,paths_do_not_meet,witness_comes_from_an_observation,witness_asserted}.hs`
**Blocked by**: None.
**Independent Validation**: A layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`

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

None for this phase. The relation is over primitive transitions and is deliberately not transitive, so
`on-host → in-container` has no inhabitant and reaching a container from the host is a composition; that
distinction is what a path is for, and a relation closed under transitivity would erase it. Whether teardown
is an obligation the type system tracks is the workflow calculus's claim, which is the next phase's and is
recorded `UNVERIFIED` here; nothing in this register enters a frame or asks an engine, so which frames exist
on which hardware remains [`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)'s
to observe.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — **done
  2026-08-20.** §7 gains the record that the calculus's three parts are built, and what is not: the layer set
  is closed at three members, so the "and so on outward" the section allows for is a change to the set rather
  than something the code already carries.
- [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md) — **done 2026-08-20.** §4's
  "what is built today" paragraph said the per-transition witness type did not exist yet. It does.

## Related Documents
- [Development Plan](README.md)
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.
