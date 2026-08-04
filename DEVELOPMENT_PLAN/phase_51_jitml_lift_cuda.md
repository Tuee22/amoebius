# Phase 51: Core jitML CUDA artifact lift

> **Purpose**: Lift the sibling `jitML` numerical and training core into amoebius as a linked workload
> extension and test that one scope-bound CUDA training request produces a pointer-committed checkpoint artifact
> through the existing workflow, cache, accelerator-owner, and content-store seams, with no silent CPU
> fallback.
> **Read this if**: phase 51 is next in the queue, or a later phase depends on what its gate establishes.

Phase 51 delivers the core jitML CUDA artifact lift; its design is owned by [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), [capability_extension_doctrine.md](../documents/engineering/capability_extension_doctrine.md), [content_addressing_doctrine.md](../documents/engineering/content_addressing_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cuda` substrate.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_48_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_53_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 51.1: Produce one committed jitML artifact on CUDA 📋](#sprint-511-produce-one-committed-jitml-artifact-on-cuda-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. The jitML library adapter, CUDA binding, committed-artifact contract, and live evidence do not yet
exist in amoebius. The sibling checkpoint and training code is evidence that the computational substance is
reusable, not evidence that this integration works. This phase opens after the Phase 37 workflow/content-store
gate, the Phase 48 determinism and jit-cache gate, and the Phase 49 infernix lift that supplies the
`InferenceEngine` capability required by jitML's closed extension graph.

Phase 37 continues to own Pulsar-Failover takeover and pointer-CAS safety; Phase 48 continues to own the
determinism kernel and bounded first-miss cache. Phase 51 consumes those contracts without adding another
coordinator, election, store, cache, or determinism implementation.

Every scoped training start carries one server-derived `CommandId` unchanged as the Phase-37 workflow
work-id through the canonical CBOR command, every progress/checkpoint event, and the terminal committed or
failed event. The adapter cannot replace it with a trainer Pod UID, retry id, checkpoint digest, or pointer
revision. Producer resends retain their Phase-35 producer/sequence identity; consumer redelivery and restart
fold on the stable work-id. The same scoped command id plus normalized request returns the original workflow
and committed-artifact outcome without launching another trainer; the same id with a changed normalized
request is a typed pre-effect idempotency conflict.

## Phase Summary

This phase owns one primary seam:

```text
ScopedTrainingRequest tenant app
  + ProvisionedCudaTraining
  -> CommittedJitMLArtifact tenant app
```

The sibling numerical, autodiff, code-generation, SL/RL, and tuning modules link as a library behind that seam;
they do not become a standalone service or another binary. `dhall/jitml/package.dhall` describes a workload
extension that requires the existing `JitBuild`, `Coordination`, and `InferenceEngine` capabilities. It has no
replica, region, failover, provider, raw endpoint, bucket, object-key, or arbitrary engine-download field.
Those decisions remain trusted bind/provision outputs.

The checkpoint adapter maps jitML's blob/manifest/pointer format onto Phase 37's app-scoped three-tier store.
Blobs and canonical-CBOR manifests are immutable and self-naming; the app-qualified `latest` pointer advances
only by ETag CAS. Only the successful pointer-write witness can construct the opaque
`CommittedJitMLArtifact tenant app`. In-flight, failed, orphaned, raw-path, and manifest-only states have no
conversion to that type. The artifact retains its trusted scope, experiment hash, manifest SHA, committed
pointer revision, engine catalog identity, and substrate fingerprint; none is accepted from an untrusted
artifact claim.

CUDA is selected from the resolved `linux-cuda` substrate and materialized as a closed-catalog identity by the
Phase 48 resolver on first miss. Before any run-scoped effect, the provision seal exact-joins every training,
serving, and Tier-3 JIT source to its workload demand, derives every permitted coexistence epoch, and checks
device family/profile, whole-device count, sharding/link constraints, each device's net allocatable VRAM after
its mandatory driver/runtime reserve, and live `currentFreeVram`. The named accelerator-owner container then
receives equal integer `nvidia.com/gpu` request and limit for the selected node's full device offering plus the
required affinity. A CPU target, shortage, fragmented fit, missing source, or stale/mismatched observation is a
pre-effect rejection; there is no fallback arm.

The output of this phase is the core committed artifact contract. Phase 52 alone owns its downstream
presentation and interaction adapter; no interaction-ready handle is produced or accepted here.

**Session scope:** In one uninterrupted engineering session, implement exactly this CUDA-training-to-committed-
artifact vertical slice and accept it with `cabal test jitml-cuda-artifact-lift-live-gate`. Split if the work
adds a second training topology, re-tests failover or general determinism, crosses the Phase-52 boundary,
targets another substrate, or requires a second acceptance command.
**Substrate:** linux-cuda
**Register:** 3 (live infrastructure)
**Gate:** `cabal test jitml-cuda-artifact-lift-live-gate` submits one fresh-challenge training request after
the subject is Ready, independently observes the named trainer execute CUDA under the exact provisioned device
claim, and accepts only the pointer-reachable committed artifact. Reserve/current-free one-short variants must
reject before run-scoped effects, and an injected pointer-CAS conflict must not produce a committed artifact.
The fixtures, oracle, observers, and mutants are delegated to [Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/dhall/phase_51/jitml_cuda_artifact.dhall`,
  `test/fixtures/phase_51/cuda_capacity_matrix.tsv`,
  `test/fixtures/phase_51/committed_artifact_contract.tsv`, and
  `test/fixtures/phase_51/command_identity_matrix.tsv`, plus
  `test/fixtures/phase_51/resource_shape.json`. The one positive workload is a pinned supervised training job
  with at least 200 optimizer steps and a multi-layer model of at least 10 million parameters; falling below
  either floor fails rather than substituting a token workload.
- **Fresh challenge.** After the platform and subject processes are Ready, the harness creates an unpredictable
  command id and challenge-bearing final batch. An independent helper computes its content address. The
  command and every derived event must retain that id; the pointer-reachable manifest must name the batch
  address, and a host-side read/driver trace must bind the same trainer cgroup and Pod UID to reading that
  batch, launching CUDA kernels, and writing the checkpoint before the pointer CAS.
- **Positive commit chain.** A host-side NVML/driver probe supplies the observed device inventory. The
  Kubernetes API confirms the owner Pod's node, UID, affinity, and the named owner's exact full-device
  request/limit. Containerd/cache records confirm a first-miss materialization of the pinned CUDA catalog
  identity. Pulsar offsets and MinIO audit history establish command consumption, immutable blob/manifest
  writes, and the successful conditional pointer update. The harness fetches the artifact independently,
  recomputes every object SHA, and checks its scope and provenance against the committed oracle. An exact
  resend returns the original workflow/artifact outcome with no second trainer, CUDA launch, object write, or
  pointer advance; changed input under the same command id returns the pinned conflict with those same zero
  effects.
- **Paired capacity negatives with zero effects.** From a clean baseline, one case fits raw VRAM but is one
  byte over net allocatable VRAM after the mandatory reserve; another fits declared residual but is one byte
  over observed `currentFreeVram`. Each must fail at preflight with its pinned reason and produce no run-scoped
  owner/trainer Pod, cache materialization, Pulsar publish/offset movement, or MinIO mutation.
- **Uncommitted negative.** A fault injected after immutable writes but before the pointer update forces an
  ETag conflict. The prior pointer and revision remain unchanged, the result contains no
  `CommittedJitMLArtifact`, and any orphaned bytes remain visible and charged to Phase 37's GC horizon.
- **Bypass probes.** A least-privilege caller submits a raw checkpoint reference directly to the adapter and
  attempts the equivalent pointer mutation and trainer launch against MinIO and Kubernetes, bypassing the
  checked request path. RBAC and provider policy must deny both direct operations, no trainer Pod may appear,
  and no pointer revision may advance; adapter self-report cannot satisfy these observations.
- **Observers outside the SUT.** The host driver/NVML trace, Kubernetes API and audit stream, containerd/cache
  records, Pulsar topic statistics, and MinIO audit/object reads are the evidence. Trainer-produced status,
  labels, metrics, and logs are diagnostic only and cannot make the gate green.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_51/mut-51-silent-cpu-fallback.patch` (effect swap),
  `test/mutants/phase_51/mut-51-spend-raw-vram.patch` (guard weakening), and
  `test/mutants/phase_51/mut-51-mint-artifact-before-cas.patch` (guard weakening), plus
  `test/mutants/phase_51/mut-51-regenerate-command-id.patch` (idempotency weakening). The unchanged gate
  command must turn the CUDA witness, reserve negative, uncommitted-artifact, and redelivery rows red
  respectively; any surviving mutant fails the gate.
- **Independent oracle and honesty.** Capacity arithmetic, expected Kubernetes allocation, artifact scope,
  canonical-manifest predicates, and allowed state transitions are hand-authored before the implementation
  and do not call its planner, renderer, encoder, or artifact constructor. This gate establishes one bounded
  CUDA execution and commit chain. It inherits, but does not re-prove, numerical correctness, general
  same-substrate determinism, trainer failover, or general tenant noninterference.

## Doctrine adopted

- [Lift and Compose Doctrine §2 — What lifts](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
  reuse jitML's computational substance while replacing its infrastructure envelope.
- [Capability Extension Doctrine §5 — Requirement edges](../documents/engineering/capability_extension_doctrine.md#5-the-requirement-edges):
  bind jitML only through the existing `JitBuild`, `Coordination`, and `InferenceEngine` providers.
- [Content Addressing Doctrine §2 — Three-tier store](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  and [§4.5 — ML-asset lifecycle](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  require pointer-CAS commitment and closed-catalog first-miss materialization.
- [Daemon Topology Doctrine §4.2 — Accelerator owner](../documents/engineering/daemon_topology_doctrine.md#42-the-accelerator-owner-worker-wholesale-per-node-ownership-a-typed-per-node-singleton):
  give exactly one named owner container the node's wholesale device claim.
- [Resource Capacity Doctrine §8 — Declared, provisioned, observed](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime):
  spend net allocatable and current-free device capacity before effects.
- [Testing Doctrine §12 — Spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect):
  correlate a post-start challenge with independently observed CUDA and store effects.

## Sprints

## Sprint 51.1: Produce one committed jitML artifact on CUDA 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/{Library,CudaArtifactLift}.hs`,
`src/Amoebius/JitML/Checkpoint/{Manifest,Store}.hs`, `src/Amoebius/JitML/Engine/Cuda.hs`,
`src/Amoebius/Accelerator/Owner.hs`, `dhall/jitml/package.dhall`, and
`test/live/Phase51JitMLCudaArtifactLift.hs` (target paths; not yet built)
**Blocked by**: Phase 37 gate;
Phase 48 gate; Phase 49 gate.
**Independent Validation**: the single live command checks the positive
CUDA-to-commit chain, both pre-effect capacity negatives, the pointer-conflict and command-id conflict
negatives, and all four committed mutants against external evidence.
**Docs to update**:
`documents/engineering/lift_and_compose_doctrine.md`,
`documents/engineering/capability_extension_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, and `documents/engineering/testing_doctrine.md`.

### Objective

Adopt [Lift and Compose Doctrine §2 — What lifts](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map)
and [Content Addressing Doctrine §2 — Three-tier store](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers):
adapt one real sibling jitML training path to amoebius's existing scoped workflow, closed-catalog CUDA,
accelerator-owner, and pointer-committed store contracts so the only successful output is an opaque committed
artifact carrying its trusted scope and provenance.

### Deliverables

- The linked jitML library and closed Dhall workload-extension package, with infrastructure and authority
  fields absent from its authored surface.
- The canonical checkpoint adapter and opaque `CommittedJitMLArtifact tenant app`, constructible only from a
  successful Phase-37 pointer-CAS witness.
- One scope-qualified command/work-id preserved through the native CBOR command/event chain and the
  idempotent training fold.
- The substrate-selected CUDA engine binding and provision-derived accelerator-owner allocation, with no CPU
  fallback or arbitrary download path.
- The Phase-0 oracle corpus, four committed mutants, live harness, and Register-3 evidence ledger with
  challenge correlation and idempotent teardown.

### Validation

1. Run `cabal test jitml-cuda-artifact-lift-live-gate` once on `linux-cuda`.
2. Require the positive request to read the fresh batch, launch CUDA in the claimed owner, and yield a
   pointer-reachable artifact whose independently fetched bytes, scope, and provenance match the oracle.
3. Resend the exact scoped command and require the original outcome with no second training effect; change its
   normalized input under the same command id and require the pinned pre-effect conflict.
4. Run the reserve and current-free one-short twins from clean baselines and require their pinned preflight
   errors plus zero run-scoped effects.
5. Force the pre-CAS conflict and require that no committed artifact can be observed or constructed.
6. Apply each named mutant and require the unchanged command to fail on its exact row before emitting a green
   ledger; always tear down and externally enumerate run-owned resources.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- Record only the tested jitML adapter, CUDA owner binding, and pointer-commit contract in the owning
  lift/capability/content/daemon/capacity doctrines; do not restate inherited Phase-37 or Phase-48 proofs.
- Keep downstream artifact presentation and interaction ownership exclusively in Phase 52.

**Cross-references to add:**

- Register the implementation paths in `DEVELOPMENT_PLAN/system_components.md` and flip the tracker status
  only after the linux-cuda Register-3 ledger is green.
- Keep the Phase-52 dependency on this committed-artifact contract explicit without moving presentation work
  into Phase 51.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 37 — Content store and workflow runtime](phase_37_content_store_workflow.md)
- [Phase 48 — Determinism and jit cache](phase_48_determinism_jitcache.md)
- [Phase 49 — infernix lift](phase_49_infernix_lift.md)
- [Phase 52 — jitML UI lift](phase_52_jitml_ui_lift.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Capability Extension Doctrine](../documents/engineering/capability_extension_doctrine.md)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md)
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
