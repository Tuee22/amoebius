# Illegal States — ML Assets & Training

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/content_addressing_doctrine.md, documents/engineering/dsl_doctrine.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_techniques.md, documents/engineering/service_capability_doctrine.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering the engine/model/kernel asset
> lifecycle (jit-build cache), continuous-training cadence, feed merge order, and cross-app model grants —
> the ML-asset states a valid `InForceSpec` cannot represent.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: it carries the deep treatment of the
ML-asset and training illegal states ([§3.25](#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model),
[§3.32](#332-a-continuous-training-run-with-no-checkpoint-cadence-or-a-feed-with-no-bounded-retention),
[§3.33](#333-a-multi-partition-training-feed-with-no-defined-merge-order),
[§3.34](#334-an-app-serving-or-continuing-another-apps-model-without-a-grant)) and nothing else.

It is **not** the index of the catalog. The full catalog index, the SSoT split, and the load-bearing honesty
limit (a type-check proves the *spec composes*, not that the *running cluster enforces it*) are owned by
[`illegal_state_catalog.md`](./illegal_state_catalog.md). The **seven typing techniques** ([§4](./illegal_state_techniques.md#4-the-typing-techniques)), the **coverage
matrix** ([§5](./illegal_state_catalog.md)), the **three-layer foreclosure** model ([§6](./illegal_state_catalog.md)), and the **validation-locus
axis** (the orthogonal `Gate-1-editor` / `Gate-2-decoder` / `rendered-output-golden` / `live-effect` axis added
on top of the foreclosure layer) are owned by
[`illegal_state_techniques.md`](./illegal_state_techniques.md). This slice **references** those — it does not
restate them. Each entry below preserves its original number and heading verbatim (inbound links depend on the
slug), reproduces the entry body faithfully, and adds one **Validation-locus** line deriving the entry's place on
that new axis from its existing foreclosure **Layer** tag.

Everything below is **design intent**, per the catalog's honesty discipline: the type-check proves the
specification composes into something internally coherent, not that the running deployment enforces it. Read
every "unrepresentable" as *design intent for the type discipline*, never as a tested amoebius behaviour.

---

## 2. The ML-asset & training illegal states

### 3.25 An ML asset named by arbitrary URL (or an unready / unlanded model)

Three ML-asset illegal states ride together. **(a) An engine named by arbitrary URL.** Sibling ML
runtimes curl-tar native payloads and install venvs at image *build* and then re-select per engine — amoebius
makes the compute engine an `EngineRuntime`, a **closed union of substrate-tagged engine identities with no
arbitrary-`Url`/`Download` arm**: the engine is *named* by a typed identity from a closed catalog, selected by
the detected substrate, and the shared **jit-build resolver** materializes that named identity on first miss
into a **`CacheBudget`-bounded content-addressed cache**
([content_addressing_doctrine.md §4.5](../engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).
Naming an engine by an arbitrary URL has no syntax; the first-miss resolve is a bounded-cache act, not a startup
URL fetch, and "more cached than fits" is decode-rejected by the capacity fold over `CacheBudget`.
**(b) A `ModelArtifact` without a completed `.ready` *and a provenance witness*.** A `ModelArtifact` yields an
`ArtifactRef` **only** once its `.ready` sentinel exists (staging writes `.ready` LAST) **and** it carries a
**provenance witness** — one of a **committed producing checkpoint** (a committed `latest`/`best` pointer that
always names a *complete* checkpoint, never a "finished run", so it composes with serving a still-running
continuous job) **or** a **pinned, content-addressed external import** carrying provenance — so a reference to a
half-staged *or provenance-less* model has no constructor (the same `.ready`-gating the release `PromotionGate`
mirrors, [§3.26](./illegal_state_lifecycle.md#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence)). A green
`.ready` proves staging *completeness* (bytes written), **not** training *provenance*; the witness closes that
gap, and naming a model for import IS an explicit content-addressed import-with-provenance (there is no bare
stage-by-name-without-provenance constructor). The provenance-gated constructor is owned by
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) §4.5; this refines the serve gate — it does
**not** add a second catalog entry. **(c) A model with no landing
engine.** A `ModelArtifact` must be servable by an `EngineRuntime` present on the deployment's substrate; an
unmatched model has no landing engine — a **decode-foreclosed total relation** ([§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)), the same relation-over-a-
collection shape as the engine↔substrate fold ([§3.13](./illegal_state_topology.md#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class)). **Owner:**
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (the `EngineRuntime`/`ModelArtifact` asset
tiers + the content-addressed store) + [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) (the
engine as a substrate-selected capability). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed `EngineRuntime` union — no arbitrary-`Url` arm) +
[§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (an `ArtifactRef` handle exists only once its `.ready` edge does) + [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the model↔engine relation).
**Layer:** type-foreclosed for the no-arbitrary-URL engine identity and the `.ready`-**and-provenance-witness**-gated `ArtifactRef` (the
committed-checkpoint arm and the *presence* of a provenance witness are genuine no-inhabitant constructors); decode-foreclosed
for the model↔engine relation and the `Σ(resident) ≤ CacheBudget` cache fold (checked total folds, not an absence of inhabitants); runtime-checked residue — that the
first-miss resolve succeeds, the staged bytes actually load on the substrate, and that an imported model's pin/tag is **truthful** (owned by
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) §6.1).

**Validation-locus:** `Gate-1-editor` (the closed `EngineRuntime` union with no arbitrary-`Url` arm fails
`dhall type` the moment an engine is named by URL) + `Gate-2-decoder` (the `.ready`-and-provenance-witness-gated
`ArtifactRef` GADT edge, the model↔engine total relation, and the `Σ(resident) ≤ CacheBudget` capacity fold all
return `Left` from the total decoder) + `live-effect` (the residue: the first-miss resolve succeeding, the staged
bytes loading on the substrate, and an imported model's pin/tag being truthful).

### 3.32 A continuous training run with no checkpoint cadence, or a feed with no bounded retention

"Train forever from a live feed" is how a bounded training budget quietly becomes unbounded — no checkpoints
means nothing serveable and no resume point, and unbounded topic retention means BookKeeper fills. This round
adds a **`TrainBudget = Bounded { steps | epochs } | Continuous { checkpointCadence }`** union: `Continuous`
**requires** a `checkpointCadence` (each cadence commits a checkpoint — a committed pointer, hence serveable per
[§3.25](#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)(b): serve-from-any-committed-checkpoint
of a still-running job) and its `TrainData.Feed` **requires** a bounded-retention `StorageBudget`. "Train forever
with no checkpoints and no retention" has **no constructor** — a **type-foreclosed union shape**, exactly the
`Growable`/`ScalingPolicy` no-unbounded-arm idiom ([§3.21](./illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)).
The authoritative Continuous trainer is **single-cluster** (the existing jitML First-Axis coordinator, its
single-writer *delegated* to a Pulsar Exclusive/Failover subscription + content-store CAS/`AdvancePredicate`, not
a bespoke election); cross-cluster is serve-by-replication, never a second trainer on the same feed. **Owner:**
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (owns the `TrainInit`/`TrainData`/`TrainBudget`
unions + the foreclosure; `dsl_doctrine.md` carries the field only), with retention bounded by the two-ceiling
storage fold ([`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) +
[`pulsar_client_doctrine.md` §6](../engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra)). **Technique:**
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed `TrainBudget`/`Feed`
unions with no unbounded arm) + [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(the retention room-fit). **Layer:** type-foreclosed for the mandatory-cadence / bounded-retention union shape; **runtime-checked**
residue — that the trainer actually checkpoints at cadence and retention actually holds (mirroring §3.21's
runtime-checked tail).

**Validation-locus:** `Gate-1-editor` (the closed `TrainBudget`/`Feed` unions with no unbounded arm, and the
mandatory `checkpointCadence` / bounded-retention `StorageBudget` fields, fail `dhall type` at authoring time) +
`Gate-2-decoder` (the [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) retention room-fit is a total decode fold that returns `Left` on overflow) +
`live-effect` (the residue: the trainer actually checkpointing at cadence and retention actually holding).

### 3.33 A multi-partition training feed with no defined merge order

A Pulsar topic with multiple partitions has no total consume order, so "train from this feed" is
non-deterministic unless the merge is pinned — a prose "must consume in order" degrades to an untyped runtime
hope. This round makes `TrainData.Feed` carry a **typed single-partition-or-explicit-merge-function witness**, so
a non-deterministically-ordered feed has **no constructor**. The consumed prefix `[from, to)` is materialized at
consume time into an **immutable dataset blob keyed by the SHA(s) of the message bodies** (bodies are already
CBOR content-addressed), and *that* content-address is the pinned training input — the Pulsar cursor is
broker-assigned metadata, never an input to any content hash. **Owner:**
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (the `TrainData.Feed` merge witness + the
materialized-prefix content-address) + [`pulsar_client_doctrine.md` §6](../engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra)
(the topic as a cursor-anchored replayable feed). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the closed merge-witness on `Feed`) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(a `Feed` handle exists only once its single-partition-or-merge witness does). **Layer:** type-foreclosed/decode-foreclosed — the merge
witness makes the non-deterministic feed unrepresentable (type-foreclosed where the witness is a closed union arm;
decode-foreclosed where the explicit merge function is a decode-checked total order); runtime-checked residue — that the broker
actually replays the pinned prefix within retention.

**Validation-locus:** `Gate-1-editor` (where the merge witness is a closed union arm — single-partition or a
named merge — the non-deterministic feed fails `dhall type`) + `Gate-2-decoder` (where the explicit merge
function is a decode-checked total order, the total decoder returns `Left` on a non-total order) + `live-effect`
(the residue: the broker actually replaying the pinned prefix within retention).

### 3.34 An app serving or continuing another app's model without a grant

With model artifacts content-addressed in shared project buckets, any app in a cluster could dedup-and-serve
another app's model, leaking a private model or its provenance across the app-isolation boundary. This round
scopes model artifacts **per app/namespace**: an app may serve **only** models it produced or imported, the
content-store pointers are per-app-namespaced, the upstream-pull Vault credential is scoped per app, and a
fine-tune-chain `parent` edge may **not** cross app boundaries. "App B serving or continuing app A's model
without an explicit grant" is a **decode-foreclosed** decode rejection (an explicit grant, if modeled, is the only
constructor that crosses). **Owner:** [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md)
(per-app pointer namespacing + the no-cross-app `parent` edge) + [`vault_pki_doctrine.md`](../engineering/vault_pki_doctrine.md)
(the per-app upstream-pull credential). **Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(a per-app ownership index — the fold rejects a cross-app model reference absent a grant) +
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (app-scoped tags, the same
shape as the cross-tenant refs of [§3.8](./illegal_state_security.md#38-cross-tenant-references-and-literal-secrets)). **Layer:** decode-foreclosed — a
total decode-time rejection; runtime-checked residue — that the running serve path honors the namespace.

**Validation-locus:** `Gate-2-decoder` (the per-app ownership-index fold and the app-scoped phantom tags make a
cross-app model reference absent a grant a total decode-time `Left`) + `live-effect` (the residue: the running
serve path honoring the per-app namespace).

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index this slice is
  carved from: owns the SSoT split, the honesty limit ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)), and the full list of entries.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques, the coverage
  matrix, the three-layer foreclosure model, and the **validation-locus axis** these entries are classified
  against.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract ("a valid `InForceSpec` cannot
  represent illegal state"); carries the `TrainBudget`/`TrainData` fields, whose foreclosure is owned elsewhere.
- [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — owner of the `EngineRuntime` /
  `ModelArtifact` asset tiers, the ML-asset lifecycle (one bounded content-addressed cache resolved on first
  miss), the `TrainInit` / `TrainData` / `TrainBudget` unions, the merge witness + materialized-prefix
  content-address, and per-app pointer namespacing with the no-cross-app `parent` edge.
- [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) — the engine as a substrate-selected
  capability ([§3.25](#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)).
- [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) — the two-ceiling storage fold bounding
  feed retention ([§3.32](#332-a-continuous-training-run-with-no-checkpoint-cadence-or-a-feed-with-no-bounded-retention)).
- [`pulsar_client_doctrine.md`](../engineering/pulsar_client_doctrine.md) — topic retention and the topic as a
  cursor-anchored replayable feed ([§3.32](#332-a-continuous-training-run-with-no-checkpoint-cadence-or-a-feed-with-no-bounded-retention),
  [§3.33](#333-a-multi-partition-training-feed-with-no-defined-merge-order)).
- [`vault_pki_doctrine.md`](../engineering/vault_pki_doctrine.md) — the per-app upstream-pull credential
  ([§3.34](#334-an-app-serving-or-continuing-another-apps-model-without-a-grant)).
