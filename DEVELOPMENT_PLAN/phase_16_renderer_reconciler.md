# Phase 16: Typed renderer + live action reconciler

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md, DEVELOPMENT_PLAN/phase_22_live_dsl_singleton.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Take an opaque whole-deployment `ProvisionedSpec`, re-observe and cross-check the target's
> complete resource/capability inventory before mutation, construct the Phase-9 deployment-global
> `renderAll` object list and separately validate/index it, then enact snapshot-bound typed actions on a live
> single-node `kind` cluster —
> mandatory bootstrap-holder Lease authority, two-stage scheduler cutover, scoped server-side apply,
> CAS `Reserved` → CAS `BindingInFlight` → submit/confirm Kubernetes Binding → CAS `Bound`, staged
> execution/retention, authenticated deletion, and observed readiness —
> converging the generation and proving an immediate re-run is a no-op.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 15 gate (the
multi-arch base image + jit-build resolver + in-cluster `distribution` registry) and runs on the
**linux-cpu** substrate in **Register 3** — the first phase whose gate actually *applies* rendered objects
to a live cluster. It builds the **live half** of the manifest doctrine: Phase 9 already stood up the pure
private per-source `renderSourcePrivate` plus the deployment-global `renderAll` owner union and golden-locked them in Register 1;
this phase wires that exact value through the `discover → diff → enact` reconciler onto the single-node
`kind` cluster from Phase 14. The reconciler is exercised here **from the host binary against a scratch
namespace**, against the pinned Phase-9 corpus — the in-cluster **control-plane singleton** that eventually owns it
(a Kubernetes Deployment `replicas=1` whose single-instance guarantee is delegated to k8s/etcd with **no
bespoke election** and no standby pods) arrives in Phase 22. Where a shape below is already exercised in a
sibling — prodbox renders a slice of its object set from typed Haskell records and applies it with
`kubectl apply -f`, stamping every object with an owner label — that is **sibling evidence, not an amoebius
result**; the state-indexed scheduler ledger, typed action algebra, authenticated deletion, scoped SSA, and
unified observed-readiness path are amoebius's new code.

## Phase Summary

This phase delivers amoebius's live typed-action engine. Pure Phase 9 supplies
`renderAll :: ProvisionedSpec -> [K8sObject]`: one deployment-global rendered list with exact structural
source ownership across service controllers and global scheduler, admission, quota, RBAC/config, route,
storage, and control-plane projections. `validateAndIndexRenderedObjects` is the separate pure step that
checks each emitted object's identity against its source key and constructs the
`Map KubernetesObjectId (K8sObject, RenderActivation)` used by diff; it rejects duplicates, source/
object-stage mismatch, or domain mismatch rather than changing
`renderAll`'s canonical signature. Omitted global projections and per-service last-writer-wins concatenation
are impossible. The exact list is the dry-run result, and only its validated index is the desired-object
baseline.

That full list is not permission to apply every object at cold start. The corresponding provisioned render
sources carry a closed activation index:
`Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover | AfterManagedCapacityReady`.
`validateAndIndexRenderedObjects` preserves that index beside each object. The typed planner exposes only
the preclassified bootstrap-safe Namespace/Lease initialization actions from `Immediate`; it never gives a
Pod/controller or mutable ledger/Lease field generic apply authority. `BootstrapSchedulerStage` then exposes
only scheduler Namespace/quota/config/root/controller plus restricted cutover RBAC; only the
observed add-on-domain equality unlocks managed taint/admission/full Binding authority; only
`ManagedCapacityReady` unlocks general platform/workload actions. Generic SSA never scans the full rendered
list and applies a later-stage object early.

The live reader then takes one coherent snapshot of objects and all capacity. Desired execution epochs are
keyed by `PlannedExecutionSlotId`, which is a pure capacity slot and never a future Pod UID. Live execution is
an `ObservedExecutionSet` keyed by
`KubernetesPod PodUid | HostProcess HostProcessInstanceId | HostReservation HostReservationId`. The third arm
represents `Reserved | LaunchInFlight | RetainedArtifacts` host-ledger rows for which no process identity is
yet or any longer observable; it cannot masquerade as a running process or be omitted from residual capacity.
The set validates
the admission-protected deployment/generation/source/revision/reservation-template annotations and the
kind-indexed Pod owner chain — Deployment Pod→ReplicaSet→Deployment, or direct StatefulSet/DaemonSet/Job —
plus resourceVersions; host processes carry the analogous supervisor provenance. A terminating predecessor
and replacement for one planned slot remain two distinct live commitments.

The same snapshot includes the full state-indexed scheduler reservation ledger and its resourceVersion/CAS
version. Normalization charges PendingUnscheduled as API-only, Reserved and BindingInFlight Pod+ledger once,
Bound/Terminating Pod+ledger as one exact-joined vector, Terminal retained axes only, and each host
reservation/process once: host Reserved, no-process LaunchInFlight, and retained-artifact rows use
`HostReservation HostReservationId`; process-observed LaunchInFlight uses `HostLaunchRecovery`, while
Running/Draining exact-join that reservation to its observed process.
An absent Pod never makes a ledger debit disappear: the closed `LedgerOnlyAbsentRecovery` arms retain the
exact full or terminal-retained debit for Reserved, BindingInFlight, Bound, Terminating, or TerminalRetained
until that state's release/cleanup evidence and whole-root CAS succeed. Unclassified orphan,
missing, wrong-state, wrong-node, wrong-generation, wrong-template, unequal-axis, or duplicate ledger joins
fail closed. Runtime storage is rederived per observed eligible Pod component, grouped by
`KubeletNodefs | CriRuntimeRoot`, resolved through `Unified | SplitRuntime | SplitImage`, combined with the
disjoint `ImageContentRoot | CriRuntimeRoot` image model, and checked once per physical backing. Pending Pods
have no observed node-runtime debit; Reserved-before-Bind uses the planned ledger vector. A
`BindingInFlight` row with unknown/unbound outcome remains planned-only, but an exact-node
`ConfirmedBound PodUid` recovery observation immediately instantiates the observed Pod-UID runtime-storage row
and joins it with the reservation as one debit even before the repair CAS reaches `Bound`.
Bound/Terminating and retained Terminal UIDs likewise have observed runtime rows.

The `amoebius-capacity` scheduler is the same amoebius Haskell binary in a dedicated role, not a scheduler
framework plugin. `CapacitySchedulerSystemDemand` makes its image, complete Pod envelope, config, RBAC,
readiness, identity admission, managed-node taint policy, reservation CRD/records, API/etcd bytes, and CAS
churn explicit. Its single pinned bootstrap Pod uses the default scheduler, a unique-node affinity, exact
`amoebius-capacity-scheduler` namespace `ResourceQuota pods=1`, and a static reservation that participates in
the same identity-aware fold. Bootstrap is deliberately two-stage. Exact scheduler generation/config/root
readback first mints `BootstrapCapacitySchedulerReady` while the managed taint is absent; its restricted
capability can only patch the finite observed distro/Phase-15 bootstrap-controller set to
`amoebius-capacity`. After every old default-scheduled UID is absent/released and every replacement UID is
reservation-joined and Ready, bootstrap installs the managed taint, identity admission, and exclusive Binding
RBAC and independently mints `ManagedCapacityReady`. Only that full witness admits general guarded
controllers. The scheduler Pod is then the sole cycle-break/default-scheduler exception, and every other Pod
tolerating the managed-capacity taint must name `amoebius-capacity`.

