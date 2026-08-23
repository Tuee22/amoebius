# Phase 30: Capability union + representational bind

> **Purpose**: Build the pure capability union and the total representational `bind` — source-expanding every
> runnable member into `BoundExecutionUnit`s and assembling one `BoundServiceSpec`/`BoundDeployment` — so that
> the *app-surface bytes are identical* across two shapes while the bound object graph differs *structurally*,
> a product-named or URL-named or shape-in-app app has no syntax (dhall-typecheck), and a binding to an unbuilt provider
> arm fails gadt-decode, all with no provision, no fold, and no render.
> **Read this if**: phase 30 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/dsl_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 30.1: The closed capability union + the no-product-arm dhall-typecheck foreclosure ⏸️](#sprint-301-the-closed-capability-union--the-no-product-arm-dhall-typecheck-foreclosure-)
- [Sprint 30.2: The `CapabilityBinding` + total representational `bind` ⏸️](#sprint-302-the-capabilitybinding--total-representational-bind-)
- [Sprint 30.3: The bind property/corpus + the Register-1 gate ⏸️](#sprint-303-the-bind-propertycorpus--the-register-1-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 29, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase is limited to the pure Haskell **capability layer and
representational bind**. Its target makes amoebius's
*"application logic names a capability, never a product"* invariant executable as a pure decode-and-bind path,
and stops at the wholly unprovisioned `BoundDeployment` boundary — the whole-deployment provision seal, the
capacity/storage folds, the accelerator/inference availability relation, and the render all live in later
phases. Haskell values own every case and expectation; any Dhall or other serialized case is generated lazily
beneath `.build/**`.

The target capability model contains:
- the closed **nine-arm** capability union — the eight ordinary capabilities (`ObjectStore`, `SecretStore`,
  `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`) plus a distinct ninth
  `InferenceEngine` arm — on the app surface with **no product arm** (`minio` has no syntax) and **no generic "some other service" escape arm**
- the `InferenceEngine` head carries a closed `EngineRuntime` lane union with **no arbitrary-`Url`/`Download` arm** (an engine named by URL has no syntax, dhall-typecheck) — this phase owns that
  union's *representational shape*
- its family×lane availability *relation* and its `CudaOwnerDemand`/`MetalOwnerDemand` accelerator provision
  are [Phase 32](phase_32_inference_accelerator_provision.md).

The target **three-part binding** contains the `CapabilityNeed` an app writes once and carries everywhere; the
`CapabilityBinding` (a capability-specific provider type defaulting to the canonical provider — with Registry
closed to Distribution `registry:2` and no alternate arm — plus a typed `shape`
that selects *which* manifest graph to render, bound only on the deployment-rules surface); and the total
function `bind :: CapabilityNeed -> CapabilityBinding -> BoundServiceSpec`. `bind` selects and fully expands the
provider's manifest graph for the chosen shape, and source-expands every runnable member into a complete
unprovisioned `BoundExecutionUnit` with one private controller/resource-compatible body — Deployment,
StatefulSet, DaemonSet, Job, or HostProcess — lowering controller-created children into that same kind-indexed
vocabulary while retaining each child's private source-expansion witness. The enclosing
`BoundExecutionInventory` retains exactly one deployment-level `FirstDeployment | UpdateFrom
PriorExecutionProvisionRef` source **without resolving it**, and the assembled `BoundDeployment` retains only
these unprovisioned units, the opaque source ref, and controller explanations — **no resolved prior inventory, materialized instance, epoch placement, or `Provisioned*` value**.

The load-bearing property is that the *app-surface bytes are identical* across shapes while the bound
`BoundServiceSpec` differs *structurally* (a different object graph, not a `replicas: 1 → 3` edit) — the
capability survives a move, the binding does not have to. Every foreclosure here is honest about its layer: an
app that names a product, an engine named by URL, or a shape/provider authored on the app surface is
**type-foreclosed** (no syntax, fails dhall-typecheck); a binding to an unbuilt provider arm and an unbound or cyclic /
shadowing extension graph are rejected by the genuine gadt-decode decoder. What is **not** here: the whole-deployment
provision seal — `planInfrastructure`/`provision`/`ProvisionedSpec` and the capacity/storage/runtime-storage/
object-store/observability/migration/scheduler-reservation demand derivation and folds
([Phase 31](phase_31_provision_seal.md)); the `InferenceEngine` family×lane availability relation, the
target-offering→lane quotient, and the accelerator residency/coexistence provision
([Phase 32](phase_32_inference_accelerator_provision.md)); the pure
`renderAll :: ProvisionedSpec -> [K8sObject]` ([Phase 33](phase_33_render_manifest_oracles.md)); and the live
jit-resolve of an engine into its `CacheBudget`-bounded cache ([Phase 80](phase_80_determinism_jitcache.md)).

**Phase scope:** one target claim — identical app-surface values bind to structurally different Haskell object
graphs when deployment shape differs. Nothing is provisioned, rendered, or observed live.

**Substrate:** none — no host, cluster, provider, or hardware; the canonical Haskell gate owns the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster.

**Depends on:** [Phase 29](phase_29_execution_accelerator_folds.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 30`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — identical app-surface Haskell values bind to structurally different object graphs when deployment shape differs; any Dhall or serialized case is generated beneath `.build/**`; Registry has only the Distribution `registry:2` provider arm. Nothing is provisioned, rendered, or observed live. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 30` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 29 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`extension_conformance_doctrine.md` §2 — What an extension is](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is) — capability union + representational bind is admitted by satisfying the contract, not by appearing on a list.
- [`service_capability_doctrine.md` §1 — Why capabilities, not products](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)
  and [`service_capability_doctrine.md` §2 — The capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set)
  — **why capabilities, not products**, and **the capability set.** The nine-arm closed union is the whole
  vocabulary an app has for "a service I depend on"; there is no arm for "some other service" and no arm that
  names a product, so an app that needs object storage selects `ObjectStore` and has no syntax with which to
  select `minio`.
- [`service_capability_doctrine.md` §4 — Capability → provider → shape: the binding](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  — **Capability → provider → shape: the binding.** The target is to implement the three-part binding as pure
  Haskell: the capability is chosen by application logic (written once, travels), and the provider (default the
  [`service_capability_doctrine.md` §3 — Canonical providers; extension is capability-specific](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)
  canonical) and shape are chosen by deployment rules — realized as the total `bind`, not restated as prose.
- [`service_capability_doctrine.md` §3 — Canonical providers; extension is capability-specific](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)
  and [`service_capability_doctrine.md` §5 — Per-cluster structural shapes — beyond values](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values)
  — **canonical providers; extension is capability-specific**, and **per-cluster structural shapes.** A provider
  type admits only doctrine-authorized arms; Registry is permanently closed to Distribution `registry:2`.
  The shape is a typed choice
  (`SingleNode` vs `Distributed`) that selects *which manifest graph* to render — the structural generalization
  of the replica dial — and amoebius builds no alternate provider arm it does not yet need (headroom in the
  type, not shipped code).
- [`service_capability_doctrine.md` §4.1 — The InferenceEngine capability — the engine is target-offering-selected and jit-resolved, never authored](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
  — the `InferenceEngine` capability: the engine is a **named catalog identity**, never authored by URL —
  grounded in [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss).
  **This phase adopts only the union's representational shape** — the closed `EngineRuntime` lane union with **no arbitrary-`Url`/`Download` arm**, so "name the engine by URL" has no syntax and fails dhall-typecheck. The family×lane
  availability relation, the target-offering→lane quotient, the accelerator owner demands, and the actual
  jit-resolve are **not** here (Phases 19 / 45).
- [`service_capability_doctrine.md` §8 — Capabilities and the illegal-state contract](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
  — **capabilities and the illegal-state contract:** an app cannot name a product (no arm — dhall-typecheck), a
  capability cannot bind to a provider with no inhabitant (an unbuilt alternate does not decode — gadt-decode), and a
  capability cannot be left unbound (an undecodable record, never a runtime `Pending`).
- [`capability_extension_doctrine.md` §3 — The PROVIDE and REQUIRE contract](../documents/engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract)
  — **the extension provide/require capability graph.** The binder validates the `extRequires` provide/require
  graph is total and acyclic and rejects an anti-shadow (shadowing) merge or a provide-and-require self-loop; a
  cyclic or shadowing Haskell-declared extension case fails gadt-decode at its independently expected locus
  (the closed v1 extension set
  `{infernix, jitML}`).
- [`illegal_state_catalog.md` §3 — The catalog — states a valid spec cannot represent](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent)
  ([`illegal_state_capability_messaging.md` §3.12 — An app that names a product instead of a capability](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability) — a product named in application logic) and
  [`illegal_state_ml_asset.md` §3.25 — An ML asset named by arbitrary URL (or an unready / unlanded model)](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)
  (an ML asset named by arbitrary URL) — the two states this phase forecloses at dhall-typecheck, honoring the
  load-bearing limit ([`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)):
  a type-check proves the *binding composes*, not that the *running provider* came up.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — **the illegal-state-unrepresentable contract's typed spec gates** (dhall-typecheck the Dhall typechecker, gadt-decode the
  in-process decoder): the capability union is guarded at dhall-typecheck, the binding decodes through gadt-decode — this
  phase adds the capability-model instance of that contract, no live half.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  (**Register 1** — pure/semantic-oracle, in-process, no cluster) and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) (the per-run proven/tested/assumed ledger): the
  register this gate reaches and the ledger it emits, with the live realization of any provider (and the
  jit-resolve of any engine) marked UNVERIFIED, owned by the live band.

The provision/fold ordering — expand every provider/shape first, then run the capacity folds, then hand only the
checked result to render
([`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)/[`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting))
— is deliberately **not** adopted here; it is owned by [Phase 31](phase_31_provision_seal.md). This phase stops
at the wholly unprovisioned `BoundDeployment`.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 30.1: The closed capability union + the no-product-arm dhall-typecheck foreclosure ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`service_capability_doctrine.md §1`](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)
and [`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set):
build the closed capability union as the whole vocabulary an app has for a dependency, so that naming a
capability is the only move available and naming a product — or an engine by URL — is not a word the grammar
contains.

### Deliverables

- The closed nine-arm capability union — the eight ordinary capabilities (`ObjectStore`, `SecretStore`,
  `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`) plus the ninth `InferenceEngine` head —
  on the app surface, with **no product arm** and no generic "some other service" arm: `minio` has no syntax.
- The `InferenceEngine` head's closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` · `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm** — an ML engine is a **named catalog identity**, so "name the engine by URL"
  has no syntax and fails dhall-typecheck. This sprint delivers the *representational shape* of that union only; its
  family×lane availability relation, target-offering→lane quotient, and `CudaOwnerDemand`/`MetalOwnerDemand`
  owner demands are [Phase 32](phase_32_inference_accelerator_provision.md).
- The app-surface `CapabilityNeed` records read as *resources of a capability* — buckets against `ObjectStore`,
  a database against `Sql`, topic lifecycles against `MessageBus`, OIDC rules against `Identity`, published
  routes against `Edge`, and so on — and the `BoundServiceSpec` skeleton the binder projects into.
- An in-file honesty note that this union is the app-facing *what*; the provider/shape *how* is Sprint 30.2, the
  provision seal is [Phase 31](phase_31_provision_seal.md), and the capability set is invariant across every
  cluster (a different capability *set* per cluster stays refused).

### Validation

1. `dhall type` accepts each positive `CapabilityNeed` and rejects both a product-named app and a URL-named
   engine at authoring time (dhall-typecheck), each at its asserted error locus; the union has exactly nine arms, no
   product arm, and no escape arm, checked against the oracle-pinned hand-authored arm list.
2. Each dhall-typecheck negative fails at a named locus rather than merely somewhere. `illegal_product_in_app`, which
   names `minio` at authoring time, raises an unknown-constructor / no-such-alternative type error on the
   capability union; `illegal_engine_by_url`, which names an engine by URL, raises the same error on the
   `EngineRuntime` lane union. Each is paired with its positive — `legal_objectstore_singlenode` and
   `legal_inference_cuda` respectively — differing only in that the product name or the URL is replaced by a
   capability or a named engine identity, so neither negative can pass for an unrelated reason such as a typo
   or a missing field.

### Remaining Work

The pre-reset record said `None`; that statement and its union/corpus result are permanently invalid for
promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval,
owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 30.2: The `CapabilityBinding` + total representational `bind` ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding),
[`§3`](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific),
and [`§5`](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values):
implement the three-part binding as a pure total function so that one byte-identical app spec binds to a
structurally different `BoundServiceSpec` per cluster — a different object graph, not a scalar `replicas` edit —
stopping at the wholly unprovisioned `BoundDeployment`.

### Deliverables

- A `CapabilityBinding` whose `provider` is a **one-arm-today** typed union defaulting to the
  [§3](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)
  canonical provider (headroom for an alternate, but no adapter amoebius does not yet need), and whose `shape`
  is a typed choice (`SingleNode` vs `Distributed { nodes }`), bound only on the deployment-rules surface.
- `bind :: CapabilityNeed -> CapabilityBinding -> BoundServiceSpec`, pure and total, selecting the provider's
  **manifest graph for the chosen shape** — a structurally different object graph, not a scalar `replicas` edit.
  Every runnable becomes a complete unprovisioned `BoundExecutionUnit` with one private
  controller/resource-compatible body. Deployment carries `ReplicaCardinality` and only
  `DeploymentRolloutPolicy`; StatefulSet carries its native replica count and serial `StatefulSetRolloutPolicy`;
  DaemonSet carries `NodeEligibilitySelector` and only `OnDelete | RollingUpdate (Surge | Unavailable)`; Job
  carries completions/parallelism/backoff, `restartPolicy=Never`, replacement-on-Failed, and finite terminal
  retention; HostProcess carries `HostProcessCardinality` plus supervisor replacement policy. A CUDA Pod is
  structurally a DaemonSet with serial `OnDelete`; CUDA host and Metal host arms structurally force their
  release/drain lifecycle. There is **no** unit-level replica scalar, caller terminating bound, generic strategy
  record, controller/resource cross-product, or unsupported StatefulSet feature field. `NodeEligibilitySelector`
  is the canonical closed conjunction of typed engine-role, provider-class, site, accelerator-profile, and
  inventory-taint constraints, with no free-text selector/toleration — these arms are **structural inputs to provision**, constructed here and resolved to host→slot maps and eligible sets only by
  [Phase 31](phase_31_provision_seal.md), never an authored or bound peak here.
- Controller-child lowering: for every operator/CR arm a version-pinned expander joins the descriptor's exact
  kind-indexed controller policy, complete child pod-resource-template, and child durable-volume operands, then
  alone constructs a private identity-keyed `ControllerChildEnvelope`. Each child is lowered into the same
  kind-indexed `BoundExecutionUnit` vocabulary; the controller witness *explains and exact-joins* the
  descriptor→child expansion but is retained as an explanation only (its capacity debit is
  [Phase 31](phase_31_provision_seal.md)'s, not a second unit here). A caller cannot author a scalar child peak,
  a generic child list, or a resource-free CR.
- The canonical identity-keyed `BoundExecutionSet`: every domain composite is exhaustively flattened into it;
  equality with the expanded runnable-source inventory rejects an omitted worker/controller/gateway/Job, and
  every unit has exactly one compatible controller body. The enclosing `BoundExecutionInventory` retains exactly
  one `FirstDeployment | UpdateFrom PriorExecutionProvisionRef` source for the entire deployment **without resolving it**, so removed prior-only units remain resolvable even though they have no current unit.
- `BoundDeployment` retains **only** these unprovisioned units, the opaque source ref, and controller
  explanations — **no** resolved prior inventory, materialized instance, epoch placement, or `Provisioned*`
  value. Its only links to old successful generations are the opaque `PriorExecutionProvisionRef` (and the sibling
  `PriorVolumeProvisionRef` / `PriorRegistryProvisionRef` carried but unresolved); resolving them against a
  `ProvisionContext` is [Phase 31](phase_31_provision_seal.md)'s work, not `bind`'s. `bind` carries the typed
  provider intents (`ObjectStoreProducerIntent`, `ObjectStoreGatewayIntent`, `StorageMigrationIntent`,
  `RegistryStorageIntent`, `SchemaMigrationIntent`, `PatroniSqlIntent`, and the `Observability` descriptor with
  its `MonitoringWorkBudget`) inside the bound graph **unresolved**; their derivation into demand records is the
  provision seal's, not here.
- An in-file honesty note: a single-node shape is the canonical provider deployed honestly at small scale (a
  one-member Patroni `Sql`, never a bare `postgres` Pod); `bind` produces a **value**, not a live provider, and
  not a provisioned deployment — the provision seal is [Phase 31](phase_31_provision_seal.md) and the live
  realization is the live band. The source inventory this sprint authors imports none of that: not the
  [Phase 31](phase_31_provision_seal.md) `provision`/`ProvisionedSpec` machinery, not the
  [Phase 29](phase_29_execution_accelerator_folds.md) execution-epoch fold, and not the
  [Phase 33](phase_33_render_manifest_oracles.md) `K8sObject`/Aeson renderer.

### Validation

1. The same `CapabilityNeed`, bound under two shapes, produces two `BoundServiceSpec`s that are **structurally different by the object-node-multiset oracle** (deep structural diff per [§5](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values), red on a scalar-only or copied-shape-tag difference; each equal to its oracle-pinned semantic projection), while the **app-surface bytes**
   (beta-normalized app-surface slices from two distinct composed spec files) are identical; a binding to an
   unbuilt provider arm returns a structured `Left` tagged (gadt-decode); a shape/provider authored on the app
   surface fails `dhall type` at its asserted locus; `bind` never throws. A structural inventory proves
   `BoundDeployment` contains no `Provisioned*` field, and the canonical `BoundExecutionSet` equals the expanded
   runnable-source inventory with every controller-lowered child present exactly once and no second debit. This
   validation must go **red** on the reviewed Haskell `mutant_copy_shape_tag` operator applied to a temporary
   subject beneath `.build/mutants/**` (Sprint 30.3) — which makes
   `bind` copy the shape tag into a `providerGraph` field instead of selecting a manifest graph, passing a plain
   `/=` but failing the multiset oracle — and on `mutant_provisioned_value_in_bound_deployment` (a `Provisioned*`
   value injected into `BoundDeployment`).
2. Each negative names its locus rather than merely failing. `illegal_shape_in_app` fails `dhall type`
   because the app-surface record has no `shape` or `provider` field, and its paired positive differs only in
   that the shape moves to the deployment-rules surface — which is what makes the app-surface byte invariant
   above worth asserting at all. A binding that names a provider arm amoebius has not built returns its
   specific unbuilt-provider-arm `DecodeError`, never a bare `Left`.

### Remaining Work

The pre-reset record said `None`; that statement and its binder/inventory result are permanently invalid for
promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval,
owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 30.3: The bind property/corpus + the Register-1 gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract),
[`capability_extension_doctrine.md §3`](../documents/engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract),
and [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
[§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)/[§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact): assemble the phase's single Register-1 gate — every positive need binds to a checked `BoundServiceSpec`
while every product- or URL-named or shape-in-app app has no syntax and every unbuilt/unbound/cyclic/shadowing
binding returns its specific `DecodeError` — and emit the per-entry validation-locus ledger that names the
honest foreclosure layer of each.

### Deliverables

- Three test modules with disjoint jobs: `test/spec/capability/BindProps.hs` holds the property battery,
  `test/spec/capability/ShapeOracle.hs` holds the object-node-multiset structural diff — authored separately from
  `bind`, so the oracle is never `bind`'s own fold — and `test/spec/capability/BindGate.hs` holds the gate and the
  validation-locus ledger with its coverage-assertion machinery.
- The **concrete Haskell positive corpus** — **one Haskell-declared case per each of the nine capability arms** (`ObjectStore`,
  `SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`, `InferenceEngine`), each
  bound under **both** a `SingleNode` and a `Distributed { nodes = n }` (n ≥ 2) shape — so the corpus is not
  scope-shrunk to the three named `legal_objectstore_{singlenode,distributed}` / `legal_inference_cuda` cases.
  A separately authored Haskell **exhaustiveness check** asserts the case→capability-arm map covers the full nine-arm union
  (red if any arm has no positive case), enumerated against the **separately authored Haskell arm list**
  (Sprint 30.1), independent of `bind`'s own case analysis.
- The property battery: the same `CapabilityNeed` bound under two shapes yields two `BoundServiceSpec`s
  **structurally different by the object-node-multiset oracle** (red on scalar-only / copied-shape-tag) with
  byte-identical app bytes (beta-normalized app-surface slices from distinct composed files); **every declared need binds totally (no partial `bind`) across all nine arms**, with QuickCheck `label`/`classify` +
  `checkCoverage` obligations forcing each of the **nine need constructors** to fire ≥ 8% (so a generator
  emitting only the three covered constructors fails coverage); an unbound capability is an undecodable record,
  not a runtime `Pending`; and a structural inventory proves `BoundDeployment` contains no `Provisioned*` field,
  that the Registry arm crosses `ObjectStoreProducerIntent.Registry : RegistryStorageIntent` on the *bound* side
  (its derivation into `RegistryStorageDemand` is the provision seal's), and that the canonical
  `BoundExecutionSet` enumerates every kind-indexed unit — including controller-lowered units — exactly once.
- The negative corpus — `illegal_product_in_app` ([§3.12](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability), dhall-typecheck), `illegal_engine_by_url` ([§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model), dhall-typecheck),
  `illegal_shape_in_app` (shape/provider on the app surface, dhall-typecheck), `illegal_unbuilt_provider` (gadt-decode),
  `illegal_unbound_capability` (undecodable, gadt-decode), `illegal_cyclic_extension` (a provide-and-require
  self-loop, gadt-decode at the `extRequires` locus), and `illegal_shadowing_extension` (an anti-shadow merge, gadt-decode
  at the `extRequires` locus) — each asserting **its specific failure reason** (its expected `dhall type` error
  locus or `DecodeError` tag) and each **paired with a positive differing only in the foreclosed dimension**,
  alongside the positive nine-arm corpus above. The two extension negatives pair with a minimal legal
  `{infernix, jitML}` positive, the closed v1 extension set. The accelerator/provision-seal negatives
  (`illegal_cuda_on_cpu_target`, `illegal_accelerator_*`, `illegal_engine_family_unavailable_on_lane`,
  `illegal_monitoring_work_over_budget`, `illegal_post_bind_expansion_overcommit`,
  `illegal_prior_provision_ref_*`, …) are **not** in this gate — they belong to
  [Phase 31](phase_31_provision_seal.md) and [Phase 32](phase_32_inference_accelerator_provision.md).
- **Reviewed Haskell mutation operators (§M.2)** — a defined set of **four** deliberately broken production
  transformations, applied beneath `.build/mutants/**` and re-run, that the gate MUST turn red:
  `mutant_copy_shape_tag` (effect swap: `bind`
  copies the shape tag into a `providerGraph` field instead of selecting a manifest graph — defeats a `/=`-only
  diff, caught by the multiset oracle); `mutant_catchall_arm` (union-arm addition: a catch-all `bind` arm returns
  a degenerate `BoundServiceSpec` for an arm whose authored need must survive unchanged — caught by the per-arm semantic projection +
  exhaustiveness check); `mutant_shared_app_import` (the two composed fixtures share one app-surface import —
  makes byte-equality vacuous — caught by the distinct-composed-file requirement in (a)); and
  `mutant_provisioned_value_in_bound_deployment` (inject a `Provisioned*` result into `BoundDeployment` before
  any provision — caught by the structural inventory). The gate re-runs each mutant and asserts red.
- A Register-1 validation-locus ledger mapping every entry to its catalog id and layer, backed by
  **Phase-27-style coverage-assertion machinery** (the ledger is not a static hand-written file: the suite goes
  **red** if any corpus entry, negative reason, or seeded mutant named above is absent from the ledger),
  explicitly marking the runtime residue (the provider actually coming up, the engine actually resolving into
  its bounded cache) deferred to the live band — never reported as proven.

### Validation

1. Rejected historical observation: the `capability-bind-spec` Cabal suite was recorded green — each of the
   **nine per-arm** positives binds byte-invariant
   (beta-normalized app-surface slices from distinct composed files) under both shapes and structurally
   different by the object-node-multiset oracle (red on scalar-only / copied-shape-tag) against its
   oracle-pinned semantic projection; the exhaustiveness check covers all nine arms and the totality property meets
   `checkCoverage` (each constructor ≥ 8%); each dhall-typecheck negative (`illegal_product_in_app`,
   `illegal_engine_by_url`, `illegal_shape_in_app`) fails `dhall type` at its asserted locus, and each gadt-decode
   negative (`illegal_unbuilt_provider`, `illegal_unbound_capability`, `illegal_cyclic_extension`,
   `illegal_shadowing_extension`) returns its specifically-tagged `Left`, each paired with a minimally-differing
   positive; the suite is red if any product-named, URL-named, or shape-in-app fixture decodes, and red under
   each of the four applied Haskell seeded mutants (`mutant_copy_shape_tag`, `mutant_catchall_arm`,
   `mutant_shared_app_import`, `mutant_provisioned_value_in_bound_deployment`). The validation-locus ledger is
   present and its coverage-assertion machinery (Phase-27 precedent) turns the suite **red** if any named fixture,
   negative reason, or mutant is missing — 'honestly classifies' is thus a machine oracle, not a hand-written
   attestation. It also observes all 18 source-expanded execution inventories, preserves the execution/volume/
   registry transition references exactly, checks Registry intent under both shapes, and pairs one missing
   extension requirement with a closed positive. The authored calculus projection accounts for the nine arms,
   18 shapes, seven negatives, one property, and four mutants as 39 units over artifact, budget, lift, workflow,
   and evidence. Provision and accelerator/inference availability are out of scope here and owned by Phases
   31/32.

### Remaining Work

The pre-reset record said `None`; that statement and every shape/negative/property/ledger result are
permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row,
predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/service_capability_doctrine.md` — backlink §1/§2 (the capability set), §3/§4/§5 (the
  provider+shape binding), and §4.1 (the `InferenceEngine` engine union's no-URL representational shape) to the
  implemented `Amoebius.Capability.{Types,Binding}`; confirm the alternate-admitting provider union stayed
  one-arm and the `EngineRuntime` union stayed URL-free. (The §4.1 availability relation stays owned by
  [Phase 32](phase_32_inference_accelerator_provision.md).)
- `documents/engineering/capability_extension_doctrine.md` — backlink §3 (the provide/require contract) to the
  implemented `extRequires` acyclicity/no-shadow check whose `illegal_cyclic_extension` /
  `illegal_shadowing_extension` negatives this gate exercises.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.12 (product in app logic) and §3.25 (engine
  by URL) with their realized layer (type-foreclosed, dhall-typecheck); keep the runtime-checked residue (provider up,
  engine resolved) deferred.
- `documents/engineering/content_addressing_doctrine.md` — reconcile §4.5's Tier-1 engine as the
  `InferenceEngine` provider whose named identity this binder decodes; keep the jit-resolve into the bounded
  cache as the live-band residue ([Phase 80](phase_80_determinism_jitcache.md)).
- `documents/engineering/app_vs_deployment_doctrine.md` — the app-surface capability resources vs the
  deployment-rules shape/provider surface; `documents/engineering/dsl_doctrine.md` — the capability-model
  instance of the two-gate contract.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + corpus ledger this gate emits
  (live realization and engine-resolve fidelity UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the human authority may change Phase 30 after reviewing a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-30 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Capability/{Types,Binding}.hs`, the Haskell
  capability-projection declaration, and the Haskell bind property/oracle suites as Phase-30 design-first
  rows. `.build/dhall/amoebius/Capability.dhall` is a lazy product, not a component row.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *binding-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the capability-not-product invariant
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — [§1](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products)/[§2](../documents/engineering/service_capability_doctrine.md#2-the-capability-set) the capability
  set, [§3](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)/[§4](../documents/illegal_state/illegal_state_techniques.md#4-the-typing-techniques)/[§5](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state) the provider+shape binding, [§4.1](../documents/illegal_state/illegal_state_techniques.md#41-pvcpv-binding-by-construction) the `InferenceEngine` union's no-URL shape, [§8](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract) the illegal-state
  instances
- [Capability Extension Doctrine](../documents/engineering/capability_extension_doctrine.md) — [§3](../documents/engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract) the
  provide/require `extRequires` contract whose acyclicity/no-shadow this gate's extension negatives exercise
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§3.12](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability) (product in app logic),
  [§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model) (engine by URL), with [§2](../documents/illegal_state/illegal_state_ml_asset.md#2-the-ml-asset--training-illegal-states) the load-bearing limit
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) the typed spec gates a capability binding decodes
  through
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — [§4.5](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) the ML-asset
  lifecycle whose Tier-1 named engine identity is the `InferenceEngine` provider
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_26](phase_26_gadt_decode_ir.md) — gadt-decode, the IR + decoder the bound specs project from
- [phase_27](phase_27_illegal_state_covering.md) — the illegal-state corpus + validation-locus ledger machinery
  this gate reuses
- [phase_29](phase_29_execution_accelerator_folds.md) — the execution-epoch / runtime-storage / accelerator
  folds whose kind-indexed vocabulary `bind`'s `BoundExecutionUnit`s are fold-compatible with
- [phase_31](phase_31_provision_seal.md) — the whole-deployment provision seal that layers `planInfrastructure`/
  `provision`/`ProvisionedSpec` and the capacity/storage/observability/migration demand derivation on this
  phase's `BoundDeployment`
- [phase_32](phase_32_inference_accelerator_provision.md) — the `InferenceEngine` family×lane availability
  relation and the accelerator residency/coexistence provision layered on this phase's capability union
- [phase_33](phase_33_render_manifest_oracles.md) — the pure deployment-global
  `renderAll :: ProvisionedSpec -> [K8sObject]` downstream of the provision seal - [phase_80](phase_80_determinism_jitcache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this phase only decodes
