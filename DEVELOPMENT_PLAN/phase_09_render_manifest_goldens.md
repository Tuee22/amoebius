# Phase 9: Pure `renderAll` + rendered-output goldens

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the pure, total `renderAll :: ProvisionedSpec -> [K8sObject]`, mapping Phase 8's
> unique identity-keyed private render sources to typed objects, and lock its emitted deployment object
> set byte-for-byte with rendered-output goldens — proving the by-construction manifest-safety invariants on
> the emitted objects in-process, before any cluster exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 8
capability→provider→shape binder gate passes and runs on **no substrate** (`none`) in **Register 1** — it
stands up no host and no cluster, only an in-process render-and-golden battery. Where a shape below is already
exercised in a sibling system (prodbox renders a slice of its object set from typed Haskell records to Aeson
and pins byte-for-byte dry-run goldens over a pure, no-process suite), that is **sibling evidence, not an
amoebius result**. This phase deliberately builds **only the pure `renderAll` half** of the manifest doctrine;
the action-driven reconciler that consumes it on a live cluster — driven by the control-plane singleton under
its mandatory Kubernetes Lease — is deferred to the live band
([Phase 16](phase_16_renderer_reconciler.md)).

## Phase Summary

This phase delivers the pure manifest renderer: the typed `K8sObject` model, the total function
`renderAll :: ProvisionedSpec -> [K8sObject]` that emits the complete whole-deployment Kubernetes object set from Haskell
ADTs serialized via Aeson — no Helm, no text template, no `values.yaml` — and the rendered-output golden
battery that locks that output and proves its by-construction safety. `renderAll` performs no I/O, reaches no
apiserver, and is total over the opaque, capacity/capability-checked `ProvisionedSpec` the Phase-8
bind/provision boundary produces. Phase 8 has already sealed a
`Map K8sObjectIdentity (ProvisionedRenderSource K8sObjectIdentity)`; `KubernetesObjectId` is only a
compatibility alias for `K8sObjectIdentity`, not a second identity type. Duplicate
`(apiGroup,apiVersion,kind,namespace,name)` sources cannot inhabit it, and Namespace, ResourceQuota, scheduler,
admission, RBAC, Lease, and CRD identities have one deployment-global source owner. This phase total-maps
each source through private `renderSourcePrivate` and serializes deterministic identity order; it does not
re-open list concatenation or decide ownership from rendered bytes.
Each source also carries a closed reconcile mode. Ordinary declarative fields may enter scoped SSA, but the
scheduler root-ledger's entries/CAS version and the mandatory Lease's holder/renewal fields are absent from
the generic apply projection and remain exclusively mutable through their typed actions; `renderAll` cannot
reset either live state machine.
Each source also retains its closed `RenderActivation` (`Immediate | BootstrapSchedulerStage |
AfterBootstrapAddonCutover | AfterManagedCapacityReady`). `renderAll` lists the complete desired object set
and never hides later-stage objects; Phase 16's typed diff/enactor filters actions by that sealed activation,
so managed-node taint/admission cannot be generically applied during the initial scheduler bootstrap.
The same serializer module is available only inside the amoebius package for Phase 15's
`BootstrapRegistryAction`: it can serialize the already provisioned registry/proxy source subset, but that
typed cycle-break exposes neither `renderSourcePrivate` nor a per-service render function to callers. The
public manifest facade exports `renderAll` only.
Raw execution cardinality/rollout, `PodRuntimeMetadataSource`, and
accelerator source/workload/coexistence maps are not renderer inputs. Ordinary objects project only the
`MaterializedExecutionInstance`s selected from private `ProvisionedExecutionEpochs`; the associated
Deployment rolling projection carries the exact checked pair with `maxSurge + maxUnavailable > 0`, so no renderer branch
can emit a zero-progress `RollingUpdate`;
the exact desired `ProvisionedExecutionController` arm selects Deployment, StatefulSet, DaemonSet, Job, or
host-process enactment and preserves only that kind's legal cardinality/policy. Prior-only controllers are
transition witnesses/actions and never render as desired objects. Every guarded Pod template copies admission-protected
deployment/generation/source/revision/reservation-template identity, absent `nodeName`, and
`schedulerName=amoebius-capacity`; the standard platform
projection also renders the independently provisioned scheduler/RBAC/config/reservation-CRD objects before
guarded controllers. Its own fully provisioned bootstrap Pod is the sole domain-equal
`schedulerName=default-scheduler` exception.
`ProvisionedKubeletRuntimeMetadataDemand`s remain capacity witnesses and emit no manifest scalar; and only
the renderable whole-device claim/affinity projection derived from `ProvisionedCudaOwnerDemand` reaches a
Kubernetes pod (`ProvisionedMetalOwnerDemand` remains host-tier). Thus the emitted object set
is a *value* the suite inspects end to end. The battery does two things: it pins the emitted `[K8sObject]`
**byte-for-byte** against a golden fixture (any change to the renderer's output is a red diff, never a silent
drift), and it asserts the **rendered-output-golden illegal states** directly on the emitted objects — an
unsafe manifest is not a value `renderAll` can return, so a golden test over the output proves the property with
no cluster. What is *not* here: snapshot-bound typed actions (including scoped SSA, staged delete/resume,
host actions, scheduler-ledger CAS, and Job completion/cleanup), wait-for-ready, drift-heal, and live
convergence — all deferred to [Phase 16](phase_16_renderer_reconciler.md); and
the `chain`/`[Step]` `--dry-run` plan render, which is [Phase 10](phase_10_chain_kernel_dryrun.md). This phase
locks the **`renderAll`** step of the pre-cluster spine.

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` render-and-golden battery
analogous to the Phase-5 decode battery and the Phase-4 `dhall type` corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `cabal test render-golden` is green against Phase-0-pinned oracles — the pure, total
`renderAll :: ProvisionedSpec -> [K8sObject]` emits, **for the concrete corpus** (the full Phase-8 provisioned output set:
every capability arm × both deployment shapes {`SingleNode`, `Distributed`}, enumerated explicitly in Sprint 9.3's
Deliverables and jointly covering every renderable `K8sObject` sum variant at least once), an object set the
**byte-for-byte** goldens pin exactly, and the three rendered-output-golden illegal-state properties hold
**non-vacuously** on the emitted objects. The goldens are authored and **committed in Phase 0** under
`test/manifest/golden/<deployment-id>.json` *before* `renderAll` exists, under a single pinned **canonical Aeson
encoding** (object keys lexicographically sorted, two-space indent, trailing LF, exactly one golden file per
deployment keyed by `ProvisionedSpec` id — so "drifts by a single byte" is unambiguous), and are **never regenerated
from the renderer's own output** (a golden regenerated from `renderAll` is not a test). The three properties, with
their predicates fixed: **(a)** every emitted pod carries a hardened `securityContext`, and its resource fields
  are an exact projection of the provision witness — every app/sidecar/init container has non-zero CPU, memory,
  and `ephemeral-storage` requests+limits; `ReadOnlyRootfs` renders
  `securityContext.readOnlyRootFilesystem: true`, while `WritableRootfs` renders false and its explicit
  allowance fits its own container and,
  with bounded shared disk volumes, the effective pod ephemeral request; every memory-backed volume's
  access/persistence resolves, its lifecycle epochs have one request carrier, unique resident volumes plus live
  working sets fit the effective pod request/limit, and possible charged accessors' limits fit; the effective
  envelopes are charged once; durable claims keep their checked StatefulSet slot/backing,
  `VolumePresentation`, required-usable and rounded-provisioned sizes; the content-digested image
  ref matches the selected OS/arch provision whose OCI-content/snapshot/import operands fit the node's
  layout-routed physical backing;
  and the
  named accelerator-owner container keeps the private provisioned full-offering integer extended-resource
  request/limit while the pod keeps required profile/topology affinity; no raw accelerator work map,
  coexistence policy, or `ProvisionedCudaOwnerDemand.epochs` map is copied into a manifest; and the
  `Observability` Prometheus container's CPU/memory request+limit exactly
  equals the version-pinned `MonitoringWorkBudget` cost derivation carried by its provision witness. That
  budget also carries the bounded scrape-sample rate, retention, structural
  `QueryWorkBudget`, TSDB/query cost-model versions,
  and StatefulSet claim/backing/presentation; the renderer copies the private TSDB usable peak through its
  filesystem/allocation witness into the exact rounded PVC/PV capacity/fsType/volumeMode and renders
  `--storage.tsdb.retention.time`, `--storage.tsdb.retention.size`, and the model-selected
  WAL/config settings from the same operands. Prometheus global and every rule-group effective evaluation
  interval exactly equal the interval used by that derivation, never a renderer default. Controller webhooks,
  object/registry/query gateways, Pulumi executors, and volume/registry/schema copy/verify Jobs are included in
  “every pod” and exactly project their private provisioned envelopes. ConfigMap/Secret/projected/token
  volumes exactly match the `KubeletMappedFileDemand`/API-object source inventory. Every rendered ordinary
  workload identity/revision/replica and volume/network mount comes only from a
  `MaterializedExecutionInstance` in the selected `ExecutionEpoch`; kubelet/runtime metadata bytes come only
  from `ProvisionedKubeletRuntimeMetadataDemand` and remain a capacity witness rather than an authorable
  manifest scalar. Control-plane
  quota/Event/Lease controls match the provisioned etcd logical model; **(b)** no
  backdoor/insecure ingress — concretely, no `Service` of
type `NodePort`/`LoadBalancer` outside the single declared edge service, every `HTTPRoute` parented to the
Keycloak-owned `Gateway`, and no bare `Ingress` kind anywhere; **(c)** every NetworkPolicy is default-deny plus
allow edges that **exactly equal** (set equality — no missing edge, no extra edge) the edge set an
**independent, test-side re-derivation from the declared dependency graph** produces, the reference side
authored by hand/spec in Phase 0 and *not* by reusing `renderAll`'s own connectivity fold. Non-vacuity is enforced
by the shape-completeness and non-zero-count assertions and by the committed safety/resource mutant battery
named in Sprint 9.3, each of which must turn the relevant **property** (not merely the byte diff) red. A **Register-1**
in-process check that runs on no substrate and contacts no infrastructure; it still emits the
proven/tested/assumed ledger, marking runtime enforcement UNVERIFIED (owned by the live band).

## Doctrine adopted

- [`namespace_layout_doctrine.md §2`](../documents/engineering/namespace_layout_doctrine.md#2-one-namespace-per-platform-capability--the-derived-set)
  — **one namespace per platform capability, derived never authored.** The render-golden battery asserts every
  emitted object lands in its doctrine-**derived** namespace and that a free-text or cross-capability namespace
  is not a value `renderAll` can emit — the rendered-output enactment that gates the namespace-layout foreclosure.
- [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects)
  — **the typed manifest model: `renderAll` is a pure, total function to objects.** Adopt the pure, total,
  cluster-free `renderAll :: ProvisionedSpec -> [K8sObject]` whose output is a value amoebius inspects before any
  object reaches a cluster; the record *is* the manifest, serialized via Aeson, with no intermediate template
  and no `values.yaml`. **Only the pure-render half is adopted here**; the apply/reconcile engine of that
  doctrine's §5 is the live-band [Phase 16](phase_16_renderer_reconciler.md) residue.
- [`manifest_generation_doctrine.md §3`](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible)
  — **best practice by construction: an unsafe manifest is not constructible.** The renderer emits a hardened
  `securityContext` on every pod, least-privilege per-workload RBAC, default-deny-plus-derived-allow
  NetworkPolicies, exact provision-derived CPU/memory/ephemeral-storage, bounded pod-local
  volume/writable/log-headroom, mapped files, durable/native-cache/migration, pod/CSI-placement identities,
  controller/admission/executor, and accelerator fields, and Secret objects that carry a
  Vault coordinate
  and never bytes — a manifest lacking any of these is not a value `renderAll` can return.
- [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **the load-bearing invariant: rendering never touches live infrastructure**, and its §4 decode →
  bind/expand → plan/resolve infrastructure → provision → `renderAll` → plan → dry-run spine (this phase locks the **`renderAll`** step). `renderAll` is a pure function of
  committed source that completes in-process with no apiserver, no credentials, no Vault; the byte-for-byte
  golden is a fixture of the renderer, and the rendered-output-golden validation locus catches a large share
  of the illegal-state catalog here, not at runtime.
- [`illegal_state_catalog.md §3.11`](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)
  (the unsafe workload — no resource limits, no hardened `securityContext`),
  [`§3.7`](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
  (accidental insecure / backdoor ingress), and
  [`§3.6`](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  (blocking / underived NetworkPolicy) — the three states realized here at the **rendered-output-golden**
  locus. Honors [`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — three layers of foreclosure: these are proven on the *emitted objects* in Register 1; the runtime-checked
  claim that the live cluster enforces them stays deferred to the live band.