For a Pending guarded Pod, the scheduler authenticates Pod UID, provenance, owner chain, generation and
template digest and controller-child discriminator, runs canonical placement over the complete resource
algebra, CASes the singleton root to `Reserved`, CASes `Reserved→BindingInFlight`, and only then submits
Kubernetes Binding. Same-UID retry reuses an identical record; only Reserved may retarget. A confirmed exact
UID/node Binding repairs BindingInFlight→Bound by CAS; confirmed same-UID/RV unbound or Pod absence may release;
timeout, lost response, or unknown outcome remains charged and reobserves. Bound/Terminating rows release only
resource-indexed partitions: ordinary Pod absence retains physical residents, CUDA additionally requires
device/process release, and terminal Job evidence retains modeled axes through cleanup/GC.

Whole-deployment preflight combines those commitments with residual CPU requests and finite CPU-limit
budget, memory, pod logical ephemeral, CNI/CSI/pod slots, API/etcd/mapped files, role-routed physical runtime
and image storage, OCI/snapshot/workspace identity unions, durable/object/native-cache presentation and
geometry, host processes/builds, controller children/webhooks, gateways/executors/migrations, and CUDA/Metal
device/VRAM/cache holds. Any missing or unbounded arm returns the specific error or `UnknownCommitment` before
effects. Success alone mints one single-use `ValidatedLiveTarget` containing the object/inventory
fingerprint, all relevant resourceVersions, scheduler CAS version, exact normalized and runtime-storage
witnesses, a complete map of `ValidatedExecutionTransitionAction`s, and the exact map of
`ValidatedStorageScalingAction`s derived from Phase 7's policy-only envelopes and fresh storage snapshots. A
final fingerprint recheck consumes the applicable token; change restarts the read-only prefix.

Enactment follows those actions, not a blind SSA/prune loop. Ordinary desired-object actions may use scoped
SSA under `fieldManager=amoebius`; scheduler ledger CAS/Binding, host control, provider/backing mutation, and
authenticated deletion use distinct capabilities. Pod controllers are kind-indexed. Serial OnDelete is
three-stage: delete one witnessed old Pod; after a fresh absence/release observation resume the controller;
after another fresh observation of the expected replacement UID Bound+Ready, advance to the next slot. Host
start is authorized only by `NoPrior | OrdinaryAfterExit | CudaAfterDeviceRelease | MetalAfterDrain`;
CUDA/Metal release evidence is live and fingerprint-bound. Owner labels discover prune candidates but do not
authorize deletion: exact owner/generation/resourceVersion, retention, and dependency guards must mint the
delete action.

Jobs also use a typed terminal state machine. This phase builds and model-checks success and
backoff-exhausted-failure completion variants, digest/outcome equality, cleanup deadlines, scheduler release
partitions, and `CompletedJobNoOp`; the live Phase-16 cluster has neither Phase-19 MinIO nor the Phase-25 sole
content-mutation gateway, so it does **not** claim a durable completion write/readback or delete a terminal Pod
on that basis. Its live Job reaches terminal and remains explicitly retained and charged. The first live
gateway write → independent matching readback → deadline/release → terminal cleanup gate is Phase 25. The Job
controller still uses `restartPolicy=Never`, `podReplacementPolicy=Failed`, its exact finite wave/retention
provision, and no `ttlSecondsAfterFinished`; Kubernetes TTL never bypasses the later typed cleanup action.

Every stage re-observes readiness/state instead of sleeping: bootstrap-scheduler and full managed-authority
witnesses, controller
rollout/Ready/Available, CR admission and child-envelope conformance, serial replacement Bound+Ready, device
release, and live Job terminal retention. The abstract durable-completion/cleanup transitions are exercised
in pure and IOSim tests only here. An immediate live re-run after convergence must mint only `NoOp` plus the
same terminal-retention action and make zero writes. The reconciler runs from the host binary against a throwaway
namespace here; the Deployment-`replicas=1` control-plane singleton that owns it arrives in Phase 22. The
release ledger/rollback path composes later and does not authorize replaying stale actions.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster on a linux-cpu host from
Phase 14; no apple, linux-cuda, or windows substrate is touched.

**Register:** 3 — live infrastructure (§K).

**Gate:** in **Register 3**, the Phase-9 pure deployment-global `renderAll` list for the **representative
reconcile corpus** (defined concretely below and Phase-0-pinned) is rendered in full and separately validated/
indexed with its source activation stages. It is enacted in a scratch namespace on the live single-node
`kind` cluster only through stage-eligible typed actions; list membership alone is never generic-SSA
authorization. The cold-start authority can create only the derived
control-plane Namespace and deployment-global mandatory reconciler Lease, acquire it under the bootstrap-host
identity through the typed `Absent → BootstrapHeld` action, and read that holder/object-UID/resourceVersion
back; its rounding-aware renewal count and exact one-update/one-revision-per-attempt etcd debits are already
provisioned. Every present-object renew uses the expected observed resourceVersion CAS and a fresh single-use
token; acknowledgement, conflict, timeout, or lost response consumes the token and requires re-observation
before authority continues. The Phase-15 registry/proxy objects are authenticated read-only as the one declared bootstrap
predecessor; their later whole-deployment ownership handoff requires exact identity/source/initialized-field
digest equality and cannot rewrite them before Lease acquisition. Before any Phase-16 scheduler, add-on
cutover, platform, or workload mutation, a read-only scheduler preflight then admits only the statically
debited `CapacitySchedulerSystemDemand`. Its scoped token creates the dedicated scheduler namespace/quota,
CRD/config/root and restricted cutover RBAC, then observation mints
`BootstrapCapacitySchedulerReady` for the exact generation/digest while the managed taint is absent; these are
the only `BootstrapSchedulerStage` actions. That
token patches only the finite observed bootstrap controllers. After old UID absence/release and replacement
reservation/Ready joins are observed, `AfterBootstrapAddonCutover` authorizes only the typed managed-taint/
admission/full-exclusive-Binding installation; an independent authority readback mints
`ManagedCapacityReady`. Only `AfterManagedCapacityReady` entries may then produce general actions. A fresh independent
whole-deployment inventory then proves that the `ProvisionedSpec`'s declared
CPU/memory/logical-ephemeral-storage, finite CPU-limit budget, pod/CNI/CSI slots, etcd logical quota and mapped
files, layout-routed physical node storage, durable/object-store/migration/native-host-cache pools, and
accelerator device/net-allocatable-and-current-free-VRAM assumptions plus content/snapshot,
controller-child/webhook, gateway, and executor bounds fit the
**residual transition capacity** after every surviving live allocation. The resulting
`ValidatedLiveTarget` drives scoped SSA, CAS `Reserved` → CAS `BindingInFlight` → submit/confirm Kubernetes
Binding → CAS `Bound`, kind-indexed controller actions,
staged serial/host/accelerator actions, Job terminal retention (with durable completion/cleanup capability
absent in this live phase), and authenticated deletion. Each action's
postcondition is observed (never a `threadDelay`) until the generation converges. In this phase's live gate,
the Job terminal remains retained; completion persistence/readback/cleanup is model-tested here and first
exercised live through the Phase-25 gateway. An immediate re-run of the same spec is a **no-op** — only
`NoOp`/unchanged terminal-retention decisions, zero further mutations, and the same converged live state,
measured by independent apiserver, scheduler-ledger, Lease, and host observers.

