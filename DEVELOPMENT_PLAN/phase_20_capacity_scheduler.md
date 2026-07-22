# Phase 20: amoebius-capacity scheduler + bootstrap cutover

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_19_object_reconciler.md, DEVELOPMENT_PLAN/phase_37_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the same-binary `amoebius-capacity` scheduler as a dedicated role layered on the
> Phase-19 reconciler — the state-indexed reservation ledger, the two-stage bootstrap taint/RBAC cutover
> (`BootstrapCapacitySchedulerReady` → controller cutover → `ManagedCapacityReady`), execution-identity
> admission, and the CAS `Reserved` → `BindingInFlight` → submit/confirm Kubernetes Binding → `Bound`
> protocol — proven live by binding a pinned Pending guarded-Pod set with no double-bind and rejecting any
> guarded workload before `ManagedCapacityReady`.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the **Phase 19 gate** (the
object reconciler's `observe → diff → scoped-SSA → staged-enact → delete → wait` convergence, its
`ValidatedLiveTarget` construction, the cold-start mandatory-reconciler-`Lease` authority, and the IOSimPOR
object-fault battery) and runs on the **linux-cpu** substrate in **Register 3**. It is **layered on** that
live reconciler: Phase 19 converges the object corpus with its Pods scheduled by the default scheduler and
holds the mandatory reconciler `Lease`; this phase adds the *scheduling* authority — the reservation ledger,
the two-stage bootstrap cutover, execution-identity admission, and the CAS reservation/Binding protocol — that
turns the corpus's guarded Deployment from a default-scheduled workload into one bound exclusively by
`amoebius-capacity`. Where a sibling already schedules pods with a stock scheduler — prodbox lets kube-scheduler
place its control-plane pods — that is **sibling evidence, not an amoebius result**; the state-indexed
reservation ledger, the aggregate-CAS reservation protocol, the identity admission webhook, and the two-stage
`BootstrapCapacitySchedulerReady`/`ManagedCapacityReady` cutover are amoebius's new code.

## Phase Summary

This phase delivers the `amoebius-capacity` scheduler. It is **the same amoebius Haskell binary in a dedicated
role**, not a scheduler-framework plugin and not a second implementation. `CapacitySchedulerSystemDemand`
makes its image, complete Pod envelope, config, RBAC, readiness, identity admission, managed-node taint
policy, reservation CRD/records, API/etcd bytes, and CAS churn explicit, so the scheduler's own cost
participates in the same identity-aware fold it enforces on every other Pod.

The scheduler owns the **state-indexed reservation ledger**. On top of Phase 19's `ObservedLiveResourceSnapshot`
— which, before this phase, carries an empty scheduler-ledger arm because the corpus Pods are default-scheduled
and no reservation CRD exists — this phase adds the join over the full
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
unique-node affinity, the exact `amoebius-capacity-scheduler` namespace `ResourceQuota pods=1`, the Phase-18
side-loaded/preloaded amoebius image (so it does not depend on the registry controller it must cut over), and
a static reservation that participates in the same identity-aware fold. Exact scheduler generation/config/root
readback first mints `BootstrapCapacitySchedulerReady` **while the managed taint is absent**; its restricted
capability can only patch the finite observed distro/Phase-18 bootstrap-controller set to
`schedulerName=amoebius-capacity`. After every old default-scheduled UID is absent/released and every
replacement UID is reservation-joined and Ready, bootstrap installs the managed-node taint, general identity
admission, and exclusive Binding RBAC, revokes the cutover-only authority, and **independently** mints
`ManagedCapacityReady`. Only that full witness admits general guarded controllers under
`AfterManagedCapacityReady`. The scheduler Pod is then the sole cycle-break/default-scheduler exception, and
every other Pod tolerating the managed-capacity taint must name `amoebius-capacity`.

