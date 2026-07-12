# Phase 8: Capability → provider → shape binder (representational)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the pure three-part capability binding — application logic names an abstract capability,
> deployment rules bind a canonical provider and a per-cluster shape — as a total, in-process function that
> decodes a capability need into a `ServiceSpec`, and prove that a product-named app has no syntax at all,
> before any cluster or provider exists.

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
`shape` that selects *which* manifest graph to render), and the total function
`bind :: CapabilityNeed -> CapabilityBinding -> ServiceSpec` that projects a need + binding into the
`ServiceSpec` the Phase-9 renderer consumes. The load-bearing property is that the *app surface bytes are
identical* across shapes while the bound `ServiceSpec` differs *structurally* (a different object graph, not a
`replicas: 1 → 3` edit) — the capability survives a move, the binding does not have to. Every foreclosure here
is honest about its layer: an app that names a product, or an engine named by URL, is **type-foreclosed** (no
syntax, fails Gate 1); a binding to an unbuilt provider arm, or a served model whose engine family is
unavailable on the serving substrate lane, is **decode-foreclosed** (a structured `Left` at Gate 2). What is
*not* here: the render of a bound `ServiceSpec` into `[K8sObject]` ([Phase 9](phase_09_render_manifest_goldens.md));
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
`bind`s to a well-typed `ServiceSpec` value in-process, with:
- **the structural-difference oracle satisfied** — the two bound `ServiceSpec`s' provider object graphs differ
  in **object-node multiset** (a `Distributed { nodes = n }` graph carries n member elements where `SingleNode`
  carries 1), verified by a deep structural diff (§5) that **fails when the difference is expressible as a
  single scalar-field edit — e.g. `replicas: 1 → 3` — or as a copied shape tag**; each bound `ServiceSpec` value
  is checked equal to its **Phase-0-committed, reviewer-authored golden** (`golden_servicespec_<arm>_<shape>`),
  authored before `bind` exists so the golden cannot be regenerated from the implementation;
- **the app-surface bytes byte-identical across the two shapes**, where *app-surface bytes* is defined as the
  **beta-normalized Dhall expression of the app-surface slice extracted from each of the two *distinct*
  composed spec files** (never a shared import compared to itself), so the equality witnesses that the DSL
  forces shape/provider out of the app surface rather than reducing to a file-read tautology;
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
the `ServiceSpec` skeleton the binder targets) — target paths, not yet built.
**Blocked by**: Phase 4 gate (the Gate-1 Dhall schema + smart-constructor prelude the union lives in); Phase 5
gate (the GADT-indexed IR + total decoder the `ServiceSpec` is a projection of).
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
  routes) read as *resources of a capability*, and the `ServiceSpec` skeleton the binder projects into.
- An in-file honesty note that this union is the app-facing *what*; the provider/shape *how* is Sprint 8.2, and
  the capability set is invariant across every cluster (a different capability *set* per cluster stays refused).

