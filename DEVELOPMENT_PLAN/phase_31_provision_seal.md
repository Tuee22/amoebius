# Phase 31: Whole-deployment provision seal + expansion

> **Purpose**: Take the fully expanded `BoundDeployment` produced by [Phase 30](phase_30_capability_bind.md),
> run it through the conditional infrastructure planner/materialization boundary and then the Phase-9/15/16
> capacity folds over explicit Haskell values, and either model a declared materialized target — sealing one opaque whole-deployment
> `ProvisionedSpec` carrying a single identity-keyed `ProvisionedRenderSourceSet` with per-field ownership and
> four-stage activation — or return exactly one structured `ProvisionError` at the `provision-seal` locus.
> **Read this if**: phase 31 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 31.1: The conditional infrastructure planner + materialization boundary (`planInfrastructure`) ⏸️](#sprint-311-the-conditional-infrastructure-planner--materialization-boundary-planinfrastructure-)
- [Sprint 31.2: The whole-deployment `provision` fold + execution/runtime-storage/object/observability/migration/scheduler expansion ⏸️](#sprint-312-the-whole-deployment-provision-fold--executionruntime-storageobjectobservabilitymigrationscheduler-expansion-)
- [Sprint 31.3: The `ProvisionedSpec` seal + identity-keyed render-source set + four-stage activation ⏸️](#sprint-313-the-provisionedspec-seal--identity-keyed-render-source-set--four-stage-activation-)
- [Sprint 31.4: The provision-seal property/corpus + the Register-1 gate ⏸️](#sprint-314-the-provision-seal-propertycorpus--the-register-1-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 30, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase specifies the pure Haskell **post-bind provision seal**.
It models exactly two total functions and the private artifact they may construct; it does not inspect a host,
provider, or cluster and cannot establish that an observation-shaped input came from reality. Haskell values
own every case and expectation; any serialized plan or case is generated lazily beneath `.build/**`.

`planInfrastructure :: ProvisionTargetSupply -> BoundDeployment -> Either ProvisionError InfrastructurePlanningResult`
— the **conditional infrastructure planner / materialization boundary**. It derives the exact infrastructure
demand *internally* from the fully expanded `BoundDeployment` (never accepting a caller-authored demand vector),
and either models the declared target as already materialized (`NoInfrastructureRequired`) or returns exactly one
non-renderable `InfrastructureRequired` plan owning one batch-scoped Pulumi
graph/checkpoint/dependency/concurrency/quota partition and a fresh plan token. `StandaloneRoot` supplies the
complete declared node/host/account/backing/API-etcd inventory; `ForestMember` supplies the exact opaque
`ClusterBudget`. In this pure phase, `ObservedInfrastructureMaterialization` is only a constructor-private
Haskell input shape. Authentic provider/host readback, freshness, and receipt binding are post-Phase-49 live
obligations; no supplied value may be cited here as a real observation.

`provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec`
— the **whole-deployment provision fold**. It is the *sole constructor* of every `Provisioned*` projection. It
resolves each opaque `PriorExecutionProvisionRef | PriorVolumeProvisionRef | PriorRegistryProvisionRef` against
`ProvisionContext`, expands each desired `BoundExecutionUnit` through its kind-indexed controller body into
`MaterializedExecutionInstance`s and empty-capable `ExecutionEpoch`s, drives the Phase-9 capacity fold, the
Phase-28 storage-geometry fold, and the Phase-29 execution-epoch / runtime-metadata / scheduler-reservation /
accelerator-residency folds over the *full* expanded resource vector, and constructs the private witnesses —
`ProvisionedExecutionEpochs`, `ProvisionedNodeRuntimeStorageAccounting`, the finite monitoring-work Prometheus
envelope, the six-arm object-producer/storage-budget/admission-gateway witnesses, the
old+new volume/registry/schema migration witnesses, the ZooKeeper/Patroni database witnesses, the
`PulumiExecutionDemand`, the mandatory reconciler `Lease`, and exactly one deployment-global
`ProvisionedCapacitySchedulerSystem`. On success it seals the opaque **`ProvisionedSpec`** and, via
`provisionRenderSources :: ProvisionedDeploymentParts -> Either ProvisionError ProvisionedRenderSourceSet`, one
**equal-keyed identity render-source set** — one `ProvisionedRenderSource` per `K8sObjectIdentity`
(alias `KubernetesObjectId`), each map key equal to its embedded source identity, its provisioned-part witness
fixing owner, fields, reconcile mode, and one of the four
`RenderActivation = Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover | AfterManagedCapacityReady`
stages. On any insufficiency — post-bind expansion overcommit, monitoring-work over budget, VRAM overcommit, or
a CUDA-requiring workload on a non-CUDA topology — it returns the exact structured `ProvisionError` at the
`provision-seal` locus and never constructs `ProvisionedSpec`.

What is **not** here:
- the capability union, the `CapabilityBinding`, the total `bind`, the object-node-multiset shape oracle,
  and the dhall-typecheck/gadt-decode negatives ([Phase 30](phase_30_capability_bind.md))
- the *representational* `InferenceEngine`/`EngineRuntime` union and the identity-complete accelerator
  source/workload/residency/ coexistence provision corpus
  ([Phase 32](phase_32_inference_accelerator_provision.md))
- the *soundness* of the `fits`/`carve`/`place` folds and the composed full-resource-vector place-witness
  gate this phase merely invokes ([Phase 9](phase_09_resource_index.md), [Phase 28](phase_28_storage_geometry_folds.md), [Phase 29](phase_29_execution_accelerator_folds.md))
- the pure `renderAll :: ProvisionedSpec -> [K8sObject]` that consumes the sealed set ([Phase 33](phase_33_render_manifest_oracles.md))
- the live `amoebius-capacity` scheduler runtime ([Phase 59](phase_59_capacity_scheduler.md))
- and the live realization of any provider or the actual jit-resolve of an engine
  ([Phase 80](phase_80_determinism_jitcache.md), the live band).

**Phase scope:** one target claim — a deployment can be sealed only once against an explicit, typed
observation-shaped value. The phase does not establish that the value was observed from a live target.

**Substrate:** none — no host, cluster, provider, or hardware; the canonical Haskell gate owns the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure Haskell only. A future candidate may speak only about the supplied model; authentic
inventory, provider realization, and engine resolution remain UNVERIFIED live-band obligations.

**Depends on:** [Phase 30](phase_30_capability_bind.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 31`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — pure Haskell may seal a deployment exactly once against an explicit typed observation-shaped value; any serialized plan or case is generated beneath `.build/**`; authenticity of any live inventory is not claimed here. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 31` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 30 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`extension_conformance_laws.md` §3 — L1–L5: the per-extension laws](../documents/engineering/extension_conformance_laws.md#3-l1l5-the-per-extension-laws) and [`extension_conformance_laws.md` §4 — C1–C7: the compositional laws](../documents/engineering/extension_conformance_laws.md#4-c1c7-the-compositional-laws) — the L-laws whole-deployment provision seal + expansion must satisfy in isolation, and the C-laws its composition with any peer must satisfy.
- [`jit_budget_doctrine.md` §3 — A ceiling is inseparable from its concurrency](../documents/engineering/jit_budget_doctrine.md#3-a-ceiling-is-inseparable-from-its-concurrency) — the bytes whole-deployment provision seal + expansion causes to exist are charged to a grant that carries its ceiling and concurrency together.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — **the complete resource envelope and the opaque post-fold `ProvisionedSpec` boundary.** This phase owns the
  ordering's tail: after Phase 30 expands every provider/shape into a `BoundDeployment`, the seal runs the
  Phase-9/15/16 folds and hands only the checked opaque result to Phase 33. A capacity check over a pre-bind
  skeleton is insufficient; the seal folds the *fully expanded* vector — kind-indexed desired/old/surge/
  terminating epochs, sidecars, controller children, the standard platform graph, and
  component→role→layout-backed runtime metadata — and returns `Left` on any one-axis overcommit.
- [`resource_capacity_sources.md` §9.2 — Monitoring cost folds through the standard machinery, and the forest has no parent-rollup budget](../documents/engineering/resource_capacity_sources.md#92-monitoring-cost-folds-through-the-standard-machinery-and-the-forest-has-no-parent-rollup-budget)
  and [`resource_capacity_doctrine.md` §10 — Planning ownership](../documents/engineering/resource_capacity_doctrine.md#10-planning-ownership)
  — **monitoring cost folds through the standard machinery**, and **planning ownership.** The seal runs the
  named, version-pinned conservative cost models that derive the Prometheus/proxy compute envelope and the
  rounded TSDB/query storage from the expanded `Observability` descriptor's cardinality — no
  descriptor-independent fixed request, tiny PVC, or optional-budget path — and `MonitoringBudgetExceeded` is a
  checked rejection, not a default. `planInfrastructure`/`provision` are the sole planning owners of the
  post-bind boundary.
- [`service_capability_doctrine.md` §4 — Capability → provider → shape: the binding](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  — **Capability → provider → shape: the binding**, its provisioning tail. The provider/shape are chosen by
  deployment rules and expanded by `bind` (Phase 30); this phase provisions that fully expanded graph against
  the cluster's topology before anything can render, so a byte-identical app that binds to a structurally
  different graph per cluster provisions — or is refused — per cluster.
- [`service_capability_doctrine.md` §4.1 — The InferenceEngine capability — the engine is target-offering-selected and jit-resolved, never authored](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
  — the `InferenceEngine` capability, its **enforcement half only**: a served model whose engine family is
  unavailable on the serving lane, or a CUDA-requiring workload on a non-CUDA topology, is a post-bind
  **`provision-seal` `Left`**. This phase implements that seal-locus rejection over the accelerator folds it
  invokes; the *representational* `EngineRuntime` union and the identity-complete residency/coexistence corpus
  are [Phase 32](phase_32_inference_accelerator_provision.md).
- [`illegal_state_catalog.md` §3 — The catalog — states a valid spec cannot represent](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent)
  with [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  — the seal proves the *binding composes and its target has capacity*, not that the *running provider* came up.
  Every insufficiency is a structured `ProvisionError` at the `provision-seal` locus, and the runtime residue
  (the provider actually up, the engine actually resolved) stays UNVERIFIED, deferred to the live band.
- [`manifest_generation_doctrine.md` §2 — The typed manifest model: `renderAll` is the sole public pure function to objects](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects)
  — **`renderAll` is the sole public pure function to objects.** The provision seal is what *produces* the
  unique identity-keyed `ProvisionedRenderSourceSet` under the opaque `ProvisionedSpec` that Phase 33's
  `renderAll` privately maps; no service projection can invoke render on its own, and the seal's per-source
  field ownership and activation stage are what the later typed diff/enactor must honor.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  (**Register 1** — pure/semantic-oracle, in-process, no cluster) and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) (the per-run proven/tested/assumed ledger): the
  register this gate reaches and the ledger it emits, with the live realization of any provider (and the
  jit-resolve of any engine) marked UNVERIFIED, owned by the live band.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 31.1: The conditional infrastructure planner + materialization boundary (`planInfrastructure`) ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`resource_capacity_doctrine.md §10 — Planning ownership`](../documents/engineering/resource_capacity_doctrine.md#10-planning-ownership):
implement the conditional infrastructure planner as a pure total function that derives — never accepts — the
matching infrastructure demand from the fully expanded `BoundDeployment` and either proves the declared target
already materialized or returns exactly one non-renderable plan owning the closed provider-action batch.

### Deliverables

- `planInfrastructure :: ProvisionTargetSupply -> BoundDeployment -> Either ProvisionError
  InfrastructurePlanningResult`, run after every capability/provider graph and standard-platform expansion.
  `StandaloneRoot` supplies the complete declared node/host/account/backing/API-etcd inventory; `ForestMember`
  supplies the exact opaque `ClusterBudget`. Demand is derived internally from `BoundDeployment`.
- `InfrastructureRequired` contains one batch-owned Pulumi graph/checkpoint/dependency/concurrency/quota
  partition and a fresh plan token; child-create payloads contain bound intent and budget, never a circular
  child `ProvisionedSpec`. A required plan owns one Pulumi action batch and cannot render.
- The materialization boundary: receipt-bound materialized nodes/root volumes/provider volumes
  (`ObservedInfrastructureMaterialization`) construct `ProvisionContext`; a `NoInfrastructureRequired` result
  supplies the already-materialized arm directly. Replay, missing readback, or promised identities reject.
- An in-file honesty note: `planInfrastructure` produces a *plan value*, not a live provider action; the live
  validation/CAS-enaction of any batch is the live band ([Phase 76](phase_76_provider_deploy_checkpoint.md)).

### Validation

1. The pre-existing fixture yields `NoInfrastructureRequired`; the creation fixture returns exactly one
   `InfrastructureRequired` plan with a fresh token and one action batch; the derived demand equals an
   independent enumeration over the expanded `BoundDeployment`; only receipt-bound readback constructs
   `ProvisionContext`, and replay / missing-readback / promised-identity inputs reject.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Both planner arms, the exact action batch, separate plan/action replay refusals, receipt-bound readback,
and promised-identity refusals are sealed by the Phase-31 gate.

## Sprint 31.2: The whole-deployment `provision` fold + execution/runtime-storage/object/observability/migration/scheduler expansion ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`resource_capacity_doctrine.md §4 — the total fold`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and [`§9.2 — monitoring cost folds through the standard machinery`](../documents/engineering/resource_capacity_sources.md#92-monitoring-cost-folds-through-the-standard-machinery-and-the-forest-has-no-parent-rollup-budget):
provision the fully expanded `BoundDeployment` against its topology by driving the Phase-9/15/16 folds over the
complete resource vector, so the only deployable representation is the opaque whole-deployment `ProvisionedSpec`
and an impossible target has no deployable value.

### Deliverables

- `provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec`, run
  after every capability/provider graph and the standard platform set have been expanded. Its private
  constructor — never a caller scalar — stores compute placement, `ProvisionedExecutionEpochs`, per-class/
  per-node expansion, pod-ephemeral/cache-population nesting, pod-slot and unique-driver-PVC attachment
  placement, mapped-file physical routing, per-slot `ProvisionedKubeletRuntimeMetadataDemand`, scope-indexed
  `ProvisionedNodeRuntimeStorageAccounting`, etcd logical quota fit, selected-platform OCI-content/snapshot
  placement by filesystem layout, durable presentation/allocation/native-host-cache backing, old+new
  volume/registry/schema migration execution, ZooKeeper metadata and Patroni database witnesses,
  controller-child transition/webhook bounds, the six-arm object-producer/storage-budget/admission-gateway
  witnesses, `PulumiExecutionDemand`, the mandatory reconciler `Lease`, and — as invoked from
  [Phase 32](phase_32_inference_accelerator_provision.md) — the `ProvisionedCudaOwnerDemand` /
  `ProvisionedMetalOwnerDemand` epoch witnesses.
- Before any placement subtraction, `provision` resolves the whole deployment's exact prior steady execution
  projection, then expands each desired `BoundExecutionUnit` through its kind-indexed controller body into
  `MaterializedExecutionInstance`s and complete, empty-capable `ExecutionEpoch`s. Desired and prior instance
  ids exact-join their own `(ExecutionUnitId, revision, ordinal, resource)` sources; the steady map contains
  the exact desired live service/daemon/host slot domain and may be empty for completed Job-only deployments,
  while planned rollout maps enumerate policy-reachable new/surge/old/zero-live steps. Unchanged identities
  dedup, changed revisions keep distinct old/new envelopes, added units have no old twin, removed prior-only
  units remain through apply-before-prune, and terminating instances are exact-joined to the referenced prior
  generation — never guessed from a raw bound. Controller-derived children pass through this exact mechanism;
  their private controller witness is checked for source equality and is not a second provision or debit.
- Placement evaluates the **full** resource vector in every epoch — CPU, memory, pod/CNI/CSI slots, logical Pod
  ephemeral, component/role/layout-routed runtime and image storage, durable volumes/cache, and accelerator
  device/residency epochs — by driving the Phase-9/15/16 folds, and retains the componentwise transition witness.
  A `ReplicaCardinality.Once` yields one planned slot; a `NodeEligibilitySelector` exact-joins the eligible set;
  Deployment/StatefulSet replicas and Job waves yield exact finite slot sets, a DaemonSet derives exactly one
  slot per selected node, and a HostProcess derives its exact host→slot map; a missing constraint target or
  missing/extra/ineligible slot rejects.
- The runtime-storage fold (`src/Amoebius/Capacity/RuntimeStorage.hs`) derives every metadata component's bytes
  and `KubeletNodefs | CriRuntimeRoot` role, proves the role sums, resolves roles through `Unified |
  SplitRuntime | SplitImage`, groups aliases by physical carve once, and builds one
  `ProvisionedNodeRuntimeStorageAccounting` per node and planned-epoch fingerprint with disjoint-and-exhaustive
  qualified Pod/image ownership combined with the `ProvisionedNodeImageStorageDemand`; SplitRuntime charges
  kubelet components to nodefs and CRI components to imagefs/containerfs, while Unified and SplitImage sum their
  forced aliases before one backing check. None of these physical bytes is repeated as logical Pod ephemeral
  demand. The same shared fold, invoked later by live preflight, instead builds the observed-inventory-fingerprint
  form keyed by authenticated `PodUid`; Phase 31 tests only the pure planned/normalized forms.
- The monitoring-work provision: `provision` runs the named, version-pinned conservative cost models over the
  expanded `Observability` descriptor's derived workflow/rule/series/sample-rate cardinality to derive the
  Prometheus CPU/memory requests and limits (baseline + evaluation overlapping maximum concurrent query work),
  the query-admission proxy's complete pod envelope, and the rounded TSDB/query `ProvisionedVolumeDemand` from
  the structural query operands (resident blocks + WAL/head + compaction overlap + query/temp peak), then
  applies the declared presentation/overhead and backing quantum. A count/rate over budget or a derived
  Prometheus/proxy envelope over the declared ceilings returns `Left MonitoringBudgetExceeded`; there is no
  descriptor-independent fixed-request/tiny-PVC/scalar-query-temp override and no optional-budget path.
- The transition resolution: using the gadt-decode-validated branded refs, `provision` resolves
  `StorageMigrationDemand { old : PriorVolumeProvisionRef, ... }`, `RegistryStorageDemand`,
  `RegistryBackendMigrationDemand { source : PriorRegistryProvisionRef, ... }`, and `SchemaMigrationDemand`
  against `ProvisionContext` — constructing every private migration witness (old+new rounded volumes, digest
  copy maps, workspace/WAL/per-backing peaks) only after resolving the opaque ref; the binder-derived
  copy/transfer/schema executor envelopes it inherits enter the same kind-indexed epoch provisioner. It also
  resolves the six-arm `ObjectStoreProducerDemand` / `ObjectStoreAdmissionGatewayDemand` and `PatroniSqlDemand`
  into their private storage-geometry witnesses (Phase-28 fold), and stores exactly one deployment-global
  `ProvisionedCapacitySchedulerSystem`: complete default-scheduled bootstrap reservation, `pods=1` quota,
  prior+desired controller-child reservation config, managed-node taint/admission/Binding RBAC, aggregate
  root-ledger schema/byte/churn bound, readiness requirement, and unique global render owner.
- `BoundDeployment` contains no `Provisioned*` record: its only links to old successful generations are
  `PriorExecutionProvisionRef`, `PriorVolumeProvisionRef`, and `PriorRegistryProvisionRef`. `provision`
  exact-matches deployment/generation/resource arm in `ProvisionContext`; missing, stale, wrong-generation,
  wrong-arm, source-unit/revision/ordinal/resource, and identity/live-snapshot mismatches reject before any
  allocation or copy. `FirstDeployment` resolves to the exact empty prior execution inventory. These
  materialized/provisioned results occur only inside `provision` and its opaque output, so direct multiplicity
  fields never weaken the wholly-unprovisioned `BoundDeployment` boundary.
- An in-file honesty note: `provision` produces a value, not a live provider; the same pure identity/revision
  epoch algebra is later reused by live admission ([Phase 59](phase_59_capacity_scheduler.md)), which performs
  the real read this phase does not.

### Validation

1. Each of the nine per-arm positives provisions to an opaque `ProvisionedSpec` on both shapes; the independent
   instance/epoch enumeration exact-equals the provision result for steady (incl. Job-completed empty) and every
   rollout step, and each one-unit-short desired-replica/surge/old-revision case rejects. The
   normalized-observation property exact-fits the live desired ∪ referenced-old ∪ terminating ∪
   scheduler-reservation union (incl. `BindingRecovery`) and rejects its one-unit-short terminating pair,
   copied-new-as-old, wrong generation, invented first-deploy old row, and two-candidate stale-residual race.
   The runtime-storage fold exact-fits the grouped node backings and rejects the SplitRuntime one-byte-short,
   missing/mismatched-model, dropped/swapped-role, planned/observed-domain-mismatch, ownership-hole/overlap,
   alias-double-debit, or dropped-largest-row cases. `illegal_monitoring_work_over_budget` returns
   `Left MonitoringBudgetExceeded` without retaining fixed Prometheus requests, and each
   `illegal_prior_provision_ref_*` returns its structured `ProvisionError` before any transition execution. The
   suite goes **red** under each of the ten inherited seeded mutants.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The 18 inherited deployments, ten exact negatives, two boundary properties, and ten paired mutants seal
the post-bind provision fold and its expansion boundary.

## Sprint 31.3: The `ProvisionedSpec` seal + identity-keyed render-source set + four-stage activation ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`manifest_generation_doctrine.md §2 — `renderAll` is the sole public pure function to objects`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
seal the checked provision result into one opaque whole-deployment `ProvisionedSpec` carrying a single
identity-keyed render-source set with per-field ownership and a four-stage activation order, so Phase 33's
`renderAll` privately maps a unique set and no service projection can render on its own.

### Deliverables

- `K8sObjectIdentity` (and its compatibility alias `KubernetesObjectId`), the closed private
  `ProvisionedRenderSource identity`, and the closed
  `RenderActivation = Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover |
  AfterManagedCapacityReady`.
- `provisionRenderSources :: ProvisionedDeploymentParts -> Either ProvisionError ProvisionedRenderSourceSet`,
  the sole constructor of the deployment-global render-source set. It seals one source per Kubernetes object
  identity; shared Namespace/quota/scheduler/admission/RBAC/`Lease`/CRD sources have one global owner; each map
  key equals its embedded source identity; and each source's provisioned-part witness fixes its owner, fields,
  reconcile mode, and activation stage. Duplicate/omitted source-domain candidates reject before
  `ProvisionedSpec`.
- The activation discipline: a later typed diff/enactor must honor activation, so a managed-node
  taint/admission object cannot be swept into the first generic apply; `renderAll` still lists the complete
  desired set. Phase 33 privately maps the unique source set and exposes only whole-deployment `renderAll`.
- An in-file honesty note: this seal produces the *input* to `renderAll`, not manifests; the byte-for-byte
  golden-locked render is [Phase 33](phase_33_render_manifest_oracles.md), and the live diff/enact honoring
  activation is the live band.

### Validation

1. The full `ProvisionedDeploymentParts` domain contributes exactly one equal-keyed `ProvisionedRenderSource`
   per object identity; duplicate/omitted/key-mismatched/owner-mismatched candidates reject; the independent
   activation classifier assigns each source its stage from the committed reference table and rejects a
   missing/extra stage, an early-staged managed taint/admission source, or an owner-disagreeing activation.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The opaque source set, exact domain/key/owner correspondence, and all four activation stages are sealed.

## Sprint 31.4: The provision-seal property/corpus + the Register-1 gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md` §2/§4](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
and [`illegal_state_catalog.md §2 — the load-bearing limit`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it):
assemble the sub-phase's single Register-1 gate — every positive need provisions to a checked opaque deployment
while every insufficient target returns its specific `ProvisionError` at the `provision-seal` locus without
constructing `ProvisionedSpec` — and emit the per-entry validation-locus ledger that marks the runtime residue
UNVERIFIED.

### Deliverables

- The **concrete provision corpus** (§M.7): the nine per-arm positives (both shapes, inherited) provisioned
  against their declared targets, the pre-existing and creation `ProvisionTargetSupply` boundary fixtures, and
  the ten named seal-locus negatives. A committed exhaustiveness unit check asserts every positive provisions
  and every negative returns a `Left`.
- The property battery (`test/spec/capability/ProvisionProps.hs`,
  `test/spec/capability/RuntimeStorageBindingProps.hs`): `provision` is total and its successful values pass an
  implementation-independent check that every private `ProvisionedServiceSpec` projection carries placement,
  pod/CSI-slot, mapped/API-object, execution/admission, storage/migration/cache/database/metadata, and (for the
  Phase-32-provided accelerator arms) accelerator witnesses; the structural inventory proves `BoundDeployment`
  contains no `Provisioned*` field; the independent instance/epoch enumeration, the runtime-storage
  ownership/grouping predicate, and the four-stage activation classifier hold; and exact-fit boundaries accept
  while one-resource/one-byte-short pairs reject.
- The seal-locus negative corpus — `illegal_post_bind_expansion_overcommit` (the exact one-short axis per
  case), `illegal_monitoring_work_over_budget` (`Left MonitoringBudgetExceeded`),
  `illegal_accelerator_vram_shortage` (`ProvisionError VramOvercommit`), `illegal_cuda_on_cpu_target`
  (`ProvisionError MissingCapability Cuda`), `illegal_controller_child_unbounded` (`Left UnknownCommitment`),
  `illegal_elastic_per_node_expansion_overcommit`, and `illegal_prior_provision_ref_{missing,stale,
  wrong_generation,wrong_arm}` — each asserting its specific post-bind `ProvisionError` tag (§M.8) and each
  paired with a positive differing only in the foreclosed dimension. The CUDA-on-CPU, VRAM, and overcommit
  negatives fail after binding but **before** `renderAll` with zero provisioned values.
- **Committed seeded mutants (§M.2)** — the ten inherited deliberately-broken implementations, committed and
  re-run (not run once), that the gate MUST turn red: `mutant_fixed_prometheus_requests`,
  `mutant_provisioned_value_in_bound_deployment`, `mutant_unchecked_prior_ref`, `mutant_drop_execution_replica`,
  `mutant_drop_execution_surge`, `mutant_drop_execution_old_revision`, `mutant_wrong_execution_revision_join`,
  `mutant_double_debit_controller_child`, `mutant_drop_largest_kubelet_metadata`, and
  `mutant_missing_kubelet_metadata_model`. The gate re-runs each and asserts red.
- Its Register-1 ledger is generated from this sprint's executed cases. Coverage assertions require every corpus
  entry, negative reason, and seeded mutant above to contribute a row naming its catalog id and foreclosure
  layer; provider bring-up and bounded-cache resolution remain explicitly deferred live residues, never proof
  claims.

### Validation

1. Rejected historical observation: the `provision-seal-spec` Cabal suite was recorded green — each of the
   nine per-arm positives provisions (both shapes) to
   an opaque `ProvisionedSpec` on its positive topology satisfying the three independent reference predicates;
   the two boundary fixtures exercise both planner arms; each seal-locus negative returns its specifically-tagged
   `Left` before `renderAll`, each paired with a minimally-differing positive; exact-fit boundaries accept and
   one-resource/one-byte-short pairs reject; and every committed mutant is red.
2. The validation-locus ledger's coverage assertion turns the suite **red** if any named fixture,
   negative reason, or mutant is missing — so *"honestly classifies"* is a machine oracle, not a hand-written
   attestation.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The eleven-sided Register-1 gate, 40-row locus ledger, 42-unit five-calculus projection, 25 metrics, and
37-surface/55-item join are sealed.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/resource_capacity_doctrine.md` — backlink §3/§4 (the complete envelope and the opaque
  post-fold `ProvisionedSpec` boundary), §9.2 (monitoring cost folds through the standard machinery), and §10
  (planning ownership) to the implemented `Amoebius.Capacity.{Provision,RuntimeStorage,RenderSource}`; confirm
  the seal derives — never accepts — its demand and returns `ProvisionError` on any one-axis overcommit.
- `documents/engineering/manifest_generation_doctrine.md` — record that the binder/provision boundary seals the
  identity-keyed `ProvisionedRenderSourceSet` under the opaque whole-deployment `ProvisionedSpec` that §2's
  `renderAll` privately maps, with per-source field ownership and four-stage activation.
- `documents/engineering/service_capability_doctrine.md` — backlink §4 (the provisioning tail of the binding)
  and §4.1 (the family-unavailable-on-lane / CUDA-on-non-CUDA state realized as a checked rejection at the
  post-bind `provision-seal` locus).
- `documents/illegal_state/illegal_state_catalog.md` — annotate §2 (the load-bearing limit) and the post-bind
  provision-seal locus: a checked `ProvisionError` proves the binding composes and the target has capacity,
  never that the running provider came up; keep the runtime-checked residue deferred.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + corpus ledger this gate emits
  (live realization and engine-resolve fidelity UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-31 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-31 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the `planInfrastructure`/`provision`/`provisionRenderSources`
  additions to `src/Amoebius/Capacity/{Provision,RuntimeStorage,RenderSource}.hs` and the provision-seal
  property + gate suites as Phase-31 design-first rows.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *binding-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the explicit-provision / opaque-`ProvisionedSpec`
  invariant
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — [§3](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)/[§4](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting) the envelope and
  the total fold, [§9.2](../documents/engineering/resource_capacity_sources.md#92-monitoring-cost-folds-through-the-standard-machinery-and-the-forest-has-no-parent-rollup-budget) monitoring cost folds, [§10](../documents/engineering/resource_capacity_doctrine.md#10-planning-ownership) planning ownership
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — [§4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) the binding's
  provisioning tail, [§4.7](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) the seal-locus family/CUDA rejection
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — [§2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) `renderAll` is
  the sole public pure function; this seal produces its unique input
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it) the load-bearing limit at
  the provision-seal locus
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_30](phase_30_capability_bind.md) — the capability union + total `bind` + shape oracle that produces
  the wholly-unprovisioned `BoundDeployment` this phase seals
- [phase_29](phase_29_execution_accelerator_folds.md) — the execution-epoch / scheduler-reservation /
  runtime-metadata / accelerator folds and the composed full-resource-vector place-witness gate this seal
  invokes
- [phase_28](phase_28_storage_geometry_folds.md) — the logical→physical storage-geometry fold this seal invokes
- [phase_9](phase_09_resource_index.md) — the base `fits`/`carve`/`place` capacity fold this seal invokes
- [phase_32](phase_32_inference_accelerator_provision.md) — the representational `InferenceEngine`/`EngineRuntime`
  union and the identity-complete accelerator source/workload/residency/coexistence provision that layers on
  this seal
- [phase_33](phase_33_render_manifest_oracles.md) — the pure deployment-global
  `renderAll :: ProvisionedSpec -> [K8sObject]` that consumes the identity-keyed render-source set this phase seals - [phase_59](phase_59_capacity_scheduler.md) — the live `amoebius-capacity` scheduler that reuses this seal's
  pure identity/revision epoch algebra
- [phase_80](phase_80_determinism_jitcache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this seal only decodes
