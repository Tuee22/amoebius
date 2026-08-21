# Phase 7: The evidence calculus

> **Purpose**: A claim is bound to the fixture that discharges it, and a mutant record is a value.
> **Read this if**: a claim has to be tied to something that could falsify it, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.
Its first deliverable is a claim type carrying its discharge, so a claim with no fixture has no constructor, and this phase sits where the vocabulary it consumes first exists.
The rule behind the evidence calculus is owned by [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, documents/engineering/evidence_calculus_doctrine.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 7.1: The evidence calculus ✅](#sprint-71-the-evidence-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — built and sealed 2026-08-20, the last of the five inserted calculi to be built. `python3
tools/evidence_calculus_gate.py` passes all thirteen sides on substrate `none`, lane `none`, natural `arm64`,
untranslated. A hand-authored claim inventory for Phase 5 names seven claims, each bound to one fixture that
exists on disk, at a strength its fixture's kind entitles it to; the four calculus modules carry no ambient
read and no partial token; the suite reaches its acceptance token with twelve checks green; the claim with no
fixture and the gate with no register each have no type while their twins compile; and all three seeded
mutants redden their own locus and no other. Attestation `sha256:a7920f6ede39c60339fbbfd4173fd4f31dadc52da8671b3de08d1b9b87de096c` binds to a 2,139-file source snapshot; as
everywhere here, the reference names the run and this record follows it.

**The self-referential gap is visible here rather than argued about.** This is a gate checking a calculus about
evidence, using evidence, and
[`evidence_calculus_doctrine.md` §4](../documents/engineering/evidence_calculus_doctrine.md#4-independence-is-what-makes-a-fixture-worth-running)
says plainly that a fixture cannot always be authored by a path outside the machinery. What stands in for
independence is that the inventory is for a *different* phase: Phase 5's claims, written out by hand from
Phase 5's contract, joined against the registry this calculus derives. The derivation being wrong and the
inventory being wrong are then two errors rather than one. That reduces the risk;
[the residue section](../documents/engineering/evidence_calculus_doctrine.md#6-the-residue) is explicit that it
does not eliminate it, and this record does not claim otherwise.

**Three rules the calculus makes mechanical.** A claim's strength may not exceed what its fixture's kind
entitles it to, so "the property test passed" cannot be written down as "the property holds" — the pairing of
the four kinds to the four strengths is one-to-one and total. An unrepresentability claim names a compile-fail
fixture and only such a claim does, checked as a biconditional over the inventory rather than as an
implication. And a gate may not declare a register its fixtures did not reach, which
[§5](../documents/engineering/evidence_calculus_doctrine.md#5-what-evidence-is-worth-is-the-registers-business)
calls its own illegal state — the same defect as an unpinned compile-fail fixture, one level up.

## Phase Summary

Bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.

**Phase scope:** one cohesive claim — *a claim that names no fixture is not expressible*. The claim value, the closed set of fixture kinds, and the mutant record are what make that binding mechanical rather than editorial.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, because a fixture and a mutant are both artifacts something has to address and reap. No obligation from the workflow calculus is consumed here.
**Gate:** `python3 tools/evidence_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
- **Committed mutants.** Mutants register a claim with no fixture, point a mutant at the wrong locus, and add a second mutant registry.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in the register model as a value, so a gate declares which register its evidence reaches.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.

## Sprints

## Sprint 7.1: The evidence calculus ✅

**Status**: Done — 2026-08-20.
**Implementation**: `src/Amoebius/Calculus/Evidence/{Register,Fixture,Claim,Mutant}.hs`,
`tools/evidence_calculus_gate.py`, `test/spec/calculus/EvidenceCalculusSpec.hs`,
`test/oracle/evidence_calculus/lift_calculus_claims.tsv`, `test/oracle/evidence_calculus_surfaces.tsv`,
`test/negative/compile_fail/evidence_calculus/{claim_names_its_fixture,claim_without_a_fixture,gate_declares_its_register,gate_without_a_register}.hs`
**Blocked by**: None.
**Independent Validation**: A hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
**Docs to update**: `documents/engineering/evidence_calculus_doctrine.md`

### Objective

Bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.

### Deliverables

- A claim type carrying its discharge, so a claim with no fixture has no constructor.
- A mutant record naming its operator, its change, and the locus the gate must redden.
- One registry for the mutant corpus, with a carrier field rather than a second registry.
- The register model as a value, so a gate declares which register its evidence reaches.

### Validation

A claim without a fixture reference must fail to construct, and every registered mutant must redden its named locus.

**"Fail to construct" is two claims and both are checked.** That the constructor takes a fixture at all is a
claim about an export list, so it is a committed compile-fail pair — omitting the argument leaves a function
waiting for a `Fixture`, and the rejection names it. That a fixture naming *nothing* is refused is a claim
about a value, so it is an in-process check, and it is where the seeded binding-erasure mutant lands: a `Text`
has no non-empty arm, so this is the one door the type could not close.

**The registry is derived, not restated.** The three mutant records the join reads come from
`test/mutant/registry.tsv` — the one registry the corpus already has — decoded through the carrier rule rather
than re-listed here. Offering the calculus a second source is refused rather than merged, which is what makes
"a carrier field rather than a second registry" a check instead of a preference.

### Remaining Work

None for this phase, and the residue is the doctrine's own. This calculus does not make a claim true; it makes
a claim falsifiable and binds it to the thing that would falsify it, so a well-formed claim with a weak fixture
satisfies it completely. It does not choose the fixtures. And it does not close the self-referential gap —
which is stated here rather than left implicit, because this is the phase where that gap is nearest.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — **done
  2026-08-20.** §6's "nothing here is built" is replaced by what is — the claim value, the fixture binding, the
  register declaration — and by the three residues that remain true of it regardless.

## Related Documents
- [Development Plan](README.md)
- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.
