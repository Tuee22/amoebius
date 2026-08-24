# Phase 35: The amoebius image recipe

> **Purpose**: Constrain the generated image recipe with independently authored semantics, and constrain the
> plain native build invocation token by token, without retaining renderer output under version control or running a container
> engine.
> **Read this if**: the typed bake catalog, Dockerfile projection, base-channel boundary, or image-build argv
> has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

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
- [Sprint 35.1: The typed catalog and its total projection ⏸️](#sprint-351-the-typed-catalog-and-its-total-projection-)
- [Sprint 35.2: The semantic recipe oracle ⏸️](#sprint-352-the-semantic-recipe-oracle-)
- [Sprint 35.3: The authored channel and run-local resolution value ⏸️](#sprint-353-the-authored-channel-and-run-local-resolution-value-)
- [Sprint 35.4: The one-architecture build argv ⏸️](#sprint-354-the-one-architecture-build-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 34, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** The recipe is to be a deterministic projection of a Haskell bake
catalog, never a file maintained by hand. A separately reviewed Haskell semantic oracle must constrain ordered step identities and acquisition
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
**Gate:** `pb validate phase 35`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — Haskell catalog and oracle values constrain a Dockerfile generated beneath `.build/**`, and the pure argv model admits one supplied native architecture only. No engine, build, registry, publication, or runtime observation is claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 35` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 34; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

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

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 35.1: The typed catalog and its total projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 34](phase_34_chain_kernel_boundary.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

1. The focused `image-recipe-spec` suite decodes the real catalog and handles every arm.
2. Two renders of the same decoded value are byte-identical.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.2: The semantic recipe oracle ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.3: The authored channel and run-local resolution value ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.4: The one-architecture build argv ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