**Pre-mutation capacity/capability cross-check (§M.5/§M.8).** The live inventory reader is independent of the
pure provision fold and combines apiserver node allocatable values and all scheduled/live reservations with
OS-boundary observations of separately-owned durable/object-store/native-host-cache pools (raw size,
presentation, mounted
usable bytes), physical-host VM/process commitments, nodefs/imagefs/containerfs identity/capacity, all
containerd content objects and committed/active snapshots, node-image model/enforced pull policy, current
pod/CNI/CSI slot use, serialized API objects/etcd quota, mapped-file payloads/backing, object-store
residents/incomplete writes, and accelerator
device/profile/raw-reserved-allocatable VRAM plus current-free memory, exact work-item/device holds, actual
Pod UIDs/host-process IDs plus ledger-only `HostReservationId`s, kind-indexed owner chains, protected provenance, and the state-indexed scheduler
ledger. It joins observed instances to planned slots by authenticated source/revision/template witnesses — it
never equates a Pod UID with `PlannedExecutionSlotId` — and preserves simultaneous predecessor/replacement
UIDs. It rederives runtime components for each eligible observed Pod, groups
`KubeletNodefs | CriRuntimeRoot`, resolves roles through the observed layout, combines the disjoint image
roles, and checks aliased physical backings once. It validates every private accelerator epoch rather than
accepting a favorable aggregate. Desired rendering, observation, typed diff,
transition-peak derivation, and validation are all read-only. A surviving foreign container without bounded
CPU/memory/ephemeral ceilings, an unobservable root-filesystem writability/allowance, a writable `hostPath`,
unknown resident content/snapshot bytes, an unexpected filesystem alias/root/capacity, a mismatched/unobservable
pull policy/model, or a supported CR/provider
arm without a finite child-resource/rollout/webhook bound, a direct backend object mutation, or an
unrecognized migration/executor is `UnknownCommitment` and fails closed. Phase-14
engine/static components enter through `EngineSystemReserve`; every remaining kube-system addon is a bounded
topology-expanded per-node unit, so stock system pods are never silently free or an unavoidable unknown.
The Phase-0-pinned negatives cover occupied CPU and memory residual, pod/CNI/CSI slot exhaustion, etcd
logical/mapped-file overrun, shrunk/occupied logical or physical node storage,
exhausted durable/object-store/migration/native-cache backing, missing/count-short/net-VRAM-short accelerators (including a raw-total
fit that fails after the mandatory reserve), omitted accelerator work items, favorable-epoch or per-device-
overlap mismatches, a missing old/terminating observed Pod UID or host-process ID, spoofed/missing provenance
or owner-chain hop, unclassified-orphan/wrong-state/unequal scheduler record, a Bound UID double-debited from Pod+ledger,
missing/largest-pod runtime component/role/backing row or wrong metadata model, under-bounded foreign or
controller-created workloads/webhooks, gateways/executors, writable foreign `hostPath`, and rollout or
migration overlap that exceeds
capacity. Each must fail with the specific offending resource/capability while independent observers show
**zero writes**: no SSA, reservation CAS, Binding, authenticated delete, host/provider/backing allocation, or
completion record, and no owned object's `resourceVersion` changes. A preflight that runs after the first
mutation is invalid.

The `ValidatedLiveTarget` carries the inventory/object-set fingerprint, relevant `resourceVersion`s,
scheduler CAS version, normalized-execution/runtime-storage witnesses, and complete typed-action domain. It
is single-use and authorizes every mutation continuation rather than only SSA. In this host-precursor phase,
the freshly observed mandatory Lease names the bootstrap host as the sole reconciler holder; the Phase-22
handoff later requires release plus a fresh resourceVersion showing no holder on that still-present Lease
before the in-cluster singleton may acquire it.
The managed workload-admission/RBAC boundary admits only that Lease holder plus
the Kubernetes controllers realizing its approved objects. An uncoordinated writer outside that boundary is
honestly runtime-checked residue: a fingerprint change before enactment causes re-observe/replan, and a target
whose writers cannot be bounded is refused rather than claimed capacity-safe.

**The representative reconcile corpus (Phase-0-pinned, §M.7 concrete corpus).** The gate's applied service
set is the committed fixture `test/live/fixtures/reconcile-corpus/` — a subset of the Phase-9 byte-for-byte
golden corpus (`test/golden/render/` service specs, referenced by their golden IDs, never a freshly
hand-picked spec) — and it MUST span, with each kind exercising a *live readiness transition that is not
instantaneous*: (i) at least one Deployment whose container image is pulled from the Phase-15 in-cluster
`distribution` registry and whose readiness probe carries a **non-zero `initialDelaySeconds`** (so
rollout-complete cannot be true at apply time and the registry dependency is actually exercised by a running
pod); (ii) one StatefulSet or DaemonSet `OnDelete` transition with at least two ordered slots; (iii) one Job
with provisioned success and backoff-exhausted completion variants whose terminal Pod is observed retained
and charged (no live completion persistence yet); (iv) at least one object that reaches a
`Ready`/`Available` status after apply; and (v) at least one CustomResource whose `status` transitions from
absent/unhealthy to healthy after apply. The scheduler-role Pod/config/ledger/admission system is itself part
of the corpus and must pass `BootstrapCapacitySchedulerReady`, bootstrap-controller UID cutover, and
`ManagedCapacityReady` before the guarded Deployment. The corpus, its
golden-ID manifest, and the committed hand-authored expected-action table (below) are authored and committed in
**Phase 0 before `Reconcile.hs` exists** (§M.1 oracle-pinning).

**Committed seeded mutants the gate MUST turn red (§M.2).** The gate re-runs against a committed mutant set
and requires each to go red: (a) **`waitForReady = pure ()`** (dropped-effect operator) — must fail against
the never-ready red-path fixture below; (b) a **generation-label-stamped-after-diff** mutant whose re-run
rewrites a per-run `amoebius/owner` generation label the diff ignores — must be caught red by the external
apiserver `managedFields`/`resourceVersion`/label comparison, not the engine's self-report; (c) a
**delete-from-owner-label-alone** mutant that deletes an unlabeled/foreign-generation object or retained
terminal Pod without typed authorization — must fail Sprint 16.3; (d) a
**bind-before-reservation-CAS** mutant — must fail scheduler-ledger auditing; and (e) a
**healthy-CR/over-bound-child** mutant whose operator reports healthy while its
actual child exceeds the provisioned resource/PVC/rollout envelope — must prevent convergence after child
enumeration. A committed **never-ready red-path fixture** `test/live/fixtures/reconcile-corpus-never-ready/`
(one Deployment whose probe never passes) MUST turn the convergence suite red on the *honest* engine too
(convergence is never declared), foreclosing an immediate-return `Wait.hs`.

**The external apiserver reader (§M.5/§M.6 measurement locus).** All "no-op / byte-stable / converged"
verdicts are read by a distinct apiserver client (a `kubectl get -o json` / client-go reader) that is **not
the reconciler and shares no diff/fold code with it**. Immediately before and after the re-run it snapshots
every owned object directly from the apiserver and asserts, per object, that `resourceVersion`,
`managedFields`, and the full label/annotation set are **byte-identical**, and that the `amoebius/owner`-labeled
object set is unchanged. The reconciler's self-reported "0 mutations, 0 prunes" is corroborating evidence
only, never the passing condition. Independent readers also assert byte-stable scheduler records/CAS version,
no new Binding request, no Job-completion object/version exists in this pre-gateway phase, the same bootstrap
host Lease holder/resourceVersion, and no host-process/device mutation.