- [`resource_capacity_doctrine.md §3.1`](../documents/engineering/resource_capacity_doctrine.md#31-the-systematic-provision-matrix)
  and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the canonical resource axes and the opaque `ProvisionedSpec` boundary this phase projects into typed
  Kubernetes objects; the renderer neither recomputes demand nor accepts an unchecked service value.
- [`platform_services_doctrine.md §9`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (east-west connectivity derived from the dependency graph; the single wild-ingress path) and
  [`§10`](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope)
  (every execution unit declares a complete resource envelope) — the *owners* of the connectivity and resource rules; this phase adopts
  their **rendering enactment** (the derived NetworkPolicy and exact provisioned resource fields on the emitted
  objects), not the rules themselves.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — generated artifacts are emitted from a Haskell source of truth and **never committed**: the rendered
  `[K8sObject]` set is never a checked-in deployment artifact; the byte-for-byte golden is a *test fixture*
  that pins the renderer, not a committed manifest.
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing) — **Register 1** (pure/golden,
  in-process, no cluster): the register this phase's gate reaches; and §4 — the per-run
  proven/tested/assumed ledger the battery emits, marking runtime-enforcement correspondence UNVERIFIED
  (owned by the live band).

## Sprints

## Sprint 9.1: The typed `K8sObject` model + Aeson serialization 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/K8sObject.hs` (the exhaustive typed `K8sObject` sum —
`Namespace` / `Node` / `Deployment` / `StatefulSet` / `DaemonSet` / `Job` / `Service` /
`PersistentVolume` / `PersistentVolumeClaim` / `StorageClass` / `Lease` / RBAC objects /
`NetworkPolicy` / `HTTPRoute` / `Gateway` / `ConfigMap` / CRD / typed CR instance /
`ResourceQuota` / `LimitRange` / validating- and mutating-webhook configurations /
`ClusterIssuer` / `Certificate` / Secret-reference), `src/Amoebius/Manifest/Types.hs` — target paths, not yet
built.
**Blocked by**: Phase 8 gate (the capability→provider→shape binder and final provision fold that construct the
opaque whole-deployment `ProvisionedSpec` and sealed render-source set this model renders from); Phase 5 (the GADT-indexed IR from which its unchecked
input is projected).
**Independent Validation**: the object model compiles under the pinned GHC 9.12.4; a hand-built object
round-trips through Aeson (`toJSON`/`fromJSON`) to an equal value, and its encoding matches a small
byte-for-byte golden — proving the record *is* the manifest with no template layer.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (Phase-9 backlink for the typed
object model), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
build the typed Haskell `K8sObject` model — every Kubernetes object amoebius emits as a typed record
serialized to JSON via Aeson, exactly the `object [...]` discipline the prodbox sibling already applies to its
supporting objects (*sibling evidence, not an amoebius result*) — so a manifest is a value, not interpolated
text.

