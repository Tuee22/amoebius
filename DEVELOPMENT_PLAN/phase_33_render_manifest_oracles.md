# Phase 33: Pure `renderAll` + rendered-artifact oracles

> **Purpose**: Stand up the pure, total `renderAll :: ProvisionedSpec -> [K8sObject]`, mapping Phase 31's
> unique identity-keyed private render sources to typed objects, and lock its emitted deployment object
> set against separately reviewed Haskell semantic projections, requiring the by-construction manifest-safety invariants on
> the emitted objects in-process, before any cluster exists.
> **Read this if**: phase 33 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 33.1: The typed `K8sObject` model + Aeson serialization ⏸️](#sprint-331-the-typed-k8sobject-model--aeson-serialization-)
- [Sprint 33.2: Pure total `renderAll` + best-practice-by-construction ⏸️](#sprint-332-pure-total-renderall--best-practice-by-construction-)
- [Sprint 33.3: The rendered-output semantic-oracle battery (`render-oracle`) — the gate ⏸️](#sprint-333-the-rendered-output-semantic-oracle-battery-render-oracle--the-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 32, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** The pure Haskell target comprises the typed `K8sObject` model and
`renderAll :: ProvisionedSpec -> [K8sObject]`, which projects the complete whole-deployment object set from
Haskell ADTs. Any serialized YAML/JSON is lazy output beneath `.build/**`, never tracked source or oracle. A
separately reviewed Haskell semantic oracle must constrain the projection. `renderAll` is intended to perform
no I/O or apiserver access and to consume only the opaque Phase-31 value. The target input contains a
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
and never hides later-stage objects; Phase 58's typed diff/enactor filters actions by that sealed activation,
so managed-node taint/admission cannot be generically applied during the initial scheduler bootstrap.
The target serializer module is to remain available only inside the amoebius package for Phase 56's
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
is a *value* the target Haskell corpus must inspect end to end. That corpus must compare the emitted `[K8sObject]`
to a separately reviewed Haskell semantic projection (exact identities and typed meanings, never renderer-produced
bytes), and require the **rendered-artifact-oracle illegal states** directly on the emitted objects — an
unsafe manifest must not be a value `renderAll` can return, with
no cluster. What is *not* here: snapshot-bound typed actions (including scoped SSA, staged delete/resume,
host actions, scheduler-ledger CAS, and Job completion/cleanup), wait-for-ready, drift-heal, and live
convergence — all deferred to [Phase 58](phase_58_object_reconciler.md); and
the `chain`/`[Step]` `--dry-run` plan render, which is [Phase 34](phase_34_chain_kernel_boundary.md). This phase
locks the **`renderAll`** step of the pre-cluster spine.

**Phase scope:** one target claim — rendering is pure and total, and every emitted object must satisfy a
separately reviewed Haskell predicate. Renderer output is never its own expectation.

**Substrate:** `none` — no host, cluster, provider, or hardware; the canonical Haskell gate owns the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 32](phase_32_inference_accelerator_provision.md)
**Gate:** `pb validate phase 33`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — pure total Haskell rendering must satisfy a separately reviewed Haskell semantic projection; any serialized manifest bytes are lazy `.build/**` output and never authority. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 33` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 32; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact pure `renderAll` emits is a recipe over a content address, never an authored file; authored expectations describe meaning rather than reproduce those bytes.
- [`namespace_layout_doctrine.md` §2 — One namespace per platform capability — the derived set](../documents/engineering/namespace_layout_doctrine.md#2-one-namespace-per-platform-capability--the-derived-set)
  — **one namespace per platform capability, derived never authored.** The target Haskell oracle requires every
  emitted object lands in its doctrine-**derived** namespace and that a free-text or cross-capability namespace
  is not a value `renderAll` can emit — the rendered-output enactment that gates the namespace-layout foreclosure.
- [`manifest_generation_doctrine.md` §2 — The typed manifest model: `renderAll` is the sole public pure function to objects](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects)
  — **the typed manifest model: `renderAll` is a pure, total function to objects.** Adopt the pure, total,
  cluster-free `renderAll :: ProvisionedSpec -> [K8sObject]` whose output is a value amoebius inspects before any object reaches a cluster; the record *is* the manifest, serialized via Aeson, with no intermediate template and no `values.yaml`. **Only the pure-render half is adopted here**; the apply/reconcile engine of that doctrine's [`manifest_generation_doctrine.md` §5 — The apply/reconcile engine: snapshot-bound typed actions](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) is the live-band [Phase 58](phase_58_object_reconciler.md) residue.
- [`manifest_generation_doctrine.md` §3 — Best practice by construction: an unsafe manifest is not constructible](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible)
  — **best practice by construction: an unsafe manifest is not constructible.** The renderer emits a hardened
  `securityContext` on every pod, least-privilege per-workload RBAC, default-deny-plus-derived-allow
  NetworkPolicies, exact provision-derived CPU/memory/ephemeral-storage, bounded pod-local
  volume/writable/log-headroom, mapped files, durable/native-cache/migration, pod/CSI-placement identities,
  controller/admission/executor, and accelerator fields, and Secret objects that carry a
  Vault coordinate
  and never bytes — a manifest lacking any of these is not a value `renderAll` can return.
- [`conformance_harness_doctrine.md` §3 — The load-bearing invariant: rendering never touches live infrastructure](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **the load-bearing invariant: rendering never touches live infrastructure**, and its [`conformance_harness_doctrine.md` §4 — The spine: decode → legality → bind/expand → plan/resolve → provision → `renderAll` → plan → dry-run → fake apply](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply) decode →
  bind/expand → plan/resolve infrastructure → provision → `renderAll` → plan → dry-run spine (this phase locks the **`renderAll`** step). `renderAll` is a pure function of
  tracked Haskell source that completes in-process with no apiserver, no credentials, no Vault; the semantic
  projection is independently authored, and the rendered-artifact-oracle validation locus catches a large share
  of the illegal-state catalog here, not at runtime.
- [`illegal_state_security.md` §3.11 — An unsafe workload (no resource limits, no hardened securityContext)](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)
  (the unsafe workload — no resource limits, no hardened `securityContext`),
  [`illegal_state_security.md` §3.7 — Accidental insecure / backdoor ingress](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
  (accidental insecure / backdoor ingress), and
  [`illegal_state_security.md` §3.6 — Blocking NetworkPolicy (services can't reach each other)](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  (blocking / underived NetworkPolicy) — the three states realized here at the **rendered-artifact-oracle**
  locus. Honors [`illegal_state_techniques.md` §6 — Three layers of foreclosure (and the honesty they force)](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — three layers of foreclosure: the target Haskell oracle constrains the *emitted objects* in Register 1; the runtime-checked
  claim that the live cluster enforces them stays deferred to the live band.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the canonical resource axes and the opaque `ProvisionedSpec` boundary this phase projects into typed
  Kubernetes objects; the renderer neither recomputes demand nor accepts an unchecked service value.
- [`platform_services_doctrine.md` §9 — The LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (east-west connectivity derived from the dependency graph; the single wild-ingress path) and
  [`platform_services_doctrine.md` §10 — Every execution unit declares its complete resource envelope](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope)
  (every execution unit declares a complete resource envelope) — the *owners* of the connectivity and resource rules; this phase adopts
  their **rendering enactment** (the derived NetworkPolicy and exact provisioned resource fields on the emitted
  objects), not the rules themselves.
- [`generated_artifacts_doctrine.md` §3 — The rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — generated artifacts are emitted from a Haskell source of truth and **never repository-retained**: the
  rendered `[K8sObject]` set exists only beneath `.build/**`; only Haskell semantic expectations are source.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  — **Register 1** (pure/semantic-oracle, in-process, no cluster): the intended register; and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  — any candidate ledger must mark runtime-enforcement correspondence UNVERIFIED (owned by the live band).

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 33.1: The typed `K8sObject` model + Aeson serialization ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 32](phase_32_inference_accelerator_provision.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
build the typed Haskell `K8sObject` model — every Kubernetes object amoebius emits as a typed record
serialized to JSON via Aeson, exactly the `object [...]` discipline the prodbox sibling already applies to its supporting objects (*sibling evidence, not an amoebius result*) — so a manifest is a value, not interpolated
text.

### Deliverables

- A typed `K8sObject` sum covering the full deployment object set, each variant a Haskell record with an
  Aeson `ToJSON`/`FromJSON` instance; the record is the manifest — no `values.yaml`, no text template.
- The Secret variant carries a Vault coordinate (a reference), structurally admitting no literal secret
  bytes; the whole `SecretRef` / Vault model stays owned by the vault/PKI doctrine and is not restated.

### Validation

1. The model compiles on the pinned toolchain; a hand-built object round-trips through Aeson to an equal
   value and re-encodes to the same canonical bytes.

### Remaining Work

The pre-reset completion claim is permanently invalid for promotion. Current remaining work includes every
`UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and the typed-object,
serialization, round-trip, and independent Haskell-oracle obligations above. Live Kubernetes decoding and
apiserver correspondence remain UNVERIFIED.

## Sprint 33.2: Pure total `renderAll` + best-practice-by-construction ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 33.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`manifest_generation_doctrine.md §3`](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible):
implement the pure, total `renderAll` that emits the complete whole-deployment object set — including generated
operator installs (CRDs, controller Deployment, CR instances) as typed objects rather than upstream charts —
with every supported CR's replica/resource/PVC/controller fields exactly projecting its provisioned child
envelope. Deployment alone projects the checked nonzero-progress surge/unavailable pair; StatefulSet projects
partition-zero native serial or amoebius-staged OnDelete without feature-gated `maxUnavailable`; DaemonSet
projects exactly one positive Surge/Unavailable or staged OnDelete; Job projects exact completions,
parallelism, backoff, `restartPolicy=Never`, `podReplacementPolicy=Failed`, and the finite amoebius cleanup
model while omitting `ttlSecondsAfterFinished`. The safe shape is the *only* shape it can return.
Every pod has a hardened `securityContext`; policies are default-deny plus graph-derived allow edges.
Every container has non-zero CPU, memory, and `ephemeral-storage` requests and limits. Disk-backed scratch is
bounded, while memory-backed volumes retain their access, persistence, and one-carrier-per-epoch witnesses.
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
  producing best-practice-by-construction objects. It maps Phase 31's sealed
  `Map K8sObjectIdentity (ProvisionedRenderSource K8sObjectIdentity)` one-for-one, proves every emitted
  object's identity equals its map key, and treats `KubernetesObjectId` as an alias only; shared identities
  already have one global source owner and output order is deterministic. The `ProvisionedSpec`, its service
  projections, and `renderSourcePrivate` are private; raw decoded, merely bound, or individual service values
  cannot call a renderer. `renderAll` is the sole public manifest function.
- A closed `RenderReconcileMode` projection that includes only immutable schema/initial fields for the
  scheduler root ledger and mandatory Lease. Ledger rows/CAS versions and Lease holder/renewal fields have no
  generic-SSA source path and are owned only by the corresponding typed actions in Phase 58.
- Exact preservation of each source's `RenderActivation`; the semantic oracle covers all four arms. The renderer emits
  the complete desired set irrespective of stage, while a companion partition oracle proves the later action
  planner can select only the identities active at a given readiness witness.
- An in-file honesty note: this is the render half only — the SSA/ApplySet apply, prune, wait-for-ready, and
  release ledger are the live-band [Phase 58](phase_58_object_reconciler.md) reconciler, run by the
  Deployment-`replicas=1` control-plane daemon under its mandatory Lease (no bespoke election).

### Validation

1. The `-Werror=incomplete-patterns`/`-Werror=incomplete-uni-patterns` compile passes. The boundary check
   reports no partial call and no `IO`/`unsafePerformIO`/partial-`Prelude` name reachable from `renderAll`.
   A QuickCheck property over legal whole-deployment `ProvisionedSpec` values constructed through
   the real provision fold — with `cover`/`checkCoverage` obligations (hard-failing) that force each
   capability arm, both shapes, and every renderable `K8sObject` variant to fire at its stated minimum —
   confirms every emitted pod is hardened, every NetworkPolicy is default-deny + derived-allow, and every
   resource-bearing object exactly projects its checked CPU, memory, pod-ephemeral, per-container private
   allowance, bounded disk-/access-indexed memory-volume, selected-platform image content/snapshot metadata,
   mapped-source/API-object identity, durable presentation/allocation, pod/CSI attachment identity,
   admission/migration execution, and accelerator provisions, including the single-debit proofs.
   Every supported CR exactly projects its kind-indexed finite child-pod/PVC/controller bound stored in its
   private provisioned controller source.
   - Deployment `RollingUpdate` preserves its checked pair with at least one positive operand;
   - StatefulSet uses native partition zero or staged OnDelete and never renders feature-gated
     `maxUnavailable`;
   - DaemonSet uses exactly one positive Surge/Unavailable or staged OnDelete;
   - Job preserves exact completions, **parallelism**, backoff, `restartPolicy=Never`,
     `podReplacementPolicy=Failed`, finite cleanup projection, and completion-ledger identity while
     rendering no `ttlSecondsAfterFinished`; and host-process rows emit no Kubernetes workload.
   - Every guarded Pod template has exact admission-protected
     deployment/generation/source/revision/reservation-template annotations, absent `nodeName`, exact
     protected resource/volume/runtime fields, and the provisioned scheduler name; the unique fully
     provisioned scheduler bootstrap Pod alone uses `default-scheduler`, exact pods=1 namespace quota, and
     unique-node affinity under its cycle-break witness.
   - Scheduler/RBAC/ config/ledger objects are present before their consumers.
   - No prior-only removed unit renders.
   - Every `Observability` object exactly projects the binder-derived Prometheus envelope, both cost-model
     versions, global/per-rule-group effective evaluation interval, exact StatefulSet
     claim/backing/presentation/PVC/PV rounded capacity, and TSDB time/size retention, Prometheus query
     flags, sole-routable query-admission proxy controls, direct-query NetworkPolicy, and WAL/config from
     its mandatory finite `MonitoringWorkBudget`.
   - An independent test-side storage oracle rederives retained blocks, WAL/head, old+new compaction
     overlap, and query/temp headroom from the structural query operands, then applies the pinned filesystem
     overhead and allocation quantum; the rendered claim must equal the resulting private
     `provisionedBytes`, not merely fit the backing.
   - The same property independently checks that controller webhook, object/registry/query gateway, Pulumi
     executor, ZooKeeper/Patroni child, and copy/schema Job pod fields equal their private envelopes;
     migration targets equal their private rounded volume/object maps; and rendered etcd quota/Event/Lease
     controls equal the logical-capacity operands.
2. A one-byte-short monitoring backing and a one-quantum-short allocation reject before `renderAll`; the
   exact-fit neighbor renders its checked claim.
3. Duplicate global identities reject before `ProvisionedSpec`. Omission/duplication mutations fail domain
   equality, while source-map permutations retain identical identity-sorted bytes.
4. The emitted activations form a complete, disjoint four-arm domain. Stage-changing and stage-filtering
   mutants turn the partition property red.

### Remaining Work

The pre-reset completion claim is permanently invalid for promotion. Current remaining work includes every
`UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and the pure-render,
totality, coverage, negative-control, and Haskell mutation obligations above. SSA, ApplySet pruning, readiness,
and live convergence remain Phase-58 work.

## Sprint 33.3: The rendered-output semantic-oracle battery (`render-oracle`) — the gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 33.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
and its [§4](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply) spine's **`renderAll`** step: assemble the in-process battery that pins `renderAll`'s exact semantic projection
and proves the three rendered-artifact-oracle illegal states — the unsafe-workload
([`§3.11`](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)),
backdoor-ingress ([`§3.7`](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)),
and blocking/underived-NetworkPolicy ([`§3.6`](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other))
states — directly on the emitted objects, all without a cluster.

### Deliverables

- Eighteen semantic rows cover every capability arm under `SingleNode` and `Distributed`, including exact identity, kind, activation, reconcile-mode, workload, policy, exposure, and accelerator facts.
- Shape checks preserve the selected workload kind and sealed source-identity domain.
- Workloads project checked resources, hardened security, content-digested images, bounded volumes,
  schedulers, and accelerator claims.
- Corpus-wide pod and NetworkPolicy counts are non-zero.
- Only the declared edge may use load-balancer exposure; no bare Ingress arm is emitted.
- Every NetworkPolicy is default-deny and its edge set equals the independent `DepGraphOracle` result.

#### Twelve reviewed Haskell mutation operators

Each operator is applied to a temporary production-source copy beneath `.build/mutants/**`. It must turn
exactly its targeted semantic property red while its unmutated twin stays green and the changed-subject witness
confirms the intended production locus changed:

- **R1/R2:** alter checked resources or the root-filesystem/ephemeral projection.
- **R3/R4:** remove bounded scratch or memory-volume accounting.
- **R5/R6:** change image-platform or durable-source projection.
- **R7:** omit the accelerator owner claim.
- **R8:** change the controller-kind projection.
- **R9:** alter the monitoring resource projection.
- **S1:** emit an unhardened pod.
- **S2:** expose an undeclared load balancer.
- **S3:** add an undeclared allow edge.
- A Register-1 proven/tested/assumed ledger led by a runtime-UNVERIFIED banner: the emitted objects are
  proven safe *as values* in-process; no claim is made that a live cluster enforces them (deferred to the
  live band). The semantic oracle is authored source; rendered deployments remain generated and untracked.

### Validation

1. Rejected historical observation: the `render-oracle` Cabal suite was recorded green — output matches the
   independently authored semantic projection across
   the concrete corpus, canonical round-trip stability holds, shape-completeness and corpus-wide non-zero counts hold (no vacuous
   universal), and every rendered-output invariant holds — the NetworkPolicy check by allow-edge set equality
   against the independent `DepGraphOracle`. Each of the twelve applied Haskell mutants (R1 CPU/memory drift,
   R2 pod-ephemeral/private allowance, R3 unbounded scratch/cache, R4 memory-volume lifecycle/accounting,
   R5 image-platform/store accounting, R6 durable-size drift, R7 accelerator projection, R8 CR-child
   projection, R9 monitoring-work projection, S1 unhardened pod, S2 wild/Keycloak-skipping route, and S3
   undeclared allow edge), must turn exactly the corresponding **property assertion** red — so a mutant is
   caught by the intended semantic property.

### Remaining Work

The pre-reset completion claim is permanently invalid for promotion. Current remaining work includes every
`UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and the independently authored
Haskell semantic-oracle, changed-production-subject mutation, discovery, and non-vacuity obligations above.
Live enforcement remains UNVERIFIED at Phase 58.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/manifest_generation_doctrine.md` — backlink §2/§3 to the Phase-33 pure renderer and
  rendered-output semantic oracles; keep §5's snapshot-bound typed action reconciler explicitly as the live-band
  [Phase 58](phase_58_object_reconciler.md) residue, run by the Deployment-`replicas=1` control-plane daemon under its
  mandatory Lease.
- `documents/engineering/conformance_harness_doctrine.md` — record the rendered-artifact-oracle validation
  locus this phase realizes as the **`renderAll`** step of the pre-cluster spine, in Register 1.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.6 / §3.7 / §3.11 with their realized
  foreclosure layer (rendered-artifact-oracle → Register 1); keep the runtime-checked (layer-3) enforcement
  claim deferred to the live band.
- `documents/engineering/namespace_layout_doctrine.md` — backlink the one-namespace-per-platform-capability
  rule: the `render-oracle` battery is the rendered-output enactment that gates the namespace-layout
  foreclosure (every emitted object lands in its doctrine-derived namespace, and a free-text or
  cross-capability namespace is not a value `renderAll` can emit).
- `documents/engineering/generated_artifacts_doctrine.md` — note that the rendered `[K8sObject]` set is emitted from Haskell only beneath `.build/**`; only the independently authored Haskell semantic projection is source.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the human authority may change Phase 33 after reviewing a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-33 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Manifest/{K8sObject,Types,Render}.hs` and
  the `render-oracle` Haskell test suite as Phase-33 design-first rows.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *rendered-output proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the pure-render / no-Helm posture
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — [§2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) the pure
  renderer adopted here; [§3](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible) best-practice-by-construction; [§5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) the SSA reconciler deferred to the live band
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the `renderAll` step
  of the pre-cluster spine and the invariant that rendering never touches live infrastructure
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)/[§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)/[§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext) the three
  rendered-artifact-oracle states; [§6](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) the honest foreclosure-layer split
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — [§9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) the derived
  NetworkPolicy rule, [§10](../documents/engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope) the complete resource-envelope rule this phase renders by construction
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the `renderAll`
  output is generated lazily beneath `.build/**` and is not repository source
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_30](phase_30_capability_bind.md) — the capability→provider→shape binder and provision fold producing
  the opaque whole-deployment `ProvisionedSpec` and its sealed identity-keyed render-source set
- [phase_34](phase_34_chain_kernel_boundary.md) — the `chain`/`[Step]` `--dry-run` plan render deferred from here - [phase_58](phase_58_object_reconciler.md) — the live action-driven reconciler that consumes
  `renderAll`'s desired object set
