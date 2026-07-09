# Release Lifecycle

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/testing_doctrine.md, DEVELOPMENT_PLAN/later_phases.md
**Generated sections**: none

> **Purpose**: Define delivery — build, promote, roll out — as **typed composition on primitives amoebius
> already owns**, with **no external CI/CD control plane** (no Argo, no Flux, no Tekton — the Helm/Harbor of
> delivery). The four values: the immutable `Release` ledger keyed by `releaseHash`; the per-`Environment`
> (`Dev`/`Staging`/`Prod`) ETag-CAS promotion pointer; the `PromotionGate` that makes promote-unverified→prod
> **unrepresentable**; and the readiness-gated `RolloutPlan` / `RolloutPhase` apply (schema-migration as a
> phase, canary, rollback) on the in-cluster SSA reconciler. This document **owns** the `environment`
> promotion-pointer kind, the `PromotionGate` and its environment→required-evidence mapping, and the
> `RolloutPlan`/`RolloutPhase` apply model. It **composes** — not re-owns — the immutable `Release` ledger
> ([manifest_generation_doctrine.md §6.1](./manifest_generation_doctrine.md#61-the-release-ledger-the-applied-log-is-canonical-not-optional)),
> the ETag-CAS protocol ([content_addressing_doctrine.md §2.3](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds)),
> and the test-evidence ledger ([testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)), and points at their authoritative homes.

---

## 1. No external CI/CD control plane — delivery is typed composition on primitives amoebius owns

A conventional platform bolts a **second control plane** onto the cluster to do delivery: Argo CD polls a git
repo and reconciles the diff, Flux does the same with its own CRDs, Tekton runs pipeline pods, and each one is
its own operator, its own RBAC surface, its own upgrade cycle, its own store of "what should be deployed."
That second plane is, to delivery, exactly what Helm is to manifests and Harbor is to the registry: an
unowned, unreviewed intermediary that re-introduces the *"valid YAML, wrong cluster"* failure class
([illegal_state_catalog.md §1](../illegal_state/illegal_state_catalog.md#1-illegal-states-fail-to-type-check)) at the delivery layer — a git-polling controller
can apply a manifest set no amoebius type ever inspected.

**amoebius refuses the second control plane, exactly as it refuses Helm and Harbor.** Delivery is not a
separate system; it is a handful of typed values composed over primitives amoebius has already defined
elsewhere. There is nothing to install, nothing to poll, and nothing to reconcile *the reconciler*:

- **One binary, two enactment frames.** The single amoebius binary composes the whole pipeline. The **build**
  half — producing multi-arch images and pushing them to the in-cluster `distribution` registry — is enacted
  by the **sudo host daemon** ([image_build_doctrine.md](./image_build_doctrine.md)). The
  **test / promote / rollout** half is enacted by the **in-cluster singleton**
  ([daemon_topology_doctrine.md §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton)). No third process arbitrates between them.
- **Auditability comes from an immutable ledger, not a controller's opinion.** What a conventional platform
  gets from "the state Argo believes is desired," amoebius gets from the immutable `Release` ledger ([§2](#2-release-and-the-immutable-release-ledger-releasehash)) plus
  the ETag-CAS pointer history ([§3](#3-environment-and-the-etag-cas-promotion-pointer)): a content-addressed, append-only record of every generation ever built
  and every promotion ever made. There is no polling loop to trust — the desired state is
  `render(release)`, recomputed from a value, exactly as the manifest reconciler recomputes desired from
  `render(InForceSpec)` ([manifest_generation_doctrine.md §6](./manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed)).
- **The environment axis is orthogonal, not a new machine.** Dev/staging/prod is one of amoebius's four
  independent typed dimensions (substrate detected; daemon-role elected; rke2 server/agent declared;
  environment declared) — it rides the same reconciler, never a bespoke delivery engine.

**What this doctrine owns vs. defers.** This document owns only the *composition* — the four delivery values
and how they chain. Every primitive they compose is owned elsewhere:

| Concern | Owned by |
|---------|----------|
| `releaseHash`, the hash/pointer master registry, the content-addressed store the ledger writes into | [content_addressing_doctrine.md §2.3 / §4](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds) |
| The SSA/ApplySet reconciler `RolloutPlan` enacts, and the *optional applied-log* this doctrine promotes to canonical | [manifest_generation_doctrine.md §5 / §6](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait) |
| The per-run proven/tested/assumed evidence ledger a `PromotionGate` reads | [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) |
| That env differences are **deployment rules**, and app bytes are byte-identical across environments | [app_vs_deployment_doctrine.md §3 / §4](./app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs) |
| `create-new → verified-migrate → retire-old` for the schema-migration phase | [storage_lifecycle_doctrine.md §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction) |
| Gateway-API `HTTPRoute` `backendRefs` weights the canary shifts | [network_fabric_doctrine.md](./network_fabric_doctrine.md) |
| The control-plane singleton that runs the promote/rollout half | [daemon_topology_doctrine.md §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton) |

> **Honesty.** This whole doctrine is **Phase-0 reference-only design intent**. None of the four values is
> built in amoebius. Where a sibling exhibits the shape — jitML's phased rollout, jitML's pre/post-grant
> schema phase, infernix's `.ready`-gated artifact — that is **sibling evidence, not an amoebius result**
> ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)). Read every prescriptive statement below as
> the contract amoebius intends to satisfy.

---

## 2. `Release` and the immutable release ledger (`releaseHash`)

The unit of delivery is one immutable value:

```haskell
-- Conceptual shape — a Release is a ledger entry, never edited in place.
data Release = Release
  { releaseHash        :: ReleaseHash        -- sha256(resolved-deployment-dhall ‖ image-digests ‖ substrate-fp)
  , deploymentDhallRef :: ContentAddress     -- the resolved deployment .dhall, by content
  , imageDigests       :: [OciImageDigest]   -- the exact images this generation runs
  , substrateFp        :: SubstrateFingerprint
  }
```

- **`releaseHash` is a distinct hash class, never shared.** It is registered in the canonical hash/pointer
  master table alongside `experimentHash`, `kernelKey`, and the OCI image digest
  ([content_addressing_doctrine.md §2.3](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds)),
  which is that table's **single source of truth** — this doctrine consumes it and does not restate the
  formula's authority. `releaseHash = sha256(resolved-deployment-dhall ‖ image-digests ‖ substrate-fp)` folds
  in exactly the three things that can change what a generation *does*: the resolved deployment spec, the
  image bytes it runs, and the substrate it targets. Change any one and the identity changes; change none and
  the same `Release` is returned — content-addressed, self-naming, deduplicated.
- **The ledger is the applied-log, promoted to canonical.**
  [manifest_generation_doctrine.md §6](./manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed)
  leaves an **optional** content-addressed applied-log — "amoebius *may* write each rendered generation into
  the content-addressed store." **This doctrine promotes that optional log to THE canonical, immutable release
  ledger**: every built generation is an append-only `Release` entry in the content-addressed store (pointers
  → manifests → blobs), keyed by `releaseHash`. What was a nice-to-have revision history for the manifest
  reconciler is load-bearing here — it is the record a promotion advances a pointer *onto* ([§3](#3-environment-and-the-etag-cas-promotion-pointer)) and the record
  a rollback re-applies *from* ([§5](#5-rolloutplan--rolloutphase-the-readiness-gated-apply)).
- **A `Release` is immutable; only pointers move.** No field of a `Release` is ever edited. Promotion,
  rollback, and drift-correction are all expressed as **pointer** operations ([§3](#3-environment-and-the-etag-cas-promotion-pointer)) over a fixed set of ledger
  entries — the same discipline as a `trial` pointer flipping over immutable manifests
  ([content_addressing_doctrine.md §2](./content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)).
  This is why "no release store to desync" holds: unlike Helm's mutable, gzip-blob release Secret, an
  amoebius `Release` cannot be half-written or edited out from under a pointer.

> **Layer.** The immutability and self-naming are **runtime-checked residue** enforced by the
> content-addressed write protocol (a blob at a hash either is the bytes that hash to it, or the write is
> rejected) — the enforcement actually holds at runtime, it is not a compile-time impossibility.

### Sibling evidence

No sibling keeps a content-addressed *release* ledger; the closest evidence is that jitML and infernix already
key ML *artifacts* by a `sha256(resolved-dhall ‖ substrate-fingerprint)` `experimentHash`
([content_addressing_doctrine.md §3](./content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)),
so the "identity = what was requested ‖ where it ran" fold is proven for runs and **generalized** here to
deployment generations. That is sibling evidence, not an amoebius result.

---

## 3. `Environment` and the ETag-CAS promotion pointer

Environments are a closed, three-arm union, and each names a **mutable pointer** into the immutable ledger:

```haskell
data Environment = Dev | Staging | Prod          -- closed union; no fourth, unnamed environment exists
-- one ETag-CAS pointer per Environment, each pointing at a Release (by releaseHash)
```

- **"Promote to prod" is a pointer CAS, then a converge.** Advancing an environment is not a redeploy and not
  a new build — it is a **compare-and-swap of that environment's pointer** from the old `releaseHash` to the
  new one, using the same ETag-CAS write protocol that advances a `trial` or `model` pointer
  ([content_addressing_doctrine.md §2.3](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds),
  where the `environment` pointer kind is registered as owned by this doctrine). Once the pointer moves, the
  in-cluster SSA reconciler ([§5](#5-rolloutplan--rolloutphase-the-readiness-gated-apply)) converges `render(release)` for that environment. The CAS is the atomic,
  race-free commit; the reconcile is the enactment.
- **App bytes are byte-identical across environments.** Dev, staging, and prod run the **same image digests**
  and the **same application logic** — an app is
  [written once](./app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once). Everything that
  differs between environments lives on the **deployment-rules surface**
  ([app_vs_deployment_doctrine.md §3](./app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)):
  replica counts, resource budgets, chaos schedules, geo-topology. There is **no** `if prod then …` in an app
  spec, and no rebuild between environments — promoting is moving a pointer at a `Release`, not producing a
  new one. (This is the delivery-layer face of the app/deployment split: the *same* `Release` can be pointed
  at by `Staging` and then `Prod` with zero app change.)
- **The pointer history is the audit trail.** Because each environment pointer is advanced only by CAS and the
  store retains prior pointer values, "what was in prod, when, and which `Release` preceded it" is a first-class
  query — replacing the git-polling controller's changelog with an immutable pointer log.

> **Layer.** Atomicity of promotion is **runtime-checked**: it is the ETag-CAS runtime protocol that forecloses a
> lost-update / split-promotion race, not a type-level impossibility. The *closedness* of `Environment` (no
> fourth environment) is **type-foreclosed** — an un-enumerated environment has no constructor.

### Sibling evidence

The ETag-CAS pointer flip is proven in the sibling content store for `trial` pointers (best/latest over ML
manifests); the `environment` pointer **reuses that exact protocol** for a new pointee (`Release`). Sibling
evidence for the mechanism, not an amoebius result for environment promotion.

---

## 4. `PromotionGate`: promote-unverified→prod is unrepresentable

A `PromotionGate` is a **typed precondition on advancing an environment pointer**: the CAS of [§3](#3-environment-and-the-etag-cas-promotion-pointer) cannot fire
unless the `Release` being promoted carries the evidence that environment requires.

```haskell
-- Conceptual shape — the advance constructor demands an evidence witness.
advance :: Environment -> Release -> EvidenceWitness -> PointerCas
--                                   ^^^^^^^^^^^^^^^^^ no witness ⇒ no advance value ⇒ nothing to CAS
```

- **The gate reads the test-topology ledger; it does not compute it.** Every test run emits a
  proven/tested/assumed evidence ledger as a first-class artifact — owned entirely by
  [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact), whose
  methodology and grammar are in turn owned by
  [chaos_failover_doctrine.md](./chaos_failover_doctrine.md). The `PromotionGate` **consumes** that ledger as
  the `EvidenceWitness` for a `Release`. This doctrine owns only the *mapping from environment to required
  evidence strength*, not the ledger itself.
- **Prod requires the chaos layer proven.** The required-evidence-strength mapping is monotone up the
  environments: `Dev` may advance on a green Decision layer; `Prod` requires the **Runtime/chaos layer
  proven**, not merely assumed. A layer the run recorded **UNVERIFIED** (a skipped-but-applicable move,
  [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact))
  yields no witness for that layer — so a `Release` short of prod's required strength has **no** `advance`
  value to hand the CAS.
- **A Tier-1-only in-process ledger cannot advance the gate to prod.** The front-loaded pre-cluster (Phases 2–6)
  formal-validation track emits its evidence ledger from a purely **in-process** run — Dhall typecheck +
  decoder + QuickCheck + TLA+/TLC, **no live substrate** — a **Tier-1 (design-time) artifact** that
  establishes only that the spec composes and the protocol is sound in the abstract, with the Runtime/chaos
  (Tier-2) correspondence and enforcement left **UNVERIFIED**
  ([testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) owns
  this Tier-1-only variant). Because the strength mapping demands the Runtime/chaos layer *proven* for `Prod`,
  such a ledger supplies **no Runtime `EvidenceWitness`** — there is no `advance` value to hand the CAS, so a
  `Prod` `PromotionGate` **cannot be advanced on a Tier-1-only (in-process, correspondence/runtime-UNVERIFIED)
  ledger**. This is the structural fence that keeps "we validated the DSL in-process" from ever meaning "the
  cluster enforces it."
- **Promote-unverified→prod is type-foreclosed unrepresentable.** Because `advance` demands an `EvidenceWitness` and
  that witness exists only once the corresponding evidence edge exists, there is simply **no term** that
  promotes an under-verified `Release` to prod — not a runtime check that fires, but a value that cannot be
  constructed. This is the same idiom as infernix's `.ready`-gated `ArtifactRef` (an artifact handle exists
  only once the `.ready` sentinel does) and as amoebius's own `ModelArtifact` (§ content-addressing) — *a
  handle exists only once its evidence edge does*. This state is catalogued at
  [illegal_state_catalog.md §3.26](../illegal_state/illegal_state_lifecycle.md#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence) (an
  unverified environment promotion), owned by this doctrine, technique "a handle exists only once its evidence
  edge does."
- **Generalizes the already-planned `Multicluster/PromotionGate.hs`.** amoebius already scopes a
  `PromotionGate` for the multicluster spawn path; this doctrine **generalizes** that single-purpose gate into
  the uniform per-environment promotion precondition. That is amoebius design intent (Phase-N), not a built
  gate.

> **Layer.** Promote-unverified→prod is **type-foreclosed** (uninhabitable — no `advance` term). The *strength
> mapping* itself (which layer prod requires) is a policy value the gate enforces at construction time.

### Sibling evidence

infernix gates a servable artifact behind a `.ready` sentinel written **last** (`model_bootstrap.py`,
`model_cache.py`) — the "no handle without its completion edge" pattern the `PromotionGate` mirrors at the
promotion layer. Sibling evidence for the *idiom*; the `PromotionGate` itself is unbuilt amoebius design intent.

---

## 5. `RolloutPlan` / `RolloutPhase`: the readiness-gated apply

Once a pointer advances, the change is enacted as an **ordered, readiness-gated plan** on the reconciler
amoebius already owns — it introduces **no new reconciler**:

```haskell
newtype RolloutPlan = RolloutPlan [RolloutPhase]   -- ordered; each phase gates the next on readiness
data RolloutPhase = RolloutPhase
  { phaseObjects :: [K8sObject]   -- the desired slice this phase applies
  , phaseGate    :: ReadinessGate -- what "this phase is done" means, observed from live state
  }
```

- **Enacted by reconciler tier (c) — the in-cluster SSA/ApplySet reconciler.** A `RolloutPlan` is applied by
  the server-side-apply engine of
  [manifest_generation_doctrine.md §5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
  each phase's objects are applied under the `amoebius` field manager, its readiness gate is **observed from
  the live object** (rollout complete / `Ready` / CR `status` healthy — never a `threadDelay`), and only then
  does the next phase apply. This is tier (c) of the reconciler taxonomy; the host-level spot-fleet reconciler
  (tier b) and the Pulumi cloud-IaC reconciler (tier a) are unrelated and live in
  [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md).
- **DB-schema migration is a `RolloutPhase`.** A schema change is not a side channel — it is an ordered phase
  obeying **`create-new → verified-migrate → retire-old`**, the exact shape
  [storage_lifecycle_doctrine.md §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction)
  requires so that **no `.dhall` value ever denotes "discard these bytes"**: the migrate phase provisions the
  new schema/columns, migrates and **verifies** the copy, and only a later phase retires the old — with the
  retire step inheriting the durable-data-deletion prohibition. This is the delivery home of the promoted
  **Phase-34** candidate ("DB schema-migration automation + manifest-change correctness semantics",
  [DEVELOPMENT_PLAN/later_phases.md](../../DEVELOPMENT_PLAN/later_phases.md)): the schema-migration engine is a
  `RolloutPhase`, and the manifest-change-correctness half hardens the typed diff of
  [manifest_generation_doctrine.md §6](./manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed).
- **Canary is a Gateway-API weight shift, not a mesh.** A canary phase shifts traffic by adjusting
  Gateway-API `HTTPRoute` `backendRefs` **weights** on the Envoy edge amoebius already renders and
  Keycloak-fronts — the *one* traffic-split feature amoebius needs, and precisely the mechanism
  [network_fabric_doctrine.md](./network_fabric_doctrine.md) records as making a service mesh unnecessary for
  v1. A `RolloutPhase` moves weight (e.g. 5% → 50% → 100%) and gates each step on the new generation's
  readiness/health. **Pulsar-consuming workloads cut over by consumer-group / subscription** instead of by
  traffic weight — the new generation subscribes, drains, and the old subscription is retired
  ([pulsar_client_doctrine.md](./pulsar_client_doctrine.md)).
- **Rollback is re-apply or CAS-back.** A failed convergence has two equivalent recoveries, both already in
  the primitive set: **re-apply the prior generation's object set** via the same SSA-declare-and-prune path
  ([manifest_generation_doctrine.md §5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)),
  or **CAS the environment pointer back** to the previous `Release` ([§3](#3-environment-and-the-etag-cas-promotion-pointer)) and let the reconciler converge. Both
  are ordinary operations over the immutable ledger — there is no special "undo" machinery, because a prior
  generation is still a valid `Release` and a prior pointer value is still a valid CAS target.

> **`RolloutPhase` is a rename of jitML's phase PATTERN — with no Helm.** The ordered, readiness-gated phase
> *type* is jitML's `HelmPhase` idea (see below) lifted off Helm entirely: amoebius renders every object
> itself (no charts, [manifest_generation_doctrine.md §1](./manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not)),
> so a `RolloutPhase` applies **rendered objects**, never a `helm install`. The pattern is borrowed; the Helm
> is dropped.

> **Layer / honesty.** The `RolloutPlan` is **Phase-N design intent** enacted by the Phase-15 SSA reconciler,
> which is itself unbuilt. Ordering, readiness-gating, canary weights, and rollback are real, documented
> Kubernetes / Gateway-API mechanisms; *that amoebius wires them into this plan type* is specified here and
> unproven until the phase lands.

### Sibling evidence

jitML's `src/JitML/Cluster/Helm.hs` defines exactly this shape — a `HelmPhase`
(`HarborPhase | PlatformPhase | FinalPhase`), a `releasePhase :: HelmPhase` field on each release, and a
`helmPhasedRolloutPlan` that applies them in readiness-gated phase order — the **`RolloutPhase` pattern,
proven in a sibling** (but bound to Helm, which amoebius drops). jitML's `src/JitML/Bootstrap.hs` splits its
rollout in two around the Postgres schema grant (`livePreGrantSubprocessesForPort → postgresSchemaGrantIO →
livePostGrantSubprocessesForPort`), which is **the schema-migration-as-a-phase shape, LIVE in a sibling** and
the concrete evidence behind the promoted Phase-34 candidate. By contrast, hostbootstrap's only delivery gate
is the build-time `check-code`, with no rollout-phase or promotion concept at all. All sibling evidence, not
amoebius results.

---

## 6. What this doctrine deliberately does not own / Planning ownership

Keeping the SSoT boundaries crisp — this doctrine *composes*, so almost every primitive it names is owned
elsewhere:

| Concern | Owned by |
|---------|----------|
| The `releaseHash` formula, the hash/pointer master registry, ETag-CAS pointer mechanics, the content-addressed store | [content_addressing_doctrine.md §2.3 / §4](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds) |
| The SSA/ApplySet reconciler, wait-for-ready, prune, and the applied-log this doctrine promotes to canonical | [manifest_generation_doctrine.md §5 / §6](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait) |
| The proven/tested/assumed evidence ledger the `PromotionGate` reads, and the no-skip / UNVERIFIED rule | [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) |
| The Extract → Model → Inject chaos methodology and the layer-strength grammar | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) |
| That environment differences are deployment rules and app bytes are identical across environments | [app_vs_deployment_doctrine.md §3 / §4](./app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs) |
| `create-new → verified-migrate → retire-old` and the durable-data-deletion prohibition the schema phase inherits | [storage_lifecycle_doctrine.md §7 / §8](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation) |
| Gateway-API `HTTPRoute` weights the canary shifts, and the no-mesh verdict | [network_fabric_doctrine.md](./network_fabric_doctrine.md) |
| Pulsar subscription / consumer-group cutover mechanics | [pulsar_client_doctrine.md](./pulsar_client_doctrine.md) |
| The build half of the pipeline (multi-arch images, the `distribution` registry) | [image_build_doctrine.md](./image_build_doctrine.md) |
| The sudo host daemon and the in-cluster singleton that enact the two halves | [daemon_topology_doctrine.md](./daemon_topology_doctrine.md) |
| The catalogued unrepresentability of an unverified promotion | [illegal_state_catalog.md §3.26](../illegal_state/illegal_state_lifecycle.md#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence) |

**Planning ownership.** This document is normative release-lifecycle doctrine only. Delivery sequencing,
completion status, and validation gates are owned by
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md), never restated here. For orientation
only (the plan is authoritative): the environment/promotion values compose with the SSA reconciler landing in
**Phase 15** and the test-topology / evidence-ledger work in **Phase 31**; the **DB schema-migration
`RolloutPhase` + manifest-change correctness** is the promoted **Phase-34** candidate
([DEVELOPMENT_PLAN/later_phases.md](../../DEVELOPMENT_PLAN/later_phases.md)), and the generic third-party
extension mechanism remains at Phase-35. This doc states the target shape and links back for status.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — [§2.3](./content_addressing_doctrine.md#23-the-hashpointer-master-table-four-hash-classes-three-pointer-kinds) the hash/pointer master registry (`releaseHash`, the `environment` pointer kind), [§4](./content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed) determinism; the store the ledger writes into
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — [§5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait) the SSA/ApplySet reconciler `RolloutPlan` enacts, [§6](./manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed) the applied-log this doctrine promotes to the canonical ledger
- [Readiness Ordering Doctrine](./readiness_ordering_doctrine.md) — [§3](./readiness_ordering_doctrine.md#3-readiness-is-a-condition-never-a-duration) the `ReadinessGate` on a `RolloutPhase` is the tier-(c) instance of the general `Readiness` edge (a condition, never a duration)
- [Testing Doctrine](./testing_doctrine.md) — [§4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run proven/tested/assumed evidence ledger the `PromotionGate` consumes
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md) — the Extract → Model → Inject grammar behind the evidence-strength the gate requires
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — [§3](./app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)/[§4](./app_vs_deployment_doctrine.md#4-the-dividing-line--a-litmus-test) env differences are deployment rules; app bytes are byte-identical across environments
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — [§8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction) `create-new → verified-migrate → retire-old` for the schema-migration `RolloutPhase`
- [Network Fabric Doctrine](./network_fabric_doctrine.md) — Gateway-API `HTTPRoute` weights the canary phase shifts; the no-mesh verdict
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — consumer-group / subscription cutover for Pulsar workloads
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — [§3.26](../illegal_state/illegal_state_lifecycle.md#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence) promote-unverified→prod is type-foreclosed unrepresentable
- [Image Build Doctrine](./image_build_doctrine.md) — the build half (multi-arch images, the `distribution` registry)
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — [§3](./daemon_topology_doctrine.md#3-the-control-plane-singleton) the control-plane singleton that runs promote/rollout; the host daemon that builds
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — reconciler tiers (a) cloud-IaC and (b) the tag-discovery host reconciler, distinct from tier (c)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Later Phases](../../DEVELOPMENT_PLAN/later_phases.md) — the promoted Phase-34 schema-migration candidate this doctrine homes
- [Documentation Standards](../documentation_standards.md)

> **Honesty.** Everything here is Phase-0 **reference-only design intent**. The `Release` ledger, the
> `Environment` promotion pointer, the `PromotionGate`, and the `RolloutPlan`/`RolloutPhase` are **unbuilt in
> amoebius** and compose primitives that are themselves Phase-15-and-later. The shapes are **generalized from
> siblings** — jitML's phased readiness-gated rollout and its pre/post-grant schema phase, infernix's
> `.ready`-gated artifact, the content store's ETag-CAS `trial` pointer — each of which is **sibling evidence,
> not proof in amoebius**. Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline), read every
> prescriptive statement as the contract amoebius intends to satisfy, never as a tested amoebius result.
