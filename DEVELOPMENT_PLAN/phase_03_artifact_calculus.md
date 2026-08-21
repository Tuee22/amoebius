# Phase 3: The artifact calculus

> **Purpose**: Targets, recipes, the content-derived address, and the materialize-consume-reap region.
> **Read this if**: an artifact's name, region, or recipe has to be reasoned about, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.
Its first deliverable is a closed `Target` set indexing artifact kinds, so a consumer expecting one kind cannot be handed another, and this phase sits where the vocabulary it consumes first exists.
The rule behind the artifact calculus is owned by [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 3.1: The artifact calculus ✅](#sprint-31-the-artifact-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-20, the first of the five inserted calculi to be built. `python3
tools/artifact_calculus_gate.py` passes all fourteen sides on substrate `none`, lane `none`, natural `arm64`,
untranslated: the authored address oracle names 24 cells over six targets and four inputs, the four calculus
modules carry no ambient read and no partial token, the in-process suite reaches its acceptance token with
eleven checks green, two independently seeded processes render identical bytes over all six targets, the region
escape has no type while its legal twin compiles, and all three seeded mutants redden their own locus and no
other. Attestation
`sha256:520eb5ce22f97fbc6e334b83aeae88de21d94384d180d4d1b6e49f6f9570cf98` binds to a 2,066-file source
snapshot; as everywhere here, the reference names the run and this record follows it.

**Two divergences this phase found rather than introduced**, both recorded in
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md#still-open-after-this-change): a library
that shares `hs-source-dirs: src` with a sibling it also depends on recompiles that sibling's modules as home
modules and fails to build, which `release-lifecycle` does today on an unmodified tree; and the content address
now has two renderings, this phase's and the store's, because the calculus is below the store and cannot
depend on it.

## Phase Summary

Give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.

**Phase scope:** one cohesive claim — *an artifact cannot exist without a recipe that produced it and a name that is a function of its content*. The kind index, the pure renderer, the address and the region that ends are one claim seen at four points.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 2](phase_02_repository_layout_conformance.md) — the target tree, which fixes the paths a recipe renders into. This is the first of the five calculi and consumes no algebra beneath it.
**Gate:** `python3 tools/artifact_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** An address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
- **Committed mutants.** Mutants drop the rendered bytes from the address, admit a clock into a recipe, and let a handle escape its region.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a region whose exit reaps every artifact materialized inside it and not promoted to retained.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: an address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind the artifact calculus.

## Sprints

## Sprint 3.1: The artifact calculus ✅

**Status**: Done — 2026-08-20.
**Implementation**: `src/Amoebius/Calculus/Artifact/Target.hs`,
`src/Amoebius/Calculus/Artifact/Recipe.hs`, `src/Amoebius/Calculus/Artifact/Address.hs`,
`src/Amoebius/Calculus/Artifact/Region.hs`, `tools/artifact_calculus_gate.py`,
`test/spec/calculus/ArtifactCalculusSpec.hs`, `test/spec/calculus/ArtifactCorpus.hs`,
`test/oracle/artifact_calculus/address_inputs.tsv`, `test/oracle/artifact_calculus_surfaces.tsv`,
`test/negative/compile_fail/artifact_calculus/handle_stays_in_region.hs`,
`test/negative/compile_fail/artifact_calculus/handle_escapes_region.hs`
**Blocked by**: None.
**Independent Validation**: An address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
**Docs to update**: `documents/engineering/jit_artifact_doctrine.md`

### Objective

Give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.

### Deliverables

- A closed `Target` set indexing artifact kinds, so a consumer expecting one kind cannot be handed another.
- A `Recipe` as a pure function from a declaration to rendered content, with no clock, environment or directory read.
- An address digesting target, recipe identity, declaration and the rendered bytes together.
- A region whose exit reaps every artifact materialized inside it and not promoted to retained.

### Validation

Two independently seeded processes render each target and must agree byte for byte; an artifact referenced after its region ends fails to compile.

**Both are checked where they can actually fail, which is not where the suite runs.** The determinism claim is
one a single process structurally cannot settle: it shares whatever ambient state a recipe reached for, so it
would agree with itself. The suite therefore prints its renderings under a seed given on the command line and
the gate runs it twice with different seeds — and the clock mutant proves the arrangement is load-bearing, by
leaving the in-process suite entirely green while the two reports diverge. The escape claim is a type-level
one, so it is a committed compile-fail pair typechecked under `-fno-code` rather than a test that runs, and the
gate requires the rejection to name the rigid type variable rather than merely to fail.

### Remaining Work

None for this phase. The budget a materialization spends is the next calculus's and is recorded `UNVERIFIED`
here; nothing in this register observes a running system.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind the artifact calculus.
