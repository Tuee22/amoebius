# Lift and Compose, Don't Reimplement

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_16_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_39_infernix_lift.md, DEVELOPMENT_PLAN/phase_40_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/generated_artifacts_doctrine.md
**Generated sections**: none

> **Purpose**: Single source of truth for the principle that amoebius **lifts the proven primitives** of the sibling projects (`prodbox`, `hostbootstrap`, `infernix`, `jitML`) and **re-homes them onto amoebius seams**, rather than reimplementing them — so amoebius's own work is the *composition and the typed surface*, not the numerics, the inference orchestration, or the deployment mechanics that already exist and run.

---

## 1. Why this doctrine exists

The hard, well-tested substance amoebius needs already exists: `jitML` implements a full Haskell-native
numerical core, autodiff, JIT codegen, and a broad RL/SL/AlphaZero catalog; `infernix` implements inference
orchestration, engine-pool routing, and durable-context event-sourcing; `hostbootstrap` implements the
`chain`/`Step` host-lift algebra; `prodbox` implements typed manifest rendering, Dhall decode with
smart-constructor illegal-state types, and schema-reflected-from-Haskell. All four run today and are test-backed.

Rewriting any of that from scratch would discard tested code and reintroduce its bugs, for no gain — the numerics
and the orchestration are not where amoebius is novel. amoebius is novel in **how these shapes are lifted and
composed under one typed DSL**: the illegal-state-unrepresentable surface, the total composability, the single
opinionated platform, the one formal obligation. So the rule is: **lift the proven shape, re-home it onto the
amoebius seam, and reserve new implementation for the composition layer and the seams themselves.** What this
forecloses is amoebius reimplementing MinIO, Pulsar, autodiff, or inference orchestration — work that is done
and whose re-doing would be pure risk.

The lifting is itself pre-cluster-validatable ([conformance_harness_doctrine.md](./conformance_harness_doctrine.md)):
re-homing a proven core onto a new seam is
decode/bind/plan-or-resolve-infrastructure/provision/`renderAll`/compose work exercised in Registers 1
and 2.

---

## 2. What lifts (the reuse map)

Each row is a shape lifted largely intact; the change is the *seam* it plugs into, not the substance.

| Shape lifted | Source (proven, runs today) | amoebius seam it re-homes onto |
|---|---|---|
| `chain`/`Step` algebra, host-lift, binary-context/witness | `hostbootstrap` `Step.hs`/`Chain.hs`/`Lift.hs`/`Context.hs` (prodbox vendors it) | the kernel; extended with a GADT-indexed IR |
| Dhall decode + smart-constructor illegal-state types + schema-reflected-from-Haskell | `prodbox` `Settings`, `Cluster/Topology.hs`, `SchemaDhall.hs`; `hostbootstrap` `Dhall/Gen.hs` | the typed spec gates + the full illegal-state catalog |
| Pure manifest render + byte-for-byte dry-run goldens | `prodbox` `CLI/Charts.hs`, `Lib/ChartPlatform.hs`, `EksImageMirror.hs` | deployment-global `renderAll :: ProvisionedSpec -> [K8sObject]`, after the amoebius post-bind resource/capability seal ([manifest_generation_doctrine.md](./manifest_generation_doctrine.md)) |
| Numerical core / autodiff / JIT codegen / RL-SL-AlphaZero / tuning | `jitML` `Numerics/*`, `Codegen/*`, `RL/*`, `SL/*`, `Tune/*` | an extension's `extChain`; hardware is a deployment rule |
| Determinism kernel (SplitMix) + content-addressed CBOR checkpoint store | `jitML` `Engines/Rng.hs`, `Checkpoint/*` | `Kernel/{Rng,ContentAddress,ExperimentHash}` ([content_addressing_doctrine.md](./content_addressing_doctrine.md)) |
| Inference orchestration, engine-pool routing, durable-context event-source, JWT | `infernix` `Runtime/*`, `Conversation/*`, `Auth/Jwt.hs` | an extension nested under the `InForceSpec` |
| PureScript demo-SPA shells + `purescript-bridge` contract generation | `infernix` `web/`, `jitML` `web/` | contracts re-generated from amoebius-composed types (SPA composition) |

---

## 3. The friction envelope: what is re-shaped during the lift

The substance lifts; the **infrastructure envelope** around it is replaced, because each envelope is a shape
amoebius already rejects on doctrine grounds. These are the only parts rewritten, and each re-homing is
Register-1/2 validatable:

