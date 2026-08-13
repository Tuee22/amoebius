# Phase 51: Core jitML CUDA artifact lift

> **Purpose**: Lift the sibling `jitML` numerical and training core into amoebius as a linked workload
> extension and test that one scope-bound CUDA training request produces a pointer-committed checkpoint artifact
> through the existing workflow, cache, accelerator-owner, and content-store seams, with no silent CPU
> fallback.
> **Read this if**: phase 51 is next in the queue, or a later phase depends on what its gate establishes.

Phase 51 delivers the core jitML CUDA artifact lift; its design is owned by [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), [capability_extension_doctrine.md](../documents/engineering/capability_extension_doctrine.md), [content_addressing_doctrine.md](../documents/engineering/content_addressing_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live evidence, on the `linux-cuda` substrate.
The linked adapter, pure contract, four compiled mutants, physical host-CUDA run, retained-MinIO record, and
enumeration ledger passed their 16-check scoped gate on 2026-08-11. The ledger is
`external-run-reference`; the receipt is
`dynamically-resolved`. CPU execution through `linux-cpu` remains
available on every hardware substrate. When an uncontaminated Linux host is required, use Incus for
Linux/Linux-CUDA hardware, Lima for Apple hardware, or WSL2 for Windows hardware.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

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
- [Sprint 51.1: Produce one committed jitML artifact on CUDA ⏸️](#sprint-511-produce-one-committed-jitml-artifact-on-cuda-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish external evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed 2026-08-11. The leaf package compiles the untouched sibling
`JitML.Codegen.RuntimeOperationsCuda` module beside a constructor-hidden artifact adapter. Pure capacity,
commit, identity, idempotency, and four mutation checks pass; a physical GTX 970 and retained MinIO supply the
live record. The full sibling trainer and Kubernetes accelerator-owner chain do not yet exist in amoebius.

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

The scoped leaf compiles the sibling CUDA runtime-operations code generator behind that seam; the full
numerical, autodiff, SL/RL, tuning, and checkpoint modules remain outside the tested linkage. They do not
become a standalone service or another binary. `dhall/jitml/package.dhall` describes a workload extension
that requires the existing `JitBuild`, `Coordination`, and `InferenceEngine` capabilities. It has no
replica, region, failover, provider, raw endpoint, bucket, object-key, or arbitrary engine-download field.
Those decisions remain trusted bind/provision outputs.

The checkpoint adapter uses Phase 37 content digests and canonical component manifests for its pure contract.
The scoped live driver writes batch and 40 MB checkpoint blobs, a canonical JSON evidence manifest, and a
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

The output of this phase is the core committed artifact contract. Phase 52 alone owns its downstream
presentation and interaction adapter; no interaction-ready handle is produced or accepted here.

**Session scope:** One scoped CUDA-microtrainer-to-committed-artifact slice, one package, one pure suite, one
live evidence reader, and one aggregate command; no Phase-52 presentation work is included.
**Substrate:** linux-cuda
**Register:** 3 (live infrastructure)
**Gate:** `python3 tools/phase51_gate.py --reuse-fresh-live` checks Phase-0
custody, package/Dhall contracts, physical-CUDA and retained-MinIO evidence, cleanup, the independent reader,
four compiled mutants, documentation, and the ledger. Details are delegated to [Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/dhall/phase_51/jitml_cuda_artifact.dhall`,
  `test/fixtures/phase_51/cuda_capacity_matrix.tsv`,
  `test/fixtures/phase_51/committed_artifact_contract.tsv`, and
  `test/fixtures/phase_51/command_identity_matrix.tsv`, plus
  `test/fixtures/phase_51/resource_shape.json`. The one positive workload is a pinned supervised training job
  with at least 200 optimizer steps and a multi-layer model of at least 10 million parameters; falling below
  either floor fails rather than substituting a token workload.
- **Fresh challenge.** The harness creates an unpredictable command id and 24-byte challenge-bearing batch.
  The host CUDA process retains command=work identity in its evidence manifest; a Kubernetes Pod/cgroup
  correlation is not claimed.
- **Positive commit chain.** `nvidia-smi` and the CUDA driver supply device/process/memory observations. The
  driver launches 200 real kernels over a 10-million-float array and compares the full checkpoint with a
  separately computed byte oracle. Retained MinIO readback establishes blob, manifest, pointer-last order,
  ETags, an unchanged 412 conflict, and zero object delta on a pointer resend. Kubernetes allocation,
  containerd cache, Pulsar offsets, and a live adapter resend remain UNVERIFIED.
- **Paired capacity negatives with zero effects.** The independent matrix and pure contract cover raw-fit/net-
  one-short and current-free-one-short refusals before modeled effects. Live zero-effect provider twins are
  not claimed.
- **Uncommitted negative.** The pure constructor refuses `PointerCasConflict`; retained MinIO separately
  returns 412 for a conflicting create-only conditional pointer and preserves the original bytes. A mutable
  latest-pointer ETag update and orphan-horizon drill remain UNVERIFIED.
- **Bypass probes.** An unauthenticated direct MinIO checkpoint read returns 403. A Kubernetes trainer-launch
  bypass and tenant-credential provider pair remain UNVERIFIED.
- **Observers outside the adapter.** CUDA driver returns, `nvidia-smi` process/device inventory, full
  checkpoint comparison, and retained MinIO readback are the evidence. Kubernetes audit, cache, broker, and
  Vault observers remain UNVERIFIED.
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
  physical CUDA microtrainer and commit slice. It does not establish full sibling numerical correctness,
  a multi-layer model, same-substrate determinism, Kubernetes ownership, native CBOR, trainer failover, or
  general tenant noninterference. The universal `linux-cpu` option and Incus/Lima/WSL2 clean-host routing stay
  available independently of this CUDA-specific gate.

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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 51.1: Produce one committed jitML artifact on CUDA ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/JitML/CudaArtifactLift.hs`, `jitml/jitml-lift.cabal`,
`dhall/jitml/package.dhall`, `test/kernel/Phase51JitMLCudaArtifactContractSpec.hs`,
`test/live/Phase51JitMLCudaArtifactLift.hs`, and `tools/phase51_jitml_cuda_live.py`
**Blocked by**: reopened numeric predecessor gates.
**Requires**: `accelerator-device-plugin` — the device plugin advertising `nvidia.com/gpu` for the host's
device vector. It is part of what makes the host `linux-cuda`, not a phase deliverable.
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
- The Phase-0 oracle corpus, four committed mutants, live harness, and generated Register-3 run ledger with
  challenge correlation and idempotent teardown.

### Validation

1. Run `python3 tools/phase51_gate.py --reuse-fresh-live` on `linux-cuda`.
2. Require pure CPU/floor/capacity/identity/idempotency/commit checks and all four mutants to pass or turn red
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

**Engineering docs updated for the scoped result:**

- Record only the tested jitML adapter, CUDA owner binding, and pointer-commit contract in the owning
  lift/capability/content/daemon/capacity doctrines; do not restate inherited Phase-37 or Phase-48 proofs.
- Keep downstream artifact presentation and interaction ownership exclusively in Phase 52.

**Cross-references to add:**

- Register the implementation paths in `DEVELOPMENT_PLAN/system_components.md` and retain scoped status until
  the `linux-cuda` Register-3 ledger is green.
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