### Validation
1. `dhall type` accepts each positive `CapabilityNeed` and rejects a product-named app at authoring time (Gate
   1); the union has no product arm and no escape arm.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.2: The `CapabilityBinding` + the total `bind :: CapabilityNeed -> CapabilityBinding -> ServiceSpec` 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (extend: the `CapabilityBinding` records — the
one-arm-today provider union + the typed `shape`); `src/Amoebius/Capability/Binding.hs` (the pure total `bind`
selecting the provider's manifest graph for the chosen shape) — target paths, not yet built.
**Blocked by**: Sprint 8.1; Phase 5 gate (the IR + decoder).
**Independent Validation**: a unit + property suite binds the same app `ObjectStore`/`Sql` need under a
`SingleNode` shape and a `Distributed { nodes = n }` (n ≥ 2) shape and asserts:
(a) the **app-surface bytes are byte-identical**, where *app-surface bytes* is the **beta-normalized Dhall
expression of the app-surface slice extracted from each of two *distinct* composed spec files** — the two
composed fixtures do **not** share one app-surface import, so the equality is never a file-compared-to-itself
tautology;
(b) the bound `ServiceSpec` differs **structurally** by the oracle: the provider object graphs differ in
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
with its specific `DecodeError` (unbuilt-provider-arm)**.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§3/§4/§5 binding backlink),
`documents/engineering/manifest_generation_doctrine.md` (who produces the `ServiceSpec` render consumes),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding),
[`§3`](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates),
and [`§5`](../documents/engineering/service_capability_doctrine.md#5-per-cluster-structural-shapes--beyond-values):
implement the three-part binding as a pure total function so that one byte-identical app spec binds to a
structurally different `ServiceSpec` per cluster, the provider defaulting to canonical and the shape selecting
which manifest graph to render.

### Deliverables
- A `CapabilityBinding` whose `provider` is a **one-arm-today** typed union defaulting to the
  [§3](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates)
  canonical provider (headroom for an alternate, but no adapter amoebius does not yet need), and whose `shape`
  is a typed choice (`SingleNode` vs `Distributed { nodes }`), bound only on the deployment-rules surface.
- `bind :: CapabilityNeed -> CapabilityBinding -> ServiceSpec`, pure and total, selecting the provider's
  **manifest graph for the chosen shape** — a structurally different object graph, not a scalar `replicas`
  edit — handed to the Phase-9 renderer.
- An in-file honesty note: a single-node shape is the canonical provider deployed honestly at small scale (a
  one-member Patroni `Sql`, never a bare `postgres` Pod); `bind` produces a value, not a live provider — the
  live realization is the live band.

### Validation
1. The same `CapabilityNeed`, bound under two shapes, produces two `ServiceSpec`s that are **structurally
   different by the object-node-multiset oracle** (deep structural diff per §5, red on a scalar-only or
   copied-shape-tag difference; each equal to its Phase-0-committed golden), while the **app-surface bytes**
   (beta-normalized app-surface slices from two distinct composed spec files) are identical; a binding to an
   unbuilt provider arm returns a structured `Left` tagged (Gate 2); `bind` never throws. This validation must
   go **red** on the committed `mutant_copy_shape_tag` seeded mutant (Sprint 8.4) — which makes `bind` copy the
   shape tag into a `providerGraph` field instead of selecting a manifest graph, passing a plain `/=` but
   failing the multiset oracle.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.3: The `InferenceEngine` capability — substrate-selected `EngineRuntime`, no URL arm (representational) 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (extend: the `InferenceEngine` head, the closed
`EngineRuntime` lane union, the engine-family union, and the per-served-model `vramFootprint` field);
`src/Amoebius/Capability/Engine.hs` (the substrate→lane quotient projection and the **partial** family×lane
availability relation) — target paths, not yet built.
**Blocked by**: Sprint 8.1, Sprint 8.2; Phase 7 gate (the `Σ served-model VRAM ≤ node vram` fold this footprint
feeds).
**Independent Validation**: a unit + property suite confirms the `EngineRuntime` union has **no** `Url`/`Download`
arm (an engine named by URL fails `dhall type`, Gate 1); the substrate→lane quotient projects
`apple → AppleMetal`, `linux-cpu → LinuxCpu`, `{ linux-cuda, windows } → Cuda` and has no constructor to author
a lane free of its substrate; a served model whose engine family is unavailable on the serving lane returns a
structured `Left` at decode (the relation-over-a-collection technique).
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§4.1 backlink),
`documents/engineering/content_addressing_doctrine.md` (§4.5 Tier-1 engine read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.25 layer reconciliation), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-substrate-selected-and-jit-resolved-never-authored)
and [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
build the ninth capability as the strictest instance of the [§4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
binding — a provider that is **selected by the detected substrate** and materialized on first miss, with no arm
to author a download — as a representational union and relation, no live resolve.

### Deliverables
- The `InferenceEngine` capability and its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` ·
  `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm** — an ML engine is a **named catalog identity**, never
  baked and never fetched by URL, so "name the engine by URL" has no syntax and fails Gate 1.
- The substrate→lane **quotient** projection (`apple → AppleMetal`, `linux-cpu → LinuxCpu`,
  `{ linux-cuda, windows } → Cuda`, `Cuda` OS-agnostic with no Linux-vs-Windows constructor) — the engine is
  *projected from* the detected substrate, never declared free of it — and the closed engine-family union.
- The **partial** family×lane availability relation making a served model whose family is unavailable on the
  serving lane a **decode-foreclosed** `Left` (the [`illegal_state_techniques.md §4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  relation-over-a-collection technique), and the per-served-model `vramFootprint` field consumed by the Phase-7
  `Σ served-model VRAM ≤ node vram` fold.
- An in-file honesty note: this is the representational union + relation only; the actual jit-build resolve into
  the `CacheBudget`-bounded content-addressed cache, and the runtime-checked cross-lane weight-load residue,
  are the live band ([Phase 32](phase_32_jitbuild_engine_cache.md)) — sibling evidence where infernix's
  `Worker.hs` selects (never fetches) its engine, not an amoebius result.

### Validation
1. An engine named by URL fails Gate 1 (the union has no such arm); an unavailable family-on-lane returns a
   structured `Left` at decode; the substrate→lane quotient is total and the OS-vs-Cuda split has no inhabitant.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 8.4: The binder property/corpus + the Register-1 gate 📋

**Status**: Planned
**Implementation**: `test/capability/BindingProps.hs` (the property battery), `test/capability/BindGate.hs`
(the gate + validation-locus ledger with coverage-assertion machinery), the **Phase-0-committed** per-arm
positive fixtures `dhall/examples/legal_<arm>_{singlenode,distributed}.dhall` for all nine arms, the reviewer
-authored goldens `test/capability/goldens/golden_servicespec_<arm>_<shape>.golden` (authored before `bind`
exists), the seeded mutants under `test/capability/mutants/{mutant_copy_shape_tag,mutant_catchall_arm,
mutant_shared_app_import}`, and `dhall/examples/{legal_objectstore_singlenode,legal_objectstore_distributed,
legal_inference_cuda,illegal_product_in_app,illegal_engine_by_url,illegal_shape_in_app,
illegal_unbound_capability,illegal_unbuilt_provider,illegal_engine_family_unavailable_on_lane}.dhall` — target
paths, not yet built.
**Blocked by**: Sprint 8.1, Sprint 8.2, Sprint 8.3; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: `cabal test capability-spec` is green — each of the **nine per-arm** positive needs
binds to a well-typed `ServiceSpec` under both shapes with byte-identical app bytes (beta-normalized
app-surface slices from distinct composed files) and a structural difference passing the object-node-multiset
oracle (red on scalar-only / copied-shape-tag) against its Phase-0-committed golden; the exhaustiveness check
confirms all nine arms are covered; the QuickCheck totality property fires each of the nine constructors ≥ 8%
(`checkCoverage`); each Gate-1 negative fails `dhall type` **at its asserted error locus** and each
Gate-2/decode negative returns a structured `Left` **tagged with its specific `DecodeError`** and annotated
with its catalog entry (§3.12 / §3.25) and foreclosure layer, each paired with a minimally-differing positive;
the three committed seeded mutants (`mutant_copy_shape_tag`, `mutant_catchall_arm`, `mutant_shared_app_import`)
each turn the suite **red** when substituted; the run emits a Register-1 proven/tested/assumed ledger whose
coverage-assertion machinery is red if any named fixture, negative reason, or mutant is absent.
**Docs to update**: `documents/engineering/service_capability_doctrine.md`,
`documents/illegal_state/illegal_state_catalog.md` (§3.12/§3.25 → realized layer),
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-8 status when the
gate passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-8 `none` gate row).

### Objective
Adopt [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
and [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2/§4: assemble the phase's single
Register-1 gate — every positive need binds to a `ServiceSpec` while every product- or URL-named app has no
syntax — and emit the per-entry validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables
- The **concrete positive corpus** — **one fixture per each of the nine capability arms** (`ObjectStore`,
  `SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge`, `InferenceEngine`),
  each bound under **both** a `SingleNode` and a `Distributed { nodes = n }` (n ≥ 2) shape — so the corpus is
  not scope-shrunk to the three named `legal_objectstore_{singlenode,distributed}` / `legal_inference_cuda`
  fixtures. A committed **exhaustiveness unit check** asserts the fixture→capability-arm map covers the full
  nine-arm union (red if any arm has no positive fixture), enumerated against the **Phase-0-committed
  hand-authored arm list** (Sprint 8.1), independent of `bind`'s own case analysis.
- The property battery: the same `CapabilityNeed` bound under two shapes yields two `ServiceSpec`s
  **structurally different by the object-node-multiset oracle** (red on scalar-only / copied-shape-tag) with
  byte-identical app bytes (beta-normalized app-surface slices from distinct composed files); **every declared
  need binds totally (no partial `bind`) across all nine arms**, with QuickCheck `label`/`classify` +
  `checkCoverage` obligations forcing each of the **nine need constructors** to fire a stated minimum fraction
  (≥ 8% each), so a generator emitting only the three covered constructors fails coverage; an unbound
  capability is an undecodable record, not a runtime `Pending`.
- The negative corpus — `illegal_product_in_app` (§3.12, Gate 1), `illegal_engine_by_url` (§3.25, Gate 1),
  `illegal_shape_in_app` (shape/provider on the app surface, Gate 1), `illegal_unbuilt_provider` (Gate 2),
  `illegal_engine_family_unavailable_on_lane` (decode-foreclosed), `illegal_unbound_capability` (undecodable) —
  each asserting **its specific failure reason** (its expected `dhall type` error locus or `DecodeError` tag)
  and each **paired with a positive differing only in the foreclosed dimension**, alongside the positive
  nine-arm corpus above that binds feasibly.
- **Committed seeded mutants (§M.2)** — a defined operator set of ≥ 3 deliberately broken implementations,
  committed and re-run (not run once), that the gate MUST turn red: `mutant_copy_shape_tag` (effect swap:
  `bind` copies the shape tag into a `providerGraph` field instead of selecting a manifest graph — defeats a
  `/=`-only diff, caught by the multiset oracle); `mutant_catchall_arm` (union-arm addition: a catch-all
  `bind` arm returns a degenerate `ServiceSpec` for the six uncovered capabilities — caught by the per-arm
  golden + exhaustiveness check); `mutant_shared_app_import` (the two composed fixtures share one app-surface
  import — makes byte-equality vacuous — caught by the distinct-composed-file requirement in (a)). The gate
  re-runs each mutant and asserts red.
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
   decode negative returns its specifically-tagged `Left`, each paired with a minimally-differing positive; the
   suite is red if any product-named, URL-named, or shape-in-app fixture decodes, and red under each of the
   three committed seeded mutants (`mutant_copy_shape_tag`, `mutant_catchall_arm`, `mutant_shared_app_import`).
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
  decode-foreclosed; keep the runtime-checked residue (provider up, engine resolved) deferred.
- `documents/engineering/content_addressing_doctrine.md` — reconcile §4.5's Tier-1 engine as the
  `InferenceEngine` provider whose named identity this binder decodes; keep the jit-resolve into the bounded
  cache as the live-band residue.
- `documents/engineering/manifest_generation_doctrine.md` — record that the binder produces the `ServiceSpec`
  the pure renderer consumes; `documents/engineering/app_vs_deployment_doctrine.md` — the app-surface capability
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
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the IR + decoder the `ServiceSpec` is a projection of
- [phase_07](phase_07_capacity_topology_folds.md) — the capacity/topology folds (incl. the `Σ VRAM` fold this
  phase's `vramFootprint` feeds) whose gate opens this phase
- [phase_09](phase_09_render_manifest_goldens.md) — the pure `render :: ServiceSpec -> [K8sObject]` that
  consumes the `ServiceSpec` this binder produces
- [phase_32](phase_32_jitbuild_engine_cache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this phase only decodes