### Deliverables
- A typed `K8sObject` sum covering the full deployment object set, each variant a Haskell record with an
  Aeson `ToJSON`/`FromJSON` instance; the record is the manifest — no `values.yaml`, no text template.
- The Secret variant carries a Vault coordinate (a reference), structurally admitting no literal secret
  bytes; the whole `SecretRef` / Vault model stays owned by the vault/PKI doctrine and is not restated.

### Validation
1. The model compiles on the pinned toolchain; a hand-built object round-trips through Aeson to an equal
   value and encodes to a byte-for-byte golden.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 9.2: Pure total `renderAll` + best-practice-by-construction 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Render.hs`
(`renderSourcePrivate :: ProvisionedRenderSource identity -> K8sObject`) and
`src/Amoebius/Manifest/RenderAll.hs`
(`renderAll :: ProvisionedSpec -> [K8sObject]` over the sealed unique source map and deterministic
serialization) — target paths, not yet built.
**Blocked by**: Sprint 9.1.
**Independent Validation**: totality is established by compiling `renderAll` and its transitive closure under
`-Werror=incomplete-patterns` and `-Werror=incomplete-uni-patterns` (a partiality grep does not establish
reachability or totality and is not sufficient), plus an **import-graph check** that no `IO`,
`unsafePerformIO`, or partial-`Prelude` name (`head`/`fromJust`/`!!`/`error`/`undefined`) appears in `renderAll`'s
transitive module surface. A QuickCheck property asserts the by-construction invariants hold on the emitted
`[K8sObject]` for arbitrary legal whole-deployment `ProvisionedSpec` values, and its generator is **not** near-constant:
it generates decoded inputs plus target inventories and retains only values constructed through the real
bind/provision boundary; it carries
`cover`/`checkCoverage` obligations (coverage failure is a hard test failure) forcing each capability arm, both
deployment shapes {`SingleNode`, `Distributed`}, and every renderable `K8sObject` sum variant to appear at a stated
minimum frequency — so the property demonstrably exercises the whole spec surface, not one happy-path shape.
An export-list check proves the public manifest facade exposes `renderAll` but not
`renderSourcePrivate` or any service-valued renderer; the internal serializer remains reachable only by the
whole-deployment implementation and the typed Phase-15 bootstrap-registry action.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (backlink §3 to the Phase-9 pure
renderer; keep the typed-action reconciler as the live-band residue), `documents/engineering/platform_services_doctrine.md`
(the rendering enactment of the §9/§10 rules), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §3`](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible):
implement the pure, total `renderAll` that emits the complete whole-deployment object set — including generated
operator installs (CRDs, controller Deployment, CR instances) as typed objects rather than upstream charts —
with every supported CR's replica/resource/PVC/controller fields exactly projecting its provisioned child
envelope. Deployment alone projects the checked nonzero-progress surge/unavailable pair; StatefulSet projects
partition-zero native serial or amoebius-staged OnDelete without feature-gated `maxUnavailable`; DaemonSet
projects exactly one positive Surge/Unavailable or staged OnDelete; Job projects exact completions,
parallelism, backoff, `restartPolicy=Never`, `podReplacementPolicy=Failed`, and the finite amoebius cleanup
model while omitting `ttlSecondsAfterFinished`. The safe shape is the
*only* shape it can return: hardened `securityContext` on every pod,
least-privilege per-workload RBAC, default-deny-plus-graph-derived-allow NetworkPolicies, required non-zero
CPU, memory, and `ephemeral-storage` requests+limits on every app/sidecar/init container; bounded disk-backed
scratch/cache volumes plus lifecycle-effective per-container private allowances fitting the pod ephemeral
request, with the closed root-filesystem arm projected exactly; access-/persistence-indexed memory-backed volumes with one reservation carrier per lifecycle epoch;
  private ordinary workload `MaterializedExecutionInstance`s selected from checked
  `ProvisionedExecutionEpochs`; platform-selected digested images whose provisioned content/snapshot/import peak fits the layout-selected node
  backing; exact durable StatefulSet claim-slot/backing/presentation/usable/provisioned sizes; derived
  kind-exact Deployment/StatefulSet/DaemonSet/Job fields, admission-protected execution provenance annotations,
  reservation-template digest, absent `nodeName`, `schedulerName`, exact namespace ResourceQuota, and the
  unique deployment-global scheduler-system/config/admission/taint/RBAC/root-ledger objects; derived
  full-offering accelerator-owner-container extended-
  resource requests/limits and affinity where applicable, expanded one uniform workload per immutable
  homogeneous offering class; and Vault-coordinate Secret references. Every mapped ConfigMap/Secret/
  downward-API/service-account-token source projects exactly once into its API object and pod volume, with no
  authorable byte aggregate. Every operator projection includes the provisioned child-envelope namespace,
  quota, webhook resources and readiness edge. Every private volume/registry/schema migration includes its
  exact replacement controls and provisioned copy/verify or DDL Job; source+target failure retention is not a
  renderer choice. ZooKeeper and Patroni objects project their provisioned member/child envelopes, volumes,
  retention, and failover controls exactly.
  The module surface contains no `BoundDeployment`, raw execution intent, `PodRuntimeMetadataSource`,
  `CudaOwnerDemand`, or `MetalOwnerDemand` input. Source/revision/ordinal equality and complete
  `ExecutionEpoch` derivation, `KubeletRuntimeMetadataDemand` costing, and accelerator source/policy equality
  and coexistence derivation remain sealed behind `ProvisionedExecutionEpochs`,
  `ProvisionedKubeletRuntimeMetadataDemand`, `ProvisionedCudaOwnerDemand`, and
  `ProvisionedMetalOwnerDemand`; `renderAll` consumes only their manifest-relevant private projections.
  For `Observability`, the renderer copies the already-derived Prometheus CPU/memory envelope, evaluation and
  TSDB cost-model versions, and `evaluationInterval` exactly into the workload and Prometheus/rule-group
  configuration. It also projects the provisioned monitoring claim slot/backing/presentation and rounded
  capacity into exact PVC/PV `capacity`, `volumeMode`, and fsType and projects retention time/size plus the
  model-selected WAL/config settings from the
  same `maxScrapeSamplesPerSecond`, `retention`, and structural query operands. It also renders Prometheus
  query concurrency/sample/timeout flags, a sole-routable query-admission proxy with the series/range bounds,
  and NetworkPolicy denying direct query API access. It never recomputes
  cardinality or storage geometry, substitutes a fixed request or PVC, or permits a shorter effective interval.

