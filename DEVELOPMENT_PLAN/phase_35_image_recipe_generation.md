# Phase 35: The amoebius image recipe

> **Purpose**: Constrain the generated image recipe with independently authored semantics, and constrain the
> plain native build invocation token by token, without committing renderer output or running a container
> engine.
> **Read this if**: the typed bake catalog, Dockerfile projection, base-channel boundary, or image-build argv
> has to change.

This phase owns the pure recipe and invocation boundary. The typed catalog projects to an untracked
Dockerfile whose meaning is checked by authored semantic rows; the build emitter projects one absolute-path
plain-build argv for one observed architecture. It does not own engine bring-up, image construction,
publication, or runtime correspondence. Those are live effects owned by later phases, beginning with
[Phase 52](phase_52_linux_engine_bringup.md) and [Phase 56](phase_56_base_image_registry.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/image_build_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 35.1: The typed catalog and its total projection ✅](#sprint-351-the-typed-catalog-and-its-total-projection-)
- [Sprint 35.2: The semantic recipe oracle ✅](#sprint-352-the-semantic-recipe-oracle-)
- [Sprint 35.3: The authored channel and run-local resolution value ✅](#sprint-353-the-authored-channel-and-run-local-resolution-value-)
- [Sprint 35.4: The one-architecture build argv ✅](#sprint-354-the-one-architecture-build-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21 by the reconciled Register-1 semantic-recipe and exact-argv gate.

**Validation record.** The isolated gate passed on natural `darwin/arm64`, untranslated. All 26 metrics
match; 37 surfaces join to 63 enumerated items; all three paired mutants redden at their exact loci; and the
rendered Dockerfile remains beneath `.build/**`. Attestation
`sha256:438484c249a92f555afce5a684425a75f24522368e847aed60fa08a1e39368f4` binds source
`sha256:2e1f9a9e9e580eaf…` over 2,246 files. Live image build, publication, and runtime correspondence remain
UNVERIFIED.

**Activated 2026-08-21** when the preceding phase resealed.

---

## Phase Summary

The recipe is a deterministic projection of the typed bake catalog, not a file maintained by hand. Its
independently authored semantic oracle fixes all twenty-two ordered step identities and their four acquisition
rungs. Structural assertions then decide the three stages, directive counts, published values, built-product
copies, environment, dynamic base reference, and repeated-render identity. The generated Dockerfile is
inspected during the run and remains untracked; no copy of renderer output becomes an expectation.

The base is an authored channel, `ubuntu:24.04`, rather than an authored digest. `BaseChannel` excludes digest
syntax, while `BaseResolution` records a run-local digest and its resolution source as a value later live code
can fill. The renderer declares `ARG BASE_IMAGE` and has exactly one `FROM ${BASE_IMAGE}`. This phase proves
that the pure boundary carries no authored digest; it does not claim that a registry was contacted or a digest
resolved.

The invocation boundary likewise remains pure. `BuildArgv` accepts an already resolved absolute engine path,
compares the requested architecture with the observed architecture, and emits exactly one plain `docker build`
for one of the four fixed flavor/architecture tags. It admits no `buildx`, `--platform`, emulation setting, or
multi-architecture join. Four authored cases enumerate all forty-four tokens in both directions, and two
cross-architecture requests refuse before argv emission.

**Phase scope:** one cohesive claim — the generated recipe has independently constrained semantics and its
build argv can express only one native architecture. The seams are the typed projection, semantic oracle,
digest-free base value, and exact argv; a live engine, build, publication, or runtime probe splits out.

**Substrate:** `none` — the Dockerfile, catalog, base boundary, and argv are values; no engine or registry is
consulted ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: semantic oracles constrain generated output without treating an output copy
as authority ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 34](phase_34_chain_kernel_boundary.md) — its opaque absolute `ToolPath` boundary is the
input the argv emitter consumes; no later host-ensure phase is a prerequisite for this pure projection.

**Gate:** `python3 tools/run_phase_gate.py 35` passes the semantic recipe, exact argv,
five-calculus, mutant, generated-output, ledger, containment, and attestation checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

The gate is `python3 tools/amoebius_image_recipe_gate.py`. It decides only the pure recipe and invocation
claims that Register 1 can observe.

**The representative recipe set is independently authored.**
`test/oracle/amoebius_image_recipe/recipe_semantics.tsv` lists all twenty-two catalog steps in order: seven
`AptPackage`, nine `OfficialArtifact`, six `BuildProduct`, and zero `CopyOci` rows. The suite joins the real
Dhall decode and renderer to those rows, verifies every apt identity, publisher URL and checksum-manifest
projection, built-product copy, stage and directive count, and renders twice from the same value. The
generated Dockerfile is emitted to `.build/dsl/image-recipe/Dockerfile`; a tracked renderer-output golden is
forbidden.

**The base boundary is digest-free but does not pretend to resolve.** The source and rendered recipe contain no
authored `baseDigest` or `sha256:` value, and the render contains exactly one global `ARG BASE_IMAGE` and one
`FROM ${BASE_IMAGE}`. Two distinct `BaseResolution` values prove that resolution is run-local data. Network
resolution, digest fidelity, live build use, and runtime correspondence are recorded as UNVERIFIED.

**The invocation oracle is exact in both directions.**
`test/oracle/amoebius_image_recipe/{build_cases,build_argv}.tsv` names the CPU/CUDA × amd64/arm64 product and all
eleven ordered tokens for each case. The first token is an absolute engine path, the second is `build`, each
tag is fixed, and neither `buildx` nor `--platform` appears. Two observed/requested mismatches must return the
typed refusal rather than an argv.

**The five calculi reach the real code.**
`test/oracle/amoebius_image_recipe/calculus_projection.tsv` fixes the artifact, budget, lift, workflow, and
evidence component names, their `22,44,4,4,3` projection counts, and their `5,77,0,0` resource vector. The
test constructs those real calculus values and checks their composition rather than printing a disconnected
claim.

**Three paired mutants separate the claims.** The registry and descriptors name an authored base digest, a
`buildx` insertion, and a second platform flag. For each, the original must pass, the mutated value must fail,
and the process must exit red at the mutant's own expected locus. The 29-row validation-locus ledger joins all
twenty-two recipe steps, four build cases, and three mutants in both directions.

- **Extension conformance (§M.13).** Not applicable: this phase delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §7 — goldens become oracles](../documents/engineering/jit_artifact_doctrine.md#7-goldens-become-oracles):
  the image recipe is generated per run and constrained by authored semantics, never by a committed copy of
  renderer output.
- [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index):
  the pure argv emitter produces one plain native build and refuses observed/requested architecture mismatch.
- [`image_build_doctrine.md` §8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
  an authored channel reaches the dynamic base argument, no authored digest reaches the recipe, and the engine
  arrives as an already resolved absolute path.
- [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  the typed bake catalog and total renderer are the source; the Dockerfile remains emitted output.

---

## Sprints

## Sprint 35.1: The typed catalog and its total projection ✅

**Status**: Done
**Implementation**: `dhall/amoebius/BakeCatalog.dhall`, `src/Amoebius/Image/BakeInventory.hs`, `src/Amoebius/Image/RenderDockerfile.hs`
**Blocked by**: none within the phase
**Independent Validation**: the real catalog decodes, all four arms are exhaustive, and two renders are byte-identical
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Adopt [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what);
make the recipe one total projection over the authored catalog.

### Deliverables

- A closed `BakeStep` union with seven package, nine official-artifact, six built-product, and zero copy-image
  values in the current catalog.
- A total renderer with incomplete patterns rejected by the compiler.
- Deterministic catalog-order emission to `.build/**`, with no tracked Dockerfile output.

### Validation

1. The focused `image-recipe-spec` suite decodes the real catalog and handles every arm.
2. Two renders of the same decoded value are byte-identical.

### Remaining Work

None.

## Sprint 35.2: The semantic recipe oracle ✅

**Status**: Done
**Implementation**: `test/oracle/amoebius_image_recipe/{recipe_semantics,calculus_projection,validation_locus}.tsv`, `test/spec/image/ImageRecipeSpec.hs`, `tools/amoebius_image_recipe_gate.py`
**Blocked by**: Sprint 35.1
**Independent Validation**: twenty-two authored semantics join to the real render and the output remains untracked
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Adopt [`jit_artifact_doctrine.md` §7 — goldens become oracles](../documents/engineering/jit_artifact_doctrine.md#7-goldens-become-oracles);
constrain what the recipe means without committing a copy of generated bytes.

### Deliverables

- Twenty-two ordered semantic rows, independently authored from the acquisition requirements.
- Exact stage, rung, directive, package, publisher-value, built-product, and environment projections.
- One real five-calculus composition and a generated-output check that forbids the retired planned golden.

### Validation

1. Removing, reordering, or changing any catalog step makes the semantic join red.
2. The generated recipe and results exist only beneath `.build/**`.

### Remaining Work

None.

## Sprint 35.3: The authored channel and run-local resolution value ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/BaseChannel.hs`, `src/Amoebius/Image/{BakeInventory,RenderDockerfile}.hs`, `dhall/amoebius/BakeCatalog.dhall`
**Blocked by**: Sprint 35.2
**Independent Validation**: the catalog and recipe admit no authored digest and contain one dynamic base reference
**Docs to update**: `documents/engineering/image_build_doctrine.md`

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

None.

## Sprint 35.4: The one-architecture build argv ✅

**Status**: Done
**Implementation**: `src/Amoebius/Image/BuildArgv.hs`, `test/oracle/amoebius_image_recipe/{build_cases,build_argv}.tsv`
**Blocked by**: Sprint 35.3
**Independent Validation**: four emitted argv vectors join exactly to forty-four authored tokens and two mismatches refuse
**Docs to update**: `documents/engineering/image_build_doctrine.md`

### Objective

Adopt [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index);
make a multi-architecture or ambient-path invocation unrepresentable at this boundary.

### Deliverables

- One plain-build argv with an absolute engine path and no `buildx`, platform flag, or emulation setting.
- Four fixed CPU/CUDA × amd64/arm64 tag cases and an exact eleven-token oracle for each.
- A typed refusal when observed and requested architectures differ.

### Validation

1. The four vectors join to all forty-four oracle rows in both directions.
2. The buildx and second-platform mutants fail at their separate loci.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update when the reconciled gate seals:**
- `documents/engineering/image_build_doctrine.md` — §3 records the tested pure native-build argv boundary and
  §8 records the tested digest-free recipe boundary while keeping live resolution UNVERIFIED.
- `documents/engineering/generated_artifacts_doctrine.md` — §3.1 records the renderer-output golden as retired
  and names the semantic recipe oracle that replaced it.

**Cross-references to update:**
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
