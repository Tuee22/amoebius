# Phase 93: The jitML numerical core, re-derived

> **Purpose**: Re-derive the `jitML` numerical and training core as an amoebius-owned workload extension —
> the guarantee it adds being a storage grant that carries its own ceiling, which the seed's cache does not —
> and test that one scope-bound CUDA training request produces a pointer-committed checkpoint artifact
> through gate-passed predecessor workflow, cache, accelerator-owner, and content-store seams, with no silent CPU
> fallback.
> **Read this if**: phase 93 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, documents/engineering/content_addressing_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 93.1: Produce one pointer-committed jitML artifact on CUDA ⏸️](#sprint-931-produce-one-pointer-committed-jitml-artifact-on-cuda-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 92, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**What this phase re-derives, and what it must add.** The seed's cache grows without a type that bounds it; amoebius re-derives the numerical core so every retained artifact is charged against a grant that carries its ceiling and its concurrency together, and names the reaper that returns it.

This phase owns one primary seam:

```text
ScopedTrainingRequest tenant app
  + ProvisionedCudaTraining
  -> CommittedJitMLArtifact tenant app
```

The scoped leaf compiles the sibling CUDA runtime-operations code generator behind that seam; the full
numerical, autodiff, SL/RL, tuning, and checkpoint modules remain outside the tested linkage. They do not
become a standalone service or another binary. A Haskell workload-extension value requires the existing
`JitBuild`, `Coordination`, and `InferenceEngine` capabilities; any Dhall projection is generated lazily
beneath `.build/dhall/**` or supplied as an external, untracked operator input, never repository source. It has no
replica, region, failover, provider, raw endpoint, bucket, object-key, or arbitrary engine-download field.
Those decisions remain trusted bind/provision outputs.

The checkpoint adapter uses Phase 69 content digests and canonical component manifests for its pure contract.
The scoped live driver writes batch and 40 MB checkpoint blobs, a canonical JSON runtime-evidence manifest, and a
create-only conditional pointer to retained MinIO. Only the successful pointer-write witness can construct the opaque
`CommittedJitMLArtifact tenant app`. In-flight, failed, orphaned, raw-path, and manifest-only states have no
conversion to that type. The artifact retains its trusted tenant/app scope, manifest SHA, committed pointer
revision, and original command/work identity; none is accepted from an untrusted artifact claim.
Experiment-hash, engine-catalog, and complete substrate-fingerprint retention in the full sibling manifest
remain UNVERIFIED.

CUDA is selected from `linux-cuda`, and the pure admission applies the fixed Phase-0 catalog identity. Before
any modeled run-scoped effect, the provision fold checks the training floor, target, whole-device count,
mandatory reserve, net allocatable, and observed current-free ceilings. The planned exact join across every training,
serving, and Tier-3 JIT source to its workload demand, derives every permitted coexistence epoch, and checks
device family/profile, whole-device count, sharding/link constraints, each device's net allocatable VRAM after
its mandatory driver/runtime reserve, and live `currentFreeVram`. The named accelerator-owner container then
receives equal integer `nvidia.com/gpu` request and limit for the selected node's full device offering plus the
required affinity remains the target Kubernetes-owner shape. A CPU target and both one-short capacity twins
are pre-effect rejections in the pure contract; there is no fallback arm.

The live driver uses `libcuda.so.1` to load an `sm_52` PTX optimizer kernel, allocates 10,000,000 float
parameters, launches 200 steps, and copies a 40 MB checkpoint whose every byte equals an independent float32
oracle. `nvidia-smi` independently observes the process and device. The retained kind node advertises no GPU,
so the device plugin, owner Pod/resource claim/affinity, native CBOR/Pulsar chain, Vault credential, mutable
ETag-CAS pointer, full sibling multi-layer trainer/checkpoint format, and failover remain UNVERIFIED.

The output of this phase is the core pointer-committed artifact contract. Here, "committed" always names an
observed content-store pointer state, never a version-control operation or repository artifact. Phase 94 alone owns its downstream
presentation and interaction adapter; no interaction-ready handle is produced or accepted here.

The bounded campaign covers one scoped CUDA-microtrainer-to-pointer-committed-artifact slice, one package, one pure
suite, one live evidence reader, and one aggregate command; no Phase-94 presentation work is included.
**Phase scope:** one cohesive claim — *a CUDA training request is bound to a scope, and there is no silent fall back to CPU*. The checkpoint it produces is committed by pointer through the existing seams.

**Substrate:** linux-cuda
**Lane:** cuda ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Depends on:** [Phase 92](phase_92_infernix_ui_rederivation.md)
**Gate:** `pb validate phase 93`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *a CUDA training request is bound to a scope, and there is no silent fall back to CPU*. The checkpoint it produces is committed by pointer through the existing seams. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 93` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 92; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map):
  reuse jitML's computational substance while replacing its infrastructure envelope.
- [`capability_extension_doctrine.md` §5 — The requirement edges](../documents/engineering/capability_extension_doctrine.md#5-the-requirement-edges):
  bind jitML only through the existing `JitBuild`, `Coordination`, and `InferenceEngine` providers.
- [`content_addressing_doctrine.md` §2 — The three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  and [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  require pointer-CAS commitment and closed-catalog first-miss materialization.
- [`daemon_topology_doctrine.md` §4.2 — The accelerator-owner worker: wholesale per-node ownership, a typed per-node singleton](../documents/engineering/daemon_topology_doctrine.md#42-the-accelerator-owner-worker-wholesale-per-node-ownership-a-typed-per-node-singleton):
  give exactly one named owner container the node's wholesale device claim.
- [`resource_capacity_doctrine.md` §8 — Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime):
  spend net allocatable and current-free device capacity before effects.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence):
  correlate a post-start challenge with independently observed CUDA and store effects.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 93.1: Produce one pointer-committed jitML artifact on CUDA ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 92](phase_92_infernix_ui_rederivation.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map)
and [Content Addressing Doctrine §2 — Three-tier store](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers):
adapt one real sibling jitML training path to amoebius's existing scoped workflow, closed-catalog CUDA,
accelerator-owner, and pointer-committed store contracts so the only successful output is an opaque pointer-committed
artifact carrying its trusted scope and provenance.

### Deliverables

- The linked jitML library and closed Haskell workload-extension declaration, with infrastructure and authority
  fields absent from its authored surface; any Dhall package projection is generated lazily beneath ignored
  `.build/**` and remains untracked.
- The canonical checkpoint adapter and opaque `CommittedJitMLArtifact tenant app`, constructible only from a
  successful Phase-69 pointer-CAS witness.
- One scope-qualified command/work-id preserved through the native CBOR command/event chain and the
  idempotent training fold.
- The substrate-selected CUDA engine binding and provision-derived accelerator-owner allocation, with no CPU
  fallback or arbitrary download path.
- The Phase-0 Haskell oracle corpus, four Haskell-authored changed-subject operators, live Haskell harness, and generated Register-3 run ledger with
  challenge correlation and idempotent teardown.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-93 supporting suite must run on `linux-cuda`.
2. Require pure CPU/floor/capacity/identity/idempotency/commit checks and all four Haskell changed subjects to pass or turn red
   at their exact loci.
3. Require physical CUDA device/process inventory, 10-million-parameter/200-step execution, complete
   checkpoint-oracle equality, retained-MinIO pointer-last/readback/conflict, and cleanup.
4. Require the sealed Haskell reader and enumeration ledger to preserve every scoped UNVERIFIED boundary.

### Remaining Work

No remaining work inside the scoped deliverable. The Kubernetes owner/device-plugin/resource/affinity/audit
chain, native CBOR/Pulsar, Vault credential, full sibling multi-layer trainer and checkpoint module, canonical
CBOR/live mutable ETag-CAS, jit-cache materialization, live negative/idempotency twins, failover, and general
correctness/noninterference remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- Record only the tested jitML adapter, CUDA owner binding, and pointer-commit contract in the owning
  lift/capability/content/daemon/capacity doctrines; do not restate inherited Phase-69 or Phase-80 proofs.
- Keep downstream artifact presentation and interaction ownership exclusively in Phase 93.

**Cross-references to add:**

- Register the implementation paths in `DEVELOPMENT_PLAN/system_components.md` and retain scoped status until
  the `linux-cuda` Register-3 ledger is green.
- Keep the Phase-94 dependency on this pointer-committed-artifact contract explicit without moving presentation work
  into Phase 92.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 69 — Content store and workflow runtime](phase_69_content_store_workflow.md)
- [Phase 80 — Determinism and jit cache](phase_80_determinism_jitcache.md)
- [Phase 91 — infernix lift](phase_91_infernix_rederivation.md)
- [Phase 94 — jitML UI lift](phase_94_jitml_ui_rederivation.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Capability Extension Doctrine](../documents/engineering/capability_extension_doctrine.md)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md)
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
