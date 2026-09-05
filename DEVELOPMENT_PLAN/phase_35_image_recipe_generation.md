# Phase 35: The amoebius image recipe

> **Purpose**: Constrain the generated image recipe with independently authored semantics, and constrain the
> plain native build invocation token by token, without retaining renderer output under version control or running a container
> engine.
> **Read this if**: the typed bake catalog, Dockerfile projection, base-channel boundary, or image-build argv
> has to change.

This is the active Phase-35 contract. Its implementation is bound below, while completion remains exclusively
owned by the exact integrated gate and the mechanical status projection that follows a pass.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/image_build_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 35.1: The typed catalog and its total projection](#sprint-351-the-typed-catalog-and-its-total-projection-)
- [Sprint 35.2: The semantic recipe oracle](#sprint-352-the-semantic-recipe-oracle-)
- [Sprint 35.3: The authored channel and run-local resolution value](#sprint-353-the-authored-channel-and-run-local-resolution-value-)
- [Sprint 35.4: The one-architecture build argv](#sprint-354-the-one-architecture-build-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 34 and every earlier gate have passed in numerical order. The typed Haskell catalog, independent semantic
oracle, digest-free base boundary, exact native-build argv, and three changed-production challenges are bound;
only the complete integrated Phase-35 gate may authorize completion.

---

## Phase Summary

**Target capability — NOT VALIDATED.** The recipe is to be a deterministic projection of a Haskell bake
catalog, never a file maintained by hand. A separately authored Haskell semantic oracle must constrain ordered step identities and acquisition
rungs. Structural assertions then decide the three stages, directive counts, published values, built-product
copies, environment, dynamic base reference, and repeated-render identity. The generated Dockerfile is
materialized only beneath `.build/**`; no copy of renderer output becomes an expectation.

The base is a Haskell-declared channel, `ubuntu:24.04`, rather than an authored digest. `BaseChannel` excludes digest
syntax, while `BaseResolution` records a run-local digest and its resolution source as a value later live code
can fill. The renderer is to declare `ARG BASE_IMAGE` and exactly one `FROM ${BASE_IMAGE}`. The Haskell oracle
must reject an authored digest; this phase does not claim that a registry was contacted or a digest
resolved.

The invocation boundary likewise remains pure. `BuildArgv` accepts an already resolved absolute engine path
and a supplied architecture value, compares it with the requested architecture, and emits exactly one plain `docker build`
for one of the four fixed flavor/architecture tags. It admits no `buildx`, `--platform`, emulation setting, or
multi-architecture join. Haskell-owned cases must cover the fixed token inventory, and
cross-architecture requests refuse before argv emission.

**Phase scope:** one target claim — the generated recipe has Haskell-constrained semantics and its
build argv can express only one native architecture. The seams are the typed projection, semantic oracle,
digest-free base value, and exact argv; a live engine, build, publication, or runtime probe splits out.

**Substrate:** `none` — the Haskell catalog, base boundary, and argv are values; the Dockerfile is lazy
`.build/**` output, and no engine or registry is consulted ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: semantic oracles constrain generated output without treating an output copy
as authority ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 34](phase_34_chain_kernel_boundary.md)
**Gate:** `pb validate phase 35`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-total-image-recipe-boundary` |
| `Subject` | `acquired-image-recipe-supervisor` |
| `Command` | `pb validate phase 35` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-image-recipe-oracle` |
| `Positive controls` | `image-recipe-positive-controls` |
| `Paired negatives` | `paired-image-recipe-negatives` |
| `Mutants` | `applied-image-recipe-production-mutants` |
| `Discovery` | `exact-image-recipe-source-discovery` |
| `Challenge` | `post-acquisition-image-recipe-challenge` |
| `Observer` | `image-recipe-process-observation` |
| `Authority/bypass` | `no-pb-network-engine-host-hardware-or-parallelism` |
| `Freshness` | `fresh-image-recipe-build-root-and-stable-source` |
| `Qualification` | `qualified-image-recipe-harness` |
| `Cleanroom` | `image-recipe-products-contained-below-build` |
| `Legacy closure` | `retired-image-recipe-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-four-receipt` |
| `Residue` | `live-resolution-build-publication-runtime-owners-explicit` |
| `Pass criterion` | `qualified-phase-thirty-five-gate-pass` |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §7 — Goldens become oracles](../documents/engineering/jit_artifact_doctrine.md#7-goldens-become-oracles):
  the image recipe is generated per run and constrained by a separately authored Haskell semantic expectation,
  never by a repository-retained copy of renderer output.
- [`image_build_doctrine.md` §3 — One image per architecture — the tag carries the architecture, not an index](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index):
  the pure argv emitter produces one plain native-build argv and refuses supplied/requested architecture mismatch;
  observing the host and running the engine are later live obligations.
- [`image_build_doctrine.md` §8 — Build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
  an authored channel reaches the dynamic base argument, no authored digest reaches the recipe, and the engine
  arrives as an already resolved absolute path.
- [`generated_artifacts_doctrine.md` §2 — What is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  the typed bake catalog and total renderer are the source; the Dockerfile remains emitted output.

---

## Sprints

> **Historical sprint results.** Earlier completion statements in sprint prose are capability inventory only;
> current completion remains owned by the integrated gate.

## Sprint 35.1: The typed catalog and its total projection ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/{BakeInventory,CanonicalBakeCatalog,BaseChannel,BuildArgv,RenderDockerfile}.hs`, `test/spec/image/{ImageRecipeSpec,ImageRecipeOracle}.hs`, and the package-hidden Phase-35 supervisor own this sprint surface.
**Blocked by**: [Phase 34](phase_34_chain_kernel_boundary.md) gate pass
**Independent Validation**: one clean Haskell semantic/argv suite plus three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/image/ImageRecipeOracle.hs` independently fixes twenty-two recipe rows, four build cases, forty-four argv tokens, calculus values, validation loci, and mutant loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Dhall bake catalog, Python gate, six serialized oracle files, and three materialized mutants.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked image-build and generated-artifact doctrines.

### Objective

Adopt [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what);
make the recipe one total projection over the authored catalog.

### Deliverables

- A closed `BakeStep` union with seven package, nine official-artifact, six built-product, and zero copy-image
  values in the current catalog.
- A total renderer with incomplete patterns rejected by the compiler.
- Deterministic catalog-order emission to `.build/**`; the Dockerfile output remains untracked and absent from
  authored roots.

### Validation

1. The focused `image-recipe-spec` suite validates the authored Haskell catalog and handles every arm.
2. Two renders of the same typed value are byte-identical.

### Remaining Work

The complete integrated Phase-35 gate and its mechanical status projection remain. Live base resolution, engine execution, image build, publication, runtime probes, clusters, and hardware remain later-owned residue.

## Sprint 35.2: The semantic recipe oracle ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/{BakeInventory,CanonicalBakeCatalog,BaseChannel,BuildArgv,RenderDockerfile}.hs`, `test/spec/image/{ImageRecipeSpec,ImageRecipeOracle}.hs`, and the package-hidden Phase-35 supervisor own this sprint surface.
**Blocked by**: Sprint 35.1
**Independent Validation**: one clean Haskell semantic/argv suite plus three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/image/ImageRecipeOracle.hs` independently fixes twenty-two recipe rows, four build cases, forty-four argv tokens, calculus values, validation loci, and mutant loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Dhall bake catalog, Python gate, six serialized oracle files, and three materialized mutants.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked image-build and generated-artifact doctrines.

### Objective

Adopt [`jit_artifact_doctrine.md` §7 — goldens become oracles](../documents/engineering/jit_artifact_doctrine.md#7-goldens-become-oracles);
constrain what the recipe means with a separately authored Haskell semantic expectation and without retaining
generated bytes in the repository.

### Deliverables

- Twenty-two ordered semantic rows, independently authored from the acquisition requirements.
- Exact stage, rung, directive, package, publisher-value, built-product, and environment projections.
- One real five-calculus composition and a generated-output check that forbids the retired serialized
  renderer-output snapshot.

### Validation

1. Removing, reordering, or changing any catalog step makes the semantic join red.
2. The generated recipe and results exist only beneath `.build/**`.

### Remaining Work

The complete integrated Phase-35 gate and its mechanical status projection remain. Live base resolution, engine execution, image build, publication, runtime probes, clusters, and hardware remain later-owned residue.

## Sprint 35.3: The authored channel and run-local resolution value ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/{BakeInventory,CanonicalBakeCatalog,BaseChannel,BuildArgv,RenderDockerfile}.hs`, `test/spec/image/{ImageRecipeSpec,ImageRecipeOracle}.hs`, and the package-hidden Phase-35 supervisor own this sprint surface.
**Blocked by**: Sprint 35.2
**Independent Validation**: one clean Haskell semantic/argv suite plus three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/image/ImageRecipeOracle.hs` independently fixes twenty-two recipe rows, four build cases, forty-four argv tokens, calculus values, validation loci, and mutant loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Dhall bake catalog, Python gate, six serialized oracle files, and three materialized mutants.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked image-build and generated-artifact doctrines.

### Objective

Adopt [`image_build_doctrine.md` §8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract);
separate the authored base channel from the digest a later live run observes.

### Deliverables

- An opaque `BaseChannel` that rejects digest syntax and malformed channel values.
- A `BaseResolution` value carrying channel, digest, and canonical-or-rate-limit-mirror source.
- A catalog with no `baseDigest` field and a renderer with one `ARG BASE_IMAGE` / `FROM ${BASE_IMAGE}` pair.

### Validation

1. A digest literal in the catalog, renderer source, or emitted recipe fails the gate.
2. Distinct run-local resolutions do not alter the recipe's bytes.

### Remaining Work

The complete integrated Phase-35 gate and its mechanical status projection remain. Live base resolution, engine execution, image build, publication, runtime probes, clusters, and hardware remain later-owned residue.

## Sprint 35.4: The one-architecture build argv ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/{BakeInventory,CanonicalBakeCatalog,BaseChannel,BuildArgv,RenderDockerfile}.hs`, `test/spec/image/{ImageRecipeSpec,ImageRecipeOracle}.hs`, and the package-hidden Phase-35 supervisor own this sprint surface.
**Blocked by**: Sprint 35.3
**Independent Validation**: one clean Haskell semantic/argv suite plus three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/image/ImageRecipeOracle.hs` independently fixes twenty-two recipe rows, four build cases, forty-four argv tokens, calculus values, validation loci, and mutant loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Dhall bake catalog, Python gate, six serialized oracle files, and three materialized mutants.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked image-build and generated-artifact doctrines.

### Objective

Adopt [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index);
make a multi-architecture or ambient-path invocation unrepresentable at this boundary.

### Deliverables

- One plain-build argv with an absolute engine path and no `buildx`, platform flag, or emulation setting.
- Four fixed CPU/CUDA × amd64/arm64 tag cases and an exact eleven-token oracle for each.
- A typed refusal when observed and requested architectures differ.

### Validation

1. The four vectors join to all forty-four oracle rows in both directions.
2. The Haskell buildx and second-platform changed-subject mutants fail at their separate loci.

### Remaining Work

The complete integrated Phase-35 gate and its mechanical status projection remain. Live base resolution, engine execution, image build, publication, runtime probes, clusters, and hardware remain later-owned residue.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/image_build_doctrine.md` — §3 records the tested pure native-build argv boundary and
  §8 records the tested digest-free recipe boundary while keeping live resolution UNVERIFIED.
- `documents/engineering/generated_artifacts_doctrine.md` — §3.1 records the serialized renderer-output
  snapshot as retired and names the separately authored Haskell semantic recipe expectation that replaced it.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` — the pure recipe and argv row points here; Phase 56 retains the live
  build and publication boundary.

---

## Related Documents

- [Image Build & Registry](../documents/engineering/image_build_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
- [Phase 34](phase_34_chain_kernel_boundary.md)
- [Phase 52](phase_52_linux_engine_bringup.md)
- [Phase 56](phase_56_base_image_registry.md)
- [Development Plan](README.md)
