# Phase 4: The budget calculus

> **Purpose**: The storage grant, a ceiling inseparable from its concurrency, admission, and the reaper.
> **Read this if**: a byte has to be accounted for before it is written, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.
Its first deliverable is a `Grant` value issued from a finite pool, specific to a location and purpose, with no unbounded constructor, and this phase sits where the vocabulary it consumes first exists.
The rule behind the budget calculus is owned by [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, documents/engineering/jit_budget_doctrine.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: The budget calculus ✅](#sprint-41-the-budget-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — built and sealed 2026-08-20, the second of the five inserted calculi to be built. `python3
tools/budget_calculus_gate.py` passes all fifteen sides on substrate `none`, lane `none`, natural `arm64`,
untranslated. The authored capacity table gives 24 demand vectors a verdict and a reason, names every reason
admission can give and no other, and repeats no vector. The four calculus modules carry no ambient read and no
partial token, and the suite reaches its acceptance token with ten checks green. Both refusals leave the store
byte-identical when its image is read from a second process; the forged grant and the reaper-less retention
each have no type while their legal twins compile; and all three seeded mutants redden their own locus and no
other. Attestation
`sha256:569236c8d48ed0bdc720562b5a00c9c11dd84faa3657c7124ccede8ea705ff86` binds to a 2,100-file source
snapshot; as everywhere here, the reference names the run and this record follows it.

**The run also builds `.build/grants/**`**, the output class
[`repository_layout_doctrine.md` §3.1](../documents/engineering/repository_layout_doctrine.md#31-canonical-build-tree)
reserves for per-region grant accounting and the generator registry named this phase as the owner of. Four
regions are written, each holding within its own ceiling and concurrency, and the registry row stops naming a
phase and starts naming a tool.

**Two decisions this phase took rather than inherited.**

The budget calculus does not depend on the artifact calculus at the package level, and the reason is the
divergence [Phase 3](phase_03_artifact_calculus.md) recorded rather than a preference: a library sharing
`hs-source-dirs: src` with a sibling it also depends on recompiles that sibling's modules as home modules and
does not build. The two calculi meet in the suite, whose own source directory is elsewhere, where a Phase-3
rendering and its address become the placement a Phase-4 grant authorises. That is also the honest layering —
a grant authorises bytes, and how those bytes got their name is the other calculus's question.

`admit` has no store in its type, so an admission refusal cannot touch one and the contract's "byte-identical"
claim is true of it by construction. A property true by construction cannot be broken by a seeded mutant,
which means nothing would be holding it, so `materializeUnder` returns the store on both paths instead — and
that is where the third mutant lands. The gate reports both refusals and says which of the two is the load
bearing one.

## Phase Summary

Make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.

**Phase scope:** one cohesive claim — *no byte exists without an authority that bounded it in advance*. The grant, the concurrency inseparable from its ceiling, admission and the reaper are four faces of that single authority.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, whose materialize step is the operation a grant authorises.
**Gate:** `python3 tools/budget_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
- **Committed mutants.** Mutants separate the ceiling from its concurrency, default a grant to unbounded, and admit after a partial write.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a retention grant that has no constructor without a reaper.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.

## Sprints

## Sprint 4.1: The budget calculus ✅

**Status**: Done — 2026-08-20.
**Implementation**: `src/Amoebius/Calculus/Budget/{Grant,Admission,Store,Retention}.hs`,
`tools/budget_calculus_gate.py`, `test/spec/calculus/BudgetCalculusSpec.hs`,
`test/oracle/budget_calculus/admission_table.tsv`, `test/oracle/budget_calculus_surfaces.tsv`,
`test/negative/compile_fail/budget_calculus/{retention_names_its_reaper,retention_omits_its_reaper,grant_comes_from_the_issuer,grant_forged_unbounded}.hs`
**Blocked by**: None.
**Independent Validation**: A capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
**Docs to update**: `documents/engineering/jit_budget_doctrine.md`

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
arm rather than to whichever check happened to run first.

### Remaining Work

None for this phase. Whether a composition's grant is the sum of its parts' is C5's claim over the lift
calculus, which is the next phase's, and is recorded `UNVERIFIED` here; nothing in this register observes a
running system, so the substrate's actual free space remains the live-effect observation
[`jit_budget_doctrine.md` §7](../documents/engineering/jit_budget_doctrine.md#7-the-residue) says it is.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — **done 2026-08-20.** §7's
  "nothing here is built" is replaced by what is: the grant, admission, the staging rule, and the reaper, as
  pure values in Register 1. What stays unbuilt is named rather than dropped — §6's additivity is stated over
  the lift calculus above this one, and §7's free-space observation is not a decision result at all.

**Cross-references to add:**

- `tools/generator_registry.tsv` — **done 2026-08-20.** The `grants/**` row named phase 4 as the owner of an
  unbuilt output class; it now names `tools/budget_calculus_gate.py`, which writes it.

## Related Documents
- [Development Plan](README.md)
- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.
