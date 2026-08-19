# Phase 5: The amoebius image recipe

> **Purpose**: Seal the rendered image recipe as bytes — a pure projection of the typed bake catalog, pinned
> to a committed golden — and pin the invocation that carries it to exactly one architecture.
> **Read this if**: the recipe's rendered bytes have to change, or the build argv has to gain or lose a token.

This phase owns the recipe as a value: the bytes the renderer projects from the typed bake catalog, and the
argv that would hand those bytes to a container engine. It does not own the engine, the build, the push, or
the registry — those are effects on a live substrate, and
[Phase 36](phase_36_base_image_registry.md) owns them under
[`image_build_doctrine.md` §8](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract).
Its one prerequisite is the ensure algebra [Phase 4](phase_04_host_ensure_kernel.md) delivered, which is what
resolves a tool to an absolute path.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/phase_06_linux_engine_bringup.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: The typed catalog and its total projection 📋](#sprint-51-the-typed-catalog-and-its-total-projection-)
- [Sprint 5.2: The sealed recipe golden 📋](#sprint-52-the-sealed-recipe-golden-)
- [Sprint 5.3: The authored channel and the resolved digest 📋](#sprint-53-the-authored-channel-and-the-resolved-digest-)
- [Sprint 5.4: The one-architecture build argv 📋](#sprint-54-the-one-architecture-build-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. No sprint has run; this phase has no implementation footprint and claims none.

---

## Phase Summary

The recipe is not a file a person maintains, it is the output of a pure projection over the typed bake
catalog. This phase seals that output. One committed golden holds the exact rendered bytes, and the gate
compares every render against them. A projection that is only asserted pure drifts one stage at a time and
nothing reports it; a projection whose bytes are pinned cannot drift without a reviewed diff.

*The recipe does not change as the remaining Haskell lands* is not a promise a plan can hold — a plan cannot
observe a later commit. What holds it is the golden: its bytes are fixed here, and no later phase's
`Docs to update` block names it. A phase whose new understanding moves those bytes reopens this phase rather
than editing the golden in passing ([§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)).

Two properties travel with the bytes and are sealed beside them. The recipe declares `ARG BASE_IMAGE` and
opens `FROM ${BASE_IMAGE}`, so no authored digest reaches it: the channel is authored, and the digest is
resolved per run and recorded beside the output. A digest a reviewer typed is one resolution asserted
forever, so the seal holds only while the rendered bytes carry none. The argv carries exactly one
architecture and no platform flag — no buildx, no BuildKit multi-platform invocation, no emulation — because a
container shares the host kernel and therefore the host instruction set.

**Phase scope:** one cohesive claim — *the rendered recipe is sealed byte-for-byte and its build argv is
pinned to exactly one architecture*. Its sprint seams are the projection, the golden, the digest boundary, and
the argv. It splits if a second architecture, a second acceptance register, or a live build appears.

**Substrate:** `none` — a Dockerfile is text and an argv is a value, so neither claim needs a host ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/golden: the claim is about a value, and no daemon is consulted to decide it ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on**: [Phase 4](phase_04_host_ensure_kernel.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/amoebius_image_recipe_gate.py` passes every check named in
[Gate integrity](#gate-integrity). Phase 6 does not open until it is green.

---

## Gate integrity

The gate is `python3 tools/amoebius_image_recipe_gate.py`, and it decides four things that are decidable
without a container engine.

**The render is compared to committed bytes, not to a description.**
`test/golden/amoebius_image_recipe/Dockerfile.golden` holds the complete rendered recipe, committed in full
rather than as a hash — a hash tells a reviewer that something moved and never what. Any difference fails,
whichever side is right, and the gate carries no refresh path: a golden a gate may rewrite records nothing.

**No authored digest reaches the recipe.** The gate scans the rendered bytes for a `sha256:` literal and for a
`FROM` whose reference is anything other than `${BASE_IMAGE}`; either is a failure. The digest belongs to the
run's record rather than to a tracked file, so the rendered bytes are stable across a republished upstream
base and a reviewer never approves a diff that carries no decision.

**The argv is joined against an independently authored oracle.**
`test/oracle/amoebius_image_recipe/build_argv.tsv` enumerates every token the invocation may carry, in order,
with the one architecture its tag names. The join runs in both directions, so a token the oracle does not name
and an oracle row the emitter never produces are both failures. The oracle is authored from the doctrine, not
captured from a run, because an emitter that writes its own expectation proves only that it is consistent.

**Three mutants are committed to `test/mutant/registry.tsv`**, and each must turn exactly one check red. An
argv that reaches the engine through a `buildx` subcommand reddens the oracle join. A second platform flag
reddens the one-architecture check. A `FROM` carrying an authored `sha256:` literal reddens the
digest-boundary scan. A mutant that reddens two checks is as much a defect as one that reddens none, because
it shows the checks do not separate what they claim to separate.

---

## Doctrine adopted

- [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index):
  one plain build per architecture on a host of that architecture, the architecture in the reference rather
  than in a manifest index, and no join between the two.
- [`image_build_doctrine.md` §8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
  a rendered recipe carries no authored digest, and the engine is invoked by a resolved absolute path rather
  than found on an ambient search path.
- [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  the recipe's source of truth is the typed bake catalog and its renderer is pure and total, so the rendered
  file is emitted rather than committed.

---

## Sprints

## Sprint 5.1: The typed catalog and its total projection 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/BakeCatalog.dhall`, `src/Amoebius/Image/BakeInventory.hs`, `src/Amoebius/Image/RenderDockerfile.hs`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: the renderer is total over the catalog's step union and emits identical bytes on repetition
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Adopt [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what);
make the recipe the output of one authored value rather than a file anyone edits by hand.

### Deliverables

- The typed bake catalog as the single authored source: each stage a non-empty step sequence, with no arm
  carrying a free shell string or a free URL, because either arm re-admits the untyped recipe this projection
  exists to replace.
- A total renderer over that step union with no default case, so an unhandled arm is a compile failure rather
  than a stage silently dropped from the output.
- A deterministic emission order derived from the catalog's own structure, so the bytes do not depend on the
  traversal order of a map.
- The rendered file's home beneath `.build/`, untracked, because an artifact that is both generated and
  tracked has two sources of truth and no rule saying which wins.

### Validation

1. Adding an arm to the step union fails to compile until the renderer handles it.
2. Two renders of the same catalog in one process emit byte-identical output.

### Remaining Work

The whole sprint.

## Sprint 5.2: The sealed recipe golden 📋

**Status**: Planned
**Implementation**: `test/golden/amoebius_image_recipe/Dockerfile.golden`, `tools/amoebius_image_recipe_gate.py`
**Blocked by**: Sprint 5.1
**Independent Validation**: the render matches the committed golden byte for byte, and no gate path rewrites it
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Seal the projection's output, so that changing the recipe is a reviewed change to committed bytes rather than
an observation made after the fact.

### Deliverables

- One golden holding the complete rendered recipe, so a reviewer reads the change rather than a digest of it.
- A comparison that reports the first differing line and its byte offset, so a failure is actionable without
  reaching for a second tool.
- No refresh path inside the gate; regeneration is an explicit maintainer command the gate never invokes.
- A registry row per seeded mutant naming the single check it must redden, so a mutant that spreads across
  checks is visible as a defect in the checks.

### Validation

1. A one-byte change to the renderer's output fails the gate.
2. Two consecutive gate runs leave the golden's bytes unchanged.

### Remaining Work

The whole sprint.

## Sprint 5.3: The authored channel and the resolved digest 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/BaseChannel.hs`, `src/Amoebius/Image/RenderDockerfile.hs`
**Blocked by**: Sprint 5.2
**Independent Validation**: the rendered bytes carry no `sha256:` literal and exactly one `FROM ${BASE_IMAGE}`
**Docs to update**: `documents/engineering/image_build_doctrine.md`

### Objective

Adopt [`image_build_doctrine.md` §8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract);
keep every public identity an authored channel in the tree and a resolved digest in the run's record.

### Deliverables

- `ARG BASE_IMAGE` declared ahead of the first `FROM`, and `FROM ${BASE_IMAGE}` as the recipe's only base
  reference, so the digest enters as an argument value rather than as recipe text.
- The channel authored in the catalog as a name and a tag with no digest field at all, because a field that
  can hold a digest eventually holds one.
- The run record's shape — the channel, the digest it resolved to, and where that resolution came from —
  authored here as a type; the resolution that fills it is the live build's at
  [Phase 36](phase_36_base_image_registry.md).

### Validation

1. A `sha256:` literal anywhere in the rendered bytes fails the gate.
2. The rendered bytes are unchanged when the channel is stated to resolve to a different digest.

### Remaining Work

The whole sprint.

## Sprint 5.4: The one-architecture build argv 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/BuildArgv.hs`, `test/oracle/amoebius_image_recipe/build_argv.tsv`
**Blocked by**: Sprint 5.3
**Independent Validation**: the emitted argv joins to the authored oracle in both directions and names one architecture
**Docs to update**: `documents/engineering/image_build_doctrine.md`

### Objective

Adopt [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index);
emit an invocation that can build only the architecture the host already executes.

### Deliverables

- A plain build argv with no `buildx` subcommand, no platform flag, and no emulation setting, because a
  container shares the host kernel and an image for an instruction set the host cannot run is not something a
  build honestly produces.
- The architecture carried in the tag the argv names rather than in a manifest index, so the reference
  identifies bytes rather than a set of them.
- An engine named by an absolute path supplied to the emitter, never as a bare command token; resolving that
  path is Phase 4's and this sprint only consumes the result.
- A refusal that compares the requested architecture against the observed host architecture before emitting
  anything, so a mismatch stops the emission instead of producing an argv that would emulate.

### Validation

1. An argv naming two architectures is unrepresentable: the emitter takes one architecture and its type
   admits no list.
2. A `buildx` token in the emitted argv fails the oracle join.

### Remaining Work

The whole sprint.

---

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/image_build_doctrine.md` — §3 records the sealed single-architecture argv and §8 the
  recipe's digest-free base reference, once both are sealed rather than planned.
- `documents/engineering/generated_artifacts_doctrine.md` — §2's image-recipe row names the golden that pins
  the projection's output.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/system_components.md` — the bake-catalog row points here for the sealed recipe and at
  Phase 36 for the build that consumes it.

---

## Related Documents
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
- [Phase 4](phase_04_host_ensure_kernel.md)
- [Phase 36](phase_36_base_image_registry.md)
- [Development Plan](README.md)