For a Pending guarded Pod, the scheduler authenticates Pod UID, provenance, the kind-indexed owner chain,
prior/desired source generation, child discriminator, and template digest; re-folds the static/foreign/
resident/whole-root/candidate resource algebra (over Phase 7's `place` fold) under one aggregate CAS;
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
those are Phase 19's and are consumed here as the substrate the scheduler runs on. It owns only the scheduling
authority. The scheduler is driven from the **host binary** against the same scratch namespace as Phase 19; the
Deployment-`replicas=1` in-cluster singleton that eventually *owns* both the reconciler and its scheduling role
arrives in Phase 26.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster on a linux-cpu host from
Phase 17, layered on the Phase-19 reconciler; no apple, linux-cuda, or windows substrate is touched.

**Register:** 3 — live infrastructure (§K).

**Gate:** in **Register 3** on the live single-node `kind` cluster, layered on the converged Phase-19
reconciler holding the mandatory reconciler `Lease`: the `amoebius-capacity` scheduler stands up from
`CapacitySchedulerSystemDemand`, mints `BootstrapCapacitySchedulerReady` (managed taint absent), cuts the
finite observed bootstrap-controller set over from the default scheduler to `schedulerName=amoebius-capacity`,
installs the managed taint/admission/full exclusive-Binding RBAC, and **independently** mints
`ManagedCapacityReady`; it then binds the pinned Pending guarded-Pod set (the corpus's registry-backed,
non-zero-`initialDelaySeconds` Deployment) **exclusively** through CAS `Reserved` → CAS `BindingInFlight` →
submit/confirm Kubernetes Binding → CAS `Bound`, with an external apiserver + reservation-CRD observer proving
**no Binding precedes a successful reservation CAS**, every guarded Pod UID debited **exactly once**, and the
bootstrap→steady cutover leaving **no double-bind**; a guarded workload submitted before
`ManagedCapacityReady` is rejected at admission with **zero writes**; the immediate re-run is a scheduler
**no-op** (byte-stable reservation records/CAS version, no new Binding, same `Lease` holder) by the independent
observer; and every committed scheduler mutant turns the suite red. The scheduler slice of the Phase-0-pinned
fixtures, the committed seeded mutant set, and the independent reference oracle are named in
[Gate integrity](#gate-integrity) below (§M delegation).

## Gate integrity

The apparatus is the **scheduler slice** of the source phase's committed reconcile corpus, partitioned along
this seam; Phase 19 owns the object/convergence slice of the same corpus, and the two do not duplicate each
other. All identifiers are Phase-0-pinned before `Scheduler/Ledger.hs` exists (§M.1 oracle-pinning), except the
scheduler-role fixtures that depend on the Phase-18 registry/preloaded image and the Phase-17 live cluster,
which are committed at the start of this phase before the implementation that consumes them (§M.1 named
exception).

**Inherited committed fixtures (§M.1/§M.7 concrete corpus).** The corpus is the committed
`test/live/fixtures/reconcile-corpus/` — a subset of the Phase-13 byte-for-byte `renderAll` golden corpus
(`test/golden/render/` service specs, referenced by their golden IDs, never a freshly hand-picked spec). This
phase inherits exactly these members:
- the **scheduler-role system** — the `CapacitySchedulerSystemDemand` Pod/config/reservation-CRD/RBAC/
  admission set — which must pass `BootstrapCapacitySchedulerReady`, the bootstrap-controller UID cutover, and
  `ManagedCapacityReady`, in order, before any guarded Pod;
- the **finite observed distro/Phase-18 bootstrap-controller set** that is patched from the default scheduler
  to `schedulerName=amoebius-capacity` during the cutover;
- corpus item **(i)** — the guarded Deployment whose container image is pulled from the Phase-18 in-cluster
  `distribution` registry and whose readiness probe carries a **non-zero `initialDelaySeconds`** (so
  rollout-complete cannot be true at Bind time and the registry dependency is exercised by a running pod) — the
  Pending guarded Pod the scheduler must reserve and bind;
- `test/live/fixtures/reconcile-corpus/expected-actions.json` — the **scheduler-action slice** only: the
  `CapacitySchedulerSystemDemand` static debit, the `BootstrapSchedulerStage` namespace/quota/CRD/config/root/
  cutover-RBAC actions, the `AfterBootstrapAddonCutover` managed-taint/admission/full-Binding install, and the
  `Reserved`/`BindingInFlight`/`Bound` reservation transitions for the guarded Pod;
- a committed **premature-guarded-workload negative** (§M.8): a Pod naming `amoebius-capacity` / tolerating the
  managed-capacity taint, submitted **before** `ManagedCapacityReady`, asserting its expected admission-reject
  reason, paired with the positive that is admitted **only after** the full witness. Corpus members (ii) serial
  OnDelete, (iii) the Job, (iv) the Ready/Available object, and (v) the CustomResource are Phase 19's slice and
  are not re-exercised here.

**Committed seeded mutants the gate MUST turn red (§M.2).** Each is drawn from the source's operator set and
committed/re-run, not run once:
- **`bind-before-reservation-CAS`** (effect-swap/ordering) — submits Kubernetes Binding before the `Reserved`
  CAS succeeds; must fail the external reservation-CRD auditing (no Binding may precede a successful CAS);
- **`numeric-add-instead-of-whole-ledger-refold`** (fold-weakening) — placement adds a numeric delta instead
  of re-folding the whole reservation ledger; must fail the two-candidate residual race;
- **`same-UID-double-debit`** (union-arm/idempotence) — a same-UID retry mints a second reservation record;
  the external "every UID debited once" assertion goes red;
- **`bound-deleted-on-restart`** (dropped-`UNCHANGED`) — recovery deletes a `Bound`/`Terminating` reservation
  merely because the scheduler restarted; the crash/restart fixture goes red;
- **`default-scheduler-managed-node-bypass`** (guard-negation) — a second default-scheduled Pod tolerating the
  managed-capacity taint is admitted; the managed-taint-bypass fixture goes red;
- **`collapsed-readiness`** (invariant-clause delete) — readiness ignores the config digest or collapses
  `BootstrapCapacitySchedulerReady` and `ManagedCapacityReady` into one witness; the
  scheduler-ready-with-managed-taint-present fixture goes red;
- **`stage-drop-generic-SSA-before-cutover`** (guard-weakening) — the rendered managed-taint/admission objects
  are generic-SSA-applied from the full render list before the bootstrap-controller domain-equality witness;
  must go red.

**Independent reference predicate (§M.3/§M.5).** All "reserved once / bound once / no-op re-run" verdicts are
read by an **external apiserver + reservation-CRD observer** — a distinct `kubectl get -o json` / client-go
reader that is **not the scheduler and shares no fold/CAS/`Step→argv` code with it**. It reads the reservation
records, their CAS version, and the Kubernetes `Binding` subresource directly and asserts, independently of the
code under test: **no `Binding` request precedes a successful `Reserved` CAS**; **every guarded Pod UID has
exactly one reservation debit** (no Pod+ledger double debit); at every audit resourceVersion **at most one
holder** and no non-authority write without the exact mandatory-`Lease` holder (held by the Phase-19
reconciler); on the immediate re-run the reservation records and CAS version are **byte-identical** and **no
new `Binding` is issued**; and **no second default-scheduler exception exists**. The scheduler's self-reported
"reserved once, bound once" is corroborating evidence only, never the passing condition. The reference *action*
domain is the Phase-0-pinned hand-authored `expected-actions.json` scheduler slice, authored before the
planner — not regenerated from the scheduler's own output.

## Resource provision — the `CapacitySchedulerSystemDemand` envelope

`CapacitySchedulerSystemDemand` is the scheduler's own explicit, pure-first provision, fitted by the Phase-7
`place` fold before any effect, so the scheduler is never silently free overhead:
- **Image** — the Phase-18 side-loaded/preloaded multi-arch amoebius base image (never a public-registry pull),
  so the scheduler does not depend on the registry controller it must cut over.
- **Pod envelope** — the complete pinned bootstrap Pod: non-zero CPU/memory request+limit, explicit logical
  `ephemeral-storage`, unique-node affinity, and `restartPolicy`/probe fields; its single Pod uses the
  **default scheduler** (the sole structural exception) and a static reservation row merged into the same
  identity-aware fold (equal shared image extents deduplicate, compute/slots add).
- **Namespace/quota** — the `amoebius-capacity-scheduler` namespace and its exact `ResourceQuota pods=1`.
- **Reservation state** — the reservation CRD, config, and aggregate root; the canonical reservation
  serializer derives entry bytes, and `maxEntries` derives from the **maximum normalized Pod-UID population
  including retained terminal records**, never an authored scalar.
- **RBAC/admission** — the restricted cutover-only RBAC first, then the full exclusive-Binding RBAC, the
  general identity-admission webhook, and the managed-node taint policy installed only at cutover.
- **API/etcd** — the serialized API objects, etcd logical bytes, and the `EtcdChurnBudget` CAS-churn
  projection reserved per attempt until a post-attempt observation commits or releases the debit.
- **Readiness** — the two distinct witnesses `BootstrapCapacitySchedulerReady` and `ManagedCapacityReady`.

## Doctrine adopted

- [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions)
  — **the apply/reconcile engine** (the scheduler slice). This phase realizes the amoebius scheduler-role
  CAS/Binding protocol (`Reserved` → `BindingInFlight` → submit/confirm Binding → `Bound`), the two-stage
  bootstrap taint/RBAC cutover, and execution-identity admission. Generic SSA, staged execution, Job terminal,
  authenticated deletion, and the rollback/release ledger are Phase 19's or stay deferred.
- [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
  — **desired is the validated identity index of `renderAll(provisionedSpec)`, observed is live inventory, and
  actions are typed** (the scheduler-ledger slice). The state-indexed
  `Reserved | BindingInFlight | Bound | Terminating | TerminalRetained` records, their CAS version, and the
  `LedgerOnlyAbsentRecovery` arms are **observed** to authorize reservation transitions, never treated as
  another desired source; a `PlannedExecutionSlotId` is never a Pod UID.
- [`resource_capacity_doctrine.md §8`](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)
  — **declared at decode, cross-checked at runtime.** Before each reservation CAS the scheduler re-folds the
  static/foreign/resident/whole-ledger/candidate resource algebra over the Phase-7 `place` fold and re-observes
  residual capacity; two concurrent candidates cannot reserve the same residual, and a stale or false witness
  is refused with zero writes.
- [`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
  — **the runtime enactor: observe, never sleep.** `BootstrapCapacitySchedulerReady`, the bootstrap-controller
  cutover, `ManagedCapacityReady`, and reservation `Bound`+Ready are read from live sources; no `threadDelay`
  substitutes for a scheduler-readiness witness.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — **the control-plane singleton.** The scheduler is a dedicated role of the same amoebius binary/image, not
  a second implementation; this phase drives it from the **host binary** as a precursor, and the Deployment-
  `replicas=1` singleton that *owns* it (single-writer authority delegated to k8s/etcd through the mandatory
  `Lease`, no bespoke election) is stood up in Phase 26.
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  — **Register 3** (live infrastructure): the register this phase's gate reaches; and
  [`§4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  the per-run proven/tested/assumed ledger the live cutover/binding emits (no skips, fail fast; the scratch
  namespace is torn down leak-free).

## Sprints

## Sprint 20.1: State-indexed reservation ledger + normalization + absent-Pod recovery arms 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Scheduler/Ledger.hs` — the state-indexed reservation ledger join and
normalization that extends Phase 19's `src/Amoebius/Execution/Normalize.hs` observed snapshot with the
scheduler dimension; target paths, not yet built.
**Blocked by**: Phase 19 gate (the object reconciler, `ObservedLiveResourceSnapshot`, and `ValidatedLiveTarget`
construction).
**Independent Validation**: a fresh snapshot over the pinned corpus normalizes each reservation state exactly
once and produces the committed scheduler-ledger slice of
`test/live/fixtures/reconcile-corpus/expected-actions.json`, authored before this module. Every ledger negative
(orphan, missing, wrong-state, double debit) fails to construct a `ValidatedLiveTarget` and before any
apiserver, ledger, or Binding write.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Adopt [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
— the reconcile state model, scheduler-ledger slice. Extend Phase 19's observed inventory with the
state-indexed reservation ledger and its resourceVersion/CAS version, normalize every reservation state
exactly once, and classify the closed absent-Pod recovery arms — so no observed Pod plus ledger row is
double-debited, no absent Pod makes a debit disappear, and no unclassified record reaches a
`ValidatedLiveTarget` constructor.

### Deliverables

- A scheduler-ledger join over full `Reserved | BindingInFlight | Bound | Terminating | TerminalRetained`
  records plus resourceVersion/CAS version, added to Phase 19's `ObservedLiveResourceSnapshot` (empty before
  this phase because the corpus is default-scheduled and no reservation CRD exists). Normalize `PendingUnscheduled`
  API-only, `Reserved`/`BindingInFlight` Pod+ledger once, joined `Bound`/`Terminating` as one exact vector,
  `Terminal` retained axes only, and each host reservation once. Missing, unclassified-orphan, wrong-state,
  wrong-node, wrong-generation, wrong-template, unequal-axis, duplicate, and observed+ledger double-debit joins
  have **no** constructor.
- The closed `LedgerOnlyAbsentRecovery` arms: an absent Pod retains the exact full or terminal-retained debit
  for `Reserved`, `BindingInFlight`, `Bound`, `Terminating`, or `TerminalRetained` until that state's
  release/cleanup evidence and whole-root CAS succeed. Positive recovery fixtures cover an absent-Pod row in
  every closed ledger state and prove each remains charged until its state-specific CAS.
- The host-aware observed identity union consumed from Phase 19 —
  `KubernetesPod PodUid | HostProcess HostProcessInstanceId | HostReservation HostReservationId` — with its
  ledger-only third arm: host `Reserved`, no-process `LaunchInFlight`, and post-process retained-artifact rows
  remain charged under `HostReservation HostReservationId`; process-observed `LaunchInFlight` enters
  `HostLaunchRecovery`; Running/Draining exact-join the process and reservation once. Missing, duplicate, or
  process-fabricated ledger-only identities reject.
- State-sensitive Binding recovery at normalization time: an unknown/unbound `BindingInFlight` row remains
  planned-only, while an exact-node `ConfirmedBound PodUid` observation immediately derives the observed
  Pod-UID runtime-storage row (from Phase 19's `RuntimeStorage`) and exact-joins it once with the
  still-`BindingInFlight` reservation — the later repair CAS (Sprint 20.3) changes state, not capacity.
- The scheduler-ledger slice of the `ValidatedLiveTarget`: the ledger CAS version, the normalized
  reservation/host-reservation witnesses, and the reservation transition sub-domain of the typed action map,
  handed to Phase 19's target constructor. `PlannedExecutionSlotId` is never equated with a Pod UID; every
  same-slot predecessor/replacement UID is preserved as two distinct commitments.

### Validation

1. The normalized ledger for the pinned corpus equals the committed scheduler-ledger slice of
   `expected-actions.json`. Seeded mutants — unclassified-orphan record, missing reservation, wrong
   state/node/template/generation/axes, a `Bound` Pod plus ledger double debit, reservation-only omission, and
   an incorrect terminal released/retained partition — each fail to construct a `ValidatedLiveTarget`.
2. Positive recovery fixtures cover absent-Pod rows in **every** closed ledger state and prove each remains
   charged until its state-specific CAS. Host negatives cover omission of `Reserved`/`LaunchInFlight`/
   retained-artifact `HostReservationId`, use of a fake process id for a ledger-only row, and double debit after
   process join. Exact-fit controls debit each identity once.
3. A confirmed-bound-but-still-`BindingInFlight` fixture must use the observed Pod-UID runtime row; the
   planned-only omission and the planned+observed double-debit mutants both turn red. The
   `same-UID-double-debit` mutant is caught at normalization by the external "every UID debited once" oracle.
4. The module imports no writer; the AST/import lint proves `Scheduler/Ledger.hs` is read-only, and a runtime
   observer proves zero apiserver/ledger/Binding writes on every negative.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 20.2: Scheduler bootstrap authority + two-stage taint/RBAC cutover + readiness witnesses 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Scheduler/Readiness.hs`, the scheduler-authority slice of
`src/Amoebius/Manifest/Authority.hs` (`CapacitySchedulerSystemDemand` admission and the scheduler-system-only
token; the cold-start `Lease` authority itself is Phase 19), and `src/Amoebius/Admission/ExecutionIdentity.hs`
(the managed-taint/admission install) — target paths, not yet built. The scheduler role is an entry point of
the existing amoebius binary/image, not a second implementation or a kube-scheduler plugin.
**Blocked by**: Sprint 20.1; Phase 18 gate (the preloaded/side-loaded base image + in-cluster registry);
Phase 19 gate (the reconciler holding the mandatory reconciler `Lease`).
**Independent Validation**: `BootstrapCapacitySchedulerReady` precedes the finite bootstrap-controller cutover;
every old default-scheduled UID is absent/released and every replacement is reservation-joined before
`ManagedCapacityReady`; only the latter precedes any general guarded controller action. An independent taint/
admission/RBAC/writer-domain readback mints `ManagedCapacityReady`; no readiness witness is a `threadDelay`.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/readiness_ordering_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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

- A read-only scheduler preflight (layered on the Phase-19 reconciler already holding
  `ProvisionedMandatoryReconcilerLease`) that admits only the statically debited `CapacitySchedulerSystemDemand`
  and mints a **scheduler-system-only** token. That token creates the `amoebius-capacity-scheduler` namespace,
  the exact `ResourceQuota pods=1`, the reservation CRD/config/root, the complete pinned scheduler Deployment,
  and RBAC **restricted to the enumerated bootstrap add-on cutover**. Its sole Pod is default-scheduled, uses
  the Phase-18 side-loaded/preloaded amoebius image, has unique-node affinity, and merges its static owner row
  with the ledger fold (equal shared image extents deduplicate, compute/slots add). These are the only
  `BootstrapSchedulerStage` actions.
- `BootstrapCapacitySchedulerReady`: exact active generation/config/root readback mints it **while the managed
  taint, general identity admission, and full Binding authority remain absent**. Its restricted capability can
  only patch the exact observed distro/Phase-18 bootstrap-controller set to `schedulerName=amoebius-capacity`.
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
3. `ceil(renewalWindow/retryPeriod) <= maxRenewalsPerWindow` is not re-proven here (the `Lease` is Phase 19's),
   but the scheduler preflight asserts it runs **only** while the Phase-19 reconciler is the exact `Lease`
   holder; an attempt to stand up the scheduler without that holder refuses.
4. The forbidden-symbol lint over `src/Amoebius/Scheduler/Readiness.hs` and the scheduler slice of
   `Manifest/Authority.hs` and `Admission/ExecutionIdentity.hs` rejects `threadDelay`, aliases, and
   clock-polling busy-waits as readiness gates.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 20.3: Scheduler loop + `Reserved`→`BindingInFlight`→Binding→`Bound` CAS + placement + recovery 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Scheduler/{Loop,Placement,Reservation,Binding,Recovery}.hs` and the
authentication path of `src/Amoebius/Admission/ExecutionIdentity.hs` — target paths, not yet built.
**Blocked by**: Sprint 20.1, Sprint 20.2, Phase 7 gate (the `place`/`fits`/`carve` resource-algebra fold the
placement invokes).
**Independent Validation**: two concurrent candidates cannot reserve the same residual; crash-after-reserve,
restart, and Binding failure recover idempotently; the external observer proves no Binding precedes a
successful reservation CAS and every UID is debited once.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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
  static/foreign/resident + whole-root + candidate resource algebra (`Scheduler/Placement.hs` over the Phase-7
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
- The reservation transitions are the scheduler's members of Phase 19's `ValidatedExecutionTransitionAction`
  domain; the scheduler never enters Phase 19's generic scoped-SSA path (`fieldManager=amoebius`), and every
  mutating reservation/Binding constructor carries only its dedicated scoped capability and can never be minted
  for a non-holder.

### Validation

1. Live scheduler tests cover config-not-Ready and digest-mismatch refusal, managed-taint bypass, invalid
   provenance/owner chain, a two-candidate CAS race, same-UID retry, unbound retarget, wrong-RV conflict,
   crash-after-reserve/restart, Binding failure, crash-after-Binding-before-`Bound`-CAS, and state mismatch. The
   external observer proves **no Binding precedes a successful reservation CAS** and every UID is debited once.
2. The seeded mutants `bind-before-reservation-CAS`, `numeric-add-instead-of-whole-ledger-refold`,
   `same-UID-double-debit`, and `bound-deleted-on-restart` all turn red. Readiness that ignores the config
   digest or collapses the two witnesses (from Sprint 20.2) also turns the reservation suite red when it lets a
   guarded Pod through prematurely.
3. Crash/watch-gap injection at each edge (post-reserve, post-Binding-pre-CAS, restart) re-observes and
   converges without a duplicate debit or an unguarded scheduling interval.
4. The scheduler modules import no generic SSA writer; the lint asserts scheduler/ledger/Binding actions never
   enter Phase 19's `Manifest/Apply.hs` scoped-SSA module, and `NoOp` carries no writer capability.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 20.4: Live scheduler binding + bootstrap→steady cutover gate 📋

**Status**: Planned
**Implementation**: `test/live/SchedulerReservationSpec.hs` and `test/live/SchedulerBootstrapCutoverSpec.hs`,
driving the Sprint 20.1–20.3 `Scheduler/*` and `Admission/ExecutionIdentity` modules against the live Phase-17
`kind` cluster and the converged Phase-19 reconciler — target paths, not yet built.
**Blocked by**: Sprint 20.3.
**Independent Validation**: the representative corpus observes `BootstrapCapacitySchedulerReady`, complete
bootstrap-controller cutover, and `ManagedCapacityReady` **before** any guarded Pod; the guarded Deployment
binds exclusively through the CAS reservation/Binding protocol with no double-bind; a guarded workload before
`ManagedCapacityReady` is rejected with zero writes; the immediate re-run is a scheduler no-op by the external
observer; and every committed scheduler mutant turns red.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/readiness_ordering_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`,
`documents/engineering/daemon_topology_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-20 status when
the gate passes).

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
  apiserver + reservation-CRD observer asserts byte-identical reservation records and CAS version, **no new
  Binding request**, the same mandatory-`Lease` holder/resourceVersion, and no second default-scheduler
  exception.
- The committed red-path suite: the mutants `bind-before-reservation-CAS`, `numeric-add-instead-of-whole-ledger-refold`,
  `same-UID-double-debit`, `bound-deleted-on-restart`, `default-scheduler-managed-node-bypass`,
  `collapsed-readiness`, and `stage-drop-generic-SSA-before-cutover` MUST turn the suite red; the
  premature-guarded-workload negative fixture MUST be rejected at admission.
- A Register-3 proven/tested/assumed ledger recording the live scheduling authority, marking the
  release-ledger/rollback residue and the in-cluster-singleton ownership (Phase 26) UNVERIFIED (deferred).

### Validation

1. `cabal test scheduler-reservation scheduler-bootstrap-cutover` is green on the linux-cpu `kind` corpus.
   `BootstrapCapacitySchedulerReady`, complete controller cutover, and `ManagedCapacityReady` occur in order
   before the first guarded Pod; every Binding follows a successful reservation CAS; the guarded Deployment
   reaches Bound+Ready; the premature guarded workload is rejected with zero writes; and the immediate re-run is
   byte-stable and Binding-free by the independent observer.
2. Every committed scheduler mutant above turns the suite red, re-run (not run once). The external observer —
   not the scheduler — is the passing condition for "reserved once / bound once / no-op re-run".
3. Two simultaneous scheduler candidates cannot race past the ledger residual; both leave zero over-allocation.
   Crash/watch-gap injection at each cutover and reservation edge re-observes and converges without a duplicate
   debit or an unguarded scheduling interval.
4. After the evidence is captured, the elevated harness destroys the run-scoped scratch namespace and sweeps
   its reservation records leak-free; this postflight is not represented as a successful convergence claim and
   proves no persistence ordering.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 20.5: Register-2.5 scheduler convergence under simulated faults 📋

**Status**: Planned
**Implementation**: `test/sim/SchedulerSim.hs`, driving the real `Scheduler/*` and
`Admission/ExecutionIdentity` modules on the Phase-14 `io-classes` `Env` / modeled apiserver — target paths,
not yet built. This is the scheduler slice of the deterministic-simulation battery; Phase 19 owns the
object-reconciler slice of the same environment.
**Blocked by**: Sprint 20.4; the Phase-15 deterministic-simulation substrate and the Phase-14 `io-classes`
seams / modeled apiserver.
**Independent Validation**: `IOSimPOR` interleaves reservation-ledger CAS races, bootstrap-`Lease` acquire/renew
ambiguity, crashes/watch gaps across **both** scheduler-readiness stages, crash-after-reserve, Binding failure,
and restarts. Every schedule either converges to a typed scheduler no-op or fails closed without an overlapping
writer, an unguarded Pod, overspend, or a double-bind; counterexamples replay by seed.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (Phase-20 status backlink),
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits):
validate the *built* scheduler under injected faults **in-process and deterministically replayable**, at
Register 2.5 — one rung below the Sprint 20.4 Register-3 gate in the register ladder, not chronologically ahead
of it — closing the code-schedule gap the pure-value tests and the live gate each leave open for the
scheduling authority.

### Deliverables

- The real scheduler loop under `IOSimPOR`, with ≥200 schedules per fault class (or an exhaustive stated
  preemption depth) and `cover`/`classify` proving faults land **inside** the bootstrap-scheduler-readiness,
  add-on-cutover/full-authority transition, reservation-CAS, and Binding critical sections rather than only
  between iterations.
- Safety invariants on every trace: no general guarded action from `BootstrapCapacitySchedulerReady`; no full
  authority before complete old-UID release/replacement joins; **one reservation debit per Pod UID**; **no
  Binding before a successful CAS**; no `Bound` record unreserved on restart; no non-authority write without the
  exact mandatory-`Lease` holder; and unchanged snapshot tokens cannot be reused after any observed-state
  transition.
- Committed mutants for lost-`Lease`/resourceVersion retry (against the reconciler holder the scheduler depends
  on), collapsed scheduler-readiness stages, premature managed taint/full RBAC, bind-before-CAS, same-UID double
  debit, crash recovery dropping `Bound`, and cached observation. Every mutant must turn red.
- A Register-2.5 proven/tested/assumed ledger — the scheduler upholds convergence + fail-closed under the
  modeled schedules and faults; honest limit: modeled-apiserver fidelity is **assumed**, discharged by the
  Sprint-20.4 Register-3 live gate.

### Validation

1. `cabal test scheduler-sim` is green at the documented exploration bound. Coverage proves every fault enters
   its critical section; every safety invariant holds; every committed mutant is caught; and each discovered
   counterexample replays identically under its seed.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/manifest_generation_doctrine.md` — §5's amoebius scheduler-role CAS/Binding protocol
  and two-stage bootstrap taint/RBAC cutover flip from design intent to delivered with the Register-3 ledger
  attached; §6's observed state-indexed scheduler ledger (`Reserved | BindingInFlight | Bound | Terminating |
  TerminalRetained` + `LedgerOnlyAbsentRecovery`) gains its first validation. The generic SSA/staged-action/
  delete/wait engine remains Phase 19's; the rollback/release ledger stays deferred.
- `documents/engineering/resource_capacity_doctrine.md` — record the scheduler's pre-reservation whole-ledger
  re-fold and its zero-write refusal on a stale/false witness.
- `documents/engineering/readiness_ordering_doctrine.md` — the §6 runtime-enactor claim (observe, never sleep)
  gains its scheduler-readiness proof (`BootstrapCapacitySchedulerReady`/`ManagedCapacityReady` observed, not
  slept).
- `documents/engineering/daemon_topology_doctrine.md` — record that Phase 20 drives the scheduler role from the
  host binary; the §3 singleton that *owns* both the reconciler and its scheduling role (Deployment
  `replicas=1`, delegated single-instance, no election) is stood up in Phase 26.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the Phase-20 scheduler slice of the
  Register-2.5 io-sim battery (Sprint 20.5), with modeled-apiserver fidelity marked assumed.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-20 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 20's gate substrate (linux-cpu) in the per-phase substrate
  map.
- `DEVELOPMENT_PLAN/system_components.md` — register the Phase-20
  `Scheduler/{Ledger,Loop,Placement,Reservation,Recovery,Binding,Readiness}` and `Admission/ExecutionIdentity`
  modules (plus the scheduler-authority slice of `Manifest/Authority.hs`) and their live/simulation suites.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  live-proof acceptance token: *the scheduler binds under an external CAS-ledger/Lease observer with no
  double-bind*, proven in Register 3)
- [overview.md](overview.md) — target architecture; the same-binary `amoebius-capacity` scheduler that
  authenticates a sealed prior+desired child template, re-folds the resource algebra under one aggregate CAS,
  then alone binds the Pod
- [phase_19_object_reconciler.md](phase_19_object_reconciler.md) — the object reconciler (observe → diff →
  scoped-SSA → staged-enact → delete → wait, and the `ValidatedLiveTarget` + mandatory `Lease`) this phase is
  layered on
- [phase_07_capacity_core_folds.md](phase_07_capacity_core_folds.md) — the `place`/`fits`/`carve` resource
  algebra the scheduler placement re-folds under aggregate CAS
- [phase_13_render_manifest_goldens.md](phase_13_render_manifest_goldens.md) — the `renderAll` golden corpus
  the pinned reconcile corpus is a subset of
- [phase_17_midwife_bootstrap_kind.md](phase_17_midwife_bootstrap_kind.md) — the live single-node `kind`
  cluster this phase's scheduler binds on
- [phase_18_base_image_registry.md](phase_18_base_image_registry.md) — the in-cluster registry and the
  preloaded/side-loaded amoebius image the bootstrap scheduler Pod uses
- [phase_26_live_dsl_singleton.md](phase_26_live_dsl_singleton.md) — the Deployment-`replicas=1` singleton that
  stands the reconciler and its scheduling role up in-cluster
- [phase_14_chain_kernel_boundary.md](phase_14_chain_kernel_boundary.md) — the `io-classes` seams / modeled
  apiserver the Register-2.5 scheduler sim (Sprint 20.5) drives the real modules on
- [phase_15_deterministic_sim_substrate.md](phase_15_deterministic_sim_substrate.md) — the deterministic-
  simulation substrate the Register-2.5 scheduler battery runs in
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §5 the apply/
  reconcile engine (scheduler CAS/Binding + bootstrap cutover slice); §6 the observed scheduler-ledger state
  model
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — §8 declared at decode,
  cross-checked at runtime (the scheduler's pre-reservation re-fold)
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — §6 the runtime
  enactor (observe, never sleep) the scheduler-readiness witnesses realize
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — §3 the Deployment-
  `replicas=1` singleton that will own this scheduling role in Phase 26
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the
  Register-2.5 io-sim environment the scheduler is validated against in Sprint 20.5, before the Register-3 gate
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 3 (live), §4 the per-run ledger
