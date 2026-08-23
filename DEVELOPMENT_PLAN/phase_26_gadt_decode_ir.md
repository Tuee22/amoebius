# Phase 26: Haskell protocol declarations, GADT-indexed IR, and total decoder

> **Purpose**: Define the GADT-indexed Haskell IR, Haskell wire declarations, and a total fail-fast decoder
> that consumes an external value or the Phase-25 projection beneath `.build/dhall/**` and returns a legal world or a structured `Left`,
> carrying normalized complete resource demands and target capacities in-process before any real resource
> exists, while preserving the later post-bind `ProvisionedSpec` boundary.
> **Read this if**: phase 26 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 26.1: The amoebius cabal package + `gadt-decode-spec` test-suite skeleton ⏸️](#sprint-261-the-amoebius-cabal-package--gadt-decode-spec-test-suite-skeleton-)
- [Sprint 26.2: GADT-indexed IR + smart constructors + phantom tenant refs + ownership indices ⏸️](#sprint-262-gadt-indexed-ir--smart-constructors--phantom-tenant-refs--ownership-indices-)
- [Sprint 26.3: The fail-closed decoder (`Dhall.inputFile auto` + exception-catch) + structured `DecodeError` ⏸️](#sprint-263-the-fail-closed-decoder-dhallinputfile-auto--exception-catch--structured-decodeerror-)
- [Sprint 26.4: The gadt-decode decode battery (`gadt-decode-spec`) — the gate ⏸️](#sprint-264-the-gadt-decode-decode-battery-gadt-decode-spec--the-gate-)
- [Sprint 26.5: Decoding the shared `SecretRef` and rejecting a literal ⏸️](#sprint-265-decoding-the-shared-secretref-and-rejecting-a-literal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 25, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** The second typed boundary is to reject values that are structurally
well-typed but do not describe a legal amoebius world. Haskell is to own the protocol declarations, the
GADT-indexed intermediate representation — sum types, smart
constructors, phantom tenant references, and ownership indices designed so that an illegal combination has no
inhabitant — together with the fail-closed decoder `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)`
built on the native `dhall` library's `Dhall.inputFile auto` wrapped in an exception-catch. Totality here is
defined precisely: every input, well-typed or not, yields `Right` or a structured `Left` *without throwing*.
All positive, negative, compile-refusal, wire, and projection cases are to be Haskell values. Any Dhall or
protocol bytes needed to exercise them are generated run-locally beneath `.build/**` and are never tracked
fixtures or authority. Capacity feasibility, binding, provisioning, and runtime remain UNVERIFIED.
`ClusterIR` is not resource-agnostic: every execution unit carries stable id/revision, arm-specific
controller/cardinality/policy in a private `BoundExecutionBody`—Deployment, StatefulSet, DaemonSet, Job, or
HostProcess—with only kind-valid rollout/progress fields and a structurally compatible Pod/host/accelerator
resource arm, plus the normalized complete `ResourceEnvelope` declaration (CPU, memory, pod-local ephemeral
storage, durable/cache storage, structural runtime-metadata sources, and the closed identity-complete
accelerator-owner demand), and every target inventory carries normalized
`Capacity`, backing, and accelerator-offering declarations. The decoder also preserves the complete physical
disk identity graph (globally scoped physical-backing/carve ids, VM subcarves, each node's logical
pod-ephemeral allocatable, closed physical-filesystem layout, `imageStorageModel`, `imagePullConcurrency`, and
`kubeletMetadataModel`), the full provider target's authored `CloudAccountId`, node-class pod/CNI and
driver-indexed CSI slot policies, complete supply/quota/root-backing shape, and every Observability binding's
mandatory finite `MonitoringWorkBudget`, including its volume presentation. Every build also retains its
mandatory per-stage `BuildExecutionEnvelope`; every kind
engine and every rke2 server/agent retains its role-indexed named-process `EngineSystemReserve`, named system-
carve reference, and applicable finite `ControlPlane | Worker` engine-storage demand. Quantities are converted once to canonical unit-tagged
forms (millicores, bytes, whole devices); no later stage may reparse free-form resource strings or invent
omitted defaults. The target claim is limited to presence, normalization, and structural legality; arithmetic
feasibility and placement remain later checked folds, not type-inhabitance claims. The target decode code may
carry no `error`/`undefined`/partial head; because
`Dhall.inputFile auto` alone throws (`DhallErrors`, IO exceptions) rather than returning `Left`, the
exception-catch wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed) so no
throw escapes into a half-applied effect. What is *not* here: the chain
/ reconcile / control-plane daemon runtime (Phase 65), the pure capacity/topology fold implementation and properties
(Phase 9) consumed by the conditional infrastructure-planning/post-materialization provision seal (Phase 31),
the capability→provider binder (Phase 30), and
the exhaustive illegal-state corpus with its per-entry validation-locus
ledger and Haskell properties (Phase 27). This phase's unresolved contract must eventually establish a
non-partial, fail-closed decoder against a separately reviewed Haskell corpus.

The non-bypass ordering is fixed here even though its implementation lands after this decoder:

`ClusterIR → bind/expand → BoundDeployment → planInfrastructure(BoundDeployment, declared
supply | forest budget) → (NoInfrastructureRequired witnessing an explicit
ObservedInfrastructureMaterialization.AlreadyMaterialized state |
ProvisionedInfrastructurePlan → validate → CAS-enact → receipt-bound
ObservedInfrastructureMaterialization) → ProvisionContext → provision → Either ProvisionError
ProvisionedSpec → renderAll`.

The decoder never constructs `ProvisionedSpec`, the binder never renders, and the renderer never accepts
`ClusterIR` or `BoundDeployment`. Neither value contains a `Provisioned*` record. `planInfrastructure`
derives its demand from that exact bound expansion; no caller-authored demand vector can bypass it. A required
plan is one batch-owned Pulumi graph/checkpoint/dependency/concurrency/quota value and cannot render. Only its
CAS-consumed, provider-read-back result (or the explicit no-plan materialized arm) can construct
`ProvisionContext`; only then may `provision` resolve opaque prior-execution/volume/registry refs and
construct the opaque checked value. At that target boundary, provider expansion must have made every platform pod, sidecar, init
container, volume, cache owner, and accelerator owner explicit.

**Phase scope:** one target claim — decoding yields either a legal Haskell world or one structured refusal,
never a partial result. Generated Dhall/protocol bytes stay beneath `.build/**`; later folds and effects are not exercised.

**Substrate:** `none` — no host, cluster, browser, or hardware; only the canonical Haskell gate owns the verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 25](phase_25_dhall_schema_generation.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 26`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — Haskell declarations and a total Haskell decoder accept a legal world or return one structured refusal; Haskell-owned cases lazily generate any Dhall/protocol bytes beneath `.build/**`. Later folds, effects, hardware, and runtime remain outside the claim. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 26` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Legacy closure` | UNRESOLVED — blocks validation: Phase-26-owned `LTD-SRC-003` remains active. Its exact Proto-family zero-finding check, field-number reintroduction negative, independently reviewed Haskell binding, and sprint-level owner assignment have not been accepted. |
| `Predecessor` | MISSING — blocks validation: the current Phase 25 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact gADT-indexed IR + total decoder (gadt-decode) emits is a recipe over a content address, never an authored file.
- [`dsl_doctrine.md` §4 — Total composability](../documents/engineering/dsl_doctrine.md#4-total-composability):
  adopt the **import policy** the doctrine assigns to the Phase-25/12 gate. `env:` and remote (`http(s):`)
  imports are forbidden in any authored or uploaded spec; every spec is resolved-and-frozen to a
  fully-local, `sha256:…`-hashed expression **before** decode. This phase owns the enforcement — Sprint 26.3's
  resolve-and-freeze stage and its `ForbiddenImport` negatives — and it is what makes the effect-free/total
  premise of [`dsl_doctrine.md` §2 — Two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)
  true of the expression actually decoded, rather than of arbitrary unresolved Dhall.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  adopt **gadt-decode — the Haskell typed decoder**. A well-typed Dhall value becomes a Haskell value through the
  native `dhall` library in-process (`Dhall.inputFile auto`); decoding is total and fail-fast (a structured
  `Either`, never a throw), and the ADTs make illegal combinations un-spellable — *because the value cannot
  be constructed, it cannot be decoded, and because it cannot be decoded, it cannot be deployed.*
- [`illegal_state_techniques.md` §4.3 — GADT-indexed state machines — only legal transitions are typed](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
  — the typing techniques discharged at the decode boundary: **GADT-indexed state machines** ([`illegal_state_techniques.md` §4.3 — GADT-indexed state machines — only legal transitions are typed](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed), only legal transitions are typed), **capability & phantom tenant tags** ([`illegal_state_techniques.md` §4.2 — Capability and phantom tenant tags — cross-tenant refs are uninhabitable](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable), cross-tenant references are uninhabitable), and **ownership indices** ([`illegal_state_techniques.md` §4.4 — Ownership indices — single-owner SSoT, structurally](../documents/illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally), single-owner SSoT structurally). This phase builds the IR
  that carries those indices; the capacity-accounting and topology-relation folds ([`illegal_state_techniques.md` §4.6 — Capacity accounting — placement witness (compute) and summed demand within capacity (storage), checked](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)/[`illegal_state_techniques.md` §4.7 — Compatibility / topology relations by construction over a collection](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)) are deferred to
  Phase 9.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget) and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the complete pure resource vocabulary and its checked-construction boundary. This phase carries and
  normalizes the declarations in `ClusterIR`; Phase 9 implements the arithmetic/placement folds; Phase 31 runs
  them after capability binding and provider expansion to construct an opaque `ProvisionedSpec` and its
  unique whole-deployment render-source set. Private service projections contribute sources but never cross
  the public boundary; a raw decoded or merely bound value can never reach Phase 33's `renderAll`.
- [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  and [`illegal_state_techniques.md` §6 — Three layers of foreclosure (and the honesty they force)](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — the load-bearing limit and the three layers of foreclosure: layers 1–2 (type-/decode-foreclosed) are
  the intended Register-1 boundary here; layer 3 (runtime-checked) stays deferred. The eventual contract must honor [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it) verbatim: *a
  type-check proves the spec composes, not that the cluster enforces it.*
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — **Register 1** (pure/semantic-oracle, in-process, no cluster): the register this phase's gate reaches; and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  — the per-run proven/tested/assumed ledger the battery emits, marking model↔runtime correspondence
  UNVERIFIED.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 26.1: The amoebius cabal package + `gadt-decode-spec` test-suite skeleton ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt the pinned toolchain from the Phase 1 spike and stand up the real `amoebius` cabal package with a
`gadt-decode-spec` test-suite target, so this phase has a buildable in-process surface — the minimal skeleton
gadt-decode needs, with **no** chain/reconcile/control-plane daemon kernel.

### Deliverables

- `amoebius.cabal` + `cabal.project` pinned to GHC 9.12.4 / Cabal 3.16.1.0 with the Phase-1 `allow-newer`
  set, exposing the `dsl-core` modules and a `gadt-decode-spec` test-suite stanza.

### Validation

1. Rejected historical observation: direct Cabal builds and the `gadt-decode-spec` Cabal suite were recorded
   successful under GHC 9.12.4 / Cabal 3.16.1.0;
   the phase gate's `strace` observer records absolute Cabal, GHC, and Dhall executable paths.
2. "No `PATH`-resolved tool" is disambiguated to the one interpretation both engineers now share, since this
   validation has no amoebius binary of its own: the Haskell harness resolves `ghc`/`cabal`/`dhall` to the
   **absolute paths established from the reviewed Phase-1 Haskell requirements** and records the fresh
   resolution beneath `.build/runs/phase_26/**` before invoking each path directly.
3. An **OS-boundary argv observer**, driven by reviewed Haskell code and materialized only beneath `.build/**`
   per [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 5,
   records that every toolchain and `dhall` invocation carried an absolute executable path. Its independent
   raw trace is red if any invocation resolved a bare name via ambient `PATH`; no shell/Python shim or subject
   build log supplies the verdict.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Phase 26 remains blocked and NOT VALIDATED. Later DSL expansion belongs to the numerically assigned phases.

## Sprint 26.2: GADT-indexed IR + smart constructors + phantom tenant refs + ownership indices ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`illegal_state_catalog.md §4.2/§4.3/§4.4`](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed):
build the Haskell types the Dhall decodes into — GADT-indexed so only legal transitions are typed, phantom
tenant-tagged so a cross-tenant reference is uninhabitable, and ownership-indexed so a resource has one
structural owner. These are the ADTs that make an illegal combination un-spellable at the decode boundary.
Complete normalized resource/capacity data is retained in the semantic-hash-pinned path-indexed tree and each
refined execution retains its exact resource subtree; no provisioned total is synthesized here.

### Deliverables

- `ClusterIR` and its component ADTs as GADT-indexed types + smart constructors exposing only a legal
  vocabulary, carried by `src/Amoebius/Dsl/Types.hs` alongside the normalized resource/capacity declaration
  fields; the phantom tenant `Ref tenant a` and ownership indices of `src/Amoebius/Dsl/Ref.hs`, catalogued at [§4.2](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)/[§4.4](../documents/illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally).
- The gadt-decode side of the three surfaces [Phase 25](phase_25_dhall_schema_generation.md) adds to the schema:
  `ExtensionSpec` with its non-optional `extMonitoring : NonEmpty MonitoringSurface`, the PACELC surface, and
  the closed `BackupPolicy`, so an extension without monitoring cannot be decoded any more than it can be
  authored.
- The **role vocabulary itself, as a closed decoded union**, which the relations below already presuppose and
  which nothing establishes today: `Process`, `InClusterRole`, and `WorkerKind` of
  [daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid),
  decoded total from Phase 25's Haskell role declaration and its `.build/dhall/amoebius/Role.dhall`
  projection. An arm outside the union is an `OutOfDomainArm`
  rejection like any other; a `Worker` with no kind and a one-shot command run holding a daemon role have no
  value to decode at all, so the negatives here are closedness negatives, not field checks. Doctrine assigns
  the foreclosure to this gate ([§3](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon),
  *decode-foreclosed (gadt-decode)*), and the union is written three times in the tree today with no two agreeing
  ([legacy_tracking_for_deletion.md §4](legacy_tracking_for_deletion.md#4-host-image-and-lift-violations)).
  Cardinality is decoded **indexed on the role**: only the `Worker` arm admits a replica count, so catalog
  [§3.90](../documents/illegal_state/illegal_state_lifecycle.md#390-a-role-whose-cardinality-contradicts-it)
  needs no separate check.
- The two **image/process cross-field relations** Dhall cannot express, decoded here because they range over
  the enclosing value rather than one field: an `AmoebiusRole` container must run an image whose identity is
  the `Runtime` arm and, when its role is `Worker`, the kind's `ExtensionId` must be a member of that arm's
  `linked` set (catalog [§3.77](../documents/illegal_state/illegal_state_lifecycle.md#377-a-worker-naming-an-extension-its-own-binary-does-not-link));
  a `BakedService`'s `BakedBinaryId` must be installed by some `BakeStep` in that identity's own build
  content. Each returns a structured `Left` with its own tag; neither is a runtime probe. The `AmoebiusRole`
  arm carries an `InClusterRole`, which has no host-daemon arm, so catalog
  [§3.75](../documents/illegal_state/illegal_state_lifecycle.md#375-a-container-whose-process-is-unnamed)
  is foreclosed one gate earlier and is not re-checked here.
- Normalized resource declarations wired into the real IR, not ornamental side records: every execution-unit
  component carries stable id/revision plus one private controller-indexed body: Deployment/StatefulSet use
  `Once | Replicated`;
  - DaemonSet embeds `PerNode`;
  - Job uses completions/parallelism/backoff/ `podRestartPolicy=Never`/`podReplacementPolicy=Failed`/finite
    terminal retention;
  - HostProcess uses `Once | PerNode` under a supervisor.
  - Deployment, StatefulSet, and DaemonSet retain only their kind-valid policies;
  - StatefulSet is native serial partition zero and DaemonSet rolling is exactly `Surge | Unavailable`.
  - The body also contains a complete structurally compatible Pod/host `ResourceEnvelope` and the identity
    required for Phase 30's exactly-once `BoundExecutionSet` join.
  - The Deployment rollout constructor is private and returns `Left (UnspellableCombination
    "rollout.rollingProgress")` for `{ maxSurge = 0, maxUnavailable = 0 }`. `{ 1, 0 }` and `{ 0, 1 }` are
    required positive controls, so the guard cannot be strengthened into an accidental both-positive
    requirement.
  - gadt-decode rejects Deployment↔Host, HostProcess↔Pod, kind-policy, kind-cardinality, CUDA-with-rolling,
    ordinary-with-device-release, and Metal-without-Metal-envelope mismatches at their exact field paths;
    every pod resource retains exact structural network/mount identities in `PodRuntimeMetadataSource`.
  - Every node/host/storage target carries the corresponding `Capacity`, durable/native-host-cache backing,
    and closed accelerator offering; in-cluster cache remains a typed reference to one declared disk-backed
    pod volume and therefore a nested consumer of pod ephemeral storage, never a second allocation.
  - CPU is normalized to millicores; memory, pod ephemeral storage, durable/cache storage, and accelerator
    residency to bytes; accelerator count remains a positive wholesale whole-device quantity.
  - An optional `ComputeHeadroomDemand`/`HostComputeHeadroomDemand` normalizes its pad on the same axes into
    the zero-capable `Residual` representation, and its checked construction proves two things dhall-typecheck cannot
    state: that the pad respects the workload's own ceiling — `requests + pad ≤ limits` per axis on the pod
    arm, `reservation + pad ≤ ceiling` on the host arm, a strict strengthening of the `requests ≤ limits`
    refinement it sits beside — and that at least one axis is `Remaining`, so `PositiveHeadroomAxisWitness`
    has no all-`Zero` inhabitant and "no headroom" keeps exactly one representation.
  - A pad breaching its ceiling or padding no axis returns the structured `UnspellableCombination` class at
    the exact field path, not a surviving scalar.
  - The reserved total the pad contributes to remains underivable here as it is unauthorable in dhall-typecheck:
    Phase 9 folds it and Phase 31's post-bind `provision` boundary alone constructs it.
  - CUDA/Metal owner inputs preserve exact equal-keyed served-model/training-job/JIT/ library source and
    workload maps, structural residency placement, and finite class-based coexistence maps.
    `domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)`; missing/extra classes
    reject.
  - Residency bytes mean total for `Unsharded`/`Sharded` and per device for `ReplicatedPerDevice`; sharded
    bytes sum to the residency total, shard ids are unique, and shard count cannot exceed owner devices.
  - Concrete and provider-template offerings preserve their device/slot link graphs.
  - A zero quantity/device count, locally inconsistent accelerator, or structurally incomplete declaration
    returns the existing structured `OutOfDomainArm`/`UnspellableCombination` class with the exact field
    path rather than surviving as an unvalidated scalar.
  - Whether a target offers the requested accelerator family/device count and can place every
    identity-complete, policy-permitted residency epoch against net per-device or unified memory is
    deliberately deferred to post-bind provisioning.
  - Each container preserves a closed `ReadOnlyRootfs | WritableRootfs { allowance }` arm; omission cannot
    mean zero writable bytes.
  - Its `ImageArtifact` retains the OCI index digest/stored bytes and, for every platform, child-manifest
    and config digest/stored bytes, every compressed-layer digest/stored bytes, snapshot chain id/ unpacked
    bytes, and peak pull/import workspace.
  - Each pod `DeclaredVolumeDemand` preserves its `StatefulSetClaimSlot`, `BackingId`, logical bytes, typed
    direct/BookKeeper/MinIO geometry owner, and `VolumePresentation = Block | Filesystem { fsType,
    overheadModel }`; each selected volume-producing host/ provider backing preserves `allocation :
    BackingAllocationPolicy { minimumBytes, quantumBytes }`.
  - No raw IR field can author physical bytes;
  - Phase 31's post-bind `provision` boundary constructs the private rounded `ProvisionedVolumeDemand`
    consumed by render, using the geometry and folds implemented in Phase 9.
- Canonical bounded service-storage inputs remain structural rather than being collapsed to caller-authored
  peak scalars. `InClusterCacheDemand`/`HostCacheDemand` preserve `CachePopulationDemand` with the exact
  catalog asset identity/digest/resident/temporary bytes and finite first-miss concurrency.
  `RegistryStorageIntent` preserves exact image-digest identities, finite upload concurrency, failure
  window/count, GC horizon, model, mutation policy, required storage budget, and typed interim-volume/MinIO
  backend;
  - Phase 30 alone exact-joins those digests to `RegistryStoredArtifact` metadata and constructs
    `RegistryStorageDemand`.
  - Every deployment preserves exactly one raw `FirstDeployment | UpdateFrom PriorProvisionRefSource`;
  - gadt-decode requires the update's `Execution` resource arm and brands it as `PriorExecutionProvisionRef`.
    `StorageMigrationIntent` and `RegistryBackendMigrationIntent` preserve `PriorProvisionRefSource {
    deployment, generation, resource }`;
  - gadt-decode checks those resource arms and brands them as `PriorVolumeProvisionRef` or
    `PriorRegistryProvisionRef`.
  - No arm decodes a prior `Provisioned*` record or an implicit latest generation.
  - They also preserve replacement/policy/workspace/chunk/concurrency inputs. `SchemaMigrationIntent`
    preserves exact old/new table/index identities plus its data/workspace backing and cost model.
    `ZooKeeperMetadataStoreDemand` preserves every member pod/claim, persistent/session znode,
    transaction/session/watch bound, retained log/snapshot and failure operands; the v1
    `PulsarMetadataStoreDemand` has no non-ZooKeeper or omitted arm. `PatroniSqlIntent` preserves finite
    data/WAL/checkpoint/failover source operands, required `StorageBudgetId`, declared volume, and bounded
    connection/transaction/WAL mutation intent rather than a fixed “database size”; it contains no
    `ControllerChildEnvelope` or provisioned child. `VaultStorageDemand` preserves the exact bounded
    persisted-object versions, maximum active leases, pinned Raft model/claim set, and rotated audit
    file/backups/retention plus named ephemeral or retained backing.
  - Only private cache/registry/Vault witnesses constructed at Phase 31's post-bind `provision` boundary,
    using Phase 9's folds, may carry derived peaks.
- Every durable platform declaration retains normalized `BookKeeperGeometry` (ensemble/write/ack quorums,
  segment bytes, bookie claim slots, journal/index reserve, finite fault bound), `MinioErasureGeometry`
  (data/parity/block geometry, drive claim slots, metadata/healing reserve, finite fault bound and replacement
  supply), and `ObjectStoreDemand` (exact store/tenant/bucket/full-key resident map, structural additional
  retained object extents, concurrent write sets, failed-write bound, finite positive orphan-GC horizon,
  admission cost model, and `StorageBudgetId`). The six-arm closed producer union retains app/content/registry,
  Pulsar-offload segment/rate/lag/failure operands, Pulumi exact state fields/revisions/failures, and the
  closed control-plane state entry kinds in `ObjectStoreProducerIntent`. `ObjectStoreGatewayIntent` preserves
  only gateway identity and execution-model selection; Phase 30 merges producer writer policies and constructs
  `ObjectStoreProducerDemand` plus `ObjectStoreAdmissionGatewayDemand`. gadt-decode
  retains only the fault-policy bounds, never a caller-curated list
  of favorable failure scenarios, and retains the `(StatefulSet, volumeClaimTemplate, ordinal)` identity needed
  for the later uniform max-ordinal projection. It normalizes/refines these operands but does not claim their
  logical→physical or rounded-backing arithmetic fits; that remains the provisioning fold. Its normalized
  `BookKeeperLogicalDemand` always carries required positive byte quantities for `retainedHotBytes`,
  `openLedgerHeadroom`, `inFlightOffloadBytes`, and `deletionLagBytes`; zero, omission, and an `Optional` bypass
  have no IR representation.
- The normalized capacity tree retains the physical identity graph without alias-erasing or synthesizing
  ids: `PhysicalHostCapacity` has a non-empty `PhysicalDiskPartition` list keyed by globally scoped
  `PhysicalDiskBackingId`; each retains `allocatableRawBytes` after unmanaged-host reserve but before all
  amoebius child carves, including `systemReserve`.
  - Every `NamedDiskCarve parent` keeps its globally scoped `DiskCarveId`, its `PhysicalRawExtent |
    VmGuestUsableExtent` parent index, and exactly one closed extent arm: `ExactParentExtent { parentBytes
    }` or `PresentedUsableExtent { requiredUsableBytes, presentation, allocation }`.
  - gadt-decode therefore cannot erase whether a debit belongs to the physical-raw parent or the nested VM-usable
    parent, but does not claim either parent sum fits.
  - Raw `VmDiskCarve` instead retains `{ id, presentation : FilesystemPresentation, allocation, guestSystem,
    kubelet }` with no authorable aggregate bytes: checked construction later derives private
    `ProvisionedVmDiskCarve { id, requiredUsableBytes, provisionedBytes, presentation, allocation, witness
    }`, with `id` copied unchanged from the raw `VmDiskCarve`; provisioning charges that raw high-water once
    to the parent partition keyed by the same id and preserves its layout-shaped kubelet filesystem carves.
  - Every node's `NodeLocalStorageCapacity` separately retains logical `podEphemeralAllocatable`, the closed
    `KubeletFilesystemLayout`, `NodeImageStorageModelVersion`, finite image-pull concurrency, and
    `KubeletRuntimeMetadataModelVersion`. `Unified` retains one nodefs reference and derives the
    nodefs=imagefs=containerfs alias; `SplitRuntime` retains distinct nodefs/imagefs and derives
    imagefs=containerfs; `SplitImage` retains distinct nodefs/imagefs plus its runtime-support requirement
    and derives nodefs=containerfs.
  - There is no arbitrary third filesystem or two free-standing pod/image pools.
  - Every retained, host-cache, and purpose-tagged host-storage pool also preserves both its typed logical
    `BackingId`/`CacheBackingId`/`HostStorageBackingId` and its `NamedDiskCarve`; a build-scratch pool
    preserves the `BuildScratch` purpose rather than relying on a name.
  - gadt-decode preserves this graph as opaque branded ids;
  - Phase 9 owns value-level global uniqueness, exactly-one parent/reference, layout alias/support checks,
    injective logical-id→carve resolution, role compatibility, and arithmetic.
  - CUDA device supply likewise preserves stable identity/profile plus `rawVram`, mandatory
    `driverRuntimeReserve`, and net `allocatableVram`; only the net value is a later fold operand.
- A managed provider target preserves the exact normalized `{ account : CloudAccountId, nodeClasses :
  NonEmpty ProviderNodeClass, quota : ProviderQuota }` shape.
  - Each class retains a distinct catalog-pinned `ProviderSkuRef` and the exact
    `ProviderNodeCapacityTemplate { allocatableCpu, allocatableMemory, podSlots, cniSlots,
    attachableVolumes, localDisks, cpuOvercommit, localStorage, accelerator }`. `podSlots` remains a
    `ProviderPodSlotPolicy`, `attachableVolumes` remains a driver-keyed map of `ProviderAttachSlotPolicy`,
    and `localStorage` remains `{ podEphemeralAllocatable, filesystems, imageStorageModel,
    imagePullConcurrency, kubeletMetadataModel }`; neither slot policy is inferred from CPU.
  - The non-empty per-instance disk/carve templates and closed accelerator offering retain template-local
    link endpoints/kinds.
  - Each disk template retains the closed node-root backing: `InstanceStore { skuDevice,
    provisionedRawBytes, presentation : FilesystemPresentation }` or `EphemeralRootEbs { policy :
    ProviderNodeRootVolumePolicy { volumeType, presentation : FilesystemPresentation, allocation :
    BackingAllocationPolicy } }`.
  - The same `PerInstanceDiskTemplate` separately retains `systemReserve : ProviderUsableDiskCarveTemplate`
    and `carves : NonEmpty ProviderUsableDiskCarveTemplate`, each exactly `{ id, requiredUsableBytes }`.
  - gadt-decode preserves `InstanceStore.provisionedRawBytes` as fixed SKU raw supply and every carve's
    `requiredUsableBytes` as mounted-filesystem usable demand; it never normalizes one unit into the other.
  - The EBS arm deliberately has no author-supplied byte request.
  - Phase 29 derives a private `ProvisionedNodeRootVolumeRequest { volumeType, requiredUsableBytes,
    presentation, allocation, sizeGiB, provisionedBytes, witness }` from system reserve plus the unique
    carve set and catalog/provider allocation rules, then privately constructs
    `ProvisionedPerInstanceDiskTemplate`.
  - For either backing arm that private value converts the SKU raw bytes or allocation-rounded root request
    through the pinned filesystem presentation into `mountedUsableBytes`; only afterward may it prove
    `systemReserve.requiredUsableBytes + Σ unique carves.requiredUsableBytes ≤ mountedUsableBytes`.
  - Its `DiskTemplateId`, `DiskCarveTemplateId`, and `AcceleratorSlotTemplateId` remain class-local recipe
    names in types distinct from concrete `PhysicalDiskBackingId`/`DiskCarveId`/`AcceleratorDeviceId`;
  - gadt-decode never invents or reuses a future node's physical identity.
  - It preserves the fields needed to derive a globally scoped `ProviderInstanceId { account, cluster,
    class, ordinal }`, copying `account` unchanged from the managed target, plus the full disk/carve/slot
    template path and the operands for the Phase-9 local uniqueness, reference, layout alias/support,
    role-byte, provider-disk raw-to-mounted-usable/nested-fit arithmetic, and accelerator raw-reserve-net
    checks.
  - Each class also preserves the exact `name`, `sku`, `allocatable`, `quotaVcpu`, `zones`, `price`,
    `baseCount`, and `maxCount` fields.
  - The outer normalized quota preserves all five exact fields: `ProviderQuota { maxInstances, maxVcpu,
    acceleratorCaps, nodeRootStorage, durable }`, with `nodeRootStorage = NoNodeRootEbs | BoundedNodeRootEbs
    { bytes, volumeCount }` and `durable = NoDurable | Bounded { bytes, volumeCount }`. `acceleratorCaps`
    remains a profile-keyed map whose selected classes cumulatively debit one entry; duplicate-profile input
    has no normalized representation.
  - The target `CloudAccountId` is the exact join key into `SharedSupplyLedger.accounts`; a missing or
    different key cannot be reconstructed from credentials.
  - The hostless control plane never erases worker supply from `ClusterIR`, and `quotaVcpu` is never
    inferred from net `allocatableCpu`.
- Every normalized `Observability` deployment binding retains a mandatory finite
  `MonitoringWorkBudget { maxWorkflows, maxRules, maxSeries, maxScrapeSamplesPerSecond,
  evaluationInterval, evaluationCpu, evaluationMemory, retention,
  query : QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout,
  costModel }, volume : { claim : StatefulSetClaimSlot, backing : BackingId,
  presentation : VolumePresentation }, tsdbCostModel }`. Counts/rate become `PositiveNatural`, intervals become
  `FiniteDuration`, and CPU, memory, and storage remain unit-tagged quantities with an exact StatefulSet
  claim/backing/presentation; omission, a
  defaulted field, scalar query-temp, or a descriptor-independent fixed Prometheus provision has no normalized bypass. Phase 30
  owns the later descriptor-count and cost fold; gadt-decode guarantees the fold's operand survived decode.
- Every normalized build retains a mandatory `BuildExecutionEnvelope`: a non-empty list of
  `BuildStageDemand` values with branded stage id, platform, dependency ids, per-stage `HostResources`, and
  per-stage intermediate-byte peak plus cache-write delta; `scratchBacking : HostStorageBackingId`; `cache : HostCacheDemand` with
  typed `CacheBackingId` plus `CacheBudget`; and separate
  `Serial | BoundedParallel PositiveNatural` architecture and stage concurrency policies. The decoder proves
  dependency references are closed and the graph acyclic; Phase 9 derives maxima over every legal concurrent
  set. All quantities and references survive in their refined domains; there is no optional, editable-
  aggregate, or descriptor-independent builder-resource bypass. Phase 56 owns snapshot-bound live admission,
  not decoding.
- Every normalized `KindEngineDemand` retains non-empty ordinal-indexed node-container runtime, full
  `NodeCapacity`, and in-node `KindControlPlane | KindWorker` reserve plus a distinct host-only
  Docker/containerd/kind-supervisor reserve. The decoder preserves the nesting; Phase 9 proves in-node reserve
  + allocatable fits the container and then charges that container once plus only the host reserve.
    - Every normalized rke2 server/agent node retains a mandatory `Rke2Server`/`Rke2Agent` reserve.
    - Each reserve carries `processes : NonEmpty EngineProcessEnvelope`, `storage.carve : DiskCarveId`, and
      a role-indexed `storage.demand : ControlPlane | Worker`.
    - Kind/server process ids contain the applicable runtime, kubelet, apiserver, etcd, controller-manager,
      scheduler, and role-overhead entries; an agent contains runtime, kubelet, and agent overhead.
    - Each has `runtime : HostResources`.
    - A kind host reserve additionally retains its exact node-container `ImageArtifact`, host container
      storage-model/driver, finite pull concurrency, per-ordinal writable/log allowances, and named
      data-root carve; it cannot collapse host OCI content and active snapshots into process log bytes.
    - A control-plane demand retains `staticEngineBytes`, `etcd { backendQuotaBytes, maxWalFiles,
      retainedSnapshots, maintenance = SerializedSnapshotAndDefrag, storageModel : EtcdStorageModelVersion,
      logical : EtcdLogicalDemand { desiredObjects, churn, model } }`, with `churn { maxEventsPerWindow,
      eventWindow, maxEventBytes, eventRetention }` as the sole Event authority; `audit { maxBytesPerFile,
      maxBackups, retention }`, `kubeletRuntimeLogs { maxBytesPerFile, maxBackups, retention }`, and
      `historyRequirement`; the worker arm retains static bytes and the same bounded
      per-file/backups/retention log shape.
    - Each retention/history value is a `FiniteDuration`.
    - A role/ storage mismatch, missing/duplicate/foreign process, unexplained aggregate reserve, omitted
      storage class, or optional/defaulted applicable history requirement returns a structured decode error.
    - Each autoscaled rke2 candidate retains the template-local agent reserve/system-carve reference and
      declared raw per-instance host CPU/memory/disk supply, distinct from the managed-provider
      SKU/no-reserve arm.
    - Missing raw host supply, process-template qualification, or SKU identity is a decoder-field-inventory
      failure.
    - Phase 55 owns kind fit/enforcement; live multi-node rke2 admission/enforcement remains an explicitly
      unassigned Phase-N gate and no current live phase may claim it.
- An in-file honesty note that binding/capacity/topology totals ([§4.6](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)/[§4.7](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)) are *not* foreclosed by these
  types — the decoded declarations are intentionally **unprovisioned**. Phase 9 owns the total feasibility
  folds and Phase 31 invokes them on the fully expanded `BoundDeployment`; only their private constructor
  produces `ProvisionedSpec`. `ClusterIR` and `BoundDeployment` are forbidden renderer inputs and a structural
  type-inventory check rejects any `Provisioned*` field in either.
- Reviewed `.hs` minimal-pair compile-fail declarations: for each of [§4.2](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)/[§4.3](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)/[§4.4](../documents/illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally), a legal twin compiles and is joined by a Haskell case identity to the named Phase-25 positive it decodes through. Its illegal twin fails `ghc -fno-code` with a type error naming the same constructor/index; a separately authored `.hs` oracle owns the expected error class and locus.

### Validation

1. For each of [§4.2](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (phantom tenant), [§4.3](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (GADT transition index), and [§4.4](../documents/illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (ownership index), the phase reviews
   **two `.hs` source declarations differing only in the one index** — tenant tag, state index, or owner. The
   legal twin compiles and its Haskell case identity joins it to the named Phase-25 positive that must decode
   through the constructor. The illegal twin fails `ghc -fno-code` with a type error naming that same
   constructor/index and matching the separately authored Haskell locus expectation. The compile-time pair is
   Sprint 26.2's standalone check; the decode-through round-trip to the cited
   positive is confirmed at the Sprint 26.4 gate once `decodeCluster` exists (Sprint 26.3). The check is red if
   the legal twin fails to compile, if its cited positive later fails to decode through it at the gate
   (foreclosing absence-by-omission), or if the illegal twin's failure locus does not match. The legal
   vocabulary compiles.
2. The pair cannot be satisfied by a strawman `mkCrossTenantRef` that was simply never defined. Because the
   legal twin is a required-to-compile, actually-decoded constructor, an impoverished vocabulary that spells
   cross-tenant references freely fails its legal twin, or fails to decode the cited positive. The compile-fail
   diagnostic class and semantic locus are separately authored in a reviewed `.hs` oracle. Raw compiler text
   is a run-local `.build/**` observation, and the exhaustive compile-fail corpus is assembled in Phase 27.
3. Every named positive fixture decodes with a complete normalized resource/capacity tree, and a structural
   traversal finds no execution unit without id/revision and one kind/cardinality/policy/resource-compatible
   private body;
   - no zero-progress Deployment, invalid/both-positive DaemonSet rolling pair, feature-gated or
     nonzero-partition StatefulSet field, Job without finite terminal retention, or CUDA/Metal lifecycle
     mismatch;
   - no incomplete `ResourceEnvelope`;
   - no target without `Capacity`, no unnormalized resource string, no empty pod container list or
     lifecycle-tagged container without `Resources` plus private runtime-memory, closed root-filesystem arm,
     and log allowance;
   - no container whose content-digested `ImageArtifact` lacks index digest/stored bytes or a platform's
     child-manifest, config, compressed-layer, snapshot-chain/unpacked, and bounded workspace entry;
   - no target without logical pod-ephemeral allocatable, a closed filesystem layout, pinned
     image/kubelet-metadata models, and finite pull-concurrency policy;
   - no physical host without globally scoped backing/carve ids, `allocatableRawBytes`, parent-indexed carve
     extent arms, and its complete partition/VM-layout plus logical-pool-id graph;
   - no `VmDiskCarve.id` dropped, substituted, or detached from its parent partition (the later provisioned
     id must equal this normalized raw id);
   - no retained/cache/host-storage logical id without exactly one role-compatible physical carve;
   - no node filesystem reference lost or renumbered;
   - no managed provider target missing its authored `CloudAccountId`, any of the five exact `ProviderQuota`
     fields, or either closed storage arm;
   - no provider node class missing `allocatableCpu`/`allocatableMemory`, `podSlots`, CNI/IP `cniSlots`,
     driver-indexed `attachableVolumes`, finite `cpuOvercommit`, per-instance `localDisks`, exact
     `localStorage` layout/model/pull fields, closed instance-store/ephemeral-root-EBS backing policy,
     `InstanceStore.provisionedRawBytes`, `ProviderUsableDiskCarveTemplate.requiredUsableBytes`, or
     per-instance `accelerator` slot/link template;
   - no provider class missing `name`/`sku`/`quotaVcpu`/`zones`/`price`/`baseCount`/`maxCount`;
   - no class-local template id occupying a concrete physical id field and no provider-instance scope/path
     field lost;
   - no migration prior-ref deployment/generation/resource arm, replacement, or policy field lost;
   - no `RegistryStorageIntent` image digest, `PatroniSqlIntent` source operand, `ObjectStoreProducerIntent`
     arm, or `ObjectStoreGatewayIntent` field lost;
   - no binder-output demand or `Provisioned*` record present in `ClusterIR`;
   - no duplicate Event authority outside `ControlPlaneStorageDemand.etcd.logical.churn`;
   - no Observability binding without every refined `MonitoringWorkBudget` field including
     `volume.claim`/`volume.backing`/`volume.presentation`, no build definition without every refined
     per-stage/dependency/concurrency `BuildExecutionEnvelope` field, no kind or rke2 self-managed node
     without the exact role-indexed named static-process envelopes or any applicable `ControlPlane | Worker`
     storage/history field, no durable platform declaration missing normalized BookKeeper
     quorum/fault/bookie-slot fields or any of the four required `BookKeeperLogicalDemand` byte fields,
     MinIO erasure/fault/drive-slot fields, content-store resident/concurrent/failed-write/orphan-horizon
     fields, or the identities required for a uniform claim-template projection;
   - no `DeclaredVolumeDemand` without a StatefulSet slot/backing/logical-byte/ geometry-owner/presentation
     value or backing allocation minimum/quantum;
   - no exact cache population, registry object/upload, or Vault persisted/Raft/audit operand collapsed to
     an editable aggregate;
   - no pod arm without bounded pod-local volumes or exact structural runtime-metadata network/mount
     sources, no memory-backed volume whose non-empty access ids fail to resolve or whose
     stage-local/pod-lifetime persistence is invalid for the container lifecycle, no in-cluster cache whose
     `VolumeId` fails to resolve to exactly one disk-backed volume, no Apple-Metal or host-cache arm inside
     a pod envelope, no in-cluster-volume cache inside a host-worker envelope, no pod CUDA owner
     `ContainerId` that fails to resolve exactly once, and no accelerator owner demand whose source/workload
     keys differ, whose coexistence domains differ from `classes(sources)`, whose residency byte
     semantics/shard sum/unique ids/count are inconsistent, or that has lost family/profile, CUDA wholesale
     device count/interconnect, concrete/template raw/reserve/net VRAM/link graph, or Apple Metal
     profile/unified-memory residency.
   - The traversal is red on a decoder mutant that drops any one resource field.
   - The positive set round-trips distinguishable `Unified` and `SplitRuntime` layouts, both provider root
     backing arms, unequal `InstanceStore.provisionedRawBytes` and
     `ProviderUsableDiskCarveTemplate.requiredUsableBytes` operands without collapsing their units, raw VM
     id/presentation/allocation without aggregate bytes, exact cache/Vault structures, and a Registry arm
     whose `RegistryStorageIntent` image digests round-trip without a pre-bound `RegistryStorageDemand`.
   - There is deliberately no v1 containerd `SplitImage` positive.
   - In particular, `legal_deployment_rules` contains an `Observability` binding with nontrivial,
     pairwise-distinguishable values for every `MonitoringWorkBudget` field, and the test asserts exact
     field-by-field round-trip equality rather than merely accepting any present budget. `legal_managed_eks`
     likewise uses pairwise-distinguishable account, slot-policy, attach-driver, class, and quota values,
     and the traversal asserts exact field-by-field equality so an account-substitution decoder mutant or
     collapsed quota/slot field turns the gate red.
   - The later shared-ledger property separately rejects a wrong-account join.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Phase 26 remains blocked and NOT VALIDATED. Exhaustive catalog expansion is Phase 27.

## Sprint 26.3: The fail-closed decoder (`Dhall.inputFile auto` + exception-catch) + structured `DecodeError` ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`dsl_doctrine.md §5 — gadt-decode, the Haskell typed decoder`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
implement the fail-closed in-process decoder that mirrors hostbootstrap's `decodeContextFile = inputFile
auto` and its `Left (ContextDecodeFailed …)` fail-fast return — *sibling evidence, not an amoebius result* —
so nothing is ever reconciled against a config that did not fully decode.

### Deliverables

- `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)` over the native `dhall` library, with a
  structured `DecodeError` whose class of failure is carried by **distinct constructors** — `SchemaMismatch`,
  `OutOfDomainArm`, `UnspellableCombination` — not a single catch-all arm; and an `NFData ClusterIR` instance
  the decode path forces with `evaluate . force` so the `Right` value is proven deep-NF-total, not merely WHNF.
- A **resolve-and-freeze** stage ahead of that decode: an import-graph preflight rejects every direct and
  nested `env:` and remote (`http(s):`) import, returning the `ForbiddenImport` arm of `DecodeError`, and the
  remaining local imports resolve into one `sha256:…` semantic-integrity-frozen normalized tree. Only then does
  `Dhall.inputFile auto` run its structural table decode over that resolved, frozen expression.
- Resource normalization is part of that same total decode: quantities are converted to canonical typed units,
  every required envelope/capacity field is retained, and invalid refined values are returned as a structured
  `Left` naming the field path. Normalization does **not** claim target feasibility; it produces only the
  unchecked declarations later consumed by the post-bind `planInfrastructure`/materialization/`provision`
  pipeline.
- An exception-catch wrapper around `Dhall.inputFile auto`: because `Dhall.inputFile auto` alone throws
  (`DhallErrors`, IO exceptions) rather than returning `Left`, it does not satisfy the never-throw contract on
  its own; the wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed).
- A non-partiality guard: the pure decode code is strict and, under `-Wall` + a partiality grep, free of
  `error`/`undefined`/partial matches. Together with the wrapper this delivers a checked-non-partial,
  fail-closed decode — not a proof of termination or of exception-freedom of the underlying `dhall` library.

### Validation

1. A malformed or out-of-domain value returns a structured `Left DecodeError` — including inputs on which
   `Dhall.inputFile auto` throws, which the wrapper catches and tags rather than propagating; the partiality
   gate reports no partial call reachable from the pure decode code; and the `evaluate . force` on the decoded
   value converts any hidden bottom into a caught `Left` (deep-NF check, not a shallow `Right _` match).
   "Strictness forces the decoded value" is disambiguated here to **deep normal form**: the derived
   `NFData ClusterIR` instance is what makes an unevaluated bottom in any field surface as a caught exception
   rather than passing as a `Right`.
2. The three named failure classes are **distinct constructors** and each is reachable: a decode reproducing a
   thunked/bottom field is caught as `Left` rather than escaping — proving the deep force is on the live path.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Phase 26 remains blocked and NOT VALIDATED.

## Sprint 26.4: The gadt-decode decode battery (`gadt-decode-spec`) — the gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §2 — Register 1`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing): assemble the
in-process decode battery that exercises the fail-closed decoder over every positive fixture and confirms it
returns a structured `Left` on each representative gadt-decode negative, emitting a Register-1 proven/tested/assumed ledger
with model↔runtime correspondence marked UNVERIFIED (owned by Phase 65). The exhaustive per-catalog-entry
corpus, the QuickCheck closure/round-trip/fold-totality properties, and the per-entry validation-locus ledger
are the front-loaded next phase ([Phase 27](phase_27_illegal_state_covering.md)); the capacity/topology fold
negatives are [Phase 9](phase_09_resource_index.md), and provider-expanded/capability feasibility is
checked at [Phase 31](phase_31_provision_seal.md)'s conditional post-bind infrastructure-planning and
provisioning boundary.

### Deliverables

- `test/spec/dsl/DecodeSpec.hs` asserting: each Haskell-declared positive lazily rendered as `legal_*.dhall`
  decodes to its `ClusterIR`; each run-local `illegal_decode_*.dhall` gadt-decode negative first passes
  `dhall type` then returns the expected structured `Left DecodeError` from the independent Haskell case map;
  no serialized header supplies the verdict; and every positive's decoded resource/capacity
  traversal exactly preserves execution id/revision and the complete kind-indexed controller/cardinality/
  policy/resource body while proving every kind's progress/render invariant; every deployment retains
  exactly one normalized `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` source with exact
  deployment/generation identity;
  - **Compute.** CPU, memory, logical ephemeral-storage, and `PodRuntimeMetadataSource`.
  - **Physical backing and carves.** Physical-backing/carve identity and
    `PhysicalDiskPartition.allocatableRawBytes`, plus each `NamedDiskCarve` parent index and extent-arm
    geometry.
  - **Slots and node filesystems.** Allocatable pod slots, driver-scoped CSI attach slots, each durable
    demand's node-local/CSI driver identity, layout-shaped node/VM filesystems, non-authorable mapped-file
    source/accounting-model operands, and raw-VM presentation/allocation without an editable byte total.
  - **Images and stored objects.** Complete OCI stored-object/snapshot/workspace metadata and image model,
    durable/cache/registry/Vault storage, and volume presentation and backing allocation policy.
  - **Provider identity and quota.** The provider target `CloudAccountId`, exact `podSlots`/CNI-IP
    `cniSlots`/driver-indexed `attachableVolumes`, complete provider-node-class/root-backing shape, and every
    `ProviderQuota` field/storage arm.
  - **Prior-provision references and migrations.** Every `PriorProvisionRefSource`
    deployment/generation/resource arm, the required whole-deployment first/update arm and separately branded
    `PriorExecutionProvisionRef`, plus each storage/registry/schema migration intent's
    replacement/policy/backing/chunk/concurrency operands.
  - **Service intents.** Every `RegistryStorageIntent` image digest, ZooKeeper metadata, and every
    `PatroniSqlIntent` source operand.
  - **Controllers, monitoring, build and engine.** Every supported controller descriptor's replica/rollout
    and complete child pod/PVC resource-source operands, every mandatory `MonitoringWorkBudget` field
    including `volume.presentation`, every `BuildExecutionEnvelope` stage/dependency/concurrency field, every
    role-indexed named `EngineSystemReserve` process and applicable engine-storage/history field, exact etcd
    desired-object/churn operands, and exact Pulumi deploy/state-field/plugin/concurrency/workspace operands.
  - **Storage geometry and the object store.** BookKeeper quorum/fault/bookie-slot geometry, MinIO
    erasure/fault/drive-slot geometry, exact physical-id-keyed object-store residents plus structural
    additional-retention/concurrent/failed-write/orphan/admission bounds, `ObjectStoreGatewayIntent`, all six
    `ObjectStoreProducerIntent` arms including the raw Registry arm's `RegistryStorageIntent`, every
    producer's required `StorageBudgetId` and the unique closed budget inventory/owner reference, uniform
    claim-slot/`DeclaredVolumeDemand` identity, and root-filesystem arms.
  - **Accelerators and host enforcement.** Accelerator owner family/profile/device-count, exact
    source/workload key equality, coexistence-domain equality, structural residency
    byte/shard/interconnect declarations, concrete/template supply raw/reserved/net-VRAM/link declarations,
    and the substrate-indexed host enforcement arm plus finite Apple supervisor operands.
- A separately authored `test/oracle/gadt_decode_ir/ResourceFieldInventory.hs` that names the complete
  normalized field/union inventory independently of `decodeCluster`, plus reviewed Haskell decoder mutation
  operators, applied only to temporary production-source copies beneath `.build/mutants/**`, that drop
  `ephemeralStorage`, erase a physical-carve or `allocatableRawBytes` field, erase a `NamedDiskCarve` parent
  index/extent arm/geometry field, erase `kubeletMetadataModel` or one runtime-metadata source identity,
  erase an execution id/revision/controller-kind/cardinality/
  replicated-count/per-node-selector/policy/Job-terminal-retention operand, weaken Deployment rolling to
  accept `{ 0, 0 }`, admit DaemonSet both-positive, add a StatefulSet feature-gated field/nonzero partition,
  cross a controller with the wrong resource/accelerator/replacement arm, drop the execution transition/ref
  deployment/generation/resource arm, accept `UpdateFrom` with the wrong resource arm or implicit latest
  generation, erase an accelerator source/workload/residency/coexistence operand, mismatch the coexistence
  domains, or corrupt sharded totals/ids/count;
  - erase provider `podSlots`, `cniSlots`, or `attachableVolumes`, erase the target `CloudAccountId`, erase
    any exact `ProviderQuota` field, erase provider-class `quotaVcpu`, conflate a class-local template id
    with a concrete physical id, drop/substitute a raw `VmDiskCarve.id`, replace `MonitoringWorkBudget` with
    fixed Prometheus resources, replace a storage fault policy with an editable scenario list, drop
    orphan-GC/claim-slot fields, or delete layout/model/OCI-object/snapshot, VM presentation/allocation,
    provider root backing/root quota, volume presentation/backing allocation or
    `MonitoringWorkBudget.volume.presentation`, mapped-file/API-object/etcd-logical operands,
    storage/registry/schema- migration-intent/prior-ref operands, substitute a wrong prior resource
    arm/generation, admit both first-deploy and update fields instead of the closed union, inject a
    `Provisioned*` field into `ClusterIR`, add a duplicate Event record, drop one of the four nested
    Event-churn fields, or delete ZooKeeper/Patroni-intent operands, Pulumi-execution operands, controller
    child/rollout source operands, exact cache population, registry upload, object-store
    resident/retention/admission/producer identity, Vault Raft/audit, or host enforcement fields;
  - the traversal/type inventory must reject each mutant independently.
- The **concretely named representative gadt-decode negative set** ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 7) is a Haskell corpus that must lazily generate beneath `.build/test-corpora/**` **exactly one `illegal_decode_*.dhall` case per named `DecodeError` class** — `illegal_decode_schema.dhall`
  (`SchemaMismatch`), `illegal_decode_domain.dhall` (`OutOfDomainArm`), `illegal_decode_unspellable.dhall`
  (`UnspellableCombination`, a raw
  `RawDeploymentRolloutPolicy.RollingUpdate { maxSurge = 0, maxUnavailable = 0 }`) — each Haskell case identity
  names the `illegal_state_catalog.md` entry it targets, while serialized case annotations remain diagnostic;
  each is
  paired with a positive `legal_*.dhall` differing only in the foreclosed dimension ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 8). Every one
  passes `dhall type` (dhall-typecheck-green) by construction; the rollout case has both `{ 1, 0 }` and `{ 0, 1 }`
  legal controls.
- **An applied Haskell changed-subject mutant** ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 2), generated and re-run beneath the candidate root: a legalized twin of
  `illegal_decode_schema.dhall` whose gadt-decode-illegal index is corrected so the value would decode; the suite
  **must go red** when the mutant replaces its negative, demonstrating the "any illegal fixture decodes ⇒ red"
  check actually executes.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the decoder is checked non-partial and fail-closed
  in-process, but no runtime-enforcement claim is made.

### Validation

1. Rejected historical observation: the `gadt-decode-spec` Cabal suite was recorded green — positives decode;
   every `illegal_decode_*.dhall` negative first passes
   `dhall type` (suite red otherwise, so the rejection on record is gadt-decode's and not dhall-typecheck's, which
   forecloses negatives that are merely ill-typed Dhall) and then returns the tagged `Left` matching its
   independently authored Haskell expectation; the suite is red if any gadt-decode-illegal case decodes; all
   four `DecodeError` tag arms have >=1 fixture (suite red if any arm is empty); and the deep-NF force and
   fail-closed assertions hold. Each positive's resource/capacity traversal is complete and normalized, and
   the dropped-resource-field decoder mutant turns the suite red.
2. The applied Haskell seeded mutant (the legalized twin of `illegal_decode_schema.dhall`) turns the suite **red**
   when substituted — a re-run, executed demonstration that "any illegal fixture decodes ⇒ red" is a live
   check, not a tautological restatement of the assertion's polarity.
3. The normalized resource-tree traversal matches a separately authored Haskell resource-field inventory on
   every positive and turns red under the applied dropped-`ephemeralStorage` decoder mutant; a decoder cannot pass by preserving only
   CPU/memory or collapsing accelerator/VRAM structure.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The exhaustive per-catalog-entry corpus begins in Phase 27.

## Sprint 26.5: Decoding the shared `SecretRef` and rejecting a literal ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Give the decoder the second half of the secrets contract of
[`vault_pki_doctrine.md` §3](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value):
*if it decodes, it carries no secret* — decided from the value, not from whether the author reached for the
type.

### Deliverables

- The `Prompt` arm on `Amoebius.Vault.SecretRef`, so the Haskell type spans the same three arms as the Dhall
  union and one shared type serves both gates.
- A `PlaintextSecret` `DecodeError` tag and the refinement that returns it.
- A dhall-typecheck-green negative that must still be rejected, with its one-place paired positive.
- The §M.8 paired positive of every negative decoded and required to succeed.

### Validation

1. Rejected historical observation: the `gadt-decode-spec` Cabal suite was recorded green with four tagged
   negatives at four distinct tags.
2. The plaintext negative passes `dhall type` and returns `PlaintextSecret`.
3. Each negative's paired positive decodes; a twin that stopped decoding fails the suite.
4. The decoder stays pure — no socket, no Vault, no filesystem read beyond the spec's own import graph.

### Remaining Work

The pre-reset `None` claim is permanently invalid. Current remaining work includes every
`UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and the Haskell case/oracle/
mutation obligations above. Whether a named secret exists and the prompt write path are
[Phase 61](phase_61_vault_pki.md) targets.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/dsl_doctrine.md` — backlink §5's gadt-decode to the in-process Phase-26 decoder; keep the
  runtime-enforcement half as Tier-2 residue owned by Phase 64.
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry the IR type-/decode-forecloses here
  with its realized foreclosure layer (layers 1–2 → Register-1); keep runtime-checked entries (layer 3)
  deferred, and keep capacity/topology/provider-feasibility entries deferred to the Phase-9 fold and Phase-31
  conditional infrastructure-planning/materialization/provisioning boundary.
- `documents/engineering/testing_doctrine.md` — record the Register-1 in-process ledger variant this gate
  emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the human authority may change Phase 26 after reviewing a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-26 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius` cabal package, `src/Amoebius/Dsl/{Types,
  SmartConstructors,Ref,Decode,Error}.hs`, and the bounded `gadt-decode-spec` test-suite as Phase-26 rows.

## Related Documents

- Phase-26 partial-foreclosure ledger — the tested/proven/unverified split sealed by this gate
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) the typed spec gates; gadt-decode is adopted here
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§4](../documents/illegal_state/illegal_state_catalog.md#4-planning-ownership) the typing techniques the
  IR carries; [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)/[§6](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) the load-bearing limit and the honest foreclosure-layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_25](phase_25_dhall_schema_generation.md) — dhall-typecheck, the Dhall schema this decoder mirrors
- [phase_27](phase_27_illegal_state_covering.md) — the exhaustive illegal-state corpus, properties, and
  validation-locus ledger built atop this decoder
- [phase_9](phase_09_resource_index.md) — the pure capacity/topology fold implementation and
  properties deferred from here; Phase 31 invokes them after bind/expansion while deriving the conditional
  infrastructure plan and again at the post-materialization provision seal
- [phase_65](phase_65_live_dsl_deploy.md) — the Tier-2 runtime-enforcement half of the DSL