## Doctrine adopted

- [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  — **the apply/reconcile engine.** This phase realizes scoped SSA, the amoebius scheduler-role CAS/Binding
  protocol, kind-indexed and staged execution actions, authenticated dependency-gated deletion, the pure and
  simulated Job completion/cleanup state machine, live terminal retention, and readiness observed from live
  state. Durable Job completion/cleanup first runs live in Phase 25; rollback and the release ledger stay deferred.
- [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed)
  — **desired is the validated identity index of `renderAll(provisionedSpec)`, observed is live inventory, and
  actions are typed.** `renderAll` retains the canonical `[K8sObject]` result; a separate pure
  `validateAndIndexRenderedObjects` checks source/object identity and duplicate freedom before diff. Desired
  state is recomputed; actual Pod UIDs/process IDs, owner chains, reservation records, completions, and physical
  allocations are observed to authorize transitions, never treated as another desired source.
- [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects)
  — **the typed manifest model** (the pure renderer half): this phase *consumes* the Phase-9 pure, total
  private per-source `renderSourcePrivate` projections through Phase 9's exact deployment-global `renderAll` owner union. The
  `[K8sObject]` list is byte-for-byte the value `--dry-run` previews; its separately validated identity index
  is the desired map. An unchecked `ServiceSpec`, duplicate `KubernetesObjectId`, or emitted/source identity
  mismatch cannot reach diff.
- [`resource_capacity_doctrine.md §8`](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-at-decode-cross-checked-at-runtime)
  — **declared at decode, cross-checked at runtime.** Immediately before mutation, this phase re-observes
  CPU/memory/local-ephemeral capacity, pod/CNI/CSI slots, mapped files/etcd logical quota, disjoint
  durable/object-store/migration/native-host-cache pools, admission/executor pods, planned execution slots,
  authenticated observed execution identities, state-indexed scheduler records, role-routed runtime storage,
  and accelerator
  devices/profiles/raw-reserved-allocatable plus current-free VRAM and
  `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch holds,
  and refuses a stale or false provision witness with zero writes.
- [`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
  — **the runtime enactor: the reconciler observes, never sleeps.** The wait-for-ready this phase builds is
  the runtime enactor of a readiness edge — the live condition is read from the object, never assumed by a
  fixed sleep.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — **the control-plane singleton.** The reconciler is, at steady state, run by the in-cluster singleton — a
  Deployment `replicas=1`, stateless (no PVC), single-writer authority delegated to k8s/etcd through its
  mandatory `Lease`, **no bespoke election**. This phase drives the reconciler from the host binary
  as a precursor; standing it up *inside* the singleton is Phase 22.
- [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **rendering never touches live infrastructure.** The boundary this phase honors from the other side:
  the `renderAll`/plan/`--dry-run` path stayed cluster-free through Phase 11, and **apply is the first live step** — so
  live prerequisites (a reachable cluster, credentials) belong here, never on the render path.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — the applied `[K8sObject]` set is emitted from the Haskell source of truth and **never committed**; what
  reaches the cluster is generated at apply time, not a checked-in manifest.
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  — **Register 3** (live infrastructure): the register this phase's gate reaches; and
  [`§4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  the per-run proven/tested/assumed ledger the live convergence emits (no skips, fail fast; the scratch
  namespace is torn down leak-free).

## Sprints

## Sprint 16.1: Deployment-global desired state + authenticated live execution/action plan 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/{Preflight,Reconcile,Diff,Actions,Authority}.hs`,
`src/Amoebius/Execution/{Observe,Normalize,RuntimeStorage}.hs`, and
`src/Amoebius/Scheduler/Ledger.hs`, plus `src/Amoebius/Storage/ScalingAction.hs` (fresh storage observation,
validation, and state-indexed action token) — target paths, not yet built.
**Blocked by**: Phase 9 (`renderAll` and the keyed owner union), Phase 14 (live cluster and observed
inventory), Phase 15 (in-cluster registry).
**Independent Validation**: a fresh snapshot produces exactly the committed
`test/live/fixtures/reconcile-corpus/expected-actions.json`, authored before the planner. It includes the full
object-action and `ValidatedExecutionTransitionAction` domains, not merely add/update/prune names. All
one-field negatives fail before any apiserver, ledger, Binding, host, provider, or object-store write.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Make desired state the separately validated identity index of the exact Phase-9
`renderAll provisionedSpec :: [K8sObject]` owner union; make observed state a coherent
snapshot of Kubernetes objects, actual Pod/process identities, scheduler records, completions, and physical
allocations, including ledger-only host reservation identities; and mint only the typed actions justified by
the whole transition. No planned slot is accepted as
a live identity, no object label alone is a mutation capability, and no preflight module imports a writer.

### Deliverables

- `renderAll → validateAndIndexRenderedObjects → observeInventoryAndObjects → authenticateExecutions → normalizeCommitments →
  deriveTransitionEnvelope → validateProvisionWitness → planActions`. The desired map proves exact
  `KubernetesObjectId` ownership across service and deployment-global projections and preserves each source's
  `Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover | AfterManagedCapacityReady` activation. The observed execution map
  proves its key equals embedded `PodUid | HostProcessInstanceId | HostReservationId`, checks protected
  provenance and the complete kind-indexed owner/supervisor chain, and preserves every same-slot
  predecessor/replacement UID and ledger-only host row.
- A host-aware observed identity union: `KubernetesPod PodUid | HostProcess HostProcessInstanceId |
  HostReservation HostReservationId`. Host `Reserved`, no-process `LaunchInFlight`, and post-process
  retained-artifact rows remain charged under the ledger-only arm; process-observed `LaunchInFlight` enters
  `HostLaunchRecovery`, and Running/Draining exact-join the process and reservation once.
  Missing, duplicate, or process-fabricated ledger-only identities reject.
- A scheduler-ledger join over full
  `Reserved | BindingInFlight | Bound | Terminating | TerminalRetained` records and
  resourceVersion/CAS version. Normalize Pending API-only, Reserved/BindingInFlight once, joined Bound/Terminating,
  Terminal retained, state-indexed absent-Pod ledger recovery, and host rows exactly once.
  Missing/unclassified-orphan/wrong-state/mismatched records and observed+
  ledger double debit have no `ValidatedLiveTarget` constructor.
- Node runtime accounting that rederives planned/observed metadata shapes, maps components to
  `KubeletNodefs | CriRuntimeRoot`, resolves the selected filesystem layout, combines disjoint
  `ImageContentRoot | CriRuntimeRoot` image components, and groups aliases once per backing. Pending has no
  observed runtime row; Reserved uses planned ledger demand; Bound/Terminating and retained Terminal use the
  observed Pod UID row.
  Binding recovery is state-sensitive: unknown/unbound `BindingInFlight` remains planned-only, while an
  exact-node `ConfirmedBound PodUid` immediately derives the observed Pod-UID runtime row and exact-joins it
  once with the still-BindingInFlight reservation; the later repair CAS changes state, not capacity.
- A complete `ValidatedLiveTarget` constructed from one `ObservedLiveResourceSnapshot`: mandatory whole
  `ObservedInventory`, exact budget-keyed storage-scaling snapshots, optional cloud observation, shared
  snapshot fingerprint, object/resourceVersions, ledger CAS version,
  exact mandatory-Lease identity/bootstrap-holder/resourceVersion readback, normalized commitment and
  runtime-storage witnesses, Job completion inventory, render-activation/domain equality, and exact action-
  domain witness. Its storage-scaling map exact-joins every Phase-7
  `ProvisionedStorageScalingEnvelope` to a complete `ObservedStorageScalingSnapshot`, total
  `planStorageScaling` result, backing-specific capability, immediate-snapshot recheck, and fresh
  `SingleUseStorageScalingActionToken`; a concrete transition is reconcile-time state, never a field of
  `ProvisionedSpec`. The provider observation is transition-indexed: host-only `NoChange`, retained-carve,
  and verified-migration arms carry `StorageScalingCloudObservation.NotRequired`, while only
  `CreateProviderCapacity` can carry the `Required ObservedCloudInfrastructureSnapshot` arm. Execution
  actions cover `NoOp`,
  kind-indexed Pod-controller apply, the three serial OnDelete stages,
  host stop/start authorizations, removed-controller prune, Job completion write/terminal cleanup/completed
  no-op, plus owner-authenticated ordinary object actions. Completion/cleanup constructors additionally
  require the provisioned gateway capability, which is absent from the Phase-16 live environment. Every
  mutating constructor carries only its scoped capability, and none can be minted for a non-holder.
- Preserve the operator child-admission and migration envelopes: admission/quota policy must be Ready before
  a CR action; observed children are independently normalized after health; storage/registry/schema migration
  actions retain old+new+workspace/temp/WAL until verified cutover. Phase 16 owns only the generic
  storage-scaling observation/validation/token boundary: Phase 17 supplies the retained-carve and verified-
  migration enactors, and Phase 30 supplies the cloud provider-capacity enactor. Durable backing is never
  generic prune.
- A mechanical no-release-store/no-write preflight boundary: AST/import lint over the modules above, plus a
  runtime observer proving no stored-desired-state read/write. Durable Job-completion reads are explicitly
  represented in the planner interface as observed execution state, never a desired manifest store; this
  phase's live inventory requires that gateway-backed arm to be absent and exercises it only through the
  pure/fake/IOSim boundary until Phase 25 supplies the live gateway.

### Validation

1. The deployment-global `[K8sObject]` list equals its Phase-9 golden; the separately validated desired map and
   action plan equal independently authored fixtures. Seeded duplicate object identity, source/emitted-identity
   mismatch, source/object activation-stage mismatch, generic-SSA-over-full-list, missing global scheduler
   object, cached observation, and action-domain omission mutants
   turn red. A Register-1 planner fixture with modeled observed completion still renders the pure Job baseline
   but plans `CompletedJobNoOp`, proving enactment is not a blind render-list apply; the live fixture instead
   plans terminal retention because no gateway/readback exists yet.
2. Execution/ledger negatives cover missing or spoofed annotations, wrong Deployment ReplicaSet hop,
   wrong direct controller kind/resourceVersion, map-key/embedded-identity mismatch, planned-slot-as-Pod-UID,
   terminator/replacement UID collapse, unclassified orphan record, missing reservation, wrong state/node/template/
   generation/axes, Bound Pod plus ledger double debit, reservation-only omission, and an incorrect terminal
   released/retained partition. Positive recovery fixtures cover absent-Pod rows in every closed ledger state
   and prove each remains charged until its state-specific CAS. Host negatives cover omission of Reserved/LaunchInFlight/retained-artifact
   `HostReservationId`, use of a fake process id for a ledger-only row, and double debit after process join.
   Exact-fit controls debit each identity once.
3. Runtime-storage negatives cover component drop/role swap, model ownership overlap/hole, Unified alias
   double-debit/drop, SplitRuntime one-byte-short kubelet-nodefs and CRI imagefs/containerfs backings,
   SplitImage routing mismatch, Pending with a node row, Reserved missing its planned debit, and Bound with
   both planned and observed rows. A confirmed-bound-but-still-BindingInFlight fixture must use the observed
   Pod-UID row; planned-only omission and planned+observed double-debit mutants both turn red. Exact fits succeed.
4. Retain the full one-short capacity corpus for CPU/memory/logical ephemeral, pod/CNI/CSI, API/etcd/mapped
   files, OCI/snapshot/workspace identities, durable/object/native-cache geometry, controller/webhook/gateway/
   executor/migration peaks, and CUDA/VRAM/Metal holds. Every failure exposes no `ValidatedLiveTarget`, and
   independent observers prove zero writes on every mutation surface.
5. Mutate any tracked object resourceVersion, scheduler CAS version/entry, Pod UID/owner chain, runtime
   backing identity, storage-scaling allocation/quota/fingerprint, content/snapshot set, device-free value,
   peer edge, Lease holder, or Lease
   resourceVersion after validation. The final recheck
   consumes/discards the token, makes zero writes, and restarts observation; a stale-token mutant turns red.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 16.2: Scheduler bootstrap + state-indexed reservation/Binding + typed enactor 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/{Apply,Enact}.hs`,
`src/Amoebius/Manifest/Authority.hs`,
`src/Amoebius/Scheduler/{Loop,Placement,Reservation,Recovery,Binding,Readiness}.hs`, and
`src/Amoebius/Admission/ExecutionIdentity.hs`, plus `src/Amoebius/Storage/ScalingDispatch.hs` — target paths,
not yet built. The scheduler role is an entry
point of the existing amoebius binary/image, not a second implementation or kube-scheduler plugin.
**Blocked by**: Sprint 16.1.
**Independent Validation**: the host holds the mandatory reconciler Lease before mutation;
`BootstrapCapacitySchedulerReady` precedes the finite bootstrap-controller cutover, every old UID is
absent/released and every replacement reservation-joined before `ManagedCapacityReady`, and only the latter
precedes any general guarded controller action. Two concurrent candidates cannot reserve the same residual;
crash after reserve, restart, and Binding failure recover idempotently. Ordinary object actions retain correct
SSA field ownership.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective

Build the stateful scheduler and generic typed-action dispatcher. Scoped ordinary-object actions may use SSA;
all other effects must consume their dedicated capability. The scheduler must authenticate, reserve by CAS,
and then Bind, with its own demand and bootstrap dependency represented and observed. The host precursor must
hold the same provisioned mandatory Lease that the Phase-22 singleton later receives by an observed handoff.

### Deliverables

- Bootstrap authority and ordering from `ProvisionedMandatoryReconcilerLease` plus
  `CapacitySchedulerSystemDemand`: a cold-start token may create only the derived control-plane Namespace and
  exact Lease, execute only typed acquire/renew actions under the bootstrap-host holder identity, and read the
  exact holder/object UID/resourceVersion successor back before any non-authority write. Present-state actions
  CAS the expected resourceVersion; every attempt consumes its fresh observation-bound token and reserves its
  exact `EtcdChurnBudget` projection until a post-attempt observation commits or releases that debit. A
  read-only scheduler preflight then mints a scheduler-system-only token and creates
  `amoebius-capacity-scheduler`, exact `ResourceQuota pods=1`, CRD/config/root, the complete pinned scheduler
  Deployment, and RBAC restricted to the enumerated bootstrap add-on cutover. Its sole default-scheduled Pod
  uses the Phase-15 side-loaded/preloaded amoebius image (so it does not depend on the registry controller it
  must cut over), has unique-node affinity, and a static owner row merged with the ledger fold (equal shared image extents
  deduplicate, compute/slots add). Exact active generation/config/root readback mints
  `BootstrapCapacitySchedulerReady`; the managed taint, general identity admission, and full Binding authority
  remain absent.
- Consume that bootstrap witness only to patch the exact observed distro/Phase-15 bootstrap controller set to
  `schedulerName=amoebius-capacity`. For every controller, re-observe the old default-scheduled UID absent and
  resource-indexed release, then the replacement UID reservation-joined, Bound, and Ready. Only the complete
  domain-equality witness authorizes installing the managed-node taint, general identity admission, and full
  exclusive Binding RBAC and revoking the cutover-only authority. Independent taint/admission/RBAC/writer-domain
  readback mints `ManagedCapacityReady`; discard the bootstrap snapshot and run a fresh whole-deployment
  preflight before exposing any general guarded action. Reject any other default-scheduled Pod that tolerates
  the managed-capacity taint. The canonical reservation serializer derives entry bytes; `maxEntries` derives
  from the maximum normalized Pod-UID population including retained terminal records, never an authored scalar.
- Scheduler loop for `schedulerName=amoebius-capacity`: authenticate Pod UID, protected annotations,
  kind-indexed owner chain, exact prior/desired source generation, child discriminator, and template digest;
  re-fold static/foreign/resident+whole-root+candidate state; CAS-create `Reserved`; CAS
  `Reserved→BindingInFlight`; submit Kubernetes Binding; confirm exact UID/node and CAS to Bound. Same-UID
  identical retry is idempotent; only Reserved can retarget; any generation/child/node/axis/model/backing
  mismatch rejects.
- Identity admission requires deployment/generation/source/revision/reservation-template annotations and
  `amoebius-capacity` at CREATE, rejects their removal/change at UPDATE, validates the kind-indexed owner
  chain, and restricts writers to the provisioned controllers/scheduler. The sole default-scheduler bootstrap
  exception is structurally separate.
- Recovery: after crash/restart, re-read Pods and the aggregate root, reuse exact reservations, and keep
  BindingInFlight charged. `ConfirmedBound` repairs to Bound;
  `ConfirmedUnboundSameUidAndResourceVersion` or `PodAbsent`
  may release; `Unknown` retries observation and never unreserves on an error/timeout. Bound/Terminating
  records are never deleted merely because the scheduler restarted. Terminal/GC release retains the exact
  witnessed axes.
- A dispatcher for every `ValidatedExecutionTransitionAction`. `ApplyDesiredPodController` preserves the
  exact controller-kind policy. `SerialOnDeleteStart/Resume/Advance`, host stop/start, Job completion/cleanup,
  and prior-controller delete are sent to their own enactors; Job completion/cleanup dispatch additionally
  requires the gateway capability and therefore cannot run in the live Phase-16 gate. `NoOp` and
  `CompletedJobNoOp` cannot reach an effect interface.
- A storage-scaling dispatcher that accepts only a `ValidatedStorageScalingAction`, immediately rechecks its
  exact observed snapshot, atomically consumes the plan-id-indexed `Fresh` token, and dispatches only the
  transition-indexed capability. `NoChange` cannot reach a mutation interface; retained-carve allocation and
  verified migration are abstract effect arms supplied in Phase 17, while provider-capacity creation also
  consumes the transition's exact validated cloud-action batch supplied in Phase 30. Every attempted effect
  requires post-attempt re-observation before success or retry, so a lost response cannot reuse a token. An
  ordinary host-only live target validates with no cloud account snapshot; absence becomes an error only when
  the planned transition actually selects provider capacity.
- Scoped SSA under `fieldManager=amoebius` only for an ordinary desired-object action. It declares the exact
  owned fields, does not GET-modify-PUT, and leaves fields owned solely by another manager untouched. The
  generation/owner/provenance annotations come from the desired object; they are never stamped after diff.
  The action must also carry `AfterManagedCapacityReady`; scheduler bootstrap and managed-authority objects
  have dedicated staged actions and can never enter this generic SSA path.

### Validation

1. Live scheduler tests cover config-not-Ready and digest-mismatch refusal, managed-taint bypass, invalid
   provenance/owner chain, two-candidate CAS race, same-UID retry, unbound retarget, wrong-RV conflict,
   crash-after-reserve/restart, bind failure, crash-after-Binding-before-Bound-CAS, and state mismatch. The
   external observer proves no Binding precedes a successful reservation CAS and every UID is debited once.
   The bootstrap suite separately covers scheduler-ready-with-managed-taint-present, general action from only
   `BootstrapCapacitySchedulerReady`, omitted bootstrap controller, old UID still present, missing replacement
   reservation, premature taint/admission/full-RBAC install, and a second default-scheduler exception; every
   case refuses. Crash/watch-gap injection at each cutover edge must re-observe and converge without duplicate
   debit or an unguarded scheduling interval. A stage-drop mutant that generic-SSA-applies the rendered taint/
   admission objects before add-on equality must turn red.
2. Seeded mutants — bind-before-CAS, numeric-add instead of whole-ledger refold, same-UID double debit,
   deletion of Bound on restart, default-scheduler managed-node bypass, and readiness that ignores config
   digest or collapses the two readiness witnesses — all turn red.
3. For a scoped SSA action, assert exact `amoebius` field ownership, drift correction of a declared field,
   and preservation of a foreign-owned field. Assert scheduler/ledger/host/delete/Job actions never enter the
   SSA module, and `NoOp` has no writer capability.
4. Lease races cover simultaneous bootstrap acquisition, lost acquire/renew response, stale resourceVersion,
   and attempted mutation without the exact bootstrap holder. Assert `ceil(renewalWindow/retryPeriod) <=
   maxRenewalsPerWindow` under the left-closed/right-open boundary rule. At every audit resourceVersion there
   is at most one holder; each attempted write consumes one fresh token and reserves exactly one etcd update/
   revision debit; ambiguous ownership retains that debit, emits no mutation capability, and re-observes.
5. Storage-scaling action tests run at the pure/fake boundary in this phase: stale allocation, backing,
   provider-quota, or fingerprint readback invalidates the action with zero mutation; `NoChange` exposes no
   writer; a retained or provider transition consumes exactly one token and dispatches only its indexed fake
   capability; and a lost response forces a fresh observation. Live retained and cloud mutations remain the
   Phase-17 and Phase-30 gates respectively.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 16.3: Staged execution transitions, Job terminal protocol, and authenticated deletion 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Execution/{SerialOnDelete,HostTransition,AcceleratorRelease,JobTerminal}.hs`
and `src/Amoebius/Manifest/Delete.hs` — target paths, not yet built.
**Blocked by**: Sprint 16.2.
**Independent Validation**: no stage can use evidence from the prior snapshot, no second serial Pod is
deleted before the expected replacement is Bound+Ready, no CUDA/Metal/host replacement starts before its
resource-indexed release, the abstract Job protocol cannot clean a terminal Pod before durable completion,
and the live pre-gateway gate retains that Pod rather than pretending persistence; no label alone can
authorize object deletion.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective

Enact the non-SSA members of `ValidatedExecutionTransitionAction` as explicit observation/effect stages.
Ownership labels are candidate discovery only. Every delete, resume, host start, completion write, and cleanup
must carry a fresh snapshot-bound capability proving its exact predecessor and dependency state. Job
completion write/readback/cleanup is implemented against the abstract effect boundary and validated in pure,
fake, and IOSim executions here; the live Phase-16 environment intentionally supplies no such capability.

### Deliverables

- Serial OnDelete for provisioned StatefulSet/DaemonSet controllers: `Start` deletes one witnessed old Pod;
  the next observation mints `Resume` only after that UID is absent and ordinary/CUDA release evidence is
  valid; the following observation mints `Advance` only when the expected replacement UID has the exact
  source/slot and is Bound+Ready. The provisioned order controls the next slot. No native automatic or
  parallel arm exists.
- HostProcess actions: stop or drain the exact observed process; start only with `NoPrior`,
  `OrdinaryAfterExit`, `CudaAfterDeviceRelease`, or `MetalAfterDrain`. CUDA evidence proves old owner absence,
  device-hold release and fresh per-device free VRAM. Metal evidence proves drain, process absence, allocation
  release and cache backing state. Fingerprint change invalidates the authorization.
- Job terminal protocol for both `Succeeded` and `FailedBackoffExhausted`: the closed model writes the exact
  `ProvisionedJobCompletionVariant` through an abstract provisioned object-gateway capability, observes
  matching digest/outcome/revision, and only after the cleanup deadline and exact scheduler release partition
  can construct terminal cleanup. Failed completion requires a new execution revision before rerun. A
  matching completion yields `CompletedJobNoOp`; a failed write retains the terminal Pod/ledger axes and
  retries safely. In the Phase-16 live cluster the gateway capability is absent, so the only inhabitant is
  `RetainTerminalAwaitingCompletionGateway`; the Pod, API bytes, logs/metadata, and ledger partition remain
  charged. Phase 25 performs the first live write/readback/cleanup trace.
- Authenticated object/controller deletion: build candidates from the live prior-owner set, then require
  structural owner, deployment/generation, object identity, resourceVersion, desired/prior union, retention,
  and dependency equality. `PruneRemovedPodController` uses its prior provisioned controller capability.
  Durable backing and unknown/foreign objects have no generic delete arm.

### Validation

1. The linux-cpu serial live test proves delete-one → observe absence/release → resume → observe expected replacement
   Bound+Ready → advance. Seeded skip-observation, delete-two, wrong replacement UID/slot/source, advance-on-
   Ready-but-unbound, and stale-fingerprint mutants turn red. The CUDA serial release arm runs against the
   deterministic observed-device model, not nonexistent GPU hardware in this phase.
2. Register-2/2.5 transition tests cover ordinary host exit, CUDA device holds/free VRAM, and Metal drain/
   allocation/cache release; one missing release component and one stale observation reject before start.
   CUDA/Metal live substrate proof remains owned by their substrate-specific phases.
3. Register-1/2 and Sprint-16.5 IOSim Job tests cover all-success and backoff-exhausted failure waves,
   completion-write failure, wrong digest/outcome/revision, cleanup before persistence/deadline,
   retained-axis partition, restart after modeled persistence, and no-rerun until new revision. In the live
   Phase-16 run, an independent apiserver observer proves the terminal UID remains, no Job-completion object is
   written, and no delete occurs. The first live object-store/apiserver persist-before-delete proof is the
   Phase-25 gate.
4. Remove a service and prove only snapshot-authorized objects/controllers disappear. Unlabeled, spoofed
   label, foreign generation, changed-resourceVersion, retained storage, active serial predecessor, and
   terminal-before-completion fixtures survive. The `delete-from-owner-label-alone` mutant turns red.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 16.4: Wait-for-ready + the idempotent-convergence gate (re-run no-op) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Wait.hs`, `test/live/ReconcileConvergeSpec.hs`,
`test/live/SchedulerReservationSpec.hs`, `test/live/SerialOnDeleteSpec.hs`, and
`test/live/JobTerminalRetentionSpec.hs` — target paths, not yet built.
**Blocked by**: Sprint 16.3, Sprint 16.2.
**Independent Validation**: the representative corpus observes bootstrap scheduler readiness, complete
bootstrap-controller cutover, and full managed authority before guarded Pods; then a non-instantaneous
Deployment, serial replacement Bound+Ready between deletions, CR health plus child conformance, and terminal
Job retention without a gateway. The immediate rerun has byte-stable objects and ledgers and no
Binding/host/object-store/delete effect. A never-ready fixture and dropped-wait mutant turn red.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`, `documents/engineering/readiness_ordering_doctrine.md` (the §6 runtime-enactor claim gains its first amoebius validation), `DEVELOPMENT_PLAN/README.md` (flip the Phase-16 status when the gate passes).

### Objective

Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
(wait-for-ready) and [`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
gate every action continuation on its live postcondition (never a fixed sleep), then prove the whole engine
idempotent — a re-run of the same deployment-global `renderAll` result plus the newly observed state plans
only `NoOp` plus the unchanged live terminal-retention decision (or `CompletedJobNoOp` in modeled/future
gateway-backed state) — and emit a
Register-3 proven/tested/assumed ledger, tearing the scratch namespace down leak-free
([`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)).

### Deliverables

- Wait-for-state: `BootstrapSchedulerStage` yields `BootstrapCapacitySchedulerReady` and precedes only finite
  bootstrap-controller patch actions;
  old UID absence/release plus replacement reservation/Ready equality precedes managed taint/admission/full
  Binding RBAC under `AfterBootstrapAddonCutover`; and `ManagedCapacityReady` unlocks
  `AfterManagedCapacityReady` general guarded controller actions. Then controller
  rollout, Pod Bound+Ready, object Ready/Available, CR health, process/device release, completion persistence,
  and cleanup are read from their authoritative live sources when those later capabilities exist. In this
  phase's live gate, terminal Job retention is read from the apiserver/ledger and the persistence/cleanup arms
  are unavailable. No `threadDelay` substitutes for observation.
  For each supported CR, its child-envelope
  admission/quota policy is Ready before CR apply and the live webhook Deployment's image/resources/replicas/
  rollout normalize exactly to `admissionExecution`; healthy status is followed
  by controller-owner enumeration of actual child Deployments/StatefulSets/Pods/PVCs and an independent
  normalization proving requests, limits, replica/rollout overlap, and storage conform to the provisioned
  child envelope. Unknown or over-bound children prevent convergence.
- The convergence battery over the pinned corpus: enact the exact `renderAll`/action plan → observe scheduler
  bootstrap/cutover/full-authority sequence → observe reserve/Binding and workload readiness → complete the
  serial stages in order → observe and retain the terminal Job →
  re-observe and rerun. The rerun asserts **zero effects** on all mutation surfaces and only typed no-op
  actions. Independent readers compare apiserver resourceVersions/managedFields/labels, reservation records
  and CAS version, absence of any Job completion object, the retained terminal UID, mandatory Lease holder,
  and host/device state. The red-path fixtures/mutants
  (never-ready Deployment; `waitForReady = pure ()`; scheduler wrong config digest; serial advance before
  replacement Bound+Ready; generation stamped after diff; over-bound CR child) MUST go red. The CR attempt is rejected at admission, leaves no child
  object/PVC allocation, and convergence fails/rolls back the CR; post-ready enumeration is not allowed to be
  the first detector. A
  Register-3 ledger records the live convergence, marking the release-ledger/rollback residue UNVERIFIED
  (deferred).

### Validation

1. `cabal test reconcile-converge scheduler-reservation serial-on-delete job-terminal-retention` is green on
   the linux-cpu `kind` corpus. Bootstrap readiness, complete controller cutover, and
   `ManagedCapacityReady` occur in order before the first guarded Pod; every
   Binding follows a successful reservation CAS, the serial second deletion follows replacement Bound+Ready,
   the terminal Job remains observed and charged with no completion/delete effect, and CR children conform. The immediate
   rerun is byte-stable and effect-free by independent observers. After that evidence is captured, the
   elevated test harness destroys the run-scoped scratch namespace and sweeps its ledger records; this
   postflight is not represented as successful Job terminal cleanup and proves no persistence ordering claim.
2. The forbidden-symbol lint covers
   `src/Amoebius/Manifest/{Preflight,Reconcile,Diff,Actions,Authority,Apply,Enact,Delete,Wait}.hs`,
   `src/Amoebius/Scheduler/*.hs`, and `src/Amoebius/Execution/*.hs`; it rejects `threadDelay`, aliases, and
   clock-polling busy-waits as readiness gates. Every red-path fixture/mutant above turns the suite red.
3. Two simultaneous CR child creates cannot race past namespace quota, and two simultaneous scheduler
   candidates cannot race past ledger residual. Both leave zero over-allocation. A compile/decode negative
   proves two owner envelopes cannot share one `ControllerEnvelopeNamespace`.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 16.5: Register-2.5 reconciler convergence under simulated faults 📋

**Status**: Planned
**Implementation**: `test/sim/{ReconcileSim,SchedulerSim,ExecutionTransitionSim}.hs`, driving the real
Manifest/Scheduler/Execution modules above on the Phase-11.4 `io-classes` `Env` — target paths, not yet built.
**Blocked by**: Sprint 16.4 (the built typed-action engine); Phase 11 Sprint 11.4 (the `io-classes`
seams + the modeled apiserver).
**Independent Validation**: `IOSimPOR` interleaves object resourceVersion conflicts, scheduler ledger CAS
races, bootstrap-Lease acquire/renew ambiguity, crashes/watch gaps across both scheduler-readiness stages,
crash-after-reserve, Binding failure, restarts, serial stage changes, completion-write failure, and external
mutation inside critical sections. Every schedule either converges to typed no-op or fails closed without
overlapping writers, an unguarded Pod, overspend, or premature deletion; counterexamples replay by seed.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md` (Phase-16 status backlink),
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits):
validate the *built* reconciler/scheduler/staged-action schedules under injected faults
**in-process and deterministically replayable**, before the Register-3 live gate — closing the code-schedule gap
the pure-value tests and the live gate each leave open ([`chaos_failover_doctrine.md §10`](../documents/engineering/chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)).

### Deliverables

- The real action loop under `IOSimPOR`, with ≥200 schedules per fault class (or exhaustive stated
  preemption depth) and `cover`/`classify` proving faults land inside Lease acquire/renew, bootstrap scheduler
  readiness, add-on cutover/full-authority transition, SSA, reservation/Binding, serial, completion/cleanup,
  delete, and wait sections rather than only between iterations.
- Safety invariants on every trace: at most one observed Lease holder and no non-authority write without the
  exact holder; no general guarded action from `BootstrapCapacitySchedulerReady`; no full authority before
  complete old-UID release/replacement joins; one reservation debit per Pod UID; no Binding before successful CAS; no
  Bound record unreserved on restart; no next serial delete before replacement Bound+Ready; no host start
  before release; no terminal cleanup before durable completion/deadline; no delete from label alone; and
  unchanged snapshot tokens cannot be reused after any observed-state transition.
- Committed mutants for lost Lease/resourceVersion retry, mutation without holder, collapsed scheduler
  readiness stages, premature managed taint/full RBAC, bind-before-CAS, same-UID double debit, crash recovery
  dropping Bound, sleep-gated readiness, serial stage collapse, completion cleanup-before-persist, label-only
  delete, and cached observation. Every mutant must turn red.
- A Register-2.5 proven/tested/assumed ledger — the reconciler upholds convergence + fail-closed under the
  modeled schedules and faults; honest limit: modeled-apiserver fidelity is **assumed**, discharged by the
  Sprint-16.4 Register-3 live gate.

### Validation

1. `cabal test reconcile-sim scheduler-sim execution-transition-sim` is green at the documented exploration
   bound. Coverage proves every fault enters its critical section; every safety invariant holds; every
   committed mutant is caught; and each discovered counterexample replays identically under its seed.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/manifest_generation_doctrine.md` — §5's typed SSA/scheduler/staged-action/delete/
  wait engine flips from design intent to delivered with the Register-3 ledger attached; §6's
  planned-vs-observed, scheduler-ledger, and `renderAll` model gains its first validation. Keep §6.1's content-addressed
  release ledger and §5's rollback explicitly as the deferred content-store-phase residue.
- `documents/engineering/readiness_ordering_doctrine.md` — the §6 runtime-enactor claim (observe, never
  sleep) gains its first amoebius proof.
- `documents/engineering/daemon_topology_doctrine.md` — record that Phase 16 drives the reconciler from the
  host binary; the §3 singleton that *owns* it (Deployment `replicas=1`, delegated single-instance, no
  election) is stood up in Phase 22.
- `documents/engineering/generated_artifacts_doctrine.md` — note that the applied `[K8sObject]` set is
  generated at apply time and never committed.
- `documents/engineering/resource_capacity_doctrine.md` — record the read-only pre-mutation live inventory
  cross-check and its zero-write failure path.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-16 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 16's gate substrate (linux-cpu) in the per-phase substrate
  map.
- `DEVELOPMENT_PLAN/system_components.md` — register the Phase-16
  `Manifest/{Preflight,Reconcile,Diff,Actions,Apply,Enact,Delete,Wait}`,
  `Scheduler/{Ledger,Loop,Placement,Reservation,Recovery,Binding,Readiness}`,
  `Execution/{Observe,Normalize,RuntimeStorage,SerialOnDelete,HostTransition,AcceleratorRelease,JobTerminal}`,
  and `Admission/ExecutionIdentity` modules plus their live/simulation suites.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  live-proof acceptance token: *converges and re-run is a no-op*, proven in Register 3)
- [overview.md](overview.md) — target architecture and the no-Helm / no-release-store reconciler posture
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 io-sim environment the reconciler is validated against in Sprint 16.5, before the Register-3 live gate
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §5 the apply/reconcile
  engine adopted here; §6 the reconcile state model; §2 the pure renderer consumed from Phase 9
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — §6 the runtime
  enactor (observe, never sleep) the wait-for-ready realizes
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — §3 the Deployment-`replicas=1`
  singleton (delegated single-instance, no election) that will own this reconciler in Phase 22
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §3 the invariant
  that rendering never touches live infrastructure; apply is the first live step
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the applied
  object set is generated and never committed
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 3 (live), §4 the per-run ledger
- [phase_09](phase_09_render_manifest_goldens.md) — the pure per-projection renderers and deployment-global
  `renderAll` owner-union goldens this phase enacts
- [phase_11](phase_11_boundary_fake_tool_harness.md) — the Register-2 fake-apply this phase replaces with real tools
- [phase_14](phase_14_midwife_bootstrap_kind.md) — the live single-node `kind` cluster this phase applies to
- [phase_15](phase_15_base_image_registry.md) — the in-cluster registry the applied workloads resolve images against
- [phase_22](phase_22_live_dsl_singleton.md) — the Deployment-`replicas=1` singleton that stands the reconciler up in-cluster