### Deliverables
- `renderAll :: ProvisionedSpec -> [K8sObject]`, pure and total (no I/O, no apiserver, no partial head),
  producing best-practice-by-construction objects. It maps Phase 8's sealed
  `Map K8sObjectIdentity (ProvisionedRenderSource K8sObjectIdentity)` one-for-one, proves every emitted
  object's identity equals its map key, and treats `KubernetesObjectId` as an alias only; shared identities
  already have one global source owner and output order is deterministic. The `ProvisionedSpec`, its service
  projections, and `renderSourcePrivate` are private; raw decoded, merely bound, or individual service values
  cannot call a renderer. `renderAll` is the sole public manifest function.
- A closed `RenderReconcileMode` projection that includes only immutable schema/initial fields for the
  scheduler root ledger and mandatory Lease. Ledger rows/CAS versions and Lease holder/renewal fields have no
  generic-SSA source path and are owned only by the corresponding typed actions in Phase 16.
- Exact preservation of each source's `RenderActivation`; the golden covers all four arms. The renderer emits
  the complete desired set irrespective of stage, while a companion partition oracle proves the later action
  planner can select only the identities active at a given readiness witness.
- An in-file honesty note: this is the render half only — the SSA/ApplySet apply, prune, wait-for-ready, and
  release ledger are the live-band [Phase 16](phase_16_renderer_reconciler.md) reconciler, run by the
  Deployment-`replicas=1` singleton under its mandatory Lease (no bespoke election).

