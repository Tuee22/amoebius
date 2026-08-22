# System Components

> **Purpose**: Map every target amoebius component to its Haskell ownership boundary, canonical doctrine, and
> numerical delivery phase without maintaining a second implementation or status ledger.
> **Read this if**: a component must be traced to the Haskell source shape, doctrine, or phase that owns it.

This is a target-only inventory. It owns no architectural rule and makes no implementation or validation
claim. Architecture belongs to the linked doctrine, phase status belongs only to [the tracker](README.md), and
every current source/layout divergence belongs only to
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, documents/engineering/lift_and_compose_doctrine.md
**Generated sections**: none

</details>

## Contents

- [How to read this inventory](#how-to-read-this-inventory)
- [Reconciliation state](#reconciliation-state)
- [1. The single binary — three contexts, several typed roles](#1-the-single-binary--three-contexts-several-typed-roles)
- [1.5. The core algebra — five calculi, two indices, one contract](#15-the-core-algebra--five-calculi-two-indices-one-contract)
- [2. The DSL — Dhall decoder + chain/Step kernel](#2-the-dsl--dhall-decoder--chainstep-kernel)
- [3. Manifests — typed renderer + the SSA reconciler](#3-manifests--typed-renderer--the-ssa-reconciler)
- [4. Capabilities — the capability→provider→shape binder](#4-capabilities--the-capabilityprovidershape-binder)
- [5. Platform services — baked non-Registry binaries + separately preloaded Distribution `registry:2`](#5-platform-services--baked-non-registry-binaries--separately-preloaded-distribution-registry2)
- [6. The native Pulsar client — `lib:pulsar-client`](#6-the-native-pulsar-client--libpulsar-client)
- [7. The content-addressed store + determinism kernel](#7-the-content-addressed-store--determinism-kernel)
- [8. Vault, secrets & PKI](#8-vault-secrets--pki)
- [9. Substrate tool-ensure + base-image build](#9-substrate-tool-ensure--base-image-build)
- [10. Pulumi backend (IaC)](#10-pulumi-backend-iac)
- [11. Release lifecycle — `lib:release-lifecycle`](#11-release-lifecycle--librelease-lifecycle)
- [12. Network fabric — raw-kernel WireGuard](#12-network-fabric--raw-kernel-wireguard)
- [13. The multi-cluster forest — spawn, geo-replication, gateway migration](#13-the-multi-cluster-forest--spawn-geo-replication-gateway-migration)
- [14. The pre-cluster (Register 1–2) design-first validation surface](#14-the-pre-cluster-register-12-design-first-validation-surface)
- [Related Documents](#related-documents)

---

## How to read this inventory

Every row is a target obligation and every phase is **NOT VALIDATED**. A path describes the intended Haskell
ownership boundary; it does not assert that the path exists or works. The closed repository-source rule is:

- behavioral production, generator, gate, fixture, oracle, mutant, and test source is version-controlled only
  as `.hs`;
- `pb/**` is the sole non-Haskell source exception and may only make the minimal platform distinction needed
  to establish the pinned toolchain, build the source-bound Haskell binary, and `exec` it with every user
  argument unchanged; Haskell owns host-floor policy and every public command;
- external/operator input is untracked;
- Dhall, Proto, PureScript, JavaScript, HTML, CSS, Pulumi programs, image recipes, manifests, serialized cases,
  reports, receipts, transcripts, and other foreign/derived bytes are emitted lazily beneath `.build/**`; and
- Markdown plus minimal build/repository metadata is governed non-behavioral input, not executable source.

The authoritative boundary and exact tree are in
[Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md). A row here cannot waive
that rule.

## Reconciliation state

This document deliberately contains no present-tree audit, historical result, stale receipt, or deletion
checklist. [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) is the single active register
for every known divergence. A current finding not bijectively matched to one active stable ID is itself a
Phase-0 failure. Removing a row here cannot conceal debt, and adding a path here cannot validate it.

## 1. The single binary — three contexts, several typed roles

One Haskell executable owns command mode, the sudo host-daemon context, and in-cluster roles. Roles are a
closed Haskell sum; they are not separate products or foreign-language entry points.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Executable and total role dispatch | `app/**/Main.hs`; `src/**/Command.hs`; `src/**/Role.hs` | [Daemon Topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-runtime-binary-three-contexts) | [34](phase_34_chain_kernel_boundary.md), [43](phase_43_ui_server_boundary.md), [55](phase_55_bootstrap_coordinator_kind.md) |
| Haskell command-mode administration | `src/**/AdminClient.hs` | [Bootstrap Sequence §5](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-control-plane-daemon-rest-api) | [65](phase_65_live_dsl_deploy.md) |
| Sudo host daemon and host-worker supervision | `src/**/Host/*.hs`; `src/**/HostWorker/*.hs` | [Daemon Topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-runtime-binary-three-contexts) | [55](phase_55_bootstrap_coordinator_kind.md), [89](phase_89_apple_metal_host_daemon.md) |
| Control-plane daemon, capacity scheduler, and unelected workers | `src/**/ControlPlane/*.hs`; `src/**/Scheduler/*.hs`; `src/**/Workflow/*.hs` | [Daemon Topology §§3–4](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) | [59](phase_59_capacity_scheduler.md), [65](phase_65_live_dsl_deploy.md), [69](phase_69_content_store_workflow.md) |

## 1.5. The core algebra — five calculi, two indices, one contract

Artifact, budget, lift, workflow, and evidence calculi plus scope/resource indices are Haskell libraries.
Their tests, independent semantic expectations, and mutants are also `.hs`.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Five calculi | `src/**/Calculus/*.hs`; `test/**/Calculus/*.hs` | [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | [3–7](phase_03_artifact_calculus.md), [10](phase_10_calculus_composition.md) |
| Scope and resource indices | `src/**/Scope/*.hs`; `src/**/Capacity/*.hs` | [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [8](phase_08_scope_index.md), [9](phase_09_resource_index.md), [28–32](phase_28_storage_geometry_folds.md) |
| Formal/checker models | `src/**/Formal/*.hs`; `test/**/Formal/*.hs` | [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) | [11–19](phase_11_formal_model_kernel.md) |
| Extension laws and transactions | `src/**/Extension/*.hs`; `test/**/Extension/*.hs` | [Extension Conformance Doctrine](../documents/engineering/extension_conformance_doctrine.md) | [20–24](phase_20_extension_declaration.md), [36](phase_36_transaction_vocabulary.md) |

## 2. The DSL — Dhall decoder + chain/Step kernel

Haskell is the sole behavioral source for the DSL schema, typed decoder, legality checks, binding, planning,
provision seal, renderer, and lifecycle plan. Dhall supplied by an operator is external/untracked input. Any
Dhall schema/prelude/projection used by tooling is lazily generated beneath `.build/**` from Haskell.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Schema declarations and generated Dhall projection | `src/**/Dsl/Schema/*.hs`; generated `.build/dhall/**` | [DSL Doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) | [25](phase_25_dhall_schema_generation.md) |
| Protocol declarations, decode, and typed IR | `src/**/Dsl/{Protocol,Decode,Types}/*.hs`; generated `.build/proto/**` | [DSL Doctrine §5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) | [26–27](phase_26_gadt_decode_ir.md) |
| Bind, plan, provision, render, dry-run, and fake apply | `src/**/{Capability,Capacity,Manifest,Kernel}/*.hs` | [Conformance Harness Doctrine §4](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply) | [30–34](phase_30_capability_bind.md), [49](phase_49_self_referential_gates.md) |
| UI/offline semantics and lazy browser projections | `src/**/Ui/*.hs`; generated `.build/ui/**` | [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) | [37–46](phase_37_ui_program_schema.md) |
| Haskell generator/gate/mutant/test-workflow layer | `src/**/{Generate,Validate,Test}/*.hs`; `test/**/*.hs` | [Testing Doctrine](../documents/engineering/testing_doctrine.md) | [47–49](phase_47_tool_and_mutant_generation.md) |

No host, browser, container, cluster, provider, or hardware validation may start until Phase 49 itself has been
independently validated and human-promoted after every predecessor.

## 3. Manifests — typed renderer + the SSA reconciler

`K8sObject` values, ownership, dependency order, diffing, and snapshot-bound actions are Haskell. YAML/JSON
manifests and observation records are lazy `.build/**` materializations.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Total typed renderer | `src/**/Manifest/*.hs`; `test/**/Manifest/*.hs` | [Manifest Generation Doctrine §2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) | [33](phase_33_render_manifest_oracles.md) |
| Snapshot-bound SSA reconciler | `src/**/Reconcile/*.hs` | [Manifest Generation Doctrine §5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) | [58](phase_58_object_reconciler.md) |

## 4. Capabilities — the capability→provider→shape binder

Capabilities, providers, shapes, permissions, supply, binding, and provisioned seals are closed Haskell types
and functions. Application/operator values cannot name provider coordinates or construct authority.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Capability/provider catalog and binding | `src/**/Capability/*.hs` | [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) | [30](phase_30_capability_bind.md) |
| Whole-deployment provision seal | `src/**/Capacity/Provision*.hs` | [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [31](phase_31_provision_seal.md) |
| Accelerator/engine offering | `src/**/Engine/*.hs`; `src/**/Capacity/Accelerator*.hs` | [Service Capability Doctrine §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | [32](phase_32_inference_accelerator_provision.md) |

## 5. Platform services — baked non-Registry binaries + separately preloaded Distribution `registry:2`

The Registry capability has exactly one provider: CNCF Distribution `registry:2`. No other registry product is
an alternative, fallback, compatibility arm, or future option. Its separately pinned image is preloaded; its
binary is never baked into `amoebius-base`. Every other platform-service binary is baked. Service declarations
and manifests are Haskell-owned; runtime artifacts are generated under `.build/**` or materialized in the
live target.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Base image and Distribution registry | `src/**/Image/*.hs`; `src/**/Platform/Registry*.hs` | [Image Build Doctrine](../documents/engineering/image_build_doctrine.md), [Service Capability Doctrine §3](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific) | [35](phase_35_image_recipe_generation.md), [56](phase_56_base_image_registry.md) |
| Object store, message bus, retained storage | `src/**/Platform/{ObjectStore,MessageBus,Storage}*.hs` | [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) | [60–62](phase_60_retained_storage.md) |
| SQL, Redis, observability, readiness | `src/**/Platform/{Sql,Redis,Observability,Readiness}*.hs` | [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) | [63](phase_63_platform_services_2.md) |
| Identity and single ingress | `src/**/Platform/{Identity,Edge}*.hs` | [Platform Services Doctrine §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) | [64](phase_64_keycloak_ingress.md) |

## 6. The native Pulsar client — `lib:pulsar-client`

Protocol source, codec, framing, subscription vocabulary, client state, fakes, and tests are Haskell. A `.proto`
view and any bindings/checksums are generated lazily beneath `.build/proto/**`.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Protocol declaration and generated projection | `src/**/Pulsar/Protocol*.hs` | [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) | [26](phase_26_gadt_decode_ir.md) |
| Native client and bounded live correspondence | `src/**/Pulsar/*.hs`; `test/**/Pulsar/*.hs` | [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) | [67](phase_67_pulsar_client.md) |

## 7. The content-addressed store + determinism kernel

Content identities, commit boundaries, cache budgets, deterministic seeds, and workflow integration are
Haskell. Blobs, manifests, cache contents, and run evidence are runtime or `.build/**` products.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Store and workflow runtime | `src/**/{Store,Workflow}/*.hs` | [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) | [69](phase_69_content_store_workflow.md) |
| Determinism and bounded JIT cache | `src/**/{Determinism,Cache}/*.hs` | [Content Addressing Determinism](../documents/engineering/content_addressing_determinism.md) | [80](phase_80_determinism_jitcache.md) |

## 8. Vault, secrets & PKI

Secret references, clients, unseal envelopes, PKI plans, and zero-persistence checks are Haskell. Secret values
are runtime-only and never tracked or retained as gate evidence.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Vault client, root unseal, and PKI | `src/**/Vault/*.hs`; `test/**/Vault/*.hs` | [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) | [61](phase_61_vault_pki.md) |
| Haskell administrative path | `src/**/ControlPlane/Admin*.hs` | [Bootstrap Sequence §5](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-control-plane-daemon-rest-api) | [65](phase_65_live_dsl_deploy.md) |

## 9. Substrate tool-ensure + base-image build

After the bounded `pb/**` handoff, substrate detection, absolute-path tool ensure, engine bring-up, image-plan
derivation, and host-worker behavior are Haskell. Image recipes, bake projections, logs, and attestations are
lazy `.build/**` products.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Bounded pre-binary handoff | `pb/**` exception only | [Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md) | [50](phase_50_host_assert_cli.md) |
| Haskell tool-ensure kernel and engine adapters | `src/**/Substrate/*.hs`; `src/**/Engine/*.hs` | [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) | [51–54](phase_51_host_ensure_kernel.md) |
| Haskell cluster bootstrap coordinator | `src/**/Cluster/*.hs` | [Bootstrap Sequence Doctrine](../documents/engineering/bootstrap_sequence_doctrine.md) | [55](phase_55_bootstrap_coordinator_kind.md) |
| Native/complementary image materialization | `src/**/Image/*.hs` | [Image Build Doctrine](../documents/engineering/image_build_doctrine.md) | [56–57](phase_56_base_image_registry.md) |
| Physical host compute | `src/**/HostWorker/*.hs` | [Substrate Doctrine §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized) | [89](phase_89_apple_metal_host_daemon.md) |

## 10. Pulumi backend (IaC)

Provider intent and Pulumi program source are Haskell. Any Pulumi-language projection, plugin state, checkpoint,
plan, log, or receipt is generated or materialized beneath `.build/**` and never tracked as behavioral source.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Provider plan/program derivation | `src/**/Pulumi/*.hs` | [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) | [76](phase_76_provider_deploy_checkpoint.md) |
| Child convergence, durable volume, dynamic nodes | `src/**/Provider/*.hs` | [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) | [77–79](phase_77_provider_child_bringup.md) |

## 11. Release lifecycle — `lib:release-lifecycle`

Release identities, promotion, rollout, UI-program atomicity, cursor/reconnect, and offline evolution are
Haskell state machines. Browser bundles and migration artifacts are lazy `.build/**` products.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Release and rollout lifecycle | `src/**/Release/*.hs` | [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md) | [71](phase_71_release_lifecycle.md) |
| Atomic UI-program release | `src/**/Ui/Release*.hs` | [Low-Code UI Runtime Doctrine §15](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) | [72](phase_72_ui_program_release.md) |
| Reconnect and offline evolution | `src/**/Ui/{Reconnect,OfflineMigration}*.hs` | [Browser Offline Runtime Doctrine](../documents/engineering/browser_offline_runtime_doctrine.md) | [83](phase_83_ui_rollout_reconnect.md), [87](phase_87_offline_release_evolution.md) |

## 12. Network fabric — raw-kernel WireGuard

Peer topology, address allocation, `SecretRef` resolution, configuration derivation, and reconciliation plans
are Haskell. Rendered configuration and observations are `.build/**`/runtime products.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| WireGuard fabric | `src/**/Network/WireGuard*.hs` | [Network Fabric Doctrine](../documents/engineering/network_fabric_doctrine.md) | [73](phase_73_network_fabric_wireguard.md) |

## 13. The multi-cluster forest — spawn, geo-replication, gateway migration

Forest topology, child bootstrap plans, geo-replication, migration decisions, and drill workflows are Haskell.
Provider/cluster state and drill records are live or `.build/**` products.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Child spawn and geo-replication | `src/**/Multicluster/{Spawn,Replication}*.hs` | [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) | [74](phase_74_multicluster_spawn_georepl.md) |
| Gateway migration model and drills | `src/**/Multicluster/Migration*.hs` | [Gateway Migration Doctrine](../documents/engineering/gateway_migration_doctrine.md) | [17](phase_17_gateway_migration_model.md), [75](phase_75_gateway_migration_drills.md) |

## 14. The pre-cluster (Register 1–2) design-first validation surface

Phases 1–49 establish the Haskell language, semantics, generators, independent oracles, mutation qualification,
cleanroom derivation, and full hardware-free pipeline before any live/hardware work. Their shared command form
is exactly `pb validate phase NN`; `pb` only ensures/builds/execs the Haskell verdict entry point. Each phase's
18-key table must be resolved, independently reviewed, run fresh, and human-promoted in strict numerical order.

Phase 49 is the final promotion barrier and must exercise:

`decode → legality → bind/expand → plan/resolve → provision → renderAll → plan → dry-run → fake apply`

with no browser, container, cluster, provider, network service, or hardware-specific observer. Until that
barrier is promoted, Phase 50 and every live/hardware phase remain blocked.

## Related Documents

- [Development Plan Tracker](README.md) — sole phase-status authority
- [Development Plan Standards](development_plan_standards.md) — plan and gate contract
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md) — sole active divergence register
- [Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md) — closed source tree
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — lazy `.build/**` rule
- [Testing Spoof Resistance](../documents/engineering/testing_spoof_resistance.md) — independent validation trust
