# Phase 8: Capability → provider → shape binder (representational)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the pure capability/provider/shape binding, expand it into complete workload resource
> envelopes, and run the Phase-7 capacity/capability folds against the selected topology so the result is an
> opaque whole-deployment `ProvisionedSpec` carrying one identity-keyed `ProvisionedRenderSourceSet` —
> proving before render that a product-named app has no syntax and that an insufficient target (for example
> CUDA required but unavailable) cannot be deployed.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 7 gate (the capacity /
topology folds and their QuickCheck battery) and runs on **no substrate** (`none`) in **Register 1** — it
stands up no host, no cluster, and no provider, only the pure capability union, the binding records, and the
total `bind` function plus its property/corpus battery. Where a shape below is exercised in a sibling system
(prodbox's `Prodbox/Lib/ChartPlatform.hs` planner/dependency/values orchestration the binding generalizes, and
infernix's `Infernix/Runtime/Worker.hs` selecting its engine by `adapterType` and never fetching it), that is
**sibling evidence, not an amoebius result** — and both siblings still *name products* and *fetch* engine
payloads, the exact couplings this phase's abstraction dissolves.

## Phase Summary

This phase makes amoebius's *"application logic names a capability, never a product"* invariant executable as a
pure decode-and-bind path. It delivers the **capability model** as data: the closed **nine-arm** capability
union — the eight ordinary capabilities (`ObjectStore`, `SecretStore`, `MessageBus`, `Sql`, `Identity`,
`Observability`, `Registry`, `Edge`) plus a distinct ninth `InferenceEngine` arm — on the app surface with
**no product arm** (`minio` has no syntax), the `InferenceEngine` provider a substrate-selected, jit-resolved
`EngineRuntime` identity with **no arbitrary-`Url`/`Download` arm**. It delivers the **three-part binding**: the `CapabilityNeed` an app writes once and carries everywhere,
the `CapabilityBinding` (a one-arm-today provider union defaulting to the canonical provider, plus a typed
`shape` that selects *which* manifest graph to render), the total function
`bind :: CapabilityNeed -> CapabilityBinding -> BoundServiceSpec`, and the whole-deployment
staged boundary
`planInfrastructure :: ProvisionTargetSupply -> BoundDeployment -> Either ProvisionError InfrastructurePlanningResult`
followed, only after authenticated infrastructure readback, by
`provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec`. `bind` expands
provider shape, containers, and every `BoundExecutionUnit`'s revision plus its kind-indexed Deployment,
StatefulSet, DaemonSet, Job, or HostProcess controller body while preserving the required deployment-level
`FirstDeployment | UpdateFrom PriorExecutionProvisionRef` source without resolving it; controller-created
children lower to those same kind-indexed units while retaining their private
source-expansion witness; DaemonSet/host-selected execution units, mapped-file/API-object demand, byte-free Pod-runtime
metadata sources, volumes/CSI attachments, raw volume/registry/schema migration
intents into unprovisioned demands, images, cache, ZooKeeper metadata, raw SQL intent into `PatroniSqlDemand`,
and all six object-store producer intents plus their gateway intent into binder-output demands,
Pulumi executor/checkpoint producers, accelerator needs, and the `Observability` descriptor's finite
monitoring-work provision;
`planInfrastructure` derives demand from that exact expansion rather than accepting a caller-authored demand
vector; a required plan owns one Pulumi action batch and cannot render. `provision` runs only after the
matching consumed-token materialization (or the explicit already-materialized arm) and is the sole constructor of the private
`ProvisionedServiceSpec` projections that contribute to the deployment-global render-source set. The only
public manifest boundary is Phase 9's `renderAll :: ProvisionedSpec -> [K8sObject]`; there is no public
per-service renderer.
The load-bearing property is that the *app surface bytes are
identical* across shapes while the bound `BoundServiceSpec` differs *structurally* (a different object graph, not a
`replicas: 1 → 3` edit) — the capability survives a move, the binding does not have to. Every foreclosure here
is honest about its layer: an app that names a product, or an engine named by URL, is **type-foreclosed** (no
syntax, fails Gate 1); a binding to an unbuilt provider arm is rejected by the genuine Gate-2 decoder; a
served model whose engine family is unavailable on the serving substrate lane, or a fully expanded
deployment whose target lacks sufficient
  CPU, memory, pod/CSI-attachment slots, pod-ephemeral storage (including mapped files/in-cluster cache),
  per-Pod kubelet/CRI runtime-metadata components routed by role through the selected filesystem layout and
  grouped once with the node's image-storage components,
  etcd logical quota, durable/native-cache/migration/metadata/database/object-store storage, every admission or
transition executor, Pulumi execution, accelerator count/family, or every identity-complete
residency/coexistence epoch against per-device net allocatable memory after its mandatory reserve,
is rejected after bind/expansion by a structured `ProvisionError` at the `provision-seal` locus. What is
*not* here: the render of a provisioned deployment into `[K8sObject]` ([Phase 9](phase_09_render_manifest_goldens.md));
the live realization of any provider or the actual jit-resolve of an engine into its bounded cache
([Phase 32](phase_32_jitbuild_engine_cache.md)); and the app-tenancy projection against live providers (the
live band).

**Substrate:** none — no host, no cluster, no provider; the gate is an in-process `cabal test` bind + property
+ corpus battery, analogous to the Phase-5 decode battery and the Phase-7 capacity/topology folds.

**Register:** 1 — pure/golden, in-process, no cluster.

**Gate:** the pure capability binder is green under `cabal test` — for the **representative set** (defined
concretely as one positive `CapabilityNeed` fixture per each of the **nine** capability arms — `ObjectStore`,
`SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`, `InferenceEngine` — bound
under both a `SingleNode` and a `Distributed { nodes = n }` (n ≥ 2) shape) every positive need decodes and
`bind`s to a well-typed `BoundServiceSpec` value and provisions against its declared target topology
in-process, with:
- **the structural-difference oracle satisfied** — the two bound `BoundServiceSpec`s' provider object graphs differ
  in **object-node multiset** (a `Distributed { nodes = n }` graph carries n member elements where `SingleNode`
  carries 1), verified by a deep structural diff (§5) that **fails when the difference is expressible as a
  single scalar-field edit — e.g. `replicas: 1 → 3` — or as a copied shape tag**; each bound value
  is checked equal to its **Phase-0-committed, reviewer-authored golden** (`golden_servicespec_<arm>_<shape>`),
  authored before `bind` exists so the golden cannot be regenerated from the implementation;
- **the app-surface bytes byte-identical across the two shapes**, where *app-surface bytes* is defined as the
  **beta-normalized Dhall expression of the app-surface slice extracted from each of the two *distinct*
  composed spec files** (never a shared import compared to itself), so the equality witnesses that the DSL
  forces shape/provider out of the app surface rather than reducing to a file-read tautology;
- **the post-bind provision boundary satisfied** — the expanded standard platform + provider + app graph
  first derives the exact infrastructure demand. A pre-existing fixture must prove
  `NoInfrastructureRequired`; a creation fixture must validate/CAS-enact its batch and feed receipt-bound
  `ObservedInfrastructureMaterialization` into `ProvisionContext`. It then produces an opaque
  whole-deployment `ProvisionedSpec` and its unique identity-keyed render-source set only after all CPU,
  memory, logical and layout-routed node storage (including catalog-derived cache populations,
  content/snapshot images, and model-derived Pod runtime-metadata components), presented/rounded durable and
  native-cache storage, scope-indexed node runtime/image-storage accounting, physical-partition
  `systemReserve raw debit + Σ unique VM provisionedBytes + Σ unique other raw parent debits ≤
  allocatableRawBytes` plus each VM's separate guest-usable nested fit (with no cross-unit or double debit),
  accelerator-device, and identity-complete residency-epoch folds pass; the
  `Observability` positive's workflow/rule/series cardinality stays inside its
  mandatory `MonitoringWorkBudget` and its Prometheus envelope equals the versioned cost-model derivation,
  while `illegal_monitoring_work_over_budget` returns `Left MonitoringBudgetExceeded`; and the committed
  `illegal_cuda_on_cpu_target`, `illegal_accelerator_count_shortage`,
  `illegal_accelerator_vram_shortage`, `illegal_accelerator_source_workload_mismatch`,
  `illegal_accelerator_policy_domain_mismatch`, `illegal_accelerator_residency_placement`, and
  `illegal_accelerator_coexistence_overcommit` fixtures return their exact structured `Left` tags before
  render. The
  committed `illegal_post_bind_expansion_overcommit` fixture has an app skeleton that fits alone but whose case
  table makes the selected provider's kind-indexed desired replica, surge instance, retained old revision, live
  terminating instance, sidecars, standard platform graph, model-derived kubelet/CRI runtime metadata, or one
  physical partition's unique child-carve sum exceed its exact boundary by one; each case must return its
  exact structured `Left`, proving the final fold runs
  after identity-keyed epoch expansion and component→role→layout-backing derivation;
and every product-named or URL-named or shape-in-app negative fixture (`illegal_product_in_app`: `minio` at the
app surface; `illegal_engine_by_url`: an engine named by URL; `illegal_shape_in_app`: a shape/provider authored
on the app surface) **fails Gate 1** (the Dhall typechecker) at its **asserted specific error/type-error
locus** — each paired with a positive differing only in the foreclosed dimension — with no binary run. The gate
turns **red** on ≥1 committed seeded mutant (§M.2, named in Sprint 8.4). A **Register-1** in-process check that
runs on no substrate.

## Doctrine adopted

- [`capability_extension_doctrine.md`](../documents/engineering/capability_extension_doctrine.md)
  — **the extension provide/require capability graph.** The binder validates the `extRequires` provide/require
  graph is total and acyclic and rejects an anti-shadow (shadowing) merge or a provide-and-require self-loop; a
  cyclic or shadowing extension fixture fails Gate 2 at its committed locus (the closed v1 extension set
  `{infernix, jitML}`).
- [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  — **Capability → provider → shape: the binding.** This phase implements the three-part binding as pure
  Haskell: the capability is chosen by application logic (written once, travels), and the provider (default
  the [§3](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates)
  canonical) and shape are chosen by deployment rules — realized as the total `bind`, not restated as prose.
- [`service_capability_doctrine.md §1`](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)
  and [`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set)
  — **why capabilities, not products**, and **the capability set.** The eight-arm closed union is the whole
  vocabulary an app has for "a service I depend on"; there is no arm for "some other service" and no arm that
  names a product, so an app that needs object storage selects `ObjectStore` and has no syntax with which to
  select `minio`.
- [`service_capability_doctrine.md §3`](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates)
  and [`§5`](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values)
  — **one canonical provider (the type admits alternates)** and **per-cluster structural shapes.** The provider
  slot is a typed union with one arm today and headroom for alternates; the shape is a typed choice
  (`SingleNode` vs `Distributed`) that selects *which manifest graph* to render — the structural generalization
  of the replica dial — and amoebius builds no alternate provider arm it does not yet need (headroom in the
  type, not shipped code).
- [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-substrate-selected-and-jit-resolved-never-authored)
  — the `InferenceEngine` capability: the engine is substrate-selected and jit-resolved, never authored —
  grounded in [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  — the ninth capability's provider is a closed union of substrate-tagged `EngineRuntime` identities with **no
  arbitrary-`Url`/`Download` arm**: an ML engine is a **named catalog identity** the shared jit-build resolver
  materializes on first miss into a `CacheBudget`-bounded content-addressed cache — never baked, never fetched
  by URL. This phase builds the *representational* union and the family×lane availability relation; the actual
  resolve is the live band.
- [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
  — **capabilities and the illegal-state contract:** an app cannot name a product (no arm — Gate 1), a
  capability cannot bind to a provider with no inhabitant (an unbuilt alternate does not decode — Gate 2), and
  a capability cannot be left unbound (an undecodable record, never a runtime `Pending`).
- [`resource_capacity_doctrine.md §3`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the complete resource envelope and the opaque post-fold `ProvisionedSpec` boundary. This phase owns the
  ordering: expand every provider/shape first, then run the Phase-7 folds, then hand only the checked result to
  Phase 9. A capacity check over a pre-bind skeleton is insufficient.
- [`illegal_state_catalog.md §3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent)
  (§3.12 — a product named in application logic) and
  [`§3.25`](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)
  (an ML asset named by arbitrary URL) — the two states this phase forecloses at Gate 1, honoring the
  load-bearing limit ([`§2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)):
  a type-check proves the *binding composes*, not that the *running provider* came up.
- [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — **the illegal-state-unrepresentable contract's two typed gates** (Gate 1 the Dhall typechecker, Gate 2 the
  in-process decoder): the capability union is guarded at Gate 1, the binding decodes through Gate 2 — this
  phase adds the capability-model instance of that contract, no live half.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2 (**Register 1** — pure/golden,
  in-process, no cluster) and §4 (the per-run proven/tested/assumed ledger): the register this gate reaches and
  the ledger it emits, with the live realization of any provider (and the jit-resolve of any engine) marked
  UNVERIFIED, owned by the live band.

## Sprints

## Sprint 8.1: The closed capability union + the no-product-arm Gate-1 foreclosure 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (the closed eight-arm capability union on the app surface
+ the app-surface `CapabilityNeed` records — buckets against `ObjectStore`, a database against `Sql`, topic
lifecycles against `MessageBus`, etc.); `src/Amoebius/Capability/Types.hs` (the Haskell `CapabilityNeed` and
the `BoundServiceSpec` skeleton the binder targets) — target paths, not yet built.
**Blocked by**: Phase 4 gate (the Gate-1 Dhall schema + smart-constructor prelude the union lives in); Phase 5
gate (the GADT-indexed IR + total decoder the `BoundServiceSpec` is a projection of).
**Independent Validation**: `dhall type` accepts every positive `CapabilityNeed` fixture and rejects the
`illegal_product_in_app` fixture (naming `minio` at authoring time, Gate 1) **at its asserted `dhall type`
error locus** — an *unknown-constructor / no-such-alternative* type error on the capability union — paired with
its positive `legal_objectstore_singlenode` differing only in that the product name is replaced by the
`ObjectStore` capability, so the negative cannot pass for an unrelated reason (typo, missing field); a unit
check confirms the union has exactly nine arms (the eight ordinary capabilities plus the `InferenceEngine` head
from Sprint 8.3) and no product arm and no "other service" escape arm, enumerated against a **Phase-0-committed
hand-authored arm list** independent of the union's own definition.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (Phase-8 status backlink),
`documents/engineering/app_vs_deployment_doctrine.md` (the app-surface capability-resource read-side),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §1`](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)
and [`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set):
build the closed capability union as the whole vocabulary an app has for a dependency, so that naming a
capability is the only move available and naming a product is not a word the grammar contains.

### Deliverables
- The closed eight-arm capability union (`ObjectStore`, `SecretStore`, `MessageBus`, `Sql`, `Identity`,
  `Observability`, `Registry`, `Edge`) on the app surface, with **no product arm** and no generic
  "some other service" arm — `minio` has no syntax.
- The app-surface `CapabilityNeed` records (buckets, a database, topic lifecycles, OIDC rules, published
  routes) read as *resources of a capability*, and the `BoundServiceSpec` skeleton the binder projects into.
- An in-file honesty note that this union is the app-facing *what*; the provider/shape *how* is Sprint 8.2, and
  the capability set is invariant across every cluster (a different capability *set* per cluster stays refused).

### Validation
1. `dhall type` accepts each positive `CapabilityNeed` and rejects a product-named app at authoring time (Gate
   1); the union has no product arm and no escape arm.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.2: The `CapabilityBinding` + total bind/whole-deployment provision boundary 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (extend: the `CapabilityBinding` records — the
one-arm-today provider union + the typed `shape`); `src/Amoebius/Capability/Binding.hs` (the pure total `bind`
selecting and fully expanding the provider's graph for the chosen shape, including kind-indexed execution controls
and controller-child lowering); `src/Amoebius/Capacity/Provision.hs` (`provision`, kind-indexed execution-epoch and
private `ProvisionedSpec` construction); `src/Amoebius/Capacity/RuntimeStorage.hs` (planned-slot and
observed-Pod-UID metadata shapes, component→role→layout-backing derivation, and scope-indexed node
runtime/image-storage aggregates); `src/Amoebius/Capacity/RenderSource.hs`
(`K8sObjectIdentity`, its compatibility alias `KubernetesObjectId`, closed private
`ProvisionedRenderSource identity` with closed
`RenderActivation = Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover |
AfterManagedCapacityReady`, and
`provisionRenderSources :: ProvisionedDeploymentParts -> Either ProvisionError ProvisionedRenderSourceSet`)
— target paths, not yet built. This Phase-8 source inventory deliberately does not import the Phase-9
`K8sObject`/Aeson renderer.
**Blocked by**: Sprint 8.1; Phase 5 gate (the IR + decoder).
**Independent Validation**: a unit + property suite binds the same app `ObjectStore`/`Sql` need under a
`SingleNode` shape and a `Distributed { nodes = n }` (n ≥ 2) shape and asserts:
(a) the **app-surface bytes are byte-identical**, where *app-surface bytes* is the **beta-normalized Dhall
expression of the app-surface slice extracted from each of two *distinct* composed spec files** — the two
composed fixtures do **not** share one app-surface import, so the equality is never a file-compared-to-itself
tautology;
(b) the bound `BoundServiceSpec` differs **structurally** by the oracle: the provider object graphs differ in
**object-node multiset** (`Distributed { nodes = n }` → n member elements, `SingleNode` → 1), asserted by a
deep structural diff (per [`service_capability_doctrine.md §5`](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values))
that **fails when the difference is expressible as a single scalar-field edit (e.g. `replicas: 1 → 3`) or a
copied shape tag** — plain `/=` does not satisfy it — and each bound value is checked equal to its
**Phase-0-committed reviewer-authored golden** `golden_servicespec_<arm>_<shape>` (authored before `bind`
exists, never regenerated from `bind`'s output);
(c) the `illegal_shape_in_app` negative — a shape or provider authored on the **app** surface — **fails
`dhall type`** at its asserted type-error locus (the app-surface record has no `shape`/`provider` field),
paired with its positive differing only in that the shape moves to the deployment-rules surface, witnessing the
byte invariant the check in (a) is meant to prove;
a binding naming a provider arm amoebius has not built returns a structured `Left` at decode (Gate 2) **tagged
with its specific `DecodeError` (unbuilt-provider-arm)**. The property also compares the independently
enumerated kind-indexed `(sourceUnit, revision, ordinal)` instance/epoch map with the provision result,
exact-fits the largest steady/rollout epoch, and rejects one-unit-short desired-replica, surge, and old-revision
variants.
A separate pure test supplies a normalized observed inventory to the same fold and exact-fits the live
desired∪old∪terminating∪scheduler-ledger union, including confirmed-bound `BindingRecovery`, with a
one-unit-short terminating-live pair. Controller children lower to that
same map with no second debit. Every planned Pod slot has one structural, model-pinned metadata shape; the
normalized live input instead keys rows by authenticated Pod UID and source witness. Provision derives every
component's `KubeletNodefs | CriRuntimeRoot` role, resolves it through the selected layout, and builds one
exact node aggregate per epoch/snapshot with disjoint qualified Pod/image ownership and one debit per grouped
carve. Dropping the largest simultaneous row, removing/changing the target model, dropping/swapping a role,
mismatching a planned/observed domain, overlapping/leaking ownership, double-debiting an alias, or reducing
either SplitRuntime nodefs or imagefs/containerfs by one byte rejects.
For an elastic planned target the retained layout is
`PerInstanceKubeletFilesystemLayout`: every backing route is an elastic
`(ProviderInstanceId, DiskTemplateId, DiskCarveTemplateId)` reference and no concrete `DiskCarveId` may
appear. An `ObservedNodeTargetBinding` must materialize every such reference to one observed backing exactly
once before observed runtime accounting; a missing, extra, aliased, wrong-instance/disk/carve, or byte-unequal
mapping rejects.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§3/§4/§5 binding backlink),
`documents/engineering/manifest_generation_doctrine.md` (who seals the whole-deployment render-source set),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding),
[`§3`](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates),
and [`§5`](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values):
implement the three-part binding as a pure total function so that one byte-identical app spec binds to a
structurally different `BoundServiceSpec` per cluster, then provision the fully expanded graph against that
cluster's topology before anything can render.

### Deliverables
- A `CapabilityBinding` whose `provider` is a **one-arm-today** typed union defaulting to the
  [§3](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates)
  canonical provider (headroom for an alternate, but no adapter amoebius does not yet need), and whose `shape`
  is a typed choice (`SingleNode` vs `Distributed { nodes }`), bound only on the deployment-rules surface.
- `bind :: CapabilityNeed -> CapabilityBinding -> BoundServiceSpec`, pure and total, selecting the provider's
  **manifest graph for the chosen shape** — a structurally different object graph, not a scalar `replicas`
  edit. Every runnable becomes a complete unprovisioned `BoundExecutionUnit` with one private
  controller/resource-compatible body. Deployment carries `ReplicaCardinality` and only
  `DeploymentRolloutPolicy`; StatefulSet carries its native replica count and serial
  `StatefulSetRolloutPolicy`; DaemonSet carries `NodeEligibilitySelector` and only
  `OnDelete | RollingUpdate (Surge | Unavailable)`; Job carries
  completions/parallelism/backoff, `restartPolicy=Never`, replacement-on-Failed, and finite terminal
  retention; HostProcess carries `HostProcessCardinality` plus supervisor replacement policy; provision alone
  resolves that cardinality to its host→slot map. A CUDA Pod is
  structurally a DaemonSet with serial `OnDelete`; CUDA host and Metal host arms structurally force their
  release/drain lifecycle. There is no unit-level replica scalar,
  caller terminating bound, generic strategy record, controller/resource cross-product, or unsupported
  StatefulSet feature field. During topology-aware provision, `ReplicaCardinality.Once` yields one planned slot,
  `NodeEligibilitySelector` is the canonical closed conjunction of typed engine-role, provider-class, site,
  accelerator-profile, and inventory-taint constraints, with no free-text selector/toleration. Provision
  exact-joins those constraints and derives the eligible set; Deployment/StatefulSet replicas and Job waves
  yield exact finite slot sets, DaemonSet derives exactly one slot per selected node, and HostProcess derives
  its exact host→slot map; a
  missing constraint target or missing, extra, or ineligible slot rejects. These arms are
  structural inputs to provision, never an authored or bound peak.
  For every operator/CR arm, a version-pinned expander joins the descriptor's exact kind-indexed controller
  policy, complete
  child pod-resource-template, and child durable-volume operands, then alone constructs a private
  identity-keyed `ControllerChildEnvelope`. Each child is lowered into the same kind-indexed
  `BoundExecutionUnit` vocabulary and epoch provisioner; the controller witness explains and
  exact-joins the descriptor→child expansion but contributes no second debit. A caller cannot author a scalar
  child peak, a generic child list, or a resource-free CR. The same model derives the validating webhook's
  complete pod/image/resource/transition envelope;
  every DaemonSet arm remains a symbolic node-selected execution unit until `NodeSupply` supplies a fixed node
  or elastic candidate-class count. Accelerator owners are grouped by immutable homogeneous offering-class
  key (resource/profile/full count/net-VRAM/link topology), producing one uniform owner template per class;
  class affinities are disjoint and cover every accelerator node/candidate exactly once. There is no
  resource-free CR, heterogeneous-count single-DaemonSet shortcut, or unmultiplied per-node side channel.
  Every domain composite is exhaustively flattened into the canonical identity-keyed `BoundExecutionSet`;
  equality with the expanded runnable-source inventory rejects an omitted worker/controller/gateway/Job, and
  every unit has exactly one compatible controller body. The enclosing
  `BoundExecutionInventory` retains exactly one
  `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` source for the entire deployment, so removed
  prior-only units remain resolvable even though they have no current unit. `BoundDeployment` retains only
  these unprovisioned units, the opaque source ref, and controller explanations—no resolved prior inventory,
  materialized instance, epoch placement, or `Provisioned*` value.
- Binding expands `ObjectStoreProducerIntent` into the six-arm closed binder-output
  `ObjectStoreProducerDemand` inventory and resolves every app/content
  bucket, registry tenant, Pulsar offload topic, Pulumi checkpoint stack, and control-plane-state namespace to
  exactly one required
  `StorageBudgetId`. Its `Fixed`, `QuotaCapped`, or `Growable` arm retains one backing/quota owner selected by
  the provider shape; missing, duplicate, or mismatched ownership is `Left StorageBudgetMismatch`, never an
  implicit MinIO/global default. From `ObjectStoreGatewayIntent` plus all producer writer policies it alone
  constructs `ObjectStoreAdmissionGatewayDemand`, including the sole object-write gateway's complete
  unprovisioned pod/image/resource/transition envelope; producer storage fitting while this gateway does not
  is a provision failure.
- Every Pod `ResourceEnvelope` carries a byte-free `PodRuntimeMetadataSource` containing exact non-empty
  network-attachment ids and container→volume mount references; the remaining container and volume inventory
  stays in the surrounding Pod envelope. Sandbox and Pod-directory multiplicity comes only from materialized
  execution. Once `provision` expands kind-indexed units, it derives one `KubeletRuntimeMetadataShape` per
  planned Pod slot: exact sandbox/Pod-directory/runtime/CNI/volume/mount counts, source-unit identity, and the
  selected node's `kubeletMetadataModel`. The same pure fold used later by live admission instead constructs an
  observed demand keyed by authenticated `PodUid` plus its owner/source witness; a planned slot id is never a
  live identity.

  The private provision result, never a caller scalar, derives every metadata component's bytes and
  `KubeletNodefs | CriRuntimeRoot` role, proves the role sums, resolves roles through
  `Unified | SplitRuntime | SplitImage`, and groups aliases by physical carve once. Pure `provision` then
  builds one `ProvisionedNodeRuntimeStorageAccounting` per node and planned epoch fingerprint; the same shared
  fold, invoked later by live preflight, builds the observed-inventory-fingerprint form: exact assigned
  metadata-id domain, qualified Pod/image component ownership that is disjoint
  and exhaustive, and a final grouped backing map combining metadata with the
  `ProvisionedNodeImageStorageDemand`. SplitRuntime therefore charges kubelet components to nodefs and CRI
  components to imagefs/containerfs; Unified and SplitImage sum their forced aliases before one backing check.
  None of these physical bytes is repeated as logical Pod ephemeral demand. In normalized live algebra,
  `PendingUnscheduled` is API-only; `Reserved` and unbound/unknown-outcome `BindingInFlight` spend the planned
  placed vector in the scheduler ledger. A confirmed Bound Pod whose ledger is still in flight instead enters
  the observed-Pod-UID `BindingRecovery` arm, while `Bound`/`Terminating` or terminal-retained axes instantiate
  observed-UID rows; the reservation/observed join proves a bound UID is not charged twice.
- Binding derives `KubeletMappedFileDemand` and serialized `KubernetesApiObjectDemand` from the same typed
  ConfigMap/Secret/projected/downward-API/token sources, using pinned AtomicWriter and etcd models; no caller
  supplies either byte aggregate. Using the Gate-2-validated and branded source refs, the transition expander refines
  `StorageMigrationIntent → StorageMigrationDemand { old : PriorVolumeProvisionRef, ... }` and
  `RegistryBackendMigrationIntent → RegistryBackendMigrationDemand { source : PriorRegistryProvisionRef, ... }`;
  it exact-joins `RegistryStorageIntent` image digests to selected `ImageArtifact` metadata to construct
  `RegistryStorageDemand`, and normalizes `SchemaMigrationIntent → SchemaMigrationDemand`. These remain
  unprovisioned: binder-derived copy/transfer/schema executor envelopes enter `BoundExecutionSet`, but
  old/new rounded volumes, digest copy maps, workspace/WAL/per-backing peaks, and every private migration
  witness are constructed only by `provision` after it resolves the opaque ref against `ProvisionContext`.
  MessageBus expansion includes the complete ZooKeeper member/volume/znode/churn demand separately from
  broker/BookKeeper/offload; every `PatroniSqlIntent` constructs its own unprovisioned `PatroniSqlDemand`,
  including binder-derived children, rather than reusing another consumer's provision. Every independent
  Pulumi deploy expands into `PulumiExecutionDemand` plus unprovisioned executor-pod envelopes. All
  admission/copy/schema/Pulumi units enter the same kind-indexed `BoundDeployment` execution inventory.
- The `Observability` arm consumes its mandatory finite
  `MonitoringWorkBudget { maxWorkflows, maxRules, maxSeries, maxScrapeSamplesPerSecond,
  evaluationInterval, evaluationCpu, evaluationMemory, retention,
  query : QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout,
  costModel }, volume, tsdbCostModel }`. Binding derives workflow/rule/series/sample-rate counts from the complete expanded descriptor;
  then named, version-pinned conservative cost models derive Prometheus CPU/memory requests and limits from
  baseline + evaluation work overlapping maximum concurrent query work, and derive the query-admission
  proxy's complete pod envelope and a `DeclaredVolumeDemand`. A count/rate over budget or derived
  Prometheus/proxy envelope over the declared CPU/memory ceilings returns `Left MonitoringBudgetExceeded`
  during binding. There is no
  descriptor-independent fixed-request/tiny-PVC/scalar-query-temp override and no optional-budget path. The
  versioned TSDB/query models derive resident blocks + WAL/head + compaction overlap + query/temp peak from
  the structural query operands; `provision` then
  applies the declared presentation/overhead and backing quantum to construct the private Prometheus
  `ProvisionedVolumeDemand` or returns the physical storage-fit `ProvisionError`. The same query operands configure Prometheus concurrency/sample/timeout flags
  and the sole-routable query-admission proxy's series/range bounds; direct query API access is denied.
- `planInfrastructure :: ProvisionTargetSupply -> BoundDeployment -> Either ProvisionError
  InfrastructurePlanningResult`, run after every capability/provider graph and standard-platform expansion.
  `StandaloneRoot` supplies the complete declared node/host/account/backing/API-etcd inventory; `ForestMember`
  supplies the exact opaque `ClusterBudget`. Demand is derived internally from `BoundDeployment`.
  `InfrastructureRequired` contains one batch-owned Pulumi graph/checkpoint/dependency/concurrency/quota
  partition and fresh plan token; child-create payloads contain bound intent and budget, never a circular
  child `ProvisionedSpec`. Receipt-bound materialized nodes/root volumes/provider volumes construct
  `ProvisionContext`; replay, missing readback, or promised identities reject.
- `provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec`, run after every
  capability/provider graph and the standard platform set have been expanded. Its private constructor stores
  compute placement, `ProvisionedExecutionEpochs`, per-class/per-node expansion,
  pod-ephemeral/cache-population nesting, pod-slot and unique-driver-PVC attachment placement, mapped-file
  physical routing, per-slot `ProvisionedKubeletRuntimeMetadataDemand`, scope-indexed
  `ProvisionedNodeRuntimeStorageAccounting`, etcd logical quota fit, selected-platform OCI-content/snapshot
  placement by filesystem layout, durable
  presentation/allocation/native-host-cache backing, old+new volume/registry/schema migration execution,
  ZooKeeper metadata and Patroni database witnesses, controller-child transition/webhook bounds, six-arm
  object-producer/storage-budget/admission-gateway witnesses,
  Pulumi executor/checkpoint demand, mandatory reconciler Lease, and
  `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses. It also stores exactly one
  deployment-global `ProvisionedCapacitySchedulerSystem`: complete default-scheduled bootstrap reservation,
  pods=1 quota, prior+desired controller-child reservation config, managed-node taint/admission/Binding RBAC,
  aggregate root-ledger schema/byte/churn bound, readiness requirement, and unique global render owner.
  `provisionRenderSources` also seals one source per Kubernetes object identity; shared Namespace/quota/
  scheduler/admission/RBAC/Lease/CRD sources have one global owner, and duplicate/omitted source-domain
  mutants reject before `ProvisionedSpec`. Each map key equals the embedded source identity, and the source's
  provisioned-part witness fixes its owner, fields, reconcile mode, and activation stage. `renderAll` still
  lists the complete desired set; the later typed diff/enactor must honor activation, so managed-node
  taint/admission objects cannot be swept into the first generic apply. Phase 9 privately maps the unique
  source set and exposes only whole-deployment `renderAll`; no service projection can invoke render on its
  own.
  `BoundDeployment` contains no
  `Provisioned*` record: its only links to old successful generations are
  `PriorExecutionProvisionRef`, `PriorVolumeProvisionRef`, and `PriorRegistryProvisionRef`. `provision`
  exact-matches deployment/generation/resource arm in `ProvisionContext`; missing, stale, wrong-generation,
  wrong-arm, source-unit/revision/ordinal/resource, and identity/live-snapshot mismatches reject before any
  allocation or copy. `FirstDeployment` resolves to the exact empty prior execution inventory.
- Before any placement subtraction, `provision` resolves the whole deployment's exact prior steady execution
  projection, then expands each desired `BoundExecutionUnit` through its kind-indexed controller body into
  `MaterializedExecutionInstance`s and complete, empty-capable `ExecutionEpoch`s. Desired and prior instance
  ids exact-join their own `(ExecutionUnitId, revision, ordinal, resource)` sources; the steady map contains
  the exact desired live service/daemon/host slot domain and may be empty for completed Job-only deployments,
  while planned rollout maps enumerate policy-reachable
  new/surge/old/zero-live steps. Unchanged identities dedup, changed revisions keep distinct old/new
  envelopes, added units have no old twin, and removed prior-only units remain through apply-before-prune.
  Terminating instances are not guessed from a raw bound: normalized live input exact-joins them to the
  referenced prior generation. Duplicate, orphan, wrong-revision, copied-new-as-old, swapped-ordinal, dropped,
  or invented-first-deploy identities reject. Placement evaluates the
  full resource vector in every epoch—CPU, memory, pod/CNI/CSI slots, logical Pod ephemeral, component/role/
  layout-routed runtime and image storage, durable volumes/cache, and accelerator device/residency epochs—and retains the
  componentwise transition witness. It also derives ResourceQuota/source-revision admission and an
  `amoebius-capacity` scheduler projection whose same-binary scheduler role validates provenance and exact
  child discriminator, resolves fixed/elastic target identity, re-folds static/foreign/resident plus the
  whole identity-aware ledger and candidate, CASes the single root `Reserved→BindingInFlight`, submits
  Kubernetes Binding, and CASes `BindingInFlight→Bound` after exact UID/node readback.
  Reserved/in-flight/bound candidates, observed terminators, and resident
  physical artifacts remain charged; an absent Pod selects a state-indexed ledger-only recovery that keeps
  the exact full/retained axes until release or cleanup CAS. Concurrent controller
  candidates cannot race on one residual. Controller-derived children pass
  through this exact mechanism; their private controller witness is checked for source equality and is not a
  second provision or debit. These materialized/provisioned results occur only inside `provision` and its opaque
  output, so direct multiplicity fields do not weaken the wholly unprovisioned `BoundDeployment` boundary. The
  same pure identity/revision epoch algebra is later reused by live admission, which exact-joins desired,
  referenced-prior old, observed still-terminating, and scheduler-reservation identities until observed
  disappearance and folds the same full resource vector; Phase 8 tests that algebra with normalized fixtures but performs no live read and claims no
  runtime proof.
- An in-file honesty note: a single-node shape is the canonical provider deployed honestly at small scale (a
  one-member Patroni `Sql`, never a bare `postgres` Pod); `bind` produces a value, not a live provider — the
  live realization is the live band.

### Validation
1. The same `CapabilityNeed`, bound under two shapes, produces two `BoundServiceSpec`s that are **structurally
   different by the object-node-multiset oracle** (deep structural diff per §5, red on a scalar-only or
   copied-shape-tag difference; each equal to its Phase-0-committed golden), while the **app-surface bytes**
   (beta-normalized app-surface slices from two distinct composed spec files) are identical; a binding to an
   unbuilt provider arm returns a structured `Left` tagged (Gate 2); `bind` never throws. An independent
   inventory rederives exact desired and resolved-prior
   `(sourceUnit, revision, ordinal, resource) → MaterializedExecutionInstance` equality and exact-fits
   steady (including a Job-completed empty control) plus every empty-capable rollout step; each one-unit-short
   replica/surge/old/removed case
   rejects. It covers exact-empty first deployment, a recreate zero-live step, different old/new envelopes,
   added/removed units, and exact-generation lookup. A separate pure
   normalized-observation property
   exact-fits the live desired∪referenced-old∪terminating∪scheduler-reservation union and rejects its
   one-unit-short terminating pair, copied-new-as-old input, wrong generation, invented first-deploy old row,
   and two-candidate stale-residual race. Its
   runtime-storage fold exact-fits the grouped node backings and rejects SplitRuntime nodefs or
   imagefs/containerfs one byte short, a missing/mismatched model, dropped/swapped component role,
   planned/observed domain mismatch, qualified Pod/image ownership hole/overlap, alias double debit, or a
   dropped largest simultaneous metadata row. This validation must
   go **red** on the committed `mutant_copy_shape_tag` seeded mutant (Sprint 8.4) — which makes `bind` copy the
   shape tag into a `providerGraph` field instead of selecting a manifest graph, passing a plain `/=` but
   failing the multiset oracle.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.3: The `InferenceEngine` capability — target-offering-selected runtime + accelerator provision 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (extend: the `InferenceEngine` head, the closed
`EngineRuntime` lane union, the engine-family union, and identity-complete
`CudaOwnerDemand`/`MetalOwnerDemand` source, workload, residency, and coexistence shapes);
`src/Amoebius/Capability/Engine.hs` (the target-offering→lane quotient projection and the **partial** family×lane
availability relation plus topology-offering compatibility) — target paths, not yet built.
**Blocked by**: Sprint 8.1, Sprint 8.2; Phase 7 gate (the identity-complete accelerator-residency epoch fold
these owner demands feed).
**Independent Validation**: a unit + property suite confirms the `EngineRuntime` union has **no** `Url`/`Download`
arm (an engine named by URL fails `dhall type`, Gate 1); the target-offering→lane quotient projects
`apple → AppleMetal`, `linux-cpu → LinuxCpu`, `{ linux-cuda, windows } → Cuda` for a **selected target
offering** and has no constructor to author a lane free of that offering. It also proves
`keys(sources) = keys(workloads)` and
`domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)`; derives every allowed
coexistence epoch; and rejects CUDA-on-CPU, too few devices, malformed
Unsharded/ReplicatedPerDevice/Sharded placement,
or any epoch whose per-device aggregate exceeds net allocatable memory. A case that fits raw device
`memory.total` but exceeds `allocatableVram`, an omitted work item, and a favorable-epoch-only acceptance each
return their exact structured `Left`; product labels and raw totals are never supply.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§4.1 backlink),
`documents/engineering/content_addressing_doctrine.md` (§4.5 Tier-1 engine read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.25 layer reconciliation), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-substrate-selected-and-jit-resolved-never-authored)
and [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
build the ninth capability as the strictest instance of the [§4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
binding — a provider selected from a **concrete eligible target offering** (whose lane is projected from that
node/host or candidate's detected substrate) and materialized on first miss, with no arm to author a download
— as a representational union and relation, no live resolve.

### Deliverables
- The `InferenceEngine` capability and its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` ·
  `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm** — an ML engine is a **named catalog identity**, never
  baked and never fetched by URL, so "name the engine by URL" has no syntax and fails Gate 1.
- The target-offering→lane **quotient** projection (`apple → AppleMetal`, `linux-cpu → LinuxCpu`,
  `{ linux-cuda, windows } → Cuda`, `Cuda` OS-agnostic with no Linux-vs-Windows constructor) — selected from a
  concrete eligible node/host or elastic candidate, not from an ambiguous cluster-wide substrate — and the
  closed engine-family union.
- The **partial** family×lane availability relation making a served model whose family is unavailable on the
  serving lane a post-bind **`provision-seal` `Left`** (the [`illegal_state_techniques.md §4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  relation-over-a-collection technique), plus identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` values:
  an exact source inventory and equal-keyed workload map for served models, training jobs, JIT compilations,
  and library work; structural weights/KV/activation/optimizer/JIT/library residency components; and finite
  class-complete coexistence policy. CUDA residency uses `Unsharded`, `ReplicatedPerDevice`, or explicit
  `Sharded` placement. Bytes are total for Unsharded/Sharded and per device for ReplicatedPerDevice; shard ids are
  unique, shard bytes sum to the residency total, and shard count cannot exceed owner devices. The Phase-7
  fold derives all policy-permitted epochs and sums every co-resident component by device; Metal derives the
  identical epochs into shared host memory rather than a separate VRAM scalar.
- An in-file honesty note: this is the representational union + relation only; the actual jit-build resolve into
  the `CacheBudget`-bounded content-addressed cache, and the runtime-checked cross-lane weight-load residue,
  are the live band ([Phase 32](phase_32_jitbuild_engine_cache.md)) — sibling evidence where infernix's
  `Worker.hs` selects (never fetches) its engine, not an amoebius result.

### Validation
1. An engine named by URL fails Gate 1; an unavailable family-on-lane, CUDA-on-CPU target, insufficient
   device count, unequal source/workload keys, unequal policy-class domains, invalid shard ids/sum/count,
   unplaceable residency, raw-fits/net-fails epoch, omitted co-resident work item, or favorable-epoch shortcut
   returns its exact structured `Left`; the target-offering→lane quotient is total and the OS-vs-Cuda split
   has no inhabitant.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.4: The binder property/corpus + the Register-1 gate 📋

**Status**: Planned
**Implementation**: `test/capability/BindingProps.hs` (the property battery),
`test/capability/RuntimeStorageBindingProps.hs` (planned-slot/observed-UID domains, role/layout resolution,
node aggregate ownership/grouping, reservation/observed no-double-debit, and exact-fit/one-byte-short cases), `test/capability/BindGate.hs`
(the gate + validation-locus ledger with coverage-assertion machinery), the **Phase-0-committed** per-arm
positive fixtures `dhall/examples/legal_<arm>_{singlenode,distributed}.dhall` for all nine arms, the reviewer
-authored goldens `test/capability/goldens/golden_servicespec_<arm>_<shape>.golden` (authored before `bind`
exists), the seeded mutants under `test/capability/mutants/{mutant_copy_shape_tag,mutant_catchall_arm,
mutant_shared_app_import,mutant_fixed_prometheus_requests,mutant_provisioned_value_in_bound_deployment,
mutant_unchecked_prior_ref,mutant_drop_execution_replica,mutant_drop_execution_surge,
mutant_drop_execution_old_revision,mutant_wrong_execution_revision_join,
mutant_double_debit_controller_child,mutant_drop_largest_kubelet_metadata,
mutant_missing_kubelet_metadata_model,mutant_drop_accelerator_work_item,
mutant_accept_accelerator_domain_mismatch,mutant_select_favorable_accelerator_epoch,
mutant_drop_accelerator_overlap_debit,mutant_skip_accelerator_shard_validation}`, and
`dhall/examples/{legal_objectstore_singlenode,legal_objectstore_distributed,
legal_inference_cuda,illegal_product_in_app,illegal_engine_by_url,illegal_shape_in_app,
illegal_unbound_capability,illegal_unbuilt_provider,illegal_engine_family_unavailable_on_lane,
illegal_cuda_on_cpu_target,illegal_accelerator_count_shortage,illegal_accelerator_vram_shortage,
illegal_accelerator_source_workload_mismatch,illegal_accelerator_policy_domain_mismatch,
illegal_accelerator_residency_placement,illegal_accelerator_coexistence_overcommit,
illegal_monitoring_work_over_budget,illegal_post_bind_expansion_overcommit}.dhall` — target
paths, not yet built.
**Blocked by**: Sprint 8.1, Sprint 8.2, Sprint 8.3; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: `cabal test capability-spec` is green — each of the **nine per-arm** positive needs
binds to a well-typed `BoundServiceSpec` under both shapes and provisions to opaque whole-deployment
`ProvisionedSpec`s on its positive topology, with byte-identical app bytes (beta-normalized
app-surface slices from distinct composed files) and a structural difference passing the object-node-multiset
oracle (red on scalar-only / copied-shape-tag) against its Phase-0-committed golden; the exhaustiveness check
confirms all nine arms are covered; the QuickCheck totality property fires each of the nine constructors ≥ 8%
(`checkCoverage`); each Gate-1 negative fails `dhall type` **at its asserted error locus**; each genuine
Gate-2/decode negative returns a structured `Left` **tagged with its specific `DecodeError`**; and each
post-bind capacity, placement, or accelerator negative returns its specific `ProvisionError` at the
`provision-seal` locus. Every negative is annotated with its catalog entry (§3.12 / §3.25 / §3.27 / §3.30)
and foreclosure layer and paired with a minimally-differing positive. The CUDA-on-CPU, device-count, and VRAM
negatives fail after binding but before `renderAll` with zero provisioned values; the monitoring negative
exceeds one derived cardinality axis by one and
returns `Left MonitoringBudgetExceeded` without retaining fixed Prometheus requests; and the
post-bind-expansion overcommit proves the final fold includes
kind-indexed desired/old/surge/terminating identities, sidecars, component/role/layout-routed Pod runtime metadata, caches/volumes,
and the standard platform graph rather than only the raw app; exact-fit and one-unit-short epoch/backing pairs
exercise both boundary directions;
the eighteen committed seeded mutants (`mutant_copy_shape_tag`, `mutant_catchall_arm`,
`mutant_shared_app_import`, `mutant_fixed_prometheus_requests`,
`mutant_provisioned_value_in_bound_deployment`, `mutant_unchecked_prior_ref`,
`mutant_drop_execution_replica`, `mutant_drop_execution_surge`,
`mutant_drop_execution_old_revision`, `mutant_wrong_execution_revision_join`,
`mutant_double_debit_controller_child`, `mutant_drop_largest_kubelet_metadata`,
`mutant_missing_kubelet_metadata_model`, `mutant_drop_accelerator_work_item`,
`mutant_accept_accelerator_domain_mismatch`, `mutant_select_favorable_accelerator_epoch`,
`mutant_drop_accelerator_overlap_debit`, and `mutant_skip_accelerator_shard_validation`)
each turn the suite **red** when substituted; the run emits a Register-1 proven/tested/assumed ledger whose
coverage-assertion machinery is red if any named fixture, negative reason, or mutant is absent.
**Docs to update**: `documents/engineering/service_capability_doctrine.md`,
`documents/illegal_state/illegal_state_catalog.md` (§3.12/§3.25 → realized layer),
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-8 status when the
gate passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-8 `none` gate row).

### Objective
Adopt [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
and [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2/§4: assemble the phase's single
Register-1 gate — every positive need binds and provisions to a checked deployment while every product- or
URL-named app has no syntax and every insufficient target returns its specific `ProvisionError` without
constructing `ProvisionedSpec` — and emit the per-entry
validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables
- The **concrete positive corpus** — **one fixture per each of the nine capability arms** (`ObjectStore`,
  `SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`, `InferenceEngine`),
  each bound under **both** a `SingleNode` and a `Distributed { nodes = n }` (n ≥ 2) shape — so the corpus is
  not scope-shrunk to the three named `legal_objectstore_{singlenode,distributed}` / `legal_inference_cuda`
  fixtures. A committed **exhaustiveness unit check** asserts the fixture→capability-arm map covers the full
  nine-arm union (red if any arm has no positive fixture), enumerated against the **Phase-0-committed
  hand-authored arm list** (Sprint 8.1), independent of `bind`'s own case analysis.
- The property battery: the same `CapabilityNeed` bound under two shapes yields two `BoundServiceSpec`s
  **structurally different by the object-node-multiset oracle** (red on scalar-only / copied-shape-tag) with
  byte-identical app bytes (beta-normalized app-surface slices from distinct composed files); **every declared
  need binds totally (no partial `bind`) across all nine arms**, with QuickCheck `label`/`classify` +
  `checkCoverage` obligations forcing each of the **nine need constructors** to fire a stated minimum fraction
  (≥ 8% each), so a generator emitting only the three covered constructors fails coverage; an unbound
  capability is an undecodable record, not a runtime `Pending`; after the full graph is expanded,
  a structural inventory proves `BoundDeployment` contains no `Provisioned*` field and that the Registry arm
  crosses `ObjectStoreProducerIntent.Registry : RegistryStorageIntent` to
  `ObjectStoreProducerDemand.Registry : RegistryStorageDemand`; `provision` is total and its successful values pass an implementation-independent check that every
  private `ProvisionedServiceSpec` projection carries placement, pod/CSI-slot, mapped/API-object,
  execution/admission, storage/migration/cache/database/metadata, and accelerator witnesses. It also checks
  that the complete `ProvisionedDeploymentParts` domain contributes exactly one equal-keyed
  `ProvisionedRenderSource` per object identity to the sole `ProvisionedSpec.renderSources`; duplicate,
  omitted, key/embedded-identity-mismatched, or owner-mismatched candidates reject before Phase 9. No public
  function accepts one service projection for rendering. The property also independently classifies every
  source into `Immediate | BootstrapSchedulerStage | AfterBootstrapAddonCutover |
  AfterManagedCapacityReady` and rejects a missing/extra stage, a managed taint/admission source in an early
  stage, or a source whose activation disagrees with its provisioned owner. The same independent check enumerates
  every kind-indexed unit's exact `(sourceUnit, revision, ordinal)` instance set for steady and all rollout steps,
  including controller-lowered units exactly once. A separate pure property feeds normalized observed
  identities to the shared fold and checks the live
  desired∪old∪terminating∪scheduler-ledger union, including confirmed-bound `BindingRecovery`, without claiming a live
  read. It derives one model-pinned shape for every planned Pod slot and an authenticated-UID shape for every
  eligible observed Pod; derives the exact metadata component→`KubeletNodefs | CriRuntimeRoot`→layout-backing
  map; and proves the largest simultaneous epoch/snapshot node aggregate has the exact assigned domain,
  disjoint/exhaustive qualified Pod/image component ownership, and one grouped debit per carve. Exact-fit
  generated cases accept; SplitRuntime nodefs and imagefs/containerfs one-byte-short cases and role/domain/
  ownership/alias mutants reject.
  Elastic-target cases independently assert that planned runtime/image storage carries the class's
  `PerInstanceKubeletFilesystemLayout` and only elastic `(instance,disk,carve)` refs, never a fabricated
  concrete `DiskCarveId`; observed binding materializes the exact ref domain one-for-one. Missing, extra,
  swapped-instance, wrong-template, alias, or capacity-mismatched materialization fixtures reject before an
  observed debit or action is produced.
- The negative corpus — `illegal_product_in_app` (§3.12, Gate 1), `illegal_engine_by_url` (§3.25, Gate 1),
  `illegal_shape_in_app` (shape/provider on the app surface, Gate 1), `illegal_unbuilt_provider` (Gate 2),
  `illegal_engine_family_unavailable_on_lane` (`provision-seal`),
  `illegal_unbound_capability` (undecodable),
  `illegal_cuda_on_cpu_target` (`ProvisionError MissingCapability Cuda`),
  `illegal_accelerator_count_shortage` (`ProvisionError AcceleratorCountShortage`),
  `illegal_accelerator_vram_shortage` (`ProvisionError VramOvercommit`),
  `illegal_accelerator_source_workload_mismatch` (unequal source/workload keys),
  `illegal_accelerator_policy_domain_mismatch` (missing or extra represented workload class),
  `illegal_accelerator_residency_placement` (invalid Unsharded/ReplicatedPerDevice/Sharded assignment, including
  non-unique shard ids, wrong shard sum, or too many shards), and
  `illegal_accelerator_coexistence_overcommit` (steady components fit separately but a policy-permitted
  co-resident epoch is one byte over one device), plus
  `illegal_monitoring_work_over_budget` (`Left MonitoringBudgetExceeded`: the expanded `Observability`
  descriptor exceeds one mandatory finite workflow/rule/series/evaluation-work bound by one; its paired
  positive differs only in that bound),
  `illegal_post_bind_expansion_overcommit` (a case table returning the exact one-short axis when the raw app
  fits but provision's complete materialized kind-indexed desired/surge/retained-old/live-terminating identity
  epochs, sidecars, platform graph, or component/role/layout-routed Pod runtime metadata, controller webhook, object gateway,
  ZooKeeper member, Patroni child, or volume/registry/schema/Pulumi transition executor does not),
  `illegal_controller_child_unbounded` (`Left UnknownCommitment`: a CR arm has no finite child
  pod/PVC/rollout envelope), and `illegal_elastic_per_node_expansion_overcommit` (a workload fits raw
  candidate allocatable but not after multiplying/subtracting required per-node execution units), plus
  `illegal_prior_provision_ref_{missing,stale,wrong_generation,wrong_arm}` (the corresponding structured
  `ProvisionError` before transition execution) —
  each asserting **its specific failure reason** (its expected `dhall type` error locus, `DecodeError` tag,
  or post-bind `ProvisionError` tag)
  and each **paired with a positive differing only in the foreclosed dimension**, alongside the positive
  nine-arm corpus above that binds feasibly.
- **Committed seeded mutants (§M.2)** — a defined operator set of eighteen deliberately broken implementations,
  committed and re-run (not run once), that the gate MUST turn red: `mutant_copy_shape_tag` (effect swap:
  `bind` copies the shape tag into a `providerGraph` field instead of selecting a manifest graph — defeats a
  `/=`-only diff, caught by the multiset oracle); `mutant_catchall_arm` (union-arm addition: a catch-all
  `bind` arm returns a degenerate `BoundServiceSpec` for the six uncovered capabilities — caught by the per-arm
  golden + exhaustiveness check); `mutant_shared_app_import` (the two composed fixtures share one app-surface
  import — makes byte-equality vacuous — caught by the distinct-composed-file requirement in (a));
  `mutant_fixed_prometheus_requests` (bypass the versioned cardinality cost fold with a fixed Prometheus
  envelope — caught by the `Observability` budget/golden property);
  `mutant_provisioned_value_in_bound_deployment` (inject a `Provisioned*` result before `provision` — caught by
  the structural inventory); and `mutant_unchecked_prior_ref` (accept a missing, stale, wrong-generation, or
  wrong-arm prior provision reference without resolving it from `ProvisionContext` — caught by the prior-ref
  negative corpus); `mutant_drop_execution_replica`, `mutant_drop_execution_surge`, and
  `mutant_drop_execution_old_revision` (omit one kind-indexed identity from its required steady/rollout/live
  epoch); `mutant_wrong_execution_revision_join` (join an instance to the wrong source revision);
  `mutant_double_debit_controller_child` (charge the explanatory controller witness after the lowered kind-indexed
  unit already paid); `mutant_drop_largest_kubelet_metadata` (omit the largest simultaneous pod metadata row);
  `mutant_missing_kubelet_metadata_model` (a case table that accepts a missing/changed target model or scalar
  byte fallback, drops/swaps a component role, resolves a role to the wrong backing, mismatches a
  planned/observed domain, overlaps/leaks qualified Pod/image ownership, or double-debits an alias group);
  `mutant_drop_accelerator_work_item` (remove one source/workload identity from the owner fold);
  `mutant_accept_accelerator_domain_mismatch` (default a missing coexistence-policy class to zero/serial);
  `mutant_select_favorable_accelerator_epoch` (check only a caller-friendly non-overlap);
  `mutant_drop_accelerator_overlap_debit` (omit one co-resident component from its device aggregate); and
  `mutant_skip_accelerator_shard_validation` (accept duplicate shard ids, wrong sum, or more shards than owner
  devices).
  The gate re-runs each mutant and asserts red.
- A Register-1 validation-locus ledger mapping every entry to its catalog id and layer, backed by
  **Phase-6-style coverage-assertion machinery** (the ledger is not a static hand-written file: the suite goes
  **red** if any corpus entry, negative reason, or seeded mutant named above is absent from the ledger),
  explicitly marking the runtime residue (the provider actually coming up, the engine actually resolving into
  its bounded cache) deferred to the live band — never reported as proven.

### Validation
1. `cabal test capability-spec` is green — each of the **nine per-arm** positives binds byte-invariant
   (beta-normalized app-surface slices from distinct composed files) under both shapes and structurally
   different by the object-node-multiset oracle (red on scalar-only / copied-shape-tag) against its
   Phase-0-committed golden; the exhaustiveness check covers all nine arms and the totality property meets
   `checkCoverage` (each constructor ≥ 8%); each Gate-1 negative fails `dhall type` at its asserted locus, each
   decode/provision negative returns its specifically-tagged `Left`, each paired with a minimally-differing positive; the
   suite is red if any product-named, URL-named, or shape-in-app fixture decodes, and red under each of the
   eighteen committed seeded mutants (`mutant_copy_shape_tag`, `mutant_catchall_arm`,
   `mutant_shared_app_import`, `mutant_fixed_prometheus_requests`,
   `mutant_provisioned_value_in_bound_deployment`, `mutant_unchecked_prior_ref`,
   `mutant_drop_execution_replica`, `mutant_drop_execution_surge`,
   `mutant_drop_execution_old_revision`, `mutant_wrong_execution_revision_join`,
   `mutant_double_debit_controller_child`, `mutant_drop_largest_kubelet_metadata`,
   `mutant_missing_kubelet_metadata_model`, `mutant_drop_accelerator_work_item`,
   `mutant_accept_accelerator_domain_mismatch`, `mutant_select_favorable_accelerator_epoch`,
   `mutant_drop_accelerator_overlap_debit`, and `mutant_skip_accelerator_shard_validation`). Exact-fit
   execution-epoch/runtime-storage-backing/accelerator-epoch boundaries accept; each one-resource or one-byte-short
   minimally differing pair rejects.
   The validation-locus ledger is present and its coverage-assertion machinery (Phase-6 precedent) turns the
   suite **red** if any named fixture, negative reason, or mutant is missing — 'honestly classifies' is thus a
   machine oracle, not a hand-written attestation.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/service_capability_doctrine.md` — backlink §1/§2 (the capability set), §3/§4/§5 (the
  provider+shape binding), §4.1 (the `InferenceEngine` engine union), and §8 (the illegal-state instances) to
  the implemented `Amoebius.Capability.*`; confirm the alternate-admitting provider union stayed one-arm and
  the `EngineRuntime` union stayed URL-free.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.12 (product in app logic) and §3.25 (engine by
  URL) with their realized layer (type-foreclosed, Gate 1) and the family-unavailable-on-lane state as
  a checked rejection at the post-bind `provision-seal` locus; keep the runtime-checked residue (provider up,
  engine resolved) deferred.
- `documents/engineering/content_addressing_doctrine.md` — reconcile §4.5's Tier-1 engine as the
  `InferenceEngine` provider whose named identity this binder decodes; keep the jit-resolve into the bounded
  cache as the live-band residue.
- `documents/engineering/manifest_generation_doctrine.md` — record that the binder/provision boundary seals
  the identity-keyed `ProvisionedRenderSourceSet` under the opaque whole-deployment `ProvisionedSpec`;
  `documents/engineering/app_vs_deployment_doctrine.md` — the app-surface capability
  resources; `documents/engineering/dsl_doctrine.md` — the capability-model instance of the two-gate contract.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + corpus ledger this gate emits
  (live realization and engine-resolve fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-8 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-8 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `dhall/amoebius/Capability.dhall`,
  `src/Amoebius/Capability/{Types,Binding,Engine}.hs`, and the capability property + gate suites as Phase-8
  design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *binding-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the capability-not-product invariant
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — §1/§2 the capability
  set, §3/§4/§5 the provider+shape binding, §4.1 the substrate-selected `InferenceEngine`, §8 the illegal-state
  instances
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.12 (product in app logic),
  §3.25 (engine by URL), with §2 the load-bearing limit
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates a capability binding decodes through
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — §4.5 the ML-asset
  lifecycle whose Tier-1 jit-resolved engine is the `InferenceEngine` provider
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the IR + decoder the bound/provisioned specs project from
- [phase_07](phase_07_capacity_topology_folds.md) — the complete capacity/topology/capability folds, including
  ephemeral storage, accelerator device fit, and identity-complete residency/coexistence epochs
- [phase_09](phase_09_render_manifest_goldens.md) — the pure
  deployment-global `renderAll :: ProvisionedSpec -> [K8sObject]` that consumes only private checked
  service/global projections
- [phase_32](phase_32_jitbuild_engine_cache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this phase only decodes