### Validation
1. The `-Werror=incomplete-patterns`/`-Werror=incomplete-uni-patterns` compile and the import-graph check
   report no partial call and no `IO`/`unsafePerformIO`/partial-`Prelude` name reachable from `renderAll`; a
   QuickCheck property over arbitrary legal whole-deployment `ProvisionedSpec` values constructed through the real
   provision fold — with `cover`/`checkCoverage` obligations
   (hard-failing) that force each capability arm, both shapes, and every renderable `K8sObject` variant to fire at its
   stated minimum — confirms every emitted pod is hardened, every NetworkPolicy is default-deny + derived-allow,
   and every resource-bearing object exactly projects its checked CPU, memory, pod-ephemeral,
   per-container private allowance, bounded disk-/access-indexed memory-volume, selected-platform image
   content/snapshot metadata, mapped-source/API-object identity, durable presentation/allocation, pod/CSI
   attachment identity, admission/migration execution, and accelerator provisions, including the
   single-debit proofs; every supported CR exactly projects its kind-indexed finite child-pod/PVC/controller
   bound stored in its private provisioned controller source. Deployment `RollingUpdate` preserves its checked pair with at
   least one positive operand; StatefulSet uses native partition zero or staged OnDelete and never renders
   feature-gated `maxUnavailable`; DaemonSet uses exactly one positive Surge/Unavailable or staged OnDelete;
   Job preserves exact completions, **parallelism**, backoff, `restartPolicy=Never`,
   `podReplacementPolicy=Failed`, finite cleanup projection, and completion-ledger identity while rendering
   no `ttlSecondsAfterFinished`; and
   host-process rows emit no Kubernetes workload. Every guarded Pod template has exact admission-protected
   deployment/generation/source/revision/reservation-template annotations, absent `nodeName`, exact protected
   resource/volume/runtime fields, and the provisioned scheduler name; the unique fully
   provisioned scheduler bootstrap Pod alone uses `default-scheduler`, exact pods=1 namespace quota, and
   unique-node affinity under its cycle-break witness. Scheduler/RBAC/
   config/ledger objects are present before their consumers. No prior-only removed unit renders. Every
   `Observability` object exactly projects the binder-derived Prometheus envelope, both cost-model versions,
   global/per-rule-group effective evaluation interval, exact StatefulSet claim/backing/presentation/PVC/PV
   rounded capacity, and
   TSDB time/size retention, Prometheus query flags, sole-routable query-admission proxy controls, direct-query
   NetworkPolicy, and WAL/config from its mandatory finite `MonitoringWorkBudget`. An independent
   test-side storage oracle rederives retained blocks, WAL/head, old+new compaction overlap, and query/temp
   headroom from the structural query operands, then applies the pinned filesystem overhead and allocation
   quantum; the rendered claim must equal
   the resulting private `provisionedBytes`, not merely fit the backing. The same property independently
   checks that controller webhook, object/registry/query gateway, Pulumi executor, ZooKeeper/Patroni child, and
   copy/schema Job pod fields equal their private envelopes; migration targets equal their private rounded
   volume/object maps; and rendered etcd quota/Event/Lease controls equal the logical-capacity operands.
