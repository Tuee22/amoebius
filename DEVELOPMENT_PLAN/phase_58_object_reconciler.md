# Phase 58: Typed renderer + object reconciler

> **Purpose**: Take an opaque whole-deployment `ProvisionedSpec`, re-observe and cross-check the target's
> complete resource/capability inventory before mutation, construct the Phase-33 deployment-global
> `renderAll` object list and separately validate/index it, then enact snapshot-bound typed actions on a live
> single-node `kind` cluster — mandatory bootstrap-holder `Lease` authority, scoped server-side apply,
> kind-indexed controllers, staged serial/host/accelerator execution, Job terminal retention, and
> authenticated deletion — observing each action's live postcondition until the generation converges and
> proving an immediate re-run is a no-op; the `amoebius-capacity` scheduler that later binds guarded Pods by
> CAS reservation is layered on in Phase 59.
> **Read this if**: phase 58 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/deterministic_simulation_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 58.1: Deployment-global desired state + authenticated live inventory + typed action plan ⏸️](#sprint-581-deployment-global-desired-state--authenticated-live-inventory--typed-action-plan-)
- [Sprint 58.2: Bootstrap Lease authority + generic typed-action dispatcher + scoped SSA + storage-scaling dispatch ⏸️](#sprint-582-bootstrap-lease-authority--generic-typed-action-dispatcher--scoped-ssa--storage-scaling-dispatch-)
- [Sprint 58.3: Staged execution transitions, Job terminal protocol, and authenticated deletion ⏸️](#sprint-583-staged-execution-transitions-job-terminal-protocol-and-authenticated-deletion-)
- [Sprint 58.4: Wait-for-ready + the idempotent-convergence gate (re-run no-op) ⏸️](#sprint-584-wait-for-ready--the-idempotent-convergence-gate-re-run-no-op-)
- [Sprint 58.5: Register-2.5 reconciler + staged-execution convergence under simulated faults ⏸️](#sprint-585-register-25-reconciler--staged-execution-convergence-under-simulated-faults-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 57, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target is amoebius's live typed-action **object reconciler**. Gate-passed Phase 33 must supply
`renderAll :: ProvisionedSpec -> [K8sObject]`: one deployment-global rendered list with exact structural source ownership across service controllers, admission, quota, RBAC/config, route, storage, and control-plane projections. `validateAndIndexRenderedObjects` is the separate pure step that checks each emitted object's identity against its source key and constructs the `Map KubernetesObjectId (K8sObject, RenderActivation)` used
by diff; it rejects duplicates, source/object-stage mismatch, or domain mismatch rather than changing
`renderAll`'s canonical signature. Omitted global projections and per-service last-writer-wins concatenation
are impossible. The exact list is the dry-run result, and only its validated index is the desired-object
baseline.

That full list is not permission to apply every object at cold start. The corresponding provisioned render
sources carry a closed activation index
`Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover | AfterManagedCapacityReady`;
`validateAndIndexRenderedObjects` preserves that index beside each object, and generic SSA never scans the full
rendered list and applies a later-stage object early. **List membership alone is never generic-SSA authorization.** In this phase the enacted corpus spans the `Immediate` bootstrap actions (the derived
control-plane Namespace and the mandatory reconciler `Lease`) and the general, default-scheduled workload
actions; the *stage-unlock gating* that consumes `BootstrapSchedulerStage`, `AfterBootstrapAddonCutover`, and
`AfterManagedCapacityReady` is produced by the two-stage scheduler bootstrap and therefore belongs to
Phase 59. The Phase-58 contract owns the index-preservation and the fail-closed refusal to grant generic apply authority
over a Pod/controller or mutable ledger/Lease field; Phase 59 owns the witnesses that unlock the guarded
stages.

The live reader then takes one coherent snapshot of objects and all capacity. Desired execution epochs are
keyed by `PlannedExecutionSlotId`, which is a pure capacity slot and never a future Pod UID. Live execution is
an `ObservedExecutionSet` keyed by
`KubernetesPod PodUid | HostProcess HostProcessInstanceId | HostReservation HostReservationId`. The third arm
represents `Reserved | LaunchInFlight | RetainedArtifacts` **host-supervisor** ledger rows for which no process
identity is yet or any longer observable; it cannot masquerade as a running process or be omitted from residual
capacity. (This is amoebius's own host-daemon reservation ledger, observed through the HostProcess supervisor;
the *k8s scheduler* reservation ledger and its `Reserved | BindingInFlight | Bound | Terminating |
TerminalRetained` records are a distinct structure added in Phase 59.) The observed set validates the
admission-protected deployment/generation/source/revision/reservation-template annotations and the kind-indexed
Pod owner chain — Deployment Pod→ReplicaSet→Deployment, or direct StatefulSet/DaemonSet/Job — plus
resourceVersions; host processes carry the analogous supervisor provenance. A terminating predecessor and its
replacement for one planned slot remain two distinct live commitments.

Normalization charges each observed identity once: an API-only Pending Pod, a Running/Terminating Pod joined to
its runtime-storage vector, a retained terminal Pod on its retained axes, a host process once, and a host
reservation/`LaunchInFlight`/retained-artifact row exactly once — process-observed `LaunchInFlight` enters
`HostLaunchRecovery`, while Running/Draining exact-join the host reservation to its observed process. Unclassified
orphan, missing, wrong-state, wrong-node, wrong-generation, wrong-template, unequal-axis, or duplicate joins fail
closed with no `ValidatedLiveTarget` constructor. Runtime storage is rederived per observed eligible Pod
component, grouped by `KubeletNodefs | CriRuntimeRoot`, resolved through `Unified | SplitRuntime | SplitImage`,
combined with the disjoint `ImageContentRoot | CriRuntimeRoot` image model, and checked once per physical
backing. Pending Pods have no observed node-runtime debit; Bound/Terminating and retained Terminal UIDs carry
the observed Pod-UID runtime row.

Whole-deployment preflight combines those surviving commitments with residual CPU requests and finite CPU-limit
budget, memory, pod logical ephemeral, CNI/CSI/pod slots, API/etcd/mapped files, role-routed physical runtime
and image storage, OCI/snapshot/workspace identity unions, durable/object/native-cache presentation and geometry,
host processes/builds, controller children/webhooks, gateways/executors/migrations, and CUDA/Metal device/VRAM/
cache holds. Any missing or unbounded arm returns the specific error or `UnknownCommitment` **before effects**.
Success alone mints one single-use `ValidatedLiveTarget` containing the object/inventory fingerprint, all
relevant resourceVersions, the exact normalized and runtime-storage witnesses, the mandatory-Lease
identity/bootstrap-holder/resourceVersion readback, a complete map of `ValidatedExecutionTransitionAction`s, and
the exact map of `ValidatedStorageScalingAction`s derived from Phase-28 policy-only envelopes and fresh storage
snapshots. (The scheduler-ledger CAS-version arm of `ValidatedLiveTarget` is added in Phase 59.) A final
fingerprint recheck consumes the applicable token; change restarts the read-only prefix.

Enactment follows those actions, not a blind SSA/prune loop. Ordinary desired-object actions may use scoped SSA
under `fieldManager=amoebius`; host control, provider/backing mutation, and authenticated deletion use distinct
capabilities. Pod controllers are kind-indexed. Serial OnDelete is three-stage: delete one witnessed old Pod;
after a fresh absence/release observation resume the controller; after another fresh observation of the expected
replacement UID Bound+Ready, advance to the next slot. Host start is authorized only by
`NoPrior | OrdinaryAfterExit | CudaAfterDeviceRelease | MetalAfterDrain`; CUDA/Metal release evidence is live
and fingerprint-bound. Owner labels discover prune candidates but do not authorize deletion: exact
owner/generation/resourceVersion, retention, and dependency guards must mint the delete action.

The target must make Jobs use a typed terminal state machine. It must build and model-check success and
backoff-exhausted-failure completion variants, digest/outcome equality, cleanup deadlines, and
`CompletedJobNoOp`; the future Phase-58 cluster must have neither MinIO nor the Phase-69 sole content-mutation
gateway, so its gate must **not** claim a durable
completion write/readback or delete a terminal Pod on that basis. Its future live Job must reach terminal and remain
explicitly retained and charged; the only inhabitant of the live protocol is
`RetainTerminalAwaitingCompletionGateway`. The first live gateway write → independent matching readback →
deadline/release → terminal cleanup gate is Phase 69. The Job controller still uses `restartPolicy=Never`,
`podReplacementPolicy=Failed`, its exact finite wave/retention provision, and no `ttlSecondsAfterFinished`;
Kubernetes TTL never bypasses the later typed cleanup action.

Every stage re-observes readiness/state instead of sleeping: controller rollout/Ready/Available, CR admission and
child-envelope conformance, serial replacement Bound+Ready, device release, and live Job terminal retention. The
abstract durable-completion/cleanup transitions are exercised in pure and IOSim tests only here. An immediate
live re-run after convergence must mint only `NoOp` plus the same terminal-retention action and make zero writes.
The release ledger/rollback path composes later and does not authorize replaying stale actions.

**Pre-mutation capacity/capability cross-check (§M.5/§M.8).** The live inventory reader is independent of the
pure provision fold and combines apiserver node allocatable values and all scheduled/live commitments with
OS-boundary observations of separately-owned durable/object-store/native-host-cache pools (raw size,
presentation, mounted usable bytes), physical-host VM/process commitments, nodefs/imagefs/containerfs
identity/capacity, all containerd content objects and both final and active containerd snapshot states,
node-image model/enforced pull
policy, current pod/CNI/CSI slot use, serialized API objects/etcd quota, mapped-file payloads/backing, object-store
residents/incomplete writes, and accelerator device/profile/raw-reserved-allocatable VRAM plus current-free
memory, exact work-item/device holds, actual Pod UIDs/host-process IDs plus ledger-only `HostReservationId`s,
kind-indexed owner chains, and protected provenance. It joins observed instances to planned slots by authenticated
source/revision/template witnesses — it never equates a Pod UID with `PlannedExecutionSlotId` — and preserves
simultaneous predecessor/replacement UIDs. It rederives runtime components for each eligible observed Pod, groups
`KubeletNodefs | CriRuntimeRoot`, resolves roles through the observed layout, combines the disjoint image roles,
and checks aliased physical backings once. Desired rendering, observation, typed diff, transition-peak derivation,
and validation are all read-only. A surviving foreign container without bounded CPU/memory/ephemeral ceilings, an
unobservable root-filesystem writability/allowance, a writable `hostPath`, unknown resident content/snapshot bytes,
an unexpected filesystem alias/root/capacity, a mismatched/unobservable pull policy/model, a supported CR/provider
arm without a finite child-resource/rollout/webhook bound, a direct backend object mutation, or an unrecognized
migration/executor is `UnknownCommitment` and fails closed. Phase-55 engine/static components enter through
`EngineSystemReserve`; every remaining kube-system addon is a bounded topology-expanded per-node unit, so stock
system pods are never silently free or an unavoidable unknown. Each negative fails with the specific offending
resource/capability while independent observers show **zero writes**: no SSA, authenticated delete,
host/provider/backing allocation, or completion record, and no owned object's `resourceVersion` changes. A
preflight that runs after the first mutation is invalid.

**Phase scope:** one cohesive claim — *nothing is mutated until the target's inventory has been re-observed and cross-checked*. The renderer's output must be checked and indexed separately from the act of applying it.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster on a linux-cpu host from
Phase 55; no apple, linux-cuda, or windows substrate is touched (the CUDA/Metal transition arms are exercised
against deterministic observed-device models here, and their live substrate proof is owned by Phase 93 and
Phase 89 respectively).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 57](phase_57_complementary_arch_child.md)
**Gate:** `pb validate phase 58`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *nothing is mutated until the target's inventory has been re-observed and cross-checked*. The renderer's output is validated and indexed separately from the act of applying it. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 58` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 57; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact typed renderer + object reconciler emits is a recipe over a content address, never an authored file.
- [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  — **the apply/reconcile engine.** This phase realizes scoped SSA, kind-indexed and staged execution actions,
  authenticated dependency-gated deletion, the pure and simulated Job completion/cleanup state machine, live
  terminal retention, and readiness observed from live state. The amoebius scheduler-role CAS/Binding protocol
  named by [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) is Phase 59; durable Job completion/cleanup first runs live in Phase 69; rollback and the release
  ledger stay deferred.
- [`manifest_generation_doctrine.md` §6 — The reconcile state model: desired is `renderAll(ProvisionedSpec)`, observed is live inventory, actions are typed](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
  — **desired is the validated identity index of `renderAll(provisionedSpec)`, observed is live inventory, and actions are typed.** `renderAll` retains the canonical `[K8sObject]` result; a separate pure `validateAndIndexRenderedObjects` checks source/object identity and duplicate freedom before diff. Desired state is recomputed; actual Pod UIDs/process IDs, owner chains, host reservations, completions, and physical allocations are observed to authorize transitions, never treated as another desired source. (The state-indexed *k8s scheduler* reservation ledger this model also names is added in Phase 59.)
- [`manifest_generation_doctrine.md` §2 — The typed manifest model: `renderAll` is the sole public pure function to objects](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects)
  — **the typed manifest model** (the pure renderer half): this phase *consumes* the Phase-33 pure, total private
  per-source `renderSourcePrivate` projections through the exact deployment-global `renderAll` owner union. The
  `[K8sObject]` list is byte-for-byte the value `--dry-run` previews; its separately validated identity index is the desired map. An unchecked `ServiceSpec`, duplicate `KubernetesObjectId`, or emitted/source identity mismatch cannot reach diff.
- [`resource_capacity_doctrine.md` §8 — Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)
  — **declared at decode, cross-checked at runtime.** Immediately before mutation, this phase re-observes
  CPU/memory/local-ephemeral capacity, pod/CNI/CSI slots, mapped files/etcd logical quota, disjoint
  durable/object-store/migration/native-host-cache pools, admission/executor pods, planned execution slots,
  authenticated observed execution identities, role-routed runtime storage, and accelerator
  devices/profiles/raw-reserved-allocatable plus current-free VRAM and epoch holds, and refuses a stale or false
  provision witness with zero writes.
- [`readiness_ordering_doctrine.md` §6 — The runtime enactor: the reconciler observes, never sleeps](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
  — **the runtime enactor: the reconciler observes, never sleeps.** This phase's target must build wait-for-ready as the
  runtime enactor of a readiness edge — the live condition is read from the object, never assumed by a fixed
  sleep.
- [`daemon_topology_doctrine.md` §3 — The control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon)
  — **the control-plane daemon.** The reconciler is, at steady state, run by the in-cluster control-plane daemon — a
  Deployment `replicas=1`, stateless (no PVC), single-writer authority delegated to k8s/etcd through its mandatory
  `Lease`, **no bespoke election**. This phase drives the reconciler from the host binary as a precursor; standing
  it up *inside* the control-plane daemon is Phase 65.
- [`conformance_harness_doctrine.md` §3 — The load-bearing invariant: rendering never touches live infrastructure](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **rendering never touches live infrastructure.** The boundary this phase honors from the other side: the
  `renderAll`/plan/`--dry-run` path stayed cluster-free through Phase 34, and **apply is the first live step** —
  so live prerequisites (a reachable cluster, credentials) belong here, never on the render path.
- [`generated_artifacts_doctrine.md` §3 — The rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — the applied `[K8sObject]` set is emitted from the Haskell source of truth and absent from the repository;
  what reaches the cluster is generated lazily beneath `.build/**` at apply time.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  — **Register 3** (live infrastructure): the register this phase's gate reaches; and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  the per-run proven/tested/assumed ledger the live convergence emits (no skips, fail fast; the scratch namespace
  is torn down leak-free).
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — **Register 2.5, where deterministic simulation sits.** Sprint 58.5 validates the *built* reconciler and staged
  enactors under `IOSimPOR` fault schedules in-process and deterministically replayable — one rung below the
  Register-3 live gate in the register ladder, not chronologically ahead of it.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanently invalid pre-reset seal record.** A 2026-08-16 run claimed to reseal Sprints 38.1–27.5; that
> claim and every referenced path are historical inventory only and cannot satisfy this contract. There is no
> current candidate evidence or gate pass. A future candidate may write only run-owned material beneath
> `.build/**`. Functional and validation outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Future closure
> requires the redesigned phase gate, predecessor gate pass, legacy closure, universal artifact hygiene, and
> complete gate pass.

## Sprint 58.1: Deployment-global desired state + authenticated live inventory + typed action plan ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 57](phase_57_complementary_arch_child.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
— the reconcile state model. Make desired state the separately validated identity index of the exact Phase-33
`renderAll provisionedSpec :: [K8sObject]` owner union; make observed state a coherent snapshot of Kubernetes objects, actual Pod/process identities, host reservations, completions, and physical allocations; and mint only the typed actions justified by the whole transition. No planned slot is accepted as a live identity, no object label alone is a mutation capability, and no preflight module imports a writer. The state-indexed `amoebius-capacity` scheduler reservation ledger is layered on this observation in Phase 59.

### Deliverables

- `renderAll → validateAndIndexRenderedObjects → observeInventoryAndObjects → authenticateExecutions →
  normalizeCommitments → deriveTransitionEnvelope → validateProvisionWitness → planActions`. The desired map
  proves exact `KubernetesObjectId` ownership across service and deployment-global projections and preserves each
  source's `Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover | AfterManagedCapacityReady`
  activation index (this phase enacts only `Immediate` bootstrap plus default-scheduled general actions and never
  grants generic SSA over the full list; the scheduler-cutover stage-unlock witnesses are Phase 59). The observed
  execution map proves its key equals embedded `PodUid | HostProcessInstanceId | HostReservationId`, checks
  protected provenance and the complete kind-indexed owner/supervisor chain, and preserves every same-slot
  predecessor/replacement UID and ledger-only host row.
- A host-aware observed identity union: `KubernetesPod PodUid | HostProcess HostProcessInstanceId |
  HostReservation HostReservationId`. Host `Reserved`, no-process `LaunchInFlight`, and post-process
  retained-artifact rows remain charged under the host-supervisor ledger-only arm; process-observed
  `LaunchInFlight` enters `HostLaunchRecovery`, and Running/Draining exact-join the process and reservation once.
  Missing, duplicate, or process-fabricated ledger-only identities reject. This is amoebius's own host-daemon
  reservation ledger, distinct from the Phase-59 k8s scheduler reservation ledger.
- Node runtime accounting that rederives planned/observed metadata shapes, maps components to
  `KubeletNodefs | CriRuntimeRoot`, resolves the selected filesystem layout, combines disjoint
  `ImageContentRoot | CriRuntimeRoot` image components, and groups aliases once per backing. Pending has no
  observed runtime row; Bound/Terminating and retained Terminal use the observed Pod UID row.
- A complete `ValidatedLiveTarget` constructed from one `ObservedLiveResourceSnapshot`: mandatory whole
  `ObservedInventory`, exact budget-keyed storage-scaling snapshots, optional cloud observation, shared snapshot
  fingerprint, object/resourceVersions, exact mandatory-`Lease` identity/bootstrap-holder/resourceVersion readback,
  normalized commitment and runtime-storage witnesses, Job completion inventory, render-activation/domain equality,
  and exact action-domain witness. Its storage-scaling map exact-joins every Phase-28
  `ProvisionedStorageScalingEnvelope` to a complete `ObservedStorageScalingSnapshot`, total `planStorageScaling`
  result, backing-specific capability, immediate-snapshot recheck, and fresh `SingleUseStorageScalingActionToken`;
  a concrete transition is reconcile-time state, never a field of `ProvisionedSpec`. The provider observation is
  transition-indexed: host-only `NoChange`, retained-carve, and verified-migration arms carry
  `StorageScalingCloudObservation.NotRequired`, while only `CreateProviderCapacity` can carry the
  `Required ObservedCloudInfrastructureSnapshot` arm. (The scheduler-ledger CAS-version field of
  `ValidatedLiveTarget` is added in Phase 59.)
- Execution actions cover `NoOp`, kind-indexed Pod-controller apply, the three serial OnDelete stages, host
  stop/start authorizations, removed-controller prune, Job completion write/terminal cleanup/completed no-op, plus
  owner-authenticated ordinary object actions. Completion/cleanup constructors additionally require the provisioned
  gateway capability, which is absent from the Phase-58 live environment. Every mutating constructor carries only
  its scoped capability, and none can be minted for a non-holder.
- Preserve the operator child-admission and migration envelopes: admission/quota policy must be Ready before a CR
  action; observed children are independently normalized after health; storage/registry/schema migration actions
  retain old+new+workspace/temp/WAL until verified cutover. Phase 58 owns only the generic storage-scaling
  observation/validation/token boundary: Phase 60 supplies the retained-carve and verified-migration enactors, and
  Phase 76 supplies the cloud provider-capacity enactor. Durable backing is never generic prune.
- A mechanical no-release-store/no-write preflight boundary: AST/import lint over the modules above, plus a runtime
  observer proving no stored-desired-state read/write. Durable Job-completion reads are explicitly represented in
  the planner interface as observed execution state, never a desired manifest store; this phase's live inventory
  requires that gateway-backed arm to be absent and exercises it only through the pure/fake/IOSim boundary until
  Phase 69 supplies the live gateway.

### Validation

1. The deployment-global `[K8sObject]` list equals the separately authored Phase-33 Haskell render expectation;
   the separately validated desired map and action plan equal independently authored Haskell expectations.
   Haskell changed-production-subject mutants for duplicate object identity, source/emitted-identity mismatch,
   source/object activation-stage mismatch, generic SSA over the full list, missing global projection, cached
   observation, and action-domain omission turn red. A Register-1 Haskell planner case with modeled observed
   completion still renders the pure Job baseline but plans `CompletedJobNoOp`, proving enactment is not a blind
   render-list apply; the live Haskell case instead plans terminal retention because no gateway/readback exists yet.
2. Haskell execution negatives cover missing or spoofed annotations, wrong Deployment ReplicaSet hop, wrong
   direct controller kind/resourceVersion, map-key/embedded-identity mismatch, planned-slot-as-Pod-UID, and
   terminator/replacement UID collapse. Haskell host negatives cover omission of Reserved/`LaunchInFlight`/
   retained-artifact `HostReservationId`, use of a fake process id for a ledger-only row, and double debit after
   process join. Positive Haskell recovery cases cover an absent-process host row in each host-supervisor ledger
   state and prove each remains charged until its state-specific release evidence. Exact-fit controls debit each
   identity once. (The Kubernetes scheduler reservation-record negatives — unclassified-orphan record, missing
   reservation, wrong ledger state/node/template, Bound-Pod-plus-ledger double debit — are Phase 59.)
3. Runtime-storage negatives cover component drop/role swap, model ownership overlap/hole, Unified alias
   double-debit/drop, SplitRuntime one-byte-short kubelet-nodefs and CRI imagefs/containerfs backings, SplitImage
   routing mismatch, Pending with a node row, and Bound with both a planned and an observed row. Exact fits succeed.
4. Retain the full one-short capacity corpus for CPU/memory/logical ephemeral, pod/CNI/CSI, API/etcd/mapped files,
   OCI/snapshot/workspace identities, durable/object/native-cache geometry, controller/webhook/gateway/executor/
   migration peaks, and CUDA/VRAM/Metal holds. Every failure exposes no `ValidatedLiveTarget`, and independent
   observers prove zero writes on every mutation surface.
5. Mutate any observed object resourceVersion, Pod UID/owner chain, runtime backing identity, storage-scaling
   allocation/quota/fingerprint, content/snapshot set, device-free value, `Lease` holder, or `Lease` resourceVersion
   after validation. The final recheck consumes/discards the token, makes zero writes, and restarts observation; a
   stale-token mutant turns red.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The receipt and its three-check transcript are written into this run's bundle under `.build/runs/`, never
into the plan tree. Sprint 58.2 consumes the typed action/authority boundary.

## Sprint 58.2: Bootstrap Lease authority + generic typed-action dispatcher + scoped SSA + storage-scaling dispatch ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 58.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
— the apply/reconcile engine. Build the bootstrap `Lease` authority and the generic typed-action dispatcher.
Scoped ordinary-object actions may use SSA; all other effects must consume their dedicated capability. The host
precursor must hold the same provisioned mandatory `Lease` that the Phase-65 control-plane daemon later receives by an
observed handoff. The scheduler's CAS reservation/Binding path and its two-stage bootstrap are Phase 59.

### Deliverables

- Bootstrap authority and ordering from `ProvisionedMandatoryReconcilerLease`: a cold-start token may create only
  the derived control-plane Namespace and the exact `Lease`, execute only typed acquire/renew actions
  (`Absent → BootstrapHeld` and present-state renew) under the bootstrap-host holder identity, and read the exact
  holder/object UID/resourceVersion successor back before any non-authority write. Present-state actions CAS the
  expected resourceVersion; every attempt consumes its fresh observation-bound token and reserves its exact
  `EtcdChurnBudget` projection until a post-attempt observation commits or releases that debit.
- A dispatcher for every non-scheduler `ValidatedExecutionTransitionAction`. `ApplyDesiredPodController` preserves
  the exact controller-kind policy. `SerialOnDeleteStart/Resume/Advance`, host stop/start, Job completion/cleanup,
  and prior-controller delete are sent to their own enactors (built in Sprint 58.3); Job completion/cleanup dispatch
  additionally requires the gateway capability and therefore cannot run in the live Phase-58 gate. `NoOp` and
  `CompletedJobNoOp` cannot reach an effect interface.
- A storage-scaling dispatcher that accepts only a `ValidatedStorageScalingAction`, immediately rechecks its exact
  observed snapshot, atomically consumes the plan-id-indexed `Fresh` token, and dispatches only the
  transition-indexed capability. `NoChange` cannot reach a mutation interface; retained-carve allocation and verified
  migration are abstract effect arms supplied in Phase 60, while provider-capacity creation also consumes the
  transition's exact validated cloud-action batch supplied in Phase 76. Every attempted effect requires post-attempt
  re-observation before success or retry, so a lost response cannot reuse a token. An ordinary host-only live target
  validates with no cloud account snapshot; absence becomes an error only when the planned transition actually
  selects provider capacity.
- Scoped SSA under `fieldManager=amoebius` only for an ordinary desired-object action. It declares the exact owned
  fields, does not GET-modify-PUT, and leaves fields owned solely by another manager untouched. The
  generation/owner/provenance annotations come from the desired object; they are never stamped after diff. The
  bootstrap Namespace/`Lease` objects have dedicated staged actions and can never enter this generic SSA path; the
  scheduler-cutover stage gating that further restricts the general stage behind `BootstrapCapacitySchedulerReady`/
  `ManagedCapacityReady` is added in Phase 59.

### Validation

1. For a scoped SSA action, assert exact `amoebius` field ownership, drift correction of a declared field, and
   preservation of a foreign-owned field. Assert host/delete/Job actions never enter the SSA module, and `NoOp` has
   no writer capability. A Haskell generation-label-stamped-after-diff changed-subject mutant is caught red by
   the external apiserver
   `managedFields`/`resourceVersion`/label comparison, not the engine's self-report.
2. `Lease` races cover simultaneous bootstrap acquisition, lost acquire/renew response, stale resourceVersion, and
   attempted mutation without the exact bootstrap holder. Assert `ceil(renewalWindow/retryPeriod) <=
   maxRenewalsPerWindow` under the left-closed/right-open boundary rule. At every audit resourceVersion there is at
   most one holder; each attempted write consumes one fresh token and reserves exactly one etcd update/revision debit;
   ambiguous ownership retains that debit, emits no mutation capability, and re-observes.
3. Storage-scaling action tests run at the pure/fake boundary in this phase: stale allocation, backing,
   provider-quota, or fingerprint readback invalidates the action with zero mutation; `NoChange` exposes no writer;
   a retained or provider transition consumes exactly one token and dispatches only its indexed fake capability; and
   a lost response forces a fresh observation. Live retained and cloud mutations remain the Phase-60 and Phase-76
   gates respectively.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The live receipt records the Lease CAS, scoped managed fields, stable no-op, and clean postflight.

## Sprint 58.3: Staged execution transitions, Job terminal protocol, and authenticated deletion ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 58.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
— the apply/reconcile engine. Enact the non-SSA members of `ValidatedExecutionTransitionAction` as explicit
observation/effect stages. Ownership labels are candidate discovery only. Every delete, resume, host start,
completion write, and cleanup must carry a fresh snapshot-bound capability proving its exact predecessor and
dependency state. Job completion write/readback/cleanup is implemented against the abstract effect boundary and
validated in pure, fake, and IOSim executions here; the live Phase-58 environment intentionally supplies no such
capability.

### Deliverables

- Serial OnDelete for provisioned StatefulSet/DaemonSet controllers: `Start` deletes one witnessed old Pod; the
  next observation mints `Resume` only after that UID is absent and ordinary/CUDA release evidence is valid; the
  following observation mints `Advance` only when the expected replacement UID has the exact source/slot and is
  Bound+Ready. The provisioned order controls the next slot. No native automatic or parallel arm exists.
- HostProcess actions: stop or drain the exact observed process; start only with `NoPrior`, `OrdinaryAfterExit`,
  `CudaAfterDeviceRelease`, or `MetalAfterDrain`. CUDA evidence proves old owner absence, device-hold release and
  fresh per-device free VRAM. Metal evidence proves drain, process absence, allocation release and cache backing
  state. Fingerprint change invalidates the authorization.
- Job terminal protocol for both `Succeeded` and `FailedBackoffExhausted`: the closed model writes the exact
  `ProvisionedJobCompletionVariant` through an abstract provisioned object-gateway capability, observes matching
  digest/outcome/revision, and only after the cleanup deadline and exact release partition can construct terminal
  cleanup. Failed completion requires a new execution revision before rerun. A matching completion yields
  `CompletedJobNoOp`; a failed write retains the terminal Pod/ledger axes and retries safely. In the Phase-58 live
  cluster the gateway capability is absent, so the only inhabitant is `RetainTerminalAwaitingCompletionGateway`; the
  Pod, API bytes, logs/metadata, and retained partition remain charged. Phase 69 performs the first live
  write/readback/cleanup trace.
- Authenticated object/controller deletion: build candidates from the live prior-owner set, then require structural
  owner, deployment/generation, object identity, resourceVersion, desired/prior union, retention, and dependency
  equality. `PruneRemovedPodController` uses its prior provisioned controller capability. Durable backing and
  unknown/foreign objects have no generic delete arm.

### Validation

1. The linux-cpu serial live test proves delete-one → observe absence/release → resume → observe expected
   replacement Bound+Ready → advance. Haskell changed-production-subject mutants for skip-observation,
   delete-two, wrong replacement UID/slot/source, advance-on-Ready-but-unbound, and stale-fingerprint turn red.
   The CUDA serial release arm runs against
   the deterministic observed-device model, not nonexistent GPU hardware in this phase.
2. Register-2/2.5 transition tests cover ordinary host exit, CUDA device holds/free VRAM, and Metal drain/allocation/
   cache release; one missing release component and one stale observation reject before start. CUDA/Metal live
   substrate proof remains owned by Phase 93 and Phase 89 respectively.
3. Register-1/2 Job tests, available at this sprint's completion, cover all-success and backoff-exhausted failure
   waves, completion-write failure, wrong digest/outcome/revision, cleanup before persistence/deadline, retained-axis
   partition, restart after modeled persistence, and no-rerun until new revision; the exhaustive IOSim schedules over
   these same variants are additionally exercised in Sprint 58.5. In the live Phase-58 run, an independent apiserver
   observer proves the terminal UID remains, no Job-completion object is written, and no delete occurs. The first live
   object-store/apiserver persist-before-delete proof is the Phase-69 gate.
4. Remove a service and prove only snapshot-authorized objects/controllers disappear. Unlabeled, spoofed label,
   foreign generation, changed-resourceVersion, retained storage, active serial predecessor, and
   terminal-before-completion Haskell cases survive. The Haskell `delete-from-owner-label-alone`
   changed-production-subject mutant turns red.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. Sprint 58.4 composes these actions into the full convergence/no-op corpus.

## Sprint 58.4: Wait-for-ready + the idempotent-convergence gate (re-run no-op) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 58.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
(wait-for-ready) and
[`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
gate every action continuation on its live postcondition (never a fixed sleep), then prove the whole engine
idempotent — a re-run of the same deployment-global `renderAll` result plus the newly observed state plans only
`NoOp` plus the unchanged live terminal-retention decision (or `CompletedJobNoOp` in modeled/future gateway-backed
state) — and emit a Register-3 proven/tested/assumed ledger, tearing the scratch namespace down leak-free
([`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)).
This is the phase gate.

### Deliverables

- Wait-for-state: controller rollout, Pod Bound+Ready (bound by the default scheduler in this phase), object
  Ready/Available, CR health, and process/device release are read from their authoritative live sources; the
  completion-persistence/cleanup arms are unavailable in this phase and terminal Job retention is read from the
  apiserver. No `threadDelay` substitutes for observation. For amoebius's own in-phase capacity/reservation CR, its
  child-envelope admission/quota policy is Ready before CR apply and the live webhook Deployment's
  image/resources/replicas/rollout normalize exactly to `admissionExecution`; healthy status is followed by
  controller-owner enumeration of the actual child Deployment/PVC and an independent normalization proving requests,
  limits, replica/rollout overlap, and storage conform to the provisioned child envelope. Unknown or over-bound
  children prevent convergence — post-ready enumeration is not allowed to be the first detector.
- The convergence battery over the Haskell-declared corpus: enact the exact `renderAll`/action plan → observe workload
  readiness → complete the serial stages in order → observe and retain the terminal Job → re-observe and rerun. The
  rerun asserts **zero effects** on all mutation surfaces and only typed no-op actions. Independent readers compare
  apiserver resourceVersions/managedFields/labels, absence of any Job completion object, the retained terminal UID,
  the mandatory `Lease` holder, and host/device state. The red-path Haskell cases and
  changed-production-subject mutants — never-ready Deployment;
  `waitForReady = pure ()`; serial advance before replacement Bound+Ready; generation stamped after diff; over-bound
  CR child on amoebius's own capacity/reservation CRD — MUST go red. A Register-3 ledger records the live convergence,
  marking the release-ledger/rollback residue UNVERIFIED (deferred). (The scheduler bootstrap sequencing —
  `BootstrapCapacitySchedulerReady`, controller cutover, `ManagedCapacityReady` — and the wrong-config-digest /
  bind-before-CAS mutants are Phase 59's gate.)

### Validation

1. Rejected historical observation: the `reconcile-converge`, `serial-on-delete`, and
   `job-terminal-retention` Cabal suites were recorded green on the linux-cpu `kind` corpus.
   A non-instantaneous Deployment reaches rollout-complete only after its `initialDelaySeconds`; the serial second
   deletion follows replacement Bound+Ready; the terminal Job remains observed and charged with no completion/delete
   effect; and CR children conform. The immediate rerun is byte-stable and effect-free by independent observers.
   After that evidence is captured, the elevated test harness destroys the run-scoped scratch namespace and sweeps
   its records; this postflight is not represented as successful Job terminal cleanup and proves no persistence
   ordering claim.
2. The forbidden-symbol lint covers
   `src/Amoebius/Manifest/{Preflight,Reconcile,Diff,Actions,Authority,Apply,Enact,Delete,Wait}.hs` and
   `src/Amoebius/Execution/*.hs`; it rejects `threadDelay`, aliases, and clock-polling busy-waits as readiness gates.
   Every red-path Haskell case and changed-production-subject mutant above turns the suite red.
3. Two simultaneous CR child creates cannot race past namespace quota, and both leave zero over-allocation. A
   compile/decode negative proves two owner envelopes cannot share one `ControllerEnvelopeNamespace`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The receipt and the live/mutation results are written into this run's bundle under `.build/runs/`. The
content-addressed completion gateway and the rollback/release ledger stay deferred to the content-store phase
and are carried UNVERIFIED, never green.

## Sprint 58.5: Register-2.5 reconciler + staged-execution convergence under simulated faults ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 58.4
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits):
validate the *built* reconciler and staged-action schedules under injected faults **in-process and deterministically replayable**, at Register 2.5 — one rung below the Register-3 live gate in the register ladder,
not chronologically ahead of it — closing the code-schedule gap the pure-value tests and the live gate each leave
open. The scheduler's CAS-race schedules are Phase 59's `SchedulerSim`.

### Deliverables

- The real action loop under `IOSimPOR`, with ≥200 schedules per fault class (or exhaustive stated preemption
  depth) and `cover`/`classify` proving faults land inside `Lease` acquire/renew, SSA, serial, host/device release,
  completion/cleanup, delete, and wait sections rather than only between iterations.
- Safety invariants on every trace: at most one observed `Lease` holder and no non-authority write without the exact
  holder; no next serial delete before replacement Bound+Ready; no host start before its resource-indexed release;
  no terminal cleanup before durable completion/deadline; no delete from label alone; and unchanged snapshot tokens
  cannot be reused after any observed-state transition.
- Haskell changed-subject mutants for lost `Lease`/resourceVersion retry, mutation without holder, sleep-gated readiness, serial
  stage collapse, completion cleanup-before-persist, label-only delete, and cached observation. Every mutant must
  turn red. (The scheduler-race mutants — bind-before-CAS, same-UID double debit, crash recovery dropping Bound,
  collapsed scheduler readiness stages, premature managed taint/full RBAC — are Phase 59's `SchedulerSim`.)
- A Register-2.5 proven/tested/assumed ledger — the reconciler upholds convergence + fail-closed under the modeled
  schedules and faults; honest limit: modeled-apiserver fidelity is **assumed**, discharged by the Sprint-43.4
  Register-3 live gate.

### Validation

1. Rejected historical observation: the `reconcile-sim` and `execution-transition-sim` Cabal suites were
   recorded green at the documented exploration bound. The historical coverage claim said
   every fault enters its critical section; every safety invariant holds; every Haskell mutant is caught; and each
   discovered counterexample replays identically under its seed.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The Register-2.5 receipt and its seven-mutant ledger are written into this run's bundle under
`.build/runs/`; modeled-apiserver fidelity remains assumed, as the register boundary requires, and the same run's
Register-3 half supplies the live boundary evidence that bounds it.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/manifest_generation_doctrine.md` — §5's typed SSA/staged-action/delete/wait engine flips
  from design intent to delivered with the Register-3 ledger attached (the scheduler CAS/Binding half of §5 stays
  design intent until Phase 59); §6's planned-vs-observed and `renderAll` model gains its first validation. Keep
  §6.1's content-addressed release ledger and §5's rollback explicitly as the deferred content-store-phase residue.
- `documents/engineering/readiness_ordering_doctrine.md` — the §6 runtime-enactor claim (observe, never sleep) gains
  its first amoebius proof.
- `documents/engineering/daemon_topology_doctrine.md` — record that Phase 58 drives the reconciler from the host
  binary; the §3 control-plane daemon that *owns* it (Deployment `replicas=1`, delegated single-instance, no election) is stood
  up in Phase 65.
- `documents/engineering/generated_artifacts_doctrine.md` — note that the applied `[K8sObject]` set is generated lazily beneath `.build/**` at apply time and is absent from the repository. - `documents/engineering/resource_capacity_doctrine.md` — record the read-only pre-mutation live inventory cross-check and its zero-write failure path. - `documents/engineering/deterministic_simulation_doctrine.md` — add the Phase-58 Register-2.5 status backlink for the Sprint-43.5 reconciler/execution fault battery.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-58 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 58's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register the Phase-58
  `Manifest/{Preflight,Reconcile,Diff,Actions,Authority,Apply,Enact,Delete,Wait}`,
  `Execution/{Observe,Normalize,RuntimeStorage,SerialOnDelete,HostTransition,AcceleratorRelease,JobTerminal}`, and
  `Storage/{ScalingAction,ScalingDispatch}` modules plus their live/simulation suites. (The `Scheduler/*` and
  `Admission/ExecutionIdentity` modules are registered by Phase 58.)

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the Register-3 acceptance token: *converges and re-run is a no-op*, externally observed live)
- [overview.md](overview.md) — target architecture and the no-Helm / no-release-store reconciler posture
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — [§5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) the apply/reconcile
  engine adopted here; [§6](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed) the reconcile state model; [§2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) the pure renderer consumed from Phase 33
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — [§6](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps) the runtime enactor
  (observe, never sleep) the wait-for-ready realizes
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — [§8](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime) the pre-mutation live
  inventory cross-check
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — [§3](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) the Deployment-`replicas=1`
  control-plane daemon (delegated single-instance, no election) that will own this reconciler in Phase 65
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — [§3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure) the invariant that
  rendering never touches live infrastructure; apply is the first live step
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the applied object
  set is generated lazily beneath `.build/**` and is absent from the repository
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — [§4](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits) the
  Register-2.5 io-sim environment the reconciler is validated against in Sprint 58.5, before the Register-3 live gate
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 3 (live), [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_33_render_manifest_oracles.md](phase_33_render_manifest_oracles.md) — the pure per-projection renderers and
  deployment-global Haskell `renderAll` owner-union expectations this phase enacts
- [phase_34_chain_kernel_boundary.md](phase_34_chain_kernel_boundary.md) — the Register-2 fake-apply this phase
  replaces with real tools, and the `io-classes` seams Sprint 58.5 drives
- [phase_16_deterministic_sim_substrate.md](phase_16_deterministic_sim_substrate.md) — the `IOSimPOR`
  deterministic-simulation substrate Sprint 58.5 runs on
- [phase_55_bootstrap_coordinator_kind.md](phase_55_bootstrap_coordinator_kind.md) — the live single-node `kind` cluster this
  phase applies to
- [phase_56_base_image_registry.md](phase_56_base_image_registry.md) — the in-cluster registry the applied workloads
  resolve images against
- [phase_59_capacity_scheduler.md](phase_59_capacity_scheduler.md) — the `amoebius-capacity` scheduler, two-stage
  bootstrap cutover, and execution-identity admission layered on this reconciler
- [phase_60_retained_storage.md](phase_60_retained_storage.md) — the retained-carve and verified-migration
  storage-scaling enactors this phase's dispatch boundary calls into
- [phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md) — the Deployment-`replicas=1` control-plane daemon that stands
  the reconciler up in-cluster and receives the `Lease` by observed handoff
- [phase_69_content_store_workflow.md](phase_69_content_store_workflow.md) — the first live gateway write → readback →
  deadline → terminal cleanup trace for the Job terminal protocol modeled here
