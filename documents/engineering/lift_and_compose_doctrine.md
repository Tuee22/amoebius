# Lift and Compose, Don't Reimplement

> **Purpose**: Single source of truth for the principle that amoebius **lifts the proven primitives** of the sibling projects (`prodbox`, `hostbootstrap`, `infernix`, `jitML`) and **re-homes them onto amoebius seams**, rather than reimplementing them — so amoebius's own work is the *composition and the typed surface*, not the numerics, the inference orchestration, or the deployment mechanics that already exist and run.
> **Read this if**: an existing sibling implementation could serve a need, and the question is whether to lift or rewrite.

This document owns the reuse discipline: which shape lifts from which sibling project onto which seam, what
is re-shaped in the process, and the honest statement that a sibling result is evidence rather than an
amoebius result. It owns none of the lifted code, and the seams it names are owned by their own doctrines.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/migration_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

---

## 1. Why this doctrine exists

The hard, well-tested substance amoebius needs already exists: `jitML` implements a full Haskell-native
numerical core, autodiff, JIT codegen, and a broad RL/SL/AlphaZero catalog; `infernix` implements inference
orchestration, engine-pool routing, and durable-context event-sourcing; `hostbootstrap` implements the
`chain`/`Step` host-lift algebra; `prodbox` implements typed manifest rendering, Dhall decode with
smart-constructor illegal-state types, and schema-reflected-from-Haskell. All four run today and are test-backed.

Rewriting any of that from scratch would discard tested code and reintroduce its bugs, for no gain — the numerics
and the orchestration are not where amoebius is novel. amoebius is novel in **how these shapes are lifted and composed under one typed DSL**: the illegal-state-unrepresentable surface, the total composability, the single
opinionated platform, the one formal obligation. So the rule is: **lift the proven shape, re-home it onto the amoebius seam, and reserve new implementation for the composition layer and the seams themselves.** What this
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
| Inference orchestration, engine-pool routing, durable-context event-source | `infernix` `Runtime/*`, `Conversation/*` | trusted Haskell workflow/artifact handlers behind typed UI ports; identity comes from the platform request context |
| Demo-SPA UX flows + the `purescript-bridge` contract-generation pattern | `infernix` `web/`, `jitML` `web/` | UX behavior is recast as bounded `UiSource`; public contracts/codecs derive from the checked Haskell boundary and run in the generic PureScript client |

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
- **Handwritten demo clients and sibling JWT/direct endpoints → `UiSource`, typed ports, and the authenticated UI server.** The sibling screens supply interaction requirements, while their browser networking and identity
  seams are replaced. One checked `BoundUiProgram` derives the generic client and server dispatch; every effect
  crosses the Keycloak/Envoy edge and a trusted Haskell handler
  ([low_code_ui_runtime_doctrine.md §13](./low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server)).

---

## 4. Sibling demo clients are migration inputs, not the runtime model

Each of `infernix` and `jitML` ships a handwritten PureScript single-page demo app. Those shells prove that the
sibling interaction flows are realizable and identify public contract requirements; they are not lifted as
amoebius application code. Their screens, state transitions, workflow controls, and artifact interactions are
re-expressed as bounded `UiSource` modules. Their Haskell workflow and artifact logic remains trusted linked
behavior and is exposed through typed port handlers. A low-code app consumes those handlers without itself
becoming an extension
([low_code_ui_runtime_doctrine.md §12](./low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux)).

`purescript-bridge` remains useful as evidence and, where compatible with the selected implementation, as the
mechanism for deriving public PureScript contract types from reified Haskell contracts. The authoritative
requirement is broader: Haskell server decoders and PureScript client codecs derive from the same checked public
contract value. No handwritten frontend contract or correspondence table is authoritative.

**Where the compiled client lives.** The committed PureScript source is the generic interpreter and trusted
component catalog. Its pinned build emits one generic JavaScript/HTML/CSS runtime bundle, copied into the
generic UI-runtime image by the typed bake mechanism
([image_build_doctrine.md §6](./image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1))
and served by the web-worker taxonomy of
[daemon_topology_doctrine.md §4](./daemon_topology_doctrine.md#4-worker-daemons--n-unelected).

Each application release emits an immutable `ClientPlan` plus its public-contract/content manifest. Those
content artifacts are never committed, do not contain a handwritten entry point, and do not rebuild an OCI
layer; the generic runtime loads and interprets them. The UI-specific plan/version contract is owned by
[low_code_ui_runtime_doctrine.md §15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts).

The generic client bundle is an image-build artifact; the per-app plan/manifest is an immutable release/content
artifact. Neither is an ML asset, and neither enters the runtime jit-build artifact cache. The
content-addressed model store continues to own ready/provenance-gated models and checkpoints; it does not become
an authorable frontend package registry.

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

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — [§3](./low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) the checked client/server projection and [§12](./low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux) workflow/artifact UX lifting
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — `UiSource` and typed workflow use are application logic; replica and placement choices are deployment rules
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — Helm → typed `renderAll`
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — WebSocket/protobuf/base64 → native CBOR
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — k8s-Secret → Vault secrets-by-name
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — Python engine-fork/baked → jit-build bounded cache
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — per-app UI plans/content manifests and the generic runtime's catalog codecs/bundle are generated, not committed
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — re-homing is Register-1/2 validatable
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