2. Feed the real provision fold a monitoring backing whose mounted usable capacity is one byte below the
   independently rederived usable peak, and separately one whose raw allocation is one quantum below the
   derived `provisionedBytes`; require typed rejection before `renderAll`. No `[K8sObject]` is produced and the import-graph
   proof establishes that this pure boundary has no apiserver, filesystem, or backing-allocation effect. The
   exact-fit neighbor produces a private provision witness whose TSDB claim/configuration renders exactly.
3. Feed Phase 8 two service/global source candidates for one Namespace/RBAC/quota identity and require
   `provisionRenderSources` to reject the duplicate before `ProvisionedSpec`; the legal control has one global
   source and `renderAll` emits it once. Mutate `renderSourcePrivate` to omit or duplicate a source and require
   the output-domain equality property to fail. Permute source-map construction and require identical
   identity-sorted bytes.
4. Partition the emitted identities by their source activation and independently assert the complete,
   disjoint four-arm domain. A mutant that marks managed-capacity taint/admission `Immediate`, filters
   later-stage objects out of `renderAll`, or lets an early-stage action select them turns the property red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 9.3: The rendered-output golden battery (`render-golden`) — the gate 📋

**Status**: Planned
**Implementation**: `test/manifest/RenderGoldenSpec.hs`, `test/manifest/golden/<deployment-id>.json` (the
Phase-0-committed golden fixtures, one per deployment, under the canonical Aeson encoding), the independent
test-side allow-edge oracle `test/manifest/DepGraphOracle.hs` (a hand-authored re-derivation of allow edges
from the declared dependency graph, not a call into `renderAll`), and the **concrete corpus** — the full Phase-8
binder output set: every capability arm × both deployment shapes {`SingleNode`, `Distributed`}, jointly
covering every renderable `K8sObject` sum variant at least once — target paths, not yet built.
**Blocked by**: Sprint 9.2; Phase 8 gate (the whole-deployment `ProvisionedSpec` corpus the goldens render from).
**Independent Validation**: `cabal test render-golden` is green — the emitted `[K8sObject]` matches its
Phase-0-committed byte-for-byte golden under the canonical encoding and every rendered-output-golden
illegal-state property holds non-vacuously; the suite goes **red** if the renderer's output drifts by a single
byte or if any emitted object violates a by-construction invariant. The NetworkPolicy property checks allow-edge
**set equality** against the independent `DepGraphOracle` re-derivation (authored in Phase 0, never `renderAll`'s
own fold), so an extra allow edge for an undeclared dependency is caught. The twelve committed seeded mutants
(below) are re-run each build and each must go red via the *property* assertion it targets, with that mutant's
golden regenerated to match its (illegal) output so the byte diff alone cannot be what fails.
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md` (record the rendered-output-golden
locus realized in Register 1), `documents/illegal_state/illegal_state_catalog.md` (annotate §3.6/§3.7/§3.11
with realized foreclosure layer = rendered-output-golden, Register 1),
`documents/engineering/namespace_layout_doctrine.md` (backlink the one-namespace-per-capability rule to the
Phase-9 render-golden battery — the rendered-output enactment that gates its foreclosure),
`documents/engineering/generated_artifacts_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-9 status
when the gate passes).

