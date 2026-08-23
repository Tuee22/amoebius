# Phase 59: amoebius-capacity scheduler + bootstrap cutover

> **Purpose**: Build the same-binary `amoebius-capacity` scheduler as a dedicated role layered on the
> Phase-58 reconciler — the state-indexed reservation ledger, the two-stage bootstrap taint/RBAC cutover
> (`BootstrapCapacitySchedulerReady` → controller cutover → `ManagedCapacityReady`), execution-identity
> admission, and the CAS `Reserved` → `BindingInFlight` → submit/confirm Kubernetes Binding → `Bound`
> protocol — targeted for live testing by binding a pinned Pending guarded-Pod set with no double-bind and
> rejecting any guarded workload before `ManagedCapacityReady`.
> **Read this if**: a later phase depends on the future capacity-scheduler gate or its evidence.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/deterministic_simulation_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 59.1: State-indexed reservation ledger + normalization + absent-Pod recovery arms ⏸️](#sprint-591-state-indexed-reservation-ledger--normalization--absent-pod-recovery-arms-)
- [Sprint 59.2: Scheduler bootstrap authority + two-stage taint/RBAC cutover + readiness witnesses ⏸️](#sprint-592-scheduler-bootstrap-authority--two-stage-taintrbac-cutover--readiness-witnesses-)
- [Sprint 59.3: Scheduler loop + `Reserved`→`BindingInFlight`→Binding→`Bound` CAS + placement + recovery ⏸️](#sprint-593-scheduler-loop--reservedbindinginflightbindingbound-cas--placement--recovery-)
- [Sprint 59.4: Live scheduler binding + bootstrap→steady cutover gate ⏸️](#sprint-594-live-scheduler-binding--bootstrapsteady-cutover-gate-)
- [Sprint 59.5: Register-2.5 scheduler convergence under simulated faults ⏸️](#sprint-595-register-25-scheduler-convergence-under-simulated-faults-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 58, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target is the `amoebius-capacity` scheduler. It must be **the same amoebius Haskell binary holding the `CapacityScheduler` arm of `InClusterRole`** ([daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)) — a decoded value on the pod's frame config, not a scheduler-framework plugin, not a second implementation, and not a second executable. `CapacitySchedulerSystemDemand`
makes its image, complete Pod envelope, config, RBAC, readiness, identity admission, managed-node taint
policy, reservation CRD/records, API/etcd bytes, and CAS churn explicit, so the scheduler's own cost
participates in the same identity-aware fold it enforces on every other Pod.

The scheduler owns the **state-indexed reservation ledger**. On top of Phase 58's `ObservedLiveResourceSnapshot`
— which, before this phase, carries an empty scheduler-ledger arm because the corpus Pods are default-scheduled
and no reservation CRD exists — this phase's target must add the join over the full
`Reserved | BindingInFlight | Bound | Terminating | TerminalRetained` records and their resourceVersion/CAS
version. Normalization charges `PendingUnscheduled` as API-only, `Reserved` and `BindingInFlight` Pod+ledger
once, `Bound`/`Terminating` as one exact-joined vector, `Terminal` retained axes only, and each host
reservation once. An absent Pod never makes a ledger debit disappear: the closed `LedgerOnlyAbsentRecovery`
arms retain the exact full or terminal-retained debit for `Reserved`, `BindingInFlight`, `Bound`,
`Terminating`, or `TerminalRetained` until that state's release/cleanup evidence and whole-root CAS succeed. A
`BindingInFlight` row with unknown/unbound outcome remains planned-only, but an exact-node `ConfirmedBound
PodUid` recovery observation immediately instantiates the observed Pod-UID runtime-storage row and joins it
with the reservation as one debit even before the repair CAS reaches `Bound`. Unclassified orphan, missing,
wrong-state, wrong-node, wrong-generation, wrong-template, unequal-axis, or duplicate ledger joins, and any
observed+ledger double debit, fail closed and have no `ValidatedLiveTarget` constructor. The
`PlannedExecutionSlotId` is a pure capacity slot and is never equated with a future Pod UID; the observed
`ObservedExecutionSet` keys on `KubernetesPod PodUid | HostProcess HostProcessInstanceId |
HostReservation HostReservationId`, and the ledger-only third arm cannot masquerade as a running process or be
omitted from residual capacity.

Bootstrap is deliberately **two-stage**. Its single pinned bootstrap Pod uses the **default scheduler**, a
unique-node affinity, the exact `amoebius-capacity-scheduler` namespace `ResourceQuota pods=1`, the Phase-56
side-loaded/preloaded amoebius image (so it does not depend on the registry controller it must cut over), and
a static reservation that participates in the same identity-aware fold. Exact scheduler generation/config/root
readback first mints `BootstrapCapacitySchedulerReady` **while the managed taint is absent**; its restricted
capability can only patch the finite observed distro/Phase-56 bootstrap-controller set to
`schedulerName=amoebius-capacity`. After every old default-scheduled UID is absent/released and every
replacement UID is reservation-joined and Ready, bootstrap installs the managed-node taint, general identity
admission, and exclusive Binding RBAC, revokes the cutover-only authority, and **independently** mints
`ManagedCapacityReady`. Only that full witness admits general guarded controllers under
`AfterManagedCapacityReady`. The scheduler Pod is then the sole cycle-break/default-scheduler exception, and
every other Pod tolerating the managed-capacity taint must name `amoebius-capacity`.

For a Pending guarded Pod, the scheduler authenticates Pod UID, provenance, the kind-indexed owner chain,
prior/desired source generation, child discriminator, and template digest; re-folds the static/foreign/
resident/whole-root/candidate resource algebra (over Phase 9's `place` fold) under one aggregate CAS;
CAS-creates `Reserved`; CASes `Reserved → BindingInFlight`; **only then** submits Kubernetes Binding; and
confirms exact UID/node before CAS to `Bound`. Same-UID identical retry reuses an identical record; only
`Reserved` may retarget; any generation/child/node/axis/model/backing mismatch rejects. Recovery is
state-sensitive: after crash/restart it re-reads Pods and the aggregate root, reuses exact reservations, and
keeps `BindingInFlight` charged; `ConfirmedBound` repairs to `Bound`, `ConfirmedUnboundSameUidAndResourceVersion`
or `PodAbsent` may release, and `Unknown` retries observation and never unreserves on an error/timeout.
Bound/Terminating records are never deleted merely because the scheduler restarted. Identity admission requires
the deployment/generation/source/revision/reservation-template annotations and `amoebius-capacity` at CREATE,
rejects their removal/change at UPDATE, validates the owner chain, and restricts writers to the provisioned
controllers/scheduler; the sole default-scheduler bootstrap exception is structurally separate.

This phase does **not** rebuild the reconciler's generic SSA, staged execution (serial OnDelete, host/
accelerator transitions), Job terminal protocol, authenticated deletion, or the object convergence gate —
those are Phase 58's and are consumed here as the substrate the scheduler runs on. It owns only the scheduling
authority. The scheduler is driven from the **host binary** against the same scratch namespace as Phase 58; the
Deployment-`replicas=1` in-cluster control-plane daemon that eventually *owns* both the reconciler and its scheduling role
arrives in Phase 65.

**Phase scope:** one cohesive claim — *a reservation is a state-indexed ledger entry, and the cutover to it is two-staged so the cluster is never unscheduled*. Execution identity is admitted, never assumed.

**Substrate:** `linux-cpu` — this gate selects the universal Linux CPU lane, which is always available on
every hardware substrate. A pristine Linux host uses Incus on native Linux or Linux-CUDA, Lima on Apple,
and WSL2 on Windows. This execution uses Phase 55's single-node `kind` cluster and the Phase-58 reconciler.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 58](phase_58_object_reconciler.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 59`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *a reservation is a state-indexed ledger entry, and the cutover to it is two-staged so the cluster is never unscheduled*. Execution identity is admitted, never assumed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 59` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 58 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

`CapacitySchedulerSystemDemand` is the scheduler's own explicit, pure-first provision, fitted by the Phase-9
`place` fold before any effect, so the scheduler is never silently free overhead:
- **Image** — the Phase-56 side-loaded/preloaded native-architecture amoebius base image (never a public-registry pull),
  so the scheduler does not depend on the registry controller it must cut over.
- **Pod envelope** — the complete pinned bootstrap Pod: non-zero CPU/memory request+limit, explicit logical
  `ephemeral-storage`, no declared compute headroom (the scheduler sizes its own row exactly and has no growth,
  burst, isolation, or defragmentation claim on the node it bootstraps), unique-node affinity, and
  `restartPolicy`/probe fields; its single Pod uses the
  **default scheduler** (the sole structural exception) and a static reservation row merged into the same
  identity-aware fold (equal shared image extents deduplicate, compute/slots add).
- **Namespace/quota** — the `amoebius-capacity-scheduler` namespace and its exact `ResourceQuota pods=1`.
- **Reservation state** — the reservation CRD, config, and aggregate root; the canonical reservation
  serializer derives entry bytes, and `maxEntries` derives from the **maximum normalized Pod-UID population including retained terminal records**, never an authored scalar. The three compute-headroom pad scalars are
  part of the canonically pinned compute-axis field set, so they enlarge the derived entry bytes and therefore
  the `maxEntries` and `EtcdChurnBudget` provisions; they are not an optional tail a serializer may omit for
  rows whose pad is `Zero`.
- **RBAC/admission** — the restricted cutover-only RBAC first, then the full exclusive-Binding RBAC, the
  general identity-admission webhook, and the managed-node taint policy installed only at cutover.
- **API/etcd** — the serialized API objects, etcd logical bytes, and the `EtcdChurnBudget` CAS-churn
  projection reserved per attempt until a post-attempt observation commits or releases the debit.
- **Readiness** — the two distinct witnesses `BootstrapCapacitySchedulerReady` and `ManagedCapacityReady`.

## Doctrine adopted

- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes amoebius-capacity scheduler + bootstrap cutover causes to exist are charged to a grant that carries its ceiling and concurrency together.
- [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  — **the apply/reconcile engine** (the scheduler slice). This phase realizes the amoebius scheduler-role
  CAS/Binding protocol (`Reserved` → `BindingInFlight` → submit/confirm Binding → `Bound`), the two-stage
  bootstrap taint/RBAC cutover, and execution-identity admission. Generic SSA, staged execution, Job terminal,
  authenticated deletion, and the rollback/release ledger are Phase 58's or stay deferred.
- [`manifest_generation_doctrine.md` §6 — The reconcile state model: desired is `renderAll(ProvisionedSpec)`, observed is live inventory, actions are typed](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
  — **desired is the validated identity index of `renderAll(provisionedSpec)`, observed is live inventory, and actions are typed** (the scheduler-ledger slice). The state-indexed
  `Reserved | BindingInFlight | Bound | Terminating | TerminalRetained` records, their CAS version, and the
  `LedgerOnlyAbsentRecovery` arms are **observed** to authorize reservation transitions, never treated as
  another desired source; a `PlannedExecutionSlotId` is never a Pod UID.
- [`resource_capacity_doctrine.md` §8 — Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)
  — **declared at decode, cross-checked at runtime.** Before each reservation CAS the scheduler re-folds the
  static/foreign/resident/whole-ledger/candidate resource algebra over the Phase-9 `place` fold and re-observes
  residual capacity; two concurrent candidates cannot reserve the same residual, and a stale or false witness
  is refused with zero writes.
- [`readiness_ordering_doctrine.md` §6 — The runtime enactor: the reconciler observes, never sleeps](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
  — **the runtime enactor: observe, never sleep.** `BootstrapCapacitySchedulerReady`, the bootstrap-controller
  cutover, `ManagedCapacityReady`, and reservation `Bound`+Ready are read from live sources; no `threadDelay`
  substitutes for a scheduler-readiness witness.
- [`daemon_topology_doctrine.md` §3 — The control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon)
  — **the control-plane daemon.** The scheduler is a dedicated role of the same amoebius binary/image, not
  a second implementation; this phase targets a **host-binary** precursor, while the Deployment-`replicas=1`
  control-plane daemon that later owns it (single-writer authority delegated to k8s/etcd through the mandatory
  `Lease`, no bespoke election) is a Phase-65 target. Phase 59 cannot consume that later daemon.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  — **Register 3** (live infrastructure): the register this phase's gate reaches; and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  the per-run proven/tested/assumed ledger the live cutover/binding emits (no skips, fail fast; the scratch
  namespace is torn down leak-free).

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.

## Sprint 59.1: State-indexed reservation ledger + normalization + absent-Pod recovery arms ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
— the reconcile state model, scheduler-ledger slice. Extend Phase 58's observed inventory with the
state-indexed reservation ledger and its resourceVersion/CAS version, normalize every reservation state
exactly once, and classify the closed absent-Pod recovery arms — so no observed Pod plus ledger row is
double-debited, no absent Pod makes a debit disappear, and no unclassified record reaches a
`ValidatedLiveTarget` constructor.

### Deliverables

- A scheduler-ledger join over full `Reserved | BindingInFlight | Bound | Terminating | TerminalRetained`
  records plus resourceVersion/CAS version, added to Phase 58's `ObservedLiveResourceSnapshot` (empty before
  this phase because the corpus is default-scheduled and no reservation CRD exists). Normalize `PendingUnscheduled`
  API-only, `Reserved`/`BindingInFlight` Pod+ledger once, joined `Bound`/`Terminating` as one exact vector,
  `Terminal` retained axes only, and each host reservation once. Missing, unclassified-orphan, wrong-state,
  wrong-node, wrong-generation, wrong-template, unequal-axis, duplicate, and observed+ledger double-debit joins
  have **no** constructor.
- The closed `LedgerOnlyAbsentRecovery` arms: an absent Pod retains the exact full or terminal-retained debit
  for `Reserved`, `BindingInFlight`, `Bound`, `Terminating`, or `TerminalRetained` until that state's
  release/cleanup evidence and whole-root CAS succeed. The retained debit is the **padded** debit: a row that
  surrendered its declared headroom while retaining its requests would let a second workload pack into space
  the first still holds. Positive Haskell recovery cases cover an absent-Pod row in
  every closed ledger state and prove each remains charged until its state-specific CAS.
  The unequal-axis rejection above is correspondingly pad-sensitive — a row whose pad axes disagree with its
  template's fails to construct, exactly as a mismatched request or limit debit does.
- The host-aware observed identity union consumed from Phase 58 —
  `KubernetesPod PodUid | HostProcess HostProcessInstanceId | HostReservation HostReservationId` — with its
  ledger-only third arm: host `Reserved`, no-process `LaunchInFlight`, and post-process retained-artifact rows
  remain charged under `HostReservation HostReservationId`; process-observed `LaunchInFlight` enters
  `HostLaunchRecovery`; Running/Draining exact-join the process and reservation once. Missing, duplicate, or
  process-fabricated ledger-only identities reject.
- State-sensitive Binding recovery at normalization time: an unknown/unbound `BindingInFlight` row remains
  planned-only, while an exact-node `ConfirmedBound PodUid` observation immediately derives the observed
  Pod-UID runtime-storage row (from Phase 58's `RuntimeStorage`) and exact-joins it once with the
  still-`BindingInFlight` reservation — the later repair CAS (Sprint 59.3) changes state, not capacity.
- The scheduler-ledger slice of the `ValidatedLiveTarget`: the ledger CAS version, the normalized
  reservation/host-reservation witnesses, and the reservation transition sub-domain of the typed action map,
  handed to Phase 58's target constructor. `PlannedExecutionSlotId` is never equated with a Pod UID; every
  same-slot predecessor/replacement UID is preserved as two distinct commitments.

### Validation

1. The normalized ledger for the Haskell-authored corpus equals the separately authored Haskell expected
   scheduler-state slice. Haskell changed-production-subject mutants — unclassified-orphan record, missing reservation, wrong
   state/node/template/generation/axes, a `Bound` Pod plus ledger double debit, reservation-only omission, and
   an incorrect terminal released/retained partition — each fail to construct a `ValidatedLiveTarget`.
2. Positive Haskell recovery cases cover absent-Pod rows in **every** closed ledger state and prove each remains
   charged until its state-specific CAS. The host-ledger controls reuse the Phase-58 failure classes: missing
   reservation/artifact identities, fabricated process evidence, and post-join double charging. Exact-fit
   controls debit each identity once.
3. A confirmed-bound-but-still-`BindingInFlight` Haskell case must use the observed Pod-UID runtime row; the
   planned-only omission and the planned+observed double-debit Haskell changed-subject mutants both turn red.
   The Haskell `same-UID-double-debit` changed-subject mutant is caught at normalization by the separately authored Haskell
   "every UID debited once" expectation.
4. The module imports no writer; the AST/import lint proves `Scheduler/Ledger.hs` is read-only, and a runtime
   observer proves zero apiserver/ledger/Binding writes on every negative.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The receipt and phase results are written into this run's bundle under `.build/runs/`.

## Sprint 59.2: Scheduler bootstrap authority + two-stage taint/RBAC cutover + readiness witnesses ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
(the apply/reconcile engine) and
[`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
(observe, never sleep). Stand up the scheduler from `CapacitySchedulerSystemDemand` under a scheduler-system-
only token, then drive the deliberately two-stage cutover: mint `BootstrapCapacitySchedulerReady` while the
managed taint is absent, cut the finite bootstrap-controller set over to `amoebius-capacity`, and only after
complete old-UID release and replacement joins install the managed taint/admission/full Binding RBAC and
independently mint `ManagedCapacityReady`.

### Deliverables

- A read-only scheduler preflight (layered on the Phase-58 reconciler already holding
  `ProvisionedMandatoryReconcilerLease`) that admits only the statically debited `CapacitySchedulerSystemDemand`
  and mints a **scheduler-system-only** token. That token creates the `amoebius-capacity-scheduler` namespace,
  the exact `ResourceQuota pods=1`, the reservation CRD/config/root, the complete pinned scheduler Deployment,
  and RBAC **restricted to the enumerated bootstrap add-on cutover**. Its sole Pod is default-scheduled, uses
  the Phase-56 side-loaded/preloaded amoebius image, has unique-node affinity, and merges its static owner row
  with the ledger fold (equal shared image extents deduplicate, compute/slots add). These are the only
  `BootstrapSchedulerStage` actions.
- `BootstrapCapacitySchedulerReady`: exact active generation/config/root readback mints it **while the managed taint, general identity admission, and full Binding authority remain absent**. Its restricted capability can
  only patch the exact observed distro/Phase-56 bootstrap-controller set to `schedulerName=amoebius-capacity`.
- The bootstrap-controller cutover under `AfterBootstrapAddonCutover`: for every controller, re-observe the old
  default-scheduled UID absent and resource-indexed released, then the replacement UID reservation-joined,
  Bound, and Ready. Only the **complete domain-equality witness** authorizes installing the managed-node taint,
  general identity admission, and full exclusive Binding RBAC and revoking the cutover-only authority. An
  **independent** taint/admission/RBAC/writer-domain readback mints `ManagedCapacityReady`; the bootstrap
  snapshot is discarded and a fresh whole-deployment preflight runs before any general guarded action is
  exposed.
- Execution-identity admission install (`Admission/ExecutionIdentity.hs`): at cutover, the general identity
  admission requires the deployment/generation/source/revision/reservation-template annotations and
  `amoebius-capacity` at CREATE, rejects their removal/change at UPDATE, validates the kind-indexed owner chain,
  and restricts writers to the provisioned controllers/scheduler. The sole default-scheduler bootstrap
  exception is structurally separate; any **other** default-scheduled Pod that tolerates the managed-capacity
  taint is rejected.
- Wait-for-state, observed never slept: `BootstrapSchedulerStage` yields `BootstrapCapacitySchedulerReady` and
  precedes only finite bootstrap-controller patch actions; old-UID absence/release plus replacement
  reservation/Ready equality precedes the managed taint/admission/full-Binding RBAC under
  `AfterBootstrapAddonCutover`; and `ManagedCapacityReady` unlocks `AfterManagedCapacityReady` general guarded
  controller actions. No `threadDelay` substitutes for a witness.

### Validation

1. The bootstrap suite covers scheduler-ready-with-managed-taint-present, a general action attempted from only
   `BootstrapCapacitySchedulerReady`, an omitted bootstrap controller, an old UID still present, a missing
   replacement reservation, a premature taint/admission/full-RBAC install, and a second default-scheduler
   exception; **every case refuses** with zero writes.
2. The `collapsed-readiness` mutant (readiness ignoring the config digest or collapsing the two witnesses), the
   `stage-drop-generic-SSA-before-cutover` mutant (rendered taint/admission objects generic-SSA-applied before
   add-on equality), and the `default-scheduler-managed-node-bypass` mutant all turn red.
3. `ceil(renewalWindow/retryPeriod) <= maxRenewalsPerWindow` is not re-proven here (the `Lease` is Phase 58's),
   but the scheduler preflight asserts it runs **only** while the Phase-58 reconciler is the exact `Lease`
   holder; an attempt to stand up the scheduler without that holder refuses.
4. The forbidden-symbol lint over `src/Amoebius/Scheduler/Readiness.hs` and the scheduler slice of
   `Manifest/Authority.hs` and `Admission/ExecutionIdentity.hs` rejects `threadDelay`, aliases, and
   clock-polling busy-waits as readiness gates.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The receipt and mutation results are written into this run's bundle under `.build/runs/`.

## Sprint 59.3: Scheduler loop + `Reserved`→`BindingInFlight`→Binding→`Bound` CAS + placement + recovery ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
(the apply/reconcile engine) and
[`resource_capacity_doctrine.md §8`](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)
(cross-checked at runtime). Build the scheduler loop that authenticates a guarded Pod, re-folds the resource
algebra, reserves by aggregate CAS, and only then binds — with idempotent recovery across crash/restart/Binding
failure — so a Pod is never bound before its reservation CAS and never double-debited.

### Deliverables

- The scheduler loop for `schedulerName=amoebius-capacity` (`Scheduler/Loop.hs`): authenticate Pod UID,
  protected annotations, the kind-indexed owner chain, exact prior/desired source generation, child
  discriminator, and template digest (`Admission/ExecutionIdentity.hs` authentication path); re-fold the
  static/foreign/resident + whole-root + candidate resource algebra (`Scheduler/Placement.hs` over the Phase-9
  `place` fold); CAS-create `Reserved` (`Scheduler/Reservation.hs`); CAS `Reserved → BindingInFlight`; submit
  Kubernetes Binding (`Scheduler/Binding.hs`); confirm exact UID/node and CAS to `Bound`. Same-UID identical
  retry is idempotent; only `Reserved` can retarget; any generation/child/node/axis/model/backing mismatch
  rejects.
- Aggregate-CAS placement: two concurrent candidates cannot reserve the same residual because placement
  re-folds the **whole** reservation ledger under one aggregate root CAS rather than a numeric add. The
  `numeric-add-instead-of-whole-ledger-refold` mutant is caught by the two-candidate residual race.
- Recovery (`Scheduler/Recovery.hs`): after crash/restart, re-read Pods and the aggregate root, reuse exact
  reservations, and keep `BindingInFlight` charged. `ConfirmedBound` repairs to `Bound`;
  `ConfirmedUnboundSameUidAndResourceVersion` or `PodAbsent` may release; `Unknown` retries observation and
  **never** unreserves on an error/timeout. `Bound`/`Terminating` records are never deleted merely because the
  scheduler restarted; terminal/GC release retains the exact witnessed axes.
- Each reservation attempt consumes its fresh observation-bound token and reserves its exact `EtcdChurnBudget`
  projection until a post-attempt observation commits or releases that debit; a timeout, lost response, or
  unknown outcome remains charged and re-observes rather than reusing a token.
- The reservation transitions are the scheduler's members of Phase 58's `ValidatedExecutionTransitionAction`
  domain; the scheduler never enters Phase 58's generic scoped-SSA path (`fieldManager=amoebius`), and every
  mutating reservation/Binding constructor carries only its dedicated scoped capability and can never be minted
  for a non-holder.

### Validation

1. Live scheduler tests cover config-not-Ready and digest-mismatch refusal, managed-taint bypass, invalid
   provenance/owner chain, a two-candidate CAS race, same-UID retry, unbound retarget, wrong-RV conflict,
   crash-after-reserve/restart, Binding failure, crash-after-Binding-before-`Bound`-CAS, and state mismatch. The
   external observer proves **no Binding precedes a successful reservation CAS** and every UID is debited once.
2. The seeded mutants `bind-before-reservation-CAS`, `numeric-add-instead-of-whole-ledger-refold`,
   `same-UID-double-debit`, and `bound-deleted-on-restart` all turn red. Readiness that ignores the config
   digest or collapses the two witnesses (from Sprint 59.2) also turns the reservation suite red when it lets a
   guarded Pod through prematurely.
3. Crash/watch-gap injection at each edge (post-reserve, post-Binding-pre-CAS, restart) re-observes and
   converges without a duplicate debit or an unguarded scheduling interval.
4. The scheduler modules import no generic SSA writer; the lint asserts scheduler/ledger/Binding actions never
   enter Phase 58's `Manifest/Apply.hs` scoped-SSA module, and `NoOp` carries no writer capability.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The receipt and mutation results are written into this run's bundle under `.build/runs/`.

## Sprint 59.4: Live scheduler binding + bootstrap→steady cutover gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
and [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
prove the whole scheduling authority live on `linux-cpu` — the two-stage bootstrap cutover in order, exclusive
CAS binding of the pinned Pending guarded-Pod set with no double-bind, rejection of a premature guarded
workload, and an idempotent re-run — and emit a Register-3 proven/tested/assumed ledger, tearing the scratch
namespace down leak-free.

### Deliverables

- The live cutover sequence over the pinned corpus: stand up `CapacitySchedulerSystemDemand` → observe
  `BootstrapCapacitySchedulerReady` (managed taint absent) → patch the finite bootstrap-controller set to
  `amoebius-capacity` → observe every old default-scheduled UID absent/released and every replacement
  reservation-joined, Bound, and Ready → install the managed taint/admission/full Binding RBAC → observe the
  independent readback and mint `ManagedCapacityReady` — **in that order**, before the first guarded Pod.
- Live exclusive binding of the guarded Deployment's Pending Pod: authenticate → CAS `Reserved` → CAS
  `BindingInFlight` → submit/confirm Kubernetes Binding → CAS `Bound` → observe Bound+Ready. Independent
  readers assert no Binding precedes a successful reservation CAS, every guarded Pod UID is debited exactly
  once, and no double-bind survives the bootstrap→steady cutover.
- The premature-guarded-workload rejection: a guarded workload submitted before `ManagedCapacityReady` is
  rejected at admission; independent observers show zero writes (no reservation record, no Binding, no owned
  object resourceVersion change), and the paired positive is admitted only after the full witness.
- The idempotent re-run: an immediate re-run of the same spec plans only scheduler no-ops; the external
  apiserver + reservation-CRD observer asserts byte-identical reservation records and CAS version, **no new Binding request**, the same mandatory-`Lease` holder/resourceVersion, and no second default-scheduler
  exception.
- The Haskell-authored red-path suite: the mutants `bind-before-reservation-CAS`, `numeric-add-instead-of-whole-ledger-refold`,
  `same-UID-double-debit`, `bound-deleted-on-restart`, `default-scheduler-managed-node-bypass`,
  `collapsed-readiness`, and `stage-drop-generic-SSA-before-cutover` MUST turn the suite red; the
  Haskell premature-guarded-workload negative case MUST be rejected at admission.
- A Register-3 proven/tested/assumed ledger recording the live scheduling authority, marking the
  release-ledger/rollback residue and the in-cluster-control-plane ownership (Phase 65) UNVERIFIED (deferred).

### Validation

1. Rejected historical observation: the `scheduler-reservation` and `scheduler-bootstrap-cutover` Cabal suites
   were recorded green on the linux-cpu `kind` corpus.
   `BootstrapCapacitySchedulerReady`, complete controller cutover, and `ManagedCapacityReady` occur in order
   before the first guarded Pod; every Binding follows a successful reservation CAS; the guarded Deployment
   reaches Bound+Ready; the premature guarded workload is rejected with zero writes; and the immediate re-run is
   byte-stable and Binding-free by the independent observer.
2. Every Haskell scheduler mutant above turns the suite red and is re-run, not run once. The external observer —
   not the scheduler — is the passing condition for "reserved once / bound once / no-op re-run".
3. Two simultaneous scheduler candidates cannot race past the ledger residual; both leave zero over-allocation.
   Crash/watch-gap injection at each cutover and reservation edge re-observes and converges without a duplicate
   debit or an unguarded scheduling interval.
4. After the evidence is captured, the elevated harness destroys the run-scoped scratch namespace and sweeps
   its reservation records leak-free; this postflight is not represented as a successful convergence claim and
   proves no persistence ordering.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Live evidence, receipt, and repeated mutation results are under
this run's bundle under `.build/runs/`.

## Sprint 59.5: Register-2.5 scheduler convergence under simulated faults ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits):
exercise the *built* scheduler under replayable in-process fault schedules at Register 2.5. This register sits
below, rather than earlier in time than, Sprint 59.4's live Register-3 gate and covers concurrency behavior that
neither pure-value checks nor the live sample exhausts.

### Deliverables

- The real scheduler loop under `IOSimPOR`, with ≥200 schedules per fault class (or an exhaustive stated
  preemption depth) and `cover`/`classify` proving faults land **inside** the bootstrap-scheduler-readiness,
  add-on-cutover/full-authority transition, reservation-CAS, and Binding critical sections rather than only
  between iterations.
- Safety invariants on every trace: no general guarded action from `BootstrapCapacitySchedulerReady`; no full
  authority before complete old-UID release/replacement joins; **one reservation debit per Pod UID**; **no Binding before a successful CAS**; no `Bound` record unreserved on restart; no non-authority write without the
  exact mandatory-`Lease` holder; and unchanged snapshot tokens cannot be reused after any observed-state
  transition.
- Haskell changed-subject mutants for lost-`Lease`/resourceVersion retry (against the reconciler holder the scheduler depends
  on), collapsed scheduler-readiness stages, premature managed taint/full RBAC, bind-before-CAS, same-UID double
  debit, crash recovery dropping `Bound`, and cached observation. Every mutant must turn red.
- A Register-2.5 ledger records convergence and fail-closed outcomes only for the explored scheduler traces.
  Fidelity of the simulated apiserver remains **assumed** and is bounded by Sprint 59.4's separate live
  Register-3 observations.

### Validation

1. Rejected historical observation: the `scheduler-sim` Cabal suite was recorded green at the documented
   exploration bound. The historical criterion required coverage to place each injected
   fault inside the intended critical section, preserve all safety predicates, kill every Haskell mutant, and
   deterministically replay any counterexample from its seed.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The 1,792-schedule summary, receipt, and mutation results are under
this run's bundle under `.build/runs/`.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/manifest_generation_doctrine.md` — §5's amoebius scheduler-role CAS/Binding protocol
  and two-stage bootstrap taint/RBAC cutover flip from design intent to delivered with the Register-3 ledger
  attached; §6's observed state-indexed scheduler ledger (`Reserved | BindingInFlight | Bound | Terminating |
  TerminalRetained` + `LedgerOnlyAbsentRecovery`) gains its first validation. The generic SSA/staged-action/
  delete/wait engine remains Phase 58's; the rollback/release ledger stays deferred.
- `documents/engineering/resource_capacity_doctrine.md` — record the scheduler's pre-reservation whole-ledger
  re-fold and its zero-write refusal on a stale/false witness.
- `documents/engineering/readiness_ordering_doctrine.md` — the §6 runtime-enactor claim (observe, never sleep)
  gains its scheduler-readiness proof (`BootstrapCapacitySchedulerReady`/`ManagedCapacityReady` observed, not
  slept).
- `documents/engineering/daemon_topology_doctrine.md` — record that Phase 59 drives the scheduler role from the
  host binary; the §3 control-plane daemon that *owns* both the reconciler and its scheduling role (Deployment
  `replicas=1`, delegated single-instance, no election) must be stood up by human-approved Phase 65.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the Phase-59 scheduler slice of the
  Register-2.5 io-sim battery (Sprint 59.5), with modeled-apiserver fidelity marked assumed.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-59 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 59's gate substrate (linux-cpu) in the per-phase substrate
  map.
- `DEVELOPMENT_PLAN/system_components.md` — register the Phase-59
  `Scheduler/{Ledger,Loop,Placement,Reservation,Recovery,Binding,Readiness}` and `Admission/ExecutionIdentity`
  modules (plus the scheduler-authority slice of `Manifest/Authority.hs`) and their live/simulation suites.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the Register-3 acceptance token: *the scheduler binds under an external CAS-ledger/Lease observer with no double-bind*, externally observed live)
- [overview.md](overview.md) — target architecture; the same-binary `amoebius-capacity` scheduler that
  authenticates a sealed prior+desired child template, re-folds the resource algebra under one aggregate CAS,
  then alone binds the Pod
- [phase_58_object_reconciler.md](phase_58_object_reconciler.md) — the object reconciler (observe → diff → scoped-SSA → staged-enact → delete → wait, and the `ValidatedLiveTarget` + mandatory `Lease`) this phase is
  layered on
- [phase_09_resource_index.md](phase_09_resource_index.md) — the `place`/`fits`/`carve` resource
  algebra the scheduler placement re-folds under aggregate CAS
- [phase_33_render_manifest_oracles.md](phase_33_render_manifest_oracles.md) — the Haskell `renderAll` expectation corpus
  the pinned reconcile corpus is a subset of
- [phase_55_bootstrap_coordinator_kind.md](phase_55_bootstrap_coordinator_kind.md) — the live single-node `kind`
  cluster this phase's scheduler binds on
- [phase_56_base_image_registry.md](phase_56_base_image_registry.md) — the in-cluster registry and the
  preloaded/side-loaded amoebius image the bootstrap scheduler Pod uses
- [phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md) — the Deployment-`replicas=1` control-plane daemon that
  stands the reconciler and its scheduling role up in-cluster
- [phase_34_chain_kernel_boundary.md](phase_34_chain_kernel_boundary.md) — the `io-classes` seams / modeled
  apiserver the Register-2.5 scheduler sim (Sprint 59.5) drives the real modules on
- [phase_16_deterministic_sim_substrate.md](phase_16_deterministic_sim_substrate.md) — the deterministic-
  simulation substrate the Register-2.5 scheduler battery runs in
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — [§5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) the apply/
  reconcile engine (scheduler CAS/Binding + bootstrap cutover slice); [§6](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed) the observed scheduler-ledger state
  model
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — [§8](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime) declared at decode,
  cross-checked at runtime (the scheduler's pre-reservation re-fold)
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — [§6](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps) the runtime
  enactor (observe, never sleep) the scheduler-readiness witnesses realize
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — [§3](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) the Deployment-
  `replicas=1` control-plane daemon that will own this scheduling role in Phase 65
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the
  Register-2.5 io-sim environment the scheduler is validated against in Sprint 59.5, before the Register-3 gate
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 3 (live), [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