- **Helm charts → typed `renderAll`.** Both siblings deploy via Helm; amoebius renders the full object set from
  typed Haskell with its own apply engine ([manifest_generation_doctrine.md §1](./manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not)).
- **Pulsar WebSocket + protobuf + base64-in-JSON → the native CBOR client.** Both siblings speak Pulsar over a
  WebSocket bridge with base64-inflated JSON; amoebius speaks the native binary protocol with exclusively-CBOR
  payloads ([pulsar_client_doctrine.md §1](./pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets)).
- **k8s-Secret / plaintext creds → Vault secrets-by-name.** Both siblings hold credentials in k8s Secrets (and
  hardcoded defaults); amoebius carries a `SecretRef` name and the parent injects into the child's Vault
  ([vault_pki_doctrine.md §3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)).
- **Python engine-fork / baked engine → the jit-build bounded cache.** `infernix` forks Python adapters and
  bakes per-engine venvs at image build; amoebius names each engine by a typed identity from a closed catalog
  and a shared **jit-build resolver** materializes it on first miss into a `CacheBudget`-bounded,
  content-addressed cache — no arbitrary URL, no author-a-download syntax
  ([content_addressing_doctrine.md](./content_addressing_doctrine.md)).

---

## 4. The demo web apps: PureScript SPAs, contracts generated from Haskell

Each of `infernix` and `jitML` ships a **PureScript** single-page demo app (built with `spago`), whose frontend
**contract types are generated from the Haskell ADTs via `purescript-bridge`** and are exercised end to end
under a browser driver. amoebius lifts these shells and regenerates their contracts from the amoebius-composed
types; the generated PureScript contract is a build artifact, never committed
([generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)). A demo web app is **application logic
that *uses* its extension**
([app_vs_deployment_doctrine.md §8](./app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic))
while itself contributing an `ExtensionSpec 'App`
([capability_extension_doctrine.md §2](./capability_extension_doctrine.md#2-three-extension-kinds-workload-capability-and-app)) —
*using* an extension and *being* one are different relations, and a demo app does both. The two demo apps are
the SPA-composition fixtures.

**Where the compiled bundle lives.** `spago` emits JavaScript, HTML, and CSS — bytes that are neither Haskell
nor Dhall, so they cannot be linked and they are the one part of an app that linking does not place. They are
**baked**: the bundle is a `BakeStep.CopyGeneratedAsset` in the app's own `Runtime` variant
([image_build_doctrine.md §6](./image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1)),
produced by the same `spago` build whose contract types `purescript-bridge` emits, and served by the pod's
Web-service host worker
([daemon_topology_doctrine.md §4](./daemon_topology_doctrine.md#4-worker-daemons--n-unelected)).

Baking is the right answer here and the content-addressed cache is the wrong one, for three reasons that are
each decisive on their own. The cache's asset catalog is closed and **not authorable by an app**, so a
per-app bundle identity would be a platform code change per app — reproducing at the asset layer exactly the
closed-set problem the `App` tier exists to dissolve. Its hash/pointer registry declares itself the
authoritative set of hash classes, so a bundle class is an amendment to a document that is closed over
precisely this. And its serve gate admits two provenance witnesses — a committed producing checkpoint or a
pinned external import — and a locally built bundle is neither
([content_addressing_doctrine.md](./content_addressing_doctrine.md)). Baking needs none of those changes: the
bundle is bytes amoebius built, entering an image amoebius builds, by the mechanism every other byte uses.

---

## 5. Evidence, not proof

Every lifted shape is **evidence from a sibling system that the shape works — never proof in amoebius**
([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).
That `jitML` trains reproducibly today, or that `prodbox` renders manifests without Helm today, argues the
amoebius design is achievable; it is not an amoebius result until the amoebius phase that lifts it passes its own
gate. The forward record of which sibling artifact each phase supersedes is
[legacy_tracking_for_deletion.md](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md).

---

## 6. Planning ownership

This document is normative only. Which phase lifts which shape is owned by
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) and
[system_components.md](../../DEVELOPMENT_PLAN/system_components.md); the migration-removal ledger is
[legacy_tracking_for_deletion.md](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). Every statement here
is design intent, never a tested amoebius result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — a demo web app is application logic, not an extension
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — Helm → typed `renderAll`
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — WebSocket/protobuf/base64 → native CBOR
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — k8s-Secret → Vault secrets-by-name
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — Python engine-fork/baked → jit-build bounded cache
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — the PureScript contract is generated, not committed
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — re-homing is Register-1/2 validatable
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