### Objective
Adopt [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
and its §4 spine's **`renderAll`** step: assemble the in-process battery that pins `renderAll`'s output byte-for-byte
and proves the three rendered-output-golden illegal states — the unsafe-workload
([`§3.11`](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)),
backdoor-ingress ([`§3.7`](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)),
and blocking/underived-NetworkPolicy ([`§3.6`](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other))
states — directly on the emitted objects, all without a cluster.

### Deliverables
- `test/manifest/RenderGoldenSpec.hs` pinning the emitted object set byte-for-byte against the
  Phase-0-committed `test/manifest/golden/<deployment-id>.json` (canonical Aeson encoding) for **the concrete
  corpus** (every capability arm × {`SingleNode`, `Distributed`}), plus per-capability **shape-completeness**
  assertions: a Kubernetes workload emits exactly its provisioned Deployment, StatefulSet, DaemonSet, or Job
  arm, while a host-only capability emits no Kubernetes workload; every Kubernetes arm has its
  `ServiceAccount`/`Role`/`RoleBinding` triple and derived `NetworkPolicy`; and every
  app/sidecar/init container preserves the exact provisioned CPU/memory/`ephemeral-storage` fields,
  app/sidecar/init container, every root-filesystem arm projected exactly and every writable/log allowance
  covered by that container and the effective
  pod ephemeral request with bounded shared disk volumes, every memory-volume access/persistence binding and
  lifecycle-derived unique reservation carrier reflected in the container memory requests/limits, every
  ConfigMap/Secret/downward-API/token projection matched to its derived mapped-file/API-object identity, every
  content digest matching the selected OS/arch provisioned image metadata, checked durable claim-slot/
  backing/presentation/required-usable/provisioned sizes
  preserved, every webhook/gateway/executor/transition Job included as a full provisioned pod, every
  ZooKeeper/Patroni member/child and migration target projected exactly, and every
  full-offering accelerator-owner-container claim plus profile/topology affinity preserved; a dedicated
  heterogeneous golden has one 1-GPU and one 4-GPU class, renders disjoint owner workloads requesting 1 and 4,
  and proves exactly one owner target per node (never one uniform template); for the `Observability` corpus member,
  the Prometheus CPU/memory envelope, every effective evaluation interval, TSDB time/size retention and
  model-selected WAL/config, and the provisioned claim slot/backing/presentation/PVC/PV capacity equal the independent
  budget/cost-model oracle. That oracle includes `maxScrapeSamplesPerSecond`, finite retention,
  the complete `QueryWorkBudget`, resident blocks, WAL/head, old+new compaction overlap, structurally derived
  query/temp headroom, filesystem
  overhead, and backing quantum) and
  **corpus-wide non-zero counts**
  (total pods > 0, total NetworkPolicies > 0) so no property holds vacuously over an empty object set; plus the
  three fixed-predicate safety assertions — every emitted pod carries a hardened `securityContext`; no `Service`
  of type `NodePort`/`LoadBalancer` outside the single declared edge, every `HTTPRoute` parented to the
  Keycloak-owned `Gateway`, no bare `Ingress` kind; and every NetworkPolicy default-deny with allow edges set-
  equal to the independent `DepGraphOracle` re-derivation.
- **Twelve committed seeded mutants** (operator: invariant-clause delete / field alteration / union-arm addition /
  guard weakening),
  each committed and re-run and each of which must turn its *targeted property* (not the byte diff) red — its
  golden regenerated to the mutant's output so only the property can fail: **R1** alter a checked CPU/memory
  request or limit; **R2** omit/mismatch the root-filesystem security projection, omit a checked
  `ephemeral-storage` request/limit or lower the request below bounded volumes plus lifecycle-effective
  private allowances, or let one container's private allowance exceed its own
  limit; **R3** remove or exceed a checked disk-backed `emptyDir.sizeLimit`; **R4** drop memory-volume
  access/persistence or render zero/two reservation carriers in one lifecycle epoch; **R5** select the wrong
  OS/arch child digest or drop its content/snapshot/import/pull-policy bound; **R6** alter a checked PVC
  claim-slot/backing/presentation/rounded-size projection; **R7** omit or mismatch an accelerator owner's full-offering integer extended-
  resource request/limit or required profile/topology affinity, or collapse heterogeneous 1/4-GPU classes into
  one uniform owner template; **R8** drop a
  supported CR's resource/replica/PVC/controller projection; emit an invalid/wrong-kind policy, Deployment
  `{ maxSurge = 0, maxUnavailable = 0 }`, StatefulSet feature-gated `maxUnavailable`, DaemonSet both-positive
  rollout, or Job with wrong/missing `parallelism`, native TTL, restart/replacement, cleanup, or completion-ledger
  projection; omit/spoof the reservation-template or another provenance annotation, scheduler name,
  nodeName-absence rule, exact protected Pod fields, or sole bootstrap exception; render a prior-only unit;
  omit the scheduler/config/ledger/admission/taint/RBAC objects, bootstrap pods=1 quota, webhook envelope,
  namespace quota, or readiness edge; or emit the same global object identity twice with unequal canonical
  bytes/field ownership so
  operator defaults/free admission escape the child bound; it also covers dropping an object/registry/query
  gateway or volume/registry/schema/Pulumi executor pod (all kill property a); **R9** replace the
  binder-derived Prometheus CPU/memory envelope/evaluation or TSDB cost-model
  version, render a shorter global/rule-group evaluation interval or retention window than the cost input,
  alter the TSDB time/size or WAL/config projection, or make its PVC/PV one byte smaller than the derived
  compaction/query peak, or alter a ZooKeeper/Patroni retention/failover or migration old+new target projection
  (kills property a's independent resource projection); **S1** render a
  pod without the hardened `securityContext` (kills property a); **S2** emit a wild `NodePort` route / a
  `Keycloak`-skipping `HTTPRoute` (kills property b); **S3** emit an allow edge for a dependency absent from the
  declared graph (kills property c's set-equality against `DepGraphOracle`).
- A Register-1 proven/tested/assumed ledger led by a runtime-UNVERIFIED banner: the emitted objects are
  proven safe *as values* in-process; no claim is made that a live cluster enforces them (deferred to the
  live band). The golden fixtures are test artifacts, never committed deployment manifests.

### Validation
1. `cabal test render-golden` is green — output matches the Phase-0-committed byte-for-byte goldens (canonical
   encoding) across the concrete corpus, shape-completeness and corpus-wide non-zero counts hold (no vacuous
   universal), and every rendered-output invariant holds — the NetworkPolicy check by allow-edge set equality
   against the independent `DepGraphOracle`. Each of the twelve committed seeded mutants (R1 CPU/memory drift,
   R2 pod-ephemeral/private allowance, R3 unbounded scratch/cache, R4 memory-volume lifecycle/accounting,
   R5 image-platform/store accounting, R6 durable-size drift, R7 accelerator projection, R8 CR-child
   projection, R9 monitoring-work projection, S1 unhardened pod, S2 wild/Keycloak-skipping route, and S3
   undeclared allow edge), with its golden
   regenerated to its own output, must
   turn the corresponding **property assertion** red — so a mutant is caught by a safety property, not merely by
   the byte diff.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/manifest_generation_doctrine.md` — backlink §2/§3 to the Phase-9 pure renderer and
  rendered-output goldens; keep §5's snapshot-bound typed action reconciler explicitly as the live-band
  [Phase 16](phase_16_renderer_reconciler.md) residue, run by the Deployment-`replicas=1` singleton under its
  mandatory Lease.
- `documents/engineering/conformance_harness_doctrine.md` — record the rendered-output-golden validation
  locus this phase realizes as the **`renderAll`** step of the pre-cluster spine, in Register 1.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.6 / §3.7 / §3.11 with their realized
  foreclosure layer (rendered-output-golden → Register 1); keep the runtime-checked (layer-3) enforcement
  claim deferred to the live band.
- `documents/engineering/namespace_layout_doctrine.md` — backlink the one-namespace-per-platform-capability
  rule: the render-golden battery is the rendered-output enactment that gates the namespace-layout
  foreclosure (every emitted object lands in its doctrine-derived namespace, and a free-text or
  cross-capability namespace is not a value `renderAll` can emit).
- `documents/engineering/generated_artifacts_doctrine.md` — note that the rendered `[K8sObject]` set is
  emitted from Haskell and never committed; the byte-for-byte golden is a test fixture of the renderer.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-9 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-9 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Manifest/{K8sObject,Types,Render}.hs` and
  the `render-golden` test-suite as Phase-9 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *rendered-output proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the pure-render / no-Helm posture
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §2 the pure
  renderer adopted here; §3 best-practice-by-construction; §5 the SSA reconciler deferred to the live band
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the `renderAll` step
  of the pre-cluster spine and the invariant that rendering never touches live infrastructure
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.6/§3.7/§3.11 the three
  rendered-output-golden states; §6 the honest foreclosure-layer split
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the derived
  NetworkPolicy rule, §10 the complete resource-envelope rule this phase renders by construction
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the `renderAll`
  output is generated and never committed
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_08](phase_08_capability_binder.md) — the capability→provider→shape binder and provision fold producing
  the opaque whole-deployment `ProvisionedSpec` and its sealed identity-keyed render-source set
- [phase_10](phase_10_chain_kernel_dryrun.md) — the `chain`/`[Step]` `--dry-run` plan render deferred from here
- [phase_16](phase_16_renderer_reconciler.md) — the live action-driven reconciler that consumes
  `renderAll`'s desired object set
